// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

interface IHexToken {
    struct GlobalsStore {
        // 1
        uint72 lockedHeartsTotal;
        uint72 nextStakeSharesTotal;
        uint40 shareRate;
        uint72 stakePenaltyTotal;
        // 2
        uint16 dailyDataCount;
        uint72 stakeSharesTotal;
        uint40 latestStakeId;
        uint128 claimStats;
    }

    struct StakeStore {
        uint40 stakeId;
        uint72 stakedHearts;
        uint72 stakeShares;
        uint16 lockedDay;
        uint16 stakedDays;
        uint16 unlockedDay;
        bool isAutoStake;
    }

    function globalInfo() external view returns (uint256[13] memory);
    function stakeLists(address stakerAddr, uint256 stakeIndex) external view returns (StakeStore memory);
    function currentDay() external view returns (uint256);
    function stakeStart(uint256 newStakedHearts, uint256 newStakedDays) external;
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function stakeEnd(uint256 stakeIndex, uint40 stakeIdParam) external;
    function stakeCount(address stakerAddr) external view returns (uint256);
    function dailyDataRange(uint256 beginDay, uint256 endDay) external view returns (uint256[] memory list);
    function dailyData(uint256 day)
        external
        view
        returns (uint72 dayPayoutTotal, uint72 dayStakeSharesTotal, uint56 dayUnclaimedSatoshisTotal);
    function dailyDataUpdate(uint256 beforeDay) external;
}
