---
name: concepts-page-split
type: spec
status: approved
date: 2026-06-16
branch: feature/concepts-page-split
links:
---

# Split "Core concepts" into a multi-page section — Design Spec

> Visualize on demand: render this file with [spec-template.html](../../../skills/woostack-build/references/spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → ready → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../../skills/woostack-status/references/conventions.md).

> **Plan:** [[plans/2026-06-16-concepts-page-split]]

## 1. Problem

`site/content/docs/concepts.mdx` is a single long "Core concepts" page that bundles several
distinct ideas: the gated build loop, the three hard gates, the `1:1:N` invariant, and the whole
"context economy" umbrella (memory vs wisdom stores, scripts-compute-agents-read, subagents,
model tiers). It is hard to scan, hard to deep-link, and two concepts a new user most needs are
**absent or thin**:

- **Parallelism via git worktrees** — not on the page at all, despite being a headline selling
  point on the landing page ("Parallel by default … more than a dozen concurrent sessions").
- **Collaboration via the derived status board** — only the `1:1:N` invariant appears; the phase
  enum, the computed-not-authored board, drift/staleness flags, and "no committed STATUS.md" are
  not explained.

`review-angles` is already its own top-level page (`/docs/review-angles`) but sits outside the
concepts grouping, so the conceptual surface is split inconsistently across the nav.

## 2. Goal

Replace the single `concepts.mdx` file with a `concepts/` **section** (a Fumadocs folder, the
same pattern `skills/` already uses) whose hub lives at `/docs/concepts` and whose focused
subpages each teach one concept. Deliver:

- A hub `index.mdx` at `/docs/concepts` that states the unifying **context-economy** spine,
  renders the existing context-economy hero component, and `<Cards>` to every subpage. Keeping
  the `/docs/concepts` URL alive means existing inbound Cards never 404.
- Subpages, one concept each:
  - **building-rules** — the gated build loop, the three hard gates, the `1:1:N` invariant.
  - **memory** — memory vs wisdom stores, recall mechanics, and the wisdom-consumer table +
    lifecycle diagram (the `lockstep-edit-sites` contract content, preserved on this page).
  - **context-management** — the context-economy principle, scripts-compute-agents-read,
    subagents-isolate, and the `fast`/`standard`/`deep` model-tier table. Hosts the
    `#subagents-isolate-work` anchor that `review-angles` deep-links.
  - **worktrees** — parallelism via git worktrees (new content).
  - **status-tracking** — collaboration via the derived board (new content).
  - **review-angles** — moved in from `/docs/review-angles` to `/docs/concepts/review-angles`.
- All inbound links repointed so nothing 404s, and `pnpm -C site build` stays green.

## 3. Non-goals

- **No new site dependencies or build-config changes.** No new npm packages, no Mermaid. The
  hero stays the existing hand-authored JSX component; it is moved/imported, not rewritten.
- **No new factual claims beyond what the source contracts state.** Every claim on every page —
  including the two new pages — must trace to a cited contract file (see §4 grounding). This is a
  re-organization plus two new pages built from existing source facts, not a rewrite of doctrine.
- **No changes to `skills/**` at all.** This is docs-only. Hardening confirmed no `SKILL.md`,
  reference doc, or README links to `/docs/review-angles` or `/docs/concepts`, and `wisdom.md`
  never names `concepts.mdx` — so moving pages breaks no skill-side reference. The only stale
  path reference is in the dream-owned `.woostack/wisdom/lockstep-edit-sites.md` note, left for
  `woostack-dream` to re-curate (see §9 Open question 1).
- **Not an exhaustive per-skill reference.** Depth stays on the generated `/docs/skills/*` pages;
  concept pages link to them.
- **No redirect infrastructure.** `/docs/review-angles` moves to `/docs/concepts/review-angles`;
  we fix inbound links rather than add a redirect (the prior URL was only ~2 weeks live and only
  internal links point at it). If §9 surfaces external inbound links, revisit.

## 4. Approach

**Mechanism (verified during hardening).** Fumadocs-core 16's `loader` maps a folder's
`index.mdx` to that folder's route: the existing `content/docs/index.mdx` serves `/docs`, which
proves index→folder-root mapping. So `concepts/index.mdx` serves `/docs/concepts`. There is **no
sibling-file fallback**: a `concepts.mdx` file and a `concepts/` folder would collide on the same
route, so the folder + `index.mdx` hub is the only valid shape — `concepts.mdx` must be deleted
as the folder is created. The root `meta.json` entry `"concepts"` resolves to the folder
unchanged (it is a path id, file-or-folder agnostic). Execute-time check is confirmatory only:
`pnpm -C site build` plus a load of `/docs/concepts`.

**File operations:**

1. Create `site/content/docs/concepts/` with a `meta.json` ordering the subpages.
2. Author `concepts/index.mdx` (hub): context-economy spine paragraph + `<ContextEconomy />`
   hero + `<Cards>` to the six subpages. Import path for the hero is unchanged
   (`@/components/concepts/context-economy`); the component file does not move.
3. Author the six subpages, each lifting the relevant content out of the current
   `concepts.mdx` verbatim where it exists (building-rules, memory, context-management) and
   authoring fresh, contract-grounded content for the two new ones (worktrees, status-tracking).
   `review-angles.mdx` moves wholesale into the folder.
4. Delete the old `site/content/docs/concepts.mdx` and the old top-level
   `site/content/docs/review-angles.mdx`.
5. Update `site/content/docs/meta.json`: drop `"review-angles"` from the top-level list (it now
   lives under the `concepts` section); keep `"concepts"`.
6. Repoint inbound links (see §5 table).

**Anchor preservation.** The current page's section ids that are deep-linked must survive on
their new page. Known external deep-link: `#subagents-isolate-work` (from `review-angles`),
which moves to `/docs/concepts/context-management#subagents-isolate-work`. Use the same heading
text so Fumadocs generates the same slug.

**Grounding (cite-and-match — every claim traces to one of these):**
- build loop / gates: `skills/woostack-build/SKILL.md`.
- `1:1:N`, phase enum, computed board, drift/staleness, no committed STATUS.md:
  `skills/woostack-status/SKILL.md`, `skills/woostack-status/references/conventions.md`.
- memory recall (scope glob + one-hop wikilink) and scripts (`recall.sh`, `build-index.sh`,
  `scope-match.sh`): `skills/woostack-init/references/memory.md`.
- wisdom wholesale load + consumer list/lifecycle: `skills/woostack-init/references/wisdom.md`.
- worktrees (disk layout, branch naming, `resolve-base.sh`, `gt track`, teardown,
  leave-on-failure, primary-tree-clean invariant):
  `skills/woostack-init/references/worktrees.md`.
- tiers: `skills/using-woostack/references/model-tiers.md`.
- scripts `status.sh` / `prefetch.sh`: their respective skill scripts.

**Copy quality.** The `humanizer` skill is installed (confirmed during hardening); run
new/edited prose through it as a final step before commit. Technical terms, code, script names,
and enum values stay verbatim through humanizing.

## 5. Components & data flow

| Artifact | Change |
| --- | --- |
| `site/content/docs/concepts/meta.json` | New. Orders the section: `index`, `building-rules`, `memory`, `context-management`, `worktrees`, `status-tracking`, `review-angles`. |
| `site/content/docs/concepts/index.mdx` | New hub. Context-economy spine + `<ContextEconomy />` hero + `<Cards>`. |
| `site/content/docs/concepts/building-rules.mdx` | New. Build loop + 3 gates + `1:1:N` (lifted from `concepts.mdx`). |
| `site/content/docs/concepts/memory.mdx` | New. Two stores + recall + consumer table + lifecycle diagram (lifted). |
| `site/content/docs/concepts/context-management.mdx` | New. Principle + scripts + subagents + tier table (lifted); owns `#subagents-isolate-work`. |
| `site/content/docs/concepts/worktrees.mdx` | New. Parallelism via worktrees (authored from `worktrees.md`). |
| `site/content/docs/concepts/status-tracking.mdx` | New. Derived board (authored from status conventions). |
| `site/content/docs/concepts/review-angles.mdx` | Moved from `site/content/docs/review-angles.mdx`; internal anchor link to `#subagents-isolate-work` repointed to `/docs/concepts/context-management#subagents-isolate-work`. |
| `site/content/docs/concepts.mdx` | Deleted. |
| `site/content/docs/review-angles.mdx` | Deleted (moved). |
| `site/content/docs/meta.json` | Drop `"review-angles"` from top-level pages. |
| `site/content/docs/index.mdx` | Card to `/docs/concepts` stays; description tightened. |
| `site/content/docs/configuration.mdx` | `/docs/review-angles` → `/docs/concepts/review-angles`; any `#model-selection`/anchor links audited. |
| `site/components/concepts/context-economy.tsx` | Unchanged (imported by the new hub). |

Inbound-link audit (the lockstep set — every reader moved together):
- `index.mdx:63` → `/docs/concepts` (Card) — still resolves to the hub; tidy copy only.
- `review-angles.mdx:54` → `/docs/concepts#subagents-isolate-work` — becomes
  `/docs/concepts/context-management#subagents-isolate-work` (now a same-section link).
- `review-angles.mdx:61` → `/docs/concepts` (Card) — still resolves to the hub.
- `configuration.mdx:82` → `/docs/review-angles` — becomes `/docs/concepts/review-angles`.
- root `meta.json` top-level `"review-angles"` — removed.
- Execute-time sweep: `grep -rn "/docs/review-angles\|/docs/concepts" site/` after edits to
  confirm zero stale targets, plus a check of `skills/**` for any hard `/docs/review-angles`
  or `/docs/concepts#...` link that a generated skill page would emit.

Data flow is render-time only: Fumadocs compiles the MDX tree, resolves the hero import, builds
the nav from the `meta.json` files. No runtime data, no API.

## 6. Error handling

- **Build must stay green.** `pnpm -C site build` (production build + typecheck + MDX compile +
  link surfacing) must pass after the change. A broken import, invalid frontmatter, or a missing
  `meta.json` page id fails the build.
- **No 404s / no dangling anchors.** Every internal `/docs/...` link resolves, and the
  `#subagents-isolate-work` anchor exists on its new page. A moved page with an unrepointed
  inbound link is a defect even if the build is green (Next can build with a dead in-content
  link).
- **Hub URL preserved.** `/docs/concepts` must still serve a page after the file→folder
  conversion; verified per §4's fallback.
- **No factual drift.** Any statement on any page that contradicts a cited contract is a defect,
  even if it reads well. The two new pages are the highest-risk surface — every claim traces to
  `worktrees.md` / status conventions.
- **No content lost in the lift.** Content moved out of `concepts.mdx` (the consumer table, the
  lifecycle diagram, the tier table, the gate list) must appear, intact, on exactly one subpage.

## 7. Acceptance criteria

> This is a docs-content + IA feature. "Behavior" is verifiable content/route presence + a green
> build, not runtime logic.

- **AC1 — `concepts/` section exists and the hub serves `/docs/concepts`.**
  - happy: `concepts/index.mdx` + `concepts/meta.json` exist; `/docs/concepts` renders the hub
    with the context-economy spine, the `<ContextEconomy />` hero, and `<Cards>` to all six
    subpages; the old `concepts.mdx` is gone.
  - error: build does not fail on the file→folder conversion; no orphaned `concepts.mdx`.
  - edge: root `meta.json` still lists `"concepts"` and it resolves to the folder.
- **AC2 — building-rules page is accurate.**
  - happy: page covers the gated build loop, the three hard gates (design, spec, execution
    handoff), and the `1:1:N` invariant, matching `woostack-build/SKILL.md`.
  - error: no gate count drift (exactly three hard gates) and no invented phases.
  - edge: links to `/docs/skills/woostack-build` and `/docs/skills/woostack-ideate` resolve.
- **AC3 — memory page is accurate and carries the lockstep contract content.**
  - happy: explains memory = scoped/routed recall (scope-match + one-hop wikilink) vs wisdom =
    wholesale/always-loaded; includes the skill→recall consumer table (≥ ideate, plan, execute,
    debug, review, dream, status) and the lifecycle diagram; matches `memory.md` + `wisdom.md`.
  - error: no claim that wisdom is scope-matched; named scripts (`recall.sh`, `build-index.sh`)
    exist.
  - edge: the empty/absent-store no-op is stated.
- **AC4 — context-management page is accurate and owns the tier anchor.**
  - happy: states the context-economy principle, scripts-compute-agents-read (real script
    names), subagents-isolate (execute inline-vs-subagent; review parallel angle swarm +
    adversarial validator), and the `fast`/`standard`/`deep` tier table matching
    `model-tiers.md`; the section that the tier table lives in has id `subagents-isolate-work`.
  - error: tier names/roles match the contract; no fabricated tiers.
  - edge: `review-angles`'s deep link resolves to this anchor.
- **AC5 — worktrees page is accurate (new content).**
  - happy: explains worktrees live at `.woostack/worktrees/<slug>`, `feature/<slug>` /
    `fix/<slug>` branch naming, base via `resolve-base.sh`, `gt track --parent`, teardown on
    success, leave-on-failure, and the primary-tree-stays-clean invariant that makes parallel
    runs safe; matches `worktrees.md`.
  - error: no invented paths or flags; parallelism is framed as across independent runs (build /
    fix / execute), not concurrent tracks within one plan.
  - edge: links to the build/execute/fix skill pages resolve.
- **AC6 — status-tracking page is accurate (new content).**
  - happy: explains the phase enum (`draft → … → done` + `abandoned`), the `1:1:N` join, that
    the board is **computed** from artifacts (specs/plans/PR trailers) rather than authored, the
    drift + staleness flags, and that there is no committed `STATUS.md`; matches the status
    conventions.
  - error: enum values match `conventions.md`; no invented config keys (`status.staleDays`
    default 14 stated correctly).
  - edge: links to `/docs/skills/woostack-status` and `/docs/configuration` resolve.
- **AC7 — review-angles moved cleanly.**
  - happy: page serves at `/docs/concepts/review-angles`; its content is intact; its internal
    tier deep link points at `/docs/concepts/context-management#subagents-isolate-work`.
  - error: old `/docs/review-angles` route is gone and no inbound link still targets it
    (`configuration.mdx` repointed; root `meta.json` entry removed).
  - edge: the catalog table and both `<Callout>`s survive the move unchanged.
- **AC8 — site builds clean and every internal link resolves.**
  - happy: `pnpm -C site build` exits 0; `grep` shows zero stale `/docs/review-angles` and zero
    `/docs/concepts#subagents-isolate-work` (un-subpaged) targets in `site/`.
  - error: no TypeScript/MDX compile error; no `meta.json` references a missing page id.
  - edge: nav renders the concepts section with its subpages in the `meta.json` order.

## 8. Testing

> Strategy only — harness, levels, fixtures, CI. Per-behavior cases live in §7.

The site has no content unit tests. Verification is:
- **Build gate (characterization baseline):** run `pnpm -C site build` once before any edit to
  capture a green baseline, then again after — both green. The site build runs in a worktree, so
  it needs real `node_modules` (see memory: `site-build-in-worktree-needs-real-node-modules`);
  the increment must ensure deps are installed in the execution tree before building.
- **Link sweep:** `grep -rn "/docs/review-angles\|/docs/concepts" site/` post-edit; assert no
  stale targets; spot-check the moved anchor.
- **Factual review:** each claim on the two new pages cross-checked against its cited contract
  during the review phase (the `docs` and `conventions` review angles will fire on this PR).
- **Manual visual check (optional):** `pnpm -C site dev`, load `/docs/concepts` and each subpage,
  eyeball the hero in light + dark and confirm nav ordering.

## 9. Open questions

All resolved during hardening:

1. **Repoint the wisdom-consumer contract's doc reference? → No (leave it).** Hardening found
   `wisdom.md` does **not** name `concepts.mdx`; only the dream-owned
   `.woostack/wisdom/lockstep-edit-sites.md` note does. No skill contract references the page, so
   there is nothing in `skills/**` to repoint. The consumer table + lifecycle diagram survive
   intact on `concepts/memory.mdx`, so the contract content is preserved; the dream-owned note is
   left for `woostack-dream` to re-curate (build does not write wisdom).
2. **File→folder vs sibling-file hub → folder + `index.mdx`, confirmed.** Fumadocs-core 16 maps a
   folder's `index.mdx` to the folder route (proven by `content/docs/index.mdx` → `/docs`). A
   sibling `concepts.mdx` would collide with the folder, so deleting it is mandatory, not
   optional. No fallback exists or is needed.
3. **Increment slicing → deferred to `woostack-plan`.** Working hypothesis: (A) scaffold folder +
   hub + lift building-rules/memory/context-management + delete old `concepts.mdx` + fix the two
   hub Cards → green build; (B) worktrees page; (C) status-tracking page; (D) move review-angles +
   repoint `configuration.mdx`, root `meta.json`, and its own anchor link. Each must be an
   independently green, reviewable PR. Final boundaries are a planning decision.

None open.
