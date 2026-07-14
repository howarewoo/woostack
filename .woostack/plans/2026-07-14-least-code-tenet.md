---
type: plan
source: .woostack/specs/2026-07-14-least-code-tenet.md
status: done
branch: feature/least-code-tenet
---

**Source:** [[specs/2026-07-14-least-code-tenet]]

# Least code, still safe — Implementation Plan

**Goal:** Codify "Least code, still safe" as woostack's one canonical engineering tenet — a tight
statement in `AGENTS.md`, the full generated-code doctrine in `patterns.md §10`, cross-linked (never
restated) from the authoring skills (`woostack-execute`, `woostack-ideate`, `woostack-fix`), and
surfaced to consumers by a new docs-site concepts page.

**Architecture:** Two canonical homes, wired by cross-link. `AGENTS.md` holds the tight tenet and
points to `patterns.md §10`, which holds the full ladder + deltas A–E. Three authoring skills carry
a one-line pointer to §10 (no prose copied). A sixth artifact — `concepts/least-code.mdx` plus its
two nav wirings — frames the tenet for docs readers and links the skills. No test runner exists, so
every "test" is a concrete `grep`/link-resolution/`git diff`/`pnpm build` command with exact
expected output (per the `woostack-tdd` no-runner substitution).

**Tech Stack:** Markdown/MDX, JSON, `grep`, `git`, Fumadocs (`pnpm -C site build`).

## Increment 1: Canonical doctrine (AGENTS.md tenet + patterns.md §10)

> One PR: the two canonical homes. `AGENTS.md`'s tenet links `patterns.md §10`; §10 links the
> `simplify` angle. Both link targets already exist, so the isolated diff has no dangling reference.

### Task 1: AGENTS.md canonical tenet (AC1, AC6)

**Files:**
- Modify: `AGENTS.md` (`## Hard constraints`, after the heading at line 81) — real file; `.claude/CLAUDE.md` is a symlink to it.

- [x] **Step 1: Write the failing check**
  Run: `grep -c "Least code, still safe" AGENTS.md`
  Expected: FAIL — prints `0` (tenet absent).

- [x] **Step 2: Add the tenet as the first Hard-constraints bullet**
  Insert immediately after the `## Hard constraints` heading (before `- No fabricated versions.`):
  ```markdown
  - **Least code, still safe.** Skills — and the code they generate — write as little code as
    necessary. Understand first (read the code the change touches, trace the real flow), *then* take
    the first rung that holds: in-tree reuse → stdlib → native feature → installed dep → one line →
    minimum that works. Deletion over addition, boring over clever — small because it's necessary,
    not golfed. Comments are minimal and explain *why* (hidden constraint, workaround, surprising
    invariant), never *what*. Never shrink code by cutting edge cases or risks — validation, error
    handling, security, accessibility, and data-loss handling stay; keep deliberate multi-layer
    safety redundancy; at equal size pick the edge-case-correct option; behavior-changing
    simplification keeps its regression test; a knowingly-cut corner leaves a `why` comment naming
    its ceiling and upgrade path. Full standard:
    [`patterns.md §10`](skills/woostack-bootstrap/references/patterns.md); enforced by the
    `simplify`/`comments` review angles.
  ```

- [x] **Step 3: Confirm the tenet, its link, and the symlink**
  Run: `grep -c "Least code, still safe" AGENTS.md && grep -c "skills/woostack-bootstrap/references/patterns.md" AGENTS.md && grep -c "Least code, still safe" .claude/CLAUDE.md`
  Expected: PASS — `1`, `1`, `1` (edit landed in the real file; symlink reflects it).

- [x] **Step 4: Confirm the link target resolves (AC6)**
  Run: `test -f skills/woostack-bootstrap/references/patterns.md && echo OK`
  Expected: PASS — `OK`.

- [x] **Step 5: Commit**
  ```bash
  gt create -m "docs: add Least code, still safe tenet to AGENTS.md"
  ```

### Task 2: patterns.md §10 full doctrine (AC2, AC6)

**Files:**
- Modify: `skills/woostack-bootstrap/references/patterns.md` (§10, lines 158–163) — rename heading, keep the four existing bullets, prepend the ladder + deltas A–E.

- [x] **Step 1: Write the failing check**
  Run: `grep -c -F "Read first (delta A)" skills/woostack-bootstrap/references/patterns.md`
  Expected: FAIL — prints `0` (doctrine absent).

- [x] **Step 2: Rename §10 and expand it**
  Replace the `## 10. Code size & comments` heading and its four bullets with:
  ```markdown
  ## 10. Least code & comments

  Write as little code as necessary — but never at the cost of correctness or safety. Understand the
  problem first, then take the first rung that holds.

  - **The ladder.** Before adding code, walk the rungs and stop at the first that works: (1) YAGNI —
    is it needed at all? (2) in-tree reuse — a helper/util/pattern that already exists here; (3)
    stdlib; (4) a native platform feature; (5) an already-installed dependency; (6) one line; (7)
    only then the minimum new code that works. The review
    [`simplify` angle](../../woostack-review/prompts/angles/simplify.md) states the full ladder
    verbatim and enforces it — link, don't restate.
  - **Read first (delta A).** The ladder runs *after* you understand the problem: read the code the
    change touches and trace the real flow end to end before picking a rung. Lazy about the
    solution, never about reading — the smallest change in the wrong place is a second bug.
  - **Equal-size tie-breaker (delta B).** When two approaches are the same size, pick the
    edge-case-correct one. Lazy means less code, not the flimsier algorithm.
  - **Never-cut list (delta C).** Never shrink code by dropping validation, error handling,
    security, accessibility, or data-loss handling. Keep deliberate multi-layer safety redundancy
    (it is not DRY-removable); prefer scoped parsing over a greedy regex; a behavior-changing
    simplification keeps its regression test.
  - **Boring over clever (delta D).** Deletion over addition; boring over clever. Code is small
    because it's necessary, not because it's golfed.
  - **Deliberate-corner marker (delta E).** A knowingly-cut corner with a known ceiling (global
    lock, O(n²) scan, naive heuristic) leaves a `why` comment naming the ceiling and the upgrade
    path, and is distilled as a memory `gotcha`.
  - Non-test source files: ≤ 500 lines.
  - User-facing components + procedures: JSDoc with purpose, inputs, outputs.
  - Comments explain **why** when non-obvious (hidden constraint, workaround, surprising invariant). Skip the **what** — code names that.
  - No magic literals. Extract to `UPPER_SNAKE_CASE` constants with descriptive names.
  ```

- [x] **Step 3: Confirm rename, deltas, and preserved bullets (AC2)**
  Run: `grep -c -F "## 10. Least code & comments" skills/woostack-bootstrap/references/patterns.md ; grep -c -F "## 10. Code size & comments" skills/woostack-bootstrap/references/patterns.md ; grep -c -F "Read first (delta A)" skills/woostack-bootstrap/references/patterns.md ; grep -c -F "No magic literals" skills/woostack-bootstrap/references/patterns.md`
  Expected: PASS — `1`, `0`, `1`, `1` (renamed; read-first present; existing bullet preserved).

- [x] **Step 4: Confirm the simplify-angle link resolves (AC6)**
  Run: `test -f skills/woostack-review/prompts/angles/simplify.md && echo OK`
  Expected: PASS — `OK` (target of `../../woostack-review/prompts/angles/simplify.md` from §10's dir).

- [x] **Step 5: Commit**
  ```bash
  gt modify -c -m "docs: expand patterns.md §10 into full least-code doctrine"
  ```

## Increment 2: Authoring-skill cross-links (execute, ideate, fix)

> One PR: three authoring skills gain a one-line pointer to §10 (which exists in the stack base from
> Increment 1). No ladder prose is copied — pointers only.

### Task 1: woostack-execute Implement step + Hard constraint (AC3)

**Files:**
- Modify: `skills/woostack-execute/SKILL.md` (Implement step 2 at line 107; `## Hard constraints` after line 240).

- [x] **Step 1: Write the failing check**
  Run: `grep -c "least code that satisfies the task" skills/woostack-execute/SKILL.md`
  Expected: FAIL — prints `0`.

- [x] **Step 2: Add the Implement-step sentence**
  Append to the end of step 2 ("**Implement** its tasks…", the line ending "…the `woostack-debug` routing in \"When to stop and ask\"."):
  ```markdown
   Write the least code that satisfies the task per [`patterns.md §10`](../woostack-bootstrap/references/patterns.md) (understand-first, smallest existing solution, why-not-what comments) — without dropping the edge-case, error-path, security, or accessibility coverage the TDD classes already require.
  ```

- [x] **Step 3: Add the Hard-constraints bullet**
  Insert after the `- **Distill durable knowledge only.** …` bullet in `## Hard constraints`:
  ```markdown
  - **Least code, still safe.** Implement the smallest change that passes per [`patterns.md §10`](../woostack-bootstrap/references/patterns.md); never cut validation, error handling, security, or accessibility to shrink a diff.
  ```

- [x] **Step 4: Confirm both references land and the link resolves**
  Run: `grep -c "least code that satisfies the task" skills/woostack-execute/SKILL.md && grep -c "patterns.md §10" skills/woostack-execute/SKILL.md && test -f skills/woostack-bootstrap/references/patterns.md && echo OK`
  Expected: PASS — `1`, `2`, `OK`.

- [x] **Step 5: Commit**
  ```bash
  gt create -m "docs: cross-link least-code doctrine from woostack-execute"
  ```

### Task 2: woostack-ideate "Least code wins" guard half (AC3)

**Files:**
- Modify: `skills/woostack-ideate/SKILL.md` (Key principles, "Least code wins" bullet, lines 117–118).

- [x] **Step 1: Write the failing check**
  Run: `grep -c "YAGNI cuts speculative features" skills/woostack-ideate/SKILL.md`
  Expected: FAIL — prints `0`.

- [x] **Step 2: Extend the "Least code wins" bullet with the guard half**
  Replace the existing bullet:
  ```markdown
  - **Least code wins.** Prefer the smallest solution that already exists — stdlib, a native
    feature, an installed dependency — before proposing a new abstraction or dependency. Understand
    the problem before choosing the smallest shape; YAGNI cuts speculative features, never
    validation, error handling, security, accessibility, or safety redundancy. Apply the full
    standard in [`patterns.md §10`](../woostack-bootstrap/references/patterns.md).
  ```

- [x] **Step 3: Confirm the guard half and cross-link landed**
  Run: `grep -c "YAGNI cuts speculative features" skills/woostack-ideate/SKILL.md && grep -c "patterns.md §10" skills/woostack-ideate/SKILL.md && test -f skills/woostack-bootstrap/references/patterns.md && echo OK`
  Expected: PASS — `1`, `1`, `OK`.

- [x] **Step 4: Commit**
  ```bash
  gt modify -c -m "docs: add safety guard to woostack-ideate Least code wins"
  ```

### Task 3: woostack-fix Proposed Fix template + Hard constraint, delta F (AC3)

**Files:**
- Modify: `skills/woostack-fix/SKILL.md` (Proposed Fix template line 134; `## Hard constraints` after line 240).

- [x] **Step 1: Write the failing check**
  Run: `grep -c "one guard at the shared function" skills/woostack-fix/SKILL.md`
  Expected: FAIL — prints `0`.

- [x] **Step 2: Sharpen the Proposed Fix template line (delta F)**
  Replace `*Describe the minimal, targeted code changes to resolve the root cause.*` with:
  ```markdown
  *Describe the minimal, targeted code changes to resolve the root cause. Fix the shared root once: grep every caller, and prefer one guard at the shared function over one-per-caller patches — smaller diff and correct. Never drop edge-case or safety coverage to shrink the change (per [`patterns.md §10`](../woostack-bootstrap/references/patterns.md)).*
  ```

- [x] **Step 3: Add the Hard-constraints bullet**
  Insert after `- **No guess-and-check.** …` in `## Hard constraints`:
  ```markdown
  - **Least code, still safe.** The fix is the smallest change that resolves the *root* cause per [`patterns.md §10`](../woostack-bootstrap/references/patterns.md) — fix the shared root once, never patch symptoms per-caller, never cut safety coverage.
  ```

- [x] **Step 4: Confirm delta F, both §10 links, and the target**
  Run: `grep -c "one guard at the shared function" skills/woostack-fix/SKILL.md && grep -c "patterns.md §10" skills/woostack-fix/SKILL.md && test -f skills/woostack-bootstrap/references/patterns.md && echo OK`
  Expected: PASS — `1`, `2`, `OK`.

- [x] **Step 5: Commit**
  ```bash
  gt modify -c -m "docs: cross-link least-code doctrine from woostack-fix (delta F)"
  ```

### Task 4: No prose duplication across authoring skills (AC5, AC6)

**Files:** none (verification only).

- [x] **Step 1: Confirm the full paragraph lives in ≤2 shipped files (AC5)**
  Run: `grep -rl "boring over clever" --include="*.md" AGENTS.md skills site | sort`
  Expected: PASS — exactly two lines: `AGENTS.md` and `skills/woostack-bootstrap/references/patterns.md` (execute/ideate/fix carry pointers, not the paragraph).

- [x] **Step 2: Confirm the ladder prose is not copied into the authoring skills (AC5)**
  Run: `grep -rl "in-tree reuse" --include="*.md" skills | sort`
  Expected: PASS — exactly one line: `skills/woostack-bootstrap/references/patterns.md`.

- [x] **Step 3: Confirm every new authoring-skill link resolves (AC6)**
  Run: `for f in skills/woostack-execute skills/woostack-ideate skills/woostack-fix; do (cd "$f" && test -f ../woostack-bootstrap/references/patterns.md && echo "$f OK"); done`
  Expected: PASS — `skills/woostack-execute OK`, `skills/woostack-ideate OK`, `skills/woostack-fix OK`.

- [x] **Step 4: No commit**
  Verification-only task — no files change. The checkbox ticks are committed with this increment's
  edit tasks (Tasks 1–3). If a check above failed, fix the offending file in its own task and re-run.

## Increment 3: Docs-site concepts page + nav wiring (File 6)

> One PR: a new user-facing concepts page plus its two nav surfaces (`meta.json` + `index.mdx`
> card), moved in lockstep, then the whole site build. Ends with the cross-cutting AC4/AC5 sweep.

### Task 1: Create the concepts page (AC7)

**Files:**
- Create: `site/content/docs/concepts/least-code.mdx`

- [x] **Step 1: Write the failing check**
  Run: `test -f site/content/docs/concepts/least-code.mdx && echo EXISTS || echo MISSING`
  Expected: FAIL — `MISSING`.

- [x] **Step 2: Author the page**
  ```mdx
  ---
  title: Least code, still safe
  description: woostack's core engineering tenet — write as little code as necessary, without cutting edge cases or risks.
  ---

  woostack's skills — and the code they generate — write as little code as necessary. Less code is
  less to read, test, and break. But "least code" is a discipline, not a golf score: it never comes
  at the cost of correctness or safety.

  ## Understand first, then take the first rung that holds

  Laziness is about the *solution*, never about *reading*. Read the code a change touches and trace
  the real flow end to end before writing anything — the smallest change in the wrong place is a
  second bug. Then take the first rung that already solves the problem:

  1. **YAGNI** — is it needed at all?
  2. **In-tree reuse** — a helper, util, or pattern that already exists here.
  3. **The standard library.**
  4. **A native platform feature.**
  5. **An already-installed dependency.**
  6. **One line.**
  7. Only then, the minimum new code that works.

  ## Never shrink code by cutting safety

  Deletion over addition, boring over clever — code is small because it's necessary, not golfed.
  What never gets cut to shrink a diff: validation, error handling, security, accessibility, and
  data-loss handling. Deliberate multi-layer safety redundancy stays (it is not DRY-removable). At
  equal size, pick the edge-case-correct option, and a behavior-changing simplification keeps its
  regression test. A knowingly-cut corner leaves a `why` comment naming its ceiling and upgrade
  path.

  ## Comments explain why, not what

  Comments are minimal and explain *why* — a hidden constraint, a workaround, a surprising
  invariant. The code already says *what*.

  ## Where it lives

  The tenet is enforced across the loop, not just stated:

  - The full generated-code standard is
    [`patterns.md §10`](https://github.com/howarewoo/woostack/blob/main/skills/woostack-bootstrap/references/patterns.md#10-least-code--comments).
  - Authoring skills carry it: [woostack-execute](/docs/skills/woostack-execute),
    [woostack-ideate](/docs/skills/woostack-ideate), and [woostack-fix](/docs/skills/woostack-fix).
  - The always-on [`simplify` review angle](/docs/concepts/review-angles) enforces the ladder; the
    source-triggered `comments` angle catches comment drift when source changes.
  ```

- [x] **Step 3: Confirm the page exists with frontmatter**
  Run: `test -f site/content/docs/concepts/least-code.mdx && grep -c "^title: Least code, still safe" site/content/docs/concepts/least-code.mdx`
  Expected: PASS — `1`.

- [x] **Step 4: Commit**
  ```bash
  gt create -m "docs(site): add Least code concepts page"
  ```

### Task 2: Wire the page into both nav surfaces (AC7)

**Files:**
- Modify: `site/content/docs/concepts/meta.json` (`pages` array)
- Modify: `site/content/docs/concepts/index.mdx` (`<Cards>` block)

- [x] **Step 1: Write the failing check**
  Run: `grep -c '"least-code"' site/content/docs/concepts/meta.json && grep -c "/docs/concepts/least-code" site/content/docs/concepts/index.mdx`
  Expected: FAIL — `0` and `0` (unwired).

- [x] **Step 2: Add to the nav order**
  In `site/content/docs/concepts/meta.json`, insert `"least-code",` into `pages` immediately after `"building-rules",`:
  ```json
  {
    "title": "Core concepts",
    "pages": [
      "index",
      "building-rules",
      "least-code",
      "memory",
      "context-management",
      "worktrees",
      "status-tracking",
      "review-angles",
      "utilities"
    ]
  }
  ```

- [x] **Step 3: Add the index card**
  In `site/content/docs/concepts/index.mdx`, insert this `<Card>` immediately after the "Building rules" card, inside `<Cards>`:
  ```mdx
    <Card title="Least code, still safe" href="/docs/concepts/least-code" description="woostack's core engineering tenet: write as little code as necessary, without cutting edge cases or risks." />
  ```

- [x] **Step 4: Confirm both nav surfaces reference the page (lockstep)**
  Run: `grep -c '"least-code"' site/content/docs/concepts/meta.json && grep -c "/docs/concepts/least-code" site/content/docs/concepts/index.mdx`
  Expected: PASS — `1` and `1`.

- [x] **Step 5: Commit**
  ```bash
  gt modify -c -m "docs(site): wire least-code page into concepts nav"
  ```

### Task 3: Site builds + cross-cutting AC4/AC5/AC6 sweep (AC7, AC4, AC5, AC6)

**Files:** none (verification only).

- [x] **Step 1: Build the docs site (AC7)**
  Run: `pnpm -C site install --frozen-lockfile && pnpm -C site build`
  Expected: PASS — build completes, exit code `0` (the new page compiles and is nav-wired). Run the
  `install` first only if `site/node_modules` is absent; a warm tree can `pnpm -C site build` directly.

- [x] **Step 2: Confirm no already-aligned skill was touched (AC4)**
  Run: `git diff --name-only main -- skills site AGENTS.md .claude | sort`
  Expected: PASS — every path is in the allowed set and none is a `woostack-tdd`, review-angle, or `woostack-audit` file:
  ```
  AGENTS.md
  site/content/docs/concepts/index.mdx
  site/content/docs/concepts/least-code.mdx
  site/content/docs/concepts/meta.json
  skills/woostack-bootstrap/references/patterns.md
  skills/woostack-execute/SKILL.md
  skills/woostack-fix/SKILL.md
  skills/woostack-ideate/SKILL.md
  ```
  (`.claude/CLAUDE.md` does **not** list — it is a symlink whose link blob is unchanged; editing the
  AGENTS.md target does not re-write the link itself.)

- [x] **Step 3: Confirm no whole-paragraph duplication feature-wide (AC5)**
  Run: `grep -rl "boring over clever" --include="*.md" AGENTS.md skills site | sort`
  Expected: PASS — exactly `AGENTS.md` and `skills/woostack-bootstrap/references/patterns.md`. The
  `.mdx` docs page is excluded by `--include="*.md"` by design: it paraphrases the tenet in its own
  words rather than copying the paragraph, so it is not a duplication site.

- [x] **Step 4: Confirm the docs page uses `/docs/…` routes, not repo-relative paths (AC6 edge)**
  Run: `grep -c "](/docs/" site/content/docs/concepts/least-code.mdx && grep -c "](../" site/content/docs/concepts/least-code.mdx`
  Expected: PASS — first `≥1`, second `0`.

- [x] **Step 5: No commit**
  Verification-only task — no files change. The checkbox ticks are committed with this increment's
  page/nav tasks (Tasks 1–2). This is the final increment: on all boxes `[x]`, `woostack-execute`
  authors the plan's terminal `status: done`.

## Plan Checks

- **Spec coverage** — Files 1–6 each map to a task: File 1 → Inc 1 Task 1; File 2 → Inc 1 Task 2;
  File 3 → Inc 2 Task 1; File 4 → Inc 2 Task 2; File 5 → Inc 2 Task 3; File 6 → Inc 3 Tasks 1–2.
- **AC coverage** — AC1 → Inc1 T1; AC2 → Inc1 T2; AC3 → Inc2 T1–T3; AC4 → Inc3 T3 S2; AC5 → Inc2 T4
  + Inc3 T3 S3; AC6 → Inc1 T1 S4/T2 S4 + Inc2 T4 + Inc3 T3 S4; AC7 → Inc3 T1–T3. Each carries a
  concrete command with expected output (no-runner substitution).
- **No placeholders** — every step has exact paths, complete content, exact commands, expected
  output.
- **Type consistency** — canonical phrase "Least code, still safe" and link target
  `patterns.md §10` are used identically across AGENTS.md, execute, and fix.
- **Angle coverage** — architecture (two homes + cross-links, §5); security/edge/error (the guard
  clause is the never-cut list, AC1–AC3 assert it, and no threat surface is added); a failing check
  precedes every edit; deps none; infra = the AC7 `pnpm -C site build` guard. observability / api /
  database / i18n → N/A for a documentation tenet (spec §9).
- **Deferral markers** — none needed: Increment 2's link targets (`patterns.md §10`) exist in the
  stack base from Increment 1, so no isolated diff has a dangling reference.
