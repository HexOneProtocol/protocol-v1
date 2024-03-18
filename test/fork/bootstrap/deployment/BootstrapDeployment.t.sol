// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import "../../Base.t.sol";

/**
 *  @dev forge test --match-contract BootstrapDeploymentTest -vvv
 */
contract BootstrapDeploymentTest is Base {
    /*//////////////////////////////////////////////////////////////////////////
                                DEPLOYMENT
    //////////////////////////////////////////////////////////////////////////*/

    function test_deployment() public {
        assertEq(bootstrap.pulseXRouter(), address(pulseXRouter));
        assertEq(bootstrap.pulseXFactory(), address(pulseXFactoryV2));
        assertEq(bootstrap.hexToken(), hexToken);
        assertEq(bootstrap.hexitToken(), address(hexit));
        assertEq(bootstrap.daiToken(), daiToken);
        assertEq(bootstrap.hexOneToken(), address(hex1));
        assertEq(bootstrap.teamWallet(), receiver);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                SET BASE DATA
    //////////////////////////////////////////////////////////////////////////*/

    function test_setBaseData() public {
        assertEq(bootstrap.hexOnePriceFeed(), address(feed));
        assertEq(bootstrap.hexOneStaking(), address(staking));
        assertEq(bootstrap.hexOneVault(), address(vault));
    }

    /*//////////////////////////////////////////////////////////////////////////
                            SET SACRIFICE TOKENS
    //////////////////////////////////////////////////////////////////////////*/

    function test_setSacrificeTokens() public {
        assertEq(bootstrap.tokenMultipliers(hexToken), 55_555);
        assertEq(bootstrap.tokenMultipliers(daiToken), 55_555);
        assertEq(bootstrap.tokenMultipliers(wplsToken), 55_555);
        assertEq(bootstrap.tokenMultipliers(plsxToken), 55_555);
    }

    /*//////////////////////////////////////////////////////////////////////////
                            GET SACRIFICE START
    //////////////////////////////////////////////////////////////////////////*/

    function test_setSacrificeStart() public {
        assertEq(bootstrap.sacrificeStart(), block.timestamp);
        assertEq(bootstrap.sacrificeEnd(), block.timestamp + 30 days);
    }
}
