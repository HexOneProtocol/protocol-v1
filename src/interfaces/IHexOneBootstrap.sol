// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

interface IHexOneBootstrap {
    struct UserInfo {
        uint256 hexitShares;
        uint256 sacrificedUSD;
        bool claimedSacrifice;
        bool claimedAirdrop;
    }

    event Sacrificed(
        address indexed user,
        address indexed token,
        uint256 amountSacrificed,
        uint256 amountSacrificedUSD,
        uint256 hexitSharesEarned
    );
    event SacrificeProcessed(address hexOneDaiPair, uint256 hexOneAmount, uint256 daiAmount, uint256 liquidity);
    event SacrificeClaimed(address indexed user, uint256 hexOneMinted, uint256 hexitMinted);
    event AirdropStarted(uint256 hexitTeamAlloc, uint256 hexitStakingAlloc);
    event AirdropClaimed(address indexed user, uint256 hexitMinted);

    error MismatchedArrayLength();
    error ZeroLengthArray();
    error InvalidTimestamp(uint256 timestamp);
    error InvalidAddress(address addr);
    error InvalidMultiplier(uint256 multiplier);
    error SacrificeHasNotStartedYet(uint256 timestamp);
    error SacrificeAlreadyEnded(uint256 timestamp);
    error SacrificeHasNotEndedYet(uint256 timestamp);
    error InvalidAmountIn(uint256 amountIn);
    error InvalidAmountOutMin(uint256 amountOutMin);
    error InvalidSacrificeToken(address token);
    error InvalidQuote(uint256 quote);
    error PriceConsultationFailedBytes(bytes revertData);
    error PriceConsultationFailedString(string revertReason);
    error SacrificeAlreadyProcessed();
    error SacrificeHasNotBeenProcessedYet();
    error SacrificeClaimPeriodAlreadyFinished(uint256 timestamp);
    error AirdropHasNotStartedYet(uint256 timestamp);
    error AirdropAlreadyEnded(uint256 timestamp);
    error DidNotParticipateInSacrifice(address sender);
    error SacrificeAlreadyClaimed(address sender);
    error SacrificeClaimPeriodHasNotFinished(uint256 timestamp);
    error AirdropAlreadyStarted();
    error AirdropAlreadyClaimed(address sender);
    error IneligibleForAirdrop(address sender);
    error ContractAlreadySet();
    error SacrificeStartAlreadySet();

    function getCurrentSacrificeDay() external view returns (uint256);
    function getCurrentAirdropDay() external view returns (uint256);

    function setBaseData(address _hexOnePriceFeed, address _hexOneStaking, address _hexOneVault) external;
    function setSacrificeTokens(address[] calldata _tokens, uint16[] calldata _multipliers) external;
    function setSacrificeStart(uint256 _sacrificeStart) external;
    function sacrifice(address _token, uint256 _amountIn, uint256 _amountOutMin) external;
    function processSacrifice(uint256 _amountOutMinDai) external;
    function claimSacrifice() external returns (uint256 stakeId, uint256 hexOneMinted, uint256 hexitMinted);
    function startAirdrop() external;
    function claimAirdrop() external;
}
