// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import "../Base.t.sol";

/**
 *  @dev forge test --match-contract HexOnePriceFeedTest --rpc-url "https://rpc.pulsechain.com" -vvv
 */
contract HexOnePriceFeedTest is Base {
    function test_update() public {
        skip(feed.PERIOD());
        feed.update();
        assertEq(feed.price0Average() != 0, true);
        assertEq(feed.price1Average() != 0, true);
    }

    function test_update_revertIfPeriodNotElapsed() public {
        vm.expectRevert(IHexOnePriceFeed.PeriodNotElapsed.selector);
        feed.update();
    }

    function test_consult() public {
        skip(feed.PERIOD());
        feed.update();
        uint256 price = feed.consult(hexToken, 1e8);
        assertEq(price != 0, true);
    }

    function test_consult_beforeFirstUpdate() public {
        uint256 price = feed.consult(hexToken, 1e8);
        assertEq(price, 0);
    }

    function test_consult_revertIfPriceTooStale() public {
        skip(feed.PERIOD());
        vm.expectRevert(IHexOnePriceFeed.PriceTooStale.selector);
        feed.consult(hexToken, 1e8);
    }

    function test_consult_revertIfInvalidToken() public {
        skip(feed.PERIOD());
        feed.update();
        vm.expectRevert(IHexOnePriceFeed.InvalidToken.selector);
        feed.consult(makeAddr("MockToken"), 1e18);
    }
}
