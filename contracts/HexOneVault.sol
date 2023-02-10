// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./utils/TokenUtils.sol";
import "./interfaces/IHexOneVault.sol";
import "./interfaces/IHexToken.sol";
import "./interfaces/IHexOnePriceFeed.sol";

contract HexOneVault is Ownable, IHexOneVault {

    using SafeERC20 for IERC20;

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

    /// @dev User infos to mange deposit and retrieve.
    mapping(address => UserInfo) private userInfos;

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
        
        return _depositCollateral(_depositor, _amount, _duration, _restakeDuration, _isCommit);
    }

    /// @inheritdoc IHexOneVault
    function claimCollateral(
        address _depositor,
        uint256 _depositId
    ) external onlyHexOneProtocol override returns (
        uint256 mintAmount, 
        uint256 burnAmount
    ) {
        UserInfo storage userInfo = userInfos[_depositor];
        DepositInfo storage depositInfo = userInfo.depositInfos[_depositId];
        require (depositInfo.exist, "no deposit pool");
        require (block.timestamp > depositInfo.depositedTimestamp + depositInfo.duration * 1 days,  "before maturity");

        /// unstake and claim rewards
        uint256 stakeListId = depositInfo.stakeId;
        IHexToken.StakeStore memory stakeStore = IHexToken(hexToken).stakeLists(address(this), stakeListId);
        uint40 stakeId = stakeStore.stakeId;
        uint256 beforeBal = IERC20(hexToken).balanceOf(address(this));
        IHexToken(hexToken).stakeEnd(stakeListId, stakeId);
        uint256 afterBal = IERC20(hexToken).balanceOf(address(this));
        uint256 receivedAmount = afterBal - beforeBal;
        require (receivedAmount > 0, "claim failed");

        /// retrieve or restake token
        burnAmount = depositInfo.mintAmount;
        if (depositInfo.isCommitType) {
            mintAmount = _depositCollateral(
                _depositor, 
                receivedAmount, 
                depositInfo.restakeDuration, 
                depositInfo.restakeDuration, 
                true
            );
        } else {
            IERC20(hexToken).safeTransfer(_depositor, receivedAmount);
        }

        /// update userInfo
        depositInfo.exist = false;
        userInfo.shareBalance -= depositInfo.shares;
        userInfo.depositedBalance -= depositInfo.amount;
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
        require (
            userInfos[_account].shareBalance != 0 && 
            userInfos[_account].depositedBalance != 0 &&
            lastDepositId > 0,
            "no deposited pool"    
        );

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
                    depositInfo.depositedTimestamp,
                    depositInfo.duration * 1 days + depositInfo.depositedTimestamp
                );
            }
        }

        return depositShowInfos;
    }
    
    /// @notice Stake collateral token and calculate USD value to mint $HEX1
    /// @param _depositor The address of depositor.
    /// @param _amount The amount of collateral.
    /// @param _duration The maturity duration.
    /// @param _restakeDuration If commitType is ture, then restakeDuration is necessary.
    /// @param _isCommit Type of deposit. true/false = commit/uncommit.
    /// @return mintAmount The amount of $HEX1 to mint.
    function _depositCollateral(
        address _depositor, 
        uint256 _amount,
        uint256 _duration,
        uint256 _restakeDuration,
        bool _isCommit
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
            stakeId,
            _amount,
            shareAmount,
            mintAmount,
            block.timestamp,
            _duration,
            _restakeDuration,
            _isCommit,
            true
        );
        userInfos[_depositor].depositId = curDepositId + 1;
    }

    /// @notice Calculate shares amount and usd value.
    function _convertShare(uint256 _amount) internal view returns (uint256 usdValue, uint256 shareAmount) {
        IHexToken.GlobalsStore memory global = IHexToken(hexToken).globals();
        uint40 shareRate = global.shareRate;    // shareRate's basePoint is 10.

        uint8 hexDecimals = TokenUtils.expectDecimals(hexToken);
        uint256 basePoint = 10**hexDecimals;
        shareAmount = _amount / shareRate;  // shareAmount: decimals 8

        uint256 hexPrice = IHexOnePriceFeed(hexOnePriceFeed).getHexTokenPrice(basePoint);
        usdValue = hexPrice * _amount / basePoint;
    }
}