// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import "../Base.t.sol";

/**
 *  @dev forge test --match-contract HexitTokenTest --rpc-url "https://rpc.pulsechain.com" -vvv
 */
contract HexitTokenTest is Base {
    address public user = makeAddr("user");

    function test_setHexOneBootstrap() public {
        hexit.setHexOneBootstrap(address(bootstrap));
        assertEq(hexit.hexOneBootstrap(), address(bootstrap));
    }

    function test_setHexOneBootstrap_revertIfNotOwner() public {
        vm.startPrank(user);
        vm.expectRevert();
        hexit.setHexOneBootstrap(address(bootstrap));
        vm.stopPrank();
    }

    function test_setHexOneBootstrap_revertIfInvalidAddress() public {
        vm.expectRevert(IHexitToken.InvalidAddress.selector);
        hexit.setHexOneBootstrap(address(0));
    }

    function test_mint() public {
        vm.startPrank(address(bootstrap));
        hexit.mint(user, 1e18);
        vm.stopPrank();
        assertEq(hexit.balanceOf(user), 1e18);
    }

    function test_mint_revertIfNotBootstrap() public {
        vm.startPrank(user);
        vm.expectRevert(IHexitToken.NotHexOneBootstrap.selector);
        hexit.mint(user, 1e18);
        vm.stopPrank();
    }
}
