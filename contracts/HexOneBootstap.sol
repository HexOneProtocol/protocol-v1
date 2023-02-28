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

/// @notice For sacrifice and airdrop
contract HexOneBootstrap is Ownable, IHexOneBootstrap {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeERC20 for IERC20;

    /// @notice Distibution rate.
    ///         This percent of HEXIT token goes to middle contract
    ///         for distribute $HEX1 token to sacrifice participants.
    uint16 public distributionRate;

    /// @notice Percent for will be used for liquify.
    uint16 public liquifyRate;

    /// @notice Percent of HEXIT token for sacrifice distribution.
    uint16 public sacrificeRate;

    /// @notice Percent of HEXIT token for airdrop.
    uint16 public airdropRate;

    uint16 constant public sacrificeCropRate = 47;   // 4.7%

    mapping(address => Token) public allowedTokens;
    mapping(uint256 => uint256) public totalSacrificeWeight;
    mapping(uint256 => mapping(address => uint256)) public sacrificeUserWeight;
    mapping(address => EnumerableSet.UintSet) private sacrificeUserDays;

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

    modifier whenSacrificeDuration {
        uint256 curTimestamp = block.timestamp;
        require (
            curTimestamp >= sacrificeStartTime && curTimestamp <= sacrificeEndTime,
            "not sacrifice duration"
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

        require (_param.sacrificeRate + _param.airdropRate == FIXED_POINT, "invalid rate");
        sacrificeRate = _param.sacrificeRate;
        airdropRate = _param.airdropRate;
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
    function distributeRewards() external onlyOwner override {
        require (block.timestamp > sacrificeEndTime, "sacrifice duration");

        address[] memory participants = sacrificeParticipants.values();
        uint256 length = participants.length;
        require (length > 0, "no sacrifice participants");

        for (uint256 i = 0; i < length; i ++) {
            address participant = participants[i];
            uint256 rewardsAmount = _calcUserRewardsAmount(participant);
            uint256 sacrificeRewardsAmount = rewardsAmount * sacrificeRate / FIXED_POINT;
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
        (uint256 dayIndex, ) = _getSupplyAmountToday();

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
    }

    function _getSupplyAmountToday() internal view returns (uint256 day, uint256 supplyAmount) {
        uint256 elapsedTime = block.timestamp - sacrificeStartTime;
        uint256 dayIndex = elapsedTime / 1 days;
        supplyAmount = _calcSupplyAmount(dayIndex);

        return (dayIndex, 0);
    }

    function _calcSupplyAmount(uint256 _dayIndex) internal pure returns (uint256) {
        uint256 supplyAmount = sacrificeInitialSupply;
        for (uint256 i = 0; i < _dayIndex; i ++) {
            supplyAmount = supplyAmount * sacrificeCropRate / FIXED_POINT;
        }

        return supplyAmount;
    }

    function _processSacrifice(
        address _token,
        uint256 _amount
    ) internal {
        uint256 amountForDistribution = _amount * distributionRate / FIXED_POINT;
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

    function _calcUserRewardsAmount(address _user) internal view returns (uint256) {
        uint256 rewardsAmount = 0;
        uint256[] memory participantDays = sacrificeUserDays[_user].values();
        uint256 length = participantDays.length;
        if (length == 0) { return 0; }

        for (uint256 i = 0; i < length; i ++) {
            uint256 dayIndex = participantDays[i];
            uint256 totalWeight = totalSacrificeWeight[dayIndex];
            uint256 userWeight = sacrificeUserWeight[dayIndex][_user];
            uint256 supplyAmount = _calcSupplyAmount(dayIndex);
            rewardsAmount += (supplyAmount * userWeight / totalWeight);
        }

        return rewardsAmount;
    }
}