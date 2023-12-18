// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IHexitToken} from "./interfaces/IHexitToken.sol";

/// @title Hexit Token
contract HexitToken is ERC20, Ownable, IHexitToken {
    /// @notice HexOneBootstrap address
    address public hexOneBootstrap;

    /// @notice checks if the sender is the bootstrap
    modifier onlyHexOneBootstrap() {
        if (msg.sender != hexOneBootstrap) revert NotHexOneBootstrap();
        _;
    }

    /// @param _name of the token: Hexit Token.
    /// @param _symbol ticker of the token: $HEXIT.
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) Ownable(msg.sender) {}

    /// @dev set the address of the bootstrap.
    /// @param _hexOneBootstrap address of the hexOneBootstrap.
    function setHexOneBootstrap(address _hexOneBootstrap) external onlyOwner {
        if (_hexOneBootstrap == address(0)) revert InvalidAddress();
        hexOneBootstrap = _hexOneBootstrap;
        emit BootstrapInitialized(_hexOneBootstrap);
    }

    /// @notice mint HEXIT tokens to a specified account.
    /// @dev only HexOneBootstrap can call this function.
    /// @param _recipient address of the receiver.
    /// @param _amount amount of HEX1 being minted.
    function mint(address _recipient, uint256 _amount) external onlyHexOneBootstrap {
        _mint(_recipient, _amount);
    }
}
