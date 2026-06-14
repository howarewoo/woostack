---
name: memory-obsidian
type: spec
status: done
date: 2026-06-02
branch: feat/woostack-memory-obsidian
increment: D of 4
---

# Obsidian layer — Design Spec

> **Plan:** [[plans/2026-06-02-memory-obsidian]]

> Increment D of 4 (final). Stacks on C ([[memory-distill]]). The optional Obsidian layer over the memory vault. Hard reality: `obsidian eval` needs the desktop app running, so it is **never a dependency** — the grep-wikilink path (already in `recall.sh`/`doctor.sh`) stays the headless workhorse. This increment adds opt-in vault config + an optional graph helper that falls back to grep.

## 1. Problem

The `.woostack/memory/` store is already an Obsidian-compatible vault (markdown + `[[wikilinks]]`), but nothing helps a user actually open it as one, and there is no convenience for graph queries (links/backlinks) beyond reading raw markdown. The earlier increments deliberately kept everything headless/pure-bash; Obsidian is a human convenience that must remain strictly optional and never block CI or headless agents.

## 2. Goal

- **Vault config:** `/woostack-init` can scaffold a minimal `.obsidian/` config so `.woostack/` opens as an Obsidian vault (memory + specs + plans as graph nodes).
- **Graph helper:** ship `graph.sh` — query a note's links / backlinks. Uses `obsidian eval` when the CLI + app are available; otherwise falls back to grep over the markdown (the default, always-works path).
- **Document** the optional Obsidian workflow in the contract.

## 3. Non-goals

- **Obsidian is never required.** `recall.sh` and `doctor.sh` are unchanged — they keep using grep-wikilink and never call Obsidian. No CI/headless path depends on the app.
- No change to A/B/C behavior.
- No sync, no plugins beyond a stock config, no `.obsidian/` for the whole repo (vault root is `.woostack/` only).

## 4. Approach

### Opt-in vault config

`/woostack-init` gains `--obsidian` / `--no-obsidian` flags; with neither, it **prompts** (consistent with its prompt-on-conflict default). When enabled, it scaffolds `.woostack/.obsidian/` from a template (a minimal stock config: app.json, graph.json) so opening `.woostack/` in Obsidian shows the memory/specs/plans graph. The `.gitignore` template keeps `.obsidian/workspace*` (per-user UI state) out of git while tracking the shared config.

### Graph helper with fallback

`graph.sh <memdir> <note> --links|--backlinks`:
- **Default (grep):** `--links` greps the note body for `[[name]]`; `--backlinks` greps `<memdir>/*.md` for `[[<note>]]`. Pure bash, headless, tested.
- **Obsidian branch (opt-in, best-effort):** when `WOOSTACK_OBSIDIAN=1` AND `command -v obsidian` succeeds, attempt `obsidian eval` against `app.metadataCache` for resolved links/backlinks (richer: handles aliases). On ANY failure (no app running, eval error) → fall back to grep + a stderr warning. Never fatal.

The helper is a standalone convenience — `recall.sh`'s one-hop expansion does NOT call it (recall stays deterministic/headless).

### Documentation

Contract gains an "Obsidian (optional)" section: the vault is already compatible; how to enable `.obsidian/`; `graph.sh` usage; the explicit guarantee that all core tooling works without Obsidian.

## 5. Components

- `skills/woostack-init/templates/obsidian/app.json`, `graph.json` — minimal stock config (vault rooted at `.woostack/`).
- `skills/woostack-init/scripts/graph.sh` — links/backlinks helper (grep default + obsidian-eval opt-in fallback).
- `skills/woostack-init/scripts/tests/test-graph.sh` — covers the grep paths (links, backlinks, no-match, note-not-found). The obsidian-eval branch is not unit-tested (needs a GUI app); it is guarded and documented as best-effort.
- `skills/woostack-init/SKILL.md` — `--obsidian`/`--no-obsidian` flags + the prompt; the `.obsidian/` scaffold step; note Obsidian is optional.
- `skills/woostack-init/templates/gitignore` — add `.obsidian/workspace*` (per-user UI state).
- `skills/woostack-init/references/memory.md` — "Obsidian (optional)" section.
- `AGENTS.md` — templates list mentions the obsidian template.

## 6. Error handling

- `graph.sh` obsidian branch: any failure → grep fallback + stderr warning; exit reflects the grep result, never the obsidian failure.
- Enabling `.obsidian/` never clobbers an existing one (init's never-clobber rule applies).
- `graph.sh` on a missing note → clear error, exit 1; no match → empty output, exit 0.

## 7. Testing

- `test-graph.sh` (bash asserts): `--links` lists a note's `[[targets]]`; `--backlinks` finds notes linking to it; note-not-found → exit 1; no links/backlinks → empty + exit 0; the obsidian branch is skipped when `obsidian` CLI is absent (grep used) — assert grep path runs under default env.
- woostack-init suite stays green.
- Manual: `/woostack-init --obsidian` in a temp repo scaffolds `.woostack/.obsidian/`; opening in Obsidian shows the graph (manual, not automated).
- Cross-links resolve; `.gitignore` template ignores `.obsidian/workspace*` only.

## 8. Open questions

- **obsidian eval JS payload** — the exact `app.metadataCache.resolvedLinks` / `getBacklinksForFile()` snippet may vary by Obsidian version; keep it minimal and treat any failure as "fall back to grep." Not load-bearing.
- **Config minimalism** — ship the smallest `app.json`/`graph.json` that makes a usable vault; avoid pinning plugin/theme choices.
