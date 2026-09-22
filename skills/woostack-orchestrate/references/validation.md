# Delivery, validation, and reconciliation contract

Every worker result is gated by the helper and by an independent read-only validation. The worker's
ordinary Execute report is evidence to check, never delivery by itself. The helper owns state
transitions; this reference defines the facts the skill must collect before invoking it.

Use the shared [source-control contract](../../woostack-commit/references/graphite.md),
[canonical worktree contract](../../woostack-init/references/worktrees.md),
[least-code standard](../../woostack-bootstrap/references/patterns.md#7-least-code--comments),
and canonical [`#artifact-delivery-note`](../../woostack-commit/references/provider-attribution.md#artifact-delivery-note)
contract. Host mechanics remain in the allowlisted host references.

## Result schema

`apply-result --git-repo <canonical-repository>` accepts one result for one helper-reserved task.
All runtime markers below are facts that the skill must substitute from direct reads; they are not
values to invent:

```json
{
  "outcome": "ok",
  "worker": {
    "worker_id": "<runtime-substituted worker identity>",
    "pr_url": "<runtime-substituted canonical PR URL>",
    "branch": "<runtime-substituted worker branch>",
    "head_sha": "<runtime-substituted head SHA>",
    "base_branch": "<runtime-substituted PR base branch>",
    "commit_sha": "<runtime-substituted commit SHA>",
    "association": "<runtime-substituted exact child issue URL>"
  },
  "readback": {
    "repo": "<runtime-substituted canonical PR repository>",
    "head_repo": "<runtime-substituted canonical head repository>",
    "pr_url": "<runtime-substituted same canonical PR URL>",
    "branch": "<runtime-substituted same worker branch>",
    "head_sha": "<runtime-substituted same head SHA>",
    "base_branch": "<runtime-substituted same PR base branch>",
    "commit_sha": "<runtime-substituted same commit SHA>",
    "association": "<runtime-substituted exact child issue URL>",
    "closing_references": ["<runtime-substituted exact child issue URL>"],
    "open": true,
    "draft": true,
    "unique": true,
    "reviews": {"head_sha": "<same head SHA>", "complete": true, "items": []},
    "threads": {"head_sha": "<same head SHA>", "complete": true, "items": []},
    "diff_identity": "sha256:<runtime-substituted exact binary-diff hash>"
  },
  "checks": {
    "passed": true,
    "commands": ["<runtime-substituted exact required contract command>"],
    "head_sha": "<runtime-substituted same head SHA>",
    "diff_identity": "sha256:<runtime-substituted same binary-diff hash>",
    "smoke": "<runtime-substituted exact contract.smoke>"
  },
  "validation": {
    "verdict": "pass",
    "reviewer_id": "<runtime-substituted independent reviewer identity>",
    "diff_identity": "sha256:<runtime-substituted same binary-diff hash>",
    "contract_hash": "sha256:<runtime-substituted canonical JSON hash of exact contract>",
    "checked_head": "<runtime-substituted same head SHA>"
  },
  "note": {
    "id": "<runtime-substituted persisted child-note ID>",
    "issue_url": "<runtime-substituted exact child issue URL>",
    "pr_url": "<runtime-substituted same canonical PR URL>",
    "head_sha": "<runtime-substituted same head SHA>",
    "contract_hash": "sha256:<runtime-substituted same contract hash>",
    "diff_identity": "sha256:<runtime-substituted same binary-diff hash>"
  },
  "project_status": {
    "project_url": "<runtime-substituted selected Project URL>",
    "issue_url": "<runtime-substituted exact child issue URL>",
    "item_id": "<runtime-substituted admission-bound native Project item ID>",
    "status": "<runtime-substituted exactly the admitted lifecycle.inReview option>"
  }
}
```

`project_status` is required only in explicit Project mode, after the configured `inReview` write
and canonical readback; its `item_id` must equal the admission-bound native Project item ID and
its `status` must equal the admitted `lifecycle.inReview` option. `project_status` is forbidden
as a fabricated receipt in parent-issue mode. The result
example's markers mean “runtime-substituted fact required”, not a successful fixture. A repair
result may omit `note` when no validated delivery note exists. It must not replace missing fields
with another task's evidence.

The `worker` and `readback` identities must agree. `readback.closing_references` must contain
exactly one entry, the canonical child URL, and the PR body must carry exactly one
`Resolves <child URL>` reference. A specification-parent closing reference, duplicate reference,
missing reference, foreign repository, foreign head repository, wrong branch/head/base, duplicate
PR, or closed PR is an identity failure, not permission to retarget or create a replacement.

In explicit issue-list mode, `readback.association` and the sole closing reference remain the
individual selected issue URL; the normalized selector list and inferred graph never receive a PR,
delivery note, Project status, or issue-closing mutation. A worker packet carries the complete
caller-supplied edge provenance for its task, but Execute does not discover, reverse, or publish
edges. Native, declared, and inferred evidence must remain distinguishable through admission and
resume. A changed selected identity, contract, external blocker, edge endpoint, provenance, or
inference/coverage evidence changes the immutable fingerprint and returns `snapshot-drift`;
reservations and running workers are retained.

## Evidence calculations

All evidence is for the exact reservation currently in controller state:

- `worker.commit_sha == worker.head_sha == readback.commit_sha == readback.head_sha`;
- the actual local worker branch ref resolves to `head_sha` and the canonical PR head branch/SHA
  resolves to the same branch/SHA;
- the reserved parent SHA is an ancestor of `head_sha`, proved with
  `git merge-base --is-ancestor <reserved-parent-sha> <head-sha>` even when hashes are equal;
- `readback.repo` and `readback.head_repo` are the admitted canonical repository, and the PR URL
  is exactly one canonical PR in that repository;
- `readback.base_branch` and `worker.base_branch` equal the reserved `parent_branch`;
- `readback.association`, `worker.association`, and the sole closing reference equal the exact
  admitted child URL; and
- `diff_identity` is `sha256:` plus the SHA-256 of the exact bytes produced by
  `git diff --no-ext-diff --no-textconv --no-color --binary <reserved-parent-sha> <head-sha>`.

`reviews` and `threads` are complete independently paginated current-head readbacks, not the
worker's assessment. Preserve native record IDs; review records must have `commit_id` equal to
the checked head. Empty arrays are valid only after proved complete reads. Missing pages or stale
heads block delivery. These readbacks travel with the complete prerequisite checkpoint to Execute;
they do not require a draft PR to be merged or human-approved before stacking.

Checks are bound to the same `head_sha` and `diff_identity`. `checks.commands` is exactly the
admitted `contract.checks` list, with observed outcomes held by the skill; `checks.smoke` is exactly
the admitted `contract.smoke`. A `passed: true` flag without the exact command list is malformed,
not a pass. Independent validation computes `contract_hash` as `sha256:` plus canonical JSON
(sorted keys, compact separators) of the exact admitted contract, records the same diff identity,
and uses `checked_head == readback.head_sha`. `reviewer_id` must be distinct from `worker.worker_id`.
A changed head invalidates all check/validation/diff evidence and requires fresh reads.

## Gate order and statuses

The helper must apply these gates against the current reservation; the skill must not implement an
alternate acceptance path:

1. **Missing, malformed, or `unknown` result:** persist the task as `unknown` with its complete
   reservation/workspace, direct evidence, and first uncertain boundary intact. Unknown blocks that
   task and its descendants; unrelated ready tasks remain dispatchable. Do not guess fields,
   dispatch another worker, or clear identity from a report. This includes an unreadable/missing
   result, incomplete worker/readback/check/validation evidence, missing stopped-worker
   reconciliation evidence, and a result for a non-running task.
2. **Focused checks or independent specification review fail:** return `repair-ready`, preserving
   the exact original branch, absolute workspace, parent branch/SHA, reservation, and retained PR.
   The note may be absent. Repairs return through the same branch/PR and may not be reparents or
   replacements.
3. **Exact PR recovered after unknown:** return `evidence-pending`, retaining the same reservation and
   canonical PR/source evidence. Accept the independent full result through `apply-result`; do not
   dispatch a second Execute worker for repository work already represented by that PR.
4. **Note or optional Project receipt missing:** return `note-pending`, retaining the validated
   PR, checks, diff, and complete result. Retry only the failed note/Project read-back with the same
   result and identity; never replay repository delivery or dispatch a worker.
5. **Worker/readback or canonical identity conflict:** return a blocked `unknown` result for that
   task, preserving its reservation and stopping only its descendants. Wrong repository/head
   repository, PR URL, branch/head, base, child association, duplicate/closed PR, or a non-unique
   readback is an identity failure, never permission to retarget or create a replacement.
6. **All evidence pass:** require the note to have been written and read back under the canonical
   [`#artifact-delivery-note`](../../woostack-commit/references/provider-attribution.md#artifact-delivery-note)
   contract. In explicit Project mode also require the `project_status` delivery readback to carry
   exactly the admission-bound `item_id` and the admitted `lifecycle.inReview` option. Only then
   may the helper transition to `delivered` and release dependents.

`outcome: "needs-repair"` requests the second gate. `outcome: "ok"` must pass every gate; it
cannot waive a failed check, stale validation, absent note, Project mismatch, or identity issue.
Worker success output alone is never delivery. `unknown`, `evidence-pending`, `note-pending`, and
blocked outcomes retain all recoverable Git, PR, workspace, and evidence state for reconciliation.

## Independent read-only specification validation

After the worker stops and before `apply-result`, the Orchestrate controller performs a separate
read-only review. It loads the admitted child contract and exact specification/rules context,
reads the canonical PR/diff at the current head, and verifies:

- every acceptance criterion is addressed by the binary diff;
- no changed path escapes `contract.scope` or repository rules;
- non-goals, decisions, and risks are respected;
- required checks and the real smoke scenario cover the changed paths; and
- the calculated contract hash, head SHA, and diff identity match the result fields.

This validator does not edit source, branch, PR, issues, notes, or Project status. It is independent
of the worker and uses a distinct `reviewer_id`. Failed focused checks or failed spec review are
repair-ready; it does not delete a submitted PR or silently broaden scope.

## GitHub delivery note and optional Project status

After the independent readback and validation pass, write one concise child delivery note to the
exact child GitHub issue using the existing
[GitHub note mechanism](../../woostack-commit/references/provider-attribution.md#artifact-delivery-note).
It contains the canonical repository, branch/commit, PR/head/base, changed paths, observed
check/review outcome, contract hash, diff identity, and safe resume boundary. Read the exact note
back and include its `id`, child issue URL, PR URL, head, contract hash, and diff identity as `note`.
Preserve unrelated issue content and managed markers. Note write/readback is before dependent
release; an intent, mutation response, or worker claim is not a receipt.

Only an explicitly selected Project may receive a lifecycle write, and only to the admitted
configured `lifecycle.inReview` option. Read the Project item/status back and include exactly the
selected Project URL, child issue URL, admission-bound native `item_id`, and exactly the admitted
`lifecycle.inReview` status in `project_status`.
Parent-issue mode performs no Project call. Never set another lifecycle option, create a Project,
claim a status from a schedule intent, or use Project progress as evidence of PR delivery.

## Unknown reconciliation

An unknown task remains reserved and blocks only that task and its descendants. Reconcile only
after the worker is stopped and with both `--admitted` and `--git-repo`:

```text
python3 skills/woostack-orchestrate/scripts/orchestrate.py reconcile \
  --admitted admitted.json --state controller-state.json \
  --state-out controller-state.json --git-repo <canonical-repository> \
  --task <task-id> --evidence canonical-reconciliation-evidence.json
```

The evidence must be a direct canonical read, not a worker assertion, and include:

```json
{
  "worker_stopped": true,
  "branch": "<runtime-substituted exact reserved branch>",
  "head_sha": "<runtime-substituted exact observed branch head>",
  "base_branch": "<runtime-substituted exact reserved parent branch>",
  "repo": "<runtime-substituted canonical repository>",
  "head_repo": "<runtime-substituted canonical head repository>",
  "pr_url": "<runtime-substituted canonical PR URL or null only with pr_absent>",
  "open": true,
  "unique": true,
  "pr_absent": false
}
```

For a proven no-PR path, use `pr_absent: true`, `pr_url: null`, `open: false`, `unique: true`,
and the same canonical branch/head/base/repository/head-repository facts plus
`worker_stopped: true`; the helper rejects contradictory absence evidence (for example a
non-null `pr_url` or `open: true` alongside `pr_absent: true`) as `evidence-mismatch` and
preserves state. The helper returns same-branch `repair-ready` only for proven absence; an exact
canonical PR returns `evidence-pending` until the caller supplies independent full result evidence.
It never allocates a new identity or a second worker for repository work already represented by that PR.
All delivery gates still apply before dependent release. Any branch/head/base/repository/PR mismatch,
absent stopped proof, arbitrary report, contradictory absence evidence, duplicate/closed/foreign PR,
or missing admitted/git-repo input blocks reconciliation and leaves that task's halt in place.

After a successful reconciliation, assemble a new fully paginated fresh snapshot and invoke
`schedule` again with the existing state, `--fresh`, and `--git-repo`. The caller holds the same
externally enforced exclusive scope and canonical task claims across `schedule`, `apply-result`,
and `reconcile`; never run a second controller, recreate missing state, or redispatch while worker
ownership is unknown.
