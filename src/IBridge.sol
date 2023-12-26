// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface IBridge {
    function lock(LockData calldata data) external;

    function release(ReleaseData calldata data) external;

    function mint(MintData calldata data) external;

    function burn(address token, uint256 amount) external;

    struct LockData {
        address token;
        uint256 amount;
        uint256 chainId;
    }

    struct ReleaseData {
        address token;
        address to;
        uint256 amount;
        uint256 nonce;
        bytes signature;
    }

    struct MintData {
        address token;
        address to;
        uint256 amount;
        uint256 nonce;
        bytes signature;
        WrapData wrapData;
    }

    struct WrapData {
        string name;
        string symbol;
    }
}
