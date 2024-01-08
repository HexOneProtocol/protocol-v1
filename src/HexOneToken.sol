// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IHexOneToken} from "./interfaces/IHexOneToken.sol";

/// @title HexOneToken
contract HexOneToken is ERC20, Ownable, IHexOneToken {
    /// @notice HexOneVault address
    address public hexOneVault;

    /// @notice checks if the sender is HexOneVault
    modifier onlyHexOneVault() {
        if (msg.sender != hexOneVault) revert NotHexOneVault();
        _;
    }

    /// @param _name of the token: Hex One Token.
    /// @param _symbol ticker of the token: $HEX1.
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) Ownable(msg.sender) {}

    /// @notice set the address of the vault.
    /// @param _hexOneVault address of the hexOneVault.
    function setHexOneVault(address _hexOneVault) external onlyOwner {
        if (_hexOneVault == address(0)) revert InvalidAddress();
        hexOneVault = _hexOneVault;
        emit VaultInitialized(_hexOneVault);
    }

    /// @notice mint HEX1 tokens to a specified account.
    /// @dev only HexOneVault can call this function.
    /// @param _recipient address of the receiver.
    /// @param _amount amount of HEX1 being minted.
    function mint(address _recipient, uint256 _amount) external onlyHexOneVault {
        _mint(_recipient, _amount);
    }

    /// @notice burn HEX1 tokens from a specified account.
    /// @dev only HexOneVault can call this function.
    /// @param _recipient address of the recipient having it's tokens burned.
    /// @param _amount amount of of HEX1 being burned.
    function burn(address _recipient, uint256 _amount) external onlyHexOneVault {
        _burn(_recipient, _amount);
    }
}
