// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/IHexOneProtocol.sol";
import "./interfaces/IHexOneBootstrap.sol";
import "./interfaces/IHexOneVault.sol";
import "./interfaces/IHexOneEscrow.sol";
import "./interfaces/IHexOnePriceFeed.sol";

contract HexOneEscrow is OwnableUpgradeable, IHexOneEscrow {
    using SafeERC20 for IERC20;

    /// @dev The address of HexOneBootstrap contract.
    address public hexOneBootstrap;

    /// @dev The address of hex token.
    address public hexToken;

    /// @dev The address of $HEX1 token.
    address public hexOneToken;

    /// @dev The address of HexOneProtocol.
    address public hexOneProtocol;

    address public usdToken;

    /// @dev The address of HexOnePriceFeed.
    address public hexOnePriceFeed;

    uint256 public borrowedAmount;

    uint256 public stakedHexAmount;

    /// @dev Flag to show hex token already deposited or not.
    bool public collateralDeposited;

    modifier onlyAfterSacrifice() {
        require(
            IHexOneBootstrap(hexOneBootstrap).afterSacrificeDuration(),
            "only after sacrifice"
        );
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _hexOneBootstrap,
        address _hexToken,
        address _hexOneToken,
        address _usdToken,
        address _hexOneProtocol,
        address _hexOnePriceFeed
    ) public initializer {
        require(
            _hexOneBootstrap != address(0),
            "zero HexOneBootstrap contract address"
        );
        require(_hexToken != address(0), "zero Hex token address");
        require(_hexOneToken != address(0), "zero HexOne token address");
        require(_hexOneProtocol != address(0), "zero HexOneProtocol address");
        require(_hexOnePriceFeed != address(0), "zero HexOnePriceFeed address");

        hexOneBootstrap = _hexOneBootstrap;
        hexToken = _hexToken;
        usdToken = _usdToken;
        hexOneToken = _hexOneToken;
        hexOneProtocol = _hexOneProtocol;
        hexOnePriceFeed = _hexOnePriceFeed;
        __Ownable_init();
    }

    /// @inheritdoc IHexOneEscrow
    function balanceOfHex() public view override returns (uint256) {
        return IERC20(hexToken).balanceOf(address(this));
    }

    /// @inheritdoc IHexOneEscrow
    function depositCollateralToHexOneProtocol(
        uint16 _duration
    ) external override onlyAfterSacrifice onlyOwner {
        uint256 collateralAmount = balanceOfHex();
        require(collateralAmount > 0, "no collateral to deposit");
        stakedHexAmount = collateralAmount;

        IERC20(hexToken).approve(hexOneProtocol, collateralAmount);
        IHexOneProtocol(hexOneProtocol).depositCollateral(
            hexToken,
            collateralAmount,
            _duration,
            address(this)
        );

        collateralDeposited = true;

        _distributeHexOne();
    }

    /// @inheritdoc IHexOneEscrow
    function reDepositCollateral() external override onlyAfterSacrifice {
        require(collateralDeposited, "collateral not deposited yet");

        IHexOneVault hexOneVault = IHexOneVault(
            IHexOneProtocol(hexOneProtocol).getVaultAddress(hexToken)
        );
        IHexOneVault.DepositShowInfo[] memory depositInfos = hexOneVault
            .getUserInfos(address(this));
        require(depositInfos.length > 0, "not deposit pool");
        uint256 depositId = depositInfos[0].depositId;
        stakedHexAmount = IHexOneProtocol(hexOneProtocol).claimCollateral(
            hexToken,
            depositId
        );

        _distributeHexOne();
    }

    /// @inheritdoc IHexOneEscrow
    function distributeHexOne() external onlyAfterSacrifice {
        _distributeHexOne();
    }

    /// @inheritdoc IHexOneEscrow
    function borrowHexOne(uint256 curPrice) external override {
        address sender = msg.sender;
        IHexOneVault hexOneVault = IHexOneVault(
            IHexOneProtocol(hexOneProtocol).getVaultAddress(hexToken)
        );
        IHexOneVault.DepositShowInfo[] memory depositInfos = hexOneVault
            .getUserInfos(address(this));
        require(depositInfos.length > 0, "not deposit pool");
        uint256 depositId = depositInfos[0].depositId;
        if (curPrice > depositInfos[0].initialHexPrice) {
            uint256 _amount = 10 ** 8 * (curPrice - depositInfos[0].initialHexPrice) / IHexOnePriceFeed(hexOnePriceFeed).getHexTokenPrice(10 ** 8);
            IHexOneProtocol(hexOneProtocol).borrowHexOne(
                hexToken,
                depositId,
                _amount
            );
        }
    }

    /// @inheritdoc IHexOneEscrow
    function getOverview(
        address _user
    ) external view override returns (EscrowOverview memory) {
        EscrowOverview memory overview;
        if (collateralDeposited) {
            IHexOneVault hexOneVault = IHexOneVault(
                IHexOneProtocol(hexOneProtocol).getVaultAddress(hexToken)
            );
            IHexOneVault.DepositShowInfo[] memory showInfo = hexOneVault
                .getUserInfos(address(this));
            IHexOneVault.DepositShowInfo memory singleInfo = showInfo[0];
            uint256 totalAmount = IHexOneBootstrap(hexOneBootstrap)
                .HEXITAmountForSacrifice();
            uint256 participantAmount = IHexOneBootstrap(hexOneBootstrap)
                .userRewardsForSacrifice(_user);
            overview = EscrowOverview({
                totalUSDValue: IHexOnePriceFeed(hexOnePriceFeed)
                    .getHexTokenPrice(singleInfo.depositAmount),
                startTime: singleInfo.lockedHexDay,
                endTime: singleInfo.endHexDay,
                curDay: singleInfo.curHexDay,
                hexAmount: singleInfo.depositAmount,
                effectiveAmount: singleInfo.effectiveAmount,
                borrowedAmount: singleInfo.mintAmount,
                initUSDValue: singleInfo.initialHexPrice,
                shareOfPool: uint16((participantAmount * 100) / totalAmount)
            });
        }

        return overview;
    }

    /// @notice Distribute $HEX1 token to sacrifice participants.
    /// @dev the distribute amount is based on amount of sacrifice that participant did.
    function _distributeHexOne() internal {
        uint256 hexOneBalance = IERC20(hexOneToken).balanceOf(address(this));
        borrowedAmount += hexOneBalance;
        if (hexOneBalance == 0) return;

        address[] memory participants = IHexOneBootstrap(hexOneBootstrap)
            .getSacrificeParticipants();
        uint256 length = participants.length;
        require(length > 0, "no sacrifice participants");
        uint256 totalAmount = IHexOneBootstrap(hexOneBootstrap)
            .HEXITAmountForSacrifice();
        for (uint256 i = 0; i < length; i++) {
            address participant = participants[i];
            uint256 participantAmount = IHexOneBootstrap(hexOneBootstrap)
                .userRewardsForSacrifice(participant);
            uint256 rewards = (hexOneBalance * participantAmount) / totalAmount;
            if (rewards > 0) {
                IERC20(hexOneToken).safeTransfer(participant, rewards);
            }
        }
    }

    uint256[100] private __gap;
}
