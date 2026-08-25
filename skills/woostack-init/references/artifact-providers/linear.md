# Linear artifact provider profile

This profile implements the provider-specific side of the shared
[local run artifact and provider mirror contract](../artifact-backends.md). Load it only when
`artifacts.provider: "linear"`. The shared contract owns authority, local artifacts, ordering,
recovery, failure handling, and read-back invariants; this profile owns Linear identities, scope,
capabilities, and lifecycle mappings.

## Configuration and scope

Require a validated `artifacts.linear` object containing canonical `repository`, `workspace`,
`team`, `projectLabels`, `projectStatuses`, and `issueStates`. `projectLabels` is an array of
non-empty strings and may be empty. Resolve configuration only after Linear is selected.

Use only the host-authenticated official Linear MCP. Scope every read and mutation to the selected
workspace, team, project, and canonical repository. Init may use that MCP for narrow authenticated
read-only discovery of missing non-secret repository, workspace, team, and native-name defaults; it
never selects persistence, reads development artifact content, probes writes, or authorizes later
access.

## Capabilities

Before an operation, prove the minimum official-MCP capabilities for its exact project/issue reads,
complete pagination, requested mutation, and independent read-back. Project admission additionally
requires complete workspace project-label discovery and update capabilities when labels are
configured. Missing capability blocks only the selected provider boundary.

## Projects and labels

Build resolves one exact caller-supplied project or creates one canonical project from validated
repository/workspace/team defaults. Fix reaches proved root cause before resolving or creating its
canonical project. Standalone Plan persists only to an exact selected project.

Completely paginate workspace project labels with a null terminal cursor. Resolve each configured
label by exact native ID or exact case-sensitive name. Reject missing, ambiguous, duplicate, or
incomplete results before mutation. Union configured labels with existing labels, preserving
unrelated labels; write at most once and independently read back the complete label set.

If project creation has no provider-native operation identity, preallocate one UUID and use the exact
summary marker `Woostack project mutation ID: <UUID>`. Prove zero exact matches across complete active
and archived project pagination before one create. Recover an unknown result only by repeating
complete discovery for that marker. Exactly one ownership-valid match may proceed to an exact native
ID read; otherwise block without allocating another identity or replaying creation.

## Issue identity and graph

The stable human-facing identifier, such as `WOO-144`, is the canonical issue reference. Use it for
caller selection, displayed task mappings, exact reads, project membership, and relation endpoints.
A native UUID may support one bounded mutation but never replaces the canonical reference.

If issue creation has no provider-native operation identity, preallocate one UUID and append the
exact title suffix `[woostack-mutation:<UUID>]`. Prove zero exact suffix matches across complete
active and archived issue pagination before one create. Recover only with the same suffix; exactly
one ownership-valid issue may proceed after an exact canonical-reference read.

Every complete issue read requests canonical and native identity, repository, workspace, team,
direct project membership, and `parentId`. A direct current issue must have null parent. Omission is
null only when the field was requested and the response and pagination are complete.

Before membership or relation mutation, completely read all retained issues and relation pages,
round-trip endpoints by canonical issue reference, and verify exact scope, membership, and null
parent state. For a new issue: create once, read by canonical reference, bind its stable task key once,
write and read back direct project membership, then write relations. Never create a parent plan issue.

An exact Fix source issue is context only. Preserve its title, description, status, assignment,
labels, relations, comments, and lifecycle. After canonical Fix project admission, the only supported
source-issue mutation is one direct project link followed by exact membership read-back.

## Lifecycle and closure

In provider Execute modes, resolve `artifacts.linear.issueStates.executing` and `inReview` to unique
same-team native states with category `started`. Resolve `artifacts.linear.projectStatuses.started`
to one native project status with category `started`. Missing, ambiguous, foreign, incomplete, or
category-mismatched resolution blocks before lifecycle or repository mutation.

When a current direct issue matches executing or inReview, synchronize the exact nonterminal project
to the configured started status. If all direct issues are Backlog or Todo, transition the selected
issue to executing and read it back first. Re-read the project before mutation, update only its native
status with one stable mutation identity, and independently read back identity, status ID/name/category,
revision, and mutation identity. An exact started status is an idempotent no-op; completed or canceled
projects are terminal conflicts.

A provider-backed standalone Plan or Execute closure uses only the retained exact project. Resolve
the configured canceled-category status, update only that status, and independently read it back.
Never create, archive, or delete a project to close it. Build/Fix handoff, blockage, and local-run
abandonment leave the mirrored project unchanged.

## Workflow procedures

Build and Plan use the detailed [Linear context](../../../woostack-build/references/linear-context.md)
and [Linear synchronization procedure](../../../woostack-build/references/linear-procedure.md).
Bootstrap and Commit retain their workflow gates and use this profile only for selected-provider
identity, capability, mutation, and read-back behavior.
