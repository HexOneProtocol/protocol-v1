// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

interface IHexOneFaucet {
    event Funded(address token, uint256 amount, uint256 timestamp);
}
