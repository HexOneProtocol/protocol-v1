// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IHexOneVault {

    struct DepositInfo {
        uint256 amount;
        uint256 shares;
        uint256 depositTime;
        uint256 duration;
        uint256 restakeDuration;
        bool isCommitType;
        bool exist;
    }

    struct UserInfo {
        uint256 depositId;
        uint256 shareBalance;
        uint256 depositedBalance;
        mapping(uint256 => DepositInfo) depositInfos;
    }

    /// @notice base token of vault.
    function baseToken() external view returns (address baseToken);

    /// @notice The share balance and deposited balance of user.
    function balanceOf(address _user) external view returns (uint256, uint256);

    /// @notice Get calimable share amount and base token amount.
    function claimableAmount(address _user) external view returns (
        uint256 shareAmount, 
        uint256 tokenAmount, 
        uint256[] memory claimableIds
    );

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
    /// @return shareAmount The amount of T-SHARES.
    function depositCollateral(
        address _depositor, 
        uint256 _amount, 
        uint256 _duration, 
        uint256 _restakeDuration,
        bool _isCommitType
    ) external returns (uint256 shareAmount);

    /// @notice Retrieve collateral after maturity.
    /// @dev Users can claim collateral after maturity.
    /// @return mintAmount If depositor's commitType is true then 
    ///         calculate shareAmount based on restake amount and duration.
    /// @return burnAmount The amount of $HEX1 should be burn.
    /// @return burnMode Present depositor's commit type.
    function claimCollateral(
        address _depositor,
        uint256 _depositId
    ) external returns (uint256 mintAmount, uint256 burnAmount, bool burnMode);

    /// @notice If total USD value is below 66% of initial USD value,
    ///         can call emergency withdraw.
    /// @dev Only owner can call this function.
    function emergencyWithdraw() external;

    /// @notice Set new limitPricePercent.
    ///         If total locked USD value is below that, emergencyWithdraw will occur.
    /// @dev Only owne can call this function.
    /// @param _percent New limitPricePercent.
    function setLimitPricePercent(uint16 _percent) external;

    event CollateralClaimed(address indexed claimer, uint256 claimedAmount);

    event CollateralRestaked(address indexed staker, uint256 restakedAmount, uint256 restakeDuration);
}