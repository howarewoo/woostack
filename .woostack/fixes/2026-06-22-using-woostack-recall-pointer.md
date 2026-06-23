---
type: fix
status: hardened
branch: fix/using-woostack-recall-pointer
---

# Fix: using-woostack never tells the agent to recall memory for non-command work

## 1. Root Cause

`using-woostack` is the project entry point — the skill every woostack repo loads first
from its root `AGENTS.md`. Its **Project Entry Check** (`skills/using-woostack/SKILL.md`,
the numbered list under `## Project Entry Check`) runs four steps: read `AGENTS.md` → follow
its woostack policy → map the request to a `/woostack-*` command → load the mapped skill.
Then it stops.

Recall of the scoped `.woostack/memory/` store is owned **only** by skills that carry their
own recall step — `woostack-review`, `woostack-execute`, `woostack-ask`, `woostack-debug`.
When the user's request maps to **no** command but the agent still answers a question or
makes an edit grounded in the project's accumulated knowledge, no skill with a recall step is
loaded, so the memory store is never consulted. The accumulated `decision`/`pattern`/`gotcha`/
`convention` notes — the whole point of the scoped store — are silently skipped for ad-hoc
adoption work.

**Evidence.** `grep -nE "recall|woostack-ask|\.woostack/memory" skills/using-woostack/SKILL.md`
returns nothing inside the entry check. The only memory mentions in the file are incidental:
"summarize the workflow from memory" (human memory, line 38), the `woostack-dream` routing row,
and a Red Flags note that review/address flows "have … memory rules." None of them tell the
agent to recall before answering or editing from the store.

This matches the Phase-3 finding of the preceding `/woostack-ask`: the legitimate gap behind
"let the agent use memory" is that recall only fires inside recall-owning commands; the right
shape to close it is a **read-only pointer** (a cross-link to the one memory contract), not a
memory-mechanics section and not freeform write/retrieve tools — those would bypass the derived
index, scope routing, the reject-by-default write gate, and the `doctor.sh` lints, and reopen
the soft-discretion failure mode that [[autonomy-needs-structural-proof]] warns against.

## 2. Proposed Fix

Add a recall **pointer** to `using-woostack`. It is a cross-link to the canonical memory
contract — never a restatement of recall mechanics (repo "cross-link, do not duplicate"
constraint; the contract's single home is `skills/woostack-init/references/memory.md`). Two
small, coherent edits to `skills/using-woostack/SKILL.md`:

### Edit A — Project Entry Check: new step 5 (the pointer itself)

Insert after the current step 4 ("Load the mapped skill before asking clarifying questions …"),
before the "Do not run `/woostack-init` …" paragraph:

```markdown
5. If the request maps to **no** woostack command but you will still answer or edit from the
   project's accumulated knowledge, **recall first** (read-only). Load the scoped
   `.woostack/memory/` notes for your working set via the procedure in
   [`../woostack-init/references/memory.md`](../woostack-init/references/memory.md):
   script-assisted when the `woostack-init` scripts are present, the manual fallback otherwise,
   skipped when `.woostack/memory/` is absent. For a read-only question prefer
   [`/woostack-ask`](../woostack-ask/SKILL.md), which owns this recall. Recall never writes —
   distillation and curation stay owned by `woostack-execute`, `woostack-address-comments`, and
   `woostack-dream`.
```

Scoping it to "maps to no woostack command" is deliberate: mapped skills already own their
recall, so this never causes a double-recall and never overrides a skill's own context-loading.

### Edit B — Red Flags: one reinforcing row

Add a row to the `## Red Flags` table (structural reinforcement — the doc already pairs an
entry-check rule with a red-flag row, e.g. the `/woostack-init` scaffolding rule appears in
both; and [[autonomy-needs-structural-proof]] says state a load-bearing pointer in more than
one place):

```markdown
| "I'll answer straight from the `.woostack/` store." | Recall the scoped memory for your working set first (read-only) per [`memory.md`](../woostack-init/references/memory.md); for a read-only question use `/woostack-ask`. |
```

### Out of scope (considered, deliberately not done)

- No memory-mechanics section in `using-woostack` (would duplicate `memory.md`).
- No generic write/retrieve memory tools (would bypass index, scope routing, write gate, doctor).
- No change to the command surface / count → `[[woostack-command-surface-bookkeeping]]` sites
  are **not** touched (no command added or removed).
- No authored `site/` page edit: the skill surface, build loop, concepts, and getting-started
  flow are unchanged; the per-skill reference page regenerates from this `SKILL.md` at build time.

## 3. Implementation Plan

- [ ] **Step 1: Reproduce the gap (red)**
  - Show the absence before editing:
    `grep -nE "recall|woostack-ask|\.woostack/memory" skills/using-woostack/SKILL.md`
    returns nothing in the Project Entry Check (the failing condition).
- [ ] **Step 2: Apply Edit A and Edit B**
  - Insert the entry-check step 5 and the Red Flags row exactly as in §2. Keep every asserted
    phrase on **one physical line** (no soft-wrap mid-phrase) per [[grep-assertion-single-physical-line]],
    so the Step 3 grep checks can't fail-green.
- [ ] **Step 3: Verification (green) — concrete, no test runner**
  - `grep -q 'woostack-init/references/memory.md' skills/using-woostack/SKILL.md`
  - `grep -q '/woostack-ask' skills/using-woostack/SKILL.md`
  - `grep -q 'recall first' skills/using-woostack/SKILL.md`
  - Links resolve: `test -f skills/woostack-init/references/memory.md` and
    `test -f skills/woostack-ask/SKILL.md`
  - Sanity: the change is additive (entry-check steps 1–4 and existing Red Flags rows unchanged).
