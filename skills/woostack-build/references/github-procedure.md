# GitHub planning synchronization procedure

This procedure applies mutations for Build/Fix optional mirror synchronization (when `artifacts.provider: "github"`)
or standalone Plan. The shared [artifact contract](../../woostack-init/references/artifact-backends.md) and
[GitHub profile](../../woostack-init/references/artifact-providers/github.md) own shared and GitHub invariants;
[github-context.md](github-context.md) owns Project baseline admission. Standalone parent-issue
publication uses the separate admission below; it does not run Project resolution or mirror saves.

## Build project lifecycle

Build allocates or resumes the canonical run under `.woostack/tmp/runs/<run-id>` and admits the
baseline. It adapts the retained goal/specification, baseline, and evidence identity into the public
Ideate/Harden packets, then persists their complete plain handbacks in the run manifest. The public
phases make zero provider calls. The synchronization procedure starts only after `project-spec.md` is written:
Perform immediate pre-save drift read and one bounded synchronization:
write the specification inside `ProjectV2.readme` between `<!-- woostack-spec-start -->` and `<!-- woostack-spec-end -->`
and update `shortDescription` with the concise goal summary, preserving unrelated README prefix/suffix and metadata.
Read content back and set `mirror.status = "synced"`; mirror failures record `mirror.status = "failed"` and are nonblocking.

## Increment graph synchronization

Build/Fix-delegated `woostack-plan` returns a candidate DAG without provider calls. The wrapper
adapts that candidate, the complete specification, and evidence identity into public Harden, then
persists Harden's complete plain handback in the manifest. The returned DAG keeps stable task IDs,
unique positive display ordinals, and explicit predecessor sets under the
[GitHub graph and parent-selection contract](../../woostack-init/references/artifact-providers/github.md#issue-identity-and-graph).
Reuse the existing manifest task/dependency/mapping forms; run-store storage does not validate the DAG.
After `execution-plan.md` is written, run the shared graph-write preflight. Failure before issue
creation has zero provider and repository mutation; a failed post-create read-back retains exactly one
same-identity creation and permits no membership or relation write.

Perform one bounded synchronization in strict order:
1. Reconcile each admitted task key to exactly one retained or explicitly new issue. Reuse verified
   canonical URL/native ID mappings. For a new key, persist its marker UUID, prove zero exact marker
   matches across complete canonical-repository pagination, and create one issue with its
   full contract. Read it back independently and persist its bind-once mapping. Project-mode new
   issues are parentless unless an exact specification parent was explicitly admitted under the
   [hierarchy contract](../../woostack-init/references/artifact-providers/github.md#specification-parent-and-native-children);
   in that case verify/link/read back the native parent using the parent-link step below before membership.
   Retained descriptions
   follow the shared existing-description invariant; unchanged fields are no-ops.
2. Read direct membership in the exact Project. Add only missing membership for an explicitly new,
   independently verified issue (including recovery of its interrupted bind/membership boundary);
   read back its item identity and initialize/read back `planned` Status. Retained items preserve
   their existing status and unrelated fields. Unknown membership outcomes require fresh discovery,
   not a second blind add. A missing retained membership is drift and blocks.
3. Compare the complete observed edge set, normalized as `[prerequisite, dependent]` tuples, with the
   explicit prerequisite sets. Existing exact tuples are no-ops; create only missing declared edges by
   adding a native `blocked-by` edge on the dependent pointing at the prerequisite (the dependent is the
   current issue and the prerequisite is its `blockedBy` issue). Remove an edge only for an explicitly approved
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

Standalone `woostack-plan --project` with `artifacts.provider: "github"` requires an exact canonical
Project URL, verifies canonical repository association, updates the managed README section and
`shortDescription`, and reads both back. It then applies the increment synchronization above:
one admitted task issue per increment, direct Project membership, and the exact prerequisite DAG.
Existing parentless Project plans remain unchanged; intentionally parented members keep their
verified native links. Containers never become extra tasks or implicitly import nonmember children.

## Parent-issue synchronization

Standalone `woostack-plan --parent-issue new|<canonical-issue-URL>` selects only the canonical
repository and specification hierarchy. Require configured GitHub provider selection, then apply
the [parent admission and capability gates](../../woostack-init/references/artifact-providers/github.md#specification-parent-and-native-children)
and shared [graph-write preflight](../../woostack-init/references/artifact-backends.md#canonical-issue-references-nullable-parents-and-graph-write-preflight).
Do not load Project resolution, require Project settings/access, or call Project APIs.

Before the first write, completely admit the specification and task contracts, full existing native
hierarchy and dependency graph, stable identities, verification-command provenance, and required
issue/sub-issue/dependency capabilities. `new` requests a parent, not permission to invent a
specification. An empty candidate creates nothing; an existing empty parent with no planned tasks
returns no work. A retained body index whose expected children are missing blocks rather than
being treated as native membership or permission to recreate them.

Keep standalone mutation identities and last verified boundary in the active contract and return
them on partial failure; no new run or tracking service. Reuse the existing issue marker convention
and complete repository pagination (including closed issues, excluding PRs) for creation recovery.
Apply the shared existing-description invariant to all retained content; preserve unrelated text,
labels, state, assignment, links, and relationships. Immediately re-read against the admitted
snapshot before each write; drift stops the boundary for fresh admission.

Synchronize in this order:

1. **Specification.** For `new`, retain one parent UUID, prove zero marker matches, create the
   specification issue once, and independently read back its canonical/native identities, marker,
   full specification and top-level parent state. Bind it separately as `specItem`, never a task.
   For an exact existing parent, reuse its verified identity and patch only an admitted changed
   specification span; unchanged content is a no-op. The specification includes the inspected
   repository revision, overall acceptance, constraints and non-goals.
2. **Children.** For each explicitly new task key, retain one UUID, prove zero marker matches,
   create its full issue contract once, independently read it back, and bind its canonical/native
   identities once. Each contract includes the now-verified canonical parent URL and relevant
   specification context. Reconcile retained task descriptions without replacing unrelated bytes.
   A retained mapping never falls through to creation; conflicting or missing identities block.
3. **Native parent links.** For each newly allocated child (including recovery of an interrupted
   linking step), independently read its actual parent and the selected parent's fully paginated
   sub-issue list. The exact link already present is a no-op; `parent = null` permits one native
   sub-issue add to this parent. A different/unknown parent blocks; never use replacement/reparenting.
   Round-trip the required native endpoint IDs before adding; independently verify both the child's
   actual parent and parent's complete child list afterward. Missing links on retained children
   are drift, not automatic repair. Unknown link outcomes require fresh two-sided discovery before
   retry. If no link exists and both reads conclusively agree, resume only that missing link.
4. **Task index and prerequisites.** Once every child identity/link is verified, reconcile the
   canonical child index in the parent's admitted managed span and read it back. Reuse increment
   synchronization's exact dependency comparison and write/read-back rules above. Parent links
   are not blocked-by edges: only admitted child→child prerequisites may be written. No parent
   dependency edge, ordinal-derived edge, external endpoint adoption, or implicit reparenting.
5. **Final read-back.** Independently read the parent specification/index, every native child page,
   each child's actual parent and full contract, all task mappings, and all dependency pages.
   Require exactly the admitted child set and prerequisite tuples with both endpoints verified.
   Report the parent separately from the complete task index and unresolved Git-parent joins.
   Preserve issue state and existing delivery/status evidence; never close or reopen issues.
   Publication is not execution, product acceptance, or delivery.

On unknown parent/child creation, retain the same UUID and fully discover it: one ownership-valid
match permits independent recovery; zero, multiple, foreign, or partial matches block without
replaying creation or allocating a replacement. After any partial failure return the actual objects,
verified mappings, and missing relations; do not advertise readiness. Changed children or contracts
require fresh admission on resume. Repeating an unchanged verified publication performs zero writes.

## Delivery notes and abandonment

Delivery notes record evidence without replacing source facts. Mirror failures are nonblocking. Explicit abandonment
records `status: "abandoned"` in the manifest and retains run artifacts without closing a mirrored GitHub Project or issue.
