# Roadmap: Brand Kit

## Overview

Build `apps/brand`, a standalone Next.js app that serves as a living style guide for the monorepo's design system. The work follows a strict foundation-first order: the app scaffold must be airtight before any content is added (5 known pitfalls cluster at scaffolding time), token sections come next to validate the CSS variable rendering pipeline, component showcase completes the content, and anchor navigation is added last once all section IDs exist. Four phases deliver full v1 scope.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Foundation** - Scaffold `apps/brand` — buildable, typecheckable, theme-toggling shell with no content yet
- [ ] **Phase 2: Token Display** - Color palette and typography sections rendering live from `@infrastructure/ui` tokens
- [ ] **Phase 3: Component Showcase** - Spacing/radius sections plus full component variant grid for all `@infrastructure/ui-web` exports
- [ ] **Phase 4: Navigation** - Sticky anchor navigation linking all sections; page is complete and coherent as a scrollable reference

## Phase Details

### Phase 1: Foundation
**Goal**: `apps/brand` exists as a working Next.js app at port 3002 that builds, typechecks, and toggles light/dark theme with no flash — before any design system content is added
**Depends on**: Nothing (first phase)
**Requirements**: FOUN-01, FOUN-02
**Success Criteria** (what must be TRUE):
  1. `pnpm --filter brand dev` starts successfully and opens a page at port 3002
  2. `pnpm --filter brand build` completes without errors
  3. `pnpm typecheck` passes with `apps/brand` included
  4. The theme toggle button switches the entire page between light and dark mode with no visible flash on load
  5. No React hydration warnings appear in the browser console on page load
**Plans**: 1 plan
- [ ] 01-01-PLAN.md — Scaffold apps/brand with config, theme toggle, and build verification

### Phase 2: Token Display
**Goal**: The color palette section and typography section are visible, accurate, and update correctly when the theme is toggled
**Depends on**: Phase 1
**Requirements**: COLR-01, COLR-02, COLR-03, TYPO-01, TYPO-02
**Success Criteria** (what must be TRUE):
  1. All 14 semantic color tokens are displayed as visual swatches that show the actual rendered color in the current theme
  2. Each color swatch shows its CSS variable name and HSL value as text labels
  3. Color swatches are grouped into semantic role sections (surfaces, content, interactive, feedback)
  4. Swatch colors change visibly and correctly when the theme toggle is activated
  5. The typography section renders the full Tailwind type scale (text-xs through text-4xl) as live text at each weight
**Plans**: TBD

### Phase 3: Component Showcase
**Goal**: The spacing/border radius sections and the full component showcase section are visible, covering every `@infrastructure/ui-web` export at resting state
**Depends on**: Phase 2
**Requirements**: SPAC-01, SPAC-02, COMP-01, COMP-02, COMP-03, COMP-04, COMP-05
**Success Criteria** (what must be TRUE):
  1. The spacing section shows visual ruler bars for the spacing scale (0-64px) with Tailwind class names and pixel values
  2. The border radius section shows sm/md/lg as rendered shape examples with pixel values
  3. Button renders in all 6 variants (default, destructive, outline, secondary, ghost, link) across key sizes
  4. Card renders with header, content, and footer; Input, Label, and Separator render with typical usage patterns
  5. Field renders with FieldLabel, FieldError, and FieldDescription in a representative form arrangement
**Plans**: TBD

### Phase 4: Navigation
**Goal**: A sticky sidebar or top nav with anchor links to every section is present, making the page usable as a scrollable reference tool
**Depends on**: Phase 3
**Requirements**: FOUN-03
**Success Criteria** (what must be TRUE):
  1. A sticky navigation element (sidebar or top bar) is visible while scrolling the page
  2. Each section (Colors, Typography, Spacing, Components) has a corresponding anchor link in the nav
  3. Clicking a nav link scrolls directly to the correct section
  4. The navigation remains accessible in both light and dark themes
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 0/1 | Planned | - |
| 2. Token Display | 0/? | Not started | - |
| 3. Component Showcase | 0/? | Not started | - |
| 4. Navigation | 0/? | Not started | - |
