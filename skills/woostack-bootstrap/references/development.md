# Development Guide

End-to-end workflow for shipping a change into a project bootstrapped from this spec.

## The loop

The loop is **automated by the woostack skill collection** — these are the source of truth
for each phase:

| Phase | Skill |
|---|---|
| Build a feature or work item requiring multiple PRs, idea → implementation (gated chain — the skill owns the steps) | `woostack-build` |
| Fix a bug or do root-cause work, diagnosis → implementation (gated fix loop) | `woostack-fix` |
| Implement a bounded non-bug enhancement or refactor that fits one reviewable PR (no approval gate or persisted plan) | `woostack-change` |
| Review | `woostack-review` |
| Audit standing code (simplify + production-readiness) | `woostack-audit` |
| Exploratory-QA a running app in the browser | `woostack-qa` |
| Investigate bounded production errors and prepare gated fixes | `woostack-respond` |
| Evaluate approved behavior and trigger corpora for a skill without editing it | `woostack-eval` |
| Address review feedback | `woostack-address-comments` |

Each command is discrete and ends by offering the next step. Merge stays with the human.

Review config and explicitly non-authoritative diagnostic output may remain under `.woostack/`;
review metrics `.woostack/metrics.json` are gitignored. None determine development scope, phase,
approval, assignment, dependencies, or acceptance.

## Optional Linear artifacts

The approved workflow contract owns scope, gates, and acceptance. Git, Graphite, and canonical
GitHub evidence own repository execution and delivery. Linear is optional persistence:

- a feature project/update may store an approved design or specification;
- increment issues may mirror an approved implementation plan and dependency graph; and
- a standalone issue may store a bounded fix or change contract.

Artifact-free workflows use the same gates and repository evidence without contacting Linear.
Never create a project or issue merely because a command runs. When the caller explicitly selects
artifact persistence, follow the canonical
[optional artifact contract](../../woostack-init/references/artifact-backends.md) for exact identity,
untrusted-data handling, narrow mutations, stable operation IDs, and independent read-back.

Linear documents and local spec, plan, fix, progress, or overnight files are not development
authority. `.woostack/config.json` is non-secret repository policy; an optional `linear` object may
provide provider hints but never credentials, permission, ownership, lifecycle, or acceptance.
Provider authentication stays in the host's official Linear MCP/OAuth connection. Missing
authentication blocks only an explicitly requested artifact read/write/read-back. Woostack does not
issue custom Linear HTTP/GraphQL requests or consume repository credentials. GitHub GraphQL remains
valid only for GitHub source-control operations such as review-thread handling.

Storage changes neither workflow intent nor approval policy.
[`woostack-build`](../../woostack-build/SKILL.md) preserves exactly three hard gates: design
approval, written-spec approval, and execution handoff. Those gates live in the active conversation
and approved in-run contract. When selected, project updates may mirror the approved design/spec
and issues may mirror the plan after each gate; no artifact event creates or replaces a gate.

`woostack-bootstrap` is greenfield only. Before design or target access, it routes an
existing-repository bug to `woostack-fix`, a bounded one-PR non-bug request to `woostack-change`,
and multi-PR work to `woostack-build`. Its requirements, research, options, complete design, and
explicit approval authorize the scaffold. Optional project persistence happens only when requested
and remains separate from the filesystem boundary.

Bootstrap does not stat, list, read, canonicalize, create, or write the target and does not invoke
Git before design approval. Its first target-filesystem action is a read-only collision check with
no Git invocation. Only an absent target or a completely listed empty non-Git directory permits
mkdir, write, scaffolding, or Git. A populated path, existing checkout, non-directory/symlink,
unreadable/partial state, or ambiguity blocks while preserving the approved design and any optional
artifact receipts. Init persists only non-secret policy and never creates local specs, plans, or
fixes.

Implementation branches begin from verified repository base evidence and follow the
[canonical worktree contract](../../woostack-init/references/worktrees.md). Bootstrap's initial
new-repository scaffold is the one pre-base worktree exception. Later PRs require direct
Git/Graphite/GitHub identity and may include an ordinary optional artifact link. Git/Graphite and
GitHub remain the source of truth for commits, branches, PRs, reviews, and merges.

Every `/woostack-status` run derives rows from current repository/Graphite/GitHub evidence. Exact
caller-supplied Linear context may enrich a row with linked specification, plan, or fix-artifact
notes; missing artifact access affects only that enrichment. The
[feature-state conventions](../../woostack-status/references/conventions.md) define rendering,
reconciliation, and failure behavior.

Legacy local development records are migration input only. They are never adopted as authority.
`/woostack-init --migrate-legacy` is the sole routed owner of the explicit one-way
[legacy migration procedure](../../woostack-init/references/legacy-migration.md) when a caller
chooses Linear persistence.

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


Wall time: 0.18 seconds