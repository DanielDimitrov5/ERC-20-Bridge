// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {WERC20} from "src/WERC.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract Bridge is Ownable {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    error Bridge__InvalidChainId(uint256 chainId);
    error Bridge__InvalidToken();
    error Bridge__InvalidAmount(uint256 amount);
    error Bridge__InvalidSignature();
    error Bridge__TokenAlreadyWrapped(address token);
    error Bridge__InvalidNonce(uint256 nonce);
    error Bridge__InvalidRecepient(address recepient);

    address public immutable ADMIN;
    mapping(address originalToken => WERC20 wrappedToken) public wrappedTokens;
    mapping(address user => uint256 nonce) public nonces;

    constructor(address admin) Ownable(msg.sender) {
        ADMIN = admin;
    }

    modifier validateLock(address token, uint256 amount, uint256 chainId) {
        if (token == address(0)) revert Bridge__InvalidToken();
        if (amount == 0) revert Bridge__InvalidAmount(amount);
        if (chainId == 0) revert Bridge__InvalidChainId(chainId);
        _;
    }

    modifier validateMint(address token, uint256 amount, address to) {
        if (token == address(0)) revert Bridge__InvalidToken();
        if (amount == 0) revert Bridge__InvalidAmount(amount);
        if (to == address(0)) revert Bridge__InvalidRecepient(to);
        _;
    }

    event Lock(address indexed token, address indexed sender, uint256 amount, uint256 indexed chainId);
    event TokenWrapped(address indexed originalToken, address indexed wrappedToken);
    event Mint(address indexed token, address indexed to, uint256 amount);

    function lock(address token, uint256 amount, uint256 chainId) external validateLock(token, amount, chainId) {
        ERC20(token).transferFrom(msg.sender, address(this), amount);
        emit Lock(token, msg.sender, amount, chainId);
    }

    function mint(address originalToken, uint256 amount, address to, uint256 nonce, bytes memory signature)
        external
        validateMint(originalToken, amount, to)
    {
        if (nonces[to] != nonce) {
            revert Bridge__InvalidNonce(nonce);
        }

        bytes32 messageHash = keccak256(abi.encodePacked(originalToken, to, amount, block.chainid, nonce));
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();

        address signer = ethSignedMessageHash.recover(signature);
        if (signer != ADMIN) {
            revert Bridge__InvalidSignature();
        }

        nonces[to]++;

        WERC20 wrappedToken = wrappedTokens[originalToken];
        if (address(wrappedToken) == address(0)) {
            _wrapToken(originalToken);
            wrappedToken = wrappedTokens[originalToken];
        }

        wrappedToken.mint(to, amount);
        emit Mint(address(wrappedToken), to, amount);
    }

    function _wrapToken(address token) internal {
            string memory name = string(abi.encodePacked("Wrapped", ERC20(token).name()));
            string memory symbol = string(abi.encodePacked("w", ERC20(token).symbol()));
            WERC20 wrappedToken = new WERC20(name, symbol);
            wrappedTokens[token] = wrappedToken;
            emit TokenWrapped(token, address(wrappedToken));
    }
}
