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

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Action contract with the account: ", deployer.address);

    // await getHexTokenFeeInfo();
    // await setHexTokenFeeInfo(50); // set feeRate as 5%
    // await getHexTokenFeeInfo();

    // await getRewardsPoolInfo();
    // await generateAdditionalTokens();
    // await getRewardsPoolInfo();

    await enableStaking();
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
