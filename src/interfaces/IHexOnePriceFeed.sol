// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

interface IHexOnePriceFeed {
    event PriceUpdated(uint256 price0Average, uint256 price1Average, uint256 blockTimestampLast);

    function update() external;
    function consult(address tokenIn, uint256 amountIn) external view returns (uint256 amountOut);
}
