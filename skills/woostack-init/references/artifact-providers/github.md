# GitHub artifact provider profile

This profile implements the provider-specific side of the shared
[local run artifact and provider mirror contract](../artifact-backends.md). Load it only when
`artifacts.provider: "github"`. The shared contract owns authority, local artifacts, ordering,
recovery, failure handling, and read-back invariants; this profile owns GitHub identities, owner and
Project admission, managed README specification sections, parentless repository issues, direct Project
membership, native blocked-by dependencies, and Status field lifecycle mappings.

## Configuration and scope

Require a validated `artifacts.github` object containing `owner` and `projectStatuses`, plus optional
`ownerType` (`"organization"` | `"user"`), `statusField` (default `"Status"`), and `visibility`
(`"private"` | `"public"`, default `"private"`). `projectStatuses` maps exactly five unique option names:
`planned`, `executing`, `inReview`, `done`, and `blocked`.

Use only the host-authenticated official `gh` CLI (`gh api graphql` for Projects v2 and dependencies;
issue APIs for repository issues). Custom HTTP/REST/GraphQL clients, credential reads, and token forwarding
remain forbidden. Scope operations strictly to the configured `owner`, canonical Git repository, and Project.
When GitHub is selected, Init may use `gh` only for narrow read-only discovery of owner, owner type,
canonical repository, and Status field/options without selecting persistence or mutating GitHub.

## Capabilities

Prove host-authenticated `gh` capabilities before an operation: `projectRead`, `projectWrite`,
`projectDelete`, `issueRead`, `issueWrite`, `issueClose`, `issueDelete`, `dependencyRead`,
`dependencyWrite`, `statusFieldRead`, `statusFieldWrite`, `pagination`, and `independentReadBack`.
Missing capability fails closed.

## Projects and labels

Owner admission verifies `artifacts.github.owner` login, type, and node ID. Build and Fix resolve one
supplied Project or create one `[Build]/[Fix] <goal>` Project after zero matches across owner pagination.
Newly created Projects use configured visibility with private default; supplied Projects retain existing visibility.
Standalone Plan uses only an exact supplied Project.

The specification is written inside `ProjectV2.readme` between markers `<!-- woostack-spec-start -->` and
`<!-- woostack-spec-end -->`, preserving unrelated README bytes. Every Project create preallocates one UUID
and embeds `<!-- woostack-project-mutation:<UUID> -->` in the managed section for duplicate-safe discovery
and recovery. Projects v2 does not require project labels; repository labels and existing views are preserved.

## Issue identity and graph

Canonical issue URLs (`https://github.com/owner/repo/issues/<N>`) are displayed task mappings and Commit
references; native GraphQL IDs are retained separately in mirror state. Every increment is a normal parentless repository
issue (`parent = null`) added directly as a Project item. Issue creation embeds
`<!-- woostack-issue-mutation:<UUID> -->` in the body for duplicate-safe pagination recovery.

Every increment has a unique stable task ID, a unique positive display ordinal, and an explicit
predecessor set naming admitted task IDs. Ordinals are stable display and tie-break order only; they are not
dependency or ancestry order, and gaps or edges against display order do not invalidate the graph.
Independent roots, forks, chains, and joins are valid; only declared predecessors become native
`blocked-by` edges. Normalize every edge as one prerequisite→dependent tuple in `[prerequisite, dependent]`
order. A tuple maps to exactly one native `blocked-by` edge on the dependent pointing at the prerequisite:
the dependent is the current issue and the prerequisite is the blocking issue. Normalize provider reads
back into the same `[prerequisite, dependent]` order and require independent read-back to verify both
endpoint identities, not an edge count. An exact Fix source issue is read-only context; after admission it
receives only one direct Project link.

Admission validates the complete graph before persistence or provider mutation and rejects duplicate
task IDs, ordinals or prerequisites, self-dependencies, cycles, missing endpoints, ambiguous identities, incomplete
pagination, and foreign repository or Project scope. An explicitly new task key (mapping `null` with a
preallocated UUID) is the only case that may create; any other unmapped endpoint is an invalid missing
endpoint and blocks. No check silently broadens repository or Project scope.

A root records the approved integration parent branch. Each dependent records its complete prerequisite
set and a parent-selection policy for resolving one concrete Git parent branch and SHA from verified
delivered predecessor branches at dispatch. The concrete branch and SHA are resolved by future
Orchestrate, never speculatively by Plan and never as an auto-created integration branch or artificial
chain. One verified parent must contain all required predecessor changes, proved by delivered branch,
commit/SHA, canonical PR head/base, and merge-state evidence. A join lacking that proof
remains valid but pauses that issue for an explicit parent/integration decision before dispatch.

Ordinal edits never change edges. Existing chain edges are preserved unless the approved specification
explicitly changes them; never add or remove edges to match ordinal adjacency. Preserve unrelated issue
fields, unrelated Project state, historical parent/container resources, and stable marker identities.
Verification scripts follow explicit predecessors only: each named repository-local script or path must
already exist at the last admitted parent tip, be created by a declared predecessor ordered before use,
or be created by the same increment before use.

Before issue creation, direct membership, or relation mutation, completely read every retained issue,
membership, and relation page, round-trip every endpoint in its required identity form, and verify
canonical repository, exact Project, direct membership, and `parent = null`. Use the manifest's
preallocated stable mutation identities in mirror mode, or the retained standalone mutation identities;
creation binds once after independent read-back, membership follows binding, and relations follow membership.
After an unknown create outcome, recover only by repeating complete discovery for the same marker UUID;
never allocate another identity or replay the create. Compare complete current reads with the admitted
candidate before writes: unchanged fields, memberships, and edges are no-ops. Remove an existing edge
only when the approved specification explicitly changes that prerequisite; unexpected drift blocks,
never silently pruning a chain. Independently read back every issue, membership, description, and the
complete exact predecessor→successor edge set after mutation. Mirror mismatches record failure without
changing local artifacts; standalone mismatches block without claiming synchronization.

Persisting a DAG does not make it runnable by current Execute. Current Execute remains sequential,
admits only the strict sequential contract, and must reject branching, multi-root, or join graphs
before worktree, source, or provider mutation, retaining artifacts and edges unchanged. Run-store
storage retains the existing task/dependency/mapping forms without schema migration or edge rewriting;
workflow admission validates the DAG.

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

Build and Plan synchronize the local specification and increment graph to GitHub Projects and
repository issues using this profile's admission, managed README section, membership, dependency,
and lifecycle rules. Bootstrap, Commit, and Status retain their workflow gates and use this
profile for selected-provider identity, capability, mutation, and read-back behavior.
