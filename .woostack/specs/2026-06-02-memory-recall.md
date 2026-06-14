---
name: memory-recall
type: spec
status: approved
date: 2026-06-02
branch: feat/woostack-memory-recall
increment: B of 4
---

# Memory recall + review scope-routing — Design Spec

> **Plan:** [[plans/2026-06-02-memory-recall]]

> Increment B of 4. Stacks on increment A ([[woostack-init]]). Builds the read path: the `recall.sh` orchestration A deferred, wired into the review pipeline so workers get scope-matched notes instead of the whole flat dump.

## 1. Problem

Increment A shipped the scope-routed memory store (`memory/` dir, `scope-match.sh`, `build-index.sh`, `doctor.sh`) and the contract, but **nothing reads it**. The review pipeline still consumes memory the old way: `prefetch.sh` copies the flat `.woostack/memory.md` whole (100KB tail-cap) into `$OUTDIR/memory.md`, and every angle worker + validator reads that as rubric. On a large codebase that is a wall of unrelated gotchas fed to every angle regardless of which files the PR touches.

A also deferred the `recall.sh` orchestration (compute working-set → scope-match → one-hop link expand → compose) to "increment B, with its first consumer." This is that increment: the review pipeline is the first consumer.

## 2. Goal

- Ship `skills/woostack-init/scripts/recall.sh` — the documented recall procedure as a script, reusing `scope-match.sh` + `lib.sh`.
- Wire it into `prefetch.sh`: replace the raw flat-file copy with a `recall.sh` call against the PR's changed paths, so `$OUTDIR/memory.md` carries the **global shard + scope-matched notes + one-hop expansion** for this PR — not the whole store.
- Preserve behavior for repos with only a flat `memory.md` (no `memory/` dir): recall folds the flat file in as the global shard, so the output degrades to today's content.

## 3. Non-goals

- **Write path unchanged.** `memory-append.sh` and review/address still write accepted-learnings to the flat `memory.md`. Routing writes into scoped notes is increment C or manual.
- **No worker-prompt changes.** Workers keep reading `$OUTDIR/memory.md`; only how it's produced changes.
- **No Obsidian layer** (increment D).
- **No build/bootstrap/address wiring** (increment C).
- No change to A's scripts' interfaces (`scope-match`, `build-index`, `doctor`); recall only consumes them.

## 4. Approach

### recall.sh = the single memory-context path

"Replace, not augment": `prefetch.sh` stops doing its own `tail -c`/`cp` and instead calls `recall.sh`, which becomes the one place memory context is composed. Crucially, recall still **includes the flat `memory.md` as the always-loaded global shard** — so additive-superset holds (nothing a repo already curated is lost), it's just routed through recall instead of dumped raw.

### Composition + ordering

`recall.sh <woostack_dir> <paths_file>` emits, in order:
1. **Scope-matched notes** from `memory/*.md` — a note is included if `scope-match` says its `scope` hits any working-set path. Ordered by match count (more matched paths = more relevant) descending.
2. **One-hop expansion** — notes directly `[[wikilinked]]` from the matched set (parsed from bodies), not already included.
3. **Global shard** — the flat `memory.md` verbatim (always-on; team's curated accepted-issues).

A `RECALL_CAP` byte budget (default 100KB) bounds the total. If exceeded, lowest-relevance items drop first and their names are logged to stderr — **no silent truncation** (improves on the blunt mid-file tail-cap).

### Degradation

- No `memory/` dir, only flat file → output = flat file (≈ today).
- Neither → empty/absent `memory.md` (as today; prefetch removes it).
- `recall.sh` missing (single-skill install) → prefetch falls back to the old copy logic and logs a warning (no silent loss).

## 5. Components & data flow

### 5.1 `skills/woostack-init/scripts/recall.sh`

```
recall.sh <woostack_dir> <paths_file>   # paths_file: newline repo-relative changed paths
  → stdout: composed memory markdown
  env: RECALL_CAP (bytes, default 102400)
```
- Working-set = lines of `paths_file`.
- For each `<woostack_dir>/memory/*.md` (skip MEMORY.md): read `scope` (via `lib.sh field`); count how many working-set paths `scope-match.sh "$scope"` matches; matched (count>0) join the candidate set. No-scope / `*` notes are global → always in (count = +∞ rank, but grouped with global, see ordering).
- One-hop: from matched bodies, `grep -oE '\[\[[^]]+\]\]'` → include `memory/<name>.md` if it exists and isn't already in.
- Emit sections with headers (`## Scoped memory (matched this PR)`, `## Linked notes`, `## Global memory`).
- **Cap rule (global is protected):** the global shard (flat `memory.md`) is the team's curated accepted-issues and drives noise control — it is **always included and never dropped** by the cap. `RECALL_CAP` bounds the total; scoped + one-hop notes fill the remaining budget after global, lowest-relevance (lowest match-count) dropped first with a stderr `recall: dropped <name> (cap)` line. Only the pathological case where the global shard alone exceeds the cap falls back to tail-capping the global (today's behavior) — also logged. No silent truncation.
- Pure bash + coreutils; sources `lib.sh`, calls `scope-match.sh` by path.

### 5.2 `skills/woostack-review/scripts/prefetch.sh` (memory block, ~679-697)

Replace the `if [ -f "$MEMORY_SRC" ] … tail -c/cp …` block with:
- `WOOSTACK_DIR="${GITHUB_WORKSPACE:-$(pwd)}/.woostack"`.
- Working-set paths file = `$OUTDIR/changed-paths.filtered.txt` if present, else derive from `meta.json` (`jq -r '.files[].path'`) — mirrors `detect-angles.sh`.
- Locate `recall.sh` via prefetch's own `SCRIPT_DIR` (already `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)` = `skills/woostack-review/scripts`): `RECALL="$SCRIPT_DIR/../../woostack-init/scripts/recall.sh"`. This sibling-skill path holds in both the chat-host install and the GitHub Action checkout (whole collection present). If found AND (`$WOOSTACK_DIR/memory/` exists OR flat file exists) → run it → `$OUTDIR/memory.md`, echo a summary.
- If `recall.sh` not found → fall back to the existing flat-copy logic (kept as a function) + warn.
- If neither memory source exists → `rm -f "$MEMORY_OUT"` (unchanged).

### 5.3 Docs

- `prompts/_header.md` memory section: note the file is now scope-routed context (global + matched), still "don't re-flag known/accepted."
- `SKILL.md` *Cross-PR Memory* section: add that, when a `.woostack/memory/` store exists, prefetch composes per-PR context via `recall.sh` (link the contract).

## 6. Error handling

- recall.sh `set -euo pipefail`; a single unreadable note is skipped with a stderr warning, not fatal (review memory is best-effort context, not a gate).
- Cap overflow logs every dropped note — never silently truncates.
- prefetch fallback path is explicit and logged; memory is never silently dropped.
- recall never writes to the repo; read-only over `.woostack/`.

## 7. Testing

- recall.sh unit tests (bash asserts, extend the woostack-init test harness):
  - only-flat-file repo → output equals flat file content (degradation).
  - matched note included; unmatched note excluded for a given paths file.
  - one-hop: a matched note `[[link]]`ing an unmatched note pulls the linked note in; two hops do NOT.
  - global (no-scope/`*`) note always included.
  - ordering: higher match-count note precedes lower.
  - `RECALL_CAP` small → lowest-relevance dropped + stderr log; output ≤ cap.
  - missing `memory/` dir + missing flat file → empty output, exit 0.
- prefetch integration (manual / scripted): a fixture repo with `.woostack/memory/` + changed paths → `$OUTDIR/memory.md` contains the matched note and not an unrelated one; a repo with only flat file → unchanged content; recall.sh absent → fallback + warning.

## 8. Open questions

Resolved during grill (2026-06-02):

- **Global shard is cap-protected** → the flat `memory.md` (accepted-issues) is always included; the cap drops scoped/one-hop notes first. Protects noise control. (§5.1)
- **recall.sh path** → `$SCRIPT_DIR/../../woostack-init/scripts/recall.sh` from prefetch; sibling-skill path holds in both layouts; fallback to flat-copy + warn when absent. (§5.2)
- **Relevance metric** → match-count descending (simple, good enough); revisit only if ordering reads wrong.

Remaining (accepted, low-risk): **section headers** (`## Scoped/Linked/Global`) slightly reshape `memory.md`; workers read it as plain markdown rubric, so no worker change needed — verify in the prefetch integration check.
