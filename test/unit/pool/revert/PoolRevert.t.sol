// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../Base.t.sol";

contract PoolRevert is Base {
    /**
     *  @dev test that the pool can only initialized by the manager.
     */
    function test_initialize_revert_AccessControlUnauthorizedAccount(address _account, uint256 _rewardPerToken)
        external
        prank(_account)
    {
        vm.assume(_account != address(0) && _account != address(manager));
        vm.assume(_rewardPerToken != 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, _account, pools[0].MANAGER_ROLE()
            )
        );
        pools[0].initialize(_rewardPerToken);
    }

    /**
     *  @dev test that zero amount of token can not be staked.
     */
    function test_stake_revert_ZeroAmount(address _account) external prank(_account) {
        vm.assume(_account != address(0));

        vm.expectRevert(IHexOnePool.ZeroAmount.selector);
        pools[0].stake(0);
    }

    /**
     *  @dev test that zero amount of token can not be unstaked.
     */
    function test_unstake_revert_ZeroAmount(address _account) external prank(_account) {
        vm.assume(_account != address(0));

        vm.expectRevert(IHexOnePool.ZeroAmount.selector);
        pools[0].unstake(0);
    }

    /**
     *  @dev test that an `_account` can not unstake more than what it has deposited.
     */
    function test_unstake_revert_ArithmeticError(address _account, uint256 _amount) external {
        vm.assume(_account != address(0));
        vm.assume(_amount != 0);

        vm.expectRevert(stdError.arithmeticError);
        pools[0].unstake(_amount);
    }

    /**
     *  @dev test that an `_account` can not unstake zero amount.
     */
    function test_exit_revert_ZeroAmount(address _account) external prank(_account) {
        vm.assume(_account != address(0));

        vm.expectRevert(IHexOnePool.ZeroAmount.selector);
        pools[0].exit();
    }
}