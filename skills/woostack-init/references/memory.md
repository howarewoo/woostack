# Scope-Routed Memory Contract

This document is the canonical reference for the `.woostack/memory/` store. Every woostack skill that reads or writes memory notes should point here rather than restating the schema.

---

## 1. Purpose

The scope-routed memory store is an additive layer on top of the flat `.woostack/memory.md` global shard. The flat file remains valid: it is always loaded in full, written by `memory-append.sh`, and its free-form bullet content is never touched by any tooling described here. The new `.woostack/memory/` directory adds **scoped per-fact notes** — individual Markdown files whose `scope:` field declares which parts of the codebase they govern. When a skill loads context for a working set of files it consults the derived index, matches notes whose scope overlaps the working set, and loads only those note bodies plus any directly linked notes. This makes recall sub-linear in the total number of accumulated notes: on a repo with 500 notes only the handful relevant to the changed files are loaded, not the full corpus. The flat file and the directory coexist; either alone is valid.

---

## 2. Layout

The `/woostack-init` scaffold verb creates this tree in a consumer repo:

```
.woostack/
├── memory.md        flat global shard — seeded empty if absent, NEVER clobbered
├── memory/
│   ├── MEMORY.md    derived index (build-index writes it)
│   └── .gitkeep
├── specs/           woostack-build markdown specs (type: spec)
├── plans/           woostack-build markdown plans
├── config.json      { "review": {} } skeleton
└── .gitignore       ignores metrics.json + *.local.* ; tracks memory/specs/plans/config
```

The `config.json` file uses a top-level namespace-per-tool convention: `"review"` is the key for woostack-review settings (see [../../woostack-review/SKILL.md](../../woostack-review/SKILL.md) for the schema of that namespace). The memory store needs no config in increment A. Future tools add sibling keys (`"memory"`, etc.) as needed; init scaffolds only the `{ "review": {} }` skeleton and documents the convention — it does not own the per-tool schemas.

The `.gitignore` ignores `metrics.json` (the review engine's per-clone rolling aggregate) and `*.local.*` (reserved for per-developer overrides such as `config.local.json`). Everything else — `memory.md`, `memory/`, `specs/`, `plans/`, `config.json` — is shared team knowledge and is tracked.

---

## 3. Note Format

A memory note is a Markdown file under `.woostack/memory/` with a line-oriented frontmatter block.

```
---
name: orpc-error-mapping
type: pattern
scope: packages/api/**, packages/api/orpc/**
tags: orpc, errors
hook: oRPC error → TanStack retry policy
updated: 2026-06-02
source:
---
oRPC ORPCError maps to TanStack retry policy: throw typed,
let [[tanstack-query-retries]] decide. Terse body.
```

### Fields

**Format rule:** one `key: value` per line; comma-separated lists for multi-value fields (NOT YAML block sequences) so `grep '^scope:' | cut` parses them in bash without any YAML library.

| Field | Required | Description |
|---|---|---|
| `name` | yes | Unique slug identifying this note. Used in wikilinks and as the index anchor. |
| `type` | yes | See enum below. |
| body | yes | Non-empty content after the closing `---` fence. |
| `scope` | no | Comma-separated glob list; omitted or `*` means global (see §5). |
| `hook` | no | One-line index summary. If absent, the index falls back to the first non-empty body line, truncated to ~80 characters. |
| `tags` | no | Comma list; informational only in increment A. |
| `updated` | no | ISO date; informational. |
| `source` | no | Provenance path (used by the increment-C distill step; empty in A). |

**Caution:** hook or body text containing a backtick can render as ambiguous Markdown in the derived index line; keep hooks plain text.

### `type` enum

Valid values: `decision`, `pattern`, `gotcha`, `convention`, `hotspot`.

`spec` and `plan` are reserved for specs and plans authored under `.woostack/specs/` and `.woostack/plans/` respectively. They are **excluded from recall routing** — the recall procedure never loads note bodies whose type is `spec` or `plan`.

### Links

Links live in the **body only**, written as `[[name]]` wikilinks. There is no `links:` frontmatter field. Body wikilinks are the single source of truth: they are native to Obsidian's graph (which reads them from the body) and bash-greppable (`grep -oE '\[\[[^]]+\]\]'`). The `doctor.sh` unresolved-link check and recall's one-hop expand both parse the body this way.

---

## 4. Glob→Match Semantics

These semantics are pinned in increment A and implemented by `scope-match.sh`. Any other tool or script matching `scope` globs must use the same semantics.

| Glob token | Meaning | ERE equivalent |
|---|---|---|
| `*` | One path segment (no `/` allowed) | `[^/]*` |
| `**` | Any depth, including `/` | `.*` |
| Exact text | Literal match (`.` is a literal dot, not any-char) | Escaped (`\.`) |
| `a, b` (comma list) | Matches if **any** alternative matches | Each glob compiled to ERE, joined with `\|` |

Matching is performed against **repo-relative paths**, anchored to the full path (i.e., `^<ERE>$`). A `scope` field that is omitted or set to `*` is global — it matches everything and the note is always loaded.

Example: `scope: packages/api/**, apps/*/utils.ts` compiles to `^packages/api/.*$|^apps/[^/]*/utils\.ts$` and matches `packages/api/orpc/handler.ts` and `apps/web/utils.ts` but not `apps/web/deep/utils.ts`.

---

## 5. Derived Index

`MEMORY.md` is the derived index of all notes in `.woostack/memory/`. It is regenerated by `build-index.sh` and **must never be hand-edited**. Each note produces exactly one line:

Each line has the form (using `→` to denote field substitution):

    - [name → linked to name.md] `type` scope=`first-scope-glob` — hook-or-first-body-line

For the `orpc-error-mapping` example note: name=`orpc-error-mapping`, type=`pattern`, first scope=`packages/api/**`, hook=`oRPC error → TanStack retry policy`.

Lines are sorted by `type` then `name` for stable diffs. When a note has multiple `scope` globs, the first glob is shown in the index line (the full list lives in the note frontmatter). The trailing summary uses the `hook:` field when present; otherwise it is the first non-empty body line, truncated.

The file also carries a generated-file header comment so tooling can detect it:

```
<!-- generated by build-index.sh — do not edit by hand -->
```

---

## 6. Recall Procedure

The recall procedure is the algorithm a skill follows to load only the memory notes relevant to a given working set of paths. The full procedure is:

1. **Always load** `memory/MEMORY.md` (one cheap line per note) and the flat `memory.md` global shard. Both are always present.
2. **Compute the working set** of repo-relative paths for the current operation. This is skill-specific: for a review it is the changed files; for a build it is the planned/touched files; for address-comments it is the files touched by the PR.
3. **Scope-match:** for each note listed in the index, evaluate the note's `scope` glob against the working-set paths using `scope-match.sh`. Load the full body of any note that matches.
4. **One-hop link expand:** for each note loaded in step 3, scan its body for `[[wikilinks]]`. Load the bodies of any directly linked notes that were not already loaded. Do not recurse further — expansion is bounded to exactly one hop.
5. **Stop.** Notes not matched in steps 3–4 are never loaded.

`recall.sh` — which orchestrates steps 2–4 — is the increment-B deliverable. It ships alongside its first consumer (the woostack-review migration) in increment B. **Increment A ships only the `scope-match.sh` primitive** (step 3's core) plus this documented procedure. Any consuming skill that wants to implement recall before increment B lands should follow this procedure manually, using `scope-match.sh` for step 3.

---

## 7. Distillation (write path)

Beyond the manual / `memory-append.sh` flat-file writes, the primary way scoped notes are
created is **distillation**: at the end of a `woostack-build` cycle, durable learnings from
the spec/plan/implementation are written as `memory/` notes with:

- `type` — `pattern | decision | gotcha | convention`.
- `scope` — the narrowest glob covering the feature's touched files.
- `source` — the spec or plan path the learning came from (provenance back to the full "why").
- body — terse; `[[wikilinks]]` to related notes.

Distillation **dedupes against `MEMORY.md` first** (update an existing note rather than adding
a duplicate) and runs `build-index.sh` + `doctor.sh` afterward. Only cross-feature knowledge
is distilled — not feature-specific trivia. This is distinct from the accept-by-design write
path (`memory-append.sh` → flat `memory.md`), which suppresses review noise; both coexist
under the additive-superset model.

## 8. Scripts

The scripts live under `skills/woostack-init/scripts/` relative to the woostack repo root. In a consumer repo they are invoked via the path resolved by the agent when the woostack-init skill is available.

| Script | Usage |
|---|---|
| `scope-match.sh` | `printf '%s\n' <paths> \| bash scope-match.sh '<glob-spec>'` — prints matching paths from stdin; exits 0 if any matched, 1 if none. |
| `build-index.sh` | `bash build-index.sh [<memdir>]` — regenerates `<memdir>/MEMORY.md` from note frontmatter; defaults to `.woostack/memory`. |
| `doctor.sh` | `bash doctor.sh [<memdir>]` — lints the memory directory; warnings exit 0, errors exit 1. |
| `graph.sh` | `bash graph.sh <memdir> <note> [--links\|--backlinks]` — lists a note's outbound wikilinks (`--links`, default) or the notes that link to it (`--backlinks`). Grep-based by default; see §9 for the opt-in Obsidian path. |

`build-index.sh` and `doctor.sh` source `lib.sh` (frontmatter helpers `field()`, `note_body()`, `first_body_line()`) from the same directory. `doctor.sh` additionally invokes `scope-match.sh` as a subprocess for its stale-scope check. `scope-match.sh` is self-contained — it sources nothing.

---

## 9. Obsidian (optional)

The `.woostack/` vault is already Obsidian-compatible: every memory note,
spec, and plan is a Markdown file and all links are `[[wikilinks]]` that
Obsidian resolves natively. No extra setup is needed to open the vault — but
the `.obsidian/` config directory must be present for Obsidian to recognise
the folder as a vault.

**Scaffolding.** `/woostack-init --obsidian` (or accepting the interactive
prompt) copies `templates/obsidian/` into `.woostack/.obsidian/`. The
template ships a minimal stock config (`app.json`, `graph.json`) that keeps
link format shortest and shows orphan nodes. An existing `.woostack/.obsidian/`
directory is never clobbered. The `.woostack/.gitignore` keeps per-user UI
state (`.obsidian/workspace*`, `.obsidian/cache`) out of git while tracking
the shared config.

**Graph queries.** `graph.sh <memdir> <note> --links|--backlinks` queries the
link graph:

- **Default (grep, always-works):** `--links` scans the note body for
  `[[target]]` wikilinks; `--backlinks` greps `<memdir>/*.md` for references
  to the named note. Pure bash, no app required.
- **Obsidian branch (opt-in, best-effort):** when `WOOSTACK_OBSIDIAN=1` and
  `command -v obsidian` succeeds, the script attempts `obsidian eval` against
  `app.metadataCache` for richer alias-aware resolution. On any failure it
  falls back to grep and emits a warning on stderr. This branch is never fatal.

**All core tooling works without Obsidian.** `recall.sh`, `doctor.sh`, and
`build-index.sh` use only grep-based wikilink parsing and are unaffected by
whether Obsidian is installed or the `.obsidian/` directory exists. Headless
CI always takes the grep path.

---

## 10. Degradation

When a consuming skill is installed individually (not as part of the full woostack collection), the scripts under `skills/woostack-init/scripts/` may not be available. In that case the skill should:

1. State explicitly in its output that the woostack-init scripts were not found and it is falling back to the manual procedure.
2. Follow the recall procedure in §6 manually: load the index and flat `memory.md`, then for each note whose `scope` overlaps the working-set paths (using substring or glob matching available in the agent's environment), load that note body and perform a single link-expand pass.
3. Do not fail silently — always indicate whether recall was script-assisted or manual.

The full-collection install (via `npx skills add howarewoo/woostack`) is the supported path and will always provide these scripts.
