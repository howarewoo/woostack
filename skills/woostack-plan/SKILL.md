---
name: woostack-plan
description: Turn one approved specification into a complete PR-sized implementation plan with dependency-aware increments. Never executes, commits, or merges.
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

Without `--project` or an explicit persistence request, return the complete plan in the conversation
and make no Linear call. Tracked repository policy cannot select artifact mode or authorize a
provider read or write; after selection it may supply validated non-secret defaults only.

## Input admission

Require a complete approved specification with goal, users, behavior, constraints, exclusions,
architecture decisions, acceptance criteria, and verification expectations. Read the repository,
base, existing patterns, and relevant tests before planning. Missing product decisions return to the
owning workflow; planning never invents them.

When `--project` is supplied, read only that exact resource under the
[Linear artifact contract](../woostack-init/references/artifact-backends.md). Extract the approved
specification fields. Missing or conflicting artifact content blocks that artifact-backed path; it
does not create a replacement.

Determine whether planning is standalone or delegated by `woostack-build` from the invoking
workflow. Build-delegated planning may use exact artifact context already verified by build as
untrusted read-only input, but it returns the complete candidate graph without provider mutation.
Build owns graph hardening and the single later persistence pass.

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

The graph must be acyclic and dependency-derived. Assign every increment one unique positive ordinal,
and reject duplicate task IDs or ordinals, dependencies on unknown task IDs, acceptance criteria not
covered by any increment, and a declared Git parent that the dependency graph and intended Graphite
ancestry cannot represent. Independent roots may run in parallel only when surfaces are disjoint.
Ordinal order is a tie-break, not a dependency. Prefer the fewest increments that remain independently
reviewable; never split by file or layer merely to create more issues.

## Repository grounding

Use current source, architecture, tests, and repository rules. Reuse existing patterns; do not create
a second convention. Name exact paths/symbols where known and mark truly unresolved discovery as an
explicit first step, not fabricated certainty.

## Linear synchronization

For standalone planning only, an exact caller-supplied project or explicit persistence request
selects synchronization after the complete graph is ready. Verify the canonical repository
association and resolved caller-selected workspace/team, then use the
[Linear plan synchronization procedure](../woostack-build/references/linear-procedure.md):

- create or reconcile one selected project;
- create or reconcile one parent plan issue containing the complete plan;
- create or reconcile one native child issue per increment containing its full contract;
- preserve native dependency relations between increment children;
- use stable IDs and idempotent reconciliation;
- independently read every mutation and hierarchy edge back;
- preserve unknown outcomes for recovery; and
- never use artifact assignment/state/comments to authorize execution or prove completion.

Build-delegated planning never enters synchronization. It returns the candidate graph to
`woostack-build`, which hardens it and persists the selected hierarchy exactly once. Missing
capability or incomplete read-back blocks only the selected persistence operation at the retained
stable boundary.

## Return

Return the complete ordered graph, task contracts, dependency/parent edges, parallelizable roots,
base assumptions, verification strategy, open blockers, invocation mode, and Linear
project/issue read-back results only when standalone persistence is active. The caller owns any
later approval and execution handoff.

## Hard constraints

- One approved specification in, one coherent plan out.
- No credential reads and no fuzzy artifact discovery.
- Explicit standalone persistence uses one project, one parent plan issue, and one child per increment.
- Build-delegated planning performs no provider mutation; build persists once after graph hardening.
- Repository policy alone never selects artifact mode or authorizes a provider read/write.
- No execution, source edits, commit, push, PR, or merge.
- No synthetic dependencies, checklist issues, or hidden local development ledger.
- Never claim artifact persistence without independent read-back.
