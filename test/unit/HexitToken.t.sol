// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {HexitToken} from "../../src/HexitToken.sol";

contract HexitTokenTest is Test {
    HexitToken public hexitToken;

    address public user = makeAddr("user");

    function setUp() public {
        hexitToken = new HexitToken("Hexit Token", "HEXIT");
    }

    function test_setBootstrap() public {
        address bootstrap = makeAddr("bootstrap");
        hexitToken.setBootstrap(bootstrap);
        assertEq(hexitToken.hexOneBootstrap(), bootstrap);
    }

    function test_setBootstrap_revertIfNotOwner() public {}
}
