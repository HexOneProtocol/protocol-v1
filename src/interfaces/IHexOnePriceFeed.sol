// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import {FixedPoint} from "../libraries/FixedPoint.sol";

interface IHexOnePriceFeed {
    struct Observation {
        uint32 blockTimestampLast;
        uint256 price0CumulativeLast;
        uint256 price1CumulativeLast;
    }

    struct Price {
        FixedPoint.uq112x112 price0;
        FixedPoint.uq112x112 price1;
    }

    event PeriodChanged(uint256 period);
    event PathAdded(address[] path);
    event PairAdded(address pair);
    event PricesUpdated(uint256 timestamp);

    error InvalidPath();
    error InvalidPair();
    error EmptyReserves();
    error PathAlreadyRegistered();
    error InvalidPeriod();
    error ZeroAddress();
    error PriceStale();
    error PricesUpToDate();

    function addPath(address[] memory _path) external;
    function changePeriod(uint256 _period) external;
    function update() external;
    function quote(address tokenIn, uint256 amountIn, address tokenOut) external view returns (uint256);
    function getPath(address _tokenIn, address _tokenOut) external view returns (address[] memory);
    function getPairs() external view returns (address[] memory);
}
