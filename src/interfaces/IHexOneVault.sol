// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

interface IHexOneVault {
    struct Stake {
        uint256 debt;
        uint72 amount;
        uint72 shares;
        uint40 param;
        uint16 start;
        uint16 end;
    }

    event Deposited(address indexed account, uint256 indexed id, uint256 hxAmount);
    event Withdrawn(address indexed account, uint256 indexed id, uint256 hxAmount, uint256 hdrnAmount);
    event Repaid(address indexed account, uint256 indexed id, uint256 hex1Amount);
    event Liquidated(address indexed account, uint256 indexed id, uint256 hxAmount, uint256 hdrnAmount);
    event Borrowed(address indexed account, uint256 indexed id, uint256 hex1Amount);
    event Took(address indexed account, uint256 indexed id, uint256 hex1Amount);

    error ZeroAddress();
    error InvalidAmount();
    error InvalidOwner();
    error StakeNotMature();
    error StakeMature();
    error StakeNotLiquidatable();
    error StakeLiquidatable();
    error MaxBorrowExceeded();
    error HealthRatioTooLow();
    error RatioHealthy();
    error NotEnoughToTake();
}
