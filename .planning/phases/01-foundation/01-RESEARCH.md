# Phase 1: Foundation - Research

**Researched:** 2026-03-02
**Domain:** Next.js app scaffolding in a pnpm monorepo + next-themes for flash-free theme toggling
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

| Decision | Source | Detail |
|----------|--------|--------|
| Structural reference | PROJECT.md | Use `apps/landing` as template — leanest Next.js app, no auth/API/navigation |
| Only new dependency | Research | `next-themes@0.4.6` — add to pnpm workspace catalog |
| Theme strategy | Research | `attribute="class"` on `ThemeProvider`, matches existing `@custom-variant dark` in `@infrastructure/ui/globals.css` |
| Hydration safety | Research | `suppressHydrationWarning` on `<html>` element required |
| Port | PROJECT.md | 3002 (next available after landing:3000, web:3001) |
| Architecture | PROJECT.md | Single-page app, no routing |

### Claude's Discretion

- **Theme toggle placement:** Top-right of page in a simple header bar. Phase 4 nav can merge with or replace this.
- **Shell page structure:** Minimal page with heading + theme toggle. No empty section containers — Phase 2/3 will add sections as they're built.
- **Default theme:** Follow OS system preference via `next-themes` `defaultTheme="system"` with `enableSystem`.

### Deferred Ideas (OUT OF SCOPE)

(None documented in CONTEXT.md — all deferred items belong to later phases.)
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| FOUN-01 | Standalone Next.js app at `apps/brand` with dev server on port 3002 | Copy `apps/landing` structure; change name, port; add to workspace |
| FOUN-02 | Light/dark theme toggle that switches the entire page via `.dark` class on `<html>` | `next-themes@0.4.6` with `attribute="class"`, `suppressHydrationWarning`, `ThemeToggle` client component |
</phase_requirements>

---

## Summary

This phase creates `apps/brand` — a minimal Next.js app at port 3002 that proves the scaffolding is correct before design system content is added. The `apps/landing` app is the confirmed structural template: it has the exact right configuration (`transpilePackages`, `reactCompiler`, Tailwind v4 via `@tailwindcss/postcss`, `@infrastructure/ui-web` dependency) and is free of auth, navigation, and API concerns that `apps/web` carries.

The only new dependency is `next-themes@0.4.6`, which must be added to the pnpm workspace catalog before it can be used. The existing CSS infrastructure in `@infrastructure/ui/globals.css` already defines `@custom-variant dark (&:where(.dark, .dark *))`, so `ThemeProvider` with `attribute="class"` will integrate without any CSS changes.

Turbopack (the default dev server since Next.js 16) is compatible with `transpilePackages` for properly-named monorepo packages. The concern raised in STATE.md ("Turbopack doesn't honor `transpilePackages`") was rooted in a resolved GitHub issue where an invalid package name (`@/utils`) caused problems — not a general Turbopack limitation. Since `@infrastructure/ui` and `@infrastructure/ui-web` use valid scoped npm names, this is a non-issue.

**Primary recommendation:** Clone `apps/landing` as the template, add `next-themes@0.4.6` to the pnpm catalog, and create three new files (`layout.tsx` with `ThemeProvider`, `page.tsx` shell, `components/theme-toggle.tsx`). All five documented pitfalls from CONTEXT.md must be addressed during scaffolding, not as afterthoughts.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| next | 16.1.6 (catalog) | Next.js App Router framework | Already in workspace catalog; all web apps use it |
| react | 19.1.0 (catalog) | React runtime | Pinned exact; RN compatibility constraint |
| react-dom | 19.1.0 (catalog) | React DOM renderer | Paired with react |
| next-themes | 0.4.6 (NEW catalog entry) | Flash-free theme toggling via `.dark` class | Industry standard for Next.js; injects blocking script before hydration |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| @infrastructure/ui | workspace:* | Design tokens, `cn()`, `globals.css` | All web apps — provides the `.dark` CSS variables |
| @infrastructure/ui-web | workspace:* | shadcn/ui components | All web apps — Phase 2+ will use Button, Card, etc. |
| @infrastructure/typescript-config | workspace:* | Shared TS config | All packages |
| @tailwindcss/postcss | catalog | Tailwind v4 PostCSS plugin | Required for Tailwind v4 CSS processing |
| lucide-react | catalog (0.564.0) | Sun/Moon icons for theme toggle | Already in catalog; used by ui-web |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| next-themes | Manual cookie/localStorage + inline script | Requires hand-rolling flash prevention; next-themes is battle-tested |
| next-themes | CSS media query only (no JS toggle) | Can't support user-controlled toggle; doesn't satisfy FOUN-02 |

**Installation (pnpm catalog pattern):**
```bash
# Step 1: Add to pnpm-workspace.yaml catalog section:
# next-themes: "0.4.6"

# Step 2: Add to apps/brand/package.json dependencies:
# "next-themes": "catalog:"

# Step 3: Run from repo root:
pnpm install
```

---

## Architecture Patterns

### Recommended Project Structure

```
apps/brand/
├── app/
│   ├── globals.css          # @import "@infrastructure/ui/globals.css" + @source directive
│   ├── layout.tsx           # ThemeProvider wrapper + suppressHydrationWarning
│   └── page.tsx             # Minimal shell: heading + ThemeToggle
├── components/
│   └── theme-toggle.tsx     # "use client" — useTheme() + Sun/Moon icon button
├── components.json          # shadcn config (copy from landing, update aliases)
├── next.config.ts           # transpilePackages + reactCompiler
├── package.json             # name: "brand", port: 3002, next-themes dep
├── postcss.config.mjs       # @tailwindcss/postcss
├── tsconfig.json            # extends @infrastructure/typescript-config/nextjs
└── vitest.config.ts         # jsdom, passWithNoTests: true (copy from landing)
```

### Pattern 1: ThemeProvider in App Router layout.tsx

**What:** `ThemeProvider` from `next-themes` wraps the entire app inside `<body>`. The `<html>` element gets `suppressHydrationWarning` because next-themes modifies it after hydration (adding the `class="dark"` or `class="light"` attribute).

**When to use:** Any Next.js App Router app that needs system-aware, flash-free theme toggling.

**Example:**
```typescript
// Source: https://github.com/pacocoursey/next-themes/blob/main/next-themes/README.md
import { ThemeProvider } from "next-themes";
import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";

const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: "Brand Kit",
  description: "Design system reference for the monorepo template",
};

/** Root layout for the brand app. Provides theme toggle support and global styles. */
export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className={inter.className}>
        <ThemeProvider attribute="class" defaultTheme="system" enableSystem>
          {children}
        </ThemeProvider>
      </body>
    </html>
  );
}
```

**Why `attribute="class"`:** The existing `@infrastructure/ui/globals.css` uses `@custom-variant dark (&:where(.dark, .dark *))` — a Tailwind v4 directive that activates dark tokens when the `dark` class is present on any ancestor. `next-themes` with `attribute="class"` adds/removes `class="dark"` on the `<html>` element, which makes this variant fire correctly.

### Pattern 2: ThemeToggle client component

**What:** A `"use client"` component that uses `useTheme()` to read current theme and call `setTheme()`. Must use the `mounted` guard to avoid hydration mismatch.

**When to use:** Any UI element that reads or sets the current theme.

**Example:**
```typescript
// Source: https://github.com/pacocoursey/next-themes/blob/main/next-themes/README.md
"use client";

import { useTheme } from "next-themes";
import { Sun, Moon } from "lucide-react";
import { useEffect, useState } from "react";

/** Theme toggle button — switches between light and dark mode. */
export function ThemeToggle() {
  const { theme, setTheme } = useTheme();
  const [mounted, setMounted] = useState(false);

  useEffect(() => setMounted(true), []);

  // Avoid hydration mismatch: don't render theme-aware icons until mounted
  if (!mounted) return <div className="size-9" />;

  return (
    <button
      type="button"
      onClick={() => setTheme(theme === "dark" ? "light" : "dark")}
      className="flex size-9 items-center justify-center rounded-md border border-border bg-background text-foreground hover:bg-accent"
      aria-label="Toggle theme"
    >
      {theme === "dark" ? <Sun className="size-4" /> : <Moon className="size-4" />}
    </button>
  );
}
```

**The `mounted` guard:** Without it, the server renders one icon (based on `defaultTheme`) and the client renders another after hydration — causing a React hydration warning. Using `resolvedTheme` instead of `theme` also works but still requires the `mounted` guard.

### Pattern 3: globals.css for a new web app

**What:** The CSS file must import the shared design tokens and tell Tailwind where to find component classes.

**Example:**
```css
/* Source: Confirmed from apps/landing/app/globals.css */
@import "@infrastructure/ui/globals.css";

@source "../node_modules/@infrastructure/ui-web/src";
```

The `@source` directive is the Tailwind v4 way to tell the compiler to scan `@infrastructure/ui-web` for class names. Without it, component styles won't be compiled. The path is relative to the CSS file itself, so from `app/globals.css`, it resolves to `apps/brand/node_modules/@infrastructure/ui-web/src`.

### Anti-Patterns to Avoid

- **Wrapping `ThemeProvider` outside `<body>`:** next-themes must be inside `<body>`, not wrapping `<html>`. The `suppressHydrationWarning` goes on `<html>`, not `<body>`.
- **Missing `mounted` guard in ThemeToggle:** Renders mismatched icon server-side vs client-side, causing hydration warnings.
- **Adding `@source` directive after Tailwind picks it up:** Must be in `globals.css` before `pnpm build`. The dev server (Turbopack) scans dynamically; production build requires it.
- **Using `@radix-ui` or other complex shadcn components in Phase 1:** Phase 1 is foundation only — `lucide-react` icons and a bare `<button>` are sufficient for the toggle.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Flash-free theme toggle | Inline `<script>` reading `localStorage` | `next-themes@0.4.6` | next-themes injects its own blocking script correctly; ordering/CSP/SSR edge cases are handled |
| System preference detection | `window.matchMedia('prefers-color-scheme')` in `useEffect` | `next-themes` `enableSystem` prop | Race conditions, SSR mismatch, and cookie sync are all handled by the library |
| Theme persistence | `localStorage` read/write manually | `next-themes` (`storageKey` defaults to `'theme'`) | next-themes reads from `localStorage` before paint via its inline script |

**Key insight:** Theme toggling without FOUC looks simple but requires a blocking inline script that runs before React hydration. next-themes handles script injection correctly across SSR, SSG, and streaming; hand-rolled solutions consistently get edge cases wrong (especially with Next.js App Router streaming).

---

## Common Pitfalls

### Pitfall 1: Missing `@source` directive in globals.css

**What goes wrong:** `@infrastructure/ui-web` component classes (used in future phases) compile to nothing. The app may look fine with inline styles but break when consuming shadcn components.

**Why it happens:** Tailwind v4 does not auto-scan `node_modules`. Each consuming app must explicitly declare which packages to scan.

**How to avoid:** Add `@source "../node_modules/@infrastructure/ui-web/src";` to `app/globals.css`. Path is relative to the CSS file.

**Warning signs:** Component renders with correct structure but wrong colors/spacing in production build (Turbopack dev mode may dynamically resolve; webpack/production build won't).

### Pitfall 2: Missing `transpilePackages` in next.config.ts

**What goes wrong:** Build error like `SyntaxError: Cannot use import statement in a module` when importing from `@infrastructure/ui` or `@infrastructure/ui-web`.

**Why it happens:** These workspace packages ship TypeScript/ESM source that Next.js cannot use without transpilation.

**How to avoid:** Copy `next.config.ts` from `apps/landing` — it already has `transpilePackages: ["@infrastructure/ui", "@infrastructure/ui-web"]`.

**Warning signs:** `pnpm --filter brand build` fails with import errors referencing workspace packages.

### Pitfall 3: Theme FOUC (Flash of Unstyled/Incorrectly-themed Content)

**What goes wrong:** Page briefly renders in light mode even when the user prefers dark, then flashes to dark after hydration.

**Why it happens:** Without a blocking script, the theme class is applied only after React hydrates — too late to prevent a paint.

**How to avoid:** Use `next-themes` (handles script injection) with `suppressHydrationWarning` on `<html>`. Do not add `"use client"` to `layout.tsx` — it must remain a Server Component for the blocking script to be injected server-side.

**Warning signs:** Visible white flash on page load when OS is in dark mode.

### Pitfall 4: Missing `@infrastructure/ui` and `@infrastructure/ui-web` in `package.json` dependencies

**What goes wrong:** pnpm does not install the workspace packages into `apps/brand/node_modules`, so `@source` path cannot resolve and `transpilePackages` cannot find them.

**Why it happens:** pnpm strict workspace linking — packages must be explicitly declared in `dependencies`.

**How to avoid:** Include both `"@infrastructure/ui": "workspace:*"` and `"@infrastructure/ui-web": "workspace:*"` in `package.json` `dependencies`.

**Warning signs:** `Module not found: Can't resolve '@infrastructure/ui'` during build.

### Pitfall 5: `next-themes` not in pnpm workspace catalog

**What goes wrong:** Using `"next-themes": "0.4.6"` directly (without `catalog:`) in `package.json` works but bypasses the catalog, making version management inconsistent.

**What to do instead:** Add `next-themes: "0.4.6"` to the `catalog:` section in `pnpm-workspace.yaml` first, then reference it as `"next-themes": "catalog:"` in `package.json`. This follows the established monorepo convention: all shared dependencies use `catalog:`.

**Warning signs:** Biome/linting does not flag this, but it violates the project convention established in `CLAUDE.md`.

### Pitfall 6: Turbopack dev vs. webpack production build differences

**What goes wrong:** `pnpm --filter brand dev` works but `pnpm --filter brand build` fails (or vice versa).

**Why it happens:** Turbopack (dev, Next.js 16 default) and webpack (production build) have slightly different resolution behaviors. Turbopack dynamically discovers source files; webpack relies on explicit `@source` and `transpilePackages`.

**How to avoid:** Test **both** `pnpm --filter brand dev` AND `pnpm --filter brand build` during Phase 1. Don't declare victory until both pass.

**Warning signs:** Dev server works but CI fails on build step.

---

## Code Examples

Verified patterns from official sources and existing codebase:

### Complete next.config.ts (copy from landing, no changes needed)
```typescript
// Source: apps/landing/next.config.ts (confirmed in codebase)
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  reactCompiler: true,
  transpilePackages: ["@infrastructure/ui", "@infrastructure/ui-web"],
};

export default nextConfig;
```

### Complete package.json for apps/brand
```json
{
  "name": "brand",
  "version": "0.0.0",
  "private": true,
  "license": "MIT",
  "type": "module",
  "scripts": {
    "dev": "next dev --port 3002",
    "build": "next build",
    "start": "next start",
    "typecheck": "tsc --noEmit",
    "test": "vitest run"
  },
  "dependencies": {
    "@infrastructure/ui": "workspace:*",
    "@infrastructure/ui-web": "workspace:*",
    "next": "catalog:",
    "next-themes": "catalog:",
    "react": "catalog:",
    "react-dom": "catalog:"
  },
  "devDependencies": {
    "@infrastructure/typescript-config": "workspace:*",
    "@tailwindcss/postcss": "catalog:",
    "@testing-library/react": "catalog:",
    "@types/node": "catalog:",
    "@types/react": "catalog:",
    "@types/react-dom": "catalog:",
    "@vitejs/plugin-react": "catalog:",
    "babel-plugin-react-compiler": "catalog:",
    "jsdom": "catalog:",
    "postcss": "catalog:",
    "tailwindcss": "catalog:",
    "typescript": "catalog:",
    "vitest": "catalog:"
  }
}
```

### pnpm-workspace.yaml catalog addition
```yaml
# Add to the catalog: section, grouped with UI Components:
next-themes: "0.4.6"
```

### globals.css (identical to landing)
```css
/* Source: apps/landing/app/globals.css (confirmed in codebase) */
@import "@infrastructure/ui/globals.css";

@source "../node_modules/@infrastructure/ui-web/src";
```

### tsconfig.json (identical to landing)
```json
{
  "extends": "@infrastructure/typescript-config/nextjs.json",
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["./*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
```

### Minimal page.tsx (Phase 1 shell only)
```typescript
// No "use client" — Server Component
import { ThemeToggle } from "@/components/theme-toggle";

/** Brand kit home page — minimal shell for Phase 1. Content added in later phases. */
export default function BrandPage() {
  return (
    <div className="min-h-screen bg-background text-foreground">
      <header className="flex items-center justify-between border-b border-border px-6 py-4">
        <h1 className="text-lg font-semibold">Brand Kit</h1>
        <ThemeToggle />
      </header>
      <main className="mx-auto max-w-6xl px-6 py-12">
        <p className="text-muted-foreground">Design system content coming in Phase 2.</p>
      </main>
    </div>
  );
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `next-transpile-modules` npm package | Built-in `transpilePackages` in next.config | Next.js 13 | No separate package needed |
| `tailwind.config.ts` | CSS-first config (`@import "tailwindcss"` in CSS) | Tailwind v4 | No `tailwind.config.ts` file in this project |
| `data-theme` attribute for theming | `class` attribute (`attribute="class"`) | n/a | Required to match `@custom-variant dark` in ui/globals.css |
| `experimental.turbo` config | Top-level Turbopack config | Next.js 16 | `experimental.turbo` is gone; no turbopack config needed for standard use |

**Deprecated/outdated:**
- `@tanstack/zod-form-adapter`: v0 concept, do not use (Zod works natively with TanStack Form v1)
- `next-transpile-modules`: Replaced by `transpilePackages` built into Next.js
- `tailwind.config.ts`: Not used in this project — Tailwind v4 CSS-first config

---

## Open Questions

1. **Turbopack + transpilePackages in production build**
   - What we know: Works in `apps/landing` and `apps/web` (both use same config). The GitHub issue 85316 was a naming-convention problem, not a real limitation.
   - What's unclear: Whether any edge case in `apps/brand` specifically would surface a new issue.
   - Recommendation: Test `pnpm --filter brand build` as a Phase 1 success criterion (already in CONTEXT.md) — if it fails, the fix will be evident from the error.

2. **`lucide-react` availability without separate install**
   - What we know: `lucide-react` is in the pnpm workspace catalog at `0.564.0`. It is a dependency of `@infrastructure/ui-web`. However, `apps/brand` may not have it in its own `node_modules` unless explicitly declared.
   - What's unclear: Whether pnpm's workspace hoisting makes `lucide-react` available to `apps/brand` without listing it in `package.json`.
   - Recommendation: Add `"lucide-react": "catalog:"` to `apps/brand/package.json` `dependencies` to be explicit. This is safe and eliminates the ambiguity.

---

## Sources

### Primary (HIGH confidence)
- `apps/landing/` — Direct codebase inspection of template app structure, package.json, next.config.ts, globals.css, layout.tsx, tsconfig.json, vitest.config.ts
- `packages/infrastructure/ui/src/globals.css` — Confirmed `@custom-variant dark` uses `.dark` class selector
- `pnpm-workspace.yaml` — Confirmed catalog contents and absence of `next-themes`
- https://github.com/pacocoursey/next-themes/blob/main/next-themes/README.md — ThemeProvider props, useTheme API, App Router setup, mounted guard pattern
- https://nextjs.org/docs/app/api-reference/config/next-config-js/transpilePackages — Confirmed `transpilePackages` is stable in Next.js 16.1.6

### Secondary (MEDIUM confidence)
- https://github.com/vercel/next.js/issues/85316 — Turbopack transpilePackages issue: confirmed resolved (was a naming problem, not a Turbopack limitation). Issue closed Oct 2025.
- Next.js 16.1 blog — Turbopack stable as default dev server; no special config needed for standard monorepo use

### Tertiary (LOW confidence)
- (None — all findings verified against primary or secondary sources)

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — directly read from existing codebase catalog and working apps
- Architecture: HIGH — cloning verified working patterns from `apps/landing`
- Pitfalls: HIGH — five of six pitfalls are documented in CONTEXT.md from prior research; Turbopack pitfall verified against the GitHub issue

**Research date:** 2026-03-02
**Valid until:** 2026-04-02 (stable libraries; next-themes, Next.js 16, and Tailwind v4 are all mature)
