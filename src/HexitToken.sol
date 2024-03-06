// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IHexitToken} from "./interfaces/IHexitToken.sol";

/// @title Hexit Token
/// @dev incentive token distributed by bootstrap staking pool.
contract HexitToken is ERC20, Ownable, IHexitToken {
    /// @dev HEX1 bootstrap contract address.
    address public hexOneBootstrap;

    /// @dev checks if the sender is the bootstrap.
    modifier onlyHexOneBootstrap() {
        if (msg.sender != hexOneBootstrap) revert NotHexOneBootstrap();
        _;
    }

    /// @param _name name of the token.
    /// @param _symbol ticker of the token.
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) Ownable(msg.sender) {}

    /// @dev set the address of the bootstrap.
    /// @param _hexOneBootstrap address of the bootstrap.
    function setHexOneBootstrap(address _hexOneBootstrap) external onlyOwner {
        if (hexOneBootstrap != address(0)) revert BootstrapAlreadySet();
        if (_hexOneBootstrap == address(0)) revert InvalidAddress();
        hexOneBootstrap = _hexOneBootstrap;
        emit BootstrapInitialized(_hexOneBootstrap);
    }

    /// @dev mint HEXIT tokens to a specified account.
    /// @notice only bootstrap can call this function.
    /// @param _recipient address of the receiver.
    /// @param _amount amount of HEX1 being minted.
    function mint(address _recipient, uint256 _amount) external onlyHexOneBootstrap {
        _mint(_recipient, _amount);
    }
}
