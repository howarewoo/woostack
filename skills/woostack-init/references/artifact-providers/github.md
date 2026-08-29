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
references; native GraphQL IDs are retained separately. Every increment is a normal parentless repository
issue (`parent = null`) added directly as a Project item. Issue creation embeds
`<!-- woostack-issue-mutation:<UUID> -->` in the body for duplicate-safe pagination recovery.

An admitted sequence of $N$ increments has $N-1$ native `blocked-by` dependencies (`ordinal k-1` blocks
`ordinal k`). Predecessor and successor issue node IDs are verified before and after relation mutation.
An exact Fix source issue is read-only context; after admission it receives only one direct Project link.

## Lifecycle and closure

Admission resolves the single-select Status field (`statusField`, default `"Status"`) and five distinct
options for `planned`, `executing`, `inReview`, `done`, and `blocked`.

New increment items begin at `planned`, transitioning to `executing` during execution, `inReview` at
delivery, and `done` (closing the issue) at completion. Recorded blockers set `blocked` without closing.
Completing all increments leaves the Project open; explicit Plan/Execute closure updates only Project closed
state after fresh read-back.

## Workflow procedures

Build and Plan synchronize the local specification and increment graph to GitHub Projects and
repository issues using this profile's admission, managed README section, membership, dependency,
and lifecycle rules. Bootstrap, Execute, Commit, and Status retain their workflow gates and use this
profile for selected-provider identity, capability, mutation, and read-back behavior.
