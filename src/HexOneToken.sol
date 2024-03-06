// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IHexOneToken} from "./interfaces/IHexOneToken.sol";

/// @title Hex One Token
/// @dev yield-bearing stablecoin backed by HEX T-shares.
contract HexOneToken is ERC20, Ownable, IHexOneToken {
    /// @dev HEX1 vault contract address.
    address public hexOneVault;

    /// @dev checks if the sender is the vault.
    modifier onlyHexOneVault() {
        if (msg.sender != hexOneVault) revert NotHexOneVault();
        _;
    }

    /// @param _name name of the token.
    /// @param _symbol ticker of the token.
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) Ownable(msg.sender) {}

    /// @dev set the address of the vault.
    /// @param _hexOneVault address of the vault.
    function setHexOneVault(address _hexOneVault) external onlyOwner {
        if (hexOneVault != address(0)) revert VaultAlreadySet();
        if (_hexOneVault == address(0)) revert InvalidAddress();
        hexOneVault = _hexOneVault;
        emit VaultInitialized(_hexOneVault);
    }

    /// @dev mint HEX1 tokens to a specified account.
    /// @notice only vault can call this function.
    /// @param _recipient address of the receiver.
    /// @param _amount amount of HEX1 being minted.
    function mint(address _recipient, uint256 _amount) external onlyHexOneVault {
        _mint(_recipient, _amount);
    }

    /// @dev burn HEX1 tokens from a specified account.
    /// @notice only vault can call this function.
    /// @param _recipient address of the recipient having it's tokens burned.
    /// @param _amount amount of of HEX1 being burned.
    function burn(address _recipient, uint256 _amount) external onlyHexOneVault {
        _burn(_recipient, _amount);
    }
}
