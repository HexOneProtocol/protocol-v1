// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import {Base} from "../Base.s.sol";

import {HexOneBootstrap} from "../../src/HexOneBootstrap.sol";

contract StartAirdropScript is Base {
    HexOneBootstrap internal immutable bootstrap = HexOneBootstrap(0x4f4Bbe6Be6Ec33aD7cEe686F2d5d11cD06cF8CE5);

    function run() external broadcast {
        bootstrap.startAirdrop(uint64(block.timestamp + 20));
    }
}
