// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {HexOneStaking} from "../../src/HexOneStaking.sol";
import {IHexOneStaking} from "../../src/interfaces/IHexOneStaking.sol";
import {HexTokenMock} from "../mocks/HexTokenMock.sol";
import {HexitTokenMock} from "../mocks/HexitTokenMock.sol";

contract HexOneStakingTest is Test {
    HexOneStaking public hexOneStaking;
    HexTokenMock public hexToken;
    HexitTokenMock public hexitToken;

    address public deployer = makeAddr("Deployer");
    address public user1 = makeAddr("User1");
    address public user2 = makeAddr("User2");
    address public protocol = makeAddr("HexOneProtocol");
    address public bootstrap = makeAddr("HexOneBootstrap");

    uint256 public constant PROTOCOL_HEX_BALANCE = 250_000 * 1e8;
    uint256 public constant BOOTSTRAP_HEXIT_BALANCE = 500_000 * 1e18;
    uint256 public constant USER_HEXIT_BALANCE = 50_000 * 1e18;

    function setUp() public {
        vm.startPrank(deployer);

        hexToken = new HexTokenMock();
        hexToken.mint(protocol, PROTOCOL_HEX_BALANCE);
        assertEq(hexToken.balanceOf(protocol), PROTOCOL_HEX_BALANCE);

        hexitToken = new HexitTokenMock();
        hexitToken.mint(bootstrap, BOOTSTRAP_HEXIT_BALANCE);
        assertEq(hexitToken.balanceOf(bootstrap), BOOTSTRAP_HEXIT_BALANCE);
        hexitToken.mint(user1, USER_HEXIT_BALANCE * 2);
        assertEq(hexitToken.balanceOf(user1), USER_HEXIT_BALANCE * 2);
        hexitToken.mint(user2, USER_HEXIT_BALANCE);
        assertEq(hexitToken.balanceOf(user2), USER_HEXIT_BALANCE);

        hexOneStaking = new HexOneStaking(address(hexToken), address(hexitToken), 10, 10);
        assertEq(hexOneStaking.hexToken(), address(hexToken));
        assertEq(hexOneStaking.hexitToken(), address(hexitToken));
        (,,,, uint16 hexDistRate) = hexOneStaking.pools(address(hexToken));
        (,,,, uint16 hexitDistRate) = hexOneStaking.pools(address(hexitToken));
        assertEq(hexDistRate, 10);
        assertEq(hexitDistRate, 10);

        hexOneStaking.setBaseData(protocol, bootstrap);
        assertEq(hexOneStaking.hexOneProtocol(), protocol);
        assertEq(hexOneStaking.hexOneBootstrap(), bootstrap);

        address[] memory tokens = new address[](3);
        uint16[] memory weights = new uint16[](3);
        tokens[0] = address(hexitToken);
        tokens[1] = makeAddr("HEX1 Token"); // mock
        tokens[2] = makeAddr("HEX1/DAI Token"); // mock
        weights[0] = 100;
        weights[1] = 200;
        weights[2] = 700;
        hexOneStaking.setStakeTokens(tokens, weights);
        assertEq(hexOneStaking.stakeTokenWeights(address(hexitToken)), 100);
        assertEq(hexOneStaking.stakeTokenWeights(makeAddr("HEX1 Token")), 200); // mock
        assertEq(hexOneStaking.stakeTokenWeights(makeAddr("HEX1/DAI Token")), 700); // mock

        vm.startPrank(protocol);
        hexToken.approve(address(hexOneStaking), PROTOCOL_HEX_BALANCE);
        hexOneStaking.purchase(address(hexToken), PROTOCOL_HEX_BALANCE);
        (uint256 hexTotalAssets,,,,) = hexOneStaking.pools(address(hexToken));
        assertEq(hexTotalAssets, PROTOCOL_HEX_BALANCE);
        assertEq(hexToken.balanceOf(address(hexOneStaking)), PROTOCOL_HEX_BALANCE);

        vm.startPrank(bootstrap);
        hexitToken.approve(address(hexOneStaking), BOOTSTRAP_HEXIT_BALANCE);
        hexOneStaking.purchase(address(hexitToken), BOOTSTRAP_HEXIT_BALANCE);
        (uint256 hexitTotalAssets,,,,) = hexOneStaking.pools(address(hexitToken));
        assertEq(hexitTotalAssets, BOOTSTRAP_HEXIT_BALANCE);
        assertEq(hexitToken.balanceOf(address(hexOneStaking)), BOOTSTRAP_HEXIT_BALANCE);

        vm.startPrank(deployer);
        hexOneStaking.enableStaking();
        assertEq(hexOneStaking.stakingEnabled(), true);
        assertEq(hexOneStaking.stakingLaunchTime(), block.timestamp);
        vm.stopPrank();
    }

    function test_stake() public {
        uint256 userBalanceBefore = hexitToken.balanceOf(user1);
        uint256 stakingBalanceBefore = hexitToken.balanceOf(address(hexOneStaking));

        // stake HEXIT
        vm.startPrank(user1);
        hexitToken.approve(address(hexOneStaking), USER_HEXIT_BALANCE);
        hexOneStaking.stake(address(hexitToken), USER_HEXIT_BALANCE);
        vm.stopPrank();

        // assert total amount staked of stake token
        assertEq(hexOneStaking.totalStakedAmount(address(hexitToken)), USER_HEXIT_BALANCE);

        // assert HEX and HEXIT total pool shares
        uint256 expectedShares = (USER_HEXIT_BALANCE * 100) / 1000;
        (,, uint256 totalHexShares,,) = hexOneStaking.pools(address(hexToken));
        assertEq(totalHexShares, expectedShares);
        (,, uint256 totalHexitShares,,) = hexOneStaking.pools(address(hexitToken));
        assertEq(totalHexitShares, expectedShares);

        // assert user staking information
        (
            uint256 stakedAmount,
            uint256 initStakeDay,
            uint256 lastClaimedDay,
            uint256 lastDepositedDay,
            uint256 userHexShares,
            uint256 userHexitShares,
            uint256 unclaimedHexRewards,
            uint256 unclaimedHexitRewards,
            ,
        ) = hexOneStaking.stakingInfos(user1, (address(hexitToken)));
        assertEq(stakedAmount, USER_HEXIT_BALANCE);
        assertEq(initStakeDay, 0);
        assertEq(lastClaimedDay, 0);
        assertEq(lastDepositedDay, 0);
        assertEq(userHexShares, expectedShares);
        assertEq(userHexitShares, expectedShares);

        // assert that no rewards were accrued
        assertEq(unclaimedHexRewards, 0);
        assertEq(unclaimedHexitRewards, 0);

        // assert token balances
        assertEq(hexitToken.balanceOf(user1), userBalanceBefore - USER_HEXIT_BALANCE);
        assertEq(hexitToken.balanceOf(address(hexOneStaking)), stakingBalanceBefore + USER_HEXIT_BALANCE);
    }

    function test_stake_accrueRewardsIfUserStakeAgain() public {
        test_stake();

        // assert that we are in the second staking day
        skip(2 days);
        assertEq(hexOneStaking.getCurrentStakingDay(), 2);

        uint256 userHexitBalanceBefore = hexitToken.balanceOf(user1);
        uint256 stakingHexitBalanceBefore = hexitToken.balanceOf(address(hexOneStaking));

        // stake more HEXIT tokens
        vm.startPrank(user1);
        hexitToken.approve(address(hexOneStaking), USER_HEXIT_BALANCE);
        hexOneStaking.stake(address(hexitToken), USER_HEXIT_BALANCE);
        vm.stopPrank();

        // TODO : assert pool history is updated for the HEX pool.
        // uint256 sumOfHexRewards;
        for (uint256 i = 0; i < 2; ++i) {
            (uint256 hexTotalShares, uint256 hexAmountToDistribute) = hexOneStaking.poolHistory(i, address(hexToken));

            console2.log("Day:                          ", i);
            console2.log("HEX total shares:             ", hexTotalShares);
            console2.log("HEX amount to distribute:     ", hexAmountToDistribute);
        }

        console2.log("");

        // TODO : assert pool history is updated for the HEXIT pool.
        // uint256 sumOfHexitRewards;
        for (uint256 i = 0; i < 2; ++i) {
            (uint256 hexitTotalShares, uint256 hexitAmountToDistribute) =
                hexOneStaking.poolHistory(i, address(hexitToken));

            console2.log("Day:                          ", i);
            console2.log("HEXIT total shares:           ", hexitTotalShares);
            console2.log("HEXIT amount to distribute:   ", hexitAmountToDistribute);
        }

        console2.log("");

        // assert that total amount of stake token was incremented
        assertEq(hexOneStaking.totalStakedAmount(address(hexitToken)), USER_HEXIT_BALANCE * 2);

        // assert that the total shares of each pool were incremented
        uint256 expectedShares = (USER_HEXIT_BALANCE * 100) / 1000;
        (,, uint256 totalHexShares,,) = hexOneStaking.pools(address(hexToken));
        assertEq(totalHexShares, expectedShares * 2);
        (,, uint256 totalHexitShares,,) = hexOneStaking.pools(address(hexitToken));
        assertEq(totalHexitShares, expectedShares * 2);

        // assert user staking information
        (,, uint256 lastClaimedDay,,,, uint256 unclaimedHexRewards, uint256 unclaimedHexitRewards,,) =
            hexOneStaking.stakingInfos(user1, address(hexitToken));
        assertEq(lastClaimedDay, 2);

        // TODO : assert that rewards were accrued
        // assertEq(unclaimedHexRewards, );
        // assertEq(unclaimedHexitRewards, );
        console2.log("HEX unclaimed:                ", unclaimedHexRewards);
        console2.log("HEXIT unclaimed:              ", unclaimedHexitRewards);

        // assert balances
        assertEq(hexitToken.balanceOf(user1), userHexitBalanceBefore - USER_HEXIT_BALANCE);
        assertEq(hexitToken.balanceOf(address(hexOneStaking)), stakingHexitBalanceBefore + USER_HEXIT_BALANCE);
    }

    function test_stake_poolSharesSplittedByStakers() public {
        // user1 stakes HEXIT
        vm.startPrank(user1);
        hexitToken.approve(address(hexOneStaking), USER_HEXIT_BALANCE);
        hexOneStaking.stake(address(hexitToken), USER_HEXIT_BALANCE);
        vm.stopPrank();

        // user2 stakes HEXIT
        vm.startPrank(user2);
        hexitToken.approve(address(hexOneStaking), USER_HEXIT_BALANCE);
        hexOneStaking.stake(address(hexitToken), USER_HEXIT_BALANCE);
        vm.stopPrank();

        // advance timestamp in 2 days
        skip(2 days);
        assertEq(hexOneStaking.getCurrentStakingDay(), 2);

        // assert HEX pool
        uint256 expectedTotalShares = (USER_HEXIT_BALANCE * 2 * 100) / 1000;
        (,, uint256 hexTotalShares,,) = hexOneStaking.pools(address(hexToken));
        assertEq(hexTotalShares, expectedTotalShares);

        // assert sum of users shares equals HEX total shares
        (,,,, uint256 user1HexShares, uint256 user1HexitShares,,,,) =
            hexOneStaking.stakingInfos(user1, address(hexitToken));
        (,,,, uint256 user2HexShares, uint256 user2HexitShares,,,,) =
            hexOneStaking.stakingInfos(user2, address(hexitToken));
        assertEq(user1HexShares + user2HexShares, hexTotalShares);

        // assert user1 HEX shares are equal to user2 HEX shares
        assertEq(user1HexShares, user2HexShares);

        // assert HEXIT pool
        (,, uint256 hexitTotalShares,,) = hexOneStaking.pools(address(hexitToken));
        assertEq(hexitTotalShares, expectedTotalShares);

        // assert sum of users shares equals HEXIT total shares
        assertEq(user1HexitShares + user2HexitShares, hexitTotalShares);

        // assert user1 HEXIT shares are equal to user2 HEXIT shares
        assertEq(user1HexitShares, user2HexitShares);
    }

    function test_stake_multipleUsersRestakeAfterInactivity() internal {}

    function test_unstake_afterTwoDays() internal {
        vm.startPrank(user1);
        hexitToken.approve(address(hexOneStaking), USER_HEXIT_BALANCE);
        hexOneStaking.stake(address(hexitToken), USER_HEXIT_BALANCE);
        vm.stopPrank();

        skip(2 days);

        vm.startPrank(user1);
        hexOneStaking.unstake(address(hexitToken), USER_HEXIT_BALANCE);
        vm.stopPrank();
    }

    function test_unstake_halfAfterTwoDays() internal {
        vm.startPrank(user1);
        hexitToken.approve(address(hexOneStaking), USER_HEXIT_BALANCE);
        hexOneStaking.stake(address(hexitToken), USER_HEXIT_BALANCE);
        vm.stopPrank();

        skip(2 days);

        vm.startPrank(user1);
        hexOneStaking.unstake(address(hexitToken), USER_HEXIT_BALANCE / 2);
        vm.stopPrank();
    }

    function test_unstake_unstakeHalfAccruesHalfOfTheRewards() internal {}

    function test_unstake_revertIfStakedLessThanTwoDaysAgo() public {
        vm.startPrank(user1);
        hexitToken.approve(address(hexOneStaking), USER_HEXIT_BALANCE);
        hexOneStaking.stake(address(hexitToken), USER_HEXIT_BALANCE);
        vm.stopPrank();

        skip(1 days);

        vm.startPrank(user1);
        vm.expectRevert("Minimum time to unstake is 2 days");
        hexOneStaking.unstake(address(hexitToken), USER_HEXIT_BALANCE);
        vm.stopPrank();
    }

    function test_unstake_revertIfReStakedLessThanTwoDaysAgo() public {
        vm.startPrank(user1);
        hexitToken.approve(address(hexOneStaking), USER_HEXIT_BALANCE);
        hexOneStaking.stake(address(hexitToken), USER_HEXIT_BALANCE);
        vm.stopPrank();

        skip(7 days);

        vm.startPrank(user1);
        hexitToken.approve(address(hexOneStaking), USER_HEXIT_BALANCE);
        hexOneStaking.stake(address(hexitToken), USER_HEXIT_BALANCE);
        vm.stopPrank();

        skip(1 days);

        vm.startPrank(user1);
        vm.expectRevert("Minimum time to unstake is 2 days");
        hexOneStaking.unstake(address(hexitToken), USER_HEXIT_BALANCE * 2);
        vm.stopPrank();
    }

    function test_claim() public {
        vm.startPrank(user1);
        hexitToken.approve(address(hexOneStaking), USER_HEXIT_BALANCE);
        hexOneStaking.stake(address(hexitToken), USER_HEXIT_BALANCE);
        vm.stopPrank();

        skip(2 days);

        uint256 userHexBalanceBefore = hexToken.balanceOf(user1);
        uint256 userHexitBalanceBefore = hexitToken.balanceOf(address(user1));

        vm.startPrank(user1);
        hexOneStaking.claim(address(hexitToken));
        vm.stopPrank();

        // assert that the unclaimed amount of HEX and HEXIT is zero
        (,,,,,, uint256 unclaimedHex, uint256 unclaimedHexit, uint256 totalHexClaimed, uint256 totalHexitClaimed) =
            hexOneStaking.stakingInfos(user1, (address(hexitToken)));
        assertEq(unclaimedHex, 0);
        assertEq(unclaimedHexit, 0);

        // assert that the total amount of HEX and HEXIT claimed is equal to
        // the difference of balances before and after the claim
        uint256 userHexBalanceAfter = hexToken.balanceOf(user1);
        uint256 userHexitBalanceAfter = hexitToken.balanceOf(address(user1));
        assertEq(totalHexClaimed, userHexBalanceAfter - userHexBalanceBefore);
        assertEq(totalHexitClaimed, userHexitBalanceAfter - userHexitBalanceBefore);
    }

    function test_claim_again() public {
        test_claim();

        uint256 userHexBalanceBefore = hexToken.balanceOf(user1);
        uint256 userHexitBalanceBefore = hexitToken.balanceOf(user1);

        vm.startPrank(user1);
        hexOneStaking.claim(address(hexitToken));
        vm.stopPrank();

        uint256 userHexBalanceAfter = hexToken.balanceOf(user1);
        uint256 userHexitBalanceAfter = hexitToken.balanceOf(user1);

        // assert that no rewards were claimed by the user
        assertEq(userHexBalanceAfter - userHexBalanceBefore, 0);
        assertEq(userHexitBalanceAfter - userHexitBalanceBefore, 0);
    }

    function test_claim_againAfterOneDay() public {
        test_claim();

        skip(1 days);

        // get user HEX and HEXIT balance before claiming
        uint256 userHexBalanceBefore = hexToken.balanceOf(user1);
        uint256 userHexitBalanceBefore = hexitToken.balanceOf(user1);

        vm.startPrank(user1);
        hexOneStaking.claim(address(hexitToken));
        vm.stopPrank();

        // get user HEX and HEXIT balance after staking
        uint256 userHexBalanceAfter = hexToken.balanceOf(user1);
        uint256 userHexitBalanceAfter = hexitToken.balanceOf(user1);

        // since only user1 staked he has all the shares, so we can assume
        // that the amount to distribute for that day are equal to his rewards
        uint256 currentDay = hexOneStaking.getCurrentStakingDay() - 1;
        (, uint256 hexAmountToDistribute) = hexOneStaking.poolHistory(currentDay, address(hexToken));
        (, uint256 hexitAmountToDistribute) = hexOneStaking.poolHistory(currentDay, address(hexitToken));

        assertEq(userHexBalanceAfter - userHexBalanceBefore, hexAmountToDistribute);
        assertEq(userHexitBalanceAfter - userHexitBalanceBefore, hexitAmountToDistribute);
    }
}
