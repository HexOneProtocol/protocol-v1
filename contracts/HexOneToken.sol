// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IHexOneToken.sol";

contract HexOneToken is ERC20, Ownable, IHexOneToken {
    address public admin;
    address public constant deadWallet =
        0x000000000000000000000000000000000000dEaD;

    modifier onlyHexOneProtocol() {
        require(msg.sender == admin, "only Admin");
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {}

    /// @inheritdoc IHexOneToken
    function setAdmin(address _admin) external override onlyOwner {
        require(_admin != address(0), "zero admin address");
        admin = _admin;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /// @inheritdoc IHexOneToken
    function mintToken(
        uint256 _amount,
        address _recipient
    ) external override onlyHexOneProtocol {
        require(_recipient != address(0), "zero recipient address");
        require(_amount > 0, "zero mint token amount");

        _mint(_recipient, _amount);
    }

    /// @inheritdoc IHexOneToken
    function burnToken(
        uint256 _amount,
        address _account
    ) external override onlyHexOneProtocol {
        require(_account != address(0), "zero account address");
        require(_amount > 0, "zero burn token amount");
        _burn(_account, _amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        require(
            from != address(0) && from != deadWallet,
            "Transfer from invalid address"
        );
        require(
            to != address(0) && to != deadWallet,
            "Transfer to invalid address"
        );
        super._transfer(from, to, amount);
    }
}
