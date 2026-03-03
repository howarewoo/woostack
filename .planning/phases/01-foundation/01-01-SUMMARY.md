---
phase: 01-foundation
plan: 01
subsystem: ui
tags: [nextjs, tailwind, next-themes, shadcn, react-compiler, typescript]

# Dependency graph
requires: []
provides:
  - apps/brand Next.js app scaffold at port 3002
  - Flash-free light/dark theme toggle via next-themes
  - Full Tailwind v4 + @infrastructure/ui-web integration
  - Production build and typecheck passing
affects: [02-design-tokens, 03-components, 04-typography]

# Tech tracking
tech-stack:
  added: [next-themes@0.4.6, lucide-react (icons)]
  patterns:
    - next-themes ThemeProvider in root layout with attribute="class" and suppressHydrationWarning on <html>
    - mounted guard pattern in client theme-toggle to prevent hydration mismatch
    - @source directive in globals.css for @infrastructure/ui-web Tailwind scanning
    - New Next.js app cloned from apps/landing as structural template

key-files:
  created:
    - apps/brand/package.json
    - apps/brand/next.config.ts
    - apps/brand/tsconfig.json
    - apps/brand/postcss.config.mjs
    - apps/brand/app/globals.css
    - apps/brand/vitest.config.ts
    - apps/brand/components.json
    - apps/brand/app/layout.tsx
    - apps/brand/app/page.tsx
    - apps/brand/components/theme-toggle.tsx
  modified:
    - pnpm-workspace.yaml (added next-themes to catalog)

key-decisions:
  - "Use apps/landing as structural template — it has no auth/API/navigation infrastructure that brand doesn't need"
  - "next-themes@0.4.6 added to pnpm workspace catalog as canonical version entry"
  - "ThemeProvider attribute='class' required to match @custom-variant dark (&:where(.dark, .dark *)) in shared CSS"
  - "mounted guard pattern chosen to prevent hydration mismatch without SSR theme detection complexity"

patterns-established:
  - "New web app template: copy apps/landing config files, change name and port, add app-specific deps"
  - "Theme toggle: useTheme() + mounted guard + placeholder div until client hydrates"
  - "Tailwind scanning: each consuming app must add @source for @infrastructure/ui-web in globals.css"

requirements-completed: [FOUN-01, FOUN-02]

# Metrics
duration: ~30min
completed: 2026-03-03
---

# Phase 1 Plan 01: Brand App Scaffold Summary

**Next.js 16 brand app at port 3002 with flash-free theme toggle using next-themes, Tailwind v4 via @infrastructure/ui-web, and React Compiler enabled**

## Performance

- **Duration:** ~30 min
- **Started:** 2026-03-03T05:20:00Z (estimated)
- **Completed:** 2026-03-03T05:57:22Z
- **Tasks:** 3 (2 auto + 1 human-verify)
- **Files modified:** 11

## Accomplishments
- Scaffolded `apps/brand` as a fully configured Next.js 16 app at port 3002 with all required config files
- Implemented flash-free light/dark theme toggle using next-themes with mounted guard pattern
- Confirmed production build and typecheck pass; human verified no FOUC and no hydration warnings

## Task Commits

Each task was committed atomically:

1. **Task 1: Scaffold apps/brand config files and install dependencies** - `484b40b` (chore)
2. **Task 2: Create layout, page shell, and theme toggle component** - `5d7e98c` (feat)
3. **Task 3: Verify theme toggle works (human-verify checkpoint)** - no code commit (verification only)

**Plan metadata:** `eeb3aeb` (docs: complete brand scaffold plan)

## Files Created/Modified
- `pnpm-workspace.yaml` - Added `next-themes: "0.4.6"` to catalog UI Components group
- `apps/brand/package.json` - App manifest with next-themes, lucide-react, and infrastructure deps; dev server on port 3002
- `apps/brand/next.config.ts` - Next.js config with reactCompiler and transpilePackages for @infrastructure/ui + @infrastructure/ui-web
- `apps/brand/tsconfig.json` - Extends @infrastructure/typescript-config/nextjs.json with path aliases
- `apps/brand/postcss.config.mjs` - @tailwindcss/postcss plugin config
- `apps/brand/app/globals.css` - Imports @infrastructure/ui/globals.css and @source directive for ui-web
- `apps/brand/vitest.config.ts` - Vitest with jsdom environment and passWithNoTests
- `apps/brand/components.json` - shadcn config with base-vega style and @infrastructure/ui utils alias
- `apps/brand/app/layout.tsx` - Root layout with ThemeProvider (attribute="class"), Inter font, suppressHydrationWarning on html
- `apps/brand/app/page.tsx` - Server component shell with "Brand Kit" heading and ThemeToggle in header
- `apps/brand/components/theme-toggle.tsx` - Client component with useTheme(), mounted guard, Sun/Moon icons

## Decisions Made
- Used `apps/landing` as the structural template (not `apps/web`) — landing has no auth/API/navigation infrastructure that brand doesn't need
- Added `next-themes@0.4.6` to pnpm workspace catalog before referencing as `catalog:` in package.json (required pattern for pnpm workspaces)
- `attribute="class"` on ThemeProvider is required — matches the `@custom-variant dark (&:where(.dark, .dark *))` directive in `@infrastructure/ui/globals.css`
- mounted guard pattern in ThemeToggle (show placeholder `<div className="size-9" />` until client hydrates) prevents hydration mismatch without SSR theme detection complexity

## Deviations from Plan

None - plan executed exactly as written. All 5 critical pitfalls from CONTEXT.md were addressed as specified.

## Issues Encountered
None - build, typecheck, and human verification all passed on first attempt.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `apps/brand` is fully scaffolded and ready to receive design system content in Phase 2
- Production build passes, typecheck passes, theme toggling is flash-free
- All 5 scaffolding-time pitfalls locked in: @source directive, transpilePackages, ThemeProvider config, mounted guard, next-themes catalog entry

## Self-Check: PASSED

- FOUND: apps/brand/package.json
- FOUND: apps/brand/next.config.ts
- FOUND: apps/brand/tsconfig.json
- FOUND: apps/brand/postcss.config.mjs
- FOUND: apps/brand/app/globals.css
- FOUND: apps/brand/vitest.config.ts
- FOUND: apps/brand/components.json
- FOUND: apps/brand/app/layout.tsx
- FOUND: apps/brand/app/page.tsx
- FOUND: apps/brand/components/theme-toggle.tsx
- FOUND: .planning/phases/01-foundation/01-01-SUMMARY.md
- FOUND commit: 484b40b (Task 1)
- FOUND commit: 5d7e98c (Task 2)
- FOUND commit: eeb3aeb (metadata)
- Build: pnpm --filter brand build exits 0

---
*Phase: 01-foundation*
*Completed: 2026-03-03*
