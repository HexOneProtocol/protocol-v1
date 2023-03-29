// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interfaces/IHexOneStaking.sol";
import "./utils/TokenUtils.sol";

contract HexOneStaking is
    Ownable,
    ERC721Holder,
    ReentrancyGuard,
    IHexOneStaking
{
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeERC20 for IERC20;

    EnumerableSet.AddressSet private allowedTokens;

    RewardsPool public rewardsPool;

    mapping(address => DistTokenWeight) public distTokenWeights;
    mapping(address => uint256) public lockedTokenAmounts;
    mapping(address => mapping(address => StakingInfo)) public stakingInfos;

    uint256 public hexRewardsRatePerShare;
    uint256 public hexitRewardsRatePerShare;
    uint256 public totalHexShareAmount; // decimals 18
    uint256 public totalHexitShareAmount; // decimals 18
    uint256 public stakingLaunchTime;

    address public hexOneProtocol;
    address public hexOneBootstrap;
    address public hexToken;
    address public hexitToken;

    uint16 public constant FIXED_POINT = 1000;
    uint16 public hexitDistRate;
    bool public stakingEnable;

    modifier onlyHexOneProtocol() {
        require(msg.sender == hexOneProtocol, "only HexOneProtocol");
        _;
    }

    constructor(address _hexToken, address _hexitToken, uint16 _hexitDistRate) {
        require(_hexToken != address(0), "zero hex token address");
        require(_hexitToken != address(0), "zero hexit token address");
        require(_hexitDistRate <= FIXED_POINT, "invalid hexit dist rate");

        hexitDistRate = _hexitDistRate;
        hexToken = _hexToken;
        hexitToken = _hexitToken;
    }

    function setBaseData(
        address _hexOneProtocol,
        address _hexOneBootstrap
    ) external onlyOwner {
        require(_hexOneProtocol != address(0), "zero hexOneProtocol address");
        require(_hexOneBootstrap != address(0), "zero hexOneBootstrap address");
        hexOneProtocol = _hexOneProtocol;
        hexOneBootstrap = _hexOneBootstrap;
    }

    function enableStaking() external onlyOwner {
        require(!stakingEnable, "already enabled");
        stakingEnable = true;
        stakingLaunchTime = block.timestamp;
        require(
            rewardsPool.hexPool > 0 && rewardsPool.hexitPool > 0,
            "no rewards pool"
        );
    }

    function purchaseHex(uint256 _amount) external override {
        address sender = msg.sender;
        require(sender == hexOneProtocol, "no permission");
        require(_amount > 0, "invalid purchase amount");
        IERC20(hexToken).safeTransferFrom(sender, address(this), _amount);
        rewardsPool.hexPool += _amount;
        _updateRewardsPerShareRate();
    }

    function purchaseHexit(uint256 _amount) external override {
        address sender = msg.sender;
        require(sender == hexOneBootstrap, "no permission");
        require(_amount > 0, "invalid purchase amount");
        IERC20(hexitToken).safeTransferFrom(sender, address(this), _amount);
        rewardsPool.hexitPool += _amount;
        _updateRewardsPerShareRate();
    }

    function addAllowedTokens(
        address[] memory _allowedTokens,
        DistTokenWeight[] memory _distTokenWeights
    ) external onlyOwner {
        uint256 length = _allowedTokens.length;
        require(length > 0, "invalid length array");
        require(length == _distTokenWeights.length, "mismatched array");

        for (uint256 i = 0; i < length; i++) {
            address allowedToken = _allowedTokens[i];
            DistTokenWeight memory distTokenWeight = _distTokenWeights[i];
            require(!allowedTokens.contains(allowedToken), "already added");
            require(
                distTokenWeight.hexDistRate == 0 ||
                    distTokenWeight.hexDistRate >= FIXED_POINT,
                "invalid hexDistRate"
            );
            require(
                distTokenWeight.hexitDistRate <= FIXED_POINT,
                "invalid hexitDistRate"
            );

            allowedTokens.add(allowedToken);
            distTokenWeights[allowedToken] = distTokenWeight;
        }
    }

    function removeAllowedTokens(
        address[] memory _allowedTokens
    ) external onlyOwner {
        uint256 length = _allowedTokens.length;
        require(length > 0, "invalid length array");

        for (uint256 i = 0; i < length; i++) {
            address allowedToken = _allowedTokens[i];
            require(
                allowedTokens.contains(allowedToken),
                "not exists allowedToken"
            );
            require(
                lockedTokenAmounts[allowedToken] == 0,
                "live staking pools exist"
            );
            allowedTokens.remove(allowedToken);
        }
    }

    function currentStakingDay() external view returns (uint256) {
        if (stakingLaunchTime == 0) {
            return 0;
        } else {
            return (block.timestamp - stakingLaunchTime) / 1 days + 1;
        }
    }

    function stakeToken(address _token, uint256 _amount) external nonReentrant {
        address sender = msg.sender;
        require(sender != address(0), "zero caller address");

        uint256 stakeAmount = _transferERC20(
            sender,
            address(this),
            _token,
            _amount
        );
        lockedTokenAmounts[_token] += stakeAmount;

        DistTokenWeight memory tokenWeight = distTokenWeights[_token];
        uint256 hexShare = (tokenWeight.hexDistRate * stakeAmount) /
            FIXED_POINT;
        hexShare = _convertToShare(_token, hexShare);
        totalHexShareAmount += hexShare;

        uint256 hexitShare = (tokenWeight.hexitDistRate * stakeAmount) /
            FIXED_POINT;
        hexitShare = _convertToShare(_token, hexitShare);
        totalHexitShareAmount += hexitShare;

        StakingInfo storage stakingInfo = stakingInfos[sender][_token];
        if (stakingInfo.stakedTime == 0) {
            stakingInfo.stakedTime = block.timestamp;
        }
        stakingInfo.stakedAmount += stakeAmount;
        stakingInfo.hexShareAmount += hexShare;
        stakingInfo.hexitShareAmount += hexitShare;
        if (stakingInfo.stakedToken == address(0)) {
            stakingInfo.stakedToken = _token;
        }
        if (stakingInfo.staker == address(0)) {
            stakingInfo.staker = sender;
        }

        _updateRewardsPerShareRate();
    }

    function claimableRewardsAmount(
        address _user,
        address _token
    ) external view returns (uint256 hexAmount, uint256 hexitAmount) {
        require(allowedTokens.contains(_token), "not allowed token");
        return _calcRewardsAmount(_user, _token);
    }

    function claimRewards(address _user, address _token) external nonReentrant {
        StakingInfo storage info = stakingInfos[_user][_token];
        require(allowedTokens.contains(_token), "not allowed token");
        require(info.stakedTime > 0, "no staking pool");

        uint256 hexAmount = (info.hexShareAmount * hexRewardsRatePerShare) /
            totalHexShareAmount;
        uint256 hexitAmount = (info.hexitShareAmount *
            hexitRewardsRatePerShare) / totalHexitShareAmount;

        hexAmount = hexAmount / 10 ** 10 - info.claimedHexAmount;
        hexitAmount -= info.claimedHexitAmount;

        require(hexAmount > 0 || hexitAmount > 0, "no rewards");
        info.claimedHexAmount += hexAmount;
        info.claimedHexitAmount += hexitAmount;

        if (hexAmount > 0) {
            IERC20(hexToken).safeTransfer(info.staker, hexAmount);
        }

        if (hexitAmount > 0) {
            IERC20(hexitToken).safeTransfer(info.staker, hexitAmount);
        }
    }

    function unstake(
        address _user,
        address _token,
        uint256 _unstakeAmount
    ) external nonReentrant {
        StakingInfo storage info = stakingInfos[_user][_token];
        DistTokenWeight memory tokenWeight = distTokenWeights[_token];
        require(allowedTokens.contains(_token), "not allowed token");
        require(info.stakedTime > 0, "no staking pool");
        require(
            _unstakeAmount > 0 && info.stakedAmount >= _unstakeAmount,
            "invalid unstake amount"
        );

        uint256 hexShareAmount = (_unstakeAmount * tokenWeight.hexDistRate) /
            FIXED_POINT;
        uint256 hexitShareAmount = (_unstakeAmount *
            tokenWeight.hexitDistRate) / FIXED_POINT;
        hexShareAmount = _convertToShare(_token, hexShareAmount);

        uint256 hexAmount = (hexShareAmount * hexRewardsRatePerShare) /
            totalHexShareAmount;
        uint256 hexitAmount = (hexitShareAmount * hexitRewardsRatePerShare) /
            totalHexitShareAmount;

        hexAmount = hexAmount / 10 ** 10 - info.claimedHexAmount;
        hexitAmount -= info.claimedHexitAmount;

        if (hexAmount > 0) {
            IERC20(hexToken).safeTransfer(info.staker, hexAmount);
        }

        if (hexitAmount > 0) {
            IERC20(hexitToken).safeTransfer(info.staker, hexitAmount);
        }

        info.claimedHexAmount += hexAmount;
        info.claimedHexitAmount += hexitAmount;
        info.hexShareAmount -= hexShareAmount;
        info.hexitShareAmount -= hexitShareAmount;

        totalHexShareAmount -= hexShareAmount;
        totalHexitShareAmount -= hexitShareAmount;

        if (info.hexShareAmount == 0 && info.hexitShareAmount == 0) {
            info.stakedTime = 0;
        }

        lockedTokenAmounts[info.stakedToken] -= _unstakeAmount;
        IERC20(info.stakedToken).safeTransfer(_user, _unstakeAmount);

        _updateRewardsPerShareRate();
    }

    function getUserStakingStatus(
        address _user
    ) external view returns (UserStakingStatus[] memory) {
        uint256 allowedTokenCnt = allowedTokens.length();
        UserStakingStatus[] memory status = new UserStakingStatus[](
            allowedTokenCnt
        );

        for (uint256 i = 0; i < allowedTokenCnt; i++) {
            address token = allowedTokens.at(i);
            StakingInfo memory info = stakingInfos[_user][token];
            DistTokenWeight memory tokenWeight = distTokenWeights[token];
            (
                uint256 claimableHexAmount,
                uint256 claimableHexitAmount
            ) = _calcRewardsAmount(_user, token);

            (uint16 hexAPR, uint16 hexitAPR) = _calcAPR(token);

            status[i] = UserStakingStatus({
                token: token,
                stakedAmount: info.stakedAmount,
                earnedHexAmount: info.claimedHexAmount,
                earnedHexitAmount: info.claimedHexitAmount,
                claimableHexAmount: claimableHexAmount,
                claimableHexitAmount: claimableHexitAmount,
                stakedTime: (block.timestamp - info.stakedAmount) / 1 days,
                liquidity: 0,
                shareOfPool: uint16(
                    (info.stakedAmount * FIXED_POINT) /
                        lockedTokenAmounts[token]
                ),
                hexAPR: hexAPR,
                hexitAPR: hexitAPR,
                hexMultiplier: tokenWeight.hexDistRate,
                hexitMultiplier: tokenWeight.hexitDistRate
            });
        }

        return status;
    }

    function _calcRewardsAmount(
        address _user,
        address _token
    ) internal view returns (uint256 hexAmount, uint256 hexitAmount) {
        StakingInfo memory info = stakingInfos[_user][_token];
        if (info.stakedTime == 0) {
            return (0, 0);
        }

        hexAmount =
            (info.hexShareAmount * hexRewardsRatePerShare) /
            totalHexShareAmount;
        hexitAmount =
            (info.hexitShareAmount * hexitRewardsRatePerShare) /
            totalHexitShareAmount;

        hexAmount = hexAmount / 10 ** 10 - info.claimedHexAmount;
        hexitAmount -= info.claimedHexitAmount;
    }

    function _updateRewardsPerShareRate() internal {
        if (totalHexShareAmount == 0 && totalHexitShareAmount == 0) {
            return;
        }

        uint256 curHexPool = IERC20(hexToken).balanceOf(address(this));
        uint256 curHexitPool = IERC20(hexitToken).balanceOf(address(this));
        curHexitPool -= rewardsPool.distributedHexit;

        uint256 hexAmountForDist = curHexPool - rewardsPool.distributedHex;
        uint256 hexitAmountForDist = (curHexitPool * hexitDistRate) /
            FIXED_POINT;

        hexRewardsRatePerShare +=
            (hexAmountForDist * 10 ** 28) /
            totalHexShareAmount;
        hexitRewardsRatePerShare +=
            (hexitAmountForDist * 10 ** 18) /
            totalHexitShareAmount;

        rewardsPool.distributedHex += hexAmountForDist;
        rewardsPool.distributedHexit += hexitAmountForDist;
    }

    function _transferERC20(
        address _from,
        address _to,
        address _token,
        uint256 _amount
    ) internal returns (uint256) {
        require(_token != address(0), "invalid token address");
        require(_amount > 0, "invalid staking amount");
        require(allowedTokens.contains(_token), "not allowed token");

        uint256 beforeBal = IERC20(_token).balanceOf(_to);
        IERC20(_token).safeTransferFrom(_from, _to, _amount);
        uint256 afterBal = IERC20(_token).balanceOf(_to);

        return afterBal - beforeBal;
    }

    function _calcAPR(
        address _token
    ) internal view returns (uint16 hexAPR, uint16 hexitAPR) {
        /// total rewards for token / total deposited token %
        uint256 depositedAmount = lockedTokenAmounts[_token];
        DistTokenWeight memory tokenWeight = distTokenWeights[_token];
        uint256 hexShare = (depositedAmount * tokenWeight.hexDistRate) /
            FIXED_POINT;
        uint256 hexitShare = (depositedAmount * tokenWeight.hexitDistRate) /
            FIXED_POINT;

        uint256 distributedHex = rewardsPool.distributedHex;
        uint256 distributedHexit = rewardsPool.distributedHexit;

        return (
            uint16((distributedHex * 10 ** 18) / hexShare),
            uint16((distributedHexit * 10 ** 18) / hexitShare)
        );
    }

    function _convertToShare(
        address _token,
        uint256 _amount
    ) internal view returns (uint256) {
        uint8 tokenDecimals = TokenUtils.expectDecimals(_token);
        if (tokenDecimals >= 18) {
            return _amount / (10 ** (tokenDecimals - 18));
        } else {
            return _amount * (10 ** (18 - tokenDecimals));
        }
    }
}
