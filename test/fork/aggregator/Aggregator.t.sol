// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import "../Base.t.sol";

/**
 *  @dev forge test --match-contract AggregatorTest -vvv
 */
contract AggregatorTest is Base {
    /*//////////////////////////////////////////////////////////////////////////
                                    DEPLOYMENT
    //////////////////////////////////////////////////////////////////////////*/

    function test_deployment() public {
        assertEq(aggregator.hexOnePriceFeed(), address(feed));
        assertEq(aggregator.hexToken(), hexToken);
        assertEq(aggregator.daiToken(), daiToken);
        assertEq(aggregator.wplsToken(), wplsToken);
        assertEq(aggregator.usdcToken(), usdcToken);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                COMPUTE HEX PRICE
    //////////////////////////////////////////////////////////////////////////*/

    function test_computeHexPrice() public {
        uint256 amountOut = aggregator.computeHexPrice(1e8);
        console.log("HEX/USD mean price: ", amountOut);
    }
}
