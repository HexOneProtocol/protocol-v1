// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";

abstract contract BaseScript is Script {
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
    uint16 internal constant DAI_SACRIFICE_MULTIPLIER = 55555;
    uint16 internal constant WPLS_SACRIFICE_MULTIPLIER = 55555;
    uint16 internal constant PLSX_SACRIFICE_MULTIPLIER = 55555;

    uint256 internal deployerPrivateKey;

    constructor() {
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    }

    modifier broadcast() {
        vm.startBroadcast(deployerPrivateKey);
        _;
        vm.stopBroadcast();
    }
}
