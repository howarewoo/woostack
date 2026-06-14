---
type: plan
source: .woostack/specs/{{SPEC_BASENAME}}.md
status: planning
branch: {{FEATURE_BRANCH}}
---

**Source:** .woostack/specs/{{SPEC_BASENAME}}.md

# {{FEATURE_NAME}} Implementation Plan

**Goal:** {{ONE_SENTENCE_WHAT_THIS_BUILDS}}

**Architecture:** {{TWO_OR_THREE_SENTENCES_ON_THE_APPROACH}}

**Tech Stack:** {{KEY_TECHNOLOGIES}}

## Increment 1: {{PR_SIZED_SLICE_NAME}}

> One independently shippable PR (<=500 LOC soft target) -- its own Graphite-stacked branch.

### Task 1: {{COMPONENT_NAME}}

**Files:**
- Create: `{{exact/path/to/new.ext}}`
- Modify: `{{exact/path/to/existing.ext}}:{{LINES}}`
- Test: `{{exact/path/to/test.ext}}`

- [ ] **Step 1: Write the failing test**
  ```{{lang}}
  {{actual test code - never a placeholder}}
  ```

- [ ] **Step 2: Run the test, confirm it fails**
  Run: `{{exact command}}`
  Expected: FAIL - `{{exact expected failure}}`

- [ ] **Step 3: Minimal implementation**
  ```{{lang}}
  {{actual implementation code}}
  ```

- [ ] **Step 4: Run the test, confirm it passes**
  Run: `{{exact command}}`
  Expected: PASS

- [ ] **Step 5: Commit**
  ```bash
  # First commit in the increment:
  gt create -m "{{type}}: {{subject}}"

  # Later commits in the same increment:
  gt modify -c -m "{{type}}: {{subject}}"
  ```

## Plan Checks

- **Spec coverage** - every spec requirement maps to a task.
- **AC coverage** - each spec section 7 acceptance criterion maps to a test; a `N/A` is
  sanity-checked against the spec body.
- **No placeholders** - no TBD/TODO; complete code, exact commands, and expected output.
- **Type consistency** - types, signatures, and names match the current codebase.

This file starts with YAML frontmatter for Obsidian properties, then preserves the `**Source:**`
line as the canonical spec -> plan join used by `/woostack-status` and `woostack-doctor`.

> Filename mirrors spec basename: `.woostack/plans/<spec-basename>.md`.

**No required-sub-skill banner.** Plans are executable by `woostack-execute` directly. In this
skills repo, a "failing test" step can be a concrete verification command such as `grep`,
`bash -n`, an existing test, or a `python3 -c` parser check with exact expected output.
