---
type: fix
status: executing
branch: fix/document-supported-harnesses
---

# Fix: Document supported harnesses in the docs app

## 1. Root Cause

The docs app has no authored owner for the supported-harness contract. The canonical six-harness taxonomy and host-specific capability differences live under `skills/using-woostack/references/hosts/`, but the earlier host-reference work scoped authored site synchronization to `site/content/docs/configuration.mdx`. `site/content/docs/meta.json` therefore has no harness group, while `site/content/docs/index.mdx` still names Aider and omits omp, opencode, and Antigravity CLI.

Evidence:

- `skills/using-woostack/references/hosts/README.md` defines the fixed reference contract for omp, opencode, Claude Code, Codex, Cursor / Composer, and Antigravity CLI.
- `site/content/docs/meta.json` registers no harness section.
- `site/content/docs/index.mdx` lists Claude Code, Cursor, Codex, and Aider instead of the canonical six.
- The host references explicitly differ on model/effort selection, tier routing, per-call working-directory support, headless CI support, and host-level fallback behavior.

## 2. Proposed Fix

Add an authored `Harnesses` docs group with an overview page and one page per explicitly supported harness. The overview will state that woostack's skill logic is harness-agnostic and should work in other harnesses, while unsupported harnesses may not expose native capabilities that woostack can use reliably, including per-call model selection, effort selection, subagent working-directory placement, parallel dispatch, or headless execution.

Each harness page will summarize only the differences that its canonical reference file explicitly covers: detection, subagent spawning, tier routing, host fallback, per-skill notes, and degradation. It will link to the canonical reference instead of duplicating operational detail. The overview comparison will cover the cross-harness capability differences without claiming unsupported behavior.

Register the group in `site/content/docs/meta.json`, repair the stale harness list and link on `site/content/docs/index.mdx`, and add a focused structural check that derives the expected harness pages from the six canonical reference files so future additions cannot silently drift.

## 3. Implementation Plan

- [x] **Step 1: Reproduce the documentation drift with a failing structural check**
  - Extend `skills/woostack-init/scripts/tests/test-host-references.sh`, the existing owner of the canonical host-file contract, to derive supported harness slugs from `skills/using-woostack/references/hosts/*.md`, excluding `README.md`.
  - Assert that the root navigation registers the Harnesses group, the group metadata registers its overview and every derived harness slug, and each authored harness page links to its canonical reference.
  - Assert the overview states both sides of the portability contract: skill logic should work in any harness, while unsupported harnesses may lack reliable native capabilities such as per-call model selection.
  - Assert the docs landing page no longer identifies Aider as explicitly supported and links readers to the Harnesses group.
  - Run `bash skills/woostack-init/scripts/tests/test-host-references.sh` and record the expected pre-fix failure.

- [x] **Step 2: Add the Harnesses docs group**
  - Create the Harnesses group metadata, overview, and six per-harness authored pages following the existing grouped-doc conventions.
  - Populate the comparison and per-harness summaries only from `skills/using-woostack/references/hosts/README.md`, the six host files, and `skills/using-woostack/references/model-tiers.md`.
  - State the portability contract precisely: core skill logic should work in any harness, but unsupported harnesses are not validated and harness-native capabilities such as model/effort selection may degrade or fail.
  - Register the group in the root docs navigation and repair the landing-page supported-harness copy and cross-link.

- [x] **Step 3: Verification**
  - Run `bash skills/woostack-init/scripts/tests/test-host-references.sh` and confirm canonical references, authored pages, navigation entries, and portability caveats stay in lockstep.
  - Install the docs app dependencies when the worktree lacks a real `site/node_modules`, then run `pnpm -C site build`.
  - Inspect the built route manifest for `/docs/harnesses` and all six harness detail routes; confirm no authored page invents capabilities absent from its canonical reference file.
