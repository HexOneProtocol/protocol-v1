// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IHexOneToken.sol";

contract HexOneToken is ERC20, Ownable, IHexOneToken {
    address public admin;
    address public deployer;
    address public constant DEAD_WALLET =
        0x000000000000000000000000000000000000dEaD;

    modifier onlyHexOneProtocol() {
        require(msg.sender == admin || msg.sender == deployer, "only Admin");
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

    /// @inheritdoc IHexOneToken
    function setDeployer(address _deployer) external override onlyOwner {
        require(_deployer != address(0), "zero deployer address");
        deployer = _deployer;
    }

    /// @inheritdoc IHexOneToken
    function mintToken(
        uint256 _amount,
        address _recipient
    ) external override onlyHexOneProtocol {
        require(_amount > 0, "zero mint token amount");
        _mint(_recipient, _amount);
    }

    /// @inheritdoc IHexOneToken
    function burnToken(
        uint256 _amount,
        address _account
    ) external override onlyHexOneProtocol {
        require(_amount > 0, "zero burn token amount");
        _burn(_account, _amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        require(from != DEAD_WALLET, "Invalid transfer from dead address");
        require(to != DEAD_WALLET, "Invalid transfer to dead address");
        super._transfer(from, to, amount);
    }
}
