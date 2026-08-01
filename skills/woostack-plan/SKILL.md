---
name: woostack-plan
description: Turn one approved specification into a complete PR-sized implementation plan with dependency-aware increments, persisted as a Linear project hierarchy when repository capability is available. Never executes, commits, or merges.
---

# woostack-plan

Produce one implementation plan from one approved specification. The specification may live in the
active conversation, a repository-authorized local artifact, or an exact caller-supplied Linear
project. Planning owns no approval gate and performs no source mutation.

## Commands

```text
/woostack-plan <approved specification> [--project <exact Linear URL-or-UUID>]
/woostack-plan --project <exact Linear URL-or-UUID>
```

Without `--project`, inspect validated non-secret repository policy. If no `linear` object exists,
return the complete plan in the conversation and make no Linear call. If it exists, preflight the
authenticated official Linear MCP without reading credentials; complete capability makes project
hierarchy persistence required, while unavailable/incomplete capability falls back artifact-free.

## Input admission

Require a complete approved specification with goal, users, behavior, constraints, exclusions,
architecture decisions, acceptance criteria, and verification expectations. Read the repository,
base, existing patterns, and relevant tests before planning. Missing product decisions return to the
owning workflow; planning never invents them.

When `--project` is supplied, read only that exact resource under the
[Linear artifact contract](../woostack-init/references/artifact-backends.md). Extract the approved
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

## Linear synchronization

When an exact project was supplied, persistence was requested, or repository Linear availability
was proved, synchronize the approved specification and complete plan using the
[Linear plan synchronization procedure](../woostack-build/references/linear-procedure.md):

- create or reconcile one project;
- create or reconcile one parent plan issue containing the complete plan;
- create or reconcile one native child issue per increment containing its full contract;
- preserve native dependency relations between increment children;
- use stable IDs and idempotent reconciliation;
- independently read every mutation and hierarchy edge back;
- preserve unknown outcomes for recovery; and
- never use artifact assignment/state/comments to authorize execution or prove completion.

An unavailable automatic preflight leaves the plan artifact-free. A failure after availability was
proved blocks completion of the plan deliverable until the same stable identities are recovered.

## Return

Return the complete ordered graph, task contracts, dependency/parent edges, parallelizable roots,
base assumptions, verification strategy, open blockers, and Linear project/issue read-back results
when persistence is active. The caller owns any later approval and execution handoff.

## Hard constraints

- One approved specification in, one coherent plan out.
- No credential reads and no fuzzy artifact discovery.
- Repository-enabled persistence uses one project, one parent plan issue, and one child per increment.
- No execution, source edits, commit, push, PR, or merge.
- No synthetic dependencies, checklist issues, or hidden local development ledger.
- Never claim artifact persistence without independent read-back.
