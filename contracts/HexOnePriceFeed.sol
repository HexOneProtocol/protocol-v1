// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "./utils/TokenUtils.sol";
import "./interfaces/IHexOnePriceFeed.sol";
import "./interfaces/pulsex/IPulseXFactory.sol";
import "./interfaces/pulsex/IPulseXRouter.sol";
import "./interfaces/pulsex/IPulseXPair.sol";

contract HexOnePriceFeed is OwnableUpgradeable, IHexOnePriceFeed {
    uint256 public FIXED_POINT_SCALAR;

    address private hexToken;

    /// @notice pairToken should stable coin to calculate hex token price.
    address private pairToken;

    IPulseXRouter02 public dexRouter;

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _hexToken,
        address _pairToken,
        address _dexRouter
    ) public initializer {
        require(_hexToken != address(0), "zero hex Token address");
        require(_pairToken != address(0), "zero pair token address");
        require(_dexRouter != address(0), "zero dexRouter address");

        FIXED_POINT_SCALAR = 1e18;
        hexToken = _hexToken;
        pairToken = _pairToken;
        dexRouter = IPulseXRouter02(_dexRouter);
        __Ownable_init();
    }

    function sqrt(uint256 x) public view returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    /// @inheritdoc IHexOnePriceFeed
    function getBaseTokenPrice(
        address _baseToken,
        uint256 _amount
    ) external view override returns (uint256) {
        // if (_baseToken == hexToken) {
        //     return getHexTokenPrice(_amount);
        // } else if (_baseToken == pairToken) {
        //     uint8 pairTokenDecimals = TokenUtils.expectDecimals(pairToken);
        //     return (FIXED_POINT_SCALAR * _amount) / 10 ** pairTokenDecimals; // 1 USD
        // } else if (_baseToken == address(0)) {
        //     /// native token
        //     _baseToken = dexRouter.WPLS();
        // }
        if (_baseToken == pairToken) {
            return _convertToUSD(_baseToken, _amount);
        }
        IPulseXPair tokenPair = IPulseXPair(
            IPulseXFactory(dexRouter.factory()).getPair(pairToken, _baseToken)
        );
        if (address(tokenPair) != address(0)) {
            (uint112 reserve0, uint112 reserve1, ) = tokenPair.getReserves();
            uint256 baseTokenReserve;
            uint256 pairTokenReserve;
            if (tokenPair.token0() == _baseToken) {
                baseTokenReserve = uint256(reserve0);
                pairTokenReserve = uint256(reserve1);
            } else {
                baseTokenReserve = uint256(reserve1);
                pairTokenReserve = uint256(reserve0);
            }
            uint256 pairTokenAmount = (pairTokenReserve * _amount) /
                baseTokenReserve;
            return _convertToUSD(pairToken, pairTokenAmount);
        } else {
            tokenPair = IPulseXPair(_baseToken);
            (uint112 reserve0, uint112 reserve1, ) = tokenPair.getReserves();
            if (tokenPair.token1() == pairToken) {
                // in case of hex1/dai lp token
                uint256 rewardTokenPrice = reserve0 / reserve1;
                uint256 lpPrice = (sqrt(reserve0) *
                    sqrt(reserve1) *
                    sqrt(rewardTokenPrice) *
                    2) / tokenPair.totalSupply();
                return lpPrice;
            } else {
                // in case of hex1/hex lp token
                uint256 rewardTokenPrice = (reserve0 / reserve1) *
                    getHexTokenPrice(10 ** 8);
                uint256 lpPrice = (sqrt(reserve0) *
                    sqrt(reserve1) *
                    sqrt(rewardTokenPrice) *
                    2) / tokenPair.totalSupply();
                return lpPrice;
            }
        }
    }

    /// @inheritdoc IHexOnePriceFeed
    function getHexTokenPrice(
        uint256 _amount
    ) public view override returns (uint256) {
        return _getBaseTokenPriceFromPairToken(hexToken, _amount);
    }

    function _getBaseTokenPriceFromPairToken(
        address _baseToken,
        uint256 _amount
    ) internal view returns (uint256) {
        IPulseXPair tokenPair = IPulseXPair(
            IPulseXFactory(dexRouter.factory()).getPair(hexToken, pairToken)
        );
        require(
            address(tokenPair) != address(0),
            "no liquidity pool with pairToken"
        );

        (uint112 reserve0, uint112 reserve1, ) = tokenPair.getReserves();
        uint256 baseTokenReserve;
        uint256 pairTokenReserve;
        if (tokenPair.token0() == _baseToken) {
            baseTokenReserve = uint256(reserve0);
            pairTokenReserve = uint256(reserve1);
        } else {
            baseTokenReserve = uint256(reserve1);
            pairTokenReserve = uint256(reserve0);
        }

        uint256 pairTokenAmount = (pairTokenReserve * _amount) /
            baseTokenReserve;
        uint8 pairTokenDecimals = TokenUtils.expectDecimals(pairToken);

        if (pairTokenDecimals > 18) {
            return pairTokenAmount / 10 ** (pairTokenDecimals - 18);
        } else {
            return pairTokenAmount * 10 ** (18 - pairTokenDecimals);
        }
    }

    function _convertToUSD(
        address _token,
        uint256 _amount
    ) internal view returns (uint256) {
        uint8 tokenDecimals = TokenUtils.expectDecimals(_token);
        if (tokenDecimals > 18) {
            return _amount / 10 ** (tokenDecimals - 18);
        } else {
            return _amount * 10 ** (18 - tokenDecimals);
        }
    }

    uint256[100] private __gap;
}
