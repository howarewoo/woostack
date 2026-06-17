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

Decide first whether a render earns its keep. A visual is worth building when the reader needs
to:

- **compare** options or weigh tradeoffs side by side;
- **map relationships** between components, modules, or data;
- **review** an architecture, a state machine, or a control/data flow;
- **approve** a direction and wants the whole shape at a glance;
- **inspect** a multi-file, code-heavy, or data-shaped source too large to hold in prose.

Skip it when the answer is trivial, is already a single number or sentence, or reads more
clearly as plain text or a short code block. A render that only restates a paragraph adds cost
without signal — say so and stop rather than produce filler.

## Procedure

1. **Research before composing.** Read the real source before drawing anything; a render is
   only as honest as what you read. Resolve and read the concrete **files, directories,
   symbols, source sections, data shapes, and existing helpers** the visualization will depend
   on. For a file/glob, read the files. For a directory, read enough structure (entry points,
   key modules, READMEs) to characterize it honestly, and state in the visual what you sampled
   versus read in full. For a free-form subject with no path, build only from what the repo and
   conversation actually contain. Never invent content. If the source cannot be read, stop and
   say so — do not render guesses.
2. **Resolve audience.** A preset loads its profile from
   [references/audiences.md](references/audiences.md). A free-form audience is interpreted
   against the same dimension rubric in that file. Default `engineer`.
3. **Choose visual primitives.** Once the source shape and audience are known, pick the
   sections and diagrams from [references/primitives.md](references/primitives.md) that the
   evidence actually supports. Primitives are an opt-in palette, not a mandatory template:
   include only those the source backs, omit (or mark unknown) any whose evidence is missing,
   and keep composing bespoke for what the palette does not cover.
4. **Compose bespoke HTML.** Design the layout, section set, and diagrams to fit *this*
   content and *this* audience, guided by the audience profile and the chosen primitives — not
   a fixed template. Emit a single self-contained `.html` file: inline `<style>` always;
   diagrams as inline SVG or pure CSS; JavaScript only when it adds real value and can be
   inlined. The file MUST render its core content offline, with no network fetch (no CDN-loaded
   library). For the engineer-audience spec case,
   [woostack-build's spec-template.html](../woostack-build/references/spec-template.html) is an
   available starting point.
5. **Write and report.** Write to `.woostack/visuals/YYYY-MM-DD-<slug>-<audience>.html`
   (derive `<slug>` from the source name/subject; kebab-case a free-form audience to a short
   form). Honor an explicit user-supplied path instead. Print the path and offer to open it
   — do not open a browser unprompted. If `.woostack/` does not exist, write next to the
   source or to a user-supplied path and note that `visuals/` is the default once initialized;
   do not require `/woostack-init`.

## High-stakes self-review

Before reporting the path, when the render covers an **architecture, backend, data model,
migration, security surface, a multi-file change, or any public contract**, re-read the source
against the finished render and confirm:

- every claim, type, file path, and identifier shown traces to real source — nothing invented
  or half-remembered;
- absent metrics, timelines, and benchmarks are omitted or labelled unknown, never filled in;
- the structure the source describes (flows, states, relationships, boundaries) is rendered
  faithfully, with no reordered or fabricated steps;
- anything you sampled rather than read in full is marked as such.

Fix any drift in the render before handing it back. Lower-stakes renders (a single small file,
a plain summary) do not need this pass.

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
