---
tier: standard
---

# Subagent execution driver

The **subagent** driver of [`woostack-execute`](../SKILL.md). Use it when `--subagent` is explicit or
when the smart default detects a host spawn capability. The
[controller](controller.md) has already bound, assigned, accepted, dependency-checked, and isolated
exactly one Linear issue. The verified authority envelope selects one of two routes:

- **Engineer pair:** the isolated paired coder implements and self-checks; its decision-maker
  performs the ordered task-scoped spec review then quality review directly.
- **Generic non-paired execution:** a fresh implementer is followed by a dispatched
  spec-compliance reviewer and then a dispatched quality reviewer.

The generic route remains available when no engineer pair is bound. Neither route grants this
driver lifecycle, acceptance, or source-control authority.

## One-issue dispatch envelope

Every dispatched paired coder, generic implementer, or generic reviewer brief is self-contained and
names exactly one selected issue. The controller fills the relevant prompt template and adds the
same immutable authority envelope:

- exact issue UUID/URL, stable resource UUID, identifier, role, canonical repository, and exact
  project UUID/URL for role `increment` or explicit no-project proof for role `work-item`;
- current issue contract revision/hash, the one bounded task, allowed file/surface responsibility,
  acceptance clause, verification commands, and changed-path smoke test;
- verified type-aware owner kind/principal, stable engineer name/run ID, current
  `assignmentAccepted` event/read-back, and the controller's fresh pre-dispatch ownership receipt;
- exact worktree path, disposable registry key, branch, frozen-base or declared-parent identity,
  and dependency proof; and
- the authority prohibitions below.

The task text comes only from that verified issue contract. The packet must be complete, current,
self-consistent, and scoped to exactly one issue; otherwise do not dispatch.

**Self-contained skill guard.** Every fenced brief must say that it is self-contained and that the
worker must never load or follow `skill://woostack-review`, the `woostack-review` `SKILL.md`, or
`using-woostack` routing. Those paths invoke the PR-review orchestrator, not this one-issue worker
loop. A fresh subagent inherits repository instructions but follows only the explicit issue brief
for this work. The controller repeats the one-issue authority barriers in the dispatched text; a
link to this file alone is insufficient because a fresh worker does not inherit controller history.

## Route selection and role separation

Resolve the route from the controller's verified envelope before the first task. A complete
engineer unit is one stable engineer identity, current type-aware Linear principal, decision-maker
profile/session, and separately isolated coding profile/session under the shared
[engineer-agent authority protocol](../../using-woostack/references/engineer-agents.md). That
complete binding selects the engineer-pair route. A partial, stale, shared, or inferred pairing
blocks; it must not degrade into generic execution. An envelope that deliberately declares
non-paired execution retains the generic subagent route.

On the engineer-pair route, only the paired coding profile implements, runs verification and smoke
commands, and self-checks its task diff. The decision-maker independently inspects that diff and the
reported command evidence, performs both ordered reviews, and authors the review receipts, but
never modifies implementation/test bytes, runs implementation or test commands, or applies a fix.
The paired coder is never a spec, quality, or PR reviewer and its self-check is not independent
review evidence.

## Coding-worker authority barriers

An implementation worker may analyze and edit only its one task inside the selected issue's
existing contract, run the stated checks, smoke the changed path, self-check, and return evidence.
On the engineer-pair route this worker is the paired coder; on the generic route it is the fresh
implementer. It must not:

- edit the issue description, scope, acceptance criteria, priority, dependencies, Git parent,
  assignment/delegation, or another issue;
- append project updates, change project phase/status, clear a gate, decide a cross-issue or
  product-contract question, or allocate/reassign work;
- append/mutate Linear events, relations, lifecycle, or PR state except the exact three
  commit-owned operations named by the bounded handoff below; accept its own evidence;
  request/write terminal `done`; or review its own work as independent evidence; or
- commit, push, submit, or create/update a PR unless the paired coder receives the single bounded
  post-review source-control handoff below; merge, force-push, and restack are never delegated.

Dispatched generic reviewers and any independent reviewers permitted by an explicit
`/woostack-review` invocation have the same mutation prohibitions and inspect only the reported diff
identity. A worker encountering contract drift, an owner/receipt mismatch, unsafe ancestry, a
registry/worktree collision, or an out-of-authority question returns `BLOCKED` or `NEEDS_CONTEXT`;
it never repairs remote authority or broadens the task.

## Sequencing

Tasks within the selected issue run **sequentially** in the controller's one worktree.
Implementation workers are never dispatched in parallel against that shared tree. There is no
per-task commit: each worker leaves its bounded changes uncommitted and reports exact changed paths
plus diff identity. After all tasks and typed evidence verify, the controller invokes one
`woostack-commit` for the issue itself or, only on the engineer-pair route, gives its paired coder
the exact bounded post-review source-control handoff below.

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

1. **Dispatch implementation.** On the engineer-pair route, dispatch the isolated paired coder. On
   the generic non-paired route, dispatch one fresh implementer. Both use
   [../prompts/implementer.md](../prompts/implementer.md), the complete one-issue envelope, exact
   worktree pin, and only the context this task needs. Route the effective implementation tier
   through [Tier selection](#tier-selection) and
   [Dispatch model](#dispatch-model-resolve--map--pass). The worker follows Red → Green → Refactor,
   exact verification, changed-path smoke testing, and self-check; it reports status, changed paths,
   diff identity, commands/results, observations, and concerns. A paired coder's self-check is
   implementation evidence only, never a review receipt.
2. **Classify status:**
   - `DONE` — continue to spec review.
   - `DONE_WITH_CONCERNS` — resolve correctness or scope concerns before review; observations may be
     retained in evidence.
   - `NEEDS_CONTEXT` — if the answer stays inside the existing issue contract, the issue
     decision-maker records the verified decision then redispatches; otherwise return a
     `decisionRequest` to the lead/dispatcher and stop.
   - `BLOCKED` — supply genuinely missing in-contract context, split only within the issue's already
     approved task structure, or stop for the controller's verified blocker/failure path. A `fast`
     implementation worker blocked specifically on reasoning may retry once at `standard`; a
     `standard` implementation worker never retries at `deep`.
3. **Perform task-scoped spec review.**
   - **Engineer pair:** the decision-maker directly reviews the reported task diff against the
     issue contract and authors the spec-review receipt. It does not dispatch a separate reviewer.
   - **Generic non-paired execution:** dispatch a spec-compliance reviewer with
     [../prompts/spec-reviewer.md](../prompts/spec-reviewer.md), the same exact issue envelope, and
     only the implementation worker's reported task diff identity.
   If either route finds a gap, the same paired coder or generic implementer fixes it after a fresh
   owner/registry recheck; repeat the same route's spec review until compliant or blocked.
4. **Perform task-scoped quality review only after spec compliance passes.**
   - **Engineer pair:** the decision-maker directly reviews the same current task diff and authors
     the quality-review receipt. It does not dispatch a separate reviewer.
   - **Generic non-paired execution:** dispatch a quality reviewer with
     [../prompts/quality-reviewer.md](../prompts/quality-reviewer.md), scoped to that same current
     diff identity.
   Resolve every Important finding through the same implementation worker, recompute the diff
   identity, and repeat the same route's ordered spec-then-quality reviews until quality-clean or
   blocked.
5. **Produce evidence, not progress mutation.** For an engineer pair, the decision-maker authors
   the two ordered task review receipts from its direct spec and quality reviews. For generic
   non-paired execution, the two dispatched reviewers return those receipts. Each receipt binds the
   reviewer identity, review type, `PASS` verdict, and same current byte-safe uncommitted diff hash.
   Return the exact task packet and ordered receipts to
   [controller.md §7](controller.md#7-typed-evidence-cadence). Implementation and review workers do
   not record Linear evidence or lifecycle mutations.

A blocked review remains blocked. Do not invoke the full PR-review orchestrator, silently retry
unchanged routing, ask another worker to accept the implementation, or mark the task complete from
a self-report.

### Explicit review-command exception

Engineer-pair task review never delegates by default. Only an explicit user invocation of
`/woostack-review` permits the decision-maker to delegate review analysis to configured independent
reviewer profiles. Those reviewers use fresh isolated sessions, receive neither engineer
profile's credential, token, environment, MCP/browser context, or session, and return advisory
analysis only. The paired coder is never eligible. The decision-maker validates every receipt and
retains any review comment/verdict authority; delegated analysis does not replace this execute
loop's ordered pre-commit receipts or transfer Linear mutation, acceptance, or terminal authority.

## Model tiers

Use the shared `fast | standard | deep` vocabulary in
[`../../using-woostack/references/model-tiers.md`](../../using-woostack/references/model-tiers.md).
Prompt frontmatter supplies role defaults for dispatched workers: implementation `fast`, generic
spec-reviewer `standard`, and generic quality-reviewer `deep`. The engineer-pair decision-maker
performs review directly, so no reviewer model dispatch or tier applies on that route. Resolve each
dispatched worker's role and task; authority never changes with tier.

### Tier selection

| Adjust | Effective tier | When |
|---|---|---|
| **Implementation escalate** | `standard` | The task touches security / auth / crypto, data migrations, concurrency / locking, money / billing, or is cross-cutting / architectural; the issue task contract is highly ambiguous inside its permitted boundary; or a `fast` attempt returned **BLOCKED** specifically because it needs more reasoning. |
| **Implementation ceiling** | never `deep` | `standard` is the implementation maximum. If it remains blocked, provide verified in-contract context, split only along existing issue task boundaries, or send a `decisionRequest` to the responsible issue engineer/lead. |
| **Generic reviewer downgrade** | `fast` / `standard` | On non-paired execution only: spec-reviewer → `fast` on a trivial diff; quality-reviewer → `standard` on a trivial diff; otherwise keep the prompt default. |
| **No escalation signal** | `fast` | Favor the implementer default; use `standard` only when a signal above establishes the need. |

### Dispatch model (resolve → map → pass)

Before each dispatch, resolve the task's effective tier, then apply the current host's routing class.
First, load `skills/using-woostack/references/hosts/<current-host>.md`; no matching file -> treat the host as having no per-call routing and say so (degraded). Use the matched host spawn primitive, model/effort/cwd knobs, and routing posture.
On a host consuming repository model configuration, resolve the tier through the shared provider table and configured overrides. On a host with
host-owned role routing, choose its fixed role-backed worker and let the host own the concrete
model. Do not read repository model leaves in that case.

When explicit per-call model routing exists, every dispatch passes the resolved values; omission
would silently inherit the parent model. Host-owned role routing is non-degraded. If neither route
exists, use the session model and state that tier routing is degraded. A host-owned temporary
fallback after a usage-limit error remains host recovery, but it cannot relax the one-issue brief,
ownership receipt, or authority barriers.

## Review and handback

The ordered spec-then-quality loops are the driver's task-scoped pre-commit review. The engineer-pair
decision-maker performs them directly; the generic non-paired route dispatches the two reviewers.
Neither route runs `woostack-review`. An explicit `/woostack-review` is the sole independent-reviewer
delegation exception described above and remains a separate PR-review command.

After all task diffs and receipts agree, the current engineer-pair decision-maker—or the current
responsible controller on generic non-paired execution—authors canonical `precommitReview` with the
two ordered `PASS` receipt records, sorted changed paths, and the same independently validated
byte-safe uncommitted diff hash, then reads the event back under
[controller.md §7](controller.md#7-typed-evidence-cadence). These receipts never constitute
post-PR `reviewResult` or terminal `acceptance`.

### Controller-authorized source-control handoff

This is the sole exception to the paired coder's source-control prohibition; generic non-paired
execution keeps its existing controller-owned `woostack-commit` path. Only after the decision-maker
has directly completed every task-scoped spec review then quality review, independently validated
the required pre-commit receipts, authored and read back canonical `precommitReview`, and freshly
rechecked the exact issue, type-aware owner, assignment, relations, worktree, branch, parent, and
reviewed diff may it authorize its paired coder to run one bounded `woostack-commit` source-control
action for that exact issue/worktree/branch.

The paired coder uses only its own isolated implementation Git/Graphite/GitHub credentials and its
own separately isolated official Linear MCP authentication context. In canonical `woostack-commit`
order it may commit, append and independently read back the exact commit-scoped
`implementationEvidence`, push and submit or update that issue's PR, create or refresh and read
back that exact native Linear PR relation, and, for initial submission only, transition `executing`
to `inReview` once and read it back. A later update independently confirms that the issue remains
`inReview`; it cannot replay the transition. The coder then returns all native Git, GitHub, and
Linear receipts for the decision-maker's independent read-back.

The action grants no second implementation pass, merge, force-push, restack, acceptance, other
Linear event/relation/lifecycle or project/issue mutation, feature-project transition, gate
mutation, contract or relation change, allocation, or cross-issue authority. Failure or an unknown
outcome stops with preserved evidence; a retry requires another fresh controller authorization and
complete recheck.

When every task has verified Red → Green → Refactor, exact verification/smoke evidence, spec
compliance, and quality-clean status, hand one complete issue-scoped evidence packet with the two
ordered review receipts, sorted changed paths, and reviewed precommit diff hash to the controller.
Outside the single paired-coder source-control handoff, the driver never commits, pushes, submits,
updates a PR, or mutates Linear. It never merges, mutates project authority, or marks `done`; the
handoff itself has only the exact commit-owned issue evidence, PR-relation, and initial `inReview`
permissions above.
Acceptance remains exclusively with the freshly verified responsible authority. Acceptance by
the paired coder, a decision-maker merely acting as reviewer, a generic implementer, or any
review worker is prohibited.
