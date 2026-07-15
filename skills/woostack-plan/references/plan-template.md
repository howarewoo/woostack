---
type: plan
source: .woostack/specs/{{SPEC_BASENAME}}.md
status: planning
branch: {{FEATURE_BRANCH}}
---

**Source:** [[specs/{{SPEC_BASENAME}}]]

> **Normalized backend input:** one resolved spec identity, content, revision, and backend.
> Markdown emits this file unchanged; Linear maps each `## Increment` to one managed issue and
> carries its stable identity, explicit ordinal, dependencies, and Git parent in adapter input.
> Linear also carries the captured preflight `team.id`, project-status UUID map, and issue-state
> UUID map as run context; configured lifecycle names are never reconciliation inputs.

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
- **Angle coverage** - the plan lens of `skills/woostack-harden/references/angle-preflight.md` is
  walked: architecture, tests-per-AC, security/observability addressed by tasks (skip rule keeps
  untouched angles silent).

## Backend output contract

- **Markdown:** preserve this file's `type: plan` frontmatter, path, reciprocal
  `**Source:** [[specs/{{SPEC_BASENAME}}]]` join, status, branch, headings, and checkboxes.
- **Linear:** do not persist this file. Reconcile one issue per increment through the shared
  adapter, with stable ID, unique ordinal, native blocked-by relations, mirrored dependencies,
  one representable Git parent, complete issue content, and verified read-back.

This file starts with YAML frontmatter for Obsidian properties, then preserves the `**Source:**`
line — an Obsidian `[[specs/<basename>]]` wikilink, symmetric with the spec's
`> **Plan:** [[plans/<basename>]]` callout — as the canonical spec -> plan join used by
`/woostack-status` and `woostack-doctor`. (The legacy bare-path form
`**Source:** .woostack/specs/<basename>.md` is still accepted by both readers.)

> Filename mirrors spec basename: `.woostack/plans/<spec-basename>.md`.

**No required-sub-skill banner.** Plans are executable by `woostack-execute` directly. In this
skills repo, a "failing test" step can be a concrete verification command such as `grep`,
`bash -n`, an existing test, or a `python3 -c` parser check with exact expected output.
