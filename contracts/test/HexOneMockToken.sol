// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract HexOneMockToken is ERC20 {
    address public admin;

    constructor (
        string memory _name, 
        string memory _symbol
    ) ERC20(_name, _symbol) { }

    function setAdmin(address _admin) external {
        require (_admin != address(0), "zero admin address");
        admin = _admin;
    }

    function mintToken(uint256 _amount, address _recipient) external {
        require (_recipient != address(0), "zero recipient address");
        require (_amount > 0, "zero mint token amount");

        _mint(_recipient, _amount);
    }

    function burnToken(uint256 _amount, address _account) external {
        require (_account != address(0), "zero account address");
        require (_amount > 0, "zero burn token amount");
        _burn(_account, _amount);
    }
}