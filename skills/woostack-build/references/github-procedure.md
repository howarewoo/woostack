# GitHub project synchronization procedure

This procedure applies mutations for Build/Fix optional mirror synchronization (when `artifacts.provider: "github"`)
or standalone Plan. The shared [artifact contract](../../woostack-init/references/artifact-backends.md) and
[GitHub profile](../../woostack-init/references/artifact-providers/github.md) own shared and GitHub invariants;
[github-context.md](github-context.md) owns baseline admission.

## Build project lifecycle

Build allocates or resumes the canonical run under `.woostack/tmp/runs/<run-id>/` and admits the baseline.
Ideate and Harden update only the manifest with zero provider calls while drafting.
After `project-spec.md` is written, perform immediate pre-save drift read and one bounded synchronization:
write the specification inside `ProjectV2.readme` between `<!-- woostack-spec-start -->` and `<!-- woostack-spec-end -->`
and update `shortDescription` with the concise goal summary, preserving unrelated README prefix/suffix and metadata.
Read content back and set `mirror.status = "synced"`; mirror failures record `mirror.status = "failed"` and are nonblocking.

## Increment graph synchronization

Build/Fix-delegated `woostack-plan` and Harden populate only the manifest with zero provider calls
and return the admitted DAG: stable task IDs, unique positive display ordinals, and explicit
predecessor sets under the [GitHub graph and parent-selection contract](../../woostack-init/references/artifact-providers/github.md#issue-identity-and-graph).
Reuse the existing manifest task/dependency/mapping forms; run-store storage does not validate the DAG.
After `execution-plan.md` is written, run the shared graph-write preflight. Failure before issue
creation has zero provider and repository mutation; a failed post-create read-back retains exactly one
same-identity creation and permits no membership or relation write.

Perform one bounded synchronization in strict order:
1. Reconcile each admitted task key to exactly one retained or explicitly new issue. Reuse verified
   canonical URL/native ID mappings. For a new key, persist its marker UUID, prove zero exact marker
   matches across complete canonical-repository pagination, and create one parentless issue with its
   full contract. Read it back independently and persist its bind-once mapping. Retained descriptions
   follow the shared existing-description invariant; unchanged fields are no-ops.
2. Read direct membership in the exact Project. Add only missing membership for an explicitly new,
   independently verified issue (including recovery of its interrupted bind/membership boundary);
   read back its item identity and initialize/read back `planned` Status. Retained items preserve
   their existing status and unrelated fields. Unknown membership outcomes require fresh discovery,
   not a second blind add. A missing retained membership is drift and blocks.
3. Compare the complete observed edge set, normalized as `[prerequisite, dependent]` tuples, with the
   explicit prerequisite sets. Existing exact tuples are no-ops; create only missing declared edges by
   adding a native `blocked-by` edge on the dependent pointing at the prerequisite (the dependent is the
   current issue and the prerequisite is the blocking issue). Remove an edge only for an explicitly approved
   prerequisite change, never to fit display order. Round-trip both native issue endpoints in their required
   identity forms before each relation mutation, normalize provider reads back into the same
   `[prerequisite, dependent]` order, and independently read back the affected graph afterward with both
   endpoint identities verified.

Apply the [canonical graph preflight and recovery rules](../../woostack-init/references/artifact-providers/github.md#issue-identity-and-graph)
before every create, membership, or edge mutation. Unknown issue creates retain the same marker UUID
and recover by complete identity discovery, never replay. In mirror mode, persist every verified
binding through run-store CAS before advancing; standalone Plan retains its stable identities without
creating a Build/Fix run.

Finally independently read every issue contract, canonical/native mapping, direct membership, and
all dependency pages. Require exact `[prerequisite, dependent]` tuples with both endpoint identities
verified, not an edge count. Only a complete match sets `mirror.status = "synced"`; otherwise record
failure without changing local artifacts.
Repeating synchronization of an unchanged admitted graph performs no provider mutations.

## Standalone plan

Standalone `woostack-plan` with `artifacts.provider: "github"` requires an exact canonical Project URL (`--project`),
verifies canonical repository association (rejecting foreign repositories), updates the managed README section and
`shortDescription`, reads both back, then reconciles exactly one parentless direct repository issue
(`parent = null`) per admitted task with direct Project membership and only the admitted prerequisite
`blocked-by` edges (each `[prerequisite, dependent]` tuple maps to one native edge on the dependent pointing
at the prerequisite). It applies the same retained-or-new reconciliation, preflight, stable-identity
recovery, preservation, parent-policy, and complete independent graph read-back above, accepts only a
complete exact prerequisite→dependent match, and owns no execution authorization.

## Delivery notes and abandonment

Delivery notes record evidence without replacing source facts. Mirror failures are nonblocking. Explicit abandonment
records `status: "abandoned"` in the manifest and retains run artifacts without closing a mirrored GitHub Project or issue.
