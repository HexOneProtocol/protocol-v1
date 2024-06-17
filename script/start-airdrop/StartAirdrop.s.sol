// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import {Base} from "../Base.s.sol";

import {HexOneBootstrap} from "../../src/HexOneBootstrap.sol";

contract StartAirdropScript is Base {
    HexOneBootstrap internal immutable bootstrap = HexOneBootstrap(0x8a83de108199009e1D11175E3f98753B47e424f2);

    function run() external broadcast {
        bootstrap.startAirdrop(uint64(block.timestamp + 1 minutes));
    }
}
