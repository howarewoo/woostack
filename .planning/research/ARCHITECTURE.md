# Architecture Research

**Domain:** Design system brand kit / living style guide app
**Researched:** 2026-03-02
**Confidence:** HIGH (derived from direct codebase inspection + verified patterns)

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         apps/brand (Next.js 16)                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐               │
│  │  Color Token │  │  Typography  │  │  Components  │               │
│  │    Section   │  │    Section   │  │    Section   │               │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘               │
│         │                 │                 │                        │
│  ┌──────┴─────────────────┴─────────────────┴───────┐               │
│  │             ThemeProvider (next-themes)           │               │
│  │             Theme toggle button                   │               │
│  └──────────────────────────────────────────────────┘               │
│  app/page.tsx — single-page catalog                                  │
│  app/layout.tsx — html+body, ThemeProvider, globals.css              │
└─────────────────────────────────────────────────────────────────────┘
                              │ imports
           ┌──────────────────┴──────────────────┐
           │                                     │
┌──────────▼──────────┐              ┌───────────▼──────────┐
│  @infrastructure/ui │              │ @infrastructure/ui-web│
│  globals.css        │              │ Button, Card, Input   │
│  tokens.ts          │              │ Label, Separator      │
│  utils.ts (cn())    │              │ Field (+ sub-exports) │
└─────────────────────┘              └──────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| `app/layout.tsx` | Root shell: html, body, ThemeProvider, font loading, globals.css import | Next.js App Router layout |
| `app/page.tsx` | Single-page catalog — renders all sections in order | Next.js Server Component (no auth, no API) |
| `ThemeProvider` | Manages dark/light class on `<html>`, persists to localStorage, no flash | `next-themes` ThemeProvider with `attribute="class"` |
| `ThemeToggle` | Button that calls `setTheme()` from `useTheme()` | Client Component; uses sun/moon icon from lucide-react |
| Color Token Section | Renders a swatch grid for every CSS custom property from `globals.css` | Static data array matching `@infrastructure/ui` tokens |
| Typography Section | Shows typeface, scale steps, and weights | Renders text at each Tailwind text-* size |
| Components Section | Renders every exported component from `@infrastructure/ui-web` in all variants | Import and render; no prop editors |
| Spacing Section | Shows spacing scale and border radius values from `tokens.ts` | Rendered boxes using inline styles or Tailwind scale classes |

## Recommended Project Structure

```
apps/brand/
├── app/
│   ├── globals.css            # @import @infrastructure/ui/globals.css + @source directive
│   ├── layout.tsx             # ThemeProvider wraps html, suppressHydrationWarning on <html>
│   └── page.tsx               # Single-page catalog; imports all sections
├── components/
│   ├── theme-toggle.tsx       # "use client" — useTheme() + lucide sun/moon button
│   └── sections/
│       ├── color-section.tsx  # Token swatches grid
│       ├── typography-section.tsx
│       ├── component-section.tsx
│       └── spacing-section.tsx
├── lib/
│   └── tokens.ts              # Re-exports or statically mirrors token arrays from @infrastructure/ui
├── next.config.ts             # transpilePackages, reactCompiler: true
├── package.json               # name: "brand", port 3002
├── postcss.config.mjs
└── tsconfig.json
```

### Structure Rationale

- **`app/page.tsx` as single page:** The catalog is a developer tool, not a multi-route app. All sections on one scrollable page reduces complexity and matches how real living style guides (Storybook's single-page mode, Pajamas, etc.) operate at this scale.
- **`components/sections/`:** Each section is its own component for code organization, but they are statically imported — no dynamic routing, no lazy loading needed.
- **`lib/tokens.ts`:** The color swatches need a data array mapping token names to their CSS variable names. This mirrors what exists in `@infrastructure/ui/src/tokens.ts` and `globals.css` but as display-friendly metadata. Do not copy the actual HSL values — render swatches using `bg-[var(--background)]` etc. so they automatically reflect the active theme.
- **No `providers.tsx`:** Unlike `apps/web`, brand has no auth, no API client, no React Query. The only provider needed is `ThemeProvider` from `next-themes`, placed directly in `layout.tsx`.

## Architectural Patterns

### Pattern 1: CSS Custom Property Swatches (No Hardcoded Values)

**What:** Render color swatches as `<div style={{ background: "hsl(var(--primary))" }}>` or with Tailwind classes like `bg-primary`. Do not hardcode HSL values from `tokens.ts` — the CSS variables are the ground truth, and they switch automatically when the `.dark` class is toggled.

**When to use:** Every color swatch in the Color Token Section.

**Trade-offs:** + Always in sync with actual theme. + Demonstrates live dark/light switching. - Requires knowing the CSS variable names, which must be manually listed (they don't auto-discover at runtime without a CSS parser).

**Example:**
```tsx
// components/sections/color-section.tsx
const COLOR_TOKENS = [
  { name: "background", variable: "--background", tailwind: "bg-background" },
  { name: "foreground", variable: "--foreground", tailwind: "bg-foreground" },
  { name: "primary", variable: "--primary", tailwind: "bg-primary" },
  { name: "primary-foreground", variable: "--primary-foreground", tailwind: "bg-primary-foreground" },
  // ... all 14 tokens from @infrastructure/ui/src/globals.css
] as const;

export function ColorSection() {
  return (
    <section>
      <h2>Colors</h2>
      <div className="grid grid-cols-4 gap-4">
        {COLOR_TOKENS.map((token) => (
          <div key={token.name}>
            <div className={`h-16 rounded-md ${token.tailwind}`} />
            <p className="text-sm font-mono mt-1">{token.name}</p>
            <p className="text-xs text-muted-foreground">var({token.variable})</p>
          </div>
        ))}
      </div>
    </section>
  );
}
```

### Pattern 2: Variant Matrix for Component Display

**What:** For components with variants (Button has `variant` + `size`), render every combination in a grid. Use the actual exported component — never screenshots.

**When to use:** Components Section for Button, Card sizes, Field states.

**Trade-offs:** + Automatically reflects real component changes. + Catches visual regressions. - Initial setup requires knowing all variant combinations, which must be read from the component source.

**Example:**
```tsx
// components/sections/component-section.tsx
import { Button } from "@infrastructure/ui-web";

const BUTTON_VARIANTS = ["default", "outline", "secondary", "ghost", "destructive", "link"] as const;
const BUTTON_SIZES = ["xs", "sm", "default", "lg"] as const;

export function ButtonShowcase() {
  return (
    <div className="flex flex-wrap gap-3">
      {BUTTON_VARIANTS.map((variant) =>
        BUTTON_SIZES.map((size) => (
          <Button key={`${variant}-${size}`} variant={variant} size={size}>
            {variant} / {size}
          </Button>
        ))
      )}
    </div>
  );
}
```

### Pattern 3: Theme Toggle with next-themes (No Flash)

**What:** `ThemeProvider` from `next-themes` with `attribute="class"` injects the `dark` class on `<html>` before hydration. `suppressHydrationWarning` on the `<html>` element prevents React from warning about the class mismatch between server and client.

**When to use:** `app/layout.tsx` — this is the only provider the brand app needs.

**Trade-offs:** + Zero flash of wrong theme. + Persists to localStorage automatically. + System preference respected by default. - Adds one dependency (`next-themes`). - ThemeToggle component must be a Client Component (`"use client"`) to call `useTheme()`.

**Example:**
```tsx
// app/layout.tsx
import { ThemeProvider } from "next-themes";
import "./globals.css";

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body>
        <ThemeProvider attribute="class" defaultTheme="system" enableSystem>
          {children}
        </ThemeProvider>
      </body>
    </html>
  );
}
```

```tsx
// components/theme-toggle.tsx
"use client";
import { useTheme } from "next-themes";
import { Moon, Sun } from "lucide-react";
import { Button } from "@infrastructure/ui-web";

export function ThemeToggle() {
  const { theme, setTheme } = useTheme();
  return (
    <Button
      variant="ghost"
      size="icon"
      onClick={() => setTheme(theme === "dark" ? "light" : "dark")}
    >
      <Sun className="rotate-0 scale-100 transition-all dark:-rotate-90 dark:scale-0" />
      <Moon className="absolute rotate-90 scale-0 transition-all dark:rotate-0 dark:scale-100" />
    </Button>
  );
}
```

## Data Flow

### Request Flow

```
User visits localhost:3002
    |
Next.js Server Component (app/page.tsx)
    |
    +-- Renders ColorSection (static data from token list)
    +-- Renders TypographySection (static Tailwind classes)
    +-- Renders ComponentSection (imports from @infrastructure/ui-web)
    +-- Renders SpacingSection (static data from @infrastructure/ui/tokens.ts)
    |
HTML served with .dark class already applied (next-themes script)
    |
React hydration
    |
ThemeToggle (client) reads localStorage / system preference
    |
User clicks toggle → setTheme() → .dark class toggled on <html>
    |
CSS custom properties in :root / .dark switch → all token swatches update
```

### State Management

```
ThemeProvider (next-themes)
    |
    +-- localStorage ("theme" key)
    +-- window.matchMedia prefers-color-scheme
    |
useTheme() hook → {theme, setTheme}
    |
ThemeToggle component → button click → setTheme()
    |
.dark class on <html> → @custom-variant dark (&:where(.dark, .dark *))
    |
CSS custom properties in .dark {} block activate
    |
All components re-render with dark theme values (no JS involved — pure CSS)
```

### Key Data Flows

1. **Token display:** Static TypeScript arrays in `lib/tokens.ts` map human-readable names to CSS variable names. No API calls. No runtime parsing of CSS files.
2. **Component rendering:** Direct ESM imports from `@infrastructure/ui-web`. Turborepo ensures packages are built before the brand app consumes them. The brand app itself has no feature logic.
3. **Theme switching:** Fully CSS-driven after toggle click. The toggle sets a class; CSS custom properties do the rest. No React state per-component.

## Integration Points

### Monorepo Integration — New App Checklist

The `apps/brand` app follows the same pattern as `apps/landing` (the simplest existing Next.js app). The required integration steps are:

| Step | What | Why |
|------|------|-----|
| `package.json` | `name: "brand"`, port 3002 in `scripts.dev` | Unique name in workspace; avoids port conflict |
| `next.config.ts` | `transpilePackages: ["@infrastructure/ui", "@infrastructure/ui-web"]` | Next.js must compile workspace packages via SWC |
| `app/globals.css` | `@import "@infrastructure/ui/globals.css"` + `@source "../node_modules/@infrastructure/ui-web/src"` | CSS custom properties (theme) + Tailwind class scanning |
| `tsconfig.json` | Extend `@infrastructure/typescript-config/nextjs` | Consistent TS config |
| `pnpm-workspace.yaml` | Already covers `apps/*` — no change needed | Brand app auto-included |
| `turbo.json` | No change needed — `build`, `dev`, `test` tasks are inherited | Turborepo picks up the app automatically |

### Internal Package Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `apps/brand` → `@infrastructure/ui` | ESM import | `globals.css` for CSS vars, `tokens.ts` for spacing/radius data, `cn()` from `utils.ts` |
| `apps/brand` → `@infrastructure/ui-web` | ESM import | All component exports (Button, Card, Field, Input, Label, Separator) |
| `apps/brand` → `@features/*` | None | Brand app has no feature logic; no auth, no API |
| `apps/brand` → `@infrastructure/supabase` | None | No database, no auth |
| `apps/brand` → `@infrastructure/api-client` | None | No API calls |
| `apps/brand` → `@infrastructure/navigation` | None | Single-page app; no internal routing needed |

### External Dependencies (New for brand app)

| Package | Source | Purpose |
|---------|--------|---------|
| `next-themes` | New dependency | Theme toggle with no flash — not currently used in `apps/web` or `apps/landing` |
| `lucide-react` | Already in catalog | Sun/Moon icons for theme toggle button |

## Scaling Considerations

This is a local dev tool — scaling is not a concern. The architecture supports:

| Scale | Approach |
|-------|----------|
| Current (6 components, 14 tokens) | Single-page, static sections, no build-time generation |
| More components added to `@infrastructure/ui-web` | Add to the component section manually — no automation needed at this scale |
| New token groups added to `@infrastructure/ui` | Add to `COLOR_TOKENS` array in brand app; CSS variable auto-picked up |

## Anti-Patterns

### Anti-Pattern 1: Hardcoding HSL Values for Swatches

**What people do:** Copy HSL values from `globals.css` into a data array and render `background: "hsl(0 0% 100%)"` statically.

**Why it's wrong:** The swatch shows the hardcoded light value even in dark mode. The whole point of the brand kit is to demonstrate the live theme. Updating `globals.css` requires also updating the brand kit data array.

**Do this instead:** Use Tailwind semantic classes (`bg-primary`, `bg-muted`) or `style={{ background: "hsl(var(--primary))" }}`. The CSS variable resolves from the active theme automatically.

### Anti-Pattern 2: Adding Auth or Provider Bloat

**What people do:** Copy `providers.tsx` from `apps/web` into brand, including QueryClientProvider, AuthProvider, NavigationProvider.

**Why it's wrong:** Brand has no routes, no API calls, no auth. Each provider adds bundle weight, potential runtime errors from missing env vars, and complexity.

**Do this instead:** The only provider is `ThemeProvider` from `next-themes`. Keep `layout.tsx` minimal.

### Anti-Pattern 3: Using Separate Routes per Section

**What people do:** Create `app/colors/page.tsx`, `app/typography/page.tsx`, etc.

**Why it's wrong:** A brand kit is a reference document, not an app. Multi-route structure requires a nav sidebar, active state management, and layout coordination — all overhead for zero benefit. Developers want to scroll a single page.

**Do this instead:** One `app/page.tsx` with section anchors (`id="colors"`, `id="typography"`). Optional sticky sidebar with anchor links if the page grows long.

### Anti-Pattern 4: Prop Editing / Storybook Replacement

**What people do:** Add controls for changing variant, size, disabled state dynamically.

**Why it's wrong:** This is explicitly out of scope (per `PROJECT.md`). Building a prop editor is significant complexity and duplicates what Storybook does. The brand kit renders static "all variants" grids.

**Do this instead:** Static variant matrices. Every variant is always visible, no toggle needed.

## Build Order (Phase Implications)

Because this is a new Next.js app added to an existing monorepo, the dependency chain is:

```
1. @infrastructure/ui-web (already built — no changes needed)
       |
2. @infrastructure/ui (already built — no changes needed)
       |
3. apps/brand scaffolding (package.json, tsconfig, next.config.ts, globals.css)
       |
4. ThemeProvider integration (layout.tsx + next-themes)
       |
5. Color Token Section (reads from @infrastructure/ui CSS vars — CSS-driven, no TS changes)
       |
6. Typography Section (standalone, no external data)
       |
7. Component Section (imports from @infrastructure/ui-web — needs packages built first)
       |
8. Spacing Section (reads from @infrastructure/ui/tokens.ts)
       |
9. Theme Toggle (client component, depends on ThemeProvider being in layout)
```

Steps 5-9 are independent of each other after step 4. The critical path is: scaffold app → ThemeProvider → then any section order.

**Turborepo dependency note:** The `build` task in `turbo.json` uses `"dependsOn": ["^build"]`, meaning `apps/brand` will automatically wait for `@infrastructure/ui` and `@infrastructure/ui-web` to build first. No `turbo.json` changes needed.

## Sources

- Codebase inspection: `packages/infrastructure/ui/src/globals.css`, `tokens.ts`, `utils.ts` (HIGH confidence — direct source)
- Codebase inspection: `packages/infrastructure/ui-web/src/components/` — all 6 component files (HIGH confidence)
- Codebase inspection: `apps/web/next.config.ts`, `apps/landing/next.config.ts`, `apps/web/app/globals.css` (HIGH confidence — reference patterns)
- Codebase inspection: `apps/web/app/providers.tsx` — confirms what providers brand does NOT need (HIGH confidence)
- Codebase inspection: `.planning/PROJECT.md` — explicit constraints and out-of-scope items (HIGH confidence)
- [next-themes GitHub](https://github.com/pacocoursey/next-themes) — flash-free dark mode for Next.js App Router (MEDIUM confidence — verified approach matches codebase patterns)
- [shadcn/ui dark mode docs](https://ui.shadcn.com/docs/dark-mode/next) — confirms `attribute="class"` + `suppressHydrationWarning` pattern (MEDIUM confidence)
- [shadcn/ui monorepo docs](https://ui.shadcn.com/docs/monorepo) — `@source` directive and `transpilePackages` patterns (MEDIUM confidence, aligns with existing `apps/web` and `apps/landing` config)

---
*Architecture research for: design system brand kit app (apps/brand)*
*Researched: 2026-03-02*
