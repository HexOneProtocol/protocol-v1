// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {BaseScript} from "../Base.s.sol";

import {HexOneBootstrap} from "../../src/HexOneBootstrap.sol";

contract SacrificeStartScript is BaseScript {
    // TODO: change address
    HexOneBootstrap internal immutable bootstrap = HexOneBootstrap(0x77AD263Cd578045105FBFC88A477CAd808d39Cf6);

    function run() external broadcast {
        // TODO: change the timestamp
        bootstrap.setSacrificeStart(block.timestamp);
    }
}
