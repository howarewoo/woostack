# Scheduling, snapshot, and state contract

This reference is the machine-facing contract for
[`woostack-orchestrate`](../SKILL.md) and the shipped
`scripts/orchestrate.py` helper. The helper is the only scheduler. It reads local JSON and local
Git ancestry evidence, never calls a network, and never spawns a worker. The skill obtains or
reuses an isolated workspace and delivers the helper packet through an authorized host primitive.

Link rather than copy the shared [source-control contract](../../woostack-commit/references/source-control.md),
the outcome-level [runtime workspace guidance](#runtime-workspace-and-branch-evidence),
the [least-code standard](../../woostack-bootstrap/references/patterns.md#7-least-code--comments),
the [model tiers](../../using-woostack/references/model-tiers.md), and canonical
[`#artifact-delivery-note`](../../woostack-commit/references/provider-attribution.md#artifact-delivery-note)
contract.

Load only the section you need: [runtime workspace and branch evidence](#runtime-workspace-and-branch-evidence) ·
[native reads before JSON assembly](#native-reads-before-json-assembly) ·
[normalized snapshot](#normalized-snapshot) · [invoking the bridge](#invoking-the-bridge) ·
[fingerprints and fresh refills](#fingerprints-and-fresh-refills) ·
[state, reservations, and joins](#state-reservations-and-joins) ·
[helper status meanings](#helper-status-meanings).

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

Before GitHub access, prove an actually available authorized mechanism for worker delivery,
isolated workspaces, native result correlation, and recovery. Record
`delivery_capable`, `workspace_isolation_capable`, `result_correlation_capable`, and
`recovery_capable` together with a positive observed `max_parallel` in the snapshot. Host names and
reference files are recipes, not admission authority. A smaller cap is a scheduling clamp, not a
scope-admission failure; any missing capability blocks before `admit` rather than degrading to
inline implementation or a guessed adapter.

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

The Orchestrate controller reads native stack membership when a selected parent PR may be
registered, to identify the trunk that supplies its applicable review policy. It never creates,
extends, or reconciles a stack; that is the owner's
[stack membership contract](../../woostack-commit/references/source-control.md#native-github-stack-membership-for-a-dependent-pr)
for a delivery, and an unreadable stack read leaves the parent policy unproven.

The model, not a selector or source layout, decides which issues are executable. It reads issue
bodies, comments, repository instructions, and relevant tracker/Project context, asks a focused
question for material ambiguity, and resolves the bounded task contract. A specification parent,
container, or tracker record can provide context without becoming a task. Do not substitute an issue
number for a REST ID, GraphQL node ID, or canonical URL, and do not infer identity or scope from a
title, branch, PR, search result, or body shorthand. Preserve exact source and native evidence.

For an exact selected tracker, read the tracker itself and the actual issues it names. A complete
implementation index, checklist, table, or accompanying scope statement is valid declared
membership when native children are absent, incomplete, or unavailable. Resolve relative `#N`
references against the verified tracker repository, read every selected issue, and deduplicate
repeated references. Do not import every issue-like mention: separate implementation issues from
design/context issues, baseline or example PRs, exclusions, history, the tracker itself, and
external prerequisites. Resolve those roles from
the selected tracker and fetched issue evidence, not from issue numbers or a source layout learned
from another tracker. A native subset plus a complete explicit tracker set is membership evidence,
not permission to import the native parent's other children. Contradictory membership declarations
require a focused question; inaccessible or unreadable evidence is not guessed.

Retain tracker phase annotations in the selected task's specification or contract. A phase label
remains work inside the issue that declares it: it is not another issue identity or writer, its
early completion does not complete that issue, and start-versus-completion gates do not become a
fabricated cycle. If one phase or delivery limitation independently remains unsatisfied, block
that precise affected task while unrelated tasks continue. Unknown optional native relation access
is disclosed honestly; it does not erase declarations from a tracker that was actually read.

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
    "workspace_isolation_capable": true,
    "result_correlation_capable": true,
    "recovery_capable": true,
    "max_parallel": "<runtime-substituted positive host capability>"
  },
  "scope_evidence": {
    "tracker": {
      "url": "<canonical tracker issue URL>",
      "id": "<numeric REST issue ID>",
      "node_id": "<GraphQL issue node ID>",
      "title": "<complete tracker title>",
      "body": "<complete tracker body>",
      "revision": "<provider revision such as updated_at>"
    },
    "membership": {
      "source": "native|declared",
      "issues": ["<sorted canonical executable issue URL>"],
      "evidence": "<non-empty actual tracker/native-read evidence>"
    }
  },
  "tasks": [
    {
      "task_id": "<runtime-substituted stable opaque task ID>",
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
  "execution_layout": {
    "revision": 1,
    "rationale": "<model-selected single-parent compatibility layout>",
    "entries": [
      {
        "task_id": "<selected task ID>",
        "execution_parent": null,
        "rationale": "<why this approved-base root is safe>",
        "constraints": ["<repository or compatibility evidence>"]
      }
    ],
    "effective_edges": []
  },
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

`scope_evidence` is optional and records tracker meaning, not another task set. The tracker URL is
canonical, belongs to `canonical_repo`, and differs from every task URL. Its real native identity,
title, body, and provider revision are retained. `membership.issues` exactly matches the sorted
canonical `tasks` URLs; `source` is `native` only for a complete successfully read native set and
`declared` when the verified tracker supplies the complete set without complete native membership.
`evidence` describes the reads actually performed, including unavailable hierarchy access; never
encode a failed or unsupported read as a successful empty page. This root context may be omitted for
existing explicit-list or Project snapshots. The tracker never enters `tasks`, becomes a dependency
endpoint, or receives a worker or PR.

`tasks` contains only verified executable issues. A task's `actual_parent` is its independently read
native parent, or `null` only after a conclusive read; declared tracker membership is never written
there. A task's `contract` retains the fields Execute and validation need: `goal`, `scope`,
`acceptance`, `checks`, and a real `smoke`. The model may retain additional bounded context such as
`non_goals`, `decisions`, `risks`, or phase annotations; the source issue is not required to use a
fixed field layout. A material unresolved ambiguity blocks admission until the user answers a
focused question. Existing delivery evidence is added to a task when independently re-reading a
delivered task, and is never copied from a worker's success sentence. Each selected task also receives
normalized `execution_parent`, `execution_rationale`, `execution_constraints`, optional
`execution_fallback`, `execution_ancestry`, `effective_prerequisites`, and the helper-derived
`base_satisfied_prerequisites` or model-supplied `satisfied_external_prerequisites`; its
`dependency_snapshot` retains technical `prerequisites`, the selected `execution_parent`, and
external prerequisite identities, while the layout entries keep landed satisfaction evidence. These
fields are verified scheduling evidence, not source edits or native relationship writes. The worker
packet binds the same values and plan revision.
Missing, contradictory, unmerged, reverted, or non-containing external satisfaction evidence
leaves that dependent blocked with the affected issue and evidence reason; it does not reject the
whole snapshot or prevent unrelated tasks from dispatching.

`edges` is the complete supplied DAG. Each edge has a predecessor, dependent, provenance of
`native`, `declared`, or `inferred`, and non-empty evidence. Native blocked-by reads, explicit
tracker/issue declarations, and model-resolved technical prerequisites remain distinguishable.
Checklist or issue-number order creates no edge, and a complete empty native dependency read does not
erase a verified declared edge. The model owns meaning and inference; the helper validates endpoint
existence, duplicate/self edges, external blockers, and acyclicity. A conflict, unknown endpoint,
ambiguous direction, or cycle blocks the affected work. An empty edge list is valid when actual reads
and interpretation establish no dependency; no separate graph receipt is required.
The technical DAG is admission evidence, not the execution layout. After the technical graph and
repository constraints are resolved, the model selects one `execution_layout` before any branch or
workspace allocation. It has a positive `revision`, a rationale, and one entry for every selected task
exactly once. Each entry carries `execution_parent` (the approved-base root is `null`), its rationale,
and non-empty compatibility `constraints`; a task that cannot use a safe single-parent stack records
the optional `fallback: {reason: "merge-checkpoint", release_condition}`. The combined technical-plus-
execution graph must be acyclic, and every technical prerequisite must appear on the task's execution
ancestor path or in a verified `base_satisfied_prerequisites` entry naming the merged revision
contained in the approved integration base. The helper derives those entries from each selected
task's retained delivery evidence instead of trusting a model assertion: the associated PR must be
merged into the integration branch with complete landed verification whose diff identity still
matches the merged revision. A prerequisite whose delivery is available that way needs no
controller-owned worker delivery, claim, or recovery import. For these entries, `admit --git-repo
<canonical-checkout>` verifies the repository remote and uses Git ancestry to prove each landed
revision is contained in the snapshot's exact `integration.sha`, not merely the branch's current
tip. Missing Git evidence blocks admission; lifecycle flags and matching branch names alone do not
prove containment. Scheduling repeats these checks on its fresh snapshot. Verified base-satisfied
prerequisites remain technical requirements but are excluded from `effective_prerequisites`, while
`effective_edges` keeps every plan edge: dependent readiness uses the landed-base evidence without
importing a controller-owned delivery or waiting for that task's lifecycle/CI state.

A declared fallback must cover at least one technical join. Once every such join is base-satisfied
the gate is released, and the admitted task carries no fallback.

A `satisfied_external_prerequisites` row retains the
external issue identity, source/provenance, associated merged PR, landed diff identity, and
task-relevant verification while leaving the external issue outside `tasks`, claims, workers, and PRs.
Its revision must be contained in the exact `integration.sha` and later in the actual selected parent;
issue closure, branch names, green checks, or a merge into another branch are insufficient. Missing,
partial, contradictory, unmerged, non-containing, or reverted evidence leaves the external edge as
an affected-task blocker. Parent selection and retained-start validation still prove every landed
revision is contained in the actual selected parent, including an open stack parent. A base-satisfied
execution parent selects the integration base while preserving its planned task identity. A selected
parent is optional compatibility ordering, not native relationship evidence. The layout must retain
useful parallelism; the model owns this selection, while Execute/Commit do not schedule siblings.


`parent_prs` supplies fresh canonical PR discovery for the integration branch and any explicitly
selected non-predecessor parent. An empty `prs` array means fully proved absence, not unavailable
access. Otherwise supply one exact PR record with `pr_url`, `repo`, `head_repo`, `branch`,
`head_sha`, `base_branch`, current `state` (`open`, `closed`, or `merged`), and the complete
[validation readback shape](validation.md#result-schema) observed at that head, including review
history, thread dispositions, and current repository review policy.
That policy is the same applicable review policy the validation contract names: the verified native
stack trunk for a registered stack member, otherwise the PR's own base branch.
Ambiguous or incomplete discovery blocks selection. Predecessor parents use their fresh complete
delivery checkpoint instead. Current tips may advance for an already-reserved child only while its
original start remains an ancestor; do not replace that child's retained start SHA.

When the integration tip changes, `schedule` verifies the canonical repository and branch, the
previous and proposed commit objects, forward ancestry, and the complete changed-path set. An
unrelated forward advance is compatible when it does not materially change a selected task's
contract scope. For a merged selected prerequisite, the shared availability proof compares
the landing's changed paths to the candidate base; a later change to that content makes only
that prerequisite and its dependents wait for fresh independent validation. Rewrites, missing
objects, wrong refs, and impact on unfinished selected work remain `parent-tip-drift` until
reconciled. A compatible advance is recorded in controller recovery and may supply the refreshed
parent only to newly eligible roots; it never reparents an existing reservation or replaces its
workspace, PR, or worker contract.

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
invoke the shipped helper. These examples describe runtime fields, not fixtures to submit unchanged.
Keep snapshot, admission, result, and state files private (`umask 077`). Only `schedule` without
`--state` initializes the state; every later call uses the existing state and newly assembled
`--fresh` evidence. Do not omit `--fresh` on an initial or subsequent refill, and do not pass a newly
created replacement state after admission. Follow the [completion- and check-driven refill
loop](../SKILL.md#procedure), not batch barriers.

```text
python3 <orchestrate-skill>/scripts/orchestrate.py admit \
  --snapshot <freshly-assembled-snapshot.json> \
  [--max-parallel <n>] > admitted.json

# Initial refill: deliberately omit --state. --fresh and --git-repo are required.
python3 <orchestrate-skill>/scripts/orchestrate.py schedule \
  --admitted admitted.json --state-out controller-state.json \
  --git-repo <canonical-git-repository> --fresh <fresh-snapshot.json> \
  [--cap <host-cap>] [--parent-decision <decision.json>]

# Every later refill: state must already exist. Re-read and assemble a new fresh snapshot first.
python3 <orchestrate-skill>/scripts/orchestrate.py schedule \
  --admitted admitted.json --state controller-state.json \
  --state-out controller-state.json \
  --git-repo <canonical-git-repository> --fresh <fresh-snapshot.json> \
  [--cap <host-cap>] [--parent-decision <decision.json>]

# Explicit recovery for a stopped controller with import-only uncertainty.
python3 <orchestrate-skill>/scripts/orchestrate.py resume \
  --admitted admitted.json --state controller-state.json \
  --state-out controller-state.json --git-repo <canonical-git-repository> \
  --fresh <fresh-snapshot.json>

python3 <orchestrate-skill>/scripts/orchestrate.py stop \
  --admitted admitted.json --state controller-state.json \
  --state-out controller-state.json --git-repo <canonical-git-repository> \
  [--reason <safe-stop-reason>]
```

## Fingerprints and fresh refills

Admission computes a `fingerprint` as `sha256:` plus the SHA-256 of canonical JSON (sorted keys,
compact separators) over the immutable normalized scope view. It binds:

- the canonical repository and sorted canonical executable issue URLs;
- each task's stable task ID, URL, native IDs, state/resource, complete title/body, effective
  `specification` and native-only `actual_parent`, resolved bounded contract, and external blockers;
- complete repository rules, effective technical dependency endpoint pairs, and normalized edge
  `provenance` and `evidence`;
- the normalized execution layout and its own `execution_fingerprint` over the plan itself — its
  revision, rationale, entries, effective edges, and execution order, without the
  availability-derived `base_satisfied_prerequisites` and `satisfied_external_prerequisites` rows
  or the declared merge `fallback`, whose gate only exists while a technical join is unlanded, so
  newly landed satisfaction evidence refreshes without a plan change;
- the selected tracker URL and meaningful scope/specification context when optional
  `scope_evidence` is present; and
- optional Project/lifecycle identity only when the user explicitly selected that Project for
  status mutation.

It deliberately excludes the host capability/cap, mutable integration SHA, fresh `parent_prs`,
runtime workspace/branch allocation, and delivery evidence. A tracker provider `revision` alone,
reordered repeated tracker references, reordered task/layout entries, and a matching native-link
addition that leaves the exact task set, technical graph, and execution plan unchanged are mutable
evidence, not drift; membership may transition from `declared` to `native` for the same set. Those
mutable facts are still refreshed and recorded. A changed issue set, contract, identity, meaningful
tracker scope/specification, actual parent, technical edge endpoint/provenance/evidence, or blocker
returns `snapshot-drift`. A changed execution layout returns controlled `execution-plan-drift` when
it touches started, reserved, claimed, worker-owned, or delivered work. A newer plan revision is
adopted only when every changed task is genuinely unstarted and compatible with complete retained
recovery and repository evidence. Legacy state without a plan treats the proposed layout as a
candidate: incompatible retained reservations or prerequisite ancestry return
`execution-plan-drift` without writing a new state or checkpoint. The original bound worker can
complete under a compatible admission, then scheduling can resume. For states already persisted by
an earlier controller with `legacy_execution_plan_drift`, a newer revision may clear that drift
only after every flagged task's retained reservation branch and full prerequisite ancestry are
proved compatible. An incompatible revision leaves the halt and worker ownership intact. The
accepted layout, fingerprint, changed unstarted-task dependencies, and plan history are written in
the same atomic checkpoint before any new dispatch. Unchanged active tasks retain their issued
plan revision and dependency snapshot. Their original admission remains usable for bound result,
check, and reconciliation calls when plan history proves their execution entry and ancestry
unchanged; result application rejects a newer admission that the worker never received. Each newly
dispatched repair attempt binds to the current execution plan and dependency context it receives
before launch, and its completion must be accepted under that issued plan rather than a stale prior
attempt revision, while an active repair worker preserves its issued plan binding across any
subsequent compatible replans. Descendant repair propagation uses the current persisted effective graph.
The execution fingerprint remains useful admission evidence, but it is not a worker-validity
gate. The helper compares the normalized task-local execution identity (parent, constraints,
fallback, effective prerequisites, and ancestry) for replan decisions; explanatory layout
rationale and formatting-only revisions do not invalidate an already issued attempt. Contract,
permission, parent, or dependency meaning changes still require reconciliation.
boundaries and requires a fully fresh interpreted snapshot.

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
    "result": "<the complete same-schema result evidence, runtime-substituted>",
    "lifecycle": {
      "pr": "<fresh canonical open, closed, or merged PR readback>",
      "source": "<fresh source-ref existence readback>",
      "checks": "<required current check readback, or null when the lifecycle is merged>",
      "landed_verification": "<required merged source/check/diff readback, or null>"
    }
  }
}
```

The skill obtains that result from fresh canonical branch/PR/head/base/repository/review/thread,
focused-check, diff, independent validation, note, and selected Project-status reads. It also supplies
the separate `lifecycle` read from that same refill; saved controller lifecycle state is compatibility
state, never a substitute for this required current evidence. Before restoring `delivered`, the helper
revalidates the retained delivery and reconciles that fresh lifecycle. An open prerequisite must still
identify the verified delivery head and current approved base; a ready PR is not a reason to redispatch
or reset its draft state. A merged prerequisite must identify the canonical landing target and landed
revision, with bounded task-relevant source/check evidence; its original head need not remain an
ancestor after a squash or rebase merge. A closed-unmerged PR, missing/partial evidence, wrong landing
target, or known reverted behavior remains unresolved. A merged prerequisite does not require its
source branch to exist locally, whether deleted or remote-only; the verified merge, landed diff
identity, unchanged landed content in the candidate base, and containment are the evidence.
Later changes to that content need fresh independent validation rather than trusting the old
landing's checks. The historical delivery checkpoint is never rewritten to look like a current
open readback.

Every prerequisite is rechecked in dependency order. Missing, stale, or contradictory evidence
preserves ownership and blocks only that task and its descendants; it never redispatches a
duplicate or releases descendants. A delivered task whose current lifecycle is unresolved stays
delivered with its lifecycle error, so a later human merge can release the same graph without
reconstructing scope.

## State, reservations, and joins

State is one explicit private session-local controller file, not a provider or retained-artifact ledger.
It carries `version`, the immutable `fingerprint`, exact `scope_identity`, the optional normalized
`scope_evidence` receipt, a random controller owner token, stop/halt flags, last recovery inventory,
and one task entry per admitted executable issue. The receipt and its meaningful tracker context let
initial and recovery admission describe the same selected tracker honestly. A revision-only change,
reference reordering, or declared-to-native transition for the same exact task set does not replace
task identities or release duplicate work. Each task entry keeps its native identity,
dependency/claim provenance, contract revision, worker identity, reservation/worktree/branch/parent
start, current source/diff identity, checks/validator receipts, observed CI identities/revisions,
diagnosis, repair-attempt history with ownership, PR identity, delivery checkpoint, next safe
action, and first uncertain boundary distinct. GitHub remains the source for issue and CI facts;
the controller stores only the observation identities needed to resume safely. The caller must
externally enforce exclusive ownership of the selected canonical scope/state for the controller
session, covering every `schedule`, `record-worker`, `apply-result`, `observe-checks`,
`reconcile`, and `resume` call. If exclusive ownership cannot be proved, block
at controller preflight before invoking the helper.

A task whose landed, verified delivery is already contained in the approved base is `satisfied`
with that evidence and needs no worker of its own: it takes no new reservation, claim, or writer,
and its historical reservation, delivery checkpoint, and claims stay exactly as they were
recorded. A refill that no longer proves that availability returns it to `pending`.

Uncertain historical evidence never invents a worker. A task whose retained delivery cannot be
revalidated is blocked with its evidence reason and holds no capacity, because a read-only
historical import never launched a writer; a genuine unknown writer — a live host session, a
recorded native writer, or an unproved reservation — still occupies its slot. `resume` is the only
explicit way to clear a user stop, and it releases only those import-only uncertainties whose fresh
evidence proves landed delivery, host liveness shows no writer, and no competing owner holds the
task claim; everything else stays `unknown` with its reservation, boundary, and last evidence intact.
No manual checkpoint edit, claim deletion, or synthetic stop receipt is part of that recovery.

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
apply-result, observe-checks, reconcile, resume, or stop names an existing state and matching
admission. An admission retained from before the landed-prerequisite cutover is accepted as
written: its scope, plan identity, and receipts are never rewritten, and only a state that was
stopped when it was persisted may cross that boundary. Missing state, malformed JSON,
state/fingerprint/scope mismatch, missing durable checkpoint head, or a state task set that differs
from the admission blocks; never silently reinitialize. The initial state is published before the
scope claim is acquired, and the claim becomes visible only after its complete owner-bearing record
is durable. A first-schedule interruption therefore leaves resumable owner-bearing state with either
no claim or one complete same-owner claim. Keep the state path private and use the helper's atomic
`--state-out` replace.

Under that exclusive ownership, the helper persists the actual selected task branch, absolute
workspace, parent branch, and parent SHA before host dispatch. The branch and workspace are runtime
facts, not stable task-ID projections or required publication fields. Repairs reuse the exact
original reservation and retained PR; when the checkout was legitimately released, reopen an
isolated worktree on the same verified branch only after reconciling ownership and retained
changes, never by recreating around a collision or from a hard-coded path. Before reuse, compare
canonical physical paths (including aliases and ancestor/descendant paths), repository identity,
current branch/HEAD, and complete Git worktree inventory. A suitable existing worktree may be
retained; an incompatible or unclaimed branch/workspace blocks, and unknown missing workspace
state is not permission to recreate. The helper reservation does not itself create Git state.
After launch, checkpoint the [native writer identity](validation.md#record-the-native-writer)
separately from the worker's delivery report. Missing or uncorrelated native identity keeps unknown
work reserved; no stopped receipt may substitute a foreign session or previous repair attempt. On
resume, refresh the selected PRs, checks, actual worktrees, workers, and branch heads before
deciding what remains; reconcile unknown pushes or reruns before replaying them. An old check
failure or lost repair-worker response must not create duplicate commits, workers, or PRs, and
external head/base changes require reconciliation rather than silently overwriting another
contributor's work.

Technical prerequisites and the model-selected execution order remain separate evidence. The
execution layout is a single-parent forest selected before branch/worktree allocation; its optional
parents add compatibility ordering only and never add, remove, or rewrite technical edges. Every
technical prerequisite must be on the selected execution ancestor path. The helper persists the
normalized layout and its fingerprint in state, binds that plan to each worker packet, and uses
effective prerequisites (technical prerequisites plus the selected execution parent, minus
prerequisites already landed in the approved base) for scheduling,
readiness, repair propagation, and resume while preserving technical `prerequisites` and provenance.
Equivalent reordered input resumes the same plan; a changed plan returns `execution-plan-drift`.

Roots use the admitted integration branch/SHA. For a dependent, the selected execution parent is
preferred when its verified open branch contains every current prerequisite revision; otherwise the
approved integration branch is considered when the selected parent has landed. A candidate is usable
only when its actual local tip is the recorded candidate SHA and `git merge-base --is-ancestor` proves
that it contains every current prerequisite revision. Dependency count alone never forces a merge
checkpoint, and ordinary joins do not require a new parent or integration decision.
Dispatch readiness also requires every effective prerequisite's verified delivery and persisted
note; an independently unsatisfied gate pauses exactly that dependent while unrelated ready work
continues.

If no candidate is suitable, the helper leaves the task pending with `waiting-for-merge` only when
the selected layout explicitly carries the `merge-checkpoint` fallback. The record includes the
fallback reason, prerequisite PRs and current states, intended integration branch, and release
condition. This human-merge checkpoint is for divergent work, fixed-parent or independent-landing
constraints, or no safe suitable stack—not the default strategy. It does not reserve a worker or
create a speculative branch/worktree. An explicit parent decision is consulted only for a material
ambiguity or an explicitly selected suitable existing parent; it is evidence to validate, never proof
by name alone. Never create a synthetic base, combine independent branches, rewrite either graph, or
require an automatic merge.

## Helper status meanings

The helper writes machine-readable JSON and exits zero for controlled workflow statuses such as
`no-work`, `snapshot-drift`, `halted`, `stopped`, and per-task `unknown`; it exits one with
`{"ok":false,"error":...}` for blocked input. The skill must inspect the status and retain output,
not treat process exit zero as delivery. `schedule` output includes dispatch entries, delivered,
satisfied, active, unknown, evidence-pending, repair-ready, pending, and paused/blocked/waiting IDs
with exact next actions.
`record-worker`, `apply-result`, `observe-checks`, `reconcile`, `resume`, and `stop` outputs are
authoritative state transitions; `resume` reports `released` and `retained_unknown`; never invent a
success response around them. A user stop prevents new dispatch but does not declare active workers
stopped or discard their worktrees.
