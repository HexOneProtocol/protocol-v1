# Deployment Guide

Quick guide on deploying and setting up the protocol on Pulsechain Mainnet or locally using scripts.

## Pulsechain Deployment

### Deployment

```
forge script script/deployment/Deploy.s.sol:DeploymentScript --rpc-url https://rpc.pulsechain.com --broadcast -vvvv
```

### Set Sacrifice Start

```
forge script script/bootstrap/SacrificeStart.s.sol:SacrificeStartScript --rpc-url https://rpc.pulsechain.com --broadcast -vvvv
```

### Process Sacrifice

```
forge script script/bootstrap/ProcessSacrifice.s.sol:ProcessSacrificeScript --rpc-url https://rpc.pulsechain.com --broadcast -vvvv
```

### Start Airdrop

```
forge script script/bootstrap/StartAirdrop.s.sol:DeploymentScript --rpc-url https://rpc.pulsechain.com --broadcast -vvvv
```

### Renounce Ownership

```
forge script script/ownership/RenounceOwnership.s.sol:RenounceOwnershipScript --rpc-url https://rpc.pulsechain.com --broadcast -vvvv
```

## Pulsechain Fork Local Testnet Node Deployment

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
forge script script/deployment/Deploy.s.sol:DeploymentScript --fork-url http://localhost:8545 --broadcast
```

### Set Sacrifice Start

Used to set initial sacrifice timestamp.

```
forge script script/bootstrap/SacrificeStart.s.sol:SacrificeStartScript --fork-url http://localhost:8545 --broadcast
```

### Process Sacrifice

Used to process the sacrifice.

```
forge script script/bootstrap/ProcessSacrifice.s.sol:ProcessSacrificeScript --fork-url http://localhost:8545 --broadcast
```

### Start Airdrop

Used to start the `HEXIT` airdrop.

```
forge script script/bootstrap/StartAirdrop.s.sol:StartAirdropScript --fork-url http://localhost:8545 --broadcast
```

### Renounce Ownership

Used to renounce ownership once bootstraping is complete.

```
forge script script/ownership/RenounceOwnership.s.sol:RenounceOwnershipScript --fork-url http://localhost:8545 --broadcast
```
