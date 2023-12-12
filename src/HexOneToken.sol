// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IHexOneToken} from "./interfaces/IHexOneToken.sol";

contract HexOneToken is ERC20, Ownable, IHexOneToken {
    /// @dev HexOneProtocol address
    address public hexOneProtocol;
    /// @dev dead wallet address
    address public constant DEAD_WALLET = 0x000000000000000000000000000000000000dEaD;

    /// @dev checks if the sender is HexOneProtocol
    modifier onlyHexOneProtocol() {
        require(msg.sender == hexOneProtocol, "Only HexOneProtocol");
        _;
    }

    /// @param _name of the token: Hex One Token.
    /// @param _symbol ticker of the token: $HEX1.
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) Ownable(msg.sender) {}

    /// @dev set the address of the protocol.
    /// @param _hexOneProtocol address of the hexOneProtocol.
    function setHexOneProtocol(address _hexOneProtocol) external onlyOwner {
        require(_hexOneProtocol != address(0), "Invalid address");
        hexOneProtocol = _hexOneProtocol;
    }

    /// @dev mint HEX1 tokens to a specified account.
    /// @notice only HexOneProtocol can call this function.
    /// @param _recipient address of the receiver.
    /// @param _amount amount of HEX1 being minted.
    function mint(address _recipient, uint256 _amount) external onlyHexOneProtocol {
        _mint(_recipient, _amount);
    }

    /// @dev burn HEX1 tokens from a specified account.
    /// @notice only HexOneProtocol can call this function.
    /// @param _recipient address of the recipient having it's tokens burned.
    /// @param _amount amount of of HEX1 being burned.
    function burn(address _recipient, uint256 _amount) external onlyHexOneProtocol {
        _burn(_recipient, _amount);
    }

    /// @dev checks if HEX1 tokens are being transfered to the dead wallet.
    /// @param _to address to where HEX1 is being transfered.
    /// @param _amount amount of HEX1 being transfered.
    function transfer(address _to, uint256 _amount) public virtual override returns (bool) {
        require(_to != DEAD_WALLET, "Invalid transfer to dead address");
        return super.transfer(_to, _amount);
    }

    /// @dev checks if HEX1 tokens are being transfered to the dead wallet.
    /// @param _from address from where HEX1 is being transfered.
    /// @param _to address to where HEX1 is being transfered.
    /// @param _amount amount of HEX1 being transfered.
    function transferFrom(address _from, address _to, uint256 _amount) public virtual override returns (bool) {
        require(_to != DEAD_WALLET, "Invalid transfer to dead address");
        return super.transferFrom(_from, _to, _amount);
    }
}
