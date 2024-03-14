// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

interface IHexOneFeedAggregator {
    error InvalidQuote(uint256 quote);
    error PriceConsultationFailedBytes(bytes revertData);
    error PriceConsultationFailedString(string revertReason);

    function computeHexPrice(uint256 _hexAmountIn) external returns (uint256 hexAmountOut);
}
