## HexOneVault

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

### UserInfo
```solidity
struct UserInfo {
    uint256 totalAmount;
    uint256 totalShares;
    uint256 totalBorrowed;
}
```

## Events
### VaultActivated
```solidity
event VaultActivated(uint256 timestamp);
```

Emitted each time tokens are sacrificed via [sacrifice](#sacrifice).

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

### Claimed
```solidity
event Claimed(address indexed depositor, uint256 indexed stakeId, uint256 hexClaimed, uint256 hexOneRepaid);
```

### Borrowed 
```solidity
event Borrowed(address indexed depositor, uint256 indexed stakeId, uint256 hexOneBorrowed);
```

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

## State-Changing Functions

### setSacrificeStatus
```solidity
function setSacrificeStatus() external;
```

Called by the Hex One Bootstrap to activate vault funcionality.

### setBaseData
```solidity
function setBaseData(address _hexOnePriceFeed, address _hexOneStaking, address _hexOneVault) external;
```

Used by the owner to configure other protocol contract addresses.

### deposit