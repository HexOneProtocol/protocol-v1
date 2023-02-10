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

    /// @notice Minimum stake duration. (days)
    uint256 public MIN_DURATION;

    /// @notice Maximum stake duration. (days)
    uint256 public MAX_DURATION;

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
        address[] memory _vaults,
        uint256 _minDuration,
        uint256 _maxDuration
    ) {
        require (_hexOneToken != address(0), "zero $HEX1 token address");
        require (_maxDuration > _minDuration, "max Duration is less min duration");
        MIN_DURATION = _minDuration;
        MAX_DURATION = _maxDuration;
        hexOneToken = _hexOneToken;
        _setVaults(_vaults, true);
    }

    /// @inheritdoc IHexOneProtocol
    function setMinDuration(uint256 _minDuration) external override onlyOwner {
        require (_minDuration < MAX_DURATION, "minDuration is bigger than maxDuration");
        MIN_DURATION = _minDuration;
    }

    /// @inheritdoc IHexOneProtocol
    function setMaxDuration(uint256 _maxDuration) external override onlyOwner {
        require (_maxDuration > MIN_DURATION, "maxDuration is less than minDuration");
        MAX_DURATION = _maxDuration;
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
        require (allowedTokens.contains(_token), "invalid token");
        require (_amount > 0, "invalid amount");
        require (_duration >= MIN_DURATION && _duration <= MAX_DURATION, "invalid duration");

        IHexOneVault hexOneVault = IHexOneVault(vaultInfos[_token]);
        IERC20(_token).safeTransferFrom(sender, address(this), _amount);
        IERC20(_token).safeApprove(address(hexOneVault), _amount);
        uint256 mintAmount = hexOneVault.depositCollateral(
            sender, 
            _amount, 
            _duration, 
            _duration, 
            _isCommit
        );

        require (mintAmount > 0, "depositing amount is too small to mint $HEX1");
        if (!depositedTokenInfos[sender].contains(_token)) {
            depositedTokenInfos[sender].add(_token);
        }
        IHexOneToken(hexOneToken).mintToken(mintAmount, sender);

        emit HexOneMint(sender, mintAmount);
    }

    /// @inheritdoc IHexOneProtocol
    function claimCollateral(address _token, uint256 _depositId) external override {
        address sender = msg.sender;
        require (sender != address(0), "zero caller address");
        require (allowedTokens.contains(_token), "not allowed token");
        require (depositedTokenInfos[sender].contains(_token), "not deposited token");

        (
            uint256 mintAmount, 
            uint256 burnAmount
        ) = IHexOneVault(vaultInfos[_token]).claimCollateral(sender, _depositId);

        IHexOneToken(hexOneToken).burnToken(burnAmount, sender);
        if (mintAmount > 0) {
            IHexOneToken(hexOneToken).mintToken(mintAmount, sender);
        }
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