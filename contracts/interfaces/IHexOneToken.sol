// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IHexOneToken {
    /// @notice Mint $HEX1 token to recipient.
    /// @dev Only HexOneProtocol can call this function.
    /// @param _amount The amount of $HEX1 to mint.
    /// @param _recipient The address of recipient.
    function mintToken(uint256 _amount, address _recipient) external;

    /// @notice burn $HEX1 token as much as _amount.
    function burnToken(uint256 _amount, address _account) external;

    /// @notice Set admin address. HexOneProtocol is admin.
    /// @dev This function can be called by only owner.
    /// @param _admin The address of admin.
    function setAdmin(address _admin) external;

    function setDeployer(address _deployer) external;
}
