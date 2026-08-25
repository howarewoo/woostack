# Plane artifact provider profile

This profile implements the provider-specific side of the shared
[local run artifact and provider mirror contract](../artifact-backends.md). Load it only when
`artifacts.provider: "plane"`. The shared contract owns authority, local artifacts, ordering,
recovery, failure handling, and read-back invariants; this profile owns Plane identities, scope,
capabilities, membership, and work-item lifecycle mappings.

## Configuration and scope

Require a validated `artifacts.plane` object containing canonical `baseUrl`, `workspace`,
`repository`, nonempty `projectLabels`, `projectStatuses`, and `issueStates`. Resolve configuration
only after Plane is selected. Plane project status is unsupported by woostack; `projectStatuses`
remains validated configuration but never authorizes synthesizing or mutating a Plane project status.

Use only the host-authenticated official Plane MCP. Support Plane Cloud and self-hosted installations,
scoped strictly to the configured canonical `baseUrl`, workspace, project, and repository. Plane
configuration is manual non-secret policy; Init does not discover Plane defaults.

## Capabilities

Before an operation, prove the minimum official-MCP capabilities for exact project/work-item reads,
complete pagination, requested mutation, and independent read-back. Project admission requires
`projectLabelRead` and `projectLabelWrite` plus listing, resolving, attaching, and complete label
read-back. Missing capability blocks only the selected provider boundary; no custom REST, GraphQL,
or token fallback is allowed.

## Projects and labels

Build resolves an exact project URL or native UUID, or creates one canonical project from validated
baseUrl/workspace/repository/projectLabels defaults. Fix reaches proved root cause before resolving or
creating its canonical project. Standalone Plan persists only to an exact selected project. Plane
projects have native UUIDs and no assumed stable human-readable project identifier.

Completely paginate workspace project labels with a null terminal cursor. Resolve each configured
label by exact native UUID or exact case-sensitive name. Reject missing, ambiguous, duplicate, or
incomplete results before mutation. Union configured labels with existing labels, preserving
unrelated labels; write at most once and independently read back the complete label set.

## External identities and recovery

Use Plane-native `external_source: "woostack"` and `external_id: <UUID>` for project, work-item, and
relation creation. Preallocate one UUID per entity, persist it in manifest mirror mappings through
manifest CAS, and bind it to that exact pair before creation. Completely paginate active and archived
resources and prove zero exact-pair matches before one create. Recover an unknown result only by
repeating complete discovery for the same pair. Exactly one ownership-valid match may proceed to an
exact native UUID read; otherwise block without allocating another identity or replaying creation.

Independently verify the complete intended resource, canonical repository, baseUrl, workspace,
project membership, native UUID, readable identifier where applicable, and external identity after
creation.

## Work-item identity, membership, and graph

Projects accept exact URLs or native UUIDs. Work items accept exact URLs or readable identifiers such
as `ENG-42`; resolve them to distinct native UUIDs within the configured baseUrl/workspace/project.
Stable task mappings retain the readable canonical work-item reference while mutation receipts retain
native UUID and external identity separately.

Every complete work-item read requests native UUID, readable identifier, repository, baseUrl,
workspace, direct project membership, and parent. A direct current work item must have `parent = null`.
Omission is null only when the field was requested and the response and pagination are complete.

Before membership or relation mutation, completely read all retained work items and relation pages,
round-trip relation endpoints by native UUID, and verify exact scope, direct membership, and null
parent state. For a new work item: create once, read it back, bind its stable task mapping once, write
direct project membership using native project/work-item UUIDs, read membership back, then write
relations. Membership operations do not reuse `external_source` or `external_id`.

Relations use their own external identity. Discover a relation only after both native work-item
endpoints have been independently read back. Create it with exact native endpoints and type, then
independently read the complete terminal-paginated relation graph back.

An exact Fix source work item is context only. Preserve its title, description, state, assignment,
labels, relations, comments, and lifecycle. After canonical Fix project admission, the only supported
source mutation is one direct project link followed by exact membership read-back.

## Lifecycle and closure

Plane Execute mutates and reads back only configured work-item states. Resolve
`artifacts.plane.issueStates.executing`, `inReview`, `done`, and `blocked` by exact native UUID or exact
case-sensitive name within canonical baseUrl/workspace/project scope. Reject missing, ambiguous,
duplicate, foreign-scope, or group-mismatched states. Read back native ID, name, and group.

Allowable groups are: executing and inReview require `started`; done requires `completed`; blocked
requires `started`. An exact current state is an idempotent no-op. Provider-mode transition failure
blocks at that lifecycle boundary; optional local-run mirror failure after an authoritative local
checkpoint remains nonblocking.

Never mutate, synthesize, archive, or gate on Plane project status. Handoff, abandonment, blockage,
and completion retain the exact project unchanged and record only work-item and local recovery state.

## Workflow procedures

Build and Plan use the detailed [Plane context](../../../woostack-build/references/plane-context.md)
and [Plane synchronization procedure](../../../woostack-build/references/plane-procedure.md).
Bootstrap and Commit retain their workflow gates and use this profile only for selected-provider
identity, capability, mutation, and read-back behavior.
