# Wisdom Store Contract

This document is the canonical reference for the `.woostack/wisdom/` store. Every woostack skill
that reads or writes wisdom files should point here rather than restating the schema. It is the
sibling of [`memory.md`](memory.md) — `memory.md` governs the scope-routed `.woostack/memory/`
store; this file governs the wholesale-loaded `.woostack/wisdom/` store.

---

## 1. Purpose — the two-tier model

woostack keeps knowledge in two tiers:

- **`.woostack/memory/`** — scoped per-fact notes, loaded by scope-matched recall (see
  [`memory.md`](memory.md)) and distilled by `woostack-execute`.
- **`.woostack/wisdom/`** — a deliberately small set of **generalized, cross-cutting findings**,
  loaded **wholesale** (always, regardless of file scope) to guide future development and reviews.

`woostack-dream` is the only writer of `wisdom/`. It consolidates corroborated trends from local
memory; sanitized diagnostic reports and independently verified remote or immutable Git context
may corroborate those trends. Raw `respond/evidence/` is excluded. A single diagnostic report or
remote artifact cannot establish generalized wisdom. Only fully absorbed memory notes may be
pruned; diagnostic reports and development records never are.

---

## 2. Layout

```
.woostack/
├── memory/    scope-routed per-fact notes (see memory.md)
├── wisdom/    generalized findings — THIS contract
│   ├── <slug>.md
│   └── .gitkeep
└── respond/                       sanitized diagnostic reports (evidence, never pruned)
```

`wisdom/` is **tracked shared knowledge** — it is NOT gitignored.
`/woostack-init` scaffolds the directory with a `.gitkeep`.

---

## 3. File format

A wisdom file is a Markdown file under `.woostack/wisdom/` with line-oriented frontmatter,
identical in parsing rules to a memory note (one `key: value` per line; comma lists, not YAML block
sequences):

```
---
name: <unique-slug>
type: wisdom
category: review | planning | testing | process
source: <comma-list of contributing inputs — see §5>
updated: YYYY-MM-DD
---
Generalized finding stated as durable guidance, plus how to apply it. [[Wikilinks]] to related
memory notes are encouraged (Obsidian-native, grep-resolvable).
```

| Field | Required | Description |
|---|---|---|
| `name` | yes | Unique slug; the wikilink anchor and filename basename. |
| `type` | yes | Always `wisdom`. Reserved + recall-excluded (see §4). |
| `category` | no | One of `review`/`planning`/`testing`/`process`. A hook for future selective loading; consumers currently load **all** categories. |
| `source` | yes | The contributor ledger (§5). Provenance is required, as for memory notes. |
| `updated` | yes | ISO date the finding was last written. |
| body | yes | Non-empty generalized guidance after the closing `---`. |

Keep the set **small**: a wisdom file must clear a bar higher than a memory note — it is
generalized, cross-cutting, and re-read on every review/build/plan. Fewer, denser findings beat
many thin ones.

---

## 4. Recall exclusion (structural)

Wisdom is **never** part of scope-matched memory recall. This is structural, not a code filter:
`build-index.sh` and `recall.sh` scan only `.woostack/memory/`, so a file under `.woostack/wisdom/`
is never indexed into `MEMORY.md` and never loaded by `recall.sh`. The `type: wisdom` value is
**reserved** (alongside `spec`/`plan`) and documented as recall-excluded in `memory.md` §3 so the
recall docs stay self-consistent. Wisdom reaches consumers only via the wholesale-load path (§6).

---

## 5. The `source:` ledger and prune semantics

`source:` is a comma-list of validated stable provenance carried forward from the contributing
claims. Every token follows the canonical [memory provenance contract](memory.md#fields);
note names, report filenames, mutable paths, and copied development text never become provenance.
The ledger is permanent: it records why the generalized finding exists.

**Only fully absorbed `.woostack/memory/` notes are prunable.**
Pruning is gated:

1. `woostack-dream` names each candidate separately from the wisdom `source:` ledger.
2. A candidate is prunable only when the proposed wisdom finding fully preserves its reusable value.
3. Scope-specific precision, uncertainty, or any independent value keeps the candidate.
4. The review gate shows the complete candidate and its absorbing wisdom entry before deletion.
5. Explicit approval is required; silence is not approval.

Deleting a memory note triggers `build-index.sh` regeneration. Diagnostic reports remain
non-authoritative evidence and are never deleted through wisdom pruning.

---

## 6. Consumption (wholesale-load)

Wisdom guides future work by being loaded **in full** (every `wisdom/*.md` body) wherever design,
planning, review, or root-cause investigation context is gathered:

- **`woostack-review`** — `prefetch.sh` composes a `$OUTDIR/wisdom.md` artifact via
  [`compose-wisdom.sh`](../../woostack-review/scripts/compose-wisdom.sh) (the wisdom analogue of
  `recall.sh`/`memory.md`); reviewers treat it as an additional rubric of learned house-rules.

- **`woostack-build` / `woostack-ideate`** — the design phase reads all `wisdom/*.md` before
  proposing a design.
- **`woostack-plan`** — reads all `wisdom/*.md` before writing the plan.
- **`woostack-debug`** — recalls all `wisdom/*.md` at investigation start, alongside its scoped
  `.woostack/memory/` recall, surfacing wisdom as recurring failure-*class* hints. Both tiers are
  quarantined as **candidate hypotheses, never answers** — subject to the Iron Law and the Phase 3
  test (see [`woostack-debug/SKILL.md`](../../woostack-debug/SKILL.md#memory)). Debug is the natural
  first **selective** consumer should the store grow: it would load the diagnostic categories
  (`testing`, `process`) and drop the prescriptive ones (`review`, `planning`) via the per-note
  `category` hook (§3).

An empty or absent `wisdom/` makes every load a no-op (no consumer error).

---

## 7. Lifecycle

```
woostack-execute distills ──► memory/ note (scoped knowledge)
woostack-dream consolidates corroborated trends across memory + verified evidence
        └──► wisdom/<slug>.md   (durable, generalized)   + gated prune of fully absorbed memory notes
review / build / plan / debug ──► wholesale-load wisdom/ as guidance
```

`woostack-dream` no longer **creates** memory notes (its old `surface` op is now `consolidate`,
retargeted to `wisdom/`); memory notes are created only by `woostack-execute` distillation.
Sanitized response reports remain non-authoritative diagnostic evidence and never enter
`MEMORY.md`; raw `respond/evidence/` is never read. One report alone cannot create wisdom.

---

## 8. Degradation

- No `.woostack/wisdom/` directory → consumers load nothing (no-op); `woostack-dream` creates it on
  first approved `consolidate` (or `/woostack-init` scaffolds it).
- Missing scripts (individual manual install) → announce the manual fallback, never fail silently
  (mirrors `memory.md` §10).
