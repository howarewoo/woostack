---
type: plan
source: .woostack/specs/2026-06-16-concepts-page-split.md
status: ready
branch: feature/concepts-page-split
---

**Source:** [[specs/2026-06-16-concepts-page-split]]

# Split "Core concepts" into a multi-page section — Implementation Plan

**Goal:** Replace the single `site/content/docs/concepts.mdx` with a `concepts/` Fumadocs
section — a hub at `/docs/concepts` plus focused subpages (building-rules, memory,
context-management, worktrees, status-tracking, review-angles) — keeping the build green and
every internal link resolving.

**Architecture:** Fumadocs-core 16 maps a folder's `index.mdx` to the folder route (proven:
`content/docs/index.mdx` → `/docs`), so `concepts/index.mdx` serves `/docs/concepts`. Each
increment adds pages and grows the hub `<Cards>` + `concepts/meta.json` together, so every
increment is independently green with no dangling links. Lifted content (build loop, memory,
context economy) moves verbatim from the old file; the two new pages (worktrees, status-tracking)
are authored from the skill contracts. The site has no content unit tests, so each step's
verification is a concrete command — `pnpm -C site build`, `grep`, file-presence — per the
[woostack-tdd](../../skills/woostack-tdd/SKILL.md) no-runner substitution.

**Tech Stack:** Next.js + Fumadocs (fumadocs-core, fumadocs-mdx), MDX, TypeScript, pnpm. No new
dependencies (spec §3).

> **Verification prerequisite (every increment).** The build runs in this worktree, so
> `node_modules` must be real, not a broken symlink (memory:
> `site-build-in-worktree-needs-real-node-modules`). Before the first build, from the worktree
> root run `pnpm -C site install --frozen-lockfile` once if `site/node_modules` is missing.

> **Baseline (run once before Increment 1).** Capture the green baseline:
> `pnpm -C site build` → Expected: exits 0 ("✓ Compiled successfully" / route list printed). If
> it is not green before edits, stop and report — do not build on a red baseline.

---

## Increment 1: Scaffold `concepts/` section and lift existing content

> One PR. Creates the folder, hub, and the three lifted subpages; deletes the old file; fixes the
> moved anchor. Net new prose is small (lifts move verbatim). Independently shippable: `/docs/concepts`
> resolves to the hub with 3 working Cards; build green.

### Task 1: Create the section folder, meta.json, and hub index

**Files:**
- Create: `site/content/docs/concepts/meta.json`
- Create: `site/content/docs/concepts/index.mdx`
- Modify: `site/content/docs/index.mdx` (tighten the Core-concepts Card description)
- (component unchanged: `site/components/concepts/context-economy.tsx`)

- [x] **Step 1: Write `concepts/meta.json` (the four pages that exist after this increment)**
  Listing `"index"` as the first page is the established working pattern — the root
  `content/docs/meta.json` lists `"index"` first for the `/docs` folder root, and it builds.
  ```json
  {
    "title": "Core concepts",
    "pages": [
      "index",
      "building-rules",
      "memory",
      "context-management"
    ]
  }
  ```

- [x] **Step 2: Write the hub `concepts/index.mdx` (context-economy spine + hero + Cards)**
  Lift the framing + spine prose from the old `concepts.mdx` (lines 8–11 and 42–45) and keep the
  hero import. Cards point only to pages that exist after this increment; increments 2–4 add their
  own cards.
  ```mdx
  ---
  title: Core concepts
  description: woostack's two big ideas — the gated build loop and context economy — and the operational surfaces around them.
  ---

  import { ContextEconomy } from '@/components/concepts/context-economy';

  woostack rests on two ideas. A feature moves through a **gated build loop** so quality is
  enforced by structure, not vigilance. And every step practices **context economy**: the agent's
  working context holds only what the step needs, so it reasons better and runs longer. The pages
  below take each concept on its own.

  ## Context economy

  <ContextEconomy />

  The working context is the scarce resource. A window stuffed with files the current step doesn't
  need is a window that reasons worse and runs out sooner. woostack spends it through three
  mechanisms — recall by scope, compute in the shell, isolate in subagents — and two operational
  surfaces, worktrees and the status board, keep parallel work and collaboration cheap on top.

  <Cards>
    <Card title="Building rules" href="/docs/concepts/building-rules" description="The gated build loop, its three hard gates, and the one-spec-one-plan-N-PRs invariant." />
    <Card title="Memory" href="/docs/concepts/memory" description="The memory and wisdom stores, and how each is recalled." />
    <Card title="Context management" href="/docs/concepts/context-management" description="Scripts compute, subagents isolate, and model tiers route work." />
  </Cards>
  ```

- [x] **Step 3: Tighten the inbound Card in `site/content/docs/index.mdx`**
  The Card already points to `/docs/concepts` (still the hub — no href change). Update only the
  stale description.
  ```mdx
  <Card title="Core concepts" href="/docs/concepts" description="The build loop, context economy, worktrees, and status tracking." />
  ```

- [x] **Step 4: Verify the folder hub resolves and the file/folder don't collide yet**
  (The old `concepts.mdx` still exists at this point — it is deleted in Task 4. Do not build until
  Task 4 removes it, or the route collides. This step only confirms the files were written.)
  Run: `ls site/content/docs/concepts/ && test -f site/content/docs/concepts/index.mdx && echo OK`
  Expected: lists `index.mdx` and `meta.json`; prints `OK`.

### Task 2: Lift the build-loop content into `building-rules.mdx`

**Files:**
- Create: `site/content/docs/concepts/building-rules.mdx`

- [x] **Step 1: Author `building-rules.mdx` from the old page's build-loop sections**
  Move the content verbatim from `concepts.mdx` lines 13–36 (## The build loop, ## Three hard
  gates, ## One spec, one plan, N PRs) under new frontmatter. No semantic change (spec §3).
  ```mdx
  ---
  title: Building rules
  description: The gated build loop, its three hard gates, and the one-spec-one-plan-N-PRs invariant.
  ---

  woostack drives a feature through a fixed, gated chain. The rules below are what make the loop
  trustworthy: a defined order, three places the chain stops for a human, and one invariant that
  keeps every feature's artifacts joined.

  ## The build loop

  [woostack-build](/docs/skills/woostack-build) chains the phases in a fixed, gated order:

  > ideate → write spec → harden spec → **approve spec** → plan → harden plan → ship spec+plan PR
  > → **execution handoff** → execute (per increment: implement → commit → review → distill)

  Each phase is its own skill. Build is the glue that sequences them and owns the handoffs between
  them.

  ## Three hard gates

  The chain only advances past these on an explicit "yes":

  1. **Design approval** is owned by [woostack-ideate](/docs/skills/woostack-ideate).
  2. **Spec approval** happens when the written spec is presented, before any planning begins.
  3. **Execution handoff** is where you choose Go, Run overnight, or Hand off, after the spec+plan PR.

  ## One spec, one plan, N PRs

  Every feature holds the `spec : plan : PRs = 1 : 1 : N` invariant: exactly one plan per spec, and
  that plan owns the N stacked increment PRs. [woostack-status](/docs/skills/woostack-status)
  derives the feature board from these artifacts, so the board is always computed rather than
  hand-maintained.
  ```

- [x] **Step 2: Confirm gate count and invariant are intact (no drift)**
  Run: `grep -c "Design approval\|Spec approval\|Execution handoff" site/content/docs/concepts/building-rules.mdx`
  Expected: `3`
  Run: `grep -F "1 : 1 : N" site/content/docs/concepts/building-rules.mdx`
  Expected: the invariant line prints (non-empty).

### Task 3: Lift the knowledge-store content into `memory.mdx`

**Files:**
- Create: `site/content/docs/concepts/memory.mdx`

- [x] **Step 1: Author `memory.mdx` from the old page's "Two knowledge stores" section**
  Move verbatim from `concepts.mdx` lines 47–86 (### Two knowledge stores, the Callout, the
  consumer table, the lifecycle ASCII fence) under new frontmatter, promoting the `###` headings
  to `##`. This page carries the `lockstep-edit-sites` wisdom-consumer contract content — keep the
  table and the lifecycle diagram exact.
  ```mdx
  ---
  title: Memory
  description: The memory and wisdom stores, and how woostack recalls each — scoped for memory, wholesale for wisdom.
  ---

  woostack keeps two knowledge stores under `.woostack/`, and they load in opposite ways. Memory is
  recalled narrowly, by scope; wisdom is loaded wholesale. Both are local to the clone, so later
  sessions stop repeating earlier mistakes.

  ## Two knowledge stores

  - **`memory/`** holds scoped, per-fact notes. Recall loads only the notes whose `scope` glob
    matches the files in play, plus any notes those link to (one hop out). A change that touches a
    few files pulls in a few notes, not the whole store.
  - **`wisdom/`** holds a small set of generalized, cross-cutting findings. These load *wholesale*:
    every wisdom file, every time a skill gathers design, planning, review, or root-cause
    investigation context, with no scope matching at all.

  <Callout type="info">
    Wisdom is never scope-matched. It loads in full or not at all. Memory is the opposite: only the
    notes whose scope matches the current files are read. An empty or absent store is a no-op either
    way.
  </Callout>

  Different skills reach for different stores, at different moments:

  | Skill | Reads memory (scoped) | Reads wisdom (wholesale) | Moment |
  | --- | :---: | :---: | --- |
  | [woostack-ideate](/docs/skills/woostack-ideate) | — | ✓ | exploring context, before proposing a design |
  | [woostack-plan](/docs/skills/woostack-plan) | — | ✓ | before writing the plan |
  | [woostack-debug](/docs/skills/woostack-debug) | ✓ | ✓ | at the start: known gotchas (scoped) and failure-class hints (wisdom), surfaced as hypotheses to test rather than answers |
  | [woostack-review](/docs/skills/woostack-review) | ✓ | ✓ | prefetch, before the angle subagents run |
  | [woostack-execute](/docs/skills/woostack-execute) | writes | — | distills a note after each increment |
  | [woostack-dream](/docs/skills/woostack-dream) | reads & curates | reads & writes | consolidating trends into wisdom |
  | [woostack-status](/docs/skills/woostack-status) | — | — | derives the board from artifacts only |

  Two skills feed the stores. [woostack-execute](/docs/skills/woostack-execute) distills a scoped
  note after each increment. [woostack-dream](/docs/skills/woostack-dream) is the only writer of
  wisdom, and it rolls recurring trends up from memory and the decision corpus:

  ```
  woostack-execute        ── distill ─────►  memory/   (scoped, per-feature)
  woostack-dream          ── consolidate ─►  wisdom/   (generalized, cross-cutting)

  ideate · plan · review · debug  ── load wholesale ─►  wisdom/
  debug · review                  ── scope-match ────►  memory/
  ```

  Recall is run in the shell, not the prompt: `recall.sh` does the scope match and one-hop
  expansion, and `build-index.sh` keeps `MEMORY.md` as a one-line-per-note index. See
  [Context management](/docs/concepts/context-management) for why that matters.
  ```

- [x] **Step 2: Confirm the consumer table and lifecycle diagram survived the lift**
  Run: `grep -c "woostack-ideate\|woostack-plan\|woostack-execute\|woostack-dream\|woostack-status" site/content/docs/concepts/memory.mdx`
  Expected: ≥ 7 (table rows + prose mentions).
  Run: `grep -F "scope-match ────►  memory/" site/content/docs/concepts/memory.mdx`
  Expected: the lifecycle fence line prints.

### Task 4: Lift scripts+subagents into `context-management.mdx`, delete old file, fix anchor

**Files:**
- Create: `site/content/docs/concepts/context-management.mdx`
- Delete: `site/content/docs/concepts.mdx`
- Modify: `site/content/docs/review-angles.mdx` (repoint the `#subagents-isolate-work` anchor; the
  page itself moves in Increment 4)

- [x] **Step 1: Author `context-management.mdx` from the old page's scripts + subagents sections**
  Move verbatim from `concepts.mdx` lines 88–128 (### Scripts compute, agents read; ### Subagents
  isolate work; the tier table), promoting `###` → `##`. **Keep the exact heading text
  `## Subagents isolate work`** so Fumadocs regenerates the slug `subagents-isolate-work` that
  external links depend on.
  ```mdx
  ---
  title: Context management
  description: How woostack keeps the working context small — scripts compute in the shell, subagents isolate heavy work, and model tiers route each task.
  ---

  Context economy has three mechanisms. One — recall by scope — is the [Memory](/docs/concepts/memory)
  store. The other two live here: shell scripts that compute and return a compact result, and
  subagents that carry heavy work off the main thread. Each returns something small, so the bulk
  never reaches the main context.

  ## Scripts compute, agents read

  woostack ships small shell scripts that do the filesystem, git, and GitHub work and print a compact
  result. The agent reads the result, not the inputs that produced it.

  - `build-index.sh` compresses every memory note down to one index line in `MEMORY.md`, so a skill
    reads the index instead of every note body.
  - `recall.sh` runs the scope match and the one-hop expansion, then emits only the notes that
    matched.
  - `status.sh` reads the specs, plans, and PR state and prints the feature board, so the agent never
    loads all those artifacts itself.
  - `prefetch.sh` gathers a PR's diff, metadata, rules, memory, and wisdom once, and the review
    subagents read those files rather than each re-fetching from GitHub.

  This is what makes recall scale: on a repo with 500 notes, recall loads only the handful that match
  the changed files, not the full corpus. Because the work happens in the shell, the results are
  deterministic and the scripts are idempotent, so they are safe to run anytime, including in CI.

  ## Subagents isolate work

  Some steps hand work to subagents. Each subagent runs in its own context window and returns only a
  compact result, so the heavy reading and reasoning never land in the main thread.

  - [woostack-execute](/docs/skills/woostack-execute) runs inline or with subagents. The smart
    default is subagents where the host can spawn them, inline otherwise. In subagent mode a fresh
    implementer writes each task, then a spec-compliance reviewer and a code-quality reviewer check
    the diff. Each is a separate agent that sees only what it needs.
  - [woostack-review](/docs/skills/woostack-review) fans out one subagent per review angle in
    parallel, then runs two opposing validator passes (one assumes each finding is real, one tries to
    refute it) and keeps only the findings both agree on.

  Each subagent runs at a tier matched to the work, so cheap tasks don't burn an expensive model. The
  tiers map to a concrete model per provider in
  [model-tiers.md](https://github.com/howarewoo/woostack/blob/main/skills/using-woostack/references/model-tiers.md):

  | Tier | Use for | Anthropic model |
  | --- | --- | --- |
  | `fast` | rubric checks, mechanical one-or-two-file tasks, context summaries | `claude-haiku-4-5` |
  | `standard` | reasoning workers, multi-file integration | `claude-sonnet-4-6` |
  | `deep` | code-quality review, design and architecture judgment, skeptical validation | `claude-opus-4-8` |
  ```

- [x] **Step 2: Repoint the anchor link inside the (still top-level) review-angles page**
  In `site/content/docs/review-angles.mdx`, the tier deep link currently targets
  `/docs/concepts#subagents-isolate-work`. The anchor now lives on the context-management subpage.
  Edit line ~54: change `[Core concepts](/docs/concepts#subagents-isolate-work)` to
  `[Core concepts](/docs/concepts/context-management#subagents-isolate-work)`.
  ```
  ... The tier-to-model mapping per provider lives in [Core concepts](/docs/concepts/context-management#subagents-isolate-work), and you can override any tier in [Configuration](/docs/configuration#model-selection).
  ```

- [x] **Step 3: Delete the old monolithic page**
  Run: `git rm site/content/docs/concepts.mdx`
  Expected: `rm 'site/content/docs/concepts.mdx'`.

- [x] **Step 4: Build green — folder hub serves /docs/concepts, no route collision**
  Run: `pnpm -C site build`
  Expected: exits 0; route list includes `/docs/concepts`, `/docs/concepts/building-rules`,
  `/docs/concepts/memory`, `/docs/concepts/context-management`; no collision error for `concepts`.

- [x] **Step 5: Confirm the deep-link anchor heading exists on its new page and is unique**
  Run: `grep -rn "## Subagents isolate work" site/content/docs/concepts/context-management.mdx`
  Expected: one match.
  Run: `grep -rn "/docs/concepts#subagents-isolate-work" site/content/`
  Expected: no matches (the un-subpaged anchor is fully repointed).

- [x] **Step 6: Commit the increment**
  ```bash
  gt create -m "docs(site): scaffold concepts/ section, lift build-loop/memory/context-management"
  ```

---

## Increment 2: Worktrees concept page (parallelism)

> One PR. New page authored from the worktree contract; adds its hub Card and meta.json entry.

### Task 1: Author `worktrees.mdx`

**Files:**
- Create: `site/content/docs/concepts/worktrees.mdx`
- Modify: `site/content/docs/concepts/meta.json` (add `"worktrees"`)
- Modify: `site/content/docs/concepts/index.mdx` (add a worktrees Card)

- [x] **Step 1: Write `worktrees.mdx`** (every claim traces to
  `skills/woostack-init/references/worktrees.md` — spec §4 grounding)
  ```mdx
  ---
  title: Parallelism with worktrees
  description: How woostack runs many builds, fixes, and executions at once by isolating each in its own git worktree.
  ---

  woostack runs several plans at the same time on one machine without collision. The mechanism is
  the **git worktree**: every build, fix, and execution does all of its writes in a private working
  tree, while the primary checkout stays clean on the base branch. Two runs never touch the same
  files, so they never collide.

  ## A worktree per run

  When a run starts, it creates a worktree under `.woostack/worktrees/<slug>`, where `<slug>` is the
  branch name with `/` replaced by `-` (branch `feature/foo` → directory `feature-foo`). The branch
  it creates follows the run:

  | Run | Branch | Worktree directory |
  | --- | --- | --- |
  | [woostack-build](/docs/skills/woostack-build) spec+plan | `feature/<slug>` | `.woostack/worktrees/feature-<slug>` |
  | [woostack-fix](/docs/skills/woostack-fix) | `fix/<slug>` | `.woostack/worktrees/fix-<slug>` |
  | [woostack-execute](/docs/skills/woostack-execute) increment | the plan's increment branch | one per increment |

  The base branch is never hard-coded. A small script, `resolve-base.sh`, resolves it in order: an
  explicit `WOOSTACK_BASE_BRANCH` override, then `base_branch` in
  [`.woostack/config.json`](/docs/configuration), then the remote's default branch, then `main`.
  After the worktree is added, the run registers the Graphite parent from inside it with
  `gt track --parent <base>`, so `gt submit` opens the PR against the right base.

  ## The primary tree stays clean

  This is the invariant that makes parallel runs safe:

  <Callout type="info">
    A run does all its writes in its own worktree. The primary checkout stays on the base branch,
    clean — the stable point every run branches from. Two runs never touch the primary tree, so
    runs with disjoint branch sets never collide.
  </Callout>

  Stacked increments build on each other rather than on the primary tree: increment _k_ branches
  off increment _k–1_'s tip (increment 1 off the spec+plan branch). The shared `.git` and Graphite
  metadata serialize through git's index and ref locks — brief contention, never corruption.

  ## Teardown, and what survives

  - **Success** — once the commit, push, and PR exist, the run removes the worktree directory
    (`git worktree remove`). The branch, commits, and PR persist; only the working directory is
    deleted.
  - **Failure** — on a commit/push error or an unresolved review blocker, the run **leaves the
    worktree in place** and reports its path, so you can inspect it.
  - **Abandon** — a run dropped before any PR exists force-removes the worktree and deletes its
    dangling branch.

  A stale directory left by a crashed run is inert (the `worktrees/` path is gitignored).
  [woostack-doctor](/docs/skills/woostack-doctor) detects an orphaned worktree and prunes it; you
  can also reclaim one by hand with `git worktree prune` / `git worktree remove`.

  Parallelism here is **across independent runs** — several `woostack-build` or `woostack-fix`
  plans in flight at once. Increments within a single plan run sequentially; the worktree's job is
  isolation, not intra-plan concurrency.
  ```

- [x] **Step 2: Add `"worktrees"` to `concepts/meta.json`** (append after `"context-management"`)
  ```json
  {
    "title": "Core concepts",
    "pages": [
      "index",
      "building-rules",
      "memory",
      "context-management",
      "worktrees"
    ]
  }
  ```

- [x] **Step 3: Add the worktrees Card to the hub** (`concepts/index.mdx`, inside `<Cards>`)
  ```mdx
    <Card title="Parallelism with worktrees" href="/docs/concepts/worktrees" description="Run many builds and fixes at once, each isolated in its own git worktree." />
  ```

- [x] **Step 4: Build green and links resolve**
  Run: `pnpm -C site build`
  Expected: exits 0; route list includes `/docs/concepts/worktrees`.
  Run: `grep -F "resolve-base.sh" site/content/docs/concepts/worktrees.mdx && grep -F ".woostack/worktrees/" site/content/docs/concepts/worktrees.mdx`
  Expected: both print (the key contract facts are present).

- [x] **Step 5: Commit**
  ```bash
  gt create -m "docs(site): add worktrees parallelism concept page"
  ```

---

## Increment 3: Status-tracking concept page (collaboration)

> One PR. New page authored from the status conventions; adds its hub Card and meta.json entry.

### Task 1: Author `status-tracking.mdx`

**Files:**
- Create: `site/content/docs/concepts/status-tracking.mdx`
- Modify: `site/content/docs/concepts/meta.json` (add `"status-tracking"`)
- Modify: `site/content/docs/concepts/index.mdx` (add a status Card)

- [x] **Step 1: Write `status-tracking.mdx`** (every claim traces to
  `skills/woostack-status/SKILL.md` + `references/conventions.md` — spec §4 grounding)
  ```mdx
  ---
  title: Collaboration with status tracking
  description: How woostack gives a team a shared feature board that is computed from artifacts in git, never a hand-maintained file.
  ---

  woostack never commits a `STATUS.md`. Instead [woostack-status](/docs/skills/woostack-status)
  **computes** a feature board on demand from artifacts that already live in git — the specs, the
  plans, and the open PRs — and prints it to the terminal. Because the board is derived, it can
  never drift from reality the way a hand-edited status file does, and any teammate gets the same
  board from the same clone.

  ## The phase enum

  Every feature moves through a fixed set of phases. The spec frontmatter owns the design-approval
  phases; once the spec is approved, the plan frontmatter owns the implementation lifecycle:

  > **spec:** `draft → hardened → approved`  ·  **plan:** `planning → ready → executing → in-review → done`
  > (plus the terminal `abandoned`)

  The build loop authors each transition as it advances, and the board reads it. The full enum and
  its join rules are defined once in the
  [status conventions](https://github.com/howarewoo/woostack/blob/main/skills/woostack-status/references/conventions.md).

  ## One spec, one plan, N PRs — joined by artifacts

  The board relies on the `spec : plan : PRs = 1 : 1 : N` invariant. It walks two joins:

  - **spec → plan**: the plan carries a `**Source:** [[specs/<basename>]]` line back to its spec.
  - **plan → PR**: every PR body carries a `Spec: .woostack/specs/<file>.md` trailer.

  Following those joins, the board pairs each spec with its one plan and that plan's N increment
  PRs.

  ## Computed, not authored

  <Callout type="info">
    The board is computed fresh each run and printed to the terminal. It never fetches, commits, or
    pushes, and there is no committed status file. A lagging authored `status:` is reconciled
    against the artifacts, not trusted blindly.
  </Callout>

  For phases before a plan exists, the board shows the spec's authored `status:`. Once execution
  starts, it shows the **computed** phase derived from branches, commits, and PR state — and a
  disagreement between the authored value and the computed one is surfaced as a flag, not displayed
  as truth. The board also flags drift it can prove from the artifacts: an unknown `status:`, a
  missing or duplicate plan, a missing branch for an executing feature, head-state phases while PRs
  already exist, two in-flight rows on one branch, and executing rows older than
  `status.staleDays` (a [config](/docs/configuration) key, default 14).

  Because `status.sh` only reads — it exits 0 even when it prints drift flags — the board is safe
  to run anywhere, including CI, without mutating anything.
  ```

- [x] **Step 2: Add `"status-tracking"` to `concepts/meta.json`** (append after `"worktrees"`)
  ```json
  {
    "title": "Core concepts",
    "pages": [
      "index",
      "building-rules",
      "memory",
      "context-management",
      "worktrees",
      "status-tracking"
    ]
  }
  ```

- [x] **Step 3: Add the status Card to the hub** (`concepts/index.mdx`, inside `<Cards>`)
  ```mdx
    <Card title="Collaboration with status tracking" href="/docs/concepts/status-tracking" description="A shared feature board computed from artifacts in git, never a hand-maintained file." />
  ```

- [x] **Step 4: Build green and facts present**
  Run: `pnpm -C site build`
  Expected: exits 0; route list includes `/docs/concepts/status-tracking`.
  Run: `grep -F "1 : 1 : N" site/content/docs/concepts/status-tracking.mdx && grep -F "staleDays" site/content/docs/concepts/status-tracking.mdx`
  Expected: both print.

- [x] **Step 5: Commit**
  ```bash
  gt create -m "docs(site): add status-tracking collaboration concept page"
  ```

---

## Increment 4: Move review-angles into the section

> One PR. Relocates the existing review-angles page under `concepts/`, repoints its inbound links,
> and removes its top-level nav entry. Content unchanged.

### Task 1: Move the page and repoint everything that referenced it

**Files:**
- Rename: `site/content/docs/review-angles.mdx` → `site/content/docs/concepts/review-angles.mdx`
- Modify: `site/content/docs/concepts/meta.json` (add `"review-angles"`)
- Modify: `site/content/docs/concepts/index.mdx` (add a review-angles Card)
- Modify: `site/content/docs/meta.json` (drop top-level `"review-angles"`)
- Modify: `site/content/docs/configuration.mdx` (repoint the `/docs/review-angles` link)

- [x] **Step 1: Move the file with git (preserves history)**
  Run: `git mv site/content/docs/review-angles.mdx site/content/docs/concepts/review-angles.mdx`
  Expected: no output (success).

- [x] **Step 2: Add `"review-angles"` to `concepts/meta.json`** (append last)
  ```json
  {
    "title": "Core concepts",
    "pages": [
      "index",
      "building-rules",
      "memory",
      "context-management",
      "worktrees",
      "status-tracking",
      "review-angles"
    ]
  }
  ```

- [x] **Step 3: Remove `"review-angles"` from the root nav** (`site/content/docs/meta.json`)
  ```json
  {"title":"Docs","pages":["index","getting-started","concepts","configuration","skills"]}
  ```

- [x] **Step 4: Repoint the inbound link in `configuration.mdx`**
  Line ~82: change `[Review angles](/docs/review-angles)` to
  `[Review angles](/docs/concepts/review-angles)`.
  ```mdx
  See [Review angles](/docs/concepts/review-angles) for the full catalog of all 19 angles: what each one
  ```

- [x] **Step 5: Add the review-angles Card to the hub** (`concepts/index.mdx`, inside `<Cards>`)
  ```mdx
    <Card title="Review angles" href="/docs/concepts/review-angles" description="The catalog of angles woostack-review runs on a PR, and when each one fires." />
  ```

- [x] **Step 6: Build green and no stale `/docs/review-angles` target remains**
  Run: `pnpm -C site build`
  Expected: exits 0; route list includes `/docs/concepts/review-angles`; no `/docs/review-angles`.
  Run: `grep -rn "/docs/review-angles" site/content`
  Expected: no matches.
  Run: `grep -rn '"review-angles"' site/content/docs/meta.json`
  Expected: no matches (it was removed from the root; the concepts/meta.json match is a different file).

- [x] **Step 7: Commit**
  ```bash
  gt create -m "docs(site): move review-angles under concepts section, repoint links"
  ```

---

## Plan Checks

- **Spec coverage** — AC1 (Inc 1 Task 1/4), AC2 (Inc 1 Task 2), AC3 (Inc 1 Task 3), AC4 (Inc 1
  Task 4), AC5 (Inc 2), AC6 (Inc 3), AC7 (Inc 4), AC8 (every increment's build + link-sweep
  steps). All eight ACs map to tasks.
- **AC coverage** — happy/error/edge for each AC land on the verification steps (build green =
  happy; grep-for-zero-stale-targets = error; route-list / heading-uniqueness = edge).
- **No placeholders** — full content for the two new pages; exact line-range mapping + frontmatter
  for the three lifts; exact commands with expected output throughout.
- **Type consistency** — page slugs, the `subagents-isolate-work` anchor text, the hero import
  path `@/components/concepts/context-economy`, and the `meta.json` page ids are consistent across
  all increments.
- **Lockstep (wisdom: `lockstep-edit-sites`)** — the review-angles move touches its full
  inbound set: `configuration.mdx`, root `meta.json`, its own anchor link (fixed in Inc 1), and
  the concepts `meta.json`/hub. The `#subagents-isolate-work` anchor move touches review-angles'
  deep link. No `skills/**` reference points at these pages (verified during hardening).
