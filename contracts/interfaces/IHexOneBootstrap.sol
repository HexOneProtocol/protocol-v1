// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

interface IHexOneBootstrap {
    struct Token {
        uint16 weight;
        uint8 decimals;
        bool enable;
    }

    struct DistributionRate {
        uint16 sacrificeDistributionRate;
        uint16 sacrificeLiquidityRate;
    }

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
        uint256 stakingId;
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

    struct SacrificeInfo {
        uint256 sacrificeId;
        uint256 day;
        uint256 supplyAmount;
        uint256 sacrificedAmount;
        uint256 sacrificedWeight;
        uint256 usdValue;
        address sacrificeToken;
        uint16 multiplier;
    }

    struct Param {
        address hexOnePriceFeed;
        address dexRouter;
        address hexToken;
        address pairToken;
        address hexitToken;
        address stakingContract;
        address teamWallet;
        uint256 sacrificeStartTime;
        uint256 airdropStartTime;
        uint16 sacrificeDuration;
        uint16 airdropDuration;
        // rate information
        uint16 rateForSacrifice;
        uint16 rateForAirdrop;
        uint16 sacrificeDistRate;
        uint16 sacrificeLiquidityRate;
        uint16 airdropDistRateForHexHolder;
        uint16 airdropDistRateForHEXITHolder;
    }

    /// @notice Check if now is after sacrificeEndTime.
    function afterSacrificeDuration() external view returns (bool);

    /// @notice minted HEXIT amount for sacrifice.
    function sacrificeHEXITAmount()
        external
        view
        returns (uint256 sacrificeHEXITAmount);

    /// @notice received HEXIT token amount of _user for sacrifice.
    function userRewardsForSacrifice(
        address _user
    ) external view returns (uint256);

    /// @notice Set escrow contract address.
    /// @dev Only owner can call this function.
    function setEscrowContract(address _escrowCA) external;

    /// @notice Set hexOnePriceFeed contract address.
    /// @dev Only owner can call this function.
    /// @param _priceFeed The address of hexOnePriceFeed contract.
    function setPriceFeedCA(address _priceFeed) external;

    /// @notice Check if user is sacrifice participant.
    function isSacrificeParticipant(address _user) external view returns (bool);

    function getUserSacrificeInfo(
        address _user
    ) external view returns (SacrificeInfo[] memory);

    /// @notice Get left airdrop requestors.
    function getAirdropRequestors() external view returns (address[] memory);

    /// @notice Get sacrifice participants.
    function getSacrificeParticipants()
        external
        view
        returns (address[] memory);

    /// @notice Add/Remove allowed tokens for sacrifice.
    /// @dev Only owner can call this function.
    /// @param _tokens The address of tokens.
    /// @param _enable Add/Remove = true/false.
    function setAllowedTokens(address[] memory _tokens, bool _enable) external;

    /// @notice Set tokens weight.
    /// @dev Only owner can call this function.
    ///      Can't be modified after sacrifice started.
    /// @param _tokens The address of tokens.
    /// @param _weights The weight of tokens.
    function setTokenWeight(
        address[] memory _tokens,
        uint16[] memory _weights
    ) external;

    /// @notice Attend to sacrifice.
    /// @dev Anyone can attend to this but should do this with allowed token.
    function sacrificeToken(address _token, uint256 _amount) external;

    /// @notice Request airdrop.
    /// @dev It can be called in airdrop duration and
    ///      each person can call this function only one time.
    function requestAirdrop() external;

    /// @notice Claim HEXIT token as airdrop.
    /// @dev If users have requests that didn't claim yet, they can request claim.
    function claimAirdrop() external;

    /// @notice Generate additional HEXIT tokens and send it to staking contract and team wallet.
    /// @dev it can be called by only owner and also only after airdrop ends.
    function generateAdditionalTokens() external;

    /// @notice Withdraw token to owner address.
    /// @dev This can be called by only owner and also when only after sacrifice finished.
    function withdrawToken(address _token) external;

    /// @notice Claim HEXIT as rewards for sacrifice.
    function claimRewardsForSacrifice(uint256 _sacrificeId) external;

    /// @notice Get HEXIT amount for sacrifice by day index.
    function getAmountForSacrifice(
        uint256 _dayIndex
    ) external view returns (uint256);

    /// @notice Get current sacrifice day index.
    function getCurrentSacrificeDay() external view returns (uint256);

    /// @notice Get current airdrop day index.
    function getCurrentAirdropDay() external view returns (uint256);

    // function getAirdropClaimHistory() external view returns ()

    event AllowedTokensSet(address[] tokens, bool enable);

    event TokenWeightSet(address[] tokens, uint16[] weights);

    event Withdrawed(address token, uint256 amount);

    event RewardsDistributed();
}
