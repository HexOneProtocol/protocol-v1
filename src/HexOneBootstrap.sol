// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import {AccessControl} from "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {EnumerableSet} from "../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import {SafeERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import {IHexOneBootstrap} from "./interfaces/IHexOneBootstrap.sol";
import {IHexOnePriceFeed} from "./interfaces/IHexOnePriceFeed.sol";
import {IHexOneVault} from "./interfaces/IHexOneVault.sol";
import {IHexitToken} from "./interfaces/IHexitToken.sol";
import {IHexToken} from "./interfaces/IHexToken.sol";

import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {IPulseXFactory} from "./interfaces/pulsex/IPulseXFactory.sol";
import {IPulseXRouter02 as IPulseXRouter} from "./interfaces/pulsex/IPulseXRouter.sol";

/**
 *  @title Hex One Bootstrap
 *  @dev bootstraps the initial hex1/dai liquidity and distributes hexit.
 */
contract HexOneBootstrap is AccessControl, ReentrancyGuard, IHexOneBootstrap {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    /// @dev access control owner role.
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    /// @dev min amount accepted to be sacrificed.
    uint256 public constant MIN_SACRIFICE = 1e18;
    /// @dev base hexit amount of hexit.
    uint256 public constant BASE_HEXIT = 5_555_555 * 1e18;

    /// @dev duration of the sacrifice duration.
    uint64 public constant SACRIFICE_DURATION = 30 days;
    /// @dev duration of the sacrifice claim duration.
    uint64 public constant SACRIFICE_CLAIM_DURATION = 7 days;
    /// @dev duration of the airdrop claim duration.
    uint64 public constant AIRDROP_DURATION = 15 days;

    /// @dev address of the pulsex v1 router.
    address private constant ROUTER_V1 = 0x98bf93ebf5c380C0e6Ae8e192A7e2AE08edAcc02;
    /// @dev address of the pulsex v2 router.
    address private constant ROUTER_V2 = 0x165C3410fC91EF562C50559f7d2289fEbed552d9;
    /// @dev address of the pulsex v2 factory.
    address private constant FACTORY_V2 = 0x29eA7545DEf87022BAdc76323F373EA1e707C523;

    /// @dev address of the hex token.
    address private constant HX = 0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39;
    /// @dev address of the dai token.
    address private constant DAI = 0xefD766cCb38EaF1dfd701853BFCe31359239F305;

    /// @dev precision scale multipler, represents 100% in bps.
    uint16 private constant FIXED_POINT = 10_000;
    /// @dev base hexit daily decrease factor of 95.24%.
    uint16 private constant DECREASE_FACTOR = 9524;
    /// @dev hexit minted to the team over the remaining hex 66.67% in bps.
    uint16 private constant HEXIT_TEAM_RATE = 6667;
    /// @dev bonus hexit multiplier multiplier used during sacrifice.
    uint16 private constant MULTIPLIER = 5555;
    /// @dev percentage of hex sacrifice used to bootstrap liquidity 25% in bps.
    uint16 private constant LIQUIDITY_RATE = 2500;

    /// @dev address of the price feed.
    address public immutable feed;
    /// @dev address of the hexit token.
    address public immutable hexit;

    /// @dev flag to keep track of vault initialization status
    bool public initialized;

    /// @dev address of the vault.
    address public vault;

    /// @dev information relative to the sacrifice period.
    SacrificeInfo public sacrificeInfo;
    /// @dev information relative to the airdrop period.
    AirdropInfo public airdropInfo;

    /// @dev schedule of the sacrifice period.
    Schedule public sacrificeSchedule;
    /// @dev schedule of the airdrop period.
    Schedule public airdropSchedule;

    /// @dev user => UserInfo.
    mapping(address => UserInfo) public userInfos;

    /// @dev tokens that can be sacrificed.
    EnumerableSet.AddressSet private sacrificeTokens;

    /**
     *  @dev gives owner permissions to the deployer.
     *  @param _sacrificeStart the starting timestamp of the sacrifice period.
     *  @param _feed address of the price feed.
     *  @param _hexit address of the hexit token.
     *  @param _tokens addresses of the supported tokens to sacrifice.
     */
    constructor(uint64 _sacrificeStart, address _feed, address _hexit, address[] memory _tokens) {
        if (_sacrificeStart < block.timestamp) revert InvalidTimestamp();
        if (_feed == address(0)) revert ZeroAddress();
        if (_hexit == address(0)) revert ZeroAddress();
        if (_tokens.length == 0) revert EmptyArray();

        feed = _feed;
        hexit = _hexit;

        uint256 length = _tokens.length;
        for (uint256 i; i < length; ++i) {
            address token = _tokens[i];
            if (token == address(0)) revert ZeroAddress();
            if (!sacrificeTokens.add(token)) revert TokenAlreadySupported();
        }

        sacrificeSchedule.start = _sacrificeStart;
        _grantRole(OWNER_ROLE, msg.sender);
    }

    /**
     *  @dev returns the current day of the sacrifice period.
     */
    function sacrificeDay() public view returns (uint256) {
        uint256 start = sacrificeSchedule.start;
        if (block.timestamp < start || block.timestamp >= start + SACRIFICE_DURATION) {
            revert SacrificeInactive();
        }

        return ((block.timestamp - sacrificeSchedule.start) / 1 days) + 1;
    }

    /**
     *  @dev returns the current day of the airdrop period.
     */
    function airdropDay() public view returns (uint256) {
        Schedule memory schedule = airdropSchedule;
        if (block.timestamp < schedule.start || block.timestamp >= schedule.claimEnd) {
            revert AirdropInactive();
        }

        return ((block.timestamp - schedule.start) / 1 days) + 1;
    }

    /**
     *  @dev initializes the vault in the contract.
     *  @notice can only be called once by the owner.
     *  @param _vault address of the vault.
     */
    function initVault(address _vault) external onlyRole(OWNER_ROLE) {
        if (initialized) revert VaultAlreadyInitialized();
        if (_vault == address(0)) revert ZeroAddress();

        initialized = true;
        vault = _vault;
    }

    /**
     *  @dev function to perform a token sacrifice.
     *  @notice the supported tokens in sacrifice are: hex, dai, wpls and plsx.
     *  @param _token address of the token to be sacrificed.
     *  @param _amount amount of tokens to be sacrificed.
     *  @param _amountOutMin minimum amount of hex tokens expected to be received in exchange.
     */
    function sacrifice(address _token, uint256 _amount, uint256 _amountOutMin) external nonReentrant {
        if (!sacrificeTokens.contains(_token)) revert TokenNotSupported();

        if (_amount == 0) revert InvalidAmount();

        uint256 start = sacrificeSchedule.start;
        if (block.timestamp < start || block.timestamp >= start + SACRIFICE_DURATION) {
            revert SacrificeInactive();
        }

        // if the sacrifice token is not dai get a quote for the sacrifice amount in usd
        uint256 quote;
        if (_token != DAI) {
            quote = _quote(_token, _amount, DAI);
        } else {
            quote = _amount;
        }

        if (quote < MIN_SACRIFICE) revert SacrificedAmountTooLow();

        // update user information
        UserInfo storage user = userInfos[msg.sender];
        user.sacrificedUsd += quote;
        user.hexitShares += _hexitSacrificeShares(quote);

        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        // if the sacrifice token is not hex swap the sacrifice amount to hex
        if (_token != HX) {
            if (_amountOutMin == 0) revert InvalidAmountOutMin();

            IERC20(_token).approve(ROUTER_V1, _amount);

            address[] memory path = new address[](2);
            path[0] = _token;
            path[1] = HX;

            uint256[] memory amountsOut = IPulseXRouter(ROUTER_V1).swapExactTokensForTokens(
                _amount, _amountOutMin, path, address(this), block.timestamp
            );

            sacrificeInfo.sacrificedHx += amountsOut[1];
        } else {
            sacrificeInfo.sacrificedHx += _amount;
        }

        sacrificeInfo.sacrificedUsd += quote;

        emit Sacrificed(msg.sender, _token, _amount);
    }

    /**
     *  @dev process the sacrifice after sacrifice period has finished.
     *  @notice 25% of the sacrificed amount in hex during the sacrifice phase is used to bootstrap
     *  initial liquidity. 12.5% is swapped to DAI, and the other 12.5% is used to mint hex one tokens.
     *  @param _amountOutMin minimum amount of dai tokens expected to be received in exchange.
     */
    function processSacrifice(uint256 _amountOutMin) external nonReentrant onlyRole(OWNER_ROLE) {
        if (_amountOutMin == 0) revert InvalidAmountOutMin();

        Schedule storage schedule = sacrificeSchedule;
        if (block.timestamp < schedule.start + SACRIFICE_DURATION) revert SacrificeActive();

        if (schedule.processed) revert SacrificeAlreadyProcessed();

        schedule.processed = true;
        schedule.claimEnd = uint64(block.timestamp) + SACRIFICE_CLAIM_DURATION;

        // 25% of the sacrificed hex are used to bootstrap the initial HEX1/DAI pool.
        SacrificeInfo memory info = sacrificeInfo;
        uint256 hxAmount = (info.sacrificedHx * LIQUIDITY_RATE) / FIXED_POINT;

        sacrificeInfo.remainingHx = info.sacrificedHx - hxAmount;

        // swap 12.5% of the sacrificed hex to dai
        uint256 halfHxAmount = hxAmount / 2;
        IERC20(HX).approve(ROUTER_V1, halfHxAmount);

        address[] memory path = new address[](2);
        path[0] = HX;
        path[1] = DAI;

        uint256[] memory amountsOut = IPulseXRouter(ROUTER_V1).swapExactTokensForTokens(
            halfHxAmount, _amountOutMin, path, address(this), block.timestamp
        );

        // deposit 12.5% of the sacrificed hex and borrow agaisnt it
        IERC20(HX).approve(vault, halfHxAmount);
        uint256 tokenId = IHexOneVault(vault).deposit(halfHxAmount);
        uint256 hex1Amount = IHexOneVault(vault).maxBorrowable(tokenId);
        IHexOneVault(vault).borrow(tokenId, hex1Amount);

        address hex1 = IHexOneVault(vault).hex1();

        address pair = IPulseXFactory(FACTORY_V2).getPair(hex1, DAI);
        if (pair == address(0)) {
            pair = IPulseXFactory(FACTORY_V2).createPair(hex1, DAI);
        }

        // add newly minted HEX1 and the resulting DAI from the swap as 1:1 liquidity and burn the LP
        IERC20(hex1).approve(ROUTER_V2, hex1Amount);
        IERC20(DAI).approve(ROUTER_V2, amountsOut[1]);
        (uint256 amountA, uint256 amountB, uint256 liquidity) = IPulseXRouter(ROUTER_V2).addLiquidity(
            hex1, DAI, hex1Amount, amountsOut[1], hex1Amount, amountsOut[1], address(0), block.timestamp
        );

        emit SacrificeProcessed(pair, amountA, amountB, liquidity);
    }

    /**
     *  @dev function to claim rewards from the sacrifice period.
     *  @notice creates a hex stake, and max borrow against it.
     */
    function claimSacrifice()
        external
        nonReentrant
        returns (uint256 tokenId, uint256 hex1Minted, uint256 hexitMinted)
    {
        Schedule storage schedule = sacrificeSchedule;
        if (!schedule.processed) revert SacrificeNotProcessed();

        if (block.timestamp >= schedule.claimEnd) revert SacrificeClaimInactive();

        UserInfo storage user = userInfos[msg.sender];
        if (user.sacrificedUsd == 0) revert DidNotParticipateInSacrifice();

        if (user.sacrificeClaimed) revert SacrificeAlreadyClaimed();

        user.sacrificeClaimed = true;

        // increment the total hexit minted during sacrifice
        SacrificeInfo storage info = sacrificeInfo;
        hexitMinted = user.hexitShares;
        info.hexitMinted += hexitMinted;

        // compute the amount of hex to deposit based on the amount sacrificed by the user
        uint256 shares = (user.sacrificedUsd * 1e18) / info.sacrificedUsd;
        uint256 hxToDeposit = (shares * info.remainingHx) / 1e18;

        // deposit hx in the vault and create a new stake
        IERC20(HX).approve(vault, hxToDeposit);
        tokenId = IHexOneVault(vault).deposit(hxToDeposit);

        // max borrow hex1 against the newly created stake
        hex1Minted = IHexOneVault(vault).maxBorrowable(tokenId);
        IHexOneVault(vault).borrow(tokenId, hex1Minted);

        IERC721(vault).transferFrom(address(this), msg.sender, tokenId);
        IERC20(IHexOneVault(vault).hex1()).safeTransfer(msg.sender, hex1Minted);
        IHexitToken(hexit).mint(msg.sender, hexitMinted);

        emit SacrificeClaimed(msg.sender, tokenId, hex1Minted, hexitMinted);
    }

    /**
     *  @dev starts the airdrop claiming period.
     *  @notice mints hexit team allocation to the owner.
     *  @param _airdropStart the starting timestamp of the airdrop period.
     */
    function startAirdrop(uint64 _airdropStart) external nonReentrant onlyRole(OWNER_ROLE) {
        if (_airdropStart < block.timestamp) revert InvalidTimestamp();

        Schedule storage schedule = airdropSchedule;
        if (schedule.processed) revert AirdropAlreadyStarted();

        schedule.start = _airdropStart;
        schedule.claimEnd = _airdropStart + AIRDROP_DURATION;
        schedule.processed = true;

        uint256 hexitTeamAllocation = (sacrificeInfo.hexitMinted * HEXIT_TEAM_RATE) / FIXED_POINT;
        IHexitToken(hexit).mint(msg.sender, hexitTeamAllocation);

        IHexOneVault(vault).enableBuyback();

        emit AirdropStarted(_airdropStart, _airdropStart + AIRDROP_DURATION);
    }

    /**
     *  @dev claim hexit rewards from the airdrop period.
     */
    function claimAirdrop() external nonReentrant {
        Schedule storage schedule = airdropSchedule;
        if (block.timestamp < schedule.start || block.timestamp >= schedule.claimEnd) {
            revert AirdropInactive();
        }

        UserInfo storage user = userInfos[msg.sender];
        if (user.airdropClaimed) revert AirdropAlreadyClaimed();

        uint256 hxStakedUsd = _quote(HX, _getHxStaked(), DAI);
        uint256 hexitMinted = _hexitAirdropShares(user.sacrificedUsd, hxStakedUsd);
        if (hexitMinted == 0) revert IneligibleForAirdrop();

        user.airdropClaimed = true;
        airdropInfo.hexitMinted += hexitMinted;

        IHexitToken(hexit).mint(msg.sender, hexitMinted);

        emit AirdropClaimed(msg.sender, hexitMinted);
    }

    /**
     *  @dev returns a quote based on the amount and tokens given as inputs.
     *  @param _tokenIn address of the token the amount in is.
     *  @param _amountIn amount we want a code quote for.
     *  @param _tokenOut address of the token the quote is returned.
     */
    function _quote(address _tokenIn, uint256 _amountIn, address _tokenOut) private view returns (uint256 amountOut) {
        amountOut = IHexOnePriceFeed(feed).quote(_tokenIn, _amountIn, _tokenOut);
    }

    /**
     *  @dev returns the number of hexit shares a user receives during the sacrifice phase.
     *  @param _sacrificedUsd the total usd value sacrificed by the user.
     */
    function _hexitSacrificeShares(uint256 _sacrificedUsd) private view returns (uint256 hexitShares) {
        hexitShares = (_sacrificedUsd * _baseDailyHexit(sacrificeDay())) / 1e18;
        hexitShares = (hexitShares * MULTIPLIER) / FIXED_POINT;
    }

    /**
     *  @dev returns the number of hexit shares a user receives during the airdrop phase.
     *  @param _sacrificedUsd the total usd value sacrificed by the user.
     *  @param _hxStakedUsd the usd value of HEX tokens staked by the user.
     */
    function _hexitAirdropShares(uint256 _sacrificedUsd, uint256 _hxStakedUsd)
        private
        view
        returns (uint256 hexitShares)
    {
        hexitShares = (9 * _sacrificedUsd) + _hxStakedUsd;
        if (hexitShares == 0) {
            return hexitShares;
        } else {
            return hexitShares + _baseDailyHexit(airdropDay());
        }
    }

    /**
     *  @dev returns the total amount of hex tokens staked by the user.
     */
    function _getHxStaked() private view returns (uint256 hexAmount) {
        uint256 stakeCount = IHexToken(HX).stakeCount(msg.sender);
        if (stakeCount == 0) return 0;

        for (uint256 i; i < stakeCount; ++i) {
            IHexToken.StakeStore memory stakeStore = IHexToken(HX).stakeLists(msg.sender, i);
            hexAmount += stakeStore.stakedHearts;
        }
    }

    /**
     *  @dev returns the base amount of hexit tokens minted per day during the sacrifice or airdrop phases.
     *  @param _day represents the current day of the sacrifice or the current day of the airdrop.
     */
    function _baseDailyHexit(uint256 _day) private pure returns (uint256 baseHexit) {
        baseHexit = BASE_HEXIT;
        for (uint256 i = 2; i <= _day; ++i) {
            baseHexit = (baseHexit * DECREASE_FACTOR) / FIXED_POINT;
        }
    }
}
