// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

interface IHexitToken {
    function setBootstrap(address _bootstrap) external;

    function mint(address _recipient, uint256 _amount) external;
}
