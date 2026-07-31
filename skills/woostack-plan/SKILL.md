---
name: woostack-plan
description: Turn one approved specification into a complete PR-sized implementation plan with dependency-aware increments. Linear project/issue persistence is optional. Never executes, commits, or merges.
---

# woostack-plan

Produce one implementation plan from one approved specification. The specification may live in the
active conversation, a repository-authorized local artifact, or an exact caller-supplied Linear
project artifact. Planning owns no approval gate and performs no source mutation.

## Commands

```text
/woostack-plan <approved specification> [--project <exact Linear URL-or-UUID>]
/woostack-plan --project <exact Linear URL-or-UUID>
```

Without `--project`, return the complete plan in the conversation and do not contact Linear.

## Input admission

Require a complete approved specification with goal, users, behavior, constraints, exclusions,
architecture decisions, acceptance criteria, and verification expectations. Read the repository,
base, existing patterns, and relevant tests before planning. Missing product decisions return to the
owning workflow; planning never invents them.

When `--project` is supplied, read only that exact resource under the
[optional artifact contract](../woostack-init/references/artifact-backends.md). Extract the approved
specification fields. Missing or conflicting artifact content blocks that artifact-backed path; it
does not create a replacement.

## Plan contract

Create independently shippable increments. Every increment contains:

- stable task ID and concise outcome;
- explicit scope and non-goals;
- exact files/symbols or the narrowest discoverable surface;
- observable acceptance criteria;
- Red → Green → Refactor steps where behavior changes;
- focused verification and smoke-test plan;
- documentation/migration/deployment effects when applicable;
- declared predecessors and at most one Git parent; and
- one intended PR.

The graph must be acyclic and dependency-derived. Independent roots may run in parallel only when
surfaces are disjoint. Ordinal order is a tie-break, not a dependency. Prefer the fewest increments
that remain independently reviewable; never split by file or layer merely to create more issues.

## Repository grounding

Use current source, architecture, tests, and repository rules. Reuse existing patterns; do not create
a second convention. Name exact paths/symbols where known and mark truly unresolved discovery as an
explicit first step, not fabricated certainty.

## Optional synchronization

If the caller requested Linear persistence, synchronize the approved specification and complete plan
to the exact project. Optional increment issues may mirror plan tasks, but they remain artifacts:

- use stable IDs and idempotent reconciliation;
- create/update only what the caller requested;
- independently read every mutation back;
- preserve unknown outcomes for recovery; and
- never use artifact assignment/state/comments to authorize execution or prove completion.

Artifact failure blocks only requested persistence unless persistence was explicitly part of the
deliverable. The plan remains valid from its approved content and repository grounding.

## Return

Return the complete ordered graph, task contracts, dependency/parent edges, parallelizable roots,
base assumptions, verification strategy, open blockers, and optional artifact synchronization
results. The caller owns any later approval and execution handoff.

## Hard constraints

- One approved specification in, one coherent plan out.
- Linear optional; no implicit discovery or creation.
- No execution, source edits, commit, push, PR, or merge.
- No synthetic dependencies, wrapper tasks, or hidden local development ledger.
- Never claim artifact persistence without independent read-back.
