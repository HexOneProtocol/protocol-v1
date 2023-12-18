// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {HexOneVault} from "../../src/HexOneVault.sol";
import {HexOnePriceFeed} from "../../src/HexOnePriceFeed.sol";
import {IPulseXPair} from "../../src/interfaces/pulsex/IPulseXPair.sol";

/**
 *  @dev forge test --match-contract HexOneVaultTest --rpc-url "https://rpc.pulsechain.com" -vvv
 */
contract HexOneVaultTest is Test {
    HexOneVault public hexOneVault;
    HexOnePriceFeed public hexOnePriceFeed;
    address public hexOneProtocol = makeAddr("HexOneProtocol");

    IPulseXPair public pair = IPulseXPair(0x6F1747370B1CAcb911ad6D4477b718633DB328c8);
    address public hexToken = 0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39;

    function setUp() public {
        hexOnePriceFeed = new HexOnePriceFeed(address(pair));
        hexOneVault = new HexOneVault(address(hexOnePriceFeed), hexToken);
    }
}
