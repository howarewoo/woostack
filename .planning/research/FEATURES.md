# Feature Research

**Domain:** Design system documentation / brand kit app (living style guide)
**Researched:** 2026-03-02
**Confidence:** HIGH (features grounded in well-established design system tooling patterns; verified against Storybook, shadcn/ui, zeroheight, and leading open-source examples)

---

## Context Note

This brand kit is a **personal dev tool**, not a collaborative SaaS product. It renders live components from `@infrastructure/ui-web` and displays tokens from `@infrastructure/ui`. Out of scope (per PROJECT.md): auth, component playground/prop editing, hosted deployment, code copy snippets, mobile (RN) components.

That constraint set meaningfully eliminates several categories competitors fight over (interactive sandboxes, collaboration, versioning) and sharpens focus on the core value: a single accurate visual reference for the design system.

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features a style guide app must have or it feels incomplete / unusable as a reference.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Color palette display | Every design system tool shows colors as the first section; missing = broken | LOW | Show all 14 semantic color tokens (background, foreground, primary, secondary, muted, accent, destructive, border, input, ring, card, popover, + foreground pairs) with swatch, CSS variable name, and HSL value |
| Light/dark theme toggle | shadcn/ui is dark-mode-native; without toggle you cannot evaluate colors in both modes | LOW | Toggle adds `dark` class on `<html>`; must persist across page refreshes (localStorage) |
| Typography display | Font size, weight, and line-height are foundational — any style guide covers this | LOW | Show Tailwind's type scale as rendered text at each size with label (text-xs → text-4xl); note the project has no custom font families so only size/weight/leading are shown |
| Component showcase | This is the stated primary purpose of the app | MEDIUM | Render every component from `@infrastructure/ui-web`: Button (all 6 variants × key sizes), Card (with header/content/footer), Input, Label, Separator, Field (with FieldLabel, FieldError, FieldDescription), all in their resting states |
| Border radius display | Radius tokens exist in `@infrastructure/ui`; spacing/geometry foundations are always shown | LOW | Show `--radius-sm`, `--radius-md`, `--radius-lg` as visual pill/rect examples with pixel values |
| Spacing scale | Spacing is a foundational token category; any real style guide shows it | LOW | Show the spacing scale from `tokens.ts` (0–64px) as visual ruler bars with Tailwind class and px value |
| Section navigation | Single-page reference needs anchors to jump between sections | LOW | Sticky sidebar or top nav with section anchors; no routing needed, anchor links suffice |

### Differentiators (Competitive Advantage)

Features that add meaningful value beyond what's expected, aligned with the "always in sync" core value.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Live CSS variable readout per theme | Shows the actual computed HSL values from `:root` and `.dark` for each token, pulled at runtime via `getComputedStyle` | LOW-MEDIUM | Eliminates the need to open DevTools or read source CSS; values reflect whatever the theme actually resolves to; `getComputedStyle(document.documentElement).getPropertyValue('--primary')` |
| Component state showcase (hover/focus/disabled) | Most reference pages show only resting state; showing states answers "what does this look like disabled?" without running the app | MEDIUM | Render each variant row with: normal, hover (CSS `:hover` via wrapper with `group`), focus-visible, disabled, and aria-invalid states side by side |
| Token grouping by semantic role | shadcn tokens follow semantic naming (primary, destructive, muted); grouping by role (surface, content, interactive, feedback) makes the palette readable | LOW | Group: surfaces (background, card, popover), content (foreground, muted-foreground, card-foreground), interactive (primary, secondary, accent, ring, input, border), feedback (destructive) |
| Side-by-side light/dark comparison | The toggle gives one-at-a-time view; a split view gives immediate contrast | MEDIUM | CSS `@media (prefers-color-scheme)` split or a forced `.dark` container next to a `:root` container; useful specifically for color tokens where you want to see both values without toggling |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Component prop editor / interactive controls | Storybook/Ladle do this; devs want to tweak props in-browser | Requires a full runtime prop system (MDX, controls, args); defeats the "no Storybook" constraint; massive scope creep for a personal reference tool | Show all meaningful variants statically — cover the matrix by rendering them, not by letting the user configure them |
| Copy-to-clipboard for code snippets | Devs want to copy import statements or usage examples | PROJECT.md explicitly marks this out of scope; adds authoring burden to keep examples accurate; the actual code is in the source files | Link to source file paths in section headers so the user knows where to look |
| Search / filter across tokens and components | Makes sense at Figma/zeroheight scale | Overkill for a 6-component, 14-token reference; nav anchors are sufficient | Anchor navigation with clear section headings |
| Versioning / changelog | Useful for team design systems | This is a personal dev tool with no audience beyond the author; git log serves this purpose | No versioning; the app auto-reflects current code |
| Design token editing / theme generator | Tools like tweakcn and shadcn Studio do this | Changes the purpose from "reference" to "authoring tool"; conflicts with tokens being owned by `@infrastructure/ui` | Keep tokens in source; display only |
| Icon gallery | Lucide icons are listed as the icon library in CLAUDE.md | The project has no icon package surface — Lucide is just available in components via `lucide-react`; a gallery requires cataloguing 1000+ icons | Skip; note "uses lucide-react" in typography/foundations section |
| Mobile (React Native) component showcase | RN components exist in the monorepo | PROJECT.md explicitly excludes mobile; RN components can't render in Next.js without Expo Web | Limit to `@infrastructure/ui-web`; add a note that mobile uses UniWind + react-native-reusables |
| Accessibility audit panel | Useful in Storybook with a11y addon | Requires axe-core integration and per-story isolation; enormous complexity relative to value for a personal tool | Ensure the brand kit app itself is accessible but don't build a live a11y checker |

---

## Feature Dependencies

```
[Color palette display]
    └──requires──> [Light/dark theme toggle]
                       └──enables──> [Side-by-side light/dark comparison]

[Component showcase]
    └──requires──> [Light/dark theme toggle]  (components must render in both themes)

[Live CSS variable readout]
    └──requires──> [Light/dark theme toggle]  (readout changes with theme; meaningless without it)

[Component state showcase]
    └──enhances──> [Component showcase]  (same section, extended rendering)

[Token grouping by semantic role]
    └──enhances──> [Color palette display]  (layout concern, not a separate feature)

[Section navigation]
    └──requires──> [Color palette display, Typography, Component showcase, Spacing, Border radius]
                   (only meaningful once sections exist)
```

### Dependency Notes

- **Light/dark theme toggle blocks almost everything else:** It must be the first thing built. Every section needs to render in both modes to be useful.
- **Color palette display + live CSS variable readout are tightly coupled:** Build readout as part of the color section, not a separate feature. Pull values with `getComputedStyle` on theme change.
- **Component state showcase enhances (not replaces) component showcase:** Build the basic showcase first, then add state rows. Don't block launch on having all states.
- **Side-by-side comparison is independent:** It can be added after the toggle exists; it's a layout option on the color section, not a global concern.

---

## MVP Definition

### Launch With (v1)

Minimum needed to replace "digging through source files" as the primary workflow.

- [ ] Light/dark theme toggle — everything depends on this; build first
- [ ] Color palette section — 14 semantic tokens with swatch, CSS var name, HSL value, grouped by semantic role
- [ ] Typography section — Tailwind type scale rendered as live text (size + weight + leading)
- [ ] Spacing scale section — visual ruler bars for the 11 spacing values from `tokens.ts`
- [ ] Border radius section — visual shape examples for sm/md/lg with px values
- [ ] Component showcase — all 6 ui-web components in all variants at resting state
- [ ] Anchor navigation — sticky nav linking to each section

### Add After Validation (v1.x)

Features to add once the basic reference is working and gaps are felt.

- [ ] Live CSS variable readout per theme — add when toggling and visually checking HSL is not enough; one extra `getComputedStyle` call per section
- [ ] Component state showcase — add when "what does this look like disabled?" becomes a recurring question during UI development

### Future Consideration (v2+)

- [ ] Side-by-side light/dark comparison — defer until the toggle approach proves insufficient; requires non-trivial layout work (forced `.dark` scoped container)

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Light/dark theme toggle | HIGH | LOW | P1 |
| Color palette display | HIGH | LOW | P1 |
| Component showcase | HIGH | MEDIUM | P1 |
| Anchor navigation | HIGH | LOW | P1 |
| Typography section | MEDIUM | LOW | P1 |
| Spacing scale | MEDIUM | LOW | P1 |
| Border radius display | LOW | LOW | P1 (trivial, do it) |
| Live CSS variable readout | MEDIUM | LOW-MEDIUM | P2 |
| Component state showcase | MEDIUM | MEDIUM | P2 |
| Side-by-side light/dark | LOW | MEDIUM | P3 |

**Priority key:**
- P1: Must have for launch — the app isn't a useful reference without these
- P2: Should have — adds meaningful reference value; add when P1 is stable
- P3: Nice to have — defer until the core proves useful

---

## Competitor Feature Analysis

Reference: how established tools handle the same feature categories.

| Feature | shadcn/ui docs (ui.shadcn.com) | Storybook | tweakcn / shadcn Studio | Our Approach |
|---------|-------------------------------|-----------|------------------------|--------------|
| Color display | Color grid with hex/HSL + var name | Token addon (optional) | Interactive picker with live preview | Static display with computed HSL via `getComputedStyle`; no editing |
| Component showcase | Static rendered examples, no controls | Stories with prop controls | Live preview tied to theme editor | Static, all variants pre-rendered; no controls (out of scope) |
| Dark mode | Toggle in header | Dark background toggle per story | Full theme editing | Single page-wide toggle; persisted in localStorage |
| Typography | Basic type scale reference | Per-story via docs | Not a focus | Tailwind scale rendered as live text |
| Navigation | Left sidebar, nested | Top-level category + story tree | Single-page | Sticky sidebar with section anchors |
| Token readout | Shows var name in docs | Addon table view | Real-time CSS edit | `getComputedStyle` readout per theme |
| Code snippets | Copy button on every block | Per-story source | Export CSS block | Explicitly out of scope per PROJECT.md |
| Interactive controls | None (static docs) | Full controls panel | Color pickers | Not building — static showcase only |

---

## Sources

- [Design System: 13 Real-World Examples (2025) — UXPin](https://www.uxpin.com/studio/blog/best-design-system-examples/)
- [Level up your design system in 2025 — zeroheight](https://zeroheight.com/blog/level-up-your-design-system-in-2025/)
- [Design System report 2025 — zeroheight](https://zeroheight.com/resource/design-system-report-2025/)
- [Design System vs UI Component Library vs Brand Style Guide — prototype.ae](https://www.prototype.ae/blog/design-system-component-library-style-guide)
- [Theming — shadcn/ui](https://ui.shadcn.com/docs/theming)
- [Storybook Design Token addon](https://storybook.js.org/addons/storybook-design-token)
- [Beautiful themes for shadcn/ui — tweakcn](https://tweakcn.com/)
- [Design System 101 — NN/g](https://www.nngroup.com/articles/design-systems-101/)
- [Color tokens: guide to light and dark modes — Medium/Bootcamp](https://medium.com/design-bootcamp/color-tokens-guide-to-light-and-dark-modes-in-design-systems-146ab33023ac)
- [An In-Depth Overview Of Living Style Guide Tools — Smashing Magazine](https://www.smashingmagazine.com/2015/04/an-in-depth-overview-of-living-style-guide-tools/)
- Internal: `packages/infrastructure/ui/src/globals.css` (14 semantic tokens + radius)
- Internal: `packages/infrastructure/ui/src/tokens.ts` (spacing + borderRadius + colors)
- Internal: `packages/infrastructure/ui-web/src/index.ts` (exported components: Button, Card, Field, Input, Label, Separator)
- Internal: `.planning/PROJECT.md` (out-of-scope constraints, tech requirements)

---
*Feature research for: Design system brand kit / living style guide app*
*Researched: 2026-03-02*
