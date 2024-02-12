// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import "../../Base.t.sol";

import {StakingHelper} from "../../utils/StakingHelper.sol";

/**
 *  @dev forge test --match-contract StakingRevertTest -vvv
 */
contract StakingRevertTest is StakingHelper {
    /*//////////////////////////////////////////////////////////////////////////
                                SET BASE DATA
    //////////////////////////////////////////////////////////////////////////*/

    function test_revert_setBaseData_BaseDataAlreadySet() public {
        address mockVault = makeAddr("vault");
        address mockBootstrap = makeAddr("bootstrap");

        vm.startPrank(deployer);

        vm.expectRevert(IHexOneStaking.BaseDataAlreadySet.selector);
        staking.setBaseData(mockVault, mockBootstrap);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                ENABLE STAKING
    //////////////////////////////////////////////////////////////////////////*/

    function test_revert_enableStaking_StakingAlreadyEnabled() public {
        uint256 initialHexAmount = 1000 * 1e8;
        uint256 initialHexitAmount = 2000 * 1e18;
        _initialPurchase(initialHexAmount, initialHexitAmount);

        // tries to enable staking twice
        vm.startPrank(address(bootstrap));

        staking.enableStaking();

        vm.expectRevert(IHexOneStaking.StakingAlreadyEnabled.selector);
        staking.enableStaking();

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                SET STAKE TOKENS
    //////////////////////////////////////////////////////////////////////////*/

    function test_revert_setStakeTokens_InvalidArrayLength() public {
        address[] memory tokens = new address[](0);
        uint16[] memory weights = new uint16[](0);

        vm.startPrank(deployer);

        vm.expectRevert(abi.encodeWithSelector(IHexOneStaking.InvalidArrayLength.selector, 0));
        staking.setStakeTokens(tokens, weights);

        vm.stopPrank();
    }

    function test_revert_setStaketokens_MismatchedArray() public {
        address[] memory tokens = new address[](2);
        uint16[] memory weights = new uint16[](1);

        vm.startPrank(deployer);

        vm.expectRevert(IHexOneStaking.MismatchedArray.selector);
        staking.setStakeTokens(tokens, weights);

        vm.stopPrank();
    }

    function test_revert_setStakeTokens_TokenAlreadyAdded() public {
        address[] memory tokens = new address[](2);
        tokens[0] = daiToken;
        tokens[1] = daiToken;

        uint16[] memory weights = new uint16[](2);
        weights[0] = 800;
        weights[1] = 200;

        vm.startPrank(deployer);

        vm.expectRevert(abi.encodeWithSelector(IHexOneStaking.StakeTokenAlreadyAdded.selector, daiToken));
        staking.setStakeTokens(tokens, weights);

        vm.stopPrank();
    }

    function test_revert_setStakeTokens_InvalidWeight() public {
        address[] memory tokens = new address[](2);
        tokens[0] = hexToken;
        tokens[1] = daiToken;

        uint16[] memory weights = new uint16[](2);
        weights[0] = 1200;
        weights[1] = 200;

        vm.startPrank(deployer);

        vm.expectRevert(abi.encodeWithSelector(IHexOneStaking.InvalidWeight.selector, 1200));
        staking.setStakeTokens(tokens, weights);

        vm.stopPrank();
    }

    function test_revert_setStakeTokens_InvalidWeightSum() public {
        address[] memory tokens = new address[](2);
        tokens[0] = hexToken;
        tokens[1] = daiToken;

        uint16[] memory weights = new uint16[](2);
        weights[0] = 900;
        weights[1] = 200;

        vm.startPrank(deployer);

        vm.expectRevert(abi.encodeWithSelector(IHexOneStaking.InvalidWeightSum.selector, 1100));
        staking.setStakeTokens(tokens, weights);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    PURCHASE
    //////////////////////////////////////////////////////////////////////////*/

    function test_revert_purchase_InvalidPurchaseAmount() public {
        vm.startPrank(address(vault));

        vm.expectRevert(abi.encodeWithSelector(IHexOneStaking.InvalidPurchaseAmount.selector, 0));
        staking.purchase(hexToken, 0);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    STAKE
    //////////////////////////////////////////////////////////////////////////*/

    function test_revert_stake_StakingNotYetEnabled() public {
        vm.startPrank(user);

        vm.expectRevert(IHexOneStaking.StakingNotYetEnabled.selector);
        staking.stake(address(hex1), 1000 * 1e18);

        vm.stopPrank();
    }

    function test_revert_stake_InvalidStakeToken() public {
        // initial purchase amounts
        uint256 hexInitialPurchase = 1000 * 1e8;
        uint256 hexitInitialPurchase = 2000 * 1e18;
        _initialPurchase(hexInitialPurchase, hexitInitialPurchase);

        // after purchases are made the bootstrap enables staking
        vm.prank(address(bootstrap));
        staking.enableStaking();

        // reverts when trying to stake a non supported token
        address token = makeAddr("invalid stake token");
        vm.startPrank(user);

        vm.expectRevert(abi.encodeWithSelector(IHexOneStaking.InvalidStakeToken.selector, token));
        staking.stake(token, 1000 * 1e18);

        vm.stopPrank();
    }

    function test_revert_stake_InvalidStakeAmount() public {
        // initial purchase amounts
        uint256 hexInitialPurchase = 1000 * 1e8;
        uint256 hexitInitialPurchase = 2000 * 1e18;
        _initialPurchase(hexInitialPurchase, hexitInitialPurchase);

        // after purchases are made the bootstrap enables staking
        vm.prank(address(bootstrap));
        staking.enableStaking();

        // reverts when trying to deposit an invalid amount of a supported token
        vm.startPrank(user);

        vm.expectRevert(abi.encodeWithSelector(IHexOneStaking.InvalidStakeAmount.selector, 0));
        staking.stake(address(hex1), 0);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    UNSTAKE
    //////////////////////////////////////////////////////////////////////////*/

    function test_revert_unstake_InvalidStakeToken() public {
        // initial purchase amounts
        uint256 hexInitialPurchase = 1000 * 1e8;
        uint256 hexitInitialPurchase = 2000 * 1e18;
        _initialPurchase(hexInitialPurchase, hexitInitialPurchase);

        // after purchases are made the bootstrap enables staking
        vm.prank(address(bootstrap));
        staking.enableStaking();

        // user tries to unstake an invalid token
        address token = makeAddr("invalid stake token");
        vm.startPrank(user);

        vm.expectRevert(abi.encodeWithSelector(IHexOneStaking.InvalidStakeToken.selector, token));
        staking.unstake(token, 1000);

        vm.stopPrank();
    }

    function test_revert_unstake_InvalidUnstakeAmount() public {
        // initial purchase amounts
        uint256 hexInitialPurchase = 1000 * 1e8;
        uint256 hexitInitialPurchase = 2000 * 1e18;
        _initialPurchase(hexInitialPurchase, hexitInitialPurchase);

        // after purchases are made the bootstrap enables staking
        vm.prank(address(bootstrap));
        staking.enableStaking();

        // user tries to unstake an invalid amount
        vm.startPrank(user);

        vm.expectRevert(abi.encodeWithSelector(IHexOneStaking.InvalidUnstakeAmount.selector, 0));
        staking.unstake(address(hex1), 0);

        vm.stopPrank();
    }

    function test_revert_unstake_MinUnstakeDaysNotElapsed() public {
        // initial purchase amounts
        uint256 hexInitialPurchase = 1000 * 1e8;
        uint256 hexitInitialPurchase = 2000 * 1e18;
        _initialPurchase(hexInitialPurchase, hexitInitialPurchase);

        // after purchases are made the bootstrap enables staking
        vm.prank(address(bootstrap));
        staking.enableStaking();

        deal(address(hex1), user, 100 * 1e18);

        vm.startPrank(user);

        // user stakes HEX1
        hex1.approve(address(staking), 100 * 1e18);
        staking.stake(address(hex1), 100 * 1e18);

        // user tries to unstake right after
        vm.expectRevert(IHexOneStaking.MinUnstakeDaysNotElapsed.selector);
        staking.unstake(address(hex1), 100 * 1e18);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    CLAIM
    //////////////////////////////////////////////////////////////////////////*/

    function test_revert_claim_InvalidStakeToken() public {
        // initial purchase amounts
        uint256 hexInitialPurchase = 1000 * 1e8;
        uint256 hexitInitialPurchase = 2000 * 1e18;
        _initialPurchase(hexInitialPurchase, hexitInitialPurchase);

        // after purchases are made the bootstrap enables staking
        vm.prank(address(bootstrap));
        staking.enableStaking();

        address token = makeAddr("invalid stake token");
        vm.startPrank(user);

        vm.expectRevert(abi.encodeWithSelector(IHexOneStaking.InvalidStakeToken.selector, token));
        staking.claim(token);

        vm.stopPrank();
    }
}
