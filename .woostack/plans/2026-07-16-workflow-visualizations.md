---
type: plan
source: .woostack/specs/2026-07-16-workflow-visualizations.md
status: done
branch: feature/workflow-visualizations
---

**Source:** [[specs/2026-07-16-workflow-visualizations]]

# Workflow Visualizations Implementation Plan

**Goal:** Add one discoverable, accessible workflow-maps page that accurately compares the Bootstrap, Build, Fix, and Change loops.

**Architecture:** Render four typed static workflow definitions through one server-rendered `WorkflowAtlas` component. Semantic HTML owns reading order and meaning; a scoped CSS module turns the ordered content into horizontal desktop rails and vertical mobile rails without client state or a new dependency. The authored MDX page frames the comparison and links back to the canonical generated skill references.

**Tech Stack:** Next.js App Router, React Server Components, TypeScript, MDX/Fumadocs, CSS Modules, Fumadocs theme tokens.

## File structure

- Create `site/components/concepts/workflow-atlas.tsx`: workflow types, four canonical static definitions, legend, and semantic renderer.
- Create `site/components/concepts/workflow-atlas.module.css`: scoped rail geometry, node/gate/branch/terminal treatments, responsive layout, wrapping, theme compatibility, and focus-visible styling.
- Create `site/content/docs/concepts/workflows.mdx`: authored comparison page, usage guidance, component import, and canonical skill links.
- Modify `site/content/docs/concepts/meta.json`: register `workflows` immediately after `building-rules`.
- Modify `site/content/docs/concepts/index.mdx`: add the Workflow maps discovery card.
- Modify `site/content/docs/getting-started.mdx`: link the command-selection guidance to Workflow maps.
- Modify `site/content/docs/concepts/building-rules.mdx`: point readers from the shared Build loop to the four-workflow comparison.

## Increment 1: Add the workflow maps page

> One independently shippable PR, stacked on `feature/workflow-visualizations`. Expected implementation is below the 500 LOC soft target and contains the complete UI, discovery links, and verification.

**Dependencies:** none.

**Git parent:** `feature/workflow-visualizations`.

### Task 1: Build the semantic workflow atlas

**Files:**
- Create: `site/components/concepts/workflow-atlas.tsx`
- Create: `site/components/concepts/workflow-atlas.module.css`

- [x] **Step 1: Confirm the component baseline is absent.**
  Run: `test -e site/components/concepts/workflow-atlas.tsx`
  Expected: exit 1 because the component does not exist on the spec+plan base branch.

- [x] **Step 2: Define the workflow model and canonical content.**
  In `workflow-atlas.tsx`, define local discriminated types equivalent to:
  ```ts
  type StepKind = 'work' | 'gate' | 'handoff' | 'terminal';

  type WorkflowStep = {
    label: string;
    detail?: string;
    kind: StepKind;
  };

  type WorkflowBranch = {
    label: string;
    steps: readonly WorkflowStep[];
  };

  type Workflow = {
    id: 'change' | 'fix' | 'build' | 'bootstrap';
    title: string;
    useWhen: string;
    href: string;
    gateCount: number;
    steps: readonly WorkflowStep[];
    branches?: readonly WorkflowBranch[];
  };
  ```
  Populate `readonly Workflow[]` in this order and with these contracts:
  - Change: classify scope → isolate worktree → implement → verify and smoke-test → two-lens inline review → commit and submit → verify PR and tear down → one reviewed PR; `gateCount: 0` and visible “No approval gate”.
  - Fix: diagnose root cause → write combined fix plan → harden and commit → approve-to-execute gate; branches are Go → TDD execute → one reviewed PR, Hand off → approved plan PR with no code, Revise → update and re-present the committed plan, and Abandon → close/remove temporary artifacts.
  - Build: ideate → design approval gate → capture and harden spec → written-spec approval gate → plan/decompose/harden → prepare backend handoff → execution handoff gate; branches are Go → reviewed PR stack, Run overnight → reviewed or truthfully blocked stack plus morning report, and Hand off → ready artifacts with no implementation PR. The prepare-handoff detail names Markdown’s spec+plan base PR and Linear’s project/issues plus frozen base without drawing separate loops.
  - Bootstrap: gather requirements → live industry research → compare stack options → explicit stack choice → load reference contracts → scaffold and clean boilerplate → verify pipelines and boot surfaces → bootable project.
  Link each title to `/docs/skills/woostack-change`, `/docs/skills/woostack-fix`, `/docs/skills/woostack-build`, or `/docs/skills/woostack-bootstrap` respectively.

- [x] **Step 3: Render semantic groups before visual connectors.**
  Export a named `WorkflowAtlas` function and default export. Render a `<figure>` containing a visible legend and one `<section aria-labelledby>` per workflow. Render the primary sequence as `<ol>` and each branch as a labelled nested `<div>` plus `<ol>`. Include visible `Gate`, `Handoff`, `Outcome`, and `No approval gate` text; set decorative connector elements or pseudo-elements outside the accessibility tree. Keep the component server-rendered: do not add `'use client'`, hooks, event handlers, or runtime data.

- [x] **Step 4: Style responsive workflow rails.**
  In the CSS module:
  - derive foreground, muted foreground, card, border, and primary surfaces from `--color-fd-*` tokens;
  - define a local amber gate accent with verified readable foreground in light and dark themes;
  - use shape plus visible labels so color is never the only distinction;
  - render desktop primary sequences left-to-right with CSS grid/flex and connector pseudo-elements;
  - render branches as compact continuations that remain visually attached to their decision node;
  - at a narrow breakpoint, switch every sequence and branch to vertical rails, preserve DOM order, remove horizontal connector assumptions, and avoid horizontal scrolling;
  - cap node corner radii at 12px, allow long labels to wrap, and use the surrounding docs type scale rather than shrinking diagram text;
  - add visible `:focus-visible` treatment for skill links and a non-color-only gate marker;
  - add no animation and change no global stylesheet.

- [x] **Step 5: Run the component-level type check.**
  Run: `pnpm -C site types:check`
  Expected: PASS with no TypeScript, CSS-module, MDX-generation, or Next.js type errors.

### Task 2: Add the authored page and discovery links

**Files:**
- Create: `site/content/docs/concepts/workflows.mdx`
- Modify: `site/content/docs/concepts/meta.json`
- Modify: `site/content/docs/concepts/index.mdx`
- Modify: `site/content/docs/getting-started.mdx`
- Modify: `site/content/docs/concepts/building-rules.mdx`

- [x] **Step 1: Confirm the route baseline is absent.**
  Run: `test -e site/content/docs/concepts/workflows.mdx`
  Expected: exit 1 because the authored route does not exist on the spec+plan base branch.

- [x] **Step 2: Author the workflow comparison page.**
  Create `workflows.mdx` with frontmatter title `Workflow maps` and a description that names the four compared loops. Import `WorkflowAtlas` from `@/components/concepts/workflow-atlas`. Explain in concise prose that the maps summarize canonical skills and that work steps are not approval gates. Render `<WorkflowAtlas />`, then add a short “Choose the loop” section linking Bootstrap for greenfield creation, Build for multi-PR features, Fix for diagnosed bugs/root-cause work, and Change for bounded non-bug work that fits one PR.

- [x] **Step 3: Register the page in Core concepts navigation.**
  Insert `"workflows"` immediately after `"building-rules"` in `site/content/docs/concepts/meta.json`; preserve the existing page order otherwise.

- [x] **Step 4: Add three bounded discovery links.**
  - In `concepts/index.mdx`, add one `Workflow maps` card beside Building rules with a description that compares Bootstrap, Build, Fix, and Change.
  - In `getting-started.mdx`, add one sentence after the Bootstrap/Build/Change/Fix command-selection bullets linking to `/docs/concepts/workflows` for the visual comparison.
  - In `concepts/building-rules.mdx`, add one sentence after the shared loop introduction linking to Workflow maps for the cross-workflow comparison.
  Do not copy stage-by-stage operational instructions into these pages.

- [x] **Step 5: Run the complete production checks.**
  Run: `pnpm -C site types:check`
  Expected: PASS.
  Run: `pnpm -C site build`
  Expected: PASS with no MDX, CSS-module, TypeScript, or production-rendering error; route behavior is proven by the built-app browser exercise in Task 3.

### Task 3: Exercise the workflow maps as a reader

**Files:**
- Verify: `site/content/docs/concepts/workflows.mdx`
- Verify: `site/components/concepts/workflow-atlas.tsx`
- Verify: `site/components/concepts/workflow-atlas.module.css`

- [x] **Step 1: Start the built documentation app.**
  Start `pnpm -C site start --port 4173` through the host’s long-running-process manager after the successful production build and wait for port 4173 to accept connections.

- [x] **Step 2: Verify the desktop route in both themes.**
  Open `/docs/concepts/workflows` at 1440×900. Confirm four workflow sections in Change, Fix, Build, Bootstrap order; readable left-to-right rails; visible gate and outcome labels; correct branch attachment; working canonical skill links; no clipped labels; and no document-level horizontal overflow. Toggle light/dark theme and confirm every label and node remains readable.

- [x] **Step 3: Verify the narrow layout and source order.**
  Recheck at 390×844. Confirm all rails reflow vertically, branch continuations remain associated with their decision, long labels wrap, the document has no horizontal overflow, and all content remains at the surrounding documentation text scale.

- [x] **Step 4: Verify accessibility and discovery.**
  Inspect the browser accessibility tree for four labelled workflow groups, ordered primary steps, labelled branches, visible gate/outcome meaning, and no duplicate announcements from decorative connectors. Keyboard through every skill and discovery link and confirm visible focus. Follow the links from Core concepts, Getting started, and Building rules back to `/docs/concepts/workflows`.

- [x] **Step 5: Commit the reviewed increment.**
  Invoke `woostack-commit` from the increment worktree with subject `feat(site): add workflow maps`. The PR body must report both production commands and the desktop/mobile, light/dark, accessibility, focus, and discovery-link browser evidence. Do not merge.

## Acceptance coverage

- **AC1 — discoverability:** Task 2 steps 2–5 and Task 3 step 4.
- **AC2 — workflow accuracy:** Task 1 steps 2–3 and Task 3 step 2.
- **AC3 — responsive/theme usability:** Task 1 step 4 and Task 3 steps 2–3.
- **AC4 — semantic accessibility:** Task 1 steps 3–4 and Task 3 step 4.
- **AC5 — existing architecture:** Task 1 steps 3–5, Task 2 step 5, and Task 3 step 1.

## Plan checks

- **Spec coverage:** every requirement and non-goal maps to the file structure, implementation tasks, or verification tasks.
- **AC coverage:** AC1–AC5 each map to concrete implementation and reader-observed verification above.
- **Premise:** the approved source spec records the user’s explicit request and the current prose-only comparison gap in §1.
- **No placeholders:** paths, types, content contracts, commands, expected outcomes, breakpoints, and browser viewports are concrete; there are no TBD/TODO markers.
- **Type consistency:** the component is a Server Component, the static definitions use local readonly discriminated types, and MDX imports the named export.
- **Angle coverage:** architecture, tests/verification, dependency, i18n, infrastructure, accessibility, and error/edge behavior are addressed. Security, observability, API, and database surfaces remain correctly skipped because no input, network, persistence, or executable workflow action is introduced.
- **Graph validity:** one independently shippable increment, no dependency cycle, and one representable Git parent (`feature/workflow-visualizations`).
