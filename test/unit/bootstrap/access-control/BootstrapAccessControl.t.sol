// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import "../../../Base.t.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {BootstrapHelper} from "../BootstrapHelper.sol";

/**
 *  @dev forge test --match-contract BootstrapAccessControlTest --rpc-url "https://rpc.pulsechain.com" -vvv
 */
contract BootstrapAccessControlTest is BootstrapHelper {
    /*//////////////////////////////////////////////////////////////////////////
                                SET BASE DATA
    //////////////////////////////////////////////////////////////////////////*/

    function test_revert_setBaseData_notTheOwner(address sender) public {
        vm.assume(sender != address(0) && sender != deployer);

        address mockFeed = makeAddr("feed");
        address mockStaking = makeAddr("staking");
        address mockVault = makeAddr("vault");

        vm.startPrank(sender);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, sender));
        bootstrap.setBaseData(mockFeed, mockStaking, mockVault);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                SET SACRIFICE TOKENS
    //////////////////////////////////////////////////////////////////////////*/

    function test_revert_setSacrificeTokens_OwnableUnauthorizedAccount(address sender) public {
        vm.assume(sender != address(0) && sender != deployer);

        address[] memory tokens = new address[](3);
        tokens[0] = makeAddr("token0");
        tokens[1] = makeAddr("token1");
        tokens[2] = makeAddr("token2");

        uint16[] memory multipliers = new uint16[](3);
        multipliers[0] = 3000;
        multipliers[1] = 2000;
        multipliers[2] = 1000;

        vm.startPrank(sender);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, sender));
        bootstrap.setSacrificeTokens(tokens, multipliers);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                SET SACRIFICE START
    //////////////////////////////////////////////////////////////////////////*/

    function test_revert_setSacrificeStart_OwnableUnauthorizedAccount(address sender) public {
        vm.assume(sender != address(0) && sender != deployer);

        vm.startPrank(sender);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, sender));
        bootstrap.setSacrificeStart(block.timestamp);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                PROCESS SACRIFICE
    //////////////////////////////////////////////////////////////////////////*/

    function test_revert_processSacrifice_OwnableUnauthorizedAccount(address sender) public {
        vm.assume(sender != address(0) && sender != deployer);

        uint256 amount = 10_000_000 * 1e8;

        // give HEX to the user
        _dealToken(hexToken, user, amount);

        // user sacrifices HEX
        vm.startPrank(user);
        _sacrifice(hexToken, amount);
        vm.stopPrank();

        // skip 30 days so ensure that sacrifice period already ended
        skip(30 days);

        // random sender tries to process the sacrifice
        vm.startPrank(sender);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, sender));
        bootstrap.processSacrifice(1000); // note: reverts before param is used

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                START AIRDROP
    //////////////////////////////////////////////////////////////////////////*/

    function test_revert_startAirdrop_OwnableUnauthorizedAccount(address sender) public {
        vm.assume(sender != address(0) && sender != deployer);

        uint256 amount = 10_000_000 * 1e8;

        // give HEX to the user
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

        // user claims HEX1 and HEXIT from the sacrifice
        vm.startPrank(user);
        bootstrap.claimSacrifice();
        vm.stopPrank();

        // skip the sacrifice claim period
        skip(7 days);

        vm.startPrank(sender);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, sender));
        bootstrap.startAirdrop();

        vm.stopPrank();
    }
}
