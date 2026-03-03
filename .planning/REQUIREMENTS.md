# Requirements: Brand Kit

**Defined:** 2026-03-02
**Core Value:** A single page where every design element is visible and accurate, so design decisions can be made quickly without digging through source files.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Foundation

- [x] **FOUN-01**: Standalone Next.js app at `apps/brand` with dev server on port 3002
- [x] **FOUN-02**: Light/dark theme toggle that switches the entire page via `.dark` class on `<html>`
- [ ] **FOUN-03**: Sticky sidebar or top nav with anchor links to each section

### Colors

- [ ] **COLR-01**: Color palette section displaying all 14 semantic tokens as visual swatches
- [ ] **COLR-02**: Each swatch shows CSS variable name and HSL value
- [ ] **COLR-03**: Colors grouped by semantic role (surfaces, content, interactive, feedback)

### Typography

- [ ] **TYPO-01**: Typography section showing Tailwind type scale as rendered text (text-xs through text-4xl)
- [ ] **TYPO-02**: Font weight examples displayed at each size

### Spacing

- [ ] **SPAC-01**: Spacing scale section showing values (0–64px) as visual ruler bars with Tailwind class and px value
- [ ] **SPAC-02**: Border radius section showing sm/md/lg as visual shape examples with px values

### Components

- [ ] **COMP-01**: Component showcase section rendering all `@infrastructure/ui-web` components
- [ ] **COMP-02**: Button rendered in all variants (default, destructive, outline, secondary, ghost, link) and sizes
- [ ] **COMP-03**: Card rendered with header, content, and footer
- [ ] **COMP-04**: Input, Label, and Separator rendered with typical usage
- [ ] **COMP-05**: Field rendered with FieldLabel, FieldError, and FieldDescription

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Enhanced Token Display

- **TOKN-01**: Live CSS variable readout per theme via `getComputedStyle`
- **TOKN-02**: Side-by-side light/dark comparison view for color tokens

### Enhanced Components

- **ECMP-01**: Component state showcase (hover, focus, disabled, aria-invalid) for each variant

## Out of Scope

| Feature | Reason |
|---------|--------|
| Auth / access control | Personal dev tool only |
| Mobile (React Native) components | Web design system only; RN can't render in Next.js |
| Component playground / prop editing | Visual reference, not Storybook |
| Hosted / deployed version | Local dev server only |
| Code snippets / copy-paste | Visual reference, not documentation |
| Icon gallery | Lucide is available but no custom icon surface to catalogue |
| Search / filter | 6 components, 14 tokens — anchor nav is sufficient |
| Versioning / changelog | Git log serves this purpose |
| Token editing / theme generator | Display only; tokens owned by `@infrastructure/ui` |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| FOUN-01 | Phase 1 | Complete |
| FOUN-02 | Phase 1 | Complete |
| FOUN-03 | Phase 4 | Pending |
| COLR-01 | Phase 2 | Pending |
| COLR-02 | Phase 2 | Pending |
| COLR-03 | Phase 2 | Pending |
| TYPO-01 | Phase 2 | Pending |
| TYPO-02 | Phase 2 | Pending |
| SPAC-01 | Phase 3 | Pending |
| SPAC-02 | Phase 3 | Pending |
| COMP-01 | Phase 3 | Pending |
| COMP-02 | Phase 3 | Pending |
| COMP-03 | Phase 3 | Pending |
| COMP-04 | Phase 3 | Pending |
| COMP-05 | Phase 3 | Pending |

**Coverage:**
- v1 requirements: 15 total
- Mapped to phases: 15
- Unmapped: 0

---
*Requirements defined: 2026-03-02*
*Last updated: 2026-03-02 after roadmap creation*
