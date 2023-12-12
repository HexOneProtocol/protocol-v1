# Hex One Protocol
Technical documentation of Hex One Protocol smart contracts.

## HexOneToken

## HexitToken

## HexOneStaking
The contract has two different pools: the `HEX` and the `HEXIT` pool, and three allowed tokens to be staked: `HEX1`, `HEXIT` and `HEX1/DAI LP`. Users are granted shares from both pools, and each pool has a daily distribution rate of 1% of the total tokens available that day. Depending on the token being staked users earn a bigger or smaller percentage of the tokens being distributed. Rewards can only be claimed 2 days after the stake.

| Stake Token | HEX Pool | HEXIT Pool |
|:-----------:|:--------:|:----------:|
|    HEXIT    |    10%   |     10%    |
|    HEX1     |    20%   |     20%    |
|   HEX1/DAI  |    70%   |     70%    |

## HexOnePriceFeed

## HexOneVault

## HexOneBootstrap

## HexOneEscrow

## HexOneProtocol
