// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

interface IHexOneStaking {
    struct DistTokenWeight {
        uint16 hexDistRate;
        uint16 hexitDistRate;
    }

    struct StakingInfo {
        uint256 initStakeTime;
        uint256 lastTimeClaimed;
        uint256 claimedHexAmount;
        uint256 claimedHexitAmount;
        uint256 stakedAmount;
        uint256 hexShareAmount;
        uint256 hexitShareAmount;
        address stakedToken;
        address staker;
    }

    struct RewardsPool {
        uint256 hexPool;
        uint256 hexitPool;
        uint256 distributedHex;
        uint256 distributedHexit;
    }

    struct UserStakingStatus {
        address token;
        uint256 stakedAmount;
        uint256 earnedHexAmount;
        uint256 earnedHexitAmount;
        uint256 claimableHexAmount;
        uint256 claimableHexitAmount;
        uint256 stakedTime;
        uint256 totalLockedAmount;
        uint16 shareOfPool;
        uint16 hexAPR;
        uint16 hexitAPR;
        uint16 hexMultiplier;
        uint16 hexitMultiplier;
    }

    function enableStaking() external;

    function purchaseHex(uint256 _amount) external;

    function purchaseHexit(uint256 _amount) external;

    function addAllowedTokens(address[] calldata _allowedTokens, DistTokenWeight[] calldata _distTokenWeights)
        external;

    function removeAllowedTokens(address[] calldata _allowedTokens) external;

    function currentStakingDay() external view returns (uint256);

    function stakeToken(address _token, uint256 _amount) external;

    function claimableRewardsAmount(address _user, address _token)
        external
        view
        returns (uint256 hexAmount, uint256 hexitAmount);

    function claimRewards(address _token) external;

    function unstake(address _token, uint256 _unstakeAmount) external;

    function getUserStakingStatus(address _user) external view returns (UserStakingStatus[] memory);
}
