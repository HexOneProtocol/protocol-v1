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

/// @title Hex One Bootstrap
/// @dev handles the bootstraping of initial PulseX liquidity and HEXIT.
contract HexOneBootstrap is IHexOneBootstrap, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    /// @dev base hexit amount per dollar for the first day of the sacrifice.
    uint256 public constant SACRIFICE_HEXIT_INIT_AMOUNT = 5_555_555 * 1e18;
    /// @dev duration of the sacrifice.
    uint256 public constant SACRIFICE_DURATION = 30 days;
    /// @dev duration of the sacrifice claim period.
    uint256 public constant SACRIFICE_CLAIM_DURATION = 7 days;

    /// @dev base hexit amount per dollar for the first day of the airdrop.
    uint256 public constant AIRDROP_HEXIT_INIT_AMOUNT = 2_777_778 * 1e18;
    /// @dev duration of the airdrop.
    uint256 public constant AIRDROP_DURATION = 30 days;

    /// @dev the sacrifice base hexit amount per dollar decreases 4.76% daily.
    uint16 public constant SACRIFICE_DECREASE_FACTOR = 9524;
    /// @dev the airdrop base hexit amount per dollar decreases 50% daily.
    uint16 public constant AIRDROP_DECREASE_FACTOR = 5000;

    /// @dev fixed point used to calculate percentages.
    uint16 public constant FIXED_POINT = 10_000;
    /// @dev fixed point used to scale down numbers multiplied by multiplier (5555 for HEX).
    uint16 public constant MULTIPLIER_FIXED_POINT = 1000;

    /// @dev HEXIT rate minted for the team after sacrifice ends.
    uint16 public constant HEXIT_TEAM_RATE = 5000;
    /// @dev HEXIT rate sent to staking to be distributed as rewards.
    uint16 public constant HEXIT_STAKING_RATE = 3333;
    /// @dev HEX rate to swap for DAI when sacrifice is being processed.
    uint16 public constant LIQUIDITY_SWAP_RATE = 1250;

    /// @dev address of the pulseXRouter.
    address public immutable pulseXRouter;
    /// @dev address of the pulseXFactory.
    address public immutable pulseXFactory;

    /// @dev HEX token address.
    address public immutable hexToken;
    /// @dev HEXIT token address.
    address public immutable hexitToken;
    /// @dev DAI from ethereum token address.
    address public immutable daiToken;
    /// @dev HEX1 token address.
    address public immutable hexOneToken;

    /// @dev recipient of the HEXIT tokens minted after sacrifice claim period ends.
    address public immutable teamWallet;

    /// @dev HEX1 price feed contract address.
    address public hexOnePriceFeed;
    /// @dev HEX1 staking contract address.
    address public hexOneStaking;
    /// @dev HEX1 vault contract address.
    address public hexOneVault;

    /// @dev total amount of HEX sacrificed.
    uint256 public totalHexAmount;
    /// @dev total amount of dollars sacrificed.
    uint256 public totalSacrificedUSD;
    /// @dev total amount of HEXIT tokens minted during the bootstrap.
    uint256 public totalHexitMinted;

    /// @dev sacrifice phase inital timestamp.
    uint256 public sacrificeStart;
    /// @dev sacrifice phase final timestamp.
    uint256 public sacrificeEnd;

    /// @dev sacrifice claim phase final timestamp.
    uint256 public sacrificeClaimPeriodEnd;

    /// @dev airdrop phase inital timestamp.
    uint256 public airdropStart;
    /// @dev airdrop phase final timestamp.
    uint256 public airdropEnd;

    /// @dev tracks user information like amount sacrificed in dollars, and hexit shares.
    mapping(address => UserInfo) public userInfos;
    /// @dev maps each sacrifice token to the corresponding multiplier deposit bonus.
    mapping(address => uint16) public tokenMultipliers;

    /// @dev flag to store the status of sacrifice.
    bool public sacrificeProcessed;
    /// @dev flag to store the status of the airdrop.
    bool public airdropStarted;

    /// @dev allowed tokens for sacrifice: HEX, DAI, WPLS & PLSX.
    EnumerableSet.AddressSet private sacrificeTokens;

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

    /// @dev set the address of other protocol contracts.
    /// @notice can only be called by the owner.
    function setBaseData(address _hexOnePriceFeed, address _hexOneStaking, address _hexOneVault) external onlyOwner {
        if (_hexOnePriceFeed == address(0)) revert InvalidAddress(_hexOnePriceFeed);
        if (_hexOneStaking == address(0)) revert InvalidAddress(_hexOneStaking);
        if (_hexOneVault == address(0)) revert InvalidAddress(_hexOneVault);

        hexOnePriceFeed = _hexOnePriceFeed;
        hexOneStaking = _hexOneStaking;
        hexOneVault = _hexOneVault;
    }

    /// @dev set the sacrifice token and its corresponding bonus multiplier.
    /// @notice can only be called by the protocol owner.
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

    /// @dev set the timestamp in which in the sacrifice period will start.
    /// @notice can only be called by the protocol owner and can not be a timestamp in the past.
    /// @param _sacrificeStart timestamp in which the sacrifice is starting.
    function setSacrificeStart(uint256 _sacrificeStart) external onlyOwner {
        if (_sacrificeStart < block.timestamp) revert InvalidTimestamp(block.timestamp);
        sacrificeStart = _sacrificeStart;
        sacrificeEnd = _sacrificeStart + SACRIFICE_DURATION;
    }

    /// @dev returns the current day of the sacrifice.
    /// @notice if the sacrifice had just been activated this func would return day 1.
    function getCurrentSacrificeDay() public view returns (uint256) {
        if (block.timestamp < sacrificeStart) revert SacrificeHasNotStartedYet(block.timestamp);
        if (block.timestamp >= sacrificeEnd) revert SacrificeAlreadyEnded(block.timestamp);

        return ((block.timestamp - sacrificeStart) / 1 days) + 1;
    }

    /// @dev returns the current day of the airdrop.
    /// @notice if the airdrop had just started this func would return day 1.
    function getCurrentAirdropDay() public view returns (uint256) {
        if (block.timestamp < airdropStart) revert AirdropHasNotStartedYet(block.timestamp);
        if (block.timestamp >= airdropEnd) revert AirdropAlreadyEnded(block.timestamp);

        return ((block.timestamp) - airdropStart / 1 days) + 1;
    }

    /// @dev allows user to participate in the sacrifice.
    /// @notice if the token being sacrificed is HEX the _amontOutMin parameter can be passed as zero.
    /// @param _token address of the token being sacrificed, must be: HEX, DAI, WPLS, PLSX.
    /// @param _amountIn amount of token being sacrificed.
    /// @param _amountOutMin min amount of HEX token resulting from the swap, this amount must
    /// be calculated off-chain to avoid frontrunning attacks.
    function sacrifice(address _token, uint256 _amountIn, uint256 _amountOutMin) external {
        if (!sacrificeTokens.contains(_token)) revert InvalidSacrificeToken(_token);
        if (_amountIn == 0) revert InvalidAmountIn(_amountIn);
        if (block.timestamp < sacrificeStart) revert SacrificeHasNotStartedYet(block.timestamp);
        if (block.timestamp >= sacrificeEnd) revert SacrificeAlreadyEnded(block.timestamp);

        // calculate the hexit shares of the token being sacrificed
        (uint256 hexitShares, uint256 amountSacrificedUSD) = _calculateHexitSacrificeShares(_token, _amountIn);

        // update the user info to increment the total hexit shares and usd sacrificed by the sender
        UserInfo storage userInfo = userInfos[msg.sender];
        userInfo.hexitShares += hexitShares;
        userInfo.sacrificedUSD += amountSacrificedUSD;

        // update the total amount of USD sacrificed in during the sacrifice phase
        totalSacrificedUSD += amountSacrificedUSD;

        // transfer tokens from the sender to the contract
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

    /// @dev swaps 12.5% of HEX to DAI, deposits 12.5% of HEX to mint HEX1 and create a PulseX
    /// pair of HEX1/DAI with nearly 1:1 ratio.
    /// @notice can only be called by the owner.
    /// @param _amountOutMinDai min amount of DAI tokens resulting from swapping HEX to DAI.
    function processSacrifice(uint256 _amountOutMinDai) external onlyOwner {
        if (block.timestamp < sacrificeEnd) revert SacrificeHasNotEndedYet(block.timestamp);
        if (sacrificeProcessed) revert SacrificeAlreadyProcessed();

        // set the sacrifice processed flag to true since the sacrifice was already processed
        sacrificeProcessed = true;

        // update the sacrifice claim period end timestamp
        sacrificeClaimPeriodEnd = block.timestamp + SACRIFICE_CLAIM_DURATION;

        // compute the HEX to swap, corresponding to 12.5% of the total HEX sacrificed
        uint256 hexToSwap = (totalHexAmount * LIQUIDITY_SWAP_RATE) / FIXED_POINT;

        // update the total amount of HEX in the contract by reducing it hexToSwap * 2
        // because 12.5% is used to being swapped to DAI and the other 12.5% are used to mint HEX1
        // that being said 25% of the inital HEX sacrificed should be decremented here!
        totalHexAmount -= hexToSwap * 2;

        // swap 12.5% of inital HEX to DAI from ETH
        address[] memory path = new address[](2);
        path[0] = hexToken;
        path[1] = daiToken;

        IERC20(hexToken).approve(pulseXRouter, hexToSwap);

        uint256[] memory amountOut = IPulseXRouter(pulseXRouter).swapExactTokensForTokens(
            hexToSwap, _amountOutMinDai, path, address(this), block.timestamp
        );

        // enable hex one vault to start working because sacrifice has been processed.
        IHexOneVault(hexOneVault).setSacrificeStatus();

        // create a new deposit for `MAX_DURATION` in the vault with 12.5% of the total minted HEX
        IERC20(hexToken).approve(hexOneVault, hexToSwap);
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

    /// @dev claim HEXIT and HEXIT based on the total amount sacrificed.
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

    /// @dev mints 33% on top of the total hexit minted during sacrifice to the staking
    /// contract and an addittional 
    /// @notice can only be called by the owner of the contract.
    function startAidrop() external onlyOwner {
        if (block.timestamp < sacrificeClaimPeriodEnd) revert SacrificeClaimPeriodHasNotFinished(block.timestamp);
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

    /// @dev amount of HEXIT being airdrop is computed based on the amount of HEX sacrificed
    /// and the amount of HEX in USD the user has staked.
    function claimAirdrop() external {
        if (block.timestamp < airdropStart) revert AirdropHasNotStartedYet(block.timestamp);
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

    /// @dev computes the amount of HEXIT tokens based on the amount sacrificed.
    /// @param _tokenIn address of the token being sacrificed.
    /// @param _amountIn amount of tokenIn being sacrificed.
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

    /// @dev tries to consult the price of `tokenIn` in `tokenOut`.
    /// @notice if consult reverts with PriceTooStale then it needs to
    /// update the oracle and only then consult the price again.
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

    /// @dev computes the amount of HEXIT per dollar to distribute based on the
    /// current sacrifice day.
    function _sacrificeBaseHexitPerDollar() internal view returns (uint256 baseHexit) {
        uint256 currentSacrificeDay = getCurrentSacrificeDay();
        if (currentSacrificeDay == 1) {
            return SACRIFICE_HEXIT_INIT_AMOUNT;
        }

        baseHexit = SACRIFICE_HEXIT_INIT_AMOUNT;
        for (uint256 i = 2; i <= currentSacrificeDay; ++i) {
            baseHexit = (baseHexit * SACRIFICE_DECREASE_FACTOR) / FIXED_POINT;
        }
    }

    /// @dev computes the amount of HEXIT per dollar to distribute based on the
    /// current airdrop day.
    function _airdropBaseHexitPerDollar() internal view returns (uint256 baseHexit) {
        uint256 currentAirdropDay = getCurrentAirdropDay();
        if (currentAirdropDay == 1) {
            return AIRDROP_HEXIT_INIT_AMOUNT;
        }

        baseHexit = AIRDROP_HEXIT_INIT_AMOUNT;
        for (uint256 i = 2; i <= currentAirdropDay; ++i) {
            baseHexit = (baseHexit * SACRIFICE_DECREASE_FACTOR) / FIXED_POINT;
        }
    }

    /// @dev computes the amount of HEX the user has in staking.
    /// @notice HEX is calculating by the share rate of t-shares.
    /// @param _user address of HEX staker.
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
