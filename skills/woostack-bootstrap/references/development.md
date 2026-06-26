# Development Guide

End-to-end workflow for shipping a change into a project bootstrapped from this spec.

## The loop

The loop is **automated by the woostack skill collection** — these are the source of truth
for each phase:

| Phase | Skill |
|---|---|
| Build a feature, idea → implementation (gated chain — the skill owns the steps) | `woostack-build` |
| Fix a small issue, diagnosis → implementation (gated fix loop) | `woostack-fix` |
| Review | `woostack-review` |
| Audit standing code (simplify + production-readiness) | `woostack-audit` |
| Address review feedback | `woostack-address-comments` |

Each command is discrete and ends by offering the next step. Merge stays with the human.

Artifacts live under `.woostack/` in the project: markdown specs in `.woostack/specs/`,
markdown plans in `.woostack/plans/`, and review config in `.woostack/config.json`
(review metrics `.woostack/metrics.json` and [local-only memory](../../woostack-init/references/memory.md)
`.woostack/memory/` are gitignored).

## Branching model

| Branch | Role | Parent | Direction |
|---|---|---|---|
| `main` | Production. What's running for users. | — | Receives from the integration branch |
| `staging` | Example integration branch. Pre-prod testing. | `main` | Receives from feature branches |
| `feature/<name>` | One change. One PR. | resolved integration branch | Merged into the integration branch via PR |

**Rules:**
- Every feature branch is cut from the resolved integration branch, not `main`.
- Every PR targets the resolved integration branch.
- The integration branch is merged into `main` on a regular cadence (weekly, or per release) after manual/automated testing on the integration environment.
- Never PR directly into `main` except for emergency hotfixes (and even then, cherry-pick into the integration branch immediately after).
- Never force-push to `main` or the integration branch.

Use Graphite (`gt create`, `gt modify`, `gt submit`) to manage stacks. The integration/trunk branch is **per-repo configurable**; resolve it through the [worktree/base-branch contract](../../woostack-init/references/worktrees.md) and use that value as the base of the stack. The example table above uses `staging` to illustrate the integration role, not as a hardcoded requirement.

## When to deviate

The loop is the default. Bypassing steps is allowed when the change is genuinely small (typo fix, comment edit, version bump) or genuinely urgent (production incident).

Document any deviation in the PR description so reviewers understand why the usual gates were skipped.
