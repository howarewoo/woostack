---
type: plan
source: .woostack/specs/2026-06-12-output-discipline.md
status: done
branch: feature/output-discipline
---

**Source:** [[specs/2026-06-12-output-discipline]]

# Native Output Discipline for Internal Comms — Implementation Plan

**Goal:** Add one canonical cross-skill Output Discipline reference for internal comms, dedup the ≤100-char memory rule into it, and wire the four high-frequency channels to it by thin cross-link — without touching user-facing output or the review JSON contract.

**Architecture:** A single new reference `skills/using-woostack/references/output-discipline.md` is the source of truth (sibling of `model-tiers.md`, reached by relative-path cross-link like it). It is created first, then the two spelled-out ≤100-char copies collapse to cross-links (plus a one-line collision pointer in `_header.md`), then one-line pointers are added at the four core channels. ~145 LOC of pure docs → one increment. No app runtime exists, so every "test" is a concrete `grep`/`test` verification with exact expected output.

**Tech Stack:** Markdown skill assets; `grep`/`bash` for verification; Graphite (`gt`) for the stacked PR.

---

## Increment 1: Output Discipline reference + dedup + wire core channels

> One independently shippable PR (~145 LOC, pure docs) on the spec+plan base. Creates the canonical doc, removes the live 2-copy ≤100-char drift, and wires the four high-frequency channels. The doc is cross-linked by the dedup sites and the channel pointers, so it is never orphaned.

### Task 1: Create the canonical Output Discipline reference

**Files:**
- Create: `skills/using-woostack/references/output-discipline.md`

- [x] **Step 1: Write the failing verification**

Run: `test -f skills/using-woostack/references/output-discipline.md && echo FOUND || echo MISSING`
Expected: FAIL — prints `MISSING` (file not created yet).

- [x] **Step 2: Confirm it fails**

Run the command above; confirm output is `MISSING`.

- [x] **Step 3: Create the file with this exact content**

```markdown
# Output Discipline (internal comms)

Canonical rules for **internal** woostack communication — subagent→parent handbacks, swarm/worker reports, and memory/log writes. Cross-linked from the channels that emit them; never restated. Sibling of [model-tiers.md](model-tiers.md).

**Governing principle: strip the envelope, never the reasoning.** Terseness applies to the *wrapper prose* — preamble, narration, pleasantries, hedging. It never applies to structured/contract fields or to risk-bearing reasoning.

## Scope

Applies to internal comms only:

- subagent→parent handbacks (implementer, spec/quality reviewers, debug),
- swarm/worker reports,
- memory note bodies and log/report writes.

Does **NOT** apply to:

- user-facing replies — including a controller's own inline-mode narration in `woostack-execute --inline`;
- the review JSON-artifact contract — that is governed by the "Output Discipline (READ FIRST)" section of [woostack-review `_header.md`](../../woostack-review/prompts/_header.md), a different channel.

## Default terse rules

- Drop preamble, narration ("I have completed…", "I went ahead and…"), pleasantries ("sure", "happy to"), and hedging.
- Use structured, named fields; fragments are fine.
- Keep code symbols, file paths, line numbers, and error strings **verbatim**.
- No invented abbreviations — a reader must be able to decode every term.

## Contract fields are verbatim

**Never compress a structured field the parent parses.** The controller's `subagent-driver.md` branches on exact tokens — compressing or renaming them breaks that branching:

- `STATUS:` codes — `DONE` / `DONE_WITH_CONCERNS` / `NEEDS_CONTEXT` / `BLOCKED`
- `VERDICT:` tokens — `PASS` / `FAIL` / `APPROVED` / `CHANGES_REQUESTED`
- the named field labels themselves (`CHANGED FILES`, `MISSING`, `EXTRA`, `ISSUES`, …)

Keep these labels and tokens exactly. Terseness applies to the prose *around* the contract, never the contract itself.

## Auto-clarity carve-out

Keep full, clear English for the **content** of:

- security findings,
- destructive-operation confirmations,
- root-cause and architecture reasoning,
- **any reviewer or implementer finding or concern** — the text under `CONCERNS`, `MISSING`, `EXTRA`, `ISSUES`, and the like — because each is reasoning a downstream decision depends on,
- anything that word order or omission would make ambiguous.

The envelope around these still goes terse (drop the preamble, keep the field label); the reasoning itself never does. *Strip the envelope, never the reasoning.*

## Memory-note bodies

A distilled memory note body is one terse reusable rule: **one line, `<pattern>: <reason>`, ideally ≤100 chars, no preamble or narration.** State the rule and stop — no instance line numbers, no restating the finding. This is the single canonical definition of the rule; the memory contract and the review / address-comments record steps link here instead of restating it.
```

- [x] **Step 4: Confirm all five sections + the principle line are present**

Run:
```bash
f=skills/using-woostack/references/output-discipline.md
grep -c '^## Scope$\|^## Default terse rules$\|^## Contract fields are verbatim$\|^## Auto-clarity carve-out$\|^## Memory-note bodies$' "$f"
grep -q 'strip the envelope, never the reasoning' "$f" && echo PRINCIPLE_OK
```
Expected: PASS — first command prints `5`; second prints `PRINCIPLE_OK`.

- [x] **Step 5: Confirm the carve-out anchor + key tokens resolve as specced**

Run:
```bash
f=skills/using-woostack/references/output-discipline.md
grep -q '^## Auto-clarity carve-out$' "$f" && echo ANCHOR_OK        # → #auto-clarity-carve-out
grep -q 'STATUS:' "$f" && grep -q 'VERDICT:' "$f" && echo CONTRACT_OK
grep -q 'CONCERNS' "$f" && grep -q 'ISSUES' "$f" && echo FINDINGS_OK
```
Expected: PASS — prints `ANCHOR_OK`, `CONTRACT_OK`, `FINDINGS_OK`. (Covers AC1 edge: contract rule names STATUS/VERDICT; carve-out names findings.)

- [x] **Step 6: Commit (first commit of the increment)**

```bash
gt create -m "docs(using-woostack): add canonical Output Discipline reference for internal comms"
```

### Task 2: Dedup the ≤100-char rule in woostack-review Stage 6

**Files:**
- Modify: `skills/woostack-review/SKILL.md:489`

- [x] **Step 1: Write the failing verification**

Run: `grep -n 'output-discipline.md' skills/woostack-review/SKILL.md || echo NO_LINK`
Expected: FAIL — prints `NO_LINK` (no cross-link yet).

- [x] **Step 2: Confirm it fails**

Run the command above; confirm output is `NO_LINK`.

- [x] **Step 3: Replace the spelled-out rule at line 489 with a cross-link**

Replace this line:
```
3. **Only when the learning is genuinely new**, record one terse reusable rule — one line, `<pattern>: <reason>`, ideally ≤100 chars, no preamble or narration. Write a scoped `.woostack/memory/` note when the scoped store exists; otherwise skip and defer to `/woostack-init`.
```
with:
```
3. **Only when the learning is genuinely new**, record one terse reusable rule — one line, `<pattern>: <reason>`, per the canonical memory-note-body discipline ([`output-discipline.md`](../using-woostack/references/output-discipline.md#memory-note-bodies)). Write a scoped `.woostack/memory/` note when the scoped store exists; otherwise skip and defer to `/woostack-init`.
```

- [x] **Step 4: Confirm the cross-link is present and the spelled-out budget is gone from this line**

Run:
```bash
grep -q 'output-discipline.md#memory-note-bodies' skills/woostack-review/SKILL.md && echo LINK_OK
sed -n '489p' skills/woostack-review/SKILL.md | grep -q '≤100 chars' && echo STILL_SPELLED || echo DEDUP_OK
```
Expected: PASS — prints `LINK_OK` then `DEDUP_OK`. (The `≤100 chars` budget no longer appears on this line.)

- [x] **Step 5: Commit**

```bash
gt modify -c -m "docs(review): cross-link canonical memory-body rule, drop duplicate ≤100-char copy"
```

### Task 3: Dedup the ≤100-char rule in woostack-address-comments (two spots)

**Files:**
- Modify: `skills/woostack-address-comments/prompts/address.md` (Phase 3 ACCEPT, lines 112–114; After-the-phases, lines 146–148)

- [x] **Step 1: Write the failing verification**

Run: `grep -c 'output-discipline.md' skills/woostack-address-comments/prompts/address.md`
Expected: FAIL — prints `0`.

- [x] **Step 2: Confirm it fails**

Run the command above; confirm output is `0`.

- [x] **Step 3a: Replace the Phase 3 ACCEPT copy (lines 112–114)**

Replace this passage:
```
an instance**: one line, `<pattern>: <reason>`, ideally ≤100 chars. State the
  rule and stop — no preamble, no narration, no instance line numbers, no
  restating the finding. Also stage `memory_scope`: the narrowest glob covering
```
with:
```
an instance**: one line, `<pattern>: <reason>`, per the canonical
  memory-note-body discipline
  ([`output-discipline.md`](../../using-woostack/references/output-discipline.md#memory-note-bodies)).
  Also stage `memory_scope`: the narrowest glob covering
```

- [x] **Step 3b: Replace the After-the-phases copy (lines 146–148)**

Replace this passage:
```
   `/woostack-init`. Keep `LEARNING` terse — one line,
   `<pattern>: <reason>`, ideally ≤100 chars, no filler. Set `MEMORY_SCOPE` to
   the staged `memory_scope`:
```
with:
```
   `/woostack-init`. Keep `LEARNING` terse per the canonical memory-note-body
   discipline ([`output-discipline.md`](../../using-woostack/references/output-discipline.md#memory-note-bodies)).
   Set `MEMORY_SCOPE` to the staged `memory_scope`:
```

- [x] **Step 4: Confirm both copies now cross-link and neither spells out the budget**

Run:
```bash
f=skills/woostack-address-comments/prompts/address.md
[ "$(grep -c 'output-discipline.md#memory-note-bodies' "$f")" = 2 ] && echo LINKS_OK
grep -q '≤100 chars' "$f" && echo STILL_SPELLED || echo DEDUP_OK
```
Expected: PASS — prints `LINKS_OK` then `DEDUP_OK`.

- [x] **Step 5: Commit**

```bash
gt modify -c -m "docs(address-comments): cross-link canonical memory-body rule, drop duplicate copies"
```

### Task 4: Add the collision pointer to woostack-review `_header.md`

**Files:**
- Modify: `skills/woostack-review/prompts/_header.md:5` (the `## Output Discipline (READ FIRST)` section)

- [x] **Step 1: Write the failing verification**

Run: `grep -n 'output-discipline.md' skills/woostack-review/prompts/_header.md || echo NO_POINTER`
Expected: FAIL — prints `NO_POINTER`.

- [x] **Step 2: Confirm it fails**

Run the command above; confirm output is `NO_POINTER`.

- [x] **Step 3: Insert a one-line pointer right under the section heading**

After this line:
```
## Output Discipline (READ FIRST)
```
insert a blank line and then:
```
> This section governs the **review JSON artifacts** below. For **prose handbacks** elsewhere in woostack (subagent reports, memory bodies), see the separate [internal-comms Output Discipline](../../using-woostack/references/output-discipline.md) — a different channel with different rules.
```

- [x] **Step 4: Confirm the pointer is present and the JSON rules are unchanged**

Run:
```bash
f=skills/woostack-review/prompts/_header.md
grep -q 'internal-comms Output Discipline' "$f" && echo POINTER_OK
grep -q 'MUST be a valid JSON array' "$f" && echo JSON_RULES_INTACT
```
Expected: PASS — prints `POINTER_OK` then `JSON_RULES_INTACT`. (AC4 edge: pointer disambiguates without altering JSON rules.)

- [x] **Step 5: Commit**

```bash
gt modify -c -m "docs(review): point _header Output Discipline to the prose internal-comms doc"
```

### Task 5: Wire the implementer Report-back block

**Files:**
- Modify: `skills/woostack-execute/prompts/implementer.md:36-41` (the `## Report back (required)` block)

- [x] **Step 1: Write the failing verification**

Run: `grep -q 'output-discipline.md' skills/woostack-execute/prompts/implementer.md && echo HAS_LINK || echo NO_LINK`
Expected: FAIL — prints `NO_LINK`.

- [x] **Step 2: Confirm it fails**

Run the command above; confirm output is `NO_LINK`.

- [x] **Step 3: Add a discipline line to the Report-back block**

Replace this block:
```
## Report back (required)
- STATUS: one of DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
- CHANGED FILES: the exact paths you created or modified
- DIFF: your task's diff (or a tight per-change summary)
- TESTS/VERIFICATION: commands you ran and their result
- CONCERNS / BLOCKER / MISSING CONTEXT: whenever STATUS is not plain DONE
```
with:
```
## Report back (required)
Follow the internal-comms Output Discipline (`skills/using-woostack/references/output-discipline.md`): terse envelope, no preamble/narration. Keep the `STATUS` token **verbatim** (the controller branches on it); write any `CONCERNS` in full clear English (auto-clarity carve-out).
- STATUS: one of DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
- CHANGED FILES: the exact paths you created or modified
- DIFF: your task's diff (or a tight per-change summary)
- TESTS/VERIFICATION: commands you ran and their result
- CONCERNS / BLOCKER / MISSING CONTEXT: whenever STATUS is not plain DONE
```

- [x] **Step 4: Confirm the pointer is present AND the STATUS contract survives verbatim (AC7)**

Run:
```bash
f=skills/woostack-execute/prompts/implementer.md
grep -q 'output-discipline.md' "$f" && echo LINK_OK
grep -q 'STATUS: one of DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED' "$f" && echo STATUS_VERBATIM
```
Expected: PASS — prints `LINK_OK` then `STATUS_VERBATIM`.

- [x] **Step 5: Commit**

```bash
gt modify -c -m "docs(execute): wire implementer report-back to Output Discipline"
```

### Task 6: Wire the spec + quality reviewer verdict blocks

**Files:**
- Modify: `skills/woostack-execute/prompts/spec-reviewer.md:28-32`
- Modify: `skills/woostack-execute/prompts/quality-reviewer.md:26-29`

- [x] **Step 1: Write the failing verification**

Run:
```bash
grep -lq 'output-discipline.md' skills/woostack-execute/prompts/spec-reviewer.md skills/woostack-execute/prompts/quality-reviewer.md && echo HAS || echo NONE
```
Expected: FAIL — prints `NONE`.

- [x] **Step 2: Confirm it fails**

Run the command above; confirm output is `NONE`.

- [x] **Step 3a: Add the discipline line to `spec-reviewer.md`**

Replace this block:
```
## Report back (required)
- VERDICT: PASS (spec-compliant, nothing missing, nothing extra) or FAIL.
- MISSING: <bullets, or "none">
- EXTRA: <bullets, or "none">
Quote the spec line each gap maps to. "Close enough" is FAIL.
```
with:
```
## Report back (required)
Follow the internal-comms Output Discipline (`skills/using-woostack/references/output-discipline.md`): terse envelope. Keep the `VERDICT` token **verbatim**; write each `MISSING`/`EXTRA` item in full clear English (auto-clarity carve-out).
- VERDICT: PASS (spec-compliant, nothing missing, nothing extra) or FAIL.
- MISSING: <bullets, or "none">
- EXTRA: <bullets, or "none">
Quote the spec line each gap maps to. "Close enough" is FAIL.
```

- [x] **Step 3b: Add the discipline line to `quality-reviewer.md`**

Replace this block:
```
## Report back (required)
- VERDICT: APPROVED or CHANGES_REQUESTED.
- ISSUES: severity-tagged bullets (Important / Minor), each with a concrete fix; "none" if clean.
Approve only when no Important issues remain outstanding.
```
with:
```
## Report back (required)
Follow the internal-comms Output Discipline (`skills/using-woostack/references/output-discipline.md`): terse envelope. Keep the `VERDICT` token **verbatim**; write each `ISSUES` item in full clear English (auto-clarity carve-out).
- VERDICT: APPROVED or CHANGES_REQUESTED.
- ISSUES: severity-tagged bullets (Important / Minor), each with a concrete fix; "none" if clean.
Approve only when no Important issues remain outstanding.
```

- [x] **Step 4: Confirm both pointers present AND both VERDICT contracts survive verbatim (AC7)**

Run:
```bash
grep -q 'output-discipline.md' skills/woostack-execute/prompts/spec-reviewer.md && \
grep -q 'output-discipline.md' skills/woostack-execute/prompts/quality-reviewer.md && echo LINKS_OK
grep -q 'VERDICT: PASS' skills/woostack-execute/prompts/spec-reviewer.md && \
grep -q 'VERDICT: APPROVED or CHANGES_REQUESTED' skills/woostack-execute/prompts/quality-reviewer.md && echo VERDICTS_VERBATIM
```
Expected: PASS — prints `LINKS_OK` then `VERDICTS_VERBATIM`.

- [x] **Step 5: Commit**

```bash
gt modify -c -m "docs(execute): wire reviewer verdict blocks to Output Discipline"
```

### Task 7: Wire the execute distill step

**Files:**
- Modify: `skills/woostack-execute/SKILL.md:121-129` (distill step 7)

- [x] **Step 1: Write the failing verification**

Run: `grep -q 'output-discipline.md' skills/woostack-execute/SKILL.md && echo HAS || echo NO_LINK`
Expected: FAIL — prints `NO_LINK`.

- [x] **Step 2: Confirm it fails**

Run the command above; confirm output is `NO_LINK`.

- [x] **Step 3: Append a pointer to the distill step's note-body guidance**

In step 7, immediately after the clause `…stamp `updated:` on every note you write.` add this sentence (same paragraph):
```
 Write each note body per the canonical memory-note-body discipline ([`output-discipline.md`](../using-woostack/references/output-discipline.md#memory-note-bodies)).
```

- [x] **Step 4: Confirm the pointer is present**

Run: `grep -q 'output-discipline.md#memory-note-bodies' skills/woostack-execute/SKILL.md && echo LINK_OK`
Expected: PASS — prints `LINK_OK`.

- [x] **Step 5: Commit**

```bash
gt modify -c -m "docs(execute): point distill note bodies at Output Discipline"
```

### Task 8: Wire the memory contract note-body (§3)

**Files:**
- Modify: `skills/woostack-init/references/memory.md` (§3 note-format example region, the fence at ~line 50)

- [x] **Step 1: Write the failing verification**

Run: `grep -q 'output-discipline.md' skills/woostack-init/references/memory.md && echo HAS || echo NO_LINK`
Expected: FAIL — prints `NO_LINK`.

- [x] **Step 2: Confirm it fails**

Run the command above; confirm output is `NO_LINK`.

- [x] **Step 3: Add a one-line pointer under the §3 note-format example**

Immediately after the closing ``` ``` `` fence of the note-format code block (the block ending with `let [[tanstack-query-retries]] decide. Terse body.`) and before the `### Fields` heading, insert (a pure pointer — do **not** restate the ≤100-char budget here, or AC2's single-definition check fails):
```
The body follows the canonical memory-note-body discipline: see [`output-discipline.md`](../../using-woostack/references/output-discipline.md#memory-note-bodies).
```

- [x] **Step 4: Confirm the pointer is present**

Run: `grep -q 'output-discipline.md#memory-note-bodies' skills/woostack-init/references/memory.md && echo LINK_OK`
Expected: PASS — prints `LINK_OK`.

- [x] **Step 5: Commit**

```bash
gt modify -c -m "docs(memory): point note-body format at canonical Output Discipline"
```

### Task 9: Whole-feature consistency verification (AC2, AC3, AC6, AC7)

**Files:** none (read-only assertions over the full change).

- [x] **Step 1: Single-definition — the ≤100-char budget is spelled out in exactly one file (AC2)**

Run:
```bash
grep -rl '≤100 chars' skills/ | sort
```
Expected: exactly one line — `skills/using-woostack/references/output-discipline.md`. (Any second path = dedup miss → FAIL.)

- [x] **Step 2: Core channels are all wired (AC3), no tail channel touched**

Run:
```bash
for f in \
  skills/woostack-execute/prompts/implementer.md \
  skills/woostack-execute/prompts/spec-reviewer.md \
  skills/woostack-execute/prompts/quality-reviewer.md \
  skills/woostack-execute/SKILL.md \
  skills/woostack-init/references/memory.md; do
  grep -q 'output-discipline.md' "$f" && echo "OK  $f" || echo "MISS $f"
done
# tail channels must NOT be wired:
for f in skills/woostack-debug/SKILL.md skills/woostack-commit/SKILL.md \
         skills/woostack-execute-overnight/references/report-template.md; do
  grep -q 'output-discipline.md' "$f" && echo "CREEP $f" || echo "clean $f"
done
```
Expected: five `OK` lines, zero `MISS`; three `clean` lines, zero `CREEP`. (Address-comments is allowed a link — it's the dedup site, not a tail wiring.)

- [x] **Step 3: Every cross-link target resolves (AC6)**

Run:
```bash
grep -rln 'output-discipline.md' skills/ | while read -r f; do
  d=$(dirname "$f")
  for rel in $(grep -oE '\.\.?/[^)]*output-discipline\.md' "$f" | sed 's/#.*//' | sort -u); do
    tgt="$d/$rel"
    [ -f "$tgt" ] && echo "RESOLVES $f -> $rel" || echo "DANGLING $f -> $rel"
  done
done
```
Expected: only `RESOLVES …` lines, zero `DANGLING`.

- [x] **Step 4: Contract tokens intact post-wiring (AC7)**

Run:
```bash
grep -q 'STATUS: one of DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED' skills/woostack-execute/prompts/implementer.md && echo STATUS_OK
grep -q 'VERDICT: PASS' skills/woostack-execute/prompts/spec-reviewer.md && echo SPEC_VERDICT_OK
grep -q 'VERDICT: APPROVED or CHANGES_REQUESTED' skills/woostack-execute/prompts/quality-reviewer.md && echo QUALITY_VERDICT_OK
```
Expected: PASS — prints `STATUS_OK`, `SPEC_VERDICT_OK`, `QUALITY_VERDICT_OK`.

- [x] **Step 5: Commit**

```bash
gt modify -c -m "test(output-discipline): assert dedup, wiring, link resolution, contract integrity"
```

---

## Self-review (run before handing back)

- [x] **Spec coverage** — §4 canonical doc → Task 1; §4 dedup → Tasks 2–3; §4 collision pointer → Task 4; §4 core-channel wiring → Tasks 5–8; §4 deferred tail channels → asserted untouched in Task 9 Step 2.
- [x] **AC coverage** — AC1 → Task 1 Steps 4–5; AC2 → Tasks 2–3 + Task 9 Step 1; AC3 → Tasks 5–8 + Task 9 Step 2; AC4 → Task 4 Step 4 (JSON rules intact) + non-goal (no user-facing edits anywhere); AC5 → satisfied once Tasks 2–3 cross-link the doc (not orphaned) and re-confirmed by Task 9 Step 2; AC6 → Task 9 Step 3; AC7 → Task 5/6 Step 4 + Task 9 Step 4.
- [x] **No placeholders** — every step has the exact file, the exact before/after text, and exact verification commands with expected output.
- [x] **Type consistency** — the anchor `#memory-note-bodies` and section heading `## Memory-note bodies` match across the doc and all consumer links; `## Auto-clarity carve-out` → `#auto-clarity-carve-out` matches the spec.

> woostack plan conventions: frontmatter-free; opens with the `**Source:**` line; basename mirrors the spec (`2026-06-12-output-discipline`); no required-sub-skill banner; in this runner-less target each "failing test" is a concrete `grep`/`test` verification with exact expected output. One increment (the user collapsed the original two), so the only `gt create` is Task 1; every later task commits with `gt modify -c`.
