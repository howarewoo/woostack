**Source:** .woostack/specs/2026-06-06-spec-acceptance-criteria.md

# Structured Acceptance Criteria in the spec template — Implementation Plan

**Goal:** Add a structured §7 Acceptance criteria section to the spec template (happy/error/edge per behavior) and wire plan self-review to gate that breadth into TDD tasks — fixed at the spec, gated at the plan, execute and harden untouched.

**Architecture:** Two stacked increments. Increment 1 edits the spec template pair (`spec-template.md` + `spec-template.html`) to add §7 and renumber the trailing sections — independently shippable (authors get the section immediately). Increment 2 stacks on it and wires the plan self-review gate (`woostack-plan/SKILL.md` + `plan-template.md`) that references the new §7. No application code; this is a skills-collection docs change.

**Tech Stack:** Markdown + HTML skill assets. No test runner (per AGENTS.md), so every "failing test" is a concrete `grep`/structural verification command with exact expected output.

---

## Increment 1: Spec template gains §7 Acceptance criteria

> One independently shippable PR — its own Graphite-stacked branch on the spec+plan base. Adds §7 to the markdown template and its HTML mirror, renumbering Testing→§8 and Open questions→§9.

### Task 1: Add §7 to `spec-template.md` and renumber

**Files:**
- Modify: `skills/woostack-build/references/spec-template.md:36-47`
- Test: shell `grep` (no runner in this repo)

- [x] **Step 1: Write the failing test**

```bash
# Asserts §7 AC exists with all three slots, the instruction line, and that
# Testing/Open questions are renumbered to §8/§9 (and the old §7 Testing is gone).
test_md() {
  f=skills/woostack-build/references/spec-template.md
  grep -q '^## 7. Acceptance criteria$' "$f" \
  && grep -q '^Each AC is a testable behavior' "$f" \
  && grep -q '^  - happy: {{expected}}$' "$f" \
  && grep -q '^  - error: {{expected}}$' "$f" \
  && grep -q '^  - edge: {{expected}}$' "$f" \
  && grep -q '^## 8. Testing$' "$f" \
  && grep -q '^## 9. Open questions$' "$f" \
  && ! grep -q '^## 7. Testing$' "$f" \
  && ! grep -q '^## 8. Open questions$' "$f" \
  && echo PASS || echo FAIL
}
test_md
```

- [x] **Step 2: Run the test, confirm it fails**

Run: paste and run the Step 1 block (it defines the check and calls it on the last line).
Expected: FAIL — current file still has `## 7. Testing` / `## 8. Open questions` and no `## 7. Acceptance criteria`, so the block prints `FAIL`.

- [x] **Step 3: Minimal implementation**

Replace the current sections 6–8 of `skills/woostack-build/references/spec-template.md`:

```markdown
## 6. Error handling

{{ERRORS}}

## 7. Testing

{{TESTING}}

## 8. Open questions

{{OPEN_QUESTIONS}}
```

with:

```markdown
## 6. Error handling

{{ERRORS}}

## 7. Acceptance criteria

Each AC is a testable behavior → ≥1 plan task. Fill every class or mark `N/A — <reason>`; mark the whole section `N/A — <why no testable behavior>` only when the spec has no testable behavior.

- **AC1 — {{behavior}}**
  - happy: {{expected}}
  - error: {{expected}}
  - edge: {{expected}}
- **AC2 — {{behavior}}**
  - happy: {{expected}}
  - error: {{expected}}
  - edge: {{expected}}

## 8. Testing

> Strategy only — harness, test levels, fixtures, CI. Per-behavior cases live in §7.

{{TESTING}}

## 9. Open questions

{{OPEN_QUESTIONS}}
```

- [x] **Step 4: Run the test, confirm it passes**

Run: re-run the Step 1 block (after the edit).
Expected: PASS — prints `PASS`.

### Task 2: Mirror §7 in `spec-template.html` and renumber

**Files:**
- Modify: `skills/woostack-build/references/spec-template.html:31-33`
- Test: shell `grep` + a structural parity check against the markdown

- [x] **Step 1: Write the failing test**

```bash
# (a) HTML carries the §7 AC panel + renumbered §8/§9; (b) the ordered section
# list of the HTML matches the markdown exactly (AC2: md/html stay 1:1).
test_html() {
  h=skills/woostack-build/references/spec-template.html
  m=skills/woostack-build/references/spec-template.md
  grep -q '<h2>7. Acceptance criteria</h2><div class="panel">{{ACCEPTANCE_CRITERIA}}</div>' "$h" \
  && grep -q '<h2>8. Testing</h2>' "$h" \
  && grep -q '<h2>9. Open questions</h2>' "$h" \
  && ! grep -q '<h2>7. Testing</h2>' "$h" \
  && diff <(grep -oE '<h2>[0-9]+\. [^<]+' "$h" | sed 's#<h2>##; s/&amp;/\&/g') \
          <(grep -oE '^## [0-9]+\. .+' "$m" | sed 's/^## //') >/dev/null \
  && echo PASS || echo FAIL
}
test_html
```

- [x] **Step 2: Run the test, confirm it fails**

Run: paste and run the Step 1 block.
Expected: FAIL — HTML still has `<h2>7. Testing</h2>`, no AC panel, and its heading list differs from the (already-updated) markdown; prints `FAIL`.

- [x] **Step 3: Minimal implementation**

Replace these three lines in `skills/woostack-build/references/spec-template.html`:

```html
  <h2>6. Error handling</h2><div class="panel">{{ERRORS}}</div>
  <h2>7. Testing</h2><div class="panel">{{TESTING}}</div>
  <h2>8. Open questions</h2><div class="panel">{{OPEN_QUESTIONS}}</div>
```

with:

```html
  <h2>6. Error handling</h2><div class="panel">{{ERRORS}}</div>
  <h2>7. Acceptance criteria</h2><div class="panel">{{ACCEPTANCE_CRITERIA}}</div>
  <h2>8. Testing</h2><div class="panel">{{TESTING}}</div>
  <h2>9. Open questions</h2><div class="panel">{{OPEN_QUESTIONS}}</div>
```

- [x] **Step 4: Run the test, confirm it passes**

Run: re-run the Step 1 block (after the edit).
Expected: PASS — the AC panel is present, §8/§9 renumbered, and the md/html heading lists are identical (empty `diff`); prints `PASS`.

- [x] **Step 5: Commit the increment**

Single `woostack-commit` for Increment 1 (its own Graphite branch on the spec+plan base):

```bash
# first commit in this increment:
gt create -m "feat(woostack-build): add §7 Acceptance criteria to the spec template"
```

---

## Increment 2: Plan self-review gates AC → task → test breadth

> One independently shippable PR, stacked on Increment 1 (it references the §7 the template now defines). Wires the plan-side gate: the self-review engine and the plan template's checklist.

### Task 3: Wire AC coverage into `woostack-plan/SKILL.md`

**Files:**
- Modify: `skills/woostack-plan/SKILL.md:104` (cross-ref the banned phrase to §7)
- Modify: `skills/woostack-plan/SKILL.md:131` (extend self-review step 1 with AC coverage + N/A sanity check)
- Test: shell `grep`

- [ ] **Step 1: Write the failing test**

```bash
test_plan_skill() {
  f=skills/woostack-plan/SKILL.md
  grep -q '\*\*AC coverage:\*\*' "$f" \
  && grep -q 'no behavioral requirement' "$f" \
  && grep -q 'belong in the spec.s §7 Acceptance criteria' "$f" \
  && echo PASS || echo FAIL
}
test_plan_skill
```

- [ ] **Step 2: Run the test, confirm it fails**

Run: paste and run the Step 1 block.
Expected: FAIL — none of the AC-coverage / N/A / §7 cross-ref strings exist yet; prints `FAIL`.

- [ ] **Step 3: Minimal implementation**

(a) Replace line 104 in `skills/woostack-plan/SKILL.md`:

```markdown
- "Add error handling" / "add validation" / "handle edge cases"
```

with:

```markdown
- "Add error handling" / "add validation" / "handle edge cases" — write the actual test instead; error and edge cases belong in the spec's §7 Acceptance criteria, enumerated there as happy/error/edge
```

(b) Replace the self-review step 1 (line 131):

```markdown
1. **Spec coverage** — every section/requirement maps to a task. List and fill any gap.
```

with:

```markdown
1. **Spec coverage** — every section/requirement maps to a task. List and fill any gap.
   **AC coverage:** when the spec's §7 Acceptance criteria lists ACs, every AC — and each
   filled (non-N/A) happy/error/edge case — maps to a task/test; when §7 is whole-section
   `N/A`, confirm the spec body has no behavioral requirement (else flag the `N/A` as suspect).
```

- [ ] **Step 4: Run the test, confirm it passes**

Run: re-run the Step 1 block (after the edits).
Expected: PASS — all three strings present; prints `PASS`.

### Task 4: Add the AC coverage line to `plan-template.md`

**Files:**
- Modify: `skills/woostack-plan/references/plan-template.md:61` (self-review checklist)
- Test: shell `grep`

- [ ] **Step 1: Write the failing test**

```bash
test_plan_template() {
  f=skills/woostack-plan/references/plan-template.md
  grep -q '^- \[ \] \*\*AC coverage\*\*' "$f" \
  && grep -q 'happy/error/edge' "$f" \
  && echo PASS || echo FAIL
}
test_plan_template
```

- [ ] **Step 2: Run the test, confirm it fails**

Run: paste and run the Step 1 block.
Expected: FAIL — no `AC coverage` checklist item yet; prints `FAIL`.

- [ ] **Step 3: Minimal implementation**

In `skills/woostack-plan/references/plan-template.md`, insert one checklist item after the **Spec coverage** line. Replace:

```markdown
- [ ] **Spec coverage** — every spec requirement maps to a task above.
- [ ] **No placeholders** — no TBD/TODO; complete code, exact commands, and expected output in every step.
```

with:

```markdown
- [ ] **Spec coverage** — every spec requirement maps to a task above.
- [ ] **AC coverage** — each spec §7 acceptance criterion (and its filled happy/error/edge cases) maps to a test; a whole-section `N/A` is sanity-checked against the spec body.
- [ ] **No placeholders** — no TBD/TODO; complete code, exact commands, and expected output in every step.
```

- [ ] **Step 4: Run the test, confirm it passes**

Run: re-run the Step 1 block (after the edit).
Expected: PASS — the `AC coverage` checklist item is present; prints `PASS`.

- [ ] **Step 5: Commit the increment**

Single `woostack-commit` for Increment 2 (stacked on Increment 1):

```bash
# first commit in this increment:
gt create -m "feat(woostack-plan): gate §7 acceptance-criteria breadth in self-review"
```

---

## Self-review (run before handing back)

- [ ] **Spec coverage** — every spec requirement maps to a task above.
  - AC1 (template exposes §7 scaffold) → Task 1.
  - AC2 (md/html 1:1) → Task 2 (incl. the `diff` parity check).
  - AC3 (plan self-review gates breadth) → Tasks 3 + 4.
  - AC4 (existing plan rules coherent) → Task 3 part (a), the `:104` cross-ref.
- [ ] **AC coverage** — each spec §7 acceptance criterion (and its filled happy/error/edge cases) maps to a test; a whole-section `N/A` is sanity-checked against the spec body.
  - happy cases → the `grep`-PASS assertions in each task; edge (N/A handling, md/html parity) → the parity `diff` and the negated `! grep` renumber checks; error cases for AC1/AC4 are spec-marked N/A (static docs), so no test owed.
- [ ] **No placeholders** — no TBD/TODO; every step has exact paths, complete before/after blocks, and exact expected output.
- [ ] **Type consistency** — the token `{{ACCEPTANCE_CRITERIA}}` (html) and the section names §7/§8/§9 are used identically across both template files and both plan files.

> woostack plan conventions (keep them):
> - This file is **frontmatter-free** and **opens with** the `**Source:**` line.
> - Filename mirrors the spec basename: `.woostack/plans/2026-06-06-spec-acceptance-criteria.md`.
> - **No** required sub-skill banner — execution is `woostack-execute`'s (woostack-build step 8, or `/woostack-execute <plan>`).
> - No test runner in this repo, so each "failing test" is a concrete `grep`/`diff` verification with exact expected output.
