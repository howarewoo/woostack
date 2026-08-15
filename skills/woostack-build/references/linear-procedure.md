# Linear project synchronization procedure

This procedure applies provider mutations for Build/Fix optional post-approval mirror synchronization
(when `linear.saveArtifacts: true`) or one standalone Plan graph. It owns no workflow gate,
assignment, execution, acceptance, or repository authority. The
[Linear artifact contract](../../woostack-init/references/artifact-backends.md) is the single
authority for gated manifest state, deterministic owner-only gate files, complete streamed artifact
bytes and identity, same-process byte-complete revision diffs with old/new identities, body-free
`Accept`/`Abandon` approval Asks, local approval records, optional mirror synchronization,
canonical issue-reference/nullable-parent preflight, drift/recovery, identity mapping, artifact
retention, and read-back. The [project context procedure](linear-context.md) owns baseline admission.

## Build project lifecycle

Build allocates or resumes the canonical run under `.woostack/tmp/runs/<run-id>/` and admits the gate
1 baseline before ideation when mirroring is enabled. Ideate and specification Harden update only the
permission-restricted run manifest and make zero provider calls. This procedure is not invoked until
the shared contract streams the complete verified `project-spec.md` bytes and full identity (or a
verified same-process byte-complete revision diff with old/new identities) immediately before its
body-free `Accept`/`Abandon` Ask. The acceptance binds only that exact preceding identity and produces
the local `projectSpecApprovalRecord`.

When `linear.saveArtifacts: true`, perform only the shared immediate pre-save drift read and one
bounded synchronization after local approval. Write the exact approved specification under the
existing-record invariant, independently read the content back, then record and independently read
back the provider receipt and referenced project. Update `mirror.status = "synced"` in the manifest;
mirror failure is recorded as `mirror.status = "failed"` and is nonblocking. Do not save intermediate
decisions, question replies, or hardening corrections.
## Increment graph synchronization

Build/Fix-delegated `woostack-plan` and Harden populate only the gate 2 manifest with a complete
candidate graph. They make zero provider calls. Render `execution-plan.md` deterministically from
that manifest. This procedure starts only after the shared contract streams the complete verified
artifact bytes and full identity (or a verified same-process byte-complete revision diff with old/new
identities) immediately before its body-free `Accept`/`Abandon` Ask; complete issue contracts stay
in the streamed file, never the Ask.

After the immediate baseline drift read matches, run the shared
[graph-write preflight](../../woostack-init/references/artifact-backends.md#canonical-issue-references-nullable-parents-and-graph-write-preflight).
Failure before issue creation has zero provider and repository mutation; a failed post-create
read-back retains exactly one same-identity creation and permits no membership or relation write.

After that preflight, perform one bounded synchronization of:

1. one direct project issue per current increment;
2. complete executor-ready issue descriptions containing the approved project-spec fingerprint;
3. direct project membership and no parent/container relation; and
4. native issue-to-issue dependency relations matching the approved graph.

Use the manifest's preallocated stable client-generated issue and relation mutation identities. A
new issue's create identity may be used only after the shared pre-create checks; project-membership
and relation identities may be used only after the canonical-reference read-back succeeds.

Before the Ask, reconcile every retained baseline issue with exactly one stable local task key.
Reuse a prior verified canonical issue-reference mapping when present; otherwise display one explicit
proposed baseline canonical-reference→task-key mapping for responsible-user approval. Ambiguous,
duplicate, or unmatched retained issues block instead of falling through to allocation. After
approval, reuse each retained canonical reference and allocate exactly one canonical reference only
for a task key whose approved mapping is explicitly new; record every newly allocated mapping
atomically and never remap it. Existing descriptions use the
[existing-description mutation invariant](../../woostack-init/references/artifact-backends.md#existing-description-mutation-invariant).

After the bounded writes, independently read every issue's canonical issue reference, provider-native
identity, stable-key mapping, content, title, project membership, validated nullable-parent state,
revision, mutation identity, and canonical fingerprint. Then independently read the complete relation
set and compare exact normalized predecessor→successor tuples with the approved display. That exact
graph read-back permits recording the provider approval record; independently read referenced records
and update `mirror.status = "synced"`. Mirror failures are recorded in the manifest and are nonblocking
for local approval or handoff.
Standalone Plan uses the same canonical issue-reference, complete-pagination, exact endpoint
round-trip, scope, and nullable-parent preflight before its unchanged direct graph synchronization.
Do not create a parent plan issue, child containment, placeholder issue, duplicate relation,
replacement resource, or second synchronization cycle under the same approval.

## Standalone plan

Standalone `woostack-plan` keeps its existing behavior unchanged: it directly creates or updates
the exact selected project's direct-issue dependency graph, independently reads the complete graph
back, and owns no shared approval record or execution authorization. It does not use the gated
Build/Fix run manifest.

For gated Build/Fix work, prepare each presentation only from the complete manifest under the
shared [deterministic streamed gate-file approval identity](../../woostack-init/references/artifact-backends.md#deterministic-gate-file-approval-identity-and-streamed-presentation).
Stream complete file bytes and full identity immediately before the body-free `Accept`/`Abandon`
Ask; same-process revisions may stream only one independently verified byte-complete unified diff
with old/new full-file identities. Approval precedes every save; no-follow regeneration and exact
content read-back precede receipt creation; exact receipt and referenced-record read-back precede
gate clearance.

No successful mutation response, Linear status, assignment, update, conversation response without
the ordered receipt, or read-back alone is approval. An unreceipted approval cannot replay after
drift, process loss, manifest loss, unknown outcome, or mismatch.

## Delivery notes

After repository execution, write only concise delivery evidence derived from Git/Graphite/GitHub:
canonical PR URLs, commit SHAs, changed paths, observed verification, review result, and blockers.
A note records evidence; it does not establish the fact it records. Read the exact issue/project
back after writing and report artifact and repository outcomes separately.

A missing local capability, failed local artifact read or write, conflicting manifest revision,
changed or symlinked gate file, process loss, or manifest failure blocks at the last verified local
boundary. Follow the shared same-identity recovery rule and present a fresh complete artifact or
verified same-process diff and body-free Ask; never replay an unreceipted approval, create a
replacement, or use an unverified draft as authority. Optional mirror capability, provider read,
pagination, mutation, fingerprint, edge, or read-back failures are recorded as mirror failure and
remain nonblocking for verified local authority and handoff.

Explicit abandonment follows the shared
[project-backed workflow closure](../../woostack-init/references/artifact-backends.md#project-backed-workflow-closure),
recording `status: "abandoned"` and retaining all run artifacts without closing a mirrored Linear project.
Handoff, replan, pauses, and blockers leave project status unchanged.
