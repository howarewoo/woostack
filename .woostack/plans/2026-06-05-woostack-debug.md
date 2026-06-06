**Source:** .woostack/specs/2026-06-05-woostack-debug.md

# woostack-debug Skill Implementation Plan

**Goal:** Ship a woostack-native systematic-debugging skill exposed as the 12th public command `/woostack-debug <target> [--auto]` and as an internal hook, then wire `woostack-execute` (autonomous `--auto` dispatch) and `woostack-review` (gated suggestion) to it and register it across the adoption surface.

**Architecture:** One new self-contained skill file (`skills/woostack-debug/SKILL.md`, no `references/`) retells superpowers `systematic-debugging` (Iron Law, 4 phases, ≥3-fixes architectural escalation) in woostack vocabulary and wires it to the `.woostack/memory/` store (recall at start via `recall.sh`, distill one `gotcha` note through the reject-by-default gate at end) and to woostack's TDD/commit discipline. Mode is an explicit `--auto` flag (autonomous, no gate) vs. its absence (standalone look-before-fix gate). Increment A ships the skill standalone; Increment B edits two skills (call sites) and four docs (enumeration). Source: [.woostack/specs/2026-06-05-woostack-debug.md](../specs/2026-06-05-woostack-debug.md).

**Tech Stack:** Markdown skill + doc files only. No app code, no app build, no CI for this repo. "Tests" are verification commands (grep / `bash -n` / link checks) with exact expected output — this is a skills collection with no test runner.

**Out of scope (explicit):** Do NOT add a `references/` dir or port superpowers' `root-cause-tracing.md` / `defense-in-depth.md` / `condition-based-waiting.md` / the TS example / `find-polluter.sh`. Do NOT make `woostack-debug` author specs/plans/status, commit, or merge. Do NOT touch `action.yml` or the reusable review workflow. Do NOT edit the build-loop prose in `README.md` (line ~62) — debug is a sub-routine, not a build phase. Do NOT move/rename any existing `SKILL.md`. Do NOT add app code, lockfiles, or CI.

---

## File Structure

- **Create** `skills/woostack-debug/SKILL.md` — scoped discovery frontmatter; Iron Law block; the 4 phases; the `--auto` mode model; Red-Flags/Rationalizations digest; memory recall + distill contract (links `memory.md`, never restates); out-of-scope/handback contract. One responsibility: systematic debugging. Lean, no `references/`.
- **Modify** `skills/woostack-execute/SKILL.md` — "When to stop and ask" routes a repeatedly-failing verification to `woostack-debug … --auto` before user escalation.
- **Modify** `skills/woostack-review/SKILL.md` — suggest the gated `/woostack-debug` for a confirmed bug; never `--auto`.
- **Modify** `skills/using-woostack/SKILL.md` — add a Command Routing row.
- **Modify** `AGENTS.md` (`.claude/CLAUDE.md` symlink) — counts (eleven→twelve, thirteen→fourteen), public list, Modes B command list, Quick file map.
- **Modify** `README.md` — count + list (line ~29) and a new `### /woostack-debug` command-catalog entry.
- **Modify** `CONTRIBUTING.md` — command-surface list + edit-map row.

---

## Increment 1: The `woostack-debug` skill

> One independently shippable PR — its own Graphite-stacked branch on top of the spec+plan PR. Creates only `skills/woostack-debug/SKILL.md`; touches no other file, so it ships and reviews on its own before any wiring references it.

### Task 1: Create `skills/woostack-debug/SKILL.md`

**Files:**
- Create: `skills/woostack-debug/SKILL.md`
- Test: verification commands below (no test runner in this repo)

- [x] **Step 1: Write the failing verification, confirm it fails**

Run:
```bash
test -f skills/woostack-debug/SKILL.md && echo EXISTS || echo MISSING
```
Expected: FAIL — prints `MISSING` (file not created yet).

- [x] **Step 2: Author the frontmatter**

Write the opening frontmatter. Keep `description` scoped so it is recognized as woostack's systematic-debugging phase / the `/woostack-debug` command and is invocable by `woostack-execute`/`woostack-review`, but does NOT over-trigger on every error mention:

```markdown
---
name: woostack-debug
description: "Use as woostack's systematic-debugging phase — find the root cause of a bug, test failure, or unexpected behavior before any fix, then fix it minimally with a failing test first. Retells the four-phase method (root-cause investigation → pattern analysis → hypothesis/test → implementation) with the Iron Law (no fix without root cause) and the 3-fixes-→-question-architecture escalation, wired to the .woostack/memory store (recall known gotchas at start, distill one gotcha at end). Invoke via /woostack-debug <target> for a look-before-fix gate, or with --auto for autonomous operation (woostack-execute dispatches --auto on a repeatedly-failing verification; woostack-review suggests the gated command for a confirmed bug). Owns no spec/plan/status, never commits or merges."
---

# woostack-debug

Find the root cause of any bug, test failure, or unexpected behavior **before** attempting a
fix, then fix the root cause minimally with a failing test first. This is woostack's own
systematic-debugging phase: a place every woostack skill can route a stuck verification or a
confirmed bug instead of falling back to guess-and-check. It owns no approval gate beyond its
standalone look-before-fix mode, never commits, and never merges — it hands the fix back.
```

- [x] **Step 3: Author the Iron Law block**

Write it as a prominent block so it survives summarization (same treatment as the ideate HARD GATE):

```markdown
<IRON-LAW>
NO FIX WITHOUT ROOT CAUSE INVESTIGATION FIRST.

A symptom fix is a failure. If you have not completed Phase 1 (root-cause investigation), you
may not propose or apply a fix. This holds for EVERY issue regardless of perceived simplicity
and ESPECIALLY under time pressure — systematic debugging is faster than thrashing. Even in
`--auto` mode, the root cause is narrated before any fix so the "why" is visible.
</IRON-LAW>
```

- [x] **Step 4: Author the four phases**

Write a `## The four phases` section. Each phase must complete before the next. Content:

- **Phase 1 — Root cause investigation:** read errors/stack traces completely (note line/file/code); reproduce consistently (if not reproducible, gather data — don't guess); check recent changes (`git diff`, recent commits, new deps/config); in multi-component systems add boundary instrumentation (log data in/out at each component boundary, run once to localize *which* layer fails before touching it); trace the bad value backward to its source and fix at source, not symptom.
- **Phase 2 — Pattern analysis:** find working examples in the same repo; read any reference implementation completely (don't skim); list every difference between working and broken ("that can't matter" is banned); map dependencies/config/environment.
- **Phase 3 — Hypothesis & test:** state one hypothesis ("X is the root cause because Y"); test with the smallest possible change, one variable at a time; confirm → Phase 4, or form a NEW hypothesis (don't stack fixes); when you don't know, say "I don't understand X" and research/ask rather than fake it.
- **Phase 4 — Implementation:** write a **failing test that reproduces the bug first** (reuse the TDD discipline embodied in `woostack-execute` — in a target without a test runner, a concrete verification command with exact expected output); apply **one** minimal fix at the root cause (no "while I'm here" extras, no bundled refactor); verify the test passes and nothing else broke; optionally add defense-in-depth validation at layer boundaries. **If the fix fails:** attempts `< 3` → return to Phase 1 with the new evidence; attempts `≥ 3` → STOP (see escalation block).

Include a one-line inline mention of the three techniques (root-cause tracing in Phase 1, defense-in-depth in Phase 4, condition-based waiting for timeout/flaky issues) — NOT separate reference files.

- [x] **Step 5: Author the ≥3-fixes escalation block**

Write it as an explicit block (load-bearing, must survive summarization):

```markdown
<ESCALATION>
If 3+ fixes have failed, STOP. This is not a failed hypothesis — it is a wrong-architecture
signal (each fix reveals new coupling/state elsewhere, fixes need "massive refactoring", each
fix creates new symptoms). Question the fundamentals with the user: is this pattern sound, or
are we continuing through inertia? Do NOT attempt fix #4 before that discussion. When invoked
with `--auto`, this stop is the handback signal to the caller.
</ESCALATION>
```

- [x] **Step 6: Author the mode model (`--auto`)**

Write a `## Mode: --auto vs standalone` section:

- Mode is selected by an explicit `--auto` flag (mirrors `woostack-execute`'s `--inline/--subagent`), never by context-sniffing.
- **`--auto` (autonomous):** run Phases 1–4 end to end; no per-fix gate (consistent with execute/harden owning none); Iron Law still forces narrating the root cause; the only hard stop is the ≥3-fixes escalation, which doubles as the caller handback.
- **No `--auto` (standalone, the default):** after Phases 1–3, STOP and present the root cause + the proposed minimal fix, and wait for an explicit go-ahead before Phase 4. Then name `woostack-commit` as the next step (debug does not commit).
- **Fail-safe:** absence/unrecognized flag ⇒ gated. An unrequested fix is never silently applied.
- **No-arg invocation:** `/woostack-debug` with no target → ask what's broken; do not guess (mirror `woostack-execute`).

- [x] **Step 7: Author the memory contract**

Write a `## Memory` section that LINKS the contract rather than restating it ([memory.md](../woostack-init/references/memory.md)):

- **Recall (start):** compute the working set (the target's files — the failing test file and the code under suspicion) and run the recall procedure — `recall.sh` when the `woostack-init` scripts are present, the manual §6 procedure otherwise. Surface matching `gotcha`/`hotspot`/`pattern` notes before investigating; a matching note may already name the root cause. State whether recall was script-assisted or manual (degradation contract).
- **Distill (end, on a confirmed fix):** write **one** `gotcha` note through the reject-by-default gate — narrow glob `scope:` (single-literal-path scope is trivia, rejected), `source:` = owning spec/plan or `pr-N`, terse body with `[[wikilinks]]`, `updated:` today. Dedupe against `MEMORY.md` first (update over add). Then run `build-index.sh` + `doctor.sh`. The note records the **root cause and its fix**, not the symptom.

- [x] **Step 8: Author Red Flags + Rationalizations digest**

Write a condensed `## Red flags — stop and return to Phase 1` list (from superpowers): "quick fix for now", "just try changing X", "add multiple changes, run tests", "skip the test", "it's probably X", "one more fix attempt" (after 2+), proposing fixes before tracing data flow, "each fix reveals a new problem". And a short rationalizations table ("issue is simple" → simple issues have root causes too; "emergency, no time" → systematic is faster than thrashing; "I see the problem" → seeing symptoms ≠ understanding root cause).

- [x] **Step 9: Author the out-of-scope / handback contract**

Write a `## Hard constraints` section: owns no spec/plan/status authoring (the `spec : plan : PRs = 1 : 1 : N` invariant is untouched); never commits or merges (hands the fix back — standalone names `woostack-commit`, `--auto` lets the caller commit in its cadence); no `references/`; Iron Law and ≥3-fixes escalation are load-bearing blocks; fail-safe to gated when `--auto` is absent.

- [x] **Step 10: Run the structure verification, confirm it passes**

Run:
```bash
f=skills/woostack-debug/SKILL.md
grep -q '^name: woostack-debug$' "$f" && \
grep -q 'IRON-LAW' "$f" && \
grep -q 'ESCALATION' "$f" && \
grep -qi 'phase 1' "$f" && grep -qi 'phase 4' "$f" && \
grep -q -- '--auto' "$f" && \
grep -q 'recall' "$f" && grep -q 'gotcha' "$f" && \
grep -q 'memory.md' "$f" && \
echo PASS || echo FAIL
```
Expected: PASS.

- [x] **Step 11: Confirm the out-of-scope contract holds (negative checks)**

Run:
```bash
f=skills/woostack-debug/SKILL.md
test ! -d skills/woostack-debug/references && echo "no-references:OK" || echo "no-references:FAIL"
grep -qiE 'gt (create|modify|submit)|git commit|git merge' "$f" && echo "commit-leak:FAIL" || echo "commit-leak:OK"
```
Expected: `no-references:OK` and `commit-leak:OK`.

- [x] **Step 12: Link check**

Run (verify every relative link target in the new skill exists):
```bash
cd skills/woostack-debug && \
grep -oE '\]\(([^)]+\.md)' SKILL.md | sed 's/](//' | while read p; do
  [ -e "$p" ] && echo "OK  $p" || echo "DANGLING  $p"; done
```
Expected: every line starts with `OK` (resolves `../woostack-init/references/memory.md`, `../woostack-status/references/conventions.md`, `../woostack-execute/SKILL.md`, `../woostack-review/SKILL.md`). No `DANGLING`.

- [x] **Step 13: Commit**

```bash
# first commit in this increment:
gt create -m "feat(woostack-debug): add systematic-debugging skill"
```

---

## Increment 2: Wire call sites and register the command

> One independently shippable PR stacked on Increment 1. Edits two skills (call sites) and four docs (enumeration). Reviewable as "the new command is now reachable and counted everywhere." Small doc LOC, so kept as one coherent PR; if a reviewer prefers, it splits cleanly into 2a (call sites: Tasks 2–3) and 2b (enumeration: Tasks 4–8) — but that is over-splitting for edits this small.

### Task 2: Wire `woostack-execute` (autonomous `--auto` dispatch)

**Files:** Modify `skills/woostack-execute/SKILL.md`

- [x] **Step 1: Confirm the current text, confirm the wiring is absent**

Run:
```bash
grep -n 'A verification fails repeatedly' skills/woostack-execute/SKILL.md
grep -c 'woostack-debug' skills/woostack-execute/SKILL.md
```
Expected: the first prints the line (~137); the second prints `0` (no wiring yet — this is the failing state).

- [x] **Step 2: Edit the "When to stop and ask" block**

In the `## When to stop and ask` list, change the `A verification fails repeatedly.` bullet so a repeatedly-failing verification first routes to `woostack-debug <target> --auto` (autonomous), escalating to the user only if debug returns its ≥3-fixes architectural stop. State that this applies to both inline and subagent drivers (the block is shared), and that debug does not commit — execute commits the returned fix in its existing per-increment cadence. Link `../woostack-debug/SKILL.md`. Example replacement bullet:

```markdown
- A verification fails repeatedly — route it to [`woostack-debug`](../woostack-debug/SKILL.md)
  in autonomous mode (`woostack-debug <target> --auto`) to find and fix the root cause before
  escalating; escalate to the user only if debug returns its 3-fixes architectural stop. Debug
  does not commit — execute commits the returned fix in its normal per-increment cadence.
  (Applies to both the inline and subagent drivers.)
```

- [x] **Step 3: Run the verification, confirm it passes**

Run:
```bash
grep -q 'woostack-debug <target> --auto' skills/woostack-execute/SKILL.md && \
grep -q '\[`woostack-debug`\](../woostack-debug/SKILL.md)' skills/woostack-execute/SKILL.md && \
echo PASS || echo FAIL
```
Expected: PASS.

- [x] **Step 4: Commit**

```bash
gt create -m "feat(woostack-execute): route stuck verifications to woostack-debug --auto"
```

### Task 3: Wire `woostack-review` (gated suggestion, never `--auto`)

**Files:** Modify `skills/woostack-review/SKILL.md`

- [x] **Step 1: Confirm wiring absent**

Run:
```bash
grep -c 'woostack-debug' skills/woostack-review/SKILL.md
```
Expected: `0`.

- [x] **Step 2: Add the suggestion pointer**

Add a short prose pointer (no verdict/threading change) in the place where review describes acting on confirmed findings: when a finding is a confirmed real bug (not a style nit), suggest the user run the gated `/woostack-debug <target>` to investigate it systematically. State explicitly that review never `--auto`-dispatches debug — review owns no fix behavior and never auto-addresses findings. Link `../woostack-debug/SKILL.md`. Example:

```markdown
For a confirmed bug (not a style nit), suggest the user investigate it with
[`woostack-debug`](../woostack-debug/SKILL.md): `/woostack-debug <target>` (gated). Review
never dispatches `--auto` — it owns no fix behavior and never auto-addresses findings.
```

- [x] **Step 3: Run the verification, confirm it passes**

Run:
```bash
grep -q '/woostack-debug' skills/woostack-review/SKILL.md && \
grep -q 'never' skills/woostack-review/SKILL.md && \
! grep -q 'woostack-debug.*--auto' skills/woostack-review/SKILL.md && \
echo PASS || echo FAIL
```
Expected: PASS (mentions the gated command; never pairs `woostack-debug` with `--auto`).

- [x] **Step 4: Commit**

```bash
gt modify -c -m "feat(woostack-review): suggest woostack-debug for confirmed bugs"
```

### Task 4: Add the `using-woostack` routing row

**Files:** Modify `skills/using-woostack/SKILL.md`

- [x] **Step 1: Confirm absent**

Run: `grep -c 'woostack-debug' skills/using-woostack/SKILL.md`
Expected: `0`.

- [x] **Step 2: Add the Command Routing row**

In the `## Command Routing` table, add a row (keep the existing column shape):

```markdown
| `/woostack-debug <target> [--auto]`, find a bug's root cause before fixing (gated; `--auto` for autonomous) | `woostack-debug` |
```

- [x] **Step 3: Run the verification, confirm it passes**

Run:
```bash
grep -q '| `/woostack-debug <target> \[--auto\]`' skills/using-woostack/SKILL.md && \
grep -q '| `woostack-debug` |' skills/using-woostack/SKILL.md && echo PASS || echo FAIL
```
Expected: PASS.

- [x] **Step 4: Commit**

```bash
gt modify -c -m "feat(using-woostack): add woostack-debug routing row"
```

### Task 5: Update counts and lists in `AGENTS.md`

**Files:** Modify `AGENTS.md` (the `.claude/CLAUDE.md` symlink points here)

- [x] **Step 1: Confirm the current counts (failing state)**

Run:
```bash
grep -n 'eleven skills' AGENTS.md
grep -n 'eleven-skill command surface' AGENTS.md
grep -n 'thirteen `SKILL.md`' AGENTS.md
grep -c 'woostack-debug' AGENTS.md
```
Expected: the three greps print their lines (~16, ~34, ~79); the count prints `0`.

- [x] **Step 2: Bump the public-surface count + list (line ~16)**

Change `The public command/adoption surface has eleven skills:` → `twelve skills:` and add a bullet `- [`woostack-debug`](skills/woostack-debug/SKILL.md)` to the list (after `woostack-status`/`woostack-visualize`, keeping the existing order/style).

- [x] **Step 3: Fix the internal-sub-skill phrasing (line ~34)**

Change `absent from the eleven-skill command surface above` → `twelve-skill command surface above` so the cross-reference stays accurate.

- [x] **Step 4: Bump the rename-protection counts (line ~79)**

Change `Do not move or rename any of the thirteen `SKILL.md` files (the eleven public command/adoption …` → `fourteen `SKILL.md` files (the twelve public command/adoption …` (twelve public + the two internal sub-skills = fourteen).

- [x] **Step 5: Add `/woostack-debug` to the Mode B command list**

In the `## Modes` → Mode B sentence that enumerates the slash commands, add `/woostack-debug` to the list (keep the intent-equivalent-wording clause).

- [x] **Step 6: Add a Quick file map entry**

Under `## Quick file map`, add an entry:

```markdown
- Systematic-debugging engine (public command + internal hook):
  [`skills/woostack-debug/SKILL.md`](skills/woostack-debug/SKILL.md)
```

- [x] **Step 7: Run the verification, confirm it passes**

Run:
```bash
grep -q 'twelve skills:' AGENTS.md && \
grep -q 'twelve-skill command surface' AGENTS.md && \
grep -q 'fourteen `SKILL.md`' AGENTS.md && \
grep -q 'the twelve public command/adoption' AGENTS.md && \
[ "$(grep -c 'woostack-debug' AGENTS.md)" -gt 0 ] && \
echo PASS || echo FAIL
```
Expected: PASS. Then confirm no stale count remains:
```bash
grep -nE 'eleven skills|eleven-skill|thirteen `SKILL.md`' AGENTS.md && echo "STALE-FOUND" || echo "no-stale:OK"
```
Expected: `no-stale:OK`.

- [x] **Step 8: Commit**

```bash
gt modify -c -m "docs(agents): register woostack-debug (eleven→twelve, file map, modes)"
```

### Task 6: Update `README.md`

**Files:** Modify `README.md`

- [x] **Step 1: Confirm the failing state**

Run:
```bash
grep -n 'public command/adoption surface is eleven skills' README.md
grep -c '/woostack-debug' README.md
```
Expected: first prints line ~29; second prints `0`.

- [x] **Step 2: Bump the count + list (line ~29)**

Change `The public command/adoption surface is eleven skills: …, and woostack-visualize.` → `twelve skills: …, woostack-visualize, and woostack-debug.` (keep the trailing internal-sub-skills sentence about `woostack-ideate`/`woostack-harden` unchanged).

- [x] **Step 3: Add a command-catalog entry**

In the per-command catalog section (the `### /woostack-X` blocks, ~lines 50–90), add a new entry consistent with the existing blurb style:

```markdown
### `/woostack-debug <target> [--auto]`: find the root cause before fixing

Runs woostack's systematic-debugging method on a bug, test failure, or unexpected behavior:
root-cause investigation → pattern analysis → hypothesis/test → minimal fix with a failing
test first, under the Iron Law (no fix without a root cause) and a 3-fixes-→-question-the-
architecture escalation. It recalls known `gotcha`s from `.woostack/memory/` at the start and
distills one at the end. Standalone it gates on the root cause before fixing; `--auto` runs
autonomously (how `woostack-execute` calls it on a stuck verification). Never commits or
merges. → [SKILL.md](skills/woostack-debug/SKILL.md)
```

- [x] **Step 4: Confirm build-loop prose is untouched**

Run (content-based, not line-based — the build-loop sentence names the four build phases and must NOT gain `woostack-debug`):
```bash
grep -n "sequences woostack's own ideate, harden, plan, and execute" README.md | grep -q 'woostack-debug' \
  && echo "LEAK:FAIL" || echo "build-prose-clean:OK"
```
Expected: `build-prose-clean:OK` (the matched build-loop line contains no `woostack-debug`).

- [x] **Step 5: Run the verification, confirm it passes**

Run:
```bash
grep -q 'twelve skills:' README.md && \
grep -q '### `/woostack-debug <target> \[--auto\]`' README.md && \
echo PASS || echo FAIL
grep -nE 'surface is eleven skills' README.md && echo "STALE-FOUND" || echo "no-stale:OK"
```
Expected: `PASS` and `no-stale:OK`.

- [x] **Step 6: Commit**

```bash
gt modify -c -m "docs(readme): register woostack-debug command (count, list, catalog)"
```

### Task 7: Update `CONTRIBUTING.md`

**Files:** Modify `CONTRIBUTING.md`

- [x] **Step 1: Confirm absent**

Run: `grep -c 'woostack-debug' CONTRIBUTING.md`
Expected: `0`.

- [x] **Step 2: Add to the command-surface list (line ~3)**

Add `woostack-debug` to the inline command-surface enumeration, matching the existing comma-list style (after `woostack-visualize`).

- [x] **Step 3: Add an edit-map row (if a per-skill table exists)**

If `CONTRIBUTING.md` has a "where to edit" table listing per-skill entries, add a row: change the debugging behavior → `skills/woostack-debug/SKILL.md`. (If there is no such table, skip this step — confirm by `grep -n 'where to edit' CONTRIBUTING.md` first.)

- [x] **Step 4: Run the verification, confirm it passes**

Run: `grep -q 'woostack-debug' CONTRIBUTING.md && echo PASS || echo FAIL`
Expected: PASS.

- [x] **Step 5: Commit**

```bash
gt modify -c -m "docs(contributing): add woostack-debug to the command surface"
```

### Task 8: Whole-repo enumeration consistency check

**Files:** none (verification only)

- [x] **Step 1: No stale counts anywhere in shipped docs**

Run:
```bash
grep -rnE 'eleven skills|eleven-skill|thirteen `SKILL.md`' AGENTS.md README.md CONTRIBUTING.md skills/using-woostack/SKILL.md && echo "STALE-FOUND" || echo "no-stale:OK"
```
Expected: `no-stale:OK`.

- [x] **Step 2: `woostack-debug` present in every enumeration site**

Run:
```bash
for f in AGENTS.md README.md CONTRIBUTING.md skills/using-woostack/SKILL.md skills/woostack-execute/SKILL.md skills/woostack-review/SKILL.md; do
  grep -q 'woostack-debug' "$f" && echo "OK  $f" || echo "MISSING  $f"; done
```
Expected: every line starts with `OK`.

- [x] **Step 3: Cross-links resolve from the new skill and its referrers**

Run:
```bash
test -f skills/woostack-debug/SKILL.md && \
test -f skills/woostack-init/references/memory.md && \
test -f skills/woostack-status/references/conventions.md && \
test -f skills/woostack-execute/SKILL.md && \
test -f skills/woostack-review/SKILL.md && echo "links:OK" || echo "links:FAIL"
```
Expected: `links:OK`.

- [x] **Step 4: Final commit (if any verification fix was needed)**

```bash
gt modify -c -m "docs: enumeration consistency for woostack-debug"
```

---

## Self-review (run before handing back)

- [x] **Spec coverage** — every spec section maps to a task: §2 goal → Task 1 (skill) + Tasks 2–7 (wiring/enum); §4.1 four phases → Task 1 Steps 4–5; §4.2 mode model → Task 1 Step 6; §4.3 memory → Task 1 Step 7; §4.4 call sites → Tasks 2–3; §5 edit set → Tasks 1–7; §6 failure modes → Task 1 Steps 6–7 + Step 11; §7 testing → the verification steps + Task 8.
- [x] **No placeholders** — every step has the actual content (frontmatter, Iron Law/escalation blocks verbatim, exact grep commands, expected output).
- [x] **Type consistency** — the flag is `--auto` everywhere; the note type is `gotcha` everywhere; the command is `/woostack-debug <target> [--auto]` everywhere; counts are twelve (public) / fourteen (SKILL.md files) consistently.

> woostack plan conventions (kept):
> - This file is **frontmatter-free** and **opens with** the `**Source:**` line.
> - Filename mirrors the spec basename: `.woostack/plans/2026-06-05-woostack-debug.md` (the spec's date).
> - **No** required sub-skill banner — execution is `woostack-execute`'s (woostack-build step 8, or `/woostack-execute <plan>`).
> - This is a skills repo with no test runner, so each "failing test" is a verification command (grep / `bash` / link check) with exact expected output.
