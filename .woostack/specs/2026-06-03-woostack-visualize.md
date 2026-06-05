---
name: woostack-visualize
type: spec
status: done
date: 2026-06-03
branch: feature/woostack-visualize
links:
---

# woostack-visualize Skill — Design Spec

> Visualize on demand: render this file with [spec-template.html](spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

## 1. Problem

woostack writes specs and plans as markdown (the source of truth) and offers a render-on-demand HTML view. But that render path is a single fixed asset — `skills/woostack-build/references/spec-template.html` — with eight hard-coded sections (Problem, Goal, Non-goals, …). It serves exactly one shape of content (a design spec) for exactly one reader (an engineer).

There is no general way to turn *anything* — a spec, a plan, a module, a directory, a concept — into a visual, and no way to tailor that visual to *who is reading it*. A non-technical stakeholder, an investor, and an implementing engineer each need a different cut of the same source: different depth, different vocabulary, different things surfaced and hidden, different visual density. Today an agent would have to hand-build that HTML each time with no shared contract.

## 2. Goal

Ship a new woostack skill, `woostack-visualize`, that reads any source and writes one self-contained HTML file whose content, depth, vocabulary, and visual density are tailored to a stated **target audience**.

The design must:

- accept varied input: a spec/plan path, an arbitrary file or glob, a directory, or a free-form subject description;
- accept a target audience as either a named preset (`engineer` | `non-technical` | `investor`) or a free-form audience string;
- produce a **bespoke** single HTML file — layout, sections, and diagrams composed to fit the specific content and audience, not slotted into a fixed template;
- produce HTML that is **viewable offline** by opening the file: inline CSS always, diagrams as inline SVG/CSS, no network fetch required to render core content;
- never fabricate data — visualize only what the source contains;
- let `woostack-build`'s "visualize on demand" step delegate to this skill instead of carrying its own render logic;
- add no new runtime dependency (pure agent + filesystem; host-agnostic).

## 3. Non-goals

- Not a documentation generator. Markdown specs/plans remain the authored source of truth; generated HTML is disposable presentation.
- Does not delete or replace `spec-template.html`. That file remains a built-in starting point for the engineer-audience spec case.
- No build step, framework, bundler, or server. No new application code, app lockfile, or CI workflow for this repository.
- Does not add a `requires.bins` dependency. Viewing needs only a browser.
- Does not auto-open a browser without the user agreeing, and does not publish or upload the visual anywhere.
- Does not invent metrics, numbers, timelines, or claims absent from the source (especially relevant for the investor audience).

## 4. Approach

Add a self-contained skill bundle `skills/woostack-visualize/` with a `SKILL.md` and one reference file, and wire four existing docs to it.

The skill procedure is four steps:

1. **Resolve input.** Accept a path (spec/plan/file/dir), a glob, or a free-form subject. The agent reads the actual source files; it never invents content. For a directory, the agent reads enough structure (entry points, key modules, READMEs) to characterize it honestly, and states in the visual what it sampled when it could not read everything.
2. **Resolve audience.** Parse the audience from the invocation. A named preset (`engineer` | `non-technical` | `investor`) loads its profile from `references/audiences.md`. A free-form audience string (e.g. "a security auditor", "a designer") is interpreted by the agent against the same rubric dimensions. Default to `engineer` when no audience is given.
3. **Compose bespoke HTML.** The agent designs the layout, section set, and diagrams to fit *this* content and *this* audience — guided by the audience profile, not a fixed template. Output is a single self-contained `.html` file: inline `<style>` always; diagrams as inline SVG or pure-CSS; JavaScript only when it adds real value and can be inlined; nothing that requires a network fetch to render the core content. For the engineer-audience spec case, `spec-template.html` is an available starting point.
4. **Write and report.** Write to the resolved output path, print it, and offer to open it. Do not open a browser unprompted.

The audience profiles live in `references/audiences.md`, one block per preset plus the shared dimension rubric that also governs free-form audiences. Each profile defines: **surface** (what to show / hide), **depth**, **vocabulary**, **visual density**, and **what this reader cares about**. Sketch:

- **engineer** — surface data flow, interfaces, components, tradeoffs, edge cases; full technical depth; precise technical vocabulary; dense; cares about how it works and how to build/maintain it.
- **non-technical** — surface what it does and why it matters; shallow on mechanism; plain language and analogies, no jargon; moderate density with generous whitespace; cares about outcomes and impact, not implementation.
- **investor** — surface the problem, the opportunity, scope, milestones, and risk; outcome-level depth; business vocabulary; high-signal, low-density, headline-driven; cares about what this is worth and what could go wrong. No code. No fabricated numbers.

## 5. Components & data flow

New files:

- `skills/woostack-visualize/SKILL.md` — frontmatter (`name`, `description`), the `/woostack-visualize` command, the four-step procedure, and hard constraints (self-contained/offline, no fabrication, HTML-is-disposable, no unprompted browser open).
- `skills/woostack-visualize/references/audiences.md` — the three audience profiles and the shared dimension rubric used for free-form audiences.

Command surface:

- `/woostack-visualize <source> [for <audience>]` — e.g. `/woostack-visualize .woostack/specs/2026-06-03-woostack-visualize.md for an investor`. Source defaults to the most recent spec/plan only when context makes it unambiguous; otherwise the skill asks. Audience defaults to `engineer`.

Output location:

- Default `.woostack/visuals/YYYY-MM-DD-<slug>-<audience>.html`. The audience is part of the filename so the three cuts of one source sit side by side instead of overwriting each other (free-form audiences are kebab-cased to a short form). The user may override the path. Generated HTML is treated as disposable (re-render anytime from source) and is gitignored, mirroring `.woostack/metrics.json`. A user may deliberately `git add -f` a visual to share it.
- **Generated HTML never lands in `.woostack/specs/`.** That directory holds Markdown source only. Authoring a spec as HTML (or letting a render settle into `specs/`) is the exact anti-pattern this skill removes: the markdown is the source, the HTML is a disposable render under `visuals/`.

Data flow: source files → agent reads → audience profile (preset file or free-form interpretation) → composed self-contained HTML → written to output path → path reported to user.

Integration edits (cross-link, do not duplicate):

- `skills/woostack-build/SKILL.md` step 2 — the "visualize on demand" sentence delegates to `woostack-visualize` (spec → `engineer` preset; `spec-template.html` as starting point) instead of describing its own render.
- `skills/using-woostack/SKILL.md` — add a `/woostack-visualize` row to the Command Routing table.
- `AGENTS.md` — update "seven shipped skills" → eight; add `woostack-visualize` to the skill list and the Quick file map.
- `README.md` — add `woostack-visualize` to the install collection list and a short "How it works" subsection.
- `.gitignore` — add `.woostack/visuals/` under the woostack section.

## 6. Error handling

- **Unreadable / missing source.** If the source path does not exist or cannot be read, stop and report it; do not emit a visual built on guesses.
- **Directory too large to fully read.** Sample honestly (entry points, key modules, structure), and state in the visual what was sampled versus exhaustively read. Never present a partial read as complete.
- **Unknown audience string.** Any free-form audience is valid — interpreted against the rubric. There is no error path for "unrecognized audience"; the presets are shortcuts, not an allow-list.
- **No fabrication guard.** When a desired element (a metric, a timeline, a benchmark) is not in the source, the agent omits it or marks it explicitly as unknown — it never invents one. This is a hard constraint, called out for the investor audience where the temptation is highest.
- **Output path collision.** If the target file exists, overwrite is fine (visuals are disposable, regenerated from source) — but confirm before overwriting a path the user supplied explicitly and that the skill did not create.
- **`.woostack/` absent (consumer repo not initialized).** The skill still works — write next to the source or to a user-supplied path, and note that `.woostack/visuals/` is the default once initialized. Do not require `/woostack-init`.

## 7. Testing

This skill is Markdown + agent behavior; there is no script to unit-test and **no app build or CI workflow is added for this repository**. Verification is by inspection and exercise:

- **Frontmatter / structure check.** `SKILL.md` has a valid `name`/`description` and does not move or rename any of the existing seven `SKILL.md` files.
- **Cross-link integrity.** Every doc edit (build, using-woostack, AGENTS.md, README.md) links to the new skill; the AGENTS.md count reads "eight"; no dangling relative links.
- **Behavioral exercise.** Render this very spec for each of the three audiences and confirm: each output is a single self-contained file that opens offline (no network), the engineer view carries technical depth, the investor view carries no code and no fabricated numbers, and the non-technical view carries no jargon.
- **No-fabrication exercise.** Render a source that lacks metrics for the investor audience and confirm the output does not invent any.
- **Delegation exercise.** Confirm `woostack-build` step 2 now points at `woostack-visualize` and that following it produces an engineer-audience spec render.

## 8. Open questions

No blocking open questions. Resolved defaults:

- Generated visuals are gitignored and disposable (re-render from source); a user may force-add one to share. Mirrors `.woostack/metrics.json`.
- HTML is fully self-contained and offline-viewable: inline SVG/CSS preferred over any CDN-loaded library (e.g. inline SVG over a network-loaded mermaid runtime).
- `spec-template.html` stays in place as the engineer-spec starting point rather than moving into this skill, to avoid a disruptive cross-link churn; `woostack-build` and `woostack-visualize` both reference it by relative path.
