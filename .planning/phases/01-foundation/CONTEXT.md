# Phase 1 Context: Foundation

**Phase Goal:** `apps/brand` exists as a working Next.js app at port 3002 that builds, typechecks, and toggles light/dark theme with no flash — before any design system content is added

**Requirements:** FOUN-01, FOUN-02

## Prior Decisions (Locked)

| Decision | Source | Detail |
|----------|--------|--------|
| Structural reference | PROJECT.md | Use `apps/landing` as template — leanest Next.js app, no auth/API/navigation |
| Only new dependency | Research | `next-themes@0.4.6` — add to pnpm workspace catalog |
| Theme strategy | Research | `attribute="class"` on `ThemeProvider`, matches existing `@custom-variant dark` in `@infrastructure/ui/globals.css` |
| Hydration safety | Research | `suppressHydrationWarning` on `<html>` element required |
| Port | PROJECT.md | 3002 (next available after landing:3000, web:3001) |
| Architecture | PROJECT.md | Single-page app, no routing |

## Implementation Defaults

Gray areas not discussed — Claude uses sensible defaults:

- **Theme toggle placement:** Top-right of page in a simple header bar. Phase 4 nav can merge with or replace this.
- **Shell page structure:** Minimal page with heading + theme toggle. No empty section containers — Phase 2/3 will add sections as they're built.
- **Default theme:** Follow OS system preference via `next-themes` `defaultTheme="system"` with `enableSystem`.

## Critical Pitfalls (Must Address)

All 5 pitfalls from research map to this phase:

1. **Missing `@source` directive** — `globals.css` must include `@source "../node_modules/@infrastructure/ui-web/src";`
2. **Missing `transpilePackages`** — `next.config.ts` must list `@infrastructure/ui` and `@infrastructure/ui-web`
3. **Theme FOUC / hydration mismatch** — `next-themes` + `suppressHydrationWarning` handles this
4. **Missing `dependencies` in `package.json`** — Must declare `@infrastructure/ui: "workspace:*"` and `@infrastructure/ui-web: "workspace:*"`
5. **`next-themes` not in catalog** — Must add `next-themes: "0.4.6"` to `pnpm-workspace.yaml` catalog

## Code Context

### Files to Copy from `apps/landing` (then modify)

- `next.config.ts` — already has correct `transpilePackages` + `reactCompiler`
- `package.json` — change name to `brand`, port to 3002, add `next-themes`
- `tsconfig.json` — extends `@infrastructure/typescript-config/nextjs`
- `postcss.config.mjs` — identical (uses `@tailwindcss/postcss`)
- `app/globals.css` — identical (imports `@infrastructure/ui/globals.css` + `@source` directive)

### Files to Create New

- `app/layout.tsx` — add `ThemeProvider` from `next-themes`, `suppressHydrationWarning`
- `app/page.tsx` — minimal shell with heading + `ThemeToggle` component
- `components/theme-toggle.tsx` — `"use client"` component using `useTheme()` + sun/moon icons

### Catalog Addition

```yaml
# pnpm-workspace.yaml catalog addition:
next-themes: "0.4.6"
```

## Success Criteria

1. `pnpm --filter brand dev` starts at port 3002
2. `pnpm --filter brand build` completes without errors
3. `pnpm typecheck` passes with `apps/brand` included
4. Theme toggle switches light/dark with no flash on load
5. No React hydration warnings in browser console

---
*Created: 2026-03-02*
*Gray areas: Skipped (user chose defaults)*
