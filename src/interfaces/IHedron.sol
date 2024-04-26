// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IHedron {
    function mintNative(uint256 stakeIndex, uint40 stakeId) external returns (uint256);
}
