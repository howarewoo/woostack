# Worker packets and host handoff

This reference defines the exact bridge between helper output and a real
[`woostack-execute`](../../woostack-execute/SKILL.md) worker. The helper emits data; it never
contacts a host. The skill supplies the selected isolated workspace/branch through the host's
supported mechanism, then invokes only the selected allowlisted host's documented subagent
primitive. Scheduling and state rules are in [scheduling](scheduling.md); delivery gates are in
[validation](validation.md).

Use the shared [source-control contract](../../woostack-commit/references/graphite.md),
the outcome-level [worktree guidance](scheduling.md#runtime-workspace-and-branch-evidence),
the [least-code standard](../../woostack-bootstrap/references/patterns.md#7-least-code--comments),
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
  "branch": "<runtime-substituted actual task branch selected by repository/host/agent>",
  "workspace": "<runtime-substituted absolute selected isolated workspace>",
  "repair": false,
  "retained_pr": null,
  "packet": {
    "task_id": "<runtime-substituted stable task ID>",
    "ordinal": "<runtime-substituted positive ordinal>",
    "child_issue_url": "<runtime-substituted canonical child issue URL>",
    "scope_url": "<runtime-substituted exact --issue/--project/--issues selector>",
    "parent_issue_url": "<runtime-substituted issue scope URL, Project member actual_parent, or selected-list actual_parent>",
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
    "branch": "<runtime-substituted actual task branch>",
    "workspace": "<runtime-substituted absolute selected isolated workspace>",
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

In explicit issue-list mode, `scope_url` is the canonical normalized space-delimited selector
list, `parent_issue_url` is `null` unless the selected issue independently reports a parent, and
the packet's `specification` is that issue's complete body (or explicit complete specification).
The packet also carries `dependency_edges` for the task and the admitted `graph` record. These are
caller-supplied evidence for Execute context; the worker must not infer additional prerequisites or
publish native relationships. An inferred edge is not a GitHub blocked-by edge and does not permit
scope expansion.

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

## Verify the selected workspace before dispatch

The helper reservation records the runtime workspace and branch; it is not itself a Git worktree.
After `schedule` returns, the caller must, before host dispatch:

1. Verify that the selected path is a real linked isolated checkout for the admitted repository (or a
   safe host-created linked-worktree location), and canonicalize it plus every existing `git worktree
   list --porcelain` path with physical path resolution.
2. Compare it against every running/pending reservation, including aliases and ancestor/descendant
   paths. Compare the selected branch against existing checkouts and refs. An active writer,
   wrong-repository checkout, mismatched branch, dirty unrelated workspace, or competing branch
   blocks; do not claim, delete, reset, or create around it.
3. Reuse a suitable existing task worktree when its repository, branch, parent, and ownership facts
   agree. Otherwise let the repository/host/agent create the checkout at the selected location with
   its supported command. No path layout, branch prefix, or universal creation API is required.
4. Read back the physical workspace, repository identity, branch, `HEAD`, selected parent, and
   ancestry. Run `git merge-base --is-ancestor <parent-sha> <head-sha>` in the selected repository
   even when the two hashes are equal. A failed or partial create/read-back is an unknown mutation
   boundary: retain the helper reservation and stop.
5. Pass only that exact workspace to the selected host primitive. The worker writes source only
   there. One writer owns one physical workspace; a timeout or missing receipt does not authorize
   overlapping redispatch until the original worker is proved stopped.

After the launch, [record the native writer](validation.md#record-the-native-writer) against the
reservation. Preserve that host/session/worker identity with the originating native handle,
independently of delivery reports, so a cached completion or timeout cannot be attributed to a
later repair launch or reconciled using another worker's stopped receipt.

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

The worker returns ordinary Execute evidence. The controller binds the nested `worker` report to
the actual originating native handle's `host_id`, `session_id`, and `worker_id`, never by copying
the task's current `host_worker` into a cached result. It adds independent canonical reads,
focused verification, and read-only specification validation using the single
[result schema and gates](validation.md#result-schema), then persists/read-backs the child note
and any explicitly selected Project status before `apply-result`. Do not invent missing evidence
or let the worker approve its own result. Failed checks/specification validation preserve the
same reservation and PR for repair; note/evidence-only retries keep the same recorded native
identity without replaying repository delivery. A new repair launch has its own native identity.

For a missing or malformed response, construct a valid envelope from the originating native handle
with `outcome: "unknown"` or the malformed report fields. Only a bound envelope may transition the
task to unknown and retain ownership. Unreadable/unparseable or unbound envelopes, including stale
repair completions, return `worker-identity` without changing the current reservation or status.
Follow [native identity recovery](validation.md#record-the-native-writer) when the handle is lost;
never relabel an old completion using current task state.

The child PR carries exactly one `Resolves <child URL>` reference. It never closes or references
the specification parent. New PRs remain drafts and no workflow step marks ready, merges, queues,
force-pushes, or silently retargets a PR.

## Existing delivery and resume

A fresh snapshot that includes a delivered task must include `existing_delivery.reservation` and
`existing_delivery.result` with the complete delivery evidence above. Without an active launch,
admission does not require the active-result `host_id`/`session_id` binding; its existing
`worker_id` and independent delivery checks remain required. The skill re-reads the canonical
branch/ref, PR/head/base/repository, focused checks, binary diff, independent validation, note, and
selected Project status immediately before assembly. The helper restores `delivered` only when the
reservation and every result identity/evidence field match; stale or partial evidence blocks. Never
redispatch a task merely because its prior worker output is absent when canonical delivery already
exists.
