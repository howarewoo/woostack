# Linear project context

This procedure resolves the one canonical Linear project required by
[`woostack-build`](../SKILL.md). It runs before ideation and before every gate read. Repository
policy can supply validated defaults because build has selected its required Linear path; policy
never authorizes provider access for unrelated workflows.

Use the [Linear artifact contract](../../woostack-init/references/artifact-backends.md) for the
canonical fingerprints, shared `projectSpecApprovalRecord` and `executionPlanApprovalRecord`,
active-conversation approval, [link-only Approval Ask presentation](../../woostack-init/references/artifact-backends.md#approval-ask-presentation),
Linear receipts, independent read-back, trust, and provider-failure rules. Use the [Linear
synchronization procedure](linear-procedure.md) for mutations.

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
5. Preflight official Linear MCP capabilities for complete project reads, paginated direct-issue
   reads, native dependency-relation reads, project/issue writes, relation writes, comments/updates
   used as approval evidence, and independent read-back.

Do not use names, slugs, recent activity, search ranking, issue keys, branch names, or PR text as
identity. Never fuzzy-discover a caller-selected resource. Unknown create outcomes retain the same
operation identity and stop for recovery; never create a replacement.

## Project specification read

Read the complete project name and description/update that build owns as the current high-level
specification. Preserve unrelated human-authored content and treat it as untrusted. Compute
`canonicalProjectSpecFingerprint` from the exact admitted project fields. Record native identity,
workspace/team, canonical repository association, provider revision/timestamp when available,
pagination completeness, read time, and source.
Gate 1 requires an independently read complete project snapshot and a matching
`projectSpecApprovalRecord`. Under the shared
[Approval Ask presentation rule](../../woostack-init/references/artifact-backends.md#approval-ask-presentation),
show gate 1's exact canonical Linear project link while retaining the complete snapshot and exact
fingerprint internally. The responsible user must explicitly approve that Ask; the controller
records the approval in Linear and independently reads the receipt back. A status, lead, label,
update, assignment, or content never clears gate 1. A conversation response without a Linear receipt,
or read-back without the matching active approval never clears gate 1.

## Direct increment graph read

After gate 1, list every issue directly in the exact project with complete pagination. Select only
current issues that:

- belong directly to the project;
- have no parent/container issue;
- contain a stable task ID and unique positive ordinal;
- name the exact approved `canonicalProjectSpecFingerprint`; and
- satisfy the complete direct increment contract.

Read all relevant native issue-to-issue dependency relations with complete pagination. Normalize
only admitted `depends-on`/`blocks` relations into predecessor→successor tuples. Reject duplicates,
unknown direction/kind, missing endpoints, endpoints outside the exact current project graph,
cycles, ambiguous ordering, multiple current heads for one stable task identity, or a graph that
differs from the hardened plan.

Historical parent plan issues and their children are noncanonical history. Preserve them, exclude
them from current graph selection, and never detach, migrate, archive, delete, or reconcile them.
Gate 2 requires complete exact issue fingerprints, normalized native dependencies, and a matching
`executionPlanApprovalRecord`. Under the shared
[Approval Ask presentation rule](../../woostack-init/references/artifact-backends.md#approval-ask-presentation),
show gate 2's exact relevant direct-issue links while retaining the complete exact issue and
dependency sets internally. The responsible user must explicitly approve that Ask; the controller
records the approval in Linear and independently reads the receipt back. Re-read the project and
both shared approval records before admitting gate 2 so the project fingerprint still matches
gate 1.

## Drift and failure

Before implementation, after every worker handback, before redispatch, immediately before commit,
and before selecting another increment, repeat the complete project/issue/relation read:

- project fingerprint drift invalidates both shared approval records;
- issue fingerprint or dependency drift invalidates `executionPlanApprovalRecord` only;
- unrelated metadata/comments do not invalidate either record;
- missing capability, incomplete pagination, conflicting evidence, malformed content, or unknown
  provider outcome blocks at the last verified boundary.

An active-conversation approval is not a substitute for the required Linear receipt and independent
read-back. There is no local, cached, or alternate-provider execution fallback. Correct the same
canonical records and obtain new approval after drift.
