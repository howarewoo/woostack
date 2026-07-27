---
tier: standard
---

# Subagent execution driver

The **subagent** driver of [`woostack-execute`](../SKILL.md). Use it when `--subagent` is explicit or
when the smart default detects a host spawn capability. The
[controller](controller.md) has already bound, assigned, accepted, dependency-checked, and isolated
exactly one Linear issue. This driver coordinates a fresh implementer per ordered task, then a
spec-compliance reviewer followed by a quality reviewer. It never acquires lifecycle or source-
control authority.

## One-issue dispatch envelope

Every implementer and reviewer brief is self-contained and names exactly one selected issue. The
controller fills the relevant prompt template and adds the same immutable authority envelope:

- exact issue UUID/URL, stable resource UUID, identifier, role, canonical repository, and exact
  project UUID/URL for role `increment` or explicit no-project proof for role `work-item`;
- current issue contract revision/hash, the one bounded task, allowed file/surface responsibility,
  acceptance clause, verification commands, and changed-path smoke test;
- verified type-aware owner kind/principal, stable engineer name/run ID, current
  `assignmentAccepted` event/read-back, and the controller's fresh pre-dispatch ownership receipt;
- exact worktree path, disposable registry key, branch, frozen-base or declared-parent identity,
  and dependency proof; and
- the authority prohibitions below.

The task text comes only from that verified issue contract. Never supply a local specification,
plan, checkbox/progress snapshot, registry entry, branch name, title, chat summary, or mutation
response as development authority. If the packet is incomplete, stale, contradictory, or names
more than one issue, do not dispatch.

**Self-contained skill guard.** Every fenced brief must say that it is self-contained and that the
worker must never load or follow `skill://woostack-review`, the `woostack-review` `SKILL.md`, or
`using-woostack` routing. Those paths invoke the PR-review orchestrator, not this one-issue worker
loop. A fresh subagent inherits repository instructions but follows only the explicit issue brief
for this work. The controller repeats the one-issue authority barriers in the dispatched text; a
link to this file alone is insufficient because a fresh worker does not inherit controller history.

## Coding-worker authority barriers

An implementer may analyze and edit only its one task inside the selected issue's existing contract,
run the stated checks, smoke the changed path, self-review, and return evidence. It must not:

- edit the issue description, scope, acceptance criteria, priority, dependencies, Git parent,
  assignment/delegation, or another issue;
- append project updates, change project phase/status, clear a gate, decide a cross-issue or
  product-contract question, or allocate/reassign work;
- append/mutate Linear events, relations, or lifecycle; attach/request a PR state; accept its own
  evidence; or request/write terminal `done`; or
- commit, push, submit, create/update a PR, merge, force-push, or restack.

Reviewers have the same mutation prohibitions and inspect only the reported task diff identity. A
worker encountering contract drift, an owner/receipt mismatch, unsafe ancestry, a registry/worktree
collision, or an out-of-authority question returns `BLOCKED` or `NEEDS_CONTEXT`; it never repairs
remote authority or broadens the task.

## Sequencing

Tasks within the selected issue run **sequentially** in the controller's one worktree. Implementers
are never dispatched in parallel against that shared tree. There is no per-task commit: each worker
leaves its bounded changes uncommitted and reports exact changed paths plus diff identity. After all
tasks and typed evidence verify, the controller invokes one `woostack-commit` for the issue.

Project-level parallelism is separate. Distinct controllers may work on verified dependency-
independent issues only under distinct owners/runs, registry keys, branches/worktrees, PRs, and
non-overlapping exclusive responsibility. A worker still receives one issue and knows nothing that
would authorize mutation of another track.

## Worktree placement

Every write happens in the selected issue worktree `$wt`, never the primary checkout. Apply both
placement layers whenever the host supports them:

- **Dispatch pin (always):** fill the implementer prompt's worktree placeholder with the exact `$wt`.
  Its first action enters `$wt` and asserts path-normalized `git rev-parse --show-toplevel` equals
  it before any write. A mismatch returns `BLOCKED` with both paths.
- **Per-call cwd (when available):** set the spawn call's cwd to `$wt` as a second guard.

A host isolation flag that creates a fresh throwaway worktree is not equivalent; it would bypass the
controller's exact Linear-ID registry claim, Graphite parent, and issue branch. If the worker cannot
perform the path assertion, it also cannot run the issue's verification reliably; fall back to
inline mode and report the degradation.

The controller independently rechecks the exact issue, current assignment event, type-aware owner,
project membership/relations, and registry claim immediately before each implementer dispatch and
each fix redispatch. Any drift invalidates the brief before edits.

## Per-task implementation loop

For each ordered task in the selected issue:

1. **Dispatch one implementer** with
   [../prompts/implementer.md](../prompts/implementer.md), the complete one-issue envelope, exact
   worktree pin, and only the context this task needs. Route its effective tier through
   [Tier selection](#tier-selection) and [Dispatch model](#dispatch-model-resolve--map--pass). It
   follows Red → Green → Refactor, exact verification, changed-path smoke testing, and self-review;
   it reports status, changed paths, diff identity, commands/results, observations, and concerns.
2. **Classify status:**
   - `DONE` — retain the task packet and continue to the next ordered task.
   - `DONE_WITH_CONCERNS` — resolve correctness or scope concerns before continuing; observations
     may be retained in evidence.
   - `NEEDS_CONTEXT` — if the answer stays inside the existing issue contract, the issue engineer
     records a verified `decisionRequest`/`decisionResponse` pair then redispatches; otherwise
     return a `decisionRequest` to the lead/dispatcher and stop until its canonical response.
   - `BLOCKED` — supply genuinely missing in-contract context, split only within the issue's already
     approved task structure, or stop for the controller's verified blocker/failure path. A `fast`
     implementer blocked specifically on reasoning may retry once at `standard`; a `standard`
     implementer never retries at `deep`.
3. **Retain evidence, not progress mutation.** Keep the exact task packet for the issue-wide review
   below. Implementers do not edit issue text, tick checkboxes, append local receipts, or mutate
   Linear.

After every ordered task reports a valid retained packet, independently compute the complete
issue-wide uncommitted diff, its sorted changed paths, and byte-safe hash:

1. Dispatch the spec-compliance reviewer with
   [../prompts/spec-reviewer.md](../prompts/spec-reviewer.md), the complete issue contract and task
   set, the complete diff, its hash, and the reviewer's authenticated kind/ID. If it finds a gap,
   recheck owner/registry authority, send the affected work back to the responsible implementer,
   recompute the complete diff, and review the whole issue again.
2. Only after spec compliance passes, dispatch the quality reviewer with
   [../prompts/quality-reviewer.md](../prompts/quality-reviewer.md) against that same complete diff
   identity and authenticated reviewer kind/ID. Resolve every Important finding, then recompute and
   rerun spec review before quality review so both final receipts bind identical bytes.
3. Require exactly two final ordered receipts, spec then quality. Each contains exactly
   `reviewType`, `reviewerKind`, `reviewerId`, `reviewedDiffHash`, and `verdict`; the identities
   equal the independently authenticated reviewers, both hashes equal the current complete diff,
   and both verdicts are literal `PASS`. Any missing field, stale hash, reviewer mismatch, non-PASS
   verdict, or changed diff is blocked.

A blocked reviewer result remains blocked. Do not invoke the full PR-review orchestrator, silently
retry unchanged routing, ask another worker to accept the implementation, or mark the issue
complete from task packets.

## Model tiers

Use the shared `fast | standard | deep` vocabulary in
[`../../using-woostack/references/model-tiers.md`](../../using-woostack/references/model-tiers.md).
Prompt frontmatter supplies role defaults: implementer `fast`, spec-reviewer `standard`,
quality-reviewer `deep`. Resolve per role and task; the worker's authority never changes with tier.

### Tier selection

| Adjust | Effective tier | When |
|---|---|---|
| **Implementation escalate** | `standard` | The task touches security / auth / crypto, data migrations, concurrency / locking, money / billing, or is cross-cutting / architectural; the issue task contract is highly ambiguous inside its permitted boundary; or a `fast` attempt returned **BLOCKED** specifically because it needs more reasoning. |
| **Implementation ceiling** | never `deep` | `standard` is the implementation maximum. If it remains blocked, provide verified in-contract context, split only along existing issue task boundaries, or send a `decisionRequest` to the responsible issue engineer/lead. |
| **Reviewer downgrade** | `fast` / `standard` | spec-reviewer → `fast` on a trivial diff; quality-reviewer → `standard` on a trivial diff; otherwise keep the prompt default. |
| **No escalation signal** | `fast` | Favor the implementer default; use `standard` only when a signal above establishes the need. |

### Dispatch model (resolve → map → pass)

Before each dispatch, resolve the task's effective tier, then apply the current host's routing class.
Load `skills/using-woostack/references/hosts/<current-host>.md` for the host spawn primitive,
model/effort/cwd knobs, and routing posture. On a host consuming repository model configuration,
resolve the tier through the shared provider table and configured overrides. On a host with
host-owned role routing, choose its fixed role-backed worker and let the host own the concrete
model. Do not read repository model leaves in that case.

When explicit per-call model routing exists, every dispatch passes the resolved values; omission
would silently inherit the parent model. Host-owned role routing is non-degraded. If neither route
exists, use the session model and state that tier routing is degraded. A host-owned temporary
fallback after a usage-limit error remains host recovery, but it cannot relax the one-issue brief,
ownership receipt, or authority barriers.

## Review and handback

The spec then quality loops are the driver's issue-wide automated review. They do not run
`woostack-review`; independent human/decision-maker PR review and responsible acceptance remain
separate. Each reviewer returns a controller-validatable receipt that binds its reviewer identity,
review type, literal `PASS` verdict, and the same byte-safe complete uncommitted issue diff hash.
Those receipts support canonical `precommitReview`, never post-PR `reviewResult` or terminal
`acceptance`.

When every task has verified Red → Green → Refactor and exact verification/smoke evidence, and the
complete issue diff has final spec-compliant and quality-clean receipts, hand one issue-scoped
evidence packet with the two ordered review receipts, sorted changed paths, and reviewed precommit
diff hash to the controller. The driver never commits, pushes, submits, merges, mutates
project/issue authority, or marks `inReview`/`done`.
