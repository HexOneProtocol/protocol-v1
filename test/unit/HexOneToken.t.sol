// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import "../Base.t.sol";

/**
 *  @dev forge test --match-contract HexOneTokenTest --rpc-url "https://rpc.pulsechain.com" -vvv
 */
contract HexOneTokenTest is Base {
    address public user = makeAddr("user");

    function test_setHexOneVault() public {
        hex1.setHexOneVault(address(vault));
        assertEq(hex1.hexOneVault(), address(vault));
    }

    function test_setHexOneVault_revertIfNotOwner() public {
        vm.startPrank(user);
        vm.expectRevert();
        hex1.setHexOneVault(address(vault));
        vm.stopPrank();
    }

    function test_setHexOneVault_revertIfInvalidAddress() public {
        vm.expectRevert(IHexOneToken.InvalidAddress.selector);
        hex1.setHexOneVault(address(0));
    }

    function test_mint() public {
        vm.startPrank(address(vault));
        hex1.mint(user, 1e18);
        vm.stopPrank();
        assertEq(hex1.balanceOf(user), 1e18);
    }

    function test_mint_revertIfNotVault() public {
        vm.startPrank(user);
        vm.expectRevert(IHexOneToken.NotHexOneVault.selector);
        hex1.mint(user, 1e18);
        vm.stopPrank();
    }

    function test_burn() public {
        test_mint();
        vm.startPrank(address(vault));
        hex1.burn(user, 1e18);
        vm.stopPrank();
        assertEq(hex1.balanceOf(user), 0);
    }

    function test_burn_revertIfNotVault() public {
        test_mint();
        vm.startPrank(user);
        vm.expectRevert(IHexOneToken.NotHexOneVault.selector);
        hex1.burn(user, 1e18);
        vm.stopPrank();
    }
}
