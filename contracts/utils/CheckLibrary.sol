// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

library CheckLibrary {
    function checkEOA() internal view {
        uint256 size;
        address sender = msg.sender;
        assembly {
            size := extcodesize(sender)
        }
        require(size == 0 && sender == tx.origin, "only EOA");
    }
}
