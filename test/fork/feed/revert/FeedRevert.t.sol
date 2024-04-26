// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../Base.t.sol";

contract FeedRevert is Base {
    function test_addPath_revert_InvalidPath() external prank(owner) {
        address[] memory path = new address[](1);
        path[0] = HEX_TOKEN;

        vm.expectRevert(IHexOnePriceFeed.InvalidPath.selector);
        feed.addPath(path);
    }

    function test_addPath_revert_PathAlreadyRegistered() external prank(owner) {
        address[] memory path = new address[](3);
        path[0] = HEX_TOKEN;
        path[1] = WPLS_TOKEN;
        path[2] = DAI_TOKEN;

        vm.expectRevert(IHexOnePriceFeed.PathAlreadyRegistered.selector);
        feed.addPath(path);
    }

    function test_addPath_revert_InvalidPair() external prank(owner) {
        address[] memory path = new address[](3);
        path[0] = HEX_TOKEN;
        path[1] = WPLS_TOKEN;
        path[2] = address(new ERC20Mock("ERC20 MOCK TOKEN", "MOCK"));

        vm.expectRevert();
        feed.addPath(path);
    }

    function test_addPath_revert_EmptyReserves() external prank(owner) {
        ERC20Mock mock = new ERC20Mock("ERC20 MOCK TOKEN", "MOCK");

        IPulseXFactory(PULSEX_FACTORY_V1).createPair(address(HEX_TOKEN), address(mock));

        address[] memory path = new address[](2);
        path[0] = HEX_TOKEN;
        path[1] = address(mock);

        vm.expectRevert(IHexOnePriceFeed.EmptyReserves.selector);
        feed.addPath(path);
    }

    function test_changePeriod_revert_InvalidPeriod_lessThanMin(uint256 _period) external prank(owner) {
        vm.assume(_period < feed.MIN_PERIOD());

        vm.expectRevert(IHexOnePriceFeed.InvalidPeriod.selector);
        feed.changePeriod(_period);
    }

    function test_changePeriod_revert_InvalidPeriod_moreThanMax(uint256 _period) external prank(owner) {
        vm.assume(_period > feed.MAX_PERIOD());

        vm.expectRevert(IHexOnePriceFeed.InvalidPeriod.selector);
        feed.changePeriod(_period);
    }

    function test_quote_revert_InvalidPath(uint256 _amountIn) external {
        vm.expectRevert(IHexOnePriceFeed.InvalidPath.selector);
        feed.quote(DAI_TOKEN, _amountIn, HEX_TOKEN);
    }

    function test_quote_revert_PriceStale() external {
        skip(feed.period());

        vm.expectRevert(IHexOnePriceFeed.PriceStale.selector);
        feed.quote(HEX_TOKEN, 1e8, DAI_TOKEN);
    }
}
