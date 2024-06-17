// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import {Base} from "../Base.s.sol";

import {HexOneBootstrap} from "../../src/HexOneBootstrap.sol";

import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract SacrificeScript is Base {
    HexOneBootstrap internal immutable bootstrap = HexOneBootstrap(0xbd6eF940394178656Ec2671D25E2ba3A3BF5d84F);

    function run() external broadcast {
        // deployer sacrifices hex tokens to latter create HEX1/HEXIT pair on pulsex v2
        IERC20(HEX_TOKEN).approve(address(bootstrap), 200e8);
        bootstrap.sacrifice(HEX_TOKEN, 200e8, 1);
    }
}
