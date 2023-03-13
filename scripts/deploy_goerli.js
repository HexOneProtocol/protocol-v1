const { ethers, network } = require("hardhat");
const { deploy, deployProxy, getCurrentTimestamp, spendTime, bigNum, smallNum, day, hour, getContract } = require('../scripts/utils');

const { uniswap_abi } = require('../external_abi/uniswap.abi.json');
const { erc20_abi } = require('../external_abi/erc20.abi.json');
const { hex_abi } = require('../external_abi/hex.abi.json');

async function deployContracts() {
    const [deployer] = await ethers.getSigners();
    let usdcAddress = "0x07865c6E87B9F70255377e024ace6630C1Eaa37F";
    let usdcPriceFeed = "0xAb5c49580294Aff77670F839ea425f5b78ab3Ae7";
    let uniswapRouterAddress = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";

    let hexToken = await deploy("HexMockToken", "HexMockToken");
    let uniswapRouter = new ethers.Contract(uniswapRouterAddress, uniswap_abi, deployer);
    let USDC = new ethers.Contract(usdcAddress, erc20_abi, deployer);
    let hexOneToken = await deploy("HexOneToken", "HexOneToken", "HexOne", "HEXONE");
    let hexOnePriceFeed = await deployProxy(
        "HexOnePriceFeedTest", 
        "HexOnePriceFeedTest", 
        [
            hexToken.address, 
            usdcAddress, 
            usdcPriceFeed,
            uniswapRouter.address
        ]
    );

    let hexOneVault = await deployProxy(
        "HexOneVault",
        "HexOneVault",
        [
            hexToken.address,
            hexOnePriceFeed.address
        ]
    );
    let stakingMaster = await deployProxy(
        "HexOneStakingMaster",
        "HexOneStakingMaster"
    );
    let hexOneProtocol = await deployProxy(
        "HexOneProtocol",
        "HexOneProtocol",
        [
            hexOneToken.address,
            [hexOneVault.address],
            stakingMaster.address,
            30,
            120
        ]
    );

    let HEXIT = await deploy(
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
        hexOnePriceFeed: hexOnePriceFeed.address,
        dexRouter: uniswapRouter.address,
        hexToken: hexToken.address,
        pairToken: usdcAddress,
        hexitToken: HEXIT.address,
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

    let hexOneBootstrap = await deployProxy(
        "HexOneBootstrap",
        "HexOneBootstrap",
        [bootstrapParam]
    );

    let hexOneEscrow = await deployProxy(
        "HexOneEscrow",
        "HexOneEscrow",
        [
            hexOneBootstrap.address,
            hexToken.address,
            hexOneToken.address,
            hexOneProtocol.address
        ]
    );

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
        hexOneBootstrap,
        hexOneEscrow
    ];
}

async function getContracts() {
    const [deployer] = await ethers.getSigners();
    let usdcAddress = "0x07865c6E87B9F70255377e024ace6630C1Eaa37F";
    let uniswapRouterAddress = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";

    let hexToken = await getContract("HexMockToken", "HexMockToken", "goerli");
    let uniswapRouter = new ethers.Contract(uniswapRouterAddress, uniswap_abi, deployer);
    let USDC = new ethers.Contract(usdcAddress, erc20_abi, deployer);
    let hexOneToken = await getContract("HexOneToken", "HexOneToken", "goerli");
    let hexOnePriceFeed = await getContract(
        "HexOnePriceFeedTest", 
        "HexOnePriceFeedTest", 
        "goerli"
    );

    let hexOneVault = await getContract(
        "HexOneVault",
        "HexOneVault", 
        "goerli"
    );
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

    let HEXIT = await getContract(
        "HEXIT",
        "HEXIT", 
        "goerli"
    );

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
        uniswapRouter,
        USDC,
        hexOneToken,
        hexOnePriceFeed,
        hexOneVault,
        stakingMaster,
        hexOneProtocol,
        HEXIT,
        hexOneBootstrap,
        hexOneEscrow
    ];
}

async function initialize(
    hexOneToken,
    hexOneVault,
    stakingMaster,
    hexOneProtocol,
    HEXIT,
    hexOneBootstrap,
    hexOneEscrow
) {
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

async function addLiquidify(
    hexToken,
    uniswapRouter,
    USDC
) {
    const [deployer] = await ethers.getSigners();
    let ethAmountForBuy = ethers.utils.parseEther("0.1");
    let WETHAddress = await uniswapRouter.WETH();

    let beforeBal = await USDC.balanceOf(deployer.address);
    let tx = await uniswapRouter.swapExactETHForTokens(
        0,
        [WETHAddress, USDC.address],
        deployer.address,
        BigInt(await getCurrentTimestamp()) + BigInt(100),
        {value: ethAmountForBuy}
    ); await tx.wait();
    let afterBal = await USDC.balanceOf(deployer.address);
    let swappedUSDCAmount = BigInt(afterBal) - BigInt(beforeBal);
    swappedUSDCAmount = BigInt(swappedUSDCAmount) * BigInt(4) / BigInt(5);
    let hexAmountForLiquidity = await hexToken.balanceOf(deployer.address);
    hexAmountForLiquidity = BigInt(hexAmountForLiquidity) / BigInt(2);
    
    tx = await USDC.approve(uniswapRouter.address, BigInt(swappedUSDCAmount)); await tx.wait();
    tx = await hexToken.approve(uniswapRouter.address, BigInt(hexAmountForLiquidity)); await tx.wait();
    tx = await uniswapRouter.addLiquidity(
        USDC.address,
        hexToken.address,
        BigInt(swappedUSDCAmount),
        BigInt(hexAmountForLiquidity),
        0,
        0,
        deployer.address,
        BigInt(await getCurrentTimestamp()) + BigInt(100)
    ); await tx.wait();
}

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);
    let [
        hexToken,
        uniswapRouter,
        USDC,
        hexOneToken,
        hexOnePriceFeed,
        hexOneVault,
        stakingMaster,
        hexOneProtocol,
        HEXIT,
        hexOneBootstrap,
        hexOneEscrow
    ] = await deployContracts();

    // let [
    //     hexToken,
    //     uniswapRouter,
    //     USDC,
    //     hexOneToken,
    //     hexOnePriceFeed,
    //     hexOneVault,
    //     stakingMaster,
    //     hexOneProtocol,
    //     HEXIT,
    //     hexOneBootstrap,
    //     hexOneEscrow
    // ] = await getContracts();

    console.log("initialize");
    await initialize(
        hexOneToken,
        hexOneVault,
        stakingMaster,
        hexOneProtocol,
        HEXIT,
        hexOneBootstrap,
        hexOneEscrow
    );

    console.log("buy USDC token and add liquidity");
    await addLiquidify(
        hexToken,
        uniswapRouter,
        USDC
    );

    console.log("Deployed successfully");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
