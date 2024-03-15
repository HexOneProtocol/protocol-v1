// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {Test, stdError, console2 as console} from "forge-std/Test.sol";

import {HexOneToken} from "../../src/HexOneToken.sol";
import {HexitToken} from "../../src/HexitToken.sol";
import {HexOneStaking} from "../../src/HexOneStaking.sol";
import {HexOnePriceFeed} from "../../src/HexOnePriceFeed.sol";
import {HexOneVault} from "../../src/HexOneVault.sol";
import {HexOneBootstrap} from "../../src/HexOneBootstrap.sol";
import {HexOneFeedAggregator} from "../../src/HexOneFeedAggregator.sol";

import {UniswapV2Library} from "../../src/libraries/UniswapV2Library.sol";

import {IHexToken} from "../../src/interfaces/IHexToken.sol";
import {IHexOneToken} from "../../src/interfaces/IHexOneToken.sol";
import {IHexitToken} from "../../src/interfaces/IHexitToken.sol";
import {IHexOneStaking} from "../../src/interfaces/IHexOneStaking.sol";
import {IHexOnePriceFeed} from "../../src/interfaces/IHexOnePriceFeed.sol";
import {IHexOneVault} from "../../src/interfaces/IHexOneVault.sol";
import {IHexOneBootstrap} from "../../src/interfaces/IHexOneBootstrap.sol";
import {IHexOneFeedAggregator} from "../../src/interfaces/IHexOneFeedAggregator.sol";

import {IPulseXPair} from "../../src/interfaces/pulsex/IPulseXPair.sol";
import {IPulseXFactory} from "../../src/interfaces/pulsex/IPulseXFactory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Base is Test {
    HexOneToken public hex1;
    HexitToken public hexit;
    HexOneStaking public staking;
    HexOnePriceFeed public feed;
    HexOneVault public vault;
    HexOneBootstrap public bootstrap;
    HexOneFeedAggregator public aggregator;

    address public pulseXFactory = 0x1715a3E4A142d8b698131108995174F37aEBA10D;
    address public pulseXRouter = 0x98bf93ebf5c380C0e6Ae8e192A7e2AE08edAcc02;

    address public hexDaiPair = 0x6F1747370B1CAcb911ad6D4477b718633DB328c8;
    address public wplsDaiPair = 0xE56043671df55dE5CDf8459710433C10324DE0aE;
    address public plsxDaiPair = 0xB2893ceA8080bF43b7b60B589EDaAb5211D98F23;
    address public hexWplsPair = 0xf1F4ee610b2bAbB05C635F726eF8B0C568c8dc65;
    address public wplsUsdcPair = 0x6753560538ECa67617A9Ce605178F788bE7E524E;
    address public wplsUsdtPair = 0x322Df7921F28F1146Cdf62aFdaC0D6bC0Ab80711;

    address public hexOneDaiPair;

    address public hexToken = 0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39;
    address public daiToken = 0xefD766cCb38EaF1dfd701853BFCe31359239F305;
    address public wplsToken = 0xA1077a294dDE1B09bB078844df40758a5D0f9a27;
    address public plsxToken = 0x95B303987A60C71504D99Aa1b13B4DA07b0790ab;
    address public usdcToken = 0x15D38573d2feeb82e7ad5187aB8c1D52810B1f07;
    address public usdtToken = 0x0Cb6F5a34ad42ec934882A05265A7d5F59b51A2f;

    address public user = makeAddr("user");
    address public attacker = makeAddr("attacker");
    address public deployer = makeAddr("deployer");
    address public receiver = makeAddr("receiver");

    function setUp() public virtual {
        // setup the fork
        // vm.createSelectFork("https://rpc.pulsechain.com", 19530000);
        vm.createSelectFork("https://rpc.pulsechain.com");

        // impersonate the deployer
        vm.startPrank(deployer);

        // deploy HEX1 token
        hex1 = new HexOneToken("Hex One Token", "HEX1");

        // deploy HEXIT token
        hexit = new HexitToken("Hexit Token", "HEXIT");

        // deploy the price feed
        address[] memory pairs = new address[](6);
        pairs[0] = hexDaiPair;
        pairs[1] = wplsDaiPair;
        pairs[2] = plsxDaiPair;
        pairs[3] = hexWplsPair;
        pairs[4] = wplsUsdcPair;
        pairs[5] = wplsUsdtPair;
        feed = new HexOnePriceFeed(pulseXFactory, pairs);

        // deploy the staking contract with 1% distribution rate of each token in bps
        uint16 hexDistRate = 100;
        uint16 hexitDistRate = 100;
        staking = new HexOneStaking(hexToken, address(hexit), hexDistRate, hexitDistRate);

        // deploy the feed aggregator
        aggregator = new HexOneFeedAggregator(address(feed), hexToken, daiToken, wplsToken, usdcToken, usdtToken);

        // deploy the vault contract
        vault = new HexOneVault(hexToken, daiToken, address(hex1));

        // deploy the bootstrap contract
        bootstrap = new HexOneBootstrap(
            address(pulseXRouter), address(pulseXFactory), hexToken, address(hexit), daiToken, address(hex1), receiver
        );

        // set the vault to have permissions to mint HEX1
        hex1.setHexOneVault(address(vault));

        // set the bootstrap to have permissions to mint HEXIT
        hexit.setHexOneBootstrap(address(bootstrap));

        // set addresses of the vault to ensure access control in the staking contract
        staking.setBaseData(address(vault), address(bootstrap));

        // create an array with the supported tokens for sacrifice
        address[] memory sacrificeTokens = new address[](4);
        sacrificeTokens[0] = hexToken;
        sacrificeTokens[1] = daiToken;
        sacrificeTokens[2] = wplsToken;
        sacrificeTokens[3] = plsxToken;

        // create an array with the corresponding multiplier for each sacrifice token
        uint16[] memory multipliers = new uint16[](4);
        multipliers[0] = 55555;
        multipliers[1] = 30000;
        multipliers[2] = 20000;
        multipliers[3] = 10000;

        bootstrap.setBaseData(address(feed), address(staking), address(vault));

        // set the sacrifice tokens with the corresponding multipliers
        bootstrap.setSacrificeTokens(sacrificeTokens, multipliers);

        // set the sacrifice start timestamp
        bootstrap.setSacrificeStart(block.timestamp);

        // set the vault base data
        vault.setBaseData(address(aggregator), address(staking), address(bootstrap));

        // create an HEX1/DAI pair
        hexOneDaiPair = IPulseXFactory(pulseXFactory).getPair(address(hex1), daiToken);
        if (hexOneDaiPair == address(0)) {
            hexOneDaiPair = IPulseXFactory(pulseXFactory).createPair(address(hex1), daiToken);
        }

        // prepare the allowed staking tokens
        address[] memory stakeTokens = new address[](3);
        stakeTokens[0] = hexOneDaiPair;
        stakeTokens[1] = address(hex1);
        stakeTokens[2] = address(hexit);

        // prepare the distribution weights for each stake token
        uint16[] memory weights = new uint16[](3);
        weights[0] = 7000;
        weights[1] = 2000;
        weights[2] = 1000;

        // set the allowed staking tokens and distribution weights
        staking.setStakeTokens(stakeTokens, weights);

        // stop impersonating the deployer
        vm.stopPrank();
    }
}
