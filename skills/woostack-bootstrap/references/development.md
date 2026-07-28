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
review metrics `.woostack/metrics.json` and
[local-only memory](../../woostack-init/references/memory.md) `.woostack/memory/` are gitignored.
They never determine development scope, phase, approval, assignment, dependencies, or acceptance.

## Linear development authority

Official Linear MCP is mandatory for woostack development records. Multi-PR work uses one
repository-owned project, append-only typed project updates, and one dependency-aware issue per
increment. A bounded change or fix uses one standalone issue and no wrapper project. Project
updates own the design/specification and lifecycle record. Linear documents and local spec, plan,
fix, progress, or overnight files are not development authority and are not created or read by the
normal workflow.

The canonical
[Linear MCP authority contract](../../woostack-init/references/artifact-backends.md) owns resource
roles and identity, versioned managed metadata, event kinds, lifecycle validation, assignment and
delegation, receipts, trust boundaries, and exact PR trailers. Related workflow docs link to that
contract rather than defining another resource model.

`.woostack/config.json` is non-secret repository policy only. Its `linear` namespace records the
canonical repository URL, workspace, team, coarse-category `projectStatuses` mappings, and
semantic `issueStates` mappings. It contains no development record, transport configuration, or
provider credential. Authentication comes from the host's official Linear MCP/OAuth connection;
missing authentication or a required read/write capability blocks before artifact access or
repository mutation. Woostack does not issue custom Linear GraphQL requests. GitHub GraphQL remains
valid for GitHub-specific operations such as review-thread handling.

Storage changes neither workflow intent nor approval policy. [`woostack-build`](../../woostack-build/SKILL.md)
preserves exactly three hard gates: design approval, written-spec approval, and execution handoff. Design is
artifact-free until explicit approval creates the project and a verified `designApproved` update.
Specification hardening and approval append verified project-update events; planning creates and
reconciles issues and native relations. `ready` exists before the explicit handoff, and Go or an
overnight run must read back `executionApproved` before any implementation Git artifact. Linear
mode has no docs-only base PR.

Implementation branches begin from verified repository base evidence and follow the
[worktree contract](../../woostack-init/references/worktrees.md#artifact-backend-boundary).
Every implementation PR carries exact Linear attribution. Git/Graphite and GitHub remain the
source of truth for commits, branches, PRs, reviews, and merges; Linear records verified linkage
and collaboration state.

Every `/woostack-status` run reads through official Linear MCP, validates the unsuperseded typed
phase chain and issue ownership/relations, independently verifies repository PR evidence, and only
then reconciles eligible native terminal states. The
[feature-state conventions](../../woostack-status/references/conventions.md) define rendering,
reconciliation, and failure behavior. Missing, partial, stale, foreign, or conflicting MCP
read-back blocks rather than presenting stale state.

Legacy local development records are migration input only. They are never adopted as a fallback or
mixed with Linear authority. An explicit one-way migration classifies active versus historical
records, creates or resumes exact client-UUID-addressed Linear resources, verifies the complete
remote receipt set and knowledge provenance, and deletes local records only after the whole
migration succeeds. Historical development remains recoverable from Git.

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
