// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import {Base} from "../Base.s.sol";

import {HexOneBootstrap} from "../../src/HexOneBootstrap.sol";

contract StartAirdropScript is Base {
    HexOneBootstrap internal immutable bootstrap = HexOneBootstrap(0xb588Bc6453C10e70035dD289D15A7DAd6Ae36B33);

    function run() external broadcast {
        bootstrap.startAirdrop(uint64(block.timestamp + 1 minutes));
    }
}
