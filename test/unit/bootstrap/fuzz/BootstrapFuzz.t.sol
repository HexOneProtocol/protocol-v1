// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import "../../../Base.t.sol";

import {BootstrapHelper} from "../BootstrapHelper.sol";

/**
 *  @dev forge test --match-contract BootstrapFuzzTest --rpc-url "https://rpc.pulsechain.com" -vvv
 */
contract BootstrapFuzzTest is BootstrapHelper {
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

    /*//////////////////////////////////////////////////////////////////////////
                                CLAIM AIRDROP
    //////////////////////////////////////////////////////////////////////////*/

    function test_claimAirdrop_hexStakerAndSacrificeParticipant(uint256 amount) public {
        // vm.assume(amount > 1_000 * 1e8 && amount < 10_000_000 * 1e8);

        // // give HEX to the sender
        // _dealToken(hexToken, user, amount * 2);

        // // user sacrifices HEX
        // vm.startPrank(user);
        // _sacrifice(hexToken, amount);
        // vm.stopPrank();

        // // assert total HEX sacrificed
        // assertEq(bootstrap.totalHexAmount(), amount);

        // // skip 30 days so ensure that sacrifice period already ended
        // skip(30 days);

        // // calculate the corresponding to 12.5% of the total HEX deposited
        // uint256 amountOfHexToDai = (amount * 1250) / 10000;

        // // deployer processes the sacrifice
        // vm.startPrank(deployer);
        // _processSacrifice(amountOfHexToDai);
        // vm.stopPrank();

        // // user claims HEX1 and HEXIT from the sacrifice
        // vm.startPrank(user);
        // bootstrap.claimSacrifice();
        // vm.stopPrank();

        // // skip the sacrifice claim period
        // skip(7 days);

        // // user creates a new HEX stake so that he is eligible to claim more HEXIT
        // vm.prank(user);
        // IHexToken(hexToken).stakeStart(amount, 5555);

        // // start the airdrop
        // vm.prank(deployer);
        // bootstrap.startAirdrop();

        // // store the total HEXIT minted by the bootstrap after starting the airdrop
        // uint256 totalHexitBalanceBefore = IERC20(hexit).balanceOf(user);

        // // store the user HEXIT balance before claiming the airdrop
        // uint256 userHexitBalanceBefore = IERC20(hexit).balanceOf(user);

        // // users claims airdrop
        // vm.prank(user);
        // bootstrap.claimAirdrop();

        // // assert total HEXIT minted
        // (, uint256 sacrificedUSD,, bool claimedAirdrop) = bootstrap.userInfos(user);

        // // assert that user claimed the airdrop
        // assertEq(claimedAirdrop, true);

        // // assert user HEXIT balance
        // uint256 hexitBalanceAfter = IERC20(hexit).balanceOf(user);
    }

    function test_claimAirdrop_onlyHexStaker(uint256 amount) public {

    }

    function test_claimAirdrop_onlySacrificeParticipant(uint256 amount) public {

    }

    function test_claimAirdrop_after_15days(uint256 amount) public {

    }

    function test_claimAirdrop_after_30days(uint256 amount) public {

    }
}
