# Cets (CETS)

CETS is a fixed-supply ERC-20. Its constructor mints **1,000,000,000 CETS with 18 decimals** to `msg.sender`. Transfers move the exact requested amount. The deployed token has no owner, subsequent minting, burning, fees, rebasing, pausing, blocklisting, seizure, or upgrade mechanism.

## Deployment parameters

| Parameter | Value |
| --- | --- |
| Contract | `src/Cets.sol:Cets` |
| Name | `Cets` |
| Symbol | `CETS` |
| Decimals | `18` |
| Total supply in base units | `1000000000000000000000000000` (`10^27`) |
| Constructor arguments | None (`[]`; empty ABI encoding) |
| Deployment transaction value | `0` |
| Initial recipient | Immediate deployer (`msg.sender`) |
| Solidity compiler | `0.8.26` |
| EVM target | `cancun` |
| Optimizer | Enabled, 200 runs |
| Bytecode metadata hash | `none` |

The constructor has no chain addresses or configuration to resolve. Deploying through a factory, including CREATE2, gives the **factory** the entire supply; the transaction origin receives nothing automatically. A factory must implement any subsequent distribution itself. No initializer or post-deployment setup call is needed.

To review the deployment inputs locally:

```sh
forge build
forge inspect src/Cets.sol:Cets abi
forge inspect src/Cets.sol:Cets bytecode
forge inspect src/Cets.sol:Cets deployedBytecode
```

The deployment operator must choose a chain supporting the Cancun EVM target, the authorized deployment account or factory, and (if using CREATE2) its salt. Deploy the compiled creation bytecode with empty constructor arguments and zero native value. Verify the resulting runtime against this build, then check `name()`, `symbol()`, `decimals()`, `totalSupply()`, and the deploying address's balance before distribution. Publish verified source and the deployed address for users.

This assignment does not specify a chain, production factory, pool, paired asset, launch price, allocation beyond the initial mint, or recipient for later distribution. Those are responsibilities of the launch operator. The token imposes no special rules or exemptions on factories, distributors, pools, or traders. It makes no external calls during deployment or token operations. This repository contains no application contracts or deployment broadcaster, and no transactions were sent.

## Token behavior and assumptions

- `transfer`, `approve`, and `transferFrom` return `true` on success and revert with OpenZeppelin's ERC-20 custom errors on failure.
- Transfers to the zero address revert, including zero-value transfers. Zero-value transfers between valid addresses and transfers to oneself are supported.
- Only a holder can transfer its tokens directly. A spender needs that holder's allowance, including when the spender is the deployer.
- Approvals replace the previous allowance. Finite allowances decrease on spending; `type(uint256).max` is treated as an unlimited allowance and remains unchanged. Failed transfers roll back all balance and allowance changes.
- Minting emits `Transfer(address(0), deployer, totalSupply)`. Transfers emit `Transfer`; explicit approvals emit `Approval`. This OpenZeppelin version does not emit `Approval` when `transferFrom` spends an allowance; integrations should read `allowance()` for current values.
- Holders are responsible for recipient addresses and approvals. Prefer limited approvals; when replacing an existing nonzero allowance, revoke it first and account for pending transactions. There is no permit extension.
- The deployer controls the initial allocation as a holder, with no additional authority. There are no administrative or maintenance transactions, recovery function, or upgrades. Transfers to the token itself or to contracts unable to send tokens can lock funds permanently. The token does not accept ordinary native-currency payments.

## Build and checks

Foundry and Solidity 0.8.26 are the only external tool prerequisites. All Solidity dependencies are included as ordinary source files under `lib/`; no dependency installation, network, environment variables, RPC, FFI, or filesystem cheatcodes are needed to build or test once the compiler is installed. `foundry.toml` pins the compiler by version and disables FFI and filesystem permissions.

```sh
forge build
forge test
forge fmt --check
```

The tests cover metadata, the exact initial supply and mint event, direct deployment, CREATE2 factory deployment, exact distribution and pool-address transfers, ERC-20 events, allowance spending/replacement/revocation, unlimited allowances, zero and self transfers, unauthorized spending, insufficient balance and allowance, zero addresses, atomic rollback, and absent privileged entrypoints. A runtime scan checks for `DELEGATECALL`, `CALLCODE`, and `SELFDESTRUCT` and checks the deployment size limit.

Four fuzz tests run 256 cases each. Two stateful invariants run 128 sequences of up to 64 actions each, mixing transfers, approvals, and delegated transfers across four actors and checking fixed supply and balance conservation. Tests use fresh fixtures and no shared environment state.

The supplied protected harness was read as an integration contract: factory minting, exact launch transfers, freely transferable holder balances, and fixed supply are covered locally. Its full Uniswap v4 pool setup depends on the launch system's contracts and deployment inputs, which are not part of this assignment. The local factory test checks token movements; it does not claim to execute that external harness or simulate DEX pricing and swaps.

## Dependencies and review

- OpenZeppelin Contracts **v5.0.2**, commit `dbb6104ce834628e473d2173bbc9d47f81a9eec3`: the unmodified ERC-20 implementation and its complete five-file Solidity dependency closure, with the upstream MIT license.
- Forge Standard Library **v1.9.7**, commit `77041d2ce690e692d6e03cc812b57d1ddaa4d505`: upstream `src/` plus MIT and Apache licenses, used only by tests.

Exact file checksums and upstream repository URLs are recorded in [dependencies.json](dependencies.json). There are no git submodules. Remappings use only these local sources.

The supplied security reference was used to review supply arithmetic, allowances, access control, input validation, external-call exposure, and upgradeability. The contract only adds a constructor and a supply constant to the vendored ERC-20; there are no oracles, callbacks, signatures, or external integrations in its logic. Local Foundry unit, fuzz, invariant, build, and formatting checks are the validation performed. Slither, Mythril, and live-chain integration checks were not run. Tests and this local review are not a security audit; independent adversarial review remains a release responsibility.
