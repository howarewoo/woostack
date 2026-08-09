# Linear project synchronization procedure

This procedure applies provider mutations for one canonical Build/Fix gated save or one standalone
Plan graph. It owns no workflow gate, assignment, execution, acceptance, or repository authority.
The [Linear artifact contract](../../woostack-init/references/artifact-backends.md) is the single
authority for gated manifest state, displayed approval identity, causal ordering, drift/recovery,
identity mapping, cleanup, and read-back. The [project context procedure](linear-context.md) owns
baseline admission.

## Build project lifecycle

Build resolves or creates the exact project and admits the gate 1 baseline before ideation. Ideate
and specification Harden update only the permission-restricted run manifest and make zero provider
calls. This procedure is not invoked until the responsible user approves the complete exact
specification displayed in the active conversation.

After approval, perform only the shared immediate pre-save drift read and one bounded
synchronization. Write the exact approved specification under the existing-record invariant,
independently read the content back, then record and independently read back
`projectSpecApprovalRecord` and its referenced project. Do not save intermediate decisions,
question replies, or hardening corrections. Drift or failure consumes the approval and requires a
fresh baseline and complete Ask.

## Increment graph synchronization

Build/Fix-delegated `woostack-plan` and Harden populate only the gate 2 manifest with a complete
candidate graph. They make zero provider calls. This procedure starts only after responsible-user
approval of every complete exact issue contract and dependency tuple displayed in the active
conversation.

After the immediate baseline drift read matches, perform one bounded synchronization of:

1. one direct project issue per current increment;
2. complete executor-ready issue descriptions containing the approved project-spec fingerprint;
3. direct project membership and no parent/container relation; and
4. native issue-to-issue dependency relations matching the approved graph.

Use the manifest's preallocated stable client-generated issue and relation mutation UUIDs.

Before the Ask, reconcile every retained baseline issue with exactly one stable local task key.
Reuse a prior verified stable-key mapping when present; otherwise display one explicit proposed
baseline issue→task-key mapping for responsible-user approval. Ambiguous, duplicate, or unmatched
retained issues block instead of falling through to allocation. After approval, reuse each retained
native issue ID and allocate exactly one native ID only for a task key whose approved mapping is
explicitly new; record every newly allocated mapping atomically and never remap it. Existing
descriptions use the
[existing-description mutation invariant](../../woostack-init/references/artifact-backends.md#existing-description-mutation-invariant).
Preserve unrelated human-authored content and historical parent/container records.

After the bounded writes, independently read every issue's native identity, stable-key mapping,
content, title, project membership, parent absence, revision, mutation identity, and canonical
fingerprint. Then independently read the complete relation set and compare exact normalized
predecessor→successor tuples with the approved display. Only that exact graph read-back permits
recording `executionPlanApprovalRecord`; independently read both receipts and every referenced
record before clearing gate 2.

Do not create a parent plan issue, child containment, placeholder issue, duplicate relation,
replacement resource, or second synchronization cycle under the same approval.

## Standalone plan

Standalone `woostack-plan` keeps its existing behavior unchanged: it directly creates or updates
the exact selected project's direct-issue dependency graph, independently reads the complete graph
back, and owns no shared approval record or execution authorization. It does not use the gated
Build/Fix run manifest.

## Approval preparation

For gated Build/Fix work, prepare each Ask only from the complete manifest under the shared
[displayed-content approval identity](../../woostack-init/references/artifact-backends.md#complete-displayed-content-approval-identity).
Display the full exact content. Approval precedes every save; exact content read-back precedes
receipt creation; exact receipt and referenced-record read-back precedes gate clearance.

No successful mutation response, Linear status, assignment, update, conversation response without
the ordered receipt, or read-back alone is approval. An unreceipted approval cannot replay after
drift, process loss, manifest loss, unknown outcome, or mismatch.

## Delivery notes

After repository execution, write only concise delivery evidence derived from Git/Graphite/GitHub:
canonical PR URLs, commit SHAs, changed paths, observed verification, review result, and blockers.
A note records evidence; it does not establish the fact it records. Read the exact issue/project
back after writing and report artifact and repository outcomes separately.

## Failures and resume

A missing capability, failed read, unknown mutation, incomplete pagination, conflicting revision,
foreign resource, stale approval, mismatched fingerprint/edge, process loss, or manifest failure
blocks at the last verified boundary. Follow the shared same-identity recovery rule and present a
fresh complete Ask; never replay an unreceipted approval, create a replacement, or use the local
draft as authority.

Explicit abandonment follows the shared
[project-backed workflow closure](../../woostack-init/references/artifact-backends.md#project-backed-workflow-closure),
including manifest cleanup. Handoff, replan, pauses, and blockers leave project status unchanged.
