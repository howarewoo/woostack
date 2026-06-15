---
type: plan
source: .woostack/specs/2026-06-08-woostack-fix.md
status: executing
branch: feature/woostack-fix
---

**Source:** [[specs/2026-06-08-woostack-fix]]

# woostack-fix Skill and woostack-debug Refinement Implementation Plan

**Goal:** Create a new `woostack-fix` skill that uses `woostack-debug` to identify a root cause, writes a fix plan under `.woostack/fixes/`, hardens, executes, and commits, while refining `woostack-debug` to focus exclusively on root cause identification.

**Architecture:** Split the implementation into three stacked Graphite increments:
1. Refine `woostack-debug` to remove code modification/Phase 4, create `skills/woostack-fix/SKILL.md`, and add its command routing to `using-woostack`.
2. Update `woostack-init` to initialize `.woostack/fixes/` and update `woostack-commit` to support fixes.
3. Update `woostack-status` (`status.sh` and its SKILL.md) to scan, parse, and render fixes on the feature board, and update `AGENTS.md` / `README.md`.

**Tech Stack:** Bash, Markdown, Git, Graphite, GitHub CLI (gh).

---

## Increment 1: Refine woostack-debug & Add woostack-fix Skill

### Task 1: Refine `woostack-debug` to focus exclusively on root cause
**Files:**
- Modify: `skills/woostack-debug/SKILL.md`

- [ ] **Step 1: Edit `skills/woostack-debug/SKILL.md`**
  Remove Phase 4 (Implementation), count of attempts, and escalation rules for 3+ failed fixes. Update overview and behavior of `--auto` and standalone modes to focus purely on diagnosing the root cause.
  
  Replace lines 75-100 with a clean transition to returning findings:
  ```markdown
  ### Phase 4 — Handback
  
  1. **Summarize findings**: Clearly list the root cause, files/lines affected, and evidence gathered.
  2. **Propose minimal fix**: Detail the exact logic change required. Do not apply it.
  3. **TDD context**: Name the test file and exact test cases needed to reproduce the issue.
  ```

- [ ] **Step 2: Run verification**
  Run: `grep -c "Phase 4 — Implementation" skills/woostack-debug/SKILL.md`
  Expected: `0`

### Task 2: Create the `woostack-fix` skill
**Files:**
- Create: `skills/woostack-fix/SKILL.md`

- [ ] **Step 1: Write `skills/woostack-fix/SKILL.md`**
  Define the unified execution loop (debug -> write fix plan -> harden -> approve -> execute -> commit) and provide the plan template.
  
  ```markdown
  ---
  name: woostack-fix
  description: Create a fix plan under .woostack/fixes/ after identifying the root cause with woostack-debug, then harden, execute (TDD), and commit.
  ---
  
  # woostack-fix
  
  ## Overview
  ...
  ```

- [ ] **Step 2: Run verification**
  Run: `test -f skills/woostack-fix/SKILL.md && echo "OK"`
  Expected: `OK`

### Task 3: Route `woostack-fix` in `using-woostack`
**Files:**
- Modify: `skills/using-woostack/SKILL.md`

- [ ] **Step 1: Edit routing table in `skills/using-woostack/SKILL.md`**
  Add a row for `/woostack-fix <target> [description]` to route it.
  Update the public commands count if mentioned.

- [ ] **Step 2: Run verification**
  Run: `grep -q "woostack-fix" skills/using-woostack/SKILL.md && echo "OK"`
  Expected: `OK`

- [ ] **Step 3: Commit Increment 1**
  Run:
  ```bash
  gt create feature/woostack-fix-core
  git add skills/woostack-debug/SKILL.md skills/woostack-fix/SKILL.md skills/using-woostack/SKILL.md
  gt modify -m "feat(fix): refine woostack-debug and create woostack-fix skill core"
  ```

---

## Increment 2: Add Workspace Init Integration

### Task 4: Update `woostack-init` to support `.woostack/fixes/`
**Files:**
- Modify: `skills/woostack-init/SKILL.md`
- Create: `skills/woostack-init/templates/fixes/.gitkeep`

- [ ] **Step 1: Create the template folder and `.gitkeep`**
  Run: `mkdir -p skills/woostack-init/templates/fixes && touch skills/woostack-init/templates/fixes/.gitkeep`

- [ ] **Step 2: Modify `skills/woostack-init/SKILL.md`**
  Add the `.woostack/fixes/` directory and `.woostack/fixes/.gitkeep` to the list of items created/managed by `/woostack-init`.

- [ ] **Step 3: Run verification**
  Run: `test -f skills/woostack-init/templates/fixes/.gitkeep && echo "OK"`
  Expected: `OK`

### Task 5: Update `woostack-commit` to support fixes
**Files:**
- Modify: `skills/woostack-commit/SKILL.md`

- [ ] **Step 1: Edit `skills/woostack-commit/SKILL.md`**
  Update the PR trailer instructions and status conventions link to search for `.woostack/fixes/*.md` and write the trailer `Spec: .woostack/fixes/<file>.md` when working on a fix branch.

- [ ] **Step 2: Run verification**
  Run: `grep -q "woostack/fixes" skills/woostack-commit/SKILL.md && echo "OK"`
  Expected: `OK`

- [ ] **Step 3: Commit Increment 2**
  Run:
  ```bash
  gt create feature/woostack-fix-init-commit
  git add skills/woostack-init/ skills/woostack-commit/SKILL.md
  gt modify -m "feat(fix): add fixes directory to woostack-init and support in woostack-commit"
  ```

---

## Increment 3: Status Board Integration & Documentation

### Task 6: Update `status.sh` script to parse and display fixes
**Files:**
- Modify: `skills/woostack-status/scripts/status.sh`
- Modify: `skills/woostack-status/SKILL.md`

- [ ] **Step 1: Modify `skills/woostack-status/scripts/status.sh`**
  Update the script to scan `.woostack/fixes/*.md` in addition to specs, parse their status, checklist, and head PRs, and format them with `[FIX]` prefix.
  
  ```bash
  # In status.sh, update specs definition:
  specs=( "$SPEC_DIR"/*.md "$WOO_DIR"/fixes/*.md )
  ```
  And update plan_for / next_action / prs_for_spec logic to handle the fixes directory.

- [ ] **Step 2: Modify `skills/woostack-status/SKILL.md`**
  Document the status integration for fixes under `.woostack/fixes/`.

- [ ] **Step 3: Run verification**
  Run: `bash skills/woostack-status/scripts/status.sh`
  Expected: Runs successfully and exits 0.

### Task 7: Update AGENTS.md and README.md
**Files:**
- Modify: `AGENTS.md`
- Modify: `README.md`

- [ ] **Step 1: Edit `AGENTS.md`**
  Add `woostack-fix` to the list of public skills (increasing count to 15).
  Update file maps and descriptions.

- [ ] **Step 2: Edit `README.md`**
  Add `woostack-fix` documentation and update public command surface counts.

- [ ] **Step 3: Run verification**
  Run: `grep -q "woostack-fix" AGENTS.md && grep -q "woostack-fix" README.md && echo "OK"`
  Expected: `OK`

- [ ] **Step 4: Commit Increment 3**
  Run:
  ```bash
  gt create feature/woostack-fix-status-docs
  git add skills/woostack-status/ AGENTS.md README.md
  gt modify -m "feat(fix): integrate fixes in status board and update documentation"
  ```

---

## Self-review (run before handing back)

- [x] **Spec coverage** — every spec requirement maps to a task above.
- [x] **AC coverage** — each spec §7 acceptance criterion maps to a test.
- [x] **No placeholders** — no TBD/TODO; complete details in every step.
- [x] **Type consistency** — paths and formats match.
