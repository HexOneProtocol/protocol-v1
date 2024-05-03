// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../Base.t.sol";

contract PoolAssert is Base {
    uint256 internal constant MAX_STAKE = 1e36;
    uint256 internal constant MAX_TIME_STAKED = 3652 days;

    function test_initialize(uint256 _rewardPerToken) external prank(address(manager)) {
        vm.assume(_rewardPerToken != 0);

        pools[0].initialize(_rewardPerToken);

        assertEq(pools[0].rewardPerToken(), _rewardPerToken);
    }

    function test_stake(address _account, uint256 _amount) external prank(_account) {
        vm.assume(_account != address(0) && _account != address(pools[0]));
        _amount = bound(_amount, 1, MAX_STAKE);

        deal(address(hex1dai), _account, _amount);

        hex1dai.approve(address(pools[0]), _amount);
        pools[0].stake(_amount);

        assertEq(pools[0].stakeOf(_account), _amount);
        assertEq(pools[0].totalStaked(), _amount);
        assertEq(hex1dai.balanceOf(_account), 0);
        assertEq(hex1dai.balanceOf(address(pools[0])), _amount);
    }

    function test_unstake(address _account, uint256 _amount) external prank(_account) {
        vm.assume(_account != address(0) && _account != address(pools[0]));
        _amount = bound(_amount, 1, MAX_STAKE);

        deal(address(hex1dai), _account, _amount);

        hex1dai.approve(address(pools[0]), _amount);
        pools[0].stake(_amount);
        pools[0].unstake(_amount);

        assertEq(pools[0].stakeOf(_account), 0);
        assertEq(pools[0].totalStaked(), 0);
        assertEq(hex1dai.balanceOf(_account), _amount);
        assertEq(hex1dai.balanceOf(address(pools[0])), 0);
    }

    function test_claim(address _account, uint256 _amount, uint256 _timeStaked) external prank(_account) {
        vm.assume(_account != address(0) && _account != address(pools[0]));
        _amount = bound(_amount, 1, MAX_STAKE);
        _timeStaked = bound(_timeStaked, 0, MAX_TIME_STAKED);

        deal(address(hex1dai), _account, _amount);

        hex1dai.approve(address(pools[0]), _amount);
        pools[0].stake(_amount);

        skip(_timeStaked);

        pools[0].claim();

        uint256 hexitMinted = (_amount * _timeStaked * pools[0].rewardPerToken()) / 1e18;
        assertEq(hexit.balanceOf(_account), hexitMinted);
    }

    function test_claim_afterUnstake(address _account, uint256 _amount, uint256 _timeStaked) external prank(_account) {
        vm.assume(_account != address(0) && _account != address(pools[0]));
        _amount = bound(_amount, 1, MAX_STAKE);
        _timeStaked = bound(_timeStaked, 1, MAX_TIME_STAKED);

        deal(address(hex1dai), _account, _amount);

        hex1dai.approve(address(pools[0]), _amount);
        pools[0].stake(_amount);

        skip(_timeStaked);

        pools[0].unstake(_amount);
        pools[0].claim();

        assertEq(pools[0].stakeOf(_account), 0);
        assertEq(pools[0].totalStaked(), 0);
        assertEq(hex1dai.balanceOf(_account), _amount);
        assertEq(hex1dai.balanceOf(address(pools[0])), 0);

        uint256 hexitMinted = (_amount * _timeStaked * pools[0].rewardPerToken()) / 1e18;
        assertEq(hexit.balanceOf(_account), hexitMinted);
    }

    function test_claim_rewardsAccruedCanBeClaimed(
        address _user,
        uint256 _depositAmount,
        uint256 _withdrawAmount,
        uint256 _firstSkip,
        uint256 _secondSkip
    ) external prank(_user) {
        _depositAmount = bound(_depositAmount, 1, 1e36);
        _withdrawAmount = bound(_withdrawAmount, 1, _depositAmount);
        _firstSkip = bound(_firstSkip, 1, 3652 days);
        _secondSkip = bound(_secondSkip, 1, 3652 days);

        vm.assume(_user != address(0));
        vm.assume(_firstSkip != 0);
        vm.assume(_secondSkip != 0);

        deal(address(hex1dai), _user, _depositAmount);

        hex1dai.approve(address(pools[0]), _depositAmount);
        pools[0].stake(_depositAmount);
        skip(_firstSkip);
        pools[0].unstake(_withdrawAmount);
        skip(_secondSkip);
        pools[0].claim();

        uint256 firstEarned = (_depositAmount * _firstSkip * 420e18) / 1e18;
        uint256 secondEarned = ((_depositAmount - _withdrawAmount) * _secondSkip * 420e18) / 1e18;
        assertEq(hexit.balanceOf(_user), firstEarned + secondEarned);
    }

    function test_exit(address _account, uint256 _amount, uint256 _timeStaked) external prank(_account) {
        vm.assume(_account != address(0) && _account != address(pools[0]));
        _amount = bound(_amount, 1, MAX_STAKE);
        _timeStaked = bound(_timeStaked, 0, MAX_TIME_STAKED);

        deal(address(hex1dai), _account, _amount);

        hex1dai.approve(address(pools[0]), _amount);
        pools[0].stake(_amount);

        skip(_timeStaked);

        pools[0].exit();

        assertEq(pools[0].stakeOf(_account), 0);
        assertEq(pools[0].totalStaked(), 0);
        assertEq(hex1dai.balanceOf(_account), _amount);
        assertEq(hex1dai.balanceOf(address(pools[0])), 0);

        uint256 hexitMinted = (_amount * _timeStaked * pools[0].rewardPerToken()) / 1e18;
        assertEq(hexit.balanceOf(_account), hexitMinted);
    }

    function test_calculateRewardsEarned(address _account, uint256 _amount, uint256 _timeStaked)
        external
        prank(_account)
    {
        vm.assume(_account != address(0) && _account != address(pools[0]));
        _amount = bound(_amount, 1, MAX_STAKE);
        _timeStaked = bound(_timeStaked, 0, MAX_TIME_STAKED);

        deal(address(hex1dai), _account, _amount);

        hex1dai.approve(address(pools[0]), _amount);
        pools[0].stake(_amount);

        skip(_timeStaked);

        uint256 rewards = pools[0].calculateRewardsEarned(_account);

        uint256 expectedRewards = (_amount * _timeStaked * pools[0].rewardPerToken()) / 1e18;
        assertEq(rewards, expectedRewards);
    }
}
