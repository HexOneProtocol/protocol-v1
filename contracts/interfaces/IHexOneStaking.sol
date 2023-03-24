// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

interface IHexOneStaking {

    struct Rewards {
        uint256 stakeId;
        uint256 stakedAmount;
        uint256 claimableRewards;
        address rewardToken;
        address stakeToken;
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

    /// @notice Set StakingMaster address.
    /// @dev Only ower can call this function.
    function setStakingMaster(address _stakingMaster) external;

    /// @notice Stake ERC20 tokens.
    function stakeERC20Start(
        address _staker,
        uint256 _amount
    ) external;

    /// @notice Stake ERC721 tokens.
    function stakeERC721Start(
        address _staker,
        uint256[] memory _tokenIds
    ) external;

    /// @notice Unstake ERC20 tokens.
    /// @return staked amount and claimable rewards info.
    function stakeERC20End(
        address _staker,
        uint256 _stakeId
    ) external returns (uint256, uint256[] memory);

    /// @notice Unstake ERC721 tokens.
    function stakeERC721End(
        address _staker,
        uint256 _stakeId
    ) external returns (uint256[] memory, uint256[] memory);

    /// @notice Get claimable rewards.
    function claimableRewards(
        address _staker,
        address _rewardToken
    ) external view returns (Rewards[] memory);

    function baseToken() external view returns (address baseToken);
}