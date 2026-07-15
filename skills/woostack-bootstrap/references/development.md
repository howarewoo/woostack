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
| Exploratory-QA a running app in the browser | `woostack-qa` |
| Investigate bounded production errors and prepare gated fixes | `woostack-respond` |
| Address review feedback | `woostack-address-comments` |

Each command is discrete and ends by offering the next step. Merge stays with the human.

Review config and non-design project state remain under `.woostack/`; review metrics
`.woostack/metrics.json` and [local-only memory](../../woostack-init/references/memory.md)
`.woostack/memory/` are gitignored. Feature specs and plans follow the selected artifact backend.

## Artifact backend

`.woostack/config.json` selects feature storage with `artifacts.specPlan`. A missing selector
means `markdown`, so Markdown is the default, not a universal requirement. Markdown stores specs
in `.woostack/specs/` and plans in `.woostack/plans/`. Selecting `linear` instead makes one
repository-owned Linear project the feature, one managed spec document its specification, and
ordered increment issues its plan. Native project statuses and team issue states carry lifecycle
state through the configured semantic mappings; do not mirror them into Markdown source files.

Linear authentication is environment only. The process running a Linear-backed skill must receive
`LINEAR_API_KEY`; the key never belongs in `.woostack/config.json`, a credential-file path, a
checked-in env file, or documentation. Backend resolution, validation, and normalized adapter
behavior are owned by
[`resolve-backend.sh`](../../woostack-init/scripts/artifacts/resolve-backend.sh) and its sibling
adapters. Adoption docs must not duplicate their request or query details.

Storage changes neither workflow intent nor approval policy. Both backends preserve exactly three
hard gates: design approval, written-spec approval, and execution handoff. The
[`woostack-build` lifecycle](../../woostack-build/SKILL.md) owns their order and backend-specific
work steps. Markdown opens one docs-only spec+plan base PR before implementation; Linear persists
the project/document/issues natively and has no docs-only base PR. Linear implementation branches
begin only after handoff and follow the frozen-base/dependency rules in the
[worktree contract](../../woostack-init/references/worktrees.md#artifact-backend-boundary).

Every `/woostack-status` run resolves the selected backend. Markdown derives terminal truth
read-only; Linear verifies merge evidence and reconciles only eligible terminal issue/project
states before rendering. The
[feature-state conventions](../../woostack-status/references/conventions.md) own lifecycle
spelling, attribution joins, reconciliation, and failure behavior.

Backend selection is a clean boundary, not live migration. Existing Markdown specs and plans stay
authoritative under Markdown. After selecting Linear, local spec/plan files are inactive
compatibility data: no command imports, adopts, or falls back to them. Move a feature only through
an explicit, separately reviewed migration; changing the selector alone never copies or adopts
artifacts.

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
