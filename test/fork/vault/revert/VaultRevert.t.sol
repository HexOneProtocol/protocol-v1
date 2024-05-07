// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../Base.t.sol";

contract VaultRevert is Base {
    function setUp() public virtual override {
        super.setUp();

        skip(feed.period());
        feed.update();
    }

    function test_constructor_revert_ZeroAddress_feed() external {
        vm.expectRevert(IHexOneVault.ZeroAddress.selector);
        new HexOneVault(address(0), address(bootstrap));
    }

    function test_constructor_revert_ZeroAddress_bootstrap() external {
        vm.expectRevert(IHexOneVault.ZeroAddress.selector);
        new HexOneVault(address(feed), address(0));
    }

    function test_enableBuyback_revert_AccessControlUnauthorizedAccount() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), vault.BOOTSTRAP_ROLE()
            )
        );
        vault.enableBuyback();
    }

    function test_deposit_revert_InvalidAmount() external {
        vm.expectRevert(IHexOneVault.InvalidAmount.selector);
        vault.deposit(0);
    }

    function test_withdraw_revert_InvalidOwner() external {
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");

        deal(HEX_TOKEN, user1, 10_000e8);

        vm.startPrank(user1);
        IERC20(HEX_TOKEN).approve(address(vault), 10_000e8);
        uint256 tokenId = vault.deposit(10_000e8);
        vm.stopPrank();

        vm.startPrank(user2);
        vm.expectRevert(IHexOneVault.InvalidOwner.selector);
        vault.withdraw(tokenId);
        vm.stopPrank();
    }

    function test_withdraw_revert_StakeNotMature() external {
        deal(HEX_TOKEN, address(this), 10_000e8);

        IERC20(HEX_TOKEN).approve(address(vault), 10_000e8);
        uint256 tokenId = vault.deposit(10_000e8);

        vm.expectRevert(IHexOneVault.StakeNotMature.selector);
        vault.withdraw(tokenId);
    }

    function test_liquidate_revert_StakeNotLiquidatable() external {
        deal(HEX_TOKEN, address(this), 10_000e8);

        IERC20(HEX_TOKEN).approve(address(vault), 10_000e8);
        uint256 tokenId = vault.deposit(10_000e8);

        address liquidator = makeAddr("liquidator");
        vm.startPrank(liquidator);
        vm.expectRevert(IHexOneVault.StakeNotLiquidatable.selector);
        vault.liquidate(tokenId);
        vm.stopPrank();
    }

    function test_repay_revert_InvalidOwner() external {
        deal(HEX_TOKEN, address(this), 10_000e8);

        IERC20(HEX_TOKEN).approve(address(vault), 10_000e8);
        uint256 tokenId = vault.deposit(10_000e8);

        address user = makeAddr("user");
        vm.startPrank(user);
        vm.expectRevert(IHexOneVault.InvalidOwner.selector);
        vault.repay(tokenId, 0);
        vm.stopPrank();
    }

    function test_repay_revert_InvalidAmount() external {
        deal(HEX_TOKEN, address(this), 10_000e8);

        IERC20(HEX_TOKEN).approve(address(vault), 10_000e8);
        uint256 tokenId = vault.deposit(10_000e8);

        vm.expectRevert(IHexOneVault.InvalidAmount.selector);
        vault.repay(tokenId, 0);
    }

    function test_borrow_revert_InvalidOwner() external {
        deal(HEX_TOKEN, address(this), 10_000e8);

        IERC20(HEX_TOKEN).approve(address(vault), 10_000e8);
        uint256 tokenId = vault.deposit(10_000e8);

        address user = makeAddr("user");
        vm.startPrank(user);
        vm.expectRevert(IHexOneVault.InvalidOwner.selector);
        vault.borrow(tokenId, 0);
        vm.stopPrank();
    }

    function test_borrow_revert_InvalidAmount() external {
        deal(HEX_TOKEN, address(this), 10_000e8);

        IERC20(HEX_TOKEN).approve(address(vault), 10_000e8);
        uint256 tokenId = vault.deposit(10_000e8);

        vm.expectRevert(IHexOneVault.InvalidAmount.selector);
        vault.borrow(tokenId, 0);
    }

    function test_borrow_revert_StakeMature() external {
        deal(HEX_TOKEN, address(this), 10_000e8);

        IERC20(HEX_TOKEN).approve(address(vault), 10_000e8);
        uint256 tokenId = vault.deposit(10_000e8);

        vm.warp(block.timestamp + 5556 days);

        feed.update();

        vm.expectRevert(IHexOneVault.StakeMature.selector);
        vault.borrow(tokenId, 1);
    }

    function test_borrow_revert_MaxBorrowExceeded() external {
        deal(HEX_TOKEN, address(this), 10_000e8);

        IERC20(HEX_TOKEN).approve(address(vault), 10_000e8);
        uint256 tokenId = vault.deposit(10_000e8);

        uint256 maxBorrow = vault.maxBorrowable(tokenId);

        vm.expectRevert(IHexOneVault.MaxBorrowExceeded.selector);
        vault.borrow(tokenId, maxBorrow + 1e18);
    }

    function test_borrow_revert_HealthRatioTooLow() external {
        // TODO : manipulate the pool to test this
    }

    function test_take_revert_InvalidAmount() external {}

    function test_take_revert_HealthRatioTooHigh() external {
        deal(HEX_TOKEN, address(this), 10_000e8);

        IERC20(HEX_TOKEN).approve(address(vault), 10_000e8);
        uint256 tokenId = vault.deposit(10_000e8);

        address liquidator = makeAddr("liquidator");

        vm.startPrank(liquidator);
        vm.expectRevert(IHexOneVault.HealthRatioTooHigh.selector);
        vault.take(tokenId, 1);
        vm.stopPrank();
    }

    function test_take_revert_StakeNotLiquidatable() external {
        deal(HEX_TOKEN, address(this), 10_000e8);

        IERC20(HEX_TOKEN).approve(address(vault), 10_000e8);
        uint256 tokenId = vault.deposit(10_000e8);

        uint256 maxBorrow = vault.maxBorrowable(tokenId);
        vault.borrow(tokenId, maxBorrow);

        vm.warp(block.timestamp + 5556 days + 7 days);

        feed.update();

        IHexToken(HEX_TOKEN).dailyDataUpdate(0);

        address liquidator = makeAddr("liquidator");
        vm.startPrank(liquidator);
        vm.expectRevert(IHexOneVault.StakeNotLiquidatable.selector);
        vault.take(tokenId, 1);
        vm.stopPrank();
    }

    function test_take_revert_NotEnoughToTake() external {
        // TODO : manipulate the oracle to test this
    }

    function test_take_revert_HealthRatioTooLow() external {
        // TODO : manipulate the oracle to test this
    }
}
