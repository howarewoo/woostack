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

Official host-exposed Linear MCP is mandatory for woostack development records. Multi-PR work uses
one repository-owned project, append-only typed project updates, and one dependency-aware issue per
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
missing authentication or a required read/write/read-back capability blocks before development
artifact access, target-directory creation, or repository mutation. Woostack does not issue custom
Linear HTTP/GraphQL requests or consume repository credentials. GitHub GraphQL remains valid only
for GitHub-specific source-control operations such as review-thread handling.

Storage changes neither workflow intent nor approval policy. [`woostack-build`](../../woostack-build/SKILL.md)
preserves exactly three hard gates: design approval, written-spec approval, and execution handoff. Design is
artifact-free until explicit approval creates the project and a verified `designApproved` update.
Specification hardening and approval append verified project-update events; planning creates and
reconciles issues and native relations. `ready` exists before the explicit handoff, and Go or an
overnight run must read back `executionApproved` before any implementation Git artifact. There is
no docs-only base PR.

`woostack-bootstrap` is greenfield only. Before design, MCP preflight, project creation, or target
access, it routes an existing-repository bug to `woostack-fix`, a bounded one-PR non-bug request to
`woostack-change`, and multi-PR work to `woostack-build`. Its requirements, research, options, and
complete design remain artifact-free until explicit approval. Only after approval does bootstrap
retain canonical repository/base intent and apply `woostack-init`'s official-MCP/config capability
preflight. It deterministically derives a managed feature client UUID from the canonical repository
plus normalized approved goal/scope, completely searches repository-owned projects, and creates
only after absence is proven. A fresh invocation recomputes that identity; duplicates, partial
managed candidates, or conflicts block. After the project read-back, bootstrap completely reads
project updates, reuses and reads back one matching stable `designApproved` event only when its
repository, normalized design/key, approval evidence, and exact initial base intent match, or
appends only when complete pagination proves it and every conflicting head absent.
Duplicate/conflicting heads, changed base intent, or incomplete pagination block.

Bootstrap does not stat, list, read, canonicalize, create, or write the target and does not invoke
Git until the preflight, repository/base intent, project receipt, and `designApproved` receipt are
all complete. Its first target-filesystem action is then a read-only collision check with no Git
invocation. Only an absent target or a completely listed empty non-Git directory permits mkdir,
write, scaffolding, or Git. A populated path, existing checkout, non-directory/symlink,
unreadable/partial state, or ambiguity blocks while preserving and reporting the verified remote
receipts. The exact feature client UUID, native project ID/URL, repository, workspace/team, base
intent, and verified event context pass unchanged into scaffolding and later project
lifecycle/planning. Init persists only non-secret policy and never creates local specs, plans, or
fixes; planning mutates the exact Linear project rather than writing a local plan.

Implementation branches begin from verified repository base evidence and follow the
[worktree contract](../../woostack-init/references/worktrees.md#artifact-backend-boundary).
Bootstrap's initial new-repository scaffold is the one pre-base worktree exception. Every later
implementation PR carries exact Linear attribution. Git/Graphite and GitHub remain the source of
truth for commits, branches, PRs, reviews, and merges; Linear records verified linkage and
collaboration state.

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
