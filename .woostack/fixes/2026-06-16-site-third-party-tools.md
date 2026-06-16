---
type: fix
status: in-review
branch: fix/site-third-party-tools
---

# Fix: Getting Started has no "recommended third-party tools" section

## 1. Root Cause

This is not a bug — it is a small docs addition to the shipped Fumadocs site
(`site/`, Mode A). The Getting Started page
(`site/content/docs/getting-started.mdx`) currently has four numbered steps
(Install, Initialize, Integrate, Build something) and a single "Recommended
companion" callout for **impeccable** embedded inside step 1. There is no
consolidated place that points readers at independent third-party tools that
pair well with woostack. Two such tools — Headroom (token compression) and
humanizer (copy humanization) — have no mention.

**Investigation evidence:**
- `site/content/docs/getting-started.mdx` ends at step 4; no trailing tools section.
- `impeccable` is the only third-party tool referenced, and only as an inline
  callout in step 1, not in a discoverable "tools" section.
- The page lives within an existing committed `meta.json`
  (`["index","getting-started",...]`) — this change edits an existing page, so
  **no `meta.json` / navigation change is required**.
- Tool research (live):
  - **Headroom** (https://headroom-docs.vercel.app/docs) — token-compression /
    context layer for LLM agents. Shrinks tool outputs, file reads, search
    results before they reach the model; reversible (agent fetches the full
    original on demand). Installs several ways including an **MCP server**.
    *No `pnpx skills add` install — it is not a skill; link to its docs instead.*
  - **humanizer** (https://github.com/blader/humanizer, owner `blader`) — a
    Claude Code / OpenCode **skill** that rewrites text to strip signs of
    AI authorship (based on Wikipedia's "Signs of AI writing"). Installs via the
    same `pnpx skills add <owner>/<repo>` pattern the page already uses for
    impeccable: `pnpx skills add blader/humanizer`.

## 2. Proposed Fix

Add one new trailing section to `site/content/docs/getting-started.mdx`, after
step 4 ("Build something"):

- Heading: `## Recommended third-party tools` (unnumbered — these are optional
  companions, not sequential install steps, matching how the impeccable callout
  is framed).
- A one-line framing sentence that these are independent, optional tools that
  pair well with woostack.
- A bullet for **Graphite** (added at user request during execution): stacked-PR
  management and code review for Git, linked to https://graphite.com, noting
  woostack already drives source control through its `gt` CLI. **No fabricated
  install command** — link to the docs (same treatment as Headroom). Placed first
  as the most woostack-integral of the three.
- A bullet for **Headroom**: what it does (token compression for LLM agents,
  fewer tokens / more context on long woostack sessions, reversible), linked to
  its docs, noting it installs as an MCP server. **No fabricated install
  command** — link to https://headroom-docs.vercel.app/docs.
- A bullet for **humanizer**: what it does (copy humanization — strips AI-writing
  tells, useful for polishing spec prose / READMEs / PR descriptions), linked to
  its repo, with the `pnpx skills add blader/humanizer` command in a fenced bash
  block (consistent with the existing impeccable example).

Leave the existing impeccable callout in step 1 untouched (it is wired to the
`design` review angle and is more integral than these two). **Harden decision:**
add a short pointer line at the end of the new section back to the impeccable
companion in step 1, so the "tools" section is the single discoverable index of
third-party companions without duplicating or moving the callout.

No other files change. The per-skill reference pages regenerate at build time and
are unaffected.

## 3. Implementation Plan

- [x] **Step 1: Reproduce with a failing check**
  - There is no runtime to unit-test for a static MDX docs page. The concrete
    verification is the site build plus an explicit content assertion. Before the
    edit, confirm the absence: `grep -n "Recommended third-party tools"
    site/content/docs/getting-started.mdx` returns nothing (the "red" state).
    Confirmed absent before the edit.
- [x] **Step 2: Apply the minimal fix**
  - Append the `## Recommended third-party tools` section to
    `site/content/docs/getting-started.mdx` with the Headroom and humanizer
    bullets described in §2. Done (with the impeccable pointer line per harden).
- [x] **Step 3: Verification**
  - `grep -n "Recommended third-party tools\|Headroom\|humanizer"
    site/content/docs/getting-started.mdx` shows the new section and both tools
    (the "green" state). Confirmed.
  - `pnpm -C site build` succeeds (MDX parses, links resolve, no broken build) —
    the CLAUDE.md hard-constraint check for authored-page changes. Build passed;
    `/docs/getting-started` prerendered.
