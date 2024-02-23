// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import "../../Base.t.sol";

contract VaultRevertTest is Base {
    function setUp() public override {
        super.setUp();

        // set sacrifice status to true
        vm.prank(bootstrap);
        vault.setSacrificeStatus();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                SET SACRIFICE STATUS
    //////////////////////////////////////////////////////////////////////////*/

    function test_revert_setSacrificeStatus_VaultAlreadyActive() public {
        vm.startPrank(bootstrap);

        vm.expectRevert(IHexOneVault.VaultAlreadyActive.selector);
        vault.setSacrificeStatus();

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                SET BASE DATA
    //////////////////////////////////////////////////////////////////////////*/

    function test_revert_setBaseData_ContractAlreadySet() public {
        address feedMock = makeAddr("feed mock");
        address stakingMock = makeAddr("staking mock");
        address bootstrapMock = makeAddr("bootstrap mock");

        vm.startPrank(deployer);

        vm.expectRevert(IHexOneVault.ContractAlreadySet.selector);
        vault.setBaseData(feedMock, stakingMock, bootstrapMock);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                DEPOSIT
    //////////////////////////////////////////////////////////////////////////*/

    function test_revert_deposit_InvalidDepositDuration() public {
        uint256 amount = 1000e8;
        uint16 duration = 2000;

        vm.startPrank(user);

        vm.expectRevert(abi.encodeWithSelector(IHexOneVault.InvalidDepositDuration.selector, duration));
        vault.deposit(amount, duration);

        vm.stopPrank();
    }

    function test_revert_deposit_InvalidDepositAmount() public {
        uint256 amount = 0;
        uint16 duration = 5000;

        vm.startPrank(user);

        vm.expectRevert(abi.encodeWithSelector(IHexOneVault.InvalidDepositAmount.selector, amount));
        vault.deposit(amount, duration);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                DELEGATE DEPOSIT
    //////////////////////////////////////////////////////////////////////////*/

    function test_revert_delegateDeposit_InvalidDepositDuration() public {
        uint256 amount = 1000e8;
        uint16 duration = 2000;

        vm.startPrank(bootstrap);

        vm.expectRevert(abi.encodeWithSelector(IHexOneVault.InvalidDepositDuration.selector, duration));
        vault.delegateDeposit(user, amount, duration);

        vm.stopPrank();
    }

    function test_revert_delegateDeposit_InvalidDepositAmount() public {
        uint256 amount = 0;
        uint16 duration = 5000;

        vm.startPrank(bootstrap);

        vm.expectRevert(abi.encodeWithSelector(IHexOneVault.InvalidDepositAmount.selector, amount));
        vault.delegateDeposit(user, amount, duration);

        vm.stopPrank();
    }

    function test_revert_delegateDeposit_InvalidDepositor() public {
        uint256 amount = 1000e8;
        uint16 duration = 5555;

        vm.startPrank(bootstrap);

        vm.expectRevert(abi.encodeWithSelector(IHexOneVault.InvalidDepositor.selector, address(0)));
        vault.delegateDeposit(address(0), amount, duration);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                CLAIM
    //////////////////////////////////////////////////////////////////////////*/

    function test_revert_claim_DepositNotActive_DoesNotExist() public {
        uint256 stakeId = 1;

        vm.startPrank(user);

        vm.expectRevert(abi.encodeWithSelector(IHexOneVault.DepositNotActive.selector, user, stakeId));
        vault.claim(stakeId);

        vm.stopPrank();
    }

    function test_revert_claim_DepositNotActive_AlreadyClaimed() public {
        uint256 amount = 1000e8;
        uint16 duration = 5555;

        hexToken.mint(user, amount);

        vm.startPrank(user);

        hexToken.approve(address(vault), amount);
        (, uint256 stakeId) = vault.deposit(amount, duration);

        skip(5555 days);

        vault.claim(stakeId);

        vm.expectRevert(abi.encodeWithSelector(IHexOneVault.DepositNotActive.selector, user, stakeId));
        vault.claim(stakeId);

        vm.stopPrank();
    }

    function test_revert_claim_SharesNotYetMature() public {
        uint256 amount = 1000e8;
        uint16 duration = 5555;

        hexToken.mint(user, amount);

        vm.startPrank(user);

        hexToken.approve(address(vault), amount);
        (, uint256 stakeId) = vault.deposit(amount, duration);

        vm.expectRevert(abi.encodeWithSelector(IHexOneVault.SharesNotYetMature.selector, user, stakeId));
        vault.claim(stakeId);

        vm.stopPrank();
    }

    function test_revert_claim_DepositLiquidatable() public {
        uint256 amount = 1000e8;
        uint16 duration = 5555;

        hexToken.mint(user, amount);

        vm.startPrank(user);

        hexToken.approve(address(vault), amount);
        (, uint256 stakeId) = vault.deposit(amount, duration);

        // stake duration + grace period
        skip(5555 days + 7 days);

        vm.expectRevert(abi.encodeWithSelector(IHexOneVault.DepositLiquidatable.selector, user, stakeId));
        vault.claim(stakeId);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                BORROW
    //////////////////////////////////////////////////////////////////////////*/

    function test_revert_borrow_InvalidBorrowAmount() public {
        uint256 amount = 1000e8;
        uint16 duration = 5555;

        hexToken.mint(user, amount);

        vm.startPrank(user);

        hexToken.approve(address(vault), amount);
        (, uint256 stakeId) = vault.deposit(amount, duration);

        vm.expectRevert(abi.encodeWithSelector(IHexOneVault.InvalidBorrowAmount.selector, 0));
        vault.borrow(0, stakeId);

        vm.stopPrank();
    }

    function test_revert_borrow_DepositNotActive() public {
        uint256 stakeId = 1;
        uint256 amount = 1000e18; // 1000 USD

        vm.startPrank(user);

        vm.expectRevert(abi.encodeWithSelector(IHexOneVault.DepositNotActive.selector, user, stakeId));
        vault.borrow(amount, stakeId);

        vm.stopPrank();
    }

    function test_revert_borrow_BorrowAmountTooHigh() public {
        uint256 amount = 1000e8;
        uint16 duration = 5555;

        hexToken.mint(user, amount);

        vm.startPrank(user);

        hexToken.approve(address(vault), amount);
        (, uint256 stakeId) = vault.deposit(amount, duration);

        vm.stopPrank();

        // change the price of HEX so that it's possible to borrow
        feed.setRate(address(hexToken), address(daiToken), 18275940385037058);

        // amount of HEX1 to borrow
        uint256 hexOneAmount = 100_000 * 1e18; // 100k USD

        vm.startPrank(user);

        vm.expectRevert(abi.encodeWithSelector(IHexOneVault.BorrowAmountTooHigh.selector, hexOneAmount));
        vault.borrow(hexOneAmount, stakeId);

        vm.stopPrank();
    }
}
