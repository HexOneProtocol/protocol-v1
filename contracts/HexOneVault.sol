// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./utils/TokenUtils.sol";
import "./interfaces/IHexOneVault.sol";
import "./interfaces/IHexOnePriceFeed.sol";

contract HexOneVault is Ownable, IHexOneVault {

    using SafeERC20 for IERC20;

    /// @dev The address of HexOneProtocol contract.
    address public hexOneProtocol;

    /// @dev The contract address to get token price.
    address private hexOnePriceFeed;

    /// @dev The address of collateral(base token).
    /// @dev It can't be updates if is't set once.
    address immutable public baseToken;

    /// @dev The total amount of locked base token.
    uint256 private totalLocked;

    /// @dev The total USD value of locked base tokens.
    uint256 private lockedUSDValue;

    // @dev Share rate to calculate shareAmount from collaterals.
    uint256 public shareRate;

    uint16 public LIMIT_PRICE_PERCENT = 66; // 66%

    /// @dev User infos to mange deposit and retrieve.
    mapping(address => UserInfo) private userInfos;

    modifier onlyHexOneProtocol {
        require (msg.sender == hexOneProtocol, "only hexOneProtocol");
        _;
    }

    constructor (
        address _baseToken,
        address _hexOnePriceFeed
    ) {
        require (_baseToken != address(0), "zero base token address");
        require (_hexOnePriceFeed != address(0), "zero priceFeed contract address");

        baseToken = _baseToken;
        hexOnePriceFeed = _hexOnePriceFeed;

        uint8 decimals = TokenUtils.expectDecimals(_baseToken);
        uint256 amount = 10**decimals;
        shareRate = IHexOnePriceFeed(_hexOnePriceFeed).getBaseTokenPrice(_baseToken, amount);
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
    function depositCollateral(
        address _depositor, 
        uint256 _amount,
        uint256 _duration,
        uint256 _restakeDuration,
        bool _isCommit
    ) external onlyHexOneProtocol override returns (uint256 shareAmount) {
        require (!_isCommit || _restakeDuration > 0, "wrong restake duration");
        address sender = msg.sender;
        IERC20(baseToken).safeTransferFrom(sender, address(this), _amount);
        
        return _depositCollateral(_depositor, _amount, _duration, _restakeDuration, _isCommit);
    }

    /// @inheritdoc IHexOneVault
    function claimCollateral(
        address _depositor,
        uint256 _depositId
    ) external onlyHexOneProtocol override returns (uint256 mintAmount, bool burnMode) {
        UserInfo storage userInfo = userInfos[_depositor];
        DepositInfo storage depositInfo = userInfo.depositInfos[_depositId];
        require (depositInfo.exist, "not exist deposit pool");
        require (depositInfo.depositTime + depositInfo.duration < block.timestamp, "can not claim before maturity");

        uint256 depositedAmount = depositInfo.amount;
        bool isCommitType = depositInfo.isCommitType;
        uint256 yieldCollateralAmount = _getYieldCollateralAmount(depositedAmount, depositInfo.duration);
        uint256 retrieveAmount = depositedAmount + yieldCollateralAmount;
        uint256 shareAmount = 0;

        _updateLockedValue(depositedAmount, false);
        if (!isCommitType) {
            IERC20(baseToken).safeTransfer(_depositor, retrieveAmount);
        } else {
            shareAmount = _depositCollateral(
                _depositor, 
                retrieveAmount, 
                depositInfo.restakeDuration, 
                depositInfo.restakeDuration, 
                true
            );
        }

        depositInfo.exist = false;
        return (shareAmount, depositInfo.isCommitType);
    }

    /// @inheritdoc IHexOneVault
    function emergencyWithdraw() external onlyOwner {
        uint256 currentUSDValue = IHexOnePriceFeed(hexOnePriceFeed).getBaseTokenPrice(baseToken, totalLocked);
        uint256 limitUSDValue = totalLocked * LIMIT_PRICE_PERCENT / 100;
        require (limitUSDValue > currentUSDValue, "emergency withdraw condition not meet");
        IERC20(baseToken).safeTransfer(msg.sender, totalLocked);
    }

    function _depositCollateral(
        address _depositor, 
        uint256 _amount,
        uint256 _duration,
        uint256 _restakeDuration,
        bool _isCommit
    ) internal returns (uint256 shareAmount) {
        shareAmount = _convertToShare(_amount, _duration);

        UserInfo storage userInfo = userInfos[_depositor];
        uint256 depositId = userInfo.depositId;
        _restakeDuration = _isCommit ? _restakeDuration : 0;
        userInfo.depositInfos[depositId] = DepositInfo(_amount, shareAmount, block.timestamp, _duration, _restakeDuration, _isCommit, true);
        userInfo.depositId += 1;

        _updateLockedValue(_amount, true);
    }

    /// @notice Calculate shares amount.
    /// @dev shares = (input HEX + bonuses(input HEX, stake days)) / Share Rate
    ///      New Share Rate = ((input HEX + payouts) + bonuses((input HEX + payouts), stake days)) / shares
    /// @param _collateralAmount The amount of collateral.
    /// @param _duration The maturity duration.
    /// @return shareAmount The calculated share amount.
    function _convertToShare(uint256 _collateralAmount, uint256 _duration) internal returns (uint256 shareAmount) {
        // TODO calculate share amount.

        // Update share rate.
        _updateShareRate(_collateralAmount, _duration);

        return 0;
    }

    /// @notice Update shares rate.
    /// @dev New Share Rate = ((input HEX + payouts) + bonuses((input HEX + payouts), stake days)) / shares
    /// @param _collateralAmount The amount of collateral.
    /// @param _duration The maturity duration.
    function _updateShareRate(uint256 _collateralAmount, uint256 _duration) internal {
        // TODO calculate new shareRate.
    }

    /// @notice Update locked base token amount and usd value.
    /// @param _collateralAmount The amount of collateral.
    /// @param _add Add or remove collateral amount.
    function _updateLockedValue(uint256 _collateralAmount, bool _add) internal {
        uint256 usdValue = IHexOnePriceFeed(hexOnePriceFeed).getBaseTokenPrice(baseToken, _collateralAmount);
        totalLocked = _add ? totalLocked + _collateralAmount : totalLocked - _collateralAmount;
        if (_add) {
            lockedUSDValue += usdValue;
        } else {
            lockedUSDValue = lockedUSDValue < usdValue ? 0 : lockedUSDValue - usdValue;
        }
    }

    /// @notice Calculate yield collateral amount based one amount and duration.
    /// @param _collateralAmount The amount of collateral.
    /// @param _duration The timestamp of duration.
    function _getYieldCollateralAmount(uint256 _collateralAmount, uint256 _duration) internal view returns (uint256) {
        // TODO Calcaulte yield collateral amount.
        return 0;
    }
}