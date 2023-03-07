const { expect } = require('chai');
const { ethers } = require('hardhat');
const { constants } = require('@openzeppelin/test-helpers');

const { uniswap_abi } = require('../external_abi/uniswap.abi.json');
const { erc20_abi } = require('../external_abi/erc20.abi.json');
const { hex_abi } = require('../external_abi/hex.abi.json');

const { deploy, deployProxy, getCurrentTimestamp, spendTime, bigNum, smallNum, day, hour } = require('../scripts/utils');

describe ("Hex Mock token test", function () {
    let usdcAddress = "0x07865c6E87B9F70255377e024ace6630C1Eaa37F";
    let usdcPriceFeed = "0xAb5c49580294Aff77670F839ea425f5b78ab3Ae7";
    let uniswapRouterAddress = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";

    before (async function () {
        [
            this.deployer,
            this.depositor_1,
            this.depositor_2,
            this.depositor_3,
            this.staker_1,
            this.staker_2,
            this.sacrificer_1,
            this.sacrificer_2,
            this.hex_staker
        ] = await ethers.getSigners();

        this.hexToken = await deploy("HexMockToken", "HexMockToken");
        this.uniswapRouter = new ethers.Contract(uniswapRouterAddress, uniswap_abi, this.deployer);
        this.USDC = new ethers.Contract(usdcAddress, erc20_abi, this.deployer);
        this.hexOneToken = await deploy("HexOneToken", "HexOneToken", "HexOne", "HEXONE");
        this.hexOnePriceFeed = await deployProxy(
            "HexOnePriceFeedTest", 
            "HexOnePriceFeedTest", 
            [
                this.hexToken.address, 
                usdcAddress, 
                usdcPriceFeed,
                this.uniswapRouter.address
            ]
        );

        this.hexOneVault = await deployProxy(
            "HexOneVault",
            "HexOneVault",
            [
                this.hexToken.address,
                this.hexOnePriceFeed.address
            ]
        );
        this.stakingMaster = await deployProxy(
            "HexOneStakingMaster",
            "HexOneStakingMaster"
        );
        this.hexOneProtocol = await deployProxy(
            "HexOneProtocol",
            "HexOneProtocol",
            [
                this.hexOneToken.address,
                [this.hexOneVault.address],
                this.stakingMaster.address,
                30,
                120
            ]
        );

        this.HEXIT = await deploy(
            "HEXIT",
            "HEXIT",
            "Hex Incentive Token",
            "HEXIT"
        );

        let sacrificeStartTime = await getCurrentTimestamp();
        sacrificeStartTime = BigInt(sacrificeStartTime) + BigInt(hour);
        let sacrificeDuration = 100;    // 100 days.
        
        let airdropStarTime = BigInt(sacrificeStartTime) + BigInt(day) * BigInt(sacrificeDuration) + BigInt(day);
        let airdropDuration = 100;      // 100 days.

        let bootstrapParam = {
            hexOnePriceFeed: this.hexOnePriceFeed.address,
            dexRouter: this.uniswapRouter.address,
            hexToken: this.hexToken.address,
            pairToken: usdcAddress,
            hexitToken: this.HEXIT.address,
            sacrificeStartTime: sacrificeStartTime,
            airdropStartTime: airdropStarTime,
            sacrificeDuration: sacrificeDuration,
            airdropDuration: airdropDuration,
            rateForSacrifice: 800,              // 80%
            rateforAirdrop: 200,                // 20%
            sacrificeDistRate: 750,             // 75%
            sacrificeLiquidityRate: 250,        // 25%
            airdropDistRateforHexHolder: 700,   // 70%
            airdropDistRateforHEXITHolder: 300  // 30%
        };

        this.hexOneBootstrap = await deployProxy(
            "HexOneBootstrap",
            "HexOneBootstrap",
            [bootstrapParam]
        );

        this.hexOneEscrow = await deployProxy(
            "HexOneEscrow",
            "HexOneEscrow",
            [
                this.hexOneBootstrap.address,
                this.hexToken.address,
                this.hexOneToken.address,
                this.hexOneProtocol.address
            ]
        );
    })

    describe ("initialize", function () {
        it ("initialize", async function () {
            await this.hexOneToken.setAdmin(this.hexOneProtocol.address);
            await this.hexOneVault.setHexOneProtocol(this.hexOneProtocol.address);
            await this.stakingMaster.setHexOneProtocol(this.hexOneProtocol.address);
            await this.hexOneBootstrap.setEscrowContract(this.hexOneEscrow.address);
            await this.HEXIT.setBootstrap(this.hexOneBootstrap.address);
        })

        it ("create staking pool", async function () {
            this.stakingPoolHex = await deployProxy(
                "HexOneStaking",
                "HexOneStaking",
                [
                    this.hexToken.address,
                    this.stakingMaster.address,
                    false    
                ]
            );
    
            await this.stakingMaster.setAllowTokens([this.hexToken.address], true);
            await this.stakingMaster.setAllowedRewardTokens(
                this.hexToken.address,
                [this.hexToken.address],
                true
            );
    
            await this.stakingMaster.setStakingPools([this.hexToken.address], [this.stakingPoolHex.address]);
            await this.stakingMaster.setRewardsRate([this.hexToken.address], [600]);        // 60% for hexToken
        })

        it ("buy USDC token and add liquidity", async function () {
            let ethAmountForBuy = ethers.utils.parseEther("0.1");
            let WETHAddress = await this.uniswapRouter.WETH();

            let amounts = await this.uniswapRouter.getAmountsOut(
                BigInt(ethAmountForBuy),
                [WETHAddress, this.USDC.address]
            );
            let expectUSDCTokenAmount = amounts[1];

            let beforeBal = await this.USDC.balanceOf(this.deployer.address);
            await this.uniswapRouter.swapExactETHForTokens(
                0,
                [WETHAddress, this.USDC.address],
                this.deployer.address,
                BigInt(await getCurrentTimestamp()) + BigInt(100),
                {value: ethAmountForBuy}
            );
            let afterBal = await this.USDC.balanceOf(this.deployer.address);
            let swappedUSDCAmount = BigInt(afterBal) - BigInt(beforeBal);
            swappedUSDCAmount = BigInt(swappedUSDCAmount) * BigInt(4) / BigInt(5);
            let hexAmountForLiquidity = await this.hexToken.balanceOf(this.deployer.address);
            hexAmountForLiquidity = BigInt(hexAmountForLiquidity) / BigInt(2);
            
            await this.USDC.approve(this.uniswapRouter.address, BigInt(swappedUSDCAmount));
            await this.hexToken.approve(this.uniswapRouter.address, BigInt(hexAmountForLiquidity));
            await this.uniswapRouter.addLiquidity(
                this.USDC.address,
                this.hexToken.address,
                BigInt(swappedUSDCAmount),
                BigInt(hexAmountForLiquidity),
                0,
                0,
                this.deployer.address,
                BigInt(await getCurrentTimestamp()) + BigInt(100)
            );

            let transferAmount = await this.hexToken.balanceOf(this.deployer.address);
            transferAmount = BigInt(transferAmount) / BigInt(3);
            await this.hexToken.transfer(this.staker_1.address, BigInt(transferAmount));
            await this.hexToken.transfer(this.staker_2.address, BigInt(transferAmount));
        })
    })

    describe ("Sacrifice and Airdrop", function () {
        describe ("Sacrifice", function () {
            it ("set allowed tokens and token weight", async function () {
                await this.hexOneBootstrap.setAllowedTokens(
                    [
                        this.USDC.address,
                        this.hexToken.address
                    ],
                    true
                );

                await this.hexOneBootstrap.setTokenWeight(
                    [
                        this.USDC.address,
                        this.hexToken.address
                    ],
                    [3000, 5555]
                );
            })

            it ("sacrifice USDC", async function () {
                let sacrificeUSDCAmount = await this.USDC.balanceOf(this.deployer.address);
                sacrificeUSDCAmount = BigInt(sacrificeUSDCAmount) / BigInt(100);
                console.log(
                    "USDC amount to sacrifice",
                    smallNum(sacrificeUSDCAmount, 6)
                );
                await this.USDC.transfer(this.sacrificer_1.address, BigInt(sacrificeUSDCAmount));

                await expect (
                    this.hexOneBootstrap.connect(this.sacrificer_1).sacrificeToken(
                        this.USDC.address,
                        BigInt(sacrificeUSDCAmount)
                    )
                ).to.be.revertedWith("not sacrifice duration");

                await spendTime(day * 1);
                
                await this.USDC.connect(this.sacrificer_1).approve(this.hexOneBootstrap.address, BigInt(sacrificeUSDCAmount));
                let beforeHexBal = await this.hexToken.balanceOf(this.hexOneEscrow.address);
                await this.hexOneBootstrap.connect(this.sacrificer_1).sacrificeToken(
                    this.USDC.address,
                    BigInt(sacrificeUSDCAmount)
                );
                let afterHexBal = await this.hexToken.balanceOf(this.hexOneEscrow.address);
                let receivedAmount = BigInt(afterHexBal) - BigInt(beforeHexBal);

                console.log(
                    "hex amount that escrow contract received: ",
                    smallNum(receivedAmount, 8)
                );
                expect (smallNum(receivedAmount, 8)).to.be.greaterThan(0);
                console.log(
                    "sacrifice token and hex token balance after sacrifice",
                    smallNum(await this.USDC.balanceOf(this.hexOneBootstrap.address), 6),
                    smallNum(await this.hexToken.balanceOf(this.hexOneBootstrap.address), 8)
                );
            })

            it ("sacrifice hex token", async function () {
                let sacrificeHexAmount = await this.hexToken.balanceOf(this.deployer.address);
                sacrificeHexAmount = BigInt(sacrificeHexAmount) / BigInt(50);
                console.log(
                    "Hex token amount to sacrifice: ",
                    smallNum(sacrificeHexAmount, 8)
                );
                await this.hexToken.transfer(this.sacrificer_2.address, BigInt(sacrificeHexAmount));

                await this.hexToken.connect(this.sacrificer_2).approve(this.hexOneBootstrap.address, BigInt(sacrificeHexAmount));
                await this.hexOneBootstrap.connect(this.sacrificer_2).sacrificeToken(
                    this.hexToken.address,
                    BigInt(sacrificeHexAmount)
                );
            })

            it ("after sacrifice duration, distribute", async function () {
                await expect (
                    this.hexOneBootstrap.distributeRewardsForSacrifice()
                ).to.be.revertedWith("sacrifice duration");

                // spend 99 days to finish sacrifice duration
                await spendTime(day * 100);

                let beforeSacrificerBal_1 = await this.HEXIT.balanceOf(this.sacrificer_1.address);
                let beforeSacrificerBal_2 = await this.HEXIT.balanceOf(this.sacrificer_2.address);
                await this.hexOneBootstrap.distributeRewardsForSacrifice();
                let afterSacrificerBal_1 = await this.HEXIT.balanceOf(this.sacrificer_1.address);
                let afterSacrificerBal_2 = await this.HEXIT.balanceOf(this.sacrificer_2.address);

                let receivedRewards_1 = BigInt(afterSacrificerBal_1) - BigInt(beforeSacrificerBal_1);
                let receivedRewards_2 = BigInt(afterSacrificerBal_2) - BigInt(beforeSacrificerBal_2);

                console.log(
                    "received hexit token for sacrifier_1 and sacrifier_2",
                    smallNum(receivedRewards_1, 18),
                    smallNum(receivedRewards_2, 18)
                );

                expect (smallNum(receivedRewards_1, 18)).to.be.greaterThan(0);
                expect (smallNum(receivedRewards_2, 18)).to.be.greaterThan(0);
            })
        })

        describe ("Airdrop", function () {
            it ("spend one more day", async function () {
                await spendTime(day);
            })

            it ("stake hex through hex token contract", async function () {
                let stakeHexAmount = await this.hexToken.balanceOf(this.deployer.address);
                stakeHexAmount = BigInt(stakeHexAmount) / BigInt(50);
                console.log(
                    "hexToken amount to stake",
                    smallNum(stakeHexAmount, 8)
                );

                await this.hexToken.transfer(this.hex_staker.address, BigInt(stakeHexAmount));
                await this.hexToken.connect(this.hex_staker).approve(this.hexToken.address, BigInt(stakeHexAmount));
                await this.hexToken.connect(this.hex_staker).stakeStart(stakeHexAmount, 80);
            })

            it ("hex staker request airdrop", async function () {
                await this.hexOneBootstrap.connect(this.hex_staker).requestAirdrop(true);
                await expect (
                    this.hexOneBootstrap.connect(this.sacrificer_1).requestAirdrop(true)
                ).to.be.revertedWith("no t-shares");

                await expect (
                    this.hexOneBootstrap.connect(this.depositor_1).requestAirdrop(false)
                ).to.be.revertedWith("no hexit balance");
                await this.hexOneBootstrap.connect(this.sacrificer_1).requestAirdrop(false);

                await spendTime(day * 3);
                await expect (
                    this.hexOneBootstrap.connect(this.hex_staker).requestAirdrop(true)
                ).to.be.revertedWith("already requested");
                await this.hexOneBootstrap.connect(this.sacrificer_2).requestAirdrop(false);
            })

            it ("after some time, claim duration", async function () {
                let beforeBal = await this.HEXIT.balanceOf(this.sacrificer_1.address);
                await this.hexOneBootstrap.connect(this.sacrificer_1).claimAirdrop();
                let afterBal = await this.HEXIT.balanceOf(this.sacrificer_1.address);
                let receivedAmount = BigInt(afterBal) - BigInt(beforeBal);
                console.log(
                    "sacrificer_1 received HEXIT amnount as airdrop: ",
                    smallNum(receivedAmount, 18)
                );
                expect (smallNum(receivedAmount, 18)).to.be.greaterThan(0);
                
                beforeBal = await this.HEXIT.balanceOf(this.sacrificer_2.address);
                await this.hexOneBootstrap.connect(this.sacrificer_2).claimAirdrop();
                afterBal = await this.HEXIT.balanceOf(this.sacrificer_2.address);
                receivedAmount = BigInt(afterBal) - BigInt(beforeBal);
                console.log(
                    "sacrificer_2 received HEXIT amnount as airdrop: ",
                    smallNum(receivedAmount, 18)
                );
                expect (smallNum(receivedAmount, 18)).to.be.greaterThan(0);

                beforeBal = await this.HEXIT.balanceOf(this.hex_staker.address);
                await this.hexOneBootstrap.connect(this.hex_staker).claimAirdrop();
                afterBal = await this.HEXIT.balanceOf(this.hex_staker.address);
                receivedAmount = BigInt(afterBal) - BigInt(beforeBal);
                console.log(
                    "hex_staker received HEXIT amnount as airdrop: ",
                    smallNum(receivedAmount, 18)
                );
                expect (smallNum(receivedAmount, 18)).to.be.greaterThan(0);
            })
        })

        describe ("Escrow", function () {
            it ("get hex balance", async function () {
                let hexBalance = await this.hexOneEscrow.balanceOfHex();
                console.log(
                    "hex token balance that escrow token has: ",
                    smallNum(hexBalance, 8)
                );
                expect (smallNum(hexBalance, 8)).to.be.greaterThan(0);
            })

            it ("deposit collateral", async function () {
                let beforeBal_1 = await this.hexOneToken.balanceOf(this.sacrificer_1.address);
                let beforeBal_2 = await this.hexOneToken.balanceOf(this.sacrificer_2.address);
                await this.hexOneEscrow.depositCollateralToHexOneProtocol(60);
                let afterBal_1 = await this.hexOneToken.balanceOf(this.sacrificer_1.address);
                let afterBal_2 = await this.hexOneToken.balanceOf(this.sacrificer_2.address);
                let rewardsAmount_1 = BigInt(afterBal_1) - BigInt(beforeBal_1);
                let rewardsAmount_2 = BigInt(afterBal_2) - BigInt(beforeBal_2);

                console.log(
                    "$HEX1 amount that sacrificer received as rewards: ",
                    smallNum(rewardsAmount_1, 18),
                    smallNum(rewardsAmount_2, 18)
                );
            })

            it ("after duration, reDeposit", async function () {
                await spendTime(81 * day);

                let beforeBal_1 = await this.hexOneToken.balanceOf(this.sacrificer_1.address);
                let beforeBal_2 = await this.hexOneToken.balanceOf(this.sacrificer_2.address);
                await this.hexOneEscrow.connect(this.depositor_1).reDepositCollateral();
                let afterBal_1 = await this.hexOneToken.balanceOf(this.sacrificer_1.address);
                let afterBal_2 = await this.hexOneToken.balanceOf(this.sacrificer_2.address);
                let rewardsAmount_1 = BigInt(afterBal_1) - BigInt(beforeBal_1);
                let rewardsAmount_2 = BigInt(afterBal_2) - BigInt(beforeBal_2);

                console.log(
                    "$HEX1 amount that sacrificer received as rewards: ",
                    smallNum(rewardsAmount_1, 18),
                    smallNum(rewardsAmount_2, 18)
                );
            })
        })
    })

    describe ("main process test", function () {
        describe ("staking hex token", function () {
            it ("stake hexToken", async function () {
                let stakeAmount = await this.hexToken.balanceOf(this.staker_1.address);
                await this.hexToken.connect(this.staker_1).approve(this.stakingMaster.address, BigInt(stakeAmount));
                await this.stakingMaster.connect(this.staker_1).stakeERC20Start(
                    this.hexToken.address,
                    this.hexToken.address,
                    BigInt(stakeAmount)
                );

                stakeAmount = BigInt(stakeAmount) / BigInt(2);
                await this.hexToken.connect(this.staker_2).approve(this.stakingMaster.address, BigInt(stakeAmount));
                await this.stakingMaster.connect(this.staker_2).stakeERC20Start(
                    this.hexToken.address,
                    this.hexToken.address,
                    BigInt(stakeAmount)
                );
            })
        })

        describe ("deposit and claim hex", function () {
            describe ("deposit hex", function () {
                it ("deposit hex as collateral and check received $HEX1", async function () {
                    let hexAmountForDeposit = await this.hexToken.balanceOf(this.deployer.address);
                    hexAmountForDeposit = BigInt(hexAmountForDeposit) / BigInt(2);
                    let duration = 40;  // 40 days
        
                    console.log(
                        "HEX token amount to deposit: ",
                        smallNum(hexAmountForDeposit, 8)
                    );
        
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
                    console.log("shareBalance after deposit collateral: ", smallNum(shareBalance, 8));
                })
            })

            describe ("claim hex", function () {
                it ("reverts if try to claim before maturity", async function () {
                    let userInfos = await this.hexOneVault.getUserInfos(this.depositor_1.address);
                    let depositId = userInfos[0].depositId;
                    await expect (
                        this.hexOneProtocol.connect(this.depositor_1).claimCollateral(this.hexToken.address, depositId)
                    ).to.be.revertedWith("before maturity");
                })
        
                it ("claim after maturity", async function () {
                    let userInfos = await this.hexOneVault.getUserInfos(this.depositor_1.address);
                    expect (userInfos.length).to.be.equal(1);
                    let depositId = userInfos[0].depositId;
                    let mintAmount = userInfos[0].mintAmount;
                    let depositedAmount = userInfos[0].depositAmount;
        
                    await spendTime(day * 45);
        
                    let beforeHexOneBal = await this.hexOneToken.balanceOf(this.depositor_1.address);
                    let beforeHexBal = await this.hexToken.balanceOf(this.depositor_1.address);
                    await this.hexOneProtocol.connect(this.depositor_1).claimCollateral(this.hexToken.address, depositId);
                    let afterHexOneBal = await this.hexOneToken.balanceOf(this.depositor_1.address);
                    let afterHexBal = await this.hexToken.balanceOf(this.depositor_1.address);
                    expect (smallNum(beforeHexOneBal, 18) - smallNum(afterHexOneBal, 18)).to.be.equal(smallNum(mintAmount, 18));
                    console.log(
                        "received HEX token amount as rewards: ",
                        smallNum(afterHexBal, 8) - smallNum(beforeHexBal, 8)
                    );
                    expect (smallNum(afterHexBal, 8) - smallNum(beforeHexBal, 8)).to.be.greaterThan(smallNum(depositedAmount, 8));
                    let shareBalance = await this.hexOneVault.getShareBalance(this.depositor_1.address);
                    expect (smallNum(shareBalance, 8)).to.be.equal(0);
                    console.log(
                        "user information after claim: ",
                        await this.hexOneVault.getUserInfos(this.depositor_1.address)
                    );
                    userInfos = await this.hexOneVault.getUserInfos(this.depositor_1.address);
                    expect (userInfos.length).to.be.equal(0);
                })
            })

            describe ("deposit as commitType and restake it", function () {
                it ("deposit hex as commit type", async function () {
                    let hexAmountForDeposit = await this.hexToken.balanceOf(this.deployer.address);
                    hexAmountForDeposit = BigInt(hexAmountForDeposit) / BigInt(4);
                    let duration = 40;  // 40 days
        
                    let beforeBal = await this.hexOneToken.balanceOf(this.depositor_2.address);
                    await this.hexToken.transfer(this.depositor_2.address, BigInt(hexAmountForDeposit));
                    await this.hexToken.connect(this.depositor_2).approve(this.hexOneProtocol.address, BigInt(hexAmountForDeposit));
                    await this.hexOneProtocol.connect(this.depositor_2).depositCollateral(
                        this.hexToken.address,
                        BigInt(hexAmountForDeposit),
                        duration,
                        true
                    );
                    let afterBal = await this.hexOneToken.balanceOf(this.depositor_2.address);
        
                    let hexPrice = await this.hexOnePriceFeed.getHexTokenPrice(10**8);
                    let expectMintAmount = BigInt(hexPrice) * BigInt(hexAmountForDeposit) / BigInt(10**8);
        
                    expect (smallNum(afterBal, 18) - smallNum(beforeBal, 18)).to.be.equal(smallNum(expectMintAmount, 18));
                    let shareBalance = await this.hexOneVault.getShareBalance(this.depositor_2.address);
                    expect (smallNum(shareBalance, 8)).to.be.greaterThan(0);
                    console.log("shareBalance after deposit collateral: ", smallNum(shareBalance, 8));
                })

                it ("restake after maturity", async function () {
                    let userInfos = await this.hexOneVault.getUserInfos(this.depositor_2.address);
                    expect (userInfos.length).to.be.equal(1);
                    let depositId = userInfos[0].depositId;
                    let shareAmount = await this.hexOneVault.getShareBalance(this.depositor_2.address);
        
                    await spendTime(day * 45);
        
                    let beforeHexOneBal = await this.hexOneToken.balanceOf(this.depositor_2.address);
                    let beforeHexBal = await this.hexToken.balanceOf(this.depositor_2.address);
                    await this.hexOneProtocol.connect(this.depositor_2).claimCollateral(this.hexToken.address, depositId);
                    let afterHexOneBal = await this.hexOneToken.balanceOf(this.depositor_2.address);
                    let afterHexBal = await this.hexToken.balanceOf(this.depositor_2.address);

                    expect (smallNum(afterHexOneBal, 18)).to.be.greaterThan(smallNum(beforeHexOneBal, 18));
                    console.log(
                        "received $HEX1 amount by restake: ", 
                        smallNum(afterHexOneBal, 18) - smallNum(beforeHexOneBal, 18)
                    );

                    console.log(
                        "received HEX token amount after restake: ",
                        smallNum(afterHexBal, 8) - smallNum(beforeHexBal, 8)
                    );
                    expect (smallNum(afterHexBal, 8) - smallNum(beforeHexBal, 8)).to.be.equal(0);

                    let shareBalance = await this.hexOneVault.getShareBalance(this.depositor_2.address);
                    console.log(
                        "shareBalance before and after restake: ",
                        smallNum(shareAmount, 8), smallNum(shareBalance, 8)
                    );
                    expect (smallNum(shareBalance, 8)).to.be.greaterThan(smallNum(shareAmount, 8));
                    
                    userInfos = await this.hexOneVault.getUserInfos(this.depositor_2.address);
                    expect (userInfos.length).to.be.equal(1);
                    expect (userInfos[0].depositId).to.be.not.equal(depositId);
                })
            })
        })

        describe ("set vaulsts", function () {
            it ("reverts if caller is not the owner", async function () {
                await expect (
                    this.hexOneProtocol.connect(this.depositor_1).setVaults([this.hexOneVault.address], false)
                ).to.be.revertedWith("Ownable: caller is not the owner");
            })

            it ("remove hexOneVault", async function () {
                await this.hexOneProtocol.setVaults([this.hexOneVault.address], false);
                expect (await this.hexOneProtocol.isAllowedToken(this.hexToken.address)).to.be.equal(false);
            })

            it ("add hexOneVault again", async function () {
                await this.hexOneProtocol.setVaults([this.hexOneVault.address], true);
                expect (await this.hexOneProtocol.isAllowedToken(this.hexToken.address)).to.be.equal(true);
            })
        })

        describe ("set staking master", function () {
            it ("deploy new staking master", async function () {
                this.stakingMaster = await deploy(
                    "HexOneStakingMaster",
                    "HexOneStakingMaster"
                );
            })

            it ("set new staking master", async function () {
                let oldOne = await this.hexOneProtocol.stakingMaster();
                expect (oldOne).to.be.not.equal(this.stakingMaster.address);
                
                /// reverts if caller is not the owner
                await expect (
                    this.hexOneProtocol.connect(this.depositor_1).setStakingPool(
                        this.stakingMaster.address
                    )
                ).to.be.revertedWith("Ownable: caller is not the owner");

                await this.hexOneProtocol.setStakingPool(
                    this.stakingMaster.address
                );

                expect (
                    await this.hexOneProtocol.stakingMaster()
                ).to.be.equal(this.stakingMaster.address);

                await this.hexOneProtocol.setStakingPool(
                    oldOne
                );
            })
        })

        describe ("deposit fee", function () {
            describe ("set deposit fee", function () {
                it ("reverts if caller is not the owner", async function () {
                    await expect (
                        this.hexOneProtocol.connect(this.depositor_1).setDepositFee(
                            this.hexToken.address,
                            10
                        )
                    ).to.be.revertedWith("Ownable: caller is not the owner");
                })

                it ("reverts if token is not allowed", async function () {
                    await expect (
                        this.hexOneProtocol.setDepositFee(
                            this.hexOneToken.address,
                            100
                        )
                    ).to.be.revertedWith("not allowed token");
                })

                it ("reverts if deposit fee is over 100%", async function () {
                    await expect (
                        this.hexOneProtocol.setDepositFee(
                            this.hexToken.address,
                            1001
                        )
                    ).to.be.revertedWith("invalid fee rate");
                })

                it ("set deposit fee", async function () {
                    await this.hexOneProtocol.setDepositFee(
                        this.hexToken.address,
                        30
                    );
                })
            })

            describe ("set deposit enable", function () {
                it ("reverts if caller is not the owner", async function () {
                    await expect (
                        this.hexOneProtocol.connect(this.depositor_1).setDepositFeeEnable(
                            this.hexToken.address,
                            true
                        )
                    ).to.be.revertedWith("Ownable: caller is not the owner");
                })

                it ("reverts if token is not allowed", async function () {
                    await expect (
                        this.hexOneProtocol.setDepositFeeEnable(
                            this.hexOneToken.address,
                            true
                        )
                    ).to.be.revertedWith("not allowed token");
                })

                it ("set deposit fee enable", async function () {
                    await this.hexOneProtocol.setDepositFeeEnable(
                        this.hexToken.address,
                        true
                    );
                })
            })

            describe ("deposit collateral with fee", function () {
                it ("reverts if token is not allowed", async function () {
                    await expect (
                        this.hexOneProtocol.connect(this.depositor_3).depositCollateral(
                            this.hexOneToken.address,
                            bigNum(10),
                            4,
                            true
                        )
                    ).to.be.revertedWith("invalid token");
                })

                it ("reverts if amount is zero", async function () {
                    await expect (
                        this.hexOneProtocol.connect(this.depositor_3).depositCollateral(
                            this.hexToken.address,
                            0,
                            4,
                            true
                        )
                    ).to.be.revertedWith("invalid amount");
                })

                it ("reverts if duration is invalid", async function () {
                    await expect (
                        this.hexOneProtocol.connect(this.depositor_3).depositCollateral(
                            this.hexToken.address,
                            bigNum(10),
                            20,
                            true
                        )
                    ).to.be.revertedWith("invalid duration");
                })

                it ("deposit collateral and check fee", async function () {
                    let hexAmountForDeposit = await this.hexToken.balanceOf(this.deployer.address);
                    hexAmountForDeposit = BigInt(hexAmountForDeposit) / BigInt(4);
                    let duration = 50;  // 50 days

                    let beforeBal = await this.hexOneToken.balanceOf(this.depositor_3.address);
                    let stakingPoolAddr = await this.hexOneProtocol.stakingMaster();
                    let beforePoolBal = await this.hexToken.balanceOf(stakingPoolAddr);
                    await this.hexToken.transfer(this.depositor_3.address, BigInt(hexAmountForDeposit));
                    await this.hexToken.connect(this.depositor_3).approve(this.hexOneProtocol.address, BigInt(hexAmountForDeposit));
                    await this.hexOneProtocol.connect(this.depositor_3).depositCollateral(
                        this.hexToken.address,
                        BigInt(hexAmountForDeposit),
                        duration,
                        false
                    );
                    let afterBal = await this.hexOneToken.balanceOf(this.depositor_3.address);
                    let afterPoolBal = await this.hexToken.balanceOf(stakingPoolAddr);
        
                    let hexPrice = await this.hexOnePriceFeed.getHexTokenPrice(10**8);
                    let feeRate = await this.hexOneProtocol.fees(this.hexToken.address);
                    feeRate = feeRate.feeRate;
                    let feeAmount = BigInt(hexAmountForDeposit) * BigInt(feeRate) / BigInt(1000);
                    let tradeAmount = BigInt(hexAmountForDeposit) - BigInt(feeAmount);
                    let expectMintAmount = BigInt(hexPrice) * BigInt(tradeAmount) / BigInt(10**8);
        
                    expect (smallNum(afterBal, 18) - smallNum(beforeBal, 18)).to.be.equal(smallNum(expectMintAmount, 18));
                    let shareBalance = await this.hexOneVault.getShareBalance(this.depositor_2.address);
                    expect (smallNum(shareBalance, 8)).to.be.greaterThan(0);
                    expect (smallNum(BigInt(afterPoolBal) - BigInt(beforePoolBal), 8)).to.be.equal(smallNum(feeAmount, 8));
                    console.log("shareBalance after deposit collateral: ", smallNum(shareBalance, 8));
                })
            })
        })

        describe ("borrow more $HEX1", function () {
            let increasePricePerToken;
            it ("set increased testRate for borrow", async function () {
                let beforePrice = await this.hexOnePriceFeed.getHexTokenPrice(bigNum(1, 8));
                let testRate = 1500;    // 150%
                await this.hexOnePriceFeed.setTestRate(testRate);
                let afterPrice = await this.hexOnePriceFeed.getHexTokenPrice(bigNum(1, 8));
                increasePricePerToken = BigInt(afterPrice) - BigInt(beforePrice);
            })

            it ("get borrowable amounts", async function () {
                let borrowableAmounts = await this.hexOneVault.getBorrowableAmounts(this.depositor_3.address);
                expect (borrowableAmounts.length).to.be.equal(1);
                console.log(borrowableAmounts[0]);
            })

            it ("reverts if token is not allowed", async function () {
                await expect (
                    this.hexOneProtocol.connect(this.depositor_3).borrowHexOne(
                        this.hexOneToken.address,
                        1,
                        bigNum(10, 18)
                    )
                ).to.be.revertedWith("not allowed token");
            })

            it ("borrow more $HEX1", async function () {
                let depositInfo = await this.hexOneVault.getUserInfos(this.depositor_3.address);
                let depositedTokenAmount = depositInfo[0].depositAmount;
                console.log("depositedAmont: ", smallNum(depositedTokenAmount, 8));
                console.log("increase price per token: ", smallNum(increasePricePerToken, 18));

                let borrowableAmounts = await this.hexOneVault.getBorrowableAmounts(this.depositor_3.address);
                let borrowableAmount = borrowableAmounts[0].borrowableAmount;
                let depositId = borrowableAmounts[0].depositId;

                let beforeBal = await this.hexOneToken.balanceOf(this.depositor_3.address);
                await this.hexOneProtocol.connect(this.depositor_3).borrowHexOne(
                    this.hexToken.address,
                    depositId,
                    BigInt(borrowableAmount)
                );
                let afterBal = await this.hexOneToken.balanceOf(this.depositor_3.address);
                let expectAmount = BigInt(depositedTokenAmount) * BigInt(increasePricePerToken) / BigInt(10**8);
                let borrowedAmount = BigInt(afterBal) - BigInt(beforeBal);

                console.log(
                    "borrowed $HEX1 token amount: ",
                    smallNum(borrowedAmount, 18),
                    smallNum(borrowableAmount, 18),
                    smallNum(expectAmount, 18)
                );

                console.log("$HEX1 balance after borrow: ", smallNum(afterBal, 18));

                expect (smallNum(borrowedAmount, 18)).to.be.equal(smallNum(borrowableAmount, 18));
                expect (smallNum(borrowedAmount, 18)).to.be.closeTo(smallNum(expectAmount, 18), 0.01);
            })
        })

        describe ("add collateral for liquidate", function () {
            it ("set decreased testRate for borrow", async function () {
                let testRate = 600;    // 60%
                await this.hexOnePriceFeed.setTestRate(testRate);
            })

            it ("get liquidableDeposits", async function () {
                let deposits = await this.hexOneVault.getLiquidableDeposits();
                /// before maturity no liquidableDeposits
                expect (deposits.length).to.be.equal(0);

                /// spend time
                await spendTime(60 * day);

                deposits = await this.hexOneVault.getLiquidableDeposits();
                expect (deposits.length).to.be.equal(1);
                expect (deposits[0].depositor).to.be.equal(this.depositor_3.address);
            })

            it ("reverts if caller is not the depositor", async function () {
                let deposits = await this.hexOneVault.getLiquidableDeposits();
                let depositInfo = deposits[0];

                let hexAmountForDeposit = await this.hexToken.balanceOf(this.deployer.address);
                hexAmountForDeposit = BigInt(hexAmountForDeposit) / BigInt(4);
                let duration = 50;  // 50 days

                await this.hexToken.transfer(this.depositor_1.address, BigInt(hexAmountForDeposit));
                await this.hexToken.connect(this.depositor_1).approve(this.hexOneProtocol.address, BigInt(hexAmountForDeposit));
                await expect (
                    this.hexOneProtocol.connect(this.depositor_1).addCollateralForLiquidate(
                        this.hexToken.address,
                        BigInt(hexAmountForDeposit),
                        depositInfo.depositId,
                        duration
                    )
                ).to.be.revertedWith("not correct depositor");

                await this.hexToken.connect(this.depositor_1).transfer(this.depositor_3.address, BigInt(hexAmountForDeposit));
            })

            it ("deposit collateral for liquidate", async function () {
                let deposits = await this.hexOneVault.getLiquidableDeposits();
                let depositInfo = deposits[0];
                let hexAmountForDeposit = bigNum(20, 8);
                let duration = 50;  // 50 days

                let burnHexOneTokenAmount = depositInfo.hexOneTokenAmount;
                let beforeBal = await this.hexOneToken.balanceOf(this.depositor_3.address);
                let beforeHexBal = await this.hexToken.balanceOf(this.depositor_3.address);
                await this.hexToken.connect(this.depositor_3).approve(this.hexOneProtocol.address, BigInt(hexAmountForDeposit));
                await this.hexOneProtocol.connect(this.depositor_3).addCollateralForLiquidate(
                    this.hexToken.address,
                    BigInt(hexAmountForDeposit),
                    depositInfo.depositId,
                    duration
                );
                let afterBal = await this.hexOneToken.balanceOf(this.depositor_3.address);
                let afterHexBal = await this.hexToken.balanceOf(this.depositor_3.address);

                console.log(
                    "burn $HEX1 token amount: ",
                    smallNum(BigInt(beforeBal) - BigInt(afterBal), 18),
                    smallNum(burnHexOneTokenAmount, 18),
                    smallNum(BigInt(beforeHexBal) - BigInt(afterHexBal), 8)
                );

                expect (smallNum(BigInt(beforeBal) - BigInt(afterBal), 18)).to.be.equal(smallNum(burnHexOneTokenAmount, 18));
            })
        })

        describe ("claim hex token of liquidate deposit by self and other users", function () {
            it ("spend time", async function () {
                let deposits = await this.hexOneVault.getLiquidableDeposits();
                /// before maturity no liquidableDeposits
                expect (deposits.length).to.be.equal(0);

                /// spend time
                await spendTime(60 * day);

                deposits = await this.hexOneVault.getLiquidableDeposits();
                expect (deposits.length).to.be.equal(0);
            })

            it ("claim hex with depositor", async function () {
                let userInfos = await this.hexOneVault.getUserInfos(this.depositor_3.address);
                expect (userInfos.length).to.be.equal(1);
                expect (smallNum(userInfos[0].liquidateAmount, 18)).to.be.equal(0);

                let depositedAmount = userInfos[0].depositAmount;
                let depositId = userInfos[0].depositId;
                let beforeBal = await this.hexToken.balanceOf(this.depositor_3.address);
                await expect (
                    this.hexOneProtocol.connect(this.depositor_1).claimCollateral(this.hexToken.address, depositId)
                ).to.be.revertedWith("not proper claimer");
                await this.hexOneProtocol.connect(this.depositor_3).claimCollateral(this.hexToken.address, depositId);
                let afterBal = await this.hexToken.balanceOf(this.depositor_3.address);
                let receivedAmount = BigInt(afterBal) - BigInt(beforeBal);

                console.log(
                    "deposited and received hex token amount after claim: ",
                    smallNum(depositedAmount, 8),
                    smallNum(receivedAmount, 8),
                );

                expect (smallNum(receivedAmount, 8)).to.be.greaterThan(smallNum(depositedAmount, 8));
            })

            it ("deposit collateral and decrease hex price", async function () {
                await this.hexOnePriceFeed.setTestRate(1000);   // 100%

                let hexAmountForDeposit = bigNum(100, 8);
                let duration = 30;  // 30 days
                let beforeHexOneTokenBal = await this.hexOneToken.balanceOf(this.depositor_1.address);
                await this.hexToken.connect(this.depositor_1).approve(this.hexOneProtocol.address, BigInt(hexAmountForDeposit));
                await this.hexOneProtocol.connect(this.depositor_1).depositCollateral(
                    this.hexToken.address,
                    BigInt(hexAmountForDeposit),
                    duration,
                    false
                );
                let afterHexOneTokenBal = await this.hexOneToken.balanceOf(this.depositor_1.address);

                console.log(smallNum(afterHexOneTokenBal, 18) - smallNum(beforeHexOneTokenBal, 18))
                await this.hexOnePriceFeed.setTestRate(600);   // 60%
            })

            it ("check liquidable deposits", async function () {
                let deposits = await this.hexOneVault.getLiquidableDeposits();
                /// before maturity no liquidable amount
                expect (deposits.length).to.be.equal(0);

                /// spend time
                await spendTime(32 * day);

                /// no liquidable before maturity + 7 days
                deposits = await this.hexOneVault.getLiquidableDeposits();
                expect (deposits.length).to.be.equal(0);

                /// spend more time
                await spendTime(6 * day);

                deposits = await this.hexOneVault.getLiquidableDeposits();
                expect (deposits.length).to.be.equal(1);
                expect (deposits[0].depositor).to.be.equal(this.depositor_1.address);
            })

            it ("claim hex with user not depositor", async function () {
                let deposits = await this.hexOneVault.getLiquidableDeposits();
                let liquidateInfo = deposits[0];
                let liquidateAmount = liquidateInfo.liquidateAmount;
                let hexOneTokenAmount = liquidateInfo.hexOneTokenAmount;
                let hexTokenAmount = liquidateInfo.hexTokenAmount;

                let beforeHexTokenBal = await this.hexToken.balanceOf(this.depositor_2.address);
                let beforeHexOneTokenBal = await this.hexOneToken.balanceOf(this.depositor_2.address);
                await this.hexOneToken.connect(this.depositor_2).approve(this.hexOneProtocol.address, BigInt(liquidateAmount));
                await this.hexOneProtocol.connect(this.depositor_2).claimCollateral(
                    this.hexToken.address, 
                    liquidateInfo.depositId
                );
                let afterHexTokenBal = await this.hexToken.balanceOf(this.depositor_2.address);
                let afterHexOneTokenBal = await this.hexOneToken.balanceOf(this.depositor_2.address);

                expect (
                    smallNum(afterHexTokenBal, 8) - smallNum(beforeHexTokenBal, 8)
                ).to.be.greaterThan(smallNum(hexTokenAmount, 8));

                expect (
                    smallNum(BigInt(beforeHexOneTokenBal) - BigInt(afterHexOneTokenBal), 18)
                ).to.be.equal(smallNum(BigInt(liquidateAmount) + BigInt(hexOneTokenAmount), 18));
            })
        })

        describe ("unstake and get rewards", function () {
            it ("claimable rewards", async function () {
                let rewardAmount_1 = await this.stakingMaster.claimableRewards(
                    this.staker_1.address,
                    this.hexToken.address,
                    this.hexToken.address
                );

                let rewardAmount_2 = await this.stakingMaster.claimableRewards(
                    this.staker_2.address,
                    this.hexToken.address,
                    this.hexToken.address
                );

                expect (rewardAmount_1.length).to.be.equal(1);
                expect (rewardAmount_2.length).to.be.equal(1);

                let beforeBal = await this.hexToken.balanceOf(this.staker_1.address);
                await this.stakingMaster.connect(this.staker_1).stakeERC20End(
                    this.hexToken.address,
                    this.hexToken.address,
                    rewardAmount_1[0].stakeId
                );
                let afterBal = await this.hexToken.balanceOf(this.staker_1.address);

                expect (smallNum(BigInt(afterBal) - BigInt(beforeBal), 8)).to.be.equal(
                    smallNum(BigInt(rewardAmount_1[0].claimableRewards) + BigInt(rewardAmount_1[0].stakedAmount), 8)
                );

                beforeBal = await this.hexToken.balanceOf(this.staker_2.address);
                await this.stakingMaster.connect(this.staker_2).stakeERC20End(
                    this.hexToken.address,
                    this.hexToken.address,
                    rewardAmount_2[0].stakeId
                );
                afterBal = await this.hexToken.balanceOf(this.staker_2.address);

                expect (smallNum(BigInt(afterBal) - BigInt(beforeBal), 8)).to.be.equal(
                    smallNum(BigInt(rewardAmount_2[0].claimableRewards) + BigInt(rewardAmount_2[0].stakedAmount), 8)
                );
            })
        })
    })
})