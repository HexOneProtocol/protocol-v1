// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, stdError, console} from "../../lib/forge-std/src/Test.sol";

import {HexitToken} from "../../src/HexitToken.sol";
import {HexOneToken} from "../../src/HexOneToken.sol";
import {HexOnePriceFeed} from "../../src/HexOnePriceFeed.sol";
import {HexOneVault} from "../../src/HexOneVault.sol";

import {IHexitToken} from "../../src/interfaces/IHexitToken.sol";
import {IHexOneToken} from "../../src/interfaces/IHexOneToken.sol";
import {IHexOnePriceFeed} from "../../src/interfaces/IHexOnePriceFeed.sol";

import {IPulseXFactory} from "../../src/interfaces/pulsex/IPulseXFactory.sol";
import {IPulseXPair} from "../../src/interfaces/pulsex/IPulseXPair.sol";
import {IPulseXRouter02 as IPulseXRouter} from "../../src/interfaces/pulsex/IPulseXRouter.sol";
import {IHexToken} from "../../src/interfaces/IHexToken.sol";
import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract Base is Test {
    HexitToken internal hexit;
    HexOnePriceFeed internal feed;
    HexOneVault internal vault;

    address internal constant PULSEX_FACTORY_V1 = 0x1715a3E4A142d8b698131108995174F37aEBA10D;
    address internal constant PULSEX_FACTORY_V2 = 0x29eA7545DEf87022BAdc76323F373EA1e707C523;

    address internal constant PULSEX_ROUTER_V1 = 0x98bf93ebf5c380C0e6Ae8e192A7e2AE08edAcc02;
    address internal constant PULSEX_ROUTER_V2 = 0x165C3410fC91EF562C50559f7d2289fEbed552d9;

    address internal constant HEX_TOKEN = 0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39;
    address internal constant HDRN_TOKEN = 0x3819f64f282bf135d62168C1e513280dAF905e06;
    address internal constant WPLS_TOKEN = 0xA1077a294dDE1B09bB078844df40758a5D0f9a27;
    address internal constant PLSX_TOKEN = 0x95B303987A60C71504D99Aa1b13B4DA07b0790ab;
    address internal constant DAI_TOKEN = 0xefD766cCb38EaF1dfd701853BFCe31359239F305;
    address internal constant USDC_TOKEN = 0x15D38573d2feeb82e7ad5187aB8c1D52810B1f07;
    address internal constant USDT_TOKEN = 0x0Cb6F5a34ad42ec934882A05265A7d5F59b51A2f;

    address internal owner = makeAddr("owner");
    address internal bootstrap = makeAddr("bootstrap");

    modifier prank(address _account) {
        vm.startPrank(_account);
        _;
        vm.stopPrank();
    }

    function setUp() public virtual prank(owner) {
        vm.createSelectFork("https://rpc.pulsechain.com", 20194011);

        _deploy();

        _configure();
    }

    function _deploy() private {
        hexit = new HexitToken();
        feed = new HexOnePriceFeed(address(hexit), 300);
        vault = new HexOneVault(address(feed));
    }

    function _configure() private {
        // HEX/DAI path
        address[] memory hexDaiPath = new address[](3);
        hexDaiPath[0] = HEX_TOKEN;
        hexDaiPath[1] = WPLS_TOKEN;
        hexDaiPath[2] = DAI_TOKEN;
        feed.addPath(hexDaiPath);

        // HEX/USDC path
        address[] memory hexUsdcPath = new address[](3);
        hexUsdcPath[0] = HEX_TOKEN;
        hexUsdcPath[1] = WPLS_TOKEN;
        hexUsdcPath[2] = USDC_TOKEN;
        feed.addPath(hexUsdcPath);

        // HEX/USDT path
        address[] memory hexUsdtPath = new address[](3);
        hexUsdtPath[0] = HEX_TOKEN;
        hexUsdtPath[1] = WPLS_TOKEN;
        hexUsdtPath[2] = USDT_TOKEN;
        feed.addPath(hexUsdtPath);

        hexit.initFeed(address(feed));
    }
}
