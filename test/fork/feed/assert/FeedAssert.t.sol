// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../Base.t.sol";

contract FeedAssert is Base {
    function test_addPath() external prank(owner) {
        address[] memory path = new address[](3);
        path[0] = USDT_TOKEN;
        path[1] = WPLS_TOKEN;
        path[2] = DAI_TOKEN;

        feed.addPath(path);

        assertEq(feed.getPath(USDT_TOKEN, DAI_TOKEN), path);
    }

    function test_addPath_withAlreadyAddedPair() external prank(owner) {
        address[] memory firstPath = new address[](3);
        firstPath[0] = USDT_TOKEN;
        firstPath[1] = WPLS_TOKEN;
        firstPath[2] = DAI_TOKEN;

        feed.addPath(firstPath);

        assertEq(feed.getPath(USDT_TOKEN, DAI_TOKEN), firstPath);

        address[] memory secondPath = new address[](3);
        secondPath[0] = USDC_TOKEN;
        secondPath[1] = PLSX_TOKEN;
        secondPath[2] = DAI_TOKEN;

        feed.addPath(secondPath);

        assertEq(feed.getPath(USDC_TOKEN, DAI_TOKEN), secondPath);
    }

    function test_changePeriod(uint256 _period) external prank(owner) {
        _period = uint128(bound(_period, feed.MIN_PERIOD(), feed.MAX_PERIOD()));

        feed.changePeriod(_period);

        assertEq(feed.period(), _period);
    }

    function test_update() external {
        feed.update();
    }

    function test_quote() external {
        skip(feed.period());
        feed.update();
        feed.quote(HEX_TOKEN, 1e8, DAI_TOKEN);
        feed.quote(HEX_TOKEN, 1e8, USDT_TOKEN);
        feed.quote(HEX_TOKEN, 1e8, USDC_TOKEN);
    }

    function test_getPath() external {
        address[] memory path = feed.getPath(HEX_TOKEN, DAI_TOKEN);
        assertEq(path[0], HEX_TOKEN);
        assertEq(path[1], WPLS_TOKEN);
        assertEq(path[2], DAI_TOKEN);
    }

    function test_getPairs() external {
        address[] memory pairs = feed.getPairs();
        assertTrue(pairs.length > 0);
    }
}
