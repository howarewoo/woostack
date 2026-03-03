# Stack Research

**Domain:** Design system brand kit / style guide app (Next.js monorepo addition)
**Researched:** 2026-03-02
**Confidence:** HIGH

## Context

This is a **subsequent-milestone** research. The core stack (Next.js 16.1.6, Tailwind v4, shadcn/ui `base-vega`, pnpm) is already established in the monorepo. This research focuses exclusively on what _additional_ tooling is needed for a brand kit app that renders live components and displays design tokens.

**Do not re-decide:** Next.js, Tailwind v4, TypeScript, Biome, Vitest, pnpm catalog.

The existing `@infrastructure/ui/src/globals.css` uses:
- HSL CSS custom properties (`--background`, `--foreground`, `--primary`, etc.) on `:root` and `.dark`
- Tailwind v4 `@custom-variant dark (&:where(.dark, .dark *))` — dark mode via `.dark` class on `<html>`
- `@theme` block mapping `--color-*` tokens to Tailwind utilities

This means the theme toggle approach **must** add/remove the `.dark` class (not `data-theme`).

---

## Recommended Stack

### Core Technologies (Already Locked)

| Technology | Version (catalog) | Purpose | Why |
|------------|-------------------|---------|-----|
| Next.js | `16.1.6` | App framework | Monorepo standard; matches `apps/web` and `apps/landing` |
| React | `19.1.0` | UI runtime | Exact version pinned for RN renderer compat — do not bump |
| Tailwind v4 | `4.1.18` | Styling | Monorepo standard; CSS-first config |
| TypeScript | `5.9.3` | Types | Monorepo standard |

These come from `pnpm-workspace.yaml` catalog entries. Use `catalog:` in `apps/brand/package.json` — never hardcode versions.

### New Dependency: Theme Toggle

| Library | Version | Purpose | Why Recommended |
|---------|---------|---------|-----------------|
| `next-themes` | `0.4.6` | Light/dark theme toggle | De-facto standard for Next.js dark mode. Adds/removes `.dark` class on `<html>` — directly compatible with the existing `@custom-variant dark (&:where(.dark, .dark *))` in `@infrastructure/ui/globals.css`. Zero-config with `attribute="class"`. Eliminates FOUC without hacks. React 19 compatible. |

**Confidence:** HIGH — verified against shadcn/ui official docs, multiple 2025 sources confirm Tailwind v4 + next-themes + `.dark` class works without changes to the CSS custom variant. The existing monorepo CSS variant already targets `.dark` class, so `next-themes` with `attribute="class"` is a drop-in.

**No new catalog entry needed beyond `next-themes`.** Add it to the catalog as `next-themes: "0.4.6"`.

### Token Display Strategy: No New Library

The design token display (color swatches with HSL values, radius values, spacing) does **not** require a library. The correct approach is a client component that reads computed CSS custom properties at runtime:

```typescript
// Inside a client component (after mount):
const value = getComputedStyle(document.documentElement)
  .getPropertyValue("--background")
  .trim(); // e.g., "0 0% 100%"
```

This reads the _resolved_ value for the active theme (light or dark), so the token display stays accurate across theme switches. No token extraction library is needed — the 14 color tokens plus radius are already defined in `@infrastructure/ui/src/globals.css` and can be enumerated statically.

**Confidence:** HIGH — MDN getComputedStyle is the standard browser API for reading CSS custom properties. Verified pattern from official MDN docs and multiple authoritative sources.

### No Documentation Framework Needed

The brand kit explicitly excludes: code snippets, copy-paste examples, MDX content, search, versioning. Fumadocs, Nextra, and Storybook are all overkill.

This is a simple Next.js App Router app with static pages organized into sections. Use plain React Server Components with a client component island for the theme toggle and token display.

**Confidence:** HIGH — PROJECT.md explicitly states "Out of Scope: Component playground / prop editing — just render the components, not Storybook" and "Code snippets or copy-paste examples — this is visual reference, not docs."

---

## Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `@infrastructure/ui` | `workspace:*` | Globals CSS (tokens) | Always — source of truth for all design tokens |
| `@infrastructure/ui-web` | `workspace:*` | Live component rendering | Always — render actual Button, Card, Input, etc. |
| `lucide-react` | `catalog:` (currently `0.564.0`) | Sun/Moon icons for theme toggle | Already in catalog; use for theme toggle button icon |

All other supporting libraries (clsx, tailwind-merge, class-variance-authority) come transitively from `@infrastructure/ui-web` and do not need direct declaration.

---

## Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| `@tailwindcss/postcss` | Tailwind v4 PostCSS plugin | Required devDep; matches `apps/web` and `apps/landing` pattern |
| `postcss` | PostCSS runner | Required devDep |
| `babel-plugin-react-compiler` | React Compiler (auto-memoization) | Enable `reactCompiler: true` in `next.config.ts` to match `apps/web` |
| `vitest` | Unit testing | Required even for minimal test coverage |
| `@vitejs/plugin-react` | Vitest React support | Required devDep for testing |

---

## Installation

```bash
# Add to pnpm-workspace.yaml catalog:
#   next-themes: "0.4.6"

# From apps/brand/ — all versions from catalog
pnpm add next-themes@catalog:
pnpm add @infrastructure/ui@workspace:*
pnpm add @infrastructure/ui-web@workspace:*

# Dev dependencies (all from catalog)
pnpm add -D next@catalog: react@catalog: react-dom@catalog:
pnpm add -D tailwindcss@catalog: @tailwindcss/postcss@catalog: postcss@catalog:
pnpm add -D typescript@catalog: @types/node@catalog: @types/react@catalog: @types/react-dom@catalog:
pnpm add -D babel-plugin-react-compiler@catalog:
pnpm add -D vitest@catalog: @vitejs/plugin-react@catalog: jsdom@catalog: @testing-library/react@catalog:
pnpm add -D @infrastructure/typescript-config@workspace:*
```

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| `next-themes` | Manual class toggle via `useState` + `useEffect` | Never for this project — next-themes handles SSR/FOUC, system preference, and localStorage persistence with zero boilerplate |
| `next-themes` | CSS-only `prefers-color-scheme` media query | Only if you never need a user-controlled toggle (this project requires a toggle) |
| Runtime `getComputedStyle` token reading | `style-dictionary` token extraction pipeline | Only if tokens are managed in JSON/YAML outside CSS and need multi-platform output; overkill here — the tokens live in CSS already |
| Plain Next.js App Router pages | Fumadocs / Nextra | Only if you need MDX content, full-text search, versioning, or auto-generated API docs — none of which are in scope |
| Plain Next.js App Router pages | Storybook | Only if you need isolated component sandboxing, addon ecosystem, or CSF stories for testing — explicitly out of scope |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Storybook | Massive bundle overhead, requires CSF story format, adds `.storybook/` config complexity. PROJECT.md explicitly calls it out of scope. | Plain Next.js pages rendering real components |
| Fumadocs / Nextra | MDX-centric doc frameworks; bring routing, search, and content infrastructure this app doesn't need. | Plain Next.js App Router pages |
| `@tanstack/react-query` | No async data fetching in a static brand kit app. | None needed |
| `data-theme` attribute approach | The existing `@infrastructure/ui/globals.css` uses `.dark` class via `@custom-variant dark (&:where(.dark, .dark *))`. Using `attribute="data-theme"` with next-themes would require rewriting the shared CSS — breaking all other web apps. | `attribute="class"` with `next-themes` |
| Installing `next-themes` into `@infrastructure/ui-web` | The theme toggle is app-level concern, not a shared component concern. | Install in `apps/brand` only |
| `@tailwindcss/typography` | Not needed for a component display app with no prose content. | None |
| New shadcn/ui components beyond what exists | The brand kit renders existing components, not new ones. Adding shadcn components to `apps/brand/components/ui/` without moving them to `@infrastructure/ui-web` would create drift. | Only use `@infrastructure/ui-web` exports |

---

## Stack Patterns for This App

**Theme toggle setup:**
```typescript
// apps/brand/app/layout.tsx
import { ThemeProvider } from "next-themes";

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body>
        <ThemeProvider attribute="class" defaultTheme="system" enableSystem disableTransitionOnChange>
          {children}
        </ThemeProvider>
      </body>
    </html>
  );
}
```

- `attribute="class"` — matches `@custom-variant dark (&:where(.dark, .dark *))` in globals.css
- `suppressHydrationWarning` on `<html>` — prevents hydration mismatch (next-themes modifies this element)
- No `storageKey` override needed — defaults to `"theme"` which is fine for a dev-only tool

**Token display component pattern (client component):**
```typescript
// Runs after mount (useEffect) to read resolved CSS values
const value = getComputedStyle(document.documentElement)
  .getPropertyValue("--primary")
  .trim(); // "222.2 47.4% 11.2%" (light) or "210 40% 98%" (dark)
```

**CSS globals setup:**
```css
/* apps/brand/app/globals.css */
@import "@infrastructure/ui/globals.css";
@source "../node_modules/@infrastructure/ui-web/src";
```

This is identical to `apps/web/app/globals.css` and is required per CLAUDE.md Tailwind v4 gotcha.

**next.config.ts:**
```typescript
const nextConfig: NextConfig = {
  reactCompiler: true,
  transpilePackages: [
    "@infrastructure/ui",
    "@infrastructure/ui-web",
  ],
};
```

Only `@infrastructure/ui` and `@infrastructure/ui-web` need transpilation. No navigation or API client needed for a purely visual app.

---

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| `next-themes@0.4.6` | `react@19.1.0`, `next@16.1.6` | Verified: React 19 peer dep satisfied. Works with App Router via client ThemeProvider wrapper. |
| `next-themes@0.4.6` | Tailwind v4 + `.dark` class | `attribute="class"` adds `.dark` to `<html>`; existing `@custom-variant dark (&:where(.dark, .dark *))` picks it up automatically |
| `@infrastructure/ui-web` | `next@16.1.6` | Must be in `transpilePackages` per CLAUDE.md checklist |
| Tailwind v4 `@source` directive | `@infrastructure/ui-web` | Required: `@source "../node_modules/@infrastructure/ui-web/src"` in globals.css |

---

## Sources

- `/Users/adamwoo/Documents/GitHub/monorepo-template/pnpm-workspace.yaml` — catalog versions (HIGH confidence, source of truth)
- `/Users/adamwoo/Documents/GitHub/monorepo-template/packages/infrastructure/ui/src/globals.css` — existing token definitions and dark variant (HIGH confidence)
- `/Users/adamwoo/Documents/GitHub/monorepo-template/.planning/PROJECT.md` — scope constraints, out-of-scope items (HIGH confidence)
- [next-themes GitHub](https://github.com/pacocoursey/next-themes) — App Router setup, `suppressHydrationWarning` requirement, `attribute="class"` config (MEDIUM confidence — docs reviewed via WebFetch)
- [shadcn/ui dark mode docs](https://ui.shadcn.com/docs/dark-mode/next) — ThemeProvider configuration for Next.js App Router (MEDIUM confidence — reviewed via WebFetch)
- [shadcn/ui Tailwind v4 docs](https://ui.shadcn.com/docs/tailwind-v4) — `@theme inline` and CSS variable structure for v4 (MEDIUM confidence — reviewed via WebFetch)
- [Next.js 16 release blog](https://nextjs.org/blog/next-16) — version requirements (Node 20.9+, React 19.2), breaking changes (HIGH confidence — official Vercel blog)
- [MDN getComputedStyle](https://developer.mozilla.org/en-US/docs/Web/API/Window/getComputedStyle) — runtime CSS custom property access pattern (HIGH confidence — W3C standard API)
- WebSearch: "next-themes npm package current version 2025" → version 0.4.6 confirmed (MEDIUM confidence — npm page reference)
- WebSearch: "lucide-react version current 2025 npm" → 0.576.0 latest, catalog pins 0.564.0 (MEDIUM confidence)

---
*Stack research for: Design system brand kit app (apps/brand)*
*Researched: 2026-03-02*
