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

    address public stakingMaster;

    uint256 public rewardsPerShare;

    uint256 public totalStakedAmount;

    bool public isNFTStaking;

    modifier onlyStakingMaster {
        require (msg.sender == stakingMaster, "no permission");
        _;
    }

    constructor (
        address _baseToken,
        address _stakingMaster,
        bool _isERC721
    ) {
        require (_baseToken != address(0), "zero baseToken address");
        require (_stakingMaster != address(0), "zero staking master address");
        stakingMaster = _stakingMaster;
        baseToken = _baseToken;
        isNFTStaking = _isERC721;
    }

    /// @inheritdoc IHexOneStaking
    function setStakingMaster(address _stakingMaster) external onlyOwner {
        require (_stakingMaster != address(0), "zero staking master address");
        stakingMaster = _stakingMaster;
    }

    /// @inheritdoc IHexOneStaking
    function stakeERC20Start(
        address _staker,
        uint256 _amount
    ) external onlyStakingMaster {
        require (!isNFTStaking, "not allowed to stake ERC20");
        
        totalStakedAmount += _amount;
        
    }

    /// @inheritdoc IHexOneStaking
    function stakeERC721Start(
        address _staker,
        uint256[] memory _tokenIds
    ) external {

    }

    /// @inheritdoc IHexOneStaking
    function stakeERC20End(
        address _staker,
        uint256 _stakeId
    ) external returns (uint256, uint256[] memory) {

    }

    /// @inheritdoc IHexOneStaking
    function stakeERC721End(
        address _staker,
        uint256 _stakeId
    ) external returns (uint256[] memory, uint256[] memory) {

    }

    /// @inheritdoc IHexOneStaking
    function claimableRewards(
        address _staker,
        address _rewardToken
    ) external view returns (Rewards[] memory) {

    }

    uint256[100] private __gap;
}