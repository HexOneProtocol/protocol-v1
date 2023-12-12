// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract HexitTokenMock is ERC20 {
    constructor() ERC20("Hexit Token", "HEXIT") {}

    function mint(address _recipient, uint256 _amount) external {
        require(_amount > 0, "zero mint token amount");
        _mint(_recipient, _amount);
    }
}
