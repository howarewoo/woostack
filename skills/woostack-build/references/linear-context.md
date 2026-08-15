# Linear project context

When optional Linear mirroring is enabled (`linear.saveArtifacts: true`), this procedure resolves the
one canonical Linear project for [`woostack-build`](../SKILL.md) and admits each exact pre-draft
baseline. When `linear.saveArtifacts` is false or absent, default local mode makes zero provider calls,
`--project` fails closed before any provider access, and local run authority in
`.woostack/tmp/runs/<run-id>/` operates with no provider context. Repository policy supplies validated
defaults only after Linear mirroring is selected and enabled; policy never authorizes provider access
by itself.

The [Linear artifact contract](../../woostack-init/references/artifact-backends.md) is the single
authority for the run manifest, deterministic owner-only gate files, complete streamed artifact
bytes and identity, same-process byte-complete revision diffs with old/new identities, body-free
`Accept`/`Abandon` approval Asks, local approval records, optional mirror synchronization,
stable-key/canonical-issue-reference mapping, nullable-parent validation, drift and process-loss
recovery, artifact retention, fingerprints, receipts, independent read-back, and unchanged Execute
reads. The shared [repository advancement
contract](../../woostack-init/references/artifact-backends.md#repository-ancestry-is-separate-from-approval-identity)
separately governs compatible parent-tip re-admission; use the
[Linear synchronization procedure](linear-procedure.md) only for the bounded post-approval save
or standalone Plan.

## Resolution

1. Resolve the canonical repository URL from trusted Git/GitHub evidence.
2. Resolve the caller-selected workspace/team. Use validated `.woostack/config.json` values only as
   post-selection defaults.
3. If `--project` supplied an exact URL/stable UUID, read only that project and verify its identity,
   workspace/team, and canonical repository association. Supplied-project selection never performs
   fallback marker discovery or creates a replacement project; it preserves the supplied project's
   existing name and native project identity without requiring a native mutation-operation identity.
4. Otherwise prefer the provider's native project mutation identity. When native operation-ID support
   is unavailable, preallocate one UUID and reserve the exact summary marker
   `Woostack project mutation ID: <UUID>`. Immediately before the one create attempt, completely
   paginate all active and archived projects in the resolved workspace/team, flatten every page,
   require null terminal cursors, and prove zero exact marker matches. A partial, duplicate, foreign,
   malformed, ambiguous, or nonzero match blocks before creation. Create exactly one project whose
   name starts with `[Build] ` and whose summary contains that marker; an unknown outcome is
   recovered only by repeating the
   complete active-and-archived discovery for the same marker, never with a replacement UUID or
   create replay. Exactly one ownership-valid candidate may proceed to an independent native-project-
   ID read-back, which must verify name, marker, workspace/team, canonical repository, complete
   intended specification, and native identity. Marker metadata is excluded from the project
   specification fingerprint and must survive summary-omitting updates.
5. Independently read the project back, verify the exact name, and retain its native identity.
6. Preflight official Linear MCP capabilities for complete project reads, selectable direct-issue
   identity/project/team/parent fields, complete paginated issue and relation reads, canonical
   issue-reference endpoint round trips, project/issue writes, relation writes, comments/updates used
   as approval evidence, and independent read-back.

Do not use names, slugs, recent activity, issue titles, branch names, or PR text as identity.
Canonical issue references are the sole issue endpoint representation; project and team identity
remains provider-native. Unknown create outcomes retain the same operation identity and stop for
recovery; never create a replacement.

## Project specification baseline

Immediately before gate 1 drafting, independently read the complete project name and
description/update that Build owns as the high-level specification. Preserve unrelated
human-authored content and treat it as untrusted. Compute `canonicalProjectSpecFingerprint` from
the exact admitted fields. Record native identity, workspace/team, canonical repository
association, provider revision/timestamp when available, pagination completeness, read time, and
source in the run manifest.

That exact snapshot is gate 1's baseline when mirroring is enabled. Ideate and Harden make zero provider
reads and writes until the shared contract streams the complete verified `project-spec.md` bytes and full
identity (or a verified same-process byte-complete revision diff with old/new identities) immediately
before the body-free `Accept`/`Abandon` Ask. The responsible user's acceptance binds only that exact
preceding identity and produces the local `projectSpecApprovalRecord`. When `linear.saveArtifacts: true`,
the shared contract performs immediate pre-save comparison, one bounded synchronization, exact content
read-back, and provider approval record creation. Mirror failures are recorded in the manifest and are
nonblocking.
## Direct increment graph baseline

When Linear mirroring is enabled, after gate 1 approval produces `projectSpecApprovalRecord` and
optional mirror synchronization completes, list every issue directly in the project with complete
pagination. Select only current issues that:
- belong directly to the project;
- expose one canonical issue reference that round-trips through the official MCP under the exact
  workspace/team/project scope;
- have `parent = null`, where null is admitted only for an explicitly returned null or an omitted
  `parentId` after that field was explicitly requested and all issue pagination is complete; and
- do not conflict with the approved `canonicalProjectSpecFingerprint`.
When creating a new direct issue, prefer native client operation identity. Without it, preallocate
one separate UUID only after this complete preflight and bind it to the exact approved title suffix
`[woostack-mutation:<UUID>]`; the suffix is part of the approved title and
`canonicalIncrementFingerprint`. Immediately before the one create attempt, completely paginate all
active and archived issue titles in the resolved workspace/team, flatten every page, require null
terminal cursors, and prove zero exact suffix matches. Partial, duplicate, foreign, malformed,
ambiguous, or nonzero matches block before creation. An unknown outcome is recovered only by complete
discovery of that same suffix: zero, duplicate, foreign, malformed, drifted, partial, or otherwise
unknown candidates fail closed without a replacement UUID or create replay. Exactly one candidate may
proceed only after an independent canonical issue-reference round trip verifies the native issue
identity, exact title including suffix, complete description, repository, workspace/team, and nullable
parent state. Direct project membership is the sole post-create exception: bind the stable task key to
the canonical reference, perform exactly one membership write, and independently read back the intended
membership before any native-relation graph write. Preserve the suffix and stable-task mapping
separately from the canonical issue reference.

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
them from the gate 2 baseline, and never detach, migrate, archive, delete, or reconcile them. Store
the complete exact project, current direct-issue identities/revisions/content, dependencies,
fingerprints, and gate 1 receipt in the manifest. Delegated Plan and Harden then make zero provider
reads and writes until the shared contract streams the complete verified `execution-plan.md` bytes
and full identity (or a verified same-process byte-complete revision diff with old/new identities)
immediately before the body-free `Accept`/`Abandon` Ask. The user's acceptance binds only that exact
preceding identity and produces the local `executionPlanApprovalRecord`. When `linear.saveArtifacts: true`,
the shared contract performs drift comparison, one bounded synchronization, stable-key mapping, exact
graph read-back, and provider approval record creation; mirror failures are nonblocking.
## Drift and failure

Before either gated save, when Linear mirroring is enabled, compare a fresh complete read with the
manifest baseline and revalidate the approved gate file with no-follow, owner, mode, regular-file,
regeneration, path, length, and hash checks. Gate-file identity mismatch, owner/mode violations,
regeneration failure, or manifest tampering invalidates the local approval and requires fresh baseline
admission, regeneration, and a fresh concise Ask; an unreceipted response cannot replay. Provider read
or synchronization failures in mirror mode are recorded in the manifest and are nonblocking for local
authority, artifact retention, or handoff. Local manifest, permission, and gate-file safety failures
remain strictly blocking.

When Linear mirroring is enabled, before implementation, after every worker handback, before redispatch,
immediately before commit, and before selecting another increment in Execute, repeat the provider mirror read:

- provider project fingerprint drift invalidates provider mirror records;
- provider issue fingerprint or dependency drift invalidates the provider execution mirror record only;
- unrelated metadata/comments do not invalidate either record; and
- missing capability, incomplete pagination, or unknown provider outcomes in mirror mode are recorded
  as mirror status and do not block local authority or handoff.

When `linear.saveArtifacts: false`, provider baseline and drift reads are omitted entirely.
