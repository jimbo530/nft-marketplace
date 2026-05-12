# Contributing

Thanks for wanting to contribute! This is a small project — keep things friendly, keep PRs focused, and we'll get along great.

## Reporting issues

- **Bugs / questions / feature ideas:** open a [GitHub issue](https://github.com/jimbo530/nft-marketplace/issues).
- **Security findings:** _don't_ open a public issue — see [SECURITY.md](./SECURITY.md).

## Quick start

Most files are static HTML deployer pages. The generators that produce them:

```bash
node generate-primary-deploys.js
node generate-resale-all.js
node generate-powerup-all.js
```

To run the marketplace UI locally:

```bash
npx serve .
```

## Pull requests

- One concern per PR. A focused 20-line change is easier to merge than a sprawling one.
- Link the issue (`Resolves #N` or `Refs #N`) in the PR body when relevant.
- Keep diffs reviewable: no drive-by reformatting or renames in a feature PR.
- New files should match the existing style in the repo.

## Style

- This project is MIT licensed. Contributions are accepted under the same license.
- Be kind in reviews and replies. Assume good intent.

## Maintainer

[`@jimbo530`](https://github.com/jimbo530) — [memefortrees.base.eth](https://memefortrees.com) — Carbon Counting Club, Meadville PA.