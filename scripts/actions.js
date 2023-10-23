const { ethers, network } = require("hardhat");
const { getContract, getCurrentTimestamp } = require("./utils");
const { getDeploymentParam } = require("./param");

const { pulsex_abi } = require("../external_abi/pulsex.abi.json");
const { erc20_abi } = require("../external_abi/erc20.abi.json");
const { factory_abi } = require("../external_abi/factory.abi.json")

async function getRewardsPoolInfo() {
    const hexOneStaking = await getContract(
        "HexOneStaking",
        "HexOneStaking",
        network.name
    );

    console.log("rewardsPool info: ", await hexOneStaking.rewardsPool());
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
    let tx = await hexOneBootstrap.generateAdditionalTokens();
    await tx.wait()
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
    let factory = new ethers.Contract('0x29eA7545DEf87022BAdc76323F373EA1e707C523', factory_abi, deployer)

    let hex1dai = await factory.getPair(hexone.address, param.daiAddress)
    console.log(hex1dai)

    console.log("add hex1 hexit hex1/hex hex1/dai token to allowToken list");
    let tx = await hexOneStaking.addAllowedTokens(
        [hexit.address, hexone.address, hex1dai],
        [
            {
                hexDistRate: 200,
                hexitDistRate: 200,
            },
            {
                hexDistRate: 200,
                hexitDistRate: 200,
            },
            {
                hexDistRate: 600,
                hexitDistRate: 600,
            },]
    );
    await tx.wait();
    // console.log("processed successfully!");
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

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Action contract with the account: ", deployer.address);

    await setHexOneEscrowAddress();

    await depositEscrowHexToProtocol();

    await getLiquidableDeposits();

    // await getRewardsPoolInfo();
    // await generateAdditionalTokens();
    // await getRewardsPoolInfo();

    // await enableStaking();

    // await createHexStakingPool();

    // await increasePriceFeedRate();
    // await decreasePriceFeedRate();

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
