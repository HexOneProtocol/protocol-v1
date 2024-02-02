// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import "../../Base.t.sol";

/**
 *  @dev forge test --match-contract HexitTokenTest --rpc-url "https://rpc.pulsechain.com" -vvv
 */
contract HexitTokenTest is Base {
    function test_deployment() public {
        // assert the name
        string memory actualName = hexit.name();
        assertEq(actualName, "Hexit Token");

        // assert the symbol
        string memory actualSymbol = hexit.symbol();
        assertEq(actualSymbol, "HEXIT");

        // assert the owner
        address actualOwner = hexit.owner();
        assertEq(actualOwner, address(this));

        // assert the bootstrap address
        address actualBootstrap = hexit.hexOneBootstrap();
        assertEq(actualBootstrap, address(bootstrap));
    }
}
