// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IHexOneProtocol {

    struct DepositInfo {
        address[] depositedTokens;
        uint256[] shareAmounts;
        uint256[] depositedAmounts;
        uint256[] claimableShareAmount;
        uint256[] claimableTokenAmount;
        uint256[][] claimableIds;
    }

    /// @notice Add/Remove vaults.
    /// @dev Only owner can call this function.
    /// @param _vaults The address of vaults.
    /// @param _add Add/Remove = true/false.
    function setVaults(address[] memory _vaults, bool _add) external;

    /// @notice Get deposit infos by user.
    function getDepositInfo(address _user) external view returns (DepositInfo memory);

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

    /// @notice Claim/restake collateral
    /// @param _token The address of collateral.
    /// @param _depositId The deposit id to claim.
    function claimCollateral(
        address _token,
        uint256 _depositId
    ) external;

    /// @notice Get T-SHARE balance of user by collateral.
    /// @param _user The address of a user.
    /// @param _token The address of collateral.
    function getShareBalance(
        address _user,
        address _token
    ) external view returns (uint256);

    event HexOneMint(address indexed recipient, uint256 amount);
}