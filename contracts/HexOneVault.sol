// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./utils/TokenUtils.sol";
import "./interfaces/IHexOneVault.sol";
import "./interfaces/IHexToken.sol";
import "./interfaces/IHexOnePriceFeed.sol";

contract HexOneVault is Ownable, IHexOneVault {

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

    uint16 public LIMIT_PRICE_PERCENT = 66; // 66%

    /// @dev After `LIMIT_CLAIM_DURATION` days, anyone can claim instead of depositor.
    uint256 public LIMIT_CLAIM_DURATION = 7;

    uint16 constant public FIXED_POINT = 1000;

    uint256 public depositId;

    /// @dev User infos to mange deposit and retrieve.
    mapping(address => UserInfo) private userInfos;

    /// @dev DepositInfos by vault side.
    mapping(uint256 => VaultDepositInfo) private vaultDepositInfos;

    modifier onlyHexOneProtocol {
        require (msg.sender == hexOneProtocol, "only hexOneProtocol");
        _;
    }

    constructor (
        address _hexToken,
        address _hexOnePriceFeed
    ) {
        require (_hexToken != address(0), "zero hex token address");
        require (_hexOnePriceFeed != address(0), "zero priceFeed contract address");

        hexToken = _hexToken;
        hexOnePriceFeed = _hexOnePriceFeed;
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
    function setLimitClaimDuration(uint256 _duration) external onlyOwner {
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
        uint256 _duration,
        uint256 _restakeDuration,
        bool _isCommit
    ) external onlyHexOneProtocol override returns (uint256 mintAmount) {
        require (!_isCommit || _restakeDuration > 0, "wrong restake duration");
        address sender = msg.sender;
        IERC20(hexToken).safeTransferFrom(sender, address(this), _amount);
        
        return _depositCollateral(
            _depositor, 
            _amount, 
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
        uint256 _duration
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
        require (block.timestamp > depositInfo.depositedTimestamp + depositInfo.duration * 1 days,  "before maturity");

        uint256 receivedAmount = _unstake(depositInfo);
        burnAmount = depositInfo.mintAmount;
        _depositCollateral(
            _depositor, 
            receivedAmount, 
            _duration, 
            0, 
            false,
            false
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
        uint256 _depositId
    ) external onlyHexOneProtocol override returns (uint256, uint256, uint256 ) {
        VaultDepositInfo memory vaultDepositInfo = vaultDepositInfos[_depositId];
        address _depositor = vaultDepositInfo.userAddress;
        uint256 _userDepositId = vaultDepositInfo.userDepositId;
        (
            bool allowLoss, 
            uint256 liquidateAmount
        ) = _checkLoss(_depositId);
        UserInfo storage userInfo = userInfos[_depositor];
        DepositInfo storage depositInfo = userInfo.depositInfos[_userDepositId];
        require (depositInfo.exist, "no deposit pool");
        require (block.timestamp > depositInfo.depositedTimestamp + depositInfo.duration * 1 days,  "before maturity");
        require (!allowLoss || _claimer == _depositor, "not proper claimer");

        /// unstake and claim rewards
        uint256 receivedAmount = _unstake(depositInfo);

        /// retrieve or restake token
        uint256 burnAmount = depositInfo.mintAmount;
        uint256 mintAmount = 0;
        if (depositInfo.isCommitType) {
            mintAmount = _depositCollateral(
                _depositor, 
                receivedAmount, 
                depositInfo.restakeDuration, 
                depositInfo.restakeDuration, 
                true,
                false
            );
        } else {
            IERC20(hexToken).safeTransfer(_claimer, receivedAmount);
        }

        /// update userInfo
        depositInfo.exist = false;
        userInfo.shareBalance -= depositInfo.shares;
        userInfo.depositedBalance -= depositInfo.amount;
        availableDepositIds.remove(_depositId);

        return (mintAmount, burnAmount, liquidateAmount);
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
        for (uint256 i = 0; i < lastDepositId; i ++) {
            DepositInfo memory depositInfo = userInfos[_account].depositInfos[i];
            if (depositInfo.exist) {
                depositShowInfos[index ++] = DepositShowInfo(
                    i,
                    depositInfo.amount,
                    depositInfo.shares,
                    depositInfo.mintAmount,
                    depositInfo.depositedTimestamp,
                    depositInfo.duration * 1 days + depositInfo.depositedTimestamp
                );
            }
        }

        return depositShowInfos;
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
            (bool isAllow, ) = _checkLoss(id);
            if (!isAllow) {
                returnIdLength ++;
            }
        }

        LiquidateInfo[] memory returnIds = new LiquidateInfo[](returnIdLength);
        uint256 index = 0;
        for (uint256 i = 0; i < length; i ++) {
            uint256 id = availableDepositIds.at(i);
            (bool isAllow, uint256 liquidateAmount) = _checkLoss(id);
            if (!isAllow) {
                VaultDepositInfo memory vaultDepositInfo = vaultDepositInfos[i];
                address depositor = vaultDepositInfo.userAddress;
                DepositInfo memory depositInfo = userInfos[depositor].depositInfos[vaultDepositInfo.userDepositId];
                returnIds[index ++] = LiquidateInfo(
                    i, 
                    depositor,
                    depositInfo.amount,
                    liquidateAmount
                );
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
        uint256 _duration,
        uint256 _restakeDuration,
        bool _isCommit,
        bool _isLiquidate
    ) internal returns (uint256 mintAmount) {
        /// stake it to hex token
        IHexToken(hexToken).stakeStart(_amount, _duration);
        uint256 stakeId = IHexToken(hexToken).stakeCount(_depositor);
        uint256 shareAmount = 0;
        (mintAmount, shareAmount) = _convertShare(_amount);
        
        uint256 curDepositId = userInfos[_depositor].depositId;
        userInfos[_depositor].shareBalance += shareAmount;
        userInfos[_depositor].depositedBalance += _amount;
        userInfos[_depositor].depositInfos[curDepositId] = DepositInfo(
            depositId,
            stakeId,
            _amount,
            shareAmount,
            _isLiquidate ? 0 : mintAmount,
            block.timestamp,
            _duration,
            _restakeDuration,
            _isCommit,
            true
        );
        userInfos[_depositor].depositId = curDepositId + 1;
        vaultDepositInfos[depositId] = VaultDepositInfo(_depositor, curDepositId);
        availableDepositIds.add(depositId ++);
    }

    /// @notice Calculate shares amount and usd value.
    function _convertShare(uint256 _amount) internal view returns (uint256 usdValue, uint256 shareAmount) {
        IHexToken.GlobalsStore memory global = IHexToken(hexToken).globals();
        uint40 shareRate = global.shareRate;    // shareRate's basePoint is 10.

        uint8 hexDecimals = TokenUtils.expectDecimals(hexToken);
        uint256 basePoint = 10**hexDecimals;
        shareAmount = _amount / shareRate * 10;  // shareAmount: decimals 8

        uint256 hexPrice = IHexOnePriceFeed(hexOnePriceFeed).getHexTokenPrice(basePoint);
        usdValue = hexPrice * _amount / basePoint;
    }

    /// @notice Check usd loss between initial staked usd value and current usd value.
    /// @dev The minimum is LIMIT_PRICE_PERCENT%. if current usd value is less than this, return false.
    /// @return Allow/Block = True/False
    function _checkLoss(uint256 _depositId) internal view returns (bool, uint256) {
        VaultDepositInfo memory vaultDepositInfo = vaultDepositInfos[_depositId];
        DepositInfo memory depositInfo = userInfos[vaultDepositInfo.userAddress].depositInfos[vaultDepositInfo.userDepositId];
        if (
            block.timestamp < depositInfo.depositedTimestamp + depositInfo.duration * 7 days ||
            !depositInfo.isCommitType
        ) {
            return (true, 0);
        }

        uint256 initialUSDValue = depositInfo.mintAmount;
        uint256 currentUSDValue = IHexOnePriceFeed(hexOnePriceFeed).getHexTokenPrice(depositInfo.amount);
        uint256 minUSDValue = initialUSDValue * LIMIT_PRICE_PERCENT / FIXED_POINT;
        bool isAllow = minUSDValue <= currentUSDValue;
        return (isAllow, isAllow ? 0 : initialUSDValue - currentUSDValue);
    }
}