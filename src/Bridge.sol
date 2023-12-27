// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {WERC20} from "src/WERC.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IBridge} from "src/IBridge.sol";
import {console2} from "forge-std/console2.sol";

contract Bridge is IBridge, Ownable {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    error Bridge__InvalidChainId(uint256 chainId);
    error Bridge__InvalidToken();
    error Bridge__InvalidAmount(uint256 amount);
    error Bridge__InvalidSignature();
    error Bridge__TokenAlreadyWrapped(address token);
    error Bridge__InvalidNonce(uint256 nonce);
    error Bridge__InvalidRecepient(address recepient);
    error Bridge__UnsuccessfulTransfer(address token, address to, uint256 amount);

    address public immutable ADMIN;

    mapping(address originalToken => WERC20 wrappedToken) public wrappedTokens;
    mapping(address user => uint256 nonce) public nonces;
    mapping(address user => mapping(address token => uint256 amount)) public balances;

    constructor(address admin) Ownable(msg.sender) {
        ADMIN = admin;
    }

    modifier validateLock(address token, uint256 amount, uint256 chainId) {
        if (token == address(0)) revert Bridge__InvalidToken();
        if (amount == 0) revert Bridge__InvalidAmount(amount);
        if (chainId == 0) revert Bridge__InvalidChainId(chainId);
        _;
    }

    modifier validateRelease(address token, address to, uint256 amount, uint256 nonce) {
        if (token == address(0)) revert Bridge__InvalidToken();
        if (to == address(0)) revert Bridge__InvalidRecepient(to);
        if (balances[to][token] < amount || amount == 0) revert Bridge__InvalidAmount(amount);
        if (nonces[to] != nonce) revert Bridge__InvalidNonce(nonce);
        _;
    }

    modifier validateMint(address token, uint256 amount, address to, uint256 nonce) {
        if (token == address(0)) revert Bridge__InvalidToken();
        if (amount == 0) revert Bridge__InvalidAmount(amount);
        if (to == address(0)) revert Bridge__InvalidRecepient(to);
        if (nonces[to] != nonce) revert Bridge__InvalidNonce(nonce);
        _;
    }

    modifier validateBurn(address token, uint256 amount) {
        if (address(wrappedTokens[token]) == address(0)) revert Bridge__InvalidToken();
        if (amount == 0) revert Bridge__InvalidAmount(amount);
        _;
    }

    event Lock(
        address indexed token, address indexed sender, uint256 amount, uint256 indexed chainId, WrapData wrapData
    );
    event Release(address indexed token, address indexed to, uint256 amount);
    event TokenWrapped(address indexed originalToken, address indexed wrappedToken);
    event Mint(address indexed token, address indexed to, uint256 amount);
    event Burn(address indexed token, address indexed from, uint256 amount);

    function lock(LockData calldata _lockData)
        external
        validateLock(_lockData.token, _lockData.amount, _lockData.chainId)
    {
        address token = _lockData.token;
        uint256 amount = _lockData.amount;
        uint256 chainId = _lockData.chainId;

        WERC20 wrappedToken = wrappedTokens[token]; // TODO: fix logic
        if (wrappedToken != WERC20(address(0))) {
            wrappedToken.burn(msg.sender, amount);
            balances[msg.sender][token] -= amount;
        } else {
            bool isSuccess = ERC20(token).transferFrom(msg.sender, address(this), amount);

            if (!isSuccess) revert Bridge__UnsuccessfulTransfer(token, address(this), amount);

            balances[msg.sender][token] += amount;
        }

        emit Lock(token, msg.sender, amount, chainId, WrapData(ERC20(token).name(), ERC20(token).symbol()));
    }

    function release(ReleaseData calldata _releaseData)
        external
        validateRelease(_releaseData.token, _releaseData.to, _releaseData.amount, _releaseData.nonce)
    {
        address originalToken = _releaseData.token;
        address to = _releaseData.to;
        uint256 amount = _releaseData.amount;
        uint256 nonce = _releaseData.nonce;
        bytes memory signature = _releaseData.signature;

        bytes32 messageHash = keccak256(abi.encodePacked(originalToken, to, amount, nonce));
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();

        address signer = ethSignedMessageHash.recover(signature);
        if (signer != ADMIN) {
            revert Bridge__InvalidSignature();
        }

        nonces[to]++;

        balances[to][originalToken] -= amount;
        bool isSuccess = ERC20(originalToken).transfer(to, amount);

        if (!isSuccess) revert Bridge__UnsuccessfulTransfer(originalToken, to, amount);

        emit Release(originalToken, to, amount);
    }

    function mint(MintData calldata _mintData)
        external
        validateMint(_mintData.token, _mintData.amount, _mintData.to, _mintData.nonce)
    {
        address originalToken = _mintData.token;
        address to = _mintData.to;
        uint256 amount = _mintData.amount;
        uint256 nonce = _mintData.nonce;
        bytes memory signature = _mintData.signature;
        uint256 sourceChainId = _mintData.sourceChainId;

        bytes32 messageHash = keccak256(abi.encodePacked(originalToken, to, amount, block.chainid, nonce));
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();

        address signer = ethSignedMessageHash.recover(signature);
        if (signer != ADMIN) {
            revert Bridge__InvalidSignature();
        }

        nonces[to]++;

        WERC20 wrappedToken = wrappedTokens[originalToken];
        if (address(wrappedToken) == address(0)) {
            _wrapToken(_mintData.wrapData, originalToken, sourceChainId);
            wrappedToken = wrappedTokens[originalToken];
        }

        wrappedToken.mint(to, amount);
        balances[to][originalToken] += amount;

        emit Mint(address(wrappedToken), to, amount);
    }

    function burn(address token, uint256 amount) external validateBurn(token, amount) {
        WERC20 wrappedToken = wrappedTokens[token];

        wrappedToken.burn(msg.sender, amount);
        balances[msg.sender][token] -= amount;

        emit Burn(token, msg.sender, amount);
    }

    function _wrapToken(WrapData calldata _wrapData, address _token, uint256 _sourceChainId) internal {
        string memory name = string(abi.encodePacked("Wrapped ", _wrapData.name));
        string memory symbol = string(abi.encodePacked("w", _wrapData.symbol));

        WERC20 wrappedToken = new WERC20(name, symbol, _token, _sourceChainId);
        wrappedTokens[_token] = wrappedToken;
        emit TokenWrapped(_token, address(wrappedToken));
    }
}
