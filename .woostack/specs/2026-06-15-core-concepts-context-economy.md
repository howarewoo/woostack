---
name: core-concepts-context-economy
type: spec
status: approved
date: 2026-06-15
branch: feature/core-concepts-context-economy
links:
---

# Core concepts page — context economy rewrite — Design Spec

> Visualize on demand: render this file with [spec-template.html](../../../skills/woostack-build/references/spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → ready → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../../skills/woostack-status/references/conventions.md).

> **Plan:** [[plans/2026-06-15-core-concepts-context-economy]]

## 1. Problem

`site/content/docs/concepts.mdx` is the docs site's "Core concepts" page. Today it is thin: a
build-loop diagram, the three hard gates, and a single one-line mention of the memory store. It
does not explain the three mechanics that make woostack distinctive and that a new user most
needs to understand:

1. **How memory and wisdom get recalled** — and that different skills recall them differently
   (scoped/routed vs wholesale/always-loaded), at different moments.
2. **How shell scripts are run to save agent context** — derive in the shell, read a compact
   result, instead of loading large data into the prompt.
3. **How subagents are used** — isolated context windows, inline-vs-subagent execution, the
   parallel review swarm, and tier/model routing.

The page also has no real visual beyond an ASCII fence, so the relationships between the stores,
the scripts, and the subagents are hard to grasp at a glance.

## 2. Goal

Rewrite `concepts.mdx` so it teaches the three mechanics above accurately, organized around one
unifying idea — **context economy**: keeping the agent's working context small so it reasons
better and longer. Memory recalls scoped, scripts compute in the shell, subagents isolate heavy
work — three expressions of the same principle.

Deliver:
- The context-economy spine section that names the principle and ties the three mechanics
  together.
- Accurate sub-sections for the two knowledge stores (memory vs wisdom), scripts-save-context,
  and subagents.
- One inline-SVG hero diagram (a maintained React component imported into the MDX) that renders
  the context-economy idea, theme-aware (light + dark).
- Native fumadocs visuals elsewhere: ASCII flow diagrams in code fences, a skill→recall mapping
  table, a fast/standard/deep tier table, `<Callout>` for invariants, `<Cards>` for navigation.
- All prose run through the `humanizer` skill as a final step.

## 3. Non-goals

- **No new site dependencies or build-config changes.** No Mermaid, no new npm packages. The
  hero SVG is hand-authored JSX, not a library.
- **Not an exhaustive per-skill reference.** Depth lives on the generated `/docs/skills/*`
  pages; this page links to them rather than restating each skill's full workflow.
- **No changes to other docs pages** (`index.mdx`, `getting-started.mdx`, skills pages) beyond
  what is needed for internal links to resolve.
- **No semantic change to the build loop or gates.** Keep the existing build-loop diagram and
  the three hard gates; tighten wording only.
- **No changes to the skills themselves** (`skills/**`). This is a docs-only feature; the page
  describes existing behavior, it does not alter it.

## 4. Approach

Rewrite the single file `site/content/docs/concepts.mdx` and add one new component under
`site/components/`. Page structure (top to bottom):

1. **One-line framing** — what the page covers.
2. **The build loop** — keep the existing diagram + the three hard gates (design approval, spec
   approval, execution handoff). Tighten wording; no semantic change.
3. **Context economy** (new spine section) — the hero SVG, then the principle stated plainly:
   the agent's working context is the scarce resource; woostack spends it carefully through
   three mechanisms.
   - **Two knowledge stores.** memory = scoped, routed recall (load the few notes whose `scope`
     matches the working set, plus one-hop wikilinks); wisdom = wholesale, always-loaded
     cross-cutting guidance. A mapping table: skill → recalls scoped memory? → loads wholesale
     wisdom? → when. A lifecycle ASCII diagram: `execute distills → memory`, `dream consolidates
     → wisdom`, `ideate/plan/review load wisdom`.
   - **Scripts compute, agents read.** `build-index.sh`, `recall.sh`, `status.sh`, `prefetch.sh`
     do filesystem/git/gh I/O and emit a compact result; the agent reads only that. The
     sub-linear-recall line: on a repo with 500 notes, only the handful matching the changed
     files load, not the full corpus. Scripts are deterministic, idempotent, run-anytime.
   - **Subagents isolate work.** Each subagent runs in its own context window and returns a
     compact result, so heavy work never bloats the main thread. `woostack-execute`
     inline-vs-subagent driver; `woostack-review` parallel angle swarm + adversarial validator;
     fast/standard/deep tier table.
4. **Where to go next** — `<Cards>` linking getting-started, woostack-build, all-skills.

The hero SVG component lives at `site/components/concepts/context-economy.tsx` (a new
`concepts/` subdir under the existing `site/components/`). It uses `currentColor` and fumadocs
theme CSS variables (e.g. `var(--color-fd-*)`) for stroke/fill so it adapts to light/dark with
no JS. Imported into the MDX with `import { ContextEconomy } from '@/components/concepts/context-economy'`.

Factual grounding (cite-and-match, do not contradict): the memory contract
`skills/woostack-init/references/memory.md`, the wisdom contract
`skills/woostack-init/references/wisdom.md`, the tier table
`skills/using-woostack/references/model-tiers.md`, the execute subagent driver
`skills/woostack-execute/references/subagent-driver.md`, and `woostack-review`/`woostack-status`
SKILL.md. Every claim on the page must trace to one of these.

Final step: run the page's prose through the `humanizer` skill and apply its fixes before the
commit.

## 5. Components & data flow

| Artifact | Change |
| --- | --- |
| `site/content/docs/concepts.mdx` | Rewrite. Imports the hero component; adds the four sections. |
| `site/components/concepts/context-economy.tsx` | New. Inline-SVG hero, theme-aware, no new deps. |

Data flow is render-time only: Fumadocs MDX compiles `concepts.mdx`, resolves the component
import, and renders the page. No runtime data, no API. `meta.json` ordering already lists
`concepts`; no change needed.

## 6. Error handling

- **Build must stay green.** `pnpm -C site build` (Next.js production build + typecheck) must
  pass before and after. A bad component import or invalid JSX fails the build.
- **MDX→component import is verified, not assumed.** Before authoring, confirm (a) the `@/`
  path alias resolves in `site/tsconfig.json`, and (b) fumadocs-mdx renders an imported React
  component inside a `.mdx` content file. If either does not hold, fall back to raw inline
  `<svg>` JSX in the MDX (React attribute casing) — same visual, no import.
- **Theme tokens are read from the live site.** The SVG uses the actual fumadocs token names
  found in `site/app/global*.css` (the `--color-fd-*` family) / `currentColor`, not guessed
  variable names. A token that does not exist silently renders transparent — verify against the
  stylesheet.
- **Theme-aware SVG.** The hero must be legible in both light and dark; achieved via theme CSS
  variables / `currentColor`, verified by eye in both modes.
- **Links resolve.** All internal `/docs/...` links and cross-links must resolve (no 404s).
- **No factual drift.** Any statement contradicting the cited contracts is a defect, even if it
  reads well.

## 7. Acceptance criteria

> This is a docs-content feature. "Behavior" here is verifiable content presence + a green
> build, not runtime logic. Cases below are the verification surface.

- **AC1 — Memory vs wisdom recall is explained accurately.**
  - happy: page states memory = scoped/routed recall (scope-match + one-hop wikilink) and wisdom
    = wholesale/always-loaded; includes a skill→recall mapping table covering at least ideate,
    plan, execute, debug, review, dream, status; matches `memory.md` + `wisdom.md`.
  - error: a claim that contradicts the contracts (e.g. "wisdom is scope-matched") is absent.
  - edge: the empty/absent store case is noted as a no-op (matches the contracts).
- **AC2 — Scripts-save-context is explained accurately.**
  - happy: page explains compute-in-shell-read-compact-output, names real scripts
    (`build-index.sh`, `recall.sh`, `status.sh`, `prefetch.sh`), and includes the sub-linear
    recall point.
  - error: no invented script names or fabricated behavior; every named script exists in
    `skills/**`.
  - edge: determinism / idempotent / run-anytime framing is present.
- **AC3 — Subagents are explained accurately.**
  - happy: page explains isolated-context + compact-return; `woostack-execute`
    inline-vs-subagent; `woostack-review` parallel angle swarm + adversarial (prosecutor/defender
    intersection) validator; includes a fast/standard/deep tier table.
  - error: tier names and roles match `model-tiers.md`; no fabricated tiers/models.
  - edge: the smart-default (subagent when host supports it, else inline) is stated.
- **AC4 — Context-economy spine is present and unifying.**
  - happy: a section names the principle and explicitly frames memory-recall, scripts, and
    subagents as three expressions of it.
  - error: the three mechanics are not left as a disconnected grab-bag.
  - edge: N/A.
- **AC5 — One inline-SVG hero renders, theme-aware, no new deps.**
  - happy: `context-economy.tsx` renders an SVG hero in the page; legible light + dark; no new
    entry in `site/package.json` dependencies.
  - error: build does not fail on the import; SVG is not invisible in either theme.
  - edge: respects fumadocs theme tokens rather than hard-coded hex that breaks in one mode.
- **AC6 — Site builds clean and links resolve.**
  - happy: `pnpm -C site build` exits 0; all internal links on the page resolve.
  - error: no TypeScript or MDX compile error introduced.
  - edge: `meta.json` ordering unchanged and still valid.
- **AC7 — Copy is humanized.**
  - happy: the page's prose has been run through the `humanizer` skill and its fixes applied
    (no AI-tell patterns: inflated symbolism, rule-of-three padding, em-dash overuse beyond
    house style, vague attributions).
  - error: N/A (process check).
  - edge: technical terms, code, and script names are preserved verbatim through humanizing.

## 8. Testing

> Strategy only — harness, test levels, fixtures, CI. Per-behavior cases live in §7.

The site has no content unit tests. Verification is:
- **Build gate:** `pnpm -C site build` (production build + typecheck) green before and after —
  the characterization baseline for this docs change.
- **Manual visual check:** load `/docs/concepts` in dev (`pnpm -C site dev`), eyeball the hero
  SVG and tables in light and dark mode.
- **Link check:** confirm internal links resolve (manual or `next build` link surfacing).
- **Factual review:** each mechanics claim cross-checked against its cited contract file (done
  during the review phase).

## 9. Open questions

Resolved during hardening:

1. **Hero SVG subject** → the **context-economy triad** (three mechanisms feeding one small core
   context). It carries the spine; the recall flow is shown as an ASCII fence in the stores
   sub-section instead. *(baked into §4)*
2. **Component location** → `site/components/concepts/context-economy.tsx` (new `concepts/`
   subdir, room to grow). *(baked into §4 / §5)*
3. **Existing build-loop ASCII** → light wording tighten only, no structural change. Stays within
   the "no semantic change to the build loop" non-goal. *(baked into §4)*
4. **MDX→component import viability** → verify the `@/` alias + fumadocs-mdx import support in
   execute; documented fallback to raw inline `<svg>` JSX if unsupported. *(baked into §6)*

None open.
