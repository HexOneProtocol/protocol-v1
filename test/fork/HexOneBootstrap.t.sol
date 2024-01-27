// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import "../Base.t.sol";

/**
 *  @dev forge test --match-contract HexOneBootstrapTest --rpc-url "https://rpc.pulsechain.com" -vvv
 */
contract HexOneBootstrapTest is Base {
    function test_deployment() public {
        // assert token multipliers for each sacrifice token

        // assert sacrifice start timestamp

        // assert sacrifice end timestamp

        // assert team wallet was set correctly

        // assert dai token was set correctly

        // assert hex one price feed was set correctly
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    SACRIFICE
    //////////////////////////////////////////////////////////////////////////*/

    function test_sacrifice_hex(uint256 amount) public {
        // bound the amount being used as an input
        vm.assume(amount > 1e8 && amount < 1_000_000 * 1e8);

        // give HEX to the sender
        deal(hexToken, user, amount);

        // start impersionating user
        vm.startPrank(user);

        // approve bootstrap to spend HEX tokens
        IERC20(hexToken).approve(address(bootstrap), amount);

        // sacrifice HEX tokens
        bootstrap.sacrifice(hexToken, amount, 0);

        // stop impersonating user
        vm.stopPrank();

        // assert that it is the first day of the sacrifice
        assertEq(bootstrap.getCurrentSacrificeDay(), 1);

        // assert total HEX sacrificed
        assertEq(bootstrap.totalHexAmount(), amount);

        // assert total HEX contract balance
        assertEq(IERC20(hexToken).balanceOf(address(bootstrap)), amount);

        // assert that the right usd price sacrificed is correct
        (uint256 totalHexitShares, uint256 sacrificedUSD,,) = bootstrap.userInfos(user);
        uint256 hexPriceInDai = feed.consult(hexToken, amount, daiToken);
        assertEq(sacrificedUSD, hexPriceInDai);

        // assert that the hexit tokens to be minted are correct
        uint256 multiplier = 5555;
        uint256 baseHexitPerDollar = 5_555_555; // note: only for the first day of sacrifice
        assertEq(totalHexitShares, (hexPriceInDai * multiplier * baseHexitPerDollar) / 1000);
    }

    function test_sacrifice_dai(uint256 amount) public {
        // bound the amount being used as an input
        vm.assume(amount > 1e18 && amount < 1_000_000 * 1e18);

        // give DAI to the sender
        deal(daiToken, user, amount);

        // start impersionating user
        vm.startPrank(user);

        // approve bootstrap to spend DAI tokens
        IERC20(daiToken).approve(address(bootstrap), amount);

        // compute the amountOutMin
        address[] memory path = new address[](2);
        path[0] = daiToken;
        path[1] = hexToken;
        uint256[] memory amounts = UniswapV2Library.getAmountsOut(pulseXFactory, amount, path);

        // sacrifice DAI tokens
        bootstrap.sacrifice(daiToken, amount, amounts[1]);

        // stop impersonating user
        vm.stopPrank();

        // assert that it is the first day of the sacrifice
        assertEq(bootstrap.getCurrentSacrificeDay(), 1);

        // note: 100% is 1e18 so 1% max slippage corresponds to 1e16
        uint256 maxSlippage = 1e16;

        // assert total HEX sacrificed
        assertApproxEqRel(bootstrap.totalHexAmount(), amounts[1], maxSlippage);

        // assert total HEX contract balance
        assertApproxEqRel(IERC20(hexToken).balanceOf(address(bootstrap)), amounts[1], maxSlippage);

        // assert that the right usd price sacrificed is correct
        (uint256 totalHexitShares, uint256 sacrificedUSD,,) = bootstrap.userInfos(user);
        assertEq(sacrificedUSD, amount);

        // assert that the hexit tokens to be minted are correct
        uint256 multiplier = 3000;
        uint256 baseHexitPerDollar = 5_555_555; // note: only for the first day of sacrifice
        assertEq(totalHexitShares, (amount * multiplier * baseHexitPerDollar) / 1000);
    }

    function test_sacrifice_wpls(uint256 amount) public {
        // bound the amount being used as an input
        vm.assume(amount > 10_000 * 1e18 && amount < 1_000_000 * 1e18);

        // give WPLS to the sender
        deal(wplsToken, user, amount);

        // start impersionating user
        vm.startPrank(user);

        // approve bootstrap to spend WPLS
        IERC20(wplsToken).approve(address(bootstrap), amount);

        // compute the amountOutMin
        address[] memory path = new address[](2);
        path[0] = wplsToken;
        path[1] = hexToken;
        uint256[] memory amounts = UniswapV2Library.getAmountsOut(pulseXFactory, amount, path);

        // sacrifice WPLS tokens
        bootstrap.sacrifice(wplsToken, amount, amounts[1]);

        // stop impersonating user
        vm.stopPrank();

        // assert that it is the first day of the sacrifice
        assertEq(bootstrap.getCurrentSacrificeDay(), 1);

        // note: 100% is 1e18 so 1% max slippage corresponds to 1e16
        uint256 maxSlippage = 1e16;

        // assert total HEX sacrificed
        assertApproxEqRel(bootstrap.totalHexAmount(), amounts[1], maxSlippage);

        // assert total HEX contract balance
        assertApproxEqRel(IERC20(hexToken).balanceOf(address(bootstrap)), amounts[1], maxSlippage);

        // assert that the right usd price sacrificed is correct
        (uint256 totalHexitShares, uint256 sacrificedUSD,,) = bootstrap.userInfos(user);
        uint256 wplsPriceInDai = feed.consult(wplsToken, amount, daiToken);
        assertEq(sacrificedUSD, wplsPriceInDai);

        // assert that the hexit tokens to be minted are correct
        uint256 multiplier = 2000;
        uint256 baseHexitPerDollar = 5_555_555; // note: only for the first day of sacrifice
        assertEq(totalHexitShares, (wplsPriceInDai * multiplier * baseHexitPerDollar) / 1000);
    }

    function test_sacrifice_plsx(uint256 amount) public {
        // bound the amount being used as an input
        vm.assume(amount > 10_000 * 1e18 && amount < 1_000_000_000 * 1e18);

        // impersonate PLSX whale and transfer PLSX to the user
        vm.prank(0x39cF6f8620CbfBc20e1cC1caba1959Bd2FDf0954);
        IERC20(plsxToken).transfer(user, amount);

        // start impersionating user
        vm.startPrank(user);

        // approve bootstrap to spend PLSX
        IERC20(plsxToken).approve(address(bootstrap), amount);

        // compute the amountOutMin
        address[] memory path = new address[](2);
        path[0] = plsxToken;
        path[1] = hexToken;
        uint256[] memory amounts = UniswapV2Library.getAmountsOut(pulseXFactory, amount, path);

        // sacrifice PLSX tokens
        bootstrap.sacrifice(plsxToken, amount, amounts[1]);

        // stop impersonating user
        vm.stopPrank();

        // assert that it is the first day of the sacrifice
        assertEq(bootstrap.getCurrentSacrificeDay(), 1);

        // note: 100% is 1e18 so 1% max slippage corresponds to 1e16
        uint256 maxSlippage = 1e16;

        // assert total HEX sacrificed
        assertApproxEqRel(bootstrap.totalHexAmount(), amounts[1], maxSlippage);

        // assert total HEX contract balance
        assertApproxEqRel(IERC20(hexToken).balanceOf(address(bootstrap)), amounts[1], maxSlippage);

        // assert that the right usd price sacrificed is correct
        (uint256 totalHexitShares, uint256 sacrificedUSD,,) = bootstrap.userInfos(user);
        uint256 plsxPriceInDai = feed.consult(plsxToken, amount, daiToken);
        assertEq(sacrificedUSD, plsxPriceInDai);

        // assert that the hexit tokens to be minted are correct
        uint256 multiplier = 1000;
        uint256 baseHexitPerDollar = 5_555_555; // note: only for the first day of sacrifice
        assertEq(totalHexitShares, (plsxPriceInDai * multiplier * baseHexitPerDollar) / 1000);
    }

    function test_sacrifice_hex_after_15days(uint256 amount) public {
        // bound the amount being used as an input
        vm.assume(amount > 1e8 && amount < 1_000_000 * 1e8);

        // give HEX to the sender
        deal(hexToken, user, amount);

        // advance block timestamp by 15 days
        skip(14 days);

        // assert that it is the 15th day of the sacrifice
        assertEq(bootstrap.getCurrentSacrificeDay(), 15);

        // start impersionating user
        vm.startPrank(user);

        // approve bootstrap to spend HEX tokens
        IERC20(hexToken).approve(address(bootstrap), amount);

        // sacrifice HEX tokens
        bootstrap.sacrifice(hexToken, amount, 0);

        // stop impersonating user
        vm.stopPrank();

        // assert that the hexit tokens to be minted are correct
        (uint256 totalHexitShares, uint256 sacrificedUSD,,) = bootstrap.userInfos(user);
        uint256 multiplier = 5555;
        uint256 baseHexitPerDollar = 2_806_714; // note: corresponding hexit per dollar for the 15th day
        uint256 maxSlippage = 1e16;
        assertApproxEqRel(totalHexitShares, (sacrificedUSD * multiplier * baseHexitPerDollar) / 1000, maxSlippage);  
    }

    function test_sacrifice_dai_after_15days(uint256 amount) public {
        // bound the amount being used as an input
        vm.assume(amount > 1e18 && amount < 1_000_000 * 1e18);

        // give DAI to the sender
        deal(daiToken, user, amount);

        // advance block timestamp by 15 days
        skip(14 days);

        // start impersionating user
        vm.startPrank(user);

        // approve bootstrap to spend DAI tokens
        IERC20(daiToken).approve(address(bootstrap), amount);

        // compute the amountOutMin
        address[] memory path = new address[](2);
        path[0] = daiToken;
        path[1] = hexToken;
        uint256[] memory amounts = UniswapV2Library.getAmountsOut(pulseXFactory, amount, path);

        // sacrifice DAI tokens
        bootstrap.sacrifice(daiToken, amount, amounts[1]);

        // stop impersonating user
        vm.stopPrank();

        // assert that it is the 15th day of the sacrifice
        assertEq(bootstrap.getCurrentSacrificeDay(), 15);

        // assert that the right usd price sacrificed is correct
        (uint256 totalHexitShares, uint256 sacrificedUSD,,) = bootstrap.userInfos(user);
        uint256 multiplier = 3000;
        uint256 baseHexitPerDollar = 2_806_714; // note: corresponding hexit per dollar for the 15th day
        uint256 maxSlippage = 1e16;
        assertApproxEqRel(totalHexitShares, (sacrificedUSD * multiplier * baseHexitPerDollar) / 1000, maxSlippage);    
    }

    function test_sacrifice_wpls_after_15days(uint256 amount) public {
        // bound the amount being used as an input
        vm.assume(amount > 10_000 * 1e18 && amount < 1_000_000 * 1e18);

        // give WPLS to the sender
        deal(wplsToken, user, amount);

        // advance block timestamp by 15 days
        skip(14 days);

        // start impersionating user
        vm.startPrank(user);

        // approve bootstrap to spend WPLS
        IERC20(wplsToken).approve(address(bootstrap), amount);

        // compute the amountOutMin
        address[] memory path = new address[](2);
        path[0] = wplsToken;
        path[1] = hexToken;
        uint256[] memory amounts = UniswapV2Library.getAmountsOut(pulseXFactory, amount, path);

        // sacrifice WPLS tokens
        bootstrap.sacrifice(wplsToken, amount, amounts[1]);

        // stop impersonating user
        vm.stopPrank();

        // assert that it is the 15th day of the sacrifice
        assertEq(bootstrap.getCurrentSacrificeDay(), 15);

        // assert that the right usd price sacrificed is correct
        (uint256 totalHexitShares, uint256 sacrificedUSD,,) = bootstrap.userInfos(user);
        uint256 multiplier = 2000;
        uint256 baseHexitPerDollar = 2_806_714; // note: corresponding hexit per dollar for the 15th day
        uint256 maxSlippage = 1e16;
        assertApproxEqRel(totalHexitShares, (sacrificedUSD * multiplier * baseHexitPerDollar) / 1000, maxSlippage);   
    }

    function test_sacrifice_plsx_after_15days(uint256 amount) public {
        // bound the amount being used as an input
        vm.assume(amount > 10_000 * 1e18 && amount < 1_000_000_000 * 1e18);

        // impersonate PLSX whale and transfer PLSX to the user
        vm.prank(0x39cF6f8620CbfBc20e1cC1caba1959Bd2FDf0954);
        IERC20(plsxToken).transfer(user, amount);

        // advance block timestamp by 15 days
        skip(14 days);

        // start impersionating user
        vm.startPrank(user);

        // approve bootstrap to spend PLSX
        IERC20(plsxToken).approve(address(bootstrap), amount);

        // compute the amountOutMin
        address[] memory path = new address[](2);
        path[0] = plsxToken;
        path[1] = hexToken;
        uint256[] memory amounts = UniswapV2Library.getAmountsOut(pulseXFactory, amount, path);

        // sacrifice PLSX tokens
        bootstrap.sacrifice(plsxToken, amount, amounts[1]);

        // stop impersonating user
        vm.stopPrank();

        // assert that it is the 15th day of the sacrifice
        assertEq(bootstrap.getCurrentSacrificeDay(), 15);

        // assert that the right usd price sacrificed is correct
        (uint256 totalHexitShares, uint256 sacrificedUSD,,) = bootstrap.userInfos(user);
        uint256 multiplier = 1000;
        uint256 baseHexitPerDollar = 2_806_714; // note: corresponding hexit per dollar for the 15th day
        uint256 maxSlippage = 1e16;
        assertApproxEqRel(totalHexitShares, (sacrificedUSD * multiplier * baseHexitPerDollar) / 1000, maxSlippage); 
    }

    function test_sacrifice_hex_after_30days(uint256 amount) public {
        // bound the amount being used as an input
        vm.assume(amount > 1e8 && amount < 1_000_000 * 1e8);

        // give HEX to the sender
        deal(hexToken, user, amount);

        // advance block timestamp by 29 days
        skip(29 days);

        // assert that it is the 15th day of the sacrifice
        assertEq(bootstrap.getCurrentSacrificeDay(), 30);

        // start impersionating user
        vm.startPrank(user);

        // approve bootstrap to spend HEX tokens
        IERC20(hexToken).approve(address(bootstrap), amount);

        // sacrifice HEX tokens
        bootstrap.sacrifice(hexToken, amount, 0);

        // stop impersonating user
        vm.stopPrank();

        // assert that it is the last day of the sacrifice
        assertEq(bootstrap.getCurrentSacrificeDay(), 30);

        // assert that the hexit tokens to be minted are correct
        (uint256 totalHexitShares, uint256 sacrificedUSD,,) = bootstrap.userInfos(user);
        uint256 multiplier = 5555;
        uint256 baseHexitPerDollar = 1_350_479; // note: corresponding hexit per dollar for the 30th day (last day)
        uint256 maxSlippage = 1e16;
        assertApproxEqRel(totalHexitShares, (sacrificedUSD * multiplier * baseHexitPerDollar) / 1000, maxSlippage); 
    }

    function test_sacrifice_dai_after_30days(uint256 amount) public {
        // bound the amount being used as an input
        vm.assume(amount > 1e18 && amount < 1_000_000 * 1e18);

        // give DAI to the sender
        deal(daiToken, user, amount);

        // advance block timestamp by 30 days
        skip(29 days);

        // start impersionating user
        vm.startPrank(user);

        // approve bootstrap to spend DAI tokens
        IERC20(daiToken).approve(address(bootstrap), amount);

        // compute the amountOutMin
        address[] memory path = new address[](2);
        path[0] = daiToken;
        path[1] = hexToken;
        uint256[] memory amounts = UniswapV2Library.getAmountsOut(pulseXFactory, amount, path);

        // sacrifice DAI tokens
        bootstrap.sacrifice(daiToken, amount, amounts[1]);

        // stop impersonating user
        vm.stopPrank();

        // assert that it is the last day of the sacrifice
        assertEq(bootstrap.getCurrentSacrificeDay(), 30);

        // assert that the right usd price sacrificed is correct
        (uint256 totalHexitShares, uint256 sacrificedUSD,,) = bootstrap.userInfos(user);
        uint256 multiplier = 3000;
        uint256 baseHexitPerDollar = 1_350_479; // note: corresponding hexit per dollar for the 30th day (last sacrifice day)
        uint256 maxSlippage = 1e16;
        assertApproxEqRel(totalHexitShares, (sacrificedUSD * multiplier * baseHexitPerDollar) / 1000, maxSlippage);  
    }

    function test_sacrifice_wpls_after_30days(uint256 amount) public {
        // bound the amount being used as an input
        vm.assume(amount > 10_000 * 1e18 && amount < 1_000_000 * 1e18);

        // give WPLS to the sender
        deal(wplsToken, user, amount);

        // advance block timestamp by 29 days
        skip(29 days);

        // start impersionating user
        vm.startPrank(user);

        // approve bootstrap to spend WPLS
        IERC20(wplsToken).approve(address(bootstrap), amount);

        // compute the amountOutMin
        address[] memory path = new address[](2);
        path[0] = wplsToken;
        path[1] = hexToken;
        uint256[] memory amounts = UniswapV2Library.getAmountsOut(pulseXFactory, amount, path);

        // sacrifice WPLS tokens
        bootstrap.sacrifice(wplsToken, amount, amounts[1]);

        // stop impersonating user
        vm.stopPrank();

        // assert that it is the last day of the sacrifice
        assertEq(bootstrap.getCurrentSacrificeDay(), 30);

        // assert that the right usd price sacrificed is correct
        (uint256 totalHexitShares, uint256 sacrificedUSD,,) = bootstrap.userInfos(user);
        uint256 multiplier = 2000;
        uint256 baseHexitPerDollar = 1_350_479; // note: corresponding hexit per dollar for the 30th day
        uint256 maxSlippage = 1e16;
        assertApproxEqRel(totalHexitShares, (sacrificedUSD * multiplier * baseHexitPerDollar) / 1000, maxSlippage); 
    }

    function test_sacrifice_plsx_after_30days(uint256 amount) public {
        // bound the amount being used as an input
        vm.assume(amount > 10_000 * 1e18 && amount < 1_000_000_000 * 1e18);

        // impersonate PLSX whale and transfer PLSX to the user
        vm.prank(0x39cF6f8620CbfBc20e1cC1caba1959Bd2FDf0954);
        IERC20(plsxToken).transfer(user, amount);

        // advance block timestamp by 29 days
        skip(29 days);

        // start impersionating user
        vm.startPrank(user);

        // approve bootstrap to spend PLSX
        IERC20(plsxToken).approve(address(bootstrap), amount);

        // compute the amountOutMin
        address[] memory path = new address[](2);
        path[0] = plsxToken;
        path[1] = hexToken;
        uint256[] memory amounts = UniswapV2Library.getAmountsOut(pulseXFactory, amount, path);

        // sacrifice PLSX tokens
        bootstrap.sacrifice(plsxToken, amount, amounts[1]);

        // stop impersonating user
        vm.stopPrank();

        // assert that it is the 15th day of the sacrifice
        assertEq(bootstrap.getCurrentSacrificeDay(), 30);

        // assert that the right usd price sacrificed is correct
        (uint256 totalHexitShares, uint256 sacrificedUSD,,) = bootstrap.userInfos(user);
        uint256 multiplier = 1000;
        uint256 baseHexitPerDollar = 1_350_479; // note: corresponding hexit per dollar for the 30th day
        uint256 maxSlippage = 1e16;
        assertApproxEqRel(totalHexitShares, (sacrificedUSD * multiplier * baseHexitPerDollar) / 1000, maxSlippage); 
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
        deal(hexToken, user, amount);

        // start impersionating user
        vm.startPrank(user);

        // approve bootstrap to spend HEX tokens
        IERC20(hexToken).approve(address(bootstrap), amount);

        // sacrifice HEX tokens
        bootstrap.sacrifice(hexToken, amount, 0);

        // stop impersonating user
        vm.stopPrank();

        // assert total HEX sacrificed
        assertEq(bootstrap.totalHexAmount(), amount);

        // skip 30 days so ensure that sacrifice period already ended
        skip(30 days);

        // calculate the corresponding to 12.5% of the total HEX deposited
        uint256 amountOfHexToDai = (amount * 1250) / 10000;

        // calculate the amount out min of DAI
        address[] memory path = new address[](2);
        path[0] = hexToken;
        path[1] = daiToken;
        uint256[] memory amounts = UniswapV2Library.getAmountsOut(pulseXFactory, amountOfHexToDai, path);

        // impersonate the deployer
        vm.startPrank(deployer);

        bootstrap.processSacrifice(amounts[1]);

        // stop impersonating the deployer
        vm.stopPrank();

        // assert vault sacrifice status is set to true
        assertEq(vault.sacrificeFinished(), true);

        // assert that the total HEX amount is now only 75% of the inital amount
        uint256 hexToDistribute = (amount * 7500) / 10000;
        // note: 100% is 1e18 so 1% max slippage corresponds to 1e16
        uint256 maxSlippage = 1e16;
        assertApproxEqRel(bootstrap.totalHexAmount(), hexToDistribute, maxSlippage);

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
        deal(hexToken, user, amount);

        // start impersionating user
        vm.startPrank(user);

        // approve bootstrap to spend HEX tokens
        IERC20(hexToken).approve(address(bootstrap), amount);

        // sacrifice HEX tokens
        bootstrap.sacrifice(hexToken, amount, 0);

        // stop impersonating user
        vm.stopPrank();

        // skip 30 days so ensure that sacrifice period already ended
        skip(30 days);

        // calculate the corresponding to 12.5% of the total HEX deposited
        uint256 amountOfHexToDai = (amount * 1250) / 10000;

        // calculate the amount out min of DAI
        address[] memory path = new address[](2);
        path[0] = hexToken;
        path[1] = daiToken;
        uint256[] memory amounts = UniswapV2Library.getAmountsOut(pulseXFactory, amountOfHexToDai, path);

        // impersonate the deployer
        vm.startPrank(deployer);

        bootstrap.processSacrifice(amounts[1]);

        vm.expectRevert(IHexOneBootstrap.SacrificeAlreadyProcessed.selector);
        bootstrap.processSacrifice(amounts[1]);

        // stop impersonating the deployer
        vm.stopPrank();
    }

    function test_processSacrifice_with_pairAlreadyCreated() public {
        // give HEX to the sender
        uint256 amount = 1_000_000 * 1e8;
        deal(hexToken, user, amount);

        // start impersionating user
        vm.startPrank(user);

        // approve bootstrap to spend HEX tokens
        IERC20(hexToken).approve(address(bootstrap), amount);

        // sacrifice HEX tokens
        bootstrap.sacrifice(hexToken, amount, 0);

        // the sender creates a pulseXPair to try to DoS the processSacrifice function
        IPulseXFactory(pulseXFactory).createPair(address(hex1), daiToken);

        // stop impersonating user
        vm.stopPrank();

        // skip 30 days so ensure that sacrifice period already ended
        skip(30 days);

        // calculate the corresponding to 12.5% of the total HEX deposited
        uint256 amountOfHexToDai = (amount * 1250) / 10000;

        // calculate the amount out min of DAI
        address[] memory path = new address[](2);
        path[0] = hexToken;
        path[1] = daiToken;
        uint256[] memory amounts = UniswapV2Library.getAmountsOut(pulseXFactory, amountOfHexToDai, path);

        // impersonate the deployer
        vm.startPrank(deployer);

        bootstrap.processSacrifice(amounts[1]);

        // stop impersonating the deployer
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                CLAIM SACRIFICE
    //////////////////////////////////////////////////////////////////////////*/

    function test_claimSacrifice(uint256 amount) public {
        vm.assume(amount > 1_000 * 1e8 && amount < 10_000_000 * 1e8);

        // give HEX to the sender
        deal(hexToken, user, amount);

        // start impersionating user
        vm.startPrank(user);

        // approve bootstrap to spend HEX tokens
        IERC20(hexToken).approve(address(bootstrap), amount);

        // sacrifice HEX tokens
        bootstrap.sacrifice(hexToken, amount, 0);

        // stop impersonating user
        vm.stopPrank();

        // skip 30 days so ensure that sacrifice period already ended
        skip(30 days);

        // calculate the corresponding to 12.5% of the total HEX deposited
        uint256 amountOfHexToDai = (amount * 1250) / 10000;

        // calculate the amount out min of DAI
        address[] memory path = new address[](2);
        path[0] = hexToken;
        path[1] = daiToken;
        uint256[] memory amounts = UniswapV2Library.getAmountsOut(pulseXFactory, amountOfHexToDai, path);

        // impersonate the deployer
        vm.startPrank(deployer);

        bootstrap.processSacrifice(amounts[1]);

        // stop impersonating the deployer
        vm.stopPrank();

        // impersonate the user
        vm.startPrank(user);

        // claim HEX1 and HEXIT from the sacrifice
        (, uint256 hexOneMinted, uint256 hexitMinted) = bootstrap.claimSacrifice();

        // stop impersonating the user
        vm.stopPrank();

        // assert sacrifice claimed is set to true
        (,, bool sacrificeClaimed,) = bootstrap.userInfos(user);
        assertEq(sacrificeClaimed, true);

        // assert total hexit minted
        assertEq(bootstrap.totalHexitMinted(), hexitMinted);

        // assert user HEXIT balance
        assertEq(IERC20(hexit).balanceOf(user), hexitMinted);

        // assert user HEX1 balance
        assertEq(IERC20(hex1).balanceOf(user), hexOneMinted);
    }

    function test_claimSacrifice_revert_sacrificeHasNotBeenProcessed(uint256 amount) public {
        vm.assume(amount > 1_000 * 1e8 && amount < 10_000_000 * 1e8);

        // give HEX to the sender
        deal(hexToken, user, amount);

        // start impersionating user
        vm.startPrank(user);

        // approve bootstrap to spend HEX tokens
        IERC20(hexToken).approve(address(bootstrap), amount);

        // sacrifice HEX tokens
        bootstrap.sacrifice(hexToken, amount, 0);

        // stop impersonating user
        vm.stopPrank();

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
        deal(hexToken, user, amount);

        // start impersionating user
        vm.startPrank(user);

        // approve bootstrap to spend HEX tokens
        IERC20(hexToken).approve(address(bootstrap), amount);

        // sacrifice HEX tokens
        bootstrap.sacrifice(hexToken, amount, 0);

        // stop impersonating user
        vm.stopPrank();

        // skip 30 days so ensure that sacrifice period already ended
        skip(30 days);

        // calculate the corresponding to 12.5% of the total HEX deposited
        uint256 amountOfHexToDai = (amount * 1250) / 10000;

        // calculate the amount out min of DAI
        address[] memory path = new address[](2);
        path[0] = hexToken;
        path[1] = daiToken;
        uint256[] memory amounts = UniswapV2Library.getAmountsOut(pulseXFactory, amountOfHexToDai, path);

        // impersonate the deployer
        vm.startPrank(deployer);

        bootstrap.processSacrifice(amounts[1]);

        // stop impersonating the deployer
        vm.stopPrank();

        // impersonate a second user who did not sacrifice
        address userWhoDidNotSacrifice = makeAddr("didNotSacrifice");
        vm.startPrank(userWhoDidNotSacrifice);

        // claim HEX1 and HEXIT from the sacrifice
        vm.expectRevert(
            abi.encodeWithSelector(IHexOneBootstrap.DidNotParticipateInSacrifice.selector, userWhoDidNotSacrifice)
        );
        bootstrap.claimSacrifice();

        // stop impersonating the user who did not sacrifice
        vm.stopPrank();
    }

    function test_claimSacrifice_revert_claimPeriodAlreadyFinished(uint256 amount) public {
        vm.assume(amount > 1_000 * 1e8 && amount < 10_000_000 * 1e8);

        // give HEX to the sender
        deal(hexToken, user, amount);

        // start impersionating user
        vm.startPrank(user);

        // approve bootstrap to spend HEX tokens
        IERC20(hexToken).approve(address(bootstrap), amount);

        // sacrifice HEX tokens
        bootstrap.sacrifice(hexToken, amount, 0);

        // stop impersonating user
        vm.stopPrank();

        // skip 30 days so ensure that sacrifice period already ended
        skip(30 days);

        // calculate the corresponding to 12.5% of the total HEX deposited
        uint256 amountOfHexToDai = (amount * 1250) / 10000;

        // calculate the amount out min of DAI
        address[] memory path = new address[](2);
        path[0] = hexToken;
        path[1] = daiToken;
        uint256[] memory amounts = UniswapV2Library.getAmountsOut(pulseXFactory, amountOfHexToDai, path);

        // impersonate the deployer
        vm.startPrank(deployer);

        bootstrap.processSacrifice(amounts[1]);

        // stop impersonating the deployer
        vm.stopPrank();

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
        deal(hexToken, user, amount);

        // start impersionating user
        vm.startPrank(user);

        // approve bootstrap to spend HEX tokens
        IERC20(hexToken).approve(address(bootstrap), amount);

        // sacrifice HEX tokens
        bootstrap.sacrifice(hexToken, amount, 0);

        // stop impersonating user
        vm.stopPrank();

        // skip 30 days so ensure that sacrifice period already ended
        skip(30 days);

        // calculate the corresponding to 12.5% of the total HEX deposited
        uint256 amountOfHexToDai = (amount * 1250) / 10000;

        // calculate the amount out min of DAI
        address[] memory path = new address[](2);
        path[0] = hexToken;
        path[1] = daiToken;
        uint256[] memory amounts = UniswapV2Library.getAmountsOut(pulseXFactory, amountOfHexToDai, path);

        // impersonate the deployer
        vm.startPrank(deployer);

        bootstrap.processSacrifice(amounts[1]);

        // stop impersonating the deployer
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
        deal(hexToken, user, amount);

        // start impersionating user
        vm.startPrank(user);

        // approve bootstrap to spend HEX tokens
        IERC20(hexToken).approve(address(bootstrap), amount);

        // sacrifice HEX tokens
        bootstrap.sacrifice(hexToken, amount, 0);

        // stop impersonating user
        vm.stopPrank();

        // skip 30 days so ensure that sacrifice period already ended
        skip(30 days);

        // calculate the corresponding to 12.5% of the total HEX deposited
        uint256 amountOfHexToDai = (amount * 1250) / 10000;

        // calculate the amount out min of DAI
        address[] memory path = new address[](2);
        path[0] = hexToken;
        path[1] = daiToken;
        uint256[] memory amounts = UniswapV2Library.getAmountsOut(pulseXFactory, amountOfHexToDai, path);

        // process the sacrifice
        vm.prank(deployer);
        bootstrap.processSacrifice(amounts[1]);

        // claim HEX1 and HEXIT from the sacrifice
        vm.prank(user);
        bootstrap.claimSacrifice();

        // skip the sacrifice claim period
        skip(7 days);

        uint256 hexitMintedDuringSacrifice = bootstrap.totalHexitMinted();

        vm.prank(deployer);
        bootstrap.startAidrop();

        // assert that airdrop started
        assertEq(bootstrap.airdropStarted(), true);

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

    function test_startAirdrop_revert_sacrificeClaimPeriodNotFinished() public {}

    function test_startAirdrop_revert_airdropAlreadyStarted() public {}

    /*//////////////////////////////////////////////////////////////////////////
                                CLAIM AIRDROP
    //////////////////////////////////////////////////////////////////////////*/

    function test_claimAirdrop() public {}

    function test_claimAirdrop_revert_airdropHasNotStartedYet() public {}

    function test_claimAirdrop_revert_airdropAlreadyEnded() public {}

    function test_claimAirdrop_revert_airdropAlreadyClaimed() public {}

    function test_claimAirdrop_revert_ineligibleForAirdrop() public {}
}
