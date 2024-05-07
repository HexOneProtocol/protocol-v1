// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../Base.t.sol";

contract HexOneRevert is Base {
    function test_mint_revert_AccessControlUnauthorizedAccount(address _account) external {
        vm.assume(_account != address(0) && _account != owner);

        vm.startPrank(_account);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, _account, hex1.VAULT_ROLE()
            )
        );
        hex1.mint(_account, 0);

        vm.stopPrank();
    }

    function test_burn_revert_AccessControlUnauthorizedAccount(address _account) external {
        vm.assume(_account != address(0) && _account != owner);

        vm.startPrank(_account);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, _account, hex1.VAULT_ROLE()
            )
        );
        hex1.burn(_account, 0);

        vm.stopPrank();
    }
}
