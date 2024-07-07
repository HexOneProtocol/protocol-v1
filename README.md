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

| Description            | Address                                    |
|------------------------|--------------------------------------------|
| HEXIT                  | 0x0Ed412B72a6676241E16E9CBC3aE499EB195A697 |
| HEX1                   | 0x786382a335205fEEf59b36C502c8891b5dd532b9 |
| Price Feed             | 0xa053E94C8a95FED093611Ea5b02f04e9f1f30F65 |
| Bootstrap              | 0x02e49cB9a245aFE3DCf3E434A85f6A8edBb3dF63 |
| Vault                  | 0x8070Fe8e6b4DB067d09B37da5497c328Be5A2Ad5 |
| Farm Manager           | 0x3EB1b653bcEB4632AA62f08e0d7775375178228c |
| HEX1DAI LP / HEXIT Farm| 0x6a3Cceff9614Fc6B5eb9144935018798286e113B |
| HEX1 / HEXIT Farm      | 0xa26c5320cf1341D8CbC32e68c0aa715eaA631c06 |


## Audits
- Coverage (31-05-2024): [report](https://github.com/coveragelabs/portfolio/blob/main/reports/2024-05-hex1.pdf).
- Coverage (06-03-2024): [report](https://github.com/coveragelabs/portfolio/blob/main/reports/2024-01-hex1.pdf).
- Certik (19-05-2023): [report](https://skynet.certik.com/projects/hex1#active-monitor).
