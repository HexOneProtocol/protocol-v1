// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IHexOneVault {

    struct DepositInfo {
        uint256 vaultDepositId;
        uint256 stakeId;
        uint256 amount;
        uint256 shares;
        uint256 mintAmount;
        uint256 borrowedAmount;
        uint256 depositedTimestamp;
        uint256 duration;
        uint256 restakeDuration;
        bool isCommitType;
        bool exist;
    }

    struct UserInfo {
        uint256 depositId;
        uint256 shareBalance;
        uint256 depositedBalance;
        uint256 totalBorrowedAmount;
        mapping(uint256 => DepositInfo) depositInfos;
    }

    struct DepositShowInfo {
        uint256 depositId;
        uint256 depositAmount;
        uint256 shareAmount;
        uint256 mintAmount;
        uint256 lockedTimestamp;
        uint256 endTimestamp;
    }

    struct BorrowableInfo {
        uint256 depositId;
        uint256 borrowableAmount;
    }

    struct VaultDepositInfo {
        address userAddress;
        uint256 userDepositId;
    }

    struct LiquidateInfo {
        uint256 depositId;
        address depositor;
        uint256 hexTokenAmount;
        uint256 liquidateAmount;
    }

    function baseToken() external view returns (address baseToken);

    /// @notice Get borrowable amount based on already deposited collateral amount.
    function getBorrowableAmounts(address _account) external view returns (BorrowableInfo[] memory);

    /// @notice Get total borrowed $HEX1 of user.
    /// @param _account The address of _account.
    function getBorrowedBalance(address _account) external view returns (uint256);
    
    /// @notice Borrow additional $HEX1 from already deposited collateral amount.
    /// @dev If collateral price is increased, there will be profit.
    ///         Based on that profit, depositors can borrow $HEX1 additionally.
    /// @param _depositor The address of depositor (borrower)
    /// @param _depositId The vault deposit id to borrow.
    /// @param _amount The amount of $HEX1 token.
    function borrowHexOne(address _depositor, uint256 _depositId, uint256 _amount) external;

    /// @notice Set hexOneProtocol contract address.
    /// @dev Only owner can call this function and 
    ///      it should be called as intialize step.
    /// @param _hexOneProtocol The address of hexOneProtocol contract.
    function setHexOneProtocol(address _hexOneProtocol) external;

    /// @notice Deposit collateral and mint $HEX1 token to depositor.
    ///         Collateral should be converted to T-SHARES and return.
    /// @dev Only HexOneProtocol can call this function.
    ///      T-SHARES will be locked for maturity, 
    ///      it means deposit can't retrieve collateral before maturity.
    /// @param _depositor The address of depositor.
    /// @param _amount The amount of collateral.
    /// @param _duration The maturity duration.
    /// @param _restakeDuration If commitType is ture, then restakeDuration is necessary.
    /// @param _isCommitType Type of deposit. true/false = commit/uncommit.
    /// @return mintAmount The amount of $HEX1 to mint.
    function depositCollateral(
        address _depositor, 
        uint256 _amount, 
        uint256 _duration, 
        uint256 _restakeDuration,
        bool _isCommitType
    ) external returns (uint256 mintAmount);

    /// @notice Add collateral to certain deposit Id to cover loss.
    /// @dev Depositors only add collateral and don't receive $HEX1 token as compensation.
    /// @param _depositor The address of depositor.
    /// @param _amount The amount of collateral.
    /// @param _depositId The certain deposit id to cover loss.
    /// @param _duration The maturity duration.
    /// @return burnAmount The amount of $HEX1 to burn.
    function addCollateralForLiquidate(
        address _depositor,
        uint256 _amount,
        uint256 _depositId,
        uint256 _duration
    ) external returns (uint256 burnAmount);

    /// @notice Retrieve collateral after maturity.
    /// @dev Users can claim collateral after maturity.
    /// @return mintAmount If depositor's commitType is true then 
    ///         calculate shareAmount based on restake amount and duration.
    /// @return burnAmount The amount of $HEX1 should be burn.
    function claimCollateral(
        address _claimer,
        uint256 _depositId
    ) external returns (uint256 mintAmount, uint256 burnAmount, uint256 liquidateAmount);

    /// @notice Get liquidable vault deposit Ids.
    function getLiquidableDeposits() external view returns (LiquidateInfo[] memory);

    /// @notice Get t-share balance of user.
    function getShareBalance(address _account) external view returns (uint256);

    function getUserInfos(address _account) external view returns (DepositShowInfo[] memory);

    /// @notice Set new limitPricePercent.
    ///         If total locked USD value is below that, emergencyWithdraw will occur.
    /// @dev Only owne can call this function.
    /// @param _percent New limitPricePercent.
    function setLimitPricePercent(uint16 _percent) external;

    /// @notice Set limit claim duration.
    /// @dev Only owner can call this function.
    function setLimitClaimDuration(uint256 _duration) external;

    event CollateralClaimed(address indexed claimer, uint256 claimedAmount);

    event CollateralRestaked(address indexed staker, uint256 restakedAmount, uint256 restakeDuration);
}