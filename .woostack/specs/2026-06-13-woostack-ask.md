---
name: woostack-ask
type: spec
status: approved
date: 2026-06-13
branch: feature/woostack-ask
links:
---

# woostack-ask — read-only codebase Q&A — Design Spec

> **Plan:** [[plans/2026-06-13-woostack-ask]]

> Visualize on demand: render this file with [spec-template.html](../../skills/woostack-build/references/spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → ready → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../skills/woostack-status/references/conventions.md).

## 1. Problem

No woostack command answers a question *about* the codebase without risking a write. Users
want investigative Q&A — "how does X work", "where does Y live", "are there benefits we could
integrate from `<external repo>` into our skill library" — grounded in the project's accumulated
knowledge and, when relevant, compared against external sources. Today the only way is an
unscoped agent that may edit, scaffold, or distill memory as a side effect.

[`woostack-debug`](../../skills/woostack-debug/SKILL.md) is investigative-only but narrowly
aimed at root-causing a bug; it is not a general question-answerer, and its recall is scoped to a
bug's working set. The scope-routed recall procedure (memory contract §6) deliberately **excludes**
`type: spec` / `type: plan` (and the planned `type: wisdom`) from routing, so recall alone cannot
reach the decision corpus a good answer often needs. There is no read-only counterpart to
[`woostack-dream`](../../skills/woostack-dream/SKILL.md): dream curates (writes, gated) the
`.woostack/` corpus; nothing simply *reads it to answer a question*.

## 2. Goal

A public `/woostack-ask <question>` command — a purely investigative, read-only Q&A skill that:

- grounds answers in the full woostack knowledge surface: recall the scoped `memory/` store,
  wholesale-load `wisdom/` when present, and read the rest of the `.woostack/` artifact tree
  (`specs/ plans/ fixes/ overnight/ visuals/` and any future store) on demand;
- reads repo code, and — when the question calls for it — external references, all read-only;
- answers in conversation with cited evidence (note names, `file:line`, artifact paths, URLs);
- writes **nothing** — no code, no `.woostack/` files, no memory notes, no commits, no merges;
- is registered as the **17th** public command with full surface wiring.

## 3. Non-goals

- **No writes of any kind.** No code, no `.woostack/` artifacts, no memory distillation, no
  commits/merges. Distillation stays owned by `woostack-execute`; curation by `woostack-dream`.
- **No approval gate, no chaining.** Autonomous like `woostack-debug`; answering is terminal. It
  never invokes build/plan/execute/fix — it may *name* the next command for the user to run.
- **No new scripts.** Pure-prose skill; reuses `woostack-init` scripts (`recall.sh`,
  `scope-match.sh`) exactly as `woostack-debug` does.
- **No recall/contract change.** Does not modify the recall procedure or the memory contract; it
  is a consumer of both. It does not add `wisdom/` — it only *reads* it when the in-flight
  dream-wisdom feature has created it.
- **Not a curator.** It is the read-only twin of `woostack-dream`, not a replacement.
- **External reads pull in, never push out.** WebFetch/WebSearch bring external content *into*
  the answer; the skill never sends codebase content to an external service.
- **No session mining.** It answers the question the user asked using static sources as
  evidence; unlike `woostack-dream` it never reflects over transcripts to write anything (it
  writes nothing at all).

## 4. Approach

Model on `woostack-debug`: investigative-only, autonomous, recall-at-start, hands findings back,
never writes. Four phases: **Recall → Investigate → Synthesize → Handback**.

The defining design point is that woostack-ask's read surface is **wider than the scoped recall
every other skill uses**. `woostack-review` / `woostack-execute` load a narrow per-working-set
context; woostack-ask uses recall as an *entry point* but reaches the whole `.woostack/` tree,
because answering a question can need the full decision history — the `woostack-dream` read
pattern, minus the writes and the gate. The tree is **enumerated dynamically** so future stores
(`wisdom/`, or anything added later) are automatically in scope; the subdir list is never
hardcoded.

A prominent **WRITE-BLOCK** invariant (mirroring debug's Iron Law, kept prominent so it survives
summarization) forbids every write action regardless of perceived simplicity. "Zero writes" means
zero *tracked* writes — no code, artifacts, memory notes, commits, or merges. The single inherited
benign side effect is `recall.sh`'s gitignored `.telemetry.tsv` stamp (best-effort, non-fatal),
identical to `woostack-debug`; `git status` stays clean because that sidecar is gitignored.

Investigation is **scoped to the question** (YAGNI on breadth) — read what the answer needs, not
the whole repo.

woostack-ask only **consumes** `wisdom/`; it neither defines nor creates that store. The
dependency direction is one-way: if/when the in-flight dream-wisdom feature lands `wisdom/`, ask's
dynamic `.woostack/` enumeration picks it up with no change to ask.

Surface registration follows the drift-prone bookkeeping sites captured in
[[woostack-command-surface-bookkeeping]] — current surface 16 public + 2 internal = 18 SKILL.md
files; adding ask makes it **17 public + 2 internal = 19**.

## 5. Components & data flow

One `skills/woostack-ask/SKILL.md`. No scripts, no `references/`.

**Knowledge surface (all read-only):**

| Source | How read | Notes |
|---|---|---|
| `.woostack/memory/` | recall procedure §6 — `recall.sh` when init scripts present, else manual (load `MEMORY.md` → `scope-match.sh` → one-hop `[[link]]` expand) | entry point; state script-assisted vs manual |
| `.woostack/wisdom/` | **wholesale-load** all `wisdom/*.md` when the dir exists | consumer pattern from the dream-wisdom feature; skip when absent |
| `.woostack/specs/ plans/ fixes/ overnight/ visuals/` | **direct read on demand**, by relevance (grep/glob) | specs/plans recall-excluded by type → direct read is the only path |
| future `.woostack/<new>/` subdirs | enumerated dynamically | never hardcode the subdir list |
| repo code | Read / Grep / Glob | follow existing patterns |
| external references | WebFetch / WebSearch | only when the question names/implies them; read-only |

**Data flow:** question → infer working set → recall + wisdom wholesale-load + targeted
corpus/code/external reads → synthesized, cited answer in conversation → optional
`woostack-visualize` render on request → stop.

**Phases:**

1. **Recall.** Infer the working set from the question. Run recall; wholesale-load `wisdom/` if
   present; surface matching notes before investigating. Never fail silently.
2. **Investigate (read-only).** Explore code, targeted `.woostack/` artifacts, and external
   sources. Gather evidence: `file:line`, note names, artifact paths, URLs.
3. **Synthesize.** Direct answer; cite every claim; mark grounded vs inferred. For an
   integration-benefit question: enumerate candidate benefits → map each to where it would land in
   the skill library → flag overlap/conflict with existing skills → give a recommendation. No
   implementation.
4. **Handback.** Answer in conversation; offer a `woostack-visualize` render on request; if the
   answer implies action, name the next command (e.g. `/woostack-build`). Chain nothing.

**No argument:** `/woostack-ask` with no question → ask what the user wants to know; do not guess
(mirror `woostack-debug`).

## 6. Error handling

- **No `.woostack/`** → report there is no memory/corpus to recall; answer from repo code (+
  external) only; never scaffold (defer to `/woostack-init`). Mirrors dream/debug degradation.
- **Init scripts missing** (individual install) → announce the manual recall fallback (memory
  contract §10); never fail silently.
- **Missing subdir** (`wisdom/`, `overnight/`, …) → skip that source, note the gap, continue.
- **External fetch fails / blocked / private URL** → report it; answer from reachable evidence;
  never fabricate.
- **Question implies a write** ("add X", "fix Y") → answer investigatively (what it would take,
  where it lands) and name the command to do it; never perform the write.
- **Non-git checkout** → filesystem corpus reads still work; recall telemetry stamping is
  best-effort and non-fatal.

## 7. Acceptance criteria

- **AC1 — purely investigative (write-block)**
  - happy: a question is answered in conversation with zero *tracked* mutations — no new or
    changed tracked files, no commits, no memory notes; `git status` clean after (the gitignored
    `recall.sh` telemetry sidecar is the only permitted side effect and does not dirty git).
  - error: a question phrased as a command ("add a woostack-foo skill") yields an investigative
    answer + the command to run, not an edit.
  - edge: even a trivially "simple" question performs no write.
- **AC2 — memory recall at start**
  - happy: ask runs recall (`recall.sh` when scripts present), surfaces matching notes before
    answering, and states whether recall was script-assisted or manual.
  - error: scripts absent → manual §6 recall, announced; never silent.
  - edge: empty/absent memory store → recall yields nothing; the answer still proceeds from
    corpus/code/external.
- **AC3 — full `.woostack/` reach beyond recall**
  - happy: a question about a spec/plan/fix is answered from a direct read of that artifact
    (recall-excluded by type, so direct read is required).
  - error: a referenced artifact dir is missing → source skipped, answer notes the gap.
  - edge: `wisdom/` present → wholesale-loaded; absent → skipped without error; a future
    `.woostack/<new>/` subdir is enumerated, not ignored.
- **AC4 — external reference comparison**
  - happy: the ponytail-style question ("benefits to integrate from `<external repo>` into our
    skill library") fetches the external source read-only and returns benefits mapped to
    skill-library landing spots + a recommendation.
  - error: external URL unreachable/private → reported; answer falls back to reachable evidence;
    no fabrication.
  - edge: a codebase-only question performs no external fetch.
- **AC5 — public command surface registered**
  - happy: `/woostack-ask <question>` routes via `using-woostack`; `AGENTS.md` count + lists,
    `README.md`, and `CONTRIBUTING.md` all include woostack-ask and the counts agree.
  - error: no automated command-count test exists in the repo (verified) — counts are prose in
    AGENTS.md / README.md / CONTRIBUTING.md; verification is grep-based that every count string and
    list agrees on 17.
  - edge: the SKILL.md `description:` follows the colon-space and angle-bracket-placeholder
    conventions ([[skill-description-colon-space]], [[skill-description-angle-bracket-placeholders]]).

## 8. Testing

> Strategy only — harness, levels, fixtures, CI. Per-behavior cases live in §7.

Prose-only skill, no scripts → no unit harness. Verification is structural and manual:

- grep assertions that every surface site references `woostack-ask` and the count strings agree
  (the [[woostack-command-surface-bookkeeping]] sites: `using-woostack` routing, `AGENTS.md`,
  `README.md`, `CONTRIBUTING.md`).
- if a committed command-count gating test exists, update its expected count and run it; otherwise
  N/A.
- manual smoke: run `/woostack-ask` on (a) a codebase question and (b) the ponytail-style external
  question; confirm a cited answer and a clean `git status` (zero writes).
- `woostack-review` on each increment PR (the `skills` angle).

## 9. Open questions

Resolved during spec harden (recorded here as settled decisions):

- **Command-count gating test?** No — verified there is no automated count test under
  `skills/*/scripts/tests/`. Counts live only as prose. AC5 is grep-based.
- **Exact wiring sites** (the authoritative map is [[woostack-command-surface-bookkeeping]]):
  - `AGENTS.md` (`.claude/CLAUDE.md` symlink): "sixteen skills" → seventeen; bulleted public list
    (+ask); "sixteen-skill command surface" → seventeen; rename constraint "eighteen … (sixteen
    public + 2 internal)" → "nineteen … (seventeen public + 2 internal)"; Quick file map (+ask);
    Mode B trigger list (+ask).
  - `skills/using-woostack/SKILL.md`: one Command Routing row.
  - `CONTRIBUTING.md`: intro public-surface list (+ask) **and** the "Change the …" pointer-table
    row — two sub-sites.
  - `README.md`: its command list is curated/exemplary ("e.g. … etc."), not an exhaustive count;
    planning adds ask where investigation commands are surfaced, minimal.
  - `skills/woostack-bootstrap/references/development.md`: **no-op** — ask is an inspection
    command, not a build-loop phase (same as `woostack-status` / `woostack-debug`); verify only.
- **Description format:** avoid any `": "` colon-space ([[skill-description-colon-space]] — it
  breaks YAML and the installer silently drops the skill); angle-bracket placeholders like
  `<question>` are fine ([[skill-description-angle-bracket-placeholders]]).

None open.
