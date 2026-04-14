# Diamond Vault Workflow

This directory contains the current Chainlink Runtime Environment workflow scaffold for DiamondVault.

## What Is Here

- `main.ts`
  Minimal cron-triggered TypeScript workflow entrypoint.
- `main.test.ts`
  Bun tests for the current workflow behavior.
- `workflow.yaml`
  Workflow-specific CRE target configuration.
- `config.staging.json` and `config.production.json`
  Environment-specific workflow configuration.

## Install

```bash
bun install
```

## Test

```bash
bun test
```

## Simulate

Run this from the `Diamond-Vault-CRE/` directory:

```bash
cre workflow simulate Diamond-Vault-workflow --target staging-settings
```

## Local Configuration

- Copy `../.env.example` to `../.env` if your simulation needs a workflow key.
- Use `../secrets.example.yaml` as the starting point for a local secrets file if the workflow later requires one.

## Status

This workflow is still a scaffold and is expected to evolve as the onchain protocol matures.
