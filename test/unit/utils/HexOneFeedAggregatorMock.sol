// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {IHexOnePriceFeed} from "../../../src/interfaces/IHexOnePriceFeed.sol";

contract HexOneFeedAggregatorMock {
    address public hexOnePriceFeed;
    address public hexToken;
    address public daiToken;

    constructor(address _hexOnePriceFeed, address _hexToken, address _daiToken) {
        hexOnePriceFeed = _hexOnePriceFeed;
        hexToken = _hexToken;
        daiToken = _daiToken;
    }

    function computeHexPrice(uint256 _amountIn) external returns (uint256) {
        try IHexOnePriceFeed(hexOnePriceFeed).consult(hexToken, _amountIn, daiToken) returns (uint256 amountOut) {
            if (amountOut == 0) revert();
            return amountOut;
        } catch (bytes memory reason) {
            bytes4 err = bytes4(reason);
            if (err == IHexOnePriceFeed.PriceTooStale.selector) {
                IHexOnePriceFeed(hexOnePriceFeed).update(hexToken, daiToken);
                return IHexOnePriceFeed(hexOnePriceFeed).consult(hexToken, _amountIn, daiToken);
            } else {
                revert();
            }
        } catch Error(string memory) {
            revert();
        } catch Panic(uint256) {
            revert();
        }
    }
}
