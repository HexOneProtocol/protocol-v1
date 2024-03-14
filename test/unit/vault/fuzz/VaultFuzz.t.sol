// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import "../../Base.t.sol";

contract VaultFuzzTest is Base {
    function setUp() public override {
        super.setUp();

        // set sacrifice status to true
        vm.prank(bootstrap);
        vault.setSacrificeStatus();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                DEPOSIT
    //////////////////////////////////////////////////////////////////////////*/

    function test_deposit(address depositor, uint256 amount, uint256 duration) public {
        vm.assume(depositor != address(0));
        amount = bound(amount, 1e7, 100_000_000 * 1e8);
        duration = bound(duration, 3652, 5555);

        hexToken.mint(depositor, amount);

        uint256 depositorHexBalanceBefore = hexToken.balanceOf(depositor);

        vm.startPrank(depositor);

        hexToken.approve(address(vault), amount);
        (uint256 amountBorrowed, uint256 stakeId) = vault.deposit(amount, uint16(duration));

        vm.stopPrank();

        // calculate the fee paid to the staking contract to be distributed as rewards
        uint256 feeToStaking = (depositorHexBalanceBefore * 500) / 10_000;

        // assert state
        (uint256 hexDeposited,, uint256 hexOneBorrowed,, uint16 depositDuration, bool active) =
            vault.depositInfos(depositor, stakeId);
        assertEq(hexDeposited, amount - feeToStaking);
        assertEq(hexOneBorrowed, amountBorrowed);
        assertEq(depositDuration, uint16(duration));
        assertEq(active, true);

        (uint256 totalHexDeposited,, uint256 totalHexOneBorrowed) = vault.userInfos(depositor);
        assertEq(totalHexDeposited, amount - feeToStaking);
        assertEq(totalHexOneBorrowed, amountBorrowed);

        // assert balances
        uint256 depositorHexBalanceAfter = hexToken.balanceOf(depositor);
        assertEq(depositorHexBalanceAfter, 0);

        uint256 stakingHexBalanceAfter = hexToken.balanceOf(address(staking));
        assertEq(stakingHexBalanceAfter, feeToStaking);
    }

    function test_deposit_twice(
        address depositor,
        uint256 firstDepositAmount,
        uint256 secondDepositAmount,
        uint256 firstDepositDuration,
        uint256 secondDepositDuration
    ) public {
        // bound fuzzer inputs
        vm.assume(depositor != address(0));

        firstDepositAmount = bound(firstDepositAmount, 1e7, 100_000_000 * 1e8);
        secondDepositAmount = bound(secondDepositAmount, 1e7, 100_000_000 * 1e8);

        firstDepositDuration = bound(firstDepositDuration, 3652, 5555);
        secondDepositDuration = bound(secondDepositDuration, 3652, 5555);

        hexToken.mint(depositor, firstDepositAmount + secondDepositAmount);

        // depositor makes two deposits
        vm.startPrank(depositor);

        hexToken.approve(address(vault), firstDepositAmount);
        (uint256 firstDepositHexOneBorrowed,) = vault.deposit(firstDepositAmount, uint16(firstDepositDuration));

        hexToken.approve(address(vault), secondDepositAmount);
        (uint256 secondDepositHexOneBorrowed,) = vault.deposit(secondDepositAmount, uint16(secondDepositDuration));

        vm.stopPrank();

        uint256 firstDepositFee = (firstDepositAmount * 500) / 10_000;
        uint256 secondDepositFee = (secondDepositAmount * 500) / 10_000;

        // assert state
        (uint256 totalHexDeposited,, uint256 totalHexOneBorrowed) = vault.userInfos(depositor);
        assertEq(totalHexDeposited, (firstDepositAmount + secondDepositAmount) - (firstDepositFee + secondDepositFee));
        assertEq(totalHexOneBorrowed, firstDepositHexOneBorrowed + secondDepositHexOneBorrowed);

        // assert balances
        uint256 depositorHexBalanceAfter = hexToken.balanceOf(depositor);
        assertEq(depositorHexBalanceAfter, 0);

        uint256 stakingHexBalanceAfter = hexToken.balanceOf(address(staking));
        assertEq(stakingHexBalanceAfter, firstDepositFee + secondDepositFee);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                DELEGATE DEPOSIT
    //////////////////////////////////////////////////////////////////////////*/

    function test_delegateDeposit(address depositor, uint256 amount, uint256 duration) public {
        // bound fuzzer inputs
        vm.assume(depositor != address(0));
        amount = bound(amount, 1e7, 100_000_000 * 1e8);
        duration = bound(duration, 3652, 5555);

        hexToken.mint(bootstrap, amount);

        // bootstrap is the only address who can create deposits in the name of a depositor
        vm.startPrank(bootstrap);

        hexToken.approve(address(vault), amount);
        (uint256 amountBorrowed, uint256 stakeId) = vault.delegateDeposit(depositor, amount, uint16(duration));

        vm.stopPrank();

        uint256 feeToStaking = (amount * 500) / 10_000;

        // assert state
        (uint256 hexDeposited,, uint256 hexOneBorrowed,, uint16 depositDuration, bool active) =
            vault.depositInfos(depositor, stakeId);
        assertEq(hexDeposited, amount - feeToStaking);
        assertEq(hexOneBorrowed, amountBorrowed);
        assertEq(depositDuration, uint16(duration));
        assertEq(active, true);

        (uint256 totalHexDeposited,, uint256 totalHexOneBorrowed) = vault.userInfos(depositor);
        assertEq(totalHexDeposited, amount - feeToStaking);
        assertEq(totalHexOneBorrowed, amountBorrowed);

        // assert balances
        uint256 bootstrapHexBalanceAfter = hexToken.balanceOf(bootstrap);
        assertEq(bootstrapHexBalanceAfter, 0);

        uint256 stakingHexBalanceAfter = hexToken.balanceOf(address(staking));
        assertEq(stakingHexBalanceAfter, feeToStaking);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                CLAIM
    //////////////////////////////////////////////////////////////////////////*/

    function test_claim(address depositor, uint256 amount, uint256 duration) public {
        // bound fuzzer inputs
        vm.assume(depositor != address(0));
        amount = bound(amount, 1e7, 100_000_000 * 1e8);
        duration = bound(duration, 3652, 5555);

        hexToken.mint(depositor, amount);

        // deposit makes a new deposit
        vm.startPrank(depositor);

        hexToken.approve(address(vault), amount);
        (uint256 hexOneBorrowed, uint256 stakeId) = vault.deposit(amount, uint16(duration));

        vm.stopPrank();

        // increate timestamp so that the HEX stake is mature
        skip(duration * 1 days);

        // depositor claim its deposit by repaying its HEX1 debt
        vm.startPrank(depositor);

        hex1.approve(address(vault), hexOneBorrowed);
        uint256 hexClaimed = vault.claim(stakeId);

        vm.stopPrank();

        // assert state
        (uint256 hexDeposited, uint256 hexShares, uint256 amountBorrowed,,, bool active) =
            vault.depositInfos(depositor, stakeId);
        assertEq(hexDeposited, 0);
        assertEq(amountBorrowed, 0);
        assertEq(hexShares, 0);
        assertEq(active, false);

        (uint256 totalHexDeposited,, uint256 totalHexOneBorrowed) = vault.userInfos(depositor);
        assertEq(totalHexDeposited, 0);
        assertEq(totalHexOneBorrowed, 0);

        // assert balances
        assertEq(hexToken.balanceOf(depositor), hexClaimed);
        assertEq(hex1.balanceOf(depositor), 0);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                BORROW
    //////////////////////////////////////////////////////////////////////////*/

    function test_borrow(
        address depositor,
        uint256 hexToDeposit,
        uint256 duration,
        uint256 hexDaiRate,
        uint256 hexOneToBorrow
    ) public {
        // assume depositor can not be the zero address
        vm.assume(depositor != address(0));

        // bound fuzzer inputs for the deposit
        hexToDeposit = bound(hexToDeposit, 100 * 1e8, 100_000_000_000 * 1e8);
        duration = bound(duration, 3652, 5555);
        hexDaiRate = bound(hexDaiRate, 15000000000000000, 90000000000000000);

        // mint HEX to the depositor
        hexToken.mint(depositor, hexToDeposit);

        // depositor creates a new deposit
        vm.startPrank(depositor);
        hexToken.approve(address(vault), hexToDeposit);
        (uint256 hexOneBorrowed, uint256 stakeId) = vault.deposit(hexToDeposit, uint16(duration));
        vm.stopPrank();

        // set the new rate in the vault
        vm.prank(deployer);
        feed.setRate(address(hexToken), address(daiToken), hexDaiRate);

        // bound amount borrowable so that it is not more than the max amount
        uint256 fee = (hexToDeposit * 500) / 10_000;
        uint256 maxHexOneBorrowable = aggregator.computeHexPrice(hexToDeposit - fee);
        hexOneToBorrow = bound(hexOneToBorrow, 1e8, maxHexOneBorrowable - hexOneBorrowed);

        // if the rate increased since the deposit
        if (hexDaiRate > HEX_DAI_INIT_RATE) {
            vm.startPrank(depositor);
            vault.borrow(hexOneToBorrow, stakeId);
            vm.stopPrank();
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                LIQUIDATE
    //////////////////////////////////////////////////////////////////////////*/

    function test_liquidate(address depositor, address liquidator, uint256 amount, uint256 duration) public {
        // bound fuzzer inputs
        vm.assume(depositor != address(0));
        vm.assume(liquidator != address(0));
        amount = bound(amount, 1e7, 100_000_000 * 1e8);
        duration = bound(duration, 3652, 5555);

        hexToken.mint(depositor, amount);

        // deposit makes a new deposit
        vm.startPrank(depositor);

        hexToken.approve(address(vault), amount);
        (uint256 hexOneBorrowed, uint256 stakeId) = vault.deposit(amount, uint16(duration));

        vm.stopPrank();

        // increate timestamp so that the HEX stake is mature + GRACE_PERIOD so that deposit
        // is liquidatable
        uint256 timeToSkip = (duration + 7) * 1 days;
        skip(timeToSkip);

        // mint HEX1 to the liquidator so that he can repay the depositors' debt
        deal(address(hex1), liquidator, hexOneBorrowed);

        // liquidates the deposit by repaying the depositor HEX1 debt
        vm.startPrank(liquidator);

        hex1.approve(address(vault), hexOneBorrowed);
        vault.liquidate(depositor, stakeId);

        vm.stopPrank();

        (uint256 hexDeposited, uint256 hexShares, uint256 amountBorrowed,,, bool active) =
            vault.depositInfos(depositor, stakeId);
        assertEq(hexDeposited, 0);
        assertEq(amountBorrowed, 0);
        assertEq(hexShares, 0);
        assertEq(active, false);

        (uint256 totalHexDeposited,, uint256 totalHexOneBorrowed) = vault.userInfos(depositor);
        assertEq(totalHexDeposited, 0);
        assertEq(totalHexOneBorrowed, 0);
    }
}
