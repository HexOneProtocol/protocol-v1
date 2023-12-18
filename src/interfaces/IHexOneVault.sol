// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

interface IHexOneVault {
    event ProtocolInitialized(address hexOneProtocol);

    error InvalidAddress();
    error NotHexOneProtocol();

    function deposit() external;
    function claim() external;
    function borrow() external;
}
