// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {BaseScript} from "../Base.s.sol";

import {HexOneBootstrap} from "../../src/HexOneBootstrap.sol";

contract SacrificeStartScript is BaseScript {
    // IHexOneBootstrap internal immutable bootstrap = IHexOneBootstrap(bootstrap);
    HexOneBootstrap internal immutable bootstrap = HexOneBootstrap(0x77AD263Cd578045105FBFC88A477CAd808d39Cf6);

    function run() external broadcast {
        // bootstrap.setSacrificeStart(block.timestamp + 7 days);
        bootstrap.setSacrificeStart(block.timestamp);
    }
}
