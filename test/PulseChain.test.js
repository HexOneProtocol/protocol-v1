const { expect } = require("chai");
const { ethers } = require("hardhat");
const { constants } = require("@openzeppelin/test-helpers");

const { pulsex_abi } = require("../external_abi/pulsex.abi.json");
const { erc20_abi } = require("../external_abi/erc20.abi.json");
const { hex_abi } = require("../external_abi/hex.abi.json");

const {
  deploy,
  bigNum,
  smallNum,
  getCurrentTimestamp,
} = require("../scripts/utils");

describe("Pulsechain test", function () {
  let pulsexRouterAddress = "0x98bf93ebf5c380C0e6Ae8e192A7e2AE08edAcc02";
  let daiAddress = "0xefD766cCb38EaF1dfd701853BFCe31359239F305";
  let hexAddress = "0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39";
  let usdcAddress = "0x15D38573d2feeb82e7ad5187aB8c1D52810B1f07";
  let WPLS;

  before(async function () {
    [this.deployer, this.account_1, this.account_2] = await ethers.getSigners();
    this.dexRouter = new ethers.Contract(
      pulsexRouterAddress,
      pulsex_abi,
      this.deployer
    );
    this.hexToken = new ethers.Contract(hexAddress, hex_abi, this.deployer);
    this.USDC = new ethers.Contract(usdcAddress, erc20_abi, this.deployer);
    this.DAI = new ethers.Contract(daiAddress, erc20_abi, this.deployer);
  });

  it("check deployment", async function () {
    console.log("deployed successfully!");
  });

  it("swap PLS for USDC", async function () {
    let swapPLSAmount = bigNum(10, 18);
    WPLS = await this.dexRouter.WPLS();
    let usdcDecimals = await this.USDC.decimals();
    let beforeUSDC = await this.USDC.balanceOf(this.deployer.address);
    await this.dexRouter.swapExactETHForTokens(
      0,
      [WPLS, this.USDC.address],
      this.deployer.address,
      BigInt(await getCurrentTimestamp()) + BigInt(1000),
      { value: BigInt(swapPLSAmount) }
    );
    let afterUSDC = await this.USDC.balanceOf(this.deployer.address);
    console.log(
      "received USDC amount: ",
      smallNum(BigInt(afterUSDC) - BigInt(beforeUSDC), usdcDecimals)
    );
  });

  it("swap PLS for hex", async function () {
    let swapPLSAmount = bigNum(10, 18);
    let hexDecimals = await this.hexToken.decimals();
    let beforeHex = await this.hexToken.balanceOf(this.deployer.address);
    await this.dexRouter.swapExactETHForTokens(
      0,
      [WPLS, this.hexToken.address],
      this.deployer.address,
      BigInt(await getCurrentTimestamp()) + BigInt(1000),
      { value: BigInt(swapPLSAmount) }
    );
    let afterHex = await this.hexToken.balanceOf(this.deployer.address);
    console.log(
      "received hex token amount: ",
      smallNum(BigInt(afterHex) - BigInt(beforeHex), hexDecimals)
    );
  });
});
