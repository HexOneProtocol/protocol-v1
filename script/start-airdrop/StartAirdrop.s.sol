// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import {Base} from "../Base.s.sol";

import {HexOneBootstrap} from "../../src/HexOneBootstrap.sol";

contract StartAirdropScript is Base {
    HexOneBootstrap internal immutable bootstrap = HexOneBootstrap(0x9636f5103Ce5c86b5167a48bd3D5C89bb4F857F8);

    function run() external broadcast {
        bootstrap.startAirdrop(uint64(block.timestamp + 1 minutes));
    }
}
