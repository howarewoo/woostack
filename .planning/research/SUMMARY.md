# Project Research Summary

**Project:** Brand Kit (apps/brand) — Design System Living Style Guide
**Domain:** Design system documentation / visual reference app (Next.js monorepo addition)
**Researched:** 2026-03-02
**Confidence:** HIGH

## Executive Summary

This project is a new Next.js app (`apps/brand`) added to the existing monorepo that serves as a living visual reference for the design system. The core value proposition is "always in sync" — components and tokens render from their actual source packages (`@infrastructure/ui-web` and `@infrastructure/ui`) rather than screenshots or hardcoded values. Research confirms this is a lean, well-understood problem space: no authentication, no database, no API calls, no interactive prop editors. The entire app is a single scrollable page with a theme toggle and section anchors.

The recommended approach requires exactly one new dependency: `next-themes@0.4.6` for the light/dark theme toggle. Every other technology (Next.js 16, Tailwind v4, TypeScript, Vitest, shadcn/ui components) is already established in the monorepo. The architecture is deliberately minimal — `ThemeProvider` in `layout.tsx`, static section components in `app/page.tsx`, and no providers beyond the theme toggle. The app should be built to match `apps/landing` as the closest structural analog, not `apps/web` (which carries auth, API client, and navigation infrastructure that brand does not need).

The two most critical risks are both scaffolding-time decisions: (1) the `@source` directive in `globals.css` must be present from day one or all `@infrastructure/ui-web` components will render completely unstyled, and (2) the `transpilePackages` array in `next.config.ts` must include both `@infrastructure/ui` and `@infrastructure/ui-web` or production builds will fail. Both are low-cost to fix if caught early, high-cost if discovered after sections are built on top of a broken foundation.

---

## Key Findings

### Recommended Stack

The core stack requires no new decisions — Next.js 16.1.6, React 19.1.0, Tailwind v4, and TypeScript 5.9.3 are inherited from the monorepo catalog. The only net-new dependency is `next-themes@0.4.6`, which must be added to the workspace catalog. This library handles FOUC prevention, localStorage persistence, system preference detection, and hydration safety with `attribute="class"` — directly compatible with the existing `@custom-variant dark (&:where(.dark, .dark *))` in `@infrastructure/ui/src/globals.css`.

Storybook, Fumadocs, Nextra, `@tanstack/react-query`, and `style-dictionary` are all explicitly out of scope. Token display uses runtime `getComputedStyle` (for live swatch rendering) and the static `tokens.ts` export from `@infrastructure/ui` (for HSL value text labels). No token extraction pipeline or documentation framework is warranted for a 6-component, 14-token reference app.

**Core technologies:**
- `next-themes@0.4.6`: Theme toggle — only new dep; `attribute="class"` is a drop-in with existing monorepo dark variant
- `@infrastructure/ui` (`workspace:*`): CSS custom properties (token swatches), `tokens.ts` (spacing/radius data), `cn()` utility
- `@infrastructure/ui-web` (`workspace:*`): Live component rendering — Button, Card, Input, Label, Separator, Field and sub-exports
- `lucide-react` (catalog, already present): Sun/Moon icons for the theme toggle button

### Expected Features

The feature set is intentionally narrow. Research (grounded in shadcn/ui, zeroheight, and established living style guide patterns) confirms the required categories: color tokens, typography scale, spacing/radius, component showcase, theme toggle, and anchor navigation. No code snippets, no interactive controls, no versioning, no search.

**Must have (table stakes — P1):**
- Light/dark theme toggle — blocks everything else; build first
- Color palette display — 14 semantic tokens with swatch, CSS var name, grouped by semantic role
- Component showcase — all `@infrastructure/ui-web` exports in all variants (resting state)
- Anchor navigation — sticky sidebar or top nav linking each section
- Typography section — Tailwind type scale rendered as live text
- Spacing scale section — visual ruler bars for spacing values from `tokens.ts`
- Border radius display — visual shape examples for sm/md/lg (trivial, include at launch)

**Should have (P2, add after P1 is stable):**
- Live CSS variable readout per theme — `getComputedStyle` value next to each swatch; add when toggling and visually inspecting isn't enough
- Component state showcase — hover/focus/disabled/aria-invalid rows per variant; add when "what does this look like disabled?" is a recurring question

**Defer (v2+):**
- Side-by-side light/dark comparison — forced `.dark` container pattern; defer until toggle-based workflow proves insufficient

### Architecture Approach

The architecture is a single-page Next.js App Router app with no routing complexity. `app/layout.tsx` wraps `ThemeProvider` around the page shell. `app/page.tsx` is a Server Component that imports static section components (`ColorSection`, `TypographySection`, `ComponentSection`, `SpacingSection`). The `ThemeToggle` is the only Client Component needed at launch. No `providers.tsx`, no `AuthProvider`, no `QueryClientProvider`, no `NavigationProvider` — those exist in `apps/web` but have no place here.

**Major components:**
1. `app/layout.tsx` — Root shell: html (with `suppressHydrationWarning`), ThemeProvider, globals.css import
2. `app/page.tsx` — Single-page catalog; assembles all sections; Server Component
3. `components/theme-toggle.tsx` — Client Component; `useTheme()` + lucide Sun/Moon + Button from `@infrastructure/ui-web`
4. `components/sections/color-section.tsx` — Token swatch grid using Tailwind semantic classes (`bg-primary` etc.); token value labels from `tokens.ts`
5. `components/sections/component-section.tsx` — Variant matrix grids for Button, Card, Input, Field, Label, Separator
6. `components/sections/typography-section.tsx` — Tailwind type scale rendered as live text
7. `components/sections/spacing-section.tsx` — Visual ruler bars from `@infrastructure/ui/tokens.ts` spacing data
8. `lib/tokens.ts` — Display metadata array mapping human-readable names to CSS variable names (mirrors `globals.css` token list)

### Critical Pitfalls

Research identified 5 pitfalls, all verified against actual codebase files. The first two are scaffolding blockers that must be correct before any content work begins.

1. **Missing `@source` directive in `globals.css`** — Without `@source "../node_modules/@infrastructure/ui-web/src"` in `apps/brand/app/globals.css`, all `@infrastructure/ui-web` components render completely unstyled. This is the single most likely day-one failure. Prevention: include this line in the initial `globals.css` before writing any section components.

2. **Missing `transpilePackages` in `next.config.ts`** — Without `transpilePackages: ["@infrastructure/ui", "@infrastructure/ui-web"]`, production builds and `pnpm typecheck` fail with module resolution errors even if the dev server appears to work. Prevention: scaffold `next.config.ts` from `apps/landing` as the reference.

3. **Theme toggle FOUC / hydration mismatch** — Without `suppressHydrationWarning` on `<html>` and the `next-themes` inline script approach, the page flashes from light to dark on load and React emits hydration warnings. Prevention: `next-themes` with `attribute="class"` handles both automatically; `suppressHydrationWarning` on `<html>` is required.

4. **Token display shows CSS variable references instead of HSL values** — `getComputedStyle` on `--color-primary` returns `hsl(var(--primary))` (unexpanded), not the actual color. Prevention: use `import { colors } from "@infrastructure/ui"` (the `tokens.ts` static export) for text labels; use Tailwind semantic classes for live swatches.

5. **Missing explicit `dependencies` in `package.json` breaks Turborepo graph** — pnpm hoisting makes imports resolve locally even without declarations, hiding the missing dependency. Turborepo then cannot determine build order or trigger incremental rebuilds. Prevention: declare `"@infrastructure/ui": "workspace:*"` and `"@infrastructure/ui-web": "workspace:*"` in `apps/brand/package.json` from the start.

---

## Implications for Roadmap

The architecture research explicitly maps a build order. The critical path is: scaffold → ThemeProvider → sections (in any order). Pitfall research reinforces that scaffolding must be airtight before any content work begins. Feature dependencies confirm the theme toggle is a prerequisite for everything else.

### Phase 1: App Scaffolding and Foundation

**Rationale:** All 5 critical pitfalls are scaffolding-time decisions. If the foundation is wrong, every subsequent phase builds on broken ground. The scaffolding phase must produce a working, buildable, typecheckable app before any design token or component content is added. Architecture research confirms `apps/landing` is the correct structural reference — copy its `next.config.ts`, `tsconfig.json`, `globals.css`, and `package.json` pattern, then add `next-themes`.

**Delivers:** A working `apps/brand` app at port 3002 that builds, typechecks, passes CI, renders styled output, and toggles dark/light theme with no flash. No design system content yet — just the shell.

**Addresses:** App scaffolding prerequisites (CLAUDE.md new web app checklist); pnpm catalog discipline; port assignment (3002 per PROJECT.md)

**Avoids:** Pitfall 1 (missing `@source`), Pitfall 2 (missing `transpilePackages`), Pitfall 3 (FOUC), Pitfall 5 (missing `package.json` deps)

**Checklist items to verify:**
- `globals.css` contains both `@import "@infrastructure/ui/globals.css"` and `@source "../node_modules/@infrastructure/ui-web/src"`
- `next.config.ts` has `transpilePackages: ["@infrastructure/ui", "@infrastructure/ui-web"]` and `reactCompiler: true`
- `package.json` declares `"@infrastructure/ui": "workspace:*"`, `"@infrastructure/ui-web": "workspace:*"`, `"next-themes": "catalog:"`
- `layout.tsx` has `ThemeProvider` with `attribute="class"` and `suppressHydrationWarning` on `<html>`
- `pnpm --filter brand build` succeeds
- `pnpm typecheck` passes
- Theme toggle renders and toggles correctly with no console hydration warnings
- Port 3002 is used

### Phase 2: Color Tokens and Typography

**Rationale:** Color tokens are the foundation of every design system reference and must come before components, since they establish that the CSS custom property approach works correctly across themes. Typography follows naturally as the second foundational category. Both sections are statically driven — no async data, no component library dependencies beyond what was verified in Phase 1.

**Delivers:** Functional Color Tokens section (14 semantic tokens with swatches and HSL labels, grouped by semantic role, updating on theme toggle) and Typography section (Tailwind type scale rendered as live text). Phase 2 validates the core value proposition of the app: live, always-in-sync design token display.

**Uses:** `getComputedStyle` swatch pattern + `tokens.ts` static import for HSL text labels; Tailwind semantic classes for swatch backgrounds

**Avoids:** Pitfall 4 (token display showing CSS variable references as text labels)

**Implements:** `components/sections/color-section.tsx`, `components/sections/typography-section.tsx`, `lib/tokens.ts`

### Phase 3: Spacing, Radius, and Component Showcase

**Rationale:** Spacing and border radius sections are trivial (low-complexity, self-contained) and complete the foundational token categories. The component showcase is the primary stated purpose of the app per PROJECT.md and should follow once token sections confirm the rendering pipeline works. The component section is the most complex — it requires enumerating all exported components and all variants — and benefits from having a proven foundation.

**Delivers:** Complete foundation token sections (spacing scale, border radius) plus full component showcase covering all `@infrastructure/ui-web` exports in all variants at resting state. This phase brings the app to full v1 scope.

**Uses:** `@infrastructure/ui/tokens.ts` spacing/radius data; variant matrix pattern (all 6 Button variants × key sizes; Card, Input, Field, Label, Separator showcase)

**Avoids:** "Looks done but isn't" checklist items — all exported components must appear (cross-reference `@infrastructure/ui-web/src/index.ts`); port 3002 must be set

**Implements:** `components/sections/spacing-section.tsx`, `components/sections/component-section.tsx`

### Phase 4: Navigation and Polish

**Rationale:** Anchor navigation is table stakes but has no implementation dependencies — it requires all sections to exist before it can meaningfully link to them. This phase finalizes the navigation structure, ensures the page is coherent as a scrollable reference, and addresses any rough edges from the previous phases.

**Delivers:** Sticky sidebar or top nav with section anchors; complete accessible page layout; all "looks done but isn't" checklist items verified

**Addresses:** Section navigation feature (P1); accessibility for the app itself; final verification of all components rendered and all variants covered

### Phase 5: Enhanced Token Display (v1.x)

**Rationale:** Research classifies live CSS variable readout and component state showcase as P2 — meaningful enhancements that add reference value once the basic app is stable. These are separated into their own phase to avoid blocking the v1 launch on non-essential features.

**Delivers:** Live HSL value readout per token per theme (using `getComputedStyle` with memoization); component state showcase rows (hover/focus/disabled/aria-invalid) added to the component section

**Uses:** `getComputedStyle(document.documentElement).getPropertyValue('--primary')` with `useEffect` memoization to avoid layout reflow

**Note:** This phase is optional and driven by real felt need. If the v1 reference proves sufficient, skip this phase.

### Phase Ordering Rationale

- Phase 1 must be first because all 5 critical pitfalls manifest at scaffolding time; building content on a broken foundation wastes effort
- Phases 2 and 3 order follows feature dependencies: theme toggle (Phase 1) unblocks color tokens (Phase 2) which prove the CSS variable approach before component rendering (Phase 3) depends on it
- Phase 4 follows after all sections exist because anchor navigation is only meaningful with complete content
- Phase 5 is decoupled from the launch sequence; it can be inserted between any phases once the core app is stable

### Research Flags

Phases with standard, well-documented patterns (skip `research-phase`):
- **Phase 1:** Standard Next.js app scaffolding. All patterns are directly verified in `apps/landing` and `apps/web`. Copy existing configs. No novel decisions.
- **Phase 2:** CSS custom property reading and Tailwind token display are standard browser APIs. Pattern is well-established.
- **Phase 3:** Component variant matrices are mechanical. Read `@infrastructure/ui-web/src/index.ts` and enumerate.
- **Phase 4:** Anchor navigation with sticky sidebar is standard HTML/CSS. No research needed.
- **Phase 5:** `getComputedStyle` with `useEffect` is standard React pattern. No research needed.

No phases require deeper research. All patterns are verified against the codebase or well-established open web standards. This is a deliberate outcome of scoping the project to avoid novel technical decisions.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Core stack is monorepo-locked; `next-themes` version verified against npm; all patterns directly confirmed in `apps/web` and `apps/landing` source |
| Features | HIGH | Grounded in PROJECT.md scope constraints (authoritative) + established design system tool patterns; no ambiguity about MVP scope |
| Architecture | HIGH | Derived from direct codebase inspection of existing apps; all component boundaries verified; no novel architectural decisions required |
| Pitfalls | HIGH | All 5 critical pitfalls verified against actual codebase files; specific file paths and line numbers confirmed; recovery strategies are low-cost |

**Overall confidence: HIGH**

### Gaps to Address

These are not blocking gaps — they are minor clarifications to resolve during implementation rather than during planning.

- **Dark mode HSL value display:** `tokens.ts` only exports light-mode values. For the dark-mode HSL text label, either (a) read `--primary` channel variable via `getComputedStyle` and format as `hsl(...)`, or (b) hardcode the dark values as a separate constant. Both approaches are valid; the choice can be made during Phase 2 implementation based on which is cleaner.

- **Component variant enumeration:** `@infrastructure/ui-web` exports 15+ symbols including composite Field sub-components (`FieldLabel`, `FieldError`, `FieldDescription`, `FieldGroup`, `FieldSet`, `FieldLegend`). The "looks done but isn't" checklist flags this. During Phase 3, cross-reference `@infrastructure/ui-web/src/index.ts` to enumerate every named export before calling the component section complete.

- **Turbopack vs webpack in dev mode:** Next.js 16 defaults to Turbopack for `next dev`, which does not honor `transpilePackages`. The dev server may behave differently than `pnpm build`. Verify both `pnpm --filter brand dev` and `pnpm --filter brand build` work during Phase 1 before proceeding.

---

## Sources

### Primary (HIGH confidence)
- `/Users/adamwoo/Documents/GitHub/monorepo-template/packages/infrastructure/ui/src/globals.css` — 14 color tokens, dark variant strategy, `@custom-variant dark` definition
- `/Users/adamwoo/Documents/GitHub/monorepo-template/packages/infrastructure/ui/src/tokens.ts` — static spacing, radius, and color exports
- `/Users/adamwoo/Documents/GitHub/monorepo-template/packages/infrastructure/ui-web/src/index.ts` — complete component export list
- `/Users/adamwoo/Documents/GitHub/monorepo-template/apps/web/next.config.ts` — `transpilePackages` reference pattern
- `/Users/adamwoo/Documents/GitHub/monorepo-template/apps/landing/app/globals.css` — `@source` directive reference
- `/Users/adamwoo/Documents/GitHub/monorepo-template/pnpm-workspace.yaml` — catalog versions
- `/Users/adamwoo/Documents/GitHub/monorepo-template/.planning/PROJECT.md` — scope constraints, out-of-scope items, port assignment
- `/Users/adamwoo/Documents/GitHub/monorepo-template/.planning/codebase/CONCERNS.md` — Tailwind v4 `@source` scanning risk flagged

### Secondary (MEDIUM confidence)
- [next-themes GitHub](https://github.com/pacocoursey/next-themes) — `attribute="class"`, `suppressHydrationWarning`, App Router setup
- [shadcn/ui dark mode docs](https://ui.shadcn.com/docs/dark-mode/next) — ThemeProvider configuration
- [shadcn/ui Tailwind v4 docs](https://ui.shadcn.com/docs/tailwind-v4) — CSS variable structure
- [vercel/next.js issue #85316](https://github.com/vercel/next.js/issues/85316) — Turbopack does not honor `transpilePackages`
- [tailwindlabs/tailwindcss issue #13136](https://github.com/tailwindlabs/tailwindcss/issues/13136) — `@source` required for monorepo node_modules scanning

### Tertiary (LOW confidence)
- WebSearch: next-themes npm version 0.4.6 confirmed as current stable (npm page)
- [tweakcn.com](https://tweakcn.com), [zeroheight.com](https://zeroheight.com) — competitor feature analysis for living style guides

---
*Research completed: 2026-03-02*
*Ready for roadmap: yes*
