// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import "../Base.t.sol";

/**
 *  @dev forge test --match-contract HexOneTokenTest--rpc-url "https://rpc.pulsechain.com" -vvv
 */
contract HexOneTokenTest is Base {
    address public user = makeAddr("user");

    function test_setHexOneProtocol() public {
        hex1.setHexOneProtocol(address(protocol));
        assertEq(hex1.hexOneProtocol(), address(protocol));
    }

    function test_setHexOneProtocol_revertIfNotOwner() public {
        vm.startPrank(user);
        vm.expectRevert();
        hex1.setHexOneProtocol(address(protocol));
        vm.stopPrank();
    }

    function test_setHexOneProtocol_revertIfInvalidAddress() public {
        vm.expectRevert(IHexOneToken.InvalidAddress.selector);
        hex1.setHexOneProtocol(address(0));
    }

    function test_mint() public {
        vm.startPrank(address(protocol));
        hex1.mint(user, 1e18);
        vm.stopPrank();
        assertEq(hex1.balanceOf(user), 1e18);
    }

    function test_mint_revertIfNotProtocol() public {
        vm.startPrank(user);
        vm.expectRevert(IHexOneToken.NotHexOneProtocol.selector);
        hex1.mint(user, 1e18);
        vm.stopPrank();
    }

    function test_burn() public {
        test_mint();
        vm.startPrank(address(protocol));
        hex1.burn(user, 1e18);
        vm.stopPrank();
        assertEq(hex1.balanceOf(user), 0);
    }

    function test_burn_revertIfNotProtocol() public {
        test_mint();
        vm.startPrank(user);
        vm.expectRevert(IHexOneToken.NotHexOneProtocol.selector);
        hex1.burn(user, 1e18);
        vm.stopPrank();
    }
}
