const { ethers, network } = require("hardhat");
const {
    deploy,
    deployProxy,
    getCurrentTimestamp,
    spendTime,
    bigNum,
    smallNum,
    day,
    hour,
    getContract,
} = require("./utils");

const { uniswap_abi } = require("../external_abi/uniswap.abi.json");
const { erc20_abi } = require("../external_abi/erc20.abi.json");
const { hex_abi } = require("../external_abi/hex.abi.json");
const { getDeploymentParam } = require("./param");

async function deployBootstrap() {
    let param = getDeploymentParam();

    let hexOnePriceFeed = await getContract(
        "HexOnePriceFeedTest",
        "HexOnePriceFeedTest",
        "goerli"
    );

    hexOneToken = await getContract("HexOneToken", "HexOneToken", "goerli");
    hexOneProtocol = await getContract(
        "HexOneProtocol",
        "HexOneProtocol",
        "goerli"
    );

    let HEXIT = await getContract("HEXIT", "HEXIT", "goerli");

    let sacrificeStartTime =
        BigInt(await getCurrentTimestamp()) + BigInt(param.sacrificeStartTime);

    let airdropStartTime =
        BigInt(sacrificeStartTime) +
        BigInt(day) * BigInt(param.sacrificeDuration) +
        BigInt(param.airdropStartTime);

    let bootstrapParam = {
        hexOnePriceFeed: hexOnePriceFeed.address,
        dexRouter: param.dexRouter,
        hexToken: param.hexToken,
        pairToken: param.usdcAddress,
        hexitToken: HEXIT.address,
        sacrificeStartTime: sacrificeStartTime,
        airdropStartTime: airdropStartTime,
        sacrificeDuration: param.sacrificeDuration,
        airdropDuration: param.airdropDuration,
        rateForSacrifice: param.rateForSacrifice,
        rateForAirdrop: param.rateForAirdrop,
        sacrificeDistRate: param.sacrificeDistRate,
        sacrificeLiquidityRate: param.sacrificeLiquidityRate,
        airdropDistRateForHexHolder: param.airdropDistRateForHexHolder,
        airdropDistRateForHEXITHolder: param.airdropDistRateForHEXITHolder,
    };

    let hexOneBootstrap = await deployProxy(
        "HexOneBootstrap",
        "HexOneBootstrap",
        [bootstrapParam]
    );

    let hexOneEscrow = await deployProxy("HexOneEscrow", "HexOneEscrow", [
        hexOneBootstrap.address,
        param.hexToken,
        hexOneToken.address,
        hexOneProtocol.address,
    ]);

    return [hexOneBootstrap, hexOneEscrow];
}

async function deployProtocol() {
    let param = getDeploymentParam();

    let hexOneToken = await deploy(
        "HexOneToken",
        "HexOneToken",
        "HexOne",
        "HEXONE"
    );
    let hexOnePriceFeed = await deployProxy(
        "HexOnePriceFeedTest",
        "HexOnePriceFeedTest",
        [
            param.hexToken,
            param.usdcAddress,
            param.usdcPriceFeed,
            param.dexRouter,
        ]
    );

    let hexOneVault = await deployProxy("HexOneVault", "HexOneVault", [
        param.hexToken,
        param.hexOnePriceFeed,
    ]);

    let stakingMaster = await deployProxy(
        "HexOneStakingMaster",
        "HexOneStakingMaster",
        [param.feeReceiver, param.feeRate]
    );

    let hexOneProtocol = await deploy(
        "HexOneProtocol",
        "HexOneProtocol",
        hexOneToken.address,
        [hexOneVault.address],
        stakingMaster.address,
        param.minStakingDuration,
        param.maxStakingDuration
    );

    let HEXIT = await deploy("HEXIT", "HEXIT", "Hex Incentive Token", "HEXIT");

    return [
        hexToken,
        uniswapRouter,
        USDC,
        hexOneToken,
        hexOnePriceFeed,
        hexOneVault,
        stakingMaster,
        hexOneProtocol,
        HEXIT,
    ];
}

async function getContracts() {
    let hexToken = await getContract("HexMockToken", "HexMockToken", "goerli");
    let hexOneToken = await getContract("HexOneToken", "HexOneToken", "goerli");
    let hexOnePriceFeed = await getContract(
        "HexOnePriceFeedTest",
        "HexOnePriceFeedTest",
        "goerli"
    );

    let hexOneVault = await getContract("HexOneVault", "HexOneVault", "goerli");
    let stakingMaster = await getContract(
        "HexOneStakingMaster",
        "HexOneStakingMaster",
        "goerli"
    );
    let hexOneProtocol = await getContract(
        "HexOneProtocol",
        "HexOneProtocol",
        "goerli"
    );

    let HEXIT = await getContract("HEXIT", "HEXIT", "goerli");

    let hexOneBootstrap = await getContract(
        "HexOneBootstrap",
        "HexOneBootstrap",
        "goerli"
    );

    let hexOneEscrow = await getContract(
        "HexOneEscrow",
        "HexOneEscrow",
        "goerli"
    );

    return [
        hexToken,
        hexOneToken,
        hexOnePriceFeed,
        hexOneVault,
        stakingMaster,
        hexOneProtocol,
        HEXIT,
        hexOneBootstrap,
        hexOneEscrow,
    ];
}

async function initialize() {
    let [
        hexToken,
        hexOneToken,
        hexOnePriceFeed,
        hexOneVault,
        stakingMaster,
        hexOneProtocol,
        HEXIT,
        hexOneBootstrap,
        hexOneEscrow,
    ] = await getContracts();

    console.log("hexOneToken.setAdmin");
    let tx = await hexOneToken.setAdmin(hexOneProtocol.address);
    await tx.wait();

    console.log("hexOneVault.setHexOneProtocol");
    tx = await hexOneVault.setHexOneProtocol(hexOneProtocol.address);
    await tx.wait();

    console.log("stakingMaster.setHexOneProtocol");
    tx = await stakingMaster.setHexOneProtocol(hexOneProtocol.address);
    await tx.wait();

    console.log("hexOneBootstrap.setEscrowContract");
    tx = await hexOneBootstrap.setEscrowContract(hexOneEscrow.address);
    await tx.wait();

    console.log("HEXIT.setBootstrap");
    tx = await HEXIT.setBootstrap(hexOneBootstrap.address);
    await tx.wait();
}

async function addLiquidity() {
    const [deployer] = await ethers.getSigners();
    let param = getDeploymentParam();
    let USDC = new ethers.Contract(param.usdcAddress, erc20_abi, deployer);
    let uniswapRouter = new ethers.Contract(
        param.dexRouter,
        uniswap_abi,
        deployer
    );
    let hexToken = new ethers.Contract(param.hexToken, erc20_abi, deployer);

    let ethAmountForBuy = ethers.utils.parseEther("0.1");
    let WETHAddress = await uniswapRouter.WETH();

    let beforeBal = await USDC.balanceOf(deployer.address);
    let tx = await uniswapRouter.swapExactETHForTokens(
        0,
        [WETHAddress, USDC.address],
        deployer.address,
        BigInt(await getCurrentTimestamp()) + BigInt(100),
        { value: ethAmountForBuy }
    );
    await tx.wait();
    let afterBal = await USDC.balanceOf(deployer.address);
    let swappedUSDCAmount = BigInt(afterBal) - BigInt(beforeBal);
    swappedUSDCAmount = (BigInt(swappedUSDCAmount) * BigInt(4)) / BigInt(5);
    let hexAmountForLiquidity = await hexToken.balanceOf(deployer.address);
    hexAmountForLiquidity = BigInt(hexAmountForLiquidity) / BigInt(2);

    tx = await USDC.approve(uniswapRouter.address, BigInt(swappedUSDCAmount));
    await tx.wait();
    tx = await hexToken.approve(
        uniswapRouter.address,
        BigInt(hexAmountForLiquidity)
    );
    await tx.wait();
    tx = await uniswapRouter.addLiquidity(
        USDC.address,
        hexToken.address,
        BigInt(swappedUSDCAmount),
        BigInt(hexAmountForLiquidity),
        0,
        0,
        deployer.address,
        BigInt(await getCurrentTimestamp()) + BigInt(100)
    );
    await tx.wait();
}

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    console.log("Deployed successfully");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
