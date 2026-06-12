---
type: fix
status: in-review
branch: fix/overnight-report-double-date
---

# Fix: Overnight reports get a doubled date in their filename

## 1. Root Cause

`woostack-execute-overnight` names its morning report
`.woostack/overnight/YYYY-MM-DD-<plan-basename>.md` (SKILL.md lines 63 and 115). It
unconditionally prefixes **today's date** to the **plan basename**.

But the plan basename already starts with a date: `woostack-plan` saves the plan to
`.woostack/plans/<spec-basename>.md` and that basename is, by contract, the **same
`YYYY-MM-DD-<slug>`** as the spec (woostack-plan SKILL.md lines 135–136 — "reuse the spec's
date"). So `<plan-basename>` = `YYYY-MM-DD-<slug>`, and prefixing another `YYYY-MM-DD-`
produces two dates:

```
plan basename:   2026-06-12-memory-vault
report path:     .woostack/overnight/2026-06-12-2026-06-12-memory-vault.md   ← doubled
```

**Evidence:** the doubled pattern is authored in exactly two places, both in
`skills/woostack-execute-overnight/SKILL.md`:

- line 63 — the "Open the report" pre-flight step
- line 115 — the "Morning report" section

`references/report-template.md` is **not** at fault — it uses `{{PLAN_BASENAME}}` as a display
token in the report body, not as the path. No automated test pins the report filename, so the
regression went unnoticed.

## 2. Proposed Fix

Change the documented report filename so the date is not doubled. The report is a **per-run**
artifact, so its filename should be keyed to the **run date** (when the overnight run happened),
not silently inherit the spec's authored date.

Replace `YYYY-MM-DD-<plan-basename>` at both sites with: the **run date** (`YYYY-MM-DD`, today)
joined to the plan basename **with any leading `YYYY-MM-DD-` stripped** (conditional — strip only
when the basename starts with a date, so a hand-authored dateless plan basename still gets a clean
single run-date prefix). Because the plan basename already begins with the spec's date, stripping
it before prefixing the run date yields a single, run-keyed date:

```
spec authored 2026-06-01, run overnight 2026-06-12:
  plan basename:  2026-06-01-memory-vault
  report path:    .woostack/overnight/2026-06-12-memory-vault.md   ← single date = run date
```

Add a one-line parenthetical at the canonical site (line 115) explaining the strip, so the
convention is self-documenting and the regression can't silently return.

This is a Mode A (skill-collection) edit: the bug lives in the instruction text, so the fix is
the corrected instruction. No script or template change is required.

## 3. Implementation Plan

No automated harness exercises the report path, and this is a doc-convention change, so the
TDD-first kernel is satisfied by a **concrete grep red→green** (woostack-tdd's no-runner carve-out)
rather than a committed test file.

- [x] **Step 1: Red — observe the doubled token**
  - Run `grep -n "YYYY-MM-DD-<plan-basename>" skills/woostack-execute-overnight/SKILL.md` and
    confirm it **matches** at both sites (lines 63 and 115). This is the failing/red state.
- [x] **Step 2: Apply the minimal fix**
  - Edit `skills/woostack-execute-overnight/SKILL.md` line 63 (pre-flight "Open the report") and
    line 115 ("Morning report") to use the **run-date + date-stripped-basename** naming. Add the
    explanatory parenthetical (why the strip exists) at the canonical site (line 115) so the
    convention is self-documenting and the regression can't silently return.
- [x] **Step 3: Green — verify**
  - `grep -rn "YYYY-MM-DD-<plan-basename>" skills/` returns **nothing** (the doubled token is gone
    everywhere).
  - Both edited passages name the run date and describe the conditional strip.
  - Sanity-read for cross-link/wording consistency with `report-template.md` (`{{PLAN_BASENAME}}`
    display token is unchanged and still correct) and `woostack-plan` SKILL.md §Filename.
