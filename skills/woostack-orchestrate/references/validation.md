# Delivery, validation, and reconciliation contract

Every worker result is gated by the helper and by an independent read-only validation. The worker's
ordinary Execute report is evidence to check, never delivery by itself. The helper owns state
transitions; this reference defines the facts the skill must collect before invoking it.

Use the shared [source-control contract](../../woostack-commit/references/graphite.md),
the outcome-level [runtime workspace guidance](scheduling.md#runtime-workspace-and-branch-evidence),
the [least-code standard](../../woostack-bootstrap/references/patterns.md#7-least-code--comments),
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
    "workspace": "<runtime-substituted actual selected isolated workspace>",
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

## Evidence calculations
All evidence is for the exact reservation currently in controller state. The worker's selected
workspace must equal the reserved physical path and its checkout must resolve to the admitted
canonical repository:

- `worker.commit_sha == worker.head_sha == readback.commit_sha == readback.head_sha`;
- the selected workspace branch resolves to `head_sha`, and the canonical PR head branch/SHA
  resolves to the same branch/SHA;
- the reserved parent SHA is an ancestor of `head_sha`, proved with
  `git merge-base --is-ancestor <reserved-parent-sha> <head-sha>` in the selected workspace even when
  hashes are equal;
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
   reservation/workspace intact, set the controller halt for fresh dispatch, and return `unknown`/
   `halted`. Do not guess fields, dispatch another worker, or clear identity from a report. This
   includes an unreadable/missing result, incomplete worker/readback/check/validation evidence,
   missing stopped-worker reconciliation evidence, and a result for a non-running task.
2. **Focused checks or independent specification review fail:** return `repair-ready`, preserving
   the exact original branch, absolute workspace, parent branch/SHA, reservation, and retained PR.
   The note may be absent. Repairs return through the same branch/PR and may not be reparents or
   replacements.
3. **Worker/readback or canonical identity conflict:** wrong repository/head repository, PR URL,
   branch/head, base, child association, duplicate/closed PR, or a non-unique readback returns a
   blocked `halted` result. Preserve the reservation and stop fresh dispatch. Never auto-authorize
   retargeting, replacement PRs, or a new branch. An ambiguous result is not a repair success.
4. **All evidence pass:** require the note to have been written and read back under the canonical
   [`#artifact-delivery-note`](../../woostack-commit/references/provider-attribution.md#artifact-delivery-note)
   contract. In explicit Project mode also require the `project_status` delivery readback to carry
   exactly the admission-bound `item_id` and the admitted `lifecycle.inReview` option. Only then
   may the helper transition to `delivered` and release dependents.

`outcome: "needs-repair"` requests the second gate. `outcome: "ok"` must pass every gate; it
cannot waive a failed check, stale validation, absent note, Project mismatch, or identity issue.
Worker success output alone is never delivery. `unknown` and `halted` retain all recoverable Git,
PR, workspace, and evidence state for reconciliation.

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

## Note persistence and optional Project status

After the independent readback and validation pass, write one concise child delivery note using the
existing provider note mechanism. It contains the canonical repository, branch/commit, PR/head/base,
changed paths, observed check/review outcome, contract hash, diff identity, and safe resume boundary.
Read the exact note back and include its `id`, child issue URL, PR URL, head, contract hash, and diff
identity as `note`. Preserve unrelated artifact content and managed markers. Note write/readback is
before dependent release; an intent, mutation response, or worker claim is not a receipt.

Only an explicitly selected Project may receive a lifecycle write, and only to the admitted
configured `lifecycle.inReview` option. Read the Project item/status back and include exactly the
selected Project URL, child issue URL, admission-bound native `item_id`, and exactly the admitted
`lifecycle.inReview` status in `project_status`.
Parent-issue mode performs no Project call. Never set another lifecycle option, create a Project,
claim a status from a schedule intent, or use Project progress as evidence of PR delivery.

## Unknown reconciliation

An unknown task remains reserved and globally halts fresh dispatch. Reconcile only after the worker
is stopped and with both `--admitted` and `--git-repo`:

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
preserves state. The helper returns same-branch `repair-ready`; it never allocates a new
identity. For an existing canonical PR, `pr_url`, `open`, and `unique` must describe that exact PR
and match the retained report/reservation. Successful reconciliation returns `repair-ready`,
retaining the exact reservation and any recovered PR. A fresh Execute worker can then repair
that same branch/PR and supply its own complete result; no missing worker identity is invented.
All delivery gates still apply before dependent release. Any branch/head/base/repository/PR mismatch, absent stopped
proof, arbitrary report, contradictory absence evidence, duplicate/closed/foreign PR, or missing
admitted/git-repo input blocks reconciliation and leaves the halt in place.

After a successful reconciliation, assemble a new fully paginated fresh snapshot and invoke
`schedule` again with the existing state, `--fresh`, and `--git-repo`. The caller holds the same
externally enforced exclusive scope ownership across `schedule`, `apply-result`, and `reconcile`;
never run a second controller, recreate missing state, or redispatch while worker ownership is
unknown.
