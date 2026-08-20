# Diamond Vault Contracts

This Foundry workspace contains the complete smart contract implementation of DiamondVault: the ERC-2535 Diamond Proxy core, vault facets, pause-control modules, strategy management system, local test doubles (mocks), and comprehensive test suite.

**Status:** Production-ready Solidity contracts with 200+ tests and full storage-safety audit coverage.

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Directory Structure](#-directory-structure)
- [Setup & Installation](#-setup--installation)
- [Building & Testing](#-building--testing)
- [Deployment](#-deployment)
- [Contract Architecture](#-contract-architecture)
- [Storage & Safety](#-storage--safety)
- [API Reference](#-api-reference)
- [Troubleshooting](#-troubleshooting)

---

## 🎯 Overview

This package contains:

1. **Diamond Proxy Core** — The eternal upgradeable proxy that all users interact with (one address forever).
2. **Vault Facets** — ERC-20 share token and ERC-4626 vault logic for deposits/withdrawals.
3. **Strategy Facets** — Pluggable yield strategy implementations (Aave V3, mock, keeper automation).
4. **Management Facets** — Owner, pause controls, and strategy registry.
5. **Mock Contracts** — USDC, Aave Pool, and aToken doubles for deterministic testing.
6. **Tests** — 200+ Foundry tests covering core logic, upgrades, and edge cases.
7. **Deployment Scripts** — Hardhat-style forge scripts for local/testnet/mainnet deployment.
8. **Documentation** — Storage layout, roles, and incident response playbooks.

---

## 📂 Directory Structure

```
Diamond-Vault-Contracts/
├── src/
│   ├── diamond/                       ← ERC-2535 proxy infrastructure
│   │   ├── Diamond.sol                ← Proxy entry point (fallback + delegatecall)
│   │   ├── facets/
│   │   │   ├── DiamondCutFacet.sol    ← Upgrade logic (diamondCut)
│   │   │   ├── DiamondLoupeFacet.sol  ← Introspection (facets, selectors)
│   │   │   └── OwnershipFacet.sol     ← Owner management
│   │   ├── interfaces/
│   │   │   ├── IDiamondCut.sol
│   │   │   ├── IDiamondLoupe.sol
│   │   │   └── IERC173.sol            ← Standard owner interface
│   │   ├── libraries/
│   │   │   └── LibDiamond.sol         ← Diamond storage & upgrade logic
│   │   └── upgrade/
│   │       └── DiamondInit.sol        ← Initialization on first cut
│   │
│   ├── vault/                         ← Vault logic (ERC-20 + ERC-4626)
│   │   ├── facets/
│   │   │   ├── VaultShareFacet.sol    ← ERC-20 transfers, approvals, balances
│   │   │   ├── Vault4626Facet.sol     ← ERC-4626 deposits, withdrawals, conversions
│   │   │   ├── VaultPauseFacet.sol    ← Emergency pause controls
│   │   │   ├── Vault4626FacetV2_BROKEN.sol   ← [Audit fixture] bad upgrade example
│   │   │   └── VaultShareFacetV2_BROKEN.sol  ← [Audit fixture] broken storage upgrade
│   │   ├── interfaces/
│   │   │   ├── IVault.sol
│   │   │   ├── IVaultShare.sol
│   │   │   ├── IVault4626.sol         ← ERC-4626 interface
│   │   │   └── IVaultPauseAdmin.sol
│   │   ├── libraries/
│   │   │   ├── LibVaultStorage.sol    ← Canonical storage layout
│   │   │   ├── LibVaultStorage_BROKEN.sol ← [Audit fixture] broken layout
│   │   │   └── LibVaultMath.sol       ← Vault accounting math
│   │   └── upgrade/
│   │       └── VaultInit.sol          ← Initialize vault on diamondCut
│   │
│   ├── strategy/                      ← Strategy system
│   │   ├── facets/
│   │   │   ├── StrategyManagerFacet.sol    ← Strategy registry, allocation, harvest
│   │   │   ├── AaveV3StrategyFacet.sol     ← Aave V3 integration (supply, withdraw, harvest)
│   │   │   ├── StrategyKeeperFacet.sol     ← Automation entry point (CRE/keeper)
│   │   │   └── MockStrategyFacet.sol       ← Deterministic mock for testing
│   │   ├── interfaces/
│   │   │   ├── IStrategyManager.sol   ← Register, allocate, harvest
│   │   │   ├── IAaveV3StrategyFacet.sol
│   │   │   ├── IStrategyKeeper.sol
│   │   │   ├── IAavePool.sol          ← Aave Pool interface
│   │   │   └── IAaveAToken.sol
│   │   └── libraries/
│   │       └── LibStrategyStorage.sol ← Strategy state & debt tracking
│   │
│   ├── mocks/                         ← Test doubles for deterministic testing
│   │   ├── MockUSDC.sol               ← ERC-20 token
│   │   ├── MockAavePool.sol           ← Aave Pool behavior
│   │   └── MockAToken.sol             ← Interest-bearing token
│   │
│   └── cre/                           ← CRE-related utilities
│       └── CREReceiver.sol            ← Chainlink CRE receiver contract
│
├── test/                              ← Foundry test suite (200+ tests)
│   ├── DiamondCore.t.sol              ← Proxy cuts, loupe, selectors
│   ├── Vault4626Diamond.t.sol         ← ERC-4626 deposit/withdraw/convert
│   ├── AaveV3StrategyDiamond.t.sol    ← Aave allocation, harvest, liquidity pull
│   ├── StrategyManagerDiamond.t.sol   ← Strategy registration & management
│   ├── StorageSafetyAudit.t.sol       ← Proves append-only rule, demos breakage
│   ├── ShareAccountingHardening.t.sol ← Share math edge cases & precision
│   ├── CREReceiverUnit.t.sol          ← Receiver contract tests
│   ├── fork test/
│   │   └── AaveV3StrategyFork.t.sol   ← Live Aave on Sepolia (optional)
│   └── unit/                          ← Isolated unit tests
│
├── script/                            ← Deployment & upgrade scripts
│   ├── DeployDiamondVault.s.sol       ← Fresh deployment (diamond + all facets)
│   ├── AddStrategyKeeperFacet.s.sol   ← Add keeper to existing diamond
│   ├── UpgradeStrategyManager.s.sol   ← Replace strategy facet
│   ├── HelperConfig.s.sol             ← Network config & deployment helpers
│   └── DeployCREReceiver.s.sol        ← Deploy CRE receiver
│
├── docs/
│   ├── storage-layout.md              ← Detailed storage, append-only rule, examples
│   └── roles-and-incident-response.md ← Roles, permissions, incident playbooks
│
├── foundry.toml                       ← Foundry config
├── foundry.lock                       ← Dependency lock
├── .env                               ← Local environment (DO NOT COMMIT)
└── README.md                          ← This file
```

---

## ⚙️ Setup & Installation

### Prerequisites

- **Foundry** (forge, cast, anvil): https://book.getfoundry.sh/getting-started/installation
- **Git**
- **Solidity 0.8.20+** (built-in with Foundry)

### 1. Clone Repository

```bash
git clone <repo-url>
cd DiamondVault/Diamond-Vault-Contracts
```

### 2. Install Dependencies

```bash
forge install
```

This pulls in:
- `openzeppelin-contracts/` — ERC-20, ERC-4626, math utilities
- `forge-std/` — Foundry testing framework
- `foundry-devops/` — Deployment helpers

### 3. Create Local .env

```bash
cp .env.example .env  # if one exists
# OR create manually:
echo "SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY" >> .env
echo "ACCOUNT=your-keystore-name" >> .env
```

The `.env` file is local-only and excluded by `.gitignore`.

---

## 🔨 Building & Testing

### Build

```bash
forge build
```

Output goes to `out/`. Contracts are compiled to their ABI and bytecode.

### Test (All)

```bash
forge test
```

**Expected Output:**
```
Compiling...
No files changed, compilation skipped

Ran 200+ tests in ~30s: All passed ✓
```

### Test (Specific File)

```bash
# Vault ERC-4626 tests
forge test --match-path test/Vault4626Diamond.t.sol -vv

# Aave strategy tests
forge test --match-path test/AaveV3StrategyDiamond.t.sol -vv

# Storage safety audit
forge test --match-path test/StorageSafetyAudit.t.sol -vv

# Share accounting edge cases
forge test --match-path test/ShareAccountingHardening.t.sol -vv
```

### Test (Specific Function)

```bash
forge test --match-contract AaveV3StrategyFork \
  --match-function test_allocateToAaveSuppliesUnderlyingAndTracksDebt -vv
```

### Test Verbosity Levels

```bash
forge test                  # Summary only
forge test -v              # Logs & events
forge test -vv             # Logs + call traces
forge test -vvv            # Logs + storage reads/writes
forge test -vvvv           # Full verbosity
```

### Coverage

```bash
forge coverage
```

Generates coverage reports for each file. Useful for identifying untested code paths.

### Gas Snapshots

```bash
forge snapshot
```

Generates `gas-snapshots.txt`. Run before/after optimizations to compare gas usage.

### Optional Fork Tests (Live Aave)

Requires RPC endpoint with Sepolia archive data.

```bash
# Set your RPC
export SEPOLIA_RPC_URL="https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY"

# Run fork tests
forge test --match-path 'test/fork test/AaveV3StrategyFork.t.sol' -vv

# Skip fork tests (run only local mocks)
forge test --no-match-path 'test/fork test/*'
```

**Note:** Fork tests are optional. Local mocks provide 99% coverage; fork tests validate against live Aave state.

### Formatting

```bash
# Format all Solidity files
forge fmt

# Check formatting (no changes)
forge fmt --check
```

---

## 🚀 Deployment

### Local Node (Anvil)

```bash
# Terminal 1: Start local node (runs forever)
cd Diamond-Vault-Contracts
anvil

# Terminal 2: Deploy to local node
forge script script/DeployDiamondVault.s.sol:DeployDiamondVault \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb476c6b8d6c1f02d45b19e5c9d9e \
  --broadcast
```

> ⚠️ **Disclaimer:** The private key shown above (`0xac0974bec39a17e36ba4a6b4d238ff944bacb476c6b8d6c1f02d45b19e5c9d9e`) is a **dummy test key provided by Anvil**. This key is publicly known and should **NEVER** be used on testnet or mainnet. For local development only. Always use secure key management (e.g., hardware wallets, encrypted keystores) for real deployments.

**Output:**
```
Deploying Diamond to http://127.0.0.1:8545
✓ Diamond deployed at 0x...
✓ VaultShareFacet deployed at 0x...
✓ Vault4626Facet deployed at 0x...
...
```

### Testnet (Sepolia)

#### Option A: Fresh Vault

```bash
# 1. Set environment
source .env

# 2. Deploy
forge script script/DeployDiamondVault.s.sol:DeployDiamondVault \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --account "$ACCOUNT" \
  --broadcast \
  --verify \
  -vv
```

#### Option B: With Aave Strategy

```bash
source .env

VAULT_ASSET=0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8 \
REGISTER_AAVE_STRATEGY=true \
AAVE_POOL=0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951 \
AAVE_ATOKEN=0x16dA4541aD1807f4443d92D26044C1147406EB80 \
KEEPER=0x3554E6C880951D15fD82df8464bF775d3C6F4dC5 \
forge script script/DeployDiamondVault.s.sol:DeployDiamondVault \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --account "$ACCOUNT" \
  --broadcast \
  --verify \
  -vv
```

#### Option C: Add Facet to Existing Diamond

```bash
source .env

DIAMOND=0x435e3A5b247F4F035C9234aDcf0B4a75BbeD5781 \
KEEPER=0x3554E6C880951D15fD82df8464bF775d3C6F4dC5 \
forge script script/AddStrategyKeeperFacet.s.sol:AddStrategyKeeperFacet \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --account "$ACCOUNT" \
  --broadcast \
  --verify \
  -vv
```

### Deployment Script Reference

| Script | Purpose | Key Env Vars |
|--------|---------|---------------|
| `DeployDiamondVault.s.sol` | Fresh deployment with all core facets | `VAULT_ASSET`, `KEEPER`, `REGISTER_AAVE_STRATEGY`, `AAVE_POOL`, `AAVE_ATOKEN` |
| `AddStrategyKeeperFacet.s.sol` | Add keeper facet to existing diamond | `DIAMOND`, `KEEPER` |
| `UpgradeStrategyManager.s.sol` | Replace strategy manager facet | `DIAMOND`, `MANAGER_ADDRESS` |
| `DeployCREReceiver.s.sol` | Deploy standalone CRE receiver | N/A |

---

## 🏗️ Contract Architecture

### Diamond Proxy Flow

```
User calls: diamond.deposit(amount)
         ↓
    Diamond (fallback)
         ↓
    Lookup: deposit(uint256,address) → Vault4626Facet
         ↓
    Vault4626Facet.deposit() [delegatecall]
         ↓
    Read/write VaultStorage at Diamond address
         ↓
    Return (shares minted)
```

### Facet Interactions

```
VaultShareFacet (ERC-20 logic)
    ├─ balanceOf(address)
    ├─ transfer(address, uint256)
    ├─ approve(address, uint256)
    └─ transferFrom(address, address, uint256)

Vault4626Facet (ERC-4626 logic)
    ├─ deposit(uint256, address) → shares
    ├─ withdraw(uint256, address, address) → shares
    ├─ redeem(uint256, address, address) → assets
    ├─ totalAssets() → uint256
    ├─ convertToShares(uint256) → uint256
    └─ convertToAssets(uint256) → uint256

VaultPauseFacet (Emergency controls)
    ├─ setDepositsPaused(bool)
    ├─ setWithdrawalsPaused(bool)
    ├─ setShareTransfersPaused(bool)
    └─ pauseState() → (bool, bool, bool)

StrategyManagerFacet (Strategy system)
    ├─ registerStrategy(bytes32, bytes4, bytes4, bytes4)
    ├─ allocateToStrategy(bytes32, uint256) → assets
    ├─ freeFundsFromStrategy(bytes32, uint256) → assets
    ├─ harvestStrategy(bytes32) → (assets, gain, loss)
    └─ strategyState(bytes32) → (...)

AaveV3StrategyFacet (Aave integration)
    ├─ aaveV3StrategyDeploy(bytes32, uint256) → assets
    ├─ aaveV3StrategyFreeFunds(bytes32, uint256) → assets
    ├─ aaveV3StrategyHarvest(bytes32) → (assets, gain, loss)
    └─ setAaveV3StrategyConfig(...)
```

### Storage Layout

See [docs/storage-layout.md](docs/storage-layout.md) for full details. Key points:

- **VaultStorage** at `keccak256("diamondvault.vault.storage")` — user balances, allowances, name, symbol, supply.
- **StrategyStorage** at `keccak256("diamondvault.strategy.storage")` — strategy registry, debt tracking.
- **DiamondStorage** at `keccak256("diamondvault.diamond.storage")` — facet mappings, owner.
- **Append-only rule** — New state always appends to the end of structs. Never insert mid-struct or mappings shift.

---

## 🔐 Storage & Safety

### The Append-Only Rule

**Critical:** When upgrading facets, NEVER insert fields in the middle of a struct. Only append at the end.

**Why?** Solidity's mapping slots are computed at compile time using the logical slot position. Inserting a field shifts all following mappings by one or more slots, breaking all existing data.

#### Example: What Breaks

```solidity
// V1 (original)
struct VaultStorage {
    address asset;              // Slot 0
    uint8 decimals;             // Slot 1
    mapping balances;           // Slot 2+
}
// Alice's balance at: keccak256(alice, 2)

// V2 (BROKEN - inserted field mid-struct)
struct VaultStorage {
    address asset;              // Slot 0
    uint8 decimals;             // Slot 1
    uint256 newField;           // Slot 2 ← INSERTED HERE!
    mapping balances;           // Slot 3+ ← NOW SHIFTED!
}
// Alice's balance now at: keccak256(alice, 3) ← DIFFERENT!
// Result: Alice's balance appears as 0. FUNDS LOST.
```

#### Example: What Works

```solidity
// V2 (CORRECT - appended at end)
struct VaultStorage {
    address asset;              // Slot 0
    uint8 decimals;             // Slot 1
    mapping balances;           // Slot 2+
    uint256 newField;           // Slot 4 ← APPENDED AT END
}
// Alice's balance still at: keccak256(alice, 2) ✓
```

**Proof:** See [StorageSafetyAudit.t.sol](test/StorageSafetyAudit.t.sol) — this test compares storage under safe vs. broken upgrades and demonstrates the corruption.

### Safety Practices

1. **Always append, never insert** — Make this a mantra before every upgrade.
2. **Review `LibVaultStorage.sol`** — Understand the current layout before extending it.
3. **Run `StorageSafetyAudit.t.sol`** — Proves your upgrade is safe.
4. **Use version comments** — Document when each field was added (e.g., `// V1`, `// V2`).

---

## 📖 API Reference

### Vault4626Facet (ERC-4626)

```solidity
// Deposit
function deposit(uint256 assets, address receiver) external returns (uint256 shares);

// Withdraw
function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);

// Redeem
function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);

// View: Total assets in vault
function totalAssets() external view returns (uint256);

// Conversion: Assets → Shares
function convertToShares(uint256 assets) external view returns (uint256);

// Conversion: Shares → Assets
function convertToAssets(uint256 shares) external view returns (uint256);

// Max deposit (unlimited in current implementation)
function maxDeposit(address) external view returns (uint256);

// Max withdraw
function maxWithdraw(address owner) external view returns (uint256);

// Max redeem
function maxRedeem(address owner) external view returns (uint256);

// Preview functions (no state changes)
function previewDeposit(uint256 assets) external view returns (uint256);
function previewWithdraw(uint256 assets) external view returns (uint256);
function previewMint(uint256 shares) external view returns (uint256);
function previewRedeem(uint256 shares) external view returns (uint256);
```

### VaultShareFacet (ERC-20)

```solidity
// Transfer
function transfer(address to, uint256 amount) external returns (bool);

// Transfer from (with approval)
function transferFrom(address from, address to, uint256 amount) external returns (bool);

// Approve
function approve(address spender, uint256 amount) external returns (bool);

// Metadata
function name() external view returns (string memory);
function symbol() external view returns (string memory);
function decimals() external view returns (uint8);
function totalSupply() external view returns (uint256);

// Balances
function balanceOf(address account) external view returns (uint256);
function allowance(address owner, address spender) external view returns (uint256);
```

### StrategyManagerFacet

```solidity
// Register a new strategy
function registerStrategy(
    bytes32 strategyId,
    bytes4 deploySelector,      // How to allocate
    bytes4 freeFundsSelector,   // How to withdraw
    bytes4 harvestSelector      // How to claim yields
) external;

// Allocate capital to strategy
function allocateToStrategy(bytes32 strategyId, uint256 amount) external returns (uint256 assets);

// Withdraw capital from strategy
function freeFundsFromStrategy(bytes32 strategyId, uint256 amount) external returns (uint256 assets);

// Claim yields from strategy
function harvestStrategy(bytes32 strategyId) external returns (uint256 assets, uint256 gain, uint256 loss);

// Query strategy state
function strategyState(bytes32 strategyId) external view returns (
    bool registered,
    bool active,
    bool allocationsPaused,
    bool frozen,
    uint256 debt,
    bytes4 deploySelector,
    bytes4 freeFundsSelector,
    bytes4 harvestSelector
);

// Get total debt across all strategies
function totalStrategyDebt() external view returns (uint256);
```

### VaultPauseFacet (Emergency Controls)

```solidity
// Set guardian (only owner)
function setGuardian(address newGuardian) external;

// Get current guardian
function guardian() external view returns (address);

// Pause/unpause deposits and mints
function setDepositsPaused(bool paused) external;
function depositsPaused() external view returns (bool);

// Pause/unpause withdrawals and redeems
function setWithdrawalsPaused(bool paused) external;
function withdrawalsPaused() external view returns (bool);

// Pause/unpause share transfers
function setShareTransfersPaused(bool paused) external;
function shareTransfersPaused() external view returns (bool);

// Get all pause states
function pauseState() external view returns (bool deposits, bool withdrawals, bool transfers);
```

### AaveV3StrategyFacet

```solidity
// Configure Aave pool and aToken for this strategy
function setAaveV3StrategyConfig(
    bytes32 strategyId,
    address pool,
    address aToken
) external;

// Get config for a strategy
function aaveV3StrategyConfig(bytes32 strategyId) external view returns (address pool, address aToken);

// Deploy (allocate) capital to Aave
function aaveV3StrategyDeploy(bytes32 strategyId, uint256 amount) external returns (uint256 assets);

// Harvest yields from Aave
function aaveV3StrategyHarvest(bytes32 strategyId) external returns (uint256 assets, uint256 gain, uint256 loss);

// Free funds (withdraw) from Aave
function aaveV3StrategyFreeFunds(bytes32 strategyId, uint256 amount) external returns (uint256 assets);
```

---

## 🐛 Troubleshooting

### Issue: Fork Tests Fail with "File not found"

**Symptom:**
```
Error: Source "forge-std/Test.sol" not found
```

**Solution:** Ensure you ran `forge install`:
```bash
forge install
forge build
```

### Issue: "Test execution revert code: 51"

**Symptom:** Fork tests fail with error code 51 from Aave.

**Cause:** Aave reserve state issue or outdated RPC fork.

**Solution:**
1. Update your RPC endpoint to latest block: `vm.createSelectFork(rpcUrl);` or pin to a specific block.
2. Verify RPC is working: `curl -X POST $SEPOLIA_RPC_URL -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'`
3. Try a different RPC provider (Infura, Alchemy, etc.).

### Issue: "Deployed contract hash mismatch"

**Symptom:** Deployment verification fails.

**Solution:** Run without `--verify` first:
```bash
forge script script/DeployDiamondVault.s.sol:DeployDiamondVault \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --account "$ACCOUNT" \
  --broadcast
```

Then verify manually after deployment is confirmed.

### Issue: "Out of memory" during compilation

**Symptom:** Large projects fail to compile.

**Solution:** Increase system memory or compile incrementally:
```bash
forge clean
forge build --no-cache
```

### Issue: Permission Denied when Unlocking Keystore

**Symptom:** `forge` can't access wallet keys.

**Solution:** Use `--private-key` instead or check keystore permissions:
```bash
chmod 600 ~/.foundry/keystore/*
```

### Issue: Strategy Allocation Reverts with "Unknown Error"

**Symptom:** `allocateToStrategy()` fails silently.

**Cause:** Strategy selector not properly registered or facet code changed.

**Solution:**
1. Verify strategy is registered: `strategyState(strategyId)` should show `active=true`.
2. Check selector matches function signature:
   ```bash
   cast sig 'aaveV3StrategyDeploy(bytes32,uint256)'
   # Should match registered selector
   ```
3. Verify Aave pool has liquidity for withdrawals.

---

## 📚 Additional Resources

- **[Storage Layout & Safety](docs/storage-layout.md)** — Deep dive into storage, the append-only rule, and upgrade gotchas.
- **[Roles & Incident Response](docs/roles-and-incident-response.md)** — Owner, Guardian, Keeper roles and emergency procedures.
- **[ERC-2535 Diamond Standard](https://eips.ethereum.org/EIPS/eip-2535)** — Full specification.
- **[Mudgen's Diamond Reference](https://github.com/mudgen/diamond)** — Reference implementation.
- **[OpenZeppelin ERC-4626](https://docs.openzeppelin.com/contracts/5.x/erc4626)** — Vault standard docs.

---

## 🔗 Quick Links

- **Parent Documentation:** [../README.md](../README.md)
- **CRE Workflow:** [../Diamond-Vault-CRE/README.md](../Diamond-Vault-CRE/README.md)
- **Storage & Safety:** [docs/storage-layout.md](docs/storage-layout.md)
- **Roles & Incidents:** [docs/roles-and-incident-response.md](docs/roles-and-incident-response.md)

---

**Built with [Foundry](https://book.getfoundry.sh/), [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/5.x/), and [ERC-2535 Diamond Standard](https://eips.ethereum.org/EIPS/eip-2535).**
