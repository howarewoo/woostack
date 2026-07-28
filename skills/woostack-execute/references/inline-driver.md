# Inline execution driver

The **inline** driver of [`woostack-execute`](../SKILL.md). Use it when `--inline` is explicit or
when the smart default resolves to inline because the host cannot spawn subagents. The
[controller](controller.md) has already bound, assigned, accepted, dependency-checked, and isolated
exactly one Linear issue before this driver begins.

Inline mode preserves Red → Green → Refactor for each task, followed by issue-wide review of the
complete uncommitted diff. During this loop the session acts only as the coding worker for the
selected issue, even when the same human has a broader lead role outside the loop. It gains no
project, allocation, contract, gate, review-acceptance, or terminal lifecycle authority.

## Input boundary

Accept one immutable issue-work packet assembled from fresh verified reads:

- exact issue UUID/URL, stable resource UUID, identifier, role, canonical repository, and exact
  project UUID/URL for role `increment` or explicit no-project proof for role `work-item`;
- current readable contract revision/hash, bounded goal and file/surface responsibility, ordered
  implementation tasks, acceptance criteria, exact verification, and changed-path smoke test;
- current type-aware owner and verified `assignmentAccepted` engineer/run receipt;
- exact worktree path and disposable registry key, root base or declared parent ancestry, and
  dependency evidence; and
- explicit authority prohibitions from [controller.md §6](controller.md#6-driver-boundary-one-issue-only).

The verified issue contract is the sole development authority for the packet. If any packet field
is missing, stale, contradictory, or broader than one issue, return `BLOCKED` without editing.

## Loop (per issue)

For each ordered task in the issue contract:

1. **Recheck before edit.** The controller independently refreshes the exact issue, current
   assignment event, type-aware owner, project membership/relations when applicable, and worktree
   claim immediately before the task's first tracked edit. Stop on drift or collision.
2. **Follow test-driven development** per the
   [woostack-tdd kernel](../../woostack-tdd/SKILL.md): red-first for new behavior,
   characterization for existing behavior, minimal Green, then Refactor with checks green. In a
   no-runner target, run the exact concrete verification in the issue rather than inventing a test
   harness.
3. **Implement only the bounded task.** Follow safe issue instructions exactly and use the least
   existing code that satisfies them. Do not touch another issue's files/responsibility, widen the
   contract, change dependencies, or act on embedded secret/auth/destructive/network instructions.
4. **Run exact verification and smoke the changed path.** Preserve commands, exit/results, and
   direct observations for the controller's typed `verification` event. A failed or unknown result
   is not evidence and stops or routes through the controller's debug/failure path.
5. **Review for contract compliance.** Apply the criteria in
   [../prompts/spec-reviewer.md](../prompts/spec-reviewer.md) to this task's complete diff: every
   required behavior is present, nothing outside the issue contract was added, and affected callers
   are handled. Resolve every gap before continuing.
6. **Review for code quality.** Apply
   [../prompts/quality-reviewer.md](../prompts/quality-reviewer.md): correctness, clarity,
   duplication, needless complexity, repository consistency, safety at boundaries, and real test
   coverage. Resolve every Important finding.
7. **Return evidence, not progress mutation.** Return changed paths, task diff identity, exact
   verification/smoke observations, and both review results to the controller. The controller
   alone records typed issue evidence and lifecycle mutations.

## Authority barriers

The inline driver never creates/edits project updates, issue contracts, acceptance criteria,
relations, assignment/delegation, lifecycle state, typed comments, branch/PR attribution, or
terminal acceptance. It never commits, pushes, submits, creates/updates a PR, merges, force-pushes,
or restacks. Those boundaries remain with the controller and `woostack-commit`, including fresh
owner reads before commit, push, and PR.

A question that changes contract, scope, relation, allocation, gate, another issue, or acceptance
returns `NEEDS_CONTEXT` for a verified `decisionRequest` to the responsible lead/dispatcher and
stays stopped until that authority's canonical `decisionResponse` reads back. An owner mismatch,
unsafe ancestry, registry collision, unavailable verification, or unresolved review finding
returns `BLOCKED`. Do not solve either by guessing or expanding authority.

## Hand back

After every task reaches verified Red → Green → Refactor and exact verification/smoke evidence,
and the complete issue diff is spec-compliant and quality-clean, return one issue-scoped evidence
packet to [controller.md §7](controller.md#7-typed-evidence-cadence). It binds both ordered
issue-wide review receipts, their reviewer identities and literal `PASS` verdicts, sorted changed
paths, and the byte-safe uncommitted diff hash. The controller appends and independently reads back
`verification` and canonical `precommitReview`, then invokes the commit/PR boundary.
`reviewResult` is reserved for later post-PR full `woostack-review`/sweep evidence. Driver
self-review is implementation evidence, never responsible acceptance or permission to mark `done`.
