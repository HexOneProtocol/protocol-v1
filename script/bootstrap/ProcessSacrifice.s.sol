// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {BaseScript} from "../Base.s.sol";

import {HexOneBootstrap} from "../../src/HexOneBootstrap.sol";
import {UniswapV2Library} from "../../src/libraries/UniswapV2Library.sol";

contract ProcessSacrificeScript is BaseScript {
    // TODO: change address
    HexOneBootstrap internal immutable bootstrap = HexOneBootstrap(0x77AD263Cd578045105FBFC88A477CAd808d39Cf6);

    function run() external broadcast {
        uint256 hexToSwap = (bootstrap.totalHexAmount() * 1250) / 10000;

        address[] memory path = new address[](2);
        path[0] = HEX_TOKEN;
        path[1] = DAI_TOKEN;
        uint256[] memory amounts = UniswapV2Library.getAmountsOut(PULSEX_FACTORY, hexToSwap, path);

        bootstrap.processSacrifice(amounts[1]);
    }
}
