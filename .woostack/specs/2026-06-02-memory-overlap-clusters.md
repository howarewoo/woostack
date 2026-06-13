---
name: memory-overlap-clusters
type: spec
status: approved
date: 2026-06-02
branch: feature/memory-overlap-clusters
links:
---

# Memory: scope-overlap clusters + recall recency tiebreak (#162) — Design Spec

> **Plan:** [[plans/2026-06-02-memory-overlap-clusters]]

> Visualize on demand: render this file with [spec-template.html](spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

## 1. Problem

Part of the memory-system efficacy initiative ([[woostack-memory-vault]]). Two related gaps:

- **Silent contradiction.** Two notes with overlapping `scope:` both load on a matching run. If their advice contradicts, the agent gets mixed signal with no resolution and nothing surfaces the collision.
- **Crude tie ordering.** `recall.sh` sorts matched notes by match-count descending; ties resolve in arbitrary glob order. Under cap pressure an older note can outrank a newer same-count note, and a stale note can win over the one that superseded it.

## 2. Goal

Surface scope-overlap clusters for human review (doctor cannot judge semantics, but the collision is cheap to flag), and break recall match-count ties by recency so the newer note ranks first.

## 3. Non-goals

- **No auto-resolution** of contradictions — semantic judgment doctor can't make. It flags; humans decide.
- **No syntactic glob-intersection math** — overlap is measured by shared *tracked files*, not glob-string algebra (a glob that overlaps another only on non-existent paths is not a real collision).
- **No pairwise reporting** — clusters only (one warning per connected component).
- No change to recall's primary sort (match-count stays the primary key) or to the global-shard reserved-first behavior.
- #163 (value-ranking) / #166 / #168 untouched.

## 4. Approach

### Part 1 — `doctor.sh` overlap clusters (warning-only)

Measure overlap by the thing that actually co-loads: shared tracked files.

- In the existing per-note loop, for each **non-global** note (`scope` present and not `*`), compute the *set* of tracked files its `scope` matches. This **replaces** (does not double) the current stale-scope `scope-match.sh … >/dev/null` call: capture the command's output instead of discarding it, derive the stale-on-empty signal from whether the output is empty (existing behavior preserved), and keep the matched paths for overlap. One `scope-match.sh` invocation per note, as today.
- Emit one `file<TAB>note` line per (matched file, note) pair to a temp file.
- After the loop, feed the pairs to an **awk union-find**. awk has native associative arrays, so this is portable on bash 3.2 (macOS default, BSD awk) where `declare -A` is unavailable. Algorithm: (1) union every pair of notes that share a file; (2) resolve each note to its component root via `find` with path-compression; (3) for each component, the **canonical cluster id is the lexicographically smallest member name**; (4) emit `clusterId<TAB>member` per note.
- bash side: `sort` those lines, group by `clusterId`, join members with `, `, and `warn` on any group with ≥2 members. The min-member canonical id makes both member order and cluster order **deterministic regardless of `git ls-files` or note-glob ordering** — so tests can assert the exact warning string. Verified by an empirical `sort -k1,1nr -k2,2r` test during design.
- Warning text: `overlap cluster: <a.md>, <b.md>, … — intersecting scope, review for contradiction`. Warning-only (exit 0). All members listed, no truncation.

Global (`*`/absent) notes never enter a cluster — they co-load with everything by design. When `git ls-files` is empty (no repo / no tracked files) the whole block is skipped, exactly as the stale-scope check already degrades.

**Transitive-merge caveat (accepted):** a broad note overlapping two narrow notes that don't touch each other puts all three in one cluster. Acceptable — a human reviewing the group is the goal.

### Part 2 — `recall.sh` recency tiebreak

- The matched-note emission (line ~36) writes `cnt<TAB>path`; change it to `cnt<TAB>updated<TAB>path`, where `updated` is `field "$f" updated` (empty when absent).
- The sort (line ~44) becomes `sort -t<TAB> -k1,1nr -k2,2r` followed by `cut -f3-`. ISO `YYYY-MM-DD` sorts lexically = chronologically; reverse (`-k2,2r`) puts the newest first and an empty `updated:` last, so an undated note loses the tie. Match-count (`-k1,1nr`) remains primary; the recency key only reorders genuine ties. **Empirically verified on BSD sort during design:** `cnt=5` outranks all `cnt=3`; within `cnt=3`, order is `2026-06-02 → 2026-03-15 → 2026-01-01 → (undated)`. A full tie (equal count *and* date) falls through to a deterministic whole-line comparison.
- Only the **matched** (scoped) note array is reordered; linked-note and global-shard ordering are unchanged (the issue scopes the tiebreak to match-count ties, which only the matched set has).

## 5. Components & data flow

| Touch point | Change |
|---|---|
| `skills/woostack-init/scripts/doctor.sh` | Capture per-note matched files in the existing loop; after the loop, awk union-find → one warning per ≥2-note cluster. |
| `skills/woostack-init/scripts/recall.sh` | Emit `updated` as a sort column; add `-k2,2r` recency tiebreak; `cut -f3-`. |
| `skills/woostack-init/references/memory.md` §8 | Document the overlap-cluster warning among the staleness signals. |
| `skills/woostack-init/references/memory.md` §6 | Note the match-count → recency tiebreak in the recall procedure. |
| `skills/woostack-init/scripts/tests/test-doctor.sh` | Cluster detection tests. |
| `skills/woostack-init/scripts/tests/test-recall.sh` | Recency-tiebreak tests. |

**doctor data flow:** `paths` (`git ls-files`) already exists in the loop. For each non-global note, `printf '%s\n' "$paths" | scope-match.sh "$scope"` yields matched files; the loop both keeps the existing stale-on-empty behavior and appends `file<TAB>note` pairs to a temp file. After the loop, `awk -F'\t'` builds union-find over the pairs and prints clusters; doctor turns each into a `warn`. The temp file is cleaned with the existing `seen` cleanup style.

**recall data flow:** unchanged except the sort tuple carries `updated` between `cnt` and `path`; downstream array build (`cut -f3-`) is otherwise identical.

## 6. Error handling

- **No git / no tracked files:** `paths` empty → the overlap block is skipped (same guard as stale-scope). No error.
- **Note with no `updated:` in recall:** emits an empty middle column; sorts last on a tie. No crash (empty field is valid for `sort`/`cut`).
- **Tab safety:** memory note paths and basenames contain no tabs (glob of `*.md` under `MEM_DIR`); the `<TAB>` delimiter is unambiguous. `updated:` is an ISO date — no tabs.
- **awk absence:** awk is POSIX and already used in `memory-record.sh` (`note_body_of`); no new dependency. If a cluster temp file is empty (no overlaps), awk prints nothing and no warning fires.
- All overlap findings are warnings — `doctor.sh` still exits 0 on warnings, 1 only on the pre-existing error conditions.
- **Warning stacking is intentional.** A note may emit overlap *and* a #161 non-glob/missing-`source:` warning *and* be part of a cluster simultaneously; doctor already stacks independent signals (e.g. stale + missing-source). No suppression — each warning is an orthogonal signal. (A stale note matches zero files, so it is never in a cluster — overlap and stale are mutually exclusive for a given note.)

## 7. Testing

**`test-doctor.sh`** (git-backed fixture repo, matching existing style — `mk_note`, `run_doctor`, `assert_*`):

- Two notes whose scopes both match a tracked file (e.g. both `packages/api/**`, or `packages/api/**` and `packages/api/orpc/**` with a tracked `packages/api/orpc/x.ts`) → `overlap cluster` warning naming **both**; exit 0.
- Two notes with disjoint scopes (`packages/api/**` vs `apps/web/**`, distinct tracked files) → **no** `overlap cluster` warning.
- A global note (`scope: *`) plus a scoped note matching real files → no overlap warning (global exempt).
- Three notes all matching a shared tracked file → a single cluster warning listing all three.
- A stale note (scope matches zero files) alongside a real note → stale warning only, no overlap.
- Confirm a clean two-note disjoint store still exits 0 and the existing assertions are unaffected.

**`test-recall.sh`** (existing harness):

- Two notes, equal match-count, different `updated:` → the newer note renders first in `## Scoped memory`; under a tight `RECALL_CAP` the **older** is the one dropped.
- Equal match-count, one note undated + one dated → the dated note wins (renders first / survives the cap).
- A higher match-count note still outranks a newer lower-count note (primary key unchanged).

Run both via `bash skills/woostack-init/scripts/tests/run-tests.sh`; full suite green.

## 8. Open questions

None — all forks resolved in brainstorm:
- Overlap detection → shared-tracked-file proxy (not syntactic glob math).
- Reporting → cluster (connected component), not pairwise.
- Undated on a recall tie → loses (sorts last).
