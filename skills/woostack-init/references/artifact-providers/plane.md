# Plane artifact provider profile

This profile implements the provider-specific side of the shared
[local run artifact and provider mirror contract](../artifact-backends.md). Load it only when
`artifacts.provider: "plane"`. The shared contract owns authority, local artifacts, ordering,
recovery, failure handling, and read-back invariants; this profile owns Plane identities, scope,
capabilities, membership, and work-item lifecycle mappings.

## Configuration and scope

Require a validated `artifacts.plane` object containing canonical `baseUrl`, `workspace`,
`repository` (canonical repository `owner/name` or URL), nonempty `projectLabels`, `projectStatuses`,
and `issueStates`. Resolve configuration only after Plane is selected. Plane project status is
unsupported by woostack; `projectStatuses` remains validated configuration but never authorizes
synthesizing or mutating a Plane project status.

Use only the host-authenticated official Plane MCP. Support Plane Cloud and self-hosted installations,
scoped strictly to the configured canonical `baseUrl`, workspace, canonical repository project
`[Repo] owner/name`, and repository. Plane configuration is manual non-secret policy; Init does not
discover Plane defaults.

## Capabilities

Before an operation, prove the minimum official-MCP capabilities for exact project/work-item reads,
complete pagination, requested mutation, and independent read-back. Project admission requires
`projectLabelRead` and `projectLabelWrite` plus listing, resolving, attaching, and complete label
read-back. Missing capability blocks only the selected provider boundary; no custom REST, GraphQL,
or token fallback is allowed.

## Projects and labels

Plane uses one canonical repository project per repository named `[Repo] owner/name` (derived from
canonical repository identity, such as `owner/name` from `https://github.com/owner/name`). Build (during
mirror synchronization) and standalone Plan resolve or create this single `[Repo] owner/name` project.
Delegated Plan performs zero provider reads or writes; its Build wrapper resolves or creates the project
when mirroring is enabled. When `--project` is supplied, it must match this canonical `[Repo] owner/name`
project URL or native UUID; a mismatched project fails closed before any mutation.

Project description is repository-only (or brief repository description) and is never overwritten with
feature specifications. Plane projects have native UUIDs and no assumed stable human-readable project
identifier.

Completely paginate workspace project labels with a null terminal cursor. Resolve each configured
label by exact native UUID or exact case-sensitive name. Reject missing, ambiguous, duplicate, or
incomplete results before mutation. Union configured labels with existing labels, preserving
unrelated labels and every unrelated project label; write at most once and independently read back the complete label set.

## External identities and recovery

Use Plane-native `external_source: "woostack"` and `external_id: <UUID>` for project, specification
work-item, increment work-item, and relation creation. Preallocate one UUID per entity, persist it in
manifest mirror mappings through manifest CAS, and bind it to that exact pair before creation.
Completely paginate active and archived resources and prove zero exact-pair matches before one create.
Recover an unknown result only by repeating complete discovery for the same pair. Exactly one
ownership-valid match may proceed to an exact native UUID read; otherwise block without allocating
another identity or replaying creation.

Independently verify the complete intended resource, canonical repository, baseUrl, workspace,
project membership, native UUID, readable identifier where applicable, and external identity after
creation.

## Work-item identity, membership, and graph

Projects accept exact URLs or native UUIDs. Work items accept exact URLs or readable identifiers such
as `ENG-42`; resolve them to distinct native UUIDs within the configured baseUrl/workspace/project.
Stable task mappings retain the readable canonical increment work-item reference while mutation
receipts retain native UUID and external identity separately.

Every complete work-item read requests native UUID, readable identifier, repository, baseUrl,
workspace, direct project membership, and parent.

1. **Specification work items:** Build and Plan create one top-level specification work item in the
   `[Repo] owner/name` project named `[Build] <goal>` (for Build) or `[Plan] <goal>` (for Plan), with
   its full specification content in its description and `parent = null`. It has separate native UUID,
   readable identifier, and external identity. It binds to `mirror.specItem` in the manifest and never
   enters `stableTaskMappings`.
2. **Increment work items:** Increment work items are created directly in the `[Repo] owner/name`
   project as exact children of that specification work item (`parent = <spec-item-UUID>`). Each has
   direct project membership, preallocated external identity, native UUID, readable identifier, and its
   complete executor-ready description.
3. **Task mappings:** `stableTaskMappings` maps each stable task key to its child increment work item's
   readable reference (and native UUID in `mirror.tasks`).
4. **Sibling blocking relations:** Native work-item-to-work-item blocking relations are created between
   increment child work items matching the strict chain (`N-1` strict blocking relations for `N`
   increments: `ordinal k-1` blocks `ordinal k`). Discover and create relations using native work-item
   endpoints and preallocated relation external identities.

Before membership, parent linkage, or relation mutation:

1. completely read all retained work items and relation pages;
2. round-trip relation endpoints by native UUID;
3. verify exact scope, direct project membership, `parent = null` for the specification work item, and
   exact specification parent UUID for increment work items.

An exact Fix source work item is context only. Preserve its title, description, state, assignment,
labels, relations, comments, and lifecycle. After canonical Fix project admission, the only supported
source mutation is one direct project link followed by exact membership read-back.

## Workflow procedures

Build and Plan use the detailed [Plane context](../../../woostack-build/references/plane-context.md)
and [Plane synchronization procedure](../../../woostack-build/references/plane-procedure.md). Standalone
Plan synchronizes the graph directly; delegated Plan remains provider-free and delegates mirror
synchronization to the Build wrapper. Bootstrap and Commit retain their workflow gates and use this
profile only for selected-provider identity, capability, mutation, and read-back behavior.

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
