**Source:** .woostack/specs/2026-06-09-readme-rewrite.md

# README Rewrite Implementation Plan

**Goal:** Completely rewrite the repository README.md to be clean, modern, and aligned with current woostack rules (installation, initialization, core loops, and memory system).

**Architecture:** Replace the verbose and deprecated contents of README.md with the newly designed sections. Verification is done using direct grep checks to ensure correct phrasing, command patterns, and the exclusion of deprecated components like the flat shard.

**Tech Stack:** Markdown

---

## Increment 1: Rewrite README.md

> One independently shippable PR (≤500 LOC soft target) — its own Graphite-stacked branch.

### Task 1: Rewrite README.md and Update AGENTS.md

**Files:**
- Modify: `README.md`
- Modify: `AGENTS.md`

- [x] **Step 1: Write the failing test**

We write a grep command checking that the deprecated `memory.md` file is NOT mentioned in `README.md`, which currently fails because it is referenced in multiple places in the existing file. We also verify that `AGENTS.md` does not use the deprecated `npx skills add` installation command.

```bash
# Verify that the deprecated flat shard "memory.md" is not referenced in README.md
grep -i "memory.md" README.md

# Verify that AGENTS.md does not use "npx skills add"
grep -F "npx skills add" AGENTS.md
```

- [x] **Step 2: Run the test, confirm it fails**

Run: `grep -i "memory.md" README.md; grep -F "npx skills add" AGENTS.md`
Expected: Exits 0 (finds matches for both, indicating they are still in the legacy state).

- [x] **Step 3: Minimal implementation**

Write the new contents of `README.md` containing the updated sections, and edit line 14 of `AGENTS.md` to change `npx skills add` to `pnpx skills add`.

- [x] **Step 4: Run the test, confirm it passes**

Run: `grep -E '(\.woostack/memory\.md|`memory\.md`)' README.md`
Expected: Exits 1 (no flat shard file references found).

Run: `grep -E '\bnpx skills add' AGENTS.md`
Expected: Exits 1 (no legacy installation command prefix found).

Run: `grep -F "pnpx skills add" AGENTS.md && grep -F "pnpx skills add" README.md`
Expected: Exits 0 (both files correctly use the new `pnpx` command).

- [x] **Step 5: Commit**

```bash
gt create -m "docs: rewrite repo readme and update agents.md install command"
```

---

## Self-review (run before handing back)

- [x] **Spec coverage** — every spec requirement maps to a task above.
- [x] **AC coverage** — each spec §7 acceptance criterion (and its filled happy/error/edge cases) maps to a test; a whole-section `N/A` is sanity-checked against the spec body.
- [x] **No placeholders** — no TBD/TODO; complete code, exact commands, and expected output in every step.
- [x] **Type consistency** — types, signatures, and names match across tasks.

> woostack plan conventions (keep them):
> - This file is **frontmatter-free** and **opens with** the `**Source:**` line.
> - Filename mirrors the spec basename: `.woostack/plans/<spec-basename>.md` (the spec's date, not today's).
> - **No** required sub-skill banner — execution is `woostack-execute`'s (woostack-build step 8, or `/woostack-execute <plan>`).
> - In a target without a test runner, a "failing test" step is a concrete verification command (grep, `bash -n`, an existing test) with exact expected output.
