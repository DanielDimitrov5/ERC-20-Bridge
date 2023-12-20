// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {WERC20} from "src/WERC.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {console2} from "forge-std/Console2.sol";


contract Bridge is Ownable {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    error Bridge__InvalidChainId(uint256 chainId);
    error Bridge__InvalidToken();
    error Bridge__InvalidAmount(uint256 amount);
    error Bridge__InvalidSignature();
    error Bridge__TokenAlreadyWrapped(address token);

    address public immutable ADMIN;
    mapping (address originalToken => WERC20 wrappedToken) public wrappedTokens;

    constructor(address admin) Ownable(msg.sender) {
        ADMIN = admin;
    }

    modifier validateLock(address token, uint256 amount, uint256 chainId) {
        if (token == address(0)) revert Bridge__InvalidToken();
        if (amount == 0) revert Bridge__InvalidAmount(amount);
        if (chainId == 0) revert Bridge__InvalidChainId(chainId);
        _;        
    }

    event Lock(address indexed token, address indexed sender, uint256 amount, uint256 indexed chainId);
    event TokenWrapped(address indexed originalToken, address indexed wrappedToken);
    event Mint(address indexed token, address indexed to, uint256 amount);

    function lock(address token, uint256 amount, uint256 chainId) external validateLock(token, amount, chainId) {
        ERC20(token).transferFrom(msg.sender, address(this), amount);
        emit Lock(token, msg.sender, amount, chainId);
    }

    function mint(address originalToken, uint256 amount, address to, bytes memory signature) external {
        bytes32 messageHash = keccak256(abi.encodePacked(originalToken, to, amount, block.chainid));
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        
        address signer = ethSignedMessageHash.recover(signature);
        if (signer != ADMIN) {
            revert Bridge__InvalidSignature();
        }

        WERC20 wrappedToken = wrappedTokens[originalToken];
        if (address(wrappedToken) == address(0)) {
            string memory name = string(abi.encodePacked("Wrapped", ERC20(originalToken).name()));
            string memory symbol = string(abi.encodePacked("w", ERC20(originalToken).symbol()));
            wrappedToken = new WERC20(name, symbol);
            wrappedTokens[originalToken] = wrappedToken;
            emit TokenWrapped(originalToken, address(wrappedToken));
        }

        wrappedToken.mint(to, amount);
        emit Mint(address(wrappedToken), to, amount);
    }
}