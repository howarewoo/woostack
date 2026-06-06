**Source:** .woostack/specs/2026-06-06-commit-memory-changes.md

# Commit memory changes unless gitignored — Implementation Plan

**Goal:** Make `woostack-commit` always stage non-gitignored `.woostack/memory/` changes, and make `woostack-execute` sweep pending memory whenever it hands control back, so distilled knowledge always reaches a PR.

**Architecture:** Two skill-markdown edits, shipped as stacked PRs. Increment 1 adds an always-stage carve-out to `woostack-commit` step 4 (a directory-guarded `git add .woostack/memory/` that relies on `.gitignore` for the "unless gitignored" boundary). Increment 2 adds a single "memory sweep on handback" rule to `woostack-execute`, referenced from both the terminal state and the blocking-stop section; it invokes `woostack-commit`, so it depends on Increment 1 and stacks on top of it.

**Tech Stack:** Markdown skill docs only. No application code, no test runner in this repo — verification is `grep`/`bash -n` with exact expected output.

---

## Increment 1: woostack-commit always-stages `.woostack/memory/`

> One independently shippable PR — its own Graphite-stacked branch. Fixes the reported symptom on its own.

### Task 1: Add the memory carve-out to `woostack-commit` step 4

**Files:**
- Modify: `skills/woostack-commit/SKILL.md` (§4 "Stage only session-relevant changes", around lines 117-131)

- [ ] **Step 1: Write the failing test (verification command)**

The marker text the edit introduces does not yet exist. Capture that as the failing check:

```bash
grep -c 'Always stage `.woostack/memory/` changes' skills/woostack-commit/SKILL.md
```

- [ ] **Step 2: Run it, confirm it fails**

Run: `grep -c 'Always stage `.woostack/memory/` changes' skills/woostack-commit/SKILL.md`
Expected: FAIL — prints `0` and exits non-zero (marker absent).

- [ ] **Step 3: Minimal implementation**

In `skills/woostack-commit/SKILL.md`, insert the carve-out into §4 immediately after the `git add -p <file>` fenced block and before the `Do not stage generated files…` line. Insert exactly:

```markdown
**Always stage `.woostack/memory/` changes.** Distilled memory notes are session work by
definition in the woostack loop — never "unrelated dirty files." Stage every non-ignored
change under `.woostack/memory/` (modifications, additions, and the note deletions distill's
dedupe makes), folded into the same commit as the code, with no relevance check and no
stop-and-ask:

```bash
[ -d .woostack/memory ] && git add .woostack/memory/
```

Plain `git add` (never `-f`) honors `.gitignore`, so ignored paths such as
`.woostack/memory/metrics.json` and `*.local.*` are skipped automatically — "unless
gitignored" needs no `git check-ignore` step. The `[ -d … ]` guard makes this a silent no-op
outside a woostack repo, where a bare `git add` of an absent path would exit non-zero with
`fatal: pathspec '.woostack/memory/' did not match any files`.
```

Then change the existing exclusion line so it no longer reads as excluding memory. Replace:

```markdown
Do not stage generated files, secrets, `.env*`, unrelated dirty files, or user work from outside this session.
```

with:

```markdown
Do not stage generated files, secrets, `.env*`, unrelated dirty files, or user work from outside this session — the `.woostack/memory/` rule above is the sole exception to "unrelated dirty files."
```

- [ ] **Step 4: Run the verification, confirm it passes**

Run: `grep -c 'Always stage `.woostack/memory/` changes' skills/woostack-commit/SKILL.md`
Expected: PASS — prints `1`.

- [ ] **Step 5: Confirm the embedded command is syntactically valid and the exclusion carve-out landed**

Run:
```bash
bash -nc '[ -d .woostack/memory ] && git add .woostack/memory/' && echo SYNTAX_OK
grep -c 'sole exception to "unrelated dirty files"' skills/woostack-commit/SKILL.md
```
Expected: prints `SYNTAX_OK`, then `1`.

- [ ] **Step 6: Commit**

```bash
# first commit in this increment:
gt create -m "fix(woostack-commit): always stage .woostack/memory/ unless gitignored"
```

---

## Increment 2: woostack-execute sweeps memory on handback

> Stacks on Increment 1 (the sweep calls `woostack-commit`, which now stages memory). One independently shippable PR.

### Task 1: Add the "memory sweep on handback" rule to `woostack-execute`

**Files:**
- Modify: `skills/woostack-execute/SKILL.md` (new subsection after "Terminal state: a reviewed stack"; reference lines in that section and in "When to stop and ask")

- [ ] **Step 1: Write the failing test (verification command)**

```bash
grep -c '## Memory sweep on handback' skills/woostack-execute/SKILL.md
```

- [ ] **Step 2: Run it, confirm it fails**

Run: `grep -c '## Memory sweep on handback' skills/woostack-execute/SKILL.md`
Expected: FAIL — prints `0` and exits non-zero.

- [ ] **Step 3: Minimal implementation — add the dedicated rule section**

In `skills/woostack-execute/SKILL.md`, insert this new section immediately after the "Terminal state: a reviewed stack" paragraph (the one ending `**Never merge.**`) and before `## When to stop and ask`. Insert exactly:

```markdown
## Memory sweep on handback

Before this skill yields control back **for any reason** — the reviewed-stack terminal state
above, or any blocking stop in [When to stop and ask](#when-to-stop-and-ask) — sweep any
distilled memory so it is never stranded. If `.woostack/memory/` has non-ignored uncommitted
changes, run one final [`woostack-commit`](../woostack-commit/SKILL.md) on the current
increment's branch; it stages `.woostack/memory/` for you. This is necessarily a memory-only
commit when the increment's code is already committed and reviewed. Skip it when memory is
clean — never create an empty commit. Intermediate increments need nothing extra: increment
N's distilled memory is swept by increment N+1's commit.
```

- [ ] **Step 4: Run the verification, confirm it passes**

Run: `grep -c '## Memory sweep on handback' skills/woostack-execute/SKILL.md`
Expected: PASS — prints `1`.

### Task 2: Reference the sweep from the terminal state and the blocking-stop section

**Files:**
- Modify: `skills/woostack-execute/SKILL.md` ("Terminal state: a reviewed stack" paragraph; "When to stop and ask" section)

- [ ] **Step 1: Write the failing test (verification command)**

```bash
grep -c '(#memory-sweep-on-handback)' skills/woostack-execute/SKILL.md
```

- [ ] **Step 2: Run it, confirm it fails**

Run: `grep -c '(#memory-sweep-on-handback)' skills/woostack-execute/SKILL.md`
Expected: FAIL — prints `0` (only the heading exists so far; no in-text links to its anchor).

- [ ] **Step 3: Minimal implementation — add the two reference pointers**

In the "Terminal state: a reviewed stack" paragraph, replace (exact text, including the line break between `or` and `mode`):

```markdown
Report the branches/PRs and their review verdicts or
mode. **Never merge.**
```

with:

```markdown
Run the [memory sweep on handback](#memory-sweep-on-handback) first, then report the
branches/PRs and their review verdicts or mode. **Never merge.**
```

In the "When to stop and ask" section, replace the closing line:

```markdown
Return to the plan-review step if the plan is updated or the approach needs rethinking.
```

with:

```markdown
On every stop above, run the [memory sweep on handback](#memory-sweep-on-handback) before
surfacing the stop, so a mid-run distill (e.g. a `woostack-debug` detour) is never stranded.

Return to the plan-review step if the plan is updated or the approach needs rethinking.
```

- [ ] **Step 4: Run the verification, confirm it passes**

Run: `grep -c '(#memory-sweep-on-handback)' skills/woostack-execute/SKILL.md`
Expected: PASS — prints `2`.

- [ ] **Step 5: Commit**

```bash
# first commit in this increment (new branch stacked on Increment 1):
gt create -m "fix(woostack-execute): sweep .woostack/memory/ on every handback"
```

---

## Self-review (run before handing back)

- [ ] **Spec coverage** — every spec requirement maps to a task above.
  - Fix 1 (commit carve-out, guarded `git add`, gitignore-free boundary, deletions staged, no-op when absent) → Increment 1, Task 1.
  - Fix 2 (sweep on any handback — terminal + blocking stops, single rule referenced twice, memory-only commit, no empty commit) → Increment 2, Tasks 1-2.
  - Non-goals (no distill change, no specs/plans staging change, no execute reorder) → not touched by any task. ✓
  - Resolved Open Q1 (no foreign guard) → Increment 1 Step 3 wording "no relevance check and no stop-and-ask". ✓
  - Resolved Open Q2 (any handback) → Increment 2 covers terminal + "When to stop and ask". ✓
- [ ] **No placeholders** — every step has the exact edit text, exact command, and exact expected output. ✓
- [ ] **Type consistency** — marker strings are consistent across find/replace and verification greps: ``Always stage `.woostack/memory/` changes`` (Inc 1), `## Memory sweep on handback` and `(#memory-sweep-on-handback)` (Inc 2). ✓

> woostack plan conventions (kept):
> - This file is **frontmatter-free** and **opens with** the `**Source:**` line.
> - Filename mirrors the spec basename: `.woostack/plans/2026-06-06-commit-memory-changes.md`.
> - **No** required sub-skill banner — execution is `woostack-execute`'s (woostack-build step 8, or `/woostack-execute <plan>`).
> - Test runner absent → "failing test" steps are concrete `grep`/`bash -n` verification commands with exact expected output.
