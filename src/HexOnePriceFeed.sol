// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import {UniswapV2OracleLibrary} from "./libraries/UniswapV2OracleLibrary.sol";
import {UniswapV2Library} from "./libraries/UniswapV2Library.sol";
import {FixedPoint} from "./libraries/FixedPoint.sol";
import {EnumerableSet} from "../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import {AccessControl} from "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

import {IHexOnePriceFeed} from "./interfaces/IHexOnePriceFeed.sol";
import {IHexitToken} from "./interfaces/IHexitToken.sol";
import {IPulseXPair} from "./interfaces/pulsex/IPulseXPair.sol";

/**
 *  @title Hex One Price Feed
 *  @dev TWAP oracle based on pulsex v1 pairs.
 */
contract HexOnePriceFeed is AccessControl, IHexOnePriceFeed {
    using EnumerableSet for EnumerableSet.AddressSet;
    using FixedPoint for *;

    /// @dev access control owner role, resulting hash of keccak256("OWNER_ROLE").
    bytes32 public constant OWNER_ROLE = 0xb19546dff01e856fb3f010c267a7b1c60363cf8a4664e21cc89c26224620214e;

    /// @dev precision scale multipler.
    uint256 public constant MULTIPLIER = 55_555_555e18;

    /// @dev max update period supported.
    uint256 public constant MAX_PERIOD = 700;
    /// @dev min update period supported.
    uint256 public constant MIN_PERIOD = 300;

    /// @dev address of the pulsex v1 factory.
    address public constant FACTORY_V1 = 0x1715a3E4A142d8b698131108995174F37aEBA10D;

    /// @dev address of the hexit token.
    address public immutable hexit;

    /// @dev current update period.
    uint256 public period;
    /// @dev last timestamp pair prices were updated.
    uint256 public lastUpdate;

    /// @dev supported pairs by the oracle.
    EnumerableSet.AddressSet internal pairs;
    /// @dev tokenIn => tokenOut => path.
    mapping(address => mapping(address => address[])) internal paths;
    /// @dev pair => last observation.
    mapping(address => Observation) internal observations;
    /// @dev pair => prices.
    mapping(address => Price) internal prices;

    /**
     *  @dev gives owner permissions to the deployer.
     *  @param _hexit address of the hexit token.
     *  @param _period feed update period.
     */
    constructor(address _hexit, uint256 _period) {
        if (_hexit == address(0)) revert ZeroAddress();
        if (_period > MAX_PERIOD || _period < MIN_PERIOD) revert InvalidPeriod();

        hexit = _hexit;
        period = _period;

        _grantRole(OWNER_ROLE, msg.sender);
    }

    /**
     *  @dev adds a new path to the oracle.
     *  @notice can only be called by the owner.
     *  @param _path route in which quotes for a given tokenIn and tokenOut are computed.
     */
    function addPath(address[] calldata _path) external onlyRole(OWNER_ROLE) {
        uint256 length = _path.length;
        if (length < 2) revert InvalidPath();

        address tokenIn = _path[0];
        address tokenOut = _path[length - 1];
        if (paths[tokenIn][tokenOut].length != 0) revert PathAlreadyRegistered();

        for (uint256 i; i < length - 1; ++i) {
            _addPair(_path[i], _path[i + 1]);
        }

        paths[tokenIn][tokenOut] = _path;

        emit PathAdded(_path);
    }

    /**
     *  @dev changes the oracle update period.
     *  @notice can only be called by the owner.
     *  @param _period new update period.
     */
    function changePeriod(uint256 _period) external onlyRole(OWNER_ROLE) {
        if (_period > MAX_PERIOD || _period < MIN_PERIOD) revert InvalidPeriod();
        period = _period;
        emit PeriodChanged(_period);
    }

    /**
     *  @dev updates the price of all supported pairs.
     */
    function update() external {
        uint256 timeElapsed = block.timestamp - lastUpdate;
        if (timeElapsed < period) revert PricesUpToDate();

        uint256 length = pairs.length();
        for (uint256 i; i < length; ++i) {
            _update(pairs.at(i));
        }

        lastUpdate = block.timestamp;

        if (lastUpdate != 0) {
            IHexitToken(hexit).mint(msg.sender, timeElapsed * MULTIPLIER);
        }

        emit PricesUpdated(block.timestamp);
    }

    /**
     *  @dev retrieves a quote following the configured path.
     *  @param _tokenIn input token address.
     *  @param _amountIn amount of input token.
     *  @param _tokenOut output token address.
     */
    function quote(address _tokenIn, uint256 _amountIn, address _tokenOut) external view returns (uint256 amountOut) {
        address[] memory path = paths[_tokenIn][_tokenOut];

        uint256 length = path.length;
        if (length < 2) revert InvalidPath();

        uint256 timeElapsed = block.timestamp - lastUpdate;
        if (timeElapsed >= period * 2) revert PriceStale();

        amountOut = _amountIn;
        for (uint256 i; i < length - 1; ++i) {
            address pair = UniswapV2Library.pairFor(FACTORY_V1, path[i], path[i + 1]);

            (address token0,) = UniswapV2Library.sortTokens(path[i], path[i + 1]);
            if (token0 == path[i]) {
                amountOut = prices[pair].price0.mul(amountOut).decode144();
            } else {
                amountOut = prices[pair].price1.mul(amountOut).decode144();
            }
        }
    }

    /**
     *  @dev retrieves the path for a given tokenIn and tokenOut.
     *  @param _tokenIn input token address.
     *  @param _tokenOut output token address.
     */
    function getPath(address _tokenIn, address _tokenOut) external view returns (address[] memory) {
        if (_tokenIn == address(0)) revert ZeroAddress();
        return paths[_tokenIn][_tokenOut];
    }

    /**
     *  @dev retrieves every pair supported.
     */
    function getPairs() external view returns (address[] memory) {
        return pairs.values();
    }

    /**
     *  @dev adds a new pair and take the first snapshot.
     */
    function _addPair(address _tokenA, address _tokenB) internal {
        address pair = UniswapV2Library.pairFor(FACTORY_V1, _tokenA, _tokenB);

        if (!pairs.add(pair)) return;

        (uint112 reserve0, uint112 reserve1,) = IPulseXPair(pair).getReserves();
        if (reserve0 == 0 || reserve1 == 0) revert EmptyReserves();

        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) =
            UniswapV2OracleLibrary.currentCumulativePrices(pair);

        Observation storage observation = observations[pair];
        observation.blockTimestampLast = blockTimestamp;
        observation.price0CumulativeLast = price0Cumulative;
        observation.price1CumulativeLast = price1Cumulative;

        emit PairAdded(pair);
    }

    /**
     *  @dev updates the price of a specific pair.
     *  @param _pair address of the pair to update.
     */
    function _update(address _pair) internal {
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) =
            UniswapV2OracleLibrary.currentCumulativePrices(_pair);

        Observation memory lastObservation = observations[_pair];

        uint32 timeElapsed;
        unchecked {
            timeElapsed = blockTimestamp - lastObservation.blockTimestampLast;
        }

        if (timeElapsed >= period) {
            unchecked {
                prices[_pair].price0 = FixedPoint.uq112x112(
                    uint224((price0Cumulative - lastObservation.price0CumulativeLast) / timeElapsed)
                );
                prices[_pair].price1 = FixedPoint.uq112x112(
                    uint224((price1Cumulative - lastObservation.price1CumulativeLast) / timeElapsed)
                );
            }

            Observation storage observation = observations[_pair];
            observation.blockTimestampLast = blockTimestamp;
            observation.price0CumulativeLast = price0Cumulative;
            observation.price1CumulativeLast = price1Cumulative;
        }
    }
}
