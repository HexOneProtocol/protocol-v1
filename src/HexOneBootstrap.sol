// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import {AccessControl} from "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

contract HexOneBootstrap is AccessControl {
    uint256 public constant HEXIT_BASE_AMOUNT = 5_555_555 * 1e18;

    uint256 public constant SACRIFICE_DURATION = 30 days;
    uint256 public constant SACRIFICE_CLAIM_DURATION = 7 days;
    uint256 public constant AIRDROP_DURATION = 15 days;

    uint16 public constant FIXED_POINT = 10_000;
    uint16 public constant DECREASE_FACTOR = 9524;

    address public feed;

    constructor() {}

    function sacrificeDay() public view returns (uint256) {}

    function airdropDay() public view returns (uint256) {}

    function sacrifice(address _token, uint256 _amount, uint256 _amountOutMin) external {}

    function processSacrifice(uint256 _amountOutMin) external {}

    function claimSacrifice() external {}

    function startAirdrop() external {}

    function claimAirdrop() external {}
}
