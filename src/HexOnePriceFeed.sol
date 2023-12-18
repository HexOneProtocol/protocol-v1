// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {IHexOnePriceFeed} from "./interfaces/IHexOnePriceFeed.sol";
import {UniswapV2OracleLibrary} from "./libraries/UniswapV2OracleLibrary.sol";
import {FixedPoint} from "./libraries/FixedPoint.sol";
import {IPulseXPair} from "./interfaces/pulsex/IPulseXPair.sol";

/// @title HexOnePriceFeed
/// @notice Fetches the price of the HEX/DAI pair from PulseX V1.
contract HexOnePriceFeed is IHexOnePriceFeed {
    using FixedPoint for *;

    /// @notice period in which the oracle becomes stale.
    uint256 public constant PERIOD = 2 hours;
    /// @notice HEX scale factor
    uint256 public constant HEX_FACTOR = 1e8;
    /// @notice DAI scale factor
    uint256 public constant DAI_FACTOR = 1e18;

    /// @notice HEX/DAI token pair
    IPulseXPair public immutable pair;
    /// @notice HEX token address
    address public immutable token0;
    /// @notice DAI token address
    address public immutable token1;

    /// @notice last token0 cumulative price snapshot.
    uint256 public price0CumulativeLast;
    /// @notice last token1 cumulative price snapshot.
    uint256 public price1CumulativeLast;
    /// @notice last time a snapshot of cumulative prices was made.
    uint32 public blockTimestampLast;
    /// @notice current token0 price average.
    FixedPoint.uq112x112 public price0Average;
    /// @notice current token0 price average.
    FixedPoint.uq112x112 public price1Average;

    /// @param _pair address of the HEX/DAI pair.
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
        if (reserve0 == 0 || reserve1 == 0) revert EmptyReserves();
    }

    /// @notice updates the average price of both pair tokens.
    function update() external {
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) =
            UniswapV2OracleLibrary.currentCumulativePrices(address(pair));

        uint32 timeElapsed;
        unchecked {
            timeElapsed = blockTimestamp - blockTimestampLast;
        }

        if (timeElapsed < PERIOD) revert PeriodNotElapsed();

        unchecked {
            price0Average = FixedPoint.uq112x112(uint224((price0Cumulative - price0CumulativeLast) / timeElapsed));
            price1Average = FixedPoint.uq112x112(uint224((price1Cumulative - price1CumulativeLast) / timeElapsed));
        }

        price0CumulativeLast = price0Cumulative;
        price1CumulativeLast = price1Cumulative;
        blockTimestampLast = blockTimestamp;

        emit PriceUpdated(
            price0Average.mul(HEX_FACTOR).decode144(), price1Average.mul(DAI_FACTOR).decode144(), blockTimestampLast
        );
    }

    /// @notice consult the price of a token in relation to the other token pair.
    /// @dev if price has not been updated for `PERIOD` the price is considered stale.
    /// @param _tokenIn address of the token we want a quote from.
    /// @param _amountIn amount of tokenIn to calculate the amountOut based on price.
    function consult(address _tokenIn, uint256 _amountIn) external view returns (uint256 amountOut) {
        uint256 timeElapsed = block.timestamp - blockTimestampLast;
        if (timeElapsed >= PERIOD) revert PriceTooStale();

        if (_tokenIn == token0) {
            amountOut = price0Average.mul(_amountIn).decode144();
        } else {
            if (_tokenIn != token1) revert InvalidToken();
            amountOut = price1Average.mul(_amountIn).decode144();
        }
    }
}
