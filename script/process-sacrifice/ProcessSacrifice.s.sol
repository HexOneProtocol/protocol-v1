// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import {Base} from "../Base.s.sol";

import {HexOneBootstrap} from "../../src/HexOneBootstrap.sol";

contract ProcessSacrificeScript is Base {
    HexOneBootstrap internal immutable bootstrap = HexOneBootstrap(0xd165DFeF31B47d233da312B590a67E038b981D02);

    function run() external broadcast {
        bootstrap.processSacrifice(1);
    }
}
