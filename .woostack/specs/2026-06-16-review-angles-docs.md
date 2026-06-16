---
name: review-angles-docs
type: spec
status: approved
date: 2026-06-16
branch: feature/review-angles-docs
links:
---

# Review angles — Docs page Design Spec

> Visualize on demand: render this file with [spec-template.html](spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → ready → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../woostack-status/references/conventions.md).

> **Plan:** [[plans/2026-06-16-review-angles-docs]]

## 1. Problem

The docs site has no human-facing reference for woostack-review's angles. A reader who wants to
know what an angle audits, when it auto-fires, or what model tier it runs at has nowhere to look:

- `configuration.mdx` "Choosing angles" lists the 19 angle **names** and the `force`/`skip`
  semantics only — no meanings, no gating, no tiers.
- The exact gating heuristics live in `skills/woostack-review/scripts/detect-angles.sh` (a shell
  comment header) and the tier assignments live in `skills/woostack-review/SKILL.md` (dense prose
  that reaches the site only as the gitignored generated `skills/woostack-review.mdx`).

Neither is a clean reference page. The angle catalog also already lives in ~11 code sites
(`lockstep-edit-sites` wisdom), so any new copy must be authored to minimize net duplication and
desync risk — not become a 12th verbatim mirror of the gating regexes.

## 2. Goal

Add one authored, tracked docs page — `site/content/docs/review-angles.mdx` — that is the single
human-facing catalog of the review angles: for each angle, what it audits, a plain-language
"fires when" trigger, and its tier. Reduce net site duplication by collapsing
`configuration.mdx`'s inline 19-name list into a cross-link to the new page. The page defers exact
gating and the tier→model mapping to their canonical homes by link, so a future gating tweak does
not silently desync it.

## 3. Non-goals

- No changes to `detect-angles.sh`, `SKILL.md`, angle prompts, or any review script/logic.
- No new angle, no change to which angles exist or how they gate.
- No per-angle deep-dive pages and no new MDX components.
- No restating the tier→model table (lives in `concepts.mdx`) or the exact glob/token heuristics
  (live in `detect-angles.sh`) — cross-link both instead.
- Not touching the generated per-skill `skills/woostack-review.mdx` (regenerated from SKILL.md,
  gitignored).

## 4. Approach

Author `site/content/docs/review-angles.mdx` with this structure:

1. **Frontmatter** — `title: Review angles`, one-line `description`.
2. **Intro** — angles are the lenses woostack-review fans out, one subagent per angle in parallel.
   Cross-link `woostack-review` and `configuration#choosing-angles`.
3. **How angles get chosen** — three facts: `bugs` + `security` always on and never skippable; the
   other 17 auto-detected from the diff (files touched + diff-body tokens); `force`/`skip` override
   detection (`force` wins; bugs/security cannot be skipped) → cross-link configuration.
4. **The catalog** — one Markdown table in canonical alphabetical order (matching `VALID_ANGLES`
   and the current `configuration.mdx` list), columns: **Angle · Audits · Fires when · Tier**, one
   row per angle (19 rows). Plain-language "Fires when" per the gating-depth decision. Immediately
   after the table, a line stating the exact gating heuristics live in `detect-angles.sh` (GitHub
   source link) — the source of truth.
5. **Two callouts** for non-obvious specials: (a) `bugs`/`security` always-on + never-skippable;
   (b) `comments` is always non-blocking (nit-only) and `conventions` only fires when the repo
   carries rule files (AGENTS.md / CLAUDE.md / .cursorrules / .windsurfrules / GEMINI.md).
6. **Tiers** — short paragraph: each angle runs at fast / standard / deep; cross-link
   `concepts#subagents-isolate-work` for the tier→model table rather than restating it.
7. **Where to go next** — `<Cards>`: woostack-review, configuration, concepts.

Then the **lockstep edits**:

- `site/content/docs/meta.json` — add `"review-angles"` to `pages`, between `configuration` and
  `skills`.
- `site/content/docs/configuration.mdx` "Choosing angles" — replace the inline 19-name list with a
  one-line cross-link to `/docs/review-angles`. (Keep the force/skip key table; it is config, not
  catalog.)
- `site/AGENTS.md` — the authored-pages enumeration (the "This rule covers the authored pages only:
  …" line) lists which pages the humanize rule covers. The new page is authored, so add
  `review-angles.mdx` to that list. Missing this desyncs the house-rule scope from the actual
  authored set (`lockstep-edit-sites`).

**House-rule: humanized copy.** `site/AGENTS.md` requires all authored site prose to read as
human-written. The new page must comply (apply the `humanizer` rules by hand or via the skill):
no em/en dashes in prose (the one carve-out is `—` as a "none" placeholder inside a table cell —
not used on this page), `**Label:** desc` not `**Label** — desc`, no false "from X to Y" ranges,
no trailing negations / hollow superlatives / rule-of-three filler. This governs the new page's
wording and the edited `configuration.mdx` line.

Angle source data (confirmed present, 19 angles): `aeo`, `api`, `architecture`, `bugs`,
`comments`, `conventions`, `database`, `deps`, `design`, `docs`, `i18n`, `infra`, `observability`,
`react`, `security`, `seo`, `skills`, `tests`, `types`. "Audits" + "Fires when" summarized from the
`detect-angles.sh` header; "Tier" read from the SKILL.md tier-assignment table.

## 5. Components & data flow

- **`site/content/docs/review-angles.mdx`** (new) — the page. Pure MDX content using the same
  Fumadocs primitives already used on sibling pages (`<Callout>`, `<Cards>`, `<Card>`, Markdown
  tables). Standalone; no data fetching, no generator.
- **`site/content/docs/meta.json`** (edit) — nav ordering; one array insertion.
- **`site/content/docs/configuration.mdx`** (edit) — the "Choosing angles" section loses its
  inline name list, gains a cross-link.

Data flow: none at runtime. The page is static authored content built by `pnpm -C site build`
(Fumadocs / Next.js) into the docs site like every other authored page.

## 6. Error handling

Build-time only. The single failure mode is an MDX/build break (bad frontmatter, malformed JSX,
broken internal link, or a `meta.json` page entry with no matching file). Guard: `pnpm -C site
build` must pass, and the new `meta.json` entry must point at the real new file. No runtime error
surface.

## 7. Acceptance criteria

- **AC1 — The review-angles page exists and builds**
  - happy: `site/content/docs/review-angles.mdx` exists with valid frontmatter; `pnpm -C site
    build` succeeds with the page included.
  - error: a malformed-frontmatter or broken-JSX page fails the build (caught by `pnpm -C site
    build`, the gate).
  - edge: page is reachable in nav because `meta.json` lists `review-angles`; a `meta.json` entry
    with no file (or a file absent from `meta.json`) is caught at build/lint time.
- **AC2 — The catalog covers exactly the 19 valid angles**
  - happy: the catalog table has one row per angle in `load-config.sh`'s `VALID_ANGLES`, same
    names, canonical alphabetical order.
  - error: a row naming a non-existent angle, or a missing angle, is a defect — verified by
    cross-checking the table rows against `VALID_ANGLES` (19 names).
  - edge: `bugs`/`security` appear in the table and are additionally called out as always-on;
    `comments`/`conventions` specials are called out.
- **AC3 — No net new verbatim duplication; canonical homes are linked, not restated**
  - happy: "Fires when" is plain-language; the page links `detect-angles.sh` for exact gating and
    `concepts#subagents-isolate-work` for the tier→model table instead of copying either.
  - error: reproducing the full glob/token regexes or the tier→model table verbatim on the page is
    a spec violation.
  - edge: `configuration.mdx`'s inline 19-name list is replaced by a cross-link (net site
    angle-name lists go from 2 → 1).
  - N/A class: none.
- **AC4 — Authored copy is humanized and the authored-pages list stays in sync**
  - happy: the new page and the edited `configuration.mdx` line carry no em/en dashes in prose,
    no `**Label** — desc` bullets, no rule-of-three filler (the `site/AGENTS.md` rules); the
    carve-out `—` "none" table placeholder is not used here.
  - error: an em/en dash in the page prose, or leaving `review-angles.mdx` out of the
    `site/AGENTS.md` authored-pages enumeration, is a defect.
  - edge: the table itself may use plain hyphens / commas; the no-dash rule is about em/en dashes
    in prose, not hyphenated words.

## 8. Testing

> Strategy only — harness, test levels, fixtures, CI. Per-behavior cases live in §7.

This is an authored docs change; the repo has no app test runner for site content. Verification is
concrete and manual/CI-style:

1. `pnpm -C site build` passes with the new page (the build is the gate, per the CLAUDE.md hard
   constraint to keep the docs site building).
2. Cross-check the catalog rows against `VALID_ANGLES` in
   `skills/woostack-review/scripts/load-config.sh` (19 names, exact set) — done by eye / `grep`
   during execution, not an automated test.
3. Visual smoke: page renders in nav between Configuration and Skills; internal links resolve.
4. Humanize pass: scan the new page + edited `configuration.mdx` line for em/en dashes in prose
   and the other `site/AGENTS.md` AI tells before committing; confirm `review-angles.mdx` is added
   to the `site/AGENTS.md` authored-pages list.

No unit tests are added — there is no code under test, only MDX content.

## 9. Open questions

None outstanding. Resolved during ideation: placement (new dedicated page, configuration's list
shrinks to a cross-link) and gating depth (plain-language trigger, not verbatim heuristic copy).
Resolved during hardening by exploring the repo (no user input needed): the `site/AGENTS.md`
humanize house-rule applies to the new authored page (folded into §4 and AC4), and the
`site/AGENTS.md` authored-pages enumeration is a lockstep site that must add `review-angles.mdx`
(folded into §4 and AC4). Cross-link anchors `#choosing-angles` and `#subagents-isolate-work`
confirmed present in the current pages.
