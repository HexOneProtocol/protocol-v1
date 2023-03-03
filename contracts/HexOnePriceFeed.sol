// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "./utils/TokenUtils.sol";
import "./interfaces/IHexOnePriceFeed.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router.sol";

contract HexOnePriceFeed is Ownable, IHexOnePriceFeed {
    mapping(address => address) private priceFeeds;
    uint256 public constant FIXED_POINT_SCALAR = 1e18;

    address private hexToken;
    address private pairToken;
    IUniswapV2Router02 public dexRouter;

    constructor (
        address _hexToken,
        address _pairToken,
        address _pairTokenPriceFeed,
        address _dexRouter
    ) {
        require (_hexToken != address(0), "zero hex Token address");
        require (_pairToken != address(0), "zero pair token address");
        require (_pairTokenPriceFeed != address(0), "zero pairTokenPriceFeed address");
        require (_dexRouter != address(0), "zero dexRouter address");

        priceFeeds[_pairToken] = _pairTokenPriceFeed;
        hexToken = _hexToken;
        pairToken = _pairToken;
        dexRouter = IUniswapV2Router02(_dexRouter);
    }

    /// @inheritdoc IHexOnePriceFeed
    function setPriceFeed(
        address _baseToken,
        address _priceFeed
    ) external onlyOwner override {
        require(_baseToken != address(0), "zero base token address");
        require(_priceFeed != address(0), "zero price feed address");
        priceFeeds[_baseToken] = _baseToken;
    }

    /// @inheritdoc IHexOnePriceFeed
    function getBaseTokenPrice(
        address _baseToken,
        uint256 _amount
    ) external view override returns (uint256) {
        if (_baseToken == address(0)) {     /// native token
            _baseToken = dexRouter.WETH();
        }
        return _convertToUSD(_baseToken, _amount);
    }

    /// @inheritdoc IHexOnePriceFeed
    function getHexTokenPrice(uint256 _amount) external view override returns (uint256) {
        uint256 pairTokenAmount = _convertHexToPairToken(_amount);
        if (pairTokenAmount == 0) return 0;
        return _convertToUSD(pairToken, pairTokenAmount);
    }

    /// @notice Convert amount of underlyint token to USD.
    /// @param _baseToken The address of base token.
    /// @param _amount The amount of base token.
    /// @return Converted amount of USD divided 10**decimals.
    function _convertToUSD(
        address _baseToken,
        uint256 _amount
    ) internal view returns (uint256) {
        address priceFeedAddr = priceFeeds[_baseToken];
        if (priceFeedAddr == address(0)) {
            return 0;
        }

        uint256 tokenPrice = _getChainlinkTokenPrice(priceFeedAddr);
        uint8 baseTokenDecimals = TokenUtils.expectDecimals(_baseToken);

        return _amount * tokenPrice / 10**baseTokenDecimals;
    }

    /// @notice Get token price according to priceFeed.
    /// @param _priceFeed The address of priceFeed on chainlink.
    /// @return Return token price calculated by 1e18.
    function _getChainlinkTokenPrice(
        address _priceFeed
    ) internal view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(_priceFeed);
        (
            uint80 roundID,
            int price,,
            uint256 timestamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();

        require(price > 0, "Chainlink price <= 0"); 
        require(answeredInRound >= roundID, "Stale price");
        require(timestamp != 0, "Round not complete");

        uint256 tokenPrice = uint256(price);

        uint8 decimals = priceFeed.decimals();
        if (decimals > 18) {
            return tokenPrice / 10**(decimals - 18);
        } else {
            uint8 additionDecimals = 18 - decimals;
            return tokenPrice * 10**additionDecimals;
        }
    }

    function _convertHexToPairToken(uint256 _amount) internal view returns(uint256) {
        address tokenPair = IUniswapV2Factory(dexRouter.factory()).getPair(hexToken, pairToken);
        if (tokenPair == address(0)) {
            return 0;
        }

        uint256 hexTokenBalance = IERC20(hexToken).balanceOf(tokenPair);
        uint256 pairTokenBalance = IERC20(pairToken).balanceOf(tokenPair);

        return pairTokenBalance * _amount / hexTokenBalance;
    }
}