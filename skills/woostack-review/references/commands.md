# woostack-review command

## Public mode

- `/woostack-review <PR#>` — review one exact existing pull request. The command fetches that PR's
  GitHub evidence, runs the detected multi-angle swarm once, runs both adversarial validator
  passes, intersects their findings, and posts one batched native GitHub Review.
This is the only public review mode.

The PR number is required and must resolve to an existing PR. Review never admits a branch,
worktree, neighboring PR, or inferred target. There are no public `fast`, `deep`, `full`, install,
status, or local-review variants. Worker `fast`/`standard`/`deep` tiers remain internal routing
details.
Review is report-only: it never edits source or tests, applies fixes, changes the PR title/body or
labels, mutates Linear, or merges. Every accepted blocker or nit is included in the one batched
review as an inline comment when anchorable or a general review comment otherwise. Blockers request
changes; without blockers, including nit-only results, the review approves when GitHub permits and
falls back to a non-approval comment only when required by platform actor rules.

## Conditional references

- Repository configuration: [configuration.md](configuration.md)
- GitHub Actions setup: [ci.md](ci.md)
- Failure recovery: [troubleshooting.md](troubleshooting.md)
- Worker output contract: [`../prompts/_worker-header.md`](../prompts/_worker-header.md)
- Orchestration and posting contract: [`../prompts/_orchestrator-header.md`](../prompts/_orchestrator-header.md)
- Pipeline scripts: `../scripts/prefetch.sh`, `detect-angles.sh`, `merge-findings.sh`,
  `intersect-findings.sh`, and `verify-receipts.sh`
