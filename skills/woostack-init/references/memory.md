# Scope-Routed Memory Contract

This document is the canonical reference for the `.woostack/memory/` store. Every woostack skill that reads or writes memory notes should point here rather than restating the schema.

---

## 1. Purpose

The `.woostack/memory/` directory is the single memory surface. It contains **scoped per-fact
notes** whose `scope:` field declares which parts of the codebase they govern. Memory and the
sibling wisdom store are reusable, non-authoritative knowledge: neither can define scope,
assignment, lifecycle, progress, approval, or acceptance. Those development facts come from the
verified Linear project or issue; Git and GitHub remain authoritative for code and PR evidence.

When a skill loads context for a working set of files it consults the derived index, matches notes
whose scope overlaps the working set, and loads only those note bodies plus bounded related notes.
This makes recall sub-linear in the total number of accumulated notes: on a repo with 500 notes
only the handful relevant to the changed files are loaded, not the full corpus.

---

## 2. Layout

The `/woostack-init` scaffold verb creates this non-authoritative local workspace in a consumer
repository:

```
.woostack/
├── memory/
│   ├── MEMORY.md    derived index (build-index writes it)
│   └── .gitkeep
├── wisdom/          generalized findings, wholesale-loaded — see wisdom.md (sibling store)
├── respond/
│   ├── .gitkeep     tracked sanitized response reports live beside it
│   └── evidence/    ignored transient provider evidence; created per run
├── worktrees/       ignored per-PR Git worktrees
├── config.json      committed non-secret Linear and tool policy
├── config.local.json ignored primary-checkout override for linear.team only
└── .gitignore       ignores local overrides, transient evidence, worktrees, and sidecars
```

`config.json` ships exactly five top-level policy namespaces: `linear`, `models`, `review`,
`respond`, and `status`. `linear` holds the canonical repository, workspace, optional default team,
native project-status mappings, and issue-state mappings. The other four namespaces hold
non-secret model, review, response, and status policy. The selected clone-local team lives only in
`config.local.json`, resolved from the primary checkout for linked worktrees. Provider credentials
and development records never belong in either file.

The `.gitignore` ignores `config.local.json` through `*.local.*`, `metrics.json`,
`respond/evidence/`, worktrees, memory telemetry, and the dream watermark. Shared memory and
wisdom, their derived index, and committed policy may be tracked, but all remain
non-authoritative. Sanitized response reports remain tracked. All sanitized diagnostic reports remain non-authoritative.

`/woostack-init` does not create `.woostack/specs/`, `.woostack/plans/`, or `.woostack/fixes/`. Existing local Markdown development records
are historical migration input only: leave them untouched for doctor to report, and never use them
as current provenance or authority.

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
source: linear://issue/22222222-2222-4222-8222-222222222222
---
oRPC ORPCError maps to TanStack retry policy: throw typed,
let [[tanstack-query-retries]] decide. Terse body.
```

The body follows the canonical memory-note-body discipline: see [`output-discipline.md`](../../using-woostack/references/output-discipline.md#memory-note-bodies).

### Fields

**Format rule:** one `key: value` per line; comma-separated lists for multi-value fields (NOT YAML block sequences) so `grep '^scope:' | cut` parses them in bash without any YAML library.

| Field | Required | Description |
|---|---|---|
| `name` | yes | Unique slug identifying this note. Used in wikilinks and as the index anchor. |
| `type` | yes | See enum below. |
| body | yes | Non-empty content after the closing `---` fence. |
| `scope` | no | Comma-separated glob list; omitted or `*` means global (see §5). |
| `hook` | no | One-line index summary. If absent, the index falls back to the first non-empty body line, truncated to ~80 characters. |
| `tags` | no | Comma list; a **load-bearing recall axis** — a one-hop tag expansion loads notes sharing ≥1 tag (trimmed, case-insensitive) with the scope-matched set (see §6). Format unchanged. |
| `updated` | no | ISO date the note's content was last written. Informational, **and** the age basis for `doctor.sh`'s dead-note check (see §8) — a note without it cannot be aged. |
| `source` | no | Stable provenance. New development notes use the most specific `linear://project/<uuid>` or `linear://issue/<uuid>` identity; review-recorded notes use raw `pr-<n>` or `address-comments`. New notes never use a Linear document, title, slug, issue key alone, local development path, or Markdown artifact. Static doctor validates shape; explicit authenticated live doctor verifies Linear ownership through the current host's official Linear MCP receipt. Historical Markdown source values are migration input only. |
Recall telemetry lives in a tool-managed, gitignored `.woostack/memory/.telemetry.tsv` sidecar with rows `name<TAB>recall_count<TAB>last_recalled`. `recall.sh` writes it, and `doctor.sh` reads it for the dead-note check (see §8). Stray `recall_count` or `last_recalled` copies in note frontmatter are inert and should be removed.

**Caution:** hook or body text containing a backtick can render as ambiguous Markdown in the derived index line; keep hooks plain text.

### `type` enum

Valid values: `decision`, `pattern`, `gotcha`, `convention`, `hotspot`.

`spec` and `plan` are legacy, recall-excluded values. Woostack does not create local specification
or plan records; existing historical files are migration input, never active memory or development
authority.

`wisdom` is likewise **reserved and recall-excluded**: wisdom files live in the sibling
`.woostack/wisdom/` store (not `.woostack/memory/`), so they are never indexed or scope-recalled.
The wisdom store has its own contract — see [`wisdom.md`](wisdom.md).

### Links

Note-to-note links live in the **body only**, written as `[[name]]` wikilinks. There is no `links:` frontmatter field for note-to-note links. The `source:` field is provenance, not a note edge: new development provenance is a stable `linear://project/<uuid>` or `linear://issue/<uuid>` URI, while review provenance is `pr-<n>` or `address-comments`. Body wikilinks remain the single source of truth for the note graph and are bash-greppable (`grep -oE '\[\[[^]]+\]\]'`). Doctor verifies Linear provenance only from an explicit authenticated official-MCP receipt and leaves recall's one-hop body-link expansion unchanged. Historical Markdown source links may be read for migration but must not be authored as current provenance.

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

    - [name → linked to name.md] `type` scope=`scope-globs` — hook-or-first-body-line

For the `orpc-error-mapping` example note: name=`orpc-error-mapping`, type=`pattern`, scope=`packages/api/**, packages/api/orpc/**`, hook=`oRPC error → TanStack retry policy`.

Lines are sorted by `type` then `name` for stable diffs. When a note has multiple `scope` globs, the full comma-separated list is shown in the index line. The trailing summary uses the `hook:` field when present; otherwise it is the first non-empty body line.

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
5. **One-hop tag expand:** build the query tag-set as the union of `tags:` across the notes loaded in step 3 (scope-matched only — not globals, not the wikilinked notes from step 4). For each not-yet-loaded, non-global note whose `tags:` share ≥1 token (whitespace-trimmed, case-insensitive) with that set, load its body. This is a second one-hop expansion edge beside step 4; tag-loaded notes are never themselves an expansion source. They rank **below** wikilinked notes and are **dropped first** under `RECALL_CAP` (a broad tag can never evict a scoped, linked, or global note). Recall renders them in a dedicated `## Tag-related notes` section, after `## Linked notes` and before `## Global memory`.
6. **Stop.** Notes not matched in steps 3–5 are never loaded.

`recall.sh` — which orchestrates steps 2–5 — is the increment-B deliverable. It ships alongside its first consumer (the woostack-review migration) in increment B. **Increment A ships only the `scope-match.sh` primitive** (step 3's core) plus this documented procedure. Any consuming skill that wants to implement recall before increment B lands should follow this procedure manually, using `scope-match.sh` for step 3.

---

## 7. Distillation (write path)

Scoped notes are created by two write paths: **distillation** and accept-by-design review memory.
Distillation runs through `woostack-execute` after an implemented Linear issue task or increment.
Durable learnings from the verified issue contract and implementation are written as `memory/`
notes with:

- `type` — `pattern | decision | gotcha | convention`.
- `scope` — the narrowest glob covering the issue's touched files.
- `source` — the most specific stable `linear://project/<uuid>` or `linear://issue/<uuid>`
  identity, or the review marker the learning came from.
- body — terse; `[[wikilinks]]` to related notes.

**Reject-by-default gate.** Before writing any note, it must pass every check — fewer, denser notes
beat many thin ones:

1. **Cross-feature test** — if `scope:` is a single literal file/path (no glob), reject as trivia.
   Scope must be a glob that could plausibly fire on a *different* feature's files.
2. **Provenance required** — no `source:`, no note. New development notes use the most specific
   stable `linear://project/<uuid>` or `linear://issue/<uuid>` identity. Review-recorded notes use
   raw `pr-<n>` or `address-comments`. A Linear document, title, slug, issue key alone, mutable
   local path, or Markdown artifact is not new provenance; legacy Markdown values are accepted only
   as historical migration input.
3. **Dedupe (strengthened)** — exact-name match against `MEMORY.md` **plus** a fuzzy compare of the
   candidate `hook:` against existing hooks to catch near-duplicates phrased differently; update
   the existing note rather than adding. (This compare is agent judgment; store-level collision
   surfacing is tracked separately in conflict detection.)
4. **Stamp `updated:`** — every created or updated note gets today's ISO date, so the dead-note
   check (§8) can age it.

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
| `doctor.sh` | `bash doctor.sh [--live-receipt <path>] [<repository-root>]` — lints the repository's `.woostack/` workspace; warnings exit 0, errors exit 1. Also emits the staleness warnings described below. |
| `recall.sh` | `bash recall.sh <woostack_dir> <paths_file>` — composes the per-PR memory context (see §6) and **stamps recall telemetry** on every selected note. |
| `graph.sh` | `bash graph.sh <memdir> <note> [--links\|--backlinks]` — lists a note's outbound wikilinks (`--links`, default) or the notes that link to it (`--backlinks`). Grep-based by default; see §9 for the opt-in Obsidian path. |

`build-index.sh`, `doctor.sh`, and `recall.sh` source `lib.sh` (frontmatter helpers `field()`, `note_body()`, `first_body_line()`; the atomic frontmatter mutator `set_field()`; and the date helpers `_woo_now()`/`_woo_epoch()`) from the same directory. `doctor.sh` additionally invokes `scope-match.sh` as a subprocess for its stale-scope check. `scope-match.sh` and `graph.sh` are self-contained — they source nothing.

**Staleness warnings.** `doctor.sh` emits warning-only findings for cheap structural staleness signals:

- **Orphaned scope:** a note with a non-global `scope:` whose globs match no tracked files in `git ls-files` is flagged as stale. This catches notes scoped to paths that were deleted or moved.
- **Stale provenance:** New development provenance must be an exact `linear://project/<uuid>` or `linear://issue/<uuid>` URI (UUID case is canonicalized without changing identity); nested segments and Linear document URIs are rejected. Static doctor validates URI shape locally without credentials or provider calls. Only an explicit `--live-receipt <path>` consumes temporary, non-secret evidence produced through the current host's authenticated official Linear MCP connection; it verifies existence, canonical repository/project ownership, managed metadata/schema, and native relation agreement. Historical Markdown provenance — `[[specs/<basename>]]`, `[[plans/<basename>]]`, `[[fixes/<basename>]]`, or the `.woostack/specs|plans|fixes/<file>.md` path — is migration input only: doctor may parse it to report staleness, but no writer may create or treat it as current provenance. A failed live check is an error, and doctor never falls back to a legacy adapter.
- **Dead note:** `recall.sh` stamps the sidecar (§3) for every selected note — matched + one-hop linked + global — as a best-effort side effect: a write failure (e.g. a read-only checkout) logs `recall: stamp failed <note>` to stderr but never changes recall's output or exit status. Ephemeral CI clones therefore simply do not accrue telemetry; persistent checkouts do. `doctor.sh` joins the sidecar by note `name` and turns that signal into a warning when a note's `updated:` date is older than `WOOSTACK_DEAD_DAYS` (default 90) days and its sidecar `recall_count` is absent or 0. `WOOSTACK_NOW` (default `date +%F`) overrides "today" for deterministic runs and tests.
- **Missing provenance:** a note with no `source:` is flagged — the distillation gate (§7) requires provenance on every note.
- **Non-glob scope:** a note whose `scope:` is non-global and contains no `*` glob (a single literal path, or an all-literal comma list) is flagged as possible trivia. Notes with global scope (`*` or absent) and review-recorded notes (`source:` of `pr-<n>` or `address-comments`, which deliberately scope narrowly) are exempt.
- **Missing age basis:** a note with no `updated:` field is flagged — it cannot be aged by the dead-note check above, so it is no longer silently skipped. (Both write paths stamp `updated:`; a note without it is anomalous.)
- **Overlap cluster:** non-global notes whose `scope:` globs match at least one common tracked file are grouped into a cluster and flagged for human review (`overlap cluster: a.md, b.md — intersecting scope, review for contradiction`). doctor cannot judge whether the advice actually contradicts — it surfaces the co-load so a human can. Global notes (`*`/absent) co-load with everything by design and are exempt; a note whose scope matches no tracked file is stale, not clustered. Overlap is measured by shared tracked files (via `scope-match.sh`), so it is skipped when there is no git repo.

`doctor.sh` also warns on unresolved body `[[wikilinks]]`; those are graph integrity warnings rather than staleness signals.

---

## 9. Obsidian (optional)

The `.woostack/` vault is already Obsidian-compatible: memory and wisdom notes are Markdown files
and body links are `[[wikilinks]]` that Obsidian resolves natively. Linear remains development
authority; the vault contains no active local spec, plan, or fix store. The `.obsidian/` config
directory must be present for Obsidian to recognise the folder as a vault.

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
