// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

interface IHexOneVault {
    struct DepositInfo {
        uint256 amount;
        uint256 shares;
        uint256 borrowed;
        uint256 depositHexDay;
        uint16 duration;
        bool active;
    }

    struct UserInfo {
        uint256 totalAmount;
        uint256 totalShares;
        uint256 totalBorrowed;
    }

    event Deposited(
        address indexed depositor, uint256 indexed stakeId, uint256 hexDeposited, uint256 depositHexDay, uint16 duration
    );
    event Claimed(address indexed depositor, uint256 indexed stakeId, uint256 hexClaimed, uint256 hexOneRepaid);
    event Borrowed(address indexed depositor, uint256 indexed stakeId, uint256 hexOneBorrowed);
    event Liquidated(
        address indexed liquidator,
        address indexed depositor,
        uint256 indexed stakeId,
        uint256 hexClaimed,
        uint256 hexOneRepaid
    );

    error InvalidAddress();
    error NotHexOneProtocol();
    error InvalidDepositDuration();
    error ZeroDepositAmount();
    error DepositNotActive();
    error SharesNotYetMature();
    error PositionLiquidatable();
    error PositionNotLiquidatable();
    error InvalidQuote();
    error PriceConsultationFailed();
    error CantBorrowFromMatureDeposit();
    error BorrowAmountTooHigh();
    error InvalidBorrowAmount();

    function deposit(uint256 _amount, uint16 _duration) external returns (uint256);
    function claim(uint256 _stakeId) external returns (uint256);
    function borrow(uint256 _amount, uint256 _stakeId) external;
    function liquidate(address _depositor, uint256 _stakeId) external returns (uint256);
}
