// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

interface IHexOneEscrow {
    /// @notice Get balance of Hex that escrow contract hold.
    function balanceOfHex() external view returns (uint256);

    /// @notice deposit Hex token to HexOneProtocol.
    /// @dev This function can be called when only sacrifice finished 
    ///      and also can be called by only Owner.
    ///      escrow contract deposits Hex token as commitType and 
    ///      distribute received $HEX1 to sacrifice participants.
    function depositCollateralToHexOneProtocol(uint16 _duration) external;

    /// @notice It calls claimCollateral function of hexOneProtocol and
    ///         gets more $HEX1 token and distrubute it to sacrifice participants.
    function reDepositCollateral() external;
}