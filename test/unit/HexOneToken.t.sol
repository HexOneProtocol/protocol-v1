// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {HexOneToken} from "../../src/HexOneToken.sol";

contract HexOneTokenTest is Test {
    HexOneToken public hexOneToken;

    function setUp() public {
        hexOneToken = new HexOneToken("Hex One Token", "HEX1");
    }
}
