// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

interface IHexitToken {
    event ManagerInitialized(address manager);
    event FeedInitialized(address faucet);
    event BootstrapInitialized(address bootstrap);
    event PoolAdded(address pool);

    error ZeroAddress();
    error AlreadyCalled();

    function initManager(address _manager) external;
    function initFeed(address _feed) external;
    function initBootstrap(address _bootstrap) external;
    function initPool(address _pool) external;
    function mint(address _account, uint256 _amount) external;
}
