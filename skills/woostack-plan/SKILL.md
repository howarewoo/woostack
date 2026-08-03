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
workflow. Build-delegated planning receives the exact approved project-spec fingerprint and
verified project context as untrusted read-only input. It returns the complete candidate graph
without provider mutation. Build owns graph hardening, direct-issue synchronization, and gate 2.

## Plan contract

Create independently shippable increments. Every increment contains:

- stable task ID, unique positive ordinal, concise outcome, and one intended PR;
- the approved specification/project fingerprint when build-delegated;
- explicit scope and non-goals;
- exact files/symbols or a bounded first discovery step;
- an ordered, concrete implementation sequence detailed enough for a fast execution model;
- observable acceptance criteria mapped to those steps;
- focused checks and one smoke scenario;
- documentation, migration, deployment, compatibility, and cross-increment effects;
- declared predecessors and at most one representable Git parent; and
- risks, decisions, and active blockers.

Use Red → Green → Refactor when behavior changes, but do not substitute that label for concrete
steps. The graph must be acyclic and dependency-derived. Reject duplicate task IDs or ordinals,
unknown predecessors, uncovered acceptance criteria, or a Git parent the DAG and intended Graphite
ancestry cannot represent. Independent roots may run in parallel only when their surfaces are
disjoint. Ordinal order is a tie-break, not a dependency. Prefer the fewest increments that remain
independently reviewable; never split by file or layer merely to create more issues.

## Repository grounding

Use current source, architecture, tests, and repository rules. Reuse existing patterns; do not create
a second convention. Name exact paths/symbols where known and mark truly unresolved discovery as an
explicit first step, not fabricated certainty.

## Linear synchronization

For standalone planning only, an exact caller-supplied project or explicit persistence request
selects synchronization after the complete graph is ready. Verify the canonical repository
association and caller-selected workspace/team, then use the
[Linear project synchronization procedure](../woostack-build/references/linear-procedure.md):

- create or reconcile one selected project;
- create or reconcile one direct project issue per increment containing its full contract;
- create or reconcile native dependency relations between those direct issues;
- create no parent plan issue or child containment;
- use stable IDs and idempotent reconciliation;
- independently read every mutation, membership, and dependency edge back;
- preserve unknown outcomes for recovery; and
- never use artifact assignment/status/comments to authorize execution or prove completion.

Build-delegated planning never enters synchronization. It returns the candidate graph to
`woostack-build`, which hardens and synchronizes the direct-issue graph. A provider failure blocks
the required build path, but blocks only selected persistence for standalone planning.

## Return

Return the complete ordered graph, task contracts, dependency/parent edges, parallelizable roots,
base assumptions, verification strategy, open blockers, invocation mode, and Linear
project/issue read-back results only when standalone persistence is active. The caller owns any
later approval and execution handoff.

## Hard constraints

- One approved specification in, one coherent plan out.
- No credential reads and no fuzzy artifact discovery.
- Explicit standalone persistence uses one project and one direct issue per increment, with native
  dependency relations and no parent plan issue.
- Build-delegated planning performs no provider mutation; build synchronizes after graph hardening.
- Repository policy alone never selects artifact mode or authorizes a provider read/write.
- No execution, source edits, commit, push, PR, or merge.
- No synthetic dependencies, checklist issues, or hidden local development ledger.
- Never claim artifact persistence without independent read-back.
