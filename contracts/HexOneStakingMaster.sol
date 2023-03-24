// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

import "./utils/TokenUtils.sol";
import "./interfaces/IHexOneStakingMaster.sol";

contract HexOneStakingMaster is 
    OwnableUpgradeable, 
    ERC721Holder,
    IHexOneStakingMaster 
{
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    struct RewardRate {
        uint256 lastUpdatedTime;
        uint256 rewardRatePerShare;
        uint256 lastPoolAmount;
        uint256 lastExcludedAmount;
    }

    mapping(address => EnumerableSet.AddressSet) private allowedTokensByRewardToken;
    mapping(address => AllowedToken) private allowedTokens;
    mapping(address => uint16) public totalRewardWeights;
    mapping(address => uint256) public stakingStartTimes;
    mapping(address => RewardRate) public rewardRatesPerShare;

    EnumerableSet.AddressSet private allowedTokenAddrs;
    address public hexOneProtocol;
    address public feeReceiver;
    uint16 public withdrawFeeRate;
    uint16 public distRate;
    uint16 public FIXED_POINT;

    modifier onlyHexOneProtocol {
        require (msg.sender == hexOneProtocol, "only HexOneProtocol");
        _;
    }

    constructor () { 
        _disableInitializers();
    }

    function initialize(
        address _feeReceiver,
        uint16 _withdrawFeeRate
    ) public initializer {
        FIXED_POINT = 1000;
        require (_feeReceiver != address(0), "zero feeReceiver address");
        require (_withdrawFeeRate <= FIXED_POINT / 2, "exceeds to max fee rate");

        feeReceiver = _feeReceiver;
        withdrawFeeRate = _withdrawFeeRate;
        __Ownable_init();
    }

    /// @inheritdoc IHexOneStakingMaster
    function setFeeReceiver(
        address _feeReceiver
    ) external onlyOwner override {
        require (_feeReceiver != address(0), "zero feeReceiver address");
        feeReceiver = _feeReceiver;
    }

    /// @inheritdoc IHexOneStakingMaster
    function setWithdrawFeeRate(
        uint16 _feeRate
    ) external onlyOwner override {
        require (_feeRate <= FIXED_POINT / 2, "exceeds to max fee rate");
        withdrawFeeRate = _feeRate;
    }

    /// @inheritdoc IHexOneStakingMaster
    function setHexOneProtocol(address _hexOneProtocol) external onlyOwner override {
        require (_hexOneProtocol != address(0) ,"zero hexOneProtocol address");
        hexOneProtocol = _hexOneProtocol;
    }

    /// @inheritdoc IHexOneStakingMaster
    function setAllowTokens(
        address _baseToken,
        address _stakingPool,
        address[] memory _rewardTokens,
        uint16[] memory _rewardTokenWeights
    ) external onlyOwner override {
        uint256 length = _rewardTokens.length;
        require (_stakingPool != address(0), "zero staking pool address");
        require (length > 0, "invalid token array");
        require (length == _rewardTokenWeights.length, "dismatch array");

        AllowedToken storage info = allowedTokens[_baseToken];
        delete info.rewardTokens;
        delete info.rewardTokenWeights;
        for (uint256 i = 0; i < length; i ++) {
            address rewardToken = _rewardTokens[i];
            uint16 rewardTokenWeight = _rewardTokenWeights[i];
            require (rewardToken != address(0), "zero reward token address");
            require (rewardTokenWeight >= 1, "invalid reward token weight");
            info.rewardTokens.push(rewardToken);
            info.rewardTokenWeights.push(rewardTokenWeight);
            totalRewardWeights[rewardToken] += rewardTokenWeight;

            _updateRewardRatePerShare(rewardToken);
        }

        info.isEnable = true;
        info.stakingPool = _stakingPool;

        if (!allowedTokenAddrs.contains(_baseToken)) {
            allowedTokenAddrs.add(_baseToken);
        }
    }

    /// @inheritdoc IHexOneStakingMaster
    function stakeERC20Start(
        address _token,
        uint256 _amount
    ) external override {
        address sender = msg.sender;
        AllowedToken memory info = allowedTokens[_token];
        require (sender != address(0), "zero caller address");
        require (_token != address(0), "invalid token address");
        require (_amount > 0, "invalid staking amount");
        require (info.isEnable, "not allowed token");
        
        for (uint256 i = 0; i < info.rewardTokens.length; i ++) {
            address rewardToken = info.rewardTokens[i];
            require (
                stakingStartTimes[rewardToken] > 0 ||
                IERC20(rewardToken).balanceOf(address(this)) > 0, 
                "no reward pool"
            );
            if (stakingStartTimes[rewardToken] == 0) {
                stakingStartTimes[rewardToken] = block.timestamp;
            }
        }

        IERC20(_token).safeTransferFrom(sender, address(this), _amount);
        address stakingPool = allowedTokens[_token].stakingPool;
        IHexOneStaking(stakingPool).stakeERC20Start(sender, _amount);
    }

    /// @inheritdoc IHexOneStakingMaster
    function stakeERC721Start(
        address _collection,
        uint256[] memory _tokenIds
    ) external override {
        address sender = msg.sender;
        AllowedToken memory info = allowedTokens[_collection];
        require (sender != address(0), "zero caller address");
        require (_collection != address(0), "invalid token address");
        require (info.isEnable, "not allowed token");
        uint256 length = _tokenIds.length;
        require (length > 0, "invalid tokenIds");

        for (uint256 i = 0; i < length; i ++) {
            uint256 tokenId = _tokenIds[i];
            IERC721(_collection).transferFrom(sender, address(this), tokenId);
        }

        for (uint256 i = 0; i < info.rewardTokens.length; i ++) {
            address rewardToken = info.rewardTokens[i];
            require (
                stakingStartTimes[rewardToken] > 0 ||
                IERC20(rewardToken).balanceOf(address(this)) > 0, 
                "no reward pool"
            );
            if (stakingStartTimes[rewardToken] == 0) {
                stakingStartTimes[rewardToken] = block.timestamp;
            }
        }

        address stakingPool = allowedTokens[_collection].stakingPool;
        IHexOneStaking(stakingPool).stakeERC721Start(sender, _tokenIds);
    }

    /// @inheritdoc IHexOneStakingMaster
    function stakeERC20End(address _token, uint256 _stakeId) external override {
        address sender = msg.sender;
        require (sender != address(0), "zero caller address");

        address stakingPool = allowedTokens[_token].stakingPool;
        (uint256 stakedAmount, uint256[] memory claimableAmounts) = IHexOneStaking(stakingPool).stakeERC20End(
            sender, 
            _stakeId
        );

        uint256 length = claimableAmounts.length;
        for (uint256 i = 0; i < length; i ++) {
            address rewardToken = allowedTokens[_token].rewardTokens[i];
            uint256 claimableAmount = claimableAmounts[i];
            uint256 feeAmount = claimableAmount * withdrawFeeRate / FIXED_POINT;
            claimableAmount -= feeAmount;
            IERC20(rewardToken).safeTransfer(sender, claimableAmount);

            if (feeAmount > 0) {
                IERC20(rewardToken).safeTransfer(feeReceiver, feeAmount);
            }
        }

        IERC20(_token).safeTransfer(sender, stakedAmount);
    }

    /// @inheritdoc IHexOneStakingMaster
    function stakeERC721End(address _collection, uint256 _stakeId) external override {
        address sender = msg.sender;
        require (sender != address(0), "zero caller address");

        address stakingPool = allowedTokens[_collection].stakingPool;
        (
            uint256[] memory claimableAmounts, 
            uint256[] memory tokenIds
        ) = IHexOneStaking(stakingPool).stakeERC721End(sender, _stakeId);

        uint256 length = claimableAmounts.length;
        for (uint256 i = 0; i < length; i ++) {
            address rewardToken = allowedTokens[_collection].rewardTokens[i];
            uint256 claimableAmount = claimableAmounts[i];
            uint256 feeAmount = claimableAmount * withdrawFeeRate / FIXED_POINT;
            claimableAmount -= feeAmount;
            IERC20(rewardToken).safeTransfer(sender, claimableAmount);

            if (feeAmount > 0) {
                IERC20(rewardToken).safeTransfer(feeReceiver, feeAmount);
            }
        }
        
        for (uint256 i = 0; i < tokenIds.length; i ++) {
            IERC721(_collection).transferFrom(address(this), sender, tokenIds[i]);
        }
    }

    /// @inheritdoc IHexOneStakingMaster
    function updateRewards(address _token, uint256 _amount) external onlyHexOneProtocol override {
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        if (stakingStartTimes[_token] == 0) {
            stakingStartTimes[_token] = block.timestamp;
        }
        _updateRewardRatePerShare(_token);
    }

    function _updateRewardRatePerShare(address _token) internal {
        RewardRate storage rateInfo = rewardRatesPerShare[_token];
        uint256 lastUpdatedTime = rateInfo.lastUpdatedTime;
        uint256 curTime = block.timestamp;
        uint256 distAmount;
        uint256 curBal;
        if (lastUpdatedTime == 0) {
            curBal = IERC20(_token).balanceOf(address(this));
            rateInfo.lastUpdatedTime = curTime;
            distAmount = curBal * distRate / FIXED_POINT;
            rateInfo.rewardRatePerShare = distAmount / totalRewardWeights[_token];
            rateInfo.lastPoolAmount = curBal - distAmount;
            rateInfo.lastExcludedAmount = distAmount;
            return;
        }

        uint256 lastPoolAmount = rateInfo.lastPoolAmount;
        uint256 rewardRatePerShare = rateInfo.rewardRatePerShare;
        uint256 lastExcludedAmount = rateInfo.lastExcludedAmount;
        
        while (lastUpdatedTime <= curTime) {
            distAmount = lastPoolAmount * distRate / FIXED_POINT;
            lastExcludedAmount += distAmount;
            rewardRatePerShare += (distAmount / totalRewardWeights[_token]);
            lastPoolAmount -= distAmount;
            lastUpdatedTime += 1 days;
        }

        curBal = IERC20(_token).balanceOf(address(this));
        curBal -= lastExcludedAmount;
        distAmount = curBal * distRate / FIXED_POINT;
        rewardRatePerShare += (distAmount / totalRewardWeights[_token]);
        curBal -= distAmount;
        lastExcludedAmount += distAmount;

        rateInfo.lastUpdatedTime = curTime;
        rateInfo.rewardRatePerShare = rewardRatePerShare;
        rateInfo.lastPoolAmount = curBal;
        rateInfo.lastExcludedAmount = lastExcludedAmount;
    }

    uint256[100] private __gap;
}