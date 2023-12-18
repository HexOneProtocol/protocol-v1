// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

interface IHexOneToken {
    event ProtocolInitialized(address hexOneProtocol);

    error NotHexOneProtocol();
    error InvalidAddress();

    function setHexOneProtocol(address _hexOneProtocol) external;
    function mint(address _recipient, uint256 _amount) external;
    function burn(address _recipient, uint256 _amount) external;
}
