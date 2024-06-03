// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import {Base} from "../Base.s.sol";

import {HexOneBootstrap} from "../../src/HexOneBootstrap.sol";

contract StartAirdropScript is Base {
    HexOneBootstrap internal immutable bootstrap = HexOneBootstrap(0xFB51fe59bfE7a1C05F65e7cc6173Ab605D2Bc2f4);

    function run() external broadcast {
        bootstrap.startAirdrop(uint64(block.timestamp + 1 minutes));
    }
}
