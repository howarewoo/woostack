---
type: plan
source: .woostack/specs/2026-06-02-memory-distill.md
status: done
branch: feat/woostack-memory-distill
---

# Memory distill + skill wiring (Increment C) — Implementation Plan

> **For agentic workers:** Steps use checkbox (`- [ ]`) syntax. Docs-only increment — no new scripts; reuses A's `build-index`/`doctor` and B's `recall.sh`.

**Goal:** Wire the remaining three skills to the memory system — distill learnings back from the build loop, scaffold `.woostack/` from bootstrap, and document address-comments' inherited scope-routed memory.

**Architecture:** Agent-behavior + doc edits only. The build loop gains a post-execute distill step; bootstrap invokes `/woostack-init`; the memory contract documents the distill write-path.

**Source:** specs/2026-06-02-memory-distill.md (Increment C of 4; shipped in #156).

> Reconstructed after the fact: this increment shipped docs-only in PR #156 before plan-checkbox tracking existed. Tasks below mirror the spec's delivered scope and are checked to reflect the merged work.

## Tasks

- [x] Add a build-loop distill step (post-execute): extract durable learnings from spec+plan into scoped memory notes with `source:` provenance.
- [x] Rebuild the memory index and run the store linter after distillation.
- [x] Wire bootstrap to invoke `/woostack-init` so a fresh repo gets `.woostack/`.
- [x] Document that woostack-address-comments already inherits scope-routed memory via increment B (no behavior change).
- [x] Update the memory contract to describe the distill write-path.
