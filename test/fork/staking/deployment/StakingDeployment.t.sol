// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import "../../Base.t.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 *  @dev forge test --match-contract StakingDeploymentTest -vvv
 */
contract StakingDeploymentTest is Base {
    /*//////////////////////////////////////////////////////////////////////////
                                DEPLOYMENT
    //////////////////////////////////////////////////////////////////////////*/

    function test_deployment() public {
        // assert token initialization
        assertEq(staking.hexToken(), hexToken);
        assertEq(staking.hexitToken(), address(hexit));

        // assert daily distribution rate for each pool is set to 1%
        (,,,, uint16 hexDistRate) = staking.pools(hexToken);
        assertEq(hexDistRate, 10);

        (,,,, uint16 hexitDistRate) = staking.pools(address(hexit));
        assertEq(hexitDistRate, 10);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                SET BASE DATA
    //////////////////////////////////////////////////////////////////////////*/

    function test_setBaseData() public {
        assertEq(staking.hexOneVault(), address(vault));
        assertEq(staking.hexOneBootstrap(), address(bootstrap));
    }

    /*//////////////////////////////////////////////////////////////////////////
                                SET STAKE TOKENS
    //////////////////////////////////////////////////////////////////////////*/

    function test_setStakeTokens() public {
        assertEq(staking.stakeTokenWeights(hexOneDaiPair), 700);
        assertEq(staking.stakeTokenWeights(address(hex1)), 200);
        assertEq(staking.stakeTokenWeights(address(hexit)), 100);
    }
}
