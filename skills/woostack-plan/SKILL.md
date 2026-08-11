---
name: woostack-plan
description: Turn one approved specification into a strict sequential chain of PR-sized direct Linear project issues. Never approves, executes, commits, reviews, or merges.
---

# woostack-plan

Turn one approved specification into one complete execution plan. Standalone Plan reads one exact
existing Linear project, derives and hardens a candidate chain, synchronizes the complete
direct-issue graph, independently reads that graph back, and returns the verified result. When
delegated by Build or project-backed Fix, Plan instead drafts the same complete candidate into the
owning workflow's run-scoped manifest with zero provider calls and returns before synchronization.

## Command

```text
/woostack-plan <approved specification> --project <exact existing Linear URL-or-UUID>
/woostack-plan --project <exact existing Linear URL-or-UUID>
```

For standalone use, `--project` is mandatory. Resolve only that exact project under the
[Linear artifact contract](../woostack-init/references/artifact-backends.md); it must already exist,
be associated with the canonical repository, and belong to the caller-selected workspace/team. A
direct specification is reconciled against that project and never creates or selects an implicit
project. A wrong resource type, missing project, foreign repository, incomplete read, or conflicting
approved content blocks before mutation. There is no project-creation, fuzzy-discovery, or
alternate-provider path.

Standalone Plan reads the repository, canonical parent branch and last admitted tip, existing
patterns, relevant tests, and the
[Linear synchronization procedure](../woostack-build/references/linear-procedure.md) before
planning. Build/Fix-delegated Plan instead obeys the shared
[run-scoped gated draft contract](../woostack-init/references/artifact-backends.md#run-scoped-gated-draft-manifest);
it reads no provider context or synchronization procedure during the delegated phase.
Repository parent-tip admission follows the shared
[repository advancement contract](../woostack-init/references/artifact-backends.md#repository-ancestry-is-separate-from-approval-identity);
Plan owns only the approved parent-branch intent and last-admitted-tip handoff.

## Input and ownership

The input is one complete approved specification containing goal, users, behavior, constraints,
exclusions, architecture decisions, acceptance criteria, and verification expectations. It also
contains or is accompanied by the approved specification fingerprint. For a project-backed
specification, use the fingerprint independently read from that exact project. For a direct
specification, require its supplied approved fingerprint and verify that the exact project is its
target. Missing or conflicting product decisions return to the owning workflow; Plan never invents
product decisions and never creates an approval event.

Build or Fix delegates candidate planning with the exact approved fingerprint, baseline identity,
and verified run manifest. Delegated planning performs no provider read or mutation; it atomically
records complete candidate contracts, stable local task keys, dependencies, unresolved questions,
and fingerprints in that manifest. The owning wrapper hardens the manifest, deterministically
renders `execution-plan.md`, and displays only its owner-only path/hash/length/version identity plus
the complete concise stable-task/dependency mapping. It synchronizes only after approval under the
shared gated contract. In standalone use, Plan itself hardens and synchronizes the graph exactly as
before. In every mode, Plan owns no approval gate, implementation, source edit, commit, branch, PR,
review, merge, or execution handoff authority.

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
- an executor-ready removal-before-addition analysis: consider safe deletion or simplification
  opportunities first, then record bounded evidence for the selected removal or why addition is
  necessary;
- observable acceptance criteria, each mapped to an implementation step;
- focused checks and one executable smoke scenario;
- documentation, migration, deployment, compatibility, and cross-increment effects (including
  explicit `none` where a category has no effect);
- risks and active blockers (including explicit `none` where clear);
- an explicit stop marker stating when the increment is complete and no further work belongs in it;
- a declared Graphite parent; and
- a hand-written changed-line estimate and size rationale.

Before admitting any verification command or smoke scenario, independently verify each named
repository-local script or path already exists at the last admitted repository parent tip, is created by a predecessor
increment whose native dependency orders it before use, or will be created by the same increment
before use. Verify a manifest-defined command against its exact manifest entry and state any
external runtime prerequisite. A missing or invented command blocks plan persistence; never defer
existence checking to Execute.

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
for ordinal 1 is the approved integration parent branch; for every later ordinal it is the
immediately preceding increment's Graphite parent branch. Bind that stable parent-branch intent in
each complete issue description and carry the last admitted tip as separate repository evidence for
Execute's shared advancement check. A different branch identity, unknown task, ordinal gap,
out-of-order edge, or parent that Graphite cannot represent blocks the plan. Validate that every
acceptance criterion is covered exactly by at least one increment and that every issue contract is
complete before any provider mutation.

Prefer the fewest increments that remain independently reviewable and fit the size target. Do not
split by file or layer merely to manufacture issues. Use Red → Green → Refactor for behavior changes
only as a structure around concrete steps, never as a substitute for those steps.

## Linear synchronization

In standalone use only, after the chain is complete and valid, verify the canonical repository
association and selected workspace/team, then apply the
[existing-description mutation invariant](../woostack-init/references/artifact-backends.md#existing-description-mutation-invariant)
while synchronizing one exact project graph through the
[Linear synchronization procedure](../woostack-build/references/linear-procedure.md):

1. Reconcile the complete current project context without creating a project.
2. Create or reconcile exactly one direct project issue per increment with its full contract.
3. Create or reconcile only the strict predecessor dependency chain.
4. Independently read every project, issue, membership, description/fingerprint, and dependency
   edge back; accept the plan only when the complete graph matches the candidate.

Preallocate stable mutation identities, make reconciliation idempotent, and preserve unknown
outcomes for recovery without allocating replacements. This standalone synchronization is
unchanged, owns no approval gate, and does not use the Build/Fix run manifest.

When delegated by Build or Fix, stop before every provider read or synchronization. Return the
complete manifest-backed candidate contracts and strict chain to the wrapper. The wrapper hardens
and fully displays that draft, obtains approval before save, and owns the one bounded post-approval
synchronization and exact read-back.

## Return

Return the complete ordered task contracts, exact project or baseline identity, strict predecessor
and Graphite parent edges, approved specification fingerprint, repository assumptions/effects,
focused verification strategy, risks/blockers, stop markers, and invocation mode. Standalone Plan
also returns independent Linear read-back evidence, provider mutation/read counts, and stable
mutation identities. Delegated Plan returns its run/process/manifest identity and makes no provider
claim. Do not return a parent-plan identity or an approval/execution claim.

## Hard constraints

- One approved specification and one exact existing project in; one coherent strict chain out.
- One direct project issue per increment; no parent/container issue and no hidden planning ledger.
- Ordinals are exactly `1..N`; native dependencies are exactly `N-1 → N`.
- Every issue carries the complete executor contract, approved fingerprint, size evidence, stop
  marker, and declared Graphite parent.
- Direct issue plans target about 500 or fewer hand-written changed lines, with only the stated
  generated/lockfile and explicitly approved unreachable-package deletion exceptions.
- Delegated Build/Fix planning performs zero provider reads and writes; its wrapper hardens,
  displays, obtains approval, and then synchronizes.
- Standalone Plan keeps its direct project synchronization and independent read-back unchanged.
- Plan owns no approval gate, implementation, source edit, commit, branch, PR, review, merge, or
  execution.
- No credential reads, fuzzy artifact discovery, implicit project creation, alternate provider,
  synthetic dependencies, or obsolete container prose.
- Never claim synchronization or independent read-back without evidence.
