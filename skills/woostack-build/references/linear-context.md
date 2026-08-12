# Linear project context

This procedure resolves the one canonical Linear project required by
[`woostack-build`](../SKILL.md) and admits each exact pre-draft baseline. Repository policy can
supply validated defaults because Build selected its required Linear path; policy never authorizes
provider access for unrelated workflows.

The [Linear artifact contract](../../woostack-init/references/artifact-backends.md) is the single
authority for the run manifest, deterministic owner-only gate files, path/byte-length/SHA-256/
fingerprint-version approval identity, post-approval ordering, stable-key/canonical-issue-reference
mapping, nullable-parent validation, drift and process-loss recovery, cleanup, fingerprints,
receipts, independent read-back, and unchanged Execute reads. The shared [repository advancement
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

That exact snapshot is gate 1's baseline. Ideate and Harden make zero provider reads and writes
until the responsible user approves the owner-only `project-spec.md` path, byte length, SHA-256,
fingerprint version, run/process identity, and project identity. The shared contract then owns the
no-follow regeneration and file checks, immediate pre-save comparison, bounded synchronization,
exact content read-back, `projectSpecApprovalRecord`, and final receipt/read-back. Status, lead,
label, update, assignment, content alone, or an unreceipted conversation response never clears
gate 1.

## Direct increment graph baseline

After the gate 1 receipt and referenced project read back exactly, list every issue directly in the
project with complete pagination. Select only current issues that:

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
reads and writes until the responsible user approves the owner-only `execution-plan.md` path/hash/
length identity and complete concise stable-task/dependency mapping. The shared contract owns the
drift comparison, one bounded synchronization, stable-key mapping, exact graph read-back,
`executionPlanApprovalRecord`, and final receipt/read-back.

## Drift and failure

Before either gated save, compare a fresh complete read with the manifest baseline exactly and
revalidate the approved gate file with no-follow, owner, mode, regular-file, regeneration, path,
length, hash, and process checks. Drift or file identity mismatch invalidates the approval and
requires fresh baseline admission, regeneration, and a fresh concise Ask; an unreceipted response
cannot replay. Provider/process/manifest failure follows the shared recovery and cleanup contract
with no local, cached, or alternate-provider execution fallback.

Before implementation, after every worker handback, before redispatch, immediately before commit,
and before selecting another increment, repeat the complete project/issue/relation/receipt read:

- project fingerprint drift invalidates both shared approval records;
- issue fingerprint or dependency drift invalidates `executionPlanApprovalRecord` only;
- unrelated metadata/comments do not invalidate either record; and
- missing capability, incomplete pagination, conflicting evidence, malformed content, or unknown
  provider outcome blocks at the last verified boundary.

This Execute-era cadence is unchanged by deferred gated synchronization.
