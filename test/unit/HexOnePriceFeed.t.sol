// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {HexOnePriceFeed} from "../../src/HexOnePriceFeed.sol";
import {IPulseXPair} from "../../src/interfaces/pulsex/IPulseXPair.sol";
import {FixedPoint} from "../../src/libraries/FixedPoint.sol";

/**
 *  @dev forge test --match-contract HexOnePriceFeedTest --rpc-url "https://rpc.pulsechain.com" -vvv
 */
contract HexOnePriceFeedTest is Test {
    HexOnePriceFeed public hexOnePriceFeed;
    IPulseXPair public pair = IPulseXPair(0x6F1747370B1CAcb911ad6D4477b718633DB328c8);
    address public hexToken = 0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39;
    address public daiToken = 0xefD766cCb38EaF1dfd701853BFCe31359239F305;

    function setUp() public {
        hexOnePriceFeed = new HexOnePriceFeed(address(pair));
        assertEq(pair.token0(), hexToken);
        assertEq(pair.token1(), daiToken);

        skip(6 hours);

        hexOnePriceFeed.update();
    }

    function test_consultHexPrice() public {
        skip(6 hours);

        hexOnePriceFeed.update();

        console2.log("HEX price in DAI: ", hexOnePriceFeed.consult(hexToken, 1e8));
    }

    function test_consultDaiPrice() public {
        skip(6 hours);

        hexOnePriceFeed.update();

        console2.log("DAI price in HEX: ", hexOnePriceFeed.consult(daiToken, 1e18));
    }

    function test_consultHexPriceWhenStale() public {
        skip(6 hours);

        uint256 hexPrice;
        try hexOnePriceFeed.consult(hexToken, 1e8) returns (uint256 amountOut) {
            hexPrice = amountOut;
        } catch Error(string memory) {
            hexOnePriceFeed.update();
            hexPrice = hexOnePriceFeed.consult(hexToken, 1e8);
        }

        console2.log("HEX price in DAI: ", hexPrice);
    }
}
