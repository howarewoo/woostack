---
name: site-utilities-page
type: spec
status: approved
date: 2026-06-17
branch: feature/site-utilities-page
links:
---

# Utilities concept page for the docs site — Design Spec

> Visualize on demand: render this file with [spec-template.html](spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → ready → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../woostack-status/references/conventions.md).

> **Plan:** [[plans/2026-06-17-site-utilities-page]]

## 1. Problem

The docs site's **Core concepts** category (`site/content/docs/concepts/`) documents the
build loop and its supporting mechanics, but has no page for the class of skills you invoke
**on demand, outside any flow**. A reader who runs `/woostack-ask` or `/woostack-visualize`
finds only the generated per-skill reference under **Skills** — there is no conceptual page
that names this class, says what unifies it, and explains when to reach for each one. The
membership is currently implicit: nothing tells a reader that `ask`, `visualize`, `status`,
`doctor`, `dream`, and `debug` form a coherent group distinct from the gated build/fix loop
phases.

## 2. Goal

Add one authored concept page, **Utilities**, to the Core-concepts category that:

- Names the class — on-demand skills that complement the build/fix loop but are **not**
  sequential steps in it — and states the unifying trait (each returns a small result and
  hands back; none merge).
- Covers the six members in two natural clusters, each with a short table linking to the
  generated per-skill reference page.
- Is wired into the category exactly like the existing concept pages (nav order + landing
  card grid), with no broken links and a green `pnpm -C site build`.

## 3. Non-goals

- **No new skills, no skill behavior changes.** Pure docs.
- **No change to the public skill-surface count or routing** (AGENTS.md / README /
  `using-woostack`). Utilities is a *concept* page, not a command-surface change.
- **No generated per-skill page edits.** Those regenerate from each `SKILL.md` and are
  gitignored.
- **No inclusion of flow phases that merely have a standalone entry point** (e.g. `tdd`,
  `commit`, `review`). They belong to the loop; out of scope.
- **No restructuring of existing concept pages.** Only additive cross-links where an existing
  page overlaps (status→status-tracking, dream→memory).

## 4. Approach

Add `site/content/docs/concepts/utilities.mdx` as a hand-authored MDX page in the same shape
as sibling concept pages (`status-tracking.mdx`, `review-angles.mdx`): YAML frontmatter
(`title`, `description`), a one-paragraph intro that defines the class, then the body.

**Membership (6), clustered by workspace impact** — the axis is *does the skill mutate your
`.woostack` workspace / repo state?* No → it's a lens you point at the truth; gated-yes → it
proposes changes you approve. This axis is crisp and maps directly to the table's `Writes?`
column.

- **Investigate & present** — read or render the truth; never mutate workspace/repo state:
  - `ask` — answer a question grounded in `.woostack/` + code; cites evidence; writes nothing.
  - `visualize` — render any source to one self-contained HTML; view-only, never the source of
    truth (its only output is a disposable HTML view artifact, not workspace state).
  - `status` — derived feature board from git artifacts; read-only.
  - `debug` — root-cause analysis; writes nothing, hands findings back. **Dual nature:**
    standalone `/woostack-debug <target>` *and* an internal hook that execute/review fire. It
    sits here because its standalone mode is a pure read-only lens; the page states the dual
    nature so a reader isn't misled that it is purely standalone.
- **Tend the workspace** — propose gated mutations to the `.woostack` workspace; nothing
  changes before explicit approval:
  - `doctor` — diagnose + gated repair of `.woostack/` health.
  - `dream` — curate memory/wisdom + docs via a gated changeset.

Each cluster renders as a short Markdown table: `Skill | What it does | Writes? | Invoke`,
with the skill name linking to `/docs/skills/woostack-<name>`. The `Writes?` column carries
the axis: ask/status/debug `no`, visualize `view only (HTML)`, doctor/dream `gated`. A closing
`<Cards>`/"Where to go next" block links back to related concept pages.

The page reuses the existing Fumadocs MDX conventions already used across `concepts/` (front
matter, `<Cards>`/`<Card>`, `<Callout>`); no new components are introduced.

## 5. Components & data flow

Files touched (all under the sanctioned `site/` subtree — Mode A; the build also writes the
`.woostack/` spec+plan):

1. **`site/content/docs/concepts/utilities.mdx`** *(new)* — the page.
2. **`site/content/docs/concepts/meta.json`** — append `"utilities"` to the `pages` array,
   last (after `review-angles`).
3. **`site/content/docs/concepts/index.mdx`** — add a 7th `<Card>` for Utilities to the
   `<Cards>` grid. This folder index (frontmatter `title: Overview`) is the page Fumadocs
   serves at `/docs/concepts` and lists in the Core-concepts nav, so this is the served
   landing's card grid.

**Routing fact (resolved during harden, not an open item):** a *second*, standalone
`site/content/docs/concepts.mdx` (frontmatter `title: Core concepts`, the long-form pre-split
content) also exists and also maps to `/docs/concepts`. The generated `.source/server.ts`
registers both, but the `concepts/` folder — its `meta.json` (`title: Core concepts`, `pages`
list) plus `concepts/index.mdx` — owns the nav node and the served landing; the standalone
`concepts.mdx` is an **orphan** the `concepts-page-split` feature intended to remove and is not
in any `pages` list. **This feature does not touch or delete `concepts.mdx`** — removing the
pre-split orphan is separate cleanup, out of scope here (flagged to the user). The Utilities
card therefore goes only in `concepts/index.mdx`.

This mirrors the **lockstep-edit-sites** wisdom: a new concept page is a multi-site contract
(page + `meta.json` + landing card grid). `pnpm -C site build` verifies the joint — it runs the
`prebuild` skill-page generator then `next build`, proving MDX validity + route generation.
`next build` has **no internal-link checker**, so member-link integrity is guaranteed
structurally instead: the six linked `/docs/skills/woostack-<name>` pages are generated from the
`SKILL.md` sources (all present), with a manual nav/link click as the human backstop.

No runtime data flow: static MDX compiled at build time.

## 6. Error handling

- **Build break:** caught by `pnpm -C site build` (the authoritative gate). The pre-existing
  `concepts.mdx`/`concepts/index.mdx` duplicate already builds today and is left untouched, so
  this change introduces no new route conflict; if the build nonetheless rejects, the fix is
  scoped to the three wiring sites above — never restructuring the category or deleting the
  orphan.
- **Broken skill links:** any `/docs/skills/woostack-<name>` target that doesn't resolve is a
  build/link failure; every linked member must have a generated page (all six do — confirmed in
  `.source/server.ts`).
- **Stale nav:** if `meta.json` omits `utilities`, the page renders but is unreachable from the
  category nav — the index-card + meta entry together are required, not optional.

## 7. Acceptance criteria

- **AC1 — Utilities page exists and renders in the Core-concepts category**
  - happy: `site/content/docs/concepts/utilities.mdx` exists with valid frontmatter
    (`title: Utilities`, a `description`) and appears in the Core-concepts left-nav.
  - error: missing/invalid frontmatter → `pnpm -C site build` fails; not acceptable.
  - edge: page title/slug do not collide with an existing concept page.
- **AC2 — All six members are covered, clustered, and correctly linked**
  - happy: page lists `ask`, `visualize`, `status`, `debug` (Investigate & present) and
    `doctor`, `dream` (Tend the workspace); each links to its `/docs/skills/woostack-<name>`
    reference; `debug`'s dual nature is stated.
  - error: a missing member, a wrong/broken skill link, or an excluded flow phase
    (tdd/commit/review) appearing on the page → not acceptable.
  - edge: workspace-impact axis is visible — the `Writes?` column reads `no` for
    ask/status/debug, `view only (HTML)` for visualize, `gated` for doctor/dream.
- **AC3 — Category wiring is complete and the site builds**
  - happy: `concepts/meta.json` `pages` includes `"utilities"`; `concepts/index.mdx` (the
    served landing) card grid includes a Utilities card; `pnpm -C site build` exits 0.
  - error: `meta.json` omission, missing landing card, or non-zero build → not acceptable.
  - edge: the standalone pre-split `concepts.mdx` orphan is left untouched (not edited, not
    deleted); the card lives only in `concepts/index.mdx`.

## 8. Testing

> Strategy only — harness, test levels, fixtures, CI. Per-behavior cases live in §7.

This is a docs-only change with no unit-test harness for content. Verification is:

- **Build gate:** `pnpm -C site build` must pass — runs the `prebuild` skill-page generator
  then `next build`; the authoritative check for MDX validity and route generation. (It does
  not check internal links; member-link integrity is structural — see §5.)
- **Manual review (recorded in the PR test plan):** Utilities appears in the Core-concepts
  nav and in the landing card grid; all six skill links resolve to their reference pages;
  the two-cluster structure and the `debug` dual-nature note read correctly.

## 9. Open questions

None. Settled during harden: membership (6 incl. `debug`); clustering by workspace impact
(`debug` → Investigate & present); placement (last in `concepts/meta.json`); the served
landing for the card grid is `concepts/index.mdx`; and the standalone `concepts.mdx` is a
pre-split orphan left untouched here (its removal is separate, out-of-scope cleanup flagged to
the user).
