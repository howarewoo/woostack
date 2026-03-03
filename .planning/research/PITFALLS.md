# Pitfalls Research

**Domain:** Design system brand kit documentation app — Next.js + Tailwind v4 monorepo
**Researched:** 2026-03-02
**Confidence:** HIGH (all critical pitfalls verified against actual codebase files)

---

## Critical Pitfalls

### Pitfall 1: Missing `@source` Directive Leaves Components Completely Unstyled

**What goes wrong:**
The new Next.js app at `apps/brand` renders `@infrastructure/ui-web` components (Button, Card, Field, etc.) but they appear completely unstyled — no colors, no spacing, no borders. The app "works" but looks broken. This is the single most likely failure mode on day one.

**Why it happens:**
Tailwind v4 is CSS-first and does not auto-scan workspace packages in `node_modules`. It only scans files reachable from the CSS entry point. Without an explicit `@source` directive, every Tailwind utility class used inside `@infrastructure/ui-web/src` is missing from the compiled CSS. The two existing apps (`apps/web` and `apps/landing`) both carry this directive in their `app/globals.css` — it is easy to forget when scaffolding a third app.

Verified in codebase: `apps/web/app/globals.css` line 3 and `apps/landing/app/globals.css` line 3 both contain `@source "../node_modules/@infrastructure/ui-web/src";`. The `CONCERNS.md` file explicitly flags this as a known risk for future apps.

**How to avoid:**
The `globals.css` for `apps/brand` must contain both lines from the start:
```css
@import "@infrastructure/ui/globals.css";

@source "../node_modules/@infrastructure/ui-web/src";
```
This is a checklist item that must appear in the scaffolding phase, not discovered later.

**Warning signs:**
- Components render as plain HTML with no visual style
- Browser DevTools shows no Tailwind utility classes in the computed styles for those components
- Works in `apps/web` with the same import, but not in `apps/brand`

**Phase to address:**
App scaffolding (Phase 1 / foundation). Must be in the initial `globals.css`, not added retroactively.

---

### Pitfall 2: Missing `transpilePackages` Breaks TypeScript and Build

**What goes wrong:**
The build compiles fine locally during development (Next.js dev server is tolerant) but `pnpm build` fails with module resolution errors, or TypeScript types from `@infrastructure/ui-web` are not resolved, producing type errors that block CI.

**Why it happens:**
Next.js requires workspace packages that ship TypeScript source (not pre-compiled) to be listed in `transpilePackages` in `next.config.ts`. Both `apps/web` and `apps/landing` list `@infrastructure/ui` and `@infrastructure/ui-web` here. A new app that omits them gets inconsistent behavior: dev server may work (Turbopack/webpack handles some cases), but production builds and type checking fail.

Verified in codebase: `apps/web/next.config.ts` lists `@infrastructure/ui`, `@infrastructure/ui-web`, `@infrastructure/utils`, `@infrastructure/api-client`, `@infrastructure/navigation` in `transpilePackages`. For the brand app (which only needs `@infrastructure/ui` and `@infrastructure/ui-web`), at minimum those two must be present.

**How to avoid:**
Scaffold `apps/brand/next.config.ts` with `transpilePackages: ["@infrastructure/ui", "@infrastructure/ui-web"]` from the start. Pattern is directly established in `apps/landing/next.config.ts` (the closest analog — same minimal dependency set).

**Warning signs:**
- `Module not found: Can't resolve '@infrastructure/ui-web'` during `pnpm build`
- TypeScript errors like `Cannot find module '@infrastructure/ui-web'` during `pnpm typecheck`
- Dev server works but `pnpm --filter brand build` fails

**Phase to address:**
App scaffolding (Phase 1). Cannot proceed to token display or component rendering without this working.

---

### Pitfall 3: Theme Toggle Causes FOUC (Flash of Unstyled Content) or Hydration Mismatch

**What goes wrong:**
The light/dark theme toggle works interactively but causes a visible flash on page load — the page renders in light mode, then snaps to dark mode after hydration. Alternatively, Next.js throws hydration errors because the server-rendered HTML assumes one theme but the client resolves to another.

**Why it happens:**
The theme preference is stored in `localStorage` (or a cookie), which is not available during SSR. The server has no way to know which theme the user prefers. The existing apps (`apps/web`, `apps/landing`) do not have a theme toggle at all — they always render in light mode. The brand app introduces this for the first time.

The `globals.css` in `@infrastructure/ui` uses `.dark` class strategy (`@custom-variant dark (&:where(.dark, .dark *));` — line 3 of `packages/infrastructure/ui/src/globals.css`). This means the `dark` class must be on an ancestor element at render time for dark utilities to apply. If the class is toggled after hydration, there will be a flash.

**How to avoid:**
Two required steps:
1. Add `suppressHydrationWarning` to the `<html>` element in `apps/brand/app/layout.tsx` — the theme toggle library will mutate the `class` attribute on `<html>` and React will otherwise warn about mismatches.
2. Use an inline script injected before React hydrates to read `localStorage` and apply the `.dark` class synchronously — this prevents the flash. Libraries like `next-themes` do this automatically if configured with `attribute="class"`.

Alternatively, skip `localStorage` entirely and implement a simple in-memory React state toggle. This avoids persistence (acceptable for a local dev tool) and eliminates the SSR/hydration problem entirely.

**Warning signs:**
- Visible color flash when loading the page in dark mode preference
- Console warning: `Warning: Prop 'className' did not match. Server: 'light' Client: 'dark'`
- Theme reverts to light after hard refresh even though user toggled dark

**Phase to address:**
Theme toggle implementation (Phase 1 or 2, whichever introduces the toggle). Must be addressed before the toggle is considered working.

---

### Pitfall 4: Token Values Displayed Show CSS Variable References, Not Resolved Colors

**What goes wrong:**
The color palette section shows the token names (e.g., `--primary`) and swatches, but the displayed HSL value reads `hsl(var(--primary))` instead of the actual resolved color `hsl(222.2 47.4% 11.2%)`. The swatches may look correct visually (CSS resolves the variable at render time), but the text display of the HSL value is wrong or empty.

**Why it happens:**
The design token system in this monorepo uses a two-layer indirection. The `@theme` block in `packages/infrastructure/ui/src/globals.css` defines `--color-primary: hsl(var(--primary))`, where `--primary` is the raw HSL channels defined in the `:root` block. If the brand app reads the token value using `getComputedStyle(document.documentElement).getPropertyValue('--color-primary')`, it gets back the string `hsl(var(--primary))` — the unexpanded reference.

The actual resolved channels live in a separate CSS variable (`--primary: 222.2 47.4% 11.2%`). To display the human-readable HSL value, the app must either:
- Read the raw channel variable (`--primary`) and format it, OR
- Use JavaScript to resolve the computed value through a hidden element

The `tokens.ts` file in `@infrastructure/ui/src/tokens.ts` exports hardcoded color values that duplicate the CSS variables — this is the correct source for static display.

**How to avoid:**
For static display of token values in the brand kit, import directly from `@infrastructure/ui`'s `tokens` export:
```typescript
import { colors } from "@infrastructure/ui";
// colors.primary === "hsl(222.2 47.4% 11.2%)"
```
This gives resolved string values without CSS variable indirection. The `colors` object already exists and has the correct light-mode values.

**Warning signs:**
- Token value labels show `hsl(var(--primary))` or similar CSS variable references as text
- Token value labels are empty strings
- Color swatches look correct but the text value annotation is wrong

**Phase to address:**
Color palette section implementation (Phase 2). Verify by rendering both the swatch (CSS-driven) and the value label (JS-driven from `tokens.ts`).

---

### Pitfall 5: `@infrastructure/ui-web` Package Not Added to `dependencies` in `package.json`

**What goes wrong:**
The import `from "@infrastructure/ui-web"` works locally (pnpm hoisting makes workspace packages available everywhere), but the app's `package.json` does not declare the dependency. This breaks Turborepo's dependency graph — it cannot determine that `apps/brand` depends on `@infrastructure/ui-web`, so the build pipeline runs in wrong order, and changes to `@infrastructure/ui-web` do not trigger rebuilds for `apps/brand` in CI.

**Why it happens:**
pnpm workspaces hoist packages, so imports resolve at runtime even without explicit declarations. The build appears to work locally. Only Turborepo's task graph (which reads `package.json` dependencies) and CI incremental builds are affected.

Verified pattern: both `apps/web/package.json` and `apps/landing/package.json` explicitly declare `"@infrastructure/ui": "workspace:*"` and `"@infrastructure/ui-web": "workspace:*"` in `dependencies`.

**How to avoid:**
Scaffold `apps/brand/package.json` with both workspace dependencies declared using `catalog:` for shared packages and `workspace:*` for infrastructure packages. Minimum required for brand app:
```json
{
  "dependencies": {
    "@infrastructure/ui": "workspace:*",
    "@infrastructure/ui-web": "workspace:*",
    "next": "catalog:",
    "react": "catalog:",
    "react-dom": "catalog:"
  }
}
```

**Warning signs:**
- `pnpm --filter brand dev` works locally but CI shows no rebuild when `@infrastructure/ui-web` changes
- `turbo build --filter=brand` completes without building `@infrastructure/ui-web` first
- Turborepo graph visualization (`turbo run build --graph`) does not show edge from `brand` to `@infrastructure/ui-web`

**Phase to address:**
App scaffolding (Phase 1). Must be correct from the start.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hardcode all token values in display components | Faster to build; no runtime resolution logic | Token values go stale when `globals.css` changes; two sources of truth | Never — use `tokens.ts` import which is already the canonical source |
| Copy component files from `@infrastructure/ui-web` into `apps/brand` | Avoids troubleshooting transpile/source issues | Brand kit diverges from real components; defeats the "living" documentation goal | Never |
| Skip the `@source` directive and manually import only needed utilities | Avoids path dependency | Breaks the moment any component uses a utility not manually imported | Never |
| Use `media` dark mode strategy instead of `class` | Simpler — no toggle JS needed | Contradicts existing `@custom-variant dark` in `@infrastructure/ui/src/globals.css`; dark classes won't fire | Never — must match existing monorepo dark variant strategy |
| Use `useState` for theme with no persistence | Zero hydration issues | User's preference resets on every refresh (acceptable for local dev tool per PROJECT.md scope) | Acceptable given PROJECT.md explicitly marks this as local-dev-only |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| `@infrastructure/ui` globals import | Importing the CSS with `@import "@infrastructure/ui/globals.css"` but the package's `exports` field only exposes TypeScript — CSS import may fail | Verify the package's `exports` in `packages/infrastructure/ui/package.json` exposes `./globals.css`; pattern is already working in `apps/web` and `apps/landing`, so copy their import exactly |
| `@infrastructure/ui-web` components with `"use client"` | All `@infrastructure/ui-web` components are marked `"use client"` (e.g., `button.tsx` line 1, `field.tsx` line 1); using them in an async Server Component without a Client Component boundary throws an error | Import into a Client Component (`"use client"`) or wrap in a client boundary; brand kit display pages can safely be Client Components |
| `@base-ui/react` peer dependency | `@infrastructure/ui-web` depends on `@base-ui/react` which is in the pnpm catalog; if `apps/brand` does not have it hoisted or declared, Base UI components error at runtime | `@base-ui/react` is already in the workspace catalog and declared in `@infrastructure/ui-web/package.json` dependencies — it will be hoisted automatically; no action needed unless isolation is required |
| Turbopack vs webpack for `transpilePackages` | GitHub issue #85316 confirms Turbopack does not honor `transpilePackages`; `next dev` with Turbopack (default in Next.js 16) may work differently than `next build` (webpack) | Test with both `pnpm --filter brand dev` and `pnpm --filter brand build` to catch discrepancies; add `--webpack` flag during diagnosis if needed |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Rendering all component variants on a single un-virtualized page | Page becomes slow to scroll and interact with as more components are added; React reconciles large component tree on every theme toggle | Group components in sections; use `<details>`/accordions for non-critical sections | Around 50+ simultaneously rendered component variants |
| Importing all of `lucide-react` for icon display in component previews | Large JS bundle; slow initial load | Import only specific icons by name (`import { ChevronRight } from "lucide-react"`) — already the monorepo convention; React Compiler tree-shakes correctly | Any time barrel imports are used with lucide-react |
| Client-side CSS variable resolution with `getComputedStyle` on every render | `getComputedStyle` forces layout reflow; if called in a render function without memoization, causes repeated reflows | Use `tokens.ts` static values for display text; only use `getComputedStyle` if dynamically reading runtime-resolved values, and memoize the result | Immediately visible if called in a tight loop |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Theme toggle that only changes the toggle button's icon but not the page theme | Developer tests in light mode, ships a non-functional dark preview; dark mode components never actually render in dark | Verify `.dark` class is applied to `<html>` or a wrapping element, not just tracked in React state; inspect DOM after toggle |
| Dark theme token display shows light-mode HSL values as the text annotation | Developer sees wrong values when inspecting dark tokens | Display both light and dark token values as static text from `globals.css` parsing, or split into two columns; the `tokens.ts` file currently only exports light values — dark values must be read from the CSS or hardcoded separately |
| Color swatches use `background-color` via Tailwind utility class that is not compiled | Swatch renders as transparent/white; developer thinks the token is broken | Use inline `style={{ backgroundColor: colors.primary }}` for swatches using imported token values rather than relying on Tailwind utilities like `bg-primary` for demonstration purposes; both approaches work, but the inline style approach is immune to `@source` mis-configuration |

---

## "Looks Done But Isn't" Checklist

- [ ] **Color palette dark mode:** Swatches look correct in light mode but dark mode swatches show light-mode values — verify `dark:` utilities apply when `.dark` class is on an ancestor, and dark token values are separately sourced
- [ ] **Theme toggle persistence:** Toggle works in the session but resets on refresh — decide intentionally (per PROJECT.md, this is a local dev tool; persistence is not required) and document the decision rather than leaving it as an accidental omission
- [ ] **All components rendered:** The brand kit shows Button and Card but not Field, FieldError, FieldLabel, FieldSet, FieldGroup, FieldLegend, Separator, Input, Label — `@infrastructure/ui-web` exports 15+ symbols; verify every exported component appears in the brand kit
- [ ] **Component variants covered:** Button has 6 variants × 8 sizes = 48 combinations; brand kit should render at minimum all 6 `variant` values with the default size — check that `buttonVariants` from `@infrastructure/ui-web` is used to enumerate variants rather than hardcoding a subset
- [ ] **Port not conflicting:** `apps/web` is on 3001, `apps/landing` on 3000; `apps/brand` must use 3002 per PROJECT.md — verify `package.json` scripts has `"dev": "next dev --port 3002"`
- [ ] **Turbo pipeline registered:** `turbo.json` does not need changes (tasks are inherited by all apps), but `apps/brand` must have a `dev` script and `build` script in its `package.json` for Turborepo to pick it up
- [ ] **TypeScript config set correctly:** `apps/brand` must have a `tsconfig.json` that extends `@infrastructure/typescript-config/nextjs.json` — same pattern as `apps/web` and `apps/landing`; missing or wrong base config causes silent type errors

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Missing `@source` directive | LOW | Add one line to `app/globals.css`; restart dev server; styles appear immediately |
| Missing `transpilePackages` | LOW | Add two entries to `next.config.ts`; restart build; resolves immediately |
| Hydration mismatch from theme toggle | MEDIUM | Add `suppressHydrationWarning` to `<html>`; if flash persists, switch to in-memory state toggle (loses persistence, acceptable per PROJECT.md scope) |
| Token values showing CSS variable references | LOW | Replace runtime `getComputedStyle` calls with `import { colors } from "@infrastructure/ui"` |
| Missing `dependencies` in `package.json` | LOW | Add `"@infrastructure/ui": "workspace:*"` and `"@infrastructure/ui-web": "workspace:*"`; run `pnpm install`; Turborepo graph corrects automatically |
| Wrong dark mode strategy (using `media` instead of `class`) | MEDIUM | Change `@custom-variant dark` to match existing monorepo pattern; update toggle logic to write `.dark` class to DOM instead of relying on system preference media query |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Missing `@source` directive | Phase 1 (app scaffold) | `pnpm --filter brand build` produces styled output; inspect compiled CSS for `bg-primary` utility |
| Missing `transpilePackages` | Phase 1 (app scaffold) | `pnpm typecheck` passes; `pnpm --filter brand build` completes without module resolution errors |
| Theme toggle FOUC / hydration mismatch | Phase 1 or 2 (theme toggle) | Hard-refresh in dark preference; no visible flash; no console hydration warnings |
| Token display shows CSS variable references | Phase 2 (color palette section) | Text annotation next to color swatch shows `hsl(222.2 47.4% 11.2%)` not `hsl(var(--primary))` |
| Missing `dependencies` in `package.json` | Phase 1 (app scaffold) | `turbo run build --filter=brand --graph` shows edges to `@infrastructure/ui-web`; CI rebuild triggers on `@infrastructure/ui-web` changes |
| Wrong dark mode variant strategy | Phase 1 or 2 (theme toggle) | Dark utilities (`dark:text-foreground` etc.) apply when `.dark` class is on ancestor; matches behavior in `apps/web` |
| Missing components in brand kit | Phase 2 (component section) | Cross-reference against `@infrastructure/ui-web/src/index.ts` exports; every named export has a rendered example |

---

## Sources

- Codebase verified: `apps/web/app/globals.css`, `apps/landing/app/globals.css` — `@source` directive pattern
- Codebase verified: `apps/web/next.config.ts`, `apps/landing/next.config.ts` — `transpilePackages` pattern
- Codebase verified: `packages/infrastructure/ui/src/globals.css` — `@custom-variant dark` class strategy
- Codebase verified: `packages/infrastructure/ui/src/tokens.ts` — static color token export for display
- Codebase verified: `packages/infrastructure/ui-web/src/index.ts` — full component export list
- Codebase verified: `.planning/codebase/CONCERNS.md` — "Tailwind v4 Scanning Requires Explicit @source" section
- Tailwind v4 monorepo scanning: [tailwindlabs/tailwindcss issue #13136](https://github.com/tailwindlabs/tailwindcss/issues/13136) — "Automatic content detection in monorepos only finds direct package" (MEDIUM confidence)
- Next.js `transpilePackages` with Turbopack: [vercel/next.js issue #85316](https://github.com/vercel/next.js/issues/85316) — Turbopack does not honor `transpilePackages` (MEDIUM confidence)
- Tailwind v4 dark mode class strategy: [Things About Web Development](https://www.thingsaboutweb.dev/en/posts/dark-mode-with-tailwind-v4-nextjs) — `@custom-variant` must match what toggle library writes to DOM (MEDIUM confidence)
- next-themes `suppressHydrationWarning`: [pacocoursey/next-themes README](https://github.com/pacocoursey/next-themes) — required on `<html>` element (MEDIUM confidence, widely documented)
- Design token resolution pitfall: [penpot.app developer guide](https://penpot.app/blog/the-developers-guide-to-design-tokens-and-css-variables/) — `var()` chains vs resolved values for display (MEDIUM confidence)

---

*Pitfalls research for: design system brand kit documentation app (apps/brand), Next.js + Tailwind v4 monorepo*
*Researched: 2026-03-02*
