// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../Base.t.sol";

contract BootstrapTest is Base {
    function setUp() public virtual override {
        super.setUp();

        skip(feed.period());
        feed.update();
    }

    function test_sacrifice_claim() external {
        deal(DAI_TOKEN, address(this), 10_000e18);

        IERC20(DAI_TOKEN).approve(address(bootstrap), 10_000e18);
        bootstrap.sacrifice(DAI_TOKEN, 10_000e18, 1);

        (, uint256 hexitShares,,) = bootstrap.userInfos(address(this));

        console.log("HEXIT sacrifice: ", hexitShares);
    }

    function test_airdrop_claim() external {
        deal(DAI_TOKEN, address(this), 10_000e18);

        IERC20(DAI_TOKEN).approve(address(bootstrap), 10_000e18);
        bootstrap.sacrifice(DAI_TOKEN, 10_000e18, 1);

        vm.startPrank(owner);
        bootstrap.startAirdrop(uint64(block.timestamp));
        vm.stopPrank();

        uint256 hexitAllocation = bootstrap.airdropHexitAllocation();
        console.log("HEXIT airdrop: ", hexitAllocation);
    }
}
