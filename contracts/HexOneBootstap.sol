// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./interfaces/IHexOneBootstrap.sol";
import "./interfaces/IHexOnePriceFeed.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IHEXIT.sol";
import "./interfaces/IHexToken.sol";

/// @notice For sacrifice and airdrop
contract HexOneBootstrap is Ownable, IHexOneBootstrap {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeERC20 for IERC20;

    /// @notice Percent of HEXIT token for sacrifice distribution.
    uint16 public rateForSacrifice;

    /// @notice Percent of HEXIT token for airdrop.
    uint16 public rateForAirdrop;

    /// @notice Distibution rate.
    ///         This percent of HEXIT token goes to middle contract
    ///         for distribute $HEX1 token to sacrifice participants.
    uint16 public sacrificeDistRate;

    /// @notice Percent for will be used for liquify.
    uint16 public sacrificeLiquifyRate;

    /// @notice Percent for users who has t-shares by staking hex.
    uint16 public airdropDistRateForHexHolder;

    /// @notice Percent for users who has $HEXIT by sacrifice.
    uint16 public airdropDistRateForHEXITHolder;

    /// @notice Percent that will be used for daily airdrop.
    uint16 constant public distRateForDailyAirdrop = 500;    // 50%

    /// @notice Percent that will be supplied daily.
    uint16 constant public supplyCropRateForSacrifice = 47;    // 4.7%

    /// @notice Allowed token info.
    mapping(address => Token) public allowedTokens;

    /// @notice total sacrificed weight info by daily.
    mapping(uint256 => uint256) public totalSacrificeWeight;

    /// @notice weight that user sacrificed by daily.
    mapping(uint256 => mapping(address => uint256)) public sacrificeUserWeight;

    /// @notice day indexes that user sacrificed.
    mapping(address => EnumerableSet.UintSet) private sacrificeUserDays;

    /// @notice dayIndex that a wallet requested airdrop.
    /// @dev request dayIndex starts from 1.
    mapping(address => RequestAirdrop) public requestAirdropInfo;

    /// @notice Requested amount by daily.
    /// @dev amount for hex token(t-share) holder and hexit holder.
    mapping(uint256 => RequestAmount) public requestedAmountInfo;

    IUniswapV2Router02 public dexRouter;
    address public hexOnePriceFeed;
    address public hexitToken;
    address public hexToken;
    address public pairToken;
    address public escrowCA;
    uint256 constant public sacrificeInitialSupply = 5_555_555 * 1e18;

    uint256 public sacrificeStartTime;
    uint256 public sacrificeEndTime;
    uint256 public airdropStartTime;
    uint256 public airdropEndTime;
    uint256 public airdropHEXITAmount;

    uint16 constant public FIXED_POINT = 1000;

    EnumerableSet.AddressSet private sacrificeParticipants;
    EnumerableSet.AddressSet private airdropRequestors;

    modifier whenSacrificeDuration {
        uint256 curTimestamp = block.timestamp;
        require (
            curTimestamp >= sacrificeStartTime && curTimestamp <= sacrificeEndTime,
            "not sacrifice duration"
        );
        _;
    }

    modifier whenAirdropDuration {
        uint256 curTimestamp = block.timestamp;
        require (
            curTimestamp >= airdropStartTime && curTimestamp <= airdropEndTime,
            "not airdrop duration"
        );
        _;
    }

    modifier onlyAllowedToken(address _token) {
        /// address(0) is native token.
        require (allowedTokens[_token].enable, "not allowed token");
        _;
    }

    constructor (
        Param memory _param
    ) { 
        require (_param.hexOnePriceFeed != address(0), "zero hexOnePriceFeed address");
        hexOnePriceFeed = _param.hexOnePriceFeed;

        require (_param.sacrificeStartTime > block.timestamp, "sacrifice: before current time");
        require (_param.sacrificeDuration > 0, "sacrfice: zero duration days");
        sacrificeStartTime = _param.sacrificeStartTime;
        sacrificeEndTime = _param.sacrificeStartTime + _param.sacrificeDuration * 1 days;

        require (_param.airdropStartTime > sacrificeEndTime, "airdrop: before sacrifice");
        require (_param.airdropDuration > 0, "airdrop: zero duration days");
        airdropStartTime = _param.airdropStartTime;
        airdropEndTime = _param.airdropStartTime + _param.airdropDuration * 1 days;

        require (_param.dexRouter != address(0), "zero dexRouter address");
        dexRouter = IUniswapV2Router02(_param.dexRouter);

        require (_param.hexToken != address(0), "zero hexToken address");
        require (_param.pairToken != address(0), "zero pairToken address");
        require (_param.escrowCA != address(0), "zero escrow contract address");
        require (_param.hexitToken != address(0), "zero hexit token address");
        hexToken = _param.hexToken;
        pairToken = _param.pairToken;
        escrowCA = _param.escrowCA;

        require (
            _param.rateForSacrifice + _param.rateforAirdrop == FIXED_POINT, 
            "distRate: invalid rate"
        );
        rateForSacrifice = _param.rateForSacrifice;
        rateForAirdrop = _param.rateforAirdrop;

        require (
            _param.sacrificeDistRate + _param.sacrificeLiquifyRate == FIXED_POINT, 
            "sacrificeRate: invalid rate"
        );
        sacrificeDistRate = _param.sacrificeDistRate;
        sacrificeLiquifyRate = _param.sacrificeLiquifyRate;

        require (
            _param.airdropDistRateforHexHolder + _param.airdropDistRateforHEXITHolder == FIXED_POINT, 
            "airdropRate: invalid rate"
        );
        airdropDistRateForHexHolder = _param.airdropDistRateforHexHolder;
        airdropDistRateForHEXITHolder = _param.airdropDistRateforHEXITHolder;
    }

    /// @inheritdoc IHexOneBootstrap
    function setEscrowContract(address _escrowCA) external onlyOwner override {
        require (_escrowCA != address(0), "zero escrow contract address");
        escrowCA = _escrowCA;
    }

    /// @inheritdoc IHexOneBootstrap
    function setPriceFeedCA(address _priceFeed) external onlyOwner override {
        require (_priceFeed != address(0), "zero priceFeed contract address");
        hexOnePriceFeed = _priceFeed;
    }

    /// @inheritdoc IHexOneBootstrap
    function isSacrificeParticipant(address _user) external view returns (bool) {
        return sacrificeParticipants.contains(_user);
    }

    /// @inheritdoc IHexOneBootstrap
    function getAirdropRequestors() external view returns (address[] memory) {
        return airdropRequestors.values();
    }

    /// @inheritdoc IHexOneBootstrap
    function getSacrificeParticipants() external view returns (address[] memory) {
        return sacrificeParticipants.values();
    }

    /// @inheritdoc IHexOneBootstrap
    function setAllowedTokens(
        address[] memory _tokens, 
        bool _enable
    ) external onlyOwner override {
        uint256 length = _tokens.length;
        require (length > 0, "invalid length");

        for (uint256 i = 0; i < length; i ++) {
            address token = _tokens[i];
            allowedTokens[token].enable = true;
        }
        emit AllowedTokensSet(_tokens, _enable);
    }

    /// @inheritdoc IHexOneBootstrap
    function setTokenWeight(
        address[] memory _tokens, 
        uint16[] memory _weights
    ) external onlyOwner override {
        uint256 length = _tokens.length;
        require (length > 0, "invalid length");
        require (block.timestamp > sacrificeEndTime, "sacrifice duration");

        for (uint256 i = 0; i < length; i ++) {
            address token = _tokens[i];
            uint16 weight = _weights[i];
            require (weight >= FIXED_POINT, "invalid weight");
            allowedTokens[token].weight = weight;
        }
        emit TokenWeightSet(_tokens, _weights);
    }

    /// @inheritdoc IHexOneBootstrap
    function sacrificeToken(address _token, uint256 _amount) 
        external 
        whenSacrificeDuration 
        onlyAllowedToken(_token)
    {
        address sender = msg.sender;
        require (sender != address(0), "zero caller address");
        require (_token != address(0), "zero token address");
        require (_amount > 0, "zero amount");

        IERC20(_token).safeTransferFrom(sender, address(this), _amount);
        _updateSacrificeInfo(sender, _token, _amount);
    }

    /// @inheritdoc IHexOneBootstrap
    function requestAirdrop(bool _isShareHolder) external whenAirdropDuration override {
        address sender = msg.sender;
        RequestAirdrop storage userInfo = requestAirdropInfo[sender];
        require (sender != address(0), "zero caller address");
        require (userInfo.requestDay == 0, "already requested");

        uint256 dayIndex = (block.timestamp - airdropStartTime) / 1 days;
        uint256 heldAmount = 0;
        if (_isShareHolder) {
            heldAmount = _getTotalShare(sender);
            require (heldAmount > 0, "no t-shares");
            requestedAmountInfo[dayIndex].amountByHexHolder += heldAmount;
        } else {
            heldAmount = IERC20(hexitToken).balanceOf(sender);
            require (heldAmount > 0, "not hexit balance");
            requestedAmountInfo[dayIndex].amountByHEXITHolder += heldAmount;
        }

        requestAirdropInfo[sender] = RequestAirdrop(
            dayIndex + 1, 
            heldAmount, 
            _isShareHolder, 
            false
        );
        airdropRequestors.add(sender);
    }

    /// @inheritdoc IHexOneBootstrap
    function claimAirdrop() external override {
        address sender = msg.sender;
        RequestAirdrop storage userInfo = requestAirdropInfo[sender];
        uint256 dayIndex = userInfo.requestDay;
        require (sender != address(0), "zero caller address");
        require (dayIndex > 0, "not requested");
        require (!userInfo.claimed, "already claimed");

        uint256 rewardsAmount = _calcUserRewardsForAirdrop(sender, dayIndex - 1);
        if (rewardsAmount > 0) {
            IHEXIT(hexitToken).mintToken(rewardsAmount, sender);
        }
        userInfo.claimed = true;
        airdropRequestors.remove(sender);
    }

    /// @inheritdoc IHexOneBootstrap
    function withdrawToken(address _token) external onlyOwner override {
        require (block.timestamp > sacrificeEndTime, "sacrifice duration");

        uint256 balance = 0;
        if (_token == address(0)) {
            balance = address(this).balance;
            require (balance > 0, "zero balance");
            (bool sent, ) = (owner()).call{value: balance}("");
            require (sent, "sending ETH failed");
        } else {
            balance = IERC20(_token).balanceOf(address(this));
            require (balance > 0, "zero balance");
            IERC20(_token).safeTransfer(owner(), balance);
        }

        emit Withdrawed(_token, balance);
    }

    /// @inheritdoc IHexOneBootstrap
    function distributeRewardsForSacrifice() external onlyOwner override {
        require (block.timestamp > sacrificeEndTime, "sacrifice duration");

        address[] memory participants = sacrificeParticipants.values();
        uint256 length = participants.length;
        require (length > 0, "no sacrifice participants");

        for (uint256 i = 0; i < length; i ++) {
            address participant = participants[i];
            uint256 rewardsAmount = _calcUserRewardsAmountForSacrifice(participant);
            uint256 sacrificeRewardsAmount = rewardsAmount * rateForSacrifice / FIXED_POINT;
            uint256 airdropAmount = rewardsAmount - sacrificeRewardsAmount;
            airdropHEXITAmount += airdropAmount;
            IHEXIT(hexitToken).mintToken(sacrificeRewardsAmount, participant);
        }

        emit RewardsDistributed();
    }

    receive() 
        external 
        payable 
        whenSacrificeDuration
        onlyAllowedToken(address(0))
    {
        _updateSacrificeInfo(msg.sender, address(0), msg.value);
    }

    function _updateSacrificeInfo(
        address _participant,
        address _token,
        uint256 _amount
    ) internal {
        uint256 usdValue = IHexOnePriceFeed(hexOnePriceFeed).getBaseTokenPrice(_token, _amount);
        (uint256 dayIndex, ) = _getSupplyAmountForSacrificeToday();

        uint16 weight = allowedTokens[_token].weight == 0 ? FIXED_POINT : allowedTokens[_token].weight;
        uint256 sacrificeWeight = usdValue * weight / FIXED_POINT;
        totalSacrificeWeight[dayIndex] += sacrificeWeight;
        sacrificeUserWeight[dayIndex][_participant] += sacrificeWeight;

        if (!sacrificeParticipants.contains(_participant)) {
            sacrificeParticipants.add(_participant);
        }

        if (!sacrificeUserDays[_participant].contains(dayIndex)) {
            sacrificeUserDays[_participant].add(dayIndex);
        }

        _processSacrifice(_token, _amount);
    }

    function _getTotalShare(address _user) internal view returns (uint256) {
        uint256 stakeCount = IHexToken(hexToken).stakeCount(_user);
        if (stakeCount == 0) return 0;

        uint256 shares = 0;
        for (uint256 i = 0; i < stakeCount; i ++) {
            IHexToken.StakeStore memory stakeStore = IHexToken(hexToken).stakeLists(_user, i);
            shares += stakeStore.stakeShares;
        }

        return shares;
    }

    /// @notice Calculate airdrop amount for today.
    function _getAmountForAirdropToday() internal view returns (uint256) {
        uint256 elapsedTime = block.timestamp - airdropStartTime;
        uint256 dayIndex = elapsedTime / 1 days;
        return _calcAmountForAirdrop(dayIndex);
    }

    function _getSupplyAmountForSacrificeToday() internal view returns (uint256 day, uint256 supplyAmount) {
        uint256 elapsedTime = block.timestamp - sacrificeStartTime;
        uint256 dayIndex = elapsedTime / 1 days;
        supplyAmount = _calcSupplyAmountForSacrifice(dayIndex);

        return (dayIndex, 0);
    }

    function _calcSupplyAmountForSacrifice(uint256 _dayIndex) internal pure returns (uint256) {
        uint256 supplyAmount = sacrificeInitialSupply;
        for (uint256 i = 0; i < _dayIndex; i ++) {
            supplyAmount = supplyAmount * supplyCropRateForSacrifice / FIXED_POINT;
        }

        return supplyAmount;
    }

    function _calcAmountForAirdrop(uint256 _dayIndex) internal view returns (uint256) {
        uint256 airdropAmount = airdropHEXITAmount;
        for (uint256 i = 0; i <= _dayIndex; i ++) {
            airdropAmount = airdropAmount * distRateForDailyAirdrop / FIXED_POINT;
        }
        return airdropAmount;
    }

    function _processSacrifice(
        address _token,
        uint256 _amount
    ) internal {
        uint256 amountForDistribution = _amount * sacrificeDistRate / FIXED_POINT;
        uint256 amountForLiquify = _amount - amountForDistribution;

        /// distribution
        _swapToken(_token, escrowCA, amountForDistribution);

        /// liquify
        uint256 swapAmountForLiquify = amountForLiquify / 2;
        _swapToken(_token, address(this), swapAmountForLiquify);
        uint256 pairTokenBalance = IERC20(pairToken).balanceOf(address(this));
        if (pairTokenBalance > 0) {
            IERC20(pairToken).approve(address(dexRouter), pairTokenBalance);
            IERC20(_token).approve(address(dexRouter), swapAmountForLiquify);
            dexRouter.addLiquidity(
                pairToken, 
                _token, 
                pairTokenBalance, 
                swapAmountForLiquify, 
                0, 
                0, 
                address(this), 
                block.timestamp
            );
        }
        
    }

    function _swapToken(
        address _token,
        address _recipient,
        uint256 _amount
    ) internal {
        address[] memory path = new address[](2);

        if (_amount > 0) {
            path[0] = _token == address(0) ? dexRouter.WETH() : _token;
            path[1] = hexToken;

            if (_token == address(0)) {
                dexRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{value: _amount}(
                    0, 
                    path, 
                    _recipient, 
                    block.timestamp
                );
            } else {
                IERC20(_token).approve(address(dexRouter), _amount);
                dexRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    _amount, 
                    0, 
                    path, 
                    _recipient, 
                    block.timestamp
                );
            }
        }
    }

    function _calcUserRewardsAmountForSacrifice(
        address _user
    ) internal view returns (uint256) {
        uint256 rewardsAmount = 0;
        uint256[] memory participantDays = sacrificeUserDays[_user].values();
        uint256 length = participantDays.length;
        if (length == 0) { return 0; }

        for (uint256 i = 0; i < length; i ++) {
            uint256 dayIndex = participantDays[i];
            uint256 totalWeight = totalSacrificeWeight[dayIndex];
            uint256 userWeight = sacrificeUserWeight[dayIndex][_user];
            uint256 supplyAmount = _calcSupplyAmountForSacrifice(dayIndex);
            rewardsAmount += (supplyAmount * userWeight / totalWeight);
        }

        return rewardsAmount;
    }

    function _calcUserRewardsForAirdrop(
        address _user, 
        uint256 _dayIndex
    ) internal view returns (uint256) {
        RequestAirdrop memory userInfo = requestAirdropInfo[_user];
        RequestAmount memory amountInfo = requestedAmountInfo[_dayIndex];

        uint256 supplyAmount = _calcAmountForAirdrop(_dayIndex);
        uint256 requestedAmount;
        if (userInfo.isShareHolder) {
            supplyAmount = supplyAmount * airdropDistRateForHexHolder / FIXED_POINT;
            requestedAmount = amountInfo.amountByHexHolder;
        } else {
            supplyAmount = supplyAmount * airdropDistRateForHEXITHolder / FIXED_POINT;
            requestedAmount = amountInfo.amountByHEXITHolder;
        }

        return supplyAmount * userInfo.balance / requestedAmount;
    }
}