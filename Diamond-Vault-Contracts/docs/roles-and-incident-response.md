## Diamond Vault Roles And Incident Response

### Status

This document formalizes the current operating model for the Diamond Vault protocol.

It intentionally distinguishes between:

- `current state`: what the codebase already supports
- `planned state`: roles and controls that should exist before mainnet-style deployment

The goal is to keep the protocol operable and auditable without adding premature complexity.

### Design Principles

- Separate fast emergency powers from normal governance powers.
- Keep the emergency role narrow: pause quickly, but do not upgrade, move funds, or change core configuration.
- Prefer one guardian address onchain, backed by a multisig, over many guardian addresses in contract storage.
- Pause the dangerous path, not everything by reflex.
- If accounting correctness is in doubt, fail closed.

### Roles

#### Owner

The owner is the highest-trust authority in the current codebase.

Current responsibilities:

- set or replace the guardian
- pause any vault path
- unpause any vault path
- perform diamond upgrades
- manage protocol configuration that is still owner-gated

Operational expectation:

- in local development, this may be a single builder address
- before any serious testnet or production deployment, this should become a multisig or timelock-controlled address

#### Guardian

The guardian is the emergency operator.

Current responsibilities:

- pause deposits and mints
- pause withdrawals and redeems
- pause share transfers
- pause new allocations into a strategy
- freeze a strategy from harvest and automatic withdrawal use

Current limitations:

- cannot unpause
- cannot unfreeze
- cannot set or replace the guardian
- cannot upgrade facets
- cannot move treasury funds
- cannot add or remove strategies

Operational expectation:

- the guardian should be one onchain address
- that address should usually be a multisig, not a single EOA

#### Governance Or Timelock

This role is planned, not fully implemented yet.

Target responsibilities:

- own the diamond
- control `diamondCut`
- manage parameter changes that should not depend on a single signer
- appoint or rotate the guardian

Rationale:

- upgrades and long-term policy decisions should be slow and reviewable
- emergency response should be fast and narrow

#### Keeper Or CRE Automation

This role is planned, not fully implemented yet.

Target responsibilities:

- trigger bounded operational actions such as harvest and rebalance
- never perform governance upgrades
- never hold full admin authority

Rationale:

- automation should execute approved operations, not become an admin backdoor

### Current Permission Matrix

| Capability | Current Access | Future Access |
| --- | --- | --- |
| Set guardian | Owner | Governance/Timelock |
| Pause deposits/mints | Owner, Guardian | Governance/Timelock |
| Unpause deposits/mints | Owner | Governance/Timelock |
| Pause withdrawals/redeems | Owner, Guardian | Governance/Timelock |
| Unpause withdrawals/redeems | Owner | Governance/Timelock |
| Pause share transfers | Owner, Guardian | Governance/Timelock |
| Unpause share transfers | Owner | Governance/Timelock |
| Pause strategy allocations | Owner, Guardian | Governance/Timelock |
| Unpause strategy allocations | Owner | Governance/Timelock |
| Freeze strategy | Owner, Guardian | Governance/Timelock |
| Unfreeze strategy | Owner | Governance/Timelock |
| Execute `diamondCut` | Owner | Governance/Timelock |
| Add/remove strategies | Owner | Governance/Timelock |
| Harvest/rebalance | Owner | Governance/Timelock sets policy; Keeper/CRE executes |

### Guardian Model

The protocol should keep exactly one guardian address in storage.

That does not mean one person must control it.

Preferred setups:

- solo builder or early testnet: a `2-of-3` multisig
- small team: a `2-of-3` or `3-of-5` multisig
- community protocol: a larger multisig chosen by governance

Why one guardian address is preferred:

- simpler contract logic
- smaller attack surface
- easier auditing
- easier incident playbooks

If multiple emergency actors are needed, they should usually sit behind the multisig rather than being stored as many guardian addresses onchain.

### Incident Classes

#### Class 1: Accounting Integrity Incident

Examples:

- deposit share math is wrong
- withdraw burn math is wrong
- `totalAssets()` is materially wrong
- a storage bug corrupts balances or supply

Default response:

- pause deposits and mints immediately
- if exit accounting may also be contaminated, pause withdrawals and redeems too
- keep transfers enabled only if they do not make remediation harder

Why:

- accounting bugs can turn into permanent loss once assets leave the vault

#### Class 2: Strategy Incident

Examples:

- strategy adapter bug
- strategy protocol exploit
- strategy insolvency or inability to withdraw

Default response:

- pause new allocations into the affected strategy immediately
- freeze the strategy if harvest or automatic withdrawal use is unsafe
- use vault-level pauses only if the remaining liquid or healthy strategies cannot safely serve users

Why:

- not every strategy incident should require freezing the entire protocol
- strategy freeze lets the vault quarantine one strategy while keeping the rest of the system usable

#### Class 3: Oracle Or Valuation Incident

Examples:

- stale Chainlink data
- bad fallback price
- valuation path returns misleading `totalAssets()`

Default response:

- pause deposits and mints
- pause withdrawals and redeems if the valuation error can overpay exits

Why:

- bad pricing on entry dilutes users
- bad pricing on exit can drain assets

#### Class 4: Share Transfer Or Approval Incident

Examples:

- share token accounting bug
- exploit involving approvals or stolen shares

Default response:

- pause share transfers if ownership movement worsens the incident
- do not pause share transfers by reflex if the problem only concerns deposits or strategy state

Why:

- transfer is usually less dangerous than withdrawal, but it can still complicate remediation

#### Class 5: Governance Or Upgrade Incident

Examples:

- compromised owner key
- malicious or incorrect upgrade proposal
- suspected bug in a newly deployed facet

Default response:

- halt upgrade execution
- use the guardian to contain user-facing damage if necessary
- move ownership to a clean authority if compromise is confirmed

Why:

- upgrade authority is the highest-risk control plane in a Diamond system

### Incident Response Workflow

#### 1. Detect

- identify the affected function or subsystem
- classify whether the problem affects entry, exit, transfers, upgrades, or strategy operations
- assume user funds are at risk until proven otherwise

#### 2. Contain

- pause the narrowest unsafe path that contains the damage
- if the blast radius is unclear, prefer the safer vault-wide pause

#### 3. Assess

- determine whether balances, supply, or strategy accounting are already corrupted
- determine whether assets can still leave incorrectly
- determine whether share transfers worsen remediation

#### 4. Patch

- implement the minimal safe fix
- simulate the incident and the fix
- if the fix is an upgrade, validate storage compatibility before executing `diamondCut`

#### 5. Reopen

- unpause only after exit accounting and asset custody are confirmed sound
- restore lower-risk paths first if needed
- publish a postmortem and operational changes

### Pause Policy

#### Deposits And Mints

Pause when:

- entry pricing is wrong
- asset transfer behavior is unsafe
- the vault cannot value shares correctly

#### Withdrawals And Redeems

Pause when:

- exit pricing is wrong
- accounting correctness is uncertain
- strategy liquidity or valuation makes safe exits impossible

#### Share Transfers

Keep enabled by default, even during many emergencies.

Pause only when:

- ownership movement makes remediation harder
- the share token itself is implicated
- governance or collateral side effects make transfer dangerous

### What Not To Do

- do not give the guardian upgrade authority
- do not give automation authority to bypass governance
- do not model many guardian EOAs onchain unless there is a strong reason
- do not keep the owner as a single hot wallet beyond local development

### Evolution Path

#### Current Milestone

- owner-controlled diamond
- single guardian address
- vault-level pause controls only

#### Next Milestone

- move owner to a multisig or timelock
- document key custody and guardian rotation procedure
- add strategy manager and mock strategy

#### Later Milestone

- introduce strategy-specific freeze controls
- introduce governance-approved guardian rotation
- separate operational roles from governance roles more formally

### Working Rule

If the math is wrong, pause the affected path immediately.

If it is unclear whether exits are still safe, pause exits too.
