```
  _  _      ___    __  __      _    
 | || |    | __|   \ \/ /     / |   
 | __ |    | _|     >  <      | |   
 |_||_|    |___|   /_/\_\    _|_|_  
_|"""""| _|"""""| _|"""""| _|"""""| 
"`-0-0-' "`-0-0-' "`-0-0-' "`-0-0-' 
```
# Hex One Protocol
This repository contains the smart contracts source code for Hex One Protocol. The repository uses Foundry as a development enviroment for compilation, testing and deployment tasks.

## What is Hex One Protocol?
A yield-bearing stablecoin backed by HEX T-shares. 1 $HEX1 = $1 worth of HEX.

## Usage
### Setup
Clone with recurse:
```
git clone https://github.com/HexOneProtocol/hex1-contracts.git --recurse
```

Alternatively, if you have already cloned without recurse, do:

```
git submodule update --init --recursive
```

### Quickstart
Install Foundry to get started:
```
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

Install all dependencies:
```
forge install
```

### Tests
```
forge test -vvv
```

Run tests with gas report:

```
forge test --gas-report
```

### Coverage
```
forge coverage
```

Detailed coverage report:

```
forge coverage --report debug
```

### Bytecode size
Detailed report of bytecode size:
```
forge build --sizes
```

## Deployment Addresses

| Description             | Address                                    |
|-------------------------|--------------------------------------------|
| HEXIT                   | 0x8d4D6aa8339dB0252dc92957544fe6931e0826Db |
| HEX1                    | 0x298978f9B59A4BF9c08C114Fb6848fade7Be7E18 |
| PRICE FEED              | 0x5d07dF5C5bf6Be1d0d5dA53DFEdc50B374EB7f82 |
| BOOTSTRAP               | 0x9636f5103Ce5c86b5167a48bd3D5C89bb4F857F8 |
| VAULT                   | 0x5fA107112E0C3B221fd4930cEB7010632b85bD13 |
| FARM MANAGER            | 0x9780A434e9c178ae025D8fD2fa32392Eb87f8D49 |
| HEX1DAI LP / HEXIT FARM | 0xB0051517782700A84F84462f3BBf401A37ff1fAd |
| HEX1 / HEXIT FARM       | 0xCaF445439E55BD8F43B45d28536A1E43C1b5C6e5 |


## Audits
- Coverage (31-05-2024): [report](https://github.com/coveragelabs/portfolio/blob/main/reports/2024-05-hex1.pdf).
- Coverage (06-03-2024): [report](https://github.com/coveragelabs/portfolio/blob/main/reports/2024-01-hex1.pdf).
- Certik (19-05-2023): [report](https://skynet.certik.com/projects/hex1#active-monitor).
