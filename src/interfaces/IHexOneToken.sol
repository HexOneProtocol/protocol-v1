// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

interface IHexOneToken {
    function mint(address _account, uint256 _amount) external;
    function burn(address _account, uint256 _amount) external;
}
