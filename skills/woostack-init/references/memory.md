# Scope-Routed Memory Contract

This document is the canonical reference for the `.woostack/memory/` store. Every woostack skill that reads or writes memory notes should point here rather than restating the schema.

---

## 1. Purpose

The scope-routed memory store is an additive layer on top of the flat `.woostack/memory.md` global shard. The flat file remains valid: it is always loaded in full and remains the legacy/global fallback for repos without a scoped store. The new `.woostack/memory/` directory adds **scoped per-fact notes** — individual Markdown files whose `scope:` field declares which parts of the codebase they govern. When a skill loads context for a working set of files it consults the derived index, matches notes whose scope overlaps the working set, and loads only those note bodies plus any directly linked notes. This makes recall sub-linear in the total number of accumulated notes: on a repo with 500 notes only the handful relevant to the changed files are loaded, not the full corpus. The flat file and the directory coexist; either alone is valid.

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
| `updated` | no | ISO date the note's content was last written. Informational, **and** the age basis for `doctor.sh`'s dead-note check (see §8) — a note without it cannot be aged. |
| `source` | no | Provenance path (used by the increment-C distill step; empty in A). |
| `recall_count` | no | **Tool-managed.** Cumulative count of recall runs that loaded this note, written by `recall.sh`. Never hand-edit. Absent ⇒ never recalled. |
| `last_recalled` | no | **Tool-managed.** ISO date of the most recent recall load, written by `recall.sh`. Never hand-edit. |

`recall_count` and `last_recalled` are **written by tooling, not by hand** — `recall.sh` stamps them (best-effort) on every note it loads. They are the recall-telemetry signal feeding `doctor.sh`'s dead-note check (see §8).

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

Scoped notes are created by two write paths: **distillation** and accept-by-design
review memory. Distillation runs at the end of a `woostack-build` cycle; durable
learnings from the spec/plan/implementation are written as `memory/` notes with:

- `type` — `pattern | decision | gotcha | convention`.
- `scope` — the narrowest glob covering the feature's touched files.
- `source` — the spec or plan path the learning came from (provenance back to the full "why").
- body — terse; `[[wikilinks]]` to related notes.

Distillation **dedupes against `MEMORY.md` first** (update an existing note rather than adding
a duplicate) and runs `build-index.sh` + `doctor.sh` afterward. Only cross-feature knowledge
is distilled — not feature-specific trivia.

The accept-by-design review path uses `woostack-review/scripts/memory-record.sh`: when
`.woostack/memory/` exists it writes a scoped `convention` note with `source: pr-<n>`
and rebuilds `MEMORY.md`; when the scoped store is absent it falls back to the flat
`memory.md` bullet append path. Address-comments should pass the narrowest `scope`
covering the reviewed files so future reviews suppress the accepted issue only where
that convention applies.

## 8. Scripts

The scripts live under `skills/woostack-init/scripts/` relative to the woostack repo root. In a consumer repo they are invoked via the path resolved by the agent when the woostack-init skill is available.

| Script | Usage |
|---|---|
| `scope-match.sh` | `printf '%s\n' <paths> \| bash scope-match.sh '<glob-spec>'` — prints matching paths from stdin; exits 0 if any matched, 1 if none. |
| `build-index.sh` | `bash build-index.sh [<memdir>]` — regenerates `<memdir>/MEMORY.md` from note frontmatter; defaults to `.woostack/memory`. |
| `doctor.sh` | `bash doctor.sh [<memdir>]` — lints the memory directory; warnings exit 0, errors exit 1. Also emits the dead-note warning described below. |
| `recall.sh` | `bash recall.sh <woostack_dir> <paths_file>` — composes the per-PR memory context (see §6) and **stamps recall telemetry** on every selected note. |
| `graph.sh` | `bash graph.sh <memdir> <note> [--links\|--backlinks]` — lists a note's outbound wikilinks (`--links`, default) or the notes that link to it (`--backlinks`). Grep-based by default; see §9 for the opt-in Obsidian path. |

`build-index.sh`, `doctor.sh`, and `recall.sh` source `lib.sh` (frontmatter helpers `field()`, `note_body()`, `first_body_line()`; the atomic frontmatter mutator `set_field()`; and the date helpers `_woo_now()`/`_woo_epoch()`) from the same directory. `doctor.sh` additionally invokes `scope-match.sh` as a subprocess for its stale-scope check. `scope-match.sh` and `graph.sh` are self-contained — they source nothing.

**Recall telemetry & the dead-note check.** `recall.sh` stamps `recall_count`/`last_recalled` (§3) on every selected note — matched + one-hop linked + global — as a best-effort side effect: a write failure (e.g. a read-only checkout) logs `recall: stamp failed <note>` to stderr but never changes recall's output or exit status. Ephemeral CI clones therefore simply do not accrue telemetry; persistent checkouts do. `doctor.sh` turns that signal into a **dead-note warning** (exit 0): a note whose `updated:` date is older than `WOOSTACK_DEAD_DAYS` (default 90) days **and** whose `recall_count` is absent or 0 is flagged as a prune candidate. Notes without an `updated:` field have no age basis and are skipped. `WOOSTACK_NOW` (default `date +%F`) overrides "today" for deterministic runs and tests.

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
