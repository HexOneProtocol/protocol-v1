// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IHexOneProtocol {
    struct Fee {
        uint16 feeRate;
        bool enabled;
    }

    /// @notice Get Max duration days for deposit.
    function getMaxDuration() external view returns (uint16);

    /// @notice Get Min duration days for deposit.
    function getMinDuration() external view returns (uint16);

    /// @notice Add/Remove vaults.
    /// @dev Only owner can call this function.
    /// @param _vaults The address of vaults.
    /// @param _add Add/Remove = true/false.
    function setVaults(address[] memory _vaults, bool _add) external;

    /// @notice Set HexOneEscrow conract address.
    /// @dev Only owner can call this function.
    function setEscrowContract(address _escrowCA) external;

    /// @notice Set stakingMaster contract address.
    /// @dev Only owner can call this function.
    /// @param _stakingMaster The address of staking Pool.
    function setStakingPool(address _stakingMaster) external;

    /// @notice Set Min stake duration.
    /// @dev Only owner can call this function.
    /// @param _minDuration The min stake duration days.
    function setMinDuration(uint16 _minDuration) external;

    /// @notice Set Max stake duration.
    /// @dev Only owner can call this function.
    /// @param _maxDuration The max stake duration days.
    function setMaxDuration(uint16 _maxDuration) external;

    /// @notice Set deposit fee by token.
    /// @dev Only owner can call this function.
    /// @param _token The address of token.
    /// @param _fee Deposit fee percent.
    function setDepositFee(address _token, uint16 _fee) external;

    /// @notice Enable/Disable deposit fee by token.
    /// @dev Only owner can call this function.
    /// @param _token The address of token.
    /// @param _enable Enable/Disable = true/false
    function setDepositFeeEnable(address _token, bool _enable) external;

    /// @notice Deposit collateral and receive $HEX1 token.
    /// @param _token The address of collateral to deposit.
    /// @param _amount The amount of collateral to deposit.
    /// @param _duration The duration days.
    function depositCollateral(
        address _token,
        uint256 _amount,
        uint16 _duration,
        address _depositor
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
    ) external returns (uint256);

    function claimHex(
        address _token,
        uint256 _depositId
    ) external returns (uint256);

    /// @notice Check that token is allowed or not.
    function isAllowedToken(address _token) external view returns (bool);

    /// @notice Get vault contract address by token.
    function getVaultAddress(address _token) external view returns (address);

    event HexOneMint(address indexed recipient, uint256 amount);
}
