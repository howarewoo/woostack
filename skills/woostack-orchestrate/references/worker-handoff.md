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

For every ready task, `schedule` emits one reservation/packet entry. This is an internal bridge
shape, not a caller-facing source schema: all markers are runtime-substituted facts from the
normalized admission and local Git reservation, never evidence to invent.

```json
{
  "task_id": "<runtime-substituted stable task ID>",
  "ordinal": "<runtime-substituted positive ordinal>",
  "child_url": "<runtime-substituted canonical executable issue URL>",
  "parent_branch": "<runtime-substituted selected local parent branch>",
  "parent_sha": "<runtime-substituted selected parent SHA>",
  "branch": "<runtime-substituted actual task branch selected by repository/host/agent>",
  "workspace": "<runtime-substituted absolute selected isolated workspace>",
  "repair": false,
  "retained_pr": null,
  "packet": {
    "task_id": "<runtime-substituted stable task ID>",
    "ordinal": "<runtime-substituted positive ordinal>",
    "child_issue_url": "<runtime-substituted canonical executable issue URL>",
    "scope_url": "<runtime-substituted canonical executable issue URL>",
    "parent_issue_url": "<runtime-substituted independently read actual parent or null>",
    "parent_issue_read": "complete",
    "specification": "<runtime-substituted complete task specification or issue body>",
    "scope_evidence": {
      "tracker": {
        "url": "<canonical selected tracker URL>",
        "id": "<numeric REST tracker ID>",
        "node_id": "<tracker GraphQL node ID>",
        "title": "<complete tracker title>",
        "body": "<complete tracker specification/context body>",
        "revision": "<provider revision>"
      },
      "membership": {
        "source": "native|declared",
        "issues": ["<sorted canonical executable issue URL>"],
        "evidence": "<non-empty actual-read evidence>"
      }
    },
    "repository_rules": "<runtime-substituted complete repository rules>",
    "bounded_input": {
      "goal": "<runtime-substituted resolved contract.goal>",
      "scope": ["<runtime-substituted contract.scope path>"],
      "acceptance": ["<runtime-substituted contract.acceptance criterion>"],
      "checks": ["<runtime-substituted contract.checks command>"],
      "smoke": "<runtime-substituted contract.smoke>"
    },
    "parent_readiness": {
      "execution_prerequisites": [],
      "base_satisfied_prerequisites": [],
      "execution_parent": null,
      "execution_ancestry": [],
      "execution_rationale": "<runtime-substituted compatibility rationale>",
      "execution_constraints": ["<runtime-substituted compatibility constraint>"],
      "execution_fallback": null,
      "logical_prerequisites": [],
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

    "dependency_edges": [],
    "execution_layout": {
      "revision": 1,
      "rationale": "<runtime-substituted whole-plan rationale>",
      "entries": [
        {
          "task_id": "<selected task ID>",
          "execution_parent": null,
          "rationale": "<runtime-substituted compatibility rationale>",
          "constraints": ["<runtime-substituted compatibility constraint>"],
          "base_satisfied_prerequisites": []
        }
      ],
      "effective_edges": []
    },
    "execution_order": {
      "plan_revision": 1,
      "execution_parent": null,
      "rationale": "<runtime-substituted compatibility rationale>",
      "constraints": ["<runtime-substituted compatibility constraint>"],
      "fallback": null,
      "effective_prerequisites": [],
      "base_satisfied_prerequisites": [],
      "ancestry": []
    },
    "graph": {"edges": []},
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
The packet also carries the admitted `execution_layout`, its `execution_order` for this task, the
technical `prerequisites` with provenance, and the controller's `effective_prerequisites` (technical
prerequisites plus the selected `execution_parent`). The execution order is a pre-execution
compatibility forest chosen by the model before branch/worktree allocation. It is not native issue
relationship evidence, and it never expands scope or lets Execute schedule siblings.

The admission's `scope_identity` is the canonical repository plus the sorted canonical URLs of the
verified executable tasks; it does not encode how the user or model found them. In the packet,
`scope_url` is this task's canonical issue URL, not a user selector; `parent_issue_url` is the
independently read native `actual_parent` and may be `null` only after a conclusive absent-parent
read; when unavailable it is omitted and `parent_issue_read` records `unavailable`.
`specification` is the complete task specification or issue body used as worker context, while
`bounded_input` carries the model-resolved contract. The contract retains `goal`, `scope`,
`acceptance`, `checks`, and a real `smoke`; optional
non-goals, decisions, risks, and other bounded context may be included when useful. The model asks
focused questions before admission when source meaning is materially ambiguous; Execute does not
recover that interpretation from a selector or issue layout.

When present, packet `scope_evidence` is the normalized tracker receipt from admission and state.
Its tracker body is complete source/specification context, its membership exactly matches this
admitted task set, and its actual source/evidence remains visible even when the selected tracker is
not the task's native parent. Treat it as read-only context: do not implement the tracker, discover
siblings from it, write relationships, attach the PR, or close it. The exact task `specification` and
contract remain the bounded work; preserve tracker phase and scope constraints that already appear
in them. A revision-only change, reordered references, or declared-to-native transition with the
same task set does not create a new packet identity.

Along with the persisted execution layout, the packet carries this task's `execution_parent`,
rationale, compatibility constraints, optional merge-checkpoint fallback, execution ancestry,
effective prerequisite set, and verified landed-base prerequisite evidence. A selected execution
parent is optional compatibility ordering; it is not a native GitHub relationship and does not
replace the technical prerequisite evidence. The worker must treat effective prerequisites as the
scheduling/readiness graph while preserving technical prerequisites separately. `dependency_edges`
remains context and scheduling evidence, not a native GitHub relationship or permission to expand
scope. The packet's task scope, specification, contract, layout, and readiness are the worker's
complete input; it must not infer missing dependencies, choose a different parent, discover siblings,
or publish an edge.

`scope_evidence` accompanies the packet but is not `actual_parent`; `parent_issue_url` carries only a
conclusively read native parent, and is omitted for an unavailable read. `parent_issue_read` records
the read status when the tracker supplied it. Native, declared, and inferred technical evidence is
scheduling context, not permission to widen scope or publish metadata. Independent task packets may
run concurrently. A dependent packet carries its complete proven effective-prerequisite readiness;
an issue with phase-specific work remains one writer and is not split into duplicate workers.
Technical prerequisites and the model-selected execution order remain separate: the worker must not
treat compatibility ordering as native evidence, rewrite requirements, or infer a missing parent. A
join with a selected execution parent can stack on that verified parent when containment is eligible.
Only when the approved layout explicitly selects a `merge-checkpoint` fallback and no safe existing
parent is available does the affected packet pause as `waiting-for-merge`; unrelated work continues
and a join otherwise does not require a new parent or integration decision. The waiting record
carries the prerequisite PRs, intended integration branch, fallback reason, and release condition.

The example's `parent_readiness` is a root with proved parent-PR absence. For a dependent,
`logical_prerequisites` is the complete technical task-ID set, while `execution_prerequisites` is
the complete effective set. `prerequisites` has exactly one record per effective prerequisite:
`task_id`, exact `issue_url`, `relationship` (`technical`, `stack`, or `technical+stack`), full
checkpoint (the complete [result object](validation.md#result-schema), including checks, PR
head/base/state/reviews/threads, independent validation, and persisted note), and verified
containment. Those SHAs are the prerequisite head and retained parent start; the helper has actually
verified their Git ancestry. `parent.selection` is `technical-parent`, `stack-parent`,
`landed-stack-parent`, `integration`, or `explicit`. An explicit choice carries its preserved
`{task_id, branch, sha}` decision; other selections use `null`. `parent.pr_evidence` uses fresh parent
PR discovery ([scheduling](scheduling.md#normalized-snapshot)).
The [landed-base exception](scheduling.md#normalized-snapshot) is separate from that effective set.
Every logical prerequisite must be covered by either an effective checkpoint or a
`base_satisfied_prerequisites` entry in the task's persisted execution layout. For the latter, the
worker verifies the recorded landed revision against the actual reserved parent SHA before mutation;
it does not require a controller-owned delivery checkpoint.


The complete Execute input comprises `bounded_input` **and** this readiness object plus the task
specification context, repository rules, and execution layout/order. The worker verifies that exact
effective prerequisite set, full checkpoints, selected parent, current PR facts, and ancestry before
Git mutation. It must block missing evidence, not discover the graph or infer readiness from a branch
name. Repairs retain their original start, even if a separately verified parent tip has advanced
compatibly. The controller persists the plan revision and fingerprint with the state, so equivalent
reordered input resumes the same plan. A newer layout revision requires genuinely unstarted changes
except for [verified legacy-migration recovery](scheduling.md#fingerprints-and-fresh-refills);
otherwise it is `execution-plan-drift`. A changed technical graph is `snapshot-drift`.


A repair entry keeps the same `branch`, absolute `workspace`, `parent_branch`, `parent_sha`, and
retained PR as its original reservation and sets `repair: true`. It never receives a new parent or
replacement PR. The task issue URL is the only issue association and closing reference. A repair
dispatched from [PR-check observation](validation.md#pr-check-observation-and-repair) additionally
carries the failing revision and the check/log evidence that justified it; the worker revalidates
that revision's freshness before editing, diagnoses through the surviving Debug workflow when needed,
and returns ordinary Execute evidence on the same branch/PR. Local test success or a successful
push is not proof that the new CI run passed; the controller independently verifies the new head
and resumes observation.

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
`existing_delivery.result` with the complete delivery evidence above. It reuses the admitted
`scope_evidence` and canonical task claims rather than selecting a fresh set from tracker prose.
Without an active launch, admission does not require the active-result `host_id`/`session_id`
binding; its existing `worker_id` and independent delivery checks remain required. The skill re-reads
the canonical tracker/scope evidence, branch/ref, PR/head/base/repository, focused checks, binary
diff, independent validation, note, and selected Project status immediately before assembly. The
helper restores `delivered` only when the reservation, meaningful tracker context, and every result
identity/evidence field match; a provider revision, reference order, or matching native membership
alone does not require redispatch, while stale or partial material evidence blocks. Never redispatch
a task merely because its prior worker output is absent when canonical delivery already exists.
