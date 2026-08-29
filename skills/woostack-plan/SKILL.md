---
name: woostack-plan
description: Turn one approved specification into a strict sequential chain of PR-sized direct Linear issues, Plane increment child work items, or parentless canonical-repository GitHub issues. Never approves, executes, commits, reviews, or merges.
---

# woostack-plan

Turn one approved specification into one complete execution plan. Standalone Plan reads one exact
existing Linear project, canonical GitHub Project, or the canonical Plane repository project, derives
and hardens a candidate chain, synchronizes the complete direct-issue, parented specification, or
parentless GitHub graph, independently reads that graph back, and returns the verified result. When
delegated by Build or project-backed Fix, Plan instead drafts the same complete candidate into the
owning workflow's run-scoped manifest with zero provider calls and returns before synchronization.
## Command

```text
/woostack-plan <approved specification> [--project <exact Linear, Plane, or GitHub URL-or-UUID>]
/woostack-plan [--project <exact Linear, Plane, or GitHub URL-or-UUID>]
```
For standalone Linear or GitHub use, `--project` is mandatory. For standalone Plane use, `--project` is optional
and omitted input uses the exact `artifacts.plane.project`; when supplied, it must identify that same
native project. Standalone use requires `artifacts.provider: "linear"`, `artifacts.provider: "plane"`, or
`artifacts.provider: "github"` in effective repository configuration. When `artifacts.provider` is "local"
or omitted, standalone Plan fails closed before any provider access with an error stating that provider
operations require `artifacts.provider: "linear"`, `artifacts.provider: "plane"`, or `artifacts.provider: "github"`. There is no CLI provider override.
Standalone Plan loads the shared
[artifact contract](../woostack-init/references/artifact-backends.md), then only the selected row:

| `artifacts.provider` | Provider profile | Synchronization |
| --- | --- | --- |
| `"github"` | [GitHub](../woostack-init/references/artifact-providers/github.md) | [GitHub procedure](../woostack-build/references/github-procedure.md) |
| `"linear"` | [Linear](../woostack-init/references/artifact-providers/linear.md) | [Linear procedure](../woostack-build/references/linear-procedure.md) |
| `"plane"` | [Plane](../woostack-init/references/artifact-providers/plane.md) | [Plane procedure](../woostack-build/references/plane-procedure.md) |

For Linear, resolve only the exact selected project, which must already exist and match the canonical
repository. For GitHub, resolve only the exact selected canonical Project URL, which must already exist
under the configured owner and match the canonical repository. For Plane, resolve only the exact configured
project, requiring any explicitly supplied `--project` to identify the same native project. The project
must match the canonical repository and belong to the configured provider scope. Wrong resource type,
missing project, foreign scope, incomplete read, or conflicting content blocks before mutation.
There is no fuzzy-discovery or alternate-provider path. Standalone Plan also reads the repository,
canonical parent branch and last admitted tip, existing patterns, and relevant tests.
Build/Fix-delegated Plan instead obeys the shared
[manifest contract](../woostack-init/references/artifact-backends.md#minimal-resumable-manifest-schema);
it reads no provider context or synchronization procedure during the delegated phase.
Repository parent-tip admission follows the shared
[repository ancestry contract](../woostack-init/references/artifact-backends.md#repository-ancestry-and-base-change-detection);
Plan owns only the approved parent-branch intent and last-admitted-tip handoff.

## Input and ownership

The input is one complete specification containing goal, users, behavior, constraints, exclusions,
architecture decisions, acceptance criteria, and verification expectations. Missing or conflicting
product decisions return to the owning workflow; Plan never invents product decisions and never
creates an approval event.

Build or Fix delegates candidate planning with the readable specification, baseline identity, and
verified run manifest. Delegated planning performs no provider read or mutation; it atomically
records complete candidate contracts, stable local task keys, dependencies, and unresolved questions
in that manifest. The owning wrapper hardens the manifest and writes `execution-plan.md` directly
under `.woostack/tmp/runs/<run-id>/`. In standalone use, Plan itself hardens and synchronizes the
graph. In every mode, Plan owns no implementation, source edit, commit, branch, PR, review, merge,
or execution handoff authority.

## Direct issue contract

Create or reconcile exactly one direct project issue (for Linear), parentless repository issue with direct
Project membership (for GitHub), or child increment work item under the `[Plan] <goal>` specification work
item (for Plane) for each execution increment. Never create extra container, checklist, layer, or
synthetic issues. Historical parent/container issues are not current
increments and are not detached, migrated, archived, deleted, or treated as containment. Every direct issue
or increment work item must retain these fields in its complete description:

- stable task ID, unique positive ordinal, concise outcome, and exactly one intended PR;
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

The plan is a strict sequential chain. If there are `N` increments, ordinals are exactly the positive
integers `1..N`, each ordinal and task ID is unique, and each native Linear dependency, GitHub blocked-by
dependency, or Plane sibling blocking relation is exactly the matching predecessor edge:

```text
ordinal 1: no predecessor
ordinal k (2..N): ordinal k-1 → ordinal k
```
No missing, extra, branching, cyclic, or synthetic dependency is valid. The declared Graphite parent
for ordinal 1 is the approved integration parent branch; for every later ordinal it is the
immediately preceding increment's Graphite parent branch. Bind that stable parent-branch intent in
each complete issue description and carry the last admitted tip as separate repository evidence for
Execute's base-change check. A different branch identity, unknown task, ordinal gap, out-of-order edge,
or parent that Graphite cannot represent blocks the plan. Validate that every acceptance criterion is
covered exactly by at least one increment and that every issue contract is complete before any provider
mutation.

Prefer the fewest increments that remain independently reviewable and fit the size target. Do not
split by file or layer merely to manufacture issues. Use Red → Green → Refactor for behavior changes
only as a structure around concrete steps, never as a substitute for those steps.

## Provider synchronization

In standalone use only, after the chain is complete and valid, verify the canonical repository
association and selected workspace/team or instance/workspace, then apply the
[existing-description mutation invariant](../woostack-init/references/artifact-backends.md#existing-description-mutation-invariant)
while synchronizing one exact project graph through the matching provider synchronization procedure
([GitHub](../woostack-build/references/github-procedure.md),
[Linear](../woostack-build/references/linear-procedure.md), or
[Plane](../woostack-build/references/plane-procedure.md)):

1. Reconcile the complete current project context (for GitHub, write the managed README section and
   update `shortDescription`; for Plane, create/update the top-level `[Plan] <goal>` specification work item with `parent = null`).
2. Create or reconcile exactly one direct project issue (Linear), parentless repository issue in the canonical
   repository with direct Project membership (GitHub), or child increment work item with `parent = <spec-item-UUID>`
   (Plane) per increment with its full contract.
3. Create or reconcile only the strict predecessor dependency chain (for GitHub and Plane, `N-1` native
   blocking relations/dependencies: predecessor blocks successor).
4. Independently read every project, spec item (where applicable), issue/work item, membership, description,
   and dependency edge back; accept the plan only when the complete graph matches the candidate.
Preallocate stable mutation identities, make reconciliation idempotent, and preserve unknown
outcomes for recovery without allocating replacements. This standalone synchronization is
unchanged, owns no approval gate, and does not use the Build/Fix run manifest.

When delegated by Build or Fix, stop before every provider read or synchronization. Return the
complete manifest-backed candidate contracts and strict chain to the wrapper. The wrapper hardens
the manifest, writes `execution-plan.md`, displays every concise stable task and dependency mapping,
and owns optional post-drafting mirror synchronization (when `artifacts.provider: "linear"`,
`artifacts.provider: "plane"`, or `artifacts.provider: "github"`) and exact read-back.

## Return

Return the complete ordered task contracts, exact project or baseline identity, strict predecessor
and Graphite parent edges, repository assumptions/effects, focused verification strategy,
read-back evidence, provider mutation/read counts, and stable mutation identities. Delegated Plan
returns its run/process/manifest identity and makes no provider claim. Do not return a parent-plan
identity or an execution claim.

## Hard constraints

- One approved specification in; one coherent strict chain out.
- One direct project issue (Linear), parentless repository issue with direct Project membership (GitHub), or specification child work item (Plane) per increment; no extra
  container issue and no hidden planning ledger.
- Ordinals are exactly `1..N`; native dependencies are exactly `N-1 → N`.
- Standalone Plan requires `--project` for Linear and GitHub; for Plane `--project` is optional and omitted input
  uses the exact `artifacts.plane.project`.
- Every issue carries the complete executor contract, size evidence, stop marker, and declared
  Graphite parent.
- Direct issue plans target about 500 or fewer hand-written changed lines, with only the stated
  generated/lockfile and explicitly approved unreachable-package deletion exceptions.
- Delegated Build/Fix planning performs zero provider reads and writes; its wrapper hardens,
  writes plain `execution-plan.md`, and optionally synchronizes when mirroring is enabled.
- Standalone Plan keeps its direct project synchronization and independent read-back unchanged.
- Plan owns no implementation, source edit, commit, branch, PR, review, merge, or execution.
- No credential reads, fuzzy artifact discovery, implicit project creation (outside omitted-project Plane
  first use), alternate provider, synthetic dependencies, or obsolete container prose.
- Never claim synchronization or independent read-back without evidence.
