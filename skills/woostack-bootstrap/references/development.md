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
| Production errors, Sentry issues, and monitoring defects | `woostack-fix` |
| Evaluate approved behavior and trigger corpora for a skill without editing it | `woostack-eval` |
| Address review feedback | `woostack-address-comments` |

Each command is discrete and ends by offering the next step. Merge stays with the human.

Review config and explicitly non-authoritative diagnostic output may remain under `.woostack/`;
review metrics `.woostack/metrics.json` are gitignored. None determine development scope, phase,
approval, assignment, dependencies, or acceptance.

## Linear product records

Linear is canonical product authority for builds and post-diagnosis fixes. Git, Graphite, and
canonical GitHub evidence remain authoritative for repository execution and delivery:

- a build project stores the evolving high-level specification;
- one direct project issue per build increment stores the complete executor-ready plan and native
  dependency edges encode the DAG; and
- one fix issue stores the proved diagnosis and complete executor-ready fix plan.

The responsible user's exact native Linear approval event clears only its matching content
revision. It does not assign a worker, prove source-control state, or replace review or acceptance.
Every mutation uses stable operation identity and independent read-back under the canonical
[artifact contract](../../woostack-init/references/artifact-backends.md).

Linear documents and local spec, plan, fix, progress, or overnight files are not build/fix product
authority. `.woostack/config.json` is non-secret repository policy; its `linear` object may provide
validated repository/workspace/team/native-name defaults but never credentials, write permission,
or approval. Provider authentication stays in the host's official Linear MCP/OAuth connection.
Missing required capability blocks build or a proved fix at its retained boundary. Woostack does
not issue custom Linear HTTP/GraphQL requests or consume repository credentials. GitHub GraphQL
remains valid only for GitHub source-control operations such as review-thread handling.

Artifact-optional workflows retain their documented selection boundary. Missing optional artifact
access blocks only that artifact operation. `woostack-change` never contacts Linear.

[`woostack-build`](../../woostack-build/SKILL.md) uses two approvals: the exact project
specification revision, then the exact complete direct-issue graph. Material edits invalidate the
matching approval and return to specification hardening or graph hardening.

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