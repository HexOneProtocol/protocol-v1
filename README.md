# Hex One Protocol

## What Is Hex One Protocol

Hex One Protocol is a stablecoin backed by __HEX__ t-shares

Please check the [Hex One gitbook](https://hex-one.gitbook.io/hex-one-protocol/) for detailed information

## How Hex One Works?

Participants can deposit __HEX__ which creates a t-share through the Hex One protocol, and allows the user to borrow the same _dollar_-value as initially deposited. To claim the collateral, depositors must wait until maturity to claim the t-share and they must also burn the initial borrowed $HEX1 amount.

## Understanding Hex & T-Shares

[Hex Layman's Guide](https://hexicans.info/documentation/contract-guide/): an overview of Hex Protocol
[How Hex T-shares Work](](https://hexicans.info/shares/): an overview of T-shares.


## Hex One Workflow

Depositors initially forego T-SHARES in order to mint $HEX1. This simply means depositors are effectively staking their Hex through Hex One. In return, they may borrow 100% of the USD-value of their Hex, in $HEX1 - a stablecoin that is essentially backed by the staked Hex (t-shares).

At t-share maturity, or when the depositor stake ends, he must claim the stake and repay the borrowed $Hex1, that is effectively burned. 

If the depositor fails to pay the borrwed $HEX1 and claim the Hex stake within 7 days from maturity date, the Hex One protocol allows any other participant to liquidate the user stake. This means anyone who sufficient $HEX1 and $ETH can pay the depositors' debt by burning $HEX1 and paying Hex's endStake ETH fee. 

Liquidations cannot occur before the 7 days have elapsed. 

If the price of Hex drops and the protocol collateral's loses USD value, we expect the probability of a momentary de-peg to increase. ALbeit, if a de-peg happens between $HEX1 and $USDC, that also means that whoever buys $HEX1 below $1, is acquiring the underlying collateral, $HEX, at a discount as well. 

This is due to $1 Hex1 = $1 worth of hex. 

# Hex One Protocol Tokens

Hex One protocols contains two ecosystem tokens: a stablecoin, and the incentive token.

$HEX1 - stablecoin backed by t-shares
$HEXIT - Hex One Protocol incentive token.

## Supply

$HEX1 supply depends greatly on the total borrowers. The more $HEX1 is minted, through borrowing against t-shares, the greater the supply. The more $HEX1 is burned to claim collateral, Hex, the less supply of $HEX1 exists.

$HEXIT supply, on the other hand, will be deflationary. The tokens are minted at the Bootstrap stage, and distributed at the Sacrifice, Airdrop and Staking phases. The total amount minted depends on the total participants. 

More info on the [Hex One gitbook](https://hex-one.gitbook.io/hex-one-protocol/hexit/hexit-distribution)

# Hex One Functionality

Hex One functionality can be brokwn down into 3 main parts: Hex One protocol, Bootsrapping and Staking.

## Hex One Protocol

- Borrow: stake hex through Hex One Protcol and borrow $HEX1. There is a 5% borrow fee that will collect Hex and send it to the staking contract that will distribute to stakers.
- Claim Hex: burn $HEX1 and pay the ETH fee, and claim hex principal + yield
- Re-borrow: if the collateral price goes up (hex), borrow more $HEX1 against the same stake
- Liquidate: if a depositor does not burn $HEX1 and pay the ETH fee within 7 days after maturity, other participants can liquidate the depositor position and claim his hex principal + yield
- Price Oracle: a price feed based on HEX/USDC to know the price of hex. 
- Vault: a contract that holds the deposits

## Bootsrapping

- Sacrifice: sacrificing means users will forego approved ERC20s (Hex, USDC, Eth, Dai and Uni) and in return receive 75% of the USD-value deposited in $HEX1 and the incentive token, $HEXIT. The amount of $HEXIT received depends on the total amount sacrificed (USD-value) and the day of sacrifice. The sooner, the more $HEXIT a user claims. Some ERC20s give bonus too.
- Airdrop: all participants that hold $HEX1 and have staked Hex (t-shares) at the moment the airdrop starts, can claim free $HEXIT.

## Staking

- Staking Master: the master contract that creates the staking contract slaves, that represent different pairs
- Staking: can be single token or LPs and the reward depends on the staking pool. Single pools are $HEX1 and $HEXIT, and will pay a lower reward than LP pools

# Optimized strategy

There is an opmitized strategy to participate in the Hex One protocol borrowing game. 

| Collateral | Borrow  | Buy $HEX1 | Sell $HEX1  | Liquidate | 
| ------------- | ------------- | ------------- | ------------- | ------------- |
| Hex Price Up | Borrow more |  |  | |
| Hex Price Down | New borrow  |  |  | Yes |
| De-peg Up | Borrow more | No | Yes |  |
| De-Peg Down |  | Yes  | No  | Yes |

