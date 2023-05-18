// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

library CheckLibrary {
    function checkEOA(address _sender) internal view {
        uint256 size;
        assembly {
            size := extcodesize(_sender)
        }
        require(size == 0, "only EOA");
    }
}
