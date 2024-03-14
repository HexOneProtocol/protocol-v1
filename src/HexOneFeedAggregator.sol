// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {LibString} from "solady/src/utils/LibString.sol";
import {TokenUtils} from "./utils/TokenUtils.sol";

import {IHexOneFeedAggregator} from "./interfaces/IHexOneFeedAggregator.sol";
import {IHexOnePriceFeed} from "./interfaces/IHexOnePriceFeed.sol";

contract HexOneFeedAggregator is IHexOneFeedAggregator {
    address public immutable hexOnePriceFeed;
    address public immutable hexToken;
    address public immutable daiToken;
    address public immutable wplsToken;
    address public immutable usdcToken;
    address public immutable usdtToken;

    /// @dev stores USDC and USDT decimals
    mapping(address => uint8) public decimals;

    constructor(
        address _hexOnePriceFeed,
        address _hexToken,
        address _daiToken,
        address _wplsToken,
        address _usdcToken,
        address _usdtToken
    ) {
        hexOnePriceFeed = _hexOnePriceFeed;
        hexToken = _hexToken;
        daiToken = _daiToken;
        wplsToken = _wplsToken;
        usdcToken = _usdcToken;
        usdtToken = _usdtToken;

        decimals[_usdcToken] = TokenUtils.expectDecimals(_usdcToken);
        decimals[_usdtToken] = TokenUtils.expectDecimals(_usdtToken);
    }

    /// @dev returns an HEX/USD quote by computing the mean of 4 liquidity pools.
    function computeHexPrice(uint256 _amountIn) external returns (uint256 amountOut) {
        // quote 1: get a quote from HEX/DAI in DAI
        uint256 hexDaiQuote = _consult(hexToken, _amountIn, daiToken);

        // quote 2: get a quote from HEX/WPLS in WPLS
        uint256 hexWplsQuote = _consult(hexToken, _amountIn, wplsToken);

        // quote 3: get a quote from WPLS/DAI in DAI
        uint256 wplsDaiQuote = _consult(wplsToken, hexWplsQuote, daiToken);

        // quote 4: get a quote from WPLS/USDC in USDC
        uint256 wplsUsdcQuote = _consult(wplsToken, hexWplsQuote, usdcToken);
        wplsUsdcQuote = _convert(usdcToken, wplsUsdcQuote);

        // quote 5: get a quote from WPLS/USDT in USDT
        uint256 wplsUsdtQuote = _consult(wplsToken, hexWplsQuote, usdtToken);
        wplsUsdtQuote = _convert(usdtToken, wplsUsdtQuote);

        amountOut = (hexDaiQuote + wplsDaiQuote + wplsUsdcQuote + wplsUsdtQuote) / 4;
    }

    /// @dev tries to consult the price of `tokenIn` in `tokenOut`.
    /// @notice if consult reverts with PriceTooStale then it needs to
    /// update the oracle and only then consult the price again.
    function _consult(address _tokenIn, uint256 _amountIn, address _tokenOut) internal returns (uint256) {
        try IHexOnePriceFeed(hexOnePriceFeed).consult(_tokenIn, _amountIn, _tokenOut) returns (uint256 amountOut) {
            if (amountOut == 0) revert InvalidQuote(amountOut);
            return amountOut;
        } catch (bytes memory reason) {
            bytes4 err = bytes4(reason);
            if (err == IHexOnePriceFeed.PriceTooStale.selector) {
                IHexOnePriceFeed(hexOnePriceFeed).update(_tokenIn, _tokenOut);
                return IHexOnePriceFeed(hexOnePriceFeed).consult(_tokenIn, _amountIn, _tokenOut);
            } else {
                revert PriceConsultationFailedBytes(reason);
            }
        } catch Error(string memory reason) {
            revert PriceConsultationFailedString(reason);
        } catch Panic(uint256 code) {
            string memory stringErrorCode = LibString.toString(code);
            revert PriceConsultationFailedString(
                string.concat("HexOnePriceFeed reverted: Panic code ", stringErrorCode)
            );
        }
    }

    /// @dev convert an `_amount` to be represented with the same decimals as `_token`.
    function _convert(address _token, uint256 _amount) internal view returns (uint256) {
        uint8 tokenDecimals = decimals[_token];
        if (tokenDecimals >= 18) {
            return _amount / (10 ** (tokenDecimals - 18));
        } else {
            return _amount * (10 ** (18 - tokenDecimals));
        }
    }
}
