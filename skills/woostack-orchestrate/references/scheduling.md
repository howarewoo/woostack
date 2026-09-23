# Scheduling, snapshot, and state contract

This reference is the machine-facing contract for
[`woostack-orchestrate`](../SKILL.md) and the shipped
`scripts/orchestrate.py` helper. The helper is the only scheduler. It reads local JSON and local
Git ancestry evidence, never calls a network, and never spawns a worker. The skill obtains or
reuses an isolated workspace through repository/host capabilities and delivers the helper packet
through the selected host adapter.

Link rather than copy the shared [source-control contract](../../woostack-commit/references/graphite.md),
the outcome-level [runtime workspace guidance](#runtime-workspace-and-branch-evidence),
the [least-code standard](../../woostack-bootstrap/references/patterns.md#7-least-code--comments),
the [model tiers](../../using-woostack/references/model-tiers.md), and canonical
[`#artifact-delivery-note`](../../woostack-commit/references/provider-attribution.md#artifact-delivery-note)
contract.

## Runtime workspace and branch evidence

The admitted task contract contains scope, dependencies, verification, and intended Git-parent
policy; it does not contain a future workspace path or branch-name recipe. On each fresh `schedule`
call, the repository, host, or agent may supply the actual selected `workspace` and `branch` on a
task record. These values are runtime evidence, not publication identity and are excluded from the
admission fingerprint. They may be absolute or
repository-relative paths; the helper resolves relative paths only against the supplied
`--git-repo` root and emits the resulting absolute path.

The selected checkout may be repository-managed, a host-created linked worktree, or an already-created
suitable external linked worktree. It may be outside `.woostack/` or outside the primary checkout. No
allocation command, directory layout, branch prefix, or creation/adoption mode is required. A task
without current runtime allocation evidence is reported as `workspace-unassigned`; the caller
supplies the next fresh snapshot after choosing a safe isolated workspace through its supported
mechanism. The helper never falls back to the primary checkout.

Before dispatch, validate the actual selected path and branch against the admitted canonical
repository, physical path aliases, complete Git worktree inventory, active reservations, branch
checkouts, and parent ancestry. Existing suitable worktrees can be reused. Wrong-repository,
wrong-branch, dirty unrelated, active-writer, alias/ancestor, or incompatible branch evidence
blocks without deletion, reset, cleanup, takeover, or automatic relocation. Delivery and recovery
must retain the selected workspace and branch and verify the same checkout before reuse.

## Native reads before JSON assembly

Resolve host capability before GitHub access. The selected host must expose a real
delivery-capable subagent primitive. Record `delivery_capable: true` and its observed positive
`max_parallel` in the snapshot. A smaller host cap is a scheduling clamp, not a scope-admission
failure; absence of a delivery primitive blocks before `admit` rather than degrading to inline
implementation. Host mechanics and tier routing remain in the allowlisted host references.

Resolve the canonical Git repository and integration branch/SHA from direct Git and an authorized
GitHub capability exposed by the host (prefer native GitHub tools when suitable; host-authenticated
`gh` remains supported). Discover actual operation capabilities and read shapes from the host. Use
the issue, parent, dependency, Project, field, PR, and note reads described by the [GitHub provider
profile](../../woostack-init/references/artifact-providers/github.md). Exhaust every page
(`--paginate` or the equivalent native pagination operation), then independently read every
endpoint needed to identify executable issues, understand their source context, resolve contracts,
and establish dependency, Project, PR, and recovery evidence. A missing or failed page is incomplete
evidence, not an empty collection; record terminal-read evidence only after the corresponding read
actually completes.

The model, not a selector or source layout, decides which issues are executable. It reads issue
bodies, comments, repository instructions, and relevant tracker/Project context, asks a focused
question for material ambiguity, and resolves the bounded task contract. A specification parent,
container, or tracker record can provide context without becoming a task. Do not substitute an issue
number for a REST ID, GraphQL node ID, or canonical URL, and do not infer identity or scope from a
title, branch, PR, search result, or body shorthand. Preserve exact source and native evidence.

## Normalized snapshot

The controller writes one private JSON snapshot from completed reads. The example is an internal
shape for the helper and is not a caller-facing source schema; all markers are runtime facts.

```json
{
  "canonical_repo": "<runtime-substituted canonical repository>",
  "integration": {
    "branch": "<runtime-substituted integration branch>",
    "sha": "<runtime-substituted admitted integration SHA>"
  },
  "repository_rules": "<runtime-substituted complete repository rules>",
  "host": {
    "delivery_capable": true,
    "max_parallel": "<runtime-substituted positive host capability>"
  },
  "tasks": [
    {
      "task_id": "<runtime-substituted stable Git-safe task ID>",
      "ordinal": "<runtime-substituted positive tie-break ordinal>",
      "url": "<runtime-substituted canonical executable issue URL>",
      "id": "<runtime-substituted positive native REST issue ID>",
      "node_id": "<runtime-substituted opaque GraphQL issue node ID>",
      "state": "open",
      "resource": "issue",
      "title": "<runtime-substituted complete native title>",
      "body": "<runtime-substituted complete native body>",
      "actual_parent": "<runtime-substituted independently read native parent URL or null>",
      "prerequisites": [],
      "external_prerequisites": [],
      "specification": "<runtime-substituted complete task specification or issue body>",
      "contract": {
        "goal": "<runtime-substituted resolved goal>",
        "scope": ["<runtime-substituted bounded path or surface>"],
        "acceptance": ["<runtime-substituted observable criterion>"],
        "checks": ["<runtime-substituted exact required command>"],
        "smoke": "<runtime-substituted real changed-path smoke scenario>"
      }
    }
  ],
  "edges": [
    {
      "predecessor": "<runtime-substituted task ID or verified external blocker>",
      "dependent": "<runtime-substituted task ID>",
      "provenance": "native|declared|inferred",
      "evidence": "<non-empty native read, declaration, or model rationale>"
    }
  ],
  "parent_prs": {
    "<runtime-substituted integration or approved parent branch>": {
      "repo": "<runtime-substituted canonical repository>",
      "branch": "<same parent branch>",
      "head_sha": "<independently read current branch tip>",
      "complete": true,
      "prs": []
    }
  },
  "recovery": {
    "checkpoints": ["<runtime-substituted controller/worker checkpoint evidence>"],
    "processes": ["<runtime-substituted worker process liveness evidence>"],
    "sessions": ["<runtime-substituted host session liveness evidence>"],
    "worktrees": ["<runtime-substituted canonical Git worktree inventory>"],
    "refs": ["<runtime-substituted branch/ref and dirty-state evidence>"],
    "prs": ["<runtime-substituted canonical PR evidence>"],
    "contracts": ["<runtime-substituted admitted contract revisions>"],
    "dependencies": ["<runtime-substituted native dependency/pagination evidence>"]
  }
}
```
The admission's canonical `scope_identity` is `{ "canonical_repo": <repository>, "issues":
[<sorted canonical executable issue URLs>] }`. It is derived from verified tasks, not from the
user's wording or the source container.

`tasks` contains only verified executable issues. A task's `contract` retains the fields Execute
and validation need: `goal`, `scope`, `acceptance`, `checks`, and a real `smoke`. The model may
retain additional bounded context such as `non_goals`, `decisions`, or `risks`; the source issue is
not required to use a fixed field layout. A material unresolved ambiguity blocks admission until the
user answers a focused question. Existing delivery evidence is added to a task when independently
re-reading a delivered task, and is never copied from a worker's success sentence.

`edges` is the complete supplied DAG. Each edge has a predecessor, dependent, provenance of
`native`, `declared`, or `inferred`, and non-empty evidence. Native blocked-by reads, explicit issue
declarations, and model-resolved technical prerequisites remain distinguishable. The model owns
meaning and inference; the helper validates endpoint existence, duplicate/self edges, external
blockers, and acyclicity. A conflict, unknown endpoint, ambiguous direction, or cycle blocks the
affected work. An empty edge list is valid when the actual reads and interpretation establish no
dependency; no separate graph receipt is required.

`parent_prs` supplies fresh canonical PR discovery for the integration branch and any explicitly
selected non-predecessor parent. An empty `prs` array means fully proved absence, not unavailable
access. Otherwise supply one exact PR record with `pr_url`, `repo`, `head_repo`, `branch`,
`head_sha`, `base_branch`, current `state` (`open`, `closed`, or `merged`), and fully paginated
current-head `reviews`/`threads` in the [validation readback shape](validation.md#result-schema).
Ambiguous or incomplete discovery blocks selection. Predecessor parents use their fresh complete
delivery checkpoint instead. Current tips may advance for an already-reserved child only while its
original start remains an ancestor; do not replace that child's retained start SHA.

When a Project is explicitly selected for status mutation, add its independently read identity and
configured lifecycle mapping:

```json
{
  "project": {
    "url": "<runtime-substituted canonical Project URL>",
    "number": "<runtime-substituted positive Project number>",
    "node_id": "<runtime-substituted opaque GraphQL Project node ID>",
    "owner": "<runtime-substituted Project owner>",
    "owner_type": "organization|user",
    "state": "open"
  },
  "lifecycle": {
    "inReview": "<runtime-substituted configured option>"
  }
}
```

Project membership is evidence for identifying executable tasks, not a requirement to flatten a
hierarchy. Nonmembers and nested containers remain context and are never imported as tasks. Every
task that will receive Project status carries its independently read native `item_id`; repeated
evidence is deduplicated only when immutable identity agrees. Admission is read-only: it never
creates a Project, changes membership, mutates an issue, or publishes an edge.

## Invoking the bridge

Assemble the normalized snapshot from actual native/Git reads, serialize it with a JSON writer, and
use the [canonical CLI sequence](../SKILL.md#one-real-helper-path). The examples describe runtime
fields, not fixtures to submit unchanged. Keep snapshot, admission, result, and state files private
(`umask 077`). Only `schedule` without `--state` initializes the state; every later call uses the
existing state and newly assembled `--fresh` evidence. Follow the [completion-driven refill
loop](../SKILL.md#continuously-refill-on-completion), not batch barriers.

## Fingerprints and fresh refills

Admission computes a `fingerprint` as `sha256:` plus the SHA-256 of canonical JSON (sorted keys,
compact separators) over the immutable normalized scope view. It binds:

- the canonical repository and sorted canonical executable issue URLs;
- each task's stable task ID, URL, native IDs, state/resource, complete title/body, effective
  `specification` and `actual_parent`, resolved bounded contract, and external blockers;
- complete repository rules, effective dependency endpoint pairs, and normalized edge `provenance`
  and `evidence`; and
- optional Project/lifecycle identity only when the user explicitly selected that Project for
  status mutation.

It deliberately excludes the host capability/cap, mutable integration SHA, fresh `parent_prs`,
runtime workspace/branch allocation, and delivery evidence. Those mutable facts are checked on every
refill. A changed issue set, contract, identity, specification, actual parent, edge endpoint,
edge provenance/evidence, or blocker returns `snapshot-drift`; preserve all running reservations,
claims, recovery inventory, and worker identity, and launch no fresh worker. The controller must
re-read native state and assemble `--fresh` for every refill, including immediately after a worker
result and after reconciliation.

Every fresh refill carries the complete recovery inventory described above: checkpoint/state
identities, worker processes/sessions, Git worktrees/refs/dirty state, canonical PRs, contract
revisions, and native dependency reads. Missing or incomplete pages are unknown, never an empty
task set. The helper records the inventory as recovery evidence; it never treats a worker assertion,
selector, branch name, or prior success sentence as ownership.

A fresh snapshot for a task already delivered must carry complete `existing_delivery` evidence:

```json
{
  "existing_delivery": {
    "reservation": {
      "branch": "<same runtime-selected task branch>",
      "workspace": "<same absolute selected isolated workspace>",
      "parent_branch": "<same selected parent branch>",
      "parent_sha": "<same admitted parent SHA>"
    },
    "result": "<the complete same-schema result evidence, runtime-substituted>"
  }
}
```

The skill obtains that result from fresh canonical branch/PR/head/base/repository/review/thread,
focused-check, diff, independent validation, note, and selected Project-status reads. Before
restoring `delivered`, the helper checks prerequisites in dependency order, rejects external
blockers, requires every prerequisite's independently verified delivery, and re-proves parent
intent and containment. Roots retain the admitted integration parent. An alternate integration
choice requires the original state's preserved explicit decision or a current `--parent-decision`
matching the retained reservation, plus fresh `parent_prs` evidence. A historical PR alone cannot
waive these gates. Missing/stale/partial proof preserves ownership and blocks only that task and
its descendants; it never redispatches a duplicate or releases descendants.

## State, reservations, and joins

State is one explicit private session-local controller file, not a provider or retained-artifact ledger.
It carries `version`, the immutable `fingerprint`, exact `scope_identity`, a random controller owner
token, stop/halt flags, last recovery inventory, and one task entry per admitted executable issue.
Each task entry keeps its native identity, dependency/claim provenance, contract revision, worker
identity, reservation/worktree/branch/parent start, current source/diff identity, checks/validator
receipts, PR identity, delivery checkpoint, and first uncertain boundary distinct. The caller must
externally enforce exclusive ownership of the selected canonical scope/state for the controller
session, covering every `schedule`, `record-worker`, `apply-result`, and `reconcile` call. If
exclusive ownership cannot be proved, block at controller preflight before invoking the helper.

The helper additionally takes owner-only atomic claims under
`<primary-root>/.woostack/tmp/orchestrate-claims/`: one exact normalized-scope claim and one claim
keyed by the canonical repository plus each canonical task issue URL (with native REST/GraphQL IDs
retained in the claim record). Each record is serialized and fsynced in an owner-only
same-directory temp file, then atomically hard-linked to its final path without replacement and
followed by a claims-directory fsync. A second controller whose normalized task set overlaps a task
therefore blocks before reservation. An interruption leaves either no final claim or a complete
claim; a stale, foreign, or unreadable claim is a blocker, never permission to take over. Existing
active issue/PR/checkpoint evidence without the current owner claim is likewise a blocker. Claims
remain retained as recovery evidence until explicit human cleanup; they are not a scheduler/database
or a replacement for the owner-only checkpoint contract.
Each mutation acquires an owner-owned per-scope checkpoint lock derived from the canonical repository
and scope fingerprint, then compares the loaded digest with the durable checkpoint head while holding
that lock before replacing `--state-out`; stale/concurrent writers fail closed as `stale-state`, and
the previous checkpoint remains intact. Before replacing `--state-out`, the helper also atomically
records an owner-only pending generation containing the prior head/output digest and the next
state/head pair. Recovery accepts only the exact prior pair (discarding the pending record) or the
exact next pair (finishing the head publication); if next state bytes are present with the prior
head, only a caller that loaded those next bytes may finish recovery. Any other pairing blocks as
checkpoint recovery evidence and never adopts arbitrary bytes. The head is independent of
input/output filenames, so a second writer using the same stale `--state` cannot advance a different
`--state-out`.
The first schedule omits `--state` and creates state. Every later schedule, record-worker,
apply-result, reconcile, or stop names an existing state and matching admission. Missing state, malformed JSON,
state/fingerprint/scope mismatch, missing durable checkpoint head, or a state task set that differs
from the admission blocks; never silently reinitialize. The initial state is published before the
scope claim is acquired, and the claim becomes visible only after its complete owner-bearing record
is durable. A first-schedule interruption therefore leaves resumable owner-bearing state with either
no claim or one complete same-owner claim. Keep the state path private and use the helper's atomic
`--state-out` replace.

Under that exclusive ownership, the helper persists the actual selected task branch, absolute
workspace, parent branch, and parent SHA before host dispatch. The branch and workspace are runtime
facts, not stable task-ID projections or required publication fields. Repairs reuse the exact
original reservation and retained PR. Before reuse, compare canonical physical paths (including
aliases and ancestor/descendant paths), repository identity, current branch/HEAD, and complete Git
worktree inventory. A suitable existing worktree may be retained; an incompatible or unclaimed
branch/workspace blocks. The helper reservation does not itself create Git state.
After launch, checkpoint the [native writer identity](validation.md#record-the-native-writer)
separately from the worker's delivery report. Missing or uncorrelated native identity keeps unknown
work reserved; no stopped receipt may substitute a foreign session or previous repair attempt.

Roots use the admitted integration branch/SHA. A dependent may use a delivered prerequisite branch
or the admitted integration branch only when local
`git merge-base --is-ancestor <each-prerequisite-head> <candidate-tip>` proves one candidate
contains every prerequisite. The actual local ref for the selected parent branch must equal the
selected SHA. Run the ancestry command even for equal hashes; missing Git access is unverifiable,
not contained. Explicit parent decisions are evidence requests, not proof, and must pass the same
checks. An unresolved join pauses only that task.

## Helper status meanings

The helper writes machine-readable JSON and exits zero for controlled workflow statuses such as
`no-work`, `snapshot-drift`, `halted`, `stopped`, and per-task `unknown`; it exits one with
`{"ok":false,"error":...}` for blocked input. The skill must inspect the status and retain output,
not treat process exit zero as delivery. `schedule` output includes dispatch entries, delivered,
active, unknown, evidence-pending, repair-ready, pending, and paused/blocked/waiting IDs with exact
next actions.
`record-worker`, `apply-result`, `reconcile`, and `stop` outputs are authoritative state transitions; never invent a
success response around them. A user stop prevents new dispatch but does not declare active workers
stopped or discard their worktrees.
