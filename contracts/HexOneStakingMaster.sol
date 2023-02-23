// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

import "./utils/TokenUtils.sol";
import "./interfaces/IHexOneStakingMaster.sol";

contract HexOneStakingMaster is 
    Ownable, 
    ERC721Holder,
    IHexOneStakingMaster 
{
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    mapping(address => EnumerableSet.AddressSet) private allowedRewardTokes;
    mapping(address => uint256) private poolAmounts;
    mapping(address => AllowedToken) private allowedTokens;

    address public hexOneProtocol;

    modifier onlyHexOneProtocol {
        require (msg.sender == hexOneProtocol, "only HexOneProtocol");
        _;
    }

    constructor () { }

    /// @inheritdoc IHexOneStakingMaster
    function setHexOneProtocol(address _hexOneProtocol) external onlyOwner override {
        require (_hexOneProtocol != address(0) ,"zero hexOneProtocol address");
        hexOneProtocol = _hexOneProtocol;
    }

    /// @inheritdoc IHexOneStakingMaster
    function setAllowedRewardTokens(
        address _baseToken, 
        address[] memory _rewardTokens, 
        bool _isAllow
    ) external onlyOwner override {
        uint256 length = _rewardTokens.length;
        require (length > 0, "invalid token array");
        require (allowedTokens[_baseToken].isEnable, "not allowed base token");

        for (uint256 i = 0; i < length; i ++) {
            address rewardToken = _rewardTokens[i];
            if (_isAllow) {
                require (!allowedRewardTokes[_baseToken].contains(rewardToken), "already added");
                allowedRewardTokes[_baseToken].add(rewardToken);
            } else  {
                require (allowedRewardTokes[_baseToken].contains(rewardToken), "already removed");
                allowedRewardTokes[_baseToken].remove(rewardToken);
            }
        }
    }

    /// @inheritdoc IHexOneStakingMaster
    function getAllowedRewardTokens(
        address _baseToken
    ) external view override returns (address[] memory) {
        if (allowedTokens[_baseToken].isEnable) {
            return allowedRewardTokes[_baseToken].values();
        }
        
        return new address[](0);
    }

    /// @inheritdoc IHexOneStakingMaster
    function setAllowTokens(
        address[] memory _tokens, 
        bool _isEnable
    ) external onlyOwner override {
        uint256 length = _tokens.length;
        require (length > 0, "invalid token array");

        for (uint256 i = 0; i < length; i ++) {
            allowedTokens[_tokens[i]].isEnable = _isEnable;
        }
    }

    /// @inheritdoc IHexOneStakingMaster
    function setRewardsRate(
        address[] memory _tokens, 
        uint16[] memory _rewardsRate
    ) external onlyOwner override {
        uint256 length = _tokens.length;
        require (length > 0, "invalid token array");
        require (length == _rewardsRate.length, "dismatched length");

        for (uint256 i = 0; i < length; i ++) {
            allowedTokens[_tokens[i]].rewardRate = _rewardsRate[i];
        }
    }

    /// @inheritdoc IHexOneStakingMaster
    function setStakingPools(
        address[] memory _tokens,
        address[] memory _stakingPools
    ) external onlyOwner override {
        uint256 length = _tokens.length;
        require (length > 0, "invalid token array");
        require (length == _stakingPools.length, "dismatched length");

        for (uint256 i = 0; i < length; i ++) {
            allowedTokens[_tokens[i]].stakingPool = _stakingPools[i];
        }
    }

    /// @inheritdoc IHexOneStakingMaster
    function stakeERC20Start(
        address _token,
        address _rewardToken,
        uint256 _amount
    ) external override {
        address sender = msg.sender;
        require (sender != address(0), "zero caller address");
        require (_token != address(0) && _rewardToken != address(0), "invalid token address");
        require (allowedTokens[_token].isEnable, "not allowed token");
        require (allowedTokens[_token].stakingPool != address(0), "no staking pool yet");
        require (allowedTokens[_rewardToken].rewardRate > 0, "reward rate is not set yet");
        require (allowedRewardTokes[_token].contains(_rewardToken), "invalid reward token");

        IERC20(_token).safeTransferFrom(sender, address(this), _amount);
        address stakingPool = allowedTokens[_token].stakingPool;
        IHexOneStaking(stakingPool).stakeERC20Start(sender, _rewardToken, _amount);
    }

    /// @inheritdoc IHexOneStakingMaster
    function stakeERC721Start(
        address _collection,
        address _rewardToken,
        uint256[] memory _tokenIds
    ) external override {
        address sender = msg.sender;
        require (sender != address(0), "zero caller address");
        require (_collection != address(0) && _rewardToken != address(0), "invalid token address");
        require (allowedTokens[_collection].isEnable, "not allowed token");
        require (allowedTokens[_collection].stakingPool != address(0), "no staking pool yet");
        require (allowedTokens[_rewardToken].rewardRate > 0, "reward rate is not set yet");
        require (allowedRewardTokes[_collection].contains(_rewardToken), "invalid reward token");
        uint256 length = _tokenIds.length;
        require (length > 0, "invalid tokenIds");

        for (uint256 i = 0; i < length; i ++) {
            uint256 tokenId = _tokenIds[i];
            IERC721(_collection).transferFrom(sender, address(this), tokenId);
        }

        address stakingPool = allowedTokens[_collection].stakingPool;
        IHexOneStaking(stakingPool).stakeERC721Start(sender, _rewardToken, _tokenIds);
    }

    /// @inheritdoc IHexOneStakingMaster
    function stakeERC20End(address _token, address _rewardToken, uint256 _stakeId) external override {
        address sender = msg.sender;
        require (sender != address(0), "zero caller address");
        require (allowedTokens[_token].isEnable, "not allowed token");
        require (allowedTokens[_token].stakingPool != address(0), "no staking pool yet");
        require (allowedRewardTokes[_token].contains(_rewardToken), "invalid reward token");

        address stakingPool = allowedTokens[_token].stakingPool;
        (uint256 stakedAmount, uint256 claimableAmount) = IHexOneStaking(stakingPool).stakeERC20End(
            sender, 
            _rewardToken, 
            _stakeId
        );

        IERC20(_token).safeTransfer(sender, stakedAmount);
        IERC20(_rewardToken).safeTransfer(sender, claimableAmount);
    }

    /// @inheritdoc IHexOneStakingMaster
    function stakeERC721End(address _collection, address _rewardToken, uint256 _stakeId) external override {
        address sender = msg.sender;
        require (sender != address(0), "zero caller address");
        require (allowedTokens[_collection].isEnable, "not allowed token");
        require (allowedTokens[_collection].stakingPool != address(0), "no staking pool yet");
        require (allowedRewardTokes[_collection].contains(_rewardToken), "invalid reward token");

        address stakingPool = allowedTokens[_collection].stakingPool;
        (uint256 claimableAmount, uint256[] memory tokenIds) = IHexOneStaking(stakingPool).stakeERC721End(sender, _rewardToken, _stakeId);
        IERC20(_rewardToken).safeTransfer(sender, claimableAmount);
        for (uint256 i = 0; i < tokenIds.length; i ++) {
            IERC721(_collection).transferFrom(address(this), sender, tokenIds[i]);
        }
    }

    /// @inheritdoc IHexOneStakingMaster
    function claimableRewards(
        address _staker, 
        address _stakeToken,
        address _rewardToken
    ) external view override returns (IHexOneStaking.Rewards[] memory) {
        require (_staker != address(0), "zero staker address");
        require (allowedTokens[_stakeToken].isEnable, "not allowed token");
        require (allowedTokens[_stakeToken].stakingPool != address(0), "no staking pool yet");
        require (allowedRewardTokes[_stakeToken].contains(_rewardToken), "invalid reward token");

        address stakingPool = allowedTokens[_stakeToken].stakingPool;
        return IHexOneStaking(stakingPool).claimableRewards(_staker, _rewardToken);
    }

    /// @inheritdoc IHexOneStakingMaster
    function updateRewards(address _token, uint256 _amount) external onlyHexOneProtocol override {
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        poolAmounts[_token] += _amount;
    }

    /// @inheritdoc IHexOneStakingMaster
    function getRewardRate(address _token) external view override returns (uint16) {
        return allowedTokens[_token].rewardRate;
    }

    /// @inheritdoc IHexOneStakingMaster
    function getTotalPoolAmount(address _rewardToken) external view override returns (uint256) {
        return poolAmounts[_rewardToken];
    }
}