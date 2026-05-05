# Diamond Vault Contracts

This Foundry workspace contains the onchain side of DiamondVault: the diamond proxy core, vault facets, pause-control modules, strategy management, mocks, and tests.

## Key Areas

- `src/diamond/`
  ERC-2535 proxy, loupe, ownership, and upgrade infrastructure.
- `src/vault/`
  ERC-4626 style vault logic, share accounting, pause controls, and supporting libraries.
- `src/strategy/`
  Strategy registration, allocation, debt tracking, and the first concrete Aave V3 strategy facet.
- `src/mocks/`
  Local doubles for USDC, Aave Pool, and aToken-backed strategy testing.
- `test/`
  Foundry test suite for the diamond, vault, share-accounting, storage-safety, and strategy flows.
- `docs/`
  Protocol and operational documentation.

## Recent Additions

- `AaveV3StrategyFacet` wires the vault's strategy manager into an Aave V3-style supply/withdraw/harvest flow.
- `MockAavePool` and `MockAToken` provide deterministic local coverage for Aave debt accounting, yield harvesting, and liquidity pulls during withdrawals.
- `StorageSafetyAudit.t.sol`, `ShareAccountingHardening.t.sol`, and the intentionally broken facet/storage fixtures document and prove the append-only storage rule for diamond upgrades.
- `test/fork test/AaveV3StrategyFork.t.sol` adds an optional mainnet-fork Aave validation suite covering allocation, withdrawal, harvest, and reserve-liquidity failure behavior when `MAINNET_RPC_URL` is set.

## Project Docs

- [Storage Layout And Safety](docs/storage-layout.md)
- [Roles And Incident Response](docs/roles-and-incident-response.md)

## Usage

### Build

```bash
forge build
```

### Test

```bash
forge test
```

### Targeted Validation

```bash
forge test --match-path test/AaveV3StrategyDiamond.t.sol -vv
forge test --match-path test/StorageSafetyAudit.t.sol -vv
forge test --match-path test/ShareAccountingHardening.t.sol -vv
```

### Optional Fork Test

Set `MAINNET_RPC_URL` only when you want to run the live Aave fork suite:

```bash
MAINNET_RPC_URL=<rpc-url> forge test --match-path 'test/fork test/AaveV3StrategyFork.t.sol' -vv
```

Without that environment variable, the fork tests exit early so the default local `forge test` flow still passes.

### Format

```bash
forge fmt
```

### Gas Snapshots

```bash
forge snapshot
```

### Local Node

```bash
anvil
```

### Help

```bash
forge --help
anvil --help
cast --help
```

## Notes

- `Vault4626FacetV2_BROKEN.sol`, `VaultShareFacetV2_BROKEN.sol`, and `LibVaultStorage_BROKEN.sol` are intentional footgun fixtures for the storage-safety audit and are not production upgrade targets.
