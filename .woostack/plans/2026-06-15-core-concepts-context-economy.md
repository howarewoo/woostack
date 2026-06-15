---
type: plan
source: .woostack/specs/2026-06-15-core-concepts-context-economy.md
status: executing
branch: feature/core-concepts-context-economy
---

**Source:** [[specs/2026-06-15-core-concepts-context-economy]]

# Core concepts page — context economy rewrite — Implementation Plan

**Goal:** Rewrite `site/content/docs/concepts.mdx` around a context-economy spine that accurately
explains memory/wisdom recall, scripts-save-context, and subagents, with one theme-aware
inline-SVG hero and native fumadocs visuals, then humanize the prose.

**Architecture:** One PR-sized increment. A new self-contained hero component
(`site/components/concepts/context-economy.tsx`) renders the context-economy triad from inline
SVG using fumadocs theme tokens. `concepts.mdx` imports it and is rewritten into four sections
(build loop → context economy → its three mechanics → next-steps cards). No unit runner exists
for MDX content, so each task verifies via the production build plus concrete content/grep/visual
checks (the woostack-tdd no-runner carve-out); the green `pnpm -C site build` before and after is
the characterization baseline. Final task runs the prose through the `humanizer` skill.

**Tech Stack:** Next.js (App Router) · Fumadocs (`fumadocs-ui`, `fumadocs-mdx`) · React · TypeScript
· pnpm. No new dependencies.

---

## Increment 1: Core concepts page — context-economy rewrite

> One PR: a new hero component + a full rewrite of `concepts.mdx`. The component exists only to
> serve this page, so the two ship together as one reviewable, independently shippable slice
> (well under 500 LOC). Stacked on the spec+plan base branch. Builds green.

### Task 0: Verify assumptions before authoring (characterization baseline)

**Files:**
- Read: `site/tsconfig.json`, `site/app/global*.css` (or wherever fumadocs tokens are defined),
  `site/components/mdx.tsx`

- [x] **Step 1: Baseline build is green**
  Run: `pnpm -C site build`
  Expected: PASS (exit 0). Records the pre-change baseline; if it already fails, stop and report
  — do not layer changes on a red build.

- [x] **Step 2: Confirm the `@/` path alias resolves**
  Run: `grep -n '"@/\*"\|"paths"' site/tsconfig.json`
  Expected: a `paths` mapping `@/*` → project root (e.g. `./*` or `./src/*`). Note the real
  prefix for the import line in Task 2.

- [x] **Step 3: Confirm fumadocs renders an imported component inside `.mdx`, and capture token names**
  Action: confirm fumadocs-mdx supports ESM `import` in content `.mdx` (it does — MDX is ESM).
  Run: `grep -rhoE '\-\-color-fd-[a-z-]+' site/app site/node_modules/fumadocs-ui/dist/*.css 2>/dev/null | sort -u | head -40`
  Expected: the real `--color-fd-*` token list (e.g. `--color-fd-foreground`,
  `--color-fd-muted-foreground`, `--color-fd-primary`, `--color-fd-border`, `--color-fd-card`).
  Use only token names that appear here. **Fallback:** if imports turn out unsupported, author
  the SVG as raw inline `<svg>` JSX in the MDX instead (same visual). Record which path is taken.

### Task 1: Add the theme-aware hero component

**Files:**
- Create: `site/components/concepts/context-economy.tsx`

- [x] **Step 1: Author the component**
  A default-exported (and named-exported) React component, no props, returning an inline `<svg>`
  with `role="img"` and an `aria-label`. Renders the **context-economy triad**: three labeled
  nodes — *Scoped recall*, *Scripts compute*, *Subagents isolate* — arrowing into one central
  node *Small working context*. Stroke/fill use the fumadocs tokens captured in Task 0
  (`stroke="var(--color-fd-border)"`, text `fill="var(--color-fd-foreground)"` /
  `var(--color-fd-muted-foreground)`, accent `var(--color-fd-primary)`), never hard-coded hex.
  `viewBox` set; width 100%, height auto; wrapped in a `<figure>` with a `<figcaption>`. React
  attribute casing throughout (`strokeWidth`, `textAnchor`, `strokeLinecap`).

- [x] **Step 2: Verify it type-checks and builds**
  Run: `pnpm -C site build`
  Expected: PASS. A malformed component or bad token reference must not break the build. (The
  component is imported by the page in Task 2; a standalone build here just proves it compiles.)

### Task 2: Rewrite `concepts.mdx`

**Files:**
- Modify: `site/content/docs/concepts.mdx` (full rewrite, keep `title`/`description` frontmatter)

- [x] **Step 1: Author the four sections**
  Preserve the frontmatter. Body, in order:
  1. One-line framing of what the page covers.
  2. **The build loop** — keep the existing ASCII build-loop diagram + the three hard gates
     (design approval, spec approval, execution handoff); tighten wording only, no semantic
     change.
  3. **Context economy** — `import { ContextEconomy } from '<alias>/components/concepts/context-economy'`
     at the top of the file; render `<ContextEconomy />` as the hero; then state the principle
     (working context is the scarce resource; woostack spends it via three mechanisms). Three
     sub-sections:
     - *Two knowledge stores* — memory = scoped/routed recall (scope-match on the working set +
       one-hop wikilink expand); wisdom = wholesale/always-loaded cross-cutting guidance. A
       skill→recall **table** (columns: Skill · Scoped memory · Wholesale wisdom · When) covering
       at least ideate, plan, execute, debug, review, dream, status — values matching
       `memory.md` + `wisdom.md`. A lifecycle ASCII fence: `execute distills → memory/`,
       `dream consolidates → wisdom/`, `ideate · plan · review load wisdom wholesale`. Note the
       empty/absent store is a no-op.
     - *Scripts compute, agents read* — the compute-in-shell / read-compact-output principle;
       name `build-index.sh`, `recall.sh`, `status.sh`, `prefetch.sh`; include the sub-linear
       recall line (500 notes → load only the matching handful); note deterministic / idempotent
       / run-anytime.
     - *Subagents isolate work* — isolated context window + compact return; `woostack-execute`
       inline-vs-subagent (smart default: subagent when the host can spawn, else inline);
       `woostack-review` parallel angle swarm + adversarial prosecutor/defender intersection
       validator; a fast/standard/deep tier **table** matching `model-tiers.md`.
  4. **Where to go next** — `<Cards>` to `/docs/getting-started`, `/docs/skills/woostack-build`,
     `/docs/skills/using-woostack`.
  Use `<Callout>` for one or two key invariants (e.g. "wisdom is never scope-matched — it loads
  in full or not at all"). Every mechanics claim must trace to a cited contract.

- [x] **Step 2: Build + content verification**
  Run: `pnpm -C site build`
  Expected: PASS.
  Run: `grep -ciE 'scoped|wholesale|build-index|recall\.sh|status\.sh|prefetch|inline|subagent|fast/standard/deep|tier' site/content/docs/concepts.mdx`
  Expected: non-zero across the required terms (memory/wisdom recall, script names, subagent +
  tier coverage present).

- [x] **Step 3: Factual cross-check**
  Re-read each mechanics claim against `skills/woostack-init/references/memory.md`,
  `skills/woostack-init/references/wisdom.md`,
  `skills/using-woostack/references/model-tiers.md`,
  `skills/woostack-execute/references/subagent-driver.md`, and the
  `woostack-review`/`woostack-status` SKILLs. Fix any statement that contradicts a contract.

### Task 3: Humanize the prose

**Files:**
- Modify: `site/content/docs/concepts.mdx` (prose only)

- [x] **Step 1: Run the humanizer**
  Invoke the `humanizer` skill on the page's prose. Apply its fixes: remove AI-tell patterns
  (inflated symbolism, rule-of-three padding, vague attributions, em-dash overuse beyond house
  style, filler). **Preserve verbatim:** code fences, script names, component/skill names, table
  cells, links, and frontmatter.

- [x] **Step 2: Final build + visual check**
  Run: `pnpm -C site build`
  Expected: PASS.
  Action: `pnpm -C site dev`, open `/docs/concepts`, confirm the hero SVG and both tables are
  legible in **light and dark** mode and all internal links resolve. Record the check in the PR
  test plan.

---

## Verification summary

- **Automated:** `pnpm -C site build` green at every task boundary (production build + typecheck);
  content `grep` checks for required terms.
- **Manual:** `/docs/concepts` rendered in dev, hero + tables verified in light and dark; internal
  links resolve; prose read for accuracy against the cited contracts.
- **Out of scope:** no content unit tests exist for MDX pages; the build gate + visual check is
  the verification surface (per spec §8).
