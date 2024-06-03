// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../Base.t.sol";

contract BootstrapAssert is Base {
    address private constant TEAM_WALLET = 0x9f4b45c40A64E345A7222F0CE595503EcB6030A6;

    function setUp() public virtual override {
        super.setUp();

        skip(feed.period());
        feed.update();
    }

    function test_sacrificeDay() external {
        assertEq(bootstrap.sacrificeDay(), 1);

        skip(14 days);

        assertEq(bootstrap.sacrificeDay(), 15);

        skip(15 days);

        assertEq(bootstrap.sacrificeDay(), 30);
    }

    function test_initVault() external {
        address[] memory tokens = new address[](1);
        tokens[0] = WPLS_TOKEN;
        HexOneBootstrap newBootstrap =
            new HexOneBootstrap(uint64(block.timestamp), address(feed), address(hexit), tokens);

        newBootstrap.initVault(address(vault));

        assertEq(newBootstrap.vault(), address(vault));
        assertEq(newBootstrap.initialized(), true);
    }

    function test_sacrifice_hex_day1() external {
        deal(HEX_TOKEN, address(this), 10_000e8);

        IERC20(HEX_TOKEN).approve(address(bootstrap), 10_000e8);
        bootstrap.sacrifice(HEX_TOKEN, 10_000e8, 0);

        (uint256 sacrificedUsd, uint256 hexitShares, bool sacrificeClaimed, bool airdropClaimed) =
            bootstrap.userInfos(address(this));

        uint256 expectedSacrificedUsd = feed.quote(HEX_TOKEN, 10_000e8, DAI_TOKEN);
        assertEq(expectedSacrificedUsd, sacrificedUsd);

        uint256 expectedHexitShares = (expectedSacrificedUsd * 5_555_555 * 1e18) / 1e18;
        expectedHexitShares = (expectedHexitShares * 555) / 10_000;
        assertEq(expectedHexitShares, hexitShares);

        assertEq(sacrificeClaimed, false);
        assertEq(airdropClaimed, false);

        (uint256 totalSacrificedUsd, uint256 totalSacrificedHx, uint256 remainingHx, uint256 hexitMinted) =
            bootstrap.sacrificeInfo();

        assertEq(totalSacrificedUsd, expectedSacrificedUsd);
        assertEq(totalSacrificedHx, 10_000e8);
        assertEq(remainingHx, 0);
        assertEq(hexitMinted, 0);
    }

    function test_sacrifice_hex_day15() external {
        skip(14 days);

        feed.update();

        deal(HEX_TOKEN, address(this), 10_000e8);

        IERC20(HEX_TOKEN).approve(address(bootstrap), 10_000e8);
        bootstrap.sacrifice(HEX_TOKEN, 10_000e8, 0);

        (uint256 sacrificedUsd, uint256 hexitShares, bool sacrificeClaimed, bool airdropClaimed) =
            bootstrap.userInfos(address(this));

        uint256 expectedSacrificedUsd = feed.quote(HEX_TOKEN, 10_000e8, DAI_TOKEN);
        assertEq(expectedSacrificedUsd, sacrificedUsd);

        uint256 expectedHexitShares = (expectedSacrificedUsd * 4_826_360 * 1e18) / 1e18;
        expectedHexitShares = (expectedHexitShares * 555) / 10_000;
        assertApproxEqRel(expectedHexitShares, hexitShares, 1e15);

        assertEq(sacrificeClaimed, false);
        assertEq(airdropClaimed, false);

        (uint256 totalSacrificedUsd, uint256 totalSacrificedHx, uint256 remainingHx, uint256 hexitMinted) =
            bootstrap.sacrificeInfo();

        assertEq(totalSacrificedUsd, expectedSacrificedUsd);
        assertEq(totalSacrificedHx, 10_000e8);
        assertEq(remainingHx, 0);
        assertEq(hexitMinted, 0);
    }

    function test_sacrifice_hex_day30() external {
        skip(29 days);

        feed.update();

        deal(HEX_TOKEN, address(this), 10_000e8);

        IERC20(HEX_TOKEN).approve(address(bootstrap), 10_000e8);
        bootstrap.sacrifice(HEX_TOKEN, 10_000e8, 0);

        (uint256 sacrificedUsd, uint256 hexitShares, bool sacrificeClaimed, bool airdropClaimed) =
            bootstrap.userInfos(address(this));

        uint256 expectedSacrificedUsd = feed.quote(HEX_TOKEN, 10_000e8, DAI_TOKEN);
        assertEq(expectedSacrificedUsd, sacrificedUsd);

        uint256 expectedHexitShares = (expectedSacrificedUsd * 4_150_944 * 1e18) / 1e18;
        expectedHexitShares = (expectedHexitShares * 555) / 10_000;
        assertApproxEqRel(expectedHexitShares, hexitShares, 1e15);

        assertEq(sacrificeClaimed, false);
        assertEq(airdropClaimed, false);

        (uint256 totalSacrificedUsd, uint256 totalSacrificedHx, uint256 remainingHx, uint256 hexitMinted) =
            bootstrap.sacrificeInfo();

        assertEq(totalSacrificedUsd, expectedSacrificedUsd);
        assertEq(totalSacrificedHx, 10_000e8);
        assertEq(remainingHx, 0);
        assertEq(hexitMinted, 0);
    }

    function test_sacrifice_dai_day1() external {
        deal(DAI_TOKEN, address(this), 100e18);

        address[] memory path = new address[](2);
        path[0] = DAI_TOKEN;
        path[1] = HEX_TOKEN;
        uint256[] memory amountsOut = IPulseXRouter(PULSEX_ROUTER_V1).getAmountsOut(100e18, path);

        IERC20(DAI_TOKEN).approve(address(bootstrap), 100e18);
        bootstrap.sacrifice(DAI_TOKEN, 100e18, amountsOut[1]);

        (uint256 sacrificedUsd, uint256 hexitShares, bool sacrificeClaimed, bool airdropClaimed) =
            bootstrap.userInfos(address(this));

        assertEq(100e18, sacrificedUsd);

        uint256 expectedHexitShares = (100e18 * 5_555_555 * 1e18) / 1e18;
        expectedHexitShares = (expectedHexitShares * 555) / 10_000;
        assertEq(expectedHexitShares, hexitShares);

        assertEq(sacrificeClaimed, false);
        assertEq(airdropClaimed, false);

        (uint256 totalSacrificedUsd, uint256 totalSacrificedHx, uint256 remainingHx, uint256 hexitMinted) =
            bootstrap.sacrificeInfo();

        assertEq(totalSacrificedUsd, 100e18);
        assertEq(totalSacrificedHx, amountsOut[1]);
        assertEq(remainingHx, 0);
        assertEq(hexitMinted, 0);
    }

    function test_sacrifice_dai_day15() external {
        skip(14 days);

        feed.update();

        deal(DAI_TOKEN, address(this), 100e18);

        address[] memory path = new address[](2);
        path[0] = DAI_TOKEN;
        path[1] = HEX_TOKEN;
        uint256[] memory amountsOut = IPulseXRouter(PULSEX_ROUTER_V1).getAmountsOut(100e18, path);

        IERC20(DAI_TOKEN).approve(address(bootstrap), 100e18);
        bootstrap.sacrifice(DAI_TOKEN, 100e18, amountsOut[1]);

        (uint256 sacrificedUsd, uint256 hexitShares, bool sacrificeClaimed, bool airdropClaimed) =
            bootstrap.userInfos(address(this));

        assertEq(100e18, sacrificedUsd);

        uint256 expectedHexitShares = (100e18 * 4_826_360 * 1e18) / 1e18;
        expectedHexitShares = (expectedHexitShares * 555) / 10_000;
        assertApproxEqRel(expectedHexitShares, hexitShares, 1e15);

        assertEq(sacrificeClaimed, false);
        assertEq(airdropClaimed, false);

        (uint256 totalSacrificedUsd, uint256 totalSacrificedHx, uint256 remainingHx, uint256 hexitMinted) =
            bootstrap.sacrificeInfo();

        assertEq(totalSacrificedUsd, 100e18);
        assertEq(totalSacrificedHx, amountsOut[1]);
        assertEq(remainingHx, 0);
        assertEq(hexitMinted, 0);
    }

    function test_sacrifice_dai_day30() external {
        skip(29 days);

        feed.update();

        deal(DAI_TOKEN, address(this), 100e18);

        address[] memory path = new address[](2);
        path[0] = DAI_TOKEN;
        path[1] = HEX_TOKEN;
        uint256[] memory amountsOut = IPulseXRouter(PULSEX_ROUTER_V1).getAmountsOut(100e18, path);

        IERC20(DAI_TOKEN).approve(address(bootstrap), 100e18);
        bootstrap.sacrifice(DAI_TOKEN, 100e18, amountsOut[1]);

        (uint256 sacrificedUsd, uint256 hexitShares, bool sacrificeClaimed, bool airdropClaimed) =
            bootstrap.userInfos(address(this));

        assertEq(100e18, sacrificedUsd);

        uint256 expectedHexitShares = (100e18 * 4_150_944 * 1e18) / 1e18;
        expectedHexitShares = (expectedHexitShares * 555) / 10_000;
        assertApproxEqRel(expectedHexitShares, hexitShares, 1e15);

        assertEq(sacrificeClaimed, false);
        assertEq(airdropClaimed, false);

        (uint256 totalSacrificedUsd, uint256 totalSacrificedHx, uint256 remainingHx, uint256 hexitMinted) =
            bootstrap.sacrificeInfo();

        assertEq(totalSacrificedUsd, 100e18);
        assertEq(totalSacrificedHx, amountsOut[1]);
        assertEq(remainingHx, 0);
        assertEq(hexitMinted, 0);
    }

    function test_sacrifice_wpls_day1() external {
        deal(WPLS_TOKEN, address(this), 100_000e18);

        address[] memory path = new address[](2);
        path[0] = WPLS_TOKEN;
        path[1] = HEX_TOKEN;
        uint256[] memory amountsOut = IPulseXRouter(PULSEX_ROUTER_V1).getAmountsOut(100_000e18, path);

        IERC20(WPLS_TOKEN).approve(address(bootstrap), 100_000e18);
        bootstrap.sacrifice(WPLS_TOKEN, 100_000e18, amountsOut[1]);

        (uint256 sacrificedUsd, uint256 hexitShares, bool sacrificeClaimed, bool airdropClaimed) =
            bootstrap.userInfos(address(this));

        uint256 expectedSacrificedUsd = feed.quote(WPLS_TOKEN, 100_000e18, DAI_TOKEN);
        assertEq(expectedSacrificedUsd, sacrificedUsd);

        uint256 expectedHexitShares = (expectedSacrificedUsd * 5_555_555 * 1e18) / 1e18;
        expectedHexitShares = (expectedHexitShares * 555) / 10_000;
        assertEq(expectedHexitShares, hexitShares);

        assertEq(sacrificeClaimed, false);
        assertEq(airdropClaimed, false);

        (uint256 totalSacrificedUsd, uint256 totalSacrificedHx, uint256 remainingHx, uint256 hexitMinted) =
            bootstrap.sacrificeInfo();

        assertEq(totalSacrificedUsd, expectedSacrificedUsd);
        assertEq(totalSacrificedHx, amountsOut[1]);
        assertEq(remainingHx, 0);
        assertEq(hexitMinted, 0);
    }

    function test_sacrifice_wpls_day15() external {
        skip(14 days);

        feed.update();

        deal(WPLS_TOKEN, address(this), 100_000e18);

        address[] memory path = new address[](2);
        path[0] = WPLS_TOKEN;
        path[1] = HEX_TOKEN;
        uint256[] memory amountsOut = IPulseXRouter(PULSEX_ROUTER_V1).getAmountsOut(100_000e18, path);

        IERC20(WPLS_TOKEN).approve(address(bootstrap), 100_000e18);
        bootstrap.sacrifice(WPLS_TOKEN, 100_000e18, amountsOut[1]);

        (uint256 sacrificedUsd, uint256 hexitShares, bool sacrificeClaimed, bool airdropClaimed) =
            bootstrap.userInfos(address(this));

        uint256 expectedSacrificedUsd = feed.quote(WPLS_TOKEN, 100_000e18, DAI_TOKEN);
        assertEq(expectedSacrificedUsd, sacrificedUsd);

        uint256 expectedHexitShares = (expectedSacrificedUsd * 4_826_360 * 1e18) / 1e18;
        expectedHexitShares = (expectedHexitShares * 555) / 10_000;
        assertApproxEqRel(expectedHexitShares, hexitShares, 1e15);

        assertEq(sacrificeClaimed, false);
        assertEq(airdropClaimed, false);

        (uint256 totalSacrificedUsd, uint256 totalSacrificedHx, uint256 remainingHx, uint256 hexitMinted) =
            bootstrap.sacrificeInfo();

        assertEq(totalSacrificedUsd, expectedSacrificedUsd);
        assertEq(totalSacrificedHx, amountsOut[1]);
        assertEq(remainingHx, 0);
        assertEq(hexitMinted, 0);
    }

    function test_sacrifice_wpls_day30() external {
        skip(29 days);

        feed.update();

        deal(WPLS_TOKEN, address(this), 100_000e18);

        address[] memory path = new address[](2);
        path[0] = WPLS_TOKEN;
        path[1] = HEX_TOKEN;
        uint256[] memory amountsOut = IPulseXRouter(PULSEX_ROUTER_V1).getAmountsOut(100_000e18, path);

        IERC20(WPLS_TOKEN).approve(address(bootstrap), 100_000e18);
        bootstrap.sacrifice(WPLS_TOKEN, 100_000e18, amountsOut[1]);

        (uint256 sacrificedUsd, uint256 hexitShares, bool sacrificeClaimed, bool airdropClaimed) =
            bootstrap.userInfos(address(this));

        uint256 expectedSacrificedUsd = feed.quote(WPLS_TOKEN, 100_000e18, DAI_TOKEN);
        assertEq(expectedSacrificedUsd, sacrificedUsd);

        uint256 expectedHexitShares = (expectedSacrificedUsd * 4_150_944 * 1e18) / 1e18;
        expectedHexitShares = (expectedHexitShares * 555) / 10_000;
        assertApproxEqRel(expectedHexitShares, hexitShares, 1e15);

        assertEq(sacrificeClaimed, false);
        assertEq(airdropClaimed, false);

        (uint256 totalSacrificedUsd, uint256 totalSacrificedHx, uint256 remainingHx, uint256 hexitMinted) =
            bootstrap.sacrificeInfo();

        assertEq(totalSacrificedUsd, expectedSacrificedUsd);
        assertEq(totalSacrificedHx, amountsOut[1]);
        assertEq(remainingHx, 0);
        assertEq(hexitMinted, 0);
    }

    function test_sacrifice_plsx_day1() external {
        vm.prank(0x39cF6f8620CbfBc20e1cC1caba1959Bd2FDf0954);
        IERC20(PLSX_TOKEN).transfer(address(this), 1_000_000e18);

        address[] memory path = new address[](2);
        path[0] = PLSX_TOKEN;
        path[1] = HEX_TOKEN;
        uint256[] memory amountsOut = IPulseXRouter(PULSEX_ROUTER_V1).getAmountsOut(1_000_000e18, path);

        IERC20(PLSX_TOKEN).approve(address(bootstrap), 1_000_000e18);
        bootstrap.sacrifice(PLSX_TOKEN, 1_000_000e18, amountsOut[1]);

        (uint256 sacrificedUsd, uint256 hexitShares, bool sacrificeClaimed, bool airdropClaimed) =
            bootstrap.userInfos(address(this));

        uint256 expectedSacrificedUsd = feed.quote(PLSX_TOKEN, 1_000_000e18, DAI_TOKEN);
        assertEq(expectedSacrificedUsd, sacrificedUsd);

        uint256 expectedHexitShares = (expectedSacrificedUsd * 5_555_555 * 1e18) / 1e18;
        expectedHexitShares = (expectedHexitShares * 555) / 10_000;
        assertEq(expectedHexitShares, hexitShares);

        assertEq(sacrificeClaimed, false);
        assertEq(airdropClaimed, false);

        (uint256 totalSacrificedUsd, uint256 totalSacrificedHx, uint256 remainingHx, uint256 hexitMinted) =
            bootstrap.sacrificeInfo();

        assertEq(totalSacrificedUsd, expectedSacrificedUsd);
        assertEq(totalSacrificedHx, amountsOut[1]);
        assertEq(remainingHx, 0);
        assertEq(hexitMinted, 0);
    }

    function test_sacrifice_plsx_day15() external {
        skip(14 days);

        feed.update();

        vm.prank(0x39cF6f8620CbfBc20e1cC1caba1959Bd2FDf0954);
        IERC20(PLSX_TOKEN).transfer(address(this), 1_000_000e18);

        address[] memory path = new address[](2);
        path[0] = PLSX_TOKEN;
        path[1] = HEX_TOKEN;
        uint256[] memory amountsOut = IPulseXRouter(PULSEX_ROUTER_V1).getAmountsOut(1_000_000e18, path);

        IERC20(PLSX_TOKEN).approve(address(bootstrap), 1_000_000e18);
        bootstrap.sacrifice(PLSX_TOKEN, 1_000_000e18, amountsOut[1]);

        (uint256 sacrificedUsd, uint256 hexitShares, bool sacrificeClaimed, bool airdropClaimed) =
            bootstrap.userInfos(address(this));

        uint256 expectedSacrificedUsd = feed.quote(PLSX_TOKEN, 1_000_000e18, DAI_TOKEN);
        assertEq(expectedSacrificedUsd, sacrificedUsd);

        uint256 expectedHexitShares = (expectedSacrificedUsd * 4_826_360 * 1e18) / 1e18;
        expectedHexitShares = (expectedHexitShares * 555) / 10_000;
        assertApproxEqRel(expectedHexitShares, hexitShares, 1e15);

        assertEq(sacrificeClaimed, false);
        assertEq(airdropClaimed, false);

        (uint256 totalSacrificedUsd, uint256 totalSacrificedHx, uint256 remainingHx, uint256 hexitMinted) =
            bootstrap.sacrificeInfo();

        assertEq(totalSacrificedUsd, expectedSacrificedUsd);
        assertEq(totalSacrificedHx, amountsOut[1]);
        assertEq(remainingHx, 0);
        assertEq(hexitMinted, 0);
    }

    function test_sacrifice_plsx_day30() external {
        skip(29 days);

        feed.update();

        vm.prank(0x39cF6f8620CbfBc20e1cC1caba1959Bd2FDf0954);
        IERC20(PLSX_TOKEN).transfer(address(this), 1_000_000e18);

        address[] memory path = new address[](2);
        path[0] = PLSX_TOKEN;
        path[1] = HEX_TOKEN;
        uint256[] memory amountsOut = IPulseXRouter(PULSEX_ROUTER_V1).getAmountsOut(1_000_000e18, path);

        IERC20(PLSX_TOKEN).approve(address(bootstrap), 1_000_000e18);
        bootstrap.sacrifice(PLSX_TOKEN, 1_000_000e18, amountsOut[1]);

        (uint256 sacrificedUsd, uint256 hexitShares, bool sacrificeClaimed, bool airdropClaimed) =
            bootstrap.userInfos(address(this));

        uint256 expectedSacrificedUsd = feed.quote(PLSX_TOKEN, 1_000_000e18, DAI_TOKEN);
        assertEq(expectedSacrificedUsd, sacrificedUsd);

        uint256 expectedHexitShares = (expectedSacrificedUsd * 4_150_944 * 1e18) / 1e18;
        expectedHexitShares = (expectedHexitShares * 555) / 10_000;
        assertApproxEqRel(expectedHexitShares, hexitShares, 1e15);

        assertEq(sacrificeClaimed, false);
        assertEq(airdropClaimed, false);

        (uint256 totalSacrificedUsd, uint256 totalSacrificedHx, uint256 remainingHx, uint256 hexitMinted) =
            bootstrap.sacrificeInfo();

        assertEq(totalSacrificedUsd, expectedSacrificedUsd);
        assertEq(totalSacrificedHx, amountsOut[1]);
        assertEq(remainingHx, 0);
        assertEq(hexitMinted, 0);
    }

    function test_processSacrifice() external {
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

        (, uint64 claimEnd, bool processed) = bootstrap.sacrificeSchedule();
        assertEq(claimEnd, block.timestamp + 7 days);
        assertEq(processed, true);

        uint256 expectedRemainingHx = (10_000e8 * 7500) / 10_000;
        (,, uint256 remainingHx,) = bootstrap.sacrificeInfo();
        assertEq(remainingHx, expectedRemainingHx);

        address vault = bootstrap.vault();
        assertTrue(vault != address(0));

        address pair = IPulseXFactory(PULSEX_FACTORY_V2).getPair(IHexOneVault(vault).hex1(), DAI_TOKEN);
        assertTrue(pair != address(0));
    }

    function test_claimSacrifice() external {
        deal(HEX_TOKEN, address(this), 100_000e8);

        IERC20(HEX_TOKEN).approve(address(bootstrap), 100_000e8);
        bootstrap.sacrifice(HEX_TOKEN, 100_000e8, 0);

        skip(30 days);

        feed.update();

        uint256 hexToSwap = (100_000e8 * 1250) / 10_000;

        address[] memory path = new address[](2);
        path[0] = HEX_TOKEN;
        path[1] = DAI_TOKEN;
        uint256[] memory amountsOut = IPulseXRouter(PULSEX_ROUTER_V1).getAmountsOut(hexToSwap, path);

        vm.startPrank(owner);
        bootstrap.processSacrifice(amountsOut[1]);
        vm.stopPrank();

        uint256 hexitBefore = hexit.balanceOf(address(this));

        (uint256 tokenId, uint256 hex1Minted, uint256 hexitMinted) = bootstrap.claimSacrifice();

        (,, bool sacrificeClaimed,) = bootstrap.userInfos(address(this));
        assertEq(sacrificeClaimed, true);

        (,,, uint256 totalHexitMinted) = bootstrap.sacrificeInfo();
        assertEq(totalHexitMinted, hexitMinted);

        address vault = bootstrap.vault();
        assertEq(IERC721(vault).balanceOf(address(this)), 1);
        assertEq(IERC721(vault).ownerOf(tokenId), address(this));

        uint256 hexitAfter = hexit.balanceOf(address(this));
        assertEq(hexitAfter - hexitBefore, hexitMinted);

        address hex1 = IHexOneVault(vault).hex1();
        assertEq(IERC20(hex1).balanceOf(address(this)), hex1Minted);
    }

    function test_airdropDay() external {
        deal(HEX_TOKEN, address(this), 100_000e8);

        IERC20(HEX_TOKEN).approve(address(bootstrap), 100_000e8);
        bootstrap.sacrifice(HEX_TOKEN, 100_000e8, 0);

        skip(30 days);

        feed.update();

        uint256 hexToSwap = (100_000e8 * 1250) / 10_000;

        address[] memory path = new address[](2);
        path[0] = HEX_TOKEN;
        path[1] = DAI_TOKEN;
        uint256[] memory amountsOut = IPulseXRouter(PULSEX_ROUTER_V1).getAmountsOut(hexToSwap, path);

        vm.startPrank(owner);
        bootstrap.processSacrifice(amountsOut[1]);
        vm.stopPrank();

        bootstrap.claimSacrifice();

        skip(7 days);

        IERC20(hexit).balanceOf(address(owner));

        vm.startPrank(owner);
        bootstrap.startAirdrop(uint64(block.timestamp));
        vm.stopPrank();

        assertEq(bootstrap.airdropDay(), 1);

        skip(7 days);

        assertEq(bootstrap.airdropDay(), 8);

        skip(7 days);

        assertEq(bootstrap.airdropDay(), 15);
    }

    function test_startAirdrop() external {
        deal(HEX_TOKEN, address(this), 100_000e8);

        IERC20(HEX_TOKEN).approve(address(bootstrap), 100_000e8);
        bootstrap.sacrifice(HEX_TOKEN, 100_000e8, 0);

        skip(30 days);

        feed.update();

        uint256 hexToSwap = (100_000e8 * 1250) / 10_000;

        address[] memory path = new address[](2);
        path[0] = HEX_TOKEN;
        path[1] = DAI_TOKEN;
        uint256[] memory amountsOut = IPulseXRouter(PULSEX_ROUTER_V1).getAmountsOut(hexToSwap, path);

        vm.startPrank(owner);
        bootstrap.processSacrifice(amountsOut[1]);
        vm.stopPrank();

        (,, uint256 hexitMinted) = bootstrap.claimSacrifice();

        skip(7 days);

        uint256 hexitBefore = IERC20(hexit).balanceOf(address(owner));

        vm.startPrank(owner);
        bootstrap.startAirdrop(uint64(block.timestamp));
        vm.stopPrank();

        (uint64 start, uint64 claimEnd, bool processed) = bootstrap.airdropSchedule();
        assertEq(start, block.timestamp);
        assertEq(claimEnd, block.timestamp + 15 days);
        assertEq(processed, true);

        uint256 hexitAfter = IERC20(hexit).balanceOf(TEAM_WALLET);

        uint256 teamHexit = (6667 * hexitMinted) / 10_000;
        assertEq(hexitAfter - hexitBefore, teamHexit);
    }

    function test_claimAirdrop_day1() external {
        deal(HEX_TOKEN, address(this), 100_000e8);

        IERC20(HEX_TOKEN).approve(address(bootstrap), 100_000e8);
        bootstrap.sacrifice(HEX_TOKEN, 100_000e8, 0);

        skip(30 days);

        feed.update();

        uint256 hexToSwap = (100_000e8 * 1250) / 10_000;

        address[] memory path = new address[](2);
        path[0] = HEX_TOKEN;
        path[1] = DAI_TOKEN;
        uint256[] memory amountsOut = IPulseXRouter(PULSEX_ROUTER_V1).getAmountsOut(hexToSwap, path);

        vm.startPrank(owner);
        bootstrap.processSacrifice(amountsOut[1]);
        vm.stopPrank();

        bootstrap.claimSacrifice();

        skip(7 days);

        vm.startPrank(owner);
        bootstrap.startAirdrop(uint64(block.timestamp));
        vm.stopPrank();

        feed.update();

        bootstrap.claimAirdrop();

        (uint256 sacrificedUsd,,, bool airdropClaimed) = bootstrap.userInfos(address(this));
        assertEq(airdropClaimed, true);

        (uint256 hexitMinted) = bootstrap.airdropInfo();
        uint256 expectedHexitMinted = (sacrificedUsd * 9) + 5_555_555 * 1e18;
        assertEq(expectedHexitMinted, hexitMinted);
    }

    function test_claimAirdrop_day8() external {
        deal(HEX_TOKEN, address(this), 100_000e8);

        IERC20(HEX_TOKEN).approve(address(bootstrap), 100_000e8);
        bootstrap.sacrifice(HEX_TOKEN, 100_000e8, 0);

        skip(30 days);

        feed.update();

        uint256 hexToSwap = (100_000e8 * 1250) / 10_000;

        address[] memory path = new address[](2);
        path[0] = HEX_TOKEN;
        path[1] = DAI_TOKEN;
        uint256[] memory amountsOut = IPulseXRouter(PULSEX_ROUTER_V1).getAmountsOut(hexToSwap, path);

        vm.startPrank(owner);
        bootstrap.processSacrifice(amountsOut[1]);
        vm.stopPrank();

        bootstrap.claimSacrifice();

        skip(7 days);

        vm.startPrank(owner);
        bootstrap.startAirdrop(uint64(block.timestamp));
        vm.stopPrank();

        skip(7 days);

        feed.update();

        bootstrap.claimAirdrop();

        (uint256 sacrificedUsd,,, bool airdropClaimed) = bootstrap.userInfos(address(this));
        assertEq(airdropClaimed, true);

        (uint256 hexitMinted) = bootstrap.airdropInfo();
        uint256 expectedHexitMinted = (sacrificedUsd * 9) + 5_178_138 * 1e18;
        assertApproxEqRel(expectedHexitMinted, hexitMinted, 1e15);
    }

    function test_claimAirdrop_day15() external {
        deal(HEX_TOKEN, address(this), 100_000e8);

        IERC20(HEX_TOKEN).approve(address(bootstrap), 100_000e8);
        bootstrap.sacrifice(HEX_TOKEN, 100_000e8, 0);

        skip(30 days);

        feed.update();

        uint256 hexToSwap = (100_000e8 * 1250) / 10_000;

        address[] memory path = new address[](2);
        path[0] = HEX_TOKEN;
        path[1] = DAI_TOKEN;
        uint256[] memory amountsOut = IPulseXRouter(PULSEX_ROUTER_V1).getAmountsOut(hexToSwap, path);

        vm.startPrank(owner);
        bootstrap.processSacrifice(amountsOut[1]);
        vm.stopPrank();

        bootstrap.claimSacrifice();

        skip(7 days);

        vm.startPrank(owner);
        bootstrap.startAirdrop(uint64(block.timestamp));
        vm.stopPrank();

        skip(14 days);

        feed.update();

        bootstrap.claimAirdrop();

        (uint256 sacrificedUsd,,, bool airdropClaimed) = bootstrap.userInfos(address(this));
        assertEq(airdropClaimed, true);

        (uint256 hexitMinted) = bootstrap.airdropInfo();
        uint256 expectedHexitMinted = (sacrificedUsd * 9) + 4_826_360 * 1e18;
        assertApproxEqRel(expectedHexitMinted, hexitMinted, 1e15);
    }

    function test_claimAirdrop_onlyHexStakes() external {
        deal(HEX_TOKEN, address(this), 100_000e8);

        IERC20(HEX_TOKEN).approve(address(bootstrap), 100_000e8);
        bootstrap.sacrifice(HEX_TOKEN, 100_000e8, 0);

        skip(30 days);

        feed.update();

        uint256 hexToSwap = (100_000e8 * 1250) / 10_000;

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

        address hexStaker = makeAddr("hexStaker");

        deal(HEX_TOKEN, hexStaker, 100_000e8);

        vm.startPrank(hexStaker);
        IHexToken(HEX_TOKEN).stakeStart(100_000e8, 5555);
        bootstrap.claimAirdrop();
        vm.stopPrank();

        uint256 expectedHexit = feed.quote(HEX_TOKEN, 100_000e8, DAI_TOKEN);
        expectedHexit = expectedHexit + (5_555_555 * 1e18);

        assertEq(hexit.balanceOf(hexStaker), expectedHexit);
    }

    function test_claimAirdrop_hexStakesAndSacrificeParticipant() external {
        deal(HEX_TOKEN, address(this), 100_000e8);

        IERC20(HEX_TOKEN).approve(address(bootstrap), 100_000e8);
        bootstrap.sacrifice(HEX_TOKEN, 100_000e8, 0);

        skip(30 days);

        feed.update();

        uint256 hexToSwap = (100_000e8 * 1250) / 10_000;

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

        deal(HEX_TOKEN, address(this), 100_000e8);

        uint256 hexitBefore = hexit.balanceOf(address(this));

        IHexToken(HEX_TOKEN).stakeStart(100_000e8, 5555);
        bootstrap.claimAirdrop();

        (uint256 sacrificedUsd,,,) = bootstrap.userInfos(address(this));

        uint256 expectedHexit = feed.quote(HEX_TOKEN, 100_000e8, DAI_TOKEN);
        expectedHexit = expectedHexit + (5_555_555 * 1e18);
        expectedHexit = expectedHexit + (9 * sacrificedUsd);

        uint256 hexitAfter = hexit.balanceOf(address(this));

        assertEq(hexitAfter - hexitBefore, expectedHexit);
    }
}
