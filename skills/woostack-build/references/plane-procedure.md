# Plane project synchronization procedure

This procedure applies provider mutations for Build/Fix optional mirror synchronization (when
`artifacts.provider: "plane"`). It owns no workflow gate, assignment, execution, acceptance, or
repository authority. The shared
[artifact contract](../../woostack-init/references/artifact-backends.md) owns manifest state, mutation
ordering, failure handling, retention, and read-back invariants. The
[Plane provider profile](../../woostack-init/references/artifact-providers/plane.md) owns Plane
identity, scope, capabilities, membership, relations, and lifecycle behavior. The
[project context procedure](plane-context.md) owns baseline admission.

## Build project lifecycle

Build allocates or resumes the canonical run under `.woostack/tmp/runs/<run-id>` and admits the
baseline before mirroring. It adapts the retained content, baseline, and evidence identity into the
public Ideate/Harden packets, then persists their complete plain handbacks in the manifest. The
public phases make zero provider calls; this procedure is not invoked until `project-spec.md` is written.

When `artifacts.provider: "plane"`, perform only the shared immediate pre-save drift read and one
bounded synchronization after `project-spec.md` is written. Write the specification to the top-level
`[Build] <goal>` specification work item (with `parent = null`) in the configured project under the
existing-record invariant, independently read the content and parent state back, and update `mirror.specItem`
and `mirror.status = "synced"` in the manifest; mirror failure is recorded as `mirror.status = "failed"` and
is nonblocking. Do not save intermediate decisions, question replies, or hardening corrections.

## Increment graph synchronization

Build/Fix writes the complete execution-plan content after the public Harden handback, then adapts
that retained specification, evidence identity, and graph into the provider synchronization packet.
The graph keeps stable task IDs and dependencies. This procedure runs after that file is written
when `artifacts.provider: "plane"`.
After the immediate baseline drift read matches, run the shared
[graph-write preflight](../../woostack-init/references/artifact-backends.md#canonical-issue-references-nullable-parents-and-graph-write-preflight).
Failure before work item creation has zero provider and repository mutation; a failed post-create
read-back retains exactly one same-identity creation and permits no membership or relation write.

After that preflight, perform one bounded synchronization of:

1. one increment child work item per current increment with `parent = <spec-item-UUID>`;
2. complete executor-ready work item descriptions;
3. direct membership in the configured project; and
4. native work-item-to-work-item blocking relations matching the graph (`N-1` strict blocking relations for `N` increments: `ordinal k-1` blocks `ordinal k`).
Use the manifest's preallocated stable client-generated work-item and relation mutation identities
(`external_source: "woostack"` and `external_id: <UUID>`), canonical `baseUrl`, and `workspace`. A new
work item's create identity may be used only after the shared pre-create checks; membership and relation
identities may be used only after the native work-item read-back succeeds.

Reconcile every retained baseline work item with exactly one stable local task key. Reuse a prior verified
native work item mapping when present; otherwise display one explicit proposed baseline native-reference→task-key
mapping. Ambiguous, duplicate, or unmatched retained work items block instead of falling through to allocation.
Reuse each retained native reference and allocate exactly one native reference only for a task key whose mapping is
explicitly new; record every newly allocated mapping atomically and never remap it. Existing descriptions use the
[existing-description mutation invariant](../../woostack-init/references/artifact-backends.md#existing-description-mutation-invariant).

After the bounded writes, independently read every work item's native UUID, readable ID, stable-key
mapping, content, title, project membership, exact specification parent UUID, revision, and mutation identity.
Then independently read the complete relation set and compare exact normalized predecessor→successor tuples with
the local execution plan. That exact graph read-back verifies the mirror sync; update `mirror.status = "synced"`.
Mirror failures are recorded in the manifest and are nonblocking for verified local authority or handoff.

The direct GitHub parent/child/dependency publisher is owned by
[Plan](../../woostack-plan/references/github-procedure.md), not this provider procedure. Plane
remains a transitional Build/Fix mirror path until the provider cleanup owned by issue #741.

## Delivery notes (retired Execute reference)

> **Retired.** Execute does not write Plane work items, states, comments, delivery checkpoints, or run
> manifests. Repository delivery is through the bounded task's GitHub PR path; Plane records never prove
> that delivery. Build/Fix synchronization rules below remain provider-specific, not Execute behavior.
> See [`woostack-execute`](../../woostack-execute/SKILL.md#retired-inputs).

A missing local capability, failed local artifact read or write, conflicting manifest revision, process
loss, or manifest failure blocks at the last verified local boundary. Optional mirror capability,
provider read, pagination, mutation, edge, or read-back failures are recorded as mirror failure and
remain nonblocking for verified local authority and handoff.

Explicit abandonment follows the shared
[artifact retention contract](../../woostack-init/references/artifact-backends.md#retention-and-reporting),
recording `status: "abandoned"` and retaining all run artifacts without closing, archiving, or mutating a mirrored
Plane project. Handoff, replan, pauses, and blockers leave project status unchanged.
