// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract HexOneAirdrop is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private eligibleTokens;
    address public hexitToken;
    uint256 immutable public startTime;

    constructor (
        address _hexitToken
    ) {
        require (_hexitToken != address(0), "zero hexOne token address");
        hexitToken = _hexitToken;
        startTime = block.timestamp;
    }

    /// @notice Add eligible tokens for airdrop.
    /// @dev Only owner can call this function.
    /// @param _tokens The address list of eligible tokens for airdrop.
    function addEligibleTokens(address[] memory _tokens) external onlyOwner {
        uint256 length = _tokens.length;
        require (length > 0, "empty token list");
        for (uint256 i = 0; i < length; i ++) {
            address token = _tokens[i];
            require (token != address(0), "zero token address");
            require (!eligibleTokens.contains(token), "already added");
        }
    }

    /// @notice Remove eligible tokens for airdrop.
    /// @dev Only owner can call this function.
    /// @param _tokens The address list of eligible tokens to remove.
    function removeEligibleTokens(address[] memory _tokens) external onlyOwner {
        uint256 length = _tokens.length;
        require (length > 0, "empty token list");
        for (uint256 i = 0; i < length; i ++) {
            address token = _tokens[i];
            require (token != address(0), "zero token address");
            require (eligibleTokens.contains(token), "already removed");
        }
    }

    function requestAirdrop() external {
        require (_checkEligibleUser(), "should have eligible token");
        // TODO Send $HEXIT token to requester.
    }

    /// @notice Check if user has one of eligible tokens.
    function _checkEligibleUser() internal view returns (bool) {
        uint256 length = eligibleTokens.length();
        address sender = msg.sender;
        for (uint256 i = 0; i < length; i ++) {
            address token = eligibleTokens.at(i);
            if (IERC20(token).balanceOf(sender) > 0) {
                return true;
            }
        }

        return false;
    }
}