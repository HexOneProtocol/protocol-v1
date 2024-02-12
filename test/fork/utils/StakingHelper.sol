// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import "../Base.t.sol";
import {TokenUtils} from "../../../src/utils/TokenUtils.sol";

contract StakingHelper is Base {
    function _initialPurchase(uint256 _hexAmount, uint256 _hexitAmount) internal {
        // vault adds HEX1 to the contract
        deal(hexToken, address(vault), _hexAmount);

        vm.startPrank(address(vault));

        IERC20(hexToken).approve(address(staking), _hexAmount);
        staking.purchase(address(hexToken), _hexAmount);

        vm.stopPrank();

        // bootstrap adds HEXIT to the contract
        deal(address(hexit), address(bootstrap), _hexitAmount);

        vm.startPrank(address(bootstrap));

        hexit.approve(address(staking), _hexitAmount);
        staking.purchase(address(hexit), _hexitAmount);

        vm.stopPrank();
    }

    function _convertToShares(address _token, uint256 _amount) internal view returns (uint256) {
        uint8 decimals = TokenUtils.expectDecimals(_token);
        if (decimals >= 18) {
            return _amount / (10 ** (decimals - 18));
        } else {
            return _amount * (10 ** (18 - decimals));
        }
    }
}
