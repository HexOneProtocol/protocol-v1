// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

import {IHexOneToken} from "./interfaces/IHexOneToken.sol";

/**
 *  @title Hex One Token
 *  @dev yield bearing stablecoin.
 */
contract HexOneToken is ERC20, AccessControl, IHexOneToken {
    /// @dev access control vault role,
    bytes32 public constant VAULT_ROLE = keccak256("VAULT_ROLE");

    /**
     *  @dev gives vault permission to mint HEX1.
     *  @notice this contract is deployed by the vault, so permissions are given to `msg.sender`.
     */
    constructor() ERC20("HEX1 Token", "HEX1") {
        _grantRole(VAULT_ROLE, msg.sender);
    }

    /**
     *  @dev mint `_amount` to `_account`.
     *  @notice can only be called by the vault.
     *  @param _account HEX1 tokens recipient.
     *  @param _amount HEX1 amount to mint.
     */
    function mint(address _account, uint256 _amount) external onlyRole(VAULT_ROLE) {
        _mint(_account, _amount);
    }

    /**
     *  @dev mint `_amount` to `_account`.
     *  @notice can only be called by the vault.
     *  @param _account HEX1 tokens recipient.
     *  @param _amount HEX1 amount to mint.
     */
    function burn(address _account, uint256 _amount) external onlyRole(VAULT_ROLE) {
        _burn(_account, _amount);
    }
}
