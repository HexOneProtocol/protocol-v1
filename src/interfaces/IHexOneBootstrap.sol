// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

interface IHexOneBootstrap {
    struct Schedule {
        uint64 start;
        uint64 claimEnd;
        bool processed;
    }

    struct SacrificeInfo {
        uint256 sacrificedUsd;
        uint256 sacrificedHx;
        uint256 remainingHx;
        uint256 hexitMinted;
    }

    struct AirdropInfo {
        uint256 hexitMinted;
    }

    struct UserInfo {
        uint256 sacrificedUsd;
        uint256 hexitShares;
        bool sacrificeClaimed;
        bool airdropClaimed;
    }

    struct TokenSacrificeInfo {
        uint256 sacrificedAmount;
        uint256 sacrificedUsd;
        uint256 hexitShares;
    }

    error VaultAlreadyInitialized();
    error InvalidTimestamp();
    error EmptyArray();
    error ZeroAddress();
    error TokenAlreadySupported();
    error SacrificeInactive();
    error TokenNotSupported();
    error InvalidAmount();
    error InvalidAmountOutMin();
    error SacrificedAmountTooLow();
    error SacrificeActive();
    error SacrificeAlreadyProcessed();
    error SacrificeNotProcessed();
    error SacrificeClaimInactive();
    error DidNotParticipateInSacrifice();
    error SacrificeAlreadyClaimed();
    error SacrificeClaimActive();
    error AirdropInactive();
    error AirdropAlreadyStarted();
    error AirdropAlreadyClaimed();
    error IneligibleForAirdrop();

    event Sacrificed(
        address indexed account, address token, uint256 amount, uint256 sacrificedUsd, uint256 hexitShares
    );
    event SacrificeProcessed(address pair, uint256 amountA, uint256 amountB, uint256 liquidity);
    event SacrificeClaimed(address indexed account, uint256 tokendId, uint256 hex1Minted, uint256 hexitMinted);
    event AirdropStarted(uint64 start, uint64 end);
    event AirdropClaimed(address indexed account, uint256 hexitMinted);

    function sacrificeDay() external view returns (uint256);
    function airdropDay() external view returns (uint256);
    function sacrifice(address _token, uint256 _amount, uint256 _amountOutMin) external;
    function processSacrifice(uint256 _amountOutMin) external;
    function claimSacrifice() external returns (uint256 tokenId, uint256 hex1Minted, uint256 hexitMinted);
    function startAirdrop(uint64 _airdropStart) external;
    function claimAirdrop() external;
}
