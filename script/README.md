# Deployment Guide
Quick guide on deploying and setting up the protocol on Pulsechain Mainnet using scripts.

## Pulsechain Deployment
Before trying to deploy the protocol a private key must be specified in `.env`.

### Deployment
```
forge script script/deployment/Deploy.s.sol:Deploy --rpc-url https://rpc.pulsechain.com --broadcast -vvvv
```

## Anvil Local Pulsechain Fork Deployment
Start an anvil node forking Pulsechain Mainnet.
```
anvil --accounts 1 --balance 1000000 --fork-url https://rpc.pulsechain.com
```

Add the listed private key by anvil to the `.env` file.
```
export PRIVATE_KEY="PRIVATE_KEY"
```

### Deployment
Used to deploy and configure the protocol.
```
forge script script/deployment/Deploy.s.sol:Deploy --fork-url http://localhost:8545 --broadcast -vvvv
```

```
forge script script/keeper-test/Keeper.s.sol:KeeperScript --fork-url https://rpc.pulsechain.com --broadcast -vvvv
```