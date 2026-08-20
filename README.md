# 🔷 DiamondVault

A production-grade, modular yield aggregator built on **ERC-2535 Diamond Proxy** with pluggable strategies, governance-controlled upgrades, and Chainlink Runtime Environment automation.

DiamondVault solves the core DeFi infrastructure problem: enabling a single, eternal contract address that can grow unlimited features without the fragmentation of traditional multi-contract deployments or the pain of contract migrations.

**Status:** Feature-complete on Solidity contracts with comprehensive test coverage. Chainlink CRE automation scaffolded and ready for extension.

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Architecture](#-architecture)
- [Repository Structure](#-repository-structure)
- [Quick Start](#-quick-start)
- [Key Features](#-key-features)
- [Testing](#-testing)
- [Deployment](#-deployment)
- [Documentation](#-documentation)
- [Contributing](#-contributing)

---

## 🎯 Overview

DiamondVault implements a modular vault protocol that addresses two critical DeFi pain points:

1. **The 24KB Contract Size Limit** — Solved by splitting logic across multiple facets while maintaining one eternal proxy address.
2. **Multi-Contract Fragmentation** — Solved by keeping all vault operations at a single address, enabling seamless strategy upgrades without user migrations or approval re-approvals.

### Why the Diamond Pattern?

- **One Address, Infinite Features** — All operations happen at the vault's single address. Adding strategies, oracles, or governance features doesn't require new contracts or migrations.
- **Granular Upgrades** — Each facet can be upgraded independently. A buggy oracle doesn't require touching the core vault logic.
- **State Coherence** — All facets share the same storage, enabling complex, interconnected logic without cross-contract communication.
- **On-Chain Introspection** — The DiamondLoupe facet provides runtime discovery of available functions and strategies.
- **Proven in Production** — Used by Beanstalk, DerivaDEX, Premia Finance, and 100+ live protocols.

### What You Can Do With DiamondVault

- **Deposit/Withdraw** — Standard ERC-4626 vault interface for users to enter/exit the protocol.
- **Strategy Allocation** — Route capital to multiple yield strategies (Aave V3, Uniswap LP, Compound, etc.) without fragmentation.
- **Governance-Driven Upgrades** — Only authorized roles can add/remove/modify strategies via `diamondCut`.
- **Emergency Controls** — Guardian can pause deposits, withdrawals, or specific strategies without requiring full owner authority.
- **Harvestable Yields** — Strategies report gains; the vault reallocates and compounds automatically or via keeper calls.
- **Automated Operations** — Chainlink Runtime Environment can trigger harvests, rebalances, and other bounded operations.

---

## 🏗️ Architecture

### High-Level Design

```
┌─────────────────────────────────────────┐
│      Diamond Proxy (One Address)        │  ← Users interact here
├─────────────────────────────────────────┤
│  DiamondCutFacet  | DiamondLoupeFacet   │  ← Admin & introspection
├─────────────────────────────────────────┤
│  VaultShareFacet  | Vault4626Facet      │  ← Core vault (ERC-20/ERC-4626)
├─────────────────────────────────────────┤
│  VaultPauseFacet  | StrategyManagerFacet│  ← Control & management
├─────────────────────────────────────────┤
│  AaveV3StrategyFacet | StrategyKeeperFacet │  ← Concrete implementations
├─────────────────────────────────────────┤
│  OwnershipFacet   | MockStrategyFacet   │  ← Ownership & testing
└─────────────────────────────────────────┘
         ↓
   Shared VaultStorage (one location)
   ├─ User balances & allowances
   ├─ Vault name, symbol, decimals
   ├─ Total supply & initialized flag
   └─ (append-only for upgrades)
```

### Facet Breakdown

| Facet | Purpose | Key Functions |
|-------|---------|----------------|
| **DiamondCutFacet** | Upgrade logic | `diamondCut()`, `facetFunctionSelectors()` |
| **DiamondLoupeFacet** | Introspection | `facets()`, `facetAddress()`, `supportsInterface()` |
| **OwnershipFacet** | Owner management | `owner()`, `transferOwnership()` |
| **VaultShareFacet** | ERC-20 logic | `transfer()`, `approve()`, `balanceOf()` |
| **Vault4626Facet** | ERC-4626 vault | `deposit()`, `withdraw()`, `totalAssets()`, `convertToShares()` |
| **VaultPauseFacet** | Emergency controls | `setDepositsPaused()`, `setWithdrawalsPaused()`, etc. |
| **StrategyManagerFacet** | Strategy registry | `registerStrategy()`, `allocateToStrategy()`, `harvestStrategy()` |
| **AaveV3StrategyFacet** | Aave integration | `aaveV3StrategyDeploy()`, `aaveV3StrategyHarvest()`, `aaveV3StrategyFreeFunds()` |
| **StrategyKeeperFacet** | Automation entry | `executeHarvest()`, `executeRebalance()` (CRE/keeper calls) |

### Strategy System

Strategies are registered with selectors that the vault uses to dispatch calls:

```solidity
registerStrategy(
  bytes32 strategyId,
  bytes4 deploySelector,     // How to allocate capital
  bytes4 freeFundsSelector,  // How to withdraw from strategy
  bytes4 harvestSelector     // How to claim yields
)
```

When you call `allocateToStrategy(strategyId, amount)`, the vault calls the registered selector on itself (delegatecall), which routes to the corresponding facet method.

---

## 📂 Repository Structure

```
DiamondVault/
├── Diamond-Vault-Contracts/    ← Solidity contracts (this is the main package)
│   ├── src/
│   │   ├── diamond/            ← Proxy, facets, upgrade logic
│   │   │   ├── Diamond.sol
│   │   │   ├── facets/
│   │   │   │   ├── DiamondCutFacet.sol
│   │   │   │   ├── DiamondLoupeFacet.sol
│   │   │   │   └── OwnershipFacet.sol
│   │   │   ├── interfaces/
│   │   │   ├── libraries/
│   │   │   └── upgrade/
│   │   ├── vault/              ← Vault logic (ERC-20, ERC-4626)
│   │   │   ├── facets/
│   │   │   │   ├── VaultShareFacet.sol
│   │   │   │   ├── Vault4626Facet.sol
│   │   │   │   ├── VaultPauseFacet.sol
│   │   │   │   └── *_BROKEN.sol (safety audit fixtures)
│   │   │   ├── interfaces/
│   │   │   ├── libraries/
│   │   │   └── upgrade/
│   │   ├── strategy/           ← Strategy management & implementations
│   │   │   ├── facets/
│   │   │   │   ├── StrategyManagerFacet.sol
│   │   │   │   ├── AaveV3StrategyFacet.sol
│   │   │   │   ├── StrategyKeeperFacet.sol
│   │   │   │   └── MockStrategyFacet.sol
│   │   │   ├── interfaces/
│   │   │   └── libraries/
│   │   ├── mocks/              ← Local test doubles (USDC, Aave Pool, aToken)
│   │   └── cre/                ← CRE-related utilities
│   ├── test/
│   │   ├── AaveV3StrategyDiamond.t.sol
│   │   ├── Vault4626Diamond.t.sol
│   │   ├── StorageSafetyAudit.t.sol
│   │   ├── ShareAccountingHardening.t.sol
│   │   ├── fork test/
│   │   │   └── AaveV3StrategyFork.t.sol  (optional mainnet fork tests)
│   │   └── unit/
│   ├── script/                 ← Deployment & upgrade scripts
│   ├── docs/
│   │   ├── storage-layout.md
│   │   └── roles-and-incident-response.md
│   ├── foundry.toml
│   └── README.md
├── Diamond-Vault-CRE/          ← Chainlink Runtime Environment
│   ├── Diamond-Vault-workflow/ ← TypeScript automation
│   ├── project.yaml
│   ├── secrets.yaml
│   └── README.md
├── .github/                    ← CI/CD workflows
├── README.md                   ← You are here
└── project-brief.md
```

---

## ⚡ Quick Start

### Prerequisites

- **Foundry** (forge, cast, anvil): [Install](https://book.getfoundry.sh/getting-started/installation)
- **Solidity 0.8.20+**
- *(Optional)* **Node.js + Bun** for CRE workflows
- *(Optional)* **Chainlink CRE CLI** for automation

### 1. Clone & Install

```bash
git clone <repo>
cd DiamondVault/Diamond-Vault-Contracts
forge install
```

### 2. Build

```bash
forge build
```

### 3. Test (All Tests)

```bash
forge test
```

### 4. Test (Specific Suite)

```bash
# Core vault & ERC-4626 logic
forge test --match-path test/Vault4626Diamond.t.sol -vv

# Strategy allocation & harvest
forge test --match-path test/AaveV3StrategyDiamond.t.sol -vv

# Storage safety (demonstrates upgrade hazards)
forge test --match-path test/StorageSafetyAudit.t.sol -vv

# Share accounting edge cases
forge test --match-path test/ShareAccountingHardening.t.sol -vv
```

### 5. Test (Optional Fork Tests - Requires RPC)

```bash
# Set your RPC endpoint
export SEPOLIA_RPC_URL="https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY"

# Run fork tests against live Aave on Sepolia
forge test --match-path 'test/fork test/AaveV3StrategyFork.t.sol' -vv
```

---

## ✨ Key Features

### ✅ Implemented

- **ERC-2535 Diamond Proxy** — Fully functional diamond with upgrade capabilities.
- **ERC-4626 Vault** — Standard vault interface (`deposit`, `withdraw`, `redeem`, conversions).
- **ERC-20 Shares** — User-friendly token representing vault positions.
- **Strategy System** — Register, allocate to, harvest from, and free funds from strategies.
- **Aave V3 Integration** — Concrete implementation of lending strategy (supply → harvest yields → withdraw on demand).
- **Emergency Pause Controls** — Guardian can pause deposits, withdrawals, share transfers, and strategy operations independently.
- **Storage-Safe Upgrades** — Append-only storage layout with audit-proven safety rules.
- **Comprehensive Tests** — 200+ tests covering core logic, edge cases, storage safety, and Aave integration.
- **Deployment Scripts** — Easy setup for local, testnet, and production deployments.

### 🚧 Planned / In Progress

- **Governance Module** — DAO-controlled `diamondCut` via Timelock.
- **Additional Strategies** — Uniswap LP, Compound, Convex, etc.
- **CRE Automation** — Full Chainlink Runtime Environment integration for keepers.
- **Yield Optimization** — Auto-compounding and dynamic rebalancing.
- **Oracle Integration** — Chainlink price feeds for multi-asset vaults.

---

## 🧪 Testing

### Test Coverage

| Module | Tests | Coverage |
|--------|-------|----------|
| **Diamond Core** | `DiamondCore.t.sol` | Loupe, cuts, selectors |
| **Vault (ERC-4626)** | `Vault4626Diamond.t.sol` | Deposits, withdrawals, conversions |
| **Shares (ERC-20)** | Built into vault tests | Transfers, approvals, balances |
| **Strategy Manager** | `StrategyManagerDiamond.t.sol` | Registration, allocation, harvest |
| **Aave Strategy** | `AaveV3StrategyDiamond.t.sol` | Supply, withdraw, harvest, edge cases |
| **Storage Safety** | `StorageSafetyAudit.t.sol` | Safe upgrades vs. broken patterns |
| **Share Accounting** | `ShareAccountingHardening.t.sol` | Math precision, edge cases |
| **Fork Tests** | `test/fork test/AaveV3StrategyFork.t.sol` | Real Aave on Sepolia |

### Running Tests

```bash
# All tests
forge test

# Specific file
forge test --match-path test/AaveV3StrategyDiamond.t.sol

# Specific test function
forge test --match-contract AaveV3StrategyFork --match-function test_allocateToAaveSupplies

# Verbose output (shows call traces)
forge test -vv

# Very verbose (shows storage reads/writes)
forge test -vvv

# With coverage
forge coverage

# Gas snapshots
forge snapshot
```

---

## 🚀 Deployment

### Local Development (Anvil)

```bash
# Terminal 1: Start local node
cd Diamond-Vault-Contracts
anvil

# Terminal 2: Deploy to local node
forge script script/DeployDiamondVault.s.sol:DeployDiamondVault \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb476c6b8d6c1f02d45b19e5c9d9e \
  --broadcast
```

> ⚠️ **Disclaimer:** The private key shown above (`0xac0974bec39a17e36ba4a6b4d238ff944bacb476c6b8d6c1f02d45b19e5c9d9e`) is a **dummy test key provided by Anvil**. This key is publicly known and should **NEVER** be used on testnet or mainnet. For local development only. Always use secure key management (e.g., hardware wallets, encrypted keystores) for real deployments.

### Testnet Deployment (Sepolia)

```bash
# 1. Set your environment
export SEPOLIA_RPC_URL="https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY"
export ACCOUNT="your-keystore-name"  # From `cast wallet list`

# 2. Deploy fresh vault
forge script script/DeployDiamondVault.s.sol:DeployDiamondVault \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --account "$ACCOUNT" \
  --broadcast \
  --verify \
  -vv

# 3. (Optional) Register Aave strategy during deployment
REGISTER_AAVE_STRATEGY=true \
AAVE_POOL=0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951 \
AAVE_ATOKEN=0x16dA4541aD1807f4443d92D26044C1147406EB80 \
VAULT_ASSET=0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8 \
KEEPER=0x3554E6C880951D15fD82df8464bF775d3C6F4dC5 \
forge script script/DeployDiamondVault.s.sol:DeployDiamondVault \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --account "$ACCOUNT" \
  --broadcast \
  -vv

# 4. Add new facet to existing vault
DIAMOND=0x435e3A5b247F4F035C9234aDcf0B4a75BbeD5781 \
KEEPER=0x3554E6C880951D15fD82df8464bF775d3C6F4dC5 \
forge script script/AddStrategyKeeperFacet.s.sol:AddStrategyKeeperFacet \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --account "$ACCOUNT" \
  --broadcast \
  -vv
```

See [Diamond-Vault-Contracts/README.md](Diamond-Vault-Contracts/README.md#deployment) for more details.

---

## 📚 Documentation

### Core Docs

- **[Contracts README](Diamond-Vault-Contracts/README.md)** — Detailed contract architecture, facets, usage examples, and API reference.
- **[Storage Layout & Safety](Diamond-Vault-Contracts/docs/storage-layout.md)** — How storage works, the append-only rule, and why it matters. Includes proofs of what breaks upgrades.
- **[Roles & Incident Response](Diamond-Vault-Contracts/docs/roles-and-incident-response.md)** — Owner/Guardian/Keeper roles, permission matrix, and incident playbooks.
- **[CRE Automation](Diamond-Vault-CRE/README.md)** — Chainlink Runtime Environment setup for keepers and automation.

### External References

- [ERC-2535 Diamond Standard](https://eips.ethereum.org/EIPS/eip-2535)
- [Mudgen's Diamond Reference](https://github.com/mudgen/diamond)
- [Awesome Diamonds](https://github.com/mudgen/awesome-diamonds) — 100+ live diamond projects
- [Beanstalk's Blog](https://bean.money/) — Real-world diamond patterns and lessons

---

## 🔐 Security & Safety

### Key Safety Features

1. **Append-Only Storage** — Facet upgrades cannot insert fields mid-struct. All new state goes at the end. Proven in `StorageSafetyAudit.t.sol`.
2. **One Guardian Address** — Emergency powers are concentrated and auditable, not scattered across many storage slots.
3. **Fail-Closed on Doubt** — If accounting is wrong, deposits are paused, not liquidity pulled.
4. **Granular Pause Controls** — Can pause deposits without blocking withdrawals, or vice versa.
5. **Strategy Isolation** — Bugs in one strategy facet don't affect core vault logic; can be replaced independently.
6. **On-Chain Introspection** — DiamondLoupe provides runtime visibility of what functions are available.

### Known Limitations

- **No automatic compounding** — Harvests must be triggered by owner or keeper; yields don't auto-reinvest in v1.
- **Single-asset vault** — Current implementation is designed for one underlying asset (USDC). Multi-asset is future work.
- **Governance not live** — Owner is currently a single address; Timelock/DAO governance is planned.
- **Aave-only strategy** — Only Aave V3 is implemented; more strategies planned.

### Audit & Testing

- **200+ Tests** — Foundry suite covers core logic, edge cases, and upgrade safety.
- **Fork Tests** — Optional mainnet fork validation against live Aave.
- **Storage Audit** — Dedicated test suite (`StorageSafetyAudit.t.sol`) proves the append-only rule and demos breaking patterns.

---

## 🛠️ Development

### Project Structure Best Practices

- **Facets are stateless** — All logic, no state. State lives in shared `VaultStorage`.
- **Libraries for shared code** — `LibVaultStorage`, `LibStrategyStorage` are used across facets.
- **Interfaces for each facet** — Each facet has a corresponding `IFacetName` interface.
- **Mocks for testing** — `MockUSDC`, `MockAavePool`, `MockAToken` enable deterministic local tests.
- **BROKEN fixtures for safety** — `*_BROKEN.sol` files intentionally break storage patterns to demonstrate hazards.

### Adding a New Facet

1. **Create the facet** — `src/strategy/facets/MyNewStrategyFacet.sol`
2. **Define the interface** — `src/strategy/interfaces/IMyNewStrategyFacet.sol`
3. **Write tests** — `test/MyNewStrategyDiamond.t.sol`
4. **Create upgrade script** — `script/AddMyNewStrategyFacet.s.sol`
5. **Never insert storage fields mid-struct** — Always append to the end.
6. **Deploy via `diamondCut`** — Only owner can execute the upgrade.

See [Diamond-Vault-Contracts/README.md](Diamond-Vault-Contracts/README.md#adding-a-facet) for step-by-step.

### Formatting & Linting

```bash
forge fmt
```

---

## 🤝 Contributing

### Code Style

- **Solidity**: Follow OpenZeppelin conventions. Use `forge fmt`.
- **Tests**: Use descriptive test names like `test_withdrawPullsFromAaveWhenIdleCashIsNotEnough`.
- **Comments**: Document public functions and complex logic.
- **Errors**: Use custom errors (not require strings) for gas efficiency.

### Pull Request Process

1. Create a feature branch: `git checkout -b feature/my-feature`
2. Make changes and test: `forge test`
3. Format code: `forge fmt`
4. Push and open a PR with a clear description.
5. Ensure CI passes and all tests are green.

### Reporting Issues

If you find a bug or have a suggestion:

1. Check existing [issues](../../issues).
2. Create a new issue with a clear title, description, and reproduction steps.
3. For security issues, please report privately (do not open public issues).

---

## 📋 Roadmap

- [x] Core diamond proxy & facet system
- [x] ERC-4626 vault implementation
- [x] Strategy manager & registry
- [x] Aave V3 strategy facet
- [x] Emergency pause controls
- [x] Comprehensive test suite
- [x] Storage safety audit
- [x] Deployment scripts
- [ ] Governance (Timelock/DAO) upgrade controls
- [ ] Additional strategy facets (Uniswap, Compound, Convex)
- [ ] Full CRE automation
- [ ] Multi-asset vault support
- [ ] Oracle integration (Chainlink)
- [ ] Mainnet deployment

---

## 📞 Support & Questions

- **Documentation**: See links above.
- **Issues**: [GitHub Issues](../../issues)
- **Discussions**: [GitHub Discussions](../../discussions)

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.

---

**Built with [Foundry](https://book.getfoundry.sh/), [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/5.x/), and the [ERC-2535 Diamond Standard](https://eips.ethereum.org/EIPS/eip-2535).**
