---
type: fix
status: in-review
branch: fix/context-management-economy
---

# Fix: Move context economy under context management

## 1. Root Cause

The docs already have a `Core concepts` folder at `site/content/docs/concepts/` and a
`Context management` page at `site/content/docs/concepts/context-management.mdx`, but the folder
index is also titled "Core concepts" and still contains a "Context economy" section. That creates
two related problems:

- The sidebar can present the folder as "Core concepts" with an index child also named "Core
  concepts".
- Context-economy material is split between the overview page and the dedicated Context management
  page, even though the taxonomy says context economy belongs under Context management.

Evidence:

- `site/content/docs/concepts/meta.json` sets the folder title to "Core concepts".
- `site/content/docs/concepts/index.mdx` also has `title: Core concepts`.
- `site/content/docs/concepts/index.mdx` contains `## Context economy`, imports
  `ContextEconomy`, and links to the context-economy mechanics.
- `site/content/docs/concepts/context-management.mdx` already exists and is the correct page for
  the context-economy explanation.

## 2. Proposed Fix

Make `Core concepts` a folder label with an "Overview" index page, and keep context-economy
material on the existing Context management child page.

Minimal targeted changes:

- Rename the `site/content/docs/concepts/index.mdx` page title from "Core concepts" to "Overview"
  so the `Core concepts` folder no longer has a child page with the same name.
- Remove the `ContextEconomy` import and the `## Context economy` section from
  `site/content/docs/concepts/index.mdx`.
- Keep or move all context-economy explanation under
  `site/content/docs/concepts/context-management.mdx`.
- Update internal docs links/cards that currently point context-economy readers at
  `/docs/concepts` so they point at `/docs/concepts/context-management` or the matching anchor.
- Update the component comment in `site/components/concepts/context-economy.tsx` so it names the
  Context management page instead of Core concepts.

## 3. Implementation Plan

- [x] **Step 1: Reproduce with a failing docs assertion**
  - Add or extend a site script test that asserts the concepts folder keeps the title "Core
    concepts", its index page title is "Overview", and `context-management` remains listed in
    `site/content/docs/concepts/meta.json`.
  - Assert that `site/content/docs/concepts/index.mdx` no longer imports `ContextEconomy` or
    defines `## Context economy`.
- [x] **Step 2: Apply the minimal docs split**
  - Retitle the concepts index page to "Overview".
  - Trim context-economy content from the index page while preserving overview cards and links.
  - Update docs cards, links, and the context-economy component comment.
- [x] **Step 3: Verification**
  - Run the focused site script tests.
  - Run the site type check if dependencies are available.
