

# Blockchain Bridge Contracts
![Test Status](https://github.com/DanielDimitrov5/ERC-20-Bridge/actions/workflows/test.yml/badge.svg)

This repository contains a Solidity smart contracts for a blockchain bridge, developed with Foundry. The bridge enables the transfer of tokens between different blockchain networks while maintaining a constant supply of assets across chains. It relies on a centralized backend to listen for events and generate the required signatures for user operations.

## Overview

The Bridge contract utilizes a lock/release/mint/burn mechanism for cross-chain token transfers. It allows tokens to be "locked" on one chain and "minted" or "released" as wrapped tokens on another. This process ensures the total supply of assets remains constant across chains.

### Key Features

- **Token Locking and Releasing**: Securely lock tokens on one chain and release them on another.
- **Minting and Burning of Wrapped Tokens**: Mint wrapped tokens representing original tokens from another chain, and burn them to transfer back.
- **Centralized Signature Generation**: A backend service listens to contract events and generates signatures for secure operations.
- **Robust Security Measures**: The contract employs extensive security checks and balances.

### Contract Components

- **ERC20 Token Standard**: Utilizes the OpenZeppelin ERC20 implementation.
- **Ownership Management**: Inherits OpenZeppelin's Ownable contract.
- **Cryptographic Utilities**: For secure operations and signature verification.
- **Custom Interfaces**: Implements the IBridge interface for specific bridge functionalities.

## Getting Started

### Prerequisites

- Solidity 0.8.23
- OpenZeppelin Contracts

### Installation

Clone the repository and install the required modules:

```bash
git clone https://github.com/DanielDimitrov5/ERC-20-Bridge.git
cd [repository-directory]
forge install
```

### Test

Run the tests with:

```bash
forge test
```

## Contributing

Contributions are welcome. Please open an issue first to discuss what you would like to change, or create a pull request with your updates.

## License

Distributed under the MIT License. See `LICENSE` for more information.

## Contact

[Daniel Dimitrov](https://linktr.ee/danithedev)

![#](https://via.placeholder.com/150/000000/FFFFFF/?text=Dark)
![#](https://via.placeholder.com/150/FFFFFF/000000/?text=Light)

---
