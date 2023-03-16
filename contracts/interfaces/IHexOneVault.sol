// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IHexOneVault {

    struct DepositInfo {
        uint256 vaultDepositId;
        uint256 stakeId;
        uint256 amount;
        uint256 shares;
        uint256 mintAmount;
        uint256 depositedHexDay;
        uint256 initHexPrice;
        uint16 duration;
        uint16 graceDay;
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
        uint256 borrowableAmount;
        uint256 effectiveAmount;
        uint256 initialHexPrice;
        uint256 lockedHexDay;
        uint256 endHexDay;
        uint256 curHexDay;
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
        address depositor;
        uint256 depositId;
        uint256 curHexDay;
        uint256 endDay;
        uint256 effectiveHex;
        uint256 borrowedHexOne;
        uint256 initHexPrice;
        uint256 currentHexPrice;
        uint256 depositedHexAmount;
        uint256 currentValue;
        uint256 initUSDValue;
        uint256 currentUSDValue;
        uint16 graceDay;
        bool liquidable;
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
    /// @param _vaultDepositId The vault deposit id to borrow.
    /// @param _amount The amount of $HEX1 token.
    function borrowHexOne(address _depositor, uint256 _vaultDepositId, uint256 _amount) external;

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
    /// @return mintAmount The amount of $HEX1 to mint.
    function depositCollateral(
        address _depositor, 
        uint256 _amount, 
        uint16 _duration
    ) external returns (uint256 mintAmount);

    /// @notice Retrieve collateral after maturity.
    /// @dev Users can claim collateral after maturity.
    /// @return burnAmount Amount of $HEX1 token to burn.
    /// @return mintAmount Amount of $HEX1 token to mint.
    function claimCollateral(
        address _claimer,
        uint256 _vaultDepositId,
        bool _restake
    ) external returns (uint256 burnAmount, uint256 mintAmount);

    /// @notice Get liquidable vault deposit Ids.
    function getLiquidableDeposits() external view returns (LiquidateInfo[] memory);

    /// @notice Get t-share balance of user.
    function getShareBalance(address _account) external view returns (uint256);

    function getUserInfos(address _account) external view returns (DepositShowInfo[] memory);

    /// @notice Set limit claim duration.
    /// @dev Only owner can call this function.
    function setLimitClaimDuration(uint16 _duration) external;

    event CollateralClaimed(address indexed claimer, uint256 claimedAmount);

    event CollateralRestaked(address indexed staker, uint256 restakedAmount, uint16 restakeDuration);
}