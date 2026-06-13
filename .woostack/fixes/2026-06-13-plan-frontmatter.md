---
type: fix
status: in-review
branch: fix/plan-frontmatter
---

# Fix: Track spec and plan lifecycle separately

## 1. Root Cause

The old feature-state contract put the whole build lifecycle on spec frontmatter and required plans
to stay frontmatter-free. That made `/woostack-status` simple, but it mixed two different states:

- specs answer whether the design has been written, hardened, and approved;
- plans answer whether implementation is planned, ready, executing, in review, or done.

This also blocked Obsidian from exposing plan properties and made the new `woostack-doctor`
spec-plan checks depend only on the markdown `**Source:**` line.

PR 342 adds `woostack-doctor`, including a spec-plan backlink check that reuses the existing
`**Source:**` contract. The fix must preserve that line exactly while adding plan frontmatter.

## 2. Proposed Fix

Split lifecycle ownership:

- Spec frontmatter owns design approval: `draft`, `hardened`, `approved`, `abandoned`.
- Plan frontmatter owns implementation state: `planning`, `ready`, `executing`, `in-review`,
  `done`, `abandoned`.
- `/woostack-status` continues to show one row per spec/fix. Before a plan exists it reads spec
  `status:`/`branch:`; after a plan resolves, it reads plan `status:`/`branch:`.
- Plans start with Obsidian YAML properties and then keep the canonical join line:
  ```yaml
  ---
  type: plan
  source: .woostack/specs/<spec>.md
  status: planning
  branch: feature/<slug>
  ---

  **Source:** .woostack/specs/<spec>.md
  ```

Stack this fix on PR 342 (`feature/woostack-doctor-7-surface`) so the doctor skill and its
spec-plan checks are present in the base.

## 3. Implementation Plan

- [x] **Step 1: Reproduce with failing contract checks**
  - Run `skills/woostack-status/scripts/tests/run-tests.sh` after switching status to plan-owned
    lifecycle.
  - Expected before fixture updates: existing tests fail because plan fixtures default to
    `planning` while old assertions expect spec-owned `ready`, `executing`, and `done`.

- [x] **Step 2: Stack on PR 342**
  - Fetch `feature/woostack-doctor-7-surface`.
  - Rebase `fix/plan-frontmatter` onto it.
  - Run `gt track --parent feature/woostack-doctor-7-surface`.

- [x] **Step 3: Update `/woostack-status` behavior and tests**
  - Teach `status.sh` to read spec lifecycle before a plan exists and plan lifecycle after a plan
    resolves.
  - Update status fixtures so generated plans carry `type`, `source`, `status`, and `branch`.
  - Verification: `skills/woostack-status/scripts/tests/run-tests.sh`.

- [x] **Step 4: Update contracts and skill guidance**
  - Update `woostack-status` conventions for split lifecycle and doctor-compatible plan joins.
  - Update `woostack-plan` and its template to generate plan frontmatter.
  - Update `woostack-build`, `using-woostack`, and `woostack-commit` wording so status/branch
    ownership is no longer spec-only.

- [x] **Step 5: Migrate tracked plans**
  - Add plan frontmatter to tracked `.woostack/plans/*.md` files.
  - Preserve every existing `**Source:**` line exactly.
  - For legacy plans without a source line, use the same-basename spec when it exists; otherwise
    leave them untouched and let `woostack-doctor` report the pre-existing convention gap.

- [x] **Step 6: Verify doctor compatibility**
  - Run `skills/woostack-status/scripts/tests/run-tests.sh`.
  - Run `skills/woostack-doctor/scripts/tests/test-spec-plan-backlink.sh`.
  - Run `bash skills/woostack-doctor/scripts/doctor.sh . --check`.
  - Run contract scans for stale `frontmatter-free` wording.
