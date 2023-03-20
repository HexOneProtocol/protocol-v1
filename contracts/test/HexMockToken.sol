// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../interfaces/IHexToken.sol";

contract HexMockToken is ERC20, IHexToken {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    uint256 public mintAmount = 1_000 * 1e8;
    uint256 public launchedTime;
    uint256 public stakeId;
    uint72 private basicPayout =  6530840230235970;

    GlobalsStore private globalInfo;
    mapping(address => EnumerableSet.UintSet) private stakedIds;
    mapping(uint256 => StakeStore) private stakeInfo;

    constructor () ERC20("Mock Hex", "HEX") {
        launchedTime = block.timestamp;
        stakeId = 1;
        _mint(msg.sender, 300000 * 1e8);

        globalInfo.shareRate = 265748;
    }

    function decimals() public view virtual override returns (uint8) {
        return 8;
    }

    function globals() external view returns (GlobalsStore memory) {
        return globalInfo;
    }

    function emergencyStakeStart(
        uint256 newStakedHearts,
        uint256 newStakedDays,
        uint256 customStakedDay,
        address staker
    ) external {
        uint256 curStakeId = stakeId;
        
        stakedIds[staker].add(curStakeId);
        stakeInfo[curStakeId] = StakeStore(
            uint40(curStakeId),
            uint72(newStakedHearts),
            _calcShareRate(newStakedHearts),
            uint16(customStakedDay),
            uint16(newStakedDays),
            uint16(customStakedDay) + uint16(newStakedDays),
            false
        );

        _burn(msg.sender, newStakedHearts);

        stakeId ++;
    }

    function stakeStart(
        uint256 newStakedHearts,
        uint256 newStakedDays
    ) external {
        address sender = msg.sender;
        uint256 curStakeId = stakeId;
        
        stakedIds[sender].add(curStakeId);
        uint256 curDay = currentDay();
        stakeInfo[curStakeId] = StakeStore(
            uint40(curStakeId),
            uint72(newStakedHearts),
            _calcShareRate(newStakedHearts),
            uint16(curDay),
            uint16(newStakedDays),
            uint16(curDay) + uint16(newStakedDays),
            false
        );

        _burn(sender, newStakedHearts);

        stakeId ++;
    }

    function stakeEnd(uint256 stakeIndex, uint40 stakeIdParam) external {
        address sender = msg.sender;
        uint256 userStakeId = stakedIds[sender].at(stakeIndex);
        require (userStakeId == stakeIdParam, "wrong stakeIndex");

        StakeStore memory data = stakeInfo[stakeIdParam];
        uint256 rewardsAmount = uint256(data.stakeShares) * uint256(basicPayout) / 1e15;
        _mint(sender, rewardsAmount + data.stakedHearts);

        delete stakeInfo[stakeIdParam];
    }

    function dailyData(uint256 dayIndex) external view returns (
        uint72 dayPayoutTotal,
        uint72 dayStakeSharesTotal,
        uint56 dayUnclaimedSatoshisTotal
    ) {
        return (basicPayout, 0, 0);
    }

    function stakeCount(address stakerAddr)
        external
        view
        returns (uint256)
    {
        return stakedIds[stakerAddr].length();
    }

    function stakeLists(
        address stakerAddr, 
        uint256 stakeIndex
    ) external view returns (StakeStore memory) {
        require (stakeIndex < stakedIds[stakerAddr].length(), "invalid stakeIndex");
        uint256 stakeId_ = stakedIds[stakerAddr].at(stakeIndex);
        return stakeInfo[stakeId_];
    }

    function currentDay() public view returns (uint256) {
        return ((block.timestamp - launchedTime) / 1 days) + 1;
    }

    function mint() external {
        _mint(msg.sender, mintAmount);
    }

    function _calcShareRate(
        uint256 stakedHearts
    ) internal view returns (uint72) {
        return uint72(stakedHearts * 10 / globalInfo.shareRate);
    }
}