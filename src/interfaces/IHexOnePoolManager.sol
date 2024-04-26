// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

interface IHexOnePoolManager {
    event PoolCreated(address pool);
    event PoolsCreated(address[] pools);

    error EmptyArray();
    error MismatchedArray();
    error ZeroAddress();
    error InvalidRewardPerToken();
    error DeploymentFailed();
    error PoolAlreadyCreated();

    function createPools(address[] memory _tokens, uint256[] memory _rewardsPerToken) external;
    function createPool(address _token, uint256 _rewardPerToken) external;
    function getPoolsLength() external returns (uint256);
}
