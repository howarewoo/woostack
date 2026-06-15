---
name: woostack-fix
description: Use to resolve small technical issues (bugs, hotfixes, refactors) through a unified execution loop — diagnose root cause with woostack-debug, author a fix plan under .woostack/fixes/, harden, get explicit user approval, then delegate execution to woostack-execute (TDD per task, task review, commit via woostack-commit, distill).
---

# woostack-fix

## Overview

Drives a bug fix or a small technical change from diagnosis to implementation through a lightweight, unified loop. Fixes are smaller than features and combine the spec and the plan into a single markdown file under `.woostack/fixes/`. The fix loop owns diagnosis, the fix plan, hardening, and the approval gate, then **delegates the execution mechanics to [`woostack-execute`](../woostack-execute/SKILL.md)** — the same engine the build loop uses — passing the fix file as the plan. Fix does not re-inline a TDD/commit/distill loop of its own.

```
diagnose root cause (woostack-debug) → write fix plan (fixes/ markdown) → harden fix plan
  → commit fix plan as a docs-only PR (stack base, via woostack-commit)
  → approve-to-execute (GATE) → execute via woostack-execute
  (fresh code-increment worktree off fix/<slug> tip → TDD per task → tick
   → commit via woostack-commit → task review → distill)
```

The skill has exactly **one** hard gate: **approve-to-execute**. The fix plan is first committed as a docs-only PR (the stack base) and *then* presented for approval — build-style (mirroring [`woostack-build`](../woostack-build/SKILL.md) steps 7-8), so the approved plan is a committed, reviewable artifact and the code increment stacks on top. The gate still protects the codebase: no implementation happens until it clears, and a fix is therefore **two PRs (docs base + code increment)**. Delegation adds no gate: `woostack-execute` owns no approval gate and never merges, so the fix's one gate stays upstream of execution.

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
   **First create the fix worktree** (the first write of this run, per the [worktree contract](../woostack-init/references/worktrees.md)): with the chosen `fix/<slug>` branch, `git worktree add -b fix/<slug> "$WOOSTACK_ROOT/.woostack/worktrees/fix-<slug>" "$(bash <wi>/resolve-base.sh)"`, run `gt track --parent "$(bash <wi>/resolve-base.sh)"` from inside that worktree, and run **steps 2–6 with cwd = that worktree** — the fix markdown, the harden edits, and (via `woostack-execute` in step 5) the TDD code all author into it, never the primary tree. (On abandon at the approval gate, `git worktree remove --force` it and delete the branch.)
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

3. **Harden the fix plan.**
   Invoke [`woostack-harden`](../woostack-harden/SKILL.md) on the fix plan file. Resolve open questions one at a time and refine the implementation steps in place. Once hardening produces no new questions, set the frontmatter `status: hardened`.

4. **Commit the fix plan as a docs-only PR (stack base), then approve to execute (GATE).**
   First, **commit the fix plan**: with it hardened, commit via
   [`woostack-commit`](../woostack-commit/SKILL.md) on the `fix/<slug>` branch from inside the
   fix worktree — a **docs-only PR** carrying only the `.woostack/fixes/` markdown, no code; the
   **stack base** (mirroring [`woostack-build`](../woostack-build/SKILL.md) step 7). Leave the
   frontmatter at `status: hardened` — the lifecycle advances only at the gate.

   Then the gate — **Approve to execute (GATE)**: **always present the committed fix-plan PR and
   get explicit approval before executing** (the skill's single hard gate, build step-8 style).
   Point the user at the PR and the fix-file path and wait for a clear yes:
   - **Go** → set `status: approved`, then **commit that bump** on the `fix/<slug>` branch via [`woostack-commit`](../woostack-commit/SKILL.md) `--no-pr-update` so the `approved` state **persists to the `fix/<slug>` tip** (not lost with the worktree). The fix worktree **stays alive across the gate** and is **torn down only on Go** — once the bump is committed (leaving a clean tree), tear it down (`git worktree remove "$WOOSTACK_ROOT/.woostack/worktrees/fix-<slug>"`), then step 5's `woostack-execute` **cuts a fresh code-increment worktree** off the `fix/<slug>` tip, which now carries `status: approved`.
   - **Revise** → amend the fix plan in the still-alive fix worktree, re-push the docs PR, and re-present at the gate.
   - **Abandon** → close the docs PR, `git worktree remove --force` the fix worktree, and delete the `fix/<slug>` branch; no code was implemented.
   Never execute on inferred or assumed approval; silence is not a yes.

5. **Execute via [`woostack-execute`](../woostack-execute/SKILL.md).**
   Set the fix file's frontmatter `status: executing`, then hand the fix file to the execute
   engine — the fix file *is* the plan, and its `## 3. Implementation Plan` is the single
   increment:
   ```
   /woostack-execute .woostack/fixes/YYYY-MM-DD-<slug>.md --inline
   ```
   `woostack-execute` owns the execution cadence so the fix inherits the same discipline as a
   build increment: the fix worktree from step 2 holds only the committed plan as the docs-PR
   stack base; the code increment runs in the fresh worktree execute cut off the `fix/<slug>` tip
   at the Go transition (step 4), not the step-2 fix-plan worktree, and execute then
   implements each task TDD-first (failing test → minimal fix → verify) per the
   [woostack-tdd kernel](../woostack-tdd/SKILL.md), tick the fix file's checkboxes in place,
   commit via [`woostack-commit`](../woostack-commit/SKILL.md), run the task-scoped
   spec-compliance and code-quality review, and distill durable learnings into `.woostack/memory/`.
   A fix is one increment / one PR, so default to **`--inline`** for this lightweight loop;
   use `--subagent` only for a larger fix. When distilling, make sure the increment captures the
   root-cause **gotcha** learned in step 1 — the debugging insight is a fix's most reusable
   takeaway. `woostack-execute` owns no approval gate and never merges; the fix's one gate
   (step 4) stays upstream.

6. **Track the PR and lifecycle.**
   There is **no separate commit step** — `woostack-execute` already committed the increment and
   opened its PR via [`woostack-commit`](../woostack-commit/SKILL.md) in step 5, and already ran
   the task review and distill. Once the PR is open, update the fix file's frontmatter to
   `status: in-review` (once merged, `status: done`). The fix file's frontmatter `status:` is the
   source of truth for the fix lifecycle — fixes are tracked by their `.woostack/fixes/` file, not
   the spec-centric `/woostack-status` board, and `woostack-execute` ticks the fix file's
   checkboxes but does not touch its frontmatter, so the lifecycle transition stays with this
   skill. `woostack-commit` writes a `Spec: .woostack/fixes/<file>.md` trailer on the fix PR
   (mirroring the `Spec: .woostack/specs/<file>.md` trailer it writes for spec increments), but
   that trailer attaches the PR to the fix file rather than to a spec — the fix file's frontmatter
   remains the lifecycle source of truth.

   The fix-plan worktree was already torn down at the **Go** transition (step 4); the
   code-increment worktree `woostack-execute` cut is torn down by execute after the code PR is
   open. The branches/commits/PRs persist. **Leave a worktree on failure** and report its path. The memory distill (run by `woostack-execute`
   in step 5) targets the primary tree via the `WOOSTACK_ROOT` export of the [worktree
   contract](../woostack-init/references/worktrees.md) §5, so it survives teardown.

## Hard constraints

- **No guess-and-check.** Always run `woostack-debug` to trace the data flow and confirm the root cause before writing the fix plan.
- **Debug driver.** Step 1's investigation runs inline or via a read-only `general-purpose` subagent (`--inline`/`--subagent`, smart default = subagent where the host can spawn, else inline); the subagent returns only `woostack-debug`'s Phase 4 handback and needs no worktree. See [Debug investigation mode](#debug-investigation-mode).
- **One combined markdown file under `.woostack/fixes/`.** Fixes are specified and planned in a single file under `.woostack/fixes/` (not `.woostack/specs/` or `.woostack/plans/`).
- **Wait for explicit approval.** Never execute a fix plan on inferred or assumed approval. Silence is not a yes.
- **Commit the plan before the gate.** The fix plan is committed as a docs-only PR (stack base) via `woostack-commit` **before** the approve-to-execute gate — build-style; a fix is two PRs (docs base + code increment).
- **Worktree lives across the gate.** The fix worktree stays alive across the approve-to-execute gate (so revise/abandon are cheap) and is torn down only on **Go**; `woostack-execute` then cuts a fresh code-increment worktree off the `fix/<slug>` tip — it does not reuse the step-2 worktree.
- **Delegate execution.** Step 5 hands the fix file to [`woostack-execute`](../woostack-execute/SKILL.md); never re-inline a TDD/commit/review/distill loop. Execute owns the branch, TDD per task, checkbox ticking, commit via `woostack-commit`, task review, and distill. This skill retains only diagnosis, the fix plan, hardening, the approval gate, and the frontmatter lifecycle.
- **TDD Kernel.** Every fix is driven by a failing test first — enforced by `woostack-execute`'s per-task TDD loop.
- **Never merge.** Execution (via `woostack-execute`) commits and opens/updates stacked PRs; this skill never merges.
