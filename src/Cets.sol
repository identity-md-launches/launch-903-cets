// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title Cets (CETS)
/// @notice Fixed-supply ERC-20 with 18 decimals and no administrative privileges.
contract Cets is ERC20 {
    /// @notice One billion CETS, expressed in the token's smallest units.
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 * 10 ** 18;

    /// @notice Mint the entire supply once to the immediate deployer, including a deploying factory.
    constructor() ERC20("Cets", "CETS") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}
