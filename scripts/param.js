const { network } = require("hardhat");
const { hour } = require("./utils");

const DEPLOYMENT_PARAM = {
    mainnet: {
        dexRouter: "",
        hexToken: "",
        usdcAddress: "",
        usdcPriceFeed: "",
        feeReceiver: "",
    },
    fuji: {
        dexRouter: "0x3705aBF712ccD4fc56Ee76f0BD3009FD4013ad75",
        hexToken: "0xEb06b60E0b3A421a7100A3b09fd25DE119831694",
        usdcAddress: "0x8025e948a7d494A845588099cb861a903EAdcF93",
        usdcPriceFeed: "0x7898AcCC83587C3C55116c5230C17a6Cd9C71bad",
        feeReceiver: "0x4364E1d16526c954b029b6cf9335CB1b0eaAfB69",
        teamWallet: "0x4364E1d16526c954b029b6cf9335CB1b0eaAfB69",
        feeRate: 100, // 10%
        minStakingDuration: 1, // 1 day
        maxStakingDuration: 10, // 10 days
        sacrificeStartTime: hour, // means after an hour
        sacrificeDuration: 3, // 1 day
        airdropStartTime: hour, // means after an hour
        airdropDuration: 3, // 1 days
        rateForSacrifice: 800,
        rateForAirdrop: 200,
        sacrificeDistRate: 750,
        sacrificeLiquidityRate: 250,
        airdropDistRateForHexHolder: 100,
        airdropDistRateForHEXITHolder: 900,
        hexitDistRateForStaking: 50, // 5%
    },
    pulse: {
        dexRouter: "0x165C3410fC91EF562C50559f7d2289fEbed552d9",
        hexToken: "0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39", // HEX
        usdcAddress: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",  // USDC
        plsxAddress: "0x95B303987A60C71504D99Aa1b13B4DA07b0790ab",  // PLSX
        wplsAddress: "0xA1077a294dDE1B09bB078844df40758a5D0f9a27",  // WPLS
        daiAddress: "0xefD766cCb38EaF1dfd701853BFCe31359239F305",  // DAI
        feeReceiver: "0x4364E1d16526c954b029b6cf9335CB1b0eaAfB69",
        teamWallet: "0xc54A5f32Bc53f49eBC4FE69c6AE60adE91eC8A35",
        feeRate: 300, // 30%
        minStakingDuration: 1, // 1 day
        maxStakingDuration: 10, // 10 days
        sacrificeStartTime: hour / 3, // means after 0 seconds
        sacrificeDuration: 1, // 2 day
        airdropStartTime: hour, // means after 0 seconds
        airdropDuration: 1, // 3 days
        rateForSacrifice: 800,
        rateForAirdrop: 200,
        sacrificeDistRate: 750,
        sacrificeLiquidityRate: 250,
        airdropDistRateForHexHolder: 100,
        airdropDistRateForHEXITHolder: 900,
        hexitDistRateForStaking: 30, // 3%
    },
    pulse_test: {
        dexRouter: "0xDaE9dd3d1A52CfCe9d5F2fAC7fDe164D500E50f7",
        hexToken: "0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39", // HEX
        usdcAddress: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",  // USDC
        plsxAddress: "0x8a810ea8B121d08342E9e7696f4a9915cBE494B7",  // PLSX
        wplsAddress: "0x70499adEBB11Efd915E3b69E700c331778628707",  // WPLS
        daiAddress: "0x826e4e896CC2f5B371Cd7Bb0bd929DB3e3DB67c0",  // DAI
        feeReceiver: "0x4364E1d16526c954b029b6cf9335CB1b0eaAfB69",
        teamWallet: "0xc54A5f32Bc53f49eBC4FE69c6AE60adE91eC8A35",
        feeRate: 100, // 10%
        minStakingDuration: 1, // 1 day
        maxStakingDuration: 10, // 10 days
        sacrificeStartTime: hour, // means after 0 seconds
        sacrificeDuration: 1, // 5 day
        airdropStartTime: hour, // means after 0 seconds
        airdropDuration: 1, // 3 days
        rateForSacrifice: 800,
        rateForAirdrop: 200,
        sacrificeDistRate: 750,
        sacrificeLiquidityRate: 250,
        airdropDistRateForHexHolder: 100,
        airdropDistRateForHEXITHolder: 900,
        hexitDistRateForStaking: 50, // 5%
    }
};

const getDeploymentParam = () => {
    if (network.name == "fuji") {
        return DEPLOYMENT_PARAM.fuji;
    } else if (network.name == "mainnet") {
        return DEPLOYMENT_PARAM.mainnet;
    } else if (network.name == "pulse_test") {
        return DEPLOYMENT_PARAM.pulse_test;
    } else if (network.name == "pulse") {
        return DEPLOYMENT_PARAM.pulse;
    } else {
        return {};
    }
};

module.exports = {
    getDeploymentParam,
};
