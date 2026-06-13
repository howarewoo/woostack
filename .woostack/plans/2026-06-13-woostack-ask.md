**Source:** .woostack/specs/2026-06-13-woostack-ask.md

# woostack-ask — read-only codebase Q&A — Implementation Plan

**Goal:** Add a public `/woostack-ask <question>` skill — a purely investigative, read-only Q&A command wired into the woostack memory/knowledge framework — and register it on the command surface.

**Architecture:** One prose-only `skills/woostack-ask/SKILL.md` (no scripts, no `references/`), modeled on `woostack-debug` (autonomous, recall-at-start, investigative-only) and positioned as the read-only twin of `woostack-dream`. Increment 1 ships the skill; Increment 2 wires it across the drift-prone command-surface bookkeeping sites. Verification is structural (grep / frontmatter parse / `git status`), since a prose skill has no test runner.

**Tech Stack:** Markdown skill assets; bash verification (grep, `git status`); Graphite (`gt`) for stacked PRs. Reuses `woostack-init` scripts (`recall.sh`, `scope-match.sh`) at runtime — none added here.

---

## Increment 1: woostack-ask SKILL.md

> One independently shippable PR (≤500 LOC soft target) — its own Graphite-stacked branch on the spec+plan base. The "missing from routing / surface lists" review finding is **expected** here and completed by Increment 2 (accepted skill-add → stacked-wiring split per [[woostack-review-is-not-stack-aware-224-a-skill-add-pr-may-de]]).

### Task 1: Author `skills/woostack-ask/SKILL.md`

**Files:**
- Create: `skills/woostack-ask/SKILL.md`

- [x] **Step 1: Confirm the file does not yet exist (red)**

Run: `test -f skills/woostack-ask/SKILL.md && echo EXISTS || echo ABSENT`
Expected: `ABSENT`

- [x] **Step 2: Create the skill file with this exact content**

```markdown
---
name: woostack-ask
description: "Use as woostack's read-only investigation phase — answer a question about the codebase grounded in the .woostack knowledge surface (recall the scoped memory store, wholesale-load wisdom/ when present, then read the rest of the .woostack/ artifact tree — specs, plans, fixes, overnight, visuals, and any future store), plus repo code and, when the question calls for it, external references. Cites its evidence and hands the answer back; chains nothing. Invoke via /woostack-ask <question>. Investigative only — autonomous is its sole mode (no flag), and it never writes code, files, memory notes, commits, or merges."
---

# woostack-ask

Answer a question about the codebase, read-only. This is woostack's own investigation phase: the
place to ask "how does X work", "where does Y live", or "what would it take to integrate Z" and
get an answer grounded in the project's accumulated knowledge — without any risk of a write. It is
the investigative twin of [`woostack-debug`](../woostack-debug/SKILL.md) (which root-causes a bug)
and the **read-only twin of** [`woostack-dream`](../woostack-dream/SKILL.md) (which curates the
same corpus with writes and a gate). woostack-ask owns no approval gate, never writes anything, and
hands the answer back.

It is a public command — `/woostack-ask <question>` — with no internal callers. It always runs
autonomously: there is no interactive mode and no flag.

<WRITE-BLOCK>
woostack-ask NEVER writes. No code, no `.woostack/` artifacts (specs, plans, fixes, memory notes),
no commits, no merges — zero tracked writes, for EVERY request regardless of perceived simplicity.
If answering seems to require a change, describe the change and name the command that makes it
(e.g. `/woostack-build`, `/woostack-fix`); do not make it. The one inherited benign side effect is
`recall.sh`'s gitignored telemetry sidecar (best-effort, non-fatal) — `git status` stays clean.
</WRITE-BLOCK>

## When to use

Any read-only question about this codebase: how a subsystem works, where something lives, why a
decision was made, what a spec/plan/fix says, or whether an external project has something worth
adopting. Use it instead of an unscoped agent whenever you want an answer with **no chance of an
edit**. For a bug's root cause use [`woostack-debug`](../woostack-debug/SKILL.md); to curate the
knowledge store use [`woostack-dream`](../woostack-dream/SKILL.md).

## Knowledge surface (all read-only)

woostack-ask reads **wider** than the scoped recall other skills use. `woostack-review` /
`woostack-execute` load a narrow per-working-set context; woostack-ask uses recall as an *entry
point* but reaches the whole `.woostack/` tree, because answering can need the full decision
history. Enumerate `.woostack/` subdirs **dynamically** — never hardcode the list — so future
stores are automatically in scope.

| Source | How read |
|---|---|
| `.woostack/memory/` | recall procedure (memory contract §6) — `recall.sh` when init scripts present, else the manual fallback. Entry point. |
| `.woostack/wisdom/` | **wholesale-load** every `wisdom/*.md` when the directory exists; skip when absent. Consumer of the dream-wisdom store; ask only reads it. |
| `.woostack/specs/ plans/ fixes/ overnight/ visuals/` | **direct read on demand**, by relevance (grep/glob). Specs and plans are recall-excluded by type, so a direct read is the only way to reach them. |
| future `.woostack/<new>/` subdirs | enumerated dynamically alongside the above. |
| repo code | Read / Grep / Glob; follow existing patterns. |
| external references | WebFetch / WebSearch, only when the question names or implies them. Reads pull content **in**; never send codebase content out. |

## The four phases

### Phase 1 — Recall
Infer the working set from the question (the files / skill dirs it implicates). Run the recall
procedure; wholesale-load `wisdom/` if present; surface the matching notes before investigating —
a note may already answer the question. State whether recall was script-assisted or manual; never
fail silently.

### Phase 2 — Investigate (read-only)
Explore the evidence: repo code, the relevant `.woostack/` artifacts, and — when the question
calls for it — external sources. Scope the investigation to the question (YAGNI on breadth); read
what the answer needs, not the whole repo. Gather concrete evidence: `file:line`, note names,
artifact paths, URLs.

### Phase 3 — Synthesize
Answer the question directly, citing every claim, and mark what is grounded vs inferred. For an
"integration-benefit" question (e.g. "benefits we could integrate from `<external repo>` into our
skill library"): enumerate the candidate benefits → map each to where it would land in the skill
library → flag overlap or conflict with existing skills → give a recommendation. Propose no
implementation.

### Phase 4 — Handback
The answer lives in the conversation. Offer a [`woostack-visualize`](../woostack-visualize/SKILL.md)
render on request (pick the audience that fits). If the answer implies action, name the next
command for the user to run. Chain nothing.

## Operation

Running `/woostack-ask <question>` works Phases 1–4 end to end and hands back the answer — no gate,
no flag, autonomous only.

- **No question given.** `/woostack-ask` with no argument → ask what the user wants to know; do not
  guess (mirror `woostack-debug`).

## Memory

woostack-ask **recalls** the scoped `.woostack/memory/` store and **never distills** — the note
schema, recall procedure, and degradation contract are defined once in
[memory.md](../woostack-init/references/memory.md); this says only how ask uses them.

- **Recall (start).** Compute the working set from the question; run recall: `recall.sh` when the
  `woostack-init` scripts are present, the manual procedure (load `MEMORY.md` + scope-match +
  one-hop link expand) otherwise. State script-assisted vs manual.
- **No distill.** woostack-ask writes nothing, so it never creates or updates a note. Distillation
  stays owned by `woostack-execute`; curation by `woostack-dream`.

## Degradation

- **No `.woostack/`** → report there is no memory/corpus to recall; answer from repo code (and
  external) only; never scaffold (defer to `/woostack-init`).
- **Init scripts missing** (individual install) → announce the manual recall fallback (memory
  contract §10); never fail silently.
- **A subdir is absent** (`wisdom/`, `overnight/`, …) → skip it, note the gap, continue.
- **External fetch fails / blocked / private** → report it; answer from reachable evidence; never
  fabricate.
- **Non-git checkout** → filesystem reads still work; recall telemetry is best-effort.

## Hard constraints

- **WRITE-BLOCK.** Zero tracked writes — no code, artifacts, memory notes, commits, or merges. Keep
  this prominent so it survives summarization.
- **Recall-only memory.** Reads the store; never distills. Distillation belongs to
  `woostack-execute`, curation to `woostack-dream`.
- **Reads the whole `.woostack/` tree, enumerated dynamically.** Beyond scoped recall; never
  hardcode the subdir list.
- **Cite evidence; no fabrication.** Mark grounded vs inferred; external reads pull in, never push
  out.
- **Autonomous, owns no gate, chains nothing.** Answering is terminal; name the next command rather
  than running it.
- **Owns no spec/plan/status.** The phase enum and join contracts live in
  [conventions.md](../woostack-status/references/conventions.md) — link, never restate.
```

- [x] **Step 3: Verify the file exists and the frontmatter is installer-safe (green)**

Run:
```bash
test -f skills/woostack-ask/SKILL.md && echo EXISTS
# description is double-quoted (neutralizes the ": " colon-space ScannerError, [[skill-description-colon-space]]):
grep -nE '^description: ".*"$' skills/woostack-ask/SKILL.md && echo DESC_QUOTED
# name slug present:
grep -nx 'name: woostack-ask' skills/woostack-ask/SKILL.md && echo NAME_OK
```
Expected:
```
EXISTS
<line>:description: "Use as woostack's read-only investigation phase — ...merges."
DESC_QUOTED
<line>:name: woostack-ask
NAME_OK
```

- [x] **Step 4: Verify the core invariants are present (green)**

Run:
```bash
grep -c 'WRITE-BLOCK' skills/woostack-ask/SKILL.md          # expect >=2 (block + hard constraint)
grep -q 'wholesale-load' skills/woostack-ask/SKILL.md && echo WISDOM_OK
grep -q 'recall procedure' skills/woostack-ask/SKILL.md && echo RECALL_OK
grep -q 'enumerated dynamically' skills/woostack-ask/SKILL.md && echo ENUM_OK
grep -q 'no flag' skills/woostack-ask/SKILL.md && echo AUTONOMOUS_OK
```
Expected: a count `>= 2`, then `WISDOM_OK`, `RECALL_OK`, `ENUM_OK`, `AUTONOMOUS_OK`.

- [x] **Step 5: Confirm no stray writes, then commit**

Run: `git status --porcelain` → Expected: only `?? skills/woostack-ask/SKILL.md` (plus the already-committed `.woostack/` spec+plan on the base branch; nothing else).
```bash
gt create -m "feat(ask): woostack-ask read-only codebase Q&A skill"
```

---

## Increment 2: register woostack-ask on the command surface

> One independently shippable PR stacked on Increment 1. Wires every drift-prone bookkeeping site in lockstep ([[woostack-command-surface-bookkeeping]]): 16 → **17** public commands, 18 → **19** `SKILL.md` files. README and `development.md` are verified no-ops.

### Task 1: AGENTS.md (six sub-edits; `.claude/CLAUDE.md` is a symlink, so editing AGENTS.md updates both)

**Files:**
- Modify: `AGENTS.md`

- [ ] **Step 1: Bump the surface count**

Replace:
`The public command/adoption surface has sixteen skills:`
With:
`The public command/adoption surface has seventeen skills:`

- [ ] **Step 2: Add the public-list bullet (after the woostack-debug bullet)**

Replace:
```
- [`woostack-debug`](skills/woostack-debug/SKILL.md)
- [`woostack-tdd`](skills/woostack-tdd/SKILL.md)
```
With:
```
- [`woostack-debug`](skills/woostack-debug/SKILL.md)
- [`woostack-ask`](skills/woostack-ask/SKILL.md)
- [`woostack-tdd`](skills/woostack-tdd/SKILL.md)
```

- [ ] **Step 3: Update the "N-skill command surface" phrase**

Replace:
`they have no routing row and are absent from the sixteen-skill command surface above.`
With:
`they have no routing row and are absent from the seventeen-skill command surface above.`

- [ ] **Step 4: Add `/woostack-ask` to the Mode B trigger list**

Replace:
`` `/woostack-review`, `/woostack-address-comments`, `/woostack-status`, `/woostack-visualize`, `/woostack-debug`, `/woostack-dream`, or ``
With:
`` `/woostack-review`, `/woostack-address-comments`, `/woostack-status`, `/woostack-visualize`, `/woostack-debug`, `/woostack-ask`, `/woostack-dream`, or ``

- [ ] **Step 5: Update the rename-constraint count (appears once, two numbers)**

Replace:
`- Do not move or rename any of the eighteen `SKILL.md` files (the sixteen public command/adoption`
With:
`- Do not move or rename any of the nineteen `SKILL.md` files (the seventeen public command/adoption`

- [ ] **Step 6: Add the Quick file map entry (after the systematic-debugging entry)**

Replace:
```
- Systematic-debugging engine (public command + internal hook invoked by execute/review):
  [`skills/woostack-debug/SKILL.md`](skills/woostack-debug/SKILL.md)
```
With:
```
- Systematic-debugging engine (public command + internal hook invoked by execute/review):
  [`skills/woostack-debug/SKILL.md`](skills/woostack-debug/SKILL.md)
- Read-only codebase Q&A engine (public command; investigative, never writes):
  [`skills/woostack-ask/SKILL.md`](skills/woostack-ask/SKILL.md)
```

- [ ] **Step 7: Verify AGENTS.md is consistent (green)**

Run:
```bash
grep -c 'seventeen' AGENTS.md            # expect 3 (L17 surface count + L40 phrase + L94 "seventeen public")
grep -c 'nineteen' AGENTS.md             # expect 1 (rename constraint "nineteen SKILL.md files")
grep -c 'sixteen\|eighteen' AGENTS.md    # expect 0 (no stale counts remain)
grep -c 'woostack-ask' AGENTS.md         # expect 3 (public bullet + Mode B + file-map link line)
```
Expected: `3`, `1`, `0`, `3`.

### Task 2: using-woostack Command Routing row

**Files:**
- Modify: `skills/using-woostack/SKILL.md`

- [ ] **Step 1: Insert the routing row (after the woostack-debug row)**

Replace:
`` | `/woostack-debug <target>`, run an autonomous root-cause analysis before fixing (investigative only — hands back the root cause and a proposed fix) | `woostack-debug` | ``
With:
```
| `/woostack-debug <target>`, run an autonomous root-cause analysis before fixing (investigative only — hands back the root cause and a proposed fix) | `woostack-debug` |
| `/woostack-ask <question>`, answer a read-only question about the codebase grounded in the .woostack knowledge surface (investigative only — never writes) | `woostack-ask` |
```

- [ ] **Step 2: Verify (green)**

Run: `grep -c 'woostack-ask' skills/using-woostack/SKILL.md`
Expected: `1`

### Task 3: CONTRIBUTING.md (two sub-edits)

**Files:**
- Modify: `CONTRIBUTING.md`

- [ ] **Step 1: Add to the intro public-surface list (after woostack-debug)**

Replace:
`` `woostack-status`, `woostack-visualize`, `woostack-debug`, `woostack-tdd`, and `woostack-dream`. ``
With:
`` `woostack-status`, `woostack-visualize`, `woostack-debug`, `woostack-ask`, `woostack-tdd`, and `woostack-dream`. ``

- [ ] **Step 2: Add the "What to change" pointer row (after the woostack-debug row)**

Replace:
`` | Change the systematic-debugging behavior (`/woostack-debug`) | `skills/woostack-debug/SKILL.md` | ``
With:
```
| Change the systematic-debugging behavior (`/woostack-debug`) | `skills/woostack-debug/SKILL.md` |
| Change the read-only codebase Q&A command (`/woostack-ask`) | `skills/woostack-ask/SKILL.md` |
```

- [ ] **Step 3: Verify (green)**

Run: `grep -c 'woostack-ask' CONTRIBUTING.md`
Expected: `2`

### Task 4: Verify README.md and development.md need no change (no-op confirmation)

- [ ] **Step 1: Confirm README's command list is exemplary, not an exhaustive count**

Run: `grep -n 'registers the public skills' README.md`
Expected: a line containing `(e.g. ... etc.)` — exemplary, no count and no per-command sections for inspection commands (status/debug/dream are likewise absent). No change required.

- [ ] **Step 2: Confirm development.md has no per-command loop row to update**

Run: `grep -nc 'woostack-debug\|woostack-status\|woostack-ask' skills/woostack-bootstrap/references/development.md`
Expected: `0` — the loop summary is generic; inspection commands are not loop phases, so this stays a no-op (consistent with [[woostack-command-surface-bookkeeping]]).

### Task 5: Final surface consistency + commit

- [ ] **Step 1: Cross-file consistency check (green)**

Run:
```bash
# every surface site references the new command:
for f in AGENTS.md CONTRIBUTING.md skills/using-woostack/SKILL.md; do
  printf '%s: ' "$f"; grep -c 'woostack-ask' "$f"
done
# the skill dir from Increment 1 is present:
test -f skills/woostack-ask/SKILL.md && echo SKILL_PRESENT
```
Expected: `AGENTS.md: 3`, `CONTRIBUTING.md: 2`, `skills/using-woostack/SKILL.md: 1`, `SKILL_PRESENT`.

- [ ] **Step 2: Confirm clean tree apart from the wiring edits, then commit**

Run: `git status --porcelain` → Expected: only `M AGENTS.md`, `M CONTRIBUTING.md`, `M skills/using-woostack/SKILL.md` (AGENTS.md edit also covers the `.claude/CLAUDE.md` symlink).
```bash
gt create -m "docs(ask): register woostack-ask on the command surface"
```

---

## Self-review (run before handing back)

- [ ] **Spec coverage** — §2 goal (skill + full knowledge surface + zero writes + 17th command) → Inc 1 Task 1 + Inc 2 Tasks 1-5. §5 knowledge-surface table → SKILL.md "Knowledge surface" table. §6 error handling → SKILL.md "Degradation".
- [ ] **AC coverage** — AC1 write-block → WRITE-BLOCK block + Inc1 Step 5 / Inc2 Step (clean `git status`); AC2 recall → "Memory" + Phase 1; AC3 full `.woostack/` reach → "Knowledge surface" (direct read + dynamic enumeration + wisdom skip); AC4 external refs → Phase 3 integration-benefit flow + surface table; AC5 surface registered → Inc 2 Tasks 1-3 verified, gating-test clause N/A (no test exists), description-format edge → Inc1 Step 3 `DESC_QUOTED`.
- [ ] **No placeholders** — full SKILL.md embedded; every wiring edit is an exact replace with expected grep counts.
- [ ] **Type consistency** — command name `woostack-ask` / `/woostack-ask <question>` and link paths (`../woostack-*/SKILL.md`, `../woostack-init/references/memory.md`, `../woostack-status/references/conventions.md`) consistent across SKILL.md, routing row, and surface edits.

> woostack plan conventions: frontmatter-free; opens with `**Source:**`; basename mirrors the spec (`2026-06-13-woostack-ask`); no sub-skill banner; in a runner-less target each "failing test" is a concrete grep/parse verification with exact expected output.
