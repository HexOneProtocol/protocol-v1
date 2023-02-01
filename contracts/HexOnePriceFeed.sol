// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "./interfaces/IHexOnePriceFeed.sol";

contract HexOnePriceFeed is Ownable, IHexOnePriceFeed {
    mapping(address => address) private priceFeeds;
    uint256 public constant FIXED_POINT_SCALAR = 1e18;

    constructor () {}

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
        return _convertToUSD(_baseToken, _amount);
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

        return _amount * tokenPrice / FIXED_POINT_SCALAR;
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
        uint8 additionDecimals = 18 - decimals;
        return tokenPrice * 10**additionDecimals;
    }
}