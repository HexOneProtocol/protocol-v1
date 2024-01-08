// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";

import {HexOneToken} from "../src/HexOneToken.sol";
import {HexitToken} from "../src/HexitToken.sol";
import {HexOneStaking} from "../src/HexOneStaking.sol";
import {HexOnePriceFeed} from "../src/HexOnePriceFeed.sol";
import {HexOneVault} from "../src/HexOneVault.sol";

import {IHexOneToken} from "../src/interfaces/IHexOneToken.sol";
import {IHexitToken} from "../src/interfaces/IHexitToken.sol";
import {IHexOneStaking} from "../src/interfaces/IHexOneStaking.sol";
import {IHexOnePriceFeed} from "../src/interfaces/IHexOnePriceFeed.sol";
import {IHexOneVault} from "../src/interfaces/IHexOneVault.sol";

import {IPulseXPair} from "../src/interfaces/pulsex/IPulseXPair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Base is Test {
    HexOneToken public hex1;
    HexitToken public hexit;
    HexOneStaking public staking;
    HexOnePriceFeed public feed;
    HexOneVault public vault;
    address public bootstrap = makeAddr("HexOneBootstrap"); // TODO: address is being mocked, change later

    IPulseXPair public pair = IPulseXPair(0x6F1747370B1CAcb911ad6D4477b718633DB328c8);
    address public hexToken = 0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39;
    address public dai = 0xefD766cCb38EaF1dfd701853BFCe31359239F305;

    function setUp() public {
        hex1 = new HexOneToken("Hex One Token", "HEX1");
        hexit = new HexitToken("Hexit Token", "HEXIT");
        staking = new HexOneStaking(hexToken, address(hexit), 10, 10); // TODO: config, enable staking
        feed = new HexOnePriceFeed(address(pair));
        vault = new HexOneVault(hexToken, address(hex1), address(feed));

        hex1.setHexOneVault(address(vault));
        hexit.setHexOneBootstrap(bootstrap);
        staking.setBaseData(address(vault), bootstrap); // TODO: refactor to use vault instead of protocol
    }
}
