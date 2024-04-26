// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import {SafeERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IHexOnePool} from "./interfaces/IHexOnePool.sol";
import {IHexitToken} from "./interfaces/IHexitToken.sol";

/**
 *  @title Hex One Pool
 *  @dev mints HEXIT based on the deposited amount and reward per token per second.
 */
contract HexOnePool is AccessControl, IHexOnePool {
    using SafeERC20 for IERC20;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    uint256 public constant MULTIPLIER = 1e18;

    address public immutable factory;
    address public immutable hexit;
    address public immutable token;

    uint256 public rewardPerToken;
    uint256 public totalStaked;
    mapping(address => uint256) public stakeOf;

    mapping(address => uint256) internal earned;
    mapping(address => uint256) internal lastUpdated;

    constructor(address _factory, address _hexit, address _token) {
        factory = _factory;
        hexit = _hexit;
        token = _token;

        _grantRole(MANAGER_ROLE, _factory);
    }

    /**
     *  @dev set the `_rewardPerToken`.
     *  @notice can only called once by the factory during deployment.
     *  @param _rewardPerToken of token to stake.
     */
    function initialize(uint256 _rewardPerToken) external onlyRole(MANAGER_ROLE) {
        rewardPerToken = _rewardPerToken;
    }

    /**
     *  @dev stakes an `_amount` of `token`.
     *  @param _amount of token to stake.
     */
    function stake(uint256 _amount) external {
        if (_amount == 0) revert ZeroAmount();

        _update(msg.sender);

        stakeOf[msg.sender] += _amount;
        totalStaked += _amount;

        IERC20(token).safeTransferFrom(msg.sender, address(this), _amount);

        emit Staked(msg.sender, _amount);
    }

    /**
     *  @dev unstakes an `_amount` of `token`.
     *  @param _amount of token to unstake.
     */
    function unstake(uint256 _amount) public {
        if (_amount == 0) revert ZeroAmount();

        _update(msg.sender);

        stakeOf[msg.sender] -= _amount;
        totalStaked -= _amount;

        IERC20(token).safeTransfer(msg.sender, _amount);

        emit Unstaked(msg.sender, _amount);
    }

    /**
     *  @dev claims earned rewards.
     */
    function claim() public returns (uint256 rewards) {
        _update(msg.sender);

        rewards = earned[msg.sender];
        if (rewards > 0) {
            earned[msg.sender] = 0;
            IHexitToken(hexit).mint(msg.sender, rewards);
        }

        emit Claimed(msg.sender, rewards);
    }

    /**
     *  @dev unstake total amount and claim earned rewards.
     */
    function exit() external returns (uint256 rewards) {
        unstake(stakeOf[msg.sender]);
        rewards = claim();
    }

    /**
     *  @dev retrieves the total earned rewards.
     */
    function calculateRewardsEarned(address _account) external view returns (uint256 rewards) {
        rewards = earned[_account] + _calculateRewards(_account);
    }

    /**
     *  @dev computes rewards accrued by `_account` since the last interaction.
     */
    function _calculateRewards(address _account) internal view returns (uint256 rewards) {
        rewards = (stakeOf[_account] * (block.timestamp - lastUpdated[_account]) * rewardPerToken) / MULTIPLIER;
    }

    /**
     *  @notice called every time an `_account` interacts with the contract.
     */
    function _update(address _account) internal {
        earned[_account] += _calculateRewards(_account);
        lastUpdated[_account] = block.timestamp;
    }
}
