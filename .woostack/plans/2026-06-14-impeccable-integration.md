---
type: plan
source: .woostack/specs/2026-06-14-impeccable-integration.md
status: ready
branch: feature/impeccable-integration
---

**Source:** .woostack/specs/2026-06-14-impeccable-integration.md

# Impeccable integration Implementation Plan

**Goal:** Make [impeccable](https://github.com/pbakaus/impeccable) a recommended, graceful-degrade companion of woostack at three additive touch-points — install discoverability (A), build-loop design-craft delegation (C), and design house-rules (D) — without making it a hard dependency.

**Architecture:** Three independently shippable, skill-collection-Markdown increments stacked linearly on the spec+plan PR. A edits the three install-doc surfaces; C edits `woostack-ideate` §"Visual treatment" + `woostack-execute` §"Per-increment cadence"; D edits `woostack-ideate` step 1. Increments C and D both touch `woostack-ideate/SKILL.md` but in different, non-overlapping sections, so the linear stack (D branches off C) applies cleanly. B (the `design` review angle) is already shipped and is a non-goal — guarded read-only.

**Tech Stack:** Markdown / MDX (skill collection + Fumadocs docs). No application runtime and no test runner — per [woostack-tdd](../../skills/woostack-tdd/SKILL.md)'s no-runner → concrete-verification rule, each "failing test" is a `grep` with exact expected output (string absent before the edit, present after). Graphite (`gt`) for stacked PRs.

## Increment 1: Setup mention (A)

> One independently shippable PR. Adds the recommended-companion mention to the three surfaces that show the woostack install command. ~25 LOC.

### Task 1: README companion note

**Files:**
- Modify: `README.md` (after the §1 Installation block, before `### 2. Initialization` — currently line 45→47)

- [x] **Step 1: Write the failing test**
  ```bash
  grep -q "pnpx skills add pbakaus/impeccable" README.md && echo FOUND || echo ABSENT
  ```

- [x] **Step 2: Run the test, confirm it fails**
  Run: `grep -q "pnpx skills add pbakaus/impeccable" README.md && echo FOUND || echo ABSENT`
  Expected: `ABSENT`

- [x] **Step 3: Minimal implementation**
  Insert immediately after the line `This command registers the public skills ...` (end of §1 Installation), before the `### 2. Initialization` heading:
  ```markdown

  > **Recommended companion — [impeccable](https://github.com/pbakaus/impeccable).** woostack's front-end design skill of choice. It powers the `design` review angle (`woostack-review` runs impeccable's detector) and front-end design craft inside the build loop. Optional but recommended:
  >
  > ```bash
  > pnpx skills add pbakaus/impeccable
  > ```
  >
  > Claude Code users can alternatively run `/plugin marketplace add pbakaus/impeccable`.
  ```

- [x] **Step 4: Run the tests, confirm they pass**
  Run:
  ```bash
  grep -q "pnpx skills add pbakaus/impeccable" README.md && \
  grep -q "Recommended companion" README.md && \
  grep -q "Optional but recommended" README.md && \
  grep -q "/plugin marketplace add pbakaus/impeccable" README.md && echo PASS
  ```
  Expected: `PASS`

- [x] **Step 5: Commit**
  ```bash
  gt create -m "docs(readme): recommend impeccable as a companion skill"
  ```

### Task 2: getting-started.mdx companion note

**Files:**
- Modify: `site/content/docs/getting-started.mdx` (after the §1 Install block — currently line 17 — before `## 2. Initialize` on line 19)

- [x] **Step 1: Write the failing test**
  ```bash
  grep -q "pnpx skills add pbakaus/impeccable" site/content/docs/getting-started.mdx && echo FOUND || echo ABSENT
  ```

- [x] **Step 2: Run the test, confirm it fails**
  Run: `grep -q "pnpx skills add pbakaus/impeccable" site/content/docs/getting-started.mdx && echo FOUND || echo ABSENT`
  Expected: `ABSENT`

- [x] **Step 3: Minimal implementation**
  Insert after the line ``` `pnpm` (and `pnpx`) is the recommended package manager.``` and before `## 2. Initialize`:
  ```mdx

  <Callout type="info">
    **Recommended companion:** [impeccable](https://github.com/pbakaus/impeccable) — woostack's
    front-end design skill. It powers the `design` review angle and front-end design craft in the
    build loop. Optional but recommended:

    ```bash
    pnpx skills add pbakaus/impeccable
    ```

    Claude Code users can alternatively run `/plugin marketplace add pbakaus/impeccable`.
  </Callout>
  ```
  (`<Callout>` is already used in this file — no new import needed.)

- [x] **Step 4: Run the tests, confirm they pass**
  Run:
  ```bash
  grep -q "pnpx skills add pbakaus/impeccable" site/content/docs/getting-started.mdx && \
  grep -q "Recommended companion" site/content/docs/getting-started.mdx && \
  grep -q "Optional but recommended" site/content/docs/getting-started.mdx && echo PASS
  ```
  Expected: `PASS`

- [x] **Step 5: Commit**
  ```bash
  gt modify -c -m "docs(site): recommend impeccable in getting-started"
  ```

### Task 3: index.mdx one-line mention

**Files:**
- Modify: `site/content/docs/index.mdx` (after the bullet list — currently the `**Team-ready**` bullet on line 18)

- [x] **Step 1: Write the failing test**
  ```bash
  grep -q "pnpx skills add pbakaus/impeccable" site/content/docs/index.mdx && echo FOUND || echo ABSENT
  ```

- [x] **Step 2: Run the test, confirm it fails**
  Run: `grep -q "pnpx skills add pbakaus/impeccable" site/content/docs/index.mdx && echo FOUND || echo ABSENT`
  Expected: `ABSENT`

- [x] **Step 3: Minimal implementation**
  Append one bullet to the existing bullet list, after the `**Team-ready**` bullet (terse — inline code only, no second ```bash block):
  ```mdx
  - **Pairs with [impeccable](https://github.com/pbakaus/impeccable)** — woostack's recommended front-end design skill. Install alongside: `pnpx skills add pbakaus/impeccable`.
  ```

- [x] **Step 4: Run the tests, confirm they pass**
  Run:
  ```bash
  grep -q "pnpx skills add pbakaus/impeccable" site/content/docs/index.mdx && \
  test "$(grep -c '```bash' site/content/docs/index.mdx)" = "1" && echo PASS
  ```
  Expected: `PASS` (the mention is one inline-code line; the file still has exactly one ```bash block — the original woostack install)

- [x] **Step 5: Commit**
  ```bash
  gt modify -c -m "docs(site): mention impeccable on the landing page"
  ```

## Increment 2: Command delegation (C)

> One independently shippable PR, stacked on Increment 1. Adds install-gated impeccable design-craft delegation to ideate and execute. ~15 LOC.

### Task 1: ideate — delegate design craft to impeccable

**Files:**
- Modify: `skills/woostack-ideate/SKILL.md` §"Visual treatment, on demand" (currently lines 90-97)

- [ ] **Step 1: Write the failing test**
  ```bash
  grep -q "impeccable" skills/woostack-ideate/SKILL.md && echo FOUND || echo ABSENT
  ```

- [ ] **Step 2: Run the test, confirm it fails**
  Run: `grep -q "impeccable" skills/woostack-ideate/SKILL.md && echo FOUND || echo ABSENT`
  Expected: `ABSENT`

- [ ] **Step 3: Minimal implementation**
  Append a paragraph to the end of the "## Visual treatment, on demand" section (after the sentence ending `...a UI topic is not automatically a visual question.`):
  ```markdown

  For genuine front-end **craft** — typography, color, spacing, motion, component polish — rather
  than a view to *show*, defer to [impeccable](https://github.com/pbakaus/impeccable) when it is
  installed (its discipline commands, e.g. `/typeset`, `/colorize`, `/animate`). The split:
  `woostack-visualize` renders a view **to show the user**; impeccable **crafts the UI itself**.
  This is optional and host-dependent — if impeccable is not installed, proceed with built-in
  judgment. Its browser-based Live Mode stays out of this phase; the no-browser-companion rule
  above is unchanged.
  ```

- [ ] **Step 4: Run the tests, confirm they pass**
  Run:
  ```bash
  grep -q "impeccable" skills/woostack-ideate/SKILL.md && \
  grep -q "crafts the UI itself" skills/woostack-ideate/SKILL.md && \
  grep -q "optional and host-dependent" skills/woostack-ideate/SKILL.md && \
  grep -q "Live Mode stays out" skills/woostack-ideate/SKILL.md && \
  grep -q "does not run a browser companion" skills/woostack-ideate/SKILL.md && echo PASS
  ```
  Expected: `PASS` (the last grep is the AC2-edge guard: the original no-browser-companion text is preserved)

- [ ] **Step 5: Commit**
  ```bash
  gt create -m "feat(ideate): delegate front-end craft to impeccable (optional)"
  ```

### Task 2: execute — optional impeccable during UI increments

**Files:**
- Modify: `skills/woostack-execute/SKILL.md` §"Per-increment cadence", step 2 "Implement" (currently ends line 107)

- [ ] **Step 1: Write the failing test**
  ```bash
  grep -q "impeccable" skills/woostack-execute/SKILL.md && echo FOUND || echo ABSENT
  ```

- [ ] **Step 2: Run the test, confirm it fails**
  Run: `grep -q "impeccable" skills/woostack-execute/SKILL.md && echo FOUND || echo ABSENT`
  Expected: `ABSENT`

- [ ] **Step 3: Minimal implementation**
  In step 2 ("**Implement** ... Follow each safe plan step exactly."), append the following as a new sentence on the same line, immediately after `Follow each safe plan step exactly.` — keep it inside step-2's list item (no blank line, so list numbering is preserved):
  ```text
   During a UI-touching increment, the implementer may optionally invoke [impeccable](https://github.com/pbakaus/impeccable) for front-end design craft (host-dependent; proceed normally if it is not installed) — the same optional-detour shape as the `woostack-debug` routing in "When to stop and ask".
  ```
  (The leading space is intentional: it separates the new sentence from the existing one on the same line.)

- [ ] **Step 4: Run the tests, confirm they pass**
  Run:
  ```bash
  grep -q "impeccable" skills/woostack-execute/SKILL.md && \
  grep -q "proceed normally if it is not installed" skills/woostack-execute/SKILL.md && echo PASS
  ```
  Expected: `PASS`

- [ ] **Step 5: Commit**
  ```bash
  gt modify -c -m "feat(execute): note optional impeccable craft on UI increments"
  ```

## Increment 3: DESIGN.md house-rules + non-goal guards (D)

> One independently shippable PR, stacked on Increment 2. Loads impeccable's DESIGN.md as design house-rules in ideate, and guards the two non-goal invariants (no-dep property; B untouched). ~12 LOC. Touches `woostack-ideate/SKILL.md` step 1 — a different section from Increment 2's edit.

### Task 1: ideate — load DESIGN.md as design house-rules

**Files:**
- Modify: `skills/woostack-ideate/SKILL.md` step 1 "Explore project context" (currently lines 49-54)

- [ ] **Step 1: Write the failing test**
  ```bash
  grep -q "DESIGN.md" skills/woostack-ideate/SKILL.md && echo FOUND || echo ABSENT
  ```

- [ ] **Step 2: Run the test, confirm it fails**
  Run: `grep -q "DESIGN.md" skills/woostack-ideate/SKILL.md && echo FOUND || echo ABSENT`
  Expected: `ABSENT`

- [ ] **Step 3: Minimal implementation**
  Insert after the wisdom sentence (`An empty or absent \`wisdom/\` is a no-op.`) inside step 1:
  ```markdown
   For front-end work, also read impeccable's `DESIGN.md` if present (at the repo root, where
   `/impeccable init` writes it) and treat it as design house-rules. Single home: `DESIGN.md` is
   the design-system source of truth, `@infrastructure/ui` tokens are its implementation, and
   `.woostack/wisdom/` holds general house-rules — read `DESIGN.md`, never copy it into `wisdom/`.
   An absent `DESIGN.md` is a no-op.
  ```

- [ ] **Step 4: Run the tests, confirm they pass**
  Run:
  ```bash
  grep -q "DESIGN.md" skills/woostack-ideate/SKILL.md && \
  grep -q "design-system source of truth" skills/woostack-ideate/SKILL.md && \
  grep -q "never copy it into" skills/woostack-ideate/SKILL.md && echo PASS
  ```
  Expected: `PASS`

- [ ] **Step 5: Commit**
  ```bash
  gt create -m "feat(ideate): load impeccable DESIGN.md as design house-rules"
  ```

### Task 2: Non-goal guards (AC4-edge, AC5) — verification-only

**Files:**
- Read-only guards (no edits): `skills/woostack-build/SKILL.md`, `skills/woostack-review/prompts/angles/design.md`

> No file change. These are assertions, not edits — the only write is ticking these checkboxes, which rides Increment 3 Task 1's commit. If either guard FAILs, **stop**: an increment violated a non-goal (made impeccable required, or touched the shipped design angle).

- [ ] **Step 1: Guard AC4-edge — no-dep property still true**
  Run: `grep -q "no external skill dependencies" skills/woostack-build/SKILL.md && echo PASS || echo FAIL`
  Expected: `PASS` (no increment converted impeccable into a required dependency; the sentence survives)

- [ ] **Step 2: Guard AC5 — B (design angle) untouched and still wired to impeccable**
  Run: `grep -q "impeccable" skills/woostack-review/prompts/angles/design.md && echo PASS || echo FAIL`
  Expected: `PASS` (the already-shipped detector wiring is intact; these increments did not touch it)

## Plan Checks

- **Spec coverage** — AC1→Inc1 (Tasks 1-3), AC2→Inc2 Task1, AC3→Inc2 Task2, AC4→Inc3 Task1 + Task2 Step1, AC5→Inc3 Task2 Step2. Every AC and each filled happy/error/edge case maps to a grep assertion.
- **AC coverage** — §7 has no `N/A` rows except AC3-edge (explicitly "N/A — single additive note"), which is sound (present/absent covered by happy/error).
- **No placeholders** — every step has the exact file, the actual insert content, the exact grep, and expected output.
- **Type consistency** — N/A (no code types); string tokens (`pnpx skills add pbakaus/impeccable`, `DESIGN.md`, `impeccable`) are used identically across tasks and match the spec.

> Filename mirrors spec basename: `.woostack/plans/2026-06-14-impeccable-integration.md`.

**No required-sub-skill banner.** Executable by `woostack-execute` directly. "Failing test" steps are concrete `grep` verifications (skill-collection repo, no runtime).
