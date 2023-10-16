// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "./IHexOneSacrifice.sol";
import "./IHexOneAirdrop.sol";

interface IHexOneBootstrap is IHexOneSacrifice, IHexOneAirdrop {
    struct Token {
        uint16 weight;
        uint8 decimals;
        bool enable;
    }

    struct Param {
        address hexOneProtocol;
        address hexOnePriceFeed;
        address dexRouter;
        address hexToken;
        address hexOneToken;
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

    /// @notice Set escrow contract address.
    /// @dev Only owner can call this function.
    function setEscrowContract(address _escrowCA) external;

    /// @notice Set hexOnePriceFeed contract address.
    /// @dev Only owner can call this function.
    /// @param _priceFeed The address of hexOnePriceFeed contract.
    function setPriceFeedCA(address _priceFeed) external;

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

    /// @notice Generate additional HEXIT tokens and send it to staking contract and team wallet.
    /// @dev it can be called by only owner and also only after airdrop ends.
    function generateAdditionalTokens() external;

    /// @notice Withdraw token to owner address.
    /// @dev This can be called by only owner and also when only after sacrifice finished.
    function withdrawToken(address _token) external;

    // function getAirdropClaimHistory() external view returns ()

    event AllowedTokensSet(address[] tokens, bool enable);

    event TokenWeightSet(address[] tokens, uint16[] weights);

    event Withdrawed(address token, uint256 amount);

    event RewardsDistributed();
}
