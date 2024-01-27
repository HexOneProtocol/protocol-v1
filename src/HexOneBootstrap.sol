// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {LibString} from "solady/utils/LibString.sol";

import {IHexOneBootstrap} from "./interfaces/IHexOneBootstrap.sol";
import {IHexOnePriceFeed} from "./interfaces/IHexOnePriceFeed.sol";
import {IHexOneVault} from "./interfaces/IHexOneVault.sol";
import {IHexOneStaking} from "./interfaces/IHexOneStaking.sol";
import {IHexitToken} from "./interfaces/IHexitToken.sol";
import {IHexToken} from "./interfaces/IHexToken.sol";
import {IPulseXRouter02 as IPulseXRouter} from "./interfaces/pulsex/IPulseXRouter.sol";
import {IPulseXFactory} from "./interfaces/pulsex/IPulseXFactory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract HexOneBootstrap is IHexOneBootstrap, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    uint256 public constant SACRIFICE_HEXIT_INIT_AMOUNT = 5_555_555 * 1e18;
    uint256 public constant SACRIFICE_DURATION = 30 days;
    uint256 public constant SACRIFICE_CLAIM_DURATION = 7 days;
    uint256 public constant AIRDROP_HEXIT_INIT_AMOUNT = 2_777_778 * 1e18;
    uint256 public constant AIRDROP_DURATION = 30 days;

    uint16 public constant SACRIFICE_DECREASE_FACTOR = 9524;
    uint16 public constant AIRDROP_DECREASE_FACTOR = 5000;

    uint16 public constant FIXED_POINT = 10_000;
    uint16 public constant MULTIPLIER_FIXED_POINT = 1000;
    uint16 public constant HEXIT_TEAM_RATE = 5000;
    uint16 public constant HEXIT_STAKING_RATE = 3333;
    uint16 public constant LIQUIDITY_SWAP_RATE = 1250;

    address public immutable pulseXRouter;
    address public immutable pulseXFactory;
    address public immutable hexToken;
    address public immutable hexitToken;
    address public immutable daiToken;
    address public immutable hexOneToken;
    address public immutable teamWallet;

    EnumerableSet.AddressSet private sacrificeTokens;

    mapping(address => uint16) public tokenMultipliers;
    mapping(address => UserInfo) public userInfos;

    address public hexOnePriceFeed;
    address public hexOneStaking;
    address public hexOneVault;

    uint256 public totalHexAmount;
    uint256 public totalHexitMinted;
    uint256 public totalSacrificedUSD;

    uint256 public sacrificeStart;
    uint256 public sacrificeEnd;
    uint256 public sacrificeClaimPeriodEnd;

    uint256 public airdropStart;
    uint256 public airdropEnd;

    bool public sacrificeProcessed;
    bool public airdropStarted;

    constructor(
        address _pulseXRouter,
        address _pulseXFactory,
        address _hexToken,
        address _hexitToken,
        address _daiToken,
        address _hexOneToken,
        address _teamWallet
    ) Ownable(msg.sender) {
        if (_pulseXRouter == address(0)) revert InvalidAddress(_pulseXRouter);
        if (_pulseXFactory == address(0)) revert InvalidAddress(_pulseXFactory);
        if (_hexToken == address(0)) revert InvalidAddress(_hexToken);
        if (_hexitToken == address(0)) revert InvalidAddress(_hexitToken);
        if (_daiToken == address(0)) revert InvalidAddress(_daiToken);
        if (_teamWallet == address(0)) revert InvalidAddress(_teamWallet);

        pulseXRouter = _pulseXRouter;
        pulseXFactory = _pulseXFactory;
        hexToken = _hexToken;
        hexitToken = _hexitToken;
        daiToken = _daiToken;
        hexOneToken = _hexOneToken;
        teamWallet = _teamWallet;
    }

    function setBaseData(address _hexOnePriceFeed, address _hexOneStaking, address _hexOneVault) external onlyOwner {
        if (_hexOnePriceFeed == address(0)) revert InvalidAddress(_hexOnePriceFeed);
        if (_hexOneStaking == address(0)) revert InvalidAddress(_hexOneStaking);
        if (_hexOneVault == address(0)) revert InvalidAddress(_hexOneVault);

        hexOnePriceFeed = _hexOnePriceFeed;
        hexOneStaking = _hexOneStaking;
        hexOneVault = _hexOneVault;
    }

    function setSacrificeTokens(address[] calldata _tokens, uint16[] calldata _multipliers) external onlyOwner {
        uint256 length = _tokens.length;
        if (length == 0) revert ZeroLengthArray();
        if (length != _multipliers.length) revert MismatchedArrayLength();

        for (uint256 i; i < length; ++i) {
            address token = _tokens[i];
            uint16 multiplier = _multipliers[i];

            if (sacrificeTokens.contains(token)) revert TokenAlreadyAdded(token);
            if (multiplier == 0) revert InvalidMultiplier(multiplier);

            sacrificeTokens.add(token);
            tokenMultipliers[token] = multiplier;
        }
    }

    function setSacrificeStart(uint256 _sacrificeStart) external onlyOwner {
        if (_sacrificeStart < block.timestamp) revert InvalidTimestamp(block.timestamp);
        sacrificeStart = _sacrificeStart;
        sacrificeEnd = _sacrificeStart + SACRIFICE_DURATION;
    }

    function getCurrentSacrificeDay() public view returns (uint256) {
        uint256 timestamp = block.timestamp;

        // check if sacrifice has already started
        if (timestamp < sacrificeStart) revert SacrificeHasNotStartedYet(timestamp);

        // check if sacrifice has not ended yet
        if (timestamp >= sacrificeEnd) revert SacrificeAlreadyEnded(timestamp);

        // if the sacrifice had just started this should return 1
        return ((timestamp - sacrificeStart) / 1 days) + 1;
    }

    function getCurrentAirdropDay() public view returns (uint256) {
        uint256 timestamp = block.timestamp;

        // check if the airdrop has already started
        if (timestamp < airdropStart) revert AirdropHasNotStartedYet(timestamp);

        // check if the airdrop has not ended yet
        if (timestamp >= airdropEnd) revert AirdropAlreadyEnded(timestamp);

        // if the airdrop has just started this should return 1
        return ((timestamp) - airdropStart / 1 days) + 1;
    }

    /// @notice allows user to participate in the sacrifice.
    /// @dev if the token being sacrificed is HEX the _amontOutMin parameter is ignored
    /// @param _token address of the token being sacrificed, must be: HEX, DAI, WPLS, PLSX.
    /// @param _amountIn amount of token being sacrificed.
    /// @param _amountOutMin min amount of HEX token resulting from the swap, this amount must
    /// be calculated off-chain to avoid frontrunning attacks. note: this parameters can
    /// be left as zero if sacrificing HEX.
    function sacrifice(address _token, uint256 _amountIn, uint256 _amountOutMin) external {
        // if the token is not allowed revert
        if (!sacrificeTokens.contains(_token)) revert InvalidSacrificeToken(_token);

        // check if the amount being sacrificed is valid
        if (_amountIn == 0) revert InvalidAmountIn(_amountIn);

        // check if sacrifice already started
        if (block.timestamp < sacrificeStart) revert SacrificeHasNotStartedYet(block.timestamp);

        // check if sacrifice has not ended yet
        if (block.timestamp >= sacrificeEnd) revert SacrificeAlreadyEnded(block.timestamp);

        // calculate the hexit shares of the token being sacrificed
        (uint256 hexitShares, uint256 amountSacrificedUSD) = _calculateHexitSacrificeShares(_token, _amountIn);

        // update the user info to increment the total hexit shares and usd sacrificed by the sender
        UserInfo storage userInfo = userInfos[msg.sender];
        userInfo.hexitShares += hexitShares;
        userInfo.sacrificedUSD += amountSacrificedUSD;

        // update the total amount of USD sacrificed in during the sacrifice phase
        totalSacrificedUSD += amountSacrificedUSD;

        // transfer tokens to the contract
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amountIn);

        if (_token != hexToken) {
            // check if the amount out min is valid
            if (_amountOutMin == 0) revert InvalidAmountOutMin(_amountOutMin);

            // approve pulseXRouter to spend the token being sacrificed
            IERC20(_token).approve(pulseXRouter, _amountIn);

            // create a swap path from the token
            address[] memory path = new address[](2);
            path[0] = _token;
            path[1] = hexToken;

            // call the pulsex router to make a swap for exact tokens to tokens
            uint256[] memory amountOut = IPulseXRouter(pulseXRouter).swapExactTokensForTokens(
                _amountIn, _amountOutMin, path, address(this), block.timestamp
            );

            // increment total amount of HEX in the contract
            // index is one because it is corresponding to the amount out of token in path[1]
            totalHexAmount += amountOut[1];
        } else {
            // increment total amount of HEX in the contract
            totalHexAmount += _amountIn;
        }

        emit Sacrificed(msg.sender, _token, _amountIn, amountSacrificedUSD, hexitShares);
    }

    function processSacrifice(uint256 _amountOutMinDai) external onlyOwner {
        // check if sacrifice has already ended
        if (block.timestamp < sacrificeEnd) revert SacrificeHasNotEndedYet(block.timestamp);

        // check if sacrifice has already been processed.
        if (sacrificeProcessed) revert SacrificeAlreadyProcessed();

        // set the sacrifice processed flag to true since the sacrifice was already processed
        sacrificeProcessed = true;

        // compute the HEX to swap, corresponding to 12.5% of the total HEX sacrificed
        uint256 hexToSwap = (totalHexAmount * LIQUIDITY_SWAP_RATE) / FIXED_POINT;

        // update the sacrifice claim period end timestamp
        sacrificeClaimPeriodEnd = block.timestamp + SACRIFICE_CLAIM_DURATION;

        // update the total amount of HEX in the contract by reducing it hexToSwap * 2
        // because 12.5% is used to being swapped to DAI and the other 12.5% are used to mint HEX1
        // that being said 25% of the inital HEX sacrificed should be decremented here!
        totalHexAmount -= hexToSwap * 2;

        // swap 12.5% of inital HEX to DAI from ETH
        address[] memory path = new address[](2);
        path[0] = hexToken;
        path[1] = daiToken;

        // approve pulseXRouter to spend `hexToSwap`
        IERC20(hexToken).approve(pulseXRouter, hexToSwap);

        // use 12.5% of the inital HEX to mint HEX1 through the vault
        uint256[] memory amountOut = IPulseXRouter(pulseXRouter).swapExactTokensForTokens(
            hexToSwap, _amountOutMinDai, path, address(this), block.timestamp
        );

        // enable hex one vault to start working because sacrifice has been processed.
        IHexOneVault(hexOneVault).setSacrificeStatus();

        // approve the vault to spend `hexToSwap`
        IERC20(hexToken).approve(hexOneVault, hexToSwap);

        // create a new deposit for `MAX_DURATION` in the vault with 12.5% of the total minted HEX
        (uint256 hexOneMinted,) = IHexOneVault(hexOneVault).deposit(hexToSwap, 5555);

        // check if there's an already created HEX1/DAI pair
        address hexOneDaiPair = IPulseXFactory(pulseXFactory).getPair(hexOneToken, daiToken);
        if (hexOneDaiPair == address(0)) {
            hexOneDaiPair = IPulseXFactory(pulseXFactory).createPair(hexOneToken, daiToken);
        }

        // approve router for both amounts
        IERC20(hexOneToken).approve(pulseXRouter, hexOneMinted);
        IERC20(daiToken).approve(pulseXRouter, amountOut[1]);

        // use the newly minted HEX1 + DAI from ETH and create an LP with 1:1 ratio
        // note: since the pair has no liquidity I'm passing real amount and desired amounts as the same values
        (uint256 amountHexOneSent, uint256 amountDaiSent, uint256 liquidity) = IPulseXRouter(pulseXRouter).addLiquidity(
            hexOneToken,
            daiToken,
            hexOneMinted,
            amountOut[1],
            hexOneMinted,
            amountOut[1],
            address(this),
            block.timestamp
        );

        emit SacrificeProcessed(hexOneDaiPair, amountHexOneSent, amountDaiSent, liquidity);
    }

    function claimSacrifice() external returns (uint256 stakeId, uint256 hexOneMinted, uint256 hexitMinted) {
        // check if sacrifice has already been processed
        if (!sacrificeProcessed) revert SacrificeHasNotBeenProcessedYet();

        // check if the sacrifice claim period has already ended (7 days)
        if (block.timestamp >= sacrificeClaimPeriodEnd) revert SacrificeClaimPeriodAlreadyFinished(block.timestamp);

        // check if the user has sacrificed
        UserInfo storage userInfo = userInfos[msg.sender];
        if (userInfo.sacrificedUSD == 0) revert DidNotParticipateInSacrifice(msg.sender);

        // check if the user already claimed
        if (userInfo.claimedSacrifice) revert SacrificeAlreadyClaimed(msg.sender);

        // compute the amount of HEX to send to the vault based on the amount
        // totalSacrificedUSD - 1e18
        // userSacrificedUSD - hexShares
        uint256 hexShares = (userInfo.sacrificedUSD * 1e18) / totalSacrificedUSD;

        // calculate the amount of HEX that user will use to mint HEX1 based on his shares
        // totalHexAmount - 1e18
        // hexToStake - hexShares
        uint256 hexToStake = (hexShares * totalHexAmount) / 1e18;

        // set claim sacrifice to true
        userInfo.claimedSacrifice = true;

        // upodate the total hexit minted by the bootstrap
        hexitMinted = userInfo.hexitShares;
        totalHexitMinted += hexitMinted;

        // approve the vault to spend HEX
        IERC20(hexToken).approve(hexOneVault, hexToStake);

        // call the vault to mint HEX1 in the name of the sender
        (hexOneMinted, stakeId) = IHexOneVault(hexOneVault).deposit(msg.sender, hexToStake, 5555);

        // mint hexit
        IHexitToken(hexitToken).mint(msg.sender, hexitMinted);

        emit SacrificeClaimed(msg.sender, hexOneMinted, hexitMinted);
    }

    function startAidrop() external onlyOwner {
        // check if the sacrifice claim period already ended (7 days)
        if (block.timestamp < sacrificeClaimPeriodEnd) revert SacrificeClaimPeriodHasNotFinished(block.timestamp);

        // check if airdrop was already started
        if (airdropStarted) revert AirdropAlreadyStarted();

        // 50% more of the total HEXIT minted during the sacrifice phase is minted to
        // the team
        uint256 hexitTeamAlloc = (totalHexitMinted * HEXIT_TEAM_RATE) / FIXED_POINT;

        // 33% more of the total HEXIT minted during the sacrifice phase is used to
        // purchase HEXIT
        uint256 hexitStakingAlloc = (totalHexitMinted * HEXIT_STAKING_RATE) / FIXED_POINT;

        // set airdrop started to true
        airdropStarted = true;
        airdropStart = block.timestamp;
        airdropEnd = block.timestamp + AIRDROP_DURATION;

        // increment the total HEXIT minted
        totalHexitMinted += hexitTeamAlloc + hexitStakingAlloc;

        // mint hexit team allocation to the team wallet
        IHexitToken(hexitToken).mint(teamWallet, hexitTeamAlloc);

        // minted hexit staking allocation to this contract
        IHexitToken(hexitToken).mint(address(this), hexitStakingAlloc);

        // approve the staking contract to spend HEXIT
        IERC20(hexitToken).approve(hexOneStaking, hexitStakingAlloc);

        // add the minted HEXIT to the staking contract
        IHexOneStaking(hexOneStaking).purchase(hexitToken, hexitStakingAlloc);

        // enable staking
        IHexOneStaking(hexOneStaking).enableStaking();

        emit AirdropStarted(hexitTeamAlloc, hexitStakingAlloc);
    }

    function claimAirdrop() external {
        // check if the airdrop has already started
        if (block.timestamp < airdropStart) revert AirdropHasNotStartedYet(block.timestamp);

        // check if the airdrop has not ended yet
        if (block.timestamp >= airdropEnd) revert AirdropAlreadyEnded(block.timestamp);

        // check if the sender already claimed the airdrop
        UserInfo storage userInfo = userInfos[msg.sender];
        if (userInfo.claimedAirdrop) revert AirdropAlreadyClaimed(msg.sender);

        // calculate the amount to airdrop based on the amount
        // that the msg.sender has of staked HEX and sacrificed USD
        uint256 hexitShares = _calculateHexitAirdropShares();
        if (hexitShares == 0) revert IneligibleForAirdrop(msg.sender);

        // increment the total amount of hexit minted by the contract
        totalHexitMinted += hexitShares;

        // mint HEXIT to the sender
        IHexitToken(hexitToken).mint(msg.sender, hexitShares);

        emit AirdropClaimed(msg.sender, hexitShares);
    }

    function _calculateHexitSacrificeShares(address _tokenIn, uint256 _amountIn)
        internal
        returns (uint256 hexitShares, uint256 sacrificedUSD)
    {
        if (_tokenIn == daiToken) {
            sacrificedUSD = _amountIn;
        } else {
            sacrificedUSD = _consultTokenPrice(_tokenIn, _amountIn, daiToken);
        }

        // compute the amount of HEXIT based on the amount of dollars sacrificed
        hexitShares = (sacrificedUSD * _sacrificeBaseHexitPerDollar()) / 1e18;

        // apply the multiplier based on the sacrificed token
        hexitShares = (hexitShares * tokenMultipliers[_tokenIn]) / MULTIPLIER_FIXED_POINT;
    }

    function _calculateHexitAirdropShares() internal returns (uint256 hexitShares) {
        // get the amount of HEX the sender has staked in the HEX contract
        uint256 hexStaked = _getHexStaked(msg.sender);

        // get the amount of HEX staked by the sender in USD
        uint256 hexStakedUSD = _consultTokenPrice(hexToken, hexStaked, daiToken);

        // get the total amount of USD sacrificed by the sender
        uint256 sacrificedUSD = userInfos[msg.sender].sacrificedUSD;

        // compute the amount of HEXIT to airdrop
        hexitShares = (9 * sacrificedUSD) + hexStakedUSD + _airdropBaseHexitPerDollar();
    }

    function _consultTokenPrice(address _tokenIn, uint256 _amountIn, address _tokenOut) internal returns (uint256) {
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

    function _sacrificeBaseHexitPerDollar() internal view returns (uint256 baseHexit) {
        uint256 currentSacrificeDay = getCurrentSacrificeDay();
        if (currentSacrificeDay == 1) {
            return SACRIFICE_HEXIT_INIT_AMOUNT;
        }

        // starts in day 2 because day one is already handled
        baseHexit = SACRIFICE_HEXIT_INIT_AMOUNT;
        for (uint256 i = 2; i <= currentSacrificeDay; ++i) {
            baseHexit = (baseHexit * SACRIFICE_DECREASE_FACTOR) / FIXED_POINT;
        }
    }

    function _airdropBaseHexitPerDollar() internal view returns (uint256 baseHexit) {
        uint256 currentAirdropDay = getCurrentAirdropDay();
        if (currentAirdropDay == 1) {
            return AIRDROP_HEXIT_INIT_AMOUNT;
        }

        // starts in day 2 because day one is already handled
        baseHexit = AIRDROP_HEXIT_INIT_AMOUNT;
        for (uint256 i = 2; i <= currentAirdropDay; ++i) {
            baseHexit = (baseHexit * SACRIFICE_DECREASE_FACTOR) / FIXED_POINT;
        }
    }

    function _getHexStaked(address _user) internal view returns (uint256 hexAmount) {
        uint256 stakeCount = IHexToken(hexToken).stakeCount(_user);
        if (stakeCount == 0) return 0;

        // note: potential denial of service issue if sender has many stakes!
        // no clue how to solve this issue yet

        uint256 shares;
        for (uint256 i; i < stakeCount; ++i) {
            IHexToken.StakeStore memory stakeStore = IHexToken(hexToken).stakeLists(_user, i);
            shares += stakeStore.stakeShares;
        }

        IHexToken.GlobalsStore memory globals = IHexToken(hexToken).globals();
        uint256 shareRate = uint256(globals.shareRate); 

        hexAmount = uint256((shares * shareRate) / 1e5);
    }

}
