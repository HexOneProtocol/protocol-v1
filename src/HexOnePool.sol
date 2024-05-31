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

    /// @dev access control manager role, resulting hash of keccak256("MANAGER_ROLE").
    bytes32 public constant MANAGER_ROLE = 0x241ecf16d79d0f8dbfb92cbc07fe17840425976cf0667f022fe9877caa831b08;

    /// @dev precision scale multipler.
    uint256 public constant MULTIPLIER = 1e18;

    /// @dev address of the pool manager.
    address public immutable manager;
    /// @dev address of the hexit token.
    address public immutable hexit;
    /// @dev address of the stake token.
    address public immutable token;

    /// @dev amount of hexit given as reward per second.
    uint256 public rewardPerShare;
    /// @dev total amount of `token` staked.
    uint256 public totalStaked;
    /// @dev user => amount staked.
    mapping(address => uint256) public stakeOf;

    /// @dev user => earned amount to be claimed.
    mapping(address => uint256) internal earned;
    /// @dev user => last timestamp user interacted with contract.
    mapping(address => uint256) internal lastUpdated;

    /**
     *  @dev gives vault permission to mint HEX1.
     *  @param _manager address of the pool manager.
     *  @param _hexit address of the hexit token.
     *  @param _token address of the stake token.
     */
    constructor(address _manager, address _hexit, address _token) {
        if (_manager == address(0)) revert ZeroAddress();
        if (_hexit == address(0)) revert ZeroAddress();
        if (_token == address(0)) revert ZeroAddress();

        manager = _manager;
        hexit = _hexit;
        token = _token;

        _grantRole(MANAGER_ROLE, _manager);
    }

    /**
     *  @dev set the `_rewardPerToken`.
     *  @notice can only be called once by the manager during deployment.
     *  @param _rewardPerShare of token to stake.
     */
    function initialize(uint256 _rewardPerShare) external onlyRole(MANAGER_ROLE) {
        rewardPerShare = _rewardPerShare;
    }

    /**
     *  @dev stakes an `_amount` of `token`.
     *  @param _amount of token to stake.
     */
    function stake(uint256 _amount) external {
        if (_amount == 0) revert InvalidAmount();

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
        if (_amount == 0) revert InvalidAmount();
        if (_amount > stakeOf[msg.sender]) revert AmountExceedsStake();

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
        uint256 shares = (stakeOf[_account] * MULTIPLIER) / totalStaked;
        rewards = (shares * (block.timestamp - lastUpdated[_account]) * rewardPerShare) / MULTIPLIER;
    }

    /**
     *  @dev called every time an `_account` interacts with the contract.
     */
    function _update(address _account) internal {
        earned[_account] += _calculateRewards(_account);
        lastUpdated[_account] = block.timestamp;
    }
}
