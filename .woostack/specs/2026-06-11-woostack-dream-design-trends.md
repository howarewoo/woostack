---
name: woostack-dream-design-trends
type: spec
status: planning
date: 2026-06-11
branch: feature/woostack-dream-design-trends
links:
---

# Shared Curated Memory + Design-Trend Consolidation in `woostack-dream` — Design Spec

> Visualize on demand: render this file with [spec-template.html](../../skills/woostack-build/references/spec-template.html) for a rich view, or hand it to `woostack-visualize` (audience `engineer`). Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../skills/woostack-status/references/conventions.md).

## 1. Problem

The originating ask: `woostack-dream` should look for **design trends in specs and plans** (not just review memories), consolidating learnings from **all development decisions** into a single durable, token-efficient recall surface.

Today `woostack-dream`'s `surface` op consolidates a recurring pattern into one memory note, but draws it **only from existing notes** — chiefly the per-increment learnings `woostack-execute` distilled and the `convention` notes `woostack-address-comments`/`woostack-review` recorded. The richest record of recurring *design decisions* lives in `.woostack/{specs,plans,fixes}/*.md`, which `woostack-dream` reads **only as provenance** (follow a note's `source:` into one artifact to judge that note's staleness) — never as a corpus to detect trends spanning many artifacts.

Pursuing that goal exposes a deeper blocker: **consolidated learnings live in a gitignored store.** `.woostack/memory/` is local-only by the memory contract, so every clone re-derives the same consolidation and a team never shares it. The learning's *source* (specs/plans/fixes) is tracked, but the consolidated, recall-shaped note is not. The only reason the store is gitignored is that notes carry **per-clone recall telemetry** (`recall_count`, `last_recalled`, stamped by `recall.sh`) — tracking them as-is would churn those fields and create merge conflicts across clones.

A third issue surfaces alongside: the legacy flat `.woostack/memory.md` global shard duplicates the store model (a second "always-loaded" surface and a fallback path threaded through nearly every skill). It complicates "track the store" (a split track-the-scoped-store / ignore-the-flat-file rule) and adds reasoning overhead for marginal value now that `/woostack-init` always scaffolds the scoped store.

So the real shape is: to consolidate **all** development decisions into a token-efficient, **shared** recall surface, the memory store must become a single, tracked, telemetry-clean scoped store — then `woostack-dream` mines the decision corpus into it.

## 2. Goal

Make consolidated learnings **both** token-efficient to recall **and** committed/shared, and have `woostack-dream` consolidate design trends from the full development-decision corpus into that surface. Concretely:

1. **One scoped store.** Remove the flat `.woostack/memory.md` shard; the scoped `.woostack/memory/` store is the single memory surface.
2. **Telemetry off the notes.** Move `recall_count`/`last_recalled` into a gitignored, per-clone sidecar so note files carry only shared, durable content.
3. **Track the store.** Commit `.woostack/memory/` notes + the derived index as shared team knowledge; keep only per-clone state (telemetry sidecar, watermark, `metrics.json`, `*.local.*`) gitignored.
4. **Mine the decision corpus.** `woostack-dream` reads `.woostack/{specs,plans,fixes}/*.md` as a first-class input to `surface`, consolidating recurring design decisions into tracked notes; it commits its curated output via `woostack-commit` and reads the corpus **incrementally** (new since a watermark, matched against the note index as the cheap history proxy) with a full-corpus first-run baseline.

Delivered as **one spec → one plan → four PR-sized increments** (A→B→C→D), each independently shippable and reviewable.

## 3. Non-goals

- **No new recall *algorithm*.** Scope-routing/one-hop-expand (memory contract §6) is unchanged in shape; recall simply stops loading a flat file and reads telemetry from the sidecar. No new matching semantics.
- **No telemetry *feature* change.** The dead-note signal still uses `recall_count`/`last_recalled`; only their *storage location* moves (frontmatter → sidecar). Same fields, same meaning.
- **No change to what gets distilled.** `woostack-execute` distillation and `address-comments`/`review` memory-record keep their existing reject-by-default §7 gate, scope rules, and note content. The deltas are mechanical: the note is now tracked, distillation writes it **in the worktree** (not redirected to primary) so it rides the increment's commit, and there is no flat-file fallback target.
- **No new approval gate.** Trend notes ride `woostack-dream`'s existing Phase 3 HARD review gate; the only new mutation surface (committing memory) routes through the existing `woostack-commit` handoff.
- **No session/transcript mining.** Inputs stay static/deterministic: the scoped store, the specs/plans/fixes corpus, docs, git history. (Incremental reading adds local *state*, not session mining — see §4.D.)
- **No spec/plan/status reconciliation.** That stays `/woostack-status`'s job.
- **No Obsidian-config or graph-script changes.** `graph.sh`/`.obsidian/` are untouched.

## 4. Approach

This repo dogfoods its own `.woostack/`, so its store/corpus is the live test surface. The work is four increments; the memory contract [`skills/woostack-init/references/memory.md`](../../skills/woostack-init/references/memory.md) is the canonical doc and is edited once per affected section, with consuming skills cross-linking (never restating) it.

### Increment A — Remove the flat `memory.md` shard (single scoped store)

Collapse the two-surface model to scoped-only. Touch points (from a collection-wide scan):

- **Contract** (`references/memory.md`): rewrite §1 (drop "additive layer on top of the flat shard"), §2 layout (remove the `memory.md` line and its gitignore mention), §6 step 1 ("always load `MEMORY.md`" only — no flat load), §7 (drop the flat-append fallback in the address-comments path), §10 degradation (no flat fallback; with no scoped store, recall has nothing and the skill says so).
- **Scripts**: `recall.sh` (remove the flat-`memory.md` load step), `build-index.sh` and `doctor.sh` (drop flat-file handling), and their tests (`test-recall.sh`, `test-build-index.sh`, `test-gitignore-template.sh`, etc.).
- **Memory-record helpers**: `address-comments/scripts/memory-record.sh` + `memory-append.sh` and `review/scripts/memory-record.sh` + `memory-append.sh` — drop the "scoped store absent → flat append" branch; when `.woostack/memory/` is absent, **skip with a stderr notice** (defer to `/woostack-init`), never write a flat file.
- **Skill prose**: remove flat-shard fallback mentions in `woostack-dream`, `woostack-execute`, `woostack-execute-overnight`, `woostack-debug`, `woostack-tdd`, `woostack-commit`, `woostack-address-comments`, `woostack-review` (`SKILL.md` + `_header.md`/`validator*.md`/`prompts`), `woostack-init` SKILL, and `woostack-bootstrap/references/development.md`.
- **Scaffold**: `woostack-init/templates/gitignore` drops the `memory.md` line; `woostack-init` no longer seeds an empty flat shard.

Pure simplification; independently shippable. **Breaking contract change** — called out as such.

### Increment B — Recall telemetry → gitignored sidecar

- **Sidecar**: a per-clone, gitignored, line-based TSV at `.woostack/memory/.telemetry.tsv` — `name<TAB>recall_count<TAB>last_recalled`, one row per note (bash-greppable, no `jq`). Resolved relative to the memdir, like the other scripts.
- **`recall.sh`**: stamp the sidecar (upsert the note's row) instead of mutating the note frontmatter; keep the best-effort failure semantics (write failure logs to stderr, never changes output/exit).
- **`doctor.sh`**: dead-note check joins `recall_count`/`last_recalled` from the sidecar by `name` instead of reading frontmatter; same `WOOSTACK_DEAD_DAYS`/`WOOSTACK_NOW` knobs.
- **Contract §3/§8**: drop `recall_count`/`last_recalled` from the note-frontmatter field table; document the sidecar as tool-managed local state. The "inert if present" rule remains a safety net (index/doctor ignore unknown keys), but because this repo's existing notes are about to be **tracked** (Inc C), Inc B also performs a **one-time strip** of `recall_count`/`last_recalled` from existing note frontmatter so tracked files don't leak one clone's counts into shared history.
- Tests: `test-recall.sh`, `test-doctor.sh`, `test-lib.sh` updated to assert sidecar read/write.

Enabler: telemetry must leave the note before the note can be tracked without churn.

### Increment C — Track the scoped memory store

- **`.woostack/.gitignore`**: stop ignoring `memory/`; instead track `memory/*.md` + `memory/MEMORY.md` and ignore only per-clone state — `memory/.telemetry.tsv`, `memory/.dream-watermark` (Inc D), plus the existing `metrics.json`, `*.local.*`. (`memory.md` line already removed in Inc A.)
- **`woostack-init/templates/gitignore`** + `test-gitignore-template.sh`: mirror the same rule so fresh scaffolds track memory.
- **Contract §2**: memory notes + index are tracked, shared knowledge; only the sidecar/watermark/metrics/local files are per-clone.
- **Worktree-contract ripple (required for "shared" to work)**: tracked memory breaks `worktrees.md` §3/§5, which redirect distilled memory to the **primary** tree via `WOOSTACK_ROOT` (because it's gitignored/local and the worktree is torn down). Once memory is tracked, distilled notes must be **committed in-worktree with the increment** (else they sit uncommitted in primary and never reach the PR). So Inc C updates: `worktrees.md` §3 (drop memory from the local-only exception — keep `metrics.json` + the telemetry sidecar + the dream watermark) and §5 (only metrics/telemetry/watermark still resolve to primary; memory is written and committed in the worktree); and `woostack-execute`/`woostack-execute-overnight` distill steps (drop the `WOOSTACK_ROOT` redirect *for memory*, rebuild `MEMORY.md` in-worktree, let memory ride the increment's `woostack-commit`). Distillation's gate/scope/content (§7) is unchanged — only the write location (worktree, not primary) and the fact that it's committed.
- **`address-comments`/`review` memory-record**: now write **tracked** notes that ride their existing commit; gate/scope unchanged.
- **Generated index**: `MEMORY.md` is tracked; the flows already rebuild it via `build-index.sh` before committing, so the tracked index stays in sync with the notes.

Depends on B (telemetry out first); benefits from A (no flat-file split rule).

### Increment D — `woostack-dream`: design-trend mining + commit + incremental (the original ask)

- **Corpus input**: Phase 1 enumerates and reads `.woostack/{specs,plans,fixes}/*.md` as design-trend input to `surface` — distinct from the existing follow-`source:`-for-staleness read, and still **excluded from the doc-promotion target set** (inputs, not promotion targets).
- **`surface` extension**: a "recurring pattern" may be a design decision recurring across the corpus, consolidated into one tracked note. `source:` = most-specific contributing artifact path (never fabricated); must pass the §7 reject-by-default gate (cross-feature glob scope, provenance, dedupe, `updated:` stamp); type stays recall-eligible (`decision`/`pattern`/`convention`), never `spec`/`plan`. Dedupe is **store-wide** (against `MEMORY.md` + fuzzy hooks) — it collapses redundancy (update/strengthen an existing note) rather than re-adding, which is the token-efficiency mechanism. Superseded raw scratch is pruned via the existing `drop` op (full-body gate).
- **Incremental read** (cheap + correct): the trigger set is artifacts new/changed since a gitignored watermark (`.woostack/memory/.dream-watermark`, which records a **git ref** — the trigger set is `git log <ref>..HEAD --name-only -- .woostack/specs .woostack/plans .woostack/fixes`; absent/corrupt ref or non-git checkout ⇒ full-corpus baseline). Matching is against the always-read **note index as the cheap proxy for history** (a new artifact corroborating a decision already captured as a note strengthens that note; a new artifact matching another new artifact is a fresh trend). **First run (no watermark) = full-corpus baseline.** `instructions: "full corpus"` forces a re-baseline. Idempotence is restated as **"no-op on a re-run with no new artifacts."**
- **Commit stance**: drop the "local-only / never commit memory" hard constraint. `woostack-dream` now hands **both** curated memory changes and doc edits to `woostack-commit`; it still never self-commits and never merges. The watermark advances only after a successful run.
- **`description`** updated to name the specs/plans/fixes decision corpus as an input alongside the store and docs (retain "no session mining").

Depends on C (notes tracked before dream commits them).

## 5. Components & data flow

```mermaid
flowchart TB
    subgraph store["`.woostack/memory/` (TRACKED after Inc C)"]
      notes["note *.md (shared)"]
      index["MEMORY.md (shared)"]
      tel[".telemetry.tsv (gitignored, Inc B)"]
      wm[".dream-watermark (gitignored, Inc D)"]
    end
    corpus[".woostack/{specs,plans,fixes}/*.md (tracked)"]
    recall["recall.sh"] -->|reads| index
    recall -->|reads| notes
    recall -->|stamps| tel
    doctor["doctor.sh"] -->|dead-note join| tel
    dream["/woostack-dream (Inc D)"] -->|new-since-watermark| corpus
    dream -->|match vs index = history proxy| index
    dream -->|surface trend → tracked note| notes
    dream -->|advance| wm
    dream -->|curated memory + doc edits| commit["woostack-commit (never merges)"]
```

Flat `memory.md` is absent post-Inc-A (no second surface, no flat load, no flat fallback).

## 6. Error handling

- **No `.woostack/memory/`** — recall/record have no target; record helpers skip with a stderr notice (defer to `/woostack-init`); recall returns the index-less empty set. No flat fallback exists.
- **Sidecar missing/unreadable** (Inc B) — treated as "no telemetry": dead-note check sees absent counts (same as a never-recalled note today); recall write failure is best-effort/logged, never fatal.
- **Note carries stale telemetry frontmatter** (post-Inc-B) — inert; ignored by index/doctor; not migrated.
- **Watermark missing/corrupt** (Inc D) — fall back to a **full-corpus baseline** (the safe superset); never error.
- **Corpus present but no trend recurs / trend already distilled** — `surface` proposes nothing (the §7 cross-feature/dedupe gate filters it); not an error.
- **No approval at the gate** — no memory/doc mutation and no commit; watermark does **not** advance.
- **Tracked-memory merge conflict** — possible now that notes are shared (acceptable trade for sharing); ordinary git resolution. Per-clone churn is eliminated because telemetry/watermark are gitignored.

## 7. Acceptance criteria

> This repo ships skill markdown + bash scripts, no app runner/CI (per `AGENTS.md`). Verification = the script unit tests under `skills/woostack-init/scripts/tests/` (and the address/review test dirs) for behavior changes, plus concrete structural assertion (grep/read) for prose, plus a live dry-run. Per the `woostack-tdd` carve-out, script changes are red/green against those bash tests; doc changes are structural.

- **AC-A1 — Flat shard removed (contract)**
  - happy: `references/memory.md` no longer presents `memory.md` as a loaded surface; §6 step 1 loads only `MEMORY.md`; §2 layout omits the flat file.
  - edge: §10 degradation states there is no flat fallback (no scoped store ⇒ recall empty / record skipped).
- **AC-A2 — Flat shard removed (scripts + helpers)**
  - happy: `recall.sh`/`build-index.sh`/`doctor.sh` no longer read/write a flat `memory.md`; their tests pass.
  - happy: `address-comments`/`review` `memory-record.sh`/`memory-append.sh` drop the flat-append branch and skip-with-notice when the scoped store is absent; their tests pass.
  - error: no code path writes `.woostack/memory.md`.
- **AC-A3 — Flat shard removed (prose + scaffold)**
  - happy: no remaining flat-shard fallback claims in the listed skills/prompts; `templates/gitignore` omits `memory.md`; `/woostack-init` no longer seeds a flat shard.
- **AC-B1 — Telemetry sidecar**
  - happy: `recall.sh` stamps `.woostack/memory/.telemetry.tsv` (name/count/date) and leaves note frontmatter untouched; `doctor.sh` dead-note check reads counts from the sidecar; `test-recall.sh`/`test-doctor.sh` assert this.
  - error: a sidecar write failure logs to stderr and does not change recall output/exit.
  - edge: contract §3 field table no longer lists `recall_count`/`last_recalled`; stray frontmatter copies are inert.
- **AC-C1 — Store tracked**
  - happy: `.woostack/.gitignore` and `templates/gitignore` track `memory/*.md` + `MEMORY.md` and ignore `memory/.telemetry.tsv`, `memory/.dream-watermark`, `metrics.json`, `*.local.*`; `test-gitignore-template.sh` asserts it.
  - edge: contract §2 describes notes/index as tracked, only per-clone state ignored.
  - edge: one-time telemetry strip (Inc B) leaves the now-tracked notes free of `recall_count`/`last_recalled` frontmatter.
- **AC-C2 — Worktree contract + distill redirect**
  - happy: `worktrees.md` §3/§5 keep only `metrics.json` + telemetry sidecar + watermark as primary/gitignored; memory is no longer in the local-only exception.
  - happy: `woostack-execute`/`woostack-execute-overnight` distill in-worktree (no `WOOSTACK_ROOT` redirect for memory), rebuild `MEMORY.md` there, and let memory ride the increment's `woostack-commit`.
  - error: no flow leaves distilled memory uncommitted in the primary tree.
- **AC-D1 — Corpus mined for design trends**
  - happy: `woostack-dream` Phase 1 reads the `{specs,plans,fixes}/*.md` corpus as `surface` input, distinct from follow-`source:`-for-staleness, and retains the doc-promotion-target exclusion.
  - happy: `surface` consolidates a cross-artifact design trend into one tracked note with a real contributing-artifact `source:`; the note passes §7 and uses a recall-eligible type.
  - edge: store-wide dedupe collapses redundancy (strengthen existing) rather than re-adding.
- **AC-D2 — Incremental + commit + idempotence**
  - happy: first run baselines the full corpus; later runs mine only artifacts newer than `.dream-watermark`, matched against the note index; watermark advances only on a successful run.
  - happy: `woostack-dream` hands curated memory + doc edits to `woostack-commit`; never self-commits, never merges.
  - edge: a re-run with no new artifacts is a no-op; a missing/corrupt watermark falls back to a full baseline.
- **AC-D3 — Description**
  - happy: the `description` names the specs/plans/fixes decision corpus as an input and retains "no session mining".
- **AC-X — Cross-link & count integrity**
  - happy: every relative link in every edited file resolves; the memory contract is edited once per section and consumers cross-link it (no restated schema); no doc still claims a flat shard or frontmatter telemetry.

## 8. Testing

> Strategy only — harness, test levels, fixtures, CI. Per-behavior cases live in §7.

- **Bash unit tests (red/green).** The script changes (Inc A flat removal, Inc B sidecar, Inc C gitignore template, the record helpers) are driven against the existing suites under `skills/woostack-init/scripts/tests/`, `skills/woostack-address-comments/scripts/tests/`, `skills/woostack-review/scripts/tests/`. Update/extend tests first (red), then change the scripts (green). New coverage: sidecar upsert + dead-note join, no-flat-file assertions, gitignore-template tracks-memory/ignores-sidecar, record-helper skip-with-notice when store absent.
- **Structural assertion (grep/read).** For prose-only edits (skill SKILL.md/prompts, contract sections, `description`): confirm flat-shard fallback language is gone, the corpus-as-input and dedupe-vs-history language is present, and the doc-promotion-target exclusion is retained.
- **Cross-link check.** Every relative link in every edited file resolves to a real path; the memory contract remains the single home for the schema (consumers link, not restate).
- **Live dry-run (acceptance smoke).** After all increments, run `recall.sh`/`doctor.sh` against this repo's tracked store (telemetry in the sidecar) and run `/woostack-dream` against the populated corpus: confirm Phase 1 reads the corpus, `surface` proposes ≥1 cross-artifact trend note (or correctly reports none/all-distilled) with a real `source:`, the HARD gate halts before any write, the watermark advances only post-approval, and a second run with no new artifacts is a no-op.

## 9. Open questions

**Settled during ideation/hardening:**
- Corpus scope → specs **+** plans **+** fixes.
- Recall efficiency vs. dream cost → **incremental** read: watermark trigger set + note-index-as-history + first-run full-corpus baseline; idempotence restated as "no-op when no new artifacts".
- Saved/shared learnings → **track the scoped store**; move recall telemetry to a gitignored sidecar so tracked notes don't churn.
- Flat `memory.md` → **removed entirely** (single scoped store); breaking contract change accepted.
- Sidecar format → line-based TSV (bash-greppable, no `jq`); Inc B one-time-strips existing telemetry frontmatter so tracked notes are clean.
- Watermark mechanism → `.dream-watermark` stores a **git ref**; trigger set = `git log <ref>..HEAD --name-only -- <corpus dirs>`; absent/non-git ⇒ full-corpus baseline.
- Tracked memory vs. worktrees → Inc C updates `worktrees.md` §3/§5 and the `execute`/`-overnight` distill steps so memory is written + committed **in-worktree** (only metrics/telemetry/watermark stay primary/gitignored).
- Other writers' commit policy → ride existing commits; no new commit logic (the note file is simply tracked now).
- `woostack-dream` commit stance → hand curated memory + doc edits to `woostack-commit`; never self-commit, never merge.
- Structure → one widened spec + one plan decomposed into four stacked increments A→B→C→D.

None open.
