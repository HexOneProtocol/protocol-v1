// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IPulseXPair} from "../interfaces/pulsex/IPulseXPair.sol";
import {FixedPoint} from "../libraries/FixedPoint.sol";

library UniswapV2OracleLibrary {
    using FixedPoint for *;

    function currentBlockTimestamp() internal view returns (uint32 timestamp) {
        unchecked {
            timestamp = uint32(block.timestamp % 2 ** 32);
        }
    }

    function currentCumulativePrices(address pair)
        internal
        view
        returns (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp)
    {
        blockTimestamp = currentBlockTimestamp();
        price0Cumulative = IPulseXPair(pair).price0CumulativeLast();
        price1Cumulative = IPulseXPair(pair).price1CumulativeLast();

        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = IPulseXPair(pair).getReserves();
        if (blockTimestampLast != blockTimestamp) {
            unchecked {
                uint32 timeElapsed = blockTimestamp - blockTimestampLast;
                price0Cumulative += uint256(FixedPoint.fraction(reserve1, reserve0)._x) * timeElapsed;
                price1Cumulative += uint256(FixedPoint.fraction(reserve0, reserve1)._x) * timeElapsed;
            }
        }
    }
}
