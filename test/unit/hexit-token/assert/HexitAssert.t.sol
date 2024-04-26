// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../Base.t.sol";

contract HexitAssert is Base {
    /**
     *  @dev assert that `_manager` is properly initialized.
     */
    function test_initManager(address _manager) external prank(owner) {
        vm.assume(_manager != address(0));

        HexitToken hexit_ = new HexitToken();
        hexit_.initManager(_manager);

        assertTrue(hexit_.hasRole(hexit_.MANAGER_ROLE(), _manager));
    }

    /**
     *  @dev assert that `_bootstrap` is properly initialized.
     */
    function test_initBootstrap(address _bootstrap) external prank(owner) {
        vm.assume(_bootstrap != address(0));

        HexitToken hexit_ = new HexitToken();
        hexit_.initBootstrap(_bootstrap);

        assertTrue(hexit_.hasRole(hexit_.MINTER_ROLE(), _bootstrap));
    }

    /**
     *  @dev assert that `_feed` is properly initialized.
     */
    function test_initFeed(address _feed) external prank(owner) {
        vm.assume(_feed != address(0));

        HexitToken hexit_ = new HexitToken();
        hexit_.initFeed(_feed);

        assertTrue(hexit_.hasRole(hexit_.MINTER_ROLE(), _feed));
    }

    /**
     *  @dev assert that `_pool` is properly initialized.
     */
    function test_initPool(address _pool) external prank(address(manager)) {
        vm.assume(_pool != address(0));

        hexit.initPool(_pool);

        assertTrue(hexit.hasRole(hexit.MINTER_ROLE(), _pool));
    }

    /**
     *  @dev assert that `pools` minted by the manager can mint HEXIT.
     */
    function test_mint_calledByPools(address _account, uint256 _amount, uint256 _rand) external {
        vm.assume(_account != address(0));
        _amount = bound(_amount, 10_000, 10_000e18);

        uint256 poolIndex = _rand % manager.getPoolsLength();
        address pool = manager.pools(poolIndex);

        vm.prank(pool);
        hexit.mint(_account, _amount);

        assertEq(hexit.balanceOf(_account), _amount);
    }

    /**
     *  @dev assert that `bootstrap` can mint HEXIT.
     */
    function test_mint_calledByBootstrap(address _account, uint256 _amount) external prank(address(bootstrap)) {
        vm.assume(_account != address(0));
        _amount = bound(_amount, 10_000, 10_000e18);

        hexit.mint(_account, _amount);

        assertEq(hexit.balanceOf(_account), _amount);
    }
}
