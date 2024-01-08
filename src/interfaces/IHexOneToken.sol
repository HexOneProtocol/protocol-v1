// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

interface IHexOneToken {
    event VaultInitialized(address hexOneVault);

    error NotHexOneVault();
    error InvalidAddress();

    function setHexOneVault(address _hexOneVault) external;
    function mint(address _recipient, uint256 _amount) external;
    function burn(address _recipient, uint256 _amount) external;
}
