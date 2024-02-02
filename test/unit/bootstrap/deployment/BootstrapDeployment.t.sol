// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import "../../../Base.t.sol";

/**
 *  @dev forge test --match-contract HexOneBootstrapTest --rpc-url "https://rpc.pulsechain.com" -vvv
 */
contract BootstrapDeploymentTest is Base {
    function test_deployment() public {
        assertEq(bootstrap.pulseXRouter(), address(pulseXRouter));
        assertEq(bootstrap.pulseXFactory(), address(pulseXFactory));
        assertEq(bootstrap.hexToken(), hexToken);
        assertEq(bootstrap.hexitToken(), address(hexit));
        assertEq(bootstrap.daiToken(), daiToken);
        assertEq(bootstrap.hexOneToken(), address(hex1));
        assertEq(bootstrap.teamWallet(), receiver);
    }

    function test_setBaseData() public {
        assertEq(bootstrap.hexOnePriceFeed(), address(feed));
        assertEq(bootstrap.hexOneStaking(), address(staking));
        assertEq(bootstrap.hexOneVault(), address(vault));
    }

    function test_setSacrificeTokens() public {
        assertEq(bootstrap.tokenMultipliers(hexToken), 5555);
        assertEq(bootstrap.tokenMultipliers(daiToken), 3000);
        assertEq(bootstrap.tokenMultipliers(wplsToken), 2000);
        assertEq(bootstrap.tokenMultipliers(plsxToken), 1000);
    }

    function test_setSacrificeStart() public {
        assertEq(bootstrap.sacrificeStart(), block.timestamp);
        assertEq(bootstrap.sacrificeEnd(), block.timestamp + 30 days);
    }
}
