// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

interface IHexOnePriceFeed {
    function getBaseTokenPrice(
        address _baseToken,
        uint256 _amount
    ) external view returns (uint256);

    function getHexTokenPrice(uint256 _amount) external view returns (uint256);
}
