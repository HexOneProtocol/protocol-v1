// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPulseXFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    function createPair(address tokenA, address tokenB) external returns (address pair);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}
