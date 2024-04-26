// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, stdError, console} from "../../lib/forge-std/src/Test.sol";

import {HexitToken} from "../../src/HexitToken.sol";
import {HexOnePoolManager} from "../../src/HexOnePoolManager.sol";
import {HexOnePool} from "../../src/HexOnePool.sol";

import {IHexitToken} from "../../src/interfaces/IHexitToken.sol";
import {IHexOnePoolManager} from "../../src/interfaces/IHexOnePoolManager.sol";
import {IHexOnePool} from "../../src/interfaces/IHexOnePool.sol";

import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IAccessControl} from "../../lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";
import {IERC20Errors} from "../../lib/openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol";

contract Base is Test {
    HexitToken internal hexit;
    HexOnePoolManager internal manager;
    HexOnePool[] internal pools;

    address internal bootstrap = makeAddr("bootstrap"); // TODO
    address internal feed = makeAddr("feed"); // TODO

    ERC20Mock internal hex1dai;

    address internal owner = makeAddr("owner");

    modifier prank(address sender) {
        vm.startPrank(sender);
        _;
        vm.stopPrank();
    }

    function setUp() public virtual prank(owner) {
        _deploy();

        _configure();
    }

    function _deploy() private {
        hex1dai = new ERC20Mock("HEX1/DAI LP", "HEX1/DAI");
        hexit = new HexitToken();
        manager = new HexOnePoolManager(address(hexit));
    }

    function _configure() private {
        hexit.initManager(address(manager));

        address[] memory tokens = new address[](2);
        tokens[0] = address(hex1dai);
        tokens[1] = address(hexit);

        uint256[] memory rewardsPerToken = new uint256[](2);
        rewardsPerToken[0] = 420e18;
        rewardsPerToken[1] = 69e18;

        manager.createPools(tokens, rewardsPerToken);

        pools = new HexOnePool[](manager.getPoolsLength());
        for (uint256 i; i < manager.getPoolsLength(); ++i) {
            pools[i] = HexOnePool(manager.pools(i));
        }

        hexit.initBootstrap(bootstrap); // TODO
        hexit.initFeed(feed); // TODO
    }
}
