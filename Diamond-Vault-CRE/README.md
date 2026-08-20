# 🔗 Diamond Vault CRE (Chainlink Runtime Environment)

This directory contains the **Chainlink Runtime Environment** setup for DiamondVault automation, keeper operations, and operational workflows.

The CRE enables trustless, decentralized execution of protocol operations (harvests, rebalances, state updates) via Chainlink's secure off-chain infrastructure.

**Status:** Scaffolded and ready for extension. Core contracts deployed and tested; automation workflows are templates for custom keeper logic.

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Directory Structure](#-directory-structure)
- [Setup & Installation](#-setup--installation)
- [Local Development](#-local-development)
- [Deployment](#-deployment)
- [CRE Workflow Reference](#-cre-workflow-reference)
- [Integration Guide](#-integration-guide)
- [Troubleshooting](#-troubleshooting)

---

## 🎯 Overview

The Diamond Vault CRE module enables:

1. **Keeper Operations** — Automated harvest, rebalance, and liquidation through Chainlink nodes.
2. **Event Monitoring** — Watch on-chain events and trigger off-chain logic.
3. **State Synchronization** — Sync vault state, strategy debts, and yield metrics off-chain for analytics.
4. **Governance Integration** — Execute DAO proposals that perform diamondCut upgrades.
5. **Incident Response** — Automated alerting and emergency pause triggers for protocol safety.

### Why CRE?

- **Decentralized** — Runs on Chainlink's Verifiable Randomness + DON (Decentralized Oracle Network).
- **Trustless** — Keepers cannot deviate from approved workflows; logic is immutable.
- **Redundancy** — Multiple independent Chainlink nodes execute in parallel; no single point of failure.
- **Cost-Efficient** — Pay only for execution; no standing contracts or subscription fees.
- **Flexible** — Custom workflows for any operation: harvests, rebalances, liquidations, governance.

---

## 📂 Directory Structure

```
Diamond-Vault-CRE/
├── Diamond-Vault-workflow/        ← TypeScript CRE workflow
│   ├── src/
│   │   ├── index.ts               ← Main workflow entry point
│   │   ├── types.ts               ← TypeScript interfaces & types
│   │   ├── contracts/
│   │   │   └── ABI.json           ← Diamond Vault ABI for calls
│   │   ├── actions/
│   │   │   ├── harvestStrategy.ts ← Harvest yields from strategy
│   │   │   ├── allocateToStrategy.ts ← Allocate capital
│   │   │   └── pauseVault.ts      ← Emergency pause
│   │   └── utils/
│   │       ├── logger.ts          ← Logging utilities
│   │       └── config.ts          ← Load environment
│   ├── test/
│   │   └── workflow.test.ts       ← Unit tests
│   ├── package.json
│   ├── tsconfig.json
│   ├── bun.lockb                  ← Bun lock file
│   └── README.md                  ← Workflow-specific docs
│
├── CREReceiver.sol (symlink from contracts/src/cre/)  ← Receives CRE calls
├── CREReceiver.t.sol (symlink from contracts/test/)   ← Tests CRE receiver
│
├── project.yaml                   ← CRE project config (targets, networks, settings)
├── secrets.yaml                   ← CRE secrets (DO NOT COMMIT)
├── secrets.example.yaml           ← Template for secrets
├── .env                           ← Local environment (DO NOT COMMIT)
├── .env.example                   ← Template for .env
├── .gitignore
└── README.md                      ← This file
```

---

## ⚙️ Setup & Installation

### Prerequisites

- **Bun** (TypeScript runtime): https://bun.sh/
  ```bash
  curl -fsSL https://bun.sh/install | bash
  ```
  
- **Node.js 18+** (as fallback if Bun unavailable)
- **CRE CLI**: https://docs.chain.link/chainlink-automation/cre/getting-started
  ```bash
  npm install -g @chainlink/cre-cli
  ```

- **Solidity Contracts** (Diamond Vault deployed on target network)

### 1. Clone & Install

```bash
cd DiamondVault/Diamond-Vault-CRE

# Install workflow dependencies
cd Diamond-Vault-workflow
bun install
# OR with npm:
npm install
```

### 2. Configure Secrets

```bash
cd ..
cp secrets.example.yaml secrets.yaml
cp .env.example .env
```

Edit `secrets.yaml` and `.env` with your network RPC, private keys, and Diamond Vault contract address.

```yaml
# secrets.yaml
networks:
  sepolia:
    rpcUrl: "https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY"
    privateKey: "0x..."
    diamondVault: "0x..."
    aavePool: "0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951"
```

### 3. Verify Setup

```bash
cd Diamond-Vault-workflow
bun run test
```

Expected output:
```
✓ Workflow unit tests pass
✓ Harvest action loads correctly
✓ Config loads from environment
```

---

## 🧪 Local Development

### Run Unit Tests

```bash
cd Diamond-Vault-workflow
bun run test
```

### Simulate Workflow Locally

```bash
# Simulate a harvest operation
cre workflow simulate Diamond-Vault-workflow \
  --target harvest-aave-strategy \
  --network sepolia
```

This runs your workflow against a local fork of the network without broadcasting actual transactions.

### Interactive Development

```bash
cd Diamond-Vault-workflow
bun repl
```

Load and test individual workflow actions:
```typescript
> const { harvestStrategy } = await import('./src/actions/harvestStrategy');
> await harvestStrategy({ strategyId: '0x...', keeper: '0x...' });
```

### Debugging

Enable verbose logging:
```bash
DEBUG=diamondvault:* cre workflow simulate Diamond-Vault-workflow --target harvest-aave-strategy
```

---

## 🚀 Deployment

### Deploy to Chainlink CRE (Testnet)

```bash
# 1. Build workflow
cd Diamond-Vault-workflow
bun run build

# 2. Deploy via CRE CLI
cd ..
cre workflow deploy Diamond-Vault-workflow \
  --network sepolia \
  --rpc-url $SEPOLIA_RPC_URL
```

Output:
```
✓ Workflow deployed to CRE
✓ Workflow ID: 0x...
✓ Keeper address: 0x...
✓ Status: Ready for automation
```

### Create Automation Trigger

After deployment, set up a trigger (automation job) in Chainlink CRE UI:

1. **Harvest on Timer** — Run every 24 hours
   ```typescript
   // trigger.yaml
   trigger:
     type: "cron"
     cronExpression: "0 0 * * *"  // Daily at midnight UTC
     action: "harvestStrategy"
     params:
       strategyId: "0x..."
   ```

2. **Harvest on Event** — Trigger when vault reaches yield threshold
   ```typescript
   trigger:
     type: "event"
     contract: "0x..."
     event: "StrategyAllocated"
     action: "harvestStrategy"
   ```

3. **Harvest on Interval** — Run every block N blocks
   ```typescript
   trigger:
     type: "block"
     interval: 6500  // ~24 hours on Ethereum
     action: "harvestStrategy"
   ```

### Mainnet Deployment

Before deploying to mainnet:

1. **Test on testnet** (Sepolia) thoroughly
2. **Audit workflows** — Have security team review logic
3. **Load test** — Simulate high-volume harvests
4. **Set up monitoring** — Alert on failures, high gas prices, etc.
5. **Enable gradual rollout** — Start with small allocations

```bash
# Deploy to mainnet
cre workflow deploy Diamond-Vault-workflow \
  --network mainnet \
  --rpc-url $MAINNET_RPC_URL \
  --dry-run  # First run as dry-run to verify
```

---

## 📖 CRE Workflow Reference

### Harvest Strategy Workflow

**Purpose:** Claim yields from an Aave strategy and trigger compounding.

```typescript
// src/actions/harvestStrategy.ts
export async function harvestStrategy(params: {
  strategyId: string;
  keeper: string;
}) {
  // 1. Call vault.harvestStrategy(strategyId)
  // 2. Returns: (assets, gain, loss)
  // 3. If gain > 0, rebalance automatically
  // 4. Emit event for off-chain tracking
}
```

**Trigger Examples:**
- Every 24 hours
- When yield exceeds 0.1% of AUM
- When gas price is below X wei

### Allocate to Strategy Workflow

**Purpose:** Route new deposits into a strategy when trigger fires.

```typescript
export async function allocateToStrategy(params: {
  strategyId: string;
  amount: string;
}) {
  // 1. Check vault has idle cash
  // 2. Call vault.allocateToStrategy(strategyId, amount)
  // 3. Emit allocation event
  // 4. Update off-chain state tracking
}
```

**Trigger Examples:**
- When idle cash > 10% of AUM
- Daily at fixed time
- After large user deposit

### Pause Vault Workflow

**Purpose:** Emergency pause if anomaly detected (e.g., Aave reserve drained).

```typescript
export async function pauseVault(params: {
  reason: string;
  notifyGuardian: boolean;
}) {
  // 1. Verify anomaly (e.g., aToken balance mismatch)
  // 2. Call vault.setDepositsPaused(true)
  // 3. Notify guardian/admin via Chainlink DON
  // 4. Log incident for investigation
}
```

**Automated Triggers:**
- aToken balance != tracked debt
- Aave reserve liquidity < threshold
- Unexpected revert from Aave pool

---

## 🔗 Integration Guide

### 1. Integrate Your Own Keeper Logic

Add a new action:

```typescript
// src/actions/myCustomAction.ts
export async function myCustomAction(params: {
  param1: string;
  param2: number;
}) {
  const vault = getVaultContract();
  
  // Your logic here
  const result = await vault.myFacetMethod(params.param1, params.param2);
  
  return result;
}
```

Add to workflow:

```typescript
// src/index.ts
import { myCustomAction } from './actions/myCustomAction';

export const workflow = {
  actions: {
    harvestStrategy,
    allocateToStrategy,
    pauseVault,
    myCustomAction,  // ← Add here
  },
};
```

### 2. Monitor Vault State Off-Chain

```typescript
// src/actions/syncVaultState.ts
export async function syncVaultState() {
  const vault = getVaultContract();
  
  const totalAssets = await vault.totalAssets();
  const totalSupply = await vault.totalSupply();
  const totalDebt = await vault.totalStrategyDebt();
  
  // Post to your analytics/dashboard
  await fetch('https://your-api.com/vault-state', {
    method: 'POST',
    body: JSON.stringify({ totalAssets, totalSupply, totalDebt }),
  });
}
```

### 3. Link to Governance

Trigger diamondCut upgrades via DAO:

```typescript
// src/actions/executeDiamondCut.ts
export async function executeDiamondCut(params: {
  facetCuts: FacetCut[];
  initAddress: string;
  initCalldata: string;
}) {
  const diamond = getDiamondContract();
  
  // Only callable if sender has DAO role
  const tx = await diamond.diamondCut(
    params.facetCuts,
    params.initAddress,
    params.initCalldata
  );
  
  return tx.hash;
}
```

---

## 🐛 Troubleshooting

### Issue: "Cannot find module '@chainlink/functions-toolkit'"

**Symptom:**
```
Error: Cannot find module '@chainlink/functions-toolkit'
```

**Solution:** Install dependencies:
```bash
cd Diamond-Vault-workflow
bun install
```

### Issue: Workflow Simulation Fails with "Network Timeout"

**Symptom:**
```
Error: Network request timed out (RPC)
```

**Cause:** RPC endpoint is slow or down.

**Solution:**
1. Check RPC status: `curl -X POST $RPC_URL -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'`
2. Switch to faster RPC (Alchemy, Infura, QuickNode)
3. Increase timeout in config:
   ```typescript
   // src/utils/config.ts
   const TIMEOUT_MS = 30000;  // Increase from 10000
   ```

### Issue: "Keeper private key not found"

**Symptom:**
```
Error: KEEPER_PRIVATE_KEY environment variable not set
```

**Solution:** Set in `.env`:
```bash
echo "KEEPER_PRIVATE_KEY=0x..." >> .env
source .env
```

### Issue: Harvest Fails with "Strategy not registered"

**Cause:** Strategy ID doesn't match registered strategy on vault.

**Solution:**
1. Verify strategy is registered:
   ```bash
   cast call 0x<diamond> "strategyState(bytes32)" 0x<strategyId>
   ```
2. Check strategy ID format (should be `keccak256("strategy-name")`)
3. Ensure vault deployment registered strategy (check deployment logs)

### Issue: "Insufficient idle cash for allocation"

**Symptom:** Allocation workflow fails.

**Cause:** Vault has allocated all idle funds to strategies.

**Solution:** Either:
1. Wait for harvest to complete (yields increase idle cash)
2. Lower allocation amount
3. Trigger withdrawal from a strategy first

---

## 📚 Additional Resources

- **[Chainlink CRE Docs](https://docs.chain.link/chainlink-automation/cre/)** — Full CRE documentation.
- **[Chainlink Automation](https://docs.chain.link/chainlink-automation/)** — Automation jobs and triggers.
- **[Bun Docs](https://bun.sh/docs)** — TypeScript runtime documentation.
- **[Parent README](../README.md)** — Diamond Vault overview.
- **[Contracts README](../Diamond-Vault-Contracts/README.md)** — Smart contract API reference.

---

## 🔗 Quick Links

- **Parent Documentation:** [../README.md](../README.md)
- **Contracts Documentation:** [../Diamond-Vault-Contracts/README.md](../Diamond-Vault-Contracts/README.md)
- **Storage & Safety:** [../Diamond-Vault-Contracts/docs/storage-layout.md](../Diamond-Vault-Contracts/docs/storage-layout.md)
- **Roles & Incidents:** [../Diamond-Vault-Contracts/docs/roles-and-incident-response.md](../Diamond-Vault-Contracts/docs/roles-and-incident-response.md)

---

**Built with [Bun](https://bun.sh/), [TypeScript](https://www.typescriptlang.org/), and [Chainlink CRE](https://docs.chain.link/chainlink-automation/cre/).**
