// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script, console} from "../lib/forge-std/src/Script.sol";

abstract contract Base is Script {
    // pulsex factory
    address internal constant PULSEX_FACTORY_V1 = 0x1715a3E4A142d8b698131108995174F37aEBA10D;
    address internal constant PULSEX_FACTORY_V2 = 0x29eA7545DEf87022BAdc76323F373EA1e707C523;

    // pulsex router
    address internal constant PULSEX_ROUTER_V1 = 0x98bf93ebf5c380C0e6Ae8e192A7e2AE08edAcc02;
    address internal constant PULSEX_ROUTER_V2 = 0x165C3410fC91EF562C50559f7d2289fEbed552d9;

    // tokens
    address internal constant HEX_TOKEN = 0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39;
    address internal constant HDRN_TOKEN = 0x3819f64f282bf135d62168C1e513280dAF905e06;
    address internal constant WPLS_TOKEN = 0xA1077a294dDE1B09bB078844df40758a5D0f9a27;
    address internal constant PLSX_TOKEN = 0x95B303987A60C71504D99Aa1b13B4DA07b0790ab;
    address internal constant DAI_TOKEN = 0xefD766cCb38EaF1dfd701853BFCe31359239F305;
    address internal constant USDC_TOKEN = 0x15D38573d2feeb82e7ad5187aB8c1D52810B1f07;
    address internal constant USDT_TOKEN = 0x0Cb6F5a34ad42ec934882A05265A7d5F59b51A2f;

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
