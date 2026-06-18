---
name: concepts-landing-is-folder-index
type: gotcha
scope: site/content/docs/**
tags: fumadocs, routing, concepts, meta.json, index, shadow-collision, authored-docs
hook: The /docs/concepts landing + nav come from the concepts/ folder (its meta.json + index.mdx), NOT the same-named sibling concepts.mdx — that file is a pre-split orphan that shadow-collides on the route. Add concept-page cards to concepts/index.mdx; never to concepts.mdx.
updated: 2026-06-18
source: [[plans/2026-06-17-site-utilities-page]]
---
In Fumadocs, a `concepts/` folder (with its own `meta.json` + `index.mdx`) and a same-named sibling
`concepts.mdx` both map to the route `/docs/concepts`. The generated `.source/server.ts` registers
**both**, but the **folder** owns the nav node and the served landing — its `meta.json`
(`title: Core concepts`, `pages: [...]`) builds the nav, and `concepts/index.mdx` (`title: Overview`,
the `<Cards>` grid) is what renders at `/docs/concepts`. The standalone `concepts.mdx` is **not** in
any `pages` list, so it is shadowed/orphaned (a leftover the `concepts-page-split` work meant to
delete; #404 even edited it, which is wasted effort on a dead file).

Consequences for site edits:

- Adding/removing a Core-concepts page is a 3-site lockstep: the `concepts/<slug>.mdx` page, the
  `"<slug>"` entry in **`concepts/meta.json`** `pages`, and a `<Card>` in **`concepts/index.mdx`**.
  Editing the orphan `concepts.mdx` (e.g. its "Where to go next" cards) has **no effect** on the
  live landing.
- The `lockstep-edit-sites` wisdom's reference to `concepts.mdx` as the authored mirror is **stale**
  post-split — the consumer table / flow content now lives under `concepts/memory.mdx` etc.
- `pnpm -C site build` tolerates the duplicate (it builds today), so it will **not** warn you off
  the orphan — confirm via `.source/server.ts` and the `pages` lists, not the build.

General lesson that survives the eventual orphan cleanup: a folder's `index.mdx` is the served route
for that folder; do not create a sibling `<folder>.mdx`, and wire new pages through the folder's
`meta.json` + `index.mdx`.
