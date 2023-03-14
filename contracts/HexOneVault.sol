// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./utils/TokenUtils.sol";
import "./interfaces/IHexOneVault.sol";
import "./interfaces/IHexToken.sol";
import "./interfaces/IHexOnePriceFeed.sol";

contract HexOneVault is OwnableUpgradeable, IHexOneVault {

    using EnumerableSet for EnumerableSet.UintSet;
    using SafeERC20 for IERC20;

    /// All exists depositId list.
    EnumerableSet.UintSet private availableDepositIds;

    /// @dev The address of HexOneProtocol contract.
    address public hexOneProtocol;

    /// @dev HEX token address.
    address public hexToken;

    /// @dev The contract address to get token price.
    address private hexOnePriceFeed;

    /// @dev The total amount of locked base token.
    uint256 private totalLocked;

    /// @dev The total USD value of locked base tokens.
    uint256 private lockedUSDValue;

    uint16 public LIMIT_PRICE_PERCENT; // 66%

    uint256 public FIXED_POINT_PAYOUT;

    uint8 public hexDecimals;

    /// @dev After `LIMIT_CLAIM_DURATION` days, anyone can claim instead of depositor.
    uint16 public LIMIT_CLAIM_DURATION;

    uint16 public FIXED_POINT;

    uint256 public depositId;

    /// @dev User infos to mange deposit and retrieve.
    mapping(address => UserInfo) private userInfos;

    /// @dev DepositInfos by vault side.
    mapping(uint256 => VaultDepositInfo) private vaultDepositInfos;

    modifier onlyHexOneProtocol {
        require (msg.sender == hexOneProtocol, "only hexOneProtocol");
        _;
    }

    constructor () {
        _disableInitializers();
    }

    function initialize (
        address _hexToken,
        address _hexOnePriceFeed
    ) public initializer {
        require (_hexToken != address(0), "zero hex token address");
        require (_hexOnePriceFeed != address(0), "zero priceFeed contract address");

        hexToken = _hexToken;
        hexOnePriceFeed = _hexOnePriceFeed;

        LIMIT_PRICE_PERCENT = 660;  // 66%
        LIMIT_CLAIM_DURATION = 7;
        FIXED_POINT = 1000;
        FIXED_POINT_PAYOUT = 10**15;

        hexDecimals = TokenUtils.expectDecimals(_hexToken);

        __Ownable_init();
    }

    /// @inheritdoc IHexOneVault
    function setHexOneProtocol(address _hexOneProtocol) external onlyOwner {
        require (_hexOneProtocol != address(0), "Zero HexOneProtocol address");
        hexOneProtocol = _hexOneProtocol;
    }

    /// @inheritdoc IHexOneVault
    function setLimitPricePercent(uint16 _percent) external onlyOwner {
        LIMIT_PRICE_PERCENT = _percent;
    }

    /// @inheritdoc IHexOneVault
    function setLimitClaimDuration(uint16 _duration) external onlyOwner {
        LIMIT_CLAIM_DURATION = _duration;
    }

    /// @inheritdoc IHexOneVault
    function baseToken() external view override returns (address) {
        return hexToken;
    }

    /// @inheritdoc IHexOneVault
    function depositCollateral(
        address _depositor, 
        uint256 _amount,
        uint16 _duration,
        uint16 _restakeDuration,
        bool _isCommit
    ) external onlyHexOneProtocol override returns (uint256 mintAmount) {
        require (!_isCommit || _restakeDuration > 0, "wrong restake duration");
        address sender = msg.sender;
        IERC20(hexToken).safeTransferFrom(sender, address(this), _amount);
        
        return _depositCollateral(
            _depositor, 
            _amount, 
            0,
            _duration, 
            _restakeDuration, 
            _isCommit, 
            false
        );
    }

    /// @inheritdoc IHexOneVault
    function addCollateralForLiquidate(
        address _depositor,
        uint256 _amount,
        uint256 _vaultDepositId,
        uint16 _duration
    ) external onlyHexOneProtocol override returns (uint256 burnAmount) {
        address sender = msg.sender;
        IERC20(hexToken).safeTransferFrom(sender, address(this), _amount);

        require (availableDepositIds.contains(_vaultDepositId), "not exists depositId");
        VaultDepositInfo memory vaultDepositInfo = vaultDepositInfos[_vaultDepositId];
        address depositedUser = vaultDepositInfo.userAddress;
        require (depositedUser == _depositor, "not correct depositor");
        uint256 _userDepositId = vaultDepositInfo.userDepositId;

        UserInfo storage userInfo = userInfos[_depositor];
        DepositInfo storage depositInfo = userInfo.depositInfos[_userDepositId];
        require (!_beforeMaturity(depositInfo), "before maturity");

        uint256 receivedAmount = _unstake(depositInfo);
        receivedAmount += _amount;
        (
            bool isAllow, uint256 liquidateAmount
        ) = _checkLoss(_vaultDepositId, false);
        require (!isAllow, "not liquidate deposit");

        burnAmount = depositInfo.mintAmount;
        _depositCollateral(
            _depositor, 
            receivedAmount, 
            liquidateAmount,
            _duration, 
            0, 
            false,
            true
        );

        /// update userInfo
        depositInfo.exist = false;
        userInfo.shareBalance -= depositInfo.shares;
        userInfo.depositedBalance -= depositInfo.amount;
        availableDepositIds.remove(_vaultDepositId);

        return burnAmount;
    }

    /// @inheritdoc IHexOneVault
    function claimCollateral(
        address _claimer,
        uint256 _vaultDepositId
    ) external onlyHexOneProtocol override returns (uint256, uint256, uint256 ) {
        VaultDepositInfo memory vaultDepositInfo = vaultDepositInfos[_vaultDepositId];
        address _depositor = vaultDepositInfo.userAddress;
        uint256 _userDepositId = vaultDepositInfo.userDepositId;
        (
            bool allowLoss, 
            uint256 liquidateAmount
        ) = _checkLoss(_vaultDepositId, false);
        UserInfo storage userInfo = userInfos[_depositor];
        DepositInfo storage depositInfo = userInfo.depositInfos[_userDepositId];
        require (depositInfo.exist, "no deposit pool");
        require (!_beforeMaturity(depositInfo),  "before maturity");
        if (_claimer != _depositor) {
            (allowLoss, ) = _checkLoss(_vaultDepositId, true);
            require (!allowLoss, "not proper claimer");    
        }

        /// unstake and claim rewards
        uint256 receivedAmount = _unstake(depositInfo);

        /// retrieve or restake token
        uint256 burnAmount = depositInfo.mintAmount;
        uint256 mintAmount = 0;
        if (depositInfo.isCommitType) {
            mintAmount = _depositCollateral(
                _depositor, 
                receivedAmount, 
                0,
                depositInfo.restakeDuration, 
                depositInfo.restakeDuration, 
                true,
                false
            );
            burnAmount = 0;
            mintAmount = mintAmount > burnAmount ? mintAmount - burnAmount : 0;
        } else {
            IERC20(hexToken).safeTransfer(_claimer, receivedAmount);
        }

        /// update userInfo
        depositInfo.exist = false;
        userInfo.shareBalance -= depositInfo.shares;
        userInfo.depositedBalance -= depositInfo.amount;
        userInfo.totalBorrowedAmount -= depositInfo.borrowedAmount;
        availableDepositIds.remove(_vaultDepositId);

        return (mintAmount, burnAmount, liquidateAmount);
    }

    /// @inheritdoc IHexOneVault
    function borrowHexOne(
        address _depositor, 
        uint256 _vaultDepositId, 
        uint256 _amount
    ) external onlyHexOneProtocol override {
        require (availableDepositIds.contains(_vaultDepositId), "invalid depositId");
        VaultDepositInfo memory vaultDepositInfo = vaultDepositInfos[_vaultDepositId];
        address depositedUser = vaultDepositInfo.userAddress;
        require (depositedUser == _depositor, "not correct depositor");
        uint256 _userDepositId = vaultDepositInfo.userDepositId;

        UserInfo storage userInfo = userInfos[_depositor];
        DepositInfo storage depositInfo = userInfo.depositInfos[_userDepositId];
        require (_getBorrowableAmount(depositInfo) >= _amount, "not enough borrowable amount");
        depositInfo.borrowedAmount += _amount;
        depositInfo.mintAmount += _amount;
    }

    /// @inheritdoc IHexOneVault
    function getShareBalance(address _account) external view override returns (uint256) {
        require (_account != address(0), "zero account address");
        return userInfos[_account].shareBalance;
    }

    /// @inheritdoc IHexOneVault
    function getUserInfos(address _account) external view override returns (DepositShowInfo[] memory) {
        uint256 lastDepositId = userInfos[_account].depositId;
        require (_account != address(0), "zero account address");
        if (
            userInfos[_account].shareBalance == 0 ||
            userInfos[_account].depositedBalance == 0 ||
            lastDepositId == 0
        ) {
            return new DepositShowInfo[](0);
        }

        uint256 cnt = 0;
        for (uint256 i = 0; i < lastDepositId; i ++) {
            DepositInfo memory depositInfo = userInfos[_account].depositInfos[i];
            if (depositInfo.exist) {
                cnt ++;
            }
        }

        DepositShowInfo[] memory depositShowInfos = new DepositShowInfo[](cnt);
        if (cnt == 0) {
            return depositShowInfos;
        }

        uint256 index = 0;
        uint256 curHexDay = IHexToken(hexToken).currentDay();
        for (uint256 i = 0; i < lastDepositId; i ++) {
            DepositInfo memory depositInfo = userInfos[_account].depositInfos[i];
            (, uint256 liquidateAmount) = _checkLoss(depositInfo.vaultDepositId, false);
            if (depositInfo.exist) {
                uint256 borrowableAmount = _getBorrowableAmount(depositInfo);
                uint256 effectiveHex = _calculateEffectiveHex(
                    depositInfo.amount,
                    depositInfo.shares,
                    depositInfo.duration
                );
                depositShowInfos[index ++] = DepositShowInfo(
                    depositInfo.vaultDepositId,
                    depositInfo.amount,
                    depositInfo.shares,
                    depositInfo.mintAmount,
                    _convertToHexAmount(liquidateAmount),
                    borrowableAmount,
                    effectiveHex,
                    depositInfo.initHexPrice,
                    depositInfo.depositedHexDay,
                    depositInfo.duration + depositInfo.depositedHexDay,
                    curHexDay,
                    depositInfo.isCommitType
                );
            }
        }

        return depositShowInfos;
    }

    /// @inheritdoc IHexOneVault
    function getBorrowableAmounts(address _account) 
        external 
        view 
        override 
        returns (BorrowableInfo[] memory) 
    {
        uint256 lastDepositId = userInfos[_account].depositId;
        if (lastDepositId == 0) {
            return new BorrowableInfo[](0);
        }

        uint256 borrowAvailableCnt = 0;
        for (uint256 i = 0; i < lastDepositId; i ++) {
            DepositInfo memory depositInfo = userInfos[_account].depositInfos[i];
            if (_getBorrowableAmount(depositInfo) > 0) {
                borrowAvailableCnt ++;
            }
        }

        uint256 index = 0;
        BorrowableInfo[] memory borrowableInfos = new BorrowableInfo[](borrowAvailableCnt);
        for (uint256 i = 0; i < lastDepositId; i ++) {
            DepositInfo memory depositInfo = userInfos[_account].depositInfos[i];
            uint256 borrowableAmount = _getBorrowableAmount(depositInfo);
            if (borrowableAmount > 0) {
                borrowableInfos[index ++] = BorrowableInfo(depositInfo.vaultDepositId, borrowableAmount);
            }
        }

        return borrowableInfos;
    }

    /// @inheritdoc IHexOneVault
    function getBorrowedBalance(address _account) external view override returns (uint256) {
        return userInfos[_account].totalBorrowedAmount;
    }
    
    /// @inheritdoc IHexOneVault
    function getLiquidableDeposits() external view override returns (LiquidateInfo[] memory) {
        uint256 length = availableDepositIds.length();
        
        if (length == 0) {
            return (new LiquidateInfo[](0));
        }

        uint256 returnIdLength = 0;
        for (uint256 i = 0; i < length; i ++) {
            uint256 id = availableDepositIds.at(i);
            (bool isAllow, ) = _checkLoss(id, true);
            if (!isAllow) {
                returnIdLength ++;
            }
        }

        LiquidateInfo[] memory returnIds = new LiquidateInfo[](returnIdLength);
        uint256 index = 0;
        uint256 curHexDay = IHexToken(hexToken).currentDay();
        for (uint256 i = 0; i < length; i ++) {
            uint256 id = availableDepositIds.at(i);
            (bool isAllow, uint256 liquidateAmount) = _checkLoss(id, true);
            if (!isAllow) {
                VaultDepositInfo memory vaultDepositInfo = vaultDepositInfos[id];
                address depositor = vaultDepositInfo.userAddress;
                DepositInfo memory depositInfo = userInfos[depositor].depositInfos[vaultDepositInfo.userDepositId];
                uint256 effectiveHex = _calculateEffectiveHex(
                    depositInfo.amount,
                    depositInfo.shares,
                    depositInfo.duration
                );
                uint256 curHexPrice = IHexOnePriceFeed(hexOnePriceFeed).getHexTokenPrice(10**hexDecimals);
                IHexOnePriceFeed(hexOnePriceFeed).getHexTokenPrice(effectiveHex);
                _convertToHexAmount(liquidateAmount);

                (uint256 initialUSDValue, uint256 currentUSDValue,) = _getUSDValue(depositInfo);
                returnIds[index ++] = LiquidateInfo({
                    depositor: depositor,
                    depositId: id,
                    curHexDay: curHexDay,
                    endDay: depositInfo.depositedHexDay + depositInfo.duration,
                    effectiveHex: effectiveHex,
                    borrowedHexOne: depositInfo.mintAmount,
                    initHexPrice: depositInfo.initHexPrice,
                    currentHexPrice: curHexPrice,
                    depositedHexAmount: depositInfo.amount,
                    currentValue: IHexOnePriceFeed(hexOnePriceFeed).getHexTokenPrice(effectiveHex),
                    liquidateAmount: liquidateAmount,
                    maxLiquidateHexAmount: _convertToHexAmount(liquidateAmount),
                    initUSDValue: initialUSDValue,
                    currentUSDValue: currentUSDValue,
                    graceDay: depositInfo.graceDay,
                    liquidable: liquidateAmount > 0
                });
            }
        }

        return returnIds;
    }

    /// @notice Stake collateral token and calculate USD value to mint $HEX1
    /// @param _depositor The address of depositor.
    /// @param _amount The amount of collateral.
    /// @param _duration The maturity duration.
    /// @param _restakeDuration If commitType is ture, then restakeDuration is necessary.
    /// @param _isCommit Type of deposit. true/false = commit/uncommit.
    /// @param _isLiquidate Status that this deposit is for liquidate loss or not.
    /// @return mintAmount The amount of $HEX1 to mint.
    function _depositCollateral(
        address _depositor, 
        uint256 _amount,
        uint256 _liquidateAmount,
        uint16 _duration,
        uint16 _restakeDuration,
        bool _isCommit,
        bool _isLiquidate
    ) internal returns (uint256 mintAmount) {
        /// stake it to hex token
        IHexToken(hexToken).stakeStart(_amount, _duration);
        uint256 stakeId = IHexToken(hexToken).stakeCount(address(this));
        uint256 shareAmount = 0;
        (mintAmount, shareAmount) = _convertShare(_amount);
        
        uint256 curDepositId = userInfos[_depositor].depositId;
        uint256 curHexDay = IHexToken(hexToken).currentDay();
        userInfos[_depositor].shareBalance += shareAmount;
        userInfos[_depositor].depositedBalance += _amount;
        uint256 initHexPrice = IHexOnePriceFeed(hexOnePriceFeed).getHexTokenPrice(10**hexDecimals);
        userInfos[_depositor].depositInfos[curDepositId] = DepositInfo(
            depositId,
            stakeId - 1,
            _amount,
            shareAmount,
            _isLiquidate ? 0 : mintAmount,
            0,
            curHexDay,
            _isLiquidate ? _liquidateAmount : 0,
            initHexPrice,
            _duration,
            _restakeDuration,
            LIMIT_CLAIM_DURATION,
            _isCommit,
            true
        );
        userInfos[_depositor].depositId = curDepositId + 1;
        vaultDepositInfos[depositId] = VaultDepositInfo(_depositor, curDepositId);
        availableDepositIds.add(depositId ++);
    }

    /// @notice Calculate shares amount and usd value.
    function _convertShare(uint256 _amount) internal view returns (uint256 usdValue, uint256 shareAmount) {
        IHexToken.GlobalsStore memory global_info = IHexToken(hexToken).globals();
        uint40 shareRate = global_info.shareRate;    // shareRate's basePoint is 10.

        shareAmount = _amount / shareRate * 10;  // shareAmount: decimals 8
        usdValue = IHexOnePriceFeed(hexOnePriceFeed).getHexTokenPrice(_amount);
    }

    /// @notice Check usd loss between initial staked usd value and current usd value.
    /// @dev The minimum is LIMIT_PRICE_PERCENT%. if current usd value is less than this, return false.
    /// @return Allow/Block = True/False
    function _checkLoss(uint256 _depositId, bool _liquidate) internal view returns (bool, uint256) {
        VaultDepositInfo memory vaultDepositInfo = vaultDepositInfos[_depositId];
        DepositInfo memory depositInfo = userInfos[vaultDepositInfo.userAddress].depositInfos[vaultDepositInfo.userDepositId];
        uint256 curHexDay = IHexToken(hexToken).currentDay();
        uint256 endTimestamp = depositInfo.depositedHexDay + depositInfo.duration;
        endTimestamp = _liquidate ? endTimestamp + LIMIT_CLAIM_DURATION : endTimestamp;
        if (
            curHexDay < endTimestamp ||
            depositInfo.isCommitType
        ) {
            return (true, 0);
        }

        (
            ,
            uint256 currentUSDValue,
            uint256 minUSDValue
        ) = _getUSDValue(depositInfo);
        bool isAllow = minUSDValue <= currentUSDValue;
        return (isAllow, isAllow ? 0 : minUSDValue - currentUSDValue);
    }

    function _getUSDValue(DepositInfo memory _depositInfo) internal view returns (
        uint256 initialUSDValue, 
        uint256 currentUSDValue, 
        uint256 minUSDValue
    ) {
        initialUSDValue = _depositInfo.mintAmount + _depositInfo.liquidateAmount;
        currentUSDValue = IHexOnePriceFeed(hexOnePriceFeed).getHexTokenPrice(_depositInfo.amount);
        minUSDValue = initialUSDValue * LIMIT_PRICE_PERCENT / FIXED_POINT;
    }

    function _getBorrowableAmount(DepositInfo memory _depositInfo) internal view returns (uint256) {
        if (_depositInfo.exist) {
            if (_beforeMaturity(_depositInfo)) {
                uint256 initialUSDValue = _depositInfo.mintAmount;
                uint256 currentUSDValue = IHexOnePriceFeed(hexOnePriceFeed).getHexTokenPrice(_depositInfo.amount);
                if (initialUSDValue < currentUSDValue) {
                    return currentUSDValue - initialUSDValue;
                }
            }
        }

        return 0;
    }

    function _unstake(DepositInfo memory _depositInfo) internal returns (uint256) {
        uint256 stakeListId = _depositInfo.stakeId;
        IHexToken.StakeStore memory stakeStore = IHexToken(hexToken).stakeLists(address(this), stakeListId);
        uint40 stakeId = stakeStore.stakeId;
        uint256 beforeBal = IERC20(hexToken).balanceOf(address(this));
        IHexToken(hexToken).stakeEnd(stakeListId, stakeId);
        uint256 afterBal = IERC20(hexToken).balanceOf(address(this));
        return afterBal - beforeBal;
    }

    function _beforeMaturity(DepositInfo memory _depositInfo) internal view returns (bool) {
        uint256 curHexDay = IHexToken(hexToken).currentDay();
        return (curHexDay < _depositInfo.depositedHexDay + _depositInfo.duration);
    }

    function _convertToHexAmount(uint256 _hexOneAmount) internal view returns (uint256) {
        uint256 hexPrice = IHexOnePriceFeed(hexOnePriceFeed).getHexTokenPrice(10**hexDecimals);
        if (hexPrice == 0) return 0;
        return _hexOneAmount * 10**hexDecimals / hexPrice;
    }

    function _calculateEffectiveHex(
        uint256 _hexAmount,
        uint256 _shareAmount,
        uint16 _stakeDays
    ) internal view returns (uint256) {
        uint256 curDay = IHexToken(hexToken).currentDay();
        (uint72 dayPayoutTotal,,) = IHexToken(hexToken).dailyData(curDay - 1);
        uint256 effectiveHex = _shareAmount * uint256(dayPayoutTotal) * _stakeDays / FIXED_POINT_PAYOUT;
        effectiveHex += _hexAmount;

        return effectiveHex;
    }

    uint256[100] private __gap;
}