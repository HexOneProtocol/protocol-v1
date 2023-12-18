// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IHexOneToken} from "./interfaces/IHexOneToken.sol";

/// @title HexOneToken
contract HexOneToken is ERC20, Ownable, IHexOneToken {
    /// @notice HexOneProtocol address
    address public hexOneProtocol;

    /// @notice checks if the sender is HexOneProtocol
    modifier onlyHexOneProtocol() {
        if (msg.sender != hexOneProtocol) revert NotHexOneProtocol();
        _;
    }

    /// @param _name of the token: Hex One Token.
    /// @param _symbol ticker of the token: $HEX1.
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) Ownable(msg.sender) {}

    /// @notice set the address of the protocol.
    /// @param _hexOneProtocol address of the hexOneProtocol.
    function setHexOneProtocol(address _hexOneProtocol) external onlyOwner {
        if (_hexOneProtocol == address(0)) revert InvalidAddress();
        hexOneProtocol = _hexOneProtocol;
        emit ProtocolInitialized(_hexOneProtocol);
    }

    /// @notice mint HEX1 tokens to a specified account.
    /// @dev only HexOneProtocol can call this function.
    /// @param _recipient address of the receiver.
    /// @param _amount amount of HEX1 being minted.
    function mint(address _recipient, uint256 _amount) external onlyHexOneProtocol {
        _mint(_recipient, _amount);
    }

    /// @notice burn HEX1 tokens from a specified account.
    /// @dev only HexOneProtocol can call this function.
    /// @param _recipient address of the recipient having it's tokens burned.
    /// @param _amount amount of of HEX1 being burned.
    function burn(address _recipient, uint256 _amount) external onlyHexOneProtocol {
        _burn(_recipient, _amount);
    }
}
