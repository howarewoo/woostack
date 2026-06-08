---
name: woostack-fix
description: Use to resolve small technical issues (bugs, hotfixes, refactors) through a unified execution loop — diagnose root cause with woostack-debug, author a fix plan under .woostack/fixes/, harden, get explicit user approval, execute via TDD, and commit via woostack-commit.
---

# woostack-fix

## Overview

Drives a bug fix or a small technical change from diagnosis to implementation through a lightweight, unified loop. Fixes are smaller than features and combine the spec and the plan into a single markdown file under `.woostack/fixes/`.

```
diagnose root cause (woostack-debug) → write fix plan (fixes/ markdown) → harden fix plan 
  → approve fix plan (GATE) → execute (TDD: failing test → minimal fix → verify) 
  → commit (woostack-commit)
```

The skill has exactly **one** hard gate: **fix plan approval**. Because the plan contains both the diagnosis (the spec part) and the steps (the plan part), a single approval stop protects the codebase from wrong fixes or poor plans before implementation begins.

## Procedure

1. **Diagnose the root cause.**
   Run the systematic-debugging skill to find the root cause before proposing any code edits.
   ```
   /woostack-debug <target> --auto
   ```
   Let it run its autonomous Phase 1-3. It will investigate the symptoms, trace data flow backward, and output a clear root-cause hypothesis and the necessary test case description. If it cannot find a root cause, do not guess: stop and ask the user for hints.

2. **Write the fix plan as markdown.**
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

5. **Execute.**
   Create the feature branch named in the frontmatter (`git switch -c fix/<slug>` or `gt create fix/<slug>`). Set the frontmatter `status: executing` on the fix file.
   Work through the implementation plan tasks in order using TDD:
   - Implement the failing test first (confirm it fails).
   - Apply the minimal fix (no bundled refactoring, no "while I'm here" edits).
   - Run the tests and verify they pass.
   - Tick the checkboxes (`- [x]`) in the fix plan file as you complete each task.

6. **Commit and PR.**
   Stage the code changes, tests, and the modified fix plan. Invoke the commit skill:
   ```
   /woostack-commit
   ```
   Once the PR is open, update the fix plan's frontmatter to `status: in-review` (once merged, `status: done`). The fix file's frontmatter `status:` is the source of truth for the fix lifecycle — fixes are tracked by their `.woostack/fixes/` file, not the spec-centric `/woostack-status` board, which enumerates increment PRs only via the `Spec: .woostack/specs/<file>.md` trailer that [`woostack-commit`](../woostack-commit/SKILL.md) writes (it never emits a `fixes/` trailer).

7. **Distill Memory gotchas.**
   At the end of a successful execution, write **one** `gotcha` note to the `.woostack/memory/` store describing the root cause and the fix patterns learned. Dedupe, update `MEMORY.md`, and rebuild the index using `build-index.sh` and `doctor.sh` as required by the [memory contract](../woostack-init/references/memory.md).

## Hard constraints

- **No guess-and-check.** Always run `woostack-debug` to trace the data flow and confirm the root cause before writing the fix plan.
- **One combined markdown file under `.woostack/fixes/`.** Fixes are specified and planned in a single file under `.woostack/fixes/` (not `.woostack/specs/` or `.woostack/plans/`).
- **Wait for explicit approval.** Never execute a fix plan on inferred or assumed approval. Silence is not a yes.
- **TDD Kernel.** Every fix must be driven by a failing test first.
- **Never merge.** The skill commits and opens/updates stacked PRs; it never merges.
