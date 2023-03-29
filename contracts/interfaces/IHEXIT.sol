// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IHEXIT is IERC20 {
    /// @notice Mint $HEXIT token to recipient.
    /// @dev Only HexOneProtocol can call this function.
    /// @param _amount The amount of $HEXIT to mint.
    /// @param _recipient The address of recipient.
    function mintToken(uint256 _amount, address _recipient) external;

    /// @notice Set admin address. HexBootstrap is admin.
    /// @dev This function can be called by only owner.
    /// @param _bootstrap The address of HexBootstrap.
    function setBootstrap(address _bootstrap) external;
}
