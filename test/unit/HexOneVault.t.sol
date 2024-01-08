// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import "../Base.t.sol";

/**
 *  @dev forge test --match-contract HexOneVaultTest --rpc-url "https://rpc.pulsechain.com" -vvv
 */
contract HexOneVaultTest is Base {
    uint256 public constant HEX_DEPOSIT_AMOUNT = 1000 * 1e8;
    uint256 public constant HEXONE_BORROW_AMOUNT = 1 * 1e18;
    address public depositor = makeAddr("depositor");
    address public liquidator = makeAddr("liquidator");

    function test_deposit() public {
        // give HEX to the depositor
        deal(hexToken, depositor, HEX_DEPOSIT_AMOUNT);
        assertEq(IERC20(hexToken).balanceOf(depositor), HEX_DEPOSIT_AMOUNT);

        // vault stakes HEX in name of the depositor for 4000 days
        vm.startPrank(depositor);
        IERC20(hexToken).approve(address(vault), HEX_DEPOSIT_AMOUNT);
        assertEq(IERC20(hexToken).allowance(depositor, address(vault)), HEX_DEPOSIT_AMOUNT);
        uint256 stakeId = vault.deposit(HEX_DEPOSIT_AMOUNT, 4000);
        assertEq(stakeId, 0);
        vm.stopPrank();

        // assert deposit information
        (uint256 amount,,,, uint16 duration, bool active) = vault.depositInfos(depositor, 0);
        assertEq(amount, HEX_DEPOSIT_AMOUNT);
        assertEq(duration, 4000);
        assertEq(active, true);

        // assert user information
        (uint256 totalAmount,,) = vault.userInfos(depositor);
        assertEq(totalAmount, HEX_DEPOSIT_AMOUNT);
    }

    function test_deposit_multipleDeposits() public {
        test_deposit();

        // deal HEX tokens to the depositor
        deal(hexToken, depositor, HEX_DEPOSIT_AMOUNT);

        // create new deposit
        vm.startPrank(depositor);
        IERC20(hexToken).approve(address(vault), HEX_DEPOSIT_AMOUNT);
        uint256 stakeId = vault.deposit(HEX_DEPOSIT_AMOUNT, 4000);
        vm.stopPrank();

        // assert stake id incremented
        assertEq(stakeId, 1);

        // assert total amount deposited
        (uint256 totalAmount,,) = vault.userInfos(depositor);
        assertEq(totalAmount, HEX_DEPOSIT_AMOUNT * 2);
    }

    function test_deposit_revertIfDurationLessThanMinDuration() public {
        vm.startPrank(depositor);
        vm.expectRevert(IHexOneVault.InvalidDepositDuration.selector);
        vault.deposit(HEX_DEPOSIT_AMOUNT, 3651);
        vm.stopPrank();
    }

    function test_deposit_revertIfDurationMoreThanMaxDuration() public {
        vm.startPrank(depositor);
        vm.expectRevert(IHexOneVault.InvalidDepositDuration.selector);
        vault.deposit(HEX_DEPOSIT_AMOUNT, 5556);
        vm.stopPrank();
    }

    function test_deposit_revertIfDepositAmountIsZero() public {
        vm.startPrank(depositor);
        vm.expectRevert(IHexOneVault.ZeroDepositAmount.selector);
        vault.deposit(0, 4000);
        vm.stopPrank();
    }

    function test_claim() public {
        test_deposit();

        skip(4001 days);

        uint256 stakeId = 0;

        vm.startPrank(depositor);
        uint256 hexAmount = vault.claim(stakeId);
        vm.stopPrank();

        assertEq(HEX_DEPOSIT_AMOUNT < hexAmount, true);
    }

    function test_claim_depositWithDebt() public {
        // deposit HEX in the protocol and stake it.
        test_deposit();

        uint256 stakeId = 0;

        // skip initial period and update the oracle for the first.
        skip(feed.PERIOD());
        feed.update();

        // borrow HEX1 agaisnt the HEX deposited.
        vm.prank(depositor);
        vault.borrow(HEXONE_BORROW_AMOUNT, stakeId);

        // assert that the depositor was able to borrow HEX1
        assertEq(IERC20(hex1).balanceOf(depositor), HEXONE_BORROW_AMOUNT);

        // wait for the HEX stake to mature.
        skip(4001 days);

        // claim the staked HEX + yield by repaying the HEX1 borrowed.
        vm.prank(depositor);
        uint256 hexAmount = vault.claim(stakeId);
        assertEq(HEX_DEPOSIT_AMOUNT < hexAmount, true);
        assertEq(IERC20(hex1).balanceOf(depositor), 0);
    }

    function test_claim_revertIfDepositNotActive() public {
        test_claim();

        uint256 stakeId = 0;
        vm.startPrank(depositor);
        vm.expectRevert(IHexOneVault.DepositNotActive.selector);
        vault.claim(stakeId);
        vm.stopPrank();
    }

    function test_claim_revertIfSharesNotMature() public {
        test_deposit();

        skip(3500 days);

        uint256 stakeId = 0;
        vm.startPrank(depositor);
        vm.expectRevert(IHexOneVault.SharesNotYetMature.selector);
        vault.claim(stakeId);
        vm.stopPrank();
    }

    function test_claim_revertIfDepositLiquidatable() public {
        test_deposit();

        skip(4008 days);

        uint256 stakeId = 0;
        vm.startPrank(depositor);
        vm.expectRevert(IHexOneVault.PositionLiquidatable.selector);
        vault.claim(stakeId);
        vm.stopPrank();
    }

    function test_claim_revertIfInvalidStakeId() public {
        test_deposit();

        uint256 stakeId = 1000;
        vm.startPrank(depositor);
        vm.expectRevert();
        vault.claim(stakeId);
        vm.stopPrank();
    }

    function test_borrow() public {
        test_deposit();

        uint256 stakeId = 0;

        skip(feed.PERIOD());
        feed.update();

        vm.prank(depositor);
        vault.borrow(HEXONE_BORROW_AMOUNT, stakeId);

        // assert userInfos.totalBorrowed
        (,, uint256 totalBorrowed) = vault.userInfos(depositor);
        assertEq(totalBorrowed, HEXONE_BORROW_AMOUNT);

        // assert depositInfo.borrowed
        (,, uint256 borrowed,,,) = vault.depositInfos(depositor, stakeId);
        assertEq(borrowed, HEXONE_BORROW_AMOUNT);

        // assert that HEX1 was minted to the user
        assertEq(IERC20(hex1).balanceOf(depositor), HEXONE_BORROW_AMOUNT);
    }

    function test_borrow_withDifferentStakeIds() public {
        // create a deposit that has stakeId = 0
        test_deposit();
        uint256 firstStakeId = 0;

        // deal more HEX tokens to the depositor to perform second deposit
        deal(hexToken, depositor, HEX_DEPOSIT_AMOUNT);

        // create the second deposit that has stakeId = 1
        vm.startPrank(depositor);
        IERC20(hexToken).approve(address(vault), HEX_DEPOSIT_AMOUNT);
        uint256 secondStakeId = vault.deposit(HEX_DEPOSIT_AMOUNT, 4000);
        vm.stopPrank();

        // setup the inital state of the oracle
        skip(feed.PERIOD());
        feed.update();

        // borrow against the stakeId = 0
        vm.prank(depositor);
        vault.borrow(HEXONE_BORROW_AMOUNT, firstStakeId);

        // borrow against the stakeId = 1
        vm.prank(depositor);
        vault.borrow(HEXONE_BORROW_AMOUNT, secondStakeId);

        // assert total amount borrowed by depositor accross both stakes
        (,, uint256 totalBorrowed) = vault.userInfos(depositor);
        assertEq(totalBorrowed, HEXONE_BORROW_AMOUNT * 2);
        assertEq(IERC20(hex1).balanceOf(depositor), HEXONE_BORROW_AMOUNT * 2);
    }

    function test_borrow_revertIfDepositMature() public {
        test_deposit();

        uint256 stakeId = 0;

        skip(4001 days);

        vm.startPrank(depositor);
        vm.expectRevert(IHexOneVault.CantBorrowFromMatureDeposit.selector);
        vault.borrow(HEXONE_BORROW_AMOUNT, stakeId);
        vm.stopPrank();
    }

    function test_borrow_revertIfBorrowAmountIsZero() public {
        test_deposit();

        uint256 stakeId = 0;

        vm.startPrank(depositor);
        vm.expectRevert(IHexOneVault.InvalidBorrowAmount.selector);
        vault.borrow(0, stakeId);
        vm.stopPrank();
    }

    function test_borrow_revertIfBorrowAmountTooHigh() public {
        test_deposit();

        uint256 stakeId = 0;

        skip(feed.PERIOD());
        feed.update();

        vm.startPrank(depositor);
        vm.expectRevert(IHexOneVault.BorrowAmountTooHigh.selector);
        vault.borrow(HEXONE_BORROW_AMOUNT * 1000, stakeId);
        vm.stopPrank();
    }

    function test_liquidate() public {
        test_deposit();

        uint256 stakeId = 0;

        // skip deposit period + grace period to ensure deposit is liquidatable.
        skip(4008 days);

        // give HEX1 to the liquidator so that he can repay the depositor debt.
        deal(address(hex1), liquidator, HEXONE_BORROW_AMOUNT);

        // liquidate the depositor stake
        vm.prank(liquidator);
        uint256 hexAmount = vault.liquidate(depositor, stakeId);

        // assert deposit information
        (uint256 amount, uint256 shares, uint256 borrowed,,, bool active) = vault.depositInfos(depositor, 0);
        assertEq(amount, 0);
        assertEq(shares, 0);
        assertEq(borrowed, 0);
        assertEq(active, false);

        // assert that the liquidator got the HEX tokens + yield
        assertEq(IERC20(hexToken).balanceOf(liquidator), hexAmount);
    }

    function test_liquidate_withDebt() public {
        test_borrow();

        uint256 stakeId = 0;

        skip(4008 days);

        deal(address(hex1), liquidator, HEXONE_BORROW_AMOUNT);

        vm.startPrank(liquidator);
        IERC20(hex1).approve(address(vault), HEXONE_BORROW_AMOUNT);
        uint256 hexAmount = vault.liquidate(depositor, stakeId);
        vm.stopPrank();

        assertEq(IERC20(hexToken).balanceOf(liquidator), hexAmount);
    }

    function test_liquidate_revertIfPositionNotLiquidatable() public {
        test_deposit();

        uint256 stakeId = 0;

        vm.startPrank(liquidator);
        vm.expectRevert(IHexOneVault.PositionNotLiquidatable.selector);
        vault.liquidate(depositor, stakeId);
        vm.stopPrank();
    }

    function test_liquidate_revertIfDepositNotActive() public {
        test_liquidate();

        uint256 stakeId = 0;

        vm.startPrank(depositor);
        vm.expectRevert(IHexOneVault.DepositNotActive.selector);
        vault.liquidate(depositor, stakeId);
        vm.stopPrank();
    }
}
