// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import {HexOneToken} from "./HexOneToken.sol";

import {ERC721} from "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {TokenUtils} from "./utils/TokenUtils.sol";

import {IHexOneVault} from "./interfaces/IHexOneVault.sol";
import {IHexOneToken} from "./interfaces/IHexOneToken.sol";
import {IHexOnePriceFeed} from "./interfaces/IHexOnePriceFeed.sol";
import {IHexToken} from "./interfaces/IHexToken.sol";

import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IPulseXRouter02 as IPulseXRouter} from "./interfaces/pulsex/IPulseXRouter.sol";
import {IHedron} from "./interfaces/IHedron.sol";

contract HexOneVault is ERC721, AccessControl, ReentrancyGuard, IHexOneVault {
    using SafeERC20 for IERC20;

    bytes32 public constant BOOTSTRAP_ROLE = keccak256("BOOTSTRAP_ROLE");

    uint16 public constant DURATION = 5555;
    uint16 public constant GRACE_PERIOD = 7;
    uint16 public constant MIN_HEALTH_RATIO = 25_000;
    uint16 public constant FIXED_POINT = 10_000;
    uint16 public constant FEE = 100;

    uint256 private constant HEARTS_UINT_SHIFT = 72;
    uint256 private constant HEARTS_MASK = (1 << HEARTS_UINT_SHIFT) - 1;

    address private constant ROUTER_V2 = 0x165C3410fC91EF562C50559f7d2289fEbed552d9;
    address private constant HX = 0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39;
    address private constant HDRN = 0x3819f64f282bf135d62168C1e513280dAF905e06;
    address private constant WPLS = 0xA1077a294dDE1B09bB078844df40758a5D0f9a27;
    address private constant DAI = 0xefD766cCb38EaF1dfd701853BFCe31359239F305;
    address private constant USDC = 0x15D38573d2feeb82e7ad5187aB8c1D52810B1f07;
    address private constant USDT = 0x0Cb6F5a34ad42ec934882A05265A7d5F59b51A2f;

    address public immutable feed;
    address public immutable hex1;

    bool public buybackEnabled;
    mapping(uint256 => Stake) public stakes;

    uint256 internal id;

    constructor(address _feed) ERC721("HEX1 Debt Title", "HDT") {
        if (_feed == address(0)) revert ZeroAddress();

        feed = _feed;
        hex1 = address(new HexOneToken());

        _grantRole(BOOTSTRAP_ROLE, msg.sender);
    }

    /**
     *  @dev
     *  @notice
     *  @param _interfaceId a
     */
    function supportsInterface(bytes4 _interfaceId) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(_interfaceId);
    }

    /**
     *  @dev
     *  @notice
     */
    function currentDay() public view returns (uint256) {
        return IHexToken(HX).currentDay();
    }

    /**
     *  @dev
     *  @notice
     *  @param _id a
     */
    function healthRatio(uint256 _id) public view returns (uint256 ratio) {
        Stake memory stake = stakes[_id];

        uint256 hxAmount;
        if (currentDay() >= stake.end) {
            hxAmount = stake.amount + _accrued(_id, stake.start, stake.end);
        } else {
            hxAmount = stake.amount + _accrued(_id, stake.start, currentDay()) + _payout(_id);
        }

        if (stake.debt != 0) {
            ratio = (_hxQuote(hxAmount) * FIXED_POINT) / stake.debt;
        }
    }

    /**
     *  @dev
     *  @notice
     *  @param _id a
     */
    function maxBorrowable(uint256 _id) public view returns (uint256 amount) {
        Stake memory stake = stakes[_id];

        uint256 hxQuote = _hxQuote(stake.amount);
        if (hxQuote > stake.debt) {
            amount = hxQuote - stake.debt;
        }
    }

    /**
     *  @dev
     *  @notice
     */
    function enableBuyback() external onlyRole(BOOTSTRAP_ROLE) {
        buybackEnabled = true;
    }

    /**
     *  @dev
     *  @notice
     *  @param _amount a
     */
    function deposit(uint256 _amount) external nonReentrant returns (uint256 tokenId) {
        if (_amount == 0) revert InvalidAmount();

        IERC20(HX).safeTransferFrom(msg.sender, address(this), _amount);

        uint256 fee;
        if (buybackEnabled) {
            fee = _computeFee(_amount);
            _amount = _amount - fee;
        }

        tokenId = id++;

        _mint(msg.sender, tokenId);

        IHexToken(HX).stakeStart(_amount, DURATION);

        IHexToken.StakeStore memory stakeStore = IHexToken(HX).stakeLists(address(this), tokenId);
        stakes[tokenId] = Stake({
            debt: 0,
            amount: stakeStore.stakedHearts,
            shares: stakeStore.stakeShares,
            param: stakeStore.stakeId,
            start: stakeStore.lockedDay,
            end: stakeStore.lockedDay + DURATION
        });

        if (fee != 0) {
            _buyback(fee);
        }

        emit Deposited(msg.sender, tokenId, _amount);
    }

    /**
     *  @dev
     *  @notice
     *  @param _id a
     */
    function withdraw(uint256 _id) external nonReentrant returns (uint256 hxAmount, uint256 hdrnAmount) {
        if (msg.sender != ownerOf(_id)) revert InvalidOwner();

        Stake memory stake = stakes[_id];
        if (currentDay() < stake.end) revert StakeNotMature();

        _burn(_id);

        delete stakes[_id];

        if (stake.debt != 0) {
            IHexOneToken(hex1).burn(msg.sender, stake.debt);
            emit Repaid(msg.sender, _id, stake.debt);
        }

        hdrnAmount = _claimHdrn(_id, stake.param);
        hxAmount = _claimHx(_id, stake.param);

        IERC20(HDRN).safeTransfer(msg.sender, hdrnAmount);
        IERC20(HX).safeTransfer(msg.sender, hxAmount);

        emit Withdrawn(msg.sender, _id, hxAmount, hdrnAmount);
    }

    /**
     *  @dev
     *  @notice
     *  @param _id a
     */
    function liquidate(uint256 _id) external nonReentrant returns (uint256 hxAmount, uint256 hdrnAmount) {
        Stake memory stake = stakes[_id];
        if (currentDay() < stake.end + GRACE_PERIOD) revert StakeNotLiquidatable();

        _burn(_id);

        delete stakes[_id];

        if (stake.debt != 0) {
            IHexOneToken(hex1).burn(msg.sender, stake.debt);
            emit Repaid(msg.sender, _id, stake.debt);
        }

        hdrnAmount = _claimHdrn(_id, stake.param);
        hxAmount = _claimHx(_id, stake.param);

        IERC20(HDRN).safeTransfer(msg.sender, hdrnAmount);
        IERC20(HX).safeTransfer(msg.sender, hxAmount);

        emit Liquidated(msg.sender, _id, hxAmount, hdrnAmount);
    }

    /**
     *  @dev
     *  @notice
     *  @param _id a
     *  @param _amount a
     */
    function repay(uint256 _id, uint256 _amount) external nonReentrant {
        if (msg.sender != ownerOf(_id)) revert InvalidOwner();
        if (_amount == 0) revert InvalidAmount();

        stakes[_id].debt -= _amount;

        IHexOneToken(hex1).burn(msg.sender, _amount);

        emit Repaid(msg.sender, _id, _amount);
    }

    /**
     *  @dev
     *  @notice
     *  @param _id a
     *  @param _amount a
     */
    function borrow(uint256 _id, uint256 _amount) external nonReentrant {
        if (msg.sender != ownerOf(_id)) revert InvalidOwner();
        if (_amount == 0) revert InvalidAmount();

        Stake memory stake = stakes[_id];
        if (currentDay() >= stake.end) revert StakeMature();

        if (maxBorrowable(_id) < _amount) revert MaxBorrowExceeded();

        stakes[_id].debt += _amount;

        if (healthRatio(_id) < MIN_HEALTH_RATIO) revert HealthRatioTooLow();

        IHexOneToken(hex1).mint(msg.sender, _amount);

        emit Borrowed(msg.sender, _id, _amount);
    }

    /**
     *  @dev
     *  @notice
     *  @param _id a
     *  @param _amount a
     */
    function take(uint256 _id, uint256 _amount) external nonReentrant {
        Stake memory stake = stakes[_id];
        if (currentDay() >= stake.end + GRACE_PERIOD) revert StakeNotLiquidatable();

        if (healthRatio(_id) == 0 || healthRatio(_id) >= MIN_HEALTH_RATIO) {
            revert HealthRatioTooHigh();
        }

        uint256 minAmount = stake.debt / 2;
        if (_amount < minAmount) revert NotEnoughToTake();

        stakes[_id].debt -= _amount;

        if (healthRatio(_id) < MIN_HEALTH_RATIO) revert HealthRatioTooLow();

        _transfer(ownerOf(_id), msg.sender, _id);

        IHexOneToken(hex1).burn(msg.sender, _amount);

        emit Took(msg.sender, _id, _amount);
    }

    /**
     *  @dev
     *  @notice
     *  @param _fee a
     */
    function _buyback(uint256 _fee) private {
        IERC20(HX).approve(ROUTER_V2, _fee);

        address[] memory path = new address[](4);
        path[0] = HX;
        path[1] = WPLS;
        path[2] = DAI;
        path[3] = hex1;

        // TODO : think of a better way to compute a solution for slippage protection in the buyback

        uint256[] memory amounts =
            IPulseXRouter(ROUTER_V2).swapExactTokensForTokens(_fee, 0, path, address(this), block.timestamp);

        IHexOneToken(hex1).burn(address(this), amounts[amounts.length - 1]);
    }

    /**
     *  @dev
     *  @notice
     *  @param _id a
     *  @param _param a
     */
    function _claimHx(uint256 _id, uint40 _param) private returns (uint256 hxAmount) {
        uint256 balanceBefore = IERC20(HX).balanceOf(address(this));
        IHexToken(HX).stakeEnd(_id, _param);
        uint256 balanceAfter = IERC20(HX).balanceOf(address(this));

        hxAmount = balanceAfter - balanceBefore;
    }

    /**
     *  @dev
     *  @notice
     *  @param _id a
     *  @param _param a
     */
    function _claimHdrn(uint256 _id, uint40 _param) private returns (uint256 hdrnAmount) {
        hdrnAmount = IHedron(HDRN).mintNative(_id, _param);
    }

    /**
     *  @dev
     *  @notice
     *  @param _amountIn a
     */
    function _hxQuote(uint256 _amountIn) private view returns (uint256 hxQuote) {
        uint256 hexDaiQuote = _quote(HX, _amountIn, DAI);
        uint256 hexUsdcQuote = _convert(USDC, _quote(HX, _amountIn, USDC));
        uint256 hexUsdtQuote = _convert(USDT, _quote(HX, _amountIn, USDT));
        hxQuote = (hexDaiQuote + hexUsdcQuote + hexUsdtQuote) / 3;
    }

    /**
     *  @dev
     *  @notice
     *  @param _tokenIn a
     *  @param _amountIn a
     *  @param _tokenOut a
     */
    function _quote(address _tokenIn, uint256 _amountIn, address _tokenOut) private view returns (uint256 amountOut) {
        amountOut = IHexOnePriceFeed(feed).quote(_tokenIn, _amountIn, _tokenOut);
    }

    /**
     *  @dev
     *  @notice
     *  @param _token a
     *  @param _amountIn a
     */
    function _convert(address _token, uint256 _amountIn) private view returns (uint256 amountOut) {
        uint8 decimals = TokenUtils.expectDecimals(_token);
        if (decimals >= 18) {
            amountOut = _amountIn / (10 ** (decimals - 18));
        } else {
            amountOut = _amountIn * (10 ** (18 - decimals));
        }
    }

    /**
     *  @dev
     *  @notice
     *  @param _id a
     *  @param _start a
     *  @param _end a
     */
    function _accrued(uint256 _id, uint256 _start, uint256 _end) private view returns (uint256 hxAccrued) {
        Stake memory stake = stakes[_id];

        if (currentDay() > stakes[_id].start) {
            uint256[] memory data = IHexToken(HX).dailyDataRange(_start, _end);

            uint256 length = data.length;
            for (uint256 i; i < length; ++i) {
                (uint256 payout, uint256 shares) = _decodeDailyData(data[i]);
                hxAccrued += (stake.shares * payout) / shares;
            }
        }
    }

    /**
     *  @dev
     *  @notice
     *  @param _id a
     */
    function _payout(uint256 _id) private view returns (uint256 hxFuturePayout) {
        (uint256 payout, uint256 shares,) = IHexToken(HX).dailyData(_lastDataDay());

        Stake memory stake = stakes[_id];
        hxFuturePayout = (stake.shares * payout * (stake.end - currentDay())) / shares;
    }

    /**
     *  @dev
     *  @notice
     */
    function _lastDataDay() private view returns (uint256 lastDay) {
        uint256[13] memory globalInfo = IHexToken(HX).globalInfo();
        lastDay = globalInfo[4] - 1;
    }

    /**
     *  @dev
     *  @notice
     *  @param _data a
     */
    function _decodeDailyData(uint256 _data) private pure returns (uint256 payout, uint256 shares) {
        payout = _data & HEARTS_MASK;
        shares = (_data >> HEARTS_UINT_SHIFT) & HEARTS_MASK;
    }

    /**
     *  @dev
     *  @notice
     *  @param _amount a
     */
    function _computeFee(uint256 _amount) private pure returns (uint256 fee) {
        fee = (_amount * FEE) / FIXED_POINT;
    }
}
