# Plane project synchronization procedure

This procedure applies provider mutations for Build optional mirror synchronization (when
`artifacts.provider: "plane"`) or one standalone Plan graph. It owns no workflow gate, assignment,
execution, acceptance, or repository authority. The
[Plane artifact contract](../../woostack-init/references/artifact-backends.md) is the single
authority for manifest state, plain Markdown artifact files, optional mirror synchronization,
native work-item-identity/nullable-parent preflight, drift/recovery, identity mapping, artifact
retention, and read-back. The [project context procedure](plane-context.md) owns baseline admission.

## Build project lifecycle

Build allocates or resumes the canonical run under `.woostack/tmp/runs/<run-id>/` and admits the
baseline before ideation when mirroring is enabled. Ideate and specification Harden update only the
permission-restricted run manifest and make zero provider calls. This procedure is not invoked until
`project-spec.md` is written.

When `artifacts.provider: "plane"`, perform only the shared immediate pre-save drift read and one
bounded synchronization after `project-spec.md` is written. Write the specification under the
existing-record invariant, independently read the content back, and update `mirror.status = "synced"`
in the manifest; mirror failure is recorded as `mirror.status = "failed"` and is nonblocking. Do not
save intermediate decisions, question replies, or hardening corrections.

## Increment graph synchronization

Build-delegated `woostack-plan` and Harden populate only the manifest with a complete candidate
graph. They make zero provider calls. Build writes `execution-plan.md` directly under the run directory.
This procedure runs after `execution-plan.md` is written when `artifacts.provider: "plane"`.
After the immediate baseline drift read matches, run the shared
[graph-write preflight](../../woostack-init/references/artifact-backends.md#canonical-issue-references-nullable-parents-and-graph-write-preflight).
Failure before work item creation has zero provider and repository mutation; a failed post-create
read-back retains exactly one same-identity creation and permits no membership or relation write.

After that preflight, perform one bounded synchronization of:

1. one direct project work item per current increment;
2. complete executor-ready work item descriptions;
3. direct project membership and no parent/container relation (`parent = null`); and
4. native work-item-to-work-item blocking relations matching the graph (`N-1` strict blocking relations for `N` increments).

Use the manifest's preallocated stable client-generated project, work item, and relation mutation identities
(`external_source: "woostack"` and `external_id: <UUID>`), canonical `baseUrl`, and `workspace`. A new work item's create identity may be used only
after the shared pre-create checks; project-membership and relation identities may be used only after the native
work item read-back succeeds.

Reconcile every retained baseline work item with exactly one stable local task key. Reuse a prior verified
native work item mapping when present; otherwise display one explicit proposed baseline native-reference→task-key
mapping. Ambiguous, duplicate, or unmatched retained work items block instead of falling through to allocation.
Reuse each retained native reference and allocate exactly one native reference only for a task key whose mapping is
explicitly new; record every newly allocated mapping atomically and never remap it. Existing descriptions use the
[existing-description mutation invariant](../../woostack-init/references/artifact-backends.md#existing-description-mutation-invariant).

After the bounded writes, independently read every work item's native UUID, readable ID, stable-key
mapping, content, title, project membership, validated nullable-parent state, revision, and mutation identity.
Then independently read the complete relation set and compare exact normalized predecessor→successor tuples with
the local execution plan. That exact graph read-back verifies the mirror sync; update `mirror.status = "synced"`.
Mirror failures are recorded in the manifest and are nonblocking for verified local authority or handoff.

Standalone Plan uses the same native reference, complete-pagination, exact endpoint round-trip, scope, and
nullable-parent preflight before its direct graph synchronization.
Do not create a parent plan issue, child containment, placeholder work item, duplicate relation,
replacement resource, or second synchronization cycle.

## Standalone plan

Standalone `woostack-plan` with `artifacts.provider: "plane"` directly creates or updates the exact
selected project's direct work item dependency graph (`N` parentless work items, `N-1` blocking relations),
independently reads the complete graph back, and owns no execution authorization. It does not use the gated
Build run manifest.
## Delivery notes

Plane delivery notes, comment writers, and execution status updates are unsupported in this increment
(supported for Linear in commit/execute; Plane writers arrive in later increments). Repository execution
delivers via Graphite/GitHub PRs and local run manifest checkpoints.
A note records evidence; it does not establish the fact it records. Read the exact work item/project
back after writing when writers are enabled, and report artifact and repository outcomes separately.
A missing local capability, failed local artifact read or write, conflicting manifest revision, process
loss, or manifest failure blocks at the last verified local boundary. Optional mirror capability,
provider read, pagination, mutation, edge, or read-back failures are recorded as mirror failure and
remain nonblocking for verified local authority and handoff.

Explicit abandonment follows the shared
[project-backed workflow closure](../../woostack-init/references/artifact-backends.md#project-backed-workflow-closure),
recording `status: "abandoned"` and retaining all run artifacts without closing, archiving, or mutating a mirrored
Plane project. Handoff, replan, pauses, and blockers leave project status unchanged.
