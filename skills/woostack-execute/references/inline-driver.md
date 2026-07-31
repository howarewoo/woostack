# Isolated inline execution driver

Use this driver when the active coding profile performs one approved bounded task in one isolated
worktree. The controller has already admitted the contract, dependencies, run identity, and
worktree. Inline means same host workflow, not shared authority: the coding profile never becomes
the controller, reviewer of its own work, or acceptance authority.

Artifact-free execution is the default. Optional Linear artifact IDs may appear as read-only context
only when explicitly selected; the driver makes no Linear call or mutation.

## Input envelope

Require:

- stable task and run IDs;
- complete approved task contract and revision/hash;
- canonical repository and exact worktree path;
- allowed paths/exclusive responsibility surface;
- base/Graphite parent and dependency evidence;
- acceptance, verification, and smoke clauses;
- current diff identity; and
- explicit prohibitions on scope, source-control, PR, and artifact mutation.

Missing, stale, partial, or contradictory input returns `BLOCKED` before editing.

## Loop

For each ordered step in the task contract:

1. **Recheck before edit.** Confirm the task/run identity, worktree claim, branch/parent, allowed
   surface, and current diff. Stop on drift or collision.
2. **Red.** Follow the [woostack-tdd kernel](../../woostack-tdd/SKILL.md). For new observable
   behavior, first run the smallest meaningful test/reproduction and observe the intended failure.
   A compile or fixture failure unrelated to the contract is not a valid Red.
3. **Green.** Make the smallest production change that satisfies the contract. No unrelated cleanup,
   speculative abstraction, or scope expansion.
4. **Refactor.** Simplify without changing behavior. Re-run the focused check after refactoring.
5. **Verify.** Run the changed-path smoke scenario and nearest relevant existing checks. Record exact
   commands, exit/results, and observations. Never fabricate or generalize coverage.
6. **Specification review.** The decision-maker reviews the complete task diff against
   [../prompts/spec-reviewer.md](../prompts/spec-reviewer.md). Resolve every in-contract gap through
   the same coding profile after a fresh recheck.
7. **Quality review.** The decision-maker reviews the same diff with
   [../prompts/quality-reviewer.md](../prompts/quality-reviewer.md). Resolve confirmed findings,
   re-run affected checks, and repeat until PASS or blocked.

The driver may inspect and edit only its worktree surface and run implementation checks. It never
creates/edits plans, task contracts, approval gates, allocation, artifact metadata, another
worktree, commits, pushes, Graphite submissions, PRs, reviews, merges, or acceptance state.

## Questions and failures

Return `NEEDS_CONTEXT` with the exact missing decision when progress would require changing the
contract, dependency, allowed path, parent/base, acceptance, or verification requirement. Return
`BLOCKED` for collision, unsafe instruction, irreproducible required behavior, failing invariant,
or unavailable required capability. Preserve the worktree and identify the first unverified
boundary; never create a workaround outside scope.

## Evidence return

After every step reaches verified Red → Green → Refactor and the complete diff passes specification
and quality review, return one packet to [controller.md §7](controller.md#7-evidence-cadence):

- stable task/run identity;
- worktree, branch, base/parent, and diff identity;
- sorted changed paths and concise diff summary;
- commands and observed results;
- smoke observations;
- specification and quality reviewer identities/verdicts;
- blockers or decisions requested; and
- status `PASS`, `NEEDS_CONTEXT`, or `BLOCKED`.

Do not claim commit, PR, artifact, or delivery success. The controller owns those boundaries.
