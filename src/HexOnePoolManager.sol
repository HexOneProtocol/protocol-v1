// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import {HexOnePool} from "./HexOnePool.sol";
import {AccessControl} from "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

import {IHexOnePoolManager} from "./interfaces/IHexOnePoolManager.sol";
import {IHexOnePool} from "./interfaces/IHexOnePool.sol";
import {IHexitToken} from "./interfaces/IHexitToken.sol";

/**
 *  @title Hex One Pool Manager
 *  @dev manage pool deployments and access control.
 */
contract HexOnePoolManager is AccessControl, IHexOnePoolManager {
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    address public immutable hexit;

    address[] public pools;

    constructor(address _hexit) {
        if (_hexit == address(0)) revert ZeroAddress();

        hexit = _hexit;

        _grantRole(OWNER_ROLE, msg.sender);
    }

    /**
     *  @dev deploy multiple pools.
     *  @param _tokens address array of stake tokens.
     *  @param _rewardsPerToken HEXIT minting rate multiplier for each stake token.
     */
    function createPools(address[] memory _tokens, uint256[] memory _rewardsPerToken) external onlyRole(OWNER_ROLE) {
        if (_tokens.length == 0) revert EmptyArray();
        if (_tokens.length != _rewardsPerToken.length) revert MismatchedArray();

        address[] memory createdPools = new address[](_tokens.length);
        for (uint256 i; i < _tokens.length; ++i) {
            if (_tokens[i] == address(0)) revert ZeroAddress();
            if (_rewardsPerToken[i] == 0) revert InvalidRewardPerToken();

            createdPools[i] = _createPool(_tokens[i], _rewardsPerToken[i]);
        }

        emit PoolsCreated(createdPools);
    }

    /**
     *  @dev deploy pool.
     *  @param _token address of the stake token.
     *  @param _rewardPerToken HEXIT minting rate multiplier.
     */
    function createPool(address _token, uint256 _rewardPerToken) external onlyRole(OWNER_ROLE) {
        if (_token == address(0)) revert ZeroAddress();
        if (_rewardPerToken == 0) revert InvalidRewardPerToken();

        address pool = _createPool(_token, _rewardPerToken);

        emit PoolCreated(pool);
    }

    /**
     *  @dev returns the number of deployed pools.
     */
    function getPoolsLength() external view returns (uint256) {
        return pools.length;
    }

    /**
     *  @notice gives `pool` permissions to mint HEXIT.
     *  @param _token address of the stake token.
     *  @param _rewardPerToken HEXIT minting rate multiplier.
     */
    function _createPool(address _token, uint256 _rewardPerToken) internal returns (address pool) {
        pool = _deployPool(_token);

        pools.push(pool);

        IHexOnePool(pool).initialize(_rewardPerToken);
        IHexitToken(hexit).initPool(pool);
    }

    /**
     *  @notice salt is computed using the hexit and stake token to ensure pool uniqueness.
     *  @param _token address of the stake token.
     */
    function _deployPool(address _token) internal returns (address pool) {
        bytes32 salt = keccak256(abi.encodePacked(address(hexit), _token));

        bytes memory bytecode =
            abi.encodePacked(type(HexOnePool).creationCode, abi.encode(address(this), address(hexit), _token));

        assembly {
            pool := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }

        if (pool == address(0)) revert DeploymentFailed();
    }
}
