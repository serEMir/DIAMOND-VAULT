# Diamond Vault CRE

This directory contains the Chainlink Runtime Environment project for DiamondVault automation and operational workflows.

## Current Status

The CRE side is still in scaffold form.

- `Diamond-Vault-workflow/` contains the current TypeScript workflow skeleton.
- `project.yaml` defines CRE project targets.
- `.env` and `secrets.yaml` are treated as local-only files and should not be committed with real values.

## Quick Start

```bash
cd Diamond-Vault-workflow
bun install
bun test
```

From `Diamond-Vault-CRE/`, simulate the workflow with:

```bash
cre workflow simulate Diamond-Vault-workflow --target staging-settings
```

## Local Files

- Copy `.env.example` to `.env` if you need local workflow credentials.
- Use `secrets.example.yaml` as the starting point for any local secrets file.
