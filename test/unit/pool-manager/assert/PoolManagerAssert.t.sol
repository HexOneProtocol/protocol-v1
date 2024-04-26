// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../Base.t.sol";

contract PoolManagerAssert is Base {
    /**
     *  @dev assert that multiple pools are created, initiliazed, and given permission to mint HEXIT.
     */
    function test_createPools(uint256 _rewardPerToken1, uint256 _rewardPerToken2) external prank(owner) {
        vm.assume(_rewardPerToken1 != 0 && _rewardPerToken2 != 0);

        ERC20Mock mock1 = new ERC20Mock("mock token 1", "MC1");
        ERC20Mock mock2 = new ERC20Mock("mock token 2", "MC2");

        uint256 poolsLengthBefore = manager.getPoolsLength();

        address[] memory tokens = new address[](2);
        tokens[0] = address(mock1);
        tokens[1] = address(mock2);

        uint256[] memory rewardsPerToken = new uint256[](2);
        rewardsPerToken[0] = _rewardPerToken1;
        rewardsPerToken[1] = _rewardPerToken2;

        manager.createPools(tokens, rewardsPerToken);

        uint256 poolsLengthAfter = manager.getPoolsLength();
        assertEq(poolsLengthAfter, poolsLengthBefore + 2);

        for (uint256 i; i < poolsLengthAfter; ++i) {
            assertTrue(hexit.hasRole(hexit.MINTER_ROLE(), manager.pools(i)));
        }

        for (uint256 i; i < poolsLengthAfter; ++i) {
            address pool = manager.pools(i);
            uint256 rewardPerToken = HexOnePool(pool).rewardPerToken();
            assertTrue(rewardPerToken > 0);
        }
    }

    /**
     *  @dev assert that a pool can be created, initialized and given permission to mint HEXIT.
     */
    function test_createPool(uint256 _rewardPerToken) external prank(owner) {
        vm.assume(_rewardPerToken != 0);

        ERC20Mock mock = new ERC20Mock("mock token", "MC");

        uint256 poolsLengthBefore = manager.getPoolsLength();

        manager.createPool(address(mock), _rewardPerToken);

        uint256 poolsLengthAfter = manager.getPoolsLength();
        assertEq(poolsLengthAfter, poolsLengthBefore + 1);

        for (uint256 i; i < poolsLengthAfter; ++i) {
            assertTrue(hexit.hasRole(hexit.MINTER_ROLE(), manager.pools(i)));
        }

        for (uint256 i; i < poolsLengthAfter; ++i) {
            address pool = manager.pools(i);
            uint256 rewardPerToken = HexOnePool(pool).rewardPerToken();
            assertTrue(rewardPerToken > 0);
        }
    }
}
