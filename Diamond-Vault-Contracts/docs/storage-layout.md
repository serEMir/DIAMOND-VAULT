# DiamondVault Storage Layout & Safety

**Milestone B: "Storage is the Boss"**

This document explains how storage works in the DiamondVault protocol and the critical rules for safe facet upgrades.

---

## Table of Contents

1. [Overview](#overview)
2. [VaultStorage Struct Layout](#vaultstorage-struct-layout)
3. [Mapping Slot Computation](#mapping-slot-computation)
4. [The Append-Only Rule](#the-append-only-rule)
5. [Common Mistakes](#common-mistakes)
6. [Upgrade Checklist](#upgrade-checklist)
7. [Proof of Concept: Storage Collision](#proof-of-concept-storage-collision)

---

## Overview

DiamondVault uses the ERC-2535 Diamond Proxy pattern with multiple facets sharing a single eternal storage address. Unlike traditional proxies, the Diamond pattern uses delegatecall to dispatch function calls to different facet implementations.

**Key insight:** Facets are stateless. They only contain logic. All state is stored at the Diamond's address in shared storage locations.

When you upgrade a facet by deploying new code, the **storage layout must not change**. If it does, all existing data becomes inaccessible or corrupted.

---

## VaultStorage Struct Layout

The `VaultStorage` struct is defined in [LibVaultStorage.sol](../src/vault/libraries/LibVaultStorage.sol) and located at a fixed storage position:

```solidity
bytes32 internal constant VAULT_STORAGE_POSITION = keccak256("diamondvault.vault.storage");
```

This ensures all facets access the same storage data regardless of which facet code is executing.

### Current Layout (V1)

```solidity
struct VaultStorage {
    address asset;                                    // Slot 0
    uint8 assetDecimals;                              // Slot 1 (packed with next field)
    uint8 __reservedShareDecimalsSlot;                // Slot 1 (packed)
    string name;                                      // Slot 2 (dynamic)
    string symbol;                                    // Slot 3 (dynamic)
    uint256 totalSupply;                              // Slot 4
    bool initialized;                                 // Slot 5 (packed, bool uses 1 byte)
    mapping(address => uint256) balances;             // Slot 5+ (keccak256 hashed)
    mapping(address => mapping(address => uint256)) allowances;  // Slot 6+ (keccak256 hashed)
}
```

### Mapping Slot Numbers

**Solidity stores mappings using keccak256 hashing.** The slot number is baked into the facet's bytecode at compile time.

For `balances` mapping at logical slot 5:
- Alice's balance: stored at `keccak256(alice, 5)` in contract storage
- Bob's balance: stored at `keccak256(bob, 5)` in contract storage

For `allowances` mapping at logical slot 6:
- Alice → Bob allowance: stored at `keccak256(keccak256(bob, 6), alice)` in contract storage

**Example calculation** (in Solidity):
```solidity
// In LibVaultStorage.sol
bytes32 balancesPosition = keccak256(abi.encodePacked(account, uint256(5)));
// balanceOf returns the value at this calculated position
```

---

## The Append-Only Rule

**GOLDEN RULE: Only add new fields at the END of the struct. Never insert fields in the middle.**

### Why This Matters

If you insert a field anywhere but the end, all subsequent mapping slots shift by one or more positions.

#### Example: Bad Upgrade (Mid-Insertion)

Original layout (V1):
```
Slot 5: bool initialized
Slot 5+: mapping balances        ← stored at keccak256(account, 5)
Slot 6+: mapping allowances      ← stored at keccak256(account, 6)
```

Broken layout (V2 with mid-insertion):
```
Slot 5: bool initialized
Slot 5: uint256 newField         ← INSERTED HERE!
Slot 6+: mapping balances        ← NOW stored at keccak256(account, 6) ❌
Slot 7+: mapping allowances      ← NOW stored at keccak256(account, 7) ❌
```

**Result:** 
- Old code reads from `keccak256(account, 5)` ✅
- New code reads from `keccak256(account, 6)` ✅ but finds ZEROS
- Alice's actual balance (1000 shares) sits untouched at `keccak256(alice, 5)`
- Alice's balance appears as 0 in the new code → **FUNDS LOST**

#### Example: Good Upgrade (Append-Only)

Original layout (V1):
```
Slot 5: bool initialized
Slot 5+: mapping balances        ← stored at keccak256(account, 5)
Slot 6+: mapping allowances      ← stored at keccak256(account, 6)
```

Fixed layout (V2 with append):
```
Slot 5: bool initialized
Slot 5+: mapping balances        ← still stored at keccak256(account, 5) ✅
Slot 6+: mapping allowances      ← still stored at keccak256(account, 6) ✅
Slot 7: uint256 newField         ← APPENDED AT END
Slot 8+: mapping newMapping      ← NEW mapping uses slot 8+
```

**Result:**
- All existing data remains at original positions ✅
- New field has fresh, uninitialized slot ✅
- Backward compatible ✅

---

## Common Mistakes

### ❌ Mistake #1: Inserting a Field in the Middle

```solidity
// WRONG - This breaks storage!
struct VaultStorage {
    address asset;
    uint8 assetDecimals;
    uint8 __reservedShareDecimalsSlot;
    string name;
    string symbol;
    uint256 totalSupply;
    bool initialized;
    uint256 trackedDeposits;  // ← INSERTED in the middle!
    mapping(address => uint256) balances;  // ← This shifts!
    mapping(address => mapping(address => uint256)) allowances;
}
```

### ❌ Mistake #2: Removing a Field

```solidity
// WRONG - This leaves a hole!
struct VaultStorage {
    address asset;
    uint8 assetDecimals;
    // uint8 __reservedShareDecimalsSlot;  // ← REMOVED - leaves garbage slot!
    string name;
    string symbol;
    // ...
}
```

### ❌ Mistake #3: Reordering Fields

```solidity
// WRONG - Slots get reassigned!
struct VaultStorage {
    uint8 assetDecimals;  // ← Moved to slot 0
    address asset;        // ← Now in slot 1
    // ...
}
```

### ✅ Correct: Append-Only

```solidity
// CORRECT - Always append new fields
struct VaultStorage {
    address asset;
    uint8 assetDecimals;
    uint8 __reservedShareDecimalsSlot;
    string name;
    string symbol;
    uint256 totalSupply;
    bool initialized;
    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) allowances;
    uint256 newTrackedField;  // ← New field at the end
}
```

---

## Upgrade Checklist

Before deploying a facet upgrade, **verify storage layout safety:**

- [ ] **No field insertions**: All new fields appended at the end only
- [ ] **No field removals**: Never delete or comment out fields
- [ ] **No field reordering**: Keep existing fields in the same order
- [ ] **No type changes**: Don't change uint256 to uint128, etc.
- [ ] **No packing changes**: uint8 fields remain in their slots
- [ ] **New libraries match**: If using new libraries, they must use the same struct
- [ ] **All facets updated**: If struct changes, update all facets that access it
- [ ] **Test on testnet first**: Deploy to testnet, run all user operations to verify

### Verification Commands

```bash
# Compile and check for warnings
forge build

# Run the storage safety test suite
forge test --match-path test/StorageSafetyAudit.t.sol -vv

# Check storage layout manually
cast storage <DIAMOND_ADDRESS> 0x$(cast keccak256 <"diamondvault.vault.storage">) --rpc-url <RPC>
```

---

## Proof of Concept: Storage Collision

The test suite in [StorageSafetyAudit.t.sol](../test/StorageSafetyAudit.t.sol) contains four acts that demonstrate storage safety:

### Act 1: Baseline Deposit
- Alice deposits 1000 USDC
- Receives 1000e18 shares (18 decimals)
- Shares stored at `keccak256(alice, 5)` in slot system
- ✅ **Result**: Shares are accessible via balanceOf()

### Act 2: Safe Upgrade (Append-Only)
- Replace Vault4626Facet with new code (same layout)
- Alice's balance unchanged
- ✅ **Result**: Append-only upgrades preserve all user state

### Act 3: Broken Upgrade (Mid-Struct Insertion)
- Deploy Vault4626FacetV2_BROKEN with mid-struct field insertion
- Upgrade both Vault4626Facet AND VaultShareFacet to broken versions
- Query Alice's balance after upgrade
- ❌ **Expected Result**: Alice's balance = 0 (collision!)
- ✅ **Actual Result**: Alice's balance = 0 (footgun proven!)

**Console output:**
```
ACT 3: BEFORE broken upgrade:
  Alice balance = 1000000000000000000000
  Expected balance = 1000000000000000000000

ACT 3: AFTER broken upgrade:
  Alice balance = 0  ← COLLISION! Balance disappeared!
  Expected balance = 1000000000000000000000
  MISMATCH: Balance should be 1000 shares but is 0

ACT 3 PROOF: Mid-struct insertion shifted mapping slots - 
             Alice's balance is now INACCESSIBLE!
```

### Act 4: Recovery (Append-Only Fix)
- After broken upgrade, deploy corrected facets with append-only layout
- Alice's balance recoverable
- ✅ **Result**: Append-only approach always works

---

## Implementation Details

### LibVaultStorage vs LibVaultStorage_BROKEN

**LibVaultStorage** (correct):
- Struct layout preserved across versions
- All facets (VaultShareFacet, Vault4626Facet, etc.) use same layout
- Test Acts 1, 2, 4 pass ✅

**LibVaultStorage_BROKEN** (intentionally broken):
- Struct has field inserted at slot 5 (where bool initialized is)
- Pushes mapping balances to slot 6 instead of slot 5
- Used ONLY in test to prove the footgun
- Test Act 3 demonstrates collision ❌

### Facet Implementations

| Facet | Library | Purpose |
|-------|---------|---------|
| VaultShareFacet | LibVaultStorage | ERC-20 interface (balanceOf, transfer, etc.) |
| Vault4626Facet | LibVaultStorage | ERC-4626 interface (deposit, withdraw, etc.) |
| VaultShareFacetV2_BROKEN | LibVaultStorage_BROKEN | Broken ERC-20 for demonstrating collision |
| Vault4626FacetV2_BROKEN | LibVaultStorage_BROKEN | Broken ERC-4626 for demonstrating collision |

When both broken facets are deployed in Act 3, they both read from shifted slots, making Alice's balance inaccessible.

---

## Recovery from Storage Mistakes

**If a bad upgrade is deployed:**

1. **Stop all transactions** - Pause deposits/withdrawals immediately
2. **Audit affected balances** - Check if collision occurred
3. **Deploy corrected facet** - Fix the struct layout with append-only approach
4. **Restore via migration** - Write a facet function that copies data from old slots to new slots
5. **Verify recovery** - Test user balance restoration on testnet first

Example recovery pattern:
```solidity
// Migration function (only callable by owner)
function migrateStorageFromBrokenToFixed() external onlyOwner {
    LibVaultStorage_BROKEN brokenStorage = LibVaultStorage_BROKEN.vaultStorage();
    LibVaultStorage fixedStorage = LibVaultStorage.vaultStorage();
    
    // Copy each affected user's balance
    for (address user in affectedUsers) {
        uint256 balance = brokenStorage.balances[user];
        fixedStorage.balances[user] = balance;
    }
}
```

---

## References

- **ERC-2535 Diamond Proxy**: [EIP-2535](https://eips.ethereum.org/EIPS/eip-2535)
- **Solidity Storage Layout**: [Solidity Docs - Layout of State Variables in Storage](https://docs.soliditylang.org/en/latest/internals/layout_in_storage.html)
- **Foundry Testing**: [Foundry Book](https://book.getfoundry.sh/)
- **Test Suite**: [StorageSafetyAudit.t.sol](../test/StorageSafetyAudit.t.sol)

---

## Summary

**Storage is the boss.** In the Diamond Proxy pattern:

1. **All state lives at the Diamond address** - Facets are stateless logic
2. **Struct layout is fixed** - Determined at compile time by bytecode
3. **Append-only rule is sacred** - Only add fields at the end
4. **All facets must agree** - If struct changes, all accessing facets must be updated together
5. **Test before deployment** - Use StorageSafetyAudit.t.sol as a template for your upgrades

The cost of getting this wrong is complete loss of user funds. The cost of getting it right is zero - append-only upgrades are zero-risk.

**Choose wisely.** 🔒
