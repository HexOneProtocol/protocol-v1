// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {console2 as console} from "forge-std/Test.sol";

library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

contract HexTokenMock is ERC20 {
    using SafeMath for uint256;

    struct StakeStore {
        uint40 stakeId;
        uint72 stakedHearts;
        uint72 stakeShares;
        uint16 lockedDay;
        uint16 stakedDays;
        uint16 unlockedDay;
        bool isAutoStake;
    }

    uint256 private nonce;
    uint256 private launch;

    mapping(address => StakeStore[]) public stakeLists;

    event StakeStart(uint256 data, address indexed stakerAddr, uint40 indexed stakeId);

    constructor() ERC20("Hex Token Mock", "HEX") {
        launch = block.timestamp;
    }

    function decimals() public pure override returns (uint8) {
        return 8;
    }

    function currentDay() public view returns (uint256) {
        return ((block.timestamp - launch) / 1 days) + 1;
    }

    function stakeStart(uint256 newStakedHearts, uint256 newStakedDays) external {
        require(balanceOf(msg.sender) >= newStakedHearts, "Insufficient balance");
        _burn(msg.sender, newStakedHearts);

        StakeStore memory newStake;

        uint40 stakeId =
            uint40(bytes5(keccak256(abi.encodePacked(msg.sender, newStakedHearts, newStakedDays, nonce++))));

        newStake.stakeId = stakeId;
        uint256 toStakeHearts = newStakedHearts.mul(newStakedDays.mul(2).add(100)).div(100);
        require(toStakeHearts <= type(uint72).max, "Overflow");
        newStake.stakedHearts = uint72(toStakeHearts);

        stakeLists[msg.sender].push(newStake);

        emit StakeStart(
            uint256(uint40(block.timestamp)) | (uint256(uint72(newStakedHearts)) << 40)
                | (uint256(uint72(toStakeHearts)) << 112) | (uint256(uint16(newStakedDays)) << 184),
            msg.sender,
            stakeId
        );
    }

    function _stakeRemove(StakeStore[] storage stakeList, uint256 stakeIndex) internal {
        uint256 lastIndex = stakeList.length - 1;

        if (stakeIndex < lastIndex) stakeList[stakeIndex] = stakeList[lastIndex];
        require(stakeIndex <= lastIndex, "something failed");

        stakeList.pop();
    }

    function stakeEnd(uint256 stakeIndex, uint40 stakeIdParam) external {
        require(stakeLists[msg.sender].length > stakeIndex, "stakeIndex out of bounds");
        require(stakeLists[msg.sender][stakeIndex].stakeId == stakeIdParam, "Invalid stake parameters");

        _mint(msg.sender, stakeLists[msg.sender][stakeIndex].stakedHearts);

        _stakeRemove(stakeLists[msg.sender], stakeIndex);
    }

    function stakeCount(address owner) external view returns (uint256) {
        return stakeLists[owner].length;
    }

    function mint(address receiver, uint256 amount) external {
        _mint(receiver, amount);
    }
}
