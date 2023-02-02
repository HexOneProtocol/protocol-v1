// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./interfaces/IHexOneProtocol.sol";
import "./interfaces/IHexOneVault.sol";
import "./interfaces/IHexOneToken.sol";

contract HexOneProtocol is Ownable, IHexOneProtocol {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    EnumerableSet.AddressSet private vaults;

    /// @notice Allowed token info based on allowed vaults.    
    EnumerableSet.AddressSet private allowedTokens;

    /// @notice The address of $HEX1.
    address public hexOneToken;

    /// @dev The address to burn tokens.
    address constant DEAD = 0x000000000000000000000000000000000000dEaD;

    /// @notice Show vault address from token address.
    mapping(address => address) private vaultInfos;

    /// @notice Show deposited token addresses by user.
    mapping(address => EnumerableSet.AddressSet) private depositedTokenInfos;

    constructor (
        address _hexOneToken,
        address[] memory _vaults
    ) {
        require (_hexOneToken != address(0), "zero $HEX1 token address");
        hexOneToken = _hexOneToken;
        _setVaults(_vaults, true);
    }

    /// @inheritdoc IHexOneProtocol
    function setVaults(address[] memory _vaults, bool _add) external onlyOwner override {
        _setVaults(_vaults, _add);
    }

    /// @inheritdoc IHexOneProtocol
    function depositCollateral(
        address _token, 
        uint256 _amount, 
        uint16 _duration,
        bool _isCommit
    ) external override {
        address sender = msg.sender;
        require (sender != address(0), "zero address caller");
        require (_token != address(0), "zero token address");
        require (allowedTokens.contains(_token), "not allowed token");
        require (_amount > 0, "invalid amount");

        IHexOneVault hexOnVault = IHexOneVault(vaultInfos[_token]);
        uint256 maturity = _duration * 1 days;
        uint256 shareAmount = hexOnVault.depositCollateral(
            sender, 
            _amount, 
            maturity, 
            maturity, 
            _isCommit
        );

        require (shareAmount > 0, "depositing amount is too small to mint $HEX1");
        if (!depositedTokenInfos[sender].contains(_token)) {
            depositedTokenInfos[sender].add(_token);
        }
        IHexOneToken(hexOneToken).mintToken(shareAmount, sender);

        emit HexOneMint(sender, shareAmount);
    }

    /// @inheritdoc IHexOneProtocol
    function claimCollateral(address _token, uint256 _depositId) external override {
        address sender = msg.sender;
        require (sender != address(0), "zero caller address");
        require (allowedTokens.contains(_token), "not allowed token");
        (
            uint256 mintAmount, 
            uint256 burnAmount,
            bool burnMode
        ) = IHexOneVault(vaultInfos[_token]).claimCollateral(sender, _depositId);

        IERC20(hexOneToken).safeTransferFrom(sender, DEAD, burnAmount);
        if (!burnMode && mintAmount > 0) {
            IHexOneToken(hexOneToken).mintToken(mintAmount, sender);
        }
    }

    /// @inheritdoc IHexOneProtocol
    function getShareBalance(address _user, address _token) external view override returns (uint256 shareBal) {
        require (_user != address(0), "zero user address");
        require (allowedTokens.contains(_token), "not allowed token");
        (shareBal, ) = IHexOneVault(vaultInfos[_token]).balanceOf(_user);
    }

    /// @inheritdoc IHexOneProtocol
    function getDepositInfo(address _user) external view override returns (DepositInfo memory) {
        require (_user != address(0), "zero user address");
        DepositInfo memory depositInfo;
        depositInfo.depositedTokens = depositedTokenInfos[_user].values();
        if (depositInfo.depositedTokens.length == 0) {
            return depositInfo;
        }

        for (uint256 i = 0; i < depositInfo.depositedTokens.length; i ++) {
            address token = depositInfo.depositedTokens[i];
            IHexOneVault vault = IHexOneVault(vaultInfos[token]);
            (uint256 shareBal, uint256 depositedBal) = vault.balanceOf(_user);
            depositInfo.shareAmounts[i] = shareBal;
            depositInfo.depositedAmounts[i] = depositedBal;
            uint256[] memory claimableIds;
            (
                shareBal, 
                depositedBal, 
                claimableIds
            ) = vault.claimableAmount(_user);

            depositInfo.claimableShareAmount[i] = shareBal;
            depositInfo.claimableTokenAmount[i] = depositedBal;
            depositInfo.claimableIds[i] = claimableIds;
        }

        return depositInfo;
    }

    /// @notice Add/Remove vault and base token addresses.
    function _setVaults(address[] memory _vaults, bool _add) internal {
        uint256 length = _vaults.length;
        require (length > 0, "invalid vaults array");
        for (uint256 i = 0; i < length; i ++) {
            address vault = _vaults[i];
            address token = IHexOneVault(vault).baseToken();
            require (
                (_add && !vaults.contains(vault)) ||
                (!_add && vaults.contains(vault)), 
                "already set"
            );
            if (_add) { 
                vaults.add(vault); 
                require (!allowedTokens.contains(token), "already exist vault has same base token");
                allowedTokens.add(token);
                vaultInfos[token] = vault;
            } else { 
                vaults.remove(vault); 
                allowedTokens.remove(token);
                vaultInfos[token] = address(0);
            }
        }
    }
}