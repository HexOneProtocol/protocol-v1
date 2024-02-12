# HexOneVault.sol
## Overview
The Hex One Vault allows depositors to create a new `HEX` stake and borrow `HEX1` in a 1:1 ratio against it's dollar value. Depositors can always claim their underlying HEX + yield by repaying the exact borrowed amount of `HEX1` regardless of its dollar value. In the event of an HEX1/USD depeg depositors will **always** be able to claim their `HEX` stake.

Depositors may be susceptible to liquidation if they do not claim their deposit within a 7-day grace period following the end of the deposit. The deposit duration ranges from a minimum of 3642 days to a maximum of 5555 days.

## Structs
### DepositInfo
```solidity
struct DepositInfo {
    uint256 amount;
    uint256 shares;
    uint256 borrowed;
    uint256 depositHexDay;
    uint16 duration;
    bool active;
}
```
Tracks deposit data of a specific `stakeId` owned by a specific `depositor`.

### UserInfo
```solidity
struct UserInfo {
    uint256 totalAmount;
    uint256 totalShares;
    uint256 totalBorrowed;
}
```
Tracks deposit data across every stakeId owned by a specific `depositor`.

## Events
### VaultActivated
```solidity
event VaultActivated(uint256 timestamp);
```

Emitted once when the Vault is activated by the Hex One Bootstrap via [setVaultStatus](#setsacrificestatus).

### Deposited
```solidity
event Deposited(
    address indexed depositor,
    uint256 indexed stakeId,
    uint256 hexOneMinted,
    uint256 hexDeposited,
    uint256 depositHexDay,
    uint16 duration
);
```

Emitted each time a new deposit is created via [deposit](#deposit) or [delegateDeposit](#delegatedeposit).

### Claimed
```solidity
event Claimed(address indexed depositor, uint256 indexed stakeId, uint256 hexClaimed, uint256 hexOneRepaid);
```

Emitted each time a deposit is claimed via [claim](#claim).

### Borrowed 
```solidity
event Borrowed(address indexed depositor, uint256 indexed stakeId, uint256 hexOneBorrowed);
```

Emitted each time a depositor borrows against his deposit via [borrow](#borrow).

### Liquidated
```solidity
event Liquidated(
    address indexed liquidator,
    address indexed depositor,
    uint256 indexed stakeId,
    uint256 hexClaimed,
    uint256 hexOneRepaid
);
```

Emited each time a depositor is liquidated via [liquidate](#liquidate).

## State-Changing Functions

### setSacrificeStatus
```solidity
function setSacrificeStatus() external;
```
Called by the Hex One Bootstrap to activate vault funcionality.

* Emits [VaultActivated](#vaultactivated).

### setBaseData
```solidity
function setBaseData(address _hexOnePriceFeed, address _hexOneStaking, address _hexOneVault) external;
```

Used by the owner to configure other protocol contract addresses.

### deposit
```solidity
function deposit(uint256 _amount, uint16 _duration) external returns (uint256 amount, uint256 stakeId);
```

Creates an `HEX` stake for the user and mints `HEX1`. Returns the `amount` of `HEX1` minted and the `stakeId`.

* Emits [Deposited](#deposited).

### delegateDeposit
```solidity
function delegateDeposit (address depositor, uint256 _amount, uint16 _duration) external returns (uint256 amount, uint256 stakeId);
```

Used by the Hex One Bootstrap contract to create an `HEX` stake and mint `HEX1` to sacrifice participants.

* Emits [Deposited](#deposited).

### claim
```solidity
function claim(uint256 _stakeId) external returns (uint256);
```

Allow users to claim back their `HEX` by paying back `HEX1` if the underlying HEX stake is already mature.

* Emits [Claimed](#claimed).

### borrow
```solidity
function borrow(uint256 _amount, uint256 _stakeId) external;
```

Allow user to mint `HEX1` based on the current spot price in dollars of their underlying HEX stake.

* Emits [Borrowed](#borrowed).
  
### liquidate
```solidity
function liquidate(address _depositor, uint256 _stakeId) external returns (uint256 hexAmount);
```

Anyone can pay back `HEX1` to claim the underlying `HEX` + yield. Deposits are only liquidatable if `GRACE_PERIOD` has passed after the underlying HEX stake has matured.

* Emits [Liquidated](#liquidated).
