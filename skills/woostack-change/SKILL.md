---
name: woostack-change
description: Use for a bounded non-bug enhancement or refactor that can ship as one reviewable PR without the full build or fix loop. Invoke via /woostack-change <goal>.
---

# woostack-change

Ship one bounded non-bug enhancement or refactor as one reviewed PR. The user's explicit goal and
this workflow's bounded contract authorize work. Git and GitHub prove delivery. Change is always
artifact-free and never reads or writes Linear.

The workflow has no hard approval gate. Clarification, repository preflight, isolated execution,
verification, review, and delivery evidence are required preconditions, not approval requests.

## Command

```text
/woostack-change <goal>
```

## Classify

Inspect repository context and affected surface before any write. Route:

- bugs, regressions, incidents, production faults, and root-cause work to
  [`woostack-fix`](../woostack-fix/SKILL.md);
- genuinely greenfield creation to [`woostack-bootstrap`](../woostack-bootstrap/SKILL.md);
- work requiring multiple coherent PRs or dependency increments to
  [`woostack-build`](../woostack-build/SKILL.md); and
- only one bounded non-bug enhancement/refactor that safely fits one reviewable PR here.

If target or outcome is ambiguous, ask one focused clarification. Otherwise state the interpreted
goal and proceed. Later scope expansion stops and routes back to the responsible workflow; never
silently widen the contract.

## Bind the contract

Record in the active run:

- observable goal and target;
- in-scope and out-of-scope surfaces;
- acceptance criteria;
- repository-relative allowed paths;
- concrete verification and changed-path smoke scenario;
- integration base and intended Graphite parent; and
- stable task/run identity.

Read `.woostack/config.json` only as non-secret repository policy. The contract remains in the
active workflow; do not create a local or remote plan/change record. Ignore Linear configuration
for this workflow.

## Repository preflight

Before creating or resuming a branch/worktree:

1. resolve the physical repository root, canonical remote, configured integration base, and exact
   base commit;
2. inventory local/remote branches, worktrees, registry claims, Graphite ancestry, commits, and
   canonical GitHub PRs;
3. require either all task state absent or one exact recoverable task/run/branch/worktree/PR state;
4. reject protected-primary edits, detached HEAD, collisions, duplicate branches/PRs, unexplained
   dirty state, or conflicting ancestry; and
5. create/claim one isolated worktree under the
   [canonical worktree contract](../woostack-init/references/worktrees.md).

Preserve unexpected user work. Never reset, clean, stash, delete, overwrite, or create around a
collision.

## Execute

Delegate the approved bounded task to [`woostack-execute`](../woostack-execute/SKILL.md), using one
isolated task identity and one implementation PR. The selected driver:

1. runs the smallest relevant baseline/reproduction;
2. implements the smallest complete change;
3. simplifies without changing behavior;
4. runs focused verification, the changed-path smoke scenario, and nearest relevant checks;
5. reviews the complete uncommitted diff against the contract and quality rules; and
6. hands evidence to the controller.

No self-review or self-acceptance. The decision-maker/controller owns task decisions, independent
review, commit/PR boundaries, and handback; the coding profile owns implementation and focused
verification only.

## Deliver

Invoke [`woostack-commit`](../woostack-commit/SKILL.md) only after verification and required review
bind to the same complete diff identity. Use Graphite, submit/update exactly one PR, and independently
read its repository, head/base, body, and open state back. Never force-push or merge.

After submission, run the owning review boundary on the exact PR head. Address confirmed in-contract
findings through [`woostack-address-comments`](../woostack-address-comments/SKILL.md), then re-review
changed heads. A clean review is delivery evidence, not product acceptance or merge proof.


## Recovery and return

On timeout or unknown repository outcome, re-read task/worktree, Git, Graphite, and GitHub facts
before retrying. Resume from the first unproved boundary; never duplicate a branch, commit, PR, or
reply.

Return:

- bounded goal/contract and stable task ID;
- worktree, branch, base/parent, and changed paths;
- verification commands and observed outcomes;
- commit SHA and canonical PR URL/head/base;
- review/thread result;
- blockers plus exact safe resume boundary.

Never claim a test, review, commit, or PR state not directly observed.
