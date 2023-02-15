// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IHexOneProtocol {

    /// @notice Add/Remove vaults.
    /// @dev Only owner can call this function.
    /// @param _vaults The address of vaults.
    /// @param _add Add/Remove = true/false.
    function setVaults(address[] memory _vaults, bool _add) external;

    /// @notice Set Min stake duration.
    /// @dev Only owner can call this function.
    /// @param _minDuration The min stake duration days.
    function setMinDuration(uint256 _minDuration) external;

    /// @notice Set Max stake duration.
    /// @dev Only owner can call this function.
    /// @param _maxDuration The max stake duration days.
    function setMaxDuration(uint256 _maxDuration) external;

    /// @notice Add collateral to certain deposit pool to cover loss.
    /// @dev Depositors can't deposit as commitType. as only uncommit.
    /// @param _token The address of collateral to deposit.
    /// @param _amount The amount of collateral to deposit.
    /// @param _depositId The id of deposit to add collateral.
    /// @param _duration The duration days.
    function addCollateralForLiquidate(
        address _token,
        uint256 _amount,
        uint256 _depositId,
        uint16 _duration
    ) external;

    /// @notice Deposit collateral and receive $HEX1 token.
    /// @param _token The address of collateral to deposit.
    /// @param _amount The amount of collateral to deposit.
    /// @param _duration The duration days.
    /// @param _isCommit Present commit or uncommit. true/false.
    function depositCollateral(
        address _token, 
        uint256 _amount, 
        uint16 _duration,
        bool _isCommit
    ) external;

    /// @notice Borrow more $HEX1 token based on already deposited collateral.
    /// @param _token The address of token already deposited.
    /// @param _depositId The vault depositId to borrow.
    /// @param _amount The amount of $HEX1 to borrow.
    function borrowHexOne(
        address _token,
        uint256 _depositId,
        uint256 _amount
    ) external;

    /// @notice Claim/restake collateral
    /// @param _token The address of collateral.
    /// @param _depositId The deposit id to claim.
    function claimCollateral(
        address _token,
        uint256 _depositId
    ) external;

    event HexOneMint(address indexed recipient, uint256 amount);
}