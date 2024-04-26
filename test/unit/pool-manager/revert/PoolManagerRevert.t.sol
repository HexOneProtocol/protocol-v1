// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../Base.t.sol";

contract PoolManagerRevert is Base {
    /**
     *  @dev test that an `_account` without owner permissions can call.
     */
    function test_createPools_revert_AccessControlUnauthorizedAccount(address _account, uint256 _rewardPerToken)
        external
        prank(_account)
    {
        vm.assume(_account != address(0) && _account != owner);
        vm.assume(_rewardPerToken != 0);

        ERC20Mock mock = new ERC20Mock("mock token", "MC");

        address[] memory tokens = new address[](1);
        tokens[0] = address(mock);

        uint256[] memory rewardsPerToken = new uint256[](1);
        rewardsPerToken[0] = _rewardPerToken;

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, _account, manager.OWNER_ROLE()
            )
        );
        manager.createPools(tokens, rewardsPerToken);
    }

    /**
     *  @dev test that an empty array can not be used as input.
     */
    function test_createPools_revert_EmptyArray() external prank(owner) {
        address[] memory tokens = new address[](0);
        uint256[] memory rewardsPerToken = new uint256[](1);

        vm.expectRevert(IHexOnePoolManager.EmptyArray.selector);
        manager.createPools(tokens, rewardsPerToken);
    }

    /**
     *  @dev test that arrays with different lengths can not be used as input.
     */
    function test_createPools_revert_MismatchedArray(uint256 _rewardPerToken) external prank(owner) {
        vm.assume(_rewardPerToken != 0);

        ERC20Mock mock = new ERC20Mock("mock token", "MC");

        address[] memory tokens = new address[](1);
        tokens[0] = address(mock);

        uint256[] memory rewardsPerToken = new uint256[](0);

        vm.expectRevert(IHexOnePoolManager.MismatchedArray.selector);
        manager.createPools(tokens, rewardsPerToken);
    }

    /**
     *  @dev test that an `_account` without owner permissions can not call.
     */
    function test_createPool_revert_AccessControlUnauthorizedAccount(address _account, uint256 _rewardPerToken)
        external
        prank(_account)
    {
        vm.assume(_account != address(0) && _account != owner);
        vm.assume(_rewardPerToken != 0);

        ERC20Mock mock = new ERC20Mock("mock token", "MC");

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, _account, manager.OWNER_ROLE()
            )
        );
        manager.createPool(address(mock), _rewardPerToken);
    }

    /**
     *  @dev test that stake token can not be address(0).
     */
    function test_createPool_revert_ZeroAddress(uint256 _rewardPerToken) external prank(owner) {
        vm.assume(_rewardPerToken != 0);

        vm.expectRevert(IHexOnePoolManager.ZeroAddress.selector);
        manager.createPool(address(0), _rewardPerToken);
    }

    /**
     *  @dev test that the reward per token can not be zero.
     */
    function test_createPool_revert_InvalidRewardPerToken() external prank(owner) {
        ERC20Mock mock = new ERC20Mock("mock token", "MC");

        vm.expectRevert(IHexOnePoolManager.InvalidRewardPerToken.selector);
        manager.createPool(address(mock), 0);
    }

    /**
     *  @dev test that the same pool can not be deployed twice.
     */
    function test_createPool_revert_DeploymentFailed(uint256 _rewardPerToken) external prank(owner) {
        vm.assume(_rewardPerToken != 0);

        ERC20Mock mock = new ERC20Mock("mock token", "MC");

        manager.createPool(address(mock), _rewardPerToken);

        vm.expectRevert(IHexOnePoolManager.DeploymentFailed.selector);
        manager.createPool(address(mock), _rewardPerToken);
    }
}
