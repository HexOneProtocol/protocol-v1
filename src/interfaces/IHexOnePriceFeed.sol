// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

interface IHexOnePriceFeed {
    event PriceUpdated(address pair);

    error EmptyReserveZero(address pair);
    error EmptyReserveOne(address pair);
    error InvalidFactory(address factory);
    error InvalidNumberOfPairs(uint256 numberOfPairs);
    error PeriodNotElapsed(address pair);
    error InvalidPair(address pair);
    error PriceTooStale();
    error PairAlreadyAdded(address pair);

    function update(address _tokenIn, address _tokenOut) external;
    function consult(address _tokenIn, uint256 _amountIn, address _tokenOut)
        external
        view
        returns (uint256 amountOut);
}
