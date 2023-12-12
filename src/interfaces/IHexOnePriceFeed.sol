// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

interface IHexOnePriceFeed {
    function update() external;
    function consult(address token, uint256 amountIn) external view returns (uint256 amountOut);
}
