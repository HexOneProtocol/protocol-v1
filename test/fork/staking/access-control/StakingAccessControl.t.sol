// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import "../../Base.t.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 *  @dev forge test --match-contract StakingAccessControlTest -vvv
 */
contract StakingAccessControlTest is Base {
    /*//////////////////////////////////////////////////////////////////////////
                                    SET BASE DATA
    //////////////////////////////////////////////////////////////////////////*/

    function test_revert_setBaseData_OwnableUnauthorizedAccount() public {
        address mockVault = makeAddr("vault");
        address mockBootstrap = makeAddr("bootstrap");

        vm.startPrank(user);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        staking.setBaseData(mockVault, mockBootstrap);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    ENABLE STAKING
    //////////////////////////////////////////////////////////////////////////*/

    function test_revert_enableStaking_OwnableUnauthorizedAccount() public {
        vm.startPrank(user);

        vm.expectRevert(abi.encodeWithSelector(IHexOneStaking.NotHexOneBootstrap.selector, user));
        staking.enableStaking();

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    SET STAKE TOKENS
    //////////////////////////////////////////////////////////////////////////*/

    function test_revert_setStakeTokens_OwnableUnauthorizedAccount() public {
        address[] memory tokens = new address[](3);
        uint16[] memory weights = new uint16[](3);

        vm.startPrank(user);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        staking.setStakeTokens(tokens, weights);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    PURCHASE
    //////////////////////////////////////////////////////////////////////////*/

    function test_revert_purchase_NotHexOneVault() public {
        vm.startPrank(user);

        vm.expectRevert(abi.encodeWithSelector(IHexOneStaking.NotHexOneVault.selector, user));
        staking.purchase(hexToken, 1000);

        vm.stopPrank();
    }

    function test_revert_purchase_NotHexOneBootstrap() public {
        vm.startPrank(user);

        vm.expectRevert(abi.encodeWithSelector(IHexOneStaking.NotHexOneBootstrap.selector, user));
        staking.purchase(address(hexit), 1000);

        vm.stopPrank();
    }
}
