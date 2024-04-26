// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../Base.t.sol";

contract VaultAssert is Base {
    uint256 internal constant HEX_DEPOSIT = 100_000e8;

    address internal hex1;
    address internal hex1Dai;

    function setUp() public virtual override {
        super.setUp();

        hex1 = vault.hex1();

        // create HEX1/DAI pair
        hex1Dai = hex1Dai = IPulseXFactory(PULSEX_FACTORY_V2).createPair(address(hex1), DAI_TOKEN);
        if (hex1Dai == address(0)) {
            hex1Dai = IPulseXFactory(PULSEX_FACTORY_V2).createPair(address(hex1), DAI_TOKEN);
        }

        // deal tokens to the owner
        deal(hex1, owner, 100_000e18);
        deal(DAI_TOKEN, owner, 100_000e18);

        // approve and add liquidity through the pulsex v2 router
        vm.startPrank(owner);
        IERC20(hex1).approve(address(PULSEX_ROUTER_V2), 100_000e18);
        IERC20(DAI_TOKEN).approve(address(PULSEX_ROUTER_V2), 100_000e18);

        IPulseXRouter(PULSEX_ROUTER_V2).addLiquidity(
            hex1, DAI_TOKEN, 100_000e18, 100_000e18, 100_000e18, 100_000e18, address(this), block.timestamp
        );
        vm.stopPrank();

        // update the price feed for the first time
        skip(feed.period());
        feed.update();
    }

    function test_constructor() external {
        assertEq(vault.feed(), address(feed));
    }

    function test_enableBuyback() external prank(owner) {
        vault.enableBuyback();
        assertEq(vault.buybackEnabled(), true);
    }

    function test_deposit_buybackDisabled() external {
        deal(address(HEX_TOKEN), address(this), HEX_DEPOSIT);

        IERC20(HEX_TOKEN).approve(address(vault), HEX_DEPOSIT);
        uint256 tokenId = vault.deposit(HEX_DEPOSIT);

        assertEq(tokenId, 0);

        (uint256 debt, uint72 amount,,,,) = vault.stakes(tokenId);
        assertEq(debt, 0);
        assertEq(uint256(amount), HEX_DEPOSIT);

        assertEq(IERC20(HEX_TOKEN).balanceOf(address(this)), 0);
        assertEq(vault.ownerOf(tokenId), address(this));
    }

    function test_deposit_buybackEnabled() external {
        deal(address(HEX_TOKEN), address(this), HEX_DEPOSIT);

        vm.prank(owner);
        vault.enableBuyback();

        IERC20(HEX_TOKEN).approve(address(vault), HEX_DEPOSIT);
        uint256 tokenId = vault.deposit(HEX_DEPOSIT);

        assertEq(tokenId, 0);

        (uint256 debt, uint72 amount,,,,) = vault.stakes(tokenId);
        assertEq(debt, 0);
        assertEq(uint256(amount), HEX_DEPOSIT - ((HEX_DEPOSIT * 100) / 10_000));

        assertEq(IERC20(HEX_TOKEN).balanceOf(address(this)), 0);
        assertEq(vault.ownerOf(tokenId), address(this));
    }

    function test_withdraw_withoutDebt() external {
        deal(address(HEX_TOKEN), address(this), HEX_DEPOSIT);

        IERC20(HEX_TOKEN).approve(address(vault), HEX_DEPOSIT);
        uint256 tokenId = vault.deposit(HEX_DEPOSIT);

        vm.warp(block.timestamp + 5556 days);

        (uint256 hxAmount, uint256 hdrnAmount) = vault.withdraw(tokenId);
        console.log(hxAmount);
        console.log(hdrnAmount);

        (uint256 debt, uint72 amount, uint72 shares, uint40 param, uint16 start, uint16 end) = vault.stakes(tokenId);
        assertEq(debt, 0);
        assertEq(amount, 0);
        assertEq(shares, 0);
        assertEq(param, 0);
        assertEq(start, 0);
        assertEq(end, 0);

        assertEq(vault.balanceOf(address(this)), 0);

        assertTrue(hxAmount > HEX_DEPOSIT);
    }

    function test_withdraw_withDebt() external {}

    function test_liquidate_withoutDebt() external {}

    function test_liquidate_withDebt() external {}

    function test_repay() external {}

    function test_borrow_initialDay() external {
        deal(address(HEX_TOKEN), address(this), HEX_DEPOSIT);

        IERC20(HEX_TOKEN).approve(address(vault), HEX_DEPOSIT);
        uint256 tokenId = vault.deposit(HEX_DEPOSIT);

        uint256 hex1Minted = vault.maxBorrowable(tokenId);
        vault.borrow(tokenId, hex1Minted);

        (uint256 debt,,,,,) = vault.stakes(tokenId);
        assertEq(debt, hex1Minted);
        assertEq(IERC20(hex1).balanceOf(address(this)), hex1Minted);

        uint256 healthRatio = vault.healthRatio(tokenId);
        console.log("HEX health ratio  :", healthRatio);
    }

    function test_borrow_afterDays() external {
        deal(address(HEX_TOKEN), address(this), HEX_DEPOSIT);

        IERC20(HEX_TOKEN).approve(address(vault), HEX_DEPOSIT);
        uint256 tokenId = vault.deposit(HEX_DEPOSIT);

        skip(365 days);

        IHexToken(HEX_TOKEN).dailyDataUpdate(0);

        feed.update();

        uint256 hex1Minted = vault.maxBorrowable(tokenId);
        vault.borrow(tokenId, hex1Minted);

        (uint256 debt,,,,,) = vault.stakes(tokenId);
        assertEq(debt, hex1Minted);
        assertEq(IERC20(hex1).balanceOf(address(this)), hex1Minted);

        uint256 healthRatio = vault.healthRatio(tokenId);
        console.log("HEX health ratio  :", healthRatio);
    }

    function test_take_withoutDebt() external {}

    function test_take_withDebt() external {}
}
