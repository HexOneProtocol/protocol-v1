// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import "../../Base.t.sol";

contract VaultDeploymentTest is Base {
    /*//////////////////////////////////////////////////////////////////////////
                                DEPLOYMENT
    //////////////////////////////////////////////////////////////////////////*/

    function test_deployment() public {
        assertEq(vault.hexToken(), address(hexToken));
        assertEq(vault.daiToken(), address(daiToken));
        assertEq(vault.hexOneToken(), address(hex1));
    }

    /*//////////////////////////////////////////////////////////////////////////
                                SET BASE DATA
    //////////////////////////////////////////////////////////////////////////*/

    function test_setBaseData() public {
        assertEq(vault.hexOneFeedAggregator(), address(aggregator));
        assertEq(vault.hexOneStaking(), address(staking));
        assertEq(vault.hexOneBootstrap(), bootstrap);
    }
}
