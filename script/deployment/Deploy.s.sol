// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../Base.s.sol";

import {HexitToken} from "../../src/HexitToken.sol";
import {HexOnePriceFeed} from "../../src/HexOnePriceFeed.sol";
import {HexOneBootstrap} from "../../src/HexOneBootstrap.sol";
import {HexOneVault} from "../../src/HexOneVault.sol";
import {HexOnePoolManager} from "../../src/HexOnePoolManager.sol";

import {IPulseXFactory} from "../../src/interfaces/pulsex/IPulseXFactory.sol";

contract DeployScript is Base {
    HexitToken internal hexit;
    HexOnePriceFeed internal feed;
    HexOneBootstrap internal bootstrap;
    HexOneVault internal vault;
    HexOnePoolManager internal manager;

    address internal hex1;
    address internal hex1Dai;
    address internal hexitHex1;

    function run() external {
        _deploy();
        _configure();
        _display();
    }

    function _deploy() internal broadcast {
        hexit = new HexitToken();
        feed = new HexOnePriceFeed(address(hexit), 500);

        address[] memory sacrificeTokens = new address[](4);
        sacrificeTokens[0] = HEX_TOKEN;
        sacrificeTokens[1] = DAI_TOKEN;
        sacrificeTokens[2] = WPLS_TOKEN;
        sacrificeTokens[3] = PLSX_TOKEN;

        uint64 sacrificeStart = uint64(block.timestamp + 1 minutes);

        bootstrap = new HexOneBootstrap(sacrificeStart, address(feed), address(hexit), sacrificeTokens);
        vault = new HexOneVault(address(feed), address(bootstrap));
        hex1 = vault.hex1();
        manager = new HexOnePoolManager(address(hexit));
    }

    function _configure() internal broadcast {
        // configure hexit
        hexit.initFeed(address(feed));
        hexit.initBootstrap(address(bootstrap));
        hexit.initManager(address(manager));

        // configure feed
        // HEX/DAI
        address[] memory hexDaiPath = new address[](3);
        hexDaiPath[0] = HEX_TOKEN;
        hexDaiPath[1] = WPLS_TOKEN;
        hexDaiPath[2] = DAI_TOKEN;
        feed.addPath(hexDaiPath);

        // HEX/USDC
        address[] memory hexUsdcPath = new address[](3);
        hexUsdcPath[0] = HEX_TOKEN;
        hexUsdcPath[1] = WPLS_TOKEN;
        hexUsdcPath[2] = USDC_TOKEN;
        feed.addPath(hexUsdcPath);

        // HEX/USDT
        address[] memory hexUsdtPath = new address[](3);
        hexUsdtPath[0] = HEX_TOKEN;
        hexUsdtPath[1] = WPLS_TOKEN;
        hexUsdtPath[2] = USDT_TOKEN;
        feed.addPath(hexUsdtPath);

        // WPLS/DAI path
        address[] memory wplsDaiPath = new address[](2);
        wplsDaiPath[0] = WPLS_TOKEN;
        wplsDaiPath[1] = DAI_TOKEN;
        feed.addPath(wplsDaiPath);

        // PLSX/DAI path
        address[] memory plsxDaiPath = new address[](2);
        plsxDaiPath[0] = PLSX_TOKEN;
        plsxDaiPath[1] = DAI_TOKEN;
        feed.addPath(plsxDaiPath);

        // configure bootstrap
        bootstrap.initVault(address(vault));

        // create HEX1/DAI and HEXIT/HEX1 pairs in pulsex v2
        hex1Dai = IPulseXFactory(PULSEX_FACTORY_V2).createPair(hex1, DAI_TOKEN);
        hexitHex1 = IPulseXFactory(PULSEX_FACTORY_V2).createPair(address(hexit), hex1);

        // deploy HEX1/DAI and HEXIT pools
        address[] memory tokens = new address[](2);
        tokens[0] = address(hex1Dai);
        tokens[1] = address(hexit);

        uint256[] memory rewardsPerToken = new uint256[](2);
        rewardsPerToken[0] = 420e18;
        rewardsPerToken[1] = 69e18;

        manager.createPools(tokens, rewardsPerToken);
    }

    function _display() internal view {
        console.log("hexit token   : ", address(hexit));
        console.log("price feed    : ", address(feed));
        console.log("bootstrap     : ", address(bootstrap));
        console.log("vault         : ", address(vault));
        console.log("hex one token : ", hex1);
        console.log("manager       : ", address(manager));
        console.log("HEX1/DAI pool : ", manager.pools(0));
        console.log("HEXIT pool    : ", manager.pools(1));
    }
}
