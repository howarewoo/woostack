---
name: woostack-visualize
description: Use when you want an HTML visualization of any source — a spec, plan, file, directory, or concept — tailored to a target audience (engineer, non-technical, investor, or any free-form reader). Reads the real source and writes one self-contained, offline-viewable HTML file; never the source of truth.
---

# woostack-visualize

Turn any source into one self-contained HTML visualization, tailored to who will read it.
The Markdown/code source stays the source of truth; the HTML is a disposable render.

## Command

- `/woostack-visualize <source> [for <audience>]`
  - `<source>` — a spec/plan path, a file, a glob, a directory, or a free-form subject.
  - `<audience>` — a preset (`engineer` | `non-technical` | `investor`) or any free-form
    string ("a security auditor", "a designer"). Defaults to `engineer`.
  - Examples:
    - `/woostack-visualize .woostack/specs/2026-06-03-auth.md for an investor`
    - `/woostack-visualize packages/api for a non-technical PM`
    - `/woostack-visualize the review swarm architecture`

## When to visualize

Use this skill when the task benefits from spatial layout, comparison, or at-a-glance
pattern recognition: side-by-side comparisons, approval reviews, relationship mapping,
architecture or state-machine walkthroughs, multi-file or multi-symbol inspections, and
data-shape or schema exploration. Free-form subjects are supported when the source is
groundable in real repo content.

Skip visualization when the output would be trivial (a single value, a short list) or when
plain prose or a code block is clearly clearer — do not render for rendering's sake.

## Procedure

1. **Research before composing.** Read the actual source before writing a single line of
   HTML. For a file or glob, read the files. For a directory, read enough structure —
   entry points, key modules, READMEs — to characterize it honestly; if the directory is
   large, state your selection criteria and what you skipped, rather than pretending full
   coverage. For a free-form subject, ground every claim in files, directories, symbols,
   source sections, data shapes, or existing helpers that exist in the repo or conversation.
   Never invent content. If the source cannot be read, stop and say so — do not render guesses.
2. **Resolve audience.** A preset loads its profile from
   [references/audiences.md](references/audiences.md). A free-form audience is interpreted
   against the same dimension rubric in that file. Default `engineer`.
3. **Choose visual primitives.** After resolving the audience, select layout and diagram
   primitives from [references/primitives.md](references/primitives.md) that fit this content
   and this audience — not a fixed template.
4. **Compose bespoke HTML.** Design the layout, section set, and diagrams to fit *this*
   content and *this* audience, guided by the audience profile and chosen primitives. Emit a
   single self-contained `.html` file: inline `<style>` always; diagrams as inline SVG or
   pure CSS; JavaScript only when it adds real value and can be inlined. The file MUST render
   its core content offline, with no network fetch (no CDN-loaded library). For the
   engineer-audience spec case, [woostack-build's spec-template.html](../woostack-build/references/spec-template.html)
   is an available starting point.
5. **High-stakes self-review.** For renders that touch architecture, backend internals,
   data models, migrations, security boundaries, multi-file scope, or public contracts,
   run this checklist before handing off:
   - Every claim traces to a real source line, symbol, or file — nothing inferred or invented.
   - The HTML renders its core content offline (no CDN dependency).
   - The framing matches the resolved audience profile.
   - Unknowns and coverage gaps are explicitly labeled in the render, not silently omitted.
   If any item fails, fix the render or report the gap — do not ship a render that hides
   what you do not know. Low-risk or small renders (a single file, a short concept) do not
   require this checklist.
6. **Write and report.** Write to `.woostack/visuals/YYYY-MM-DD-<slug>-<audience>.html`
   (derive `<slug>` from the source name/subject; kebab-case a free-form audience to a short
   form). Honor an explicit user-supplied path instead. Print the path and offer to open it
   — do not open a browser unprompted. If `.woostack/` does not exist, write next to the
   source or to a user-supplied path and note that `visuals/` is the default once initialized;
   do not require `/woostack-init`.

## Hard constraints

- **Source of truth is the source.** Generated HTML is a disposable render. Re-render anytime.
- **Never write into `.woostack/specs/`.** That holds Markdown source only. Renders go to
  `.woostack/visuals/` (gitignored) or a user path.
- **Self-contained and offline.** No CDN, no external fetch to render core content. Inline
  everything. Prefer inline SVG over a network-loaded diagram runtime.
- **No fabrication.** Visualize only what the source contains. When a metric, timeline, or
  benchmark is absent, omit it or mark it unknown — never invent one. This binds hardest for
  the investor audience.
- **Audience is open.** The three presets are shortcuts, not an allow-list; any free-form
  audience is valid, interpreted against the rubric.
- **No browser without consent.** Report the path; open only if the user agrees.
