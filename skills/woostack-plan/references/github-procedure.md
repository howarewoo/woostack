# GitHub Plan publication procedure

This procedure is the single write/read-back path for `woostack-plan` in both direct and composed
use. It publishes one approved specification as either an explicitly selected GitHub Project graph
or one native GitHub specification parent with direct children and native `blocked-by` edges. A
Prepare caller may retain packet artifacts, but it does not own a second issue or relationship writer.
The shared [artifact contract](../../woostack-init/references/artifact-backends.md#direct-publication-and-recovery)
and [GitHub profile](../../woostack-init/references/artifact-providers/github.md#configuration-and-scope)
own common identity, capability, recovery, and read-back invariants; [github-context.md](github-context.md)
owns the optional Project baseline.

Plan never invokes Orchestrate or Execute. It performs no repository source mutation, branch, worktree,
commit, PR, review, merge, approval, or lifecycle transition.

## Common admission and publication invariants

Both scopes use the same complete plain planning packet, candidate contract, and publication
identity rules. Before the first write:

Confirm user approval of the complete candidate, exact repository/new-or-existing destination, and
resulting visibility before publication. Reuse unchanged explicit approvals; a private Project does
not make repository issues private. Material content or destination changes require a new decision.

1. Establish the exact canonical repository and immutable repository/evidence baseline. Read the
   selected scope completely, including closed issue pages where recovery requires them, terminal
   pagination, native IDs, current descriptions, labels, state, assignment, links, hierarchy, and
   all dependency pages. A partial page or an HTTP error interpreted as `parent = null` blocks.
2. Validate the complete candidate: stable task IDs, unique positive ordinals, complete bounded
   contracts, explicit prerequisite sets, no self-dependencies/cycles/missing endpoints, and
   verification-command provenance. Every named repository-local check/path must exist at the
   admitted parent tip, be created by an admitted prerequisite before use, or be created by the
   same task before use. A missing or invented command blocks publication.
3. Preflight issue read/write, native parent/sub-issue read/write, dependency read/write, complete
   pagination, and independent read-back capabilities without a test mutation. Project membership,
   Project fields, and Status capabilities are required only in Project mode. Missing or unknown
   required relationship capabilities make publication incomplete; do not downgrade it to a local
   checklist.
4. Re-read the complete admitted snapshot immediately before each mutation. Preserve unrelated
   human content and all unrelated labels, state, assignment, links, memberships, hierarchy, and
   relationships. An observed drift or changed candidate requires fresh admission.

Issue bodies use the existing marker convention `<!-- woostack-issue-mutation:<UUID> -->`. Preallocate
one distinct UUID for the specification parent and one for each explicitly new task. A retained
canonical/native mapping never falls through to creation. After an unknown create response, repeat
complete open/closed canonical-repository discovery for that same marker; one ownership-valid match
recovers the identity, while zero, multiple, foreign, partial, or ambiguous matches block without
replaying the create or allocating a replacement.

Normalize every prerequisite as `[prerequisite, dependent]`. The native edge is a `blocked-by` edge
on the dependent pointing at the prerequisite. Read both endpoint collections independently and
normalize them back to the same tuple order with both identities verified. Existing exact tuples are
no-ops; only an explicitly approved prerequisite change can remove an edge. Ordinal adjacency never
creates an edge.

## Explicit Project mode

`--project` accepts one exact canonical GitHub Project URL. Resolve that Project, verify its owner and
canonical repository association, and preserve its existing title, visibility, unrelated README
bytes, views, labels, and fields. The selected Project's managed specification span and `shortDescription`
may be reconciled under the existing-description invariant; no replacement Project or hidden planning
container is created.

After the complete Project baseline is admitted, synchronize exactly one direct Project member per
increment. Retained parentless issues stay parentless; intentionally parented members retain and
round-trip their independently verified native parent. A Project container is not an executable task,
and nonmember children are never imported. Reconcile only the declared prerequisite tuples after
membership and native identities are verified. Read back every issue contract, stable mapping,
Project membership/item identity, native parent (when present), and the complete dependency graph.
An unchanged graph produces zero writes on repeat. A mismatch blocks without claiming publication.

## Native parent-issue mode

`--parent-issue new` explicitly requests one new top-level specification parent. An exact
`https://github.com/<owner>/<repo>/issues/<number>` URL selects one existing parent; it must be an
issue, not a PR, search result, title, or bare number. Parent mode requires only the exact canonical
repository, the explicit selector, and the native issue/hierarchy/dependency capabilities. It does
not resolve a Project, require Project settings or Status fields, or call Project APIs.

For an existing parent, independently read its open issue state, actual parent, complete body and
relevant comments, every paginated direct child, each child's actual parent and complete contract,
and all dependency pages. The selected parent must be top-level (`parent = null`) and have one level
of direct PR-sized children. Nested containers, foreign/conflicting parents, missing expected native
children, incomplete pagination, duplicate task mappings, or ambiguous identities block before
mutation. A readable body index or `Parent: #N` prose is not hierarchy evidence.

Before any write, including a parent-body update or child creation, prove that the fully paginated
existing direct-child set plus all planned additional links fits GitHub's
[100 direct-sub-issue limit](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/adding-sub-issues).
Count unique native child identities already linked once, plus every admitted child not yet linked
(including same-publication children recovered after an interrupted create); a new parent starts
with zero existing children. Unknown membership or a total above 100 blocks publication before
creating any issue. Do not truncate the candidate, split parents, or remove retained children to fit.
Recheck capacity during the existing pre-mutation drift admission; concurrent additions require
fresh admission, not optimistic continuation.

Synchronize in strict order:

1. **Specification parent.** For `new`, prove zero marker matches, create one parent issue once, and
   independently read back its canonical URL, REST/GraphQL identities, marker, complete specification,
   and top-level parent state. Bind it separately as `specItem`, never as a task or dependency
   endpoint. For an existing parent, patch only the admitted managed specification span; unchanged
   content is a no-op and unrelated human bytes survive.
2. **Child issues.** For each explicitly new task key, prove zero marker matches, create one complete
   issue contract, independently read it back, and bind its canonical/native identities once. Every
   child body carries the canonical parent URL, relevant specification context, stable identity,
   scope, non-goals, affected interfaces, acceptance, verified checks and smoke scenario, risks,
   prerequisites, and Git-parent-selection policy. Retained descriptions follow the existing-
   description invariant; conflicting or missing retained identities block.
3. **Native containment.** For each newly allocated child, independently read its actual parent and
   the parent's fully paginated sub-issue list. An exact existing link is a no-op. If both reads
   conclusively show `parent = null`, round-trip the required native IDs and add exactly one
   sub-issue link without replacement/reparenting, then verify the child's parent and parent's full
   child list in both directions. A different or unknown parent blocks. Missing links on retained
   children are drift, not permission to adopt or reparent; unknown link outcomes require fresh
   two-sided discovery before retry.
   A child already created by this same publication remains newly allocated for an unfinished link
   only when its original creation intent, marker, and bound native identity are retained and verified;
   interruption never turns that receipt into permission to adopt an unrelated issue.
4. **Task index and prerequisites.** After every child identity and native parent link is verified,
   reconcile the parent's managed child index and read it back. Write only declared child-to-child
   `blocked-by` edges; parent containment is not a prerequisite, and no parent edge, external endpoint,
   or ordinal-derived edge is allowed.
5. **Final read-back.** Independently read the parent specification/index, every child issue and full
   contract, each actual parent, all stable mappings, and every dependency page. Require exactly the
   admitted child set and exact normalized prerequisite tuples with both endpoints verified. Report
   the parent separately from task mappings and unresolved Git-parent joins.

An empty candidate creates nothing; an existing empty parent with no planned tasks is reported as no
work, not successful implementation. Preserve issue state and delivery evidence; never close or reopen
issues. Parent containment receives no task key, worker, worktree, PR, or dependency edge.

## Composed callers and recovery

A caller may supply an approved specification, repository/evidence identity, and a candidate issue
plan. Plan drafts the smallest coherent PR-sized candidate when one is not supplied, passes the
complete candidate through the public Harden content interface once, and pauses for explicit user
resolution of every material discrepancy. Harden is read-only and never calls Plan; Plan never calls
Plan recursively. Publication starts only from Harden's complete handback with no unresolved
questions. A Prepare caller passes that same packet to Plan and records the returned publication
evidence if needed; it does not perform a draft-only Plan call or a second publication.

Every boundary retains confirmed mutation identities, exact URLs/native IDs, and the last verified
operation. A partial or unknown result returns confirmed parent/children and the missing links,
relations, or read-back boundary, and cannot claim readiness. Resume only the first unproved operation
with the same identities after fresh drift admission. A complete unchanged repeat performs no writes.

## Return

Return the exact canonical repository and admitted revision, selected scope, complete display-ordered
child contracts, actual parent/child URLs and native identities, exact normalized graph, native-parent
read-back, focused verification provenance, mutation/read counts, stable recovery identities, and any
remaining missing relation. In parent mode also return the separate specification-parent URL and the
independently verified child index. When required relationships are verified, provide the separate
command matching the admitted scope:

```text
/woostack-orchestrate --issue <verified specification-parent-URL>
/woostack-orchestrate --project <verified selected-Project-URL>
```

Show only the applicable command; Project mode does not invent a specification parent.

That command is a handoff suggestion, not an automatic dispatch or execution claim. A partial graph,
missing relationship capability, stale specification, unresolved correction, unknown identity, or
empty executable plan is not Orchestrate-ready.
