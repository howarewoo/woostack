---
type: fix
status: hardened
branch: fix/memory-rides-fix-commit
---

# Fix: woostack-fix strands distilled memory in the primary tree instead of committing it with the fix

**Base:** stacked on `fix/fix-closeout-invariant` (the in-flight branch that owns the step-6
closeout paragraph and `test-closeout-invariant.sh`), not `main` — the false sentence exists on
both, and that branch defines the final step-6 text, so fixing it there is the durable fix and
avoids a same-paragraph merge conflict.

## 1. Root Cause

`woostack-fix` delegates execution (and therefore the memory distill) to `woostack-execute`.
Every other document in the collection agrees that distilled memory notes are **tracked**,
written **inside the per-PR worktree**, and **ride the increment/fix commit** — only the
gitignored sidecars (`metrics.json`, `.telemetry.tsv`, the dream watermark) target the primary
tree via the `WOOSTACK_ROOT` export:

- worktree contract §3 — "Tracked memory notes are written in the worktree and ride the
  increment's commit."
- worktree contract §5 — "Memory notes and `MEMORY.md` are tracked, so they are written in the
  worktree and committed with the increment"; `metrics.json`, telemetry, and watermark sidecars
  are the primary-root local state.
- `woostack-execute` step 7 / "Memory Is Shared" — the distill "runs inside the per-PR worktree,
  and tracked memory notes are written there … let the note plus index ride the increment's
  `woostack-commit`."
- memory contract §2 — memory notes and `MEMORY.md` are tracked team knowledge; only
  `metrics.json`, `*.local.*`, `.telemetry.tsv`, and `.dream-watermark` are gitignored.

But `skills/woostack-fix/SKILL.md` step 6 (the closeout paragraph) contradicts all of them:

> The memory distill (run by `woostack-execute` in step 5) targets the primary tree via the
> `WOOSTACK_ROOT` export of the worktree contract §5, so it survives teardown.

**Evidence:** `grep -rn "targets the primary tree" skills/` returns exactly one hit —
`skills/woostack-fix/SKILL.md` — and the surrounding line reads "the memory distill … targets the
primary tree." An agent following this false instruction writes the distilled note into the
primary tree (outside the fix worktree). There it is never part of the `fix/<slug>` commit, so it
lands uncommitted in the primary working tree — exactly the reported symptom ("the fix skill keeps
creating memories outside of its worktree"). The correct behavior (memory rides the fix commit) is
what makes the learning ship inside the one fix PR.

## 2. Proposed Fix

Rewrite the false sentence in `skills/woostack-fix/SKILL.md` step 6 so it matches the worktree
contract and `woostack-execute`:

- The memory distill writes tracked `.woostack/memory/` notes and the rebuilt `MEMORY.md` **inside
  the fix worktree**, so they **ride the fix commit into the one PR** — the durable learning is
  **committed with the fix**, not stranded in the primary tree.
- Only the gitignored sidecars (`metrics.json`, `.telemetry.tsv`, the dream watermark) target the
  primary tree via the `WOOSTACK_ROOT` export of the worktree contract §5 and survive teardown.

Scope is one sentence in one file. No behavior code changes; the bug is a doc instruction that
misdirects the distill write path. The docs-site per-skill page for woostack-fix is generated from
`SKILL.md` and gitignored, and no authored `site/` page repeats the claim, so no site edit is
required.

## 3. Implementation Plan

- [ ] **Step 1: Reproduce with a failing test**
  - Add `skills/woostack-fix/scripts/tests/test-memory-in-worktree.sh` (mirroring
    `test-closeout-invariant.sh`: source `skills/woostack-init/scripts/tests/assert.sh`, read
    `skills/woostack-fix/SKILL.md` into `$body`). **Single-quote every needle** containing
    backticks so bash does not run `` `woostack-execute` `` as a command substitution.
  - `assert_not_contains "$body" 'distill (run by `woostack-execute` in step 5) targets the primary tree'`
    — the false claim must be gone.
  - `assert_contains "$body" "ride the fix commit"` — the corrected text asserts memory rides the
    fix commit.
  - `assert_contains "$body" "committed with the fix"` — the learning is committed with the fix,
    not stranded in the primary tree.
  - `assert_contains "$body" "inside the fix worktree"` — pins where the distill writes.
  - Run it against the current SKILL.md → RED (the file still contains the false sentence and none
    of the corrected phrases).

- [ ] **Step 2: Apply the minimal fix**
  - In `skills/woostack-fix/SKILL.md` step 6, replace the "memory distill … targets the primary
    tree … so it survives teardown" sentence with the corrected two-part statement from §2
    (memory rides the fix commit; only the gitignored sidecars target the primary tree via
    `WOOSTACK_ROOT` and survive teardown).

- [ ] **Step 3: Verification**
  - Run `bash skills/woostack-fix/scripts/tests/test-memory-in-worktree.sh` → GREEN.
  - Run `bash skills/woostack-fix/scripts/tests/test-closeout-invariant.sh` → still GREEN
    (closeout teardown wording untouched).
