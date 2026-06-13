# Wisdom Store Contract

This document is the canonical reference for the `.woostack/wisdom/` store. Every woostack skill
that reads or writes wisdom files should point here rather than restating the schema. It is the
sibling of [`memory.md`](memory.md) — `memory.md` governs the scope-routed `.woostack/memory/`
store; this file governs the wholesale-loaded `.woostack/wisdom/` store.

---

## 1. Purpose — the two-tier model

woostack keeps knowledge in two tiers:

- **`.woostack/memory/`** — scoped per-fact notes, loaded by scope-matched recall (see
  [`memory.md`](memory.md)). Raw, per-feature scratch distilled by `woostack-execute`.
- **`.woostack/wisdom/`** — a deliberately small set of **generalized, cross-cutting findings**,
  loaded **wholesale** (always, regardless of file scope) to guide future development and reviews.

`woostack-dream` is the only writer of `wisdom/`. It mines the decision corpus
(`.woostack/{fixes,specs,plans}/`) plus the scratch tiers (`.woostack/memory/`,
`.woostack/overnight/`) for recurring trends and consolidates them here. Once a finding is fully
captured in a wisdom file, the contributing **scratch** inputs (memory notes + overnight reports)
are pruned (see §5). The decision corpus is never deleted.

---

## 2. Layout

```
.woostack/
├── memory/    scope-routed per-fact notes (see memory.md)
├── wisdom/    generalized findings — THIS contract
│   ├── <slug>.md
│   └── .gitkeep
├── specs/     plans/   fixes/   authored decision corpus (mined, never pruned)
└── overnight/ run reports (gitignored scratch, mined + prunable)
```

`wisdom/` is **tracked shared knowledge** — it is NOT gitignored (contrast `overnight/`, which is).
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
Generalized finding stated as durable guidance, plus how to apply it. [[wikilinks]] to related
memory notes, specs, or plans are encouraged (Obsidian-native, grep-resolvable).
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

`source:` is a comma-list of **all** inputs that contributed to the finding. Each token is one of:
- a memory note `name` (resolves to `.woostack/memory/<name>.md`);
- a repo-relative path under `.woostack/overnight/`, `.woostack/specs/`, `.woostack/plans/`, or
  `.woostack/fixes/`.

The ledger is **permanent provenance**: it still names a contributor after that contributor has been
pruned (a tombstone). It records *why* the finding exists.

**Prune** is the deletion of fully-absorbed scratch. It is computed and gated by `woostack-dream`:

1. An input is **eligible** for prune only if it appears in some wisdom file's `source:`.
2. Of the eligible inputs, the **prune list** is the subset whose value is *fully* captured by the
   wisdom finding — judged per-input by the agent at synthesis time.
3. Inputs that retain independent value (e.g. a **scope-specific** memory note whose precision would
   be lost if generalized) are **partial** → kept (or rescoped), never in the prune list.
4. **Any doubt → keep.**
5. **Only scratch is prunable:** `.woostack/memory/` notes and `.woostack/overnight/` reports.
   `specs`/`plans`/`fixes` tokens are provenance-only and are **never** deleted, even when fully
   absorbed.

Safety: `overnight/` is gitignored → a deleted report is **unrecoverable**. `woostack-dream`'s
review gate therefore shows the **full body** of every overnight report on the prune list before
any deletion, and requires explicit approval (silence is not approval). Memory notes are
git-tracked (recoverable) but are still shown with their absorbing wisdom file. Pruning a memory
note triggers `build-index.sh` regeneration; deleting an overnight report touches no index.

---

## 6. Consumption (wholesale-load)

Wisdom guides future work by being loaded **in full** (every `wisdom/*.md` body) wherever design,
planning, or review context is gathered:

- **`woostack-review`** — `prefetch.sh` composes a `$OUTDIR/wisdom.md` artifact via
  [`compose-wisdom.sh`](../../woostack-review/scripts/compose-wisdom.sh) (the wisdom analogue of
  `recall.sh`/`memory.md`); reviewers treat it as an additional rubric of learned house-rules.

- **`woostack-build` / `woostack-ideate`** — the design phase reads all `wisdom/*.md` before
  proposing a design.
- **`woostack-plan`** — reads all `wisdom/*.md` before writing the plan.

An empty or absent `wisdom/` makes every load a no-op (no consumer error).

---

## 7. Lifecycle

```
woostack-execute distills ──► memory/ note (scoped scratch)
woostack-execute-overnight ──► overnight/ report (gitignored scratch)
woostack-dream consolidates recurring trends across memory + overnight + fixes/specs/plans
        └──► wisdom/<slug>.md   (durable, generalized)   + gated prune of fully-absorbed scratch
review / build / plan ──► wholesale-load wisdom/ as guidance
```

`woostack-dream` no longer **creates** memory notes (its old `surface` op is now `consolidate`,
retargeted to `wisdom/`); memory notes are created only by `woostack-execute` distillation.

---

## 8. Degradation

- No `.woostack/wisdom/` directory → consumers load nothing (no-op); `woostack-dream` creates it on
  first approved `consolidate` (or `/woostack-init` scaffolds it).
- No `.woostack/overnight/` directory → the overnight scan is a no-op; the rest of the dream pass
  proceeds.
- Missing scripts (individual manual install) → announce the manual fallback, never fail silently
  (mirrors `memory.md` §10).
