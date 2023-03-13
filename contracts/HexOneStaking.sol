// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./utils/TokenUtils.sol";
import "./interfaces/IHexOneStaking.sol";
import "./interfaces/IHexOneStakingMaster.sol";

contract HexOneStaking is OwnableUpgradeable, IHexOneStaking {
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeERC20 for IERC20;

    address public override baseToken;
    
    uint256 public launchedTime;
    // uint256 public stakedAmount;
    uint16 public FIXED_POINT;

    /// @dev rewardTokenAddr => stakeId => tokenIds
    /// @dev This is for staking ERC721.
    mapping(address => mapping(uint256 => EnumerableSet.UintSet)) private stakedTokenIds;

    /// @dev rewardTokenAddr => poolId => PoolInfo
    mapping(address => mapping(uint256 => PoolInfo)) private poolInfos;
    
    /// @dev rewardTokenAddr => userAddr => stakeIds
    mapping(address => mapping(address => EnumerableSet.UintSet)) private userStakeIds;

    /// @dev rewardTokenAddr => userAddr => stakeId => StakeInfo
    mapping(address => mapping(address => mapping(uint256 => StakeInfo))) private userStakeInfos;

    /// @dev Based on reward token, stakeId is different.
    mapping(address => uint256) private stakeIds;

    /// @dev Based on reward token, poolId is different.
    mapping(address => uint256) private poolIds;

    mapping(address => uint256) private stakedAmounts;

    address public stakingMaster;

    bool public NFTStaking;

    modifier onlyStakingMaster {
        require (msg.sender == stakingMaster, "no permission");
        _;
    }

    constructor () {
        _disableInitializers();
    }

    function initialize (
        address _baseToken,
        address _stakingMaster,
        bool _isERC721
    ) public initializer {
        require (_baseToken != address(0), "zero baseToken address");
        require (_stakingMaster != address(0), "zero staking master address");
        launchedTime = block.timestamp;
        stakingMaster = _stakingMaster;
        baseToken = _baseToken;
        NFTStaking = _isERC721;

        FIXED_POINT = 1000;

        __Ownable_init();
    }

    /// @inheritdoc IHexOneStaking
    function setStakingMaster(address _stakingMaster) external onlyOwner override {
        require (_stakingMaster != address(0), "zero staking master address");
        stakingMaster = _stakingMaster;
    }

    /// @inheritdoc IHexOneStaking
    function stakeERC20Start(
        address _staker,
        address _rewardToken,
        uint256 _amount
    ) external onlyStakingMaster override {
        _stakeStart(_staker, _rewardToken, _amount);
    }

    /// @inheritdoc IHexOneStaking
    function stakeERC721Start(
        address _staker,
        address _rewardToken,
        uint256[] memory _tokenIds
    ) external onlyStakingMaster override {
        uint256 amount = _tokenIds.length;
        uint256 curStakeId = stakeIds[_rewardToken];
        for (uint256 i = 0; i < amount; i ++) {
            uint256 tokenId = _tokenIds[i];
            stakedTokenIds[_rewardToken][curStakeId].add(tokenId);
        }

        _stakeStart(_staker, _rewardToken, amount);
    }

    /// @inheritdoc IHexOneStaking
    function stakeERC20End(
        address _staker,
        address _rewardToken, 
        uint256 _stakeId
    ) external override returns (uint256 stakedAmount, uint256 claimableAmount) {
        claimableAmount = _stakeEnd(_staker, _rewardToken, _stakeId);
        stakedAmount = userStakeInfos[_rewardToken][_staker][_stakeId].stakedAmount;
    }

    /// @inheritdoc IHexOneStaking
    function stakeERC721End(
        address _staker,
        address _rewardToken, 
        uint256 _stakeId
    ) external override returns (uint256 claimableAmount, uint256[] memory tokenIds) {
        return (
            _stakeEnd(_staker, _rewardToken, _stakeId),
            stakedTokenIds[_rewardToken][_stakeId].values()
        );
    }
    

    /// @inheritdoc IHexOneStaking
    function claimableRewards(
        address _staker,
        address _rewardToken
    ) external view override returns (Rewards[] memory) {
        require (_staker != address(0), "zero staker address");
        require (userStakeIds[_rewardToken][_staker].length() > 0, "no staking pool");

        uint256[] memory ids = userStakeIds[_rewardToken][_staker].values();
        Rewards[] memory rewardsData = new Rewards[](ids.length);
        for (uint256 i = 0; i < ids.length; i ++) {
            uint256 _stakeId = ids[i];
            StakeInfo memory stakeInfo = userStakeInfos[_rewardToken][_staker][_stakeId];
            rewardsData[i] = Rewards(
                _stakeId, 
                stakeInfo.stakedAmount,
                _getClaimableRewards(_staker, _rewardToken, ids[i]),
                _rewardToken,
                baseToken
            );
        }

        return rewardsData;
    }

    function _getClaimableRewards(
        address _staker, 
        address _rewardToken,
        uint256 _stakeId
    ) internal view returns (uint256) {
        StakeInfo memory stakeInfo = userStakeInfos[_rewardToken][_staker][_stakeId];
        uint256 curStakeId = stakeIds[_rewardToken];
        if (_stakeId == curStakeId - 1) {
            PoolInfo memory poolInfo = poolInfos[_rewardToken][_stakeId];
            uint256 totalPoolAmount = _getTotalPoolAmount(_rewardToken);
            uint256 rewardsAmount = totalPoolAmount - stakeInfo.currentPoolAmount;
            rewardsAmount = rewardsAmount * stakeInfo.stakedAmount / poolInfo.totalStakedAmount;

            return rewardsAmount;
        }

        uint256 claimableAmount = 0;
        for (uint256 id = _stakeId; id < curStakeId - 1; id ++) {
            PoolInfo memory pointPoolInfo = poolInfos[_rewardToken][id];
            PoolInfo memory nextPoolInfo = poolInfos[_rewardToken][id + 1];
            uint256 rewardsAmount = nextPoolInfo.poolAmount - pointPoolInfo.poolAmount;
            uint256 rewardRate = _getRewardRate(_rewardToken);
            rewardsAmount = rewardsAmount * rewardRate / FIXED_POINT;
            rewardsAmount = rewardsAmount * stakeInfo.stakedAmount / pointPoolInfo.totalStakedAmount;
            claimableAmount += rewardsAmount;
        }

        {
            PoolInfo memory poolInfo = poolInfos[_rewardToken][curStakeId - 1];
            uint256 totalPoolAmount = _getTotalPoolAmount(_rewardToken);
            uint256 rewardsAmount = totalPoolAmount - stakeInfo.currentPoolAmount;
            rewardsAmount = rewardsAmount * stakeInfo.stakedAmount / poolInfo.totalStakedAmount;
            claimableAmount += rewardsAmount;
        }

        return claimableAmount;
    }

    function _getRewardRate(address _rewardToken) internal view returns (uint16) {
        return IHexOneStakingMaster(stakingMaster).getRewardRate(_rewardToken);
    }

    function _getTotalPoolAmount(address _rewardToken) internal view returns (uint256) {
        return IHexOneStakingMaster(stakingMaster).getTotalPoolAmount(_rewardToken);
    }

    function _stakeStart(
        address _staker, 
        address _rewardToken, 
        uint256 _amount
    ) internal {
        uint256 curStakeId = stakeIds[_rewardToken];
        uint256 curPoolId = poolIds[_rewardToken];
        uint256 totalPoolAmount = _getTotalPoolAmount(_rewardToken);
        userStakeInfos[_rewardToken][_staker][curStakeId] = StakeInfo(
            block.timestamp, 
            _amount, 
            totalPoolAmount
        );
        stakedAmounts[_rewardToken] += _amount;
        poolInfos[_rewardToken][curPoolId] = PoolInfo(stakedAmounts[_rewardToken], totalPoolAmount);
        userStakeIds[_rewardToken][_staker].add(curStakeId);

        stakeIds[_rewardToken] = curStakeId + 1;
        poolIds[_rewardToken] = curPoolId + 1;
    }

    function _stakeEnd(
        address _staker, 
        address _rewardToken, 
        uint256 _stakeId
    ) internal returns (uint256) {
        require (userStakeIds[_rewardToken][_staker].contains(_stakeId), "not exist stakeId");
        uint256 curPoolId = poolIds[_rewardToken];
        uint256 claimableAmount = _getClaimableRewards(_staker, _rewardToken, _stakeId);
        userStakeIds[_rewardToken][_staker].remove(_stakeId);
        stakedAmounts[_rewardToken] -= userStakeInfos[_rewardToken][_staker][_stakeId].stakedAmount;
        poolInfos[_rewardToken][curPoolId] = PoolInfo(
            stakedAmounts[_rewardToken], 
            _getTotalPoolAmount(_rewardToken)
        );
        poolIds[_rewardToken] = curPoolId + 1;

        return claimableAmount;
    }
}