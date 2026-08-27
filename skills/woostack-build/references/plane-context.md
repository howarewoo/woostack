# Plane project context

When optional Plane mirroring is enabled (`artifacts.provider: "plane"`), this procedure resolves the
exact configured Plane project for [`woostack-build`](../SKILL.md) and admits each exact pre-draft
baseline. When `artifacts.provider` is "local" or omitted, default local mode makes zero provider calls,
`--project` fails closed before any provider access, and local run authority in
`.woostack/tmp/runs/<run-id>/` operates with no provider context. Repository policy supplies validated
defaults only after Plane mirroring is selected and enabled; policy never authorizes provider access
by itself.

The shared [artifact contract](../../woostack-init/references/artifact-backends.md) owns the run
manifest, plain artifacts, mutation ordering, failure handling, and read-back invariants. The
[Plane provider profile](../../woostack-init/references/artifact-providers/plane.md) owns Plane scope,
capabilities, identities, labels, memberships, relation endpoints, and lifecycle mappings. The shared
[repository ancestry contract](../../woostack-init/references/artifact-backends.md#repository-ancestry-and-base-change-detection)
separately governs parent-branch intent and base-change detection; use the
[Plane synchronization procedure](plane-procedure.md) only for the bounded mirror save or standalone Plan.

## Resolution
1. Resolve the canonical repository URL and repository name `owner/name` from trusted Git/GitHub evidence.
2. Resolve the configured Plane instance `baseUrl`, `workspace`, and exact `artifacts.plane.project`
   URL or native UUID. Never infer a project from repository identity or recent/name-based discovery.
3. Preflight official Plane MCP capabilities for exact project reads, selectable direct work item
   identity/project/parent fields, complete paginated work item and relation reads, work item/project
   writes, relation writes, independent read-back, and workspace project-label discovery/updates
   (`projectLabelRead`, `projectLabelWrite`).
4. Read only the configured project and verify its native identity, instance `baseUrl`, workspace, and
   canonical repository association. If `--project` is supplied, require it to resolve to the same native
   project UUID. Missing, ambiguous, foreign, or mismatched project evidence fails closed; never create
   a project.
5. Completely paginate all workspace project labels, require null terminal cursors, and resolve each
   configured `projectLabels` value by exact native UUID or exact case-sensitive name. Reject missing,
   ambiguous, duplicate, or incomplete matches. Union resolved labels with the configured project's
   existing labels, preserving unrelated labels; write at most once and independently read back the
   exact project identity, repository association, and complete label set into `mirror.project`.

## Project specification baseline

Specification drafting is local and provider-free in Ideate and Harden. After `project-spec.md` is written,
when `artifacts.provider: "plane"`, the shared contract performs one bounded synchronization to create or
reconcile one top-level specification work item in the configured project named `[Build] <goal>`
with `parent = null`.

Use `external_source: "woostack"` and preallocated `external_id: <UUID>`. Prove zero matches before creation.
Write the complete user-verified specification Markdown into its description. Independently read back
native UUID, readable identifier (`ENG-X`), title, description, and `parent = null`. Retain the specification
work item in `mirror.specItem` in the run manifest; specification items never enter `stableTaskMappings`.
Mirror failures are recorded in the manifest and are nonblocking.

## Direct increment graph baseline

When Plane mirroring is enabled, after `project-spec.md` is written and optional mirror synchronization
completes, child increment work items are created directly in the configured project as exact children
of the specification work item (`parent = <spec-item-UUID>`).

For each increment in `execution-plan.md`, use `external_source: "woostack"` and preallocate one separate UUID
bound to `external_id: <UUID>`. Immediately before the one create attempt, completely paginate all active and
archived work items in the resolved project/workspace, flatten every page, require null terminal cursors, and
prove zero exact external ID matches. Partial, duplicate, foreign, malformed, ambiguous, or nonzero matches block
before creation. An unknown outcome is recovered only by complete discovery of that same external ID pair: zero,
duplicate, foreign, malformed, drifted, partial, or otherwise unknown candidates fail closed without a replacement
UUID or create replay.

Create each increment work item with `parent = <spec-item-UUID>`, full executor-ready description, and direct
project membership. Bind the stable task key to the native work item reference in `stableTaskMappings` and
`mirror.tasks`. Direct project membership is verified alongside creation before any native-relation graph write.

Read and create native work-item-to-work-item sibling blocking relations matching the strict chain (`N-1` strict
blocking relations for `N` increments: `ordinal k-1` blocks `ordinal k`). Every relation source and target uses
the same native work item representation and exact instance/workspace/project scope, then independently round-trips
through its official-MCP endpoint. Normalize admitted `blocks`/`blocked_by` relations into predecessor→successor
tuples. Reject unknown parent state, duplicates, unknown direction/kind, missing endpoints, endpoints outside
the exact specification children graph, cycles, or ambiguous ordering.

This selectable-field, complete-pagination, endpoint-round-trip, and parent-state preflight runs before any
direct project-membership or native-relation graph write. A failed preflight blocks with zero provider and
repository mutation.

Historical parent plan issues and their children are noncanonical history. Preserve them, exclude them from
the baseline, and never detach, migrate, archive, delete, or reconcile them. Store the complete exact project,
specification work item, child increment work item identities/revisions/content, and sibling dependencies in the
manifest. Delegated Plan and Harden then make zero provider reads and writes while drafting. After
`execution-plan.md` is written, when `artifacts.provider: "plane"`, the shared contract performs drift
comparison, one bounded synchronization, stable-key mapping, and exact graph read-back; mirror failures are
nonblocking.

## Drift and failure

Before either mirror save, when Plane mirroring is enabled, compare a fresh complete read with the
manifest baseline. Provider read or synchronization failures in mirror mode are recorded in the
manifest and are nonblocking for local authority, artifact retention, or handoff. Local manifest,
permission, and file safety failures remain strictly blocking.

When Plane mirroring is enabled during Build, before drafting, before mirror synchronization, and at handoff,
repeat the provider mirror read:

- provider project drift is reported and recorded in mirror status;
- provider work item or dependency drift is reported and recorded in mirror status;
- unrelated metadata do not affect local authority; and
- missing capability, incomplete pagination, or unknown provider outcomes in mirror mode are recorded
  as mirror status and do not block local authority or handoff.

When `artifacts.provider: "local"` (or omitted), provider baseline and drift reads are omitted entirely.
