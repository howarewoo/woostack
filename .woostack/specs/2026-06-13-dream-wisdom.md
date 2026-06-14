---
name: dream-wisdom
type: spec
status: approved
date: 2026-06-13
branch: feature/dream-wisdom
links:
---

# woostack-dream → wisdom consolidation — Design Spec

> **Plan:** [[plans/2026-06-13-dream-wisdom]]

> Visualize on demand: render this file with [spec-template.html](../../skills/woostack-build/references/spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → ready → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../skills/woostack-status/references/conventions.md).

## 1. Problem

`woostack-dream` today consolidates recurring trends **into memory notes** (the `surface`
operation) and curates the memory store in place (`merge`/`replace`/`drop`/`resolve`). Two gaps:

1. **Overnight reports are never read.** `.woostack/overnight/*.md` (morning reports from
   `woostack-execute-overnight`) accumulate hard-won, gotcha-dense run learnings that the dream pass
   ignores entirely. They are gitignored scratch that grows unbounded and is never distilled.
2. **No durable home for generalized cross-cutting wisdom.** Surfaced trends land back in the
   memory store as scope-matched notes — the same tier as raw per-feature distillations. There is no
   separate, deliberately-small layer of generalized findings meant to *guide future development and
   reviews* wholesale, independent of any one feature's file scope.

The result: overnight learnings rot, and generalized wisdom is indistinguishable from per-feature
scratch. There is also a latent documentation defect — `woostack-dream/SKILL.md` repeatedly asserts
"gitignored memory is unrecoverable," but in this store `.woostack/memory/` is git-tracked; the
genuinely-unrecoverable surface is `.woostack/overnight/` (gitignored).

## 2. Goal

Reshape `woostack-dream` around a **two-tier knowledge model**:

- **`.woostack/wisdom/`** (new, tracked) — the durable home for generalized, cross-cutting findings
  consolidated from all decision/scratch corpora. Small, high-value, loaded *wholesale* to guide
  future development and reviews.
- **memory notes + overnight reports** — raw inputs that are mined for trends and then **pruned**
  (deleted) once a wisdom file has fully absorbed them.

Concretely:
1. Add `.woostack/overnight/*.md` to the corpus `woostack-dream` scans.
2. Introduce `.woostack/wisdom/` as the `consolidate` operation's output target (retargeting and
   broadening today's `surface`).
3. Add a gated `prune` operation that deletes fully-absorbed memory notes and overnight reports,
   leaving `fixes/specs/plans` untouched.
4. Wire `woostack-review`, `woostack-build`, and `woostack-plan` to load `wisdom/` wholesale.
5. Scaffold `wisdom/` in `woostack-init`, track it in git, and document it in the memory contract.
6. Correct the "gitignored memory is unrecoverable" defect.

## 3. Non-goals

- **No scope-matched recall for wisdom.** Wisdom is loaded wholesale (always-load), not scope-routed.
  `type: wisdom` is excluded from scope-match recall exactly as `spec`/`plan` are.
- **No `doctor.sh` linting of `wisdom/`.** A future follow-on; out of scope here to avoid ballooning.
- **No `category:`-based selective loading of wisdom.** `category:` is recorded as a hook for future
  filtering, but consumers load *all* wisdom files for now (approach B).
- **No deletion of `fixes/specs/plans`.** Ever. They are authored decision records, exempt even when
  fully absorbed into a wisdom file.
- **No change to the spec/plan/PR board joins** or the `status:` enum — wisdom is not a spec/plan and
  does not appear on the `/woostack-status` board.
- **No retroactive migration** of existing memory notes into wisdom beyond what a normal first
  full-corpus dream pass would surface.

## 4. Approach

**Two-tier model.** `fixes/specs/plans` are the authored decision corpus (mined, never deleted).
`memory` + `overnight` are scratch (mined, then pruned once absorbed). `wisdom/` is the consolidated
durable output.

**Reshape the dream operations** (Phase 2 of the existing procedure):
- `scan` — broaden the corpus to all five: `fixes`, `specs`, `plans`, **`overnight` (new)**, `memory`,
  plus tracked docs.
- `consolidate` (was `surface`) — roll recurring trends/gotchas across all five corpora into
  `.woostack/wisdom/<slug>.md` files instead of memory notes. Each wisdom file records its
  contributing inputs in a `source:` ledger.
- `prune` (new) — delete only the memory notes and overnight reports judged **fully absorbed** into a
  wisdom file. Mechanism: a wisdom file's `source:` ledger records **all** contributors (permanent
  provenance/tombstone — it still names a contributor after that contributor is deleted). At synthesis
  the agent computes a **prune list** = the subset of `source:` whose value is *fully* captured by the
  wisdom finding. Inputs retaining independent (e.g. scope-specific) value are **partial** → kept or
  rescoped, never in the prune list. **Any doubt → keep.** `fixes/specs/plans` are exempt and never
  appear in a prune list. Pruning memory notes triggers `build-index.sh` regen (Phase 4); deleting
  overnight reports touches no index.
- Retain **all** existing memory-curation ops (`merge`, `replace`, `drop`, `resolve`) for memory
  hygiene, and the evidence-guarded `doc recommendation` (now backable by a wisdom file *or* a memory
  note). The only change to the legacy ops: `surface` is renamed/retargeted to `consolidate`
  (memory → wisdom). dream therefore **no longer creates** memory notes — memory notes are created by
  `woostack-execute` distillation; dream now only consolidates, hygienes, and prunes them.

**Wisdom file format (approach B — wholesale-loaded).** See §5.

**Consumption.** A shared "load all `wisdom/*.md` bodies as a guidance preamble" step, wired into
`woostack-review` (as a review-context artifact), the `woostack-build` design phase (the wisdom load
sits where design context is gathered — `woostack-build`/`woostack-ideate`; exact file placement is a
plan-time detail), and `woostack-plan` (at plan start). Wholesale read of a small dir — documented
procedure, no new recall index; review may surface it via its existing context-artifact/prefetch path.

**Plumbing.** `woostack-init` scaffolds `wisdom/`; `.woostack/.gitignore` tracks it (no ignore entry,
unlike `overnight/`); the memory contract documents the directory, the new reserved `type: wisdom`,
and its recall exclusion.

## 5. Components & data flow

```
INPUTS (read, mined for trends)            OUTPUT                  PRUNE (gated, after absorb)
  .woostack/fixes/*.md   ─┐
  .woostack/specs/*.md    ├─ decision corpus ──┐                   (never deleted)
  .woostack/plans/*.md   ─┘                     │ consolidate
  .woostack/memory/*.md  ─┐ scratch ────────────┼──►  .woostack/   memory note deleted (tracked → recoverable)
  .woostack/overnight/*.md┘ run reports ────────┘     wisdom/<slug> overnight report deleted (gitignored → NOT recoverable)
  tracked docs (git ls-files '*.md') ── doc recommendation (evidence-guarded)
                                                       │ wholesale-load
                            woostack-review ◄──────────┤
                            woostack-build  ◄──────────┤
                            woostack-plan   ◄──────────┘
```

**Wisdom file** — `.woostack/wisdom/<slug>.md`, tracked, Obsidian node, `[[wikilink]]`-able:
```
---
name: <slug>
type: wisdom
category: review | planning | testing | process
source: <merged-from ledger — memory note names, overnight paths, spec/plan/fix paths>
updated: YYYY-MM-DD
---
Generalized finding + how to apply. [[wikilinks]] to related notes/specs.
```
- `type: wisdom` is a **new reserved type**, excluded from scope-match recall (like `spec`/`plan`).
- `source:` is a comma-list of **all** contributing inputs (memory note names, overnight paths,
  spec/plan/fix paths) — permanent provenance that survives as a tombstone after a contributor is
  pruned. An input is *eligible* for prune only if it appears in some `source:`; whether it is *in the
  prune list* is the fully-vs-partially-absorbed judgment (above), adjudicated per-input at the gate.

**Components touched:**
- `skills/woostack-dream/SKILL.md` — reshaped Phase 1 scan, Phase 2 ops (`consolidate`, `prune`),
  Phase 3 gate (full-body for overnight), Phase 4 apply, degradation, hard constraints; correction of
  the memory-recoverability claim.
- `skills/woostack-init/` — scaffold `.woostack/wisdom/` (+ `.gitkeep`); `.gitignore` template tracks
  wisdom.
- `skills/woostack-init/references/wisdom.md` — **new**, the canonical wisdom-store contract (format,
  layout, recall exclusion, `source:` ledger + prune semantics, wholesale-load consumption). Sibling to
  `memory.md`; cross-linked by dream/review/build/plan.
- `skills/woostack-init/references/memory.md` — §2 layout note that `wisdom/` is a sibling store (one
  line, cross-link `wisdom.md`); §3 one-line `type: wisdom` reserved + recall-excluded entry. memory.md
  stays scoped to the memory store; the wisdom contract lives in `wisdom.md`.
- `skills/woostack-dream/SKILL.md` hard constraints — update the legacy "do not add new scripts / do
  not modify the memory contract" rule: it bounds dream's **runtime** behavior, not this Mode-A feature
  that evolves the contract surface and may add an init template/test.
- `skills/woostack-review/`, `skills/woostack-build/SKILL.md`, `skills/woostack-plan/SKILL.md` —
  wholesale wisdom-load wiring.
- `.woostack/.gitignore` (live store) — confirm `wisdom/` not ignored.

## 6. Error handling

- **No `overnight/` dir** → overnight scan is a no-op; rest of the pass proceeds.
- **No `wisdom/` dir** → created on first approved `consolidate` (or by `woostack-init`); absence is
  not an error.
- **Overnight is gitignored → unrecoverable.** The deletion gate (Phase 3) MUST show the **full body**
  of every overnight report scheduled for deletion before any prune. Memory notes are tracked
  (recoverable) but are still shown with their absorbing wisdom file.
- **Partial absorption** → an input that retains independent value not captured by the generalized
  wisdom is kept (or flagged for rescope), never auto-deleted. The common partial case: a memory note
  whose value is **scope-specific** (precisely scope-routed to certain files) — generalizing it into
  global wisdom would *lose* the scope precision, so it stays in `memory/` and only contributes to the
  wisdom finding's `source:` ledger.
- **No deletion before explicit approval** — silence/ambiguity is not approval (existing gate
  discipline).
- **Watermark blindness to overnight** → because `overnight/` is gitignored, the git-log watermark
  cannot track it; overnight is **full-scanned every run**. This does **not** grow unbounded: prune is
  the natural incrementality bound — fully-absorbed reports/notes are deleted, so each run only re-sees
  inputs still awaiting corroboration. Kept (partial / not-yet-trended) inputs are intentionally
  re-scanned until they reach the corroboration threshold. Specs/plans/fixes (never deleted) keep the
  existing git-log watermark to avoid re-mining the full decision history each run; memory is
  always-read.
- **No `.woostack/` at all** → stop; do not scaffold (defer to `/woostack-init`), per existing rule.
- **Missing scripts** → manual fallback per memory contract §10, never silent.

## 7. Acceptance criteria

Each AC is a testable behavior → ≥1 plan task.

- **AC1 — `woostack-init` scaffolds `wisdom/`**
  - happy: a fresh `/woostack-init` creates `.woostack/wisdom/` containing `.gitkeep`.
  - error: an existing non-empty `.woostack/wisdom/` is never clobbered.
  - edge: re-running init on a store that already has `wisdom/` is idempotent (no duplicate/no error).
- **AC2 — `wisdom/` is tracked, not gitignored**
  - happy: the scaffolded `.woostack/.gitignore` has no entry that ignores `wisdom/`; a file under
    `wisdom/` shows up in `git status`/`git ls-files`.
  - error: N/A — absence of an ignore entry is the assertion.
  - edge: `overnight/` remains ignored in the same template (regression guard that the two are treated
    differently).
- **AC3 — wisdom is structurally outside memory recall**
  - happy: a `wisdom/<slug>.md` file is never indexed by `build-index.sh` nor loaded by `recall.sh`
    (both scan only `.woostack/memory/`), so it never enters scope-matched context.
  - error: even a wisdom file carrying a `scope:` field is not scope-recalled — it lives in
    `wisdom/`, not `memory/`.
  - edge: `MEMORY.md` regeneration over a store that also has a sibling `wisdom/` dir is unchanged
    (no wisdom line leaks into the memory index). *(Resolved by inspection: exclusion is structural —
    separate directory — plus a documented `type: wisdom` reserved entry in memory.md §3. No
    `recall.sh`/`scope-match.sh` code change.)*
- **AC4 — wisdom store has a canonical contract**
  - happy: `skills/woostack-init/references/wisdom.md` exists and documents format, layout, recall
    exclusion, `source:` ledger + prune semantics, and wholesale-load consumption.
  - error: `memory.md` gains a one-line `type: wisdom` reserved/recall-excluded note in §3 and a layout
    cross-link to `wisdom.md`, without otherwise broadening its memory-store scope.
  - edge: cross-links from `woostack-dream/SKILL.md`, `woostack-review`, `woostack-build`,
    `woostack-plan`, and `memory.md` to `wisdom.md` all resolve.
- **AC5 — `woostack-dream/SKILL.md` describes the reshaped pass**
  - happy: SKILL scan reads all five corpora incl. `overnight/`; `consolidate` writes to `wisdom/`;
    `prune` deletes fully-absorbed memory + overnight only; `fixes/specs/plans` exempt; gate shows
    overnight full-body.
  - error: SKILL no longer claims "gitignored memory is unrecoverable"; names `overnight/` as the
    unrecoverable surface.
  - edge: degradation rules (no overnight / no wisdom dir) are stated.
- **AC6 — consumers load wisdom wholesale**
  - happy: `woostack-review`, `woostack-build`, `woostack-plan` each document loading all `wisdom/*.md`
    bodies as guidance.
  - error: with an empty/absent `wisdom/`, the load is a no-op (no consumer error).
  - edge: review wiring follows the existing review-context-artifact pattern (load-config, prefetch,
    header — the known wiring sites).
- **AC7 — prune is gated and default-keep (safety-critical)**
  - happy: the dream procedure prunes only prune-list (fully-absorbed) inputs, after explicit approval;
    each prune entry is shown with its absorbing wisdom file and a "why absorbed" line.
  - error: every `overnight/` report scheduled for deletion is shown **full-body** at the gate before
    any prune (gitignored → unrecoverable); `fixes/specs/plans` never appear in a prune list.
  - edge: a contributor judged *partial* (e.g. scope-specific memory note) is kept and only recorded in
    `source:`; on any doubt the input is kept; silence/ambiguity is not approval.

## 8. Testing

> Strategy only — per-behavior cases live in §7.

`woostack-dream` is a Markdown procedure, not executable code, so the bulk of verification is
**doc-content + cross-link consistency** (procedure text, reserved-type docs, consumer wiring,
corrected claim), checked by review against §7.

Where real code is touched, add concrete tests in the matching harness:
- **Init scaffold** — extend the existing `woostack-init` scaffold tests to assert `wisdom/` +
  `.gitkeep` creation, idempotency, no-clobber, and the gitignore tracks-wisdom / ignores-overnight
  pair (AC1, AC2).
- **Recall / index scripts** — if `recall.sh`/`scope-match.sh`/`build-index.sh` enforce the
  `spec`/`plan` recall exclusion **in code**, extend that to `type: wisdom` with a test fixture; if
  the exclusion is procedure-only, AC3 is a memory.md/doc assertion (resolve in §9 / planning).

CI: this repo runs no self-CI; tests run via the touched component's local runner (whatever the
`woostack-init` scripts use). No new test harness is introduced.

## 9. Open questions

1. ~~**Recall exclusion: code-enforced or procedure-only?**~~ **RESOLVED (inspection).** No script
   filters `type` for recall — `recall.sh`/`scope-match.sh` are type-blind and `build-index.sh` scans
   only `.woostack/memory/`. Wisdom lives in a separate `.woostack/wisdom/` dir → structurally never
   indexed or recalled. AC3 is a structural + doc assertion, not a `recall.sh` code change.
2. ~~**`source:` ledger format for multi-input provenance.**~~ **RESOLVED (hardening).** `source:` is a
   comma-list of provenance tokens — each a memory note `name` (→ `.woostack/memory/<name>.md`) or a
   repo-relative path (`.woostack/overnight/<file>.md`, `.woostack/{specs,plans,fixes}/...`). Prune maps
   a prune-list token to its file: note names → `memory/<name>.md`, `overnight/` paths → that file;
   `specs/plans/fixes` tokens are provenance-only and never map to a delete. `wisdom.md` pins this token
   grammar.
3. ~~**First-run volume.**~~ **RESOLVED (hardening).** No spec change: the existing Phase 3 hard gate
   bounds risk, and the skill already offers a `woostack-visualize` (`engineer`) render for large
   changesets. The new prune list is presented within that same gate.
4. ~~**Does `woostack-status`/conventions need any wisdom awareness?**~~ **RESOLVED (inspection).**
   `conventions.md` has no `type`/`recall`/`wisdom` awareness; wisdom is not a spec/plan and never
   joins the board. No enum/table touch.
