// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "./IHexOneStaking.sol";

interface IHexOneStakingMaster {

    struct AllowedToken {
        address stakingPool;
        address[] rewardTokens;
        uint16[] rewardTokenWeights;
        bool isEnable;
    }

    /// @notice Set hexOneProtocol contract address.
    /// @dev Only owner can call this function.
    function setHexOneProtocol(address _hexOneProtocol) external;

    /// @notice Set fee receiver address.
    /// @dev Only owner can call this function.
    function setFeeReceiver(
        address _feeReceiver
    ) external;

    /// @notice Set withdraw fee rate.
    /// @dev Only owner can call this function.
    function setWithdrawFeeRate(
        uint16 _feeRate
    ) external;

    /// @notice Enable/Disable allow tokens.
    /// @dev Only owner can call this function.
    function setAllowTokens(
        address _baseToken,
        address _stakingPool,
        address[] memory _rewardTokens,
        uint16[] memory _rewardTokenWeights
    ) external;

    /// @notice Stake ERC20 tokens.
    function stakeERC20Start(
        address _token,
        uint256 _amount
    ) external;

    /// @notice Stake ERC721 tokens.
    function stakeERC721Start(
        address _collection,
        uint256[] memory _tokenIds
    ) external;

    /// @notice Unstake ERC20 tokens.
    function stakeERC20End(address _token, uint256 _stakeId) external;

    /// @notice Unstake ERC721 tokens.
    function stakeERC721End(address _collection, uint256 _stakeId) external;

    /// @notice update reward pool amount.
    /// @dev Only HexOneProtocol can call this function.
    function updateRewards(address _token, uint256 _amount) external;
}