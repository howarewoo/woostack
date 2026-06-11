---
name: woostack-fix
description: Use to resolve small technical issues (bugs, hotfixes, refactors) through a unified execution loop — diagnose root cause with woostack-debug, author a fix plan under .woostack/fixes/, harden, get explicit user approval, then delegate execution to woostack-execute (TDD per task, task review, commit via woostack-commit, distill).
---

# woostack-fix

## Overview

Drives a bug fix or a small technical change from diagnosis to implementation through a lightweight, unified loop. Fixes are smaller than features and combine the spec and the plan into a single markdown file under `.woostack/fixes/`. The fix loop owns diagnosis, the fix plan, hardening, and the approval gate, then **delegates the execution mechanics to [`woostack-execute`](../woostack-execute/SKILL.md)** — the same engine the build loop uses — passing the fix file as the plan. Fix does not re-inline a TDD/commit/distill loop of its own.

```
diagnose root cause (woostack-debug) → write fix plan (fixes/ markdown) → harden fix plan 
  → approve fix plan (GATE) → execute via woostack-execute
  (branch → TDD per task → tick → commit via woostack-commit → task review → distill)
```

The skill has exactly **one** hard gate: **fix plan approval**. Because the plan contains both the diagnosis (the spec part) and the steps (the plan part), a single approval stop protects the codebase from wrong fixes or poor plans before implementation begins. Delegation adds no gate: `woostack-execute` owns no approval gate and never merges, so the fix's one gate stays upstream of execution.

## Procedure

1. **Diagnose the root cause.**
   Run the systematic-debugging skill to find the root cause before proposing any code edits.
   ```
   /woostack-debug <target>
   ```
   It runs its four-phase root-cause analysis automatically — investigating the symptoms, tracing data flow backward, identifying the root cause — and hands back the Phase 4 result: the root-cause summary, the proposed minimal fix, and the TDD context (the failing-test description). Carry the proposed fix forward into the fix plan's Proposed Fix section below. If it cannot find a root cause, do not guess: stop and ask the user for hints.

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

4. **Get explicit approval (GATE).**
   **Always present the written fix plan to the user and get explicit approval before executing** — this is a hard gate. Point the user at the file path, wait for a clear yes, and make any requested changes. When approved, set the frontmatter `status: approved`.

5. **Execute via [`woostack-execute`](../woostack-execute/SKILL.md).**
   Set the fix file's frontmatter `status: executing`, then hand the fix file to the execute
   engine — the fix file *is* the plan, and its `## 3. Implementation Plan` is the single
   increment:
   ```
   /woostack-execute .woostack/fixes/YYYY-MM-DD-<slug>.md --inline
   ```
   `woostack-execute` owns the execution cadence so the fix inherits the same discipline as a
   build increment: the increment's Graphite branch + its worktree already exist (created in
   step 2), so execute **verifies and reuses** that worktree rather than re-creating it, then
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

   After the PR is open and the frontmatter is set, **teardown** the fix worktree
   (`git worktree remove "$WOOSTACK_ROOT/.woostack/worktrees/fix-<slug>"`); the branch/commits/PR
   persist. **Leave it on failure** and report its path. The memory distill (run by `woostack-execute`
   in step 5) targets the primary tree via the `WOOSTACK_ROOT` export of the [worktree
   contract](../woostack-init/references/worktrees.md) §5, so it survives teardown.

## Hard constraints

- **No guess-and-check.** Always run `woostack-debug` to trace the data flow and confirm the root cause before writing the fix plan.
- **One combined markdown file under `.woostack/fixes/`.** Fixes are specified and planned in a single file under `.woostack/fixes/` (not `.woostack/specs/` or `.woostack/plans/`).
- **Wait for explicit approval.** Never execute a fix plan on inferred or assumed approval. Silence is not a yes.
- **Delegate execution.** Step 5 hands the fix file to [`woostack-execute`](../woostack-execute/SKILL.md); never re-inline a TDD/commit/review/distill loop. Execute owns the branch, TDD per task, checkbox ticking, commit via `woostack-commit`, task review, and distill. This skill retains only diagnosis, the fix plan, hardening, the approval gate, and the frontmatter lifecycle.
- **TDD Kernel.** Every fix is driven by a failing test first — enforced by `woostack-execute`'s per-task TDD loop.
- **Never merge.** Execution (via `woostack-execute`) commits and opens/updates stacked PRs; this skill never merges.
