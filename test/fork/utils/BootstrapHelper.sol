// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import "../Base.t.sol";

contract BootstrapHelper is Base {
    function _dealToken(address _token, address _recipient, uint256 _amount) internal {
        if (_token == plsxToken) {
            vm.prank(0x39cF6f8620CbfBc20e1cC1caba1959Bd2FDf0954);
            IERC20(plsxToken).transfer(_recipient, _amount);
        } else {
            deal(_token, _recipient, _amount);
        }
    }

    function _sacrifice(address _token, uint256 _amount) internal returns (uint256) {
        IERC20(_token).approve(address(bootstrap), _amount);

        uint256 amountOut;
        if (_token == hexToken) {
            amountOut = _amount;
            bootstrap.sacrifice(_token, _amount, 0);
        } else {
            address[] memory path = new address[](2);
            path[0] = _token;
            path[1] = hexToken;
            uint256[] memory amounts = UniswapV2Library.getAmountsOut(pulseXFactory, _amount, path);

            amountOut = amounts[1];

            bootstrap.sacrifice(_token, _amount, amounts[1]);
        }

        return amountOut;
    }

    function _processSacrifice(uint256 _amountOfHexToDai) internal returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = hexToken;
        path[1] = daiToken;
        uint256[] memory amounts = UniswapV2Library.getAmountsOut(pulseXFactory, _amountOfHexToDai, path);

        bootstrap.processSacrifice(amounts[1]);

        return amounts[1];
    }

    function _getHexStaked(address _user) internal view returns (uint256 hexAmount) {
        uint256 stakeCount = IHexToken(hexToken).stakeCount(_user);
        if (stakeCount == 0) return 0;

        uint256 shares;
        for (uint256 i; i < stakeCount; ++i) {
            IHexToken.StakeStore memory stakeStore = IHexToken(hexToken).stakeLists(_user, i);
            shares += stakeStore.stakeShares;
        }

        IHexToken.GlobalsStore memory globals = IHexToken(hexToken).globals();
        hexAmount = uint256((shares * uint256(globals.shareRate)) / 1e5);
    }
}
