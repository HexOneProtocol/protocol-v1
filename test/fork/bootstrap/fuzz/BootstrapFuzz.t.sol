// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import "../../Base.t.sol";

import {BootstrapHelper} from "../../utils/BootstrapHelper.sol";

/**
 *  @dev forge test --match-contract BootstrapFuzzTest -vvv
 */
contract BootstrapFuzzTest is BootstrapHelper {
    /*//////////////////////////////////////////////////////////////////////////
                                    SACRIFICE
    //////////////////////////////////////////////////////////////////////////*/

    function test_sacrifice_hex(uint256 amount) public {
        // bound the amount being used as an input
        amount = bound(amount, 1e8, 1_000_000 * 1e8);

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
        uint256 multiplier = 55555;
        uint256 baseHexitPerDollar = 5_555_555 * 1e18;
        uint256 expectedHexitShares = (hexPriceInDai * baseHexitPerDollar) / 1e18;
        expectedHexitShares = (expectedHexitShares * multiplier) / 10_000;
        assertEq(totalHexitShares, expectedHexitShares);
    }

    function test_sacrifice_dai(uint256 amount) public {
        // bound the amount being used as an input
        amount = bound(amount, 1e18, 1_000_000 * 1e18);

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
        amount = bound(amount, 10_000 * 1e18, 10_000_000 * 1e18);

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
        amount = bound(amount, 10_000 * 1e18, 1_000_000_000 * 1e18);

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
        amount = bound(amount, 1e8, 1_000_000 * 1e8);

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
        amount = bound(amount, 1e18, 1_000_000 * 1e18);

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
        amount = bound(amount, 10_000 * 1e18, 10_000_000 * 1e18);

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
        amount = bound(amount, 10_000 * 1e18, 1_000_000_000 * 1e18);

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
        amount = bound(amount, 1e8, 1_000_000 * 1e8);

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
        amount = bound(amount, 1e18, 1_000_000 * 1e18);

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
        amount = bound(amount, 10_000 * 1e18, 10_000_000 * 1e18);

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
        amount = bound(amount, 10_000 * 1e18, 1_000_000_000 * 1e18);

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

    /*//////////////////////////////////////////////////////////////////////////
                                PROCESS SACRIFICE
    //////////////////////////////////////////////////////////////////////////*/

    function test_processSacrifice(uint256 amount) public {
        amount = bound(amount, 1_000 * 1e8, 10_000_000 * 1e8);

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

    /*//////////////////////////////////////////////////////////////////////////
                                CLAIM SACRIFICE
    //////////////////////////////////////////////////////////////////////////*/

    function test_claimSacrifice(uint256 amount) public {
        amount = bound(amount, 1_000 * 1e8, 10_000_000 * 1e8);

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

    /*//////////////////////////////////////////////////////////////////////////
                                START AIRDROP
    //////////////////////////////////////////////////////////////////////////*/

    function test_startAirdrop(uint256 amount) public {
        amount = bound(amount, 1_000 * 1e8, 10_000_000 * 1e8);

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

    /*//////////////////////////////////////////////////////////////////////////
                                CLAIM AIRDROP
    //////////////////////////////////////////////////////////////////////////*/

    function test_claimAirdrop_onlyHexStaker(uint256 amount, uint256 amountHexStaked) public {
        amount = bound(amount, 1_000 * 1e8, 10_000_000 * 1e8);
        amountHexStaked = bound(amountHexStaked, 100 * 1e8, 100_000 * 1e8);

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
        vm.prank(deployer);
        bootstrap.startAirdrop();

        // HEX staker stakes HEX tokens to that he can be eligible to claim the airdrop
        address staker = makeAddr("HEX staker");
        deal(hexToken, staker, amountHexStaked);

        vm.startPrank(staker);

        IHexToken(hexToken).stakeStart(amountHexStaked, 5555);
        bootstrap.claimAirdrop();

        vm.stopPrank();

        // assert user info
        (,,, bool claimedAirdrop) = bootstrap.userInfos(staker);
        assertEq(claimedAirdrop, true);

        // assert HEXIT minted
        uint256 realHexAmountStaked = _getHexStaked(staker);
        uint256 amountOut = feed.consult(hexToken, realHexAmountStaked, daiToken);
        assertEq(hexit.balanceOf(staker), amountOut + bootstrap.AIRDROP_HEXIT_INIT_AMOUNT());
    }

    function test_claimAirdrop_onlyHexStaker_after_15days(uint256 amount, uint256 amountHexStaked) public {
        amount = bound(amount, 1_000 * 1e8, 10_000_000 * 1e8);
        amountHexStaked = bound(amountHexStaked, 100 * 1e8, 100_000 * 1e8);

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
        vm.prank(deployer);
        bootstrap.startAirdrop();

        // HEX staker stakes HEX tokens to that he can be eligible to claim the airdrop
        address staker = makeAddr("HEX staker");
        deal(hexToken, staker, amountHexStaked);

        // skip the first 15 days of the airdrop claim period
        skip(14 days);

        vm.startPrank(staker);

        IHexToken(hexToken).stakeStart(amountHexStaked, 5555);
        bootstrap.claimAirdrop();

        vm.stopPrank();

        // assert user info
        (,,, bool claimedAirdrop) = bootstrap.userInfos(staker);
        assertEq(claimedAirdrop, true);

        // assert HEXIT minted
        uint256 realHexAmountStaked = _getHexStaked(staker);
        uint256 amountOut = feed.consult(hexToken, realHexAmountStaked, daiToken);
        uint256 baseHexit = 170 * 1e18;
        uint256 maxSlippage = 1e16;
        assertApproxEqRel(hexit.balanceOf(staker), amountOut + baseHexit, maxSlippage);
    }

    function test_claimAirdrop_onlyHexStaker_after_30days(uint256 amount, uint256 amountHexStaked) public {
        amount = bound(amount, 1_000 * 1e8, 10_000_000 * 1e8);
        amountHexStaked = bound(amountHexStaked, 100 * 1e8, 100_000 * 1e8);

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
        vm.prank(deployer);
        bootstrap.startAirdrop();

        // HEX staker stakes HEX tokens to that he can be eligible to claim the airdrop
        address staker = makeAddr("HEX staker");
        deal(hexToken, staker, amountHexStaked);

        // skip the first 15 days of the airdrop claim period
        skip(29 days);

        vm.startPrank(staker);

        IHexToken(hexToken).stakeStart(amountHexStaked, 5555);
        bootstrap.claimAirdrop();

        vm.stopPrank();

        // assert user info
        (,,, bool claimedAirdrop) = bootstrap.userInfos(staker);
        assertEq(claimedAirdrop, true);

        // assert HEXIT minted
        uint256 realHexAmountStaked = _getHexStaked(staker);
        uint256 amountOut = feed.consult(hexToken, realHexAmountStaked, daiToken);
        uint256 baseHexit = 517 * 1e13;
        uint256 maxSlippage = 1e16;
        assertApproxEqRel(hexit.balanceOf(staker), amountOut + baseHexit, maxSlippage);
    }

    function test_claimAirdrop_onlySacrificeParticipant(uint256 amount) public {
        amount = bound(amount, 1_000 * 1e8, 10_000_000 * 1e8);

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
        vm.prank(deployer);
        bootstrap.startAirdrop();

        uint256 userHexitBalanceBefore = hexit.balanceOf(user);

        // sacrifice participant tries to claim the airdrop
        vm.prank(user);
        bootstrap.claimAirdrop();

        // assert user info
        (, uint256 sacrificedUSD,, bool claimedAirdrop) = bootstrap.userInfos(user);
        assertEq(claimedAirdrop, true);

        // assert HEXIT claimed
        uint256 baseHexit = bootstrap.AIRDROP_HEXIT_INIT_AMOUNT();
        assertEq(hexit.balanceOf(user), userHexitBalanceBefore + (sacrificedUSD * 9 + baseHexit));
    }

    function test_claimAirdrop_onlySacrificeParticipant_after_15days(uint256 amount) public {
        amount = bound(amount, 1_000 * 1e8, 10_000_000 * 1e8);

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
        vm.prank(deployer);
        bootstrap.startAirdrop();

        uint256 userHexitBalanceBefore = hexit.balanceOf(user);

        // skip half of the airdrop claim period
        skip(14 days);

        // sacrifice participant tries to claim the airdrop
        vm.prank(user);
        bootstrap.claimAirdrop();

        // assert user info
        (, uint256 sacrificedUSD,, bool claimedAirdrop) = bootstrap.userInfos(user);
        assertEq(claimedAirdrop, true);

        // assert HEXIT claimed
        uint256 baseHexit = 170 * 1e18;
        uint256 maxSlippage = 1e16;
        assertApproxEqRel(hexit.balanceOf(user), userHexitBalanceBefore + (sacrificedUSD * 9 + baseHexit), maxSlippage);
    }

    function test_claimAirdrop_onlySacrificeParticipant_after_30days(uint256 amount) public {
        amount = bound(amount, 1_000 * 1e8, 10_000_000 * 1e8);

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
        vm.prank(deployer);
        bootstrap.startAirdrop();

        uint256 userHexitBalanceBefore = hexit.balanceOf(user);

        // skip to the last day of the airdrop claim period
        skip(29 days);

        // sacrifice participant tries to claim the airdrop
        vm.prank(user);
        bootstrap.claimAirdrop();

        // assert user info
        (, uint256 sacrificedUSD,, bool claimedAirdrop) = bootstrap.userInfos(user);
        assertEq(claimedAirdrop, true);

        // assert HEXIT claimed
        uint256 baseHexit = 517 * 1e13;
        uint256 maxSlippage = 1e16;
        assertApproxEqRel(hexit.balanceOf(user), userHexitBalanceBefore + (sacrificedUSD * 9 + baseHexit), maxSlippage);
    }

    function test_claimAirdrop_hexStakerAndSacrificeParticipant(uint256 amount, uint256 amountHexStaked) public {
        amount = bound(amount, 1_000 * 1e8, 10_000_000 * 1e8);
        amountHexStaked = bound(amountHexStaked, 100 * 1e8, 100_000 * 1e8);

        // give HEX to the sender
        _dealToken(hexToken, user, amount + amountHexStaked);

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
        vm.prank(deployer);
        bootstrap.startAirdrop();

        // user stakes HEX to get a bigger allocation in the HEXIT airdrop
        uint256 userHexitBalanceBefore = hexit.balanceOf(user);
        vm.startPrank(user);

        IHexToken(hexToken).stakeStart(amountHexStaked, 5555);
        bootstrap.claimAirdrop();

        vm.stopPrank();

        // assert user info
        (, uint256 sacrificedUSD,, bool claimedAirdrop) = bootstrap.userInfos(user);
        assertEq(claimedAirdrop, true);

        // assert HEXIT minted
        uint256 realHexAmountStaked = _getHexStaked(user);
        uint256 amountOut = feed.consult(hexToken, realHexAmountStaked, daiToken);
        assertEq(
            hexit.balanceOf(user),
            userHexitBalanceBefore + (sacrificedUSD * 9) + amountOut + bootstrap.AIRDROP_HEXIT_INIT_AMOUNT()
        );
    }

    function test_claimAirdrop_hexStakerAndSacrificeParticipant_after_15_days(uint256 amount, uint256 amountHexStaked)
        public
    {
        amount = bound(amount, 1_000 * 1e8, 10_000_000 * 1e8);
        amountHexStaked = bound(amountHexStaked, 100 * 1e8, 100_000 * 1e8);

        // give HEX to the sender
        _dealToken(hexToken, user, amount + amountHexStaked);

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
        vm.prank(deployer);
        bootstrap.startAirdrop();

        // skip half of the airdrop claim period
        skip(14 days);

        // user stakes HEX to get a bigger allocation in the HEXIT airdrop
        uint256 userHexitBalanceBefore = hexit.balanceOf(user);
        vm.startPrank(user);

        IHexToken(hexToken).stakeStart(amountHexStaked, 5555);
        bootstrap.claimAirdrop();

        vm.stopPrank();

        // assert user info
        (, uint256 sacrificedUSD,, bool claimedAirdrop) = bootstrap.userInfos(user);
        assertEq(claimedAirdrop, true);

        // assert HEXIT minted
        uint256 realHexAmountStaked = _getHexStaked(user);
        uint256 amountOut = feed.consult(hexToken, realHexAmountStaked, daiToken);
        uint256 baseHexit = 170 * 1e18;
        uint256 maxSlippage = 1e16;
        assertApproxEqRel(
            hexit.balanceOf(user), userHexitBalanceBefore + (sacrificedUSD * 9) + amountOut + baseHexit, maxSlippage
        );
    }

    function test_claimAirdrop_hexStakerAndSacrificeParticipant_after_30_days(uint256 amount, uint256 amountHexStaked)
        public
    {
        amount = bound(amount, 1_000 * 1e8, 10_000_000 * 1e8);
        amountHexStaked = bound(amountHexStaked, 100 * 1e8, 100_000 * 1e8);

        // give HEX to the sender
        _dealToken(hexToken, user, amount + amountHexStaked);

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
        vm.prank(deployer);
        bootstrap.startAirdrop();

        // skip to the last day of the airdrop claim period
        skip(29 days);

        // user stakes HEX to get a bigger allocation in the HEXIT airdrop
        uint256 userHexitBalanceBefore = hexit.balanceOf(user);
        vm.startPrank(user);

        IHexToken(hexToken).stakeStart(amountHexStaked, 5555);
        bootstrap.claimAirdrop();

        vm.stopPrank();

        // assert user info
        (, uint256 sacrificedUSD,, bool claimedAirdrop) = bootstrap.userInfos(user);
        assertEq(claimedAirdrop, true);

        // assert HEXIT minted
        uint256 realHexAmountStaked = _getHexStaked(user);
        uint256 amountOut = feed.consult(hexToken, realHexAmountStaked, daiToken);
        uint256 baseHexit = 517 * 1e13;
        uint256 maxSlippage = 1e16;
        assertApproxEqRel(
            hexit.balanceOf(user), userHexitBalanceBefore + (sacrificedUSD * 9) + amountOut + baseHexit, maxSlippage
        );
    }
}
