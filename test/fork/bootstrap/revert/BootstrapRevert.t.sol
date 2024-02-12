// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import "../../Base.t.sol";

import {BootstrapHelper} from "../../utils/BootstrapHelper.sol";

/**
 *  @dev forge test --match-contract BootstrapRevertTest -vvv
 */
contract BootstrapRevertTest is BootstrapHelper {
    /*//////////////////////////////////////////////////////////////////////////
                                SET BASE DATA
    //////////////////////////////////////////////////////////////////////////*/

    function test_revert_setBaseData_ContractAlreadySet() public {
        address mockFeed = makeAddr("feed");
        address mockStaking = makeAddr("staking");
        address mockVault = makeAddr("vault");

        vm.startPrank(deployer);

        vm.expectRevert(IHexOneBootstrap.ContractAlreadySet.selector);
        bootstrap.setBaseData(mockFeed, mockStaking, mockVault);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                SET SACRIFICE START
    //////////////////////////////////////////////////////////////////////////*/

    function test_revert_setSacrificeStart_SacrificeStartAlreadySet() public {
        vm.startPrank(deployer);

        vm.expectRevert(IHexOneBootstrap.SacrificeStartAlreadySet.selector);
        bootstrap.setSacrificeStart(block.timestamp + 7 days);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    SACRIFICE
    //////////////////////////////////////////////////////////////////////////*/

    function test_revert_sacrifice_SacrificeHasNotStartedYet() public {
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

    function test_revert_sacrifice_SacrificeAlreadyEnded() public {
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

    function test_revert_processSacrifice_SacrificeHasNotEndedYet() public {
        // impersonate the deployer
        vm.startPrank(deployer);

        // expect the process sacrifice function to revert because sacrifice has not ended yet
        vm.expectRevert(abi.encodeWithSelector(IHexOneBootstrap.SacrificeHasNotEndedYet.selector, block.timestamp));
        bootstrap.processSacrifice(1);

        // stop impersonating the deployer
        vm.stopPrank();
    }

    function test_revert_processSacrifice_SacrificeAlreadyProcessed() public {
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

    /*//////////////////////////////////////////////////////////////////////////
                                CLAIM SACRIFICE
    //////////////////////////////////////////////////////////////////////////*/

    function test_revert_claimSacrifice_SacrificeHasNotBeenProcessedYet() public {
        uint256 amount = 10_000_000 * 1e8;

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

    function test_revert_claimSacrifice_DidNotParticipateInSacrifice() public {
        uint256 amount = 10_000_000 * 1e8;

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

    function test_revert_claimSacrifice_SacrificeClaimPeriodAlreadyFinished() public {
        uint256 amount = 10_000_000 * 1e8;

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

    function test_revert_claimSacrifice_SacrificeAlreadyClaimed() public {
        uint256 amount = 10_000_000 * 1e8;

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

    function test_revert_startAirdrop_SacrificeClaimPeriodHasNotFinished() public {
        uint256 amount = 10_000_000 * 1e8;

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

    function test_revert_startAirdrop_AirdropAlreadyStarted() public {
        uint256 amount = 10_000_000 * 1e8;

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

    function test_revert_claimAirdrop_AirdropHasNotStartedYet() public {
        uint256 amount = 10_000_000 * 1e8;

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

        // user claims HEX1 and HEXIT from the sacrifice
        vm.startPrank(user);
        bootstrap.claimSacrifice();
        vm.stopPrank();

        // skip the sacrifice claim period
        skip(7 days);

        // try to claim the airdrop before it starts
        vm.startPrank(user);

        vm.expectRevert(abi.encodeWithSelector(IHexOneBootstrap.AirdropHasNotStartedYet.selector, block.timestamp));
        bootstrap.claimAirdrop();

        vm.stopPrank();
    }

    function test_revert_claimAirdrop_AirdropAlreadyEnded() public {
        uint256 amount = 10_000_000 * 1e8;

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

        // user claims HEX1 and HEXIT from the sacrifice
        vm.startPrank(user);
        bootstrap.claimSacrifice();
        vm.stopPrank();

        // skip the sacrifice claim period
        skip(7 days);

        // start the airdrop
        vm.prank(deployer);
        bootstrap.startAirdrop();

        // skip 30 days to ensure that airdrop claim period already finished
        skip(30 days);

        // expect the claim function to revert because airdrop claim period already finished
        vm.startPrank(user);

        vm.expectRevert(abi.encodeWithSelector(IHexOneBootstrap.AirdropAlreadyEnded.selector, block.timestamp));
        bootstrap.claimAirdrop();

        vm.stopPrank();
    }

    function test_revert_claimAirdrop_AirdropAlreadyClaimed() public {
        uint256 amount = 10_000_000 * 1e8;

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

        // user claims HEX1 and HEXIT from the sacrifice
        vm.startPrank(user);
        bootstrap.claimSacrifice();
        vm.stopPrank();

        // skip the sacrifice claim period
        skip(7 days);

        // start the airdrop
        vm.prank(deployer);
        bootstrap.startAirdrop();

        // expect the claim function to revert because airdrop claim period already finished
        vm.startPrank(user);

        bootstrap.claimAirdrop();

        vm.expectRevert(abi.encodeWithSelector(IHexOneBootstrap.AirdropAlreadyClaimed.selector, user));
        bootstrap.claimAirdrop();

        vm.stopPrank();
    }

    function test_revert_claimAirdrop_IneligibleForAirdrop() public {
        uint256 amount = 10_000_000 * 1e8;

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

        // user claims HEX1 and HEXIT from the sacrifice
        vm.startPrank(user);
        bootstrap.claimSacrifice();
        vm.stopPrank();

        // skip the sacrifice claim period
        skip(7 days);

        // start the airdrop
        vm.prank(deployer);
        bootstrap.startAirdrop();

        // expect the claim function to revert because airdrop claim period already finished
        vm.startPrank(attacker);

        vm.expectRevert(abi.encodeWithSelector(IHexOneBootstrap.IneligibleForAirdrop.selector, attacker));
        bootstrap.claimAirdrop();

        vm.stopPrank();
    }
}
