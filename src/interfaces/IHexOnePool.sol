// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

interface IHexOnePool {
    event Staked(address indexed account, uint256 amount);
    event Unstaked(address indexed account, uint256 amount);
    event Claimed(address indexed account, uint256 rewards);

    error InvalidAmount();
    error ZeroAddress();
    error AmountExceedsStake();

    function initialize(uint256 _rewardPerToken) external;
    function stake(uint256 _amount) external;
    function unstake(uint256 _amount) external;
    function claim() external returns (uint256 rewards);
    function exit() external returns (uint256 rewards);
}
