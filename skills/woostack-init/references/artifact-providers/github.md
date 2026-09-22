# GitHub artifact provider profile

This profile implements the provider-specific side of the shared
[local run artifact and provider mirror contract](../artifact-backends.md). Load it only when
`artifacts.provider: "github"`. The shared contract owns authority, local artifacts, ordering,
recovery, failure handling, and read-back invariants; this profile owns GitHub identities, owner and
selected Project or specification-parent admission, native issue hierarchy, blocked-by dependencies,
and Project membership/Status lifecycle mappings where a Project is selected.

## Configuration and scope

Select the scope before resolving scope-specific configuration. Parent-issue planning requires
`artifacts.provider: "github"` and a verified canonical GitHub repository; a configured `owner`
must match that repository, but missing Project configuration does not block this mode.
Project mode requires a validated `artifacts.github` object containing `owner` and `projectStatuses`,
plus optional `ownerType` (`"organization"` | `"user"`), `statusField` (default `"Status"`), and
`visibility` (`"private"` | `"public"`, default `"private"`). `projectStatuses` maps exactly five unique option names:
`planned`, `executing`, `inReview`, `done`, and `blocked`.

Use only the host-authenticated official `gh` CLI (`gh api graphql` for Projects v2 and dependencies;
issue APIs for repository issues). Custom HTTP/REST/GraphQL clients, credential reads, and token forwarding
remain forbidden. Scope operations strictly to the canonical repository and explicitly selected
parent issue or Project; parent selection never selects a Project or provider mirroring.
When GitHub is selected, Init may use `gh` only for narrow read-only discovery of owner, owner type,
canonical repository, and Status field/options without selecting persistence or mutating GitHub.

## Capabilities

Prove each operation's capabilities independently through host-authenticated `gh`: issue reads/writes,
native parent/sub-issue reads/writes, dependency reads/writes, terminal pagination, and independent
read-back. Issue-write access alone does not prove sub-issue or dependency-write access. Before
publication, preflight every required write family without a test mutation; unsupported or unknown
capability blocks. Project read/write, membership, and Status capabilities are required only for
selected Project operations. Unavailable Project access does not block parent-only planning.

Use GitHub's [native sub-issue API](https://docs.github.com/en/rest/issues/sub-issues) through `gh api`.
`GET repos/{owner}/{repo}/issues/{number}/sub_issues` must exhaust all pages; read the actual
parent independently (`GET .../parent` or an explicitly selected nullable GraphQL `parent`).
An HTTP error is not proof of `parent = null`. `POST .../sub_issues` takes the child's numeric
REST `id` as `sub_issue_id`, not its issue number or GraphQL node ID. Never set `replace_parent`
to true. API permission to link another repository's issue does not widen the canonical-repository
scope. Require native reads in both directions after a link write.

## Projects and labels

Owner admission verifies `artifacts.github.owner` login, type, and node ID. Build and Fix resolve one
supplied Project or create one `[Build]/[Fix] <goal>` Project after zero matches across owner pagination.
Newly created Projects use configured visibility with private default; supplied Projects retain existing visibility.
Standalone Plan's Project mode uses only an exact supplied Project.

The specification is written inside `ProjectV2.readme` between markers `<!-- woostack-spec-start -->` and
`<!-- woostack-spec-end -->`, preserving unrelated README bytes. Every Project create preallocates one UUID
and embeds `<!-- woostack-project-mutation:<UUID> -->` in the managed section for duplicate-safe discovery
and recovery. Projects v2 does not require project labels; repository labels and existing views are preserved.

## Specification parent and native children

Standalone Plan explicitly selects `--parent-issue new` or one canonical existing parent issue URL,
exclusive with `--project`. Verify canonical repository/owner/native identities from trusted Git and
GitHub evidence. For an existing parent, independently read its open issue state (not a PR), actual
parent, complete body and relevant comments, every native sub-issue page, and every child's actual
parent, identity, full contract, dependency pages, and existing delivery evidence. Require a
top-level specification parent (`parent = null`) and one level of direct PR-sized children.
Nested containers, foreign/conflicting parents, missing expected children, incomplete pagination,
duplicate task mappings, or ambiguous identity block before mutation. Do not silently flatten,
skip work, infer a parent from omission, or convert a historical Project plan.

The parent retains the approved specification, constraints, non-goals, overall acceptance,
inspected repository revision, and canonical child task index. Each child carries the canonical
parent URL and the full [Plan task contract](../../../woostack-plan/SKILL.md#direct-issue-contract).
The readable index and `Parent: #N` prose are not native membership evidence. New publication may
fill explicitly planned missing links only for newly allocated children under the synchronization
procedure; missing retained links are drift, not permission to adopt unrelated issues.

Containment, prerequisites, and Git ancestry are separate: native direct children define parent-mode
scope; native blocked-by edges between tasks define prerequisites; Git branches define eventual PR
bases. The specification parent never enters task mappings or dependency endpoints and receives no
implementation worker, worktree, or PR. A parent with no planned tasks is no work; an index naming
children absent from native reads is incomplete publication, not a ready hierarchy.

Retain the fully admitted hierarchy snapshot, including native IDs and complete contracts. New,
removed, or changed children require fresh admission before another synchronization; never expand
scope from a changed response. External prerequisites do not expand the selected scope and block
publication readiness until the missing endpoint contract is resolved.

Existing explicit Project plans remain supported with no automatic conversion or reparenting.
In Project mode, completely paginate membership and distinguish specification containers from
executable items. A container is not an extra task; only explicitly admitted member tasks execute
as increments, each once. Do not pull nonmember children into scope automatically. For intentionally
parented members, verify the exact declared parent and native link separately from Project membership.
Unmatched containers remain preserved and excluded, not flattened.

## Issue identity and graph

Canonical issue URLs (`https://github.com/owner/repo/issues/<N>`) are displayed task mappings and Commit
references; native GraphQL and REST IDs are retained separately for the APIs that require each form.
Every increment is a normal repository issue in the selected scope: a verified native child in
parent mode or a direct Project member in Project mode. Existing parentless Project issues retain
`parent = null`. Issue creation embeds `<!-- woostack-issue-mutation:<UUID> -->` in the body for
duplicate-safe pagination recovery; specification parents use that same issue marker convention
with their own distinct UUID and separate specification binding.

Every increment has a unique stable task ID, a unique positive display ordinal, and an explicit
predecessor set naming admitted task IDs. Ordinals are stable display and tie-break order only; they are not
dependency or ancestry order, and gaps or edges against display order do not invalidate the graph.
Independent roots, forks, chains, and joins are valid; only declared predecessors become native
`blocked-by` edges. Normalize every edge as one prerequisite→dependent tuple in `[prerequisite, dependent]`
order. A tuple maps to exactly one native `blocked-by` edge on the dependent pointing at the prerequisite:
the second identity is GitHub's current dependent issue and the first is its `blockedBy` issue.
Read both native endpoint collections independently and normalize them back into the same
`[prerequisite, dependent]` order before comparing the complete edge set. Require read-back to verify both
endpoint identities, not an edge count. An exact Fix source issue is read-only context; after admission it
receives only one direct Project link.

Admission validates the complete graph before persistence or provider mutation and rejects duplicate
task IDs, ordinals or prerequisites, self-dependencies, cycles, missing endpoints, ambiguous identities, incomplete
pagination, and foreign repository or selected scope. An explicitly new task key (mapping `null` with a
preallocated UUID) is the only case that may create; any other unmapped endpoint is an invalid missing
endpoint and blocks. No check silently broadens repository, parent, or Project scope.

A root records the approved integration parent branch. Each dependent records its complete prerequisite
set and a parent-selection policy for resolving one concrete Git parent branch and SHA from verified
delivered predecessor branches or an explicitly approved integration parent at dispatch. Future
Orchestrate resolves that parent for graph dispatch; a caller selecting one bounded task supplies
the parent and readiness evidence. Plan never chooses it speculatively or creates an integration
branch or artificial chain.
One verified parent must contain all required predecessor changes. The
[parent-admission contract](../worktrees.md#plan-dependency-child) requires canonical branch/SHA
ancestry and every prerequisite's complete delivery evidence; an integration parent's own PR evidence
is required only when that PR exists. A join lacking the required proof remains valid but pauses that
issue for an explicit parent/integration decision before dispatch.

Ordinal edits never change edges. Existing chain edges are preserved unless the approved specification
explicitly changes them; never add or remove edges to match ordinal adjacency. Preserve unrelated issue
fields, unrelated Project state, historical parent/container resources, and stable marker identities.
Verification scripts follow explicit predecessors only: each named repository-local script or path must
already exist at the last admitted parent tip, be created by a declared predecessor ordered before use,
or be created by the same increment before use.

Before issue creation, membership, parent linkage, or relation mutation, completely read every
retained issue and relation page, round-trip every endpoint in its required identity form, and
verify canonical repository and selected scope: exact native parent links for parent mode, or
direct membership and the admitted parent state for Project mode. Use the manifest's preallocated
stable mutation identities in mirror mode, or retained standalone mutation identities. Creation
binds once after independent read-back; required parent links and selected memberships follow
binding; dependencies follow verified scope membership.
After an unknown create outcome, recover only by repeating complete discovery for the same marker UUID;
never allocate another identity or replay the create. Compare complete current reads with the admitted
candidate before writes: unchanged fields, memberships, parent links, and edges are no-ops. Remove an existing edge
only when the approved specification explicitly changes that prerequisite; unexpected drift blocks,
never silently pruning a chain. Independently read back every specification/task issue, description,
native parent link, selected membership, and complete exact predecessor→successor edge set.
Mirror mismatches record failure without changing local artifacts; standalone mismatches block
without claiming synchronization.

Retain the complete DAG for future Orchestrate; Execute cannot accept or dispatch it as a graph.
A caller may select one task from any valid DAG for
[bounded Execute admission](../../../woostack-execute/SKILL.md#admit-one-task), supplying its concrete
parent and complete prerequisite-readiness evidence under the
[worktree contract](../worktrees.md#plan-dependency-child). An unresolved join parent blocks that
task, not unrelated tasks. Run-store storage retains the existing task/dependency/mapping forms
without schema migration or edge rewriting; workflow admission validates the DAG.

Reuse existing task/dependency/mapping representations. A specification parent is retained separately
as `specItem` (in `mirror.specItem` when a run manifest applies), never in `stableTaskMappings`.
Standalone Plan retains the same canonical/native/marker identities and last verified mutation
boundary in its handback, not a new Build/Fix run, hidden ledger, or storage schema. Incomplete
identity recovery blocks further publication rather than allocating a replacement.

## Lifecycle and closure (retired Execute reference)

> **Retired.** Execute no longer performs GitHub Project/issue lifecycle transitions, run-controller
> reads, or closure. It accepts one bounded task and an optional exact GitHub issue URL; the issue
> path is read-only until Commit adds the verified closing reference. The retained `projectStatuses`
> fields and historical records support Build/Plan mirroring only; see
> [`woostack-execute`](../../../woostack-execute/SKILL.md#retired-inputs).

An explicitly requested provider-backed standalone Plan closure uses only the retained exact
Project. Independently verify its canonical identity and current state, update only its `closed`
state, and read back that same Project as closed. An already-closed Project is an independently
verified no-op. Do not create a replacement, close issues, alter membership or dependencies, or
bulk-change resources. An unknown outcome requires fresh discovery before retry.

## Workflow procedures

Build/Fix keep their optional Project mirrors. Standalone Plan also supports the explicitly selected
native parent hierarchy through the [GitHub synchronization procedure](../../../woostack-build/references/github-procedure.md).
Bootstrap, Commit, and Status retain their own workflow gates; planning support alone does not widen
their inputs or authorize execution.
