// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

interface IHexOneBootstrap {
    struct Token {
        uint16 weight;
        bool enable;
    }

    struct Param {
        address hexOnePriceFeed;
        address dexRouter;
        address hexToken;
        address pairToken;
        address hexitToken;
        address escrowCA;
        uint256 sacrificeStartTime;
        uint256 airdropStartTime;
        uint16 sacrificeDuration;
        uint16 airdropDuration;
        uint16 sacrificeRate;
        uint16 airdropRate;
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
    function setAllowedTokens(
        address[] memory _tokens, 
        bool _enable
    ) external;

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

    /// @notice Withdraw token to owner address.
    /// @dev This can be called by only owner and also when only after sacrifice finished.
    function withdrawToken(address _token) external;

    /// @notice Ditribute reward token(HEXIT) to sacrifice participants.
    /// @dev This can be called by only owner and also when only after sacrifice finished.
    function distributeRewards() external;

    event AllowedTokensSet(address[] tokens, bool enable);

    event TokenWeightSet(address[] tokens, uint16[] weights);

    event Withdrawed(address token, uint256 amount);

    event RewardsDistributed();
}