// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import "../Base.t.sol";

/**
 *  @dev forge test --match-contract HexOneTokenTest --rpc-url "https://rpc.pulsechain.com" -vvv
 */
contract HexOneTokenTest is Base {
    function test_deployment() public {
        // assert the name
        string memory actualName = hex1.name();
        assertEq(actualName, "Hex One Token");

        // assert the symbol
        string memory actualSymbol = hex1.symbol();
        assertEq(actualSymbol, "HEX1");

        // assert the owner
        address actualOwner = hex1.owner();
        assertEq(actualOwner, address(this));

        // assert vault address
        address actualVault = hex1.hexOneVault();
        assertEq(actualVault, address(vault));
    }
}
