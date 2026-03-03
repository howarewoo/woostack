# Brand Kit

## What This Is

A standalone Next.js app (`apps/brand`) that serves as a living style guide for the monorepo's design system. It renders actual components from `@infrastructure/ui-web` and displays all design tokens from `@infrastructure/ui`, so the reference is always in sync with the real code. Built for personal use during UI/UX development.

## Core Value

A single page where every design element — colors, typography, components, spacing — is visible and accurate, so design decisions can be made quickly without digging through source files.

## Requirements

### Validated

- ✓ Shared design tokens (HSL color palette, border radius, spacing) — existing in `@infrastructure/ui`
- ✓ Shared UI components (Button, Card, Input, Label, Separator, Field) — existing in `@infrastructure/ui-web`
- ✓ Light/dark theme support via CSS custom properties — existing
- ✓ Tailwind v4 CSS-first configuration — existing

### Active

- [ ] Standalone Next.js app at `apps/brand` with its own dev port
- [ ] Color palette section showing all theme colors with HSL values (light + dark)
- [ ] Typography section showing font families, sizes, and weights
- [ ] Components section rendering every `@infrastructure/ui-web` component with variants
- [ ] Spacing and layout section showing the spacing scale, border radius values, and container widths
- [ ] Light/dark theme toggle that switches the entire page

### Out of Scope

- Auth or access control — personal dev tool only
- Mobile (React Native) components — web design system only
- Component playground / prop editing — just render the components, not Storybook
- Hosted/deployed version — local dev server only
- Code snippets or copy-paste examples — this is visual reference, not docs

## Context

- Existing design tokens live in `packages/infrastructure/ui/src/globals.css` (14 color tokens + radius)
- Existing components in `@infrastructure/ui-web`: Button, Card, Input, Label, Separator, Field (with FieldLabel, FieldError)
- shadcn/ui `base-vega` style, uses Base UI primitives
- Tailwind v4 requires `@source` directive for scanning `@infrastructure/ui-web` classes
- The monorepo already has `apps/web` (port 3001) and `apps/landing` (port 3000) as Next.js app references
- Port assignment: 3002 (next available after 3001)

## Constraints

- **Tech stack**: Must be Next.js 16 + Tailwind v4 to match existing web apps
- **Dependencies**: Must consume `@infrastructure/ui-web` and `@infrastructure/ui` directly — no copying components
- **Conventions**: Follow monorepo patterns (unscoped app name, Biome formatting, `@source` directive)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Standalone app vs route in existing app | Keeps brand kit isolated; won't add weight to production apps | — Pending |
| Live components vs screenshots | Stays in sync automatically; no maintenance burden | — Pending |
| Theme toggle vs side-by-side | Simpler to build; full page context per theme | — Pending |

---
*Last updated: 2026-03-02 after initialization*
