---
type: plan
source: .woostack/specs/2026-06-17-site-utilities-page.md
status: ready
branch: feature/site-utilities-page
---

**Source:** [[specs/2026-06-17-site-utilities-page]]

# Utilities concept page Implementation Plan

**Goal:** Add a `Utilities` concept page to the docs site's Core-concepts category covering the six on-demand skills (`ask`, `visualize`, `status`, `debug`, `doctor`, `dream`), wired into the category nav and landing card grid.

**Architecture:** One new hand-authored MDX page under `site/content/docs/concepts/`, plus two one-line wiring edits (the folder `meta.json` `pages` array and the served landing `index.mdx` card grid) — the lockstep trio a new Fumadocs concept page requires. The pre-split orphan `concepts.mdx` is deliberately left untouched. Verification is `pnpm -C site build` — which runs the `prebuild` skill-page generator (regenerating the six `/docs/skills/woostack-*` reference pages the member links target) then `next build` (compiles `utilities.mdx`, generates the `/docs/concepts/utilities` route) — plus `grep`/`node` content assertions, since docs have no unit-test runner (woostack-tdd no-runner → concrete-verification substitution). Note: `next build` has **no internal-link checker** configured; member-link integrity is instead guaranteed structurally — the six target pages are generated from `SKILL.md` sources asserted present in Task 4 Step 2 — with a manual nav/link click as the human backstop.

**Tech Stack:** Fumadocs (fumadocs-mdx) on Next.js, MDX with `<Cards>`/`<Card>`/`<Callout>` components, pnpm.

## Increment 1: Utilities concept page + category wiring

> One independently shippable PR (<=500 LOC soft target) -- its own Graphite-stacked branch, stacked on the spec+plan PR. ~55 LOC across 3 files (one new page + two one-line edits).

### Task 1: Author the Utilities page

**Files:**
- Create: `site/content/docs/concepts/utilities.mdx`
- Test: concrete verification via `grep` (no docs test runner)

- [ ] **Step 1: Write the failing check**
  Run: `grep -c "title: Utilities" site/content/docs/concepts/utilities.mdx 2>/dev/null || echo "RED: file absent"`
  Expected: FAIL — prints `RED: file absent` (the page does not exist yet).

- [ ] **Step 2: Create the page**
  Create `site/content/docs/concepts/utilities.mdx` with exactly this content:
  ```mdx
  ---
  title: Utilities
  description: "On-demand skills that complement the build and fix loops — investigate, render, and tend the workspace — without being a step in any flow."
  ---

  Most woostack skills are steps in a flow: the [build loop](/docs/concepts/building-rules) chains
  ideate → plan → execute, and the fix loop runs its own gated sequence. A second group of skills
  sits beside those flows. You reach for them on demand, whenever you need them, and each hands back
  a small result rather than advancing a pipeline. None of them merge, and none change your code.

  They split by one question: **does the skill change your `.woostack` workspace?**

  ## Investigate & present

  These point at the truth — your repo, the `.woostack/` artifacts, a spec — and either answer or
  render it. They never mutate workspace or repo state, so they are safe to run anytime, including in
  CI.

  | Skill | What it does | Writes? | Invoke |
  | --- | --- | --- | --- |
  | [woostack-ask](/docs/skills/woostack-ask) | Answers a question grounded in the `.woostack/` knowledge surface and the code, citing its evidence. | no | `/woostack-ask <question>` |
  | [woostack-visualize](/docs/skills/woostack-visualize) | Renders any source — a spec, plan, file, or concept — to one self-contained HTML view for a chosen audience. | view only (HTML) | `/woostack-visualize <source>` |
  | [woostack-status](/docs/skills/woostack-status) | Computes the feature board from git artifacts and prints it. | no | `/woostack-status` |
  | [woostack-debug](/docs/skills/woostack-debug) | Runs a four-phase root-cause analysis and hands the findings back — it never writes the fix. | no | `/woostack-debug <target>` |

  <Callout type="info">
    `woostack-debug` is **dual-natured**: the standalone `/woostack-debug` command is the pure
    on-demand utility listed here, but the same engine is also an internal hook that
    [woostack-execute](/docs/skills/woostack-execute) and
    [woostack-review](/docs/skills/woostack-review) fire from inside their flows. It earns its place
    here because, run on its own, it only investigates.
  </Callout>

  ## Tend the workspace

  These maintain the `.woostack/` workspace itself. Both are **gated**: they propose a changeset and
  nothing is written until you approve it.

  | Skill | What it does | Writes? | Invoke |
  | --- | --- | --- | --- |
  | [woostack-doctor](/docs/skills/woostack-doctor) | Diagnoses `.woostack/` store integrity and conventions, then applies repairs you approve. | gated | `/woostack-doctor` |
  | [woostack-dream](/docs/skills/woostack-dream) | Curates the [memory and wisdom](/docs/concepts/memory) stores and docs via a gated changeset. | gated | `/woostack-dream [instructions]` |

  ## Where to go next

  <Cards>
    <Card title="Building rules" href="/docs/concepts/building-rules" description="The gated build loop these utilities complement." />
    <Card title="Memory" href="/docs/concepts/memory" description="The stores woostack-dream curates and woostack-ask recalls." />
    <Card title="All skills" href="/docs/skills/using-woostack" description="Per-skill reference, generated from each SKILL.md." />
  </Cards>
  ```

- [ ] **Step 3: Confirm the page covers all six members in the right clusters**
  Run (from the worktree root):
  ```bash
  F=site/content/docs/concepts/utilities.mdx
  for s in ask visualize status debug doctor dream; do grep -q "/docs/skills/woostack-$s" "$F" && echo "ok $s" || echo "MISSING $s"; done
  grep -q "## Investigate & present" "$F" && echo "ok cluster1" || echo "MISSING cluster1"
  grep -q "## Tend the workspace" "$F" && echo "ok cluster2" || echo "MISSING cluster2"
  grep -q "dual-natured" "$F" && echo "ok debug-note" || echo "MISSING debug-note"
  # Excluded flow phases must NOT appear as members:
  for s in tdd commit plan ideate harden; do grep -q "/docs/skills/woostack-$s" "$F" && echo "note: links woostack-$s"; done
  ```
  Expected: PASS — `ok` for all six skills, both clusters, and the debug note. No `note:` line appears (only `woostack-execute` and `woostack-review` are referenced, and only inside the debug Callout — neither is in the excluded-list checked here).

### Task 2: Wire the page into the category nav

**Files:**
- Modify: `site/content/docs/concepts/meta.json`

- [ ] **Step 1: Write the failing check**
  Run: `grep -q '"utilities"' site/content/docs/concepts/meta.json && echo PASS || echo "RED: not in pages"`
  Expected: FAIL — prints `RED: not in pages`.

- [ ] **Step 2: Add `"utilities"` last in the `pages` array**
  Edit `site/content/docs/concepts/meta.json` — change:
  ```json
  {"title":"Core concepts","pages":["index","building-rules","memory","context-management","worktrees","status-tracking","review-angles"]}
  ```
  to:
  ```json
  {"title":"Core concepts","pages":["index","building-rules","memory","context-management","worktrees","status-tracking","review-angles","utilities"]}
  ```

- [ ] **Step 3: Confirm valid JSON with `utilities` present**
  Run: `node -e "const p=require('./site/content/docs/concepts/meta.json'); if(!p.pages.includes('utilities')) throw new Error('missing'); console.log('PASS', p.pages.join(','))"`
  Expected: PASS — prints `PASS index,building-rules,memory,context-management,worktrees,status-tracking,review-angles,utilities`.

### Task 3: Add the landing card

**Files:**
- Modify: `site/content/docs/concepts/index.mdx` (the served `/docs/concepts` landing; `<Cards>` grid at lines 12-19)

- [ ] **Step 1: Write the failing check**
  Run: `grep -q 'href="/docs/concepts/utilities"' site/content/docs/concepts/index.mdx && echo PASS || echo "RED: no card"`
  Expected: FAIL — prints `RED: no card`.

- [ ] **Step 2: Add a 7th `<Card>` after the review-angles card**
  In `site/content/docs/concepts/index.mdx`, insert a new line immediately after the
  `<Card title="Review angles" ... />` line (line 18) and before `</Cards>`:
  ```mdx
    <Card title="Utilities" href="/docs/concepts/utilities" description="On-demand skills — ask, visualize, status, debug, doctor, dream — that complement the loops without being a step in one." />
  ```

- [ ] **Step 3: Confirm the card is present**
  Run: `grep -q 'title="Utilities" href="/docs/concepts/utilities"' site/content/docs/concepts/index.mdx && echo PASS || echo FAIL`
  Expected: PASS.

### Task 4: Build verification + orphan untouched

**Files:** none (verification only)

- [ ] **Step 1: Confirm the pre-split orphan is untouched**
  Run: `git status --porcelain site/content/docs/concepts.mdx`
  Expected: empty output (no staged/unstaged change to `concepts.mdx`).

- [ ] **Step 2: Confirm every linked skill page source exists**
  Run:
  ```bash
  for s in ask visualize status debug doctor dream; do test -f skills/woostack-$s/SKILL.md && echo "ok $s" || echo "MISSING SKILL $s"; done
  ```
  Expected: PASS — `ok` for all six (their `/docs/skills/woostack-<s>` pages regenerate from these `SKILL.md` files at build).

- [ ] **Step 3: Build the site (authoritative MDX + route gate)**
  Run:
  ```bash
  pnpm -C site install
  pnpm -C site build
  ```
  Expected: PASS — install resolves; `pnpm -C site build` runs `prebuild` (regenerates the `/docs/skills/woostack-*` pages) then `next build`, exiting 0 (compiles `utilities.mdx`, generates the `/docs/concepts/utilities` route). `next build` has no internal-link checker, so this gate proves MDX validity + route generation, not link integrity (that is covered structurally by Step 2). On failure, read the build error and fix the offending wiring site — do not restructure the category or delete the orphan.

### Task 5: Commit the increment

- [ ] **Step 1: Commit via Graphite (stacks on the spec+plan PR)**
  Hand off to [woostack-commit](../../skills/woostack-commit/SKILL.md), which creates the branch, pushes with Graphite, and opens/updates the PR. Equivalent first commit:
  ```bash
  gt create -m "docs(site): add Utilities concept page"
  ```
  Expected: a new Graphite branch stacked on the spec+plan branch, PR opened, `concepts.mdx` not in the diff.

## Plan Checks

- **Spec coverage** — AC1 (page exists + renders in category) → Tasks 1-3; AC2 (six members, clustered, linked, debug dual-nature) → Task 1 Step 3 + the page content; AC3 (meta + landing card + green build) → Tasks 2, 3, 4. The "out-of-scope orphan untouched" edge → Task 4 Step 1.
- **AC coverage** — every §7 AC and its happy/error/edge case maps to a verification step above; no §7 section is `N/A`.
- **No placeholders** — full MDX content in Task 1; exact `grep`/`node`/`pnpm` commands with expected output throughout.
- **Type consistency** — skill slugs (`woostack-ask|visualize|status|debug|doctor|dream`), the route `/docs/concepts/utilities`, and the `meta.json` `pages` entry `"utilities"` match across all tasks.

> Filename mirrors spec basename: `.woostack/plans/2026-06-17-site-utilities-page.md`.
