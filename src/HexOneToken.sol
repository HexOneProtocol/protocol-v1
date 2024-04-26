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
    bytes32 public constant VAULT_ROLE = keccak256("VAULT_ROLE");

    constructor() ERC20("HEX1 Token", "HEX1") {
        _grantRole(VAULT_ROLE, msg.sender);
    }

    function mint(address _account, uint256 _amount) external onlyRole(VAULT_ROLE) {
        _mint(_account, _amount);
    }

    function burn(address _account, uint256 _amount) external onlyRole(VAULT_ROLE) {
        _burn(_account, _amount);
    }
}
