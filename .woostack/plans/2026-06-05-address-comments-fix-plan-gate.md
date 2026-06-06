**Source:** .woostack/specs/2026-06-05-address-comments-fix-plan-gate.md

# woostack-address-comments: show the fix plan before approval — Implementation Plan

**Goal:** Surface a terse one-line plan of how each FIX will land at the verdict gate, so the user approves knowing the edit — not just the verdict.

**Architecture:** Documentation-only change inside `skills/woostack-address-comments/`. The worker contract already defines a `fix_plan` field (`prompts/address.md:30`) that dies on the worker boundary; this plan threads it through the parent's own staged record (Phase 1 step 5) and surfaces it at the verdict gate (Phase 2) host-agnostically — a table column on a plain host, the per-thread option text on a structured host — plus a bounded override→FIX follow-up so every applied FIX has had a plan shown. `SKILL.md` prose is aligned at a high level; the gate detail stays in the prompt. Two grep assertions in the existing shell test guard the contract.

**Tech Stack:** Markdown (skill `SKILL.md` + `prompts/address.md`), Bash + ripgrep grep-assertion tests (`scripts/tests/*.sh`). No app build/CI in this repo.

---

## Increment 1: Fix plan at the verdict gate (single PR)

> One independently shippable PR (~40 lines of prose + 2 test lines, well under the ≤500 LOC soft target) — its own Graphite-stacked branch on top of the spec+plan base PR. All three tasks edit the one `woostack-address-comments` skill and must ship together to stay internally consistent.

### Task 1: Phase 2 verdict gate shows the fix plan + override→FIX follow-up

**Files:**
- Modify: `skills/woostack-address-comments/prompts/address.md` (Phase 2, lines ~59–77)
- Test: `skills/woostack-address-comments/scripts/tests/test-address-worker-contract.sh` (add assertions after line 19)

- [ ] **Step 1: Write the failing test**

Add these two assertions to `test-address-worker-contract.sh`, immediately after the existing `assert_contains "$PROMPT" "fix_plan"` line (line 19):

```bash
# the verdict gate must surface the fix plan to the user, not just the verdict
assert_contains "$PROMPT" "fix plan"
# an override that creates a FIX must derive + confirm its plan before applying
# (ASCII token from the override→FIX follow-up prose — robust to arrow encoding)
assert_contains "$PROMPT" "bounded confirm"
```

- [ ] **Step 2: Run the test, confirm it fails**

Run: `bash skills/woostack-address-comments/scripts/tests/test-address-worker-contract.sh`
Expected: FAIL — `missing pattern in skills/woostack-address-comments/prompts/address.md: fix plan` (the prompt has `fix_plan` but not the literal `fix plan`, and no `override→FIX` text yet).

- [ ] **Step 3: Minimal implementation**

Replace the Phase 2 body in `prompts/address.md` (from the `**Otherwise (default):**` paragraph through the host-mechanics / final-verdict bullets, lines ~64–77) with:

```markdown
**Otherwise (default):** present all staged threads for approval, showing each
thread's **recommended verdict, reasoning, and — for a FIX — its one-line
`fix_plan`**, so the user approves knowing *how* each fix will land, not just
that a fix is recommended. The fix plan is a **description only**: Phase 1 makes
no edits; the edit happens in Phase 3 on the final verdict. Then ask the user to
either **approve all** recommendations or **override** specific threads to a
different verdict (any of FIX / ACCEPT / CLARIFY).

Show the fix plan alongside the FIX verdict **wherever the gate renders it**:

- Host mechanics: a host with a structured question primitive (e.g. Claude
  Code's `AskUserQuestion`) offers an "approve all" choice plus per-thread
  overrides — carry the fix plan inside each FIX thread's option text; a plain
  host prints the numbered table — columns: thread, finding, recommended
  verdict, reasoning, **fix plan** (the fix-plan cell is the one-line `fix_plan`
  for a FIX, `—` for ACCEPT / CLARIFY) — and asks for "approve all, or list
  `thread#=verdict` overrides".
- The **final verdict** per thread = the user's override where given, else your
  recommendation. Only Phase 3 acts, and only on final verdicts.
- **override→FIX follow-up:** if an override turns an ACCEPT/CLARIFY thread into
  a FIX, no `fix_plan` was staged for it — derive its one-line plan and present
  those override-created plans for **one bounded confirm** before Phase 3 acts,
  so every applied FIX has had its plan shown. This completes the single verdict
  gate; it is not a new chained gate and does not re-open cascading re-overrides
  (the user confirms the derived plan or pulls that thread back off FIX).
- **Non-interactive host, no `--auto`:** if you cannot obtain confirmation,
  **abort** without acting — tell the user: "interactive verdict review needs a
  user; re-run with `--auto` to address autonomously." Never act unapproved.
```

(Leave the `**If --auto was set:**` paragraph above and the `## Phase 3` heading below unchanged.)

- [ ] **Step 4: Run the test, confirm it passes**

Run: `bash skills/woostack-address-comments/scripts/tests/test-address-worker-contract.sh`
Expected: PASS (no output, exit 0) — `fix plan` and `override→FIX` are now both present.

- [ ] **Step 5: Commit**

```bash
# first commit in this increment:
gt create -m "feat(woostack-address-comments): show fix plan at the verdict gate"
```

### Task 2: Phase 1 staged record carries `fix_plan` (cross-reference)

**Files:**
- Modify: `skills/woostack-address-comments/prompts/address.md` (Phase 1, step 5, lines ~48–55)

- [ ] **Step 1: Write the failing check**

Run: `rg -F -q "memory_scope, fix_plan" skills/woostack-address-comments/prompts/address.md; echo $?`
Expected: FAIL — prints `1` (the step-5 record ends `…, memory_scope }`; only the worker record on line 30 mentions `fix_plan`, never the sequence `memory_scope, fix_plan`).

- [ ] **Step 2: Minimal implementation**

Replace step 5 in `prompts/address.md` with (add `fix_plan` to the record tuple and define it by cross-reference, not restatement):

```markdown
5. Stage a record per thread:
   `{ threadId, file, line, finding, recommended, reasoning, learning, memory_scope, fix_plan }`
   — `finding` is the one-line restatement, `reasoning` is why you recommend
   that verdict, `learning` is the reusable memory pattern to write **if** the
   final verdict is ACCEPT (else leave empty), `memory_scope` is the narrowest
   glob that should suppress the same accepted finding in future reviews (prefer
   the reviewed file's package/feature path; use comma-separated globs when the
   learning specifically covers multiple paths), and `fix_plan` is **as defined
   for the worker record above** — a terse one-line description of the planned
   edit for a FIX, an empty string otherwise. Staging `fix_plan` here, not only
   in the worker fan-out, is what lets the verdict gate show *how* each FIX will
   land.
```

- [ ] **Step 3: Run the check + full test, confirm they pass**

Run: `rg -F -q "memory_scope, fix_plan" skills/woostack-address-comments/prompts/address.md && echo OK`
Expected: prints `OK`.
Run: `bash skills/woostack-address-comments/scripts/tests/test-address-worker-contract.sh && bash skills/woostack-address-comments/scripts/tests/test-address-comments-ownership.sh`
Expected: PASS (no output, exit 0 from both) — existing `fix_plan` presence assertions still hold.

- [ ] **Step 4: Commit**

```bash
# later commit in the same increment:
gt modify -c -m "feat(woostack-address-comments): stage fix_plan in the parent record"
```

### Task 3: Align `SKILL.md` prose (Overview + reception-loop + verdict-gate bullets)

**Files:**
- Modify: `skills/woostack-address-comments/SKILL.md` (Overview lines ~10–16; step 3 lines ~39–46; step 4 lines ~47–51)

- [ ] **Step 1: Write the failing check**

Run: `rg -F -c "fix plan" skills/woostack-address-comments/SKILL.md; echo $?`
Expected: FAIL — prints `0` then `1` (no occurrence of `fix plan` in `SKILL.md` yet).

- [ ] **Step 2: Minimal implementation**

Three edits in `SKILL.md`, keeping the file high-level (the override→FIX and host-rendering detail stay in the prompt, which the verdict-gate bullet already delegates to):

1. **Overview** — change the default-gate sentence so it names the fix plan. Replace:

   ```markdown
   **CLARIFY**. By **default** it presents the batched recommendations for your approval (or
   per-thread override) before applying anything; with `--auto` it skips the gate and acts
   autonomously.
   ```

   with:

   ```markdown
   **CLARIFY**. By **default** it presents the batched recommendations — including the
   one-line fix plan for each FIX, so you see *how* it will fix before approving — for your
   approval (or per-thread override) before applying anything; with `--auto` it skips the
   gate and acts autonomously.
   ```

2. **Step 3 (reception loop)** — change the staging clause. Replace:

   ```markdown
   it stages a recommended verdict + reasoning per thread.
   ```

   with:

   ```markdown
   it stages a recommended verdict + reasoning + (for a FIX) a one-line fix plan per thread.
   ```

3. **Step 4 (verdict gate)** — name the planned fix and the override→FIX detail location. Replace:

   ```markdown
   4. **Verdict gate** — default: the user approves the batch or overrides specific threads
      before anything is applied; `--auto` skips the gate; a non-interactive host with no
      `--auto` aborts rather than acting unapproved. The **final** verdict per thread is the
      override where given, else the recommendation. See `prompts/address.md` § Phase 2 for
      the gate mechanics.
   ```

   with:

   ```markdown
   4. **Verdict gate** — default: the user approves the batch — seeing the planned fix for
      each FIX — or overrides specific threads before anything is applied; `--auto` skips the
      gate; a non-interactive host with no `--auto` aborts rather than acting unapproved. The
      **final** verdict per thread is the override where given, else the recommendation. See
      `prompts/address.md` § Phase 2 for the gate mechanics, including the override→FIX plan
      confirm.
   ```

   (The description frontmatter line 3 already stays accurate — "fix or push back on each finding" still holds — so it needs no change.)

- [ ] **Step 3: Run the check + full address-comments test suite, confirm they pass**

Run: `rg -F -c "fix plan" skills/woostack-address-comments/SKILL.md`
Expected: prints `2` (Overview + step 3).
Run: `for t in skills/woostack-address-comments/scripts/tests/*.sh; do bash "$t" || { echo "FAIL: $t"; break; }; done; echo done`
Expected: prints `done` with no `FAIL:` line — all three address-comments tests green.

- [ ] **Step 4: Commit**

```bash
# later commit in the same increment:
gt modify -c -m "docs(woostack-address-comments): align SKILL prose with fix-plan gate"
```

---

## Self-review (run before handing back)

- [ ] **Spec coverage** — every spec requirement maps to a task above.
  - Terse one-line plan, FIX-only, `—` for ACCEPT/CLARIFY → Task 1 (gate prose) + Task 2 (`fix_plan` definition).
  - Host-agnostic (table column on plain host, option text on structured host) → Task 1.
  - `fix_plan` on both Phase 1 paths; step 5 cross-references line 30 → Task 2.
  - Override→FIX bounded follow-up → Task 1.
  - Phase 1 stays side-effect-free; `--auto` unchanged → Task 1 (left the `--auto` and Phase 3 text untouched; "description only" restatement added).
  - SKILL.md high-level alignment → Task 3.
  - Two grep assertions (gate names fix plan; override→FIX follow-up) → Task 1.
- [ ] **No placeholders** — every step has the exact prose to write, the exact command, and expected output. No TBD/TODO.
- [ ] **Type consistency** — the field is named `fix_plan` everywhere (worker record line 30, parent step-5 record, gate); the user-facing column/label is "fix plan"; the override case heading is "override→FIX follow-up" in the prompt prose, and the durable assertion greps the ASCII phrase "bounded confirm" present in that same prose (not the unicode arrow). Names match across tasks.

> woostack plan conventions (kept):
> - This file is **frontmatter-free** and **opens with** the `**Source:**` line.
> - Filename mirrors the spec basename: `.woostack/plans/2026-06-05-address-comments-fix-plan-gate.md` (the spec's date, not today's).
> - **No** required sub-skill banner — execution is `woostack-execute`'s (woostack-build step 8, or `/woostack-execute <plan>`).
> - This repo has no app test runner, so each "failing test" step is a concrete grep/`rg` verification command with exact expected output, plus the durable assertions added to the existing shell test.
