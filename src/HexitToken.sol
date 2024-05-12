// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

import {IHexitToken} from "./interfaces/IHexitToken.sol";

/**
 *  @title Hexit Token
 *  @dev hex one protocol incentive token.
 */
contract HexitToken is ERC20, AccessControl, IHexitToken {
    /// @dev access control owner role, resulting hash of keccak256("OWNER_ROLE").
    bytes32 public constant OWNER_ROLE = 0xb19546dff01e856fb3f010c267a7b1c60363cf8a4664e21cc89c26224620214e;
    /// @dev access control manager role, resulting hash of keccak256("MANAGER_ROLE").
    bytes32 public constant MANAGER_ROLE = 0x241ecf16d79d0f8dbfb92cbc07fe17840425976cf0667f022fe9877caa831b08;
    /// @dev access control minter role, resulting hash of keccak256("MINTER_ROLE").
    bytes32 public constant MINTER_ROLE = 0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6;

    /// @dev function selector => initialized.
    mapping(bytes4 => bool) internal initialized;

    /**
     *  @dev reverts if the `msg.sig` is already initialized.
     */
    modifier initializer() {
        if (initialized[msg.sig]) revert AlreadyInitialized();
        _;
    }

    /**
     *  @dev gives owner permissions to the deployer.
     */
    constructor() ERC20("HEXIT Token", "HEXIT") {
        _grantRole(OWNER_ROLE, msg.sender);
    }

    /**
     *  @dev give `_manager` permission to add new pools.
     *  @notice can only be called once by an account with `OWNER_ROLE`.
     *  @param _manager address of the pool manager contract.
     */
    function initManager(address _manager) external initializer onlyRole(OWNER_ROLE) {
        if (_manager == address(0)) revert ZeroAddress();

        initialized[msg.sig] = true;

        _grantRole(MANAGER_ROLE, _manager);

        emit ManagerInitialized(_manager);
    }

    /**
     *  @dev give `_feed` permission to mint HEXIT.
     *  @notice can only be called once by an account with `OWNER_ROLE`.
     *  @param _feed address of the price feed contract.
     */
    function initFeed(address _feed) external initializer onlyRole(OWNER_ROLE) {
        if (_feed == address(0)) revert ZeroAddress();

        initialized[msg.sig] = true;

        _grantRole(MINTER_ROLE, _feed);

        emit FeedInitialized(_feed);
    }

    /**
     *  @dev give `_bootstrap` permission to mint HEXIT.
     *  @notice can only be called once by an account with `OWNER_ROLE`.
     *  @param _bootstrap address of the bootstrap contract.
     */
    function initBootstrap(address _bootstrap) external initializer onlyRole(OWNER_ROLE) {
        if (_bootstrap == address(0)) revert ZeroAddress();

        initialized[msg.sig] = true;

        _grantRole(MINTER_ROLE, _bootstrap);

        emit BootstrapInitialized(_bootstrap);
    }

    /**
     *  @dev give `_pool` permission to mint HEXIT.
     *  @notice can only be called by accounts with `MANAGER_ROLE`.
     *  @param _pool address of the pool contract.
     */
    function initPool(address _pool) external onlyRole(MANAGER_ROLE) {
        _grantRole(MINTER_ROLE, _pool);
        emit PoolAdded(_pool);
    }

    /**
     *  @dev mint `_amount` to `_account`.
     *  @notice can only be called by accounts with `MINTER_ROLE`.
     *  @param _account HEXIT tokens recipient.
     *  @param _amount HEXIT amount to mint.
     */
    function mint(address _account, uint256 _amount) external onlyRole(MINTER_ROLE) {
        _mint(_account, _amount);
    }
}
