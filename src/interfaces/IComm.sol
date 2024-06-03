// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IComm {
    function mintEndBonus(uint256 stakeIndex, uint256 stakeId, address referrer, uint256 stakeAmount) external;
}
