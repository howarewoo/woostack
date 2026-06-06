---
name: address-comments-fix-plan-gate
type: spec
status: planning
date: 2026-06-05
branch: address-comments-fix-plan-gate
links:
---

# woostack-address-comments: show the fix plan before approval — Design Spec

> Visualize on demand: render this file with [spec-template.html](../../skills/woostack-build/references/spec-template.html) for a rich view, or hand it to `woostack-visualize` (audience `engineer`). Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../skills/woostack-status/references/conventions.md).

## 1. Problem

`woostack-address-comments` runs an analysis loop, then presents a batched verdict gate for
the user to approve before any edit lands (`prompts/address.md` Phase 1 → Phase 2). The gate
table has four columns: **thread · finding · recommended verdict · reasoning**
(`prompts/address.md:65`).

For a **FIX** verdict, that table shows *why* a fix is recommended (`reasoning`) but never
*what edit* will be made. The user approves a fix sight-unseen — the planned change is not
surfaced until Phase 3 has already mutated the working tree.

The information already half-exists. The worker-fan-out contract defines a `fix_plan` field
— "a short description of the needed code edit for FIX, or an empty string otherwise"
(`prompts/address.md:30`). But it dies on the worker boundary:

1. The non-fan-out staged record (Phase 1, step 5, `prompts/address.md:48–49`) lists
   `{ threadId, file, line, finding, recommended, reasoning, learning, memory_scope }` —
   **no `fix_plan`**. A run without worker fan-out never produces one.
2. The Phase 2 gate table never renders `fix_plan`, so even a fan-out run that produced it
   hides it from the approval decision.

Net: approval of a FIX is uninformed about the actual change.

## 2. Goal

Surface, at the verdict gate, a **terse one-line plan** of how each FIX will be applied, so
the user approves with knowledge of the edit — not just the verdict.

Concretely:

- The Phase 1 staged record carries `fix_plan` on **both** code paths (worker fan-out and the
  parent's own analysis), so the two record schemas align.
- The verdict gate shows the fix plan **alongside the FIX verdict, wherever the gate renders
  it** — a new column on a plain numbered table, and inside the per-thread option text on a
  structured-question host. Host-agnostic, matching `prompts/address.md:69–72`.
- **Every applied FIX has had a plan shown.** If a gate override turns an ACCEPT/CLARIFY
  thread into a FIX (no `fix_plan` was staged for it), derive the one-line plan for that
  thread and present it for one bounded follow-up confirm before Phase 3 applies it — so no
  FIX edit lands without its plan having been seen.
- `SKILL.md` prose (Overview, reception-loop bullet, verdict-gate bullet) matches the prompt
  contract.

Scope is the prose, prompt, and tests of one skill: `skills/woostack-address-comments/`. No
app code, no other skills.

## 3. Non-goals

- **No full diff/patch preview.** The plan is a one-line description, not generated code.
  Reuses the existing `fix_plan` altitude.
- **No edits in Phase 1.** The side-effect-free analysis invariant is preserved
  (`prompts/address.md:14–16`); the real edit stays in Phase 3.
- **No fix-plan column for ACCEPT / CLARIFY.** Those verdicts already carry their action in
  the `reasoning` column (pushback) or as a posted question. `fix_plan` stays empty for them,
  matching the line-30 contract.
- **`--auto` path unchanged.** With `--auto` there is no gate and no table; `fix_plan` is
  still staged but simply not presented.
- No change to commit/push/reply/resolve/memory mechanics or the worker-ownership boundary.

## 4. Approach

Edit three spots in `skills/woostack-address-comments/`, plus one test assertion:

1. **`prompts/address.md` — Phase 1, step 5 staged record (`:48–49`).** Add `fix_plan` to the
   non-fan-out record, **cross-referencing** the existing worker-record definition
   (`prompts/address.md:30`) rather than restating it — e.g. "…, `fix_plan` (as defined for
   the worker record above)". One canonical definition (honoring the repo "cross-link, do not
   duplicate" constraint); this aligns the parent's staged record with the worker record.

2. **`prompts/address.md` — Phase 2 verdict gate (`:64–72`).** State the requirement
   host-agnostically: the fix plan is shown alongside the FIX verdict **wherever the gate
   renders it**. Spell out both host instances against the existing host-mechanics note
   (`:69–72`): a plain numbered-table host gains a **fix plan** column (thread · finding ·
   recommended verdict · reasoning · **fix plan**); a structured-question host carries the
   fix plan inside each FIX thread's option text. Populated for FIX, `—`/empty for
   ACCEPT / CLARIFY. Reaffirm the plan is a *description only* — Phase 1 makes no edits; the
   edit happens in Phase 3 on the final verdict. Approve-all / per-thread override mechanics
   are unchanged. **Add the override→FIX follow-up:** after overrides are submitted, for any
   thread now FIX-bound with an empty `fix_plan` (i.e. it was not a recommended FIX), derive
   the one-line plan and present those override-created plans for a single bounded confirm
   before Phase 3 acts. The follow-up confirm is **not** a new chained gate — it completes the
   one verdict gate, which is done only once every final FIX has had a plan shown. It does not
   re-open arbitrary re-override cascades: the user confirms the derived plan or pulls that
   thread back off FIX.

3. **`SKILL.md` — Overview + lifecycle (`:10–16`, step 3 `:39–46`, step 4 `:47–51`).** Update
   the reception-loop bullet so it stages "a recommended verdict + reasoning **+ fix plan**"
   per thread, and the verdict-gate bullet so the gate "presents the batched recommendations
   **with the planned fix** for approval." Keep `SKILL.md` high-level: the override→FIX
   follow-up and host-rendering detail stay in `prompts/address.md` (the verdict-gate bullet
   already delegates gate mechanics to it, `SKILL.md:50–51`). Keep the description line
   accurate.

4. **Tests — `scripts/tests/test-address-worker-contract.sh`.** Add two grep assertions on
   stable keywords (not exact prose): (a) the Phase 2 gate surfaces the fix plan (the gate
   section mentions `fix plan`); (b) the override→FIX follow-up is present (e.g. the prompt
   mentions deriving/confirming a plan for an override-created FIX). Existing `fix_plan`
   presence assertions (`test-address-worker-contract.sh:19`,
   `test-address-comments-ownership.sh:32`) still pass.

Markdown/prompt + shell-test change only; the skill is documentation an agent executes.

## 5. Components & data flow

**Staged record (Phase 1, both paths)** — gains the final field:

```
{ threadId, file, line, finding, recommended, reasoning, learning, memory_scope, fix_plan }
```

- `fix_plan`: terse one-line edit description for a FIX verdict; empty string for ACCEPT /
  CLARIFY. Same semantics as the worker-record `fix_plan` (`prompts/address.md:30`).

**Phase 2 gate table** — five columns:

| thread | finding | recommended verdict | reasoning | fix plan |
|--------|---------|---------------------|-----------|----------|
| #1 | off-by-one in expiry | FIX | real bug, still present | change `<`→`<=` in auth.ts:42 |
| #2 | rename endpoint | ACCEPT | intentional public API | — |
| #3 | unclear retry intent | CLARIFY | cannot verify intent | — |

The table above is the **plain-host** instance. On a **structured-question** host the fix
plan rides inside each FIX thread's option text:

```
Thread #1  finding: off-by-one in expiry
  [approve FIX]  change `<`→`<=` in auth.ts:42
  [override → ACCEPT / CLARIFY]
```

Flow: Phase 1 stages `fix_plan` per thread → Phase 2 shows it alongside each FIX verdict
(table column on a plain host, option text on a structured host) → user approves/overrides →
**override→FIX follow-up**: any thread the user overrides into FIX has no staged plan, so
derive its one-line plan and present those for one bounded confirm → Phase 3 applies the edit
for final FIX verdicts (unchanged). The host-mechanics note (`prompts/address.md:69–72`) is
unchanged in mechanics; both rendering paths now carry the fix plan.

## 6. Error handling

No new failure modes — the change is prompt/doc prose plus one grep test.

- A FIX whose plan is hard to articulate → best-effort one-liner; the existing per-thread
  `errored` guardrail (`prompts/address.md:135`) still covers a true analysis failure and
  leaves that thread open without aborting the run.
- Push-rejected and per-thread-error guardrails (`prompts/address.md:133–139`) are untouched.
- `--auto`: gate skipped, no table rendered, behavior unchanged.

## 7. Testing

Automated: this repo has no app build/CI for its own skill markdown. The skill's own shell
tests are the harness:

- Extend `scripts/tests/test-address-worker-contract.sh` with two grep assertions: the Phase 2
  gate section names the fix plan, and the override→FIX follow-up is present. Run the three
  address-comments tests (`test-address-comments-ownership.sh`,
  `test-address-helper-scripts.sh`, `test-address-worker-contract.sh`) and confirm green.

Manual (before merge):

- Read `prompts/address.md` and confirm: step 5 record lists `fix_plan` cross-referencing the
  line-30 worker definition; Phase 2 shows the fix plan host-agnostically (table column on a
  plain host, option text on a structured host) with the FIX-only / `—` rule, the "description
  only, edit happens in Phase 3" restatement, and the override→FIX follow-up confirm.
- Read `SKILL.md` and confirm the reception-loop and verdict-gate bullets mention the fix plan
  and stay consistent with the prompt — no leftover four-column description.

Manual (after merge): none — the skill takes effect for consumers on install; no deploy or
runtime surface to verify post-merge for this repo.

## 8. Open questions

None. All decisions are resolved:

- Altitude: a **terse one-line** fix plan (not a full diff); Phase 1 stays side-effect-free.
- Scope: the new column is **FIX-only**; ACCEPT / CLARIFY render `—`, matching the
  existing `fix_plan` empty-string contract.
- Surface: shown alongside the FIX verdict (not a separate per-thread expansion).
- Host-agnostic: stated once host-neutrally, then both renderings named — a table column on a
  plain host, the per-thread option text on a structured-question host. The skill works for
  any agent, not one host.
- Field definition: step 5 **cross-references** the line-30 worker-record definition of
  `fix_plan` rather than restating it (repo "cross-link, do not duplicate" rule); one
  canonical definition.
- Override→FIX: a gate override that creates a FIX gets its plan **derived and shown for one
  bounded confirm** before Phase 3, so every applied FIX has had a plan seen. This completes
  the single verdict gate; it is not a new chained gate and does not re-open cascading
  re-overrides.
