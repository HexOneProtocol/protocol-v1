/** @type import('hardhat/config').HardhatUserConfig */
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-ethers");
require("@openzeppelin/hardhat-upgrades");
// require("hardhat-gas-reporter");
require("hardhat-contract-sizer");
require("solidity-coverage");
require("dotenv").config();
const { utils } = require("ethers");

module.exports = {
    defaultNetwork: "hardhat",
    networks: {
        hardhat: {
            forking: {
                // url: "https://api.avax-test.network/ext/bc/C/rpc",
                // blockNumber: 20593883,
                url: "https://mainnet.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161",
                blockNumber: 16589147,
                // url: "https://goerli.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161",
                // blockNumber: 8611771
            },
        },
        goerli: {
            url: "https://goerli.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161",
            chainId: 5,
            gasPrice: utils.parseUnits("100", "gwei").toNumber(),
            accounts: [process.env.DEPLOYER_WALLET],
        },
        pulse: {
            url: "https://rpc.v2b.testnet.pulsechain.com",
            chainId: 941,
            gasPrice: utils.parseUnits("100", "gwei").toNumber(),
            accounts: [process.env.DEPLOYER_WALLET],
        },
        fuji: {
            url: "https://api.avax-test.network/ext/bc/C/rpc",
            chainId: 43113,
            accounts: [process.env.DEPLOYER_WALLET],
            gasPrice: utils.parseUnits("100", "gwei").toNumber(),
        },
    },
    solidity: {
        compilers: [
            {
                version: "0.8.17",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 2000,
                    },
                },
            },
        ],
    },
    etherscan: {
        apiKey: {
            mainnet: process.env.ETH_API_KEY,
            goerli: process.env.ETH_API_KEY,
            avalancheFujiTestnet: process.env.AVAX_API_KEY,
        },
    },
    mocha: {
        timeout: 2000000000,
    },
};
