// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Bridge {
    error Bridge__InvalidChainId(uint256 chainId);
    error Bridge__InvalidToken();
    error Bridge__InvalidAmount(uint256 amount);

    modifier validateLock(address token, uint256 amount, uint256 chainId) {
        if (token == address(0)) revert Bridge__InvalidToken();
        if (amount == 0) revert Bridge__InvalidAmount(amount);
        if (chainId == 0) revert Bridge__InvalidChainId(chainId);
        _;        
    }

    event Lock(address indexed token, address indexed sender, uint256 amount, uint256 indexed chainId);

    function lock(address token, uint256 amount, uint256 chainId) external validateLock(token, amount, chainId) {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        emit Lock(token, msg.sender, amount, chainId);
    }
}