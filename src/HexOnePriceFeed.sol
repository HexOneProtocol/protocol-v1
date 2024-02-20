// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {UniswapV2OracleLibrary} from "./libraries/UniswapV2OracleLibrary.sol";
import {UniswapV2Library} from "./libraries/UniswapV2Library.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {FixedPoint} from "./libraries/FixedPoint.sol";

import {IHexOnePriceFeed} from "./interfaces/IHexOnePriceFeed.sol";
import {IPulseXPair} from "./interfaces/pulsex/IPulseXPair.sol";

/// @title HexOnePriceFeed
/// @notice fetches the price of the PulseX pairs.
/// @dev supported pairs: HEX/DAI, PLSX/DAI and WPLS/DAI.
contract HexOnePriceFeed is IHexOnePriceFeed {
    using FixedPoint for *;
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @dev stores the observed values at a specific timestamp.
    struct Observation {
        uint32 blockTimestampLast;
        uint256 price0CumulativeLast;
        uint256 price1CumulativeLast;
    }

    /// @dev represents the average price within a specific time frame.
    struct PriceAverage {
        FixedPoint.uq112x112 price0Average;
        FixedPoint.uq112x112 price1Average;
    }

    /// @dev pairs supported by the oracle.
    EnumerableSet.AddressSet private pairTokens;

    /// @dev period in which the oracle becomes stale.
    uint256 public constant PERIOD = 2000;

    /// @dev address of the pulsex factory.
    address public immutable factory;
    /// @dev stores the last observed cumulative prices of each token pair.
    mapping(address => Observation) public pairLastObservation;
    /// @dev stores the average price of each token between the last two observations.
    mapping(address => PriceAverage) public pairPriceAverage;

    /// @param _factory address of the pulsex factory.
    /// @param _pairs address of the supported pairs in the feed.
    constructor(address _factory, address[] memory _pairs) {
        if (_pairs.length == 0) revert InvalidNumberOfPairs(_pairs.length);
        if (_factory == address(0)) revert InvalidFactory(_factory);

        for (uint256 i; i < _pairs.length; i++) {
            // check if pair was already added
            address pair = _pairs[i];
            if (pairTokens.contains(pair)) revert PairAlreadyAdded(pair);

            // get the reserves of the pair and the last time the reserves were updated
            IPulseXPair pulseXPair = IPulseXPair(pair);
            (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = pulseXPair.getReserves();

            // check if pair has reserves
            if (reserve0 == 0) revert EmptyReserveZero(pair);
            if (reserve1 == 0) revert EmptyReserveOne(pair);

            // add pair contract to allowed pair tokens
            pairTokens.add(pair);

            // update the last observation made for this pair
            Observation storage observation = pairLastObservation[pair];
            observation.blockTimestampLast = blockTimestampLast;
            observation.price0CumulativeLast = pulseXPair.price0CumulativeLast();
            observation.price1CumulativeLast = pulseXPair.price1CumulativeLast();

            // update the initial price average of the pair
            PriceAverage storage priceAverage = pairPriceAverage[pair];
            priceAverage.price0Average = FixedPoint.uq112x112(FixedPoint.fraction(reserve1, reserve0)._x);
            priceAverage.price1Average = FixedPoint.uq112x112(FixedPoint.fraction(reserve1, reserve0)._x);
        }

        factory = _factory;
    }

    /// @dev updates the average price of both tokens of the pair.
    /// @notice the average price can not be updated if the time elapsed since the last
    /// update is less than `PERIOD`.
    /// @param _tokenA address of the token we want a quote from.
    /// @param _tokenB address of the token we are receiving the price in.
    function update(address _tokenA, address _tokenB) external {
        // check if the tokens being passed correspond to a supported pair
        address pair = UniswapV2Library.pairFor(factory, _tokenA, _tokenB);
        if (!pairTokens.contains(pair)) revert InvalidPair(pair);

        // get updated information about cumulative prices and last time updated
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) =
            UniswapV2OracleLibrary.currentCumulativePrices(pair);

        // calculate how much time has passed since the pair was last updated
        uint32 timeElapsed;
        unchecked {
            timeElapsed = blockTimestamp - pairLastObservation[pair].blockTimestampLast;
        }

        // if the pair has already been updated in the last 2 hours revert
        if (timeElapsed < PERIOD) revert PeriodNotElapsed(pair);

        // compute the new price average since the price was last updated
        PriceAverage storage priceAverage = pairPriceAverage[pair];
        unchecked {
            priceAverage.price0Average = FixedPoint.uq112x112(
                uint224((price0Cumulative - pairLastObservation[pair].price0CumulativeLast) / timeElapsed)
            );
            priceAverage.price1Average = FixedPoint.uq112x112(
                uint224((price1Cumulative - pairLastObservation[pair].price1CumulativeLast) / timeElapsed)
            );
        }

        // update the last pair observation with the newly fetched cumulative prices and timestamp
        Observation storage observation = pairLastObservation[pair];
        observation.blockTimestampLast = blockTimestamp;
        observation.price0CumulativeLast = price0Cumulative;
        observation.price1CumulativeLast = price1Cumulative;

        emit PriceUpdated(pair);
    }

    /// @dev consult the price of a token.
    /// @notice if price has not been updated for `PERIOD` the price is considered stale.
    /// @param _tokenIn address of the token we want a quote from.
    /// @param _amountIn amount of tokenIn to calculate the amountOut based on price.
    /// @param _tokenOut address of the token we are receiving the price in.
    function consult(address _tokenIn, uint256 _amountIn, address _tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        // check if the tokens being passed correspond to a supported pair
        address pair = UniswapV2Library.pairFor(factory, _tokenIn, _tokenOut);
        if (!pairTokens.contains(pair)) revert InvalidPair(pair);

        // check how much time has elapsed since the price was last updated
        uint256 timeElapsed = block.timestamp - pairLastObservation[pair].blockTimestampLast;

        // if the price was not updated for PERIOD then the transaction should revert
        if (timeElapsed >= PERIOD) revert PriceTooStale();

        // compute the amount out
        (address token0,) = UniswapV2Library.sortTokens(_tokenIn, _tokenOut);
        if (token0 == _tokenIn) {
            amountOut = pairPriceAverage[pair].price0Average.mul(_amountIn).decode144();
        } else {
            amountOut = pairPriceAverage[pair].price1Average.mul(_amountIn).decode144();
        }
    }
}
