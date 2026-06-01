# Development Guide

End-to-end workflow for shipping a change into a project bootstrapped from this spec.

## The loop

The loop is **automated by the woostack skill collection** — these are the source of truth
for each phase:

| Phase | Skill |
|---|---|
| Brainstorm → spec (HTML) → grill → plan → execute | `woostack-build` |
| Review | `woostack-review` |
| Address review feedback | `woostack-address-comments` |

Each command is discrete and ends by offering the next step. Merge stays with the human.

Artifacts live under `.woostack/` in the project: HTML specs in `.woostack/specs/`,
markdown plans in `.woostack/plans/`, review config/memory in `.woostack/config.json`
and `.woostack/memory.md` (`.woostack/metrics.json` is gitignored).

## Branching model

| Branch | Role | Parent | Direction |
|---|---|---|---|
| `main` | Production. What's running for users. | — | Receives from `staging` only |
| `staging` | Integration. Pre-prod testing. | `main` | Receives from feature branches |
| `feature/<name>` | One change. One PR. | `staging` | Merged into `staging` via PR |

**Rules:**
- Every feature branch is cut from `staging`, not `main`.
- Every PR targets `staging`.
- `staging` is merged into `main` on a regular cadence (weekly, or per release) after manual/automated testing on the staging environment.
- Never PR directly into `main` except for emergency hotfixes (and even then, cherry-pick into `staging` immediately after).
- Never force-push to `main` or `staging`.

Use Graphite (`gt create`, `gt modify`, `gt submit`) to manage stacks. `gt create --base staging` for the initial branch.

## When to deviate

The loop is the default. Bypassing steps is allowed when the change is genuinely small (typo fix, comment edit, version bump) or genuinely urgent (production incident).

Document any deviation in the PR description so reviewers understand why the usual gates were skipped.
