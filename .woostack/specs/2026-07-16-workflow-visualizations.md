---
name: workflow-visualizations
type: spec
status: approved
date: 2026-07-16
branch: feature/workflow-visualizations
links:
---

# Workflow Visualizations — Design Spec

> Artifact: `.woostack/specs/2026-07-16-workflow-visualizations.md`. This Markdown file is the source of truth. Render with [spec-template.html](../../../skills/woostack-build/references/spec-template.html) for a rich presentation only.

> `status:` follows the owning-artifact contract in [conventions.md](../../../skills/woostack-status/references/conventions.md).

> **Plan:** [[plans/2026-07-16-workflow-visualizations]]

## 1. Problem

The documentation app explains the Bootstrap, Build, Fix, and Change workflows primarily as prose and inline arrow sequences. The user explicitly requested visualizations of all four loops. Readers currently lack one place to compare each workflow's sequence, approval gates, branch outcomes, and terminal artifact without reconstructing those relationships from separate generated skill references.

## 2. Goal

Add one authored, discoverable workflow-maps page to the documentation app. It must visualize Bootstrap, Build, Fix, and Change accurately; distinguish work steps, approval gates, branches, and terminal artifacts; remain readable on narrow screens and in both themes; and preserve semantic access when styling is unavailable.

## 3. Non-goals

- Rewriting or replacing the generated per-skill reference pages.
- Changing any workflow, gate, lifecycle, artifact-backend, or worktree contract.
- Adding client-side state, animation, a diagramming library, or another runtime dependency.
- Duplicating detailed operational instructions already owned by the canonical `SKILL.md` files.
- Redesigning the wider documentation site or changing its typography and global theme.

## 4. Approach

Create a dedicated `/docs/concepts/workflows` page backed by a server-rendered `WorkflowAtlas` React component. The component uses typed static definitions for the four workflows and renders semantic ordered lists. A scoped CSS module turns those lists into responsive workflow rails with explicit visual treatments for work steps, gates, branch choices, and terminal outcomes.

The presentation uses Fumadocs theme tokens for its neutral structure and a local, accessible gate accent. Text and shape carry every distinction so color is never the sole signal. Desktop layouts use horizontal rails with compact branches; narrow layouts reflow into vertical rails rather than shrinking labels or introducing horizontal scrolling.

The page orders the workflows from the lightest bounded path to the broadest setup path: Change, Fix, Build, Bootstrap. Each section states when to use the workflow and links to its canonical skill reference. Discovery links are added to the concepts overview, Getting started, and Building rules, and the page is registered in the concepts navigation.

## 5. Components & data flow

- `site/content/docs/concepts/workflows.mdx` owns the page introduction, legend, usage framing, canonical links, and `WorkflowAtlas` placement.
- `site/components/concepts/workflow-atlas.tsx` owns the typed, static workflow definitions and semantic renderer. It remains a Server Component and introduces no client boundary.
- `site/components/concepts/workflow-atlas.module.css` owns rail geometry, semantic node treatments, responsive reflow, theme-compatible colors, and focus-visible states.
- `site/content/docs/concepts/meta.json` registers the authored page in navigation.
- `site/content/docs/concepts/index.mdx`, `site/content/docs/getting-started.mdx`, and `site/content/docs/concepts/building-rules.mdx` link readers to the comparison page.

The component receives no remote or runtime data. The committed definitions render deterministically during the docs build. Canonical workflow details remain in the four skills; the visualization page summarizes their stable sequence and links back for operational detail.

## 6. Error handling

- If CSS fails or is unavailable, ordered-list structure, node labels, gate labels, branch labels, and terminal outcomes remain readable in source order.
- Narrow screens use a vertical flow and wrapped labels; no workflow requires horizontal scrolling or scaled-down text.
- Gate, branch, and terminal meaning is expressed in visible text and semantic grouping, not color alone.
- Light and dark themes derive surfaces and text from Fumadocs tokens; local accent values must retain readable contrast in both themes.
- Long labels wrap inside their node rather than overflow or clip.
- The page does not copy adapter commands or lifecycle implementation details that could drift from the skills.

Security, observability, API, and database error paths are not implicated: this is static, local documentation rendering with no input, network request, persistence, or executable workflow action. The existing documentation source and search configuration are English-only, so this change follows that established copy contract rather than introducing an isolated translation layer. Dependency and infrastructure risk are bounded by adding no package and verifying against the existing typecheck and production-build commands.

## 7. Acceptance criteria

- **AC1 — Readers can discover one workflow comparison page.**
  - happy: `/docs/concepts/workflows` is present in Core concepts navigation and linked from the concepts overview, Getting started, and Building rules.
  - error: a missing component or invalid MDX import fails the existing docs typecheck/build rather than producing a partially rendered page.
  - edge: generated per-skill reference pages remain generated and untouched.
- **AC2 — The four workflow maps accurately communicate their contracts.**
  - happy: Bootstrap, Build, Fix, and Change each show their ordered work steps, approval behavior, branches where applicable, and terminal artifact.
  - error: no gate is implied where the canonical workflow has none, and no branch outcome is presented as execution approval.
  - edge: Build shows the shared three-gate loop plus the Markdown/Linear pre-execution distinction without duplicating two full diagrams; Fix shows Go, Hand off, Revise, and Abandon; Change explicitly states that it has no approval gate.
- **AC3 — The maps remain usable across layout and theme boundaries.**
  - happy: desktop and mobile layouts show readable labels and unambiguous connector order in light and dark themes.
  - error: styling loss still leaves a coherent ordered textual representation.
  - edge: long labels wrap without clipping, text does not shrink below the surrounding documentation scale, and the page introduces no horizontal workflow scroll.
- **AC4 — The maps expose accessible meaning without relying on color.**
  - happy: workflow groups and ordered steps have meaningful accessible labels, gates and outcomes include visible text, and canonical links have visible keyboard focus.
  - error: decorative connectors are hidden from assistive technology and do not create duplicate announcements.
  - edge: the accessibility tree preserves each workflow's source order after responsive reflow.
- **AC5 — The feature stays within the documentation app's existing architecture.**
  - happy: the implementation is server-rendered, uses Fumadocs tokens, adds no dependency, and passes the site's existing typecheck and production build.
  - error: any type, CSS-module, MDX, or production-rendering incompatibility fails verification before submission.
  - edge: no global theme rule or unrelated docs surface is changed.

## 8. Testing

Run the existing documentation checks with `pnpm -C site types:check` and `pnpm -C site build`. Then launch the documentation app and exercise `/docs/concepts/workflows` in a real browser at desktop and mobile widths, in light and dark themes. Inspect the accessibility tree and keyboard-focus behavior, and confirm every discovery link reaches the page. No new unit or snapshot test is planned because the new contract is static visual/semantic rendering and is better verified through the production build plus browser behavior.

## 9. Open questions

N/A — the approved design settled placement, interaction model, visual semantics, workflow ordering, responsive behavior, and verification strategy.
