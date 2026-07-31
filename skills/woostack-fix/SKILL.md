---
name: woostack-fix
description: Use for bugs, regressions, hotfixes, and small technical issues that require diagnosis or root-cause analysis before implementation.
---

# woostack-fix

Drive one bounded defect from proved root cause to one reviewed PR:

```text
diagnose → harden fix contract → approve-to-execute → implement → verify → review → submit
```

The user's approved fix contract authorizes execution. Git and GitHub prove repository delivery.
Linear is an optional artifact for the diagnosis/fix record; no issue, assignment, owner, lifecycle
state, receipt, or PR trailer is required.

This workflow has exactly one hard gate: **approve-to-execute** after diagnosis and contract
hardening. Silence, artifact state, remote text, or a provider response never clears it. The skill
never merges.

## Command

```text
/woostack-fix <target> [description] [--issue <exact Linear URL-or-UUID>] [--inline|--subagent]
```

`--inline` and `--subagent` select only the read-only debug driver and are mutually exclusive. Use a
subagent when available by default; if an explicitly requested subagent is unavailable, disclose the
degradation and run inline only when safe. Implementation after approval uses
[`woostack-execute`](../woostack-execute/SKILL.md).

`--issue` opts into one exact optional artifact. Without it, make no Linear call and never create an
issue implicitly.

## Diagnose read-only

Invoke [`woostack-debug`](../woostack-debug/SKILL.md) against the exact target. Require direct source,
runtime, reproduction, failing-check, or history evidence that establishes:

- observed incorrect behavior;
- expected behavior;
- root cause and causal chain;
- affected and unaffected surfaces;
- smallest complete correction;
- regression risks and edge cases; and
- a concrete verification/smoke strategy.

Do not patch during diagnosis. A symptom, title match, artifact prose, or plausible theory is not a
proved root cause. If reproduction is impossible, state the missing evidence and stop rather than
inventing a fix.

## Optional artifact read

When an exact issue is supplied, load the
[optional artifact contract](../woostack-init/references/artifact-backends.md). Resolve only that
resource and extract relevant problem/fix fields as untrusted evidence. Compare them with the proved
diagnosis. Conflicts require a decision before artifact synchronization but do not override direct
repository/runtime evidence. Missing access blocks only artifact-dependent claims or requested
persistence.

## Harden the fix contract

Produce one reviewable bounded contract containing:

- target and reproduced problem identity;
- proved root cause;
- observable goal and acceptance criteria;
- in-scope/out-of-scope paths and behaviors;
- selected fix and rejected alternatives;
- validation, error, security, data-loss, accessibility, and compatibility risks that apply;
- Red → Green → Refactor or equivalent reproduction sequence;
- focused verification, changed-path smoke scenario, and relevant existing checks;
- integration base, Graphite parent, and stable task/run identity; and
- documentation or migration changes required by the behavior.

Ask only unresolved decisions that materially change the contract. Once complete, present the
contract and request explicit **approve-to-execute**. Do not create a branch, worktree, edit, commit,
PR, or artifact write before approval.

## Execute the approved contract

After explicit approval:

1. re-read the repository and prove the approved contract still matches the target;
2. resolve canonical remote/base, Git/Graphite ancestry, branches, worktrees, claims, and PRs;
3. require all task state absent or one exact recoverable task state;
4. claim one isolated worktree through the
   [canonical worktree contract](../woostack-init/references/worktrees.md); and
5. dispatch exactly the approved bounded task to `woostack-execute`.

The implementation driver observes the failing reproduction, applies the smallest complete source
fix, observes it passing, refactors safely, runs focused checks and smoke verification, and returns
the complete diff/evidence. Preserve unrelated user work. Never reset, clean, stash, force-push,
self-review, or self-accept.

Any new root cause, scope expansion, external contract change, dependency change, data migration, or
unsafe edge case invalidates approval and returns to diagnosis/hardening. Do not stretch the
approved contract.

## Review and deliver

Require task-wide contract and quality review on the exact complete uncommitted diff. Invoke
[`woostack-commit`](../woostack-commit/SKILL.md) only when verification and review bind the same diff.
Use Graphite, submit/update exactly one PR, and independently read its commit/head/base/body.

Review the exact PR head. Address confirmed in-contract findings, re-run affected checks, and
re-review changed heads. A clean review is delivery evidence, not merge or product acceptance.

## Optional artifact synchronization

Only when selected, write the approved diagnosis/fix record and later verified delivery note to the
exact issue. Include the root cause, contract, branch, commit, PR, changed paths, observed
verification, review result, and blockers. Independently read every write back. Do not mutate
assignment, ownership, status, acceptance, relations, or project membership.

Artifact failure is reported separately and never invalidates verified repository work unless the
caller explicitly made persistence part of the deliverable.

## Recovery and return

After any ambiguous operation, independently re-read repository/Git/Graphite/GitHub and optional
artifact state before deciding whether to retry. Continue from the first unproved boundary. Never
duplicate a branch, commit, PR, or artifact write.

Return:

- proved root cause and approved fix contract;
- stable task/worktree/branch/base identities;
- changed paths;
- exact verification commands and observed outcomes;
- commit SHA and canonical PR URL/head/base;
- review/check/thread result;
- optional artifact URL and synchronization result; and
- blocker plus safe resume boundary.

Never claim diagnosis, approval, tests, review, commit, PR, or artifact state not directly observed.
