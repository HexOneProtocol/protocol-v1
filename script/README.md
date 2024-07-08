# Deployment Guide
Quick guide on deploying and setting up the protocol on Pulsechain Mainnet using scripts.

## Pulsechain Deployment
Before trying to deploy the protocol a private key must be specified in `.env`.

### Deployment
```
forge script script/deployment/Deploy.s.sol:DeployScript --rpc-url https://rpc.pulsechain.com --verify --verifier sourcify --broadcast -vvv
```

### Process Sacrifice
```
forge script script/process-sacrifice/ProcessSacrifice.s.sol:ProcessSacrificeScript --rpc-url https://rpc.pulsechain.com --broadcast -vvvv
```

### Start Airdrop
```
forge script script/start-airdrop/StartAirdrop.s.sol:StartAirdropScript --rpc-url https://rpc.pulsechain.com --broadcast -vvvv
```