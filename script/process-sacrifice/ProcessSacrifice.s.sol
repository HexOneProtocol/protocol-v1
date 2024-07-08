// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import {Base} from "../Base.s.sol";

import {HexOneBootstrap} from "../../src/HexOneBootstrap.sol";
import {UniswapV2Library} from "../../src/libraries/UniswapV2Library.sol";

import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IPulseXFactory} from "../../src/interfaces/pulsex/IPulseXFactory.sol";
import {IPulseXRouter01 as IPulseXRouter} from "../../src/interfaces/pulsex/IPulseXRouter.sol";

contract ProcessSacrificeScript is Base {
    HexOneBootstrap internal immutable bootstrap = HexOneBootstrap(0x9636f5103Ce5c86b5167a48bd3D5C89bb4F857F8);

    address internal immutable hex1 = 0x298978f9B59A4BF9c08C114Fb6848fade7Be7E18;
    address internal immutable hexit = 0x8d4D6aa8339dB0252dc92957544fe6931e0826Db;

    function run() external broadcast {
        // get the amount out min of dai tokens the protocol wants to receive
        (, uint256 sacrificedHx,,) = bootstrap.sacrificeInfo();
        uint256 hexToSwap = (sacrificedHx * 1250) / 10000;

        address[] memory path = new address[](2);
        path[0] = HEX_TOKEN;
        path[1] = DAI_TOKEN;
        uint256[] memory amounts = UniswapV2Library.getAmountsOut(PULSEX_FACTORY_V1, hexToSwap, path);

        // process the sacrifice
        bootstrap.processSacrifice(amounts[1]);

        // claim the sacrificed hex tokens
        (, uint256 hex1Minted, uint256 hexitMinted) = bootstrap.claimSacrifice();

        // create HEX1/HEXIT pair on pulsex v2
        address pair = IPulseXFactory(PULSEX_FACTORY_V2).getPair(hex1, hexit);
        if (pair == address(0)) {
            pair = IPulseXFactory(PULSEX_FACTORY_V2).createPair(hex1, hexit);
        }

        // deposit liquidity in the HEX1/HEXIT pair on pulsex v2
        IERC20(hex1).approve(PULSEX_ROUTER_V2, hex1Minted);
        IERC20(hexit).approve(PULSEX_ROUTER_V2, hexitMinted);
        IPulseXRouter(PULSEX_ROUTER_V2).addLiquidity(
            hex1, hexit, hex1Minted, hexitMinted, hex1Minted, hexitMinted, address(0), block.timestamp + 100
        );
    }
}
