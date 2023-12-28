// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract WERC20 is ERC20, Ownable {
    address public immutable UNDERLYING_TOKEN;
    uint256 public immutable SOURCE_CHAIN_ID;

    constructor(string memory _name, string memory _symbol, address _underlyingToken, uint256 _sourceChainId) ERC20(_name, _symbol) Ownable(msg.sender) {
        UNDERLYING_TOKEN = _underlyingToken;
        SOURCE_CHAIN_ID = _sourceChainId;
    }


    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}