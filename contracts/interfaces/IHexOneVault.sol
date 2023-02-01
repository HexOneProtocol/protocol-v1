// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IHexOneVault {

    struct DepositInfo {
        uint256 amount;
        uint256 shares;
        uint256 depositTime;
        bool isCommitType;
    }

    struct UserInfo {
        uint256 depositId;
        mapping(uint256 => DepositInfo) depositInfos;
        bool claimed;
    }

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
    /// @param _isCommitType Type of deposit. true/false = commit/uncommit.
    /// @return shareAmount The amount of T-SHARES.
    function depositCollateral(address _depositor, uint256 _amount, uint256 _duration, bool _isCommitType) external returns (uint256 shareAmount);

    /// @notice If total USD value is below 66% of initial USD value,
    ///         can call emergency withdraw.
    /// @dev Only owner can call this function.
    function emergencyWithdraw() external;
}