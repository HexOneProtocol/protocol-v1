// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IHexOneVault} from "./interfaces/IHexOneVault.sol";
import {IHexOnePriceFeed} from "./interfaces/IHexOnePriceFeed.sol";

contract HexOneVault is IHexOneVault, Ownable {
    IHexOnePriceFeed public hexOnePriceFeed;
    address public immutable hexToken;

    address public hexOneProtocol;

    modifier onlyHexOneProtocol() {
        if (msg.sender != hexOneProtocol) revert NotHexOneProtocol();
        _;
    }

    constructor(address _hexOnePriceFeed, address _hexToken) Ownable(msg.sender) {
        hexOnePriceFeed = IHexOnePriceFeed(_hexOnePriceFeed);
        hexToken = _hexToken;
    }

    function setHexOneProtocol(address _hexOneProtocol) external onlyOwner {
        if (_hexOneProtocol == address(0)) revert InvalidAddress();
        hexOneProtocol = _hexOneProtocol;
        emit ProtocolInitialized(_hexOneProtocol);
    }

    function deposit() external {}

    function claim() external {}

    function borrow() external {}

    function _getHexPrice(uint256 amountIn) internal returns (uint256) {
        try hexOnePriceFeed.consult(hexToken, amountIn) returns (uint256 amountOut) {
            return amountOut;
        } catch (bytes memory reason) {
            bytes4 err = abi.decode(reason, (bytes4));
            if (err == IHexOnePriceFeed.PriceTooStale.selector) {
                hexOnePriceFeed.update();
                return hexOnePriceFeed.consult(hexToken, amountIn);
            }
            revert();
        }
    }
}
