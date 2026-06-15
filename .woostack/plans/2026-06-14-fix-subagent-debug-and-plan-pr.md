---
type: plan
source: .woostack/specs/2026-06-14-fix-subagent-debug-and-plan-pr.md
status: ready
branch: feature/fix-subagent-debug-and-plan-pr
---

**Source:** [[specs/2026-06-14-fix-subagent-debug-and-plan-pr]]

# Tighten the woostack-fix loop (subagent debug + plan PR before the execute gate) Implementation Plan

**Goal:** Edit `skills/woostack-fix/SKILL.md` so the fix loop can run its step-1 debug investigation in a read-only subagent (smart default mirroring `woostack-execute`) and commits the fix plan as a docs-only PR before the approve-to-execute gate.

**Architecture:** Two independent edits to a single markdown file, `skills/woostack-fix/SKILL.md`. Increment 1 adds a `## Debug investigation mode` section + a step-1 reference + a hard-constraint bullet. Increment 2 reorders the procedure (commit the fix plan before the gate, build-style 2-PR docs base) and updates the Overview diagram, the gate paragraph, the worktree prose, and Hard constraints. Cross-links target the *existing* `woostack-execute` "Execution mode" section and the worktree contract — no new files, and `woostack-debug`/`woostack-execute` SKILLs are untouched.

**Tech Stack:** Markdown (skills repo). No code runner — every "test" is a `grep`/`grep -n` assertion over `skills/woostack-fix/SKILL.md` with exact expected output, plus `skills/woostack-init/scripts/build-index.sh` and `woostack-doctor` ending clean.

> **Increments stack linearly:** Increment 2 branches off Increment 1's tip and sees its edits. The two touch disjoint regions of the file (Increment 1: a new section + step 1 + one constraint bullet; Increment 2: Overview diagram + gate paragraph + procedure steps + other constraint bullets), so each PR diff stands alone.

> **Anchor note for the executor:** all `old_string` anchors below are quoted verbatim from `skills/woostack-fix/SKILL.md` at the increment's start. Re-grep before each Edit if the file has drifted.

---

## Increment 1: Add the `--inline` / `--subagent` debug driver to fix step 1

> One independently shippable PR. Adds a `## Debug investigation mode` section, points step 1 at it, and adds one Hard-constraints bullet. Covers spec **AC1** and **AC2**.

### Task 1: Add the `## Debug investigation mode` section

**Files:**
- Modify: `skills/woostack-fix/SKILL.md` (insert a new section between the Overview's gate paragraph and `## Procedure`)
- Test: grep assertions over the same file

- [x] **Step 1: Write the failing test**
  ```bash
  # .woostack/tmp/inc1_section.sh — run from repo root
  set -e
  f=skills/woostack-fix/SKILL.md
  grep -q '^## Debug investigation mode$' "$f" \
    && grep -q 'Smart default (no flag): subagent where the host can spawn' "$f" \
    && grep -q 'Passing both `--inline` and `--subagent` is an error' "$f" \
    && grep -q 'no worktree and no cwd-pin' "$f" \
    && grep -q 'it returns a \*\*blocked' "$f" \
    && grep -q 'general-purpose' "$f"
  echo "PASS"
  ```

- [x] **Step 2: Run the test, confirm it fails**
  Run: `bash .woostack/tmp/inc1_section.sh; echo "exit=$?"`
  Expected: FAIL — no `PASS` printed; `exit=1` (the `^## Debug investigation mode$` grep fails first).

- [x] **Step 3: Minimal implementation**
  Edit `skills/woostack-fix/SKILL.md`. Insert the following section immediately **after** the Overview gate paragraph (the paragraph beginning `The skill has exactly **one** hard gate:`) and **before** `## Procedure`:
  ```markdown
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
  never pretend subagent mode ran. Passing both `--inline` and `--subagent` is an error: stop and
  ask which to use.

  **The debug subagent is read-only and needs no worktree and no cwd-pin.** `woostack-debug`
  never writes code, commits, or `.woostack/` artifacts, so the investigator — unlike
  `woostack-execute`'s implementer subagent, which must self-pin to its worktree (see the
  [worktree contract](../woostack-init/references/worktrees.md)) — pins to nothing. Step 1 also
  runs **before** the fix worktree is created (step 2), so there is nothing to pin to.

  **No root cause found.** In **inline** mode, `woostack-debug` stops and asks the user for hints,
  as today. In **subagent** mode the subagent cannot prompt mid-run, so it returns a **blocked
  status plus what it investigated**, and the orchestrator surfaces that to the user (mirroring
  `woostack-execute`'s BLOCKED escalation) — never guess a fix plan from a failed investigation.
  ```

- [x] **Step 4: Run the test, confirm it passes**
  Run: `bash .woostack/tmp/inc1_section.sh`
  Expected: PASS

- [x] **Step 5: Commit**
  ```bash
  # First commit in the increment:
  gt create -m "feat(fix): add --inline/--subagent debug investigation mode"
  ```

### Task 2: Point step 1 at the driver

**Files:**
- Modify: `skills/woostack-fix/SKILL.md` step 1 (the `1. **Diagnose the root cause.**` block)
- Test: grep assertions

- [x] **Step 1: Write the failing test**
  ```bash
  # .woostack/tmp/inc1_step1.sh — run from repo root
  set -e
  f=skills/woostack-fix/SKILL.md
  grep -q 'through the selected driver' "$f" \
    && grep -q 'see \[Debug investigation mode\](#debug-investigation-mode)' "$f"
  echo "PASS"
  ```

- [x] **Step 2: Run the test, confirm it fails**
  Run: `bash .woostack/tmp/inc1_step1.sh; echo "exit=$?"`
  Expected: FAIL — `exit=1`; the phrase `through the selected driver` is absent.

- [x] **Step 3: Minimal implementation**
  In `skills/woostack-fix/SKILL.md`, replace this exact block (step 1's lead-in + the fenced command):
  ```markdown
  1. **Diagnose the root cause.**
     Run the systematic-debugging skill to find the root cause before proposing any code edits.
     ```
     /woostack-debug <target>
     ```
  ```
  with:
  ```markdown
  1. **Diagnose the root cause.**
     Run the systematic-debugging skill to find the root cause before proposing any code edits,
     through the selected driver — inline, or a read-only subagent (see
     [Debug investigation mode](#debug-investigation-mode)).
     ```
     /woostack-debug <target>   # inline, or dispatched to a read-only investigator subagent
     ```
  ```
  Then replace the step's trailing sentence:
  ```markdown
  If it cannot find a root cause, do not guess: stop and ask the user for hints.
  ```
  with:
  ```markdown
  If it cannot find a root cause, do not guess: inline, stop and ask the user for hints; in
  subagent mode the investigator returns a blocked status plus what it investigated, which you
  surface to the user (see [Debug investigation mode](#debug-investigation-mode)).
  ```

- [x] **Step 4: Run the test, confirm it passes**
  Run: `bash .woostack/tmp/inc1_step1.sh`
  Expected: PASS

- [x] **Step 5: Commit**
  ```bash
  gt modify -c -m "docs(fix): route step 1 diagnosis through the debug driver"
  ```

### Task 3: Add the Hard-constraints `Debug driver` bullet + verify the store

**Files:**
- Modify: `skills/woostack-fix/SKILL.md` `## Hard constraints`
- Verify: `skills/woostack-init/scripts/build-index.sh`, `woostack-doctor`

- [x] **Step 1: Write the failing test**
  ```bash
  # .woostack/tmp/inc1_constraint.sh — run from repo root
  set -e
  f=skills/woostack-fix/SKILL.md
  grep -q '\*\*Debug driver\.\*\* Step 1' "$f"
  echo "PASS"
  ```

- [x] **Step 2: Run the test, confirm it fails**
  Run: `bash .woostack/tmp/inc1_constraint.sh; echo "exit=$?"`
  Expected: FAIL — `exit=1`.

- [x] **Step 3: Minimal implementation**
  In `skills/woostack-fix/SKILL.md`, insert this bullet into `## Hard constraints` immediately **after** the `- **No guess-and-check.** ...` bullet:
  ```markdown
  - **Debug driver.** Step 1's investigation runs inline or via a read-only `general-purpose` subagent (`--inline`/`--subagent`, smart default = subagent where the host can spawn, else inline); the subagent returns only `woostack-debug`'s Phase 4 handback and needs no worktree. See [Debug investigation mode](#debug-investigation-mode).
  ```

- [x] **Step 4: Run the test, confirm it passes**
  Run: `bash .woostack/tmp/inc1_constraint.sh`
  Expected: PASS

- [x] **Step 5: Verify the store is clean**
  Run:
  ```bash
  bash skills/woostack-init/scripts/build-index.sh
  bash skills/woostack-doctor/scripts/doctor.sh --check
  ```
  Expected: build-index exits 0; `doctor.sh --check` exits 0 (no error). The `.woostack/tmp/inc1_*.sh` scratch scripts live in the gitignored `.woostack/tmp/` (root `.gitignore` line 63), so they never ride the PR — no cleanup step needed.

- [x] **Step 6: Commit**
  ```bash
  gt modify -c -m "docs(fix): add Debug driver hard constraint"
  ```

---

## Increment 2: Commit the fix plan as a docs-only PR before the approve-to-execute gate

> One independently shippable PR, stacked on Increment 1. Reorders the procedure so the fix plan is committed (docs-only PR, stack base) before the gate, build-style; updates the Overview diagram, the gate paragraph, the worktree prose, and Hard constraints. Covers spec **AC3** and **AC4**.

### Task 1: Reorder the Overview diagram and rewrite the gate paragraph

**Files:**
- Modify: `skills/woostack-fix/SKILL.md` Overview (the fenced flow diagram + the gate paragraph)
- Test: grep assertions

- [x] **Step 1: Write the failing test**
  ```bash
  # .woostack/tmp/inc2_overview.sh — run from repo root
  set -e
  f=skills/woostack-fix/SKILL.md
  grep -q 'commit fix plan as a docs-only PR (stack base' "$f" \
    && grep -q 'approve-to-execute (GATE)' "$f" \
    && grep -q 'fresh code-increment worktree off' "$f" \
    && grep -q 'two PRs (docs base + code increment)' "$f"
  echo "PASS"
  ```

- [x] **Step 2: Run the test, confirm it fails**
  Run: `bash .woostack/tmp/inc2_overview.sh; echo "exit=$?"`
  Expected: FAIL — `exit=1`.

- [x] **Step 3: Minimal implementation**
  In `skills/woostack-fix/SKILL.md`, replace the Overview diagram block:
  ```
  diagnose root cause (woostack-debug) → write fix plan (fixes/ markdown) → harden fix plan 
    → approve fix plan (GATE) → execute via woostack-execute
    (branch → TDD per task → tick → commit via woostack-commit → task review → distill)
  ```
  with:
  ```
  diagnose root cause (woostack-debug) → write fix plan (fixes/ markdown) → harden fix plan
    → commit fix plan as a docs-only PR (stack base, via woostack-commit)
    → approve-to-execute (GATE) → execute via woostack-execute
    (fresh code-increment worktree off fix/<slug> tip → TDD per task → tick
     → commit via woostack-commit → task review → distill)
  ```
  Then replace the gate paragraph:
  ```markdown
  The skill has exactly **one** hard gate: **fix plan approval**. Because the plan contains both the diagnosis (the spec part) and the steps (the plan part), a single approval stop protects the codebase from wrong fixes or poor plans before implementation begins. Delegation adds no gate: `woostack-execute` owns no approval gate and never merges, so the fix's one gate stays upstream of execution.
  ```
  with:
  ```markdown
  The skill has exactly **one** hard gate: **approve-to-execute**. The fix plan is first committed as a docs-only PR (the stack base) and *then* presented for approval — build-style (mirroring [`woostack-build`](../woostack-build/SKILL.md) steps 7-8), so the approved plan is a committed, reviewable artifact and the code increment stacks on top. The gate still protects the codebase: no implementation happens until it clears, and a fix is therefore **two PRs (docs base + code increment)**. Delegation adds no gate: `woostack-execute` owns no approval gate and never merges, so the fix's one gate stays upstream of execution.
  ```

- [x] **Step 4: Run the test, confirm it passes**
  Run: `bash .woostack/tmp/inc2_overview.sh`
  Expected: PASS

- [x] **Step 5: Commit**
  ```bash
  gt create -m "feat(fix): commit the fix plan as a docs PR before the execute gate"
  ```

### Task 2: Reorder the procedure — commit the plan before the gate, with the worktree lifecycle

**Files:**
- Modify: `skills/woostack-fix/SKILL.md` procedure steps (the approval step, the execute step's worktree-reuse prose, the teardown step)
- Test: grep + ordering assertion

- [x] **Step 1: Write the failing test**
  ```bash
  # .woostack/tmp/inc2_procedure.sh — run from repo root
  set -e
  f=skills/woostack-fix/SKILL.md
  # required phrases
  grep -q 'Commit the fix plan as a docs-only PR (stack base)' "$f"
  grep -q 'Approve to execute (GATE)' "$f"
  grep -q 'stays alive across the gate' "$f"
  grep -q 'torn down only on Go' "$f"
  grep -q 'cuts a fresh code-increment worktree' "$f"
  grep -q '\*\*Revise\*\*' "$f" && grep -q '\*\*Abandon\*\*' "$f"
  # ordering: the commit-the-plan step must appear BEFORE the gate step
  commit_ln=$(grep -n 'Commit the fix plan as a docs-only PR (stack base)' "$f" | head -1 | cut -d: -f1)
  gate_ln=$(grep -n 'Approve to execute (GATE)' "$f" | head -1 | cut -d: -f1)
  test "$commit_ln" -lt "$gate_ln"
  echo "PASS (commit@$commit_ln < gate@$gate_ln)"
  ```

- [x] **Step 2: Run the test, confirm it fails**
  Run: `bash .woostack/tmp/inc2_procedure.sh; echo "exit=$?"`
  Expected: FAIL — `exit=1`; `Commit the fix plan as a docs-only PR (stack base)` is absent.

- [x] **Step 3: Minimal implementation**
  Apply these edits to `skills/woostack-fix/SKILL.md`.

  > **Why one combined step, not a new numbered step:** inserting a new `5.` would force renumbering the existing execute (5) and track (6) steps and every `step 5`/`step 6` cross-reference in the file (e.g. "(run by `woostack-execute` in step 5)"). Folding commit + gate into step 4 (commit prose first, then the gate) keeps steps 5/6 and their references intact while still satisfying the commit-before-gate ordering assertion.

  (a) Replace the approval step — the line `4. **Get explicit approval (GATE).**` plus its body paragraph (ending `When approved, set the frontmatter \`status: approved\`.`) — with this single combined step:
  ```markdown
  4. **Commit the fix plan as a docs-only PR (stack base), then approve to execute (GATE).**
     First, **commit the fix plan**: with it hardened, commit via
     [`woostack-commit`](../woostack-commit/SKILL.md) on the `fix/<slug>` branch from inside the
     fix worktree — a **docs-only PR** carrying only the `.woostack/fixes/` markdown, no code; the
     **stack base** (mirroring [`woostack-build`](../woostack-build/SKILL.md) step 7). Leave the
     frontmatter at `status: hardened` — the lifecycle advances only at the gate.

     Then the gate — **Approve to execute (GATE)**: **always present the committed fix-plan PR and
     get explicit approval before executing** (the skill's single hard gate, build step-8 style).
     Point the user at the PR and the fix-file path and wait for a clear yes:
     - **Go** → set `status: approved` and proceed to step 5. The fix worktree **stays alive
       across the gate** and is **torn down only on Go** — on Go, tear it down
       (`git worktree remove "$WOOSTACK_ROOT/.woostack/worktrees/fix-<slug>"`), then step 5's
       `woostack-execute` **cuts a fresh code-increment worktree** off the `fix/<slug>` tip.
     - **Revise** → amend the fix plan in the still-alive fix worktree, re-push the docs PR, and
       re-present at the gate.
     - **Abandon** → close the docs PR, `git worktree remove --force` the fix worktree, and delete
       the `fix/<slug>` branch; no code was implemented.
     Never execute on inferred or assumed approval; silence is not a yes.
  ```

  (b) In the execute step (step 5, unchanged number), replace the worktree-reuse sentence:
  ```markdown
   step 2), so execute **verifies and reuses** that worktree rather than re-creating it, then
  ```
  with (factual correction only — the lifecycle tokens live in step 4):
  ```markdown
   step 2) but holds only the committed plan as the docs-PR stack base; the code increment runs in
   the fresh worktree execute cut off the `fix/<slug>` tip at the Go transition (step 4), not the
   step-2 fix-plan worktree, and execute then
  ```

  (c) In the track-and-lifecycle step (step 6, unchanged number), replace the teardown sentence:
  ```markdown
     After the PR is open and the frontmatter is set, **teardown** the fix worktree
     (`git worktree remove "$WOOSTACK_ROOT/.woostack/worktrees/fix-<slug>"`); the branch/commits/PR
     persist. **Leave it on failure** and report its path. The memory distill (run by `woostack-execute`
     in step 5) targets the primary tree via the `WOOSTACK_ROOT` export of the [worktree
     contract](../woostack-init/references/worktrees.md) §5, so it survives teardown.
  ```
  with:
  ```markdown
     The fix-plan worktree was already torn down at the **Go** transition (step 4); the
     code-increment worktree `woostack-execute` cut is torn down by execute after the code PR is
     open. The branches/commits/PRs persist. **Leave a worktree on failure** and report its path. The
     memory distill (run by `woostack-execute` in step 5) targets the primary tree via the
     `WOOSTACK_ROOT` export of the [worktree contract](../woostack-init/references/worktrees.md) §5,
     so it survives teardown.
  ```

- [x] **Step 4: Run the test, confirm it passes**
  Run: `bash .woostack/tmp/inc2_procedure.sh`
  Expected: PASS (prints `PASS (commit@N < gate@M)`).

- [x] **Step 5: Commit**
  ```bash
  gt modify -c -m "feat(fix): reorder procedure to commit plan before the gate; worktree lifecycle"
  ```

### Task 3: Update Hard constraints + verify the store

**Files:**
- Modify: `skills/woostack-fix/SKILL.md` `## Hard constraints`
- Verify: `build-index.sh`, `woostack-doctor`

- [x] **Step 1: Write the failing test**
  ```bash
  # .woostack/tmp/inc2_constraint.sh — run from repo root
  set -e
  f=skills/woostack-fix/SKILL.md
  grep -q '\*\*Commit the plan before the gate\.\*\*' "$f"
  grep -q '\*\*Worktree lives across the gate\.\*\*' "$f"
  # AC4 invariants still present
  grep -q '\*\*Delegate execution\.\*\*' "$f"
  grep -q '\*\*Never merge\.\*\*' "$f"
  echo "PASS"
  ```

- [x] **Step 2: Run the test, confirm it fails**
  Run: `bash .woostack/tmp/inc2_constraint.sh; echo "exit=$?"`
  Expected: FAIL — `exit=1`; the two new bullets are absent (the `Delegate execution` / `Never merge` greps already pass, proving AC4 invariants are preserved).

- [x] **Step 3: Minimal implementation**
  In `skills/woostack-fix/SKILL.md` `## Hard constraints`, insert these two bullets immediately **after** the `- **Wait for explicit approval.** ...` bullet:
  ```markdown
  - **Commit the plan before the gate.** The fix plan is committed as a docs-only PR (stack base) via `woostack-commit` **before** the approve-to-execute gate — build-style; a fix is two PRs (docs base + code increment).
  - **Worktree lives across the gate.** The fix worktree stays alive across the approve-to-execute gate (so revise/abandon are cheap) and is torn down only on **Go**; `woostack-execute` then cuts a fresh code-increment worktree off the `fix/<slug>` tip — it does not reuse the step-2 worktree.
  ```

- [x] **Step 4: Run the test, confirm it passes**
  Run: `bash .woostack/tmp/inc2_constraint.sh`
  Expected: PASS

- [x] **Step 5: Verify the store is clean**
  Run:
  ```bash
  bash skills/woostack-init/scripts/build-index.sh
  bash skills/woostack-doctor/scripts/doctor.sh --check
  ```
  Expected: build-index exits 0; `doctor.sh --check` exits 0 (no error). The `.woostack/tmp/inc2_*.sh` scratch scripts live in the gitignored `.woostack/tmp/`, so they never ride the PR — no cleanup step needed.

- [x] **Step 6: Commit**
  ```bash
  gt modify -c -m "docs(fix): add commit-before-gate and worktree-lifecycle constraints"
  ```

---

## Plan Checks

- **Spec coverage** — AC1 → Increment 1 Tasks 1-2 (flags, smart default, both-flags error, degrade); AC2 → Increment 1 Tasks 1-3 (handback-only, read-only/no-worktree, blocked path, general-purpose); AC3 → Increment 2 Tasks 1-2 (commit-before-gate ordering assertion, 2 PRs, fresh worktree off tip); AC4 → Increment 2 Task 3 (delegate/never-merge greps still pass) + the unchanged harden/lifecycle steps.
- **AC coverage** — every filled happy/error/edge case in spec §7 maps to a grep above; no §7 case is whole-section `N/A`.
- **No placeholders** — every Step carries the exact SKILL markdown to insert and the exact `grep`/command with expected output.
- **Type consistency** — heading/token strings asserted by greps match the strings written in the implementation steps verbatim (`## Debug investigation mode`, `Commit the fix plan as a docs-only PR (stack base)`, `Approve to execute (GATE)`).
- **No code edits outside `skills/woostack-fix/SKILL.md`** — cross-link targets (`woostack-execute#execution-mode`, the worktree contract) already exist; `woostack-debug`/`woostack-execute` SKILLs are not edited.
- **No spec/plan status mutation in tasks** — these are edits to the *shipped* `woostack-fix` skill, not to this build's own `.woostack/` artifacts. No task touches this spec's or plan's frontmatter; this build's spec stays `approved` and the plan owns its own `planning`→`ready` band (set by the build loop, not by a task).
- **Step numbering preserved** — Increment 2 folds commit+gate into step 4 (no new numbered step), so the execute (5) and track (6) steps and every `step 5`/`step 6` cross-reference in the SKILL stay valid.
