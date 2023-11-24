// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Dependencies
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts//security/ReentrancyGuard.sol";

// Interfaces
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IHexOneStaking} from "./interfaces/IHexOneStaking.sol";

// Utils
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./utils/TokenUtils.sol";

abstract contract HexOneStaking is Ownable, ReentrancyGuard, IHexOneStaking {
    /// @dev using EnumerableSet OZ library for addresses
    using EnumerableSet for EnumerableSet.AddressSet;
    /// @dev using safeERC20 OZ library
    using SafeERC20 for IERC20;

    /// @dev tokens that are allowed to be staked.
    EnumerableSet.AddressSet private allowedTokens;

    /// @dev keeps track of the HEX and HEXIT pool
    RewardsPool public rewardsPool;
    /// @dev total number of HEX pool deposit shares with 18 decimals precision
    uint256 public totalHexSharesAmount;
    /// @dev total number of HEXIT pool deposit shares with 18 decimals precision
    uint256 public totalHexitSharesAmount;
    /// @dev rate of HEX rewards to be distributed per share with 18 decimals precision
    uint256 public hexRewardsPerShareRate;
    /// @dev rate of HEXIT rewards to be distributed per share with 18 decimals precision
    uint256 public hexitRewardsPerShareRate;
    /// @dev HEX pool distribution rate per day in basis points
    uint16 public hexDistRate;
    /// @dev HEXIT pool distribution rate per day in basis points
    uint16 public hexitDistRate;

    /// @dev fixed point for basis points
    uint16 public constant FIXED_POINT = 1000;

    /// @dev address of the HexOneProtocol
    address public hexOneProtocol;
    /// @dev address of the HexOneBootstrap
    address public hexOneBootstrap;
    /// @dev address of the HEX token
    address public hexToken;
    /// @dev address of the HEXIT token
    address public hexitToken;

    /// @dev the timestamp in which the staking launched
    uint256 public stakingLaunchTime;
    /// @dev tracks if the stake is enabled or not
    bool public stakingEnable;

    /// @dev allowed tokens => pools distribution rate in bps
    /// @notice represents the percentage of the pool that is distributed to the
    /// staker based on the token the staker deposited.
    mapping(address => DistTokenWeight) public distTokenWeights;
    /// @dev user => allowed token => StakingInfo
    mapping(address => mapping(address => StakingInfo)) public stakingInfos;
    /// @dev allowed tokens => total amount of token staked.
    mapping(address => uint256) public totalAmountStaked;

    /// @dev checks if the sender is the HexOneProtocol
    modifier onlyHexOneProtocol() {
        require(msg.sender == hexOneProtocol, "Only HexOneProtocol");
        _;
    }

    /// @dev checks if the sender is the HexOneBootstrap
    modifier onlyHexOneBootstrap() {
        require(msg.sender == hexOneBootstrap, "Only HexOneBootstrap");
        _;
    }

    /// @dev checks if the staking is enabled
    modifier onlyWhenStakingEnable() {
        require(stakingEnable, "Staking not enabled");
        _;
    }

    /// @param _hex address of the HEX token.
    /// @param _hexit address of the HEXIT token.
    /// @param _hexDistRate HEX pool distribution of HEX in bps.
    /// @param _hexitDistRate HEXIT pool distribution in bps.
    constructor(address _hex, address _hexit, uint16 _hexDistRate, uint16 _hexitDistRate) {
        require(_hex != address(0), "Invalid address");
        require(_hexit != address(0), "Invalid address");
        require(_hexDistRate <= FIXED_POINT, "Invalid distribution rate");
        require(_hexitDistRate <= FIXED_POINT, "Invalid distribution rate");

        hexDistRate = _hexDistRate;
        hexitDistRate = _hexitDistRate;
        hexToken = _hex;
        hexitToken = _hexit;
    }

    /// @dev set the address of the Protocol and Bootstrap
    /// @param _hexOneProtocol address of the HexOneProtocol.
    /// @param _hexOneBootstrap address of the HexOneBootstrap.
    function setBaseData(address _hexOneProtocol, address _hexOneBootstrap) external onlyOwner {
        require(_hexOneProtocol != address(0), "Invalid address");
        require(_hexOneBootstrap != address(0), "Invalid address");
        hexOneProtocol = _hexOneProtocol;
        hexOneBootstrap = _hexOneBootstrap;
    }

    /// @dev enable staking.
    /// @notice staking can only be enabled if there are HEX and HEXIT rewards to be distributed.
    function enableStaking() external onlyOwner {
        require(!stakingEnable, "Staking already enabled");
        require(rewardsPool.hexPool > 0 && rewardsPool.hexitPool > 0, "No rewards to distribute");
        stakingEnable = true;
        stakingLaunchTime = block.timestamp;
    }

    /// @dev add token to the allowed tokens list with their respective share of the pool rewards.
    /// @param _tokens address of the tokens to be added.
    /// @param _distTokenWeights pool distribution for the token in bps
    function addAllowedTokens(address[] calldata _tokens, DistTokenWeight[] calldata _distTokenWeights)
        external
        onlyOwner
    {
        uint256 length = _tokens.length;
        require(length > 0, "Zero length array");
        require(length == _distTokenWeights.length, "Mismatched array");

        for (uint256 i = 0; i < length; i++) {
            address allowedToken = _tokens[i];
            DistTokenWeight memory distTokenWeight = _distTokenWeights[i];
            require(!allowedTokens.contains(allowedToken), "already added");
            require(
                distTokenWeight.hexDistRate != 0 && distTokenWeight.hexDistRate <= FIXED_POINT,
                "Invalid distribution rate"
            );
            require(
                distTokenWeight.hexitDistRate != 0 && distTokenWeight.hexitDistRate <= FIXED_POINT,
                "Invalid distribution rate"
            );

            allowedTokens.add(allowedToken);
            distTokenWeights[allowedToken] = distTokenWeight;
        }
    }

    /// @dev remove tokens from the allowed tokens list.
    /// @notice token can only be removed if there is no amount of that token staked.
    /// @param _tokens addresses of the tokens to be removed.
    function removeAllowedTokens(address[] calldata _tokens) external onlyOwner {
        uint256 length = _tokens.length;
        require(length > 0, "invalid length array");

        for (uint256 i = 0; i < length; i++) {
            address allowedToken = _tokens[i];
            require(allowedTokens.contains(allowedToken), "not exists allowedToken");
            require(totalAmountStaked[allowedToken] == 0, "live staking pools exist");
            allowedTokens.remove(allowedToken);
        }
    }

    /// @dev called by the HexOneProtocol to deposit HEX in the staking pool.
    /// @param _amount of HEX tokens being added by the protocol.
    function purchaseHex(uint256 _amount) external onlyHexOneProtocol {
        require(_amount > 0, "Invalid purchase amount");

        rewardsPool.hexPool += _amount;
        _updateRewardsPerShareRate();

        IERC20(hexToken).safeTransferFrom(msg.sender, address(this), _amount);
    }

    /// @dev called by the bootstrap to deposit HEXIT in the staking pool.
    /// @param _amount of HEXIT tokens being added by the bootstrap.
    function purchaseHexit(uint256 _amount) external onlyHexOneBootstrap {
        require(_amount > 0, "Invalid purchase amount");

        rewardsPool.hexitPool += _amount;
        _updateRewardsPerShareRate();

        IERC20(hexitToken).safeTransferFrom(msg.sender, address(this), _amount);
    }

    /// @dev stake HEX1, HEXIT or HEX1/DAI LP.
    /// @param _token address of the token being staked.
    /// @param _amount amount of token being staked.
    function stakeToken(address _token, uint256 _amount) external nonReentrant onlyWhenStakingEnable {
        require(allowedTokens.contains(_token), "Token not allowed");
        require(_amount > 0, "Invalid staking amount");

        // transfer the tokens from the sender this contract
        uint256 stakeAmount = _transferERC20(msg.sender, address(this), _token, _amount);

        // update the total amount of token staked
        totalAmountStaked[_token] += stakeAmount;

        // get the respective pool distribution for that token in bps.
        DistTokenWeight memory tokenWeight = distTokenWeights[_token];

        // update the total amount of HEX shares
        uint256 hexShare = (tokenWeight.hexDistRate * stakeAmount) / FIXED_POINT;
        hexShare = _convertToShare(_token, hexShare);
        totalHexSharesAmount += hexShare;

        // update the total amount of HEXIT shares
        uint256 hexitShare = (tokenWeight.hexitDistRate * stakeAmount) / FIXED_POINT;
        hexitShare = _convertToShare(_token, hexitShare);
        totalHexitSharesAmount += hexitShare;

        // update the information of the stake
        StakingInfo storage stakingInfo = stakingInfos[msg.sender][_token];
        if (stakingInfo.initStakeTime == 0) {
            stakingInfo.initStakeTime = block.timestamp;
        }
        if (stakingInfo.lastTimeClaimed == 0) {
            stakingInfo.lastTimeClaimed = block.timestamp;
        }
        stakingInfo.stakedAmount += stakeAmount;
        stakingInfo.hexShareAmount += hexShare;
        stakingInfo.hexitShareAmount += hexitShare;
        if (stakingInfo.stakedToken == address(0)) {
            stakingInfo.stakedToken = _token;
        }
        if (stakingInfo.staker == address(0)) {
            stakingInfo.staker = msg.sender;
        }

        // update the rate rewards per share of HEX and HEXIT pools
        _updateRewardsPerShareRate();
    }

    /// @dev unstake HEX1, HEXIT or HEX1/DAI LP and collect the respective fees.
    /// @param _token address of the token being unstaked.
    /// @param _unstakeAmount amount of token to be unstaked.
    function unstake(address _token, uint256 _unstakeAmount) external nonReentrant onlyWhenStakingEnable {
        StakingInfo storage info = stakingInfos[msg.sender][_token];
        DistTokenWeight memory tokenWeight = distTokenWeights[_token];
        require(allowedTokens.contains(_token), "Token not allowed");
        require(info.initStakeTime > 0, "No staking available");
        require(_unstakeAmount > 0 && info.stakedAmount >= _unstakeAmount, "Invalid unstake amount");

        // calculate the amount of HEX shares to be withdrawn
        uint256 hexShareAmount = (_unstakeAmount * tokenWeight.hexDistRate) / FIXED_POINT;
        hexShareAmount = _convertToShare(_token, hexShareAmount);

        // calculate the amount of HEXIT shares to be withdrawn
        uint256 hexitShareAmount = (_unstakeAmount * tokenWeight.hexitDistRate) / FIXED_POINT;
        hexitShareAmount = _convertToShare(_token, hexitShareAmount);

        // calculate the rewards that are claimable by the user since he last claimed
        (uint256 hexAmount, uint256 hexitAmount) = _calcRewardsAmount(msg.sender, _token);

        // update the staking info of the user for token
        info.lastTimeClaimed = block.timestamp;
        info.claimedHexAmount += hexAmount;
        info.claimedHexitAmount += hexitAmount;
        info.hexShareAmount -= hexShareAmount;
        info.hexitShareAmount -= hexitShareAmount;
        info.stakedAmount -= _unstakeAmount;

        // if the amount of HEXIT and HEX shares the users has are zero then
        // it's because the user unstaked all, so the stakeInitTime is now 0
        if (info.hexShareAmount == 0 && info.hexitShareAmount == 0) {
            info.initStakeTime = 0;
        }

        // update the amount of HEX and HEXIT distributed by the pools
        rewardsPool.distributedHex += hexAmount;
        rewardsPool.distributedHexit += hexitAmount;

        // update the total amount of HEX and HEXIT pool shares
        totalHexSharesAmount -= hexShareAmount;
        totalHexitSharesAmount -= hexitShareAmount;

        // update the total amount staked of the token
        totalAmountStaked[info.stakedToken] -= _unstakeAmount;

        // update the rate of rewards per share
        _updateRewardsPerShareRate();

        // transfer the HEX rewards to the user
        if (hexAmount > 0) {
            IERC20(hexToken).safeTransfer(info.staker, hexAmount);
        }

        // transfer the HEXIT rewards to the user
        if (hexitAmount > 0) {
            IERC20(hexitToken).safeTransfer(info.staker, hexitAmount);
        }

        // transfer the staked token back to the sender
        IERC20(info.stakedToken).safeTransfer(msg.sender, _unstakeAmount);
    }

    /// @dev claim rewards generated from a specific stake
    /// @param _token address of the token to claim rewards from, tokens: HEX1, HEXIT or HEX1/DAI LP
    function claimRewards(address _token) external nonReentrant onlyWhenStakingEnable {
        StakingInfo storage info = stakingInfos[msg.sender][_token];
        require(allowedTokens.contains(_token), "Token not allowed");
        require(info.initStakeTime > 0, "No available staking");

        // check if there are any rewards to claim
        (uint256 hexAmount, uint256 hexitAmount) = _calcRewardsAmount(msg.sender, _token);
        require(hexAmount > 0 || hexitAmount > 0, "No rewards to claim");

        // update the staking information
        info.lastTimeClaimed = block.timestamp;
        info.claimedHexAmount += hexAmount;
        info.claimedHexitAmount += hexitAmount;

        // update the amount of HEX and HEXIT distributed by the pools
        rewardsPool.distributedHex += hexAmount;
        rewardsPool.distributedHexit += hexitAmount;

        // transfer the rewards to the user
        if (hexAmount > 0) {
            IERC20(hexToken).safeTransfer(info.staker, hexAmount);
        }

        if (hexitAmount > 0) {
            IERC20(hexitToken).safeTransfer(info.staker, hexitAmount);
        }
    }

    /// @dev returns the amount of days that passed since the staking started.
    function currentStakingDay() external view returns (uint256) {
        if (stakingLaunchTime == 0) {
            return 0;
        } else {
            return (block.timestamp - stakingLaunchTime) / 1 days + 1;
        }
    }

    /// @dev amount of rewards available to claim for a certain stake
    /// @param _user address of the user
    /// @param _token address of the token, can be HEX1, HEXIT or HEX1/DAI
    function claimableRewardsAmount(address _user, address _token)
        external
        view
        returns (uint256 hexAmount, uint256 hexitAmount)
    {
        require(allowedTokens.contains(_token), "not allowed token");
        return _calcRewardsAmount(_user, _token);
    }

    /// @dev updates the rate of HEX and HEXIT rewards per share.
    /// @notice the rewards per share are calculated by dividing the amount available
    /// to distribute (1% distribution rate) with the total amount of shares.
    function _updateRewardsPerShareRate() internal {
        // if there are no pool shares then no one has deposited, which means
        // there is no need to update the rate of rewards per share of the pool.
        if (totalHexSharesAmount == 0 && totalHexitSharesAmount == 0) {
            return;
        }

        // calculate the current amount of HEX and HEXIT in the pool
        uint256 curHexPool = rewardsPool.hexPool - rewardsPool.distributedHex;
        uint256 curHexitPool = rewardsPool.hexitPool - rewardsPool.distributedHexit;

        // calculate the amount of HEX and HEXIT to be distributed based on the distribution rate
        uint256 hexAmountForDist = (curHexPool * hexDistRate) / FIXED_POINT;
        uint256 hexitAmountForDist = (curHexitPool * hexitDistRate) / FIXED_POINT;

        // update the rate of HEX rewards per share, this is represented as 18 decimals.
        if (totalHexSharesAmount > 0) {
            hexRewardsPerShareRate += (hexAmountForDist * 10 ** 28) / totalHexSharesAmount;
        }

        // update the rate of HEXIT rewards per share, this is represented as 18 decimals.
        if (totalHexitSharesAmount > 0) {
            hexitRewardsPerShareRate += (hexitAmountForDist * 10 ** 18) / totalHexitSharesAmount;
        }
    }

    /// @dev calculates the HEX and HEXIT rewards to distribute
    /// @param _user address of the user
    /// @param _token address of the token
    function _calcRewardsAmount(address _user, address _token)
        internal
        view
        returns (uint256 hexAmount, uint256 hexitAmount)
    {
        StakingInfo memory info = stakingInfos[_user][_token];
        if (info.initStakeTime == 0) {
            return (0, 0);
        }

        // calculate the elapsed time since stake was last claimed
        uint256 elapsedTime = block.timestamp - info.lastTimeClaimed;

        // calculate the amount of HEX and HEXIT rewards
        if (totalHexSharesAmount > 0) {
            hexAmount = (info.hexShareAmount * hexRewardsPerShareRate * elapsedTime) / 10 ** 18;
            hexAmount = _convertToShare(hexToken, hexAmount);
        }

        if (totalHexitSharesAmount > 0) {
            hexitAmount = (info.hexitShareAmount * hexitRewardsPerShareRate * elapsedTime) / 10 ** 18;
            hexitAmount = _convertToShare(hexitToken, hexitAmount);
        }
    }

    /// @dev calculates the APR of the staking pool
    /// @param _token address of the token, can be HEX1, HEXIT or HEX1/DAI
    function _calcAPR(address _token) internal view returns (uint16 hexAPR, uint16 hexitAPR) {
        uint256 depositedAmount = totalAmountStaked[_token];
        DistTokenWeight memory tokenWeight = distTokenWeights[_token];

        uint256 hexShare = (depositedAmount * tokenWeight.hexDistRate) / FIXED_POINT;
        uint256 hexitShare = (depositedAmount * tokenWeight.hexitDistRate) / FIXED_POINT;

        uint256 distributedHex = rewardsPool.distributedHex;
        uint256 distributedHexit = rewardsPool.distributedHexit;

        if (hexShare > 0) {
            hexAPR = uint16((distributedHex * 10 ** 8) / hexShare);
        }

        if (hexitShare > 0) {
            hexitAPR = uint16((distributedHexit * 10 ** 18) / hexitShare);
        }
    }

    /// @dev transfers an ERC20.
    /// @notice this function is used to handle tokens with fee on transfer mechanisms.
    /// @param _from address from where the tokens are being transfered.
    /// @param _to address to where the tokens are being transfers.
    /// @param _token address of the token.
    /// @param _amount amount to be transfered.
    function _transferERC20(address _from, address _to, address _token, uint256 _amount) internal returns (uint256) {
        uint256 beforeBal = IERC20(_token).balanceOf(_to);
        IERC20(_token).safeTransferFrom(_from, _to, _amount);
        uint256 afterBal = IERC20(_token).balanceOf(_to);

        return afterBal - beforeBal;
    }

    /// @dev scales amount to share precision, 18 decimals
    /// @param _token address of the token being converted
    /// @param _amount of the token to be scaled up or down
    function _convertToShare(address _token, uint256 _amount) internal view returns (uint256) {
        uint8 tokenDecimals = TokenUtils.expectDecimals(_token);
        if (tokenDecimals >= 18) {
            return _amount / (10 ** (tokenDecimals - 18));
        } else {
            return _amount * (10 ** (18 - tokenDecimals));
        }
    }
}
