// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

contract HexOnePriceFeedMock {
    /// @dev tokenIn => tokenOut => rate
    mapping(address => mapping(address => uint256)) rates;

    constructor() {}

    function setRate(address tokenIn, address tokenOut, uint256 rate) public {
        rates[tokenIn][tokenOut] = rate;
    }

    function getRate(address tokenIn, address tokenOut) public view returns (uint256) {
        return rates[tokenIn][tokenOut];
    }

    function update(address, address) external {}

    function consult(address tokenIn, uint256 amountIn, address tokenOut) external view returns (uint256 amountOut) {
        return amountIn * rates[tokenIn][tokenOut] / 1e18;
    }
}
