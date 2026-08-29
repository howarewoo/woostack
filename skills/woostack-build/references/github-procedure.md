# GitHub project synchronization procedure

This procedure applies mutations for Build/Fix optional mirror synchronization (when `artifacts.provider: "github"`)
or standalone Plan. The shared [artifact contract](../../woostack-init/references/artifact-backends.md) and
[GitHub profile](../../woostack-init/references/artifact-providers/github.md) own shared and GitHub invariants;
[github-context.md](github-context.md) owns baseline admission.

## Build project lifecycle

Build allocates or resumes the canonical run under `.woostack/tmp/runs/<run-id>/` and admits the baseline.
Ideate and Harden update only the manifest with zero provider calls while drafting.
After `project-spec.md` is written, perform immediate pre-save drift read and one bounded synchronization:
write the specification inside `ProjectV2.readme` between `<!-- woostack-spec-start -->` and `<!-- woostack-spec-end -->`
and update `shortDescription` with the concise goal summary, preserving unrelated README prefix/suffix and metadata.
Read content back and set `mirror.status = "synced"`; mirror failures record `mirror.status = "failed"` and are nonblocking.

## Increment graph synchronization

Build/Fix-delegated `woostack-plan` and Harden populate only the manifest with zero provider calls.
After `execution-plan.md` is written, run the shared graph-write preflight. Failure before issue creation has zero provider and repository mutation; a failed post-create read-back permits no membership or relation write. Perform bounded synchronization in strict order:
1. create direct parentless canonical repository issues (`parent = null`) with full increment contract and `<!-- woostack-issue-mutation:<UUID> -->`, and read each issue back;
2. persist the bind-once canonical issue URL mapping atomically in the manifest;
3. add direct Project item membership in the exact Project and read back `planned` Status; and
4. create native issue-to-issue dependency relations matching the graph ($N-1$ strict dependencies: `ordinal k-1` blocks `ordinal k`) and read back complete relations graph.
Verify exact normalized predecessor→successor tuples; update `mirror.status = "synced"`.

## Standalone plan

Standalone `woostack-plan` with `artifacts.provider: "github"` requires an exact canonical Project URL (`--project`),
verifies canonical repository association (rejecting foreign repositories), updates the managed README section and
`shortDescription`, reads both back, creates parentless direct repository issues (`parent = null`), persists mappings, adds
direct Project membership, and creates $N-1$ native blocked-by dependencies (`ordinal k-1` blocks `ordinal k`). It independently
reads the complete graph back and owns no execution authorization.

## Delivery notes and abandonment

Delivery notes record evidence without replacing source facts. Mirror failures are nonblocking. Explicit abandonment
records `status: "abandoned"` in the manifest and retains run artifacts without closing a mirrored GitHub Project or issue.
