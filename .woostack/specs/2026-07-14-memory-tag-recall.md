---
name: memory-tag-recall
type: spec
status: approved
date: 2026-07-14
branch: feature/memory-tag-recall
links:
---

# Memory tag-hop recall axis — Design Spec

> Visualize on demand: render this file with [spec-template.html](../../../skills/woostack-build/references/spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → ready → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../../skills/woostack-status/references/conventions.md).

> **Plan:** [[plans/2026-07-14-memory-tag-recall]]

## 1. Problem

`recall.sh` selects memory notes for a working set using **one axis only: file-path scope**.
A note is loaded when its `scope:` globs match the working-set paths (`scope-match.sh`), plus a
one-hop `[[wikilink]]` expand from the matched set, plus always-on global (`*`/absent-scope)
notes. Knowledge that is *conceptually* relevant to the current work but authored against
**different files** never surfaces — there is no path overlap and (unless someone hand-wrote a
wikilink) no edge to reach it.

The note schema already carries a `tags:` field (comma list, `memory.md` §3), but it is declared
**"informational only in increment A"** — nothing reads it at recall time. So the one piece of
cross-cutting, non-path metadata the store already collects is inert. This is the gap a semantic
(vector) store would close with embeddings; woostack can close part of it deterministically,
with the metadata it already has, and no new infrastructure.

## 2. Goal

Make `tags:` a **load-bearing recall axis** via **one-hop tag expansion**: after scope-match,
pull in any not-yet-loaded, non-global note that shares ≥1 tag with a scope-matched note. This is
a **second expansion edge beside the existing one-hop wikilink expand** — same shape, same
machinery, deterministic and grep/bash-only. It widens recall from "path-adjacent" to
"path-adjacent + one tag-hop," with strict precision guards so a broad tag cannot flood or evict
higher-value notes.

## 3. Non-goals

- **No explicit query-tags input** (deferred "Approach B"): recall keeps its two-arg contract
  (`<woostack_dir> <paths_file>`); no third arg, no `RECALL_TAGS` env. Query tags are derived
  from the scope-matched notes, not supplied by callers. No caller-contract change anywhere.
- **No `doctor.sh` tag checks** (no tag-orphan / tag-lint / tag-cluster warnings).
- **No `build-index.sh` change** — `MEMORY.md` gains no tag column; `recall.sh` reads `tags:`
  from note frontmatter directly via `field()`.
- **No distillation change** — the write path and reject-by-default gate (`memory.md` §7) are
  untouched; this is a read-path feature.
- **No multi-hop tag graph** — expansion is exactly one hop from the scope-matched set.
- **No re-ranking of scoped/linked/global** — their existing order and cap precedence are
  unchanged; tag-related notes are strictly appended below them.

## 4. Approach

**Tag-hop expansion**, inserted into `recall.sh` after the existing one-hop wikilink expand
(current lines 52–59) and before the telemetry-stamp / render phase.

1. **Build the query tag-set** = the union of `tags:` values across the **scope-matched notes
   only** — not globals (they co-load with everything and would seed unbounded expansion), not
   wikilinked notes (keeps the hop anchored to the primary matched set). Tag tokens are the
   comma-separated `tags:` values, **whitespace-trimmed** and compared **case-insensitively**.
2. **Scan candidates.** For each note in `MEM_DIR` not already loaded (`inc_set`) and not global,
   read its `tags:`; if it shares ≥1 token with the query tag-set, add it to a new `tag_linked`
   bucket and mark it in `inc_set`.
3. **One hop only.** `tag_linked` notes are never themselves used as an expansion source (neither
   tag nor wikilink). Dedup is enforced against everything already loaded (scoped, linked, global).
4. **Telemetry.** Stamp `tag_linked` notes through the same best-effort `stamp_note` path used for
   matched/linked/global (a stamp failure logs to stderr and never changes output or exit status).
5. **Order & cap.** `tag_linked` is ordered by **shared-tag count desc, then `updated:` recency
   desc, then name asc** — a candidate sharing more tags with the working set ranks higher and
   survives cap pressure longer (the tag analog of the matched set's `cnt`-then-`updated`
   tie-break, `recall.sh` line 47). The new section `## Tag-related notes` prints **after
   `## Linked notes` and before `## Global memory`**. Cap-fill precedence is strictly lowest:
   globals are reserved first (always kept), then scoped fills `budget`, then linked fills the
   remainder, then `tag_linked` fills what is left; each dropped note logs `recall: dropped
   tag-related <note> (cap)` to stderr. When globals alone exceed the cap (the existing
   global-tail-cap branch, `recall.sh` lines 89–91) scoped, linked, **and** tag_linked are
   suppressed together — tag_linked renders inside the same `else` branch as scoped/linked,
   never the tail-cap branch. A broad tag can therefore never evict a scoped, linked, or global
   note.

Output section order becomes: `## Scoped memory (matched this PR)` → `## Linked notes` →
`## Tag-related notes` → `## Global memory`.

## 5. Components & data flow

- **`skills/woostack-init/scripts/recall.sh`** — the only behavior change. Adds a `tag_linked`
  bucket + tempfile, the query-tag-set build, the candidate scan, telemetry stamping of the new
  bucket, a `rem2` cap-budget step, and the `## Tag-related notes` render. Tag parsing reuses
  `field "$f" tags` (`lib.sh`); no new helper is required unless a tiny tag-tokenize/lowercase
  inline is cleaner (implementation detail for the plan).
- **`skills/woostack-init/references/memory.md`** — the contract home. §3: `tags:` row changes
  from "informational only in increment A" to a recall axis (format unchanged — comma list). §6:
  add the tag-hop step to the recall procedure (one hop, matched-source, ranked below wikilinks,
  dropped-first under cap), and note the new output section.
- **`skills/woostack-init/scripts/tests/test-recall.sh`** — structural proof of every AC (§8).
- **Lockstep site docs** (`lockstep-edit-sites` house-rule). The recall mechanic is restated in
  three **authored** pages, all phrased "scope match and one-hop expansion":
  `site/content/docs/concepts.mdx` (the "Scripts compute, agents read" section),
  `site/content/docs/concepts/context-management.mdx`, and
  `site/content/docs/concepts/memory.mdx`. The plan updates `concepts/memory.mdx` (the memory
  page) to name the tag axis; the two overview lines stay accurate (tag-hop *is* a one-hop
  expansion) and are enriched only if it reads cleanly. Per-skill `.mdx` is generated/gitignored
  — not counted.

```
paths_file ─▶ scope-match ─▶ matched{cnt,updated}
                               │            │
                     one-hop wikilink   one-hop TAG (NEW: union tags of matched
                       expand → linked      → pull non-global shared-tag notes → tag_linked)
                               │            │
   globals (always) ──────────┴────────────┴──▶ cap fill: globals▸scoped▸linked▸tag_linked
                                                 render: Scoped ▸ Linked ▸ Tag-related ▸ Global
```

## 6. Error handling

- **Broad-tag noise** (a common tag like `errors` pulling in many notes): bounded by
  matched-only source + one hop + distinct section + **lowest cap precedence** (dropped first).
  The feature can add notes but never displace higher-value ones.
- **No tags anywhere / empty or whitespace-only `tags:`**: query tag-set is empty ⇒ zero
  candidates ⇒ no `## Tag-related notes` section ⇒ output byte-identical to today (regression
  guard, AC5).
- **Malformed tags** (stray commas, extra spaces): trimmed to tokens; empty tokens are ignored;
  never errors.
- **Telemetry write failure** (read-only checkout): `stamp_note` logs `recall: stamp failed
  <note>` to stderr; recall output and exit 0 are unchanged (existing contract).
- **Cap exhaustion**: `tag_linked` notes that do not fit are dropped and logged; scoped/linked/
  global are never sacrificed for a tag-related note.
- **Global tail-cap**: when globals alone exceed the cap, scoped, linked, and tag_linked are
  suppressed together (§4 step 5) — the tail-cap branch never emits a tag-related note.
- **Absent `MEM_DIR` / empty paths**: unchanged — no matched set ⇒ empty query tag-set ⇒ no
  tag expansion.

## 7. Acceptance criteria

> **Angle pre-flight.** security: N/A — reads local note files only, no new input or network.
> observability: cap-drop and stamp-fail stderr logs (§6) cover the new bucket. api: the recall
> stdout contract gains one clearly-delimited section (§4). database: N/A. edge/error: broad tag,
> no tags, one-hop bound, cap eviction, global exclusion, dedup — all captured below.

- **AC1 — tag-hop expansion surfaces a shared-tag note**
  - happy: a scope-matched note has tag `T`; a **non-global** note scoped to unrelated files also
    has tag `T` → the second note appears under `## Tag-related notes`.
  - error: N/A (no external failure mode; see AC5 for the empty case).
  - edge: a note that shares **no** tag with any matched note is **not** pulled.
- **AC2 — expansion is exactly one hop from the matched set**
  - happy: expansion runs once over candidates against the matched set's tag union.
  - error: N/A.
  - edge: a note that shares a tag only with a `tag_linked` note (not with any scope-matched
    note) is **not** pulled — no second-hop.
- **AC3 — cap precedence: tag-related is lowest**
  - happy: under a tight `RECALL_CAP`, a `tag_linked` note that does not fit is dropped and
    `recall: dropped tag-related <note> (cap)` is logged to stderr.
  - error: N/A.
  - edge: globals, scoped, and linked notes are **never** dropped to make room for a tag-related
    note.
- **AC4 — globals are not an expansion source**
  - happy: a global (`*`/absent-scope) note's tags do **not** seed the query tag-set; a note that
    shares a tag only with a global note is not pulled.
  - error: N/A.
  - edge: a candidate that is itself global is skipped (already loaded via the globals path; no
    duplicate).
- **AC5 — no-tags regression / no-op**
  - happy: with no `tags:` on any note, recall output is **byte-identical** to the pre-change
    behavior (no `## Tag-related notes` header emitted).
  - error: N/A.
  - edge: an empty or whitespace-only `tags:` value is treated as no tags.
- **AC6 — dedup + telemetry**
  - happy: a `tag_linked` note is stamped in `.telemetry.tsv` like matched/linked/global notes.
  - error: a telemetry stamp failure logs to stderr and does not change recall output or exit 0.
  - edge: a note already loaded as scoped, linked, or global is **not** duplicated into
    `## Tag-related notes`.
- **AC7 — tag-related ordering under cap**
  - happy: given two tag-related candidates and a cap that fits only one, the candidate sharing
    **more** tags with the matched set is kept; the other is dropped and logged.
  - error: N/A.
  - edge: equal shared-tag counts break by `updated:` recency, then name — deterministic.

## 8. Testing

Strategy: the existing bespoke bash harness — `tests/assert.sh` helpers driven by
`tests/run-tests.sh`, no external framework — extended in `tests/test-recall.sh`. Each test
builds a temp `MEMORY`-style dir of fixture notes (frontmatter + body), runs `recall.sh` with a
`paths_file`, and asserts on stdout sections / stderr drop logs / `.telemetry.tsv` rows. Tests set
`WOOSTACK_NOW`/`RECALL_CAP` for determinism (mirroring existing cases). Assertions follow the
`grep-assertion-single-physical-line` house-rule (one asserted phrase per physical line). AC5's
regression guard captures pre-change output for a no-tags fixture and asserts byte-equality.
Every AC in §7 maps to ≥1 case; a negative case pins AC2's one-hop bound and AC1's no-shared-tag
exclusion (a deliberate regression guard, not redundant — see
`skill-test-negative-regression-guard-not-redundant`).

## 9. Open questions

None blocking — the spec is hardened. Resolved by design: **(a)** tag comparison is
whitespace-trimmed and case-insensitive (§4); **(b)** the query-tag source is the scope-matched
set only, excluding globals and wikilinked notes (§4); **(d)** `tag_linked` ordering is
shared-tag-count desc → `updated:` recency desc → name asc (§4, AC7). Resolved by exploration:
**(c)** the recall mechanic is restated in three authored site pages (§5), moved in lockstep by
the plan; and `run-tests.sh` globs `test-*.sh`, so the new `test-recall.sh` cases run with no
wiring change.
