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
import "hardhat/console.sol";

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

    uint256 public FIXED_POINT_PAYOUT;

    uint8 public hexDecimals;

    /// @dev After `GRACE_DURATION` days, anyone can claim instead of depositor.
    uint16 public GRACE_DURATION;

    uint16 public FIXED_POINT;

    uint256 public depositId;

    /// @dev User infos to mange deposit and retrieve.
    mapping(address => UserInfo) private userInfos;

    /// @dev DepositInfos by vault side.
    mapping(uint256 => VaultDepositInfo) private vaultDepositInfos;

    mapping(address => EnumerableSet.UintSet) private userDepositIds;

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

        GRACE_DURATION = 7;
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
    function setLimitClaimDuration(uint16 _duration) external onlyOwner {
        GRACE_DURATION = _duration;
    }

    /// @inheritdoc IHexOneVault
    function baseToken() external view override returns (address) {
        return hexToken;
    }

    /// @inheritdoc IHexOneVault
    function depositCollateral(
        address _depositor, 
        uint256 _amount,
        uint16 _duration
    ) public onlyHexOneProtocol override returns (uint256) {
        address sender = msg.sender;
        IERC20(hexToken).safeTransferFrom(sender, address(this), _amount);
        
        return _depositCollateral(
            _depositor,
            _amount,
            _duration
        );
    }

    /// @inheritdoc IHexOneVault
    function claimCollateral(
        address _claimer,
        uint256 _vaultDepositId,
        bool _restake
    ) external onlyHexOneProtocol override returns (uint256, uint256) {
        require (availableDepositIds.contains(_vaultDepositId), "no deposit pool");

        VaultDepositInfo memory vaultDepositInfo = vaultDepositInfos[_vaultDepositId];
        address _depositor = vaultDepositInfo.userAddress;
        uint256 _userDepositId = vaultDepositInfo.userDepositId;

        UserInfo storage userInfo = userInfos[_depositor];
        DepositInfo storage depositInfo = userInfo.depositInfos[_userDepositId];
        require (!_beforeMaturity(depositInfo),  "before maturity");
        require (
            (_claimer == _depositor) || _afterGraceDuration(depositInfo),
            "not proper claimer"
        );

        /// unstake and claim rewards
        uint256 receivedAmount = _unstake(depositInfo);
        uint256 mintAmount = 0;
        uint256 burnAmount = 0;

        if (_restake) {
            mintAmount = _depositCollateral(
                _claimer,
                receivedAmount,
                depositInfo.duration
            );
            mintAmount = (mintAmount > depositInfo.mintAmount) ? (mintAmount - depositInfo.mintAmount) : 0;
        } else {
            /// retrieve or restake token
            IERC20(hexToken).safeTransfer(_claimer, receivedAmount);
            burnAmount = depositInfo.mintAmount;
        }

        /// update userInfo
        depositInfo.exist = false;
        availableDepositIds.remove(_vaultDepositId);

        userInfo.shareBalance -= depositInfo.shares;
        userInfo.depositedBalance -= depositInfo.amount;
        userInfo.totalBorrowedAmount -= depositInfo.mintAmount;
        userDepositIds[_depositor].remove(_vaultDepositId);

        return (burnAmount, mintAmount);
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
        depositInfo.mintAmount += _amount;
        userInfo.totalBorrowedAmount += _amount;
    }

    /// @inheritdoc IHexOneVault
    function getShareBalance(address _account) external view override returns (uint256) {
        require (_account != address(0), "zero account address");
        return userInfos[_account].shareBalance;
    }

    /// @inheritdoc IHexOneVault
    function getUserInfos(address _account) external view override returns (DepositShowInfo[] memory) {
        require (_account != address(0), "zero account address");

        uint256 length = userDepositIds[_account].length();
        DepositShowInfo[] memory depositShowInfos = new DepositShowInfo[](length);

        if (length == 0) {
            return depositShowInfos;
        }

        uint256[] memory depositIds = userDepositIds[_account].values();

        uint256 curHexDay = IHexToken(hexToken).currentDay();
        for (uint256 i = 0; i < length; i ++) {
            uint256 vaultDepositId = depositIds[i];
            VaultDepositInfo memory info = vaultDepositInfos[vaultDepositId];
            uint256 userDepositId = info.userDepositId;
            DepositInfo memory depositInfo = userInfos[info.userAddress].depositInfos[userDepositId];
            
            uint256 borrowableAmount = _getBorrowableAmount(depositInfo);
            uint256 shares = _regetShares(depositInfo.stakeId);
            uint256 effectiveHex = _calculateEffectiveHex(
                depositInfo.amount,
                shares,
                depositInfo.duration
            );

            depositShowInfos[i] = DepositShowInfo(
                depositInfo.vaultDepositId,
                depositInfo.amount,
                shares,
                depositInfo.mintAmount,
                borrowableAmount,
                effectiveHex,
                depositInfo.initHexPrice,
                depositInfo.depositedHexDay,
                depositInfo.duration + depositInfo.depositedHexDay,
                curHexDay
            );
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
        uint256 length = userDepositIds[_account].length();

        if (length == 0) {
            return new BorrowableInfo[](0);
        }

        uint256[] memory depositIds = userDepositIds[_account].values();
        uint256 borrowAvailableCnt = 0;
        for (uint256 i = 0; i < length; i ++) {
            uint256 vaultDepositId = depositIds[i];
            VaultDepositInfo memory info = vaultDepositInfos[vaultDepositId];
            uint256 userDepositId = info.userDepositId;
            DepositInfo memory depositInfo = userInfos[info.userAddress].depositInfos[userDepositId];

            if (_getBorrowableAmount(depositInfo) > 0) {
                borrowAvailableCnt ++;
            }
        }

        
        BorrowableInfo[] memory borrowableInfos = new BorrowableInfo[](borrowAvailableCnt);
        if (borrowAvailableCnt == 0) {
            return borrowableInfos;
        }

        uint256 index = 0;
        for (uint256 i = 0; i < length; i ++) {
            uint256 vaultDepositId = depositIds[i];
            VaultDepositInfo memory info = vaultDepositInfos[vaultDepositId];
            uint256 userDepositId = info.userDepositId;
            DepositInfo memory depositInfo = userInfos[info.userAddress].depositInfos[userDepositId];

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

        uint256 liquidableLength = 0;
        for (uint256 i = 0; i < length; i ++) {
            uint256 vaultDepositId = availableDepositIds.at(i);
            VaultDepositInfo memory info = vaultDepositInfos[vaultDepositId];
            uint256 userDepositId = info.userDepositId;
            DepositInfo memory depositInfo = userInfos[info.userAddress].depositInfos[userDepositId];

            if (!_beforeMaturity(depositInfo)) {
                liquidableLength ++;
            }
        }

        LiquidateInfo[] memory liquidableDeposits = new LiquidateInfo[](liquidableLength);
        if (liquidableLength == 0) {
            return liquidableDeposits;
        }

        uint256 index = 0;
        uint256 curHexDay = IHexToken(hexToken).currentDay();
        for (uint256 i = 0; i < length; i ++) {
            uint256 vaultDepositId = availableDepositIds.at(i);
            VaultDepositInfo memory info = vaultDepositInfos[vaultDepositId];
            uint256 userDepositId = info.userDepositId;
            address depositor = info.userAddress;
            DepositInfo memory depositInfo = userInfos[depositor].depositInfos[userDepositId];

            if (!_beforeMaturity(depositInfo)) {
                uint256 shares = _regetShares(depositInfo.stakeId);
                uint256 effectiveHex = _calculateEffectiveHex(
                    depositInfo.amount,
                    shares,
                    depositInfo.duration
                );
                uint256 curHexPrice = IHexOnePriceFeed(hexOnePriceFeed).getHexTokenPrice(10**hexDecimals);
                uint256 initialUSDValue = depositInfo.amount * depositInfo.initHexPrice / (10**hexDecimals);
                uint256 currentUSDValue = depositInfo.amount * curHexPrice / (10**hexDecimals);

                liquidableDeposits[index ++] = LiquidateInfo({
                    depositor: depositor,
                    depositId: vaultDepositId,
                    curHexDay: curHexDay,
                    endDay: depositInfo.depositedHexDay + depositInfo.duration,
                    effectiveHex: effectiveHex,
                    borrowedHexOne: depositInfo.mintAmount,
                    initHexPrice: depositInfo.initHexPrice,
                    currentHexPrice: curHexPrice,
                    depositedHexAmount: depositInfo.amount,
                    currentValue: IHexOnePriceFeed(hexOnePriceFeed).getHexTokenPrice(effectiveHex),
                    initUSDValue: initialUSDValue,
                    currentUSDValue: currentUSDValue,
                    graceDay: depositInfo.graceDay,
                    liquidable: _afterGraceDuration(depositInfo)
                });
            }
        }

        return liquidableDeposits;
    }

    function _depositCollateral(
        address _depositor, 
        uint256 _amount,
        uint16 _duration
    ) internal returns (uint256 mintAmount) {
        /// stake it to hex token
        IHexToken(hexToken).stakeStart(_amount, _duration);
        uint256 stakeId = IHexToken(hexToken).stakeCount(address(this));
        uint256 shareAmount = 0;
        (mintAmount, shareAmount) = _convertShare(_amount, stakeId - 1);
        
        UserInfo storage userInfo = userInfos[_depositor];
        uint256 curDepositId = userInfo.depositId;
        uint256 curHexDay = IHexToken(hexToken).currentDay();
        uint256 initHexPrice = IHexOnePriceFeed(hexOnePriceFeed).getHexTokenPrice(10**hexDecimals);
        userInfo.depositInfos[curDepositId] = DepositInfo(
            depositId,
            stakeId - 1,
            _amount,
            shareAmount,
            mintAmount,
            curHexDay,
            initHexPrice,
            _duration,
            GRACE_DURATION,
            true
        );

        userInfo.shareBalance += shareAmount;
        userInfo.depositedBalance += _amount;
        userInfo.depositId = curDepositId + 1;
        userInfo.totalBorrowedAmount += mintAmount;

        userDepositIds[_depositor].add(depositId);
        vaultDepositInfos[depositId] = VaultDepositInfo(_depositor, curDepositId);
        availableDepositIds.add(depositId ++);
    }

    /// @notice Calculate shares amount and usd value.
    function _convertShare(
        uint256 _amount,
        uint256 _stakeId
    ) internal view returns (uint256 usdValue, uint256 shareAmount) {
        shareAmount = _regetShares(_stakeId);  // shareAmount: decimals 12
        usdValue = IHexOnePriceFeed(hexOnePriceFeed).getHexTokenPrice(_amount);
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

    function _afterGraceDuration(DepositInfo memory _depositInfo) internal view returns (bool) {
        uint256 curHexDay = IHexToken(hexToken).currentDay();
        uint256 endHexDay = _depositInfo.depositedHexDay + _depositInfo.duration;
        return curHexDay > (endHexDay + _depositInfo.graceDay);
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
        /// hexToken decimal = 8, share decimal = 12. to get hex token amount, divide by 10**4
        uint256 effectiveHex = _shareAmount * uint256(dayPayoutTotal) * _stakeDays / FIXED_POINT_PAYOUT / 10**4;
        effectiveHex += _hexAmount;

        return effectiveHex;
    }

    function _regetShares(uint256 _stakeId) internal view returns (uint256) {
        IHexToken.StakeStore memory stakeStore = IHexToken(hexToken).stakeLists(address(this), _stakeId);
        return stakeStore.stakeShares;
    }

    uint256[100] private __gap;
}