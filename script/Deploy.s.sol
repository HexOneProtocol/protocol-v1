// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {console2 as console} from "forge-std/Test.sol";

import {BaseScript} from "./Base.s.sol";

import {HexOneToken} from "../src/HexOneToken.sol";
import {HexitToken} from "../src/HexitToken.sol";
import {HexOneStaking} from "../src/HexOneStaking.sol";
import {HexOnePriceFeed} from "../src/HexOnePriceFeed.sol";
import {HexOneVault} from "../src/HexOneVault.sol";
import {HexOneBootstrap} from "../src/HexOneBootstrap.sol";
import {HexOneFeedAggregator} from "../src/HexOneFeedAggregator.sol";

import {IPulseXFactory} from "../src/interfaces/pulsex/IPulseXFactory.sol";

contract DeploymentScript is BaseScript {
    // TODO: team wallet
    address internal constant TEAM_WALLET = address(0x1337);

    // pulsex
    address internal constant PULSEX_FACTORY = 0x1715a3E4A142d8b698131108995174F37aEBA10D;
    address internal constant PULSEX_ROUTER = 0x98bf93ebf5c380C0e6Ae8e192A7e2AE08edAcc02;

    // pulsex pairs
    address internal constant HEX_DAI_PAIR = 0x6F1747370B1CAcb911ad6D4477b718633DB328c8;
    address internal constant WPLS_DAI_PAIR = 0xE56043671df55dE5CDf8459710433C10324DE0aE;
    address internal constant PLSX_DAI_PAIR = 0xB2893ceA8080bF43b7b60B589EDaAb5211D98F23;
    address internal constant HEX_WPLS_PAIR = 0xf1F4ee610b2bAbB05C635F726eF8B0C568c8dc65;
    address internal constant WPLS_USDC_PAIR = 0x6753560538ECa67617A9Ce605178F788bE7E524E;
    address internal constant WPLS_USDT_PAIR = 0x322Df7921F28F1146Cdf62aFdaC0D6bC0Ab80711;

    // tokens
    address internal constant HEX_TOKEN = 0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39;
    address internal constant DAI_TOKEN = 0xefD766cCb38EaF1dfd701853BFCe31359239F305;
    address internal constant WPLS_TOKEN = 0xA1077a294dDE1B09bB078844df40758a5D0f9a27;
    address internal constant PLSX_TOKEN = 0x95B303987A60C71504D99Aa1b13B4DA07b0790ab;
    address internal constant USDC_TOKEN = 0x15D38573d2feeb82e7ad5187aB8c1D52810B1f07;
    address internal constant USDT_TOKEN = 0x0Cb6F5a34ad42ec934882A05265A7d5F59b51A2f;

    // staking distribution rates
    uint16 internal constant HEX_STAKING_DIST_RATE = 100;
    uint16 internal constant HEXIT_STAKING_DIST_RATE = 100;

    // stake tokens weight
    uint16 internal constant HEX1_DAI_WEIGHT = 7000;
    uint16 internal constant HEX1_WEIGHT = 2000;
    uint16 internal constant HEXIT_WEIGHT = 1000;

    // bootstrap sacrifice tokens multiplier
    uint16 internal constant HEX_SACRIFICE_MULTIPLIER = 55555;
    uint16 internal constant DAI_SACRIFICE_MULTIPLIER = 30000;
    uint16 internal constant WPLS_SACRIFICE_MULTIPLIER = 20000;
    uint16 internal constant PLSX_SACRIFICE_MULTIPLIER = 10000;

    // protocol contracts
    HexOneToken internal hex1;
    HexitToken internal hexit;
    HexOnePriceFeed internal feed;
    HexOneFeedAggregator internal aggregator;
    HexOneStaking internal staking;
    HexOneVault internal vault;
    HexOneBootstrap internal bootstrap;

    // HEX1/DAI pair
    address internal hex1DaiPair;

    function run() external {
        // deploy the protocol
        _deploy();

        // configure the protocol
        _configure();

        // display protocol addresses
        _display();
    }

    function _deploy() internal broadcast {
        // deploy HEX1 token
        hex1 = new HexOneToken("Hex One Token", "HEX1");

        // deploy HEXIT token
        hexit = new HexitToken("Hexit Token", "HEXIT");

        // deploy price feed
        address[] memory pairs = new address[](6);
        pairs[0] = HEX_DAI_PAIR;
        pairs[1] = WPLS_DAI_PAIR;
        pairs[2] = PLSX_DAI_PAIR;
        pairs[3] = HEX_WPLS_PAIR;
        pairs[4] = WPLS_USDC_PAIR;
        pairs[5] = WPLS_USDT_PAIR;
        feed = new HexOnePriceFeed(PULSEX_FACTORY, pairs);

        // deploy feed aggregator
        aggregator = new HexOneFeedAggregator(address(feed), HEX_TOKEN, DAI_TOKEN, WPLS_TOKEN, USDC_TOKEN, USDT_TOKEN);

        // deploy staking
        staking = new HexOneStaking(HEX_TOKEN, address(hexit), HEX_STAKING_DIST_RATE, HEXIT_STAKING_DIST_RATE);

        // deploy vault
        vault = new HexOneVault(HEX_TOKEN, DAI_TOKEN, address(hex1));

        // deploy bootstrap
        bootstrap = new HexOneBootstrap(
            PULSEX_ROUTER, PULSEX_FACTORY, HEX_TOKEN, address(hexit), DAI_TOKEN, address(hex1), TEAM_WALLET
        );
    }

    function _configure() internal broadcast {
        // configure HEX1 token
        hex1.setHexOneVault(address(vault));

        // configure HEXIT token
        hexit.setHexOneBootstrap(address(bootstrap));

        // configure staking
        staking.setBaseData(address(vault), address(bootstrap));

        hex1DaiPair = IPulseXFactory(PULSEX_FACTORY).getPair(address(hex1), DAI_TOKEN);
        if (hex1DaiPair == address(0)) {
            hex1DaiPair = IPulseXFactory(PULSEX_FACTORY).createPair(address(hex1), DAI_TOKEN);
        }

        address[] memory stakeTokens = new address[](3);
        stakeTokens[0] = hex1DaiPair;
        stakeTokens[1] = address(hex1);
        stakeTokens[2] = address(hexit);

        uint16[] memory weights = new uint16[](3);
        weights[0] = HEX1_DAI_WEIGHT;
        weights[1] = HEX1_WEIGHT;
        weights[2] = HEXIT_WEIGHT;

        staking.setStakeTokens(stakeTokens, weights);

        // configure vault
        vault.setBaseData(address(aggregator), address(staking), address(bootstrap));

        // configure bootstrap
        address[] memory sacrificeTokens = new address[](4);
        sacrificeTokens[0] = HEX_TOKEN;
        sacrificeTokens[1] = DAI_TOKEN;
        sacrificeTokens[2] = WPLS_TOKEN;
        sacrificeTokens[3] = PLSX_TOKEN;

        uint16[] memory multipliers = new uint16[](4);
        multipliers[0] = HEX_SACRIFICE_MULTIPLIER;
        multipliers[1] = DAI_SACRIFICE_MULTIPLIER;
        multipliers[2] = WPLS_SACRIFICE_MULTIPLIER;
        multipliers[3] = PLSX_SACRIFICE_MULTIPLIER;

        bootstrap.setSacrificeTokens(sacrificeTokens, multipliers);

        bootstrap.setBaseData(address(feed), address(staking), address(vault));
    }

    function _display() internal view {
        console.log("HexOneToken:          ", address(hex1));
        console.log("HexitToken:           ", address(hexit));
        console.log("HexOnePriceFeed:      ", address(feed));
        console.log("HexOneFeedAggregator: ", address(aggregator));
        console.log("HexOneStaking:        ", address(staking));
        console.log("HexOneVault:          ", address(vault));
        console.log("HexOneBootstrap:      ", address(bootstrap));
        console.log("HEX1/DAI pair:        ", address(hex1DaiPair));
    }
}
