// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import "../../Base.t.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract VaultAccessControlTest is Base {
    /*//////////////////////////////////////////////////////////////////////////
                                SET SACRIFICE STATUS
    //////////////////////////////////////////////////////////////////////////*/

    function test_revert_setSacrificeStatus_NotHexOneBootstrap() public {
        vm.startPrank(user);

        vm.expectRevert(abi.encodeWithSelector(IHexOneVault.NotHexOneBootstrap.selector, user));
        vault.setSacrificeStatus();

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                SET BASE DATA
    //////////////////////////////////////////////////////////////////////////*/

    function test_revert_setBaseData_OwnableUnauthorizedAccount() public {
        address mockFeed = makeAddr("mock feed");
        address mockStaking = makeAddr("mock staking");
        address mockBootstrap = makeAddr("mock bootstrap");

        vm.startPrank(user);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        vault.setBaseData(mockFeed, mockStaking, mockBootstrap);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                DELEGATE DEPOSIT
    //////////////////////////////////////////////////////////////////////////*/

    function test_revert_delegateDeposit_NotHexOneBootstrap() public {
        // deposits in the vault are only enabled after the sacrifice phase is finished, so to test
        // that only the bootstrap can call the vault sacrifice status must be set to true.
        vm.prank(bootstrap);
        vault.setSacrificeStatus();

        // try to create a delegate deposit, should revert since only the bootstrap can create
        // delegate deposits
        vm.startPrank(user);

        vm.expectRevert(abi.encodeWithSelector(IHexOneVault.NotHexOneBootstrap.selector, user));
        vault.delegateDeposit(attacker, 100 * 1e8, 5555);

        vm.stopPrank();
    }
}
