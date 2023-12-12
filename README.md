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


$ cast call 0x6F1747370B1CAcb911ad6D4477b718633DB328c8 "token0()(address)" --rpc-url "https://rpc.pulsechain.com"
0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39

$ cast call 0x6F1747370B1CAcb911ad6D4477b718633DB328c8 "token1()(address)" --rpc-url "https://rpc.pulsechain.com"
0xefD766cCb38EaF1dfd701853BFCe31359239F305

$ cast call 0x6F1747370B1CAcb911ad6D4477b718633DB328c8 "price0CumulativeLast()(uint256)" --rpc-url "https://rpc.pulsechain.com"
11958060672516864139326204842964478565015734169920 [1.195e49]

$ cast call 0x6F1747370B1CAcb911ad6D4477b718633DB328c8 "price1CumulativeLast()(uint256)" --rpc-url "https://rpc.pulsechain.com"
863799371889934988612902382734900 [8.637e32]

$ cast call 0x6F1747370B1CAcb911ad6D4477b718633DB328c8 "getReserves()(uint256,uint256,uint32)" --rpc-url "https://rpc.pulsechain.com"
974521338888232 [9.745e14]        
75781953710016847292693 [7.578e22]
1702389985 [1.702e9]