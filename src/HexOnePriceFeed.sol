// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {UniswapV2OracleLibrary} from "./libraries/UniswapV2OracleLibrary.sol";
import {FixedPoint} from "./libraries/FixedPoint.sol";
import {IPulseXPair} from "./interfaces/pulsex/IPulseXPair.sol";

import {console2} from "forge-std/Test.sol";

contract HexOnePriceFeed {
    using FixedPoint for *;

    uint256 public constant PERIOD = 6 hours;

    IPulseXPair public immutable pair;
    address public immutable token0;
    address public immutable token1;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint32 public blockTimestampLast;
    FixedPoint.uq112x112 public price0Average;
    FixedPoint.uq112x112 public price1Average;

    constructor(address _pair) {
        IPulseXPair pulseXPair = IPulseXPair(_pair);

        pair = pulseXPair;
        token0 = pulseXPair.token0();
        token1 = pulseXPair.token1();

        price0CumulativeLast = pulseXPair.price0CumulativeLast();
        price1CumulativeLast = pulseXPair.price1CumulativeLast();

        uint112 reserve0;
        uint112 reserve1;
        (reserve0, reserve1, blockTimestampLast) = pulseXPair.getReserves();
        require(reserve0 != 0 && reserve1 != 0, "No reserves");
    }

    function update() external {
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) =
            UniswapV2OracleLibrary.currentCumulativePrices(address(pair));
        
        uint32 timeElapsed;
        unchecked {
            timeElapsed = blockTimestamp - blockTimestampLast;
        }

        require(timeElapsed >= PERIOD, "Period not elapsed");

        unchecked {
            price0Average = FixedPoint.uq112x112(uint224((price0Cumulative - price0CumulativeLast) / timeElapsed));
            price1Average = FixedPoint.uq112x112(uint224((price1Cumulative - price1CumulativeLast) / timeElapsed));           
        }

        price0CumulativeLast = price0Cumulative;
        price1CumulativeLast = price1Cumulative;
        blockTimestampLast = blockTimestamp;
    }

    function consult(address token, uint256 amountIn) external view returns (uint256 amountOut) {
        uint256 timeElapsed = block.timestamp - blockTimestampLast;
        require(timeElapsed < PERIOD, "Price too stale");
        
        if (token == token0) {
            amountOut = price0Average.mul(amountIn).decode144();
        } else {
            require(token == token1, "Invalid token");            
            amountOut = price1Average.mul(amountIn).decode144();
        }
    }
}