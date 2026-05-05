# DiamondVault

DiamondVault is a multi-part workspace for an upgradeable diamond-based vault protocol and its supporting Chainlink Runtime Environment workflow.

## Repository Layout

- `Diamond-Vault-Contracts/`
  Solidity contracts, tests, docs, and Foundry configuration for the diamond proxy, vault facets, pause controls, and strategy management.
- `Diamond-Vault-CRE/`
  Chainlink Runtime Environment project for workflow automation and future operational tooling.
- `.vscode/`
  Workspace-level editor recommendations.

## Current Status

This repository is an active build in progress.

- The contracts project contains the main protocol implementation and test suite.
- The contracts workspace now includes a concrete Aave V3 strategy facet, local mocks, and both local and optional mainnet-fork validation for strategy allocation, withdrawal, harvest, and liquidity-stress flows.
- Storage-layout hardening material now lives alongside the contracts code, including a write-up and proof tests for safe vs broken diamond upgrades.
- The CRE project is currently a scaffolded workflow area that will evolve alongside the protocol.

## Quick Start

### Contracts

```bash
cd Diamond-Vault-Contracts
forge build
forge test
```

Focused validation for the new strategy and storage work:

```bash
cd Diamond-Vault-Contracts
forge test --match-path test/AaveV3StrategyDiamond.t.sol -vv
forge test --match-path test/StorageSafetyAudit.t.sol -vv
forge test --match-path test/ShareAccountingHardening.t.sol -vv
MAINNET_RPC_URL=<rpc-url> forge test --match-path 'test/fork test/AaveV3StrategyFork.t.sol' -vv
```

### CRE Workflow

```bash
cd Diamond-Vault-CRE/Diamond-Vault-workflow
bun install
bun test
```

To simulate the workflow, run the CRE CLI from `Diamond-Vault-CRE/`:

```bash
cre workflow simulate Diamond-Vault-workflow --target staging-settings
```

## Documentation

- Contracts overview and usage: `Diamond-Vault-Contracts/README.md`
- Storage layout and upgrade safety: `Diamond-Vault-Contracts/docs/storage-layout.md`
- Roles and incident response: `Diamond-Vault-Contracts/docs/roles-and-incident-response.md`
- CRE workflow notes: `Diamond-Vault-CRE/README.md`

## Repository Notes

- Local-only files such as `.env`, generated build artifacts, and workflow secrets are excluded by the root `.gitignore`.
- Root GitHub Actions are configured to run the Foundry checks from the contracts workspace.
- The repository has been prepared so `DiamondVault/` can be used as the actual GitHub repository root.
