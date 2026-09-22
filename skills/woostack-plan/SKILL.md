---
name: woostack-plan
description: Turn an approved specification into GitHub parent/sub-issues or Project issues with prerequisite DAGs, or sequential Linear/Plane plans. Never executes or merges.
---

# woostack-plan

Turn one approved specification into one complete execution plan. Standalone Plan selects one
GitHub specification parent, GitHub Project, Linear project, or canonical Plane repository project,
derives and hardens a candidate graph, synchronizes the selected hierarchy and dependencies,
independently reads them back, and returns the verified result. When
delegated by Build or project-backed Fix, Plan instead drafts the same complete candidate into the
owning workflow's run-scoped manifest with zero provider calls and returns before synchronization.
## Command

```text
/woostack-plan <approved specification> [--project <exact Linear, Plane, or GitHub URL-or-UUID>]
/woostack-plan [--project <exact Linear, Plane, or GitHub URL-or-UUID>]
/woostack-plan <approved specification> --parent-issue new
/woostack-plan [<approved specification>] --parent-issue <canonical GitHub issue URL>
```
For standalone GitHub use, select exactly one of `--project` or `--parent-issue`; conflicting,
repeated, or malformed selectors block before provider access. `--parent-issue` is standalone-only,
requires `artifacts.provider: "github"`, and never selects mirroring. `new` requires a complete
approved specification and explicitly requests one specification parent in the verified canonical
repository. An existing parent must be one exact `https://github.com/<owner>/<repo>/issues/<number>`
URL, not a title, bare number, search result, or PR. Its complete specification may supply the input;
material conflicts with the live request return to the caller before mutation.

For standalone Linear use, `--project` is mandatory. For standalone Plane use, `--project` is optional
and omitted input uses the exact `artifacts.plane.project`; when supplied, it must identify that same
native project. Standalone use requires `artifacts.provider: "linear"`, `"plane"`, or `"github"`
in effective repository configuration. Local/omitted provider configuration fails closed before
provider access. Selectors never override the configured provider.
Standalone Plan loads the shared
[artifact contract](../woostack-init/references/artifact-backends.md), then only the selected row:

| `artifacts.provider` | Provider profile | Synchronization |
| --- | --- | --- |
| `"github"` | [GitHub](../woostack-init/references/artifact-providers/github.md) | [GitHub procedure](../woostack-build/references/github-procedure.md) |
| `"linear"` | [Linear](../woostack-init/references/artifact-providers/linear.md) | [Linear procedure](../woostack-build/references/linear-procedure.md) |
| `"plane"` | [Plane](../woostack-init/references/artifact-providers/plane.md) | [Plane procedure](../woostack-build/references/plane-procedure.md) |

For Linear, resolve only the exact selected project, which must already exist and match the canonical
repository. For GitHub Project mode, resolve only the exact selected canonical Project URL, which
must already exist under the configured owner and match the canonical repository. For parent mode,
apply the [GitHub parent-issue admission](../woostack-init/references/artifact-providers/github.md#specification-parent-and-native-children);
Project configuration, membership, README, Status fields, and Project capabilities are not gates.
For Plane, resolve only the exact configured project, requiring any explicitly supplied `--project`
to identify that same native project. Wrong resource type, missing selected resource, foreign scope,
incomplete read, or conflicting content blocks before mutation.
There is no fuzzy-discovery or alternate-provider path. Standalone Plan also reads the repository,
canonical parent branch and last admitted tip, existing patterns, and relevant tests.
Build/Fix-delegated Plan instead obeys the shared
[manifest contract](../woostack-init/references/artifact-backends.md#minimal-resumable-manifest-schema);
it reads no provider context or synchronization procedure during the delegated phase.
Repository parent-tip admission follows the shared
[repository ancestry contract](../woostack-init/references/artifact-backends.md#repository-ancestry-and-base-change-detection);
Plan owns the approved root parent intent, dependent parent-selection policy, and last-admitted-tip handoff.
Use the shared [source-control selection and ancestry contract](../woostack-commit/references/graphite.md):
Git+gh is the default delivery path; Graphite is opt-in for an explicitly selected or verified
Graphite-managed task/stack. Planning records backend-neutral `parentBranch` intent, not a requirement
to install or track with Graphite. Unknown selection blocks mutation; `gt` failure never selects native mode.

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

Create or reconcile exactly one executable issue/work item per increment under the selected
provider hierarchy: a direct Linear project issue, a GitHub native child of the selected
specification parent or an admitted Project task, or a Plane specification child. The GitHub
specification parent is a separate scope resource, not an increment; it receives no task key,
implementation worker, worktree, PR, or dependency edge. Preserve existing Project plans and
historical containers without automatic conversion, detachment, or reparenting. Every increment
must retain these fields in its complete description:

- stable task ID, unique positive ordinal, concise outcome, and exactly one intended PR;
- exact scope and explicit non-goals;
- affected files, symbols, or a bounded discovery surface, with relevant interfaces and constraints;
- observable acceptance criteria defining completion;
- focused checks and one executable smoke scenario;
- material risks, active blockers, and relevant documentation, migration, deployment,
  compatibility, or cross-increment effects;
- an explicit prerequisite set and parent-selection policy under the selected graph contract below; and
- in GitHub parent mode, the exact canonical specification parent URL and relevant specification
  context sufficient for a fresh worker, independently verified against the native parent link.

When an increment touches an inter-application boundary (HTTP/RPC server-client, service-to-service, webhooks, queues/events, or third-party APIs in either direction), the direct issue contract must explicitly identify each boundary and specify adapter mapping, boundary validation/narrowing, transport error translation, app-local placement, wire/API compatibility, and focused boundary test obligations following the canonical [application-boundary adapters rule](../woostack-bootstrap/references/patterns.md#3-application-boundary-adapters). Do not demand identity-only or no-op wrappers when a deliberately shared contract is already the application/domain shape.

Before admitting any verification command or smoke scenario, independently verify each named
repository-local script or path already exists at the last admitted repository parent tip, is created by a declared predecessor
increment whose dependency orders it before use, or will be created by the same increment
before use. Verify a manifest-defined command against its exact manifest entry and state any
external runtime prerequisite. A missing or invented command blocks plan persistence; never defer
existence checking to the bounded task.


## Graph invariants

Every task ID and positive display ordinal is unique, every prerequisite names an admitted task,
and every issue contract is complete. Reject duplicate prerequisites, self-dependencies, cycles,
missing endpoints, and ambiguous identities before persistence or provider mutation. Every acceptance
criterion must be covered by at least one increment. Repository verification provenance is part of
admission: ordinal proximity does not prove that a task supplies a command or file.

### GitHub prerequisite DAG

When `artifacts.provider: "github"`, including delegated planning for a GitHub mirror, use the
[GitHub graph and parent-selection contract](../woostack-init/references/artifact-providers/github.md#issue-identity-and-graph).
Independent roots, forks, chains, and joins are valid. Record each task's complete explicit
prerequisite set; only those prerequisites become native blocked-by edges. Normalize each edge as a
`[prerequisite, dependent]` tuple and read provider relations back in the same order, verifying both
endpoint identities. Ordinals are stable display/tie-break order, not dependencies or ancestry; gaps or
an edge against display order do not invalidate an otherwise valid DAG. Preserve existing chain edges
unless the approved specification explicitly changes them; never add or remove edges merely to match ordinal adjacency.

A root records its approved integration parent. A dependent records its prerequisites and the policy
for resolving one concrete Git parent and SHA from verified delivered branches at dispatch.
Orchestrate is the intended consumer; Plan does not choose a speculative branch or create an
integration branch. A join without one verified parent containing all required changes remains a
valid plan, with an explicit parent/integration decision required before that issue can run.

Bounded Execute takes one complete bounded task per invocation and is not a DAG dispatcher. Do not hand a branching/multi-root/join plan
to Execute as runnable, including through retired `--run`; retain the graph and report the unsupported
handoff before execution mutation. Planning and mirroring success do not prove execution readiness.

### Linear, Plane, and local-only sequence

Their existing planning contract remains a strict sequence: ordinals are exactly `1..N`,
ordinal 1 has no predecessor, and ordinal `k` depends only on ordinal `k-1`. The root's declared
parent is the approved integration branch; each later task's parent is its immediate predecessor's
branch. Carry last-admitted tips separately as repository evidence. Missing, extra, branching,
out-of-order, or unprovable parent edges block these plans. GitHub DAG support does not add local-run,
Linear, or Plane orchestration.

Prefer the fewest independently reviewable increments that deliver coherent outcomes. Do not
split by file or layer merely to manufacture issues. Leave coding order and implementation
decomposition to the executor within each approved increment's scope.

Before fixing each increment's scope, load and apply the canonical
[least-code standard](../woostack-bootstrap/references/patterns.md#7-least-code--comments) to the
affected repository flow. Prefer existing capabilities over planned new code; record concrete
reuse opportunities and material reasons for new dependencies or abstractions in the existing
scope, interfaces, or risks fields. Do not invent implementation detail merely to document every
rung. Simplification must still cover every approved acceptance criterion and required protection;
an alternative that changes product scope returns to the owning workflow rather than entering the plan.

## Provider synchronization

In standalone use only, after the graph is complete and valid, verify the canonical repository
association and selected workspace/team or instance/workspace, then apply the
[existing-description mutation invariant](../woostack-init/references/artifact-backends.md#existing-description-mutation-invariant)
while synchronizing one exact selected scope through the matching provider synchronization procedure
([GitHub](../woostack-build/references/github-procedure.md),
[Linear](../woostack-build/references/linear-procedure.md), or
[Plane](../woostack-build/references/plane-procedure.md)):

1. Reconcile the selected specification resource: GitHub Project managed README and `shortDescription`,
   GitHub specification parent, or Plane top-level specification, under its owning procedure.
2. Create or reconcile each increment with its full contract; independently verify native parent
   links and any selected Project memberships before prerequisite mutations. GitHub parent
   publication uses the [parent-issue synchronization procedure](../woostack-build/references/github-procedure.md#parent-issue-synchronization).
3. Reconcile exactly the admitted prerequisite edges under the selected provider profile: explicit
   GitHub DAG edges, or the existing strict predecessor sequence for Linear and Plane.
4. Independently read the complete specification, task identities/contracts, native hierarchy,
   selected memberships, and dependency pages; accept only a complete match with the candidate.
Preallocate stable mutation identities, make reconciliation idempotent, and preserve unknown
outcomes for recovery without allocating replacements. This standalone synchronization is
provider-owned, owns no approval gate, and does not use the Build/Fix run manifest.

When delegated by Build or Fix, stop before every provider read or synchronization. Return the
complete manifest-backed candidate contracts and selected graph to the wrapper. The wrapper hardens
the manifest, writes `execution-plan.md`, displays every concise stable task and dependency mapping,
and owns optional post-drafting mirror synchronization (when `artifacts.provider: "linear"`,
`artifacts.provider: "plane"`, or `artifacts.provider: "github"`) and exact read-back.

## Return

Return the complete display-ordered task contracts, exact selected scope or baseline identity,
explicit prerequisite sets and parent-selection policies, repository assumptions/effects, focused
verification strategy, read-back evidence, provider mutation/read counts, and stable mutation
identities. Parent mode includes the canonical specification parent separately from its child task
index, plus actual verified objects and missing relations after partial publication. A parent with
no planned tasks is reported as no work, not an executable increment or completed delivery.
Delegated Plan returns its run/process/manifest identity and makes no provider claim. No execution claim.

## Hard constraints

- One approved specification in; one coherent graph under the selected provider contract out.
- One executable resource per increment under the selected provider hierarchy; specification
  parents stay separate from task mappings. No extra containers or hidden planning ledger.
- GitHub ordinals never imply edges; Linear, Plane, and local-only plans retain their strict sequence.
- Standalone GitHub selects exactly one `--project` or `--parent-issue`; Linear requires `--project`;
  Plane may omit `--project` for its exact configured project.
- Every issue carries the complete outcome, scope, acceptance, verification, prerequisite set,
  and parent-selection contract.
- Delegated Build/Fix planning performs zero provider reads and writes; its wrapper hardens,
  writes plain `execution-plan.md`, and optionally synchronizes when mirroring is enabled.
- Preserve existing Project synchronization; parent mode never implicitly selects a Project.
- Plan owns no implementation, source edit, commit, branch, PR, review, merge, or execution.
- No credential reads, fuzzy artifact selection, implicit Project creation (outside omitted-project
  Plane first use), alternate provider, automatic reparenting, or synthetic dependencies.
- Never claim synchronization or independent read-back without evidence.
