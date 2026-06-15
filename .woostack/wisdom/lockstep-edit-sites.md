---
name: lockstep-edit-sites
type: wisdom
category: process
source: source-line-is-multi-reader-contract, memory-source-field-multi-reader, woostack-command-surface-bookkeeping, review-add-angle-sites, review-prompt-self-contained-blob, spec-template-md-html-mirror, plans/2026-06-04-woostack-status, plans/2026-06-06-review-self-contained, pr-376
updated: 2026-06-15
---

Several woostack values are parsed or authored in **N places at once**. Touching one site
without the others half-works or silently desyncs — and the missed site is usually a config
validator, an attribution/footer whitelist, or a committed gating test, not the obvious one.
Before changing such a value, **enumerate every reader/author, move them in lockstep, and
verify the test that pins the joint.**

Known multi-site contracts:

- **Plan `**Source:**` line** — 2 parser regexes (`status.sh` plan-for, `spec-plan-backlink.sh`
  spec-for) + ~5 authoring/contract docs; readers must stay back-compatible with on-disk
  path-form plans. ([[source-line-is-multi-reader-contract]])
- **Memory note `source:`** — parsed by 2 doctor checks (provenance + unresolved-link).
  ([[memory-source-field-multi-reader]])
- **Public command surface** — AGENTS.md (count line, public list, N-skill phrasing,
  rename-constraint, file-map, Mode B) + README + `using-woostack` routing + CONTRIBUTING
  (2 sites) + bootstrap `development.md`. ([[woostack-command-surface-bookkeeping]])
- **A review angle** — ~11 sites: `detect-angles.sh` (predicate + push + header catalog),
  worker prompt, `load-config.sh` VALID_ANGLES, `_header.md` (count word + catalog row +
  Python footer whitelist + findings schema), SKILL.md (conditional + tier), `anthropic.md`
  per-angle tier (+ openai/google/opencode), and the detect-angles test.
  ([[review-add-angle-sites]])
- **Review prompt shared content** — must be **inlined** into the composed blob; CI runners
  follow no relative links. ([[review-prompt-self-contained-blob]])
- **spec-template `.md` / `.html`** — a hand-maintained 1:1 section pair, no generator.
  ([[spec-template-md-html-mirror]])
- **Wisdom-consumer contract** — the set of skills that recall the wisdom store is enumerated in
  N places: `wisdom.md` §6 (consumer list) + §7 (lifecycle diagram), each consuming skill's
  `## Memory` recall section (review / ideate / plan / debug), **and the authored site page
  `site/content/docs/concepts.mdx`** (the consumer table + wholesale-load flow diagram). The site
  page is the easy-to-miss reader: per-skill `.mdx` is generated from `SKILL.md` and gitignored,
  but `concepts.mdx` is hand-authored and tracked. (pr-376)

How to apply: when a value is read/authored in more than one place, treat the **site-list
itself** as the contract. Add a structural test that fails when the sites disagree, and review
the easy-to-miss validators and whitelists last — they are where lockstep edits leak — and remember
authored site/docs pages mirror these contracts too.
