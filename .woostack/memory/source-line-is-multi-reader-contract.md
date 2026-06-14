---
name: source-line-is-multi-reader-contract
type: gotcha
scope: skills/woostack-status/scripts/**,skills/woostack-doctor/scripts/checks/spec-plan-backlink.sh,skills/woostack-plan/**,skills/woostack-build/SKILL.md,skills/woostack-commit/SKILL.md
tags: Source, spec-plan-join, wikilink, conventions, status.sh, spec-plan-backlink, plan-template, back-compat
hook: The plan **Source:** line is a multi-reader contract — change its format and you must touch both parser regexes plus every authoring/contract doc, and keep readers back-compatible with on-disk path-form plans.
updated: 2026-06-14
source: .woostack/fixes/2026-06-14-plan-source-wikilinks.md
---

The plan→spec join (`**Source:**` line) is read by **two scripts** and authored/described in
**five docs**; reformatting it is never a one-liner. Sites that must move together:

- **Parsers (code):**
  - `status.sh` `plan_for()` — `grep -lE "...specs/<slug>..."` to resolve a spec's plan.
  - `spec-plan-backlink.sh` `spec_for()` — `grep -oE 'specs/...'` to resolve a plan's spec.
- **Authoring + contract (docs):** `plan-template.md` (the body line), `woostack-plan/SKILL.md`,
  `woostack-build/SKILL.md`, `woostack-status/references/conventions.md` (the canonical contract),
  `woostack-commit/SKILL.md` (affected-spec derivation). `doctor/references/checks.md` only
  cross-links conventions, so it needs no per-format edit.

The 2026-06-14 change made the line an Obsidian wikilink — `**Source:**` followed by a
double-bracketed `specs/<basename>` target (symmetric with the spec's `**Plan:**` callout, a
double-bracketed `plans/<basename>` target), so the graph links both ways — **body line only**.
The frontmatter `source:` property stays a path, matching the spec side which carries no plan path
in frontmatter.

How to apply:

- **Readers must accept BOTH forms.** ~46 plans on disk are path-form; a format flip that drops
  legacy support silently breaks resolution for all of them (no migration was done). The wikilink
  regexes were written as supersets: match `specs/<slug>` with an **optional `.md`** and a
  **`]`/space/EOL right boundary** (`status.sh`), and normalize the extracted `specs/<slug>` to one
  `.md` before the file test (`spec-plan-backlink.sh`).
- The `]`/space/EOL boundary preserves the **exact-slug** guarantee — `…-foo` must not match
  `…-foo-bar`. Don't relax it to a bare prefix.
- Test the join through a plan whose **basename differs from the spec basename**, else the
  same-basename slug fallback masks a broken Source parse and the test passes for the wrong reason.
- The plan→PR `Spec:` trailer is a **separate** join (see [[gh-search-fuzzy-trailer-match]]) — it is
  not an Obsidian link and was intentionally left as a path.
