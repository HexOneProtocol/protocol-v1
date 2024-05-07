// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

contract PriceFeedMock {
    mapping(address => mapping(address => uint256)) prices;

    function setPrice(address tokenIn, address tokenOut, uint256 price) external {
        prices[tokenIn][tokenOut] = price;
    }

    function update() external {}

    function quote(address tokenIn, uint256 amountIn, address tokenOut) external view returns (uint256 amountOut) {
        return (prices[tokenIn][tokenOut] * amountIn) / 1e18;
    }
}
