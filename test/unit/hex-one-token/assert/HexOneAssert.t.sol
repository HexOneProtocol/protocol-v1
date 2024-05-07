// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../Base.t.sol";

contract HexOneAssert is Base {
    uint256 internal constant MAX_HEX_ONE = 100_000_000e18;

    function test_constructor() external {
        assertEq(hex1.hasRole(hex1.VAULT_ROLE(), owner), true);
    }

    function test_mint(address _account, uint256 _amount) external {
        vm.assume(_account != address(0) && _account != owner);
        _amount = bound(_amount, 1, MAX_HEX_ONE);

        vm.startPrank(owner);
        hex1.mint(_account, _amount);
        vm.stopPrank();

        assertEq(hex1.balanceOf(_account), _amount);
    }

    function test_burn(address _account, uint256 _amount) external {
        vm.assume(_account != address(0) && _account != owner);
        _amount = bound(_amount, 1, MAX_HEX_ONE);

        vm.startPrank(owner);
        hex1.mint(_account, _amount);

        assertEq(hex1.balanceOf(_account), _amount);

        hex1.burn(_account, _amount);

        assertEq(hex1.balanceOf(_account), 0);

        vm.stopPrank();
    }
}
