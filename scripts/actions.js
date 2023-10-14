const { ethers, network } = require("hardhat");
const { getContract, getCurrentTimestamp } = require("./utils");
const { getDeploymentParam } = require("./param");

const { pulsex_abi } = require("../external_abi/pulsex.abi.json");
const { erc20_abi } = require("../external_abi/erc20.abi.json");
const { factory_abi } = require("../external_abi/factory.abi.json")

async function getHexTokenFeeInfo() {
    const hexOneProtocol = await getContract(
        "HexOneProtocol",
        "HexOneProtocol",
        network.name
    );

    let param = getDeploymentParam();
    let hexTokenAddr = param.hexToken;
    console.log(await hexOneProtocol.fees(hexTokenAddr));
}

async function getRewardsPoolInfo() {
    const hexOneStaking = await getContract(
        "HexOneStaking",
        "HexOneStaking",
        network.name
    );

    console.log("rewardsPool info: ", await hexOneStaking.rewardsPool());
}

async function setHexTokenFeeInfo(feeRate) {
    const hexOneProtocol = await getContract(
        "HexOneProtocol",
        "HexOneProtocol",
        network.name
    );
    let param = getDeploymentParam();
    let hexTokenAddr = param.hexToken;
    console.log("set depositFeeRate");
    let tx = await hexOneProtocol.setDepositFee(hexTokenAddr, feeRate);
    await tx.wait();
    console.log("enable DepositFee");
    tx = await hexOneProtocol.setDepositFeeEnable(hexTokenAddr, true);
    await tx.wait();
    console.log("setHexTokenDepositFee successfully");
}

async function enableStaking() {
    const hexOneStaking = await getContract(
        "HexOneStaking",
        "HexOneStaking",
        network.name
    );

    console.log(
        "current staking status: ",
        await hexOneStaking.stakingEnable()
    );

    let param = getDeploymentParam();
    const hexOneProtocol = await getContract(
        "HexOneProtocol",
        "HexOneProtocol",
        network.name
    );

    let tx = await hexOneStaking.enableStaking();
    await tx.wait();

    console.log("after staking status: ", await hexOneStaking.stakingEnable());
}

async function generateAdditionalTokens() {
    const hexOneBootstrap = await getContract(
        "HexOneBootstrap",
        "HexOneBootstrap",
        network.name
    );

    console.log(
        "generateAdditionalTokens and purchase hexit to staking contract"
    );
    await hexOneBootstrap.generateAdditionalTokens();
    console.log("addtionalTokens generated successfully!");
}

async function createHexStakingPool() {
    const [deployer] = await ethers.getSigners();
    let param = getDeploymentParam();
    const hexOneStaking = await getContract(
        "HexOneStaking",
        "HexOneStaking",
        network.name
    );
    let hexit = await getContract("HEXIT", "HEXIT", network.name);
    let hexone = await getContract("HexOneToken", "HexOneToken", network.name);
    let factory = await ethers.Contract('0x29eA7545DEf87022BAdc76323F373EA1e707C523', factory_abi, deployer)
    let hex1dai = factory.getPair(hexone, param.daiAddress)
    let hex1hex = factory.getPair(hexone, param.hexToken)
    //let hex1dai = '0x37a30908C77Bc1da05478317026ED84F6Bb1ADbE'
    //let hex1hex = '0x15f566711E2B703011BaF7f878dd0ce1e30E0753'
    console.log(hex1dai, hex1hex)

    console.log("add hex1 hexit hex1/hex hex1/dai token to allowToken list");
    let tx = await hexOneStaking.addAllowedTokens(
        [hexit.address, hexone.address, hex1dai, hex1hex],
        [
            {
                hexDistRate: 100,
                hexitDistRate: 100,
            },
            {
                hexDistRate: 100,
                hexitDistRate: 100,
            },
            {
                hexDistRate: 600,
                hexitDistRate: 600,
            },
            {
                hexDistRate: 200,
                hexitDistRate: 200,
            },]
    );
    await tx.wait();
    console.log("processed successfully!");
}

async function increasePriceFeedRate() {
    const hexOnePriceFeed = await getContract(
        "HexOnePriceFeedTest",
        "HexOnePriceFeedTest",
        network.name
    );
    console.log("set priceFeed rate as 150%");
    let tx = await hexOnePriceFeed.setTestRate(1500);
    await tx.wait();
    console.log("processed successfully!");
}

async function decreasePriceFeedRate() {
    const hexOnePriceFeed = await getContract(
        "HexOnePriceFeedTest",
        "HexOnePriceFeedTest",
        network.name
    );
    console.log("set priceFeed rate as 80%");
    let tx = await hexOnePriceFeed.setTestRate(800);
    await tx.wait();
    console.log("processed successfully!");
}

async function setHexOneEscrowAddress() {
    const hexOneProtocol = await getContract(
        "HexOneProtocol",
        "HexOneProtocol",
        network.name
    );
    const hexOneEscrow = await getContract(
        "HexOneEscrow",
        "HexOneEscrow",
        network.name
    );
    console.log("setting EscrowContract address");
    let tx = await hexOneProtocol.setEscrowContract(hexOneEscrow.address);
    await tx.wait();
    console.log("processed successfully!");
}

async function depositEscrowHexToProtocol() {
    const hexOneEscrow = await getContract(
        "HexOneEscrow",
        "HexOneEscrow",
        network.name
    );
    console.log("deposit escrow hex to protocol");
    let tx = await hexOneEscrow.depositCollateralToHexOneProtocol(2);
    await tx.wait();
    console.log("processed successfully!");
}

async function getLiquidableDeposits() {
    const hexOneVault = await getContract(
        "HexOneVault",
        "HexOneVault",
        network.name
    );
    console.log(await hexOneVault.getLiquidableDeposits());
}

async function addHexOneLiquidity() {
    const [deployer] = await ethers.getSigners();
    let param = getDeploymentParam();
    let USDC = new ethers.Contract(param.usdcAddress, erc20_abi, deployer);
    let PLSX = new ethers.Contract(param.plsxAddress, erc20_abi, deployer);
    let DAI = new ethers.Contract(param.daiAddress, erc20_abi, deployer);
    let hexOne = await getContract("HexOneToken", "HexOneToken", network.name);
    let uniswapRouter = new ethers.Contract(
        param.dexRouter,
        pulsex_abi,
        deployer
    );
    let hexToken = new ethers.Contract(param.hexToken, erc20_abi, deployer);

    console.log("add liquidity Hex1/Hex");
    let plsAmountForSwap = bigNum(3000, 18);
    let WPLS = await uniswapRouter.WPLS();
    let tx = await uniswapRouter.swapExactETHForTokens(
        0,
        [WPLS, hexOne.address],
        deployer.address,
        BigInt(await getCurrentTimestamp()) + BigInt(100),
        {
            value: BigInt(plsAmountForSwap)
        }
    );
    await tx.wait();

    tx = await uniswapRouter.swapExactETHForTokens(
        0,
        [WPLS, hexToken.address],
        deployer.address,
        BigInt(await getCurrentTimestamp()) + BigInt(100),
        {
            value: BigInt(plsAmountForSwap)
        }
    );
    await tx.wait();

    let hexAmountForLiquidity = await hexToken.balanceOf(deployer.address);
    let hexOneForLiquidity = await hexOne.balanceOf(deployer.address);
    console.log(smallNum(hexAmountForLiquidity, 8), smallNum(hexOneForLiquidity, 18));

    tx = await hexOne.approve(uniswapRouter.address, BigInt(hexOneForLiquidity));
    await tx.wait();

    tx = await hexToken.approve(
        uniswapRouter.address,
        BigInt(hexAmountForLiquidity)
    );
    await tx.wait();
    tx = await uniswapRouter.addLiquidity(
        hexOne.address,
        hexToken.address,
        BigInt(hexOneForLiquidity),
        BigInt(hexAmountForLiquidity),
        0,
        0,
        deployer.address,
        BigInt(await getCurrentTimestamp()) + BigInt(100)
    );
    await tx.wait();

    console.log("addLiquidity HEX1/DAI");
    tx = await uniswapRouter.swapExactETHForTokens(
        0,
        [WPLS, DAI.address],
        deployer.address,
        BigInt(await getCurrentTimestamp()) + BigInt(100),
        {
            value: BigInt(plsAmountForSwap)
        }
    );
    await tx.wait();

    tx = await uniswapRouter.swapExactETHForTokens(
        0,
        [WPLS, hexOne.address],
        deployer.address,
        BigInt(await getCurrentTimestamp()) + BigInt(100),
        {
            value: BigInt(plsAmountForSwap)
        }
    );
    await tx.wait();

    hexOneForLiquidity = await hexOne.balanceOf(deployer.address);
    let daiAmountForLiquidity = await DAI.balanceOf(deployer.address);
    console.log(hexOneForLiquidity, daiAmountForLiquidity);

    tx = await DAI.approve(uniswapRouter.address, BigInt(daiAmountForLiquidity));
    await tx.wait();

    tx = await hexOne.approve(
        uniswapRouter.address,
        BigInt(hexOneForLiquidity)
    );
    await tx.wait();
    tx = await uniswapRouter.addLiquidity(
        hexOne.address,
        DAI.address,
        BigInt(hexOneForLiquidity),
        BigInt(daiAmountForLiquidity),
        0,
        0,
        deployer.address,
        BigInt(await getCurrentTimestamp()) + BigInt(100)
    );
    await tx.wait();
    console.log("processed successfully!");
}

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Action contract with the account: ", deployer.address);

    await addHexOneLiquidity()

    await getHexTokenFeeInfo();
    await setHexTokenFeeInfo(50); // set feeRate as 5%
    await getHexTokenFeeInfo();

    // await getRewardsPoolInfo();
    // await generateAdditionalTokens();
    // await getRewardsPoolInfo();

    // await enableStaking();

    // await createHexStakingPool();

    // await increasePriceFeedRate();
    // await decreasePriceFeedRate();

    await setHexOneEscrowAddress();

    await depositEscrowHexToProtocol();

    await getLiquidableDeposits();

    // await generateAdditionalTokens();

    // const hexOneBootstrap = await getContract("HexOneBootstrap", "HexOneBootstrap", network.name);
    // const userAddr = "0xf960c54D4744C7B9B1B450C30F5cfe2D825abc0F";
    // const sacrificeUserInfo = await hexOneBootstrap.getUserSacrificeInfo(userAddr);
    // const info = sacrificeUserInfo[2];
    // console.log(info);

    // console.log(BigInt(info.sacrificedWeight) * BigInt(info.supplyAmount));
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
