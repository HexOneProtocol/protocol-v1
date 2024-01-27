// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {LibString} from "solady/utils/LibString.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IHexOneVault} from "./interfaces/IHexOneVault.sol";
import {IHexOnePriceFeed} from "./interfaces/IHexOnePriceFeed.sol";
import {IHexOneToken} from "./interfaces/IHexOneToken.sol";
import {IHexToken} from "./interfaces/IHexToken.sol";
import {IHexOneStaking} from "./interfaces/IHexOneStaking.sol";

contract HexOneVault is IHexOneVault, Ownable {
    using SafeERC20 for IERC20;

    uint16 public constant GRACE_PERIOD = 7;
    uint16 public constant MIN_DURATION = 3652;
    uint16 public constant MAX_DURATION = 5555;
    uint16 public constant FIXED_POINT = 1000;
    uint16 public constant DEPOSIT_FEE = 50;

    address public immutable hexToken;
    address public immutable daiToken;
    address public immutable hexOneToken;

    mapping(address => mapping(uint256 => DepositInfo)) public depositInfos;
    mapping(address => UserInfo) public userInfos;
    address public hexOnePriceFeed;
    address public hexOneStaking;
    address public hexOneBootstrap;
    bool public sacrificeFinished;

    modifier onlyAfterSacrifice() {
        if (!sacrificeFinished) revert SacrificeHasNotFinished();
        _;
    }

    modifier onlyHexOneBootstrap() {
        if (msg.sender != hexOneBootstrap) revert NotHexOneBootstrap(msg.sender);
        _;
    }

    constructor(address _hexToken, address _daiToken, address _hexOneToken) Ownable(msg.sender) {
        if (_hexToken == address(0)) revert InvalidAddress(_hexToken);
        if (_daiToken == address(0)) revert InvalidAddress(_daiToken);
        if (_hexOneToken == address(0)) revert InvalidAddress(_hexOneToken);

        hexToken = _hexToken;
        daiToken = _daiToken;
        hexOneToken = _hexOneToken;
    }

    function setSacrificeStatus() external onlyHexOneBootstrap {
        if (sacrificeFinished) revert VaultAlreadyActive();
        sacrificeFinished = true;
        emit VaultActivated(block.timestamp);
    }

    function setBaseData(address _hexOnePriceFeed, address _hexOneStaking, address _hexOneBootstrap)
        external
        onlyOwner
    {
        if (_hexOnePriceFeed == address(0)) revert InvalidAddress(_hexOnePriceFeed);
        if (_hexOneStaking == address(0)) revert InvalidAddress(_hexOneStaking);
        if (_hexOneBootstrap == address(0)) revert InvalidAddress(_hexOneBootstrap);

        hexOnePriceFeed = _hexOnePriceFeed;
        hexOneStaking = _hexOneStaking;
        hexOneBootstrap = _hexOneBootstrap;
    }

    function deposit(uint256 _amount, uint16 _duration)
        external
        onlyAfterSacrifice
        returns (uint256 hexOneMinted, uint256 stakeId)
    {
        if (_duration < MIN_DURATION || _duration > MAX_DURATION) revert InvalidDepositDuration(_duration);
        if (_amount == 0) revert InvalidDepositAmount(_amount);

        return _deposit(msg.sender, _amount, _duration);
    }

    function deposit(address _depositor, uint256 _amount, uint16 _duration)
        external
        onlyAfterSacrifice
        onlyHexOneBootstrap
        returns (uint256 hexOneMinted, uint256 stakeId)
    {
        if (_duration < MIN_DURATION || _duration > MAX_DURATION) revert InvalidDepositDuration(_duration);
        if (_amount == 0) revert InvalidDepositAmount(_amount);
        if (_depositor == address(0)) revert InvalidDepositor(_depositor);

        return _deposit(_depositor, _amount, _duration);
    }

    function claim(uint256 _stakeId) external onlyAfterSacrifice returns (uint256 hexClaimed) {
        // revert if the deposit is not active
        DepositInfo storage depositInfo = depositInfos[msg.sender][_stakeId];
        if (!depositInfo.active) revert DepositNotActive(msg.sender, _stakeId);

        // revert if the t-shares are not yet mature therefore cant be claimed
        if (_beforeMaturity(depositInfo.depositHexDay, depositInfo.duration)) {
            revert SharesNotYetMature(msg.sender, _stakeId);
        }

        // revert if the deposit is liquidatable
        if (_depositLiquidatable(depositInfo.depositHexDay, depositInfo.duration)) {
            revert DepositLiquidatable(msg.sender, _stakeId);
        }

        // payback the HEX1 borrowed
        uint256 hexOneBorrowed = depositInfo.borrowed;
        if (hexOneBorrowed > 0) {
            IHexOneToken(hexOneToken).burn(msg.sender, hexOneBorrowed);
        }

        // update user information for all user stakes
        UserInfo storage userInfo = userInfos[msg.sender];
        userInfo.totalAmount -= depositInfo.amount;
        userInfo.totalShares -= depositInfo.shares;
        userInfo.totalBorrowed -= hexOneBorrowed;

        // update the user deposit being claimed
        depositInfo.amount = 0;
        depositInfo.shares = 0;
        depositInfo.borrowed = 0;
        depositInfo.active = false;

        // unstake HEX + yield
        hexClaimed = _unstake(_stakeId);

        // transfer HEX + yield back to the depositor
        IERC20(hexToken).safeTransfer(msg.sender, hexClaimed);

        // emit claimed event
        emit Claimed(msg.sender, _stakeId, hexClaimed, hexOneBorrowed);
    }

    function borrow(uint256 _amount, uint256 _stakeId) external onlyAfterSacrifice {
        // revert if the amount being borrowed is zero
        if (_amount == 0) revert InvalidBorrowAmount(_amount);

        // revert if the deposit is not active
        DepositInfo storage depositInfo = depositInfos[msg.sender][_stakeId];
        if (!depositInfo.active) revert DepositNotActive(msg.sender, _stakeId);

        // revert if the deposit is mature
        if (!_beforeMaturity(depositInfo.depositHexDay, depositInfo.duration)) {
            revert CantBorrowFromMatureDeposit(msg.sender, _stakeId);
        }

        // calculate max borrowable amount
        uint256 maxBorrowableAmount = _calculateBorrowableAmount(msg.sender, _stakeId);

        // if the amount the depositor is trying to borrow is bigger than the max borrowable amount revert.
        if (_amount > maxBorrowableAmount) revert BorrowAmountTooHigh(_amount);

        // update the total amount borrowed by the user accross all it's stakes
        userInfos[msg.sender].totalBorrowed += _amount;

        // update the amount borrowed by the user for the stakeId
        depositInfo.borrowed += _amount;

        // mint amount passed as an argument to the user
        IHexOneToken(hexOneToken).mint(msg.sender, _amount);

        // emit borrowed event
        emit Borrowed(msg.sender, _stakeId, _amount);
    }

    function liquidate(address _depositor, uint256 _stakeId) external onlyAfterSacrifice returns (uint256 hexAmount) {
        // revert if the deposit is not active
        DepositInfo storage depositInfo = depositInfos[_depositor][_stakeId];
        if (!depositInfo.active) revert DepositNotActive(_depositor, _stakeId);

        // revert if the deposit is not liquidatable
        if (!_depositLiquidatable(depositInfo.depositHexDay, depositInfo.duration)) {
            revert DepositNotLiquidatable(_depositor, _stakeId);
        }

        // update information for all user stakes
        UserInfo storage userInfo = userInfos[_depositor];
        userInfo.totalAmount -= depositInfo.amount;
        userInfo.totalBorrowed -= depositInfo.borrowed;
        userInfo.totalShares -= depositInfo.shares;

        // update information of the deposit being liquidated
        depositInfo.amount = 0;
        depositInfo.shares = 0;
        depositInfo.borrowed = 0;
        depositInfo.active = false;

        // if there is debt the sender must pay it in order to liquidate the deposit
        uint256 hexOneRepaid = depositInfo.borrowed;
        if (hexOneRepaid > 0) {
            IHexOneToken(hexOneToken).burn(msg.sender, hexOneRepaid);
        }

        // unstake HEX + yield
        hexAmount = _unstake(_stakeId);

        // transfer HEX + yield to the sender
        IERC20(hexToken).safeTransfer(msg.sender, hexAmount);

        emit Liquidated(msg.sender, _depositor, _stakeId, hexAmount, hexOneRepaid);
    }

    function _deposit(address _depositor, uint256 _amount, uint16 _duration)
        internal
        returns (uint256 hexOneMinted, uint256 stakeId)
    {
        // transfer HEX from either an EOA or the bootstrap to this contract
        IERC20(hexToken).safeTransferFrom(msg.sender, address(this), _amount);

        // calculate the fee and the real amount being deposited
        uint256 feeAmount = (_amount * DEPOSIT_FEE) / FIXED_POINT;
        uint256 realAmount = _amount - feeAmount;

        // stake HEX, get stakeId
        IHexToken(hexToken).stakeStart(realAmount, _duration);
        stakeId = IHexToken(hexToken).stakeCount(address(this)) - 1;

        // get the current HEX day, and t-shares of the stake
        uint256 currentHexDay = IHexToken(hexToken).currentDay();
        uint256 shares = _getShares(stakeId);

        // update the user deposit
        DepositInfo storage depositInfo = depositInfos[_depositor][stakeId];
        depositInfo.amount = realAmount;
        depositInfo.shares = shares;
        depositInfo.depositHexDay = currentHexDay;
        depositInfo.duration = _duration;
        depositInfo.active = true;

        // update user information for all its stakes
        UserInfo storage userInfo = userInfos[_depositor];
        userInfo.totalAmount += realAmount;
        userInfo.totalShares += shares;

        // calculate the max amount borrowable
        hexOneMinted = _calculateBorrowableAmount(_depositor, stakeId);
        depositInfo.borrowed += hexOneMinted;
        userInfo.totalBorrowed += hexOneMinted;

        // approve the staking contract to spend the feeAmount
        IERC20(hexToken).approve(hexOneStaking, feeAmount);

        // send the fee to the staking contract to be distributed as a reward
        IHexOneStaking(hexOneStaking).purchase(hexToken, feeAmount);

        // mint the max amount possible to the sender based on the HEX price
        IHexOneToken(hexOneToken).mint(_depositor, hexOneMinted);

        emit Deposited(_depositor, stakeId, hexOneMinted, realAmount, currentHexDay, _duration);
    }

    function _getHexPrice(uint256 _amountIn) internal returns (uint256) {
        try IHexOnePriceFeed(hexOnePriceFeed).consult(hexToken, _amountIn, daiToken) returns (uint256 amountOut) {
            if (amountOut == 0) revert PriceConsultationFailedInvalidQuote(amountOut);
            return amountOut;
        } catch (bytes memory reason) {
            bytes4 err = bytes4(reason);
            if (err == IHexOnePriceFeed.PriceTooStale.selector) {
                IHexOnePriceFeed(hexOnePriceFeed).update(hexToken, daiToken);
                return IHexOnePriceFeed(hexOnePriceFeed).consult(hexToken, _amountIn, daiToken);
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

    function _unstake(uint256 _stakeId) internal returns (uint256) {
        IHexToken.StakeStore memory stakeStore = IHexToken(hexToken).stakeLists(address(this), _stakeId);
        uint256 balanceBefore = IERC20(hexToken).balanceOf(address(this));
        IHexToken(hexToken).stakeEnd(_stakeId, stakeStore.stakeId);
        uint256 balanceAfter = IERC20(hexToken).balanceOf(address(this));
        return balanceAfter - balanceBefore;
    }

    function _calculateBorrowableAmount(address _depositor, uint256 _stakeId) internal returns (uint256) {
        DepositInfo memory depositInfo = depositInfos[_depositor][_stakeId];
        uint256 hexOneBorrowed = depositInfo.borrowed;
        uint256 hexStakePrice = _getHexPrice(depositInfo.amount);

        if (hexStakePrice > hexOneBorrowed) {
            return hexStakePrice - hexOneBorrowed;
        } else {
            return 0;
        }
    }

    function _getShares(uint256 _stakeId) internal view returns (uint256) {
        IHexToken.StakeStore memory stakeStore = IHexToken(hexToken).stakeLists(address(this), _stakeId);
        return stakeStore.stakeShares;
    }

    function _beforeMaturity(uint256 _depositHexDay, uint16 _duration) internal view returns (bool) {
        uint256 currHexDay = IHexToken(hexToken).currentDay();
        return currHexDay < (_depositHexDay + _duration);
    }

    function _depositLiquidatable(uint256 _depositHexDay, uint16 _duration) internal view returns (bool) {
        uint256 currHexDay = IHexToken(hexToken).currentDay();
        return currHexDay > (_depositHexDay + _duration + GRACE_PERIOD);
    }
}
