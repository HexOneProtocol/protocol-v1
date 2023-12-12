// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

interface IHexOneStaking {
    /// @dev this struct represents a staking pool, that can be
    /// either an HEX or HEXIT pool
    struct Pool {
        /// @dev total amount of pool token deposited (18 decimals for HEXIT and 8 for HEX)
        uint256 totalAssets;
        /// @dev total amount of distributed pool token (18 decimals for HEXIT and 8 for HEX)
        uint256 distributedAssets;
        /// @dev total amount of pool shares (always 18 decimals)
        uint256 totalShares;
        /// @dev last staking day in which the pool was synced
        uint256 currentStakingDay;
        /// @dev 1% of the pool is distributed daily in bps 10
        uint16 distributionRate;
    }

    /// @dev this struct stores information about the user stake for
    /// both HEX and HEXIT pool
    struct StakeInfo {
        /// @dev amount of stake token deposited
        uint256 stakedAmount;
        /// @dev staking day in which the stake was created
        uint256 initStakeDay;
        /// @dev staking day in which rewards were last claimed
        uint256 lastClaimedDay;
        /// @dev staking day in which the user last deposited
        uint256 lastDepositedDay;
        /// @dev amount of shares user has from HEX pool
        uint256 hexSharesAmount;
        /// @dev amount of shares user has from HEXIT pool
        uint256 hexitSharesAmount;
        /// @dev amount of HEX rewards accrued
        uint256 unclaimedHex;
        /// @dev amount of HEXIT rewards accrued
        uint256 unclaimedHexit;
        /// @dev total HEX rewards claimed since initStakeTime
        uint256 totalHexClaimed;
        /// @dev total HEXIT rewards claimed since initStakeTime
        uint256 totalHexitClaimed;
    }

    /// @dev this struct stores the state in which the pool was at the
    /// end of each day.
    struct PoolHistory {
        /// @dev total shares emitted by the pool at a specific day
        uint256 totalShares;
        /// @dev total amount of pool token to distribute for that day (1% of available)
        uint256 amountToDistribute;
    }

    function setBaseData(address _hexOneProtocol, address _hexOneBootstrap) external;

    function enableStaking() external;

    function setStakeTokens(address[] calldata _tokens, uint16[] calldata _weights) external;

    function purchase(address _poolToken, uint256 _amount) external;

    function stake(address _stakeToken, uint256 _amount) external;

    function unstake(address _stakeToken, uint256 _amount) external;

    function claim(address _stakeToken) external;

    function getCurrentStakingDay() external view returns (uint256);
}
