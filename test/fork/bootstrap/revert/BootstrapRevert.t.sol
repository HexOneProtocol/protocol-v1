// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../Base.t.sol";

contract BootstrapRevert is Base {
    function setUp() public virtual override {
        super.setUp();

        skip(feed.period());
        feed.update();
    }

    function test_sacrificeDay_revert_SacrificeInactive() external {
        skip(30 days);

        vm.expectRevert(IHexOneBootstrap.SacrificeInactive.selector);
        bootstrap.sacrificeDay();
    }

    function test_sacrifice_revert_TokenNotSupported() external {
        address token = makeAddr("mock token");

        vm.expectRevert(IHexOneBootstrap.TokenNotSupported.selector);
        bootstrap.sacrifice(token, 1, 0);
    }

    function test_sacrifice_revert_InvalidAmount() external {
        vm.expectRevert(IHexOneBootstrap.InvalidAmount.selector);
        bootstrap.sacrifice(HEX_TOKEN, 0, 0);
    }

    function test_sacrifice_revert_SacrificeInactive() external {
        skip(30 days);

        vm.expectRevert(IHexOneBootstrap.SacrificeInactive.selector);
        bootstrap.sacrifice(HEX_TOKEN, 1, 0);
    }

    function test_sacrifice_revert_SacrificedAmountTooLow() external {
        vm.expectRevert(IHexOneBootstrap.SacrificedAmountTooLow.selector);
        bootstrap.sacrifice(HEX_TOKEN, 1000, 0);
    }

    function test_sacrifice_revert_InvalidAmountOutMin() external {
        deal(WPLS_TOKEN, address(this), 100_000e18);

        IERC20(WPLS_TOKEN).approve(address(bootstrap), 100_000e18);

        vm.expectRevert(IHexOneBootstrap.InvalidAmountOutMin.selector);
        bootstrap.sacrifice(WPLS_TOKEN, 100_000e18, 0);
    }

    function test_processSacrifice_revert_AccessControlUnauthorizedAccount() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), bootstrap.OWNER_ROLE()
            )
        );
        bootstrap.processSacrifice(0);
    }

    function test_processSacrifice_revert_InvalidAmountOutMin() external {
        vm.startPrank(owner);

        vm.expectRevert(IHexOneBootstrap.InvalidAmountOutMin.selector);
        bootstrap.processSacrifice(0);

        vm.stopPrank();
    }

    function test_processSacrifice_revert_SacrificeActive() external {
        vm.startPrank(owner);

        vm.expectRevert(IHexOneBootstrap.SacrificeActive.selector);
        bootstrap.processSacrifice(1);

        vm.stopPrank();
    }

    function test_processSacrifice_revert_SacrificeAlreadyProcessed() external {
        deal(HEX_TOKEN, address(this), 10_000e8);

        IERC20(HEX_TOKEN).approve(address(bootstrap), 10_000e8);
        bootstrap.sacrifice(HEX_TOKEN, 10_000e8, 0);

        skip(30 days);

        feed.update();

        vm.startPrank(owner);

        bootstrap.processSacrifice(1);

        vm.expectRevert(IHexOneBootstrap.SacrificeAlreadyProcessed.selector);
        bootstrap.processSacrifice(1);

        vm.stopPrank();
    }

    function test_claimSacrifice_revert_SacrificeNotProcessed() external {
        vm.expectRevert(IHexOneBootstrap.SacrificeNotProcessed.selector);
        bootstrap.claimSacrifice();
    }

    function test_claimSacrifice_revert_SacrificeClaimInactive() external {
        deal(HEX_TOKEN, address(this), 10_000e8);

        IERC20(HEX_TOKEN).approve(address(bootstrap), 10_000e8);
        bootstrap.sacrifice(HEX_TOKEN, 10_000e8, 0);

        skip(30 days);

        feed.update();

        uint256 hexToSwap = (10_000e8 * 1250) / 10_000;

        address[] memory path = new address[](2);
        path[0] = HEX_TOKEN;
        path[1] = DAI_TOKEN;
        uint256[] memory amountsOut = IPulseXRouter(PULSEX_ROUTER_V1).getAmountsOut(hexToSwap, path);

        vm.startPrank(owner);

        bootstrap.processSacrifice(amountsOut[1]);

        vm.stopPrank();

        skip(15 days);

        feed.update();

        vm.expectRevert(IHexOneBootstrap.SacrificeClaimInactive.selector);
        bootstrap.claimSacrifice();
    }

    function test_claimSacrifice_revert_DidNotParticipateInSacrifice() external {
        deal(HEX_TOKEN, address(this), 10_000e8);

        IERC20(HEX_TOKEN).approve(address(bootstrap), 10_000e8);
        bootstrap.sacrifice(HEX_TOKEN, 10_000e8, 0);

        skip(30 days);

        feed.update();

        uint256 hexToSwap = (10_000e8 * 1250) / 10_000;

        address[] memory path = new address[](2);
        path[0] = HEX_TOKEN;
        path[1] = DAI_TOKEN;
        uint256[] memory amountsOut = IPulseXRouter(PULSEX_ROUTER_V1).getAmountsOut(hexToSwap, path);

        vm.startPrank(owner);

        bootstrap.processSacrifice(amountsOut[1]);

        vm.stopPrank();

        address user = makeAddr("random user");
        vm.startPrank(user);

        vm.expectRevert(IHexOneBootstrap.DidNotParticipateInSacrifice.selector);
        bootstrap.claimSacrifice();

        vm.stopPrank();
    }

    function test_claimSacrifice_revert_SacrificeAlreadyClaimed() external {
        deal(HEX_TOKEN, address(this), 10_000e8);

        IERC20(HEX_TOKEN).approve(address(bootstrap), 10_000e8);
        bootstrap.sacrifice(HEX_TOKEN, 10_000e8, 0);

        skip(30 days);

        feed.update();

        uint256 hexToSwap = (10_000e8 * 1250) / 10_000;

        address[] memory path = new address[](2);
        path[0] = HEX_TOKEN;
        path[1] = DAI_TOKEN;
        uint256[] memory amountsOut = IPulseXRouter(PULSEX_ROUTER_V1).getAmountsOut(hexToSwap, path);

        vm.startPrank(owner);

        bootstrap.processSacrifice(amountsOut[1]);

        vm.stopPrank();

        bootstrap.claimSacrifice();

        vm.expectRevert(IHexOneBootstrap.SacrificeAlreadyClaimed.selector);
        bootstrap.claimSacrifice();
    }

    function test_startAirdrop_revert_AccessControlUnauthorizedAccount() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), bootstrap.OWNER_ROLE()
            )
        );
        bootstrap.processSacrifice(0);
    }

    function test_startAirdrop_revert_InvalidTimestamp() external prank(owner) {
        vm.expectRevert(IHexOneBootstrap.InvalidTimestamp.selector);
        bootstrap.startAirdrop(uint64(block.timestamp - 100));
    }

    function test_startAirdrop_revert_AirdropAlreadyStarted() external {
        deal(HEX_TOKEN, address(this), 10_000e8);

        IERC20(HEX_TOKEN).approve(address(bootstrap), 10_000e8);
        bootstrap.sacrifice(HEX_TOKEN, 10_000e8, 0);

        skip(30 days);

        feed.update();

        uint256 hexToSwap = (10_000e8 * 1250) / 10_000;

        address[] memory path = new address[](2);
        path[0] = HEX_TOKEN;
        path[1] = DAI_TOKEN;
        uint256[] memory amountsOut = IPulseXRouter(PULSEX_ROUTER_V1).getAmountsOut(hexToSwap, path);

        vm.startPrank(owner);

        bootstrap.processSacrifice(amountsOut[1]);

        vm.stopPrank();

        bootstrap.claimSacrifice();

        skip(7 days);

        feed.update();

        vm.startPrank(owner);
        bootstrap.startAirdrop(uint64(block.timestamp + 100));

        vm.expectRevert(IHexOneBootstrap.AirdropAlreadyStarted.selector);
        bootstrap.startAirdrop(uint64(block.timestamp + 100));
        vm.stopPrank();
    }

    function test_claimAirdrop_revert_AirdropInactive() external {
        vm.expectRevert(IHexOneBootstrap.AirdropInactive.selector);
        bootstrap.claimAirdrop();
    }

    function test_claimAirdrop_revert_AirdropAlreadyClaimed() external {
        deal(HEX_TOKEN, address(this), 10_000e8);

        IERC20(HEX_TOKEN).approve(address(bootstrap), 10_000e8);
        bootstrap.sacrifice(HEX_TOKEN, 10_000e8, 0);

        skip(30 days);

        feed.update();

        uint256 hexToSwap = (10_000e8 * 1250) / 10_000;

        address[] memory path = new address[](2);
        path[0] = HEX_TOKEN;
        path[1] = DAI_TOKEN;
        uint256[] memory amountsOut = IPulseXRouter(PULSEX_ROUTER_V1).getAmountsOut(hexToSwap, path);

        vm.startPrank(owner);

        bootstrap.processSacrifice(amountsOut[1]);

        vm.stopPrank();

        bootstrap.claimSacrifice();

        skip(7 days);

        feed.update();

        vm.startPrank(owner);
        bootstrap.startAirdrop(uint64(block.timestamp));
        vm.stopPrank();

        bootstrap.claimAirdrop();

        vm.expectRevert(IHexOneBootstrap.AirdropAlreadyClaimed.selector);
        bootstrap.claimAirdrop();
    }

    function test_claimAirdrop_revert_IneligibleForAirdrop() external {
        deal(HEX_TOKEN, address(this), 10_000e8);

        IERC20(HEX_TOKEN).approve(address(bootstrap), 10_000e8);
        bootstrap.sacrifice(HEX_TOKEN, 10_000e8, 0);

        skip(30 days);

        feed.update();

        uint256 hexToSwap = (10_000e8 * 1250) / 10_000;

        address[] memory path = new address[](2);
        path[0] = HEX_TOKEN;
        path[1] = DAI_TOKEN;
        uint256[] memory amountsOut = IPulseXRouter(PULSEX_ROUTER_V1).getAmountsOut(hexToSwap, path);

        vm.startPrank(owner);

        bootstrap.processSacrifice(amountsOut[1]);

        vm.stopPrank();

        bootstrap.claimSacrifice();

        skip(7 days);

        feed.update();

        vm.startPrank(owner);
        bootstrap.startAirdrop(uint64(block.timestamp));
        vm.stopPrank();

        address randomUser = makeAddr("random user");
        vm.startPrank(randomUser);
        vm.expectRevert(IHexOneBootstrap.IneligibleForAirdrop.selector);
        bootstrap.claimAirdrop();
        vm.stopPrank();
    }
}
