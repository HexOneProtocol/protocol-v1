const { network } = require("hardhat");

const DEPLOYMENT_PARAM = {
    mainnet: {
        dexRouter: "",
        hexToken: "",
        usdcAddress: "",
        usdcPriceFeed: "",
        feeReceiver: "",
    },
    goerli: {
        dexRouter: "",
        hexToken: "0xdF1906df64C5f3b13eFAA25729F5EA4b469db805",
        usdcAddress: "0x07865c6E87B9F70255377e024ace6630C1Eaa37F",
        usdcPriceFeed: "0xAb5c49580294Aff77670F839ea425f5b78ab3Ae7",
        feeReceiver: "0x4364E1d16526c954b029b6cf9335CB1b0eaAfB69",
        feeRate: 100, // 100%
        minStakingDuration: 1, // 1 day
        maxStakingDuration: 10, // 10 days
        sacrificeStartTime: 0, // means after 0 seconds
        sacrificeDuration: 30, // 30 days
        airdropStartTime: 0, // means after 0 seconds
        airdropDuration: 30, // 30 days
        rateForSacrifice: 800,
        rateForAirdrop: 200,
        sacrificeDistRate: 750,
        sacrificeLiquidityRate: 250,
        airdropDistRateForHexHolder: 700,
        airdropDistRateForHEXITHolder: 300,
    },
};

const getDeploymentParam = () => {
    if (network.name == "goerli") {
        return DEPLOYMENT_PARAM.goerli;
    } else if (network.name == "mainnet") {
        return DEPLOYMENT_PARAM.mainnet;
    } else {
        return {};
    }
};

module.exports = {
    getDeploymentParam,
};
