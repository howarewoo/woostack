---
name: readme-rewrite
type: spec
status: planning
date: 2026-06-09
branch: feature/readme-rewrite
links:
---

# README Rewrite — Design Spec

> Visualize on demand: render this file with [spec-template.html](spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../woostack-status/references/conventions.md).

## 1. Problem

The current repository `README.md` is outdated, verbose, and lists legacy patterns (like the `memory.md` flat shard and `pnpx skills add` with incorrect context on initialization). It does not clearly and concisely guide developers on the primary entry points for development versus review skills, nor does it emphasize the mandatory order of operations.

## 2. Goal

Completely rewrite the repository `README.md` to be clean, modern, and aligned with current woostack rules. The new README must:
1. Provide a brief, high-level explanation of `woostack` as an agent- and model-agnostic collection of software development skills with a local memory system designed for small-to-medium teams.
2. Outline the installation process using `pnpx` and explicitly state that `/woostack-init` must be run before using any other skills, along with a brief explanation of `.woostack/config.json`.
3. Layout the Core Development and Review Loop, highlighting the Iron Law: "No code should be written without `/woostack-bootstrap`, `/woostack-build`, or `/woostack-fix`."
4. Detail the local memory system (`.woostack/memory/`), including scope-routing and Obsidian compatibility, while omitting the deprecated flat shard (`memory.md`).

## 3. Non-goals

- Adding details of other internal scripts, deprecated components, or developer workflows not relevant to repository adoption.
- Changing any package source code or adding new script behaviors in this PR.

## 4. Approach

We will draft a replacement for `README.md` containing the following sections:
- **Title and High-Level Pitch**: Standard project intro.
- **Getting Started (Install & Init)**:
  - Run `pnpx skills add howarewoo/woostack`.
  - Run `/woostack-init` in the project root (mandatory first step).
  - Add `using-woostack` adoption block to `AGENTS.md` (or `CLAUDE.md`).
  - Explain `.woostack/config.json` showing a minimal copy-pasteable example:
    ```json
    {
      "review": {
        "severity_floor": "medium",
        "ignore": ["**/*.generated.ts"]
      }
    }
    ```
- **The Development & Review Loop**:
  - Code changes: Greenfield (`/woostack-bootstrap`), Features (`/woostack-build`), Fixes (`/woostack-fix`).
  - *Iron Law*: No code should be written without one of these three.
  - Verification: `/woostack-review` (parallel swarm, prosecutor/defender validator), `/woostack-address-comments` (unresolved feedback iterator).
- **The Local Memory System**:
  - Scoped markdown files under `.woostack/memory/`.
  - Context routing: how `scope` glob matching selects relevant memory context.
  - Obsidian vault support, detailing that `/woostack-init --obsidian` scaffolds Obsidian configuration.

## 5. Components & data flow

*N/A — Documentation-only change.*

## 6. Error handling

*N/A — Documentation-only change.*

## 7. Acceptance criteria

Each AC represents a testable behavior/state of the newly written README.md:

- **AC1 — Complete Content Match**
  - happy: The rewritten README contains all four required sections (Overview, Install/Init/Config, Core Dev/Review loop, Memory system).
  - edge: Check that no reference to the deprecated `memory.md` flat shard exists in the new text.
- **AC2 — Installation and Order of Operations**
  - happy: README specifies `pnpx skills add` and clearly instructs the developer to run `/woostack-init` before any other commands.
- **AC3 — Gated Coding Rule**
  - happy: README prominently features a warning block stating no code should be written without `bootstrap`, `build`, or `fix`.
- **AC4 — Command Links**
  - happy: References to skill files (e.g. `skills/woostack-init/SKILL.md`) use clickable relative file links.

## 8. Testing

- Manual review of the rendered Markdown structure.
- Verification of all relative links inside the rewritten README.

## 9. Open questions

- **How to document the config file?** Decided: include a minimal realistic copy-pasteable example of `.woostack/config.json`.
- **How to document the Obsidian vault setup?** Decided: explicitly mention the `/woostack-init --obsidian` flag.

