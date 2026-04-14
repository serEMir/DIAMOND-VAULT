# Diamond Vault Contracts

This Foundry workspace contains the onchain side of DiamondVault: the diamond proxy core, vault facets, pause-control modules, strategy management, mocks, and tests.

## Key Areas

- `src/diamond/`
  ERC-2535 proxy, loupe, ownership, and upgrade infrastructure.
- `src/vault/`
  ERC-4626 style vault logic, share accounting, pause controls, and supporting libraries.
- `src/strategy/`
  Strategy registration, allocation, debt tracking, and mock strategy plumbing.
- `test/`
  Foundry test suite for the diamond, vault, and strategy flows.
- `docs/`
  Protocol and operational documentation.

## Project Docs

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
