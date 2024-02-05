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

    event VaultActivated(uint256 timestamp);
    event Deposited(
        address indexed depositor,
        uint256 indexed stakeId,
        uint256 hexOneMinted,
        uint256 hexDeposited,
        uint256 depositHexDay,
        uint16 duration
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

    error VaultAlreadyActive();
    error InvalidAddress(address addr);
    error SacrificeHasNotFinished();
    error NotHexOneBootstrap(address sender);
    error InvalidDepositDuration(uint16 depositDuration);
    error InvalidDepositAmount(uint256 amount);
    error PriceConsultationFailedInvalidQuote(uint256 quote);
    error PriceConsultationFailedBytes(bytes data);
    error PriceConsultationFailedString(string reason);
    error DepositNotActive(address depositor, uint256 stakeId);
    error SharesNotYetMature(address depositor, uint256 stakeId);
    error DepositLiquidatable(address depositor, uint256 stakeId);
    error InvalidBorrowAmount(uint256 amount);
    error CantBorrowFromMatureDeposit(address depositor, uint256 stakeId);
    error BorrowAmountTooHigh(uint256 amount);
    error DepositNotLiquidatable(address depositor, uint256 stakeId);
    error InvalidDepositor(address depositor);
    error ContractAlreadySet();

    function setSacrificeStatus() external;
    function setBaseData(address _hexOnePriceFeed, address _hexOneStaking, address _hexOneVault) external;
    function delegateDeposit(address depositor, uint256 _amount, uint16 _duration)
        external
        returns (uint256 amount, uint256 stakeId);
    function deposit(uint256 _amount, uint16 _duration) external returns (uint256 amount, uint256 stakeId);
    function claim(uint256 _stakeId) external returns (uint256);
    function borrow(uint256 _amount, uint256 _stakeId) external;
    function liquidate(address _depositor, uint256 _stakeId) external returns (uint256 hexAmount);
}
