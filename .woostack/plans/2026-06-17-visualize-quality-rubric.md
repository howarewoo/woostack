---
type: plan
source: .woostack/specs/2026-06-17-visualize-quality-rubric.md
status: done
branch: feature/visualize-quality-rubric
---

**Source:** [[specs/2026-06-17-visualize-quality-rubric]]

# woostack-visualize Quality Rubric Implementation Plan

**Goal:** Teach `woostack-visualize` to produce better source-grounded offline HTML renders by adding when-to-visualize guidance, a local primitives palette, and high-stakes self-review while preserving the disposable render contract.

**Architecture:** This is one docs-only skill update. `SKILL.md` owns the command procedure, including the decision gate, source research bar, primitive-selection step, and inline self-review. `references/primitives.md` owns the reusable offline section palette; `references/audiences.md` remains unchanged so audience policy does not duplicate primitive definitions.

**Tech Stack:** Markdown skill files, `rg` structural checks, Git/Graphite.

## Increment 1: Add visualize quality rubric and primitives reference

> One independently shippable PR (<=500 LOC soft target) -- its own Graphite-stacked branch.

### Task 1: Strengthen `woostack-visualize` procedure

**Files:**
- Modify: `skills/woostack-visualize/SKILL.md`

**Step 1: Write the failing structural checks**

Run:

```bash
for p in "When to visualize" "Research before composing" "Choose visual primitives" "High-stakes self-review"; do
  rg -n "$p" skills/woostack-visualize/SKILL.md >/dev/null || exit 1
done
```

Expected: FAIL - `rg` exits 1 because the current skill does not contain those procedure anchors.

**Step 2: Minimal implementation**

Edit `skills/woostack-visualize/SKILL.md` to:

- add a "When to visualize" section before the existing procedure, recommending visual output for comparison, approval, relationship mapping, architecture/state review, and multi-file/code/data inspection, while telling agents to skip trivial or clearer-as-text cases;
- expand "Resolve input" into "Research before composing" guidance that requires real files, directories, symbols, source sections, data shapes, and existing helpers where relevant;
- add a step that chooses primitives from `references/primitives.md` after resolving the audience;
- add an inline "High-stakes self-review" checklist for architecture, backend, data-model, migration, security, multi-file, or public-contract renders;
- preserve the existing command shape, write path, no-browser-without-consent rule, self-contained offline rule, and disposable source-of-truth rule.

**Step 3: Run the structural checks, confirm they pass**

Run:

```bash
for p in "When to visualize" "Research before composing" "Choose visual primitives" "High-stakes self-review"; do
  rg -n "$p" skills/woostack-visualize/SKILL.md >/dev/null || exit 1
done
```

Expected: PASS - each anchor appears in `SKILL.md`.

### Task 2: Add offline visual primitives reference

**Files:**
- Create: `skills/woostack-visualize/references/primitives.md`
- Modify: `skills/woostack-visualize/SKILL.md`

**Step 1: Write the failing structural checks**

Run:

```bash
test -f skills/woostack-visualize/references/primitives.md &&
for p in "source summary" "file map" "annotated code" "before/after" "API/data contract" "state matrix" "flow diagram" "decision table" "risk register" "open questions"; do
  rg -n "$p" skills/woostack-visualize/references/primitives.md >/dev/null || exit 1
done
```

Expected: FAIL - the file does not exist yet.

**Step 2: Minimal implementation**

Create `skills/woostack-visualize/references/primitives.md` with a concise palette. For each primitive, document:

- when to use it;
- what source evidence is required;
- what to omit or mark unknown when unsupported.

Include at least: source summary, file map, annotated code, diff/before-after panel, API/data contract, state matrix, flow diagram, decision table, risk register, and open questions.

Update `SKILL.md` to link `references/primitives.md` from the primitive-selection step. Keep `audiences.md` unchanged.

**Step 3: Run the structural checks, confirm they pass**

Run:

```bash
test -f skills/woostack-visualize/references/primitives.md &&
for p in "source summary" "file map" "annotated code" "before/after" "API/data contract" "state matrix" "flow diagram" "decision table" "risk register" "open questions"; do
  rg -n "$p" skills/woostack-visualize/references/primitives.md >/dev/null || exit 1
done
```

Expected: PASS - the file exists and every required primitive phrase is present.

### Task 3: Verify offline/disposable boundaries and unchanged audience file

**Files:**
- Modify: `skills/woostack-visualize/SKILL.md`
- Create: `skills/woostack-visualize/references/primitives.md`

**Step 1: Write the boundary checks before finalizing**

Run:

```bash
for p in "self-contained" "offline" "disposable render" "source of truth" "No browser without consent"; do
  rg -n "$p" skills/woostack-visualize/SKILL.md >/dev/null || exit 1
done &&
! rg -n "Agent-Native|Plan MCP|MCP connector|auth/reconnect|feedback API|publish flow|export receipt|lockfile|build step|CI workflow" skills/woostack-visualize &&
git diff --exit-code -- skills/woostack-visualize/references/audiences.md
```

Expected: PASS - the original offline/disposable constraints remain, conflicting BuilderIO workflow terms are absent, and `audiences.md` has no diff.

**Step 2: If the check fails, make the minimal correction**

- Restore or reword the original offline/disposable constraints in `SKILL.md`.
- Remove any hosted Plan/MCP/auth/publish/export workflow language.
- Revert any accidental `audiences.md` change.

**Step 3: Run the boundary checks again**

Run:

```bash
for p in "self-contained" "offline" "disposable render" "source of truth" "No browser without consent"; do
  rg -n "$p" skills/woostack-visualize/SKILL.md >/dev/null || exit 1
done &&
! rg -n "Agent-Native|Plan MCP|MCP connector|auth/reconnect|feedback API|publish flow|export receipt|lockfile|build step|CI workflow" skills/woostack-visualize &&
git diff --exit-code -- skills/woostack-visualize/references/audiences.md
```

Expected: PASS.

**Step 4: Commit the implementation increment**

Run:

```bash
gt create -m "docs: strengthen visualize quality rubric"
```

Expected: PASS - Graphite creates the implementation branch stacked on the spec+plan PR when execution runs.

## Self-review checklist

- **Spec coverage:** AC1 maps to Task 1; AC2 maps to Task 1; AC3 maps to Task 2; AC4 maps to Task 1; AC5 maps to Task 3.
- **AC coverage:** Each acceptance criterion has an explicit structural check or no-diff boundary check.
- **No placeholders:** All commands and expected outcomes are concrete.
- **Type consistency:** This is a Markdown-only skill collection change; no code types or runtime APIs are involved.
