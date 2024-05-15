// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../Base.s.sol";

import {HexitToken} from "../../src/HexitToken.sol";
import {HexOnePriceFeed} from "../../src/HexOnePriceFeed.sol";

contract KeeperScript is Base {
    HexitToken internal hexit;
    HexOnePriceFeed internal feed;

    function run() external {
        _deploy();
        _configure();
        _log();
    }

    function _deploy() internal broadcast {
        hexit = new HexitToken();
        feed = new HexOnePriceFeed(address(hexit), 500);
    }

    function _configure() internal broadcast {
        hexit.initFeed(address(feed));

        address[] memory hexDaiPath = new address[](3);
        hexDaiPath[0] = HEX_TOKEN;
        hexDaiPath[1] = WPLS_TOKEN;
        hexDaiPath[2] = DAI_TOKEN;
        feed.addPath(hexDaiPath);

        address[] memory hexUsdcPath = new address[](3);
        hexUsdcPath[0] = HEX_TOKEN;
        hexUsdcPath[1] = WPLS_TOKEN;
        hexUsdcPath[2] = USDC_TOKEN;
        feed.addPath(hexUsdcPath);

        address[] memory hexUsdtPath = new address[](3);
        hexUsdtPath[0] = HEX_TOKEN;
        hexUsdtPath[1] = WPLS_TOKEN;
        hexUsdtPath[2] = USDT_TOKEN;
        feed.addPath(hexUsdtPath);
    }

    function _log() internal view {
        console.log("hexit token   : ", address(hexit));
        console.log("price feed    : ", address(feed));
    }
}
