// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

interface IHexOneSacrifice {
    struct SacrificeInfo {
        uint256 sacrificeId;
        uint256 day;
        uint256 supplyAmount;
        uint256 sacrificedAmount;
        uint256 sacrificedWeight;
        uint256 usdValue;
        uint256 totalHexitAmount;
        address sacrificeToken;
        string sacrificeTokenSymbol;
        uint16 multiplier;
        bool claimed;
    }

    /// @notice Check if now is after sacrificeEndTime.
    function afterSacrificeDuration() external view returns (bool);

    /// @notice minted HEXIT amount for sacrifice.
    function HEXITAmountForSacrifice()
        external
        view
        returns (uint256 HEXITAmountForSacrifice);

    /// @notice received HEXIT token amount of _user for sacrifice.
    function userRewardsForSacrifice(
        address _user
    ) external view returns (uint256);

    /// @notice Check if user is sacrifice participant.
    function isSacrificeParticipant(address _user) external view returns (bool);

    function getUserSacrificeInfo(
        address _user
    ) external view returns (SacrificeInfo[] memory);

    /// @notice Get sacrifice participants.
    function getSacrificeParticipants()
        external
        view
        returns (address[] memory);

    /// @notice Get HEXIT amount for sacrifice by day index.
    function getAmountForSacrifice(
        uint256 _dayIndex
    ) external view returns (uint256);

    /// @notice Get current sacrifice day index.
    function getCurrentSacrificeDay() external view returns (uint256);

    /// @notice Attend to sacrifice.
    /// @dev Anyone can attend to this but should do this with allowed token.
    function sacrificeToken(address _token, uint256 _amount) external;

    /// @notice Claim HEXIT as rewards for sacrifice.
    function claimRewardsForSacrifice(uint256 _sacrificeId) external;
}
