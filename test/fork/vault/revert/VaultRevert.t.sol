// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../Base.t.sol";

contract VaultRevert is Base {
    function test_enableBuyback_revert_AccessControlUnauthorizedAccount() external {}

    function test_deposit_revert_InvalidAmount() external {}

    function test_withdraw_revert_InvalidOwner() external {}

    function test_liquidate_revert_StakeNotLiquidatable() external {}

    function test_repay_revert_InvalidOwner() external {}

    function test_repay_revert_InvalidAmount() external {}

    function test_borrow_revert_InvalidOwner() external {}

    function test_borrow_revert_InvalidAmount() external {}

    function test_borrow_revert_StakeMature() external {}

    function test_borrow_revert_MaxBorrowExceeded() external {}

    function test_borrow_revert_HealthRatioTooLow() external {}

    function test_take_revert_RatioHealthy() external {}

    function test_take_revert_StakeNotLiquidatable() external {}

    function test_take_revert_HealthRatioTooLow() external {}
}
