---
type: fix
status: in-review
branch: fix/address-comments-verdict-gate
---

# Fix: woostack-address-comments skips the verdict gate under low-effort models (issue #282)

## 1. Root Cause

The verdict gate is `woostack-address-comments`' single most important safety invariant — no
working-tree edit, commit, push, reply, resolve, or memory write may happen in the default
(non-`--auto`) flow until the user has approved the batched recommendations. But the gate
exists **only as soft, distributed prose inside the workflow body**, with two structural gaps
that let a low-effort/fast model (`gpt-5.3-codex-spark` in Codex CLI, issue #282) collapse the
Phase 1 → Phase 2 → Phase 3 narrative and go straight from analysis to applying fixes:

1. **No prominent STOP barrier.** Sibling gated skills carry a visually-prominent,
   skim/summary-resistant barrier — `using-woostack`'s `<EXTREMELY-IMPORTANT>`,
   `woostack-debug`'s `<IRON-LAW>`, `woostack-ideate`'s `<HARD-GATE>`. `address-comments` has
   **none**. The gate is only descriptive default prose (`SKILL.md:14-15` "By default it
   presents…"; the Phase 4 verdict-gate bullet `SKILL.md:49-54`; `prompts/address.md` Phase 2).
   Nothing structurally halts the model between "recommend" and "act."
2. **Gate absent from `## Hard constraints`.** `SKILL.md:68-71` lists only **No merge** and
   **No performative replies**. The most skim- and summarization-resistant section omits the
   gate entirely. Compare `woostack-fix`, whose Hard constraints restate it ("Wait for explicit
   approval. Never execute … on inferred or assumed approval. Silence is not a yes.") and whose
   Overview calls out "exactly **one** hard gate."

**Evidence.** `grep -riE 'STOP|HALT|HARD|IRON|never act|unapproved|silence is not'` over
`SKILL.md` + `prompts/` returns only the two soft mentions (`SKILL.md:51` non-interactive abort,
`prompts/address.md:95` "Never act unapproved") — both buried mid-paragraph. No barrier tag
exists in the skill, while `using-woostack`, `woostack-debug`, and `woostack-ideate` all have one.
Under `gpt-5.3-codex-spark` (the fast/low-effort "spark" tier) the body's Phase 1→2→3 sequence is
narrative-only, so the model proceeds analysis → apply, skipping render-and-wait.

This is a **prose-enforcement** root cause, not a code path: the contract is correct but is not
expressed where a low-effort model will reliably honor it.

## 2. Proposed Fix

Make the existing verdict-gate contract **structurally load-bearing** without changing its
mechanics. Three minimal, additive edits — no behavior change to the happy path, no new flags:

1. **Add a `<HARD-GATE>` barrier near the top of `SKILL.md`** (mirroring
   `woostack-ideate`'s, immediately after the Overview): in the default flow you MUST present
   the verdict gate and obtain explicit user approval **before any** working-tree edit, commit,
   push, reply, resolve, or memory write; only `--auto` skips it; a non-interactive host with no
   `--auto` aborts rather than acting; silence is not approval. This applies to EVERY run
   regardless of perceived simplicity or model speed.
2. **Add a `## Hard constraints` bullet** restating the gate so the most skim-resistant section
   carries it: "**Wait for explicit approval.** Never apply fixes, commit, push, reply, resolve,
   or write memory on inferred approval … Silence is not a yes."
3. **Reinforce `prompts/address.md` Phase 2** with an explicit one-line STOP cue at the top of
   the phase so the Phase 1→3 narrative cannot collapse for a worker-fan-out / low-effort run.

## 3. Implementation Plan

**Hardened decisions** (resolved by exploring the repo, no behavior change):
- **Barrier tag = `<HARD-GATE>`**, placed at the end of `## Overview` (after the overview
  prose, before `## Workflow`) — mirrors `woostack-ideate`'s gate placement.
- **ASCII assertion tokens** per memory `skill-test-assert-ascii-token` (recall 46): keep any
  readable em-dash in the prose, but assert pure-ASCII substrings — `<HARD-GATE>`,
  `Silence is not a yes`, and `do not act until approved`.
- **Test home** = extend the existing `test-address-comments-ownership.sh` (already the
  SKILL/prompt content-assertion test), not a new file.
- **`--auto` carve-out preserved**: the barrier explicitly states `--auto` skips the gate and a
  non-interactive host with no `--auto` aborts — so autonomous use is unchanged.

- [x] **Step 1: Reproduce with a failing test**
  - Extend `skills/woostack-address-comments/scripts/tests/test-address-comments-ownership.sh`
    with three `assert_contains` calls pinning the gate's structural presence:
    - `assert_contains "$ADDRESS_SKILL" "<HARD-GATE>"`
    - `assert_contains "$ADDRESS_SKILL" "Silence is not a yes"`
    - `assert_contains "$ADDRESS_PROMPT" "do not act until approved"`
  - Run the test and confirm it **fails** (tokens absent today).
- [x] **Step 2: Apply the minimal fix**
  - Add the `<HARD-GATE>` block at the end of `SKILL.md`'s `## Overview` (before `## Workflow`):
    default flow MUST present the verdict gate and get explicit approval before ANY working-tree
    edit, commit, push, reply, resolve, or memory write; only `--auto` skips it; non-interactive
    + no `--auto` aborts; silence is not approval; the gate is never delegated to fan-out workers.
  - Add a `## Hard constraints` bullet: **Wait for explicit approval.** Never apply fixes,
    commit, push, reply, resolve, or write memory on inferred approval … `Silence is not a yes.`
  - Add an explicit one-line STOP cue to `prompts/address.md` Phase 2 containing the ASCII
    substring `do not act until approved`.
- [x] **Step 3: Verification**
  - Re-run `test-address-comments-ownership.sh` and the sibling `test-address-worker-contract.sh`
    — all pass.
  - Re-run the §1 `grep` and confirm a prominent barrier now exists.
