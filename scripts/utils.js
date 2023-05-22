const { ethers, upgrades, network } = require("hardhat");
const { getImplementationAddress } = require("@openzeppelin/upgrades-core");
const fs = require("fs");

const hour = 60 * 60;

const day = 24 * hour;

const month = day * 30;

const delay = (ms) => new Promise((res) => setTimeout(res, ms));

const checkDeploymentFolder = async () => {
    if (network.name == "localhost" || network.name == "hardhat") return;

    const addressDir = `${__dirname}/../deploy_address/`;
    if (!fs.existsSync(addressDir)) {
        fs.mkdirSync(addressDir);
    }
};

const updateAddress = async (contractName, contractAddreses) => {
    if (network.name == "localhost" || network.name == "hardhat") return;
    await checkDeploymentFolder();
    const addressDir = `${__dirname}/../deploy_address/${network.name}`;
    if (!fs.existsSync(addressDir)) {
        fs.mkdirSync(addressDir);
    }

    let data = "";
    if (contractAddreses.length == 2) {
        data = {
            contract: contractAddreses[0],
            proxyImp: contractAddreses[1],
        };
    } else {
        data = {
            contract: contractAddreses[0],
        };
    }

    fs.writeFileSync(
        `${addressDir}/${contractName}.txt`,
        JSON.stringify(data, null, 2)
    );
};

const getContractAddress = async (contractName, network_name) => {
    const addressDir = `${__dirname}/../deploy_address/${network_name}`;
    if (!fs.existsSync(addressDir)) {
        return "";
    }

    let data = fs.readFileSync(`${addressDir}/${contractName}.txt`);
    data = JSON.parse(data, null, 2);

    return data;
};

const getContract = async (contractName, contractMark, network_name) => {
    const addressDir = `${__dirname}/../deploy_address/${network_name}`;
    if (!fs.existsSync(addressDir)) {
        return "";
    }

    let data = fs.readFileSync(`${addressDir}/${contractMark}.txt`);
    data = JSON.parse(data, null, 2);

    return await getAt(contractName, data.contract);
};

const deploy = async (contractName, contractMark, ...args) => {
    const factory = await ethers.getContractFactory(contractName);
    const contract = await factory.deploy(...args);
    await contract.deployed();

    if (network.name != "hardhat") {
        await delay(12000);
        console.log("Waited 12s");
    }

    await verify(contract.address, [...args]);
    console.log(contractName, contract.address);
    await updateAddress(contractMark, [contract.address]);
    return contract;
};

const deployProxy = async (contractName, contractMark, args = []) => {
    const factory = await ethers.getContractFactory(contractName);
    const contract = await upgrades.deployProxy(factory, args, {
        unsafeAllow: ["delegatecall", "constructor"],
    });
    await contract.deployed();

    if (network.name != "hardhat") {
        await delay(12000);
        console.log("Waited 12s");
    }

    const implAddress = await getImplementationAddress(
        ethers.provider,
        contract.address
    );
    await verify(implAddress, args);
    await updateAddress(contractMark, [contract.address, implAddress]);
    console.log(contractName, contract.address, implAddress);
    return contract;
};

const verifyProxy = async (contractName, contractMark, args = []) => {
    const contract = await getContract(
        contractName,
        contractMark,
        network.name
    );

    const implAddress = await getImplementationAddress(
        ethers.provider,
        contract.address
    );
    await verify(implAddress, args);
};

const upgradeProxy = async (contractName, contractMark, contractAddress) => {
    const factory = await ethers.getContractFactory(contractName);
    const contract = await upgrades.upgradeProxy(contractAddress, factory, {
        unsafeAllow: ["delegatecall", "constructor"],
    });
    await contract.deployed();
    const implAddress = await getImplementationAddress(
        ethers.provider,
        contract.address
    );
    await updateAddress(contractMark, [contract.address, implAddress]);
    console.log(contractName, contract.address, implAddress);
    return contract;
};

const getAt = async (contractName, contractAddress) => {
    return await ethers.getContractAt(contractName, contractAddress);
};

const verify = async (contractAddress, args = []) => {
    if (network.name == "localhost" || network.name == "hardhat") return;
    try {
        console.log("verifying...");
        await hre.run("verify:verify", {
            address: contractAddress,
            constructorArguments: args,
        });
    } catch (ex) {
        console.log(ex);
    }
};

const getCurrentTimestamp = async () => {
    return (await ethers.provider.getBlock("latest")).timestamp;
};

const spendTime = async (spendSeconds) => {
    await network.provider.send("evm_increaseTime", [spendSeconds]);
    await network.provider.send("evm_mine");
};

const getETHBalance = async (walletAddress) => {
    return await ethers.provider.getBalance(walletAddress);
};

const bigNum = (num, decimals) => num + "0".repeat(decimals);

const smallNum = (num, decimals) => parseInt(num) / bigNum(1, decimals);

module.exports = {
    getAt,
    verify,
    verifyProxy,
    deploy,
    deployProxy,
    upgradeProxy,
    getContractAddress,
    getContract,
    getCurrentTimestamp,
    spendTime,
    getETHBalance,
    bigNum,
    smallNum,
    hour,
    day,
    month,
};
