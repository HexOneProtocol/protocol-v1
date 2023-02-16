// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

interface IHexOneStaking {

    struct Rewards {
        uint256 stakeId;
        uint256 claimableRewards;
    }

    struct StakeInfo {
        uint256 stakedTimestamp;
        uint256 stakedAmount;
        uint256 currentPoolAmount;
    }

    struct PoolInfo {
        uint256 totalStakedAmount;
        uint256 poolAmount;
    }

    /// @notice Set rewards percent for staking.
    /// @dev Only owner can call this function.
    function setStakingRewardsRate(uint16 _rewardsRate) external;

    /// @notice Set HexOneProtocol address.
    /// @dev Only ower can call this function.
    function setHexOneProtocol(address _hexOneProtocol) external;

    /// @notice Stake tokens.
    /// @dev Stakers can stake only token that allowed in HexOneProtocol
    function stakeStart(uint256 _amount) external;

    /// @notice Unstake tokens.
    function stakeEnd(
        uint256 _stakeId
    ) external;

    /// @notice Get claimable rewards.
    function claimableRewards(
        address _staker
    ) external view returns (Rewards[] memory);

    /// @notice Update rewards amount.
    /// @dev Only HexOneProtocol can call this function.
    function updateRewards(uint256 _amount) external;

    function baseToken() external view returns (address baseToken);
}