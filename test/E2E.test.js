const { expect } = require('chai');
const { ethers } = require('hardhat');
const { constants } = require('@openzeppelin/test-helpers');

const { uniswap_abi } = require('../external_abi/uniswap.abi.json');
const { erc20_abi } = require('../external_abi/erc20.abi.json');

const { deploy, bigNum, getCurrentTimestamp, smallNum } = require('../scripts/utils');

describe ("HexOne Protocol", function () {
    let usdcAddress = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
    let usdcPriceFeed = "0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6";
    let hexTokenAddress = "0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39";
    let uniswapRouterAddress = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";

    before (async function () {
        [
            this.deployer,
            this.depositor_1,
            this.depositor_2,
            this.depositor_3
        ] = await ethers.getSigners();

        this.uniswapRouter = new ethers.Contract(uniswapRouterAddress, uniswap_abi, this.deployer);
        this.hexToken = new ethers.Contract(hexTokenAddress, erc20_abi, this.deployer);

        this.hexOneToken = await deploy("HexOneToken", "HexOneToken", "HexOne", "HEXONE");
        this.hexOnePriceFeed = await deploy(
            "HexOnePriceFeed", 
            "HexOnePriceFeed", 
            this.hexToken.address, 
            usdcAddress, 
            usdcPriceFeed,
            this.uniswapRouter.address
        );
        this.hexOneVault = await deploy(
            "HexOneVault",
            "HexOneVault",
            this.hexToken.address,
            this.hexOnePriceFeed.address
        );
        this.hexOneProtocol = await deploy(
            "HexOneProtocol",
            "HexOneProtocol",
            this.hexOneToken.address,
            [this.hexOneVault.address],
            30,
            120
        );
    })

    it ("initialize", async function () {
        await this.hexOneToken.setAdmin(this.hexOneProtocol.address);
        await this.hexOneVault.setHexOneProtocol(this.hexOneProtocol.address);
    })

    it ("buy hex token", async function () {
        let ethAmountForBuy = bigNum(1, 18);
        let WETHAddress = await this.uniswapRouter.WETH();

        let amounts = await this.uniswapRouter.getAmountsOut(
            BigInt(ethAmountForBuy),
            [WETHAddress, this.hexToken.address]
        );
        let expectHexTokenAmount = amounts[1];

        let beforeBal = await this.hexToken.balanceOf(this.deployer.address);
        await this.uniswapRouter.swapExactETHForTokens(
            0,
            [WETHAddress, this.hexToken.address],
            this.deployer.address,
            BigInt(await getCurrentTimestamp()) + BigInt(100),
            {value: ethAmountForBuy}
        );
        let afterBal = await this.hexToken.balanceOf(this.deployer.address);

        expect (smallNum(afterBal, 8) - smallNum(beforeBal, 8)).to.be.equal(smallNum(expectHexTokenAmount, 8));
    })

    describe ("deposit hex", function () {
        it ("deposit hex as collateral and check received $HEX1", async function () {
            let hexAmountForDeposit = await this.hexToken.balanceOf(this.deployer.address);
            hexAmountForDeposit = BigInt(hexAmountForDeposit) / BigInt(2);
            let duration = 40;  // 40 days

            let beforeBal = await this.hexOneToken.balanceOf(this.depositor_1.address);
            await this.hexToken.transfer(this.depositor_1.address, BigInt(hexAmountForDeposit));
            await this.hexToken.connect(this.depositor_1).approve(this.hexOneProtocol.address, BigInt(hexAmountForDeposit));
            await this.hexOneProtocol.connect(this.depositor_1).depositCollateral(
                this.hexToken.address,
                BigInt(hexAmountForDeposit),
                duration,
                false
            );
            let afterBal = await this.hexOneToken.balanceOf(this.depositor_1.address);

            let hexPrice = await this.hexOnePriceFeed.getHexTokenPrice(10**8);
            let expectMintAmount = BigInt(hexPrice) * BigInt(hexAmountForDeposit) / BigInt(10**8);

            expect (smallNum(afterBal, 18) - smallNum(beforeBal, 18)).to.be.equal(smallNum(expectMintAmount, 18));
            let shareBalance = await this.hexOneVault.getShareBalance(this.depositor_1.address);
            expect (smallNum(shareBalance, 8)).to.be.greaterThan(0);
            console.log("shareBalance: ", smallNum(shareBalance, 8));
        })
    })
})