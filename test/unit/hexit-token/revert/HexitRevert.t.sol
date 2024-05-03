// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../Base.t.sol";

contract HexitRevert is Base {
    /**
     *  @dev test that an `_account` without owner permissions can not call.
     */
    function test_initManager_revert_AccessControlUnauthorizedAccount(address _account, address _manager) external {
        vm.assume(_account != address(0) && _account != owner);
        vm.assume(_manager != address(0));

        vm.startPrank(owner);
        HexitToken hexitToken = new HexitToken();
        vm.stopPrank();

        vm.startPrank(_account);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, _account, hexitToken.OWNER_ROLE()
            )
        );
        hexitToken.initManager(_manager);
        vm.stopPrank();
    }

    /**
     *  @dev test that manager can not be address(0).
     */
    function test_initManager_revert_ZeroAddress() external prank(owner) {
        HexitToken hexitToken = new HexitToken();
        vm.expectRevert(IHexitToken.ZeroAddress.selector);
        hexitToken.initManager(address(0));
    }

    /**
     *  @dev test that manager can only be set once.
     */
    function test_initManager_revert_AlreadyInitialized(address _manager) external prank(owner) {
        vm.assume(_manager != address(0));

        vm.expectRevert(IHexitToken.AlreadyInitialized.selector);
        hexit.initManager(_manager);
    }

    /**
     *  @dev test that an `_account` without owner permissions can not call.
     */
    function test_initFeed_revert_AccessControlUnauthorizedAccount(address _account, address _feed) external {
        vm.assume(_account != address(0) && _account != owner);
        vm.assume(_feed != address(0));

        vm.startPrank(owner);
        HexitToken hexitToken = new HexitToken();
        vm.stopPrank();

        vm.startPrank(_account);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, _account, hexitToken.OWNER_ROLE()
            )
        );
        hexitToken.initFeed(_feed);
        vm.stopPrank();
    }

    /**
     *  @dev test that the price feed can not be address(0).
     */
    function test_initFeed_revert_ZeroAddress() external prank(owner) {
        HexitToken hexitToken = new HexitToken();
        vm.expectRevert(IHexitToken.ZeroAddress.selector);
        hexitToken.initFeed(address(0));
    }

    /**
     *  @dev test that the price feed can only be set once.
     */
    function test_initFeed_revert_AlreadyInitialized(address _feed) external prank(owner) {
        vm.assume(_feed != address(0));

        vm.expectRevert(IHexitToken.AlreadyInitialized.selector);
        hexit.initManager(_feed);
    }

    /**
     *  @dev test that an `_account` without owner permissions can not call.
     */
    function test_initBootstrap_revert_AccessControlUnauthorizedAccount(address _account, address _bootstrap)
        external
    {
        vm.assume(_account != address(0) && _account != owner);
        vm.assume(_bootstrap != address(0));

        vm.startPrank(owner);
        HexitToken hexitToken = new HexitToken();
        vm.stopPrank();

        vm.startPrank(_account);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, _account, hexitToken.OWNER_ROLE()
            )
        );
        hexitToken.initBootstrap(_bootstrap);
        vm.stopPrank();
    }

    /**
     *  @dev test that bootstrap can not be address(0).
     */
    function test_initBootstrap_revert_ZeroAddress() external prank(owner) {
        HexitToken hexitToken = new HexitToken();
        vm.expectRevert(IHexitToken.ZeroAddress.selector);
        hexitToken.initBootstrap(address(0));
    }

    /**
     *  @dev test that bootstrap can only be set once.
     */
    function test_initBootstrap_revert_AlreadyInitialized(address _bootstrap) external prank(owner) {
        vm.assume(_bootstrap != address(0));

        vm.expectRevert(IHexitToken.AlreadyInitialized.selector);
        hexit.initBootstrap(_bootstrap);
    }

    /**
     *  @dev test that an `_account` without manager permissions can not call.
     */
    function test_initPool_revert_AccessControlUnauthorizedAccount(address _account, address _pool) external {
        vm.assume(_account != address(0) && _account != address(manager));
        vm.assume(_pool != address(0));

        vm.startPrank(owner);
        HexitToken hexitToken = new HexitToken();
        vm.stopPrank();

        vm.startPrank(_account);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, _account, hexitToken.MANAGER_ROLE()
            )
        );
        hexitToken.initPool(_pool);
        vm.stopPrank();
    }
}
