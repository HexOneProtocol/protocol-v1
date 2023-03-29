// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

interface IHexOneAirdrop {
    struct RequestAirdrop {
        uint256 airdropId;
        uint256 requestedDay;
        uint256 sacrificeUSD;
        uint256 sacrificeMultiplier;
        uint256 hexShares;
        uint256 hexShareMultiplier;
        uint256 totalUSD;
        uint256 claimedAmount;
        bool claimed;
    }

    struct AirdropClaimHistory {
        uint256 airdropId;
        uint256 requestedDay;
        uint256 sacrificeUSD;
        uint256 sacrificeMultiplier;
        uint256 hexShares;
        uint256 hexShareMultiplier;
        uint256 totalUSD;
        uint256 dailySupplyAmount;
        uint256 claimedAmount;
        uint16 shareOfPool;
    }

    struct AirdropPoolInfo {
        uint256 sacrificedAmount;
        uint256 stakingShareAmount;
        uint256 curAirdropDay;
        uint256 curDayPoolAmount;
        uint256 curDaySupplyHEXIT;
        uint16 sacrificeDistRate;
        uint16 stakingDistRate;
        uint16 shareOfPool;
    }

    /// @notice Get left airdrop requestors.
    function getAirdropRequestors() external view returns (address[] memory);

    /// @notice Get airdrop claim history
    function getAirdropClaimHistory(
        address _user
    ) external view returns (AirdropClaimHistory memory);

    /// @notice Get current airdrop day index.
    function getCurrentAirdropDay() external view returns (uint256);

    /// @notice
    function getCurrentAirdropInfo(address _user)
        external
        view
        returns (AirdropPoolInfo memory);

    /// @notice Request airdrop.
    /// @dev It can be called in airdrop duration and
    ///      each person can call this function only one time.
    function requestAirdrop() external;

    /// @notice Claim HEXIT token as airdrop.
    /// @dev If users have requests that didn't claim yet, they can request claim.
    function claimAirdrop() external;
}
