# Deployment Guide
Quick guide on deploying and setting up the protocol on Pulsechain Mainnet using scripts.

## Pulsechain Deployment
Before trying to deploy the protocol a private key must be specified in `.env`.

### Deployment
```
forge script script/deployment/Deploy.s.sol:DeploymentScript --rpc-url https://rpc.pulsechain.com --broadcast -vvvv
```