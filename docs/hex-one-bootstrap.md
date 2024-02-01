# HexOneBootstrap.sol

## Overview
The bootstrap consists of 5 major phases:
1. **Sacrifice**: During a 30 days period, participants can sacrifice tokens (HEX, DAI, WPLS, PLSX). The amount of HEXIT allocated to the participant is computed based on the amount sacrificed in USD during this period.
2. **Process Sacrifice**: After the sacrifice period, the owner swaps 12.5% of the total HEX deposited in the contract to DAI, and another 12.5% is deposited to mint HEX1. The resulting amounts are used to create a PulseX HEX1/DAI pair with 1:1 ratio.
3. **Claim Sacrifice**: During a 7 days period, sacrifice participants can claim their HEXIT allocation and create an HEX stake to mint HEX1 with 75% of the sacrificed USD (minus a 5% fee for the Hex One Staking contract).
4. **Start Airdrop**: After the sacrifice claim period is finished, the owner mints 50% more HEXIT to the team wallet, and another 33% to the Hex One Staking contract on top of the total HEXIT minted during the claim sacrifice period. It also enables the Hex One Staking contract.
5. **Claim Airdrop**: The airdrop claim phase is a 30 days period where both sacrifice participants and HEX stakers can claim more HEXIT.

## Bootstrap Sacrifice
During a 30 days period, participants can sacrifice tokens. By doing so, once the sacrifice period ends, participants of the sacrifice get a 7 day period to mint `HEXIT` based on the sacrificed USD amount, and mint `HEX1` by creating an `HEX` stake through the Hex One Vault.
```
Sacrifice USD Amount * Bonus Multiplier * Base Daily HEXIT Sacrifice
```

### Sacrificed USD Amount
Amount of USD sacrificed by the user in the moment of the sacrifice.

### Bonus Multiplier
Depending on the sacrificed token, a bonus multiplier is applied.
| Sacrifice Token | Multiplier |
|:---------------:|:----------:|
|       HEX       |    5.555   |
|       DAI       |     3      |
|       WPLS      |     2      |
|       PLSX      |     1      |

### Base Daily HEXIT Sacrifice
The Sacrifice Base Daily HEXIT decreases 4.76% daily for 30 days.
| Day           | Base Daily HEXIT |
|:-------------:|:----------------:|
|      1        |    5,555,555     |
|      ...      |       ...        |
|      10       |    3,655,183     |
|      15       |    2,896,669     |
|      20       |    2,295,560     |
|      25       |    1,819,192     |
|      30       |    1,441,678     |

## Bootstrap Airdrop
The airdrop claim phase lasts for 30 days and allows both sacrifice participants and non-sacrifice participants to claim `HEXIT` based on the amount of `HEX` in USD they have currently staked, and the amount of USD sacrificed.
```
(9 * Sacrifice USD Amount) + (1 * Hex Staking Total USD) + Base Daily HEXIT Airdrop
```

### Sacrifice USD Amount
Total amount of USD sacrificed by the user during the sacrifice period.

### HEX Staking Total USD
Total amount of `HEX` in USD the user has staked.

### Base Daily HEXIT Airdrop
The Airdrop Base Daily HEXIT decreases 50% daily for 30 days.
| Day           | Base Daily HEXIT |
|:-------------:|:----------------:|
|      1        |    2,777,778     |
|      ...      |       ...        |
|      10       |    5,425         |
|      15       |    170           |
|      20       |    5             |
|      25       |    0.166         |
|      30       |    0.005         |

## Structs
```solidity
struct UserInfo {
    uint256 hexitShares;
    uint256 sacrificedUSD;
    bool claimedSacrifice;
    bool claimedAirdrop;
}
```
Tracks user sacrifice allocation of HEXIT, the total amount sacrificed in USD, and reward claim flags for both the sacrifice and airdrop phases.

## Events
### Sacrificed
```solidity
event Sacrificed(
    address indexed user,
    address indexed token,
    uint256 amountSacrificed,
    uint256 amountSacrificedUSD,
    uint256 hexitSharesEarned
);
```
Emitted each time tokens are sacrificed via [sacrifice](#sacrifice).

### SacrificeProcessed
```solidity
event SacrificeProcessed(address hexOneDaiPair, uint256 hexOneAmount, uint256 daiAmount, uint256 liquidity);
```
Emitted once when sacrifice is processed by the owner via [processSacrifice](#processsacrifice).

### SacrificeClaimed
```solidity
event SacrificeClaimed(address indexed user, uint256 hexOneMinted, uint256 hexitMinted);
```
Emitted each time a user claims its sacrifice rewards via [claimSacrifice](#claimsacrifice).

### AirdropStarted
```solidity
event AirdropStarted(uint256 hexitTeamAlloc, uint256 hexitStakingAlloc);
```
Emitted once when airdrop is started by the owner via [airdropStarted](#airdropstarted).

### AirdropClaimed
```solidity
event AirdropClaimed(address indexed user, uint256 hexitMinted);
```
Emitted each time a user claims its airdrop rewards via [claimAirdrop](#claimairdrop).


## Read-Only Functions

### getCurrentSacrificeDay
```solidity
function getCurrentSacrificeDay() public view returns (uint256);
```
Returns the current day of the sacrifice since ``sacrificeStart``. Reverts if sacrifice has not started yet or if its already finished.

### getCurrentAirdropDay
```solidity
function getCurrentAirdropDay() public view returns (uint256);
```
Returns the current day of the airdrop since ``airdropStart``. Reverts if airdrop has not started yet or if its already finished.


## State-Changing Functions

### setBaseData
```solidity
function setBaseData(address _hexOnePriceFeed, address _hexOneStaking, address _hexOneVault) external;
```

Used by the owner to configure other protocol contract addresses.

### setSacrificeTokens
```solidity
function setSacrificeTokens(address[] calldata _tokens, uint16[] calldata _multipliers) external;
```

Used by the owner to set the allowed tokens to [sacrifice](#sacrifice) and it's respective [multipliers](#bonus-multiplier).

### setSacrificeStart
```solidity
function setSacrificeStart(uint256 _sacrificeStart) external;
```

Used by the owner to set the starting timestamp of the sacrifice.

### sacrifice
```solidity
function sacrifice(address _token, uint256 _amountIn, uint256 _amountOutMin) external;
```

Users can [sacrifice tokens](#bonus-multiplier) to get a bigger HEXIT allocation. If the token sacrificed is ``HEX`` the parameter ``_amountOutMin`` can be set to ``0``.

* Emits [Sacrificed](#sacrificed).

### processSacrifice
```solidity
function processSacrifice(uint256 _amountOutMinDai) external;
```

Can only be called once by the owner to bootstrap HEX1/DAI liquidity and enable the Hex One Vault.

* Emits [SacrificeProcessed](#sacrificeprocessed).

### claimSacrifice
```solidity
function claimSacrifice() external returns (uint256 stakeId, uint256 hexOneMinted, uint256 hexitMinted);
```

Allows sacrifice participants to mint their ``HEXIT`` allocation, and mint ``HEX1`` through the Hex One Vault, based on the participant's sacrificed USD.

* Emits [SacrificeClaimed](#sacrificeclaimed).

### startAirdrop
```solidity
function startAidrop() external;
```

Can only be called once by the owner to start the aidrop. On top of the total ``HEXIT`` minted during sacrifice 50% more HEXIT is minted to the `teamWallet`, and another 33% is minted to the Hex One Staking contract be distributed as staking rewards.

* Emits [AirdropStared](#airdropstarted).

### claimAirdrop
```solidity
function claimAirdrop() external;
```
Allows `HEX` stakers and sacrifice participants to claim `HEXIT`.

* Emits [AirdropClaimed](#airdropclaimed).
