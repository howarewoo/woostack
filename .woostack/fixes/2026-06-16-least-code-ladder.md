---
type: fix
status: approved
branch: fix/least-code-ladder
---

# Fix: No generation-time least-code guidance — over-build is caught only in review

## 1. Root Cause

woostack's minimalism doctrine is **entirely review-side**: the `architecture` review angle
hunts missed deletions, thin abstractions, and copy-paste-over-extraction
(`skills/woostack-review/prompts/angles/architecture.md`), and the execute-phase
`quality-reviewer.md:22` checks "dead code; duplication (DRY); needless complexity (YAGNI)."
All of that fires **after** the diff already exists.

There is no guidance at **generation time** telling the implementer to reach for the least code
that already exists *before* writing custom code. `implementer.md`'s `## How to work` step 2 says
only "Implement exactly the task — no more, no less" — a scope guard, not a build-order ladder.
`woostack-ideate` cuts unneeded *features* (`YAGNI ruthlessly`) but says nothing about preferring
an existing solution (stdlib / native / installed dep) over a new abstraction.

Net: over-build is **caught in review, never prevented**. This fix adds the missing
prevention-time guidance. Inspired by the ponytail skill's "best code is the code you never
wrote" philosophy; complements (does not duplicate) the diff-scoped `architecture` angle.

## 2. Proposed Fix

Two altitude-distinct prose additions. **No shared reference file** — the two statements sit at
different altitudes (code-generation vs design) and parse no shared value, so a new canonical doc
would itself be over-engineering (it would manufacture a `[[lockstep-edit-sites]]` multi-site
contract to dedupe ~12 lines). The fix embodies its own ladder: smallest change that works.

### Change A — `skills/woostack-execute/prompts/implementer.md` (canonical, generation-time)

The ladder **must** land *inside* the fenced subagent-prompt blob (the ` ```` ` … ` ```` ` block)
or it never reaches the implementer subagent. Anchor = the existing `## How to work` step 2.
Expand that one step in place (no new section):

> 2. Implement exactly the task — no more (no extra flags, files, or features), no less. Reach for
>    the **least code that already exists** before writing your own — in order: **skip it** (YAGNI —
>    if the task doesn't require it, don't build it) → **language standard library** → a **native
>    platform/framework feature** → an **already-installed dependency** → a **one-liner** → and only
>    then **minimal custom code**. Never trade away **security, accessibility, data-loss, or
>    trust-boundary** handling to shrink code — those are never on the chopping block.

### Change B — `skills/woostack-ideate/SKILL.md` `## Key principles` (design-time nudge)

Add one bullet immediately after the existing `**YAGNI ruthlessly.**` line:

> - **Least code wins.** Prefer the smallest solution that already exists — stdlib, a native
>   feature, an installed dependency — before proposing a new abstraction or dependency.

### Out of scope (explicit scope guard)

- **No** whole-repo over-engineering audit (conflicts with woostack's diff-scoped doctrine).
- **No** ad-hoc shortcut / debt-ledger marker (conflicts with the `woostack-defer(<ref>)`
  increment-scoped contract).
- **No** new reference file and no structural/lockstep test: the two additions parse no shared
  value, so there is no multi-site joint for a test to pin (`[[lockstep-edit-sites]]`).
- **No** `site/` change (verified at harden): the per-skill `site/content/docs/skills/woostack-ideate.mdx`
  is **generated from `SKILL.md` and gitignored**, so Change B regenerates automatically; the authored
  `concepts.mdx` describes the loop at a high level ("implementer writes each task") and enumerates
  neither ideate's Key principles nor the implement-step ladder, so Changes A/B do not alter what it
  states. The change touches neither the skill surface/count, the build-loop gates, the core concepts,
  nor getting-started.

## 3. Implementation Plan

- [x] **Step 1: Pin the assertion (red).** Confirm the target phrases are currently ABSENT, so the
      edit has a verifiable before/after (docs edit → structural assertion in place of a failing
      test, per `implementer.md` step 1):
  - `grep -c "least code that already exists" skills/woostack-execute/prompts/implementer.md` → `0`
  - `grep -c "Least code wins" skills/woostack-ideate/SKILL.md` → `0`
- [x] **Step 2: Apply Change A.** Edit `skills/woostack-execute/prompts/implementer.md` — expand
      `## How to work` step 2 to the ladder text in §2 above, **inside** the fenced blob. Preserve
      the `tier: standard` frontmatter and the surrounding numbered list.
- [x] **Step 3: Apply Change B.** Edit `skills/woostack-ideate/SKILL.md` — add the `Least code wins.`
      bullet under `## Key principles`, directly after `**YAGNI ruthlessly.**`.
- [x] **Step 4: Verify (green).** Assert the additions landed correctly and stayed in scope:
  - `grep -c "least code that already exists" skills/woostack-execute/prompts/implementer.md` → `1`
  - `grep -c "Least code wins" skills/woostack-ideate/SKILL.md` → `1`
  - Ladder is inside the fenced blob: the `least code that already exists` line falls between the
    opening ` ```` ` and closing ` ```` ` of `implementer.md`'s prompt block (e.g. confirm via
    `awk` range or visual read — it sits within `## How to work`, which is inside the blob).
  - Protected zones present: `grep -c "trust-boundary" skills/woostack-execute/prompts/implementer.md` → `1`.
  - No stray files / scope creep: `git status --porcelain` shows only the two edited skill files
    (plus this fix doc); no new reference file, no `site/` change.
