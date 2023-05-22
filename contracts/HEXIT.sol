// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IHEXIT.sol";

contract HEXIT is ERC20, Ownable, IHEXIT {
    address public bootstrap;
    address public constant deadWallet =
        0x000000000000000000000000000000000000dEaD;

    modifier onlyBootstrap() {
        require(msg.sender == bootstrap, "only bootstrap");
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {}

    /// @inheritdoc IHEXIT
    function setBootstrap(address _bootstrap) external override onlyOwner {
        require(_bootstrap != address(0), "zero bootstrap address");
        bootstrap = _bootstrap;
    }

    /// @inheritdoc IHEXIT
    function mintToken(
        uint256 _amount,
        address _recipient
    ) external override onlyBootstrap {
        require(_recipient != address(0), "zero recipient address");
        require(_amount > 0, "zero mint token amount");

        _mint(_recipient, _amount);
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
