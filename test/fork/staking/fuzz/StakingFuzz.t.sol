// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import "../../Base.t.sol";

import {StakingHelper} from "../../utils/StakingHelper.sol";

/**
 *  @dev forge test --match-contract StakingFuzzTest -vvv
 */
contract StakingFuzzTest is StakingHelper {
    /*//////////////////////////////////////////////////////////////////////////
                                    SETUP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public override {
        super.setUp();

        // initial purchase amounts
        uint256 hexInitialPurchase = 1000 * 1e8;
        uint256 hexitInitialPurchase = 2000 * 1e18;
        _initialPurchase(hexInitialPurchase, hexitInitialPurchase);

        // after purchases are made the bootstrap enables staking
        vm.prank(address(bootstrap));
        staking.enableStaking();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    PURCHASE
    //////////////////////////////////////////////////////////////////////////*/

    function test_purchase_hex(uint256 amount) public {
        // bound HEX amount
        amount = bound(amount, 1e8, 10_000_000 * 1e8);

        uint256 stakingHexBalanceBefore = IERC20(hexToken).balanceOf(address(staking));

        // give HEX to the vault
        deal(hexToken, address(vault), amount);

        // vault add HEX to the staking contract
        vm.startPrank(address(vault));

        IERC20(hexToken).approve(address(staking), amount);
        staking.purchase(hexToken, amount);

        vm.stopPrank();

        // assert pool total assets
        (uint256 totalAssets,,, uint256 currentStakingDay,) = staking.pools(hexToken);
        assertEq(totalAssets - stakingHexBalanceBefore, amount);
        assertEq(currentStakingDay, 0);

        // assert pool balance
        uint256 stakingHexBalanceAfter = IERC20(hexToken).balanceOf(address(staking));
        assertEq(stakingHexBalanceAfter - stakingHexBalanceBefore, amount);
    }

    function test_purchase_hex_afterInactivityDays_zeroShares(uint256 amount, uint256 inactivity) public {
        // bound the HEX amount
        amount = bound(amount, 1e18, 10_000_000 * 1e18);
        // bound inactivity between 1 and 120 days
        inactivity = bound(inactivity, 1 days, 120 days);

        uint256 stakingHexBalanceBefore = IERC20(hexToken).balanceOf(address(staking));

        // give HEX to the vault
        deal(hexToken, address(vault), amount);

        // advance the block timestamp
        skip(inactivity);

        // vault add HEX to the staking contract
        vm.startPrank(address(vault));

        IERC20(hexToken).approve(address(staking), amount);
        staking.purchase(hexToken, amount);

        vm.stopPrank();

        // assert pool history
        uint256 stakingDays = staking.getCurrentStakingDay();
        for (uint256 i = 0; i < stakingDays; i++) {
            (, uint256 totalShares, uint256 amountToDistribute) = staking.poolHistory(i, hexToken);
            assertEq(totalShares, 0);
            assertEq(amountToDistribute, 0);
        }

        // assert pool info
        (uint256 totalAssets,,, uint256 currentStakingDay,) = staking.pools(hexToken);
        assertEq(totalAssets - stakingHexBalanceBefore, amount);
        assertEq(currentStakingDay, stakingDays);
    }

    function test_purchase_hexit(uint256 amount) public {
        // bound the HEXIT amount
        amount = bound(amount, 1e18, 10_000_000 * 1e18);

        uint256 stakingHexitBalanceBefore = hexit.balanceOf(address(staking));

        // give HEXIT to the bootstrap
        deal(address(hexit), address(bootstrap), amount);

        // bootstrap adds HEXIT to the staking contract
        vm.startPrank(address(bootstrap));

        hexit.approve(address(staking), amount);
        staking.purchase(address(hexit), amount);

        vm.stopPrank();

        // assert pool info
        (uint256 totalAssets,,, uint256 currentStakingDay,) = staking.pools(address(hexit));
        assertEq(totalAssets - stakingHexitBalanceBefore, amount);
        assertEq(currentStakingDay, 0);

        // assert pool balance
        uint256 stakingHexitBalanceAfter = hexit.balanceOf(address(staking));
        assertEq(stakingHexitBalanceAfter - stakingHexitBalanceBefore, amount);
    }

    function test_purchase_hexit_afterInactivityDays_zeroShares(uint256 amount, uint256 inactivity) public {
        // bound the HEXIT amount
        amount = bound(amount, 1e18, 10_000_000 * 1e18);
        // bound inactivity between 1 and 120 days
        inactivity = bound(inactivity, 1 days, 120 days);

        uint256 stakingHexitBalanceBefore = hexit.balanceOf(address(staking));

        // give HEXIT to the bootstrap
        deal(address(hexit), address(bootstrap), amount);

        // advance the block timestamp
        skip(inactivity);

        // bootstrap adds HEXIT to the staking contract
        vm.startPrank(address(bootstrap));

        hexit.approve(address(staking), amount);
        staking.purchase(address(hexit), amount);

        vm.stopPrank();

        // assert pool history
        uint256 stakingDays = staking.getCurrentStakingDay();
        for (uint256 i = 0; i < stakingDays; i++) {
            (, uint256 totalShares, uint256 amountToDistribute) = staking.poolHistory(i, address(hexit));
            assertEq(totalShares, 0);
            assertEq(amountToDistribute, 0);
        }

        // assert pool info
        (uint256 totalAssets,,, uint256 currentStakingDay,) = staking.pools(address(hexit));
        assertEq(totalAssets - stakingHexitBalanceBefore, amount);
        assertEq(currentStakingDay, stakingDays);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    STAKE
    //////////////////////////////////////////////////////////////////////////*/

    function test_stake_hexOneDai(uint256 amount) public {
        // bound HEX1/DAI LP token amount
        amount = bound(amount, 1e18, 1_000_000 * 1e18);

        // deal HEX1/DAI LP to the user
        deal(hexOneDaiPair, user, amount);

        // user stakes HEX1/DAI LP
        vm.startPrank(user);

        IERC20(hexOneDaiPair).approve(address(staking), amount);
        staking.stake(hexOneDaiPair, amount);

        vm.stopPrank();

        // assert HEX pool history
        (, uint256 hexPoolHistoryShares, uint256 hexAmountToDistribute) = staking.poolHistory(0, hexToken);
        assertEq(hexPoolHistoryShares, 0);
        assertEq(hexAmountToDistribute, 0);

        // assert HEXIT pool history
        (, uint256 hexitPoolHistoryShares, uint256 hexitAmountToDistribute) = staking.poolHistory(0, address(hexit));
        assertEq(hexitPoolHistoryShares, 0);
        assertEq(hexitAmountToDistribute, 0);

        // assert total HEX1/DAI staked amount
        uint256 hexOneDaiAmount = staking.totalStakedAmount(hexOneDaiPair);
        assertEq(hexOneDaiAmount, amount);

        // convert HEX1/DAI deposited amount to pool shares
        uint256 shares = (_convertToShares(hexOneDaiPair, amount) * 700) / 1000;

        // assert HEX pool total shares
        (,, uint256 hexPoolTotalShares,,) = staking.pools(hexToken);
        assertEq(hexPoolTotalShares, shares);

        // assert HEXIT pool total shares
        (,, uint256 hexitPoolTotalShares,,) = staking.pools(address(hexit));
        assertEq(hexitPoolTotalShares, shares);

        // assert user stake information
        (
            uint256 stakedAmount,
            uint256 initStakeDay,
            ,
            uint256 lastDepositedDay,
            uint256 hexSharesAmount,
            uint256 hexitSharesAmount,
            ,
            ,
            ,
        ) = staking.stakingInfos(user, hexOneDaiPair);
        assertEq(stakedAmount, amount);
        assertEq(initStakeDay, 0);
        assertEq(lastDepositedDay, 0);
        assertEq(hexSharesAmount, shares);
        assertEq(hexitSharesAmount, shares);
    }

    function test_stake_hexOneDai_increaseStake(uint256 amountToIncrease) public {
        // bound the amount of HEX1/DAI to increase staking
        amountToIncrease = bound(amountToIncrease, 1e18, 1_000_000 * 1e18);

        // deal HEX1/DAI LP to the user
        uint256 amount = 100_000 * 1e18;
        deal(hexOneDaiPair, user, amount);

        // user stakes HEX1/DAI LP
        vm.startPrank(user);

        IERC20(hexOneDaiPair).approve(address(staking), amount);
        staking.stake(hexOneDaiPair, amount);

        vm.stopPrank();

        // deal HEX1/DAI LP to the user so that he can increase its stake
        deal(hexOneDaiPair, user, amountToIncrease);

        // user wants to increase its stake of HEX1/DAI
        vm.startPrank(user);

        IERC20(hexOneDaiPair).approve(address(staking), amountToIncrease);
        staking.stake(hexOneDaiPair, amountToIncrease);

        vm.stopPrank();

        // assert HEX pool history
        (, uint256 hexPoolHistoryShares, uint256 hexAmountToDistribute) = staking.poolHistory(0, hexToken);
        assertEq(hexPoolHistoryShares, 0);
        assertEq(hexAmountToDistribute, 0);

        // assert HEXIT pool history
        (, uint256 hexitPoolHistoryShares, uint256 hexitAmountToDistribute) = staking.poolHistory(0, address(hexit));
        assertEq(hexitPoolHistoryShares, 0);
        assertEq(hexitAmountToDistribute, 0);

        // assert total HEX1/DAI staked amount
        uint256 hexOneDaiAmount = staking.totalStakedAmount(hexOneDaiPair);
        assertEq(hexOneDaiAmount, amount + amountToIncrease);

        // convert HEX1/DAI deposited amount to pool shares
        uint256 shares = (_convertToShares(hexOneDaiPair, amount + amountToIncrease) * 700) / 1000;

        // assert HEX pool total shares
        (,, uint256 hexPoolTotalShares,,) = staking.pools(hexToken);
        assertEq(hexPoolTotalShares, shares);

        // assert HEXIT pool total shares
        (,, uint256 hexitPoolTotalShares,,) = staking.pools(address(hexit));
        assertEq(hexitPoolTotalShares, shares);

        // assert user stake information
        (uint256 stakedAmount,,,, uint256 hexSharesAmount, uint256 hexitSharesAmount,,,,) =
            staking.stakingInfos(user, hexOneDaiPair);
        assertEq(stakedAmount, amount + amountToIncrease);
        assertEq(hexSharesAmount, shares);
        assertEq(hexitSharesAmount, shares);
    }

    function test_stake_hexOneDai_increaseStake_afterDays(uint256 amountToIncrease, uint256 intervalDays) public {
        // bound the amount of HEX1/DAI to increase staking
        amountToIncrease = bound(amountToIncrease, 1e18, 1_000_000 * 1e18);

        // bound the amount of days that passed between the first and second time the user staked.
        intervalDays = bound(intervalDays, 1 days, 120 days);

        // deal HEX1/DAI LP to the user
        uint256 amount = 100_000 * 1e18;
        deal(hexOneDaiPair, user, amount);

        // user stakes HEX1/DAI LP
        vm.startPrank(user);

        IERC20(hexOneDaiPair).approve(address(staking), amount);
        staking.stake(hexOneDaiPair, amount);

        vm.stopPrank();

        // skip interval days between stakes
        skip(intervalDays);
        uint256 currentStakingDay = staking.getCurrentStakingDay();
        // deal HEX1/DAI to the user so that he can stake more
        deal(hexOneDaiPair, user, amountToIncrease);

        // user increases its stake after interval days have passed since the first stake
        vm.startPrank(user);

        IERC20(hexOneDaiPair).approve(address(staking), amountToIncrease);
        staking.stake(hexOneDaiPair, amountToIncrease);

        vm.stopPrank();

        // assert HEX pool history
        uint256 hexAmountToDistribute;
        for (uint256 i = 0; i < currentStakingDay; i++) {
            (,, uint256 amountToDistribute) = staking.poolHistory(i, hexToken);
            console.log("amount to distribute in day ", i, " :", amountToDistribute);
            hexAmountToDistribute += amountToDistribute;
        }

        // assert HEXIT pool history
        uint256 hexitAmountToDistribute;
        for (uint256 i = 0; i < currentStakingDay; i++) {
            (,, uint256 amountToDistribute) = staking.poolHistory(i, address(hexit));
            hexitAmountToDistribute += amountToDistribute;
        }

        // assert total HEX1/DAI staked amount
        uint256 hexOneDaiAmount = staking.totalStakedAmount(hexOneDaiPair);
        assertEq(hexOneDaiAmount, amount + amountToIncrease);

        // convert HEX1/DAI deposited amount to pool shares
        uint256 shares = (_convertToShares(hexOneDaiPair, amount + amountToIncrease) * 700) / 1000;

        {
            // assert HEX pool total shares and distributed amounts
            (, uint256 distributedHex, uint256 hexPoolTotalShares,,) = staking.pools(hexToken);
            assertEq(hexAmountToDistribute, distributedHex);
            assertEq(hexPoolTotalShares, shares);

            // assert HEXIT pool total shares and distributed amounts
            (, uint256 distributedHexit, uint256 hexitPoolTotalShares,,) = staking.pools(address(hexit));
            assertEq(hexitAmountToDistribute, distributedHexit);
            assertEq(hexitPoolTotalShares, shares);
        }

        // assert user stake information
        (uint256 stakedAmount,,, uint256 lastDepositedDay, uint256 hexSharesAmount, uint256 hexitSharesAmount,,,,) =
            staking.stakingInfos(user, hexOneDaiPair);
        assertEq(stakedAmount, amount + amountToIncrease);
        assertEq(lastDepositedDay, staking.getCurrentStakingDay());
        assertEq(hexSharesAmount, shares);
        assertEq(hexitSharesAmount, shares);
    }

    function test_stake_hexOne(uint256 amount) public {
        // bound HEX1 token amount
        amount = bound(amount, 1e18, 1_000_000 * 1e18);

        // deal HEX1 to the user
        deal(address(hex1), user, amount);

        // user stakes HEX1
        vm.startPrank(user);

        hex1.approve(address(staking), amount);
        staking.stake(address(hex1), amount);

        vm.stopPrank();

        // assert HEX pool history
        (, uint256 hexPoolHistoryShares, uint256 hexAmountToDistribute) = staking.poolHistory(0, hexToken);
        assertEq(hexPoolHistoryShares, 0);
        assertEq(hexAmountToDistribute, 0);

        // assert HEXIT pool history
        (, uint256 hexitPoolHistoryShares, uint256 hexitAmountToDistribute) = staking.poolHistory(0, address(hexit));
        assertEq(hexitPoolHistoryShares, 0);
        assertEq(hexitAmountToDistribute, 0);

        // assert total HEX1 staked amount
        uint256 hexOneAmount = staking.totalStakedAmount(address(hex1));
        assertEq(hexOneAmount, amount);

        // convert HEX1 deposited amount to pool shares
        uint256 shares = (_convertToShares(address(hex1), amount) * 1000) / 10000;

        // assert HEX pool total shares
        (,, uint256 hexPoolTotalShares,,) = staking.pools(hexToken);
        assertEq(hexPoolTotalShares, shares);

        // assert HEXIT pool total shares
        (,, uint256 hexitPoolTotalShares,,) = staking.pools(address(hexit));
        assertEq(hexitPoolTotalShares, shares);

        // assert user stake information
        (
            uint256 stakedAmount,
            uint256 initStakeDay,
            ,
            uint256 lastDepositedDay,
            uint256 hexSharesAmount,
            uint256 hexitSharesAmount,
            ,
            ,
            ,
        ) = staking.stakingInfos(user, address(hex1));
        assertEq(stakedAmount, amount);
        assertEq(initStakeDay, 0);
        assertEq(lastDepositedDay, 0);
        assertEq(hexSharesAmount, shares);
        assertEq(hexitSharesAmount, shares);
    }

    function test_stake_hexOne_increaseStake(uint256 amountToIncrease) public {
        // bound the amount of HEX1 to increase staking
        amountToIncrease = bound(amountToIncrease, 1e18, 1_000_000 * 1e18);

        // deal HEX1 to the user
        uint256 amount = 100_000 * 1e18;
        deal(address(hex1), user, amount);

        // user stakes HEX1
        vm.startPrank(user);

        hex1.approve(address(staking), amount);
        staking.stake(address(hex1), amount);

        vm.stopPrank();

        // deal HEXIT to the user so that he can increase its stake
        deal(address(hex1), user, amountToIncrease);

        // user wants to increase its stake of HEXIT
        vm.startPrank(user);

        hex1.approve(address(staking), amountToIncrease);
        staking.stake(address(hex1), amountToIncrease);

        vm.stopPrank();

        // assert HEX pool history
        (, uint256 hexPoolHistoryShares, uint256 hexAmountToDistribute) = staking.poolHistory(0, hexToken);
        assertEq(hexPoolHistoryShares, 0);
        assertEq(hexAmountToDistribute, 0);

        // assert HEXIT pool history
        (, uint256 hexitPoolHistoryShares, uint256 hexitAmountToDistribute) = staking.poolHistory(0, address(hexit));
        assertEq(hexitPoolHistoryShares, 0);
        assertEq(hexitAmountToDistribute, 0);

        // assert total HEX1/DAI staked amount
        uint256 hexOneAmount = staking.totalStakedAmount(address(hex1));
        assertEq(hexOneAmount, amount + amountToIncrease);

        // convert HEX1/DAI deposited amount to pool shares
        uint256 shares = (_convertToShares(address(hex1), amount + amountToIncrease) * 1000) / 10000;

        // assert HEX pool total shares
        (,, uint256 hexPoolTotalShares,,) = staking.pools(hexToken);
        assertEq(hexPoolTotalShares, shares);

        // assert HEXIT pool total shares
        (,, uint256 hexitPoolTotalShares,,) = staking.pools(address(hexit));
        assertEq(hexitPoolTotalShares, shares);

        // assert user stake information
        (uint256 stakedAmount,,,, uint256 hexSharesAmount, uint256 hexitSharesAmount,,,,) =
            staking.stakingInfos(user, address(hex1));
        assertEq(stakedAmount, amount + amountToIncrease);
        assertEq(hexSharesAmount, shares);
        assertEq(hexitSharesAmount, shares);
    }

    function test_stake_hexOne_increaseStake_afterDays(uint256 amountToIncrease, uint256 intervalDays) public {
        // bound the amount of HEX1 to increase staking
        amountToIncrease = bound(amountToIncrease, 1e18, 1_000_000 * 1e18);

        // bound the amount of days that passed between the first and second time the user staked.
        intervalDays = bound(intervalDays, 1 days, 120 days);

        // deal HEX1 to the user
        uint256 amount = 100_000 * 1e18;
        deal(address(hex1), user, amount);

        // user stakes HEX1
        vm.startPrank(user);

        hex1.approve(address(staking), amount);
        staking.stake(address(hex1), amount);

        vm.stopPrank();

        // skip interval days between stakes
        skip(intervalDays);
        uint256 currentStakingDay = staking.getCurrentStakingDay();

        // deal HEX1 to the user so that he can stake more
        deal(address(hex1), user, amountToIncrease);

        // user increases its stake after interval days have passed since the first stake
        vm.startPrank(user);

        hex1.approve(address(staking), amountToIncrease);
        staking.stake(address(hex1), amountToIncrease);

        vm.stopPrank();

        // assert HEX pool history
        uint256 hexAmountToDistribute;
        for (uint256 i = 0; i < currentStakingDay; i++) {
            (,, uint256 amountToDistribute) = staking.poolHistory(i, hexToken);
            hexAmountToDistribute += amountToDistribute;
        }

        // assert HEXIT pool history
        uint256 hexitAmountToDistribute;
        for (uint256 i = 0; i < currentStakingDay; i++) {
            (,, uint256 amountToDistribute) = staking.poolHistory(i, address(hexit));
            hexitAmountToDistribute += amountToDistribute;
        }

        // assert total HEX1 staked amount
        uint256 hexOneAmount = staking.totalStakedAmount(address(hex1));
        assertEq(hexOneAmount, amount + amountToIncrease);

        // convert HEX1 deposited amount to pool shares
        uint256 shares = (_convertToShares(address(hex1), amount + amountToIncrease) * 1000) / 10000;

        {
            // assert HEX pool total shares and distributed amounts
            (, uint256 distributedHex, uint256 hexPoolTotalShares,,) = staking.pools(hexToken);
            assertEq(hexAmountToDistribute, distributedHex);
            assertEq(hexPoolTotalShares, shares);

            // assert HEXIT pool total shares and distributed amounts
            (, uint256 distributedHexit, uint256 hexitPoolTotalShares,,) = staking.pools(address(hexit));
            assertEq(hexitAmountToDistribute, distributedHexit);
            assertEq(hexitPoolTotalShares, shares);
        }

        // assert user stake information
        (uint256 stakedAmount,,, uint256 lastDepositedDay, uint256 hexSharesAmount, uint256 hexitSharesAmount,,,,) =
            staking.stakingInfos(user, address(hex1));
        assertEq(stakedAmount, amount + amountToIncrease);
        assertEq(lastDepositedDay, staking.getCurrentStakingDay());
        assertEq(hexSharesAmount, shares);
        assertEq(hexitSharesAmount, shares);
    }

    function test_stake_hexitHexOne(uint256 amount) public {
        // bound HEXIT token amount
        amount = bound(amount, 1e18, 1_000_000 * 1e18);

        // deal HEXIT to the user
        deal(hexitHexOnePair, user, amount);

        // user stakes HEXIT
        vm.startPrank(user);

        IERC20(hexitHexOnePair).approve(address(staking), amount);
        staking.stake(hexitHexOnePair, amount);

        vm.stopPrank();

        // assert HEX pool history
        (, uint256 hexPoolHistoryShares, uint256 hexAmountToDistribute) = staking.poolHistory(0, hexToken);
        assertEq(hexPoolHistoryShares, 0);
        assertEq(hexAmountToDistribute, 0);

        // assert HEXIT pool history
        (, uint256 hexitPoolHistoryShares, uint256 hexitAmountToDistribute) = staking.poolHistory(0, address(hexit));
        assertEq(hexitPoolHistoryShares, 0);
        assertEq(hexitAmountToDistribute, 0);

        // assert total HEXIT/HEX1 staked amount
        uint256 hexitHexOneAmount = staking.totalStakedAmount(hexitHexOnePair);
        assertEq(hexitHexOneAmount, amount);

        // convert HEXIT/HEX1 deposited amount to pool shares
        uint256 shares = (_convertToShares(hexitHexOnePair, amount) * 2000) / 10000;

        // assert HEX pool total shares
        (,, uint256 hexPoolTotalShares,,) = staking.pools(hexToken);
        assertEq(hexPoolTotalShares, shares);

        // assert HEXIT pool total shares
        (,, uint256 hexitPoolTotalShares,,) = staking.pools(address(hexit));
        assertEq(hexitPoolTotalShares, shares);

        // assert user stake information
        (
            uint256 stakedAmount,
            uint256 initStakeDay,
            ,
            uint256 lastDepositedDay,
            uint256 hexSharesAmount,
            uint256 hexitSharesAmount,
            ,
            ,
            ,
        ) = staking.stakingInfos(user, hexitHexOnePair);
        assertEq(stakedAmount, amount);
        assertEq(initStakeDay, 0);
        assertEq(lastDepositedDay, 0);
        assertEq(hexSharesAmount, shares);
        assertEq(hexitSharesAmount, shares);
    }

    function test_stake_hexitHexOne_increaseStake(uint256 amountToIncrease) public {
        // bound the amount of HEXIT/HEX1 to increase staking
        amountToIncrease = bound(amountToIncrease, 1e18, 1_000_000 * 1e18);

        // deal HEXIT/HEX1 to the user
        uint256 amount = 100_000 * 1e18;
        deal(hexitHexOnePair, user, amount);

        // user stakes HEXIT/HEX1
        vm.startPrank(user);

        IERC20(hexitHexOnePair).approve(address(staking), amount);
        staking.stake(hexitHexOnePair, amount);

        vm.stopPrank();

        // deal HEXIT/HEX1 to the user so that he can increase its stake
        deal(hexitHexOnePair, user, amountToIncrease);

        // user wants to increase its stake of HEXIT
        vm.startPrank(user);

        IERC20(hexitHexOnePair).approve(address(staking), amountToIncrease);
        staking.stake(hexitHexOnePair, amountToIncrease);

        vm.stopPrank();

        // assert HEX pool history
        (, uint256 hexPoolHistoryShares, uint256 hexAmountToDistribute) = staking.poolHistory(0, hexToken);
        assertEq(hexPoolHistoryShares, 0);
        assertEq(hexAmountToDistribute, 0);

        // assert HEXIT pool history
        (, uint256 hexitPoolHistoryShares, uint256 hexitAmountToDistribute) = staking.poolHistory(0, address(hexit));
        assertEq(hexitPoolHistoryShares, 0);
        assertEq(hexitAmountToDistribute, 0);

        // assert total HEX1/DAI staked amount
        uint256 hexitAmount = staking.totalStakedAmount(hexitHexOnePair);
        assertEq(hexitAmount, amount + amountToIncrease);

        // convert HEXIT/HEX1 deposited amount to pool shares
        uint256 shares = (_convertToShares(address(hexitHexOnePair), amount + amountToIncrease) * 2000) / 10000;

        // assert HEX pool total shares
        (,, uint256 hexPoolTotalShares,,) = staking.pools(hexToken);
        assertEq(hexPoolTotalShares, shares);

        // assert HEXIT pool total shares
        (,, uint256 hexitPoolTotalShares,,) = staking.pools(address(hexit));
        assertEq(hexitPoolTotalShares, shares);

        // assert user stake information
        (uint256 stakedAmount,,,, uint256 hexSharesAmount, uint256 hexitSharesAmount,,,,) =
            staking.stakingInfos(user, hexitHexOnePair);
        assertEq(stakedAmount, amount + amountToIncrease);
        assertEq(hexSharesAmount, shares);
        assertEq(hexitSharesAmount, shares);
    }

    function test_stake_hexitHexOne_increaseStake_afterDays(uint256 amountToIncrease, uint256 intervalDays) public {
        // bound the amount of HEXIT/HEX1 to increase staking
        amountToIncrease = bound(amountToIncrease, 1e18, 1_000_000 * 1e18);

        // bound the amount of days that passed between the first and second time the user staked.
        intervalDays = bound(intervalDays, 1 days, 120 days);

        // deal HEXIT/HEX1 to the user
        uint256 amount = 100_000 * 1e18;
        deal(hexitHexOnePair, user, amount);

        // user stakes HEXIT
        vm.startPrank(user);

        IERC20(hexitHexOnePair).approve(address(staking), amount);
        staking.stake(hexitHexOnePair, amount);

        vm.stopPrank();

        // skip interval days between stakes
        skip(intervalDays);
        uint256 currentStakingDay = staking.getCurrentStakingDay();

        // deal HEXIT to the user so that he can stake more
        deal(hexitHexOnePair, user, amountToIncrease);

        // user increases its stake after interval days have passed since the first stake
        vm.startPrank(user);

        IERC20(hexitHexOnePair).approve(address(staking), amountToIncrease);
        staking.stake(hexitHexOnePair, amountToIncrease);

        vm.stopPrank();

        // assert HEX pool history
        uint256 hexAmountToDistribute;
        for (uint256 i = 0; i < currentStakingDay; i++) {
            (,, uint256 amountToDistribute) = staking.poolHistory(i, hexToken);
            hexAmountToDistribute += amountToDistribute;
        }

        // assert HEXIT pool history
        uint256 hexitAmountToDistribute;
        for (uint256 i = 0; i < currentStakingDay; i++) {
            (,, uint256 amountToDistribute) = staking.poolHistory(i, address(hexit));
            hexitAmountToDistribute += amountToDistribute;
        }

        // assert total HEXIT/HEX1 staked amount
        uint256 hexitHexOneAmount = staking.totalStakedAmount(hexitHexOnePair);
        assertEq(hexitHexOneAmount, amount + amountToIncrease);

        // convert HEXIT/HEX1 deposited amount to pool shares
        uint256 shares = (_convertToShares(hexitHexOnePair, amount + amountToIncrease) * 2000) / 10000;

        {
            // assert HEX pool total shares and distributed amounts
            (, uint256 distributedHex, uint256 hexPoolTotalShares,,) = staking.pools(hexToken);
            assertEq(hexAmountToDistribute, distributedHex);
            assertEq(hexPoolTotalShares, shares);

            // assert HEXIT pool total shares and distributed amounts
            (, uint256 distributedHexit, uint256 hexitPoolTotalShares,,) = staking.pools(address(hexit));
            assertEq(hexitAmountToDistribute, distributedHexit);
            assertEq(hexitPoolTotalShares, shares);
        }

        // assert user stake information
        (uint256 stakedAmount,,, uint256 lastDepositedDay, uint256 hexSharesAmount, uint256 hexitSharesAmount,,,,) =
            staking.stakingInfos(user, hexitHexOnePair);
        assertEq(stakedAmount, amount + amountToIncrease);
        assertEq(lastDepositedDay, staking.getCurrentStakingDay());
        assertEq(hexSharesAmount, shares);
        assertEq(hexitSharesAmount, shares);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    UNSTAKE
    //////////////////////////////////////////////////////////////////////////*/

    function test_unstake_hexOneDai(uint256 amount, uint256 intervalDays) public {
        // bound HEX1/DAI LP token amount
        amount = bound(amount, 1e18, 1_000_000 * 1e18);
        // bound the interval days between the stake and unstake
        intervalDays = bound(intervalDays, 2 days, 365 days);

        // deal HEX1/DAI LP to the user
        deal(hexOneDaiPair, user, amount);

        // user stakes HEX1/DAI LP
        vm.startPrank(user);

        IERC20(hexOneDaiPair).approve(address(staking), amount);
        staking.stake(hexOneDaiPair, amount);

        vm.stopPrank();

        // increments the block timestamp with interval days
        skip(intervalDays);

        // store the balances before unstaking
        uint256 userHexBalanceBefore = IERC20(hexToken).balanceOf(user);
        uint256 userHexitBalanceBefore = hexit.balanceOf(user);
        uint256 userHex1DaiBalanceBefore = IERC20(hexOneDaiPair).balanceOf(user);

        // user unstakes HEX1/DAI LP
        vm.startPrank(user);

        staking.unstake(hexOneDaiPair, amount);

        vm.stopPrank();

        uint256 currentStakingDay = staking.getCurrentStakingDay();

        // compute rewards distributed by HEX pool history
        uint256 hexAmountDistributed;
        for (uint256 i = 0; i < currentStakingDay; i++) {
            (,, uint256 amountToDistribute) = staking.poolHistory(i, hexToken);
            hexAmountDistributed += amountToDistribute;
        }

        // compute rewards distributed by HEXIT pool history
        uint256 hexitAmountDistributed;
        for (uint256 i = 0; i < currentStakingDay; i++) {
            (,, uint256 amountToDistribute) = staking.poolHistory(i, address(hexit));
            hexitAmountDistributed += amountToDistribute;
        }

        // assert stake info
        {
            (
                uint256 stakedAmount,
                ,
                uint256 lastClaimedDay,
                ,
                uint256 hexSharesAmount,
                uint256 hexitSharesAmount,
                uint256 unclaimedHex,
                uint256 unclaimedHexit,
                uint256 totalHexClaimed,
                uint256 totalHexitClaimed
            ) = staking.stakingInfos(user, hexOneDaiPair);
            assertEq(stakedAmount, 0);
            assertEq(lastClaimedDay, 0);
            assertEq(hexSharesAmount, 0);
            assertEq(hexitSharesAmount, 0);
            assertEq(unclaimedHex, 0);
            assertEq(unclaimedHexit, 0);
            assertEq(totalHexClaimed, hexAmountDistributed);
            assertEq(totalHexitClaimed, hexitAmountDistributed);
        }

        // assert total staked amount of HEX1/DAI LP
        assertEq(staking.totalStakedAmount(hexOneDaiPair), 0);

        // assert HEX pool shares
        (,, uint256 hexTotalShares,,) = staking.pools(hexToken);
        assertEq(hexTotalShares, 0);

        // assert HEXIT pool shares
        (,, uint256 hexitTotalShares,,) = staking.pools(address(hexit));
        assertEq(hexitTotalShares, 0);

        // assert that HEX and HEXIT rewards are paid to the user
        assertEq(IERC20(hexToken).balanceOf(user), userHexBalanceBefore + hexAmountDistributed);
        assertEq(hexit.balanceOf(user), userHexitBalanceBefore + hexitAmountDistributed);

        // assert that HEX1/DAI is transfered back to the user
        assertEq(IERC20(hexOneDaiPair).balanceOf(user), userHex1DaiBalanceBefore + amount);
    }

    function test_unstake_hexOne(uint256 amount, uint256 intervalDays) public {
        // bound HEX1 token amount
        amount = bound(amount, 1e18, 1_000_000 * 1e18);
        // bound the interval days between the stake and unstake
        intervalDays = bound(intervalDays, 2 days, 365 days);

        // deal HEX1 to the user
        deal(address(hex1), user, amount);

        // user stakes HEX1
        vm.startPrank(user);

        hex1.approve(address(staking), amount);
        staking.stake(address(hex1), amount);

        vm.stopPrank();

        // increments the block timestamp with interval days
        skip(intervalDays);

        // store the balances before unstaking
        uint256 userHexBalanceBefore = IERC20(hexToken).balanceOf(user);
        uint256 userHexitBalanceBefore = hexit.balanceOf(user);
        uint256 userHexOneBalanceBefore = IERC20(hexOneDaiPair).balanceOf(user);

        // user unstakes HEX1
        vm.startPrank(user);

        staking.unstake(address(hex1), amount);

        vm.stopPrank();

        uint256 currentStakingDay = staking.getCurrentStakingDay();

        // compute rewards distributed by HEX pool history
        uint256 hexAmountDistributed;
        for (uint256 i = 0; i < currentStakingDay; i++) {
            (,, uint256 amountToDistribute) = staking.poolHistory(i, hexToken);
            hexAmountDistributed += amountToDistribute;
        }

        // compute rewards distributed by HEXIT pool history
        uint256 hexitAmountDistributed;
        for (uint256 i = 0; i < currentStakingDay; i++) {
            (,, uint256 amountToDistribute) = staking.poolHistory(i, address(hexit));
            hexitAmountDistributed += amountToDistribute;
        }

        // assert stake info
        {
            (
                uint256 stakedAmount,
                ,
                uint256 lastClaimedDay,
                ,
                uint256 hexSharesAmount,
                uint256 hexitSharesAmount,
                uint256 unclaimedHex,
                uint256 unclaimedHexit,
                uint256 totalHexClaimed,
                uint256 totalHexitClaimed
            ) = staking.stakingInfos(user, address(hex1));
            assertEq(stakedAmount, 0);
            assertEq(lastClaimedDay, 0);
            assertEq(hexSharesAmount, 0);
            assertEq(hexitSharesAmount, 0);
            assertEq(unclaimedHex, 0);
            assertEq(unclaimedHexit, 0);
            assertEq(totalHexClaimed, hexAmountDistributed);
            assertEq(totalHexitClaimed, hexitAmountDistributed);
        }

        // assert total staked amount of HEX1
        assertEq(staking.totalStakedAmount(address(hex1)), 0);

        // assert HEX pool shares
        (,, uint256 hexTotalShares,,) = staking.pools(hexToken);
        assertEq(hexTotalShares, 0);

        // assert HEXIT pool shares
        (,, uint256 hexitTotalShares,,) = staking.pools(address(hexit));
        assertEq(hexitTotalShares, 0);

        // assert that HEX and HEXIT rewards are paid to the user
        assertEq(IERC20(hexToken).balanceOf(user), userHexBalanceBefore + hexAmountDistributed);
        assertEq(hexit.balanceOf(user), userHexitBalanceBefore + hexitAmountDistributed);

        // assert that HEX1 is transfered back to the user
        assertEq(IERC20(address(hex1)).balanceOf(user), userHexOneBalanceBefore + amount);
    }

    function test_unstake_hexitHexOne(uint256 amount, uint256 intervalDays) public {
        // bound HEXIT/HEX1 token amount
        amount = bound(amount, 1e18, 1_000_000 * 1e18);
        // bound the interval days between the stake and unstake
        intervalDays = bound(intervalDays, 2 days, 365 days);

        // deal HEXIT/HEX1 to the user
        deal(hexitHexOnePair, user, amount);

        // user stakes HEXIT/HEX1
        vm.startPrank(user);

        IERC20(hexitHexOnePair).approve(address(staking), amount);
        staking.stake(address(hexitHexOnePair), amount);

        vm.stopPrank();

        // increments the block timestamp with interval days
        skip(intervalDays);

        // store the balances before unstaking
        uint256 userHexBalanceBefore = IERC20(hexToken).balanceOf(user);
        uint256 userHexitBalanceBefore = hexit.balanceOf(user);

        // user unstakes HEXIT
        vm.startPrank(user);

        staking.unstake(hexitHexOnePair, amount);

        vm.stopPrank();

        uint256 currentStakingDay = staking.getCurrentStakingDay();

        // compute rewards distributed by HEX pool history
        uint256 hexAmountDistributed;
        for (uint256 i = 0; i < currentStakingDay; i++) {
            (,, uint256 amountToDistribute) = staking.poolHistory(i, hexToken);
            hexAmountDistributed += amountToDistribute;
        }

        // compute rewards distributed by HEXIT pool history
        uint256 hexitAmountDistributed;
        for (uint256 i = 0; i < currentStakingDay; i++) {
            (,, uint256 amountToDistribute) = staking.poolHistory(i, address(hexit));
            hexitAmountDistributed += amountToDistribute;
        }

        // assert stake info
        {
            (
                uint256 stakedAmount,
                ,
                uint256 lastClaimedDay,
                ,
                uint256 hexSharesAmount,
                uint256 hexitSharesAmount,
                uint256 unclaimedHex,
                uint256 unclaimedHexit,
                uint256 totalHexClaimed,
                uint256 totalHexitClaimed
            ) = staking.stakingInfos(user, hexitHexOnePair);
            assertEq(stakedAmount, 0);
            assertEq(lastClaimedDay, 0);
            assertEq(hexSharesAmount, 0);
            assertEq(hexitSharesAmount, 0);
            assertEq(unclaimedHex, 0);
            assertEq(unclaimedHexit, 0);
            assertEq(totalHexClaimed, hexAmountDistributed);
            assertEq(totalHexitClaimed, hexitAmountDistributed);
        }

        // assert total staked amount of HEXIT/HEX1
        assertEq(staking.totalStakedAmount(hexitHexOnePair), 0);

        // assert HEX pool shares
        (,, uint256 hexTotalShares,,) = staking.pools(hexToken);
        assertEq(hexTotalShares, 0);

        // assert HEXIT pool shares
        (,, uint256 hexitTotalShares,,) = staking.pools(address(hexit));
        assertEq(hexitTotalShares, 0);

        // assert that HEX rewards are paid to the user and HEXIT rewards are paid to the user
        assertEq(IERC20(hexToken).balanceOf(user), userHexBalanceBefore + hexAmountDistributed);

        // assert that HEXIT rewards plus the amount staked is returned to the user
        assertEq(hexit.balanceOf(user), userHexitBalanceBefore + hexitAmountDistributed);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    CLAIM
    //////////////////////////////////////////////////////////////////////////*/

    function test_claim_hexOneDai(uint256 amount, uint256 intervalDays) public {
        // bound HEX1/DAI LP token amount
        amount = bound(amount, 1e18, 1_000_000 * 1e18);
        // bound the interval days between the stake and unstake
        intervalDays = bound(intervalDays, 2 days, 365 days);

        // deal HEX1/DAI LP to the user
        deal(hexOneDaiPair, user, amount);

        // user stakes HEX1/DAI LP
        vm.startPrank(user);

        IERC20(hexOneDaiPair).approve(address(staking), amount);
        staking.stake(hexOneDaiPair, amount);

        vm.stopPrank();

        // increments the block timestamp with interval days
        skip(intervalDays);

        uint256 userHexBalanceBefore = IERC20(hexToken).balanceOf(user);
        uint256 userHexitBalanceBefore = hexit.balanceOf(user);

        // user claims it's HEX and HEXIT rewards
        vm.startPrank(user);

        (uint256 hexRewards, uint256 hexitRewards) = staking.claim(hexOneDaiPair);

        vm.stopPrank();

        uint256 currentStakingDay = staking.getCurrentStakingDay();

        // assert HEX pool history
        uint256 hexAmountDistributed;
        for (uint256 i = 0; i < currentStakingDay; i++) {
            (,, uint256 amountToDistribute) = staking.poolHistory(i, hexToken);
            hexAmountDistributed += amountToDistribute;
        }
        assertEq(hexRewards, hexAmountDistributed);

        // assert HEXIT pool history
        uint256 hexitAmountDistributed;
        for (uint256 i = 0; i < currentStakingDay; i++) {
            (,, uint256 amountToDistribute) = staking.poolHistory(i, address(hexit));
            hexitAmountDistributed += amountToDistribute;
        }
        assertEq(hexitRewards, hexitAmountDistributed);

        // assert user stake information
        {
            (
                ,
                ,
                uint256 lastClaimedDay,
                ,
                ,
                ,
                uint256 unclaimedHex,
                uint256 unclaimedHexit,
                uint256 totalHexClaimed,
                uint256 totalHexitClaimed
            ) = staking.stakingInfos(user, hexOneDaiPair);
            assertEq(lastClaimedDay, currentStakingDay);
            assertEq(unclaimedHex, 0);
            assertEq(unclaimedHexit, 0);
            assertEq(totalHexClaimed, hexAmountDistributed);
            assertEq(totalHexitClaimed, hexitAmountDistributed);
        }

        // assert user HEX balance
        assertEq(IERC20(hexToken).balanceOf(user), userHexBalanceBefore + hexRewards);

        // assert user HEXIT balance
        assertEq(hexit.balanceOf(user), userHexitBalanceBefore + hexitRewards);
    }

    function test_claim_hexOne(uint256 amount, uint256 intervalDays) public {
        // bound HEX1 token amount
        amount = bound(amount, 1e18, 1_000_000 * 1e18);
        // bound the interval days between the stake and unstake
        intervalDays = bound(intervalDays, 2 days, 365 days);

        // deal HEX1 to the user
        deal(address(hex1), user, amount);

        // user stakes HEX1
        vm.startPrank(user);

        hex1.approve(address(staking), amount);
        staking.stake(address(hex1), amount);

        vm.stopPrank();

        // increments the block timestamp with interval days
        skip(intervalDays);

        uint256 userHexBalanceBefore = IERC20(hexToken).balanceOf(user);
        uint256 userHexitBalanceBefore = hexit.balanceOf(user);

        // user claims it's HEX and HEXIT rewards
        vm.startPrank(user);

        (uint256 hexRewards, uint256 hexitRewards) = staking.claim(address(hex1));

        vm.stopPrank();

        uint256 currentStakingDay = staking.getCurrentStakingDay();

        // assert HEX pool history
        uint256 hexAmountDistributed;
        for (uint256 i = 0; i < currentStakingDay; i++) {
            (,, uint256 amountToDistribute) = staking.poolHistory(i, hexToken);
            hexAmountDistributed += amountToDistribute;
        }
        assertEq(hexRewards, hexAmountDistributed);

        // assert HEXIT pool history
        uint256 hexitAmountDistributed;
        for (uint256 i = 0; i < currentStakingDay; i++) {
            (,, uint256 amountToDistribute) = staking.poolHistory(i, address(hexit));
            hexitAmountDistributed += amountToDistribute;
        }
        assertEq(hexitRewards, hexitAmountDistributed);

        // assert user stake information
        {
            (
                ,
                ,
                uint256 lastClaimedDay,
                ,
                ,
                ,
                uint256 unclaimedHex,
                uint256 unclaimedHexit,
                uint256 totalHexClaimed,
                uint256 totalHexitClaimed
            ) = staking.stakingInfos(user, address(hex1));
            assertEq(lastClaimedDay, currentStakingDay);
            assertEq(unclaimedHex, 0);
            assertEq(unclaimedHexit, 0);
            assertEq(totalHexClaimed, hexAmountDistributed);
            assertEq(totalHexitClaimed, hexitAmountDistributed);
        }

        // assert user HEX balance
        assertEq(IERC20(hexToken).balanceOf(user), userHexBalanceBefore + hexRewards);

        // assert user HEXIT balance
        assertEq(hexit.balanceOf(user), userHexitBalanceBefore + hexitRewards);
    }

    function test_claim_hexitHexOne(uint256 amount, uint256 intervalDays) public {
        // bound HEXIT token amount
        amount = bound(amount, 1e18, 1_000_000 * 1e18);
        // bound the interval days between the stake and unstake
        intervalDays = bound(intervalDays, 2 days, 365 days);

        // deal HEXIT to the user
        deal(hexitHexOnePair, user, amount);

        // user stakes HEXIT
        vm.startPrank(user);

        IERC20(hexitHexOnePair).approve(address(staking), amount);
        staking.stake(hexitHexOnePair, amount);

        vm.stopPrank();

        // increments the block timestamp with interval days
        skip(intervalDays);

        uint256 userHexBalanceBefore = IERC20(hexToken).balanceOf(user);
        uint256 userHexitBalanceBefore = hexit.balanceOf(user);

        // user claims it's HEX and HEXIT rewards
        vm.startPrank(user);

        (uint256 hexRewards, uint256 hexitRewards) = staking.claim(hexitHexOnePair);

        vm.stopPrank();

        uint256 currentStakingDay = staking.getCurrentStakingDay();

        // assert HEX pool history
        uint256 hexAmountDistributed;
        for (uint256 i = 0; i < currentStakingDay; i++) {
            (,, uint256 amountToDistribute) = staking.poolHistory(i, hexToken);
            hexAmountDistributed += amountToDistribute;
        }
        assertEq(hexRewards, hexAmountDistributed);

        // assert HEXIT pool history
        uint256 hexitAmountDistributed;
        for (uint256 i = 0; i < currentStakingDay; i++) {
            (,, uint256 amountToDistribute) = staking.poolHistory(i, address(hexit));
            hexitAmountDistributed += amountToDistribute;
        }
        assertEq(hexitRewards, hexitAmountDistributed);

        // assert user stake information
        {
            (
                ,
                ,
                uint256 lastClaimedDay,
                ,
                ,
                ,
                uint256 unclaimedHex,
                uint256 unclaimedHexit,
                uint256 totalHexClaimed,
                uint256 totalHexitClaimed
            ) = staking.stakingInfos(user, hexitHexOnePair);
            assertEq(lastClaimedDay, currentStakingDay);
            assertEq(unclaimedHex, 0);
            assertEq(unclaimedHexit, 0);
            assertEq(totalHexClaimed, hexAmountDistributed);
            assertEq(totalHexitClaimed, hexitAmountDistributed);
        }

        // assert user HEX balance
        assertEq(IERC20(hexToken).balanceOf(user), userHexBalanceBefore + hexRewards);

        // assert user HEXIT balance
        assertEq(hexit.balanceOf(user), userHexitBalanceBefore + hexitRewards);
    }
}
