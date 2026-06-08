**Source:** .woostack/specs/2026-06-08-address-comments-commit-integration.md

# woostack-address-comments: integrate the commit skill — Implementation Plan

**Goal:** Integrate the `woostack-commit` skill into `woostack-address-comments` to handle committing, pushing, and updating PR metadata, while preserving the SHA capture for GitHub thread replies.

**Architecture:** Edit `skills/woostack-address-comments/SKILL.md` and `skills/woostack-address-comments/prompts/address.md` to instruct the agent to use the `/woostack-commit` command instead of raw git commands, and then use `git rev-parse HEAD` to capture the SHA.

**Tech Stack:** Markdown, Git, Bash

---

## Increment 1: Integrate woostack-commit into address-comments

> One independently shippable PR containing the skill markdown changes.

### Task 1: Update SKILL.md to use woostack-commit

**Files:**
- Modify: `skills/woostack-address-comments/SKILL.md`

- [x] **Step 1: Write the failing test**

  Write a verification command that checks if the commit skill `woostack-commit` is referenced in the commit/push step of `SKILL.md`.
  
  Run: `grep -q "woostack-commit" skills/woostack-address-comments/SKILL.md`
  Expected: FAIL (exit status 1)

- [x] **Step 2: Run the test, confirm it fails**

  Run: `grep -q "woostack-commit" skills/woostack-address-comments/SKILL.md`
  Expected: FAIL (exit code 1)

- [x] **Step 3: Minimal implementation**

  Modify step 5 in `skills/woostack-address-comments/SKILL.md` to stage changes, run `/woostack-commit`, and capture the SHA:
  
  ```markdown
  5. **Commit + push** — apply all final `FIX` edits to the working tree → stage the changes → invoke [`woostack-commit`](../woostack-commit/SKILL.md) with a message referencing the threads addressed (e.g. `/woostack-commit "fix: address review threads <ids>"`) to commit, run checks, push, and update the PR metadata → capture the commit `<sha>` (e.g., via `git rev-parse HEAD`) before any reply, so "Fixed in `<sha>`" is real. Never force-push.
  ```

- [x] **Step 4: Run the test, confirm it passes**

  Run: `grep -q "woostack-commit" skills/woostack-address-comments/SKILL.md`
  Expected: PASS (exit code 0)

- [x] **Step 5: Commit**

  ```bash
  gt create -m "docs: use commit skill in address-comments workflow"
  ```

### Task 2: Update prompts/address.md to run /woostack-commit

**Files:**
- Modify: `skills/woostack-address-comments/prompts/address.md`

- [x] **Step 1: Write the failing test**

  Write a verification command that checks if the `/woostack-commit` command is referenced in `prompts/address.md`.
  
  Run: `grep -q "/woostack-commit" skills/woostack-address-comments/prompts/address.md`
  Expected: FAIL (exit status 1)

- [x] **Step 2: Run the test, confirm it fails**

  Run: `grep -q "/woostack-commit" skills/woostack-address-comments/prompts/address.md`
  Expected: FAIL (exit status 1)

- [x] **Step 3: Minimal implementation**

  Modify the instructions under "After the phases" Step 1 in `skills/woostack-address-comments/prompts/address.md` to use `/woostack-commit`:
  
  ```markdown
  1. If any FIX edits were made, stage the changes and invoke the [`woostack-commit`](../woostack-commit/SKILL.md) skill to commit, push, and update the PR metadata:
     ```bash
     /woostack-commit "fix: address review threads <ids>"
     ```
     Then capture the commit `<sha>` (e.g., `git rev-parse HEAD`) before posting any replies. Never force-push.
  ```

- [x] **Step 4: Run the test, confirm it passes**

  Run: `grep -q "/woostack-commit" skills/woostack-address-comments/prompts/address.md`
  Expected: PASS (exit code 0)

- [x] **Step 5: Commit**

  ```bash
  gt modify -c -m "docs: instruct agent to invoke commit skill in address-comments prompt"
  ```

### Task 3: Verify existing address-comments tests

**Files:**
- None (verify scripts)

- [x] **Step 1: Write the verification command**

  Run all tests in the `skills/woostack-address-comments/scripts/tests/` directory to ensure they all pass.
  
  Run:
  ```bash
  ./skills/woostack-address-comments/scripts/tests/test-address-worker-contract.sh && \
  ./skills/woostack-address-comments/scripts/tests/test-address-comments-ownership.sh && \
  ./skills/woostack-address-comments/scripts/tests/test-address-helper-scripts.sh
  ```
  Expected: PASS

- [x] **Step 2: Run the test, confirm it passes**

  Run the command from Step 1 and verify all tests exit successfully.

- [ ] **Step 3: Commit**

  ```bash
  gt modify -c -m "test: verify all address-comments tests pass"
  ```

---

## Self-review (run before handing back)

- [x] **Spec coverage** — every spec requirement maps to a task above.
- [x] **AC coverage** — each spec §7 acceptance criterion (and its filled happy/error/edge cases) maps to a test.
- [x] **No placeholders** — no TBD/TODO; complete code, exact commands, and expected output in every step.
- [x] **Type consistency** — types, signatures, and names match across tasks.
