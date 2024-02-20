// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IHexOneStaking} from "./interfaces/IHexOneStaking.sol";
import {TokenUtils} from "./utils/TokenUtils.sol";

/// @title Hex One Staking
/// @dev Distributes 1% of the HEX and HEXIT available daily.
/// @notice pool tokens  -> HEXIT and HEX
///         stake tokens -> HEXIT, HEX1 and HEX1/DAI
contract HexOneStaking is Ownable, ReentrancyGuard, IHexOneStaking {
    /// @dev using EnumerableSet OZ library for addresses
    using EnumerableSet for EnumerableSet.AddressSet;
    /// @dev using safe ERC20 OZ library
    using SafeERC20 for IERC20;

    /// @dev fixed point is used to calculate ratios in bps
    uint16 public constant FIXED_POINT = 1000;
    /// @dev minimum amount of days to unstake
    uint16 public constant MIN_UNSTAKE_DAYS = 2;

    /// @dev address of the HEX token
    address public immutable hexToken;
    /// @dev address of the HEXIT token
    address public immutable hexitToken;

    /// @dev tokens that are allowed to be staked.
    EnumerableSet.AddressSet private stakeTokens;

    /// @dev pool token => Pool
    mapping(address => Pool) public pools;
    /// @dev stake token => distribution weight (10%, 20% or 70%)
    mapping(address => uint256) public stakeTokenWeights;

    /// @dev user address => stake token => StakeInfo
    mapping(address => mapping(address => StakeInfo)) public stakingInfos;
    /// @dev stake token => total amount of token staked
    mapping(address => uint256) public totalStakedAmount;

    /// @dev current staking day => pool token => PoolRewards
    mapping(uint256 => mapping(address => PoolHistory)) public poolHistory;

    /// @dev the timestamp in which the staking launched
    uint256 public stakingLaunchTime;
    /// @dev tracks if staking is enabled or not
    bool public stakingEnabled;

    /// @dev address of the hexOneVault
    address public hexOneVault;
    /// @dev address of the HexOneBootstrap
    address public hexOneBootstrap;

    /// @dev checks if staking is enabled
    modifier onlyWhenStakingEnabled() {
        if (!stakingEnabled) revert StakingNotYetEnabled();
        _;
    }

    /// @dev checks if hexOneBootstrap is the sender
    modifier onlyHexOneBootstrap() {
        if (msg.sender != hexOneBootstrap) revert NotHexOneBootstrap(msg.sender);
        _;
    }

    /// @dev create both HEX and HEXIT pools and set their daily
    /// distribution rate to 1%
    /// @param _hexToken address of the HEX token
    /// @param _hexitToken address of the HEXIT token
    constructor(address _hexToken, address _hexitToken, uint16 _hexDistRate, uint16 _hexitDistRate)
        Ownable(msg.sender)
    {
        if (_hexToken == address(0)) revert InvalidAddress(_hexToken);
        if (_hexitToken == address(0)) revert InvalidAddress(_hexitToken);
        if (_hexDistRate > FIXED_POINT) revert InvalidRate(_hexDistRate);
        if (_hexitDistRate > FIXED_POINT) revert InvalidRate(_hexitDistRate);

        hexToken = _hexToken;
        hexitToken = _hexitToken;

        Pool storage hexPool = pools[_hexToken];
        hexPool.distributionRate = _hexDistRate;

        Pool storage hexitPool = pools[_hexitToken];
        hexitPool.distributionRate = _hexitDistRate;
    }

    /// @dev set the address of the Vault and Bootstrap
    /// @param _hexOneVault address of the HexOneVault.
    /// @param _hexOneBootstrap address of the HexOneBootstrap.
    function setBaseData(address _hexOneVault, address _hexOneBootstrap) external onlyOwner {
        if (hexOneVault != address(0)) revert BaseDataAlreadySet();
        if (hexOneBootstrap != address(0)) revert BaseDataAlreadySet();

        if (_hexOneVault == address(0)) revert InvalidAddress(_hexOneVault);
        if (_hexOneBootstrap == address(0)) revert InvalidAddress(_hexOneBootstrap);

        hexOneVault = _hexOneVault;
        hexOneBootstrap = _hexOneBootstrap;

        emit BaseDataSet(_hexOneVault, _hexOneBootstrap);
    }

    /// @dev called once by the bootstrap to enable staking.
    /// staking can only be enabled if there are HEX and HEXIT rewards already deposited.
    function enableStaking() external onlyHexOneBootstrap {
        if (stakingEnabled) revert StakingAlreadyEnabled();
        if (pools[hexToken].totalAssets == 0) revert NoRewardsToDistribute(hexToken);
        if (pools[hexitToken].totalAssets == 0) revert NoRewardsToDistribute(hexitToken);

        stakingEnabled = true;
        stakingLaunchTime = block.timestamp;

        emit StakingEnabled(block.timestamp);
    }

    /// @dev add tokens that can be used to earn staking rewards.
    /// @param _tokens addresses of each token to be added as a stake token.
    /// @param _weights distribution rate for the respective token in bps.
    function setStakeTokens(address[] calldata _tokens, uint16[] calldata _weights) external onlyOwner {
        uint256 length = _tokens.length;
        if (length == 0) revert InvalidArrayLength(length);
        if (length != _weights.length) revert MismatchedArray();

        uint16 weightSum;
        for (uint256 i; i < length; ++i) {
            address token = _tokens[i];
            uint16 weight = _weights[i];
            if (token == address(0)) revert InvalidStakeToken(token);
            if (weight == 0 || weight > FIXED_POINT) revert InvalidWeight(weight);

            weightSum += weight;

            stakeTokens.add(token);
            stakeTokenWeights[token] = weight;
        }

        // total weight should always be equal to FIXED_POINT (100%)
        if (weightSum != FIXED_POINT) revert InvalidWeightSum(weightSum);

        emit StakeTokensAdded(_tokens, _weights);
    }

    /// @dev adds HEX or HEXIT to the pool incrementing total assets.
    /// @notice to add HEX the caller must be HexOneVault
    /// and to add HEXIT the caller must be HexOneBootstrap.
    /// @param _poolToken address of the pool token.
    /// @param _amount of HEX tokens to be added to the pool to be distributed.
    function purchase(address _poolToken, uint256 _amount) external {
        if (_amount == 0) revert InvalidPurchaseAmount(_amount);
        if (_poolToken == hexToken) {
            if (msg.sender != hexOneVault) revert NotHexOneVault(msg.sender);
        } else if (_poolToken == hexitToken) {
            if (msg.sender != hexOneBootstrap) revert NotHexOneBootstrap(msg.sender);
        } else {
            revert InvalidPoolToken(_poolToken);
        }

        // if the pool staking day is not sync with the contract staking day
        // there might be gaps in pool history, so we need to updated it
        Pool storage pool = pools[_poolToken];
        if (pool.currentStakingDay < getCurrentStakingDay()) {
            _updatePoolHistory(_poolToken);
        }

        // increment the total assets deposited in the pool
        pool.totalAssets += _amount;

        // transfer tokens from the msg.sender to this contract
        IERC20(_poolToken).safeTransferFrom(msg.sender, address(this), _amount);

        emit Purchased(msg.sender, _poolToken, _amount);
    }

    /// @dev allow users to stake HEXIT, HEX1 or HEX1/DAI to earn HEX and HEXIT rewards.
    /// @param _stakeToken address of the token being staked.
    /// @param _amount of token being staked.
    function stake(address _stakeToken, uint256 _amount) external nonReentrant onlyWhenStakingEnabled {
        if (!stakeTokens.contains(_stakeToken)) revert InvalidStakeToken(_stakeToken);
        if (_amount == 0) revert InvalidStakeAmount(_amount);

        // accrue rewards and update history for both the HEX and HEXIT pools
        _accrueRewards(msg.sender, _stakeToken);

        // transfers amount of stake token from the sender to this contract.
        uint256 stakeAmount = _transferToken(_stakeToken, msg.sender, address(this), _amount);

        // update the total amount staked
        totalStakedAmount[_stakeToken] += stakeAmount;

        // calculate the amount of HEX and HEXIT pool shares to give to the user
        uint256 shares = _calculateShares(_stakeToken, stakeAmount);
        if (shares == 0) revert InvalidSharesAmount(shares);

        // update the number of total shares in the HEX and HEXIT pools
        pools[hexToken].totalShares += shares;
        pools[hexitToken].totalShares += shares;

        // update the staking information of the user for a specific stake token
        uint256 currentStakingDay = getCurrentStakingDay();
        StakeInfo storage stakeInfo = stakingInfos[msg.sender][_stakeToken];
        stakeInfo.stakedAmount += stakeAmount;
        if (stakeInfo.initStakeDay == 0) {
            stakeInfo.initStakeDay = currentStakingDay;
        }
        if (stakeInfo.lastClaimedDay == 0) {
            stakeInfo.lastClaimedDay = currentStakingDay;
        }
        stakeInfo.lastDepositedDay = currentStakingDay;
        stakeInfo.hexSharesAmount += shares;
        stakeInfo.hexitSharesAmount += shares;

        emit Staked(msg.sender, _stakeToken, _amount, currentStakingDay);
    }

    /// @dev unstake HEXIT, HEX1 or HEX1/DAI.
    /// @param _stakeToken address of the stake token.
    /// @param _amount amount to unstake.
    function unstake(address _stakeToken, uint256 _amount)
        external
        nonReentrant
        onlyWhenStakingEnabled
        returns (uint256 hexRewards, uint256 hexitRewards)
    {
        if (!stakeTokens.contains(_stakeToken)) revert InvalidStakeToken(_stakeToken);
        if (_amount == 0) revert InvalidUnstakeAmount(_amount);

        StakeInfo storage stakeInfo = stakingInfos[msg.sender][_stakeToken];
        if (getCurrentStakingDay() < stakeInfo.lastDepositedDay + MIN_UNSTAKE_DAYS) revert MinUnstakeDaysNotElapsed();

        // accrue rewards for both HEX and HEXIT pools
        _accrueRewards(msg.sender, _stakeToken);

        // calculate the amount of HEX and HEXIT shares to unstake based
        // on the amount the user wants to unstake
        uint256 shares = _calculateShares(_stakeToken, _amount);
        if (shares == 0) revert InvalidSharesAmount(shares);

        // update user staking information
        stakeInfo.stakedAmount -= _amount;
        stakeInfo.hexSharesAmount -= shares;
        stakeInfo.hexitSharesAmount -= shares;
        if (stakeInfo.hexSharesAmount == 0 && stakeInfo.hexitSharesAmount == 0) {
            stakeInfo.initStakeDay = 0;
            stakeInfo.lastClaimedDay = 0;
        }
        hexRewards = stakeInfo.unclaimedHex;
        hexitRewards = stakeInfo.unclaimedHexit;
        stakeInfo.unclaimedHex -= hexRewards;
        stakeInfo.unclaimedHexit -= hexitRewards;
        stakeInfo.totalHexClaimed += hexRewards;
        stakeInfo.totalHexitClaimed += hexitRewards;

        // decrease the total amount staked of stake token
        totalStakedAmount[_stakeToken] -= _amount;

        // decrease the total amount of shares in both pools
        pools[hexToken].totalShares -= shares;
        pools[hexitToken].totalShares -= shares;

        // transfer all accrued rewards to the user
        if (hexRewards > 0) {
            IERC20(hexToken).safeTransfer(msg.sender, hexRewards);
        }

        if (hexitRewards > 0) {
            IERC20(hexitToken).safeTransfer(msg.sender, hexitRewards);
        }

        // transfer amount stake token back to the user
        IERC20(_stakeToken).safeTransfer(msg.sender, _amount);

        emit Unstaked(msg.sender, _stakeToken, _amount, hexRewards, hexitRewards);
    }

    /// @dev claim accrued rewards earned by the stake token.
    /// @param _stakeToken address of the token staked.
    function claim(address _stakeToken)
        external
        nonReentrant
        onlyWhenStakingEnabled
        returns (uint256 hexRewards, uint256 hexitRewards)
    {
        if (!stakeTokens.contains(_stakeToken)) revert InvalidStakeToken(_stakeToken);

        // accrue rewards for both HEX and HEXIT pools
        _accrueRewards(msg.sender, _stakeToken);

        StakeInfo storage stakeInfo = stakingInfos[msg.sender][_stakeToken];
        hexRewards = stakeInfo.unclaimedHex;
        hexitRewards = stakeInfo.unclaimedHexit;

        // update the amount of HEX and HEXIT left to claim to 0
        stakeInfo.unclaimedHex = 0;
        stakeInfo.unclaimedHexit = 0;

        // update the total amount of HEX and HEXIT claimed by the user.
        stakeInfo.totalHexClaimed += hexRewards;
        stakeInfo.totalHexitClaimed += hexitRewards;

        // transfer all accrued rewards to the user
        if (hexRewards > 0) {
            IERC20(hexToken).safeTransfer(msg.sender, hexRewards);
        }

        if (hexitRewards > 0) {
            IERC20(hexitToken).safeTransfer(msg.sender, hexitRewards);
        }

        emit Claimed(msg.sender, _stakeToken, hexRewards, hexitRewards);
    }

    /// @dev returns the amount of days that passed since the staking started.
    function getCurrentStakingDay() public view returns (uint256) {
        uint256 stakingLaunch = stakingLaunchTime;
        if (stakingLaunch == 0) {
            return 0;
        } else {
            return (block.timestamp - stakingLaunch) / 1 days;
        }
    }

    /// @dev accrue rewards and add them as unclaimed for HEX and HEXIT.
    /// @param _user address of the user staking
    /// @param _stakeToken address of the stake token
    function _accrueRewards(address _user, address _stakeToken) internal {
        // update HEX pool history if it is outdated.
        Pool storage hexPool = pools[hexToken];
        if (hexPool.currentStakingDay < getCurrentStakingDay()) {
            _updatePoolHistory(hexToken);
        }

        // update HEXIT pool history if it is outdated.
        Pool storage hexitPool = pools[hexitToken];
        if (hexitPool.currentStakingDay < getCurrentStakingDay()) {
            _updatePoolHistory(hexitToken);
        }

        StakeInfo storage stakeInfo = stakingInfos[_user][_stakeToken];
        if (stakeInfo.hexSharesAmount > 0 && stakeInfo.hexitSharesAmount > 0) {
            // calculate the amount of HEX and HEXIT rewards since the last day claimed
            (uint256 hexRewards, uint256 hexitRewards) = _calculateRewards(_user, _stakeToken);

            // increment the rewards accrued as unclaimed rewards
            stakeInfo.unclaimedHex += hexRewards;
            stakeInfo.unclaimedHexit += hexitRewards;
        }
    }

    /// @dev updates daily rewards since they were last updated
    /// @param _poolToken address of the pool token
    function _updatePoolHistory(address _poolToken) internal {
        Pool storage pool = pools[_poolToken];

        uint256 currentStakingDay = pool.currentStakingDay;
        while (currentStakingDay < getCurrentStakingDay()) {
            // get the pool rewards for each day since it was last updated
            PoolHistory storage history = poolHistory[currentStakingDay][_poolToken];

            // store the total shares emitted by the pool at a specific day
            history.totalShares = pool.totalShares;

            // compute the available assets for that day
            uint256 availableAssets = pool.totalAssets - pool.distributedAssets;
            history.availableAssets = availableAssets;

            // if the number of total shares is zero then the amount of stakers to distribute
            // rewards to is also zero, which means that no rewards should be distributed if
            // there are no stakers.
            if (pool.totalShares != 0) {
                // calculate the amount of pool token to distribute for a specific staking day
                uint256 amountToDistribute = (availableAssets * pool.distributionRate) / FIXED_POINT;
                history.amountToDistribute = amountToDistribute;

                // increment the distributedAssets by the pool
                pool.distributedAssets += amountToDistribute;
            } else {
                history.amountToDistribute = 0;
            }

            // increment the staking day in which the pool rewards were last updated
            currentStakingDay++;
        }
        pool.currentStakingDay = currentStakingDay;
    }

    /// @dev calculates HEX and HEXIT rewards since the user last claimed.
    /// @param _user address of the user.
    /// @param _stakeToken address of the stake token.
    function _calculateRewards(address _user, address _stakeToken)
        internal
        returns (uint256 hexRewards, uint256 hexitRewards)
    {
        StakeInfo storage stakeInfo = stakingInfos[_user][_stakeToken];

        uint256 lastClaimedDay = stakeInfo.lastClaimedDay;
        while (lastClaimedDay < getCurrentStakingDay()) {
            // calculate HEX rewards for that day
            PoolHistory storage hexHistory = poolHistory[lastClaimedDay][hexToken];
            uint256 hexSharesRatio = stakeInfo.hexSharesAmount * FIXED_POINT / hexHistory.totalShares;
            hexRewards += (hexHistory.amountToDistribute * hexSharesRatio) / FIXED_POINT;

            // calculate HEXIT rewards
            PoolHistory storage hexitHistory = poolHistory[lastClaimedDay][hexitToken];
            uint256 hexitSharesRatio = stakeInfo.hexitSharesAmount * FIXED_POINT / hexitHistory.totalShares;
            hexitRewards += (hexitHistory.amountToDistribute * hexitSharesRatio) / FIXED_POINT;

            lastClaimedDay++;
        }
        // update last day user claimed rewards for both pools
        stakeInfo.lastClaimedDay = lastClaimedDay;
    }

    /// @dev transfers an ERC20.
    /// @notice this function is used to handle tokens with fee mechanisms.
    /// @param _token address of the token.
    /// @param _from address from where the tokens are being transfered.
    /// @param _to address to where the tokens are being transfered.
    /// @param _amount amount to be transfered.
    function _transferToken(address _token, address _from, address _to, uint256 _amount) internal returns (uint256) {
        uint256 balanceBefore = IERC20(_token).balanceOf(_to);
        IERC20(_token).safeTransferFrom(_from, _to, _amount);
        uint256 balanceAfter = IERC20(_token).balanceOf(_to);
        return balanceAfter - balanceBefore;
    }

    /// @dev calculates the shares to be given to the user depending on the token staked
    /// @notice shares are always 18 decimals, so depending on the token it might need to be scaled up or down.
    /// @param _stakeToken address of the stake token.
    /// @param _amount amount of stake token.
    function _calculateShares(address _stakeToken, uint256 _amount) internal view returns (uint256) {
        uint256 shares = (_amount * stakeTokenWeights[_stakeToken]) / FIXED_POINT;
        return _convertToShares(_stakeToken, shares);
    }

    /// @dev converts the amount of token to shares precision (18 decimals).
    /// @param _token address of the token being converted.
    /// @param _amount of the token to be scaled up or down.
    function _convertToShares(address _token, uint256 _amount) internal view returns (uint256) {
        uint8 decimals = TokenUtils.expectDecimals(_token);
        if (decimals >= 18) {
            return _amount / (10 ** (decimals - 18));
        } else {
            return _amount * (10 ** (18 - decimals));
        }
    }
}
