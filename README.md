# nft-marketplace

**On-chain backed NFT marketplace for the Tales of Tasern ecosystem.** Buy, sell, and power up NFTs across Base and Polygon. Every primary sale builds LP into the underlying token; every resale routes liquidity back into the nation's pool.

> Part of the [MfT / Tales of Tasern](https://tasern.quest/) network.

## What's in this repo

This repo ships:
1. The **marketplace UI** (`marketplace.html`)
2. **Solidity contracts** under `contracts/` (compiled `.bin` / `.abi` not tracked — see `.gitignore`)
3. **Deployer pages** — static HTML pages with embedded bytecode that let you flash a contract from the browser via ethers.js
4. **Generators** that produce per-nation deployer pages from a template

## Repository layout

```
marketplace.html              — The marketplace UI (133 KB).
contracts/                    — Solidity sources (no compiled artifacts in git).

generate-primary-deploys.js   — Generates deploy-primary-{nation}.html for 8 nations.
generate-resale-all.js        — Generates deploy-resale-{nation}.html for 7 nations.
generate-powerup-all.js       — Generates deploy-powerup-{variant}.html for several variants.

deploy-marketplace.html       — Marketplace deployer (Base) — handwritten.
deploy-marketplace-poly.html  — Marketplace deployer (Polygon) — handwritten.
deploy-resale.html            — Generic resale deployer — handwritten.
deploy-powerups.html          — Generic powerup deployer — handwritten.
deploy-primary-all.html       — All-nations primary deployer (aggregator).
deploy-resale-all.html        — All-nations resale deployer (aggregator).
deploy-powerup-all.html       — All-variants powerup deployer (aggregator).

seed-db.js                    — Seed marketplace listings database.
FIX-NFT-BACKING-TABLE.sql     — One-off DB migration.
vercel.json                   — Hosting config.
```

## Quick start

```bash
# Serve the UI + deployer pages locally
npx serve .

# Regenerate per-nation deployer pages after a contract change
node generate-primary-deploys.js
node generate-resale-all.js
node generate-powerup-all.js
```

The generated `deploy-primary-{nation}.html` / `deploy-resale-{nation}.html` / `deploy-powerup-{variant}.html` files are gitignored — regenerate locally as needed.

## The 8 nations

Each nation has its own primary sale + resale market backed by an LP pair:

| Nation | Token | Label |
|--------|-------|-------|
| `igs` | IGS | Bazaar of Igypt |
| `egp` | EGP | Elven Emporium |
| `btn` | BTN | Magic Grove |
| `lgp` | LGP | Dwarven Fortress |
| `dhg` | DHG | Dragon's Nest |
| `ddd` | DDD | Durgan Dynasty |
| `pkt` | PKT | Pirate's Cove |
| `ogc` | OGC | Ork Warcamp |

(See `generate-primary-deploys.js` for the token addresses and accent colors.)

## Related repos

- **[Tales-of-Tasern](https://github.com/jimbo530/Tales-of-Tasern)** — D20 hex RPG (Next.js app + contracts).
- **[Tales-of-Tasern-cards](https://github.com/jimbo530/Tales-of-Tasern-cards)** — NFT card-battle game.
- **[mft-arcade](https://github.com/jimbo530/mft-arcade)** — Play-for-impact arcade portal.

## License

MIT
