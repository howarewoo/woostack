---
name: woostack-fix
description: Use to resolve small technical issues (bugs, hotfixes, refactors) through a unified execution loop — diagnose root cause with woostack-debug, author a fix plan under .woostack/fixes/, harden and commit it for review, get explicit user approval, then delegate execution to woostack-execute (TDD per task, task review, commit via woostack-commit, distill).
---

# woostack-fix

## Overview

Drives a bug fix or a small technical change from diagnosis to implementation through a lightweight, unified loop. Fixes are smaller than features and combine the spec and the plan into a single markdown file under `.woostack/fixes/`. The fix loop owns diagnosis, the fix plan, hardening, a pre-approval plan commit, and the approval gate, then **delegates the execution mechanics to [`woostack-execute`](../woostack-execute/SKILL.md)** — the same engine the build loop uses — passing the fix file as the plan. Fix does not re-inline a TDD/commit/distill loop of its own. Because a fix is small, its plan and code ship on **one branch / one PR**: the hardened fix plan is committed first for review, and `woostack-execute` later commits the checked-off plan updates and code onto the same single `fix/<slug>` branch.

```
diagnose root cause (woostack-debug) → write fix plan (fixes/ markdown) → harden fix plan
  → commit hardened plan for review → approve-to-execute (GATE)
  → execute via woostack-execute in the fix/<slug> worktree
  (TDD per task → tick → commit code + plan updates via woostack-commit → task review → distill)
  ⇒ one branch / one PR (plan commit + code commit(s) on fix/<slug>)
```

The skill has exactly **one** hard gate: **approve-to-execute**. The hardened fix plan is committed before the gate so the user can inspect the committed diff, branch, or PR without opening the worktree; no code is written until approval clears. Because a fix is small enough that this is appropriate, the plan and the code still ship as a **single PR** on the one `fix/<slug>` branch — there is no separate docs-only base PR and no stacked code increment. Delegation adds no gate: `woostack-execute` owns no approval gate and never merges, so the fix's one gate stays upstream of execution.

## Completion invariant

A successful `woostack-fix` run is not complete when implementation or tests pass.
**Do not final-answer after implementation or tests.** After approved execution succeeds, the
orchestrator must complete closeout before handing back:

- the single fix PR is submitted or updated;
- the fix file frontmatter is `status: in-review`;
- that lifecycle update is committed and submitted on the same `fix/<slug>` branch;
- the fix worktree is removed; and
- the final response includes the PR URL and verification summary.

If commit, submit, review, or teardown cannot complete, leave the worktree in place and report the
blocker plus the worktree path. Do not treat closeout as optional cleanup for the user to request.

## Debug investigation mode

Step 1's root-cause investigation runs through one of two drivers — the same `--inline` /
`--subagent` selection [`woostack-execute`](../woostack-execute/SKILL.md#execution-mode) uses
for its implement step; only *what* is delegated differs (here the read-only debug
investigation, not implementation). Pass the flag on the fix invocation; the flags are mutually
exclusive and an explicit flag always wins.

- **inline** — the fix orchestrator runs `/woostack-debug` itself, in this session (today's
  behavior).
- **subagent** — dispatch a fresh `general-purpose` investigator subagent that runs the
  `woostack-debug` four-phase analysis and returns **only** its Phase 4 handback (root-cause
  summary + proposed minimal fix + TDD context). All the heavy investigation material — reading
  errors, `git diff`, data-flow tracing — stays in the subagent, keeping the orchestrator
  context small.

**Smart default (no flag): subagent where the host can spawn** a subagent (an `Agent`/`Task`
tool is available), else inline — the same rule `woostack-execute` uses. If `--subagent` is
requested but the host cannot spawn, fall back to inline (degraded — say so) or stop and ask;
never pretend subagent mode ran.

Passing both `--inline` and `--subagent` is an error: stop and ask which one to use.

**The debug subagent is read-only and needs no worktree and no cwd-pin.** `woostack-debug`
never writes code, commits, or `.woostack/` artifacts, so the investigator — unlike
`woostack-execute`'s implementer subagent, which must self-pin to its worktree (see the
[worktree contract](../woostack-init/references/worktrees.md)) — pins to nothing. Step 1 also
runs **before** the fix worktree is created (step 2), so there is nothing to pin to.

**No root cause found.** In **inline** mode, `woostack-debug` stops and asks the user for hints,
as today. In **subagent** mode the subagent cannot prompt mid-run, so it
returns a **blocked status plus what it investigated**, and the orchestrator surfaces that to the
user (mirroring `woostack-execute`'s BLOCKED escalation) — never guess a fix plan from a failed
investigation.

## Procedure

1. **Diagnose the root cause.**
   Run the systematic-debugging skill to find the root cause before proposing any code edits,
   through the selected driver — inline, or a read-only subagent (see
   [Debug investigation mode](#debug-investigation-mode)).
   ```
   /woostack-debug <target>   # inline, or dispatched to a read-only investigator subagent
   ```
   It runs its four-phase root-cause analysis automatically — investigating the symptoms, tracing data flow backward, identifying the root cause — and hands back the Phase 4 result: the root-cause summary, the proposed minimal fix, and the TDD context (the failing-test description). Carry the proposed fix forward into the fix plan's Proposed Fix section below. If it cannot find a root cause, do not guess: inline, stop and ask the user for hints; in subagent mode the investigator returns a blocked status plus what it investigated, which you surface to the user (see [Debug investigation mode](#debug-investigation-mode)).

2. **Write the fix plan as markdown.**
   **First create the fix worktree** (the first write of this run, per the [worktree contract](../woostack-init/references/worktrees.md)): with the chosen `fix/<slug>` branch, `git worktree add -b fix/<slug> "$WOOSTACK_ROOT/.woostack/worktrees/fix-<slug>" "$(bash <wi>/resolve-base.sh)"`, run `gt track --parent "$(bash <wi>/resolve-base.sh)"` from inside that worktree, and run **steps 2–5 with cwd = that worktree** — the fix markdown, the harden edits, and (via `woostack-execute` in step 5) the TDD code all author into the **one** worktree on `fix/<slug>`, never the primary tree. (On abandon at the approval gate, `git worktree remove --force` it and delete the branch.)
   Create a markdown file under `.woostack/fixes/YYYY-MM-DD-<slug>.md`, using the current date and a short slug based on the target (e.g. `.woostack/fixes/2026-06-08-status-parsing.md`).
   
   The file must follow this structure:
   ```markdown
   ---
   type: fix
   status: draft
   branch: fix/<target-slug>
   ---

   # Fix: <Short description of the bug/symptom>

   ## 1. Root Cause
   *Summarize the findings from woostack-debug. Where does the bad value originate? What is the evidence?*

   ## 2. Proposed Fix
   *Describe the minimal, targeted code changes to resolve the root cause.*

   ## 3. Implementation Plan
   - [ ] **Step 1: Reproduce with a failing test**
     - Add test case verifying...
   - [ ] **Step 2: Apply the minimal fix**
     - Implement...
   - [ ] **Step 3: Verification**
     - Run verification command...
   ```
   Set the frontmatter `status: draft` and set the `branch:` to the branch name you will use.

3. **Harden and commit the fix plan.**
   Invoke [`woostack-harden`](../woostack-harden/SKILL.md) on the fix plan file. Resolve open questions one at a time and refine the implementation steps in place. Once hardening produces no new questions, set the frontmatter `status: hardened`.
   Then commit the hardened fix file on the existing `fix/<slug>` branch before asking for
   execution approval. Prefer Graphite from inside the fix worktree:
   ```bash
   gt modify -m "docs: add <slug> fix plan"
   ```
   If the branch has no commit yet and Graphite requires branch creation plus commit in one flow,
   use the equivalent `gt create`/`gt modify` path that preserves the already-created
   `fix/<slug>` branch and its tracked parent. Fall back to
   `git commit -m "docs: add <slug> fix plan"` only when Graphite is unavailable. If normal
   Graphite flow opens or updates the PR while submitting the branch, that PR is the same eventual
   fix PR, initially containing only the plan; it is not a separate docs-only base PR.

4. **Approve to execute (GATE).**
   With the plan hardened and committed, **always present it and get explicit approval before
   executing** — the skill's single hard gate. Point the user at the committed fix-file path, the
   reviewable commit (and PR URL if one was submitted), summarize the root cause and the proposed
   fix, and wait for a clear yes. The plan and the code ship in **one PR**, so there is no separate
   docs-only base PR here — the gate guards the codebase by approving the committed plan *before*
   any code is written.
   - **Go** → set the fix file's frontmatter `status: approved` (still in the worktree). The fix
     worktree **stays alive** — step 5's `woostack-execute` runs **inside it**, on the same
     `fix/<slug>` branch, and commits the approved/executing lifecycle update, checked-off plan,
     and code into the one PR.
   - **Revise** → amend the fix plan in the still-alive fix worktree, commit the revised hardened
     plan on the same `fix/<slug>` branch, and re-present at the gate.
   - **Abandon** → `git worktree remove --force` the fix worktree and delete the `fix/<slug>`
     branch; no PR was opened and no code was written.
   Never execute on inferred or assumed approval; silence is not a yes.

5. **Execute via [`woostack-execute`](../woostack-execute/SKILL.md).**
   Set the fix file's frontmatter `status: executing`, then hand the fix file to the execute
   engine — the fix file *is* the plan, and its `## 3. Implementation Plan` is the single
   increment:
   ```
   /woostack-execute .woostack/fixes/YYYY-MM-DD-<slug>.md --inline
   ```
   Execute runs **in the existing fix worktree on the `fix/<slug>` branch** that step 2 created:
   it **verifies and reuses** that branch and worktree (the
   [`woostack-execute`](../woostack-execute/SKILL.md) "when a caller like `woostack-fix` already
   made it, verify" path) rather than cutting a fresh worktree or a child branch. It implements
   each task TDD-first (failing test → minimal fix → verify) per the
   [woostack-tdd kernel](../woostack-tdd/SKILL.md), ticks the fix file's checkboxes in place, then
   commits via [`woostack-commit`](../woostack-commit/SKILL.md) — which commits the whole worktree,
   the `.woostack/fixes/` lifecycle/checklist updates **and** the code, onto `fix/<slug>` and opens
   or updates **one PR** — and
   runs the task-scoped spec-compliance and code-quality review, then distills durable learnings
   into `.woostack/memory/`.
   A fix is one increment / one PR, so default to **`--inline`** for this lightweight loop;
   use `--subagent` only for a larger fix. When distilling, make sure the increment captures the
   root-cause **gotcha** learned in step 1 — the debugging insight is a fix's most reusable
   takeaway. `woostack-execute` owns no approval gate and never merges; the fix's one gate
   (step 4) stays upstream.

6. **Submit PR, Mark In Review, And Tear Down Worktree.**
   This closeout commit is separate from the execution commit: `woostack-execute`
   commits code, checklist, and execution lifecycle updates through
   `woostack-commit`; after that succeeds, `woostack-fix` commits only the final
   `status: in-review` lifecycle update to the same PR before teardown.
   Do not stop after implementation, tests, or the code commit. This closeout is part of the
   successful fix loop, not optional cleanup for a later user request.
   There is **no separate post-execution commit step** — step 3 already committed the hardened plan
   for review, and step 5's `woostack-execute` committed the code plus fix-file lifecycle/checklist
   updates and opened or updated the **one PR** via
   [`woostack-commit`](../woostack-commit/SKILL.md), then ran the task review and distill. Once the PR is open, update the fix file's
   frontmatter to `status: in-review` (once merged, `status: done`). The fix file's frontmatter `status:` is the
   source of truth for the fix lifecycle — fixes are tracked by their `.woostack/fixes/` file, not
   the spec-centric `/woostack-status` board, and `woostack-execute` ticks the fix file's
   checkboxes but does not touch its frontmatter, so the lifecycle transition stays with this
   skill. `woostack-commit` writes a `Spec: .woostack/fixes/<file>.md` trailer on the fix PR
   (mirroring the `Spec: .woostack/specs/<file>.md` trailer it writes for spec increments), but
   that trailer attaches the PR to the fix file rather than to a spec — the fix file's frontmatter
   remains the lifecycle source of truth.

   Tear down the **single** fix worktree after the one PR is open/updated and the `status:
   in-review` lifecycle update is committed and submitted; the branch/commits/PR persist. **Leave
   the worktree in place on failure** and report its path. The memory distill (run by
   `woostack-execute` in step 5) writes tracked `.woostack/memory/` notes and the rebuilt
   `MEMORY.md` **inside the fix worktree**, so they **ride the fix commit** into the one PR — the
   durable learning is **committed with the fix**, not stranded in the primary tree. Only the
   gitignored sidecars (`metrics.json`, `.telemetry.tsv`, the dream watermark) target the primary
   tree via the `WOOSTACK_ROOT` export of the
   [worktree contract](../woostack-init/references/worktrees.md) §5 and survive teardown.

## Hard constraints

- **No guess-and-check.** Always run `woostack-debug` to trace the data flow and confirm the root cause before writing the fix plan.
- **Debug driver.** Step 1's investigation runs inline or via a read-only `general-purpose` subagent (`--inline`/`--subagent`, smart default = subagent where the host can spawn, else inline); the subagent returns only `woostack-debug`'s Phase 4 handback and needs no worktree. See [Debug investigation mode](#debug-investigation-mode).
- **One combined markdown file under `.woostack/fixes/`.** Fixes are specified and planned in a single file under `.woostack/fixes/` (not `.woostack/specs/` or `.woostack/plans/`).
- **Wait for explicit approval.** Never execute a fix plan on inferred or assumed approval. Silence is not a yes.
- **Commit the plan before approval.** After hardening, commit the `.woostack/fixes/` markdown on
  the `fix/<slug>` branch before asking for execute approval, so the user can review the plan as a
  committed artifact instead of opening the worktree. Revisions at the gate must be committed
  before re-presenting.
- **One PR.** The fix plan and the code ship in a **single PR** on the one `fix/<slug>` branch — first as a plan commit for review, then with code and fix-file lifecycle/checklist updates added by `woostack-execute`. There is no separate docs-only base PR; a fix is one PR, because a fix is small enough that this is appropriate.
- **One worktree across the whole run.** A single `fix/<slug>` worktree spans the run: created in step 2, kept alive across the approve-to-execute gate (so revise/abandon stay cheap — during the gate it is torn down only on **Abandon**, via `git worktree remove --force`), then **reused** by `woostack-execute` for the code increment — execute does not cut a fresh worktree or a child branch, and tears the worktree down on **Go** after the one PR is open.
- **Delegate execution.** Step 5 hands the fix file to [`woostack-execute`](../woostack-execute/SKILL.md); never re-inline a TDD/commit/review/distill loop. Execute runs inside the step-2 fix worktree on `fix/<slug>` and owns the branch, TDD per task, checkbox ticking, commit via `woostack-commit` (code + plan updates into the one PR), task review, and distill. This skill retains only diagnosis, the fix plan, hardening, the pre-approval plan commit, the approval gate, and the frontmatter lifecycle.
- **Closeout is mandatory.** After approved execution succeeds, do not final-answer until the single PR is submitted or updated, the fix frontmatter is `status: in-review`, the lifecycle update is committed and submitted, and the fix worktree is removed. If any closeout step fails, leave the worktree in place and report the blocker plus path.
- **Closeout handback.** The final response must include the PR URL and verification summary. A failed closeout must report both the blocker and the fix worktree path.
- **TDD Kernel.** Every fix is driven by a failing test first — enforced by `woostack-execute`'s per-task TDD loop.
- **Never merge.** Execution (via `woostack-execute`) commits and opens or updates the single fix PR; this skill never merges.
