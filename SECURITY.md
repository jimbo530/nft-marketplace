# Security Policy

This repo deploys NFT marketplace contracts (primary / resale / powerup) on Base + Polygon via in-repo HTML deployer pages with embedded bytecode. Bugs in deployed contracts, generator scripts, or seed-db can affect real NFT trades.

## Reporting a Vulnerability

**Preferred:** [GitHub Private Vulnerability Reporting](https://github.com/jimbo530/nft-marketplace/security/advisories/new) — opens a private advisory thread.

**Fallback:** _Add a contact email here (e.g. `security@carbon-counting-club.com` or DM `@memefortrees.base.eth`)._

### Please include

- Affected file/function and line numbers
- Impact (severity, affected funds/users, attack precondition)
- Reproduction steps or proof-of-concept
- Suggested fix if you have one

### What to expect

- Acknowledgement within 72 hours
- Severity triage within 7 days
- Coordinated disclosure once a fix is deployed or determined infeasible

## Scope

**In scope:** `generate-*.js` (deployer-page generators), `seed-db.js`, `FIX-NFT-BACKING-TABLE.sql`, the contracts under `contracts/` that the deployer pages flash to chain.

**Out of scope:** Issues in already-deployed marketplace contracts traceable to chain (file with the deploying entity), front-end UX bugs.

## Out-of-Scope Reports

Please do not file public issues for:

- Theoretical attacks without a working PoC
- Best-practice / style critiques (those are fine as regular issues)
- Issues in upstream npm dependencies (file with the upstream)

Thank you for helping keep this project safe.