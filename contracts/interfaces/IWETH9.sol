// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

interface IWETH9 {
    function deposit() external payable;

    function withdraw(uint256 amount) external;
}
