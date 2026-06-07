**Source:** .woostack/specs/{{SPEC_BASENAME}}.md

# {{FEATURE_NAME}} Implementation Plan

**Goal:** {{ONE_SENTENCE_WHAT_THIS_BUILDS}}

**Architecture:** {{TWO_OR_THREE_SENTENCES_ON_THE_APPROACH}}

**Tech Stack:** {{KEY_TECHNOLOGIES}}

---

## Increment 1: {{PR_SIZED_SLICE_NAME}}

> One independently shippable PR (≤500 LOC soft target) — its own Graphite-stacked branch.

### Task 1: {{COMPONENT_NAME}}

**Files:**
- Create: `{{exact/path/to/new.ext}}`
- Modify: `{{exact/path/to/existing.ext}}:{{LINES}}`
- Test: `{{exact/path/to/test.ext}}`

- [ ] **Step 1: Write the failing test**

```{{lang}}
{{actual test code — never a placeholder}}
```

- [ ] **Step 2: Run the test, confirm it fails**

Run: `{{exact command}}`
Expected: FAIL — `{{exact expected failure}}`

- [ ] **Step 3: Minimal implementation**

```{{lang}}
{{actual implementation code}}
```

- [ ] **Step 4: Run the test, confirm it passes**

Run: `{{exact command}}`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
# first commit in this increment:
gt create -m "{{type}}: {{subject}}"
# later commits in the same increment:
gt modify -c -m "{{type}}: {{subject}}"
```

<!-- Repeat Task N for each unit in this increment. Add Increment 2, 3, … for each PR-sized slice. -->

---

## Self-review (run before handing back)

- [ ] **Spec coverage** — every spec requirement maps to a task above.
- [ ] **AC coverage** — each spec §7 acceptance criterion (and its filled happy/error/edge cases) maps to a test; a whole-section `N/A` is sanity-checked against the spec body.
- [ ] **No placeholders** — no TBD/TODO; complete code, exact commands, and expected output in every step.
- [ ] **Type consistency** — types, signatures, and names match across tasks.

> woostack plan conventions (keep them):
> - This file is **frontmatter-free** and **opens with** the `**Source:**` line.
> - Filename mirrors the spec basename: `.woostack/plans/<spec-basename>.md` (the spec's date, not today's).
> - **No** required sub-skill banner — execution is `woostack-execute`'s (woostack-build step 8, or `/woostack-execute <plan>`).
> - In a target without a test runner, a "failing test" step is a concrete verification command (grep, `bash -n`, an existing test) with exact expected output.
