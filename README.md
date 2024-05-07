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

## Audits
- Coverage (06-03-2024): [report](https://github.com/HexOneProtocol/hex1-contracts/files/14516700/hex1-security-review.pdf).
- Certik (19-05-2023): [report](https://skynet.certik.com/projects/hex1#active-monitor).
