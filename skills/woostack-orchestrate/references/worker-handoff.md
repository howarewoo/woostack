# Worker packets and host handoff

This reference defines the exact bridge between helper output and a real
[`woostack-execute`](../../woostack-execute/SKILL.md) worker. The helper emits data; it never
contacts a host. The skill reserves and creates the Git worktree, then invokes only the selected
allowlisted host's documented subagent primitive. Scheduling and state rules are in
[scheduling](scheduling.md); delivery gates are in [validation](validation.md).

Use the shared [source-control contract](../../woostack-commit/references/graphite.md),
[canonical worktree contract](../../woostack-init/references/worktrees.md),
[least-code standard](../../woostack-bootstrap/references/patterns.md#7-least-code--comments),
and [model tiers](../../using-woostack/references/model-tiers.md). Host mechanics do not belong in
this file.

## Dispatch entry emitted by the helper

For every ready task, `schedule` emits exactly one reservation/packet entry. Values below are
runtime-substituted facts from the admission and local Git reservation; they are not evidence to
invent:

```json
{
  "task_id": "<runtime-substituted stable task ID>",
  "ordinal": "<runtime-substituted positive ordinal>",
  "child_url": "<runtime-substituted canonical child issue URL>",
  "parent_branch": "<runtime-substituted selected local parent branch>",
  "parent_sha": "<runtime-substituted selected parent SHA>",
  "branch": "woostack/<runtime-substituted task ID>",
  "workspace": "<runtime-substituted absolute primary-common-root worktree path>",
  "repair": false,
  "retained_pr": null,
  "packet": {
    "task_id": "<runtime-substituted stable task ID>",
    "ordinal": "<runtime-substituted positive ordinal>",
    "child_issue_url": "<runtime-substituted canonical child issue URL>",
    "scope_url": "<runtime-substituted exact --issue/--project selector>",
    "parent_issue_url": "<runtime-substituted issue scope URL, or Project member actual_parent>",
    "specification": "<runtime-substituted complete approved specification>",
    "repository_rules": "<runtime-substituted complete repository rules>",
    "bounded_input": {
      "goal": "<runtime-substituted contract.goal>",
      "scope": ["<runtime-substituted contract.scope path>"],
      "non_goals": ["<runtime-substituted contract.non_goals entry>"],
      "acceptance": ["<runtime-substituted contract.acceptance criterion>"],
      "checks": ["<runtime-substituted exact contract.checks command>"],
      "smoke": "<runtime-substituted contract.smoke>",
      "decisions": "<runtime-substituted contract.decisions>",
      "risks": "<runtime-substituted contract.risks>"
    },
    "parent_readiness": {
      "logical_prerequisites": [],
      "external_prerequisites": [],
      "prerequisites": [],
      "parent": {
        "branch": "<selected parent branch>",
        "sha": "<retained approved start SHA>",
        "current_sha": "<independently read current parent tip>",
        "selection": "integration",
        "pr_evidence": {
          "repo": "<canonical repository>",
          "branch": "<same parent branch>",
          "head_sha": "<same current parent tip>",
          "complete": true,
          "prs": []
        }
      },
      "decision": null
    },
    "acceptance": ["<runtime-substituted exact contract.acceptance criterion>"],
    "checks": ["<runtime-substituted exact contract.checks command>"],
    "contract_hash": "sha256:<runtime-substituted canonical JSON contract hash>",
    "execute_skill": "woostack-execute",
    "repair": false,
    "retained_pr": null,
    "branch": "woostack/<runtime-substituted task ID>",
    "workspace": "<runtime-substituted absolute primary-common-root worktree path>",
    "parent_branch": "<runtime-substituted selected parent branch>",
    "parent_sha": "<runtime-substituted selected parent SHA>"
  }
}
```

`bounded_input` is the complete contract object, not a prose string. The actual helper output
contains the runtime arrays/objects; the markers above identify facts that must be substituted
from helper output and direct reads. `parent_issue_url` is the selected specification issue in
issue mode; in Project mode it is the member's independently read `actual_parent` (including
`null` for a parentless member). `scope_url` remains the exact selected Project URL in Project
mode. `specification` and `repository_rules` are complete strings, not summaries.

The example's `parent_readiness` is a root with proved parent-PR absence. For a dependent,
`logical_prerequisites` is the complete admitted task-ID set and `prerequisites` has exactly one
record per ID: `task_id`, exact `issue_url`, `checkpoint` (the complete
[result object](validation.md#result-schema), including checks, PR head/base/state/reviews/threads,
independent validation, and persisted note), and `containment: {ancestor, descendant, verified}`.
Those SHAs are the prerequisite head and retained parent start; the helper has actually verified
their Git ancestry. `parent.selection` is `predecessor`, `integration`, or `explicit`. An explicit
choice carries its preserved `{task_id, branch, sha}` decision; other selections use `null`.
`parent.pr_evidence` uses [fresh parent PR discovery](scheduling.md#snapshot-schema).

The complete Execute input comprises `bounded_input` **and** this readiness object plus the
specification/repository context. The worker verifies that exact prerequisite set, full checkpoints,
parent choice, current PR facts, and ancestry before Git mutation. It must block missing evidence,
not discover the graph or infer readiness from a branch name. Repairs retain their original start,
even if a separately verified parent tip has advanced compatibly.

A repair entry keeps the same `branch`, absolute `workspace`, `parent_branch`, `parent_sha`, and
retained PR as its original reservation and sets `repair: true`. It never receives a new parent or
replacement PR. The child URL is the only issue association and closing reference.

## Reserve then create the actual worktree

The helper reservation is not a Git worktree. After `schedule` returns, the caller must, before
host dispatch:

1. Resolve the primary Git common root using the shared worktree contract. Canonicalize the emitted
   workspace and every existing `git worktree list --porcelain` path with physical path resolution.
2. Compare the emitted workspace against every running/pending reservation, including aliases and
   ancestor/descendant paths. Compare the emitted branch against every local/remote branch and
   checkout. An existing unclaimed branch, path, checkout, or competing writer blocks; do not claim,
   delete, reset, or create around it.
3. For fresh work only, create the exact emitted branch at the exact emitted parent SHA, using the
   canonical worktree procedure (native Git is the default):

   ```sh
   git -C <canonical-repository> worktree add -b <emitted-branch> \
     <emitted-absolute-workspace> <emitted-parent-sha>
   ```

   A relative override from the snapshot is resolved beneath the primary common root; an absolute
   path or traversal is invalid. Repairs reopen/adopt only the already verified reservation and
   branch/PR; they never create a replacement checkout or reparent.
4. Read back the physical workspace, common root, branch, `HEAD`, and parent branch ref. The local
   parent branch ref must equal the emitted `parent_sha`; then run
   `git -C <canonical-repository> merge-base --is-ancestor <parent-sha> <head-sha>` even if the
   two hashes are equal. A failed or partial create/read-back is an unknown mutation boundary:
   retain the helper reservation and stop.
5. Pass only that exact workspace to the selected host primitive. The worker writes source only
   there. One writer owns one physical workspace; a timeout or missing receipt does not authorize
   overlapping redispatch until the original worker is proved stopped.

The worker must not create its own alternate workspace, switch to another branch, infer a parent
from ordinal order, read/write a sibling workspace, alter hierarchy/dependencies, or own Project
progress. It may use Execute/Commit for its one task and one child-associated draft PR.

## Host handoff

Resolve the host slug against the exact allowlist before using a spawn primitive and load only that
host's reference. The host adapter owns primitive names, worker selectors, per-call directory/model
knobs, fallback, and concurrency mechanics. This skill owns only the invariant payload and says
when missing delivery capability is a blocker:

- pass one schedule entry to one delivery-capable subagent;
- pass the exact absolute workspace, branch, parent branch/SHA, complete packet, child URL,
  specification, repository rules, bounded input object, acceptance, checks, and contract hash;
- clamp the helper's cap to the real host capability, preserving the host's documented tier
  routing; and
- require a worker receipt. Missing capability or receipt is not success and never falls back to
  inline source edits.

The worker prompt in [`prompts/execute-child.md`](../prompts/execute-child.md) is a transport
payload template, not a second workflow. The host must deliver it with the runtime values from the
helper entry; do not hand-author a weaker prose packet.

## Worker result envelope

The worker returns ordinary Execute evidence. The controller adds independent canonical reads,
focused verification, and read-only specification validation using the single
[result schema and gates](validation.md#result-schema), then persists/read-backs the child note
and any explicitly selected Project status before `apply-result`. Do not invent missing evidence
or let the worker approve its own result. Failed checks/specification validation preserve the
same reservation and PR for repair; missing note/Project receipts are retried without replaying
repository delivery; unknown outcomes retain ownership and block only that task and descendants.

The child PR carries exactly one `Resolves <child URL>` reference. It never closes or references
the specification parent. New PRs remain drafts and no workflow step marks ready, merges, queues,
force-pushes, or silently retargets a PR.

## Existing delivery and resume

A fresh snapshot that includes a delivered task must include `existing_delivery.reservation` and
`existing_delivery.result` with this same complete result shape. The skill re-reads the canonical
branch/ref, PR/head/base/repository, focused checks, binary diff, independent validation, note, and
selected Project status immediately before assembly. The helper restores `delivered` only when the
reservation and every result identity/evidence field match; stale or partial evidence blocks. Never
redispatch a task merely because its prior worker output is absent when canonical delivery already
exists.
