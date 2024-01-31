// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import "../Base.t.sol";

/**
 *  @dev forge test --match-contract HexOneBootstrapTest --rpc-url "https://rpc.pulsechain.com" -vvv
 */
contract HexOneBootstrapTest is Base {

    /*//////////////////////////////////////////////////////////////////////////
                                    CONFIGURATION
    //////////////////////////////////////////////////////////////////////////*/

    function test_deployment() public {
        assertEq(bootstrap.pulseXRouter(), address(pulseXRouter));
        assertEq(bootstrap.pulseXFactory(), address(pulseXFactory));
        assertEq(bootstrap.hexToken(), hexToken);
        assertEq(bootstrap.hexitToken(), address(hexit));
        assertEq(bootstrap.daiToken(), daiToken);
        assertEq(bootstrap.hexOneToken(), address(hex1));
        assertEq(bootstrap.teamWallet(), receiver);
    }

    function test_setBaseData() public {
        assertEq(bootstrap.hexOnePriceFeed(), address(feed));
        assertEq(bootstrap.hexOneStaking(), address(staking));
        assertEq(bootstrap.hexOneVault(), address(vault));
    }

    function test_setSacrificeTokens() public {
        assertEq(bootstrap.tokenMultipliers(hexToken), 5555);
        assertEq(bootstrap.tokenMultipliers(daiToken), 3000);
        assertEq(bootstrap.tokenMultipliers(wplsToken), 2000);
        assertEq(bootstrap.tokenMultipliers(plsxToken), 1000);
    }

    function test_setSacrificeStart() public {
        assertEq(bootstrap.sacrificeStart(), block.timestamp);
        assertEq(bootstrap.sacrificeEnd(), block.timestamp + 30 days);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    SACRIFICE
    //////////////////////////////////////////////////////////////////////////*/

    function test_sacrifice_hex(uint256 amount) public {
        // bound the amount being used as an input
        vm.assume(amount > 1e8 && amount < 1_000_000 * 1e8);

        // give HEX to the sender
        _dealToken(hexToken, user, amount);

        vm.startPrank(user);
        uint256 amountOut = _sacrifice(hexToken, amount);
        vm.stopPrank();

        // assert that it is the first day of the sacrifice
        assertEq(bootstrap.getCurrentSacrificeDay(), 1);

        // assert total HEX sacrificed
        assertEq(bootstrap.totalHexAmount(), amountOut);

        // assert total HEX contract balance
        assertEq(IERC20(hexToken).balanceOf(address(bootstrap)), amountOut);

        // assert that the right usd price sacrificed is correct
        (uint256 totalHexitShares, uint256 sacrificedUSD,,) = bootstrap.userInfos(user);
        uint256 hexPriceInDai = feed.consult(hexToken, amountOut, daiToken);
        assertEq(sacrificedUSD, hexPriceInDai);

        // assert that the hexit tokens to be minted are correct
        uint256 multiplier = 5555;
        uint256 baseHexitPerDollar = 5_555_555 * 1e18;
        uint256 expectedHexitShares = (hexPriceInDai * baseHexitPerDollar) / 1e18;
        expectedHexitShares = (expectedHexitShares * multiplier) / 1000;
        assertEq(totalHexitShares, expectedHexitShares);
    }

    function test_sacrifice_dai(uint256 amount) public {
        // bound the amount being used as an input
        vm.assume(amount > 1e18 && amount < 1_000_000 * 1e18);

        // deal DAI to the user
        _dealToken(daiToken, user, amount);

        // user sacrifices DAI
        vm.startPrank(user);
        uint256 amountOut = _sacrifice(daiToken, amount);
        vm.stopPrank();

        // assert that it is the first day of the sacrifice
        assertEq(bootstrap.getCurrentSacrificeDay(), 1);

        // note: 100% is 1e18 so 1% max slippage corresponds to 1e16
        uint256 maxSlippage = 1e16;

        // assert total DAI sacrificed
        assertApproxEqRel(bootstrap.totalHexAmount(), amountOut, maxSlippage);

        // assert total DAI contract balance
        assertApproxEqRel(IERC20(hexToken).balanceOf(address(bootstrap)), amountOut, maxSlippage);

        // assert that the right USD price sacrificed is correct
        (uint256 totalHexitShares, uint256 sacrificedUSD,,) = bootstrap.userInfos(user);
        assertEq(sacrificedUSD, amount);

        // assert that the HEXIT tokens to be minted are correct
        uint256 multiplier = 3000;
        uint256 baseHexitPerDollar = 5_555_555 * 1e18;
        uint256 expectedHexitShares = (amount * baseHexitPerDollar) / 1e18;
        expectedHexitShares = (expectedHexitShares * multiplier) / 1000;
        assertEq(totalHexitShares, expectedHexitShares);
    }

    function test_sacrifice_wpls(uint256 amount) public {
        // bound the amount being used as an input
        vm.assume(amount > 10_000 * 1e18 && amount < 1_000_000 * 1e18);

        // deal WPLS to the sender
        _dealToken(wplsToken, user, amount);

        vm.startPrank(user);
        uint256 amountOut = _sacrifice(wplsToken, amount);
        vm.stopPrank();

        // assert that it is the first day of the sacrifice
        assertEq(bootstrap.getCurrentSacrificeDay(), 1);

        // note: 100% is 1e18 so 1% max slippage corresponds to 1e16
        uint256 maxSlippage = 1e16;

        // assert total HEX sacrificed
        assertApproxEqRel(bootstrap.totalHexAmount(), amountOut, maxSlippage);

        // assert total HEX contract balance
        assertApproxEqRel(IERC20(hexToken).balanceOf(address(bootstrap)), amountOut, maxSlippage);

        // assert that the right usd price sacrificed is correct
        (uint256 totalHexitShares, uint256 sacrificedUSD,,) = bootstrap.userInfos(user);
        uint256 wplsPriceInDai = feed.consult(wplsToken, amount, daiToken);
        assertEq(sacrificedUSD, wplsPriceInDai);

        // assert that the hexit tokens to be minted are correct
        uint256 multiplier = 2000;
        uint256 baseHexitPerDollar = 5_555_555 * 1e18;
        uint256 expectedHexitShares = (wplsPriceInDai * baseHexitPerDollar) / 1e18;
        expectedHexitShares = (expectedHexitShares * multiplier) / 1000;
        assertEq(totalHexitShares, expectedHexitShares);
    }

    function test_sacrifice_plsx(uint256 amount) public {
        // bound the amount being used as an input
        vm.assume(amount > 10_000 * 1e18 && amount < 1_000_000_000 * 1e18);

        // deal PLSX to the sender
        _dealToken(plsxToken, user, amount);

        // sacrifice PLSX tokens
        vm.startPrank(user);
        uint256 amountOut = _sacrifice(plsxToken, amount);
        vm.stopPrank();

        // assert that it is the first day of the sacrifice
        assertEq(bootstrap.getCurrentSacrificeDay(), 1);

        // note: 100% is 1e18 so 1% max slippage corresponds to 1e16
        uint256 maxSlippage = 1e16;

        // assert total HEX sacrificed
        assertApproxEqRel(bootstrap.totalHexAmount(), amountOut, maxSlippage);

        // assert total HEX contract balance
        assertApproxEqRel(IERC20(hexToken).balanceOf(address(bootstrap)), amountOut, maxSlippage);

        // assert that the right USD price sacrificed is correct
        (uint256 totalHexitShares, uint256 sacrificedUSD,,) = bootstrap.userInfos(user);
        uint256 plsxPriceInDai = feed.consult(plsxToken, amount, daiToken);
        assertEq(sacrificedUSD, plsxPriceInDai);

        // assert that the hexit tokens to be minted are correct
        uint256 multiplier = 1000;
        uint256 baseHexitPerDollar = 5_555_555 * 1e18;
        uint256 expectedHexitShares = (plsxPriceInDai * baseHexitPerDollar) / 1e18;
        expectedHexitShares = (expectedHexitShares * multiplier) / 1000;
        assertEq(totalHexitShares, expectedHexitShares);
    }

    function test_sacrifice_hex_after_15days(uint256 amount) public {
        // bound the amount being used as an input
        vm.assume(amount > 1e8 && amount < 1_000_000 * 1e8);

        // give HEX to the sender
        _dealToken(hexToken, user, amount);

        // advance block timestamp by 15 days
        skip(14 days);

        // assert that it is the 15th day of the sacrifice
        assertEq(bootstrap.getCurrentSacrificeDay(), 15);

        vm.startPrank(user);
        uint256 amountOut = _sacrifice(hexToken, amount);
        vm.stopPrank();

        // assert that the right usd price sacrificed is correct
        (uint256 totalHexitShares, uint256 sacrificedUSD,,) = bootstrap.userInfos(user);
        uint256 hexPriceInDai = feed.consult(hexToken, amountOut, daiToken);
        assertEq(sacrificedUSD, hexPriceInDai);

        // assert that the hexit tokens to be minted are correct
        uint256 maxSlippage = 1e16;
        uint256 multiplier = 5555;
        uint256 baseHexitPerDollar = 2_806_714 * 1e18;
        uint256 expectedHexitShares = (hexPriceInDai * baseHexitPerDollar) / 1e18;
        expectedHexitShares = (expectedHexitShares * multiplier) / 1000;
        assertApproxEqRel(totalHexitShares, expectedHexitShares, maxSlippage);
    }

    function test_sacrifice_dai_after_15days(uint256 amount) public {
        // bound the amount being used as an input
        vm.assume(amount > 1e18 && amount < 1_000_000 * 1e18);

        // give DAI to the sender
        _dealToken(daiToken, user, amount);

        // advance block timestamp by 15 days
        skip(14 days);

        // assert that it is the 15th day of the sacrifice
        assertEq(bootstrap.getCurrentSacrificeDay(), 15);

        vm.startPrank(user);
        _sacrifice(daiToken, amount);
        vm.stopPrank();

        // assert that the right usd price sacrificed is correct
        (uint256 totalHexitShares, uint256 sacrificedUSD,,) = bootstrap.userInfos(user);
        assertEq(sacrificedUSD, amount);

        // assert that the hexit tokens to be minted are correct
        uint256 maxSlippage = 1e16;
        uint256 multiplier = 3000;
        uint256 baseHexitPerDollar = 2_806_714 * 1e18;
        uint256 expectedHexitShares = (amount * baseHexitPerDollar) / 1e18;
        expectedHexitShares = (expectedHexitShares * multiplier) / 1000;
        assertApproxEqRel(totalHexitShares, expectedHexitShares, maxSlippage);
    }

    function test_sacrifice_wpls_after_15days(uint256 amount) public {
        // bound the amount being used as an input
        vm.assume(amount > 10_000 * 1e18 && amount < 1_000_000 * 1e18);

        // give WPLS to the sender
        _dealToken(wplsToken, user, amount);

        // advance block timestamp by 15 days
        skip(14 days);

        // assert that it is the 15th day of the sacrifice
        assertEq(bootstrap.getCurrentSacrificeDay(), 15);

        vm.startPrank(user);
        _sacrifice(wplsToken, amount);
        vm.stopPrank();

        // assert that the right usd price sacrificed is correct
        (uint256 totalHexitShares, uint256 sacrificedUSD,,) = bootstrap.userInfos(user);
        uint256 wplsPriceInDai = feed.consult(wplsToken, amount, daiToken);
        assertEq(sacrificedUSD, wplsPriceInDai);

        // assert that the hexit tokens to be minted are correct
        uint256 maxSlippage = 1e16;
        uint256 multiplier = 2000;
        uint256 baseHexitPerDollar = 2_806_714 * 1e18;
        uint256 expectedHexitShares = (wplsPriceInDai * baseHexitPerDollar) / 1e18;
        expectedHexitShares = (expectedHexitShares * multiplier) / 1000;
        assertApproxEqRel(totalHexitShares, expectedHexitShares, maxSlippage);
    }

    function test_sacrifice_plsx_after_15days(uint256 amount) public {
        // bound the amount being used as an input
        vm.assume(amount > 10_000 * 1e18 && amount < 1_000_000_000 * 1e18);

        // give PLSX to the sender
        _dealToken(plsxToken, user, amount);

        // advance block timestamp by 15 days
        skip(14 days);

        // assert that it is the 15th day of the sacrifice
        assertEq(bootstrap.getCurrentSacrificeDay(), 15);

        vm.startPrank(user);
        _sacrifice(plsxToken, amount);
        vm.stopPrank();

        // assert that the right usd price sacrificed is correct
        (uint256 totalHexitShares, uint256 sacrificedUSD,,) = bootstrap.userInfos(user);
        uint256 plsxPriceInDai = feed.consult(plsxToken, amount, daiToken);
        assertEq(sacrificedUSD, plsxPriceInDai);

        // assert that the hexit tokens to be minted are correct
        uint256 maxSlippage = 1e16;
        uint256 multiplier = 1000;
        uint256 baseHexitPerDollar = 2_806_714 * 1e18;
        uint256 expectedHexitShares = (plsxPriceInDai * baseHexitPerDollar) / 1e18;
        expectedHexitShares = (expectedHexitShares * multiplier) / 1000;
        assertApproxEqRel(totalHexitShares, expectedHexitShares, maxSlippage);
    }

    function test_sacrifice_hex_after_30days(uint256 amount) public {
        // bound the amount being used as an input
        vm.assume(amount > 1e8 && amount < 1_000_000 * 1e8);

        // give HEX to the sender
        _dealToken(hexToken, user, amount);

        // advance block timestamp by 15 days
        skip(29 days);

        // assert that it is the 15th day of the sacrifice
        assertEq(bootstrap.getCurrentSacrificeDay(), 30);

        vm.startPrank(user);
        uint256 amountOut = _sacrifice(hexToken, amount);
        vm.stopPrank();

        // stop impersonating user
        vm.stopPrank();

        // assert that the right usd price sacrificed is correct
        (uint256 totalHexitShares, uint256 sacrificedUSD,,) = bootstrap.userInfos(user);
        uint256 hexPriceInDai = feed.consult(hexToken, amountOut, daiToken);
        assertEq(sacrificedUSD, hexPriceInDai);

        // assert that the hexit tokens to be minted are correct
        uint256 maxSlippage = 1e16;
        uint256 multiplier = 5555;
        uint256 baseHexitPerDollar = 1_350_479 * 1e18;
        uint256 expectedHexitShares = (hexPriceInDai * baseHexitPerDollar) / 1e18;
        expectedHexitShares = (expectedHexitShares * multiplier) / 1000;
        assertApproxEqRel(totalHexitShares, expectedHexitShares, maxSlippage);
    }

    function test_sacrifice_dai_after_30days(uint256 amount) public {
        // bound the amount being used as an input
        vm.assume(amount > 1e18 && amount < 1_000_000 * 1e18);

        // give DAI to the sender
        _dealToken(daiToken, user, amount);

        // advance block timestamp by 15 days
        skip(29 days);

        // assert that it is the final day of the sacrifice
        assertEq(bootstrap.getCurrentSacrificeDay(), 30);

        vm.startPrank(user);
        _sacrifice(daiToken, amount);
        vm.stopPrank();

        // assert that the right usd price sacrificed is correct
        (uint256 totalHexitShares, uint256 sacrificedUSD,,) = bootstrap.userInfos(user);
        assertEq(sacrificedUSD, amount);

        // assert that the hexit tokens to be minted are correct
        uint256 maxSlippage = 1e16;
        uint256 multiplier = 3000;
        uint256 baseHexitPerDollar = 1_350_479 * 1e18;
        uint256 expectedHexitShares = (amount * baseHexitPerDollar) / 1e18;
        expectedHexitShares = (expectedHexitShares * multiplier) / 1000;
        assertApproxEqRel(totalHexitShares, expectedHexitShares, maxSlippage);
    }

    function test_sacrifice_wpls_after_30days(uint256 amount) public {
        // bound the amount being used as an input
        vm.assume(amount > 10_000 * 1e18 && amount < 1_000_000 * 1e18);

        // give WPLS to the sender
        _dealToken(wplsToken, user, amount);

        // advance block timestamp by 15 days
        skip(29 days);

        // assert that it is the final day of the sacrifice
        assertEq(bootstrap.getCurrentSacrificeDay(), 30);

        vm.startPrank(user);
        _sacrifice(wplsToken, amount);
        vm.stopPrank();

        // assert that the right usd price sacrificed is correct
        (uint256 totalHexitShares, uint256 sacrificedUSD,,) = bootstrap.userInfos(user);
        uint256 wplsPriceInDai = feed.consult(wplsToken, amount, daiToken);
        assertEq(sacrificedUSD, wplsPriceInDai);

        // assert that the hexit tokens to be minted are correct
        uint256 maxSlippage = 1e16;
        uint256 multiplier = 2000;
        uint256 baseHexitPerDollar = 1_350_479 * 1e18;
        uint256 expectedHexitShares = (wplsPriceInDai * baseHexitPerDollar) / 1e18;
        expectedHexitShares = (expectedHexitShares * multiplier) / 1000;
        assertApproxEqRel(totalHexitShares, expectedHexitShares, maxSlippage);
    }

    function test_sacrifice_plsx_after_30days(uint256 amount) public {
        // bound the amount being used as an input
        vm.assume(amount > 10_000 * 1e18 && amount < 1_000_000_000 * 1e18);

        // give PLSX to the sender
        _dealToken(plsxToken, user, amount);

        // advance block timestamp by 15 days
        skip(29 days);

        // assert that it is the final day of the sacrifice
        assertEq(bootstrap.getCurrentSacrificeDay(), 30);

        vm.startPrank(user);
        _sacrifice(plsxToken, amount);
        vm.stopPrank();

        // assert that the right usd price sacrificed is correct
        (uint256 totalHexitShares, uint256 sacrificedUSD,,) = bootstrap.userInfos(user);
        uint256 plsxPriceInDai = feed.consult(plsxToken, amount, daiToken);
        assertEq(sacrificedUSD, plsxPriceInDai);

        // assert that the hexit tokens to be minted are correct
        uint256 maxSlippage = 1e16;
        uint256 multiplier = 1000;
        uint256 baseHexitPerDollar = 1_350_479 * 1e18;
        uint256 expectedHexitShares = (plsxPriceInDai * baseHexitPerDollar) / 1e18;
        expectedHexitShares = (expectedHexitShares * multiplier) / 1000;
        assertApproxEqRel(totalHexitShares, expectedHexitShares, maxSlippage);
    }

    function test_sacrifice_revert_sacrificeHasNotStartedYet() public {
        // start impersionating user
        vm.startPrank(user);

        // set a timestamp in the past
        uint256 timestamp = block.timestamp - 1 days;
        vm.warp(timestamp);

        // expect the sacrifice function to revert because sacrifice has not started yet
        vm.expectRevert(abi.encodeWithSelector(IHexOneBootstrap.SacrificeHasNotStartedYet.selector, timestamp));
        bootstrap.sacrifice(hexToken, 100, 0);

        // stop impersonating the user
        vm.stopPrank();
    }

    function test_sacrifice_revert_sacrificeAlreadyEnded() public {
        // start impersionating user
        vm.startPrank(user);

        // advance block timestamp by 30 days
        skip(30 days);

        // expect the sacrifice function to revert because sacrifice period already finished
        vm.expectRevert(abi.encodeWithSelector(IHexOneBootstrap.SacrificeAlreadyEnded.selector, block.timestamp));
        bootstrap.sacrifice(hexToken, 100, 0);

        // stop impersonating the user
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                PROCESS SACRIFICE
    //////////////////////////////////////////////////////////////////////////*/

    function test_processSacrifice(uint256 amount) public {
        vm.assume(amount > 1_000 * 1e8 && amount < 10_000_000 * 1e8);

        // give HEX to the sender
        _dealToken(hexToken, user, amount);

        // user sacrifices HEX
        vm.startPrank(user);
        _sacrifice(hexToken, amount);
        vm.stopPrank();

        // skip 30 days so ensure that sacrifice period already ended
        skip(30 days);

        // calculate the corresponding to 12.5% of the total HEX deposited
        uint256 amountOfHexToDai = (amount * 1250) / 10000;

        // deployer processes the sacrifice
        vm.startPrank(deployer);
        _processSacrifice(amountOfHexToDai);
        vm.stopPrank();

        // assert sacrifice was processed.
        assertEq(bootstrap.sacrificeProcessed(), true);

        // assert sacrifice claim period.
        assertEq(bootstrap.sacrificeClaimPeriodEnd(), block.timestamp + 7 days);

        // assert that the total HEX amount is now only 75% of the inital amount
        uint256 hexToDistribute = (amount * 7500) / 10000;
        uint256 maxSlippage = 1e16;
        assertApproxEqRel(bootstrap.totalHexAmount(), hexToDistribute, maxSlippage);

        // assert vault sacrifice status is set to true
        assertEq(vault.sacrificeFinished(), true);

        // assert that a new pair was created
        address expectedPairAddr = UniswapV2Library.pairFor(pulseXFactory, address(hex1), daiToken);
        address pair = IPulseXFactory(pulseXFactory).getPair(address(hex1), daiToken);
        assertEq(expectedPairAddr, pair);
    }

    function test_processSacrifice_revert_sacrificeHasNotEndedYet() public {
        // impersonate the deployer
        vm.startPrank(deployer);

        vm.expectRevert(abi.encodeWithSelector(IHexOneBootstrap.SacrificeHasNotEndedYet.selector, block.timestamp));
        bootstrap.processSacrifice(1); // parameters here does not matter because it is never read

        // stop impersonating the deployer
        vm.stopPrank();
    }

    function test_processSacrifice_revert_sacrificeAlreadyProcessed() public {
        // give HEX to the sender
        uint256 amount = 1_000_000 * 1e8;
        _dealToken(hexToken, user, amount);

        // user sacrifices HEX
        vm.startPrank(user);
        _sacrifice(hexToken, amount);
        vm.stopPrank();

        // skip 30 days so ensure that sacrifice period already ended
        skip(30 days);

        // calculate the corresponding to 12.5% of the total HEX deposited
        uint256 amountOfHexToDai = (amount * 1250) / 10000;

        // impersonate the deployer
        vm.startPrank(deployer);

        // process sacrifice
        uint256 amountOut = _processSacrifice(amountOfHexToDai);

        // expect revert because deployer cant process the sacrifice twice
        vm.expectRevert(IHexOneBootstrap.SacrificeAlreadyProcessed.selector);
        bootstrap.processSacrifice(amountOut);

        // stop impersonating the deployer
        vm.stopPrank();
    }

    function test_processSacrifice_with_pairAlreadyCreated() public {
        // give HEX to the sender
        uint256 amount = 1_000_000 * 1e8;
        deal(hexToken, user, amount);

        // give HEX to the sender
        _dealToken(hexToken, user, amount);

        // user sacrifices HEX
        vm.startPrank(user);
        _sacrifice(hexToken, amount);
        vm.stopPrank();

        // assert total HEX sacrificed
        assertEq(bootstrap.totalHexAmount(), amount);

        // skip 30 days so ensure that sacrifice period already ended
        skip(30 days);

        // the sender creates a pulseXPair to try to DoS the processSacrifice function
        vm.prank(attacker);
        IPulseXFactory(pulseXFactory).createPair(address(hex1), daiToken);

        // calculate the corresponding to 12.5% of the total HEX deposited
        uint256 amountOfHexToDai = (amount * 1250) / 10000;

        // deployer processes the sacrifice
        vm.startPrank(deployer);
        _processSacrifice(amountOfHexToDai);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                CLAIM SACRIFICE
    //////////////////////////////////////////////////////////////////////////*/

    function test_claimSacrifice(uint256 amount) public {
        vm.assume(amount > 1_000 * 1e8 && amount < 10_000_000 * 1e8);

        // give HEX to the sender
        _dealToken(hexToken, user, amount);

        // user sacrifices HEX
        vm.startPrank(user);
        _sacrifice(hexToken, amount);
        vm.stopPrank();

        // assert total HEX sacrificed
        assertEq(bootstrap.totalHexAmount(), amount);

        // skip 30 days so ensure that sacrifice period already ended
        skip(30 days);

        // calculate the corresponding to 12.5% of the total HEX deposited
        uint256 amountOfHexToDai = (amount * 1250) / 10000;

        // deployer processes the sacrifice
        vm.startPrank(deployer);
        _processSacrifice(amountOfHexToDai);
        vm.stopPrank();

        // user claims HEX1 and HEXIT from the sacrifice
        vm.startPrank(user);
        (, uint256 hexOneMinted, uint256 hexitMinted) = bootstrap.claimSacrifice();
        vm.stopPrank();

        // assert sacrifice claimed is set to true
        (uint256 hexitShares,, bool sacrificeClaimed,) = bootstrap.userInfos(user);
        assertEq(sacrificeClaimed, true);

        // assert user HEXIT balance
        assertEq(hexitMinted, hexitShares);
        assertEq(IERC20(hexit).balanceOf(user), hexitShares);

        // assert user HEX1 balance
        assertEq(IERC20(hex1).balanceOf(user), hexOneMinted);
    }

    function test_claimSacrifice_revert_sacrificeHasNotBeenProcessed(uint256 amount) public {
        vm.assume(amount > 1_000 * 1e8 && amount < 10_000_000 * 1e8);

        // give HEX to the sender
        _dealToken(hexToken, user, amount);

        // user sacrifices HEX
        vm.startPrank(user);
        _sacrifice(hexToken, amount);
        vm.stopPrank();

        // assert total HEX sacrificed
        assertEq(bootstrap.totalHexAmount(), amount);

        // skip 30 days so ensure that sacrifice period already ended
        skip(30 days);

        // impersonate the user
        vm.startPrank(user);

        // claim HEX1 and HEXIT from the sacrifice
        vm.expectRevert(IHexOneBootstrap.SacrificeHasNotBeenProcessedYet.selector);
        bootstrap.claimSacrifice();

        // stop impersonating the user
        vm.stopPrank();
    }

    function test_claimSacrifice_revert_didNotParticipateInSacrifice(uint256 amount) public {
        vm.assume(amount > 1_000 * 1e8 && amount < 10_000_000 * 1e8);

        // give HEX to the sender
        _dealToken(hexToken, user, amount);

        // user sacrifices HEX
        vm.startPrank(user);
        _sacrifice(hexToken, amount);
        vm.stopPrank();

        // assert total HEX sacrificed
        assertEq(bootstrap.totalHexAmount(), amount);

        // skip 30 days so ensure that sacrifice period already ended
        skip(30 days);

        // calculate the corresponding to 12.5% of the total HEX deposited
        uint256 amountOfHexToDai = (amount * 1250) / 10000;

        // deployer processes the sacrifice
        vm.startPrank(deployer);
        _processSacrifice(amountOfHexToDai);
        vm.stopPrank();

        // impersonate an attacker who did not participate in the sacrifice
        vm.startPrank(attacker);

        // claim HEX1 and HEXIT from the sacrifice
        vm.expectRevert(abi.encodeWithSelector(IHexOneBootstrap.DidNotParticipateInSacrifice.selector, attacker));
        bootstrap.claimSacrifice();

        // stop impersonating the user who did not sacrifice
        vm.stopPrank();
    }

    function test_claimSacrifice_revert_claimPeriodAlreadyFinished(uint256 amount) public {
        vm.assume(amount > 1_000 * 1e8 && amount < 10_000_000 * 1e8);

        // give HEX to the sender
        _dealToken(hexToken, user, amount);

        // user sacrifices HEX
        vm.startPrank(user);
        _sacrifice(hexToken, amount);
        vm.stopPrank();

        // assert total HEX sacrificed
        assertEq(bootstrap.totalHexAmount(), amount);

        // skip 30 days to ensure that sacrifice period already ended
        skip(30 days);

        // calculate the corresponding to 12.5% of the total HEX deposited
        uint256 amountOfHexToDai = (amount * 1250) / 10000;

        // deployer processes the sacrifice
        vm.startPrank(deployer);
        _processSacrifice(amountOfHexToDai);
        vm.stopPrank();

        // skip 7 days to ensure that sacrifice claim period already ended
        skip(7 days);

        // impersonate the user
        vm.startPrank(user);

        // claim HEX1 and HEXIT from the sacrifice
        vm.expectRevert(
            abi.encodeWithSelector(IHexOneBootstrap.SacrificeClaimPeriodAlreadyFinished.selector, block.timestamp)
        );
        bootstrap.claimSacrifice();

        // stop impersonating the user
        vm.stopPrank();
    }

    function test_claimSacrifice_revert_alreadyClaimed(uint256 amount) public {
        vm.assume(amount > 1_000 * 1e8 && amount < 10_000_000 * 1e8);

        // give HEX to the sender
        _dealToken(hexToken, user, amount);

        // user sacrifices HEX
        vm.startPrank(user);
        _sacrifice(hexToken, amount);
        vm.stopPrank();

        // assert total HEX sacrificed
        assertEq(bootstrap.totalHexAmount(), amount);

        // skip 30 days to ensure that sacrifice period already ended
        skip(30 days);

        // calculate the corresponding to 12.5% of the total HEX deposited
        uint256 amountOfHexToDai = (amount * 1250) / 10000;

        // deployer processes the sacrifice
        vm.startPrank(deployer);
        _processSacrifice(amountOfHexToDai);
        vm.stopPrank();

        // impersonate the user
        vm.startPrank(user);

        // claim HEX1 and HEXIT from the sacrifice
        bootstrap.claimSacrifice();

        // expect call to revert because the user cant claim rewards froms sacrifice twice
        vm.expectRevert(abi.encodeWithSelector(IHexOneBootstrap.SacrificeAlreadyClaimed.selector, user));
        bootstrap.claimSacrifice();

        // stop impersonating the user
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                START AIRDROP
    //////////////////////////////////////////////////////////////////////////*/

    function test_startAirdrop(uint256 amount) public {
        vm.assume(amount > 1_000 * 1e8 && amount < 10_000_000 * 1e8);

        // give HEX to the sender
        _dealToken(hexToken, user, amount);

        // user sacrifices HEX
        vm.startPrank(user);
        _sacrifice(hexToken, amount);
        vm.stopPrank();

        // assert total HEX sacrificed
        assertEq(bootstrap.totalHexAmount(), amount);

        // skip 30 days so ensure that sacrifice period already ended
        skip(30 days);

        // calculate the corresponding to 12.5% of the total HEX deposited
        uint256 amountOfHexToDai = (amount * 1250) / 10000;

        // deployer processes the sacrifice
        vm.startPrank(deployer);
        _processSacrifice(amountOfHexToDai);
        vm.stopPrank();

        // user claims HEX1 and HEXIT from the sacrifice
        vm.startPrank(user);
        bootstrap.claimSacrifice();
        vm.stopPrank();

        // skip the sacrifice claim period
        skip(7 days);

        uint256 hexitMintedDuringSacrifice = bootstrap.totalHexitMinted();

        // start the airdrop
        vm.prank(deployer);
        bootstrap.startAirdrop();

        // assert that airdrop started
        assertEq(bootstrap.airdropStarted(), true);

        // assert airdrop start timestamp
        assertEq(bootstrap.airdropStart(), block.timestamp);

        // assert airdrop end timestamp
        assertEq(bootstrap.airdropEnd(), block.timestamp + 30 days);

        // assert that 50% more on top of the total HEXIT minted during sacrifice
        // is minted to the team
        uint256 hexitForTeam = (hexitMintedDuringSacrifice * 5000) / 10_000;
        assertEq(IERC20(address(hexit)).balanceOf(receiver), hexitForTeam);

        // assert that 33% more on top of the total HEXIT minted during sacrifice
        // is use to add as liquidity in the staking contract
        uint256 hexitForStaking = (hexitMintedDuringSacrifice * 3333) / 10_000;
        assertEq(IERC20(address(hexit)).balanceOf(address(staking)), hexitForStaking);

        // assert that staking was enabled
        assertEq(staking.stakingEnabled(), true);

        // assert the new amount of total hexit minted
        assertEq(bootstrap.totalHexitMinted(), hexitMintedDuringSacrifice + hexitForTeam + hexitForStaking);
    }

    function test_startAirdrop_revert_sacrificeClaimPeriodNotFinished(uint256 amount) public {
        vm.assume(amount > 1_000 * 1e8 && amount < 10_000_000 * 1e8);

        // give HEX to the sender
        _dealToken(hexToken, user, amount);

        // user sacrifices HEX
        vm.startPrank(user);
        _sacrifice(hexToken, amount);
        vm.stopPrank();

        // assert total HEX sacrificed
        assertEq(bootstrap.totalHexAmount(), amount);

        // skip 30 days so ensure that sacrifice period already ended
        skip(30 days);

        // calculate the corresponding to 12.5% of the total HEX deposited
        uint256 amountOfHexToDai = (amount * 1250) / 10000;

        // deployer processes the sacrifice
        vm.startPrank(deployer);
        _processSacrifice(amountOfHexToDai);
        vm.stopPrank();

        // user claims HEX1 and HEXIT from the sacrifice
        vm.startPrank(user);
        bootstrap.claimSacrifice();
        vm.stopPrank();

        // note: still inside sacrifice claim period
        skip(2 days);

        // start the airdrop
        vm.startPrank(deployer);

        // expect revert because sacrifice claim period has not yet finished.
        vm.expectRevert(
            abi.encodeWithSelector(IHexOneBootstrap.SacrificeClaimPeriodHasNotFinished.selector, block.timestamp)
        );
        bootstrap.startAirdrop();

        vm.stopPrank();
    }

    function test_startAirdrop_revert_airdropAlreadyStarted(uint256 amount) public {
        vm.assume(amount > 1_000 * 1e8 && amount < 10_000_000 * 1e8);

        // give HEX to the sender
        _dealToken(hexToken, user, amount);

        // user sacrifices HEX
        vm.startPrank(user);
        _sacrifice(hexToken, amount);
        vm.stopPrank();

        // assert total HEX sacrificed
        assertEq(bootstrap.totalHexAmount(), amount);

        // skip 30 days so ensure that sacrifice period already ended
        skip(30 days);

        // calculate the corresponding to 12.5% of the total HEX deposited
        uint256 amountOfHexToDai = (amount * 1250) / 10000;

        // deployer processes the sacrifice
        vm.startPrank(deployer);
        _processSacrifice(amountOfHexToDai);
        vm.stopPrank();

        // user claims HEX1 and HEXIT from the sacrifice
        vm.startPrank(user);
        bootstrap.claimSacrifice();
        vm.stopPrank();

        // skip the sacrifice claim period
        skip(7 days);

        // start the airdrop
        vm.startPrank(deployer);

        bootstrap.startAirdrop();
        
        // expect start airdrop to revert because it was already started
        vm.expectRevert(IHexOneBootstrap.AirdropAlreadyStarted.selector);
        bootstrap.startAirdrop();

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                CLAIM AIRDROP
    //////////////////////////////////////////////////////////////////////////*/

    function test_claimAirdrop() public {}

    function test_claimAirdrop_onlyHexStaker() public {}

    function test_claimAirdrop_onlySacrificeParticipant() public {}

    function test_claimAirdrop_after_15days() public {}

    function test_claimAirdrop_after_30days() public {}

    function test_claimAirdrop_revert_airdropHasNotStartedYet() public {}

    function test_claimAirdrop_revert_airdropAlreadyEnded() public {}

    function test_claimAirdrop_revert_airdropAlreadyClaimed() public {}

    function test_claimAirdrop_revert_ineligibleForAirdrop() public {}

    /*//////////////////////////////////////////////////////////////////////////
                                HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function _dealToken(address _token, address _recipient, uint256 _amount) internal {
        if (_token == plsxToken) {
            vm.prank(0x39cF6f8620CbfBc20e1cC1caba1959Bd2FDf0954);
            IERC20(plsxToken).transfer(_recipient, _amount);
        } else {
            deal(_token, _recipient, _amount);
        }
    }

    function _sacrifice(address _token, uint256 _amount) internal returns (uint256) {
        IERC20(_token).approve(address(bootstrap), _amount);

        uint256 amountOut;
        if (_token == hexToken) {
            amountOut = _amount;
            bootstrap.sacrifice(_token, _amount, 0);
        } else {
            address[] memory path = new address[](2);
            path[0] = _token;
            path[1] = hexToken;
            uint256[] memory amounts = UniswapV2Library.getAmountsOut(pulseXFactory, _amount, path);

            amountOut = amounts[1];

            bootstrap.sacrifice(_token, _amount, amounts[1]);
        }

        return amountOut;
    }

    function _processSacrifice(uint256 _amountOfHexToDai) internal returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = hexToken;
        path[1] = daiToken;
        uint256[] memory amounts = UniswapV2Library.getAmountsOut(pulseXFactory, _amountOfHexToDai, path);

        bootstrap.processSacrifice(amounts[1]);

        return amounts[1];
    }
}
