// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./utils/TokenUtils.sol";
import "./interfaces/IHexOneStaking.sol";
import "./interfaces/IHexOneProtocol.sol";

contract HexOneStaking is Ownable, IHexOneStaking {
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeERC20 for IERC20;

    IHexOneProtocol public hexOneProtocol;
    address public override baseToken;
    uint256 public stakeId;
    uint256 private poolId;
    uint256 public launchedTime;
    uint256 private totalPoolAmount;
    uint256 public stakedAmount;
    uint16 public stakingRewardRate;
    uint16 constant FIXED_POINT = 1000;

    mapping(uint256 => PoolInfo) private poolInfos;
    mapping(address => EnumerableSet.UintSet) private userStakeIds;
    mapping(address => mapping(uint256 => StakeInfo)) private userStakeInfos;

    constructor (
        address _baseToken,
        uint16 _rewardsRate
    ) {
        require (_baseToken != address(0), "zero baseToken address");
        launchedTime = block.timestamp;
        stakingRewardRate = _rewardsRate;
    }

    /// @inheritdoc IHexOneStaking
    function setStakingRewardsRate(uint16 _rewardsRate) external onlyOwner override {
        stakingRewardRate = _rewardsRate;
    }

    /// @inheritdoc IHexOneStaking
    function setHexOneProtocol(address _hexOneProtocol) external onlyOwner override {
        require (_hexOneProtocol != address(0), "zero hexOneProtocol address");
        hexOneProtocol = IHexOneProtocol(_hexOneProtocol);
    }

    /// @inheritdoc IHexOneStaking
    function stakeStart(uint256 _amount) external override {
        address sender;
        require (sender != address(0), "zero caller address");
        IERC20(baseToken).safeTransferFrom(sender, address(this), _amount);

        userStakeInfos[sender][stakeId] = StakeInfo(block.timestamp, _amount, totalPoolAmount);
        stakedAmount += _amount;
        poolInfos[poolId ++] = PoolInfo(stakedAmount, totalPoolAmount);
        userStakeIds[sender].add(stakeId ++);
    }

    /// @inheritdoc IHexOneStaking
    function stakeEnd(uint256 _stakeId) external override {
        address sender;
        require (sender != address(0), "zero caller address");
        require (userStakeIds[sender].contains(_stakeId), "not exist stakeId");
        uint256 claimableAmount = _getClaimableRewards(sender, _stakeId);
        userStakeIds[sender].remove(_stakeId);
        stakedAmount -= userStakeInfos[sender][_stakeId].stakedAmount;
        poolInfos[poolId ++] = PoolInfo(stakedAmount, totalPoolAmount);

        IERC20(baseToken).safeTransfer(sender, claimableAmount);
    }

    /// @inheritdoc IHexOneStaking
    function claimableRewards(
        address _staker
    ) external view override returns (Rewards[] memory) {
        require (_staker != address(0), "zero staker address");
        require (userStakeIds[_staker].length() > 0, "no staking pool");

        uint256[] memory stakeIds = userStakeIds[_staker].values();
        Rewards[] memory rewardsData = new Rewards[](stakeIds.length);
        for (uint256 i = 0; i < stakeIds.length; i ++) {
            rewardsData[i] = Rewards(
                stakeIds[i], 
                _getClaimableRewards(_staker, stakeIds[i])
            );
        }

        return rewardsData;
    }

    /// @inheritdoc IHexOneStaking
    function updateRewards(uint256 _amount) external override {
        address sender;
        require (sender == address(hexOneProtocol), "only HexOneProtocol");
        IERC20(baseToken).safeTransferFrom(sender, address(this), _amount);
        totalPoolAmount += _amount;
    }

    function _getClaimableRewards(address _staker, uint256 _stakeId) internal view returns (uint256) {
        StakeInfo memory stakeInfo = userStakeInfos[_staker][_stakeId];
        if (_stakeId == stakeId - 1) {
            PoolInfo memory poolInfo = poolInfos[_stakeId];
            uint256 rewardsAmount = totalPoolAmount - stakeInfo.currentPoolAmount;
            rewardsAmount = rewardsAmount * stakeInfo.stakedAmount / poolInfo.totalStakedAmount;

            return rewardsAmount + stakeInfo.stakedAmount;
        }

        uint256 claimableAmount = 0;
        for (uint256 id = _stakeId; id < stakeId - 1; id ++) {
            PoolInfo memory pointPoolInfo = poolInfos[id];
            PoolInfo memory nextPoolInfo = poolInfos[id + 1];
            uint256 rewardsAmount = nextPoolInfo.poolAmount - pointPoolInfo.poolAmount;
            rewardsAmount = rewardsAmount * stakingRewardRate / FIXED_POINT;
            rewardsAmount = rewardsAmount * stakeInfo.stakedAmount / pointPoolInfo.totalStakedAmount;
            claimableAmount += rewardsAmount;
        }

        return claimableAmount + stakeInfo.stakedAmount;
    }
}