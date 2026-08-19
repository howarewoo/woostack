# Linear project synchronization procedure

This procedure applies provider mutations for Build/Fix optional mirror synchronization (when
`linear.saveArtifacts: true`) or one standalone Plan graph. It owns no workflow gate, assignment,
execution, acceptance, or repository authority. The
[Linear artifact contract](../../woostack-init/references/artifact-backends.md) is the single
authority for manifest state, plain Markdown artifact files, optional mirror synchronization,
canonical issue-reference/nullable-parent preflight, drift/recovery, identity mapping, artifact
retention, and read-back. The [project context procedure](linear-context.md) owns baseline admission.

## Build project lifecycle

Build allocates or resumes the canonical run under `.woostack/tmp/runs/<run-id>/` and admits the
baseline before ideation when mirroring is enabled. Ideate and specification Harden update only the
permission-restricted run manifest and make zero provider calls. This procedure is not invoked until
`project-spec.md` is written.

When `linear.saveArtifacts: true`, perform only the shared immediate pre-save drift read and one
bounded synchronization after `project-spec.md` is written. Write the specification under the
existing-record invariant, independently read the content back, and update `mirror.status = "synced"`
in the manifest; mirror failure is recorded as `mirror.status = "failed"` and is nonblocking. Do not
save intermediate decisions, question replies, or hardening corrections.

## Increment graph synchronization

Build/Fix-delegated `woostack-plan` and Harden populate only the manifest with a complete candidate
graph. They make zero provider calls. Build writes `execution-plan.md` directly under the run directory.
This procedure runs after `execution-plan.md` is written when `linear.saveArtifacts: true`.

After the immediate baseline drift read matches, run the shared
[graph-write preflight](../../woostack-init/references/artifact-backends.md#canonical-issue-references-nullable-parents-and-graph-write-preflight).
Failure before issue creation has zero provider and repository mutation; a failed post-create
read-back retains exactly one same-identity creation and permits no membership or relation write.

After that preflight, perform one bounded synchronization of:

1. one direct project issue per current increment;
2. complete executor-ready issue descriptions;
3. direct project membership and no parent/container relation; and
4. native issue-to-issue dependency relations matching the graph.

Use the manifest's preallocated stable client-generated issue and relation mutation identities. A
new issue's create identity may be used only after the shared pre-create checks; project-membership
and relation identities may be used only after the canonical-reference read-back succeeds.

Reconcile every retained baseline issue with exactly one stable local task key. Reuse a prior verified
canonical issue-reference mapping when present; otherwise display one explicit proposed baseline
canonical-reference→task-key mapping. Ambiguous, duplicate, or unmatched retained issues block instead
of falling through to allocation. Reuse each retained canonical reference and allocate exactly one
canonical reference only for a task key whose mapping is explicitly new; record every newly allocated
mapping atomically and never remap it. Existing descriptions use the
[existing-description mutation invariant](../../woostack-init/references/artifact-backends.md#existing-description-mutation-invariant).

After the bounded writes, independently read every issue's canonical issue reference, provider-native
identity, stable-key mapping, content, title, project membership, validated nullable-parent state,
revision, and mutation identity. Then independently read the complete relation set and compare exact
normalized predecessor→successor tuples with the local execution plan. That exact graph read-back
verifies the mirror sync; update `mirror.status = "synced"`. Mirror failures are recorded in the manifest
and are nonblocking for verified local authority or handoff.

Standalone Plan uses the same canonical issue-reference, complete-pagination, exact endpoint
round-trip, scope, and nullable-parent preflight before its direct graph synchronization.
Do not create a parent plan issue, child containment, placeholder issue, duplicate relation,
replacement resource, or second synchronization cycle.

## Standalone plan

Standalone `woostack-plan` keeps its existing behavior unchanged: it directly creates or updates
the exact selected project's direct-issue dependency graph, independently reads the complete graph
back, and owns no execution authorization. It does not use the gated Build/Fix run manifest.

## Delivery notes

After repository execution, write only concise delivery evidence derived from Git/Graphite/GitHub:
canonical PR URLs, commit SHAs, changed paths, observed verification, review result, and blockers.
A note records evidence; it does not establish the fact it records. Read the exact issue/project
back after writing and report artifact and repository outcomes separately.

A missing local capability, failed local artifact read or write, conflicting manifest revision, process
loss, or manifest failure blocks at the last verified local boundary. Optional mirror capability,
provider read, pagination, mutation, edge, or read-back failures are recorded as mirror failure and
remain nonblocking for verified local authority and handoff.

Explicit abandonment follows the shared
[project-backed workflow closure](../../woostack-init/references/artifact-backends.md#project-backed-workflow-closure),
recording `status: "abandoned"` and retaining all run artifacts without closing a mirrored Linear project.
Handoff, replan, pauses, and blockers leave project status unchanged.
