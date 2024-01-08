// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IHexOneVault} from "./interfaces/IHexOneVault.sol";
import {IHexOnePriceFeed} from "./interfaces/IHexOnePriceFeed.sol";
import {IHexOneToken} from "./interfaces/IHexOneToken.sol";
import {IHexToken} from "./interfaces/IHexToken.sol";

contract HexOneVault is IHexOneVault, Ownable {
    using SafeERC20 for IERC20;

    uint16 public constant GRACE_PERIOD = 7;
    uint16 public constant MIN_DURATION = 3652;
    uint16 public constant MAX_DURATION = 5555;

    address public immutable hexToken;
    address public immutable hexOneToken;

    address public hexOnePriceFeed;
    mapping(address => mapping(uint256 => DepositInfo)) public depositInfos;
    mapping(address => UserInfo) public userInfos;

    constructor(address _hexToken, address _hexOneToken, address _hexOnePriceFeed) Ownable(msg.sender) {
        hexToken = _hexToken;
        hexOneToken = _hexOneToken;
        hexOnePriceFeed = _hexOnePriceFeed;
    }

    function deposit(uint256 _amount, uint16 _duration) external returns (uint256) {
        if (_duration < MIN_DURATION || _duration > MAX_DURATION) revert InvalidDepositDuration();
        if (_amount == 0) revert ZeroDepositAmount();

        // transfer HEX from the sender to this contract
        IERC20(hexToken).safeTransferFrom(msg.sender, address(this), _amount);

        // stake HEX, get stakeId and get t-shares
        IHexToken(hexToken).stakeStart(_amount, _duration);
        uint256 stakeId = IHexToken(hexToken).stakeCount(address(this)) - 1;
        uint256 currHexDay = IHexToken(hexToken).currentDay();
        uint256 shares = _getShares(stakeId);

        // create a new deposit for the user
        DepositInfo storage depositInfo = depositInfos[msg.sender][stakeId];
        depositInfo.amount = _amount;
        depositInfo.shares = shares;
        depositInfo.depositHexDay = currHexDay;
        depositInfo.duration = _duration;
        depositInfo.active = true;

        // update user information for all user stakes
        UserInfo storage userInfo = userInfos[msg.sender];
        userInfo.totalAmount += _amount;
        userInfo.totalShares += shares;

        // emit deposited event
        emit Deposited(msg.sender, stakeId, _amount, currHexDay, _duration);

        // return the stakeId of the newly created deposit
        return stakeId;
    }

    function claim(uint256 _stakeId) external returns (uint256) {
        // revert if the deposit is not active
        DepositInfo storage depositInfo = depositInfos[msg.sender][_stakeId];
        if (!depositInfo.active) revert DepositNotActive();

        // revert if the t-shares are not yet mature therefore cant be claimed
        if (_beforeMaturity(depositInfo.depositHexDay, depositInfo.duration)) revert SharesNotYetMature();

        // revert if the position is liquidatable
        if (_depositLiquidatable(depositInfo.depositHexDay, depositInfo.duration)) revert PositionLiquidatable();

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
        uint256 hexAmount = _unstake(_stakeId);

        // transfer HEX + yield back to the depositor
        IERC20(hexToken).safeTransfer(msg.sender, 1);

        // emit claimed event
        emit Claimed(msg.sender, _stakeId, 1, hexOneBorrowed);

        // return amount of HEX claimed
        return hexAmount;
    }

    function borrow(uint256 _amount, uint256 _stakeId) external {
        // revert if the amount being borrowed is zero
        if (_amount == 0) revert InvalidBorrowAmount();

        // revert if the deposit is not active
        DepositInfo storage depositInfo = depositInfos[msg.sender][_stakeId];
        if (!depositInfo.active) revert DepositNotActive();

        // revert if the position is mature
        if (!_beforeMaturity(depositInfo.depositHexDay, depositInfo.duration)) revert CantBorrowFromMatureDeposit();

        // calculate max borrowable amount
        uint256 maxBorrowableAmount = _calculateBorrowableAmount(_stakeId);

        // if the amount the depositor is trying to borrow is bigger than the max borrowable amount revert.
        if (_amount > maxBorrowableAmount) revert BorrowAmountTooHigh();

        // update the total amount borrowed by the user accross all it's stakes
        userInfos[msg.sender].totalBorrowed += _amount;

        // update the amount borrowed by the user for the stakeId
        depositInfo.borrowed += _amount;

        // mint amount passed as an argument to the user
        IHexOneToken(hexOneToken).mint(msg.sender, _amount);

        // emit borrowed event
        emit Borrowed(msg.sender, _stakeId, _amount);
    }

    function liquidate(address _depositor, uint256 _stakeId) external returns (uint256) {
        // revert if the position is not active
        DepositInfo storage depositInfo = depositInfos[_depositor][_stakeId];
        if (!depositInfo.active) revert DepositNotActive();

        // revert if the position is not liquidatable
        if (!_depositLiquidatable(depositInfo.depositHexDay, depositInfo.duration)) revert PositionNotLiquidatable();

        // if there is debt the sender must pay it in order to liquidate the deposit
        uint256 hexOneRepaid = depositInfo.borrowed;
        if (hexOneRepaid > 0) {
            IHexOneToken(hexOneToken).burn(msg.sender, hexOneRepaid);
        }

        // update information for all user stakes
        UserInfo storage userInfo = userInfos[_depositor];
        userInfo.totalAmount -= depositInfo.amount;
        userInfo.totalBorrowed -= hexOneRepaid;
        userInfo.totalShares -= depositInfo.shares;

        // update information of the deposit being liquidated
        depositInfo.amount = 0;
        depositInfo.shares = 0;
        depositInfo.borrowed = 0;
        depositInfo.active = false;

        // unstake HEX + yield
        uint256 hexAmount = _unstake(_stakeId);

        // transfer HEX + yield to the sender
        IERC20(hexToken).safeTransfer(msg.sender, hexAmount);

        // emit the liquidation event
        emit Liquidated(msg.sender, _depositor, _stakeId, hexAmount, hexOneRepaid);

        // return the amount of HEX + yield claimed
        return hexAmount;
    }

    function _getHexPrice(uint256 _amountIn) internal returns (uint256) {
        try IHexOnePriceFeed(hexOnePriceFeed).consult(hexToken, _amountIn) returns (uint256 amountOut) {
            if (amountOut == 0) revert InvalidQuote();
            return amountOut;
        } catch (bytes memory reason) {
            bytes4 err = abi.decode(reason, (bytes4));
            if (err == IHexOnePriceFeed.PriceTooStale.selector) {
                IHexOnePriceFeed(hexOnePriceFeed).update();
                return IHexOnePriceFeed(hexOnePriceFeed).consult(hexToken, _amountIn);
            } else {
                revert PriceConsultationFailed();
            }
        }
    }

    function _unstake(uint256 _stakeId) internal returns (uint256) {
        IHexToken.StakeStore memory stakeStore = IHexToken(hexToken).stakeLists(address(this), _stakeId);
        uint256 balanceBefore = IERC20(hexToken).balanceOf(address(this));
        IHexToken(hexToken).stakeEnd(_stakeId, stakeStore.stakeId);
        uint256 balanceAfter = IERC20(hexToken).balanceOf(address(this));
        return balanceAfter - balanceBefore;
    }

    function _calculateBorrowableAmount(uint256 _stakeId) internal returns (uint256) {
        DepositInfo memory depositInfo = depositInfos[msg.sender][_stakeId];
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
