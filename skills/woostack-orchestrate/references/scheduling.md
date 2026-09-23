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

Resolve host capability before provider access. The selected host must expose a real
delivery-capable subagent primitive. Record `delivery_capable: true` and its observed positive
`max_parallel` in the snapshot. A smaller host cap is a scheduling clamp, not a scope-admission
failure; absence of a delivery primitive blocks before `admit` rather than degrading to inline
implementation. Host mechanics and tier routing remain in the allowlisted host references.

Resolve the canonical Git repository and admitted integration branch/SHA from direct Git and an
authorized GitHub capability exposed by the host (prefer native GitHub tools when suitable;
host-authenticated `gh` remains supported). Discover actual operation capabilities and read shapes
from the host. Use the native issue, sub-issue, parent, dependency, Project membership, and Project
field reads described by the [GitHub provider profile](../../woostack-init/references/artifact-providers/github.md).
Exhaust every page (`--paginate` or the equivalent native pagination operation), then independently
read each endpoint needed for identity, hierarchy, contracts, dependencies, checks, PRs, notes, or
Project status. A missing/failed page is incomplete evidence, not an empty collection. The
`pagination` booleans below are controller attestations written only after those native terminal
reads succeed; they are not permission to skip a page or to claim a read that did not happen.

Normalize native records without losing identity forms:

- canonical issue URL and number for display/Commit association;
- positive numeric REST `id` and non-empty GraphQL `node_id` for native API operations;
- `state: "open"` and `resource: "issue"` for admitted task issues;
- complete title and body;
- actual native parent, read independently from the child (an error is not `parent: null`);
- complete contract and native blocked-by relations; and
- complete existing delivery evidence, when present.

Do not substitute an issue number for a REST ID, a GraphQL node ID, or a canonical URL. A body line
such as `Parent: #N` is not hierarchy evidence. Native parentage, dependency edges, Git ancestry,
and Project membership are separate facts.

## Snapshot schema

Every value that is not a fixed schema literal is a runtime-substituted fact from completed
native/Git reads; the markers below are not fabricated evidence.

```json
{
  "canonical_repo": "<runtime-substituted canonical repository>",
  "integration": {
    "branch": "<runtime-substituted integration branch>",
    "sha": "<runtime-substituted admitted integration SHA>"
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
  "repository_rules": "<runtime-substituted complete repository rules>",
  "specification": "<runtime-substituted complete approved specification when parent or Project mode is selected>",
  "host": {
    "delivery_capable": true,
    "max_parallel": "<runtime-substituted positive host capability>"
  },
  "pagination": {
    "sub_issues": true,
    "issues": true,
    "parents": true,
    "dependencies": true,
    "contracts": true
  },
  "recovery": {
    "checkpoints": ["<runtime-substituted controller/worker checkpoint evidence>"],
    "processes": ["<runtime-substituted worker process liveness evidence>"],
    "sessions": ["<runtime-substituted host session liveness evidence>"],
    "worktrees": ["<runtime-substituted canonical Git worktree inventory>"],
    "refs": ["<runtime-substituted branch/ref and dirty-state evidence>"],
    "prs": ["<runtime-substituted canonical PR evidence>"],
    "contracts": ["<runtime-substituted admitted contract revisions>"],
    "dependencies": ["<runtime-substituted hierarchy/dependency pagination evidence>"]
  }
}
```

Every admission snapshot and every fresh schedule refill MUST carry a complete `recovery` inventory
object: every listed family is present and terminally read. An incomplete inventory is unknown
evidence and blocks admission/scheduling; it is never treated as an empty collection. A host that
cannot expose a family records the inability in its direct recovery evidence rather than fabricating
a clean result.
`repository_rules` and `specification` are complete strings from the admitted repository/scope;
they are not summaries. List mode uses each selected issue body or explicit `specification` field
as worker context and does not require an aggregate `specification`. Every boolean in `pagination`
must correspond to a terminal native read. Issue-mode snapshots require all four existing keys;
Project-mode snapshots require `members`, `parents`, `dependencies`, and `contracts`; list-mode
snapshots require `issues`, `parents`, `dependencies`, and `contracts`. All required keys must be
`true`.

`parent_prs` supplies fresh canonical PR discovery for the integration branch and any explicitly
selected non-predecessor parent. An empty `prs` array means fully proved absence, not unavailable
access. Otherwise supply one exact PR record with `pr_url`, `repo`, `head_repo`, `branch`,
`head_sha`, `base_branch`, current `state` (`open`, `closed`, or `merged`), and fully paginated
current-head `reviews`/`threads` in the [validation readback shape](validation.md#result-schema).
Ambiguous or incomplete discovery blocks selection. Predecessor parents use their fresh complete
delivery checkpoint instead. Current tips may advance for an already-reserved child only while its
original start remains an ancestor; do not replace that child's retained start SHA.

### Parent-issue snapshot

Add these fields:

```json
{
  "parent": {
    "url": "<runtime-substituted canonical parent issue URL>",
    "id": "<runtime-substituted positive native REST issue ID>",
    "node_id": "<runtime-substituted opaque GraphQL issue node ID>",
    "state": "open",
    "resource": "issue",
    "parent": null,
    "title": "<runtime-substituted native parent title>",
    "body": "<runtime-substituted complete native parent body>"
  },
  "expected_index": ["<runtime-substituted stable task ID>"],
  "children": [
    {
      "task_id": "<runtime-substituted stable task ID>",
      "ordinal": "<runtime-substituted positive ordinal>",
      "url": "<runtime-substituted canonical child issue URL>",
      "id": "<runtime-substituted positive native REST issue ID>",
      "node_id": "<runtime-substituted opaque GraphQL issue node ID>",
      "state": "open",
      "resource": "issue",
      "actual_parent": "<runtime-substituted canonical parent issue URL>",
      "nested_children": false,
      "prerequisites": ["<runtime-substituted admitted prerequisite task ID>"],
      "external_prerequisites": ["<runtime-substituted external prerequisite URL>"],
      "contract": {
        "goal": "<runtime-substituted string>",
        "scope": ["<runtime-substituted allowed path or bounded surface>"],
        "non_goals": ["<runtime-substituted string>"],
        "acceptance": ["<runtime-substituted observable criterion>"],
        "checks": ["<runtime-substituted exact required command>"],
        "smoke": "<runtime-substituted real changed-path smoke scenario>",
        "decisions": "<runtime-substituted implementation decisions>",
        "risks": "<runtime-substituted known risks and mitigations>"
      }
    }
  ]
}
```

`parent` must be an open top-level issue (`parent: null`). Every direct child must be in the
canonical repository, open, a native issue, and have `actual_parent` exactly equal to the selected
parent URL. `nested_children: true` blocks as unsupported scope; never flatten it. `expected_index`
comes from the complete parent specification and every named child must be present in the fully
paginated native child read. Runtime `workspace`/`branch` values are optional fresh allocation
evidence, never required issue-contract fields or immutable scope identity.

Add a complete native Project record and complete member issue records:

```json
{
  "project": {
    "url": "<runtime-substituted canonical Project URL>",
    "number": "<runtime-substituted positive Project number matching /projects/N>",
    "node_id": "<runtime-substituted opaque GraphQL Project node ID>",
    "owner": "<runtime-substituted Project owner>",
    "owner_type": "<runtime-substituted organization or user>",
    "state": "open"
  },
  "lifecycle": {
    "planned": "<runtime-substituted unique configured option>",
    "executing": "<runtime-substituted unique configured option>",
    "inReview": "<runtime-substituted unique configured option>",
    "done": "<runtime-substituted unique configured option>",
    "blocked": "<runtime-substituted unique configured option>"
  },
  "members": [
    {
      "task_id": "<runtime-substituted stable task ID>",
      "ordinal": "<runtime-substituted positive ordinal>",
      "url": "<runtime-substituted canonical member issue URL>",
      "id": "<runtime-substituted positive native REST issue ID>",
      "node_id": "<runtime-substituted opaque GraphQL issue node ID>",
      "item_id": "<runtime-substituted non-empty native Project item ID bound during admission>",
      "state": "open",
      "resource": "issue",
      "title": "<runtime-substituted native title>",
      "body": "<runtime-substituted complete native body>",
      "actual_parent": null,
      "declared_parent": null,
      "nested_children": false,
      "prerequisites": [],
      "external_prerequisites": [],
      "contract": {
        "goal": "<runtime-substituted string>",
        "scope": ["<runtime-substituted allowed path or bounded surface>"],
        "non_goals": ["<runtime-substituted string>"],
        "acceptance": ["<runtime-substituted observable criterion>"],
        "checks": ["<runtime-substituted exact required command>"],
        "smoke": "<runtime-substituted real changed-path smoke scenario>",
        "decisions": "<runtime-substituted implementation decisions>",
        "risks": "<runtime-substituted known risks and mitigations>"
      }
    }
  ]
}
```
The Project owner type is exactly `organization` or `user`; the Project and all member issues are
open and canonical. Read Project membership and native parents independently. Every member
carries a non-empty native `item_id` bound during admission; missing or empty `item_id` blocks as
`invalid-project-item`, and distinct members sharing an item ID block as `duplicate-identity`.
Each member's `declared_parent` must equal its independently
read `actual_parent` (either `null` or a canonical issue URL). Containers may omit `contract`
only when the native member record is otherwise complete; containers are preserved but excluded
from execution. Do not import nonmembers, flatten nested containers, or infer a parent from
Project position. Repeated evidence for one URL is deduplicated only when every immutable field,
including `item_id`, agrees; any disagreement blocks as ambiguous identity.

### Explicit issue-list snapshot

List mode uses `--issues` and carries no aggregate specification parent or Project record:

```json
{
  "issues": [
    {
      "url": "<canonical selected issue URL>",
      "id": "<positive native REST ID>",
      "node_id": "<opaque GraphQL issue node ID>",
      "state": "open",
      "resource": "issue",
      "title": "<complete native title>",
      "body": "<complete native body>",
      "actual_parent": "<independently read canonical parent URL or null>",
      "nested_children": false,
      "task_id": "<stable Git-safe ID, optional when issue number can derive issue-N>",
      "ordinal": "<stable positive tie-break ordinal, optional>",
      "prerequisites": ["<selected task ID or canonical external issue URL>"],
      "external_prerequisites": ["<canonical issue URL outside this explicit list>"],
      "contract": {
        "goal": "<string>",
        "scope": ["<contained path>"],
        "non_goals": ["<string>"],
        "acceptance": ["<observable criterion>"],
        "checks": ["<exact command>"],
        "smoke": "<real changed-path scenario>",
        "decisions": "<string>",
        "risks": "<string>"
      }
    }
  ],
  "graph": {
    "coverage": "complete",
    "model_inference": "complete",
    "source": "skill",
    "complete": true,
    "edges": [
      {
        "predecessor": "<task ID>",
        "dependent": "<task ID>",
        "provenance": "native|declared|inferred",
        "evidence": "<non-empty native read, declaration, or model rationale>"
      }
    ]
  }
}
```

The caller must read exactly the selected issue set and set terminal `pagination.issues`,
`pagination.parents`, `pagination.dependencies`, and `pagination.contracts` only after those reads
complete. Every selected issue must include both `prerequisites` and
`external_prerequisites`, including explicit empty arrays for a verified empty dependency read.
Repeated selectors and repeated native evidence for one canonical URL are deduplicated
only when immutable identity, body, parent, contract, and dependency evidence agree. The helper
sorts normalized selectors and task identities before computing the fingerprint, so reordering the
same explicit set is equivalent.

List admission requires the graph to carry explicit successful terminal receipts:
`graph.coverage: "complete"`, `graph.model_inference: "complete"`, and `graph.complete: true`.
Missing, failed, unknown, or other non-terminal values block admission even when the supplied
edge list is empty; an empty edge list is valid only with those receipts. Model inference is
required to complete even when no edge is ultimately inferred. The helper never performs model
inference or native reads.

`graph.edges` may also be supplied as top-level `edges`, `dependency_edges`, or
`edge_provenance`; the helper normalizes all accepted forms to the schema above and rejects
duplicate endpoint pairs, missing evidence, unknown selected endpoints, self-dependencies, and
cycles. When a task's documented `prerequisites` repeats an annotated graph edge, the graph
record remains authoritative and its provenance/evidence is retained; conflicting explicit edge
records still block as contradictory evidence. Native, declared, and inferred edges are distinct
evidence classes. An external prerequisite stays on the affected task's blocker list and is never
imported into the admitted task set.

## Invoking the bridge

Assemble the complete snapshot above from actual native/Git reads, serialize it with a JSON writer,
and use the [canonical CLI sequence](../SKILL.md#one-real-helper-path). The examples describe
runtime fields, not fixtures to submit unchanged. Keep snapshot, admission, result, and state files
private (`umask 077`). Only `schedule` without `--state` initializes the state; every later call uses
the existing state and newly assembled `--fresh` evidence. Follow the
[completion-driven refill loop](../SKILL.md#continuously-refill-on-completion), not batch barriers.

## Fingerprints and fresh refills

Admission computes a `fingerprint` as `sha256:` plus the SHA-256 of canonical JSON (sorted keys,
compact separators) over the immutable scope view. It binds:

- mode and exact selector, or the normalized sorted explicit issue URL set in list mode;
- canonical repository;
- native parent or Project identity and the parent specification identity/body binding, or every
  selected issue identity/body binding in list mode;
- complete `specification` (when required) and `repository_rules`;
- every immutable child/member/list-issue field: task ID, ordinal, URL, native IDs (including
  Project `item_id`), state/resource, title/body, actual and declared parent, nested flag,
  full contract, and prerequisite/external prerequisite sets. Runtime workspace and branch
  evidence are excluded; and
- effective graph edges and their provenance/evidence, plus Project lifecycle identity/configuration
  when Project mode is selected.

It deliberately excludes host capability/cap, integration branch SHA, fresh `parent_prs`, and
runtime reservation/delivery evidence. These mutable facts are checked separately: changing the
admitted integration SHA requires readmission. A changed immutable scope returns `snapshot-drift`;
preserve all running reservations and launch no fresh worker. The skill must re-read native state
and assemble `--fresh` for **every** refill, including immediately after a worker result and after
a reconciliation.

Every fresh refill also carries the completed recovery inventory described above: checkpoint/state
identities, worker processes/sessions, Git worktrees/refs/dirty state, canonical PRs, contract
revisions, and native hierarchy/dependency pagination. Missing or incomplete native pages are
unknown, never an empty child set. The helper records the inventory as recovery evidence; it never
 treats a worker assertion, selector, branch name, or prior success sentence as ownership.

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

State is one explicit private session-local controller file, not a provider ledger. It carries
`version`, the immutable `fingerprint`, exact `scope_identity`, a random controller owner token,
stop/halt flags, last recovery inventory, and one task entry per admitted child. Each task entry
keeps its native membership/dependency and contract revisions, claim provenance, worker identity,
reservation/worktree/branch/parent start, current source/diff identity, checks/validator receipts,
PR identity, delivery checkpoint, and first uncertain boundary distinct. The caller must still
externally enforce exclusive ownership of the selected canonical scope/state for the controller
session.

The helper additionally takes owner-only atomic claims under
`<primary-root>/.woostack/tmp/orchestrate-claims/`: one exact scope claim and one claim keyed by
the canonical repository plus canonical child issue URL (with native REST/GraphQL IDs retained in
the claim record). A second controller selecting a parent
issue and a Project that overlap on a child therefore blocks before reservation; a stale or
unreadable claim is a blocker, never permission to take over. Existing active issue/PR/checkpoint
evidence without the current owner claim is likewise a blocker. Claims remain retained as recovery
evidence until explicit human cleanup; they are not a scheduler/database or a replacement for the
owner-only checkpoint contract.
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
The first schedule omits `--state` and creates state. Every later schedule, apply-result,
reconcile, or stop names an existing state and matching admission. Missing state, malformed JSON,
state/fingerprint/scope mismatch, missing durable checkpoint head, or a state task set that differs
from the admission blocks; never silently reinitialize. Keep the state path private and use the
helper's atomic `--state-out` replace.

Under that exclusive ownership, the helper persists the actual selected task branch, absolute
workspace, parent branch, and parent SHA before host dispatch. The branch and workspace are runtime
facts, not stable task-ID projections or required publication fields. Repairs reuse the exact
original reservation and retained PR. Before reuse, compare canonical physical paths (including
aliases and ancestor/descendant paths), repository identity, current branch/HEAD, and complete Git
worktree inventory. A suitable existing worktree may be retained; an incompatible or unclaimed
branch/workspace blocks. The helper reservation does not itself create Git state.

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
`apply-result`, `reconcile`, and `stop` outputs are authoritative state transitions; never invent a
success response around them. A user stop prevents new dispatch but does not declare active workers
stopped or discard their worktrees.
