# Linear project context

This procedure resolves the one canonical Linear project required by
[`woostack-build`](../SKILL.md) and admits each exact pre-draft baseline. Repository policy can
supply validated defaults because Build selected its required Linear path; policy never authorizes
provider access for unrelated workflows.

The [Linear artifact contract](../../woostack-init/references/artifact-backends.md) is the single
authority for the run manifest, displayed-content approval identity, post-approval ordering,
stable-key/canonical-issue-reference mapping, nullable-parent validation, drift and process-loss
recovery, cleanup, fingerprints, receipts, independent read-back, and unchanged Execute reads. Use
the [Linear synchronization procedure](linear-procedure.md) only for the bounded post-approval save
or standalone Plan.

## Resolution

1. Resolve the canonical repository URL from trusted Git/GitHub evidence.
2. Resolve the caller-selected workspace/team. Use validated `.woostack/config.json` values only as
   post-selection defaults.
3. If `--project` supplied an exact URL/stable UUID, read only that project and verify its identity,
   workspace/team, and canonical repository association.
4. Otherwise allocate one stable client mutation UUID, prove that no project exists for that
   operation identity, and create exactly one project in the resolved workspace/team. Its name
   starts with `[Build] ` and otherwise derives from the accepted goal. Independently read the
   project back, verify the exact name, and retain its native identity.
5. Preflight official Linear MCP capabilities for complete project reads, selectable direct-issue
   identity/project/team/parent fields, complete paginated issue and relation reads, canonical
   issue-reference endpoint round trips, project/issue writes, relation writes, comments/updates used
   as approval evidence, and independent read-back.

Do not use names, slugs, recent activity, search ranking, issue titles, branch names, or PR text as
identity. Canonical issue references are the sole issue endpoint representation; project and team
identity remains provider-native. Never fuzzy-discover a caller-selected resource. Unknown create
outcomes retain the same operation identity and stop for recovery; never create a replacement.

## Project specification baseline

Immediately before gate 1 drafting, independently read the complete project name and
description/update that Build owns as the high-level specification. Preserve unrelated
human-authored content and treat it as untrusted. Compute `canonicalProjectSpecFingerprint` from
the exact admitted fields. Record native identity, workspace/team, canonical repository
association, provider revision/timestamp when available, pagination completeness, read time, and
source in the run manifest.

That exact snapshot is gate 1's baseline. Ideate and Harden make zero provider reads and writes
until the responsible user approves the complete exact displayed specification. The shared contract
then owns the immediate pre-save comparison, bounded synchronization, exact content read-back,
`projectSpecApprovalRecord`, and final receipt/read-back. Status, lead, label, update, assignment,
content alone, or an unreceipted conversation response never clears gate 1.

## Direct increment graph baseline

After the gate 1 receipt and referenced project read back exactly, list every issue directly in the
project with complete pagination. Select only current issues that:

- belong directly to the project;
- expose one canonical issue reference that round-trips through the official MCP under the exact
  workspace/team/project scope;
- have `parent = null`, where null is admitted only for an explicitly returned null or an omitted
  `parentId` after that field was explicitly requested and all issue pagination is complete; and
- do not conflict with the approved `canonicalProjectSpecFingerprint`.

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
fingerprints, and gate 1 receipt in the manifest. Delegated Plan and Harden then make zero provider reads and writes
until the responsible user approves the complete exact displayed plan. The shared
contract owns the drift comparison, one bounded synchronization, stable-key mapping, exact graph
read-back, `executionPlanApprovalRecord`, and final receipt/read-back.

## Drift and failure

Before either gated save, compare a fresh complete read with the manifest baseline exactly. Drift
invalidates the displayed approval and requires fresh baseline admission and a fresh complete Ask;
an unreceipted response cannot replay. Provider/process/manifest failure follows the shared recovery
and cleanup contract with no local, cached, or alternate-provider execution fallback.

Before implementation, after every worker handback, before redispatch, immediately before commit,
and before selecting another increment, repeat the complete project/issue/relation/receipt read:

- project fingerprint drift invalidates both shared approval records;
- issue fingerprint or dependency drift invalidates `executionPlanApprovalRecord` only;
- unrelated metadata/comments do not invalidate either record; and
- missing capability, incomplete pagination, conflicting evidence, malformed content, or unknown
  provider outcome blocks at the last verified boundary.

This Execute-era cadence is unchanged by deferred gated synchronization.
