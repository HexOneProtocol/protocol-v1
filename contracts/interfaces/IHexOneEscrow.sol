// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

interface IHexOneEscrow {
    struct EscrowOverview {
        uint256 totalUSDValue;
        uint256 startTime;
        uint256 endTime;
        uint256 curDay;
        uint256 hexAmount;
        uint256 effectiveAmount;
        uint256 borrowedAmount;
        uint256 initUSDValue;
        uint16 shareOfPool;
    }

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

    function borrowHexOne(uint256 curPrice) external;

    function getOverview(
        address _user
    ) external view returns (EscrowOverview memory);
}
