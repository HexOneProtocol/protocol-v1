// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "./IHexOneStaking.sol";

interface IHexOneStakingMaster {

    struct AllowedToken {
        address stakingPool;
        uint16 rewardRate;
        bool isEnable;
    }

    /// @notice Set hexOneProtocol contract address.
    /// @dev Only owner can call this function.
    function setHexOneProtocol(address _hexOneProtocol) external;

    /// @notice Set reward tokens for stake token.
    /// @dev Only owner can call this function.
    function setAllowedRewardTokens(
        address _baseToken, 
        address[] memory _rewardTokens, 
        bool _isAllow
    ) external;

    /// @notice Enable/Disable allow tokens.
    /// @dev Only owner can call this function.
    /// @param _tokens The address of tokens.
    /// @param _isEnable Enable/Disable = true/false.
    function setAllowTokens(
        address[] memory _tokens, 
        bool _isEnable
    ) external;

    /// @notice Set rewards rate per token.
    function setRewardsRate(
        address[] memory _tokens, 
        uint16[] memory _rewardsRate
    ) external;

    /// @notice Set staking contract for base token.
    /// @dev Only owner can call this function.
    function setStakingPools(
        address[] memory _tokens,
        address[] memory _stakingPools
    ) external;

    /// @notice Get allowed reward tokens for base token.
    function getAllowedRewardTokens(
        address _baseToken
    ) external view returns (address[] memory);

    /// @notice Stake ERC20 tokens.
    function stakeERC20Start(
        address _token,
        address _rewardToken,
        uint256 _amount
    ) external;

    /// @notice Stake ERC721 tokens.
    function stakeERC721Start(
        address _collection,
        address _rewardToken,
        uint256[] memory _tokenIds
    ) external;

    /// @notice Unstake ERC20 tokens.
    function stakeERC20End(address _token, address _rewardToken, uint256 _stakeId) external;

    /// @notice Unstake ERC721 tokens.
    function stakeERC721End(address _collection, address _rewardToken, uint256 _stakeId) external;

    function claimableRewards(
        address _staker, 
        address _stakeToken,
        address _rewardToken
    ) external view returns (IHexOneStaking.Rewards[] memory);

    /// @notice update reward pool amount.
    /// @dev Only HexOneProtocol can call this function.
    function updateRewards(address _token, uint256 _amount) external;

    /// @notice Return reward rate for reward token.
    function getRewardRate(address _token) external view returns (uint16);

    /// @notice Return pool amount of reward token.
    function getTotalPoolAmount(address _rewardToken) external view returns (uint256);
}