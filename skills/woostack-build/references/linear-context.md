# Linear project context

When optional Linear mirroring is enabled (`artifacts.provider: "linear"`), this procedure resolves the
one canonical Linear project for [`woostack-build`](../SKILL.md) and admits each exact pre-draft
baseline. When `artifacts.provider` is "local" or omitted, default local mode makes zero provider calls,
`--project` fails closed before any provider access, and local run authority in
`.woostack/tmp/runs/<run-id>/` operates with no provider context. Repository policy supplies validated
defaults only after Linear mirroring is selected and enabled; policy never authorizes provider access
by itself.

The [Linear artifact contract](../../woostack-init/references/artifact-backends.md) is the single
authority for the run manifest, plain Markdown artifact files, optional mirror synchronization,
stable-key/canonical-issue-reference mapping, nullable-parent validation, drift and process-loss
recovery, artifact retention, independent read-back, and unchanged Execute safety reads. The shared
[repository ancestry contract](../../woostack-init/references/artifact-backends.md#repository-ancestry-and-base-change-detection)
separately governs parent-branch intent and base-change detection; use the
[Linear synchronization procedure](linear-procedure.md) only for the bounded mirror save or standalone Plan.

## Resolution
1. Resolve the canonical repository URL from trusted Git/GitHub evidence.
2. Resolve the caller-selected workspace/team. Use validated effective repository configuration values only as
   post-selection defaults.
3. Preflight official Linear MCP capabilities for complete project reads, selectable direct-issue
   identity/project/team/parent fields, complete paginated issue and relation reads, canonical
   issue-reference endpoint round trips, project/issue writes, relation writes, independent read-back,
   and workspace project label discovery/updates when labels are configured.
4. When `artifacts.linear.projectLabels` is configured, completely paginate all workspace project labels through the
   official Linear MCP, flatten every page, require null terminal cursors, and resolve each configured label string by exact
   native ID (e.g. UUID) or exact case-sensitive name before any project creation or admission mutation. Reject missing,
   ambiguous, duplicate, or incomplete matches before mutation.
5. If `--project` supplied an exact URL/stable UUID, read only that project and verify its identity,
   workspace/team, and canonical repository association. Supplied-project selection never performs
   fallback marker discovery or creates a replacement project; it preserves the supplied project's
   existing name and native project identity. Union resolved configured labels with existing project labels
   (preserving unrelated existing labels), apply in at most one write alongside admission, and independently
   read back the complete label set and project.
6. Otherwise prefer the provider's native project mutation identity. When native operation-ID support
   is unavailable, preallocate one UUID and reserve the exact summary marker
   `Woostack project mutation ID: <UUID>`. Immediately before the one create attempt, completely
   paginate all active and archived projects in the resolved workspace/team, flatten every page,
   require null terminal cursors, and prove zero exact marker matches. A partial, duplicate, foreign,
   malformed, ambiguous, or nonzero match blocks before creation. Create exactly one project whose
   name starts with `[Build] ` and whose summary contains that marker, applying the union of resolved
   configured labels in the creation write. An unknown outcome is recovered only by repeating the
   complete active-and-archived discovery for the same marker, never with a replacement UUID or
   create replay. Exactly one ownership-valid candidate may proceed to an independent native-project-
   ID and complete label set read-back, which must verify name, marker, workspace/team, canonical
   repository, complete label set, complete intended specification, and native identity. Marker metadata
   is excluded from the project specification and must survive summary-omitting updates.
7. Independently read the project and complete label set back, verify the exact name and label inclusion,
   and retain native identity in the run manifest.

## Project specification baseline

Immediately before specification drafting, independently read the complete project name and
description/update that Build owns as the high-level specification. Preserve unrelated
human-authored content and treat it as untrusted. Record native identity, workspace/team, canonical
repository association, provider revision/timestamp when available, pagination completeness, read time,
and source in the run manifest.

That exact snapshot is the baseline when mirroring is enabled. Ideate and Harden make zero provider
reads and writes while drafting. After `project-spec.md` is written, when `artifacts.provider: "linear"`,
the shared contract performs immediate pre-save comparison, one bounded synchronization, and exact
content read-back. Mirror failures are recorded in the manifest and are nonblocking.

## Direct increment graph baseline

When Linear mirroring is enabled, after `project-spec.md` is written and optional mirror synchronization
completes, list every issue directly in the project with complete pagination. Select only current issues
that:
- belong directly to the project;
- expose one canonical issue reference that round-trips through the official MCP under the exact
  workspace/team/project scope; and
- have `parent = null`, where null is admitted only for an explicitly returned null or an omitted
  `parentId` after that field was explicitly requested and all issue pagination is complete.

When creating a new direct issue, prefer native client operation identity. Without it, preallocate
one separate UUID only after this complete preflight and bind it to the exact title suffix
`[woostack-mutation:<UUID>]`; the suffix is part of the title. Immediately before the one create
attempt, completely paginate all active and archived issue titles in the resolved workspace/team, flatten
every page, require null terminal cursors, and prove zero exact suffix matches. Partial, duplicate,
foreign, malformed, ambiguous, or nonzero matches block before creation. An unknown outcome is
recovered only by complete discovery of that same suffix: zero, duplicate, foreign, malformed, drifted,
partial, or otherwise unknown candidates fail closed without a replacement UUID or create replay.
Exactly one candidate may proceed only after an independent canonical issue-reference round trip
verifies the native issue identity, exact title including suffix, complete description, repository,
workspace/team, and nullable parent state. Direct project membership is the sole post-create
exception: bind the stable task key to the canonical reference, perform exactly one membership write,
and independently read back the intended membership before any native-relation graph write. Preserve the
suffix and stable-task mapping separately from the canonical issue reference.

Read all relevant native issue-to-issue dependency relations with complete pagination. Every relation
source and target uses the same canonical issue-reference representation and exact workspace/team/
project scope, then independently round-trips through its official-MCP endpoint. Normalize only
admitted `depends-on`/`blocks` relations into predecessor→successor tuples. Reject unknown parent
state, duplicates, unknown direction/kind, missing endpoints, endpoints outside the exact current
project graph, cycles, ambiguous ordering, or multiple current heads for one stable task identity.

This selectable-field, complete-pagination, endpoint-round-trip, and parent-state preflight runs
before any direct project-membership or native-relation graph write. A failed preflight blocks with
zero provider and repository mutation.

Historical parent plan issues and their children are noncanonical history. Preserve them, exclude
them from the baseline, and never detach, migrate, archive, delete, or reconcile them. Store the
complete exact project, current direct-issue identities/revisions/content, and dependencies in the
manifest. Delegated Plan and Harden then make zero provider reads and writes while drafting. After
`execution-plan.md` is written, when `artifacts.provider: "linear"`, the shared contract performs drift
comparison, one bounded synchronization, stable-key mapping, and exact graph read-back; mirror failures
are nonblocking.

## Drift and failure

Before either mirror save, when Linear mirroring is enabled, compare a fresh complete read with the
manifest baseline. Provider read or synchronization failures in mirror mode are recorded in the
manifest and are nonblocking for local authority, artifact retention, or handoff. Local manifest,
permission, and file safety failures remain strictly blocking.

When Linear mirroring is enabled, before implementation, after every worker handback, before redispatch,
immediately before commit, and before selecting another increment in Execute, repeat the provider mirror read:

- provider project drift is reported and recorded in mirror status;
- provider issue or dependency drift is reported and recorded in mirror status;
- unrelated metadata/comments do not affect local authority; and
- missing capability, incomplete pagination, or unknown provider outcomes in mirror mode are recorded
  as mirror status and do not block local authority or handoff.

When `artifacts.provider: "local"` (or omitted), provider baseline and drift reads are omitted entirely.
