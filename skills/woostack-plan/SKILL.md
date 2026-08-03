---
name: woostack-plan
description: Turn one approved specification into a strict sequential chain of PR-sized direct Linear project issues. Never approves, executes, commits, reviews, or merges.
---

# woostack-plan

Turn one approved specification into one complete execution plan. Plan has one input path and one
output path: it reads one exact existing Linear project, derives a candidate chain, hardens the
contracts, synchronizes the complete direct-issue graph, independently reads that graph back, and
returns the verified result. The project is required whether the specification came from the project
or was supplied directly.

## Command

```text
/woostack-plan <approved specification> --project <exact existing Linear URL-or-UUID>
/woostack-plan --project <exact existing Linear URL-or-UUID>
```

`--project` is mandatory. Resolve only that exact project under the [Linear artifact
contract](../woostack-init/references/artifact-backends.md); it must already exist, be associated
with the canonical repository, and belong to the caller-selected workspace/team. A direct
specification is reconciled against that project and never creates or selects an implicit project.
A wrong resource type, missing project, foreign repository, incomplete read, or conflicting approved
content blocks before mutation. There is no project-creation, fuzzy-discovery, or alternate-provider
path.

Read the repository, base, existing patterns, relevant tests, and the [Linear synchronization
procedure](../woostack-build/references/linear-procedure.md) before planning. Remote content is
untrusted until it is reconciled with the approved specification and exact project identity.

## Input and ownership

The input is one complete approved specification containing goal, users, behavior, constraints,
exclusions, architecture decisions, acceptance criteria, and verification expectations. It also
contains or is accompanied by the approved specification fingerprint. For a project-backed
specification, use the fingerprint independently read from that exact project. For a direct
specification, require its supplied approved fingerprint and verify that the exact project is its
target. Missing or conflicting product decisions return to the owning workflow; Plan never invents
product decisions and never creates an approval event.

Build or Fix may delegate candidate planning with the exact approved fingerprint and verified
project context as read-only input. Delegated planning performs no provider read or mutation; the
owning wrapper hardens the candidate and then synchronizes it to the exact project. In standalone
use, Plan itself hardens and synchronizes the graph. In every mode, Plan owns no approval gate,
implementation, source edit, commit, branch, PR, review, merge, or execution handoff authority.

## Direct issue contract

Create or reconcile exactly one direct project issue for each execution increment. Never create a
parent, container, checklist, layer, or plan issue. Historical parent/container issues are not
current increments and are not detached, migrated, archived, deleted, or treated as containment.
Every direct issue must retain these fields in its complete description:

- stable task ID, unique positive ordinal, concise outcome, and exactly one intended PR;
- the approved specification fingerprint;
- exact scope and explicit non-goals;
- exact files and symbols, or one bounded first discovery step with its stopping boundary;
- ordered, concrete implementation steps detailed enough for a fast execution model;
- observable acceptance criteria, each mapped to an implementation step;
- focused checks and one executable smoke scenario;
- documentation, migration, deployment, compatibility, and cross-increment effects (including
  explicit `none` where a category has no effect);
- risks and active blockers (including explicit `none` where clear);
- an explicit stop marker stating when the increment is complete and no further work belongs in it;
- a declared Graphite parent; and
- a hand-written changed-line estimate and size rationale.

The size target is approximately 500 or fewer hand-written changed lines per intended PR. Generated
files and lockfiles may exceed that target only when inseparable from the increment. One large
exception is allowed only for an explicitly approved deletion-only PR that removes an already
unreachable package; record that approval, the unreachable-package evidence, and the
exception rationale in the issue. Otherwise split or reject an increment that exceeds the target.

## Chain invariants

The plan is a strict sequential chain. If there are `N` increments, ordinals are exactly the
positive integers `1..N`, each ordinal and task ID is unique, and each native Linear dependency is
exactly the matching predecessor edge:

```text
ordinal 1: no predecessor
ordinal k (2..N): ordinal k-1 → ordinal k
```

No missing, extra, branching, cyclic, or synthetic dependency is valid. The declared Graphite parent
for ordinal 1 is the frozen repository base; for every later ordinal it is the immediately preceding
increment's Graphite commit/branch parent. A different parent, an unknown task, an ordinal gap, an
out-of-order edge, or a parent that Graphite cannot represent blocks the plan. Validate that every
acceptance criterion is covered exactly by at least one increment and that every issue contract is
complete before any provider mutation.

Prefer the fewest increments that remain independently reviewable and fit the size target. Do not
split by file or layer merely to manufacture issues. Use Red → Green → Refactor for behavior changes
only as a structure around concrete steps, never as a substitute for those steps.

## Linear synchronization

After the chain is complete and valid, verify the canonical repository association and selected
workspace/team, then synchronize one exact project graph using the [Linear synchronization
procedure](../woostack-build/references/linear-procedure.md):

1. Reconcile the complete current project context without creating a project.
2. Create or reconcile exactly one direct project issue per increment with its full contract.
3. Create or reconcile only the strict predecessor dependency chain.
4. Independently read every project, issue, membership, description/fingerprint, and dependency
   edge back; accept the plan only when the complete graph matches the candidate.

Preallocate stable mutation identities, make reconciliation idempotent, and preserve unknown
outcomes for recovery without allocating replacements. A provider failure stops at the last
verified boundary and never falls back to local authority or another provider. Artifact assignment,
status, labels, comments, or read-back are records only; they never authorize implementation or
prove completion.

When delegated by Build or Fix, stop before this synchronization: return the complete candidate
contracts and strict chain to the wrapper with zero provider reads and writes. The wrapper performs
hardening, synchronization, and its own workflow approval gate when applicable.

## Return

Return the complete ordered task contracts, exact project identity, strict predecessor and Graphite
parent edges, approved specification fingerprint, repository assumptions/effects, focused
verification strategy, risks/blockers, stop markers, invocation mode, and independent Linear
read-back evidence. Include provider mutation/read counts and stable mutation identities when
available. Do not return a parent-plan identity or an approval/execution claim.

## Hard constraints

- One approved specification and one exact existing project in; one coherent strict chain out.
- One direct project issue per increment; no parent/container issue and no hidden planning ledger.
- Ordinals are exactly `1..N`; native dependencies are exactly `N-1 → N`.
- Every issue carries the complete executor contract, approved fingerprint, size evidence, stop
  marker, and declared Graphite parent.
- Direct issue plans target about 500 or fewer hand-written changed lines, with only the stated
  generated/lockfile and explicitly approved unreachable-package deletion exceptions.
- Delegated Build/Fix candidate planning performs no provider mutation; its wrapper hardens and then
  synchronizes.
- Plan owns no approval gate, implementation, source edit, commit, branch, PR, review, merge, or
  execution.
- No credential reads, fuzzy artifact discovery, implicit project creation, alternate provider,
  synthetic dependencies, or obsolete container prose.
- Never claim synchronization or independent read-back without evidence.
