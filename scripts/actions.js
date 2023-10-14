const { ethers, network } = require("hardhat");
const { getContract, getCurrentTimestamp } = require("./utils");
const { getDeploymentParam } = require("./param");

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
    const hexOneStaking = await getContract(
        "HexOneStaking",
        "HexOneStaking",
        network.name
    );
    let hexit = await getContract("HEXIT", "HEXIT", network.name);
    let hexone = await getContract("HexOneToken", "HexOneToken", network.name);
    let param = getDeploymentParam();
    let hex1TokenAddr = hexone.address;
    let hexitTokenAddr = hexit.address
    let hexdai = '0x37a30908C77Bc1da05478317026ED84F6Bb1ADbE'
    let hexhex1 = '0x15f566711E2B703011BaF7f878dd0ce1e30E0753'

    console.log(hex1TokenAddr, hexitTokenAddr)
    console.log("add hex1 hexit hex1/hex hex/dai token to allowToken list");
    let tx = await hexOneStaking.addAllowedTokens(
        [hexitTokenAddr, hex1TokenAddr, hexdai, hexhex1],
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

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Action contract with the account: ", deployer.address);

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
