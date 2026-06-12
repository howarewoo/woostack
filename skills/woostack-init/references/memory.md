# Scope-Routed Memory Contract

This document is the canonical reference for the `.woostack/memory/` store. Every woostack skill that reads or writes memory notes should point here rather than restating the schema.

---

## 1. Purpose

The `.woostack/memory/` directory is the single memory surface. It contains **scoped per-fact notes** — individual Markdown files whose `scope:` field declares which parts of the codebase they govern. When a skill loads context for a working set of files it consults the derived index, matches notes whose scope overlaps the working set, and loads only those note bodies plus any directly linked notes. This makes recall sub-linear in the total number of accumulated notes: on a repo with 500 notes only the handful relevant to the changed files are loaded, not the full corpus.

---

## 2. Layout

The `/woostack-init` scaffold verb creates this tree in a consumer repo:

```
.woostack/
├── memory/
│   ├── MEMORY.md    derived index (build-index writes it)
│   └── .gitkeep
├── specs/           woostack-build markdown specs (type: spec)
├── plans/           woostack-build markdown plans
├── config.json      { "review": {} } skeleton
└── .gitignore       ignores metrics.json, *.local.*, memory/.telemetry.tsv, and memory/.dream-watermark ; tracks specs/plans/fixes/config/memory notes
```

The `config.json` file uses a top-level namespace-per-tool convention: `"review"` is the key for woostack-review settings (see [../../woostack-review/SKILL.md](../../woostack-review/SKILL.md) for the schema of that namespace). The memory store needs no config in increment A. Future tools add sibling keys (`"memory"`, etc.) as needed; init scaffolds only the `{ "review": {} }` skeleton and documents the convention — it does not own the per-tool schemas.

The `.gitignore` ignores `metrics.json` (the review engine's per-clone rolling aggregate), `*.local.*` (reserved for per-developer overrides such as `config.local.json`), `.woostack/memory/.telemetry.tsv`, and `.woostack/memory/.dream-watermark`. Memory notes and `MEMORY.md` are tracked shared team knowledge, alongside `specs/`, `plans/`, `fixes/`, and `config.json`.

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
Recall telemetry lives in a tool-managed, gitignored `.woostack/memory/.telemetry.tsv` sidecar with rows `name<TAB>recall_count<TAB>last_recalled`. `recall.sh` writes it, and `doctor.sh` reads it for the dead-note check (see §8). Stray `recall_count` or `last_recalled` copies in note frontmatter are inert and should be removed.

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

1. **Always load** `memory/MEMORY.md` (one cheap line per note).
2. **Compute the working set** of repo-relative paths for the current operation. This is skill-specific: for a review it is the changed files; for a build it is the planned/touched files; for address-comments it is the files touched by the PR.
3. **Scope-match:** for each note listed in the index, evaluate the note's `scope` glob against the working-set paths using `scope-match.sh`. Load the full body of any note that matches. When two matched notes have the **same** match-count, the tie is broken by `updated:` recency — the newer note ranks first, and a note without `updated:` ranks last (so under cap pressure the older / undated note is dropped first). Match-count remains the primary key.
4. **One-hop link expand:** for each note loaded in step 3, scan its body for `[[wikilinks]]`. Load the bodies of any directly linked notes that were not already loaded. Do not recurse further — expansion is bounded to exactly one hop.
5. **Stop.** Notes not matched in steps 3–4 are never loaded.

`recall.sh` — which orchestrates steps 2–4 — is the increment-B deliverable. It ships alongside its first consumer (the woostack-review migration) in increment B. **Increment A ships only the `scope-match.sh` primitive** (step 3's core) plus this documented procedure. Any consuming skill that wants to implement recall before increment B lands should follow this procedure manually, using `scope-match.sh` for step 3.

---

## 7. Distillation (write path)

Scoped notes are created by two write paths: **distillation** and accept-by-design
review memory. Distillation runs through `woostack-execute` after each implemented increment;
durable learnings from the spec/plan/implementation are written as `memory/` notes with:

- `type` — `pattern | decision | gotcha | convention`.
- `scope` — the narrowest glob covering the feature's touched files.
- `source` — the spec or plan path the learning came from (provenance back to the full "why").
- body — terse; `[[wikilinks]]` to related notes.

**Reject-by-default gate.** Before writing any note, it must pass every check — fewer, denser notes beat many thin ones:

1. **Cross-feature test** — if `scope:` is a single literal file/path (no glob), reject as trivia. Scope must be a glob that could plausibly fire on a *different* feature's files.
2. **Provenance required** — no `source:`, no note. Every durable learning traces back to a spec or plan.
3. **Dedupe (strengthened)** — exact-name match against `MEMORY.md` **plus** a fuzzy compare of the candidate `hook:` against existing hooks to catch near-duplicates phrased differently; update the existing note rather than adding. (This compare is agent judgment; store-level collision surfacing is tracked separately in conflict detection.)
4. **Stamp `updated:`** — every created or updated note gets today's ISO date, so the dead-note check (§8) can age it.

`doctor.sh` backstops items 1, 2, and 4 with warning-only checks (§8) — they catch escapes but never hard-block.

Distillation **dedupes against `MEMORY.md` first** (update an existing note rather than adding
a duplicate) and runs `build-index.sh` + `doctor.sh` afterward. Only cross-feature knowledge
is distilled — not feature-specific trivia.

The accept-by-design address-comments path uses
`woostack-address-comments/scripts/memory-record.sh`: when
`.woostack/memory/` exists it writes a scoped `convention` note with `source: pr-<n>`
and rebuilds `MEMORY.md`; when the scoped store is absent it skips the record and
defers to `/woostack-init`. Address-comments should pass the narrowest `scope`
covering the reviewed files so future reviews suppress the accepted issue only where
that convention applies.

## 8. Scripts

The scripts live under `skills/woostack-init/scripts/` relative to the woostack repo root. In a consumer repo they are invoked via the path resolved by the agent when the woostack-init skill is available.

| Script | Usage |
|---|---|
| `scope-match.sh` | `printf '%s\n' <paths> \| bash scope-match.sh '<glob-spec>'` — prints matching paths from stdin; exits 0 if any matched, 1 if none. |
| `build-index.sh` | `bash build-index.sh [<memdir>]` — regenerates `<memdir>/MEMORY.md` from note frontmatter; defaults to `.woostack/memory`. |
| `doctor.sh` | `bash doctor.sh [<memdir>]` — lints the memory directory; warnings exit 0, errors exit 1. Also emits the staleness warnings described below. |
| `recall.sh` | `bash recall.sh <woostack_dir> <paths_file>` — composes the per-PR memory context (see §6) and **stamps recall telemetry** on every selected note. |
| `graph.sh` | `bash graph.sh <memdir> <note> [--links\|--backlinks]` — lists a note's outbound wikilinks (`--links`, default) or the notes that link to it (`--backlinks`). Grep-based by default; see §9 for the opt-in Obsidian path. |

`build-index.sh`, `doctor.sh`, and `recall.sh` source `lib.sh` (frontmatter helpers `field()`, `note_body()`, `first_body_line()`; the atomic frontmatter mutator `set_field()`; and the date helpers `_woo_now()`/`_woo_epoch()`) from the same directory. `doctor.sh` additionally invokes `scope-match.sh` as a subprocess for its stale-scope check. `scope-match.sh` and `graph.sh` are self-contained — they source nothing.

**Staleness warnings.** `doctor.sh` emits warning-only findings for cheap structural staleness signals:

- **Orphaned scope:** a note with a non-global `scope:` whose globs match no tracked files in `git ls-files` is flagged as stale. This catches notes scoped to paths that were deleted or moved.
- **Stale provenance:** a note whose `source:` starts with `.woostack/specs/` or `.woostack/plans/` is expected to point at an authored spec or plan in the current repo. If that file is missing, the note is flagged for review. Other provenance forms, such as `source: pr-165`, are not treated as filesystem paths.
- **Dead note:** `recall.sh` stamps the sidecar (§3) for every selected note — matched + one-hop linked + global — as a best-effort side effect: a write failure (e.g. a read-only checkout) logs `recall: stamp failed <note>` to stderr but never changes recall's output or exit status. Ephemeral CI clones therefore simply do not accrue telemetry; persistent checkouts do. `doctor.sh` joins the sidecar by note `name` and turns that signal into a warning when a note's `updated:` date is older than `WOOSTACK_DEAD_DAYS` (default 90) days and its sidecar `recall_count` is absent or 0. `WOOSTACK_NOW` (default `date +%F`) overrides "today" for deterministic runs and tests.
- **Missing provenance:** a note with no `source:` is flagged — the distillation gate (§7) requires provenance on every note.
- **Non-glob scope:** a note whose `scope:` is non-global and contains no `*` glob (a single literal path, or an all-literal comma list) is flagged as possible trivia. Notes with global scope (`*` or absent) and review-recorded notes (`source:` of `pr-<n>` or `address-comments`, which deliberately scope narrowly) are exempt.
- **Missing age basis:** a note with no `updated:` field is flagged — it cannot be aged by the dead-note check above, so it is no longer silently skipped. (Both write paths stamp `updated:`; a note without it is anomalous.)
- **Overlap cluster:** non-global notes whose `scope:` globs match at least one common tracked file are grouped into a cluster and flagged for human review (`overlap cluster: a.md, b.md — intersecting scope, review for contradiction`). doctor cannot judge whether the advice actually contradicts — it surfaces the co-load so a human can. Global notes (`*`/absent) co-load with everything by design and are exempt; a note whose scope matches no tracked file is stale, not clustered. Overlap is measured by shared tracked files (via `scope-match.sh`), so it is skipped when there is no git repo.

`doctor.sh` also warns on unresolved body `[[wikilinks]]`; those are graph integrity warnings rather than staleness signals.

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
2. Follow the recall procedure in §6 manually: load the index, then for each note whose `scope` overlaps the working-set paths (using substring or glob matching available in the agent's environment), load that note body and perform a single link-expand pass. With no scoped store, recall yields an empty set and records are skipped.
3. Do not fail silently — always indicate whether recall was script-assisted or manual.

The full-collection install (via `npx skills add howarewoo/woostack`) is the supported path and will always provide these scripts.
