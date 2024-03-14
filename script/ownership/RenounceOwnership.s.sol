// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {console2 as console} from "forge-std/Test.sol";

import {BaseScript} from "../Base.s.sol";

import {HexOneToken} from "../../src/HexOneToken.sol";
import {HexitToken} from "../../src/HexitToken.sol";
import {HexOneStaking} from "../../src/HexOneStaking.sol";
import {HexOneVault} from "../../src/HexOneVault.sol";
import {HexOneBootstrap} from "../../src/HexOneBootstrap.sol";

contract RenounceOwnershipScript is BaseScript {
    // TODO: change addresses
    HexOneToken internal hex1 = HexOneToken(0xc1EeD9232A0A44c2463ACB83698c162966FBc78d);
    HexitToken internal hexit = HexitToken(0xC220Ed128102d888af857d137a54b9B7573A41b2);
    HexOneStaking internal staking = HexOneStaking(0xce830DA8667097BB491A70da268b76a081211814);
    HexOneVault internal vault = HexOneVault(0xD5bFeBDce5c91413E41cc7B24C8402c59A344f7c);
    HexOneBootstrap internal bootstrap = HexOneBootstrap(0x77AD263Cd578045105FBFC88A477CAd808d39Cf6);

    function run() external {
        // renounce ownership of protocol contracts
        _renounce();

        // display protocol contracts owner
        _display();
    }

    function _renounce() internal broadcast {
        hex1.renounceOwnership();
        hexit.renounceOwnership();
        staking.renounceOwnership();
        vault.renounceOwnership();
        bootstrap.renounceOwnership();
    }

    function _display() internal view {
        console.log("HexOneToken owner:     ", hex1.owner());
        console.log("HexitToken owner:      ", hexit.owner());
        console.log("HexOneStaking owner:   ", staking.owner());
        console.log("HexOneVault owner:     ", vault.owner());
        console.log("HexOneBootstrap owner: ", bootstrap.owner());
    }
}
