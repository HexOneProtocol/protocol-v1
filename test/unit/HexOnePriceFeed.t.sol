// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {IHexOnePriceFeed} from "../../src/interfaces/IHexOnePriceFeed.sol";

/**
 *  @dev forge test --match-contract HexOnePriceFeedTest --rpc-url "https://rpc.pulsechain.com" -vvv
 */
contract HexOnePriceFeedTest is Test {
    address public hexOnePriceFeed;
    address public pair = 0x6F1747370B1CAcb911ad6D4477b718633DB328c8;
    address public hexToken = 0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39;
    address public daiToken = 0xefD766cCb38EaF1dfd701853BFCe31359239F305;

    function setUp() public {
        hexOnePriceFeed = deployCode("HexOnePriceFeed.sol", abi.encode(pair));
    }

    function test_consult() public {
        skip(6 hours);

        // update the pool for the first time
        (bool success,) = hexOnePriceFeed.call(abi.encodeWithSignature("update()"));
        require(success, "Update failed");

        // compute DAI amountOut for 1 HEX
        bytes memory args1 = abi.encode(hexToken, 1e8);
        (, bytes memory daiAmountOutData) = hexOnePriceFeed.call(abi.encodeWithSignature("consult()", args1));

        uint256 daiAmountOut = abi.decode(daiAmountOutData, (uint256));
        console2.log("DAI amountOut: ", daiAmountOut);

        // compute HEX amountOut for 1 DAI
        bytes memory args2 = abi.encode(daiToken, 1e6);
        (, bytes memory hexAmountOutData) = hexOnePriceFeed.call(abi.encodeWithSignature("consult()", args2));

        uint256 hexAmountOut = abi.decode(hexAmountOutData, (uint256));
        console2.log("HEX amountOut: ", hexAmountOut);
    }
}
