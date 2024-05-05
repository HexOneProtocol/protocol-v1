[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
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

## Audits
- Coverage (29-01-2024 - 06-03-2024): [report](https://github.com/HexOneProtocol/hex1-contracts/files/14516700/hex1-security-review.pdf).