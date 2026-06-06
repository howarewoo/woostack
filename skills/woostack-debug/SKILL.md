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

It is both the 12th public command (`/woostack-debug <target> [--auto]`) and an internal hook:
[`woostack-execute`](../woostack-execute/SKILL.md) dispatches it autonomously when a
verification fails repeatedly, and [`woostack-review`](../woostack-review/SKILL.md) suggests it
for a confirmed bug.

<IRON-LAW>
NO FIX WITHOUT ROOT CAUSE INVESTIGATION FIRST.

A symptom fix is a failure. If you have not completed Phase 1 (root-cause investigation), you
may not propose or apply a fix. This holds for EVERY issue regardless of perceived simplicity
and ESPECIALLY under time pressure — systematic debugging is faster than thrashing. Even in
`--auto` mode the root cause is narrated before any fix, so the "why" is always visible.
</IRON-LAW>

## When to use

Any technical issue: test failures, production bugs, unexpected behavior, performance
problems, build failures, integration issues. Use it **especially** when guessing is
tempting — under time pressure, when "just one quick fix" looks obvious, when a previous fix
didn't work, or when you don't fully understand the issue. Do **not** skip it because an issue
"seems simple": simple bugs have root causes too, and the process is fast for them.

## The four phases

Complete each phase before the next.

### Phase 1 — Root cause investigation

1. **Read errors completely.** Don't skip past errors, warnings, or stack traces — they often
   contain the exact answer. Note line numbers, file paths, error codes.
2. **Reproduce consistently.** Can you trigger it reliably, and with what exact steps? If it is
   not reproducible, gather more data — do not guess.
3. **Check recent changes.** `git diff`, recent commits, new dependencies, config or
   environment differences. What changed that could cause this?
4. **Gather evidence in multi-component systems.** When the system has multiple components
   (CI → build → sign, API → service → DB), add boundary instrumentation *before* proposing a
   fix: log what data enters and exits each component, verify config/env propagation, and run
   once to reveal **which** layer breaks. Investigate that layer, not a guess.
5. **Trace data flow backward** (root-cause tracing). Where does the bad value originate? What
   called this with the bad value? Keep tracing up the call stack to the source — fix at the
   source, not at the symptom.

### Phase 2 — Pattern analysis

1. **Find working examples** of similar code in the same repo.
2. **Compare against references** completely — if you are applying a pattern, read the
   reference implementation every line, don't skim.
3. **Identify every difference** between working and broken, however small. "That can't matter"
   is banned.
4. **Understand dependencies** — what other components, settings, config, or environment does
   this need, and what does it assume?

### Phase 3 — Hypothesis and test

1. **Form one hypothesis.** State it: "X is the root cause because Y." Be specific.
2. **Test minimally.** Make the smallest possible change to test it; change one variable at a
   time; don't fix several things at once.
3. **Verify before continuing.** Worked → Phase 4. Didn't work → form a **new** hypothesis;
   don't stack more fixes on top.
4. **When you don't know,** say "I don't understand X" and research or ask — don't pretend.

### Phase 4 — Implementation

1. **Write a failing test first.** The simplest reproduction of the bug, automated if a test
   harness exists — reusing the TDD discipline embodied in
   [`woostack-execute`](../woostack-execute/SKILL.md). In a target with no test runner, the
   "failing test" is a concrete verification command (a `grep`, a `bash -n`, a link check)
   with exact expected output — never a vague "verify it works". You must have this before
   fixing.
2. **Implement one minimal fix** at the root cause identified — one change, no "while I'm here"
   improvements, no bundled refactoring.
3. **Verify the fix.** The test passes now, no other test broke, the issue is actually
   resolved. Optionally add **defense-in-depth** validation at the relevant layer boundaries so
   the same class of bad value is caught earlier next time.
4. **If the fix doesn't work,** count attempts: `< 3` → return to Phase 1 with the new
   evidence; `≥ 3` → STOP (see the escalation block).

For timing-dependent or flaky failures, replace arbitrary timeouts with **condition-based
waiting** (poll for the condition) rather than sleeping a fixed interval.

<ESCALATION>
If 3+ fixes have failed, STOP. This is not a failed hypothesis — it is a wrong-architecture
signal: each fix reveals new coupling or shared state somewhere else, fixes start needing
"massive refactoring", and each fix creates new symptoms. Question the fundamentals with the
user: is this pattern sound, or are we continuing through inertia? Do NOT attempt fix #4 before
that discussion. When invoked with `--auto`, this stop is the handback signal to the caller.
</ESCALATION>

## Mode: `--auto` vs standalone

Mode is selected by an explicit `--auto` flag — mirroring
[`woostack-execute`](../woostack-execute/SKILL.md)'s explicit `--inline/--subagent` precedent —
never by context-sniffing.

- **`--auto` (autonomous).** Run Phases 1–4 end to end. No per-fix approval gate (consistent
  with `woostack-execute` / `woostack-harden` owning none). The Iron Law still forces narrating
  the root cause before any fix. The only hard stop is the ≥3-fixes escalation, which doubles
  as the handback to the caller. `woostack-execute` dispatches this mode on a repeatedly-failing
  verification.
- **No `--auto` (standalone — the default).** After Phases 1–3 (root cause found, hypothesis
  confirmed), **stop and present the root cause plus the proposed minimal fix, and wait for an
  explicit go-ahead** before Phase 4. When the fix is applied, name
  [`woostack-commit`](../woostack-commit/SKILL.md) as the next step — debug does not commit.
- **Fail-safe.** Absence or an unrecognized flag ⇒ the gated standalone mode. An unrequested
  fix is never silently applied.
- **No target given.** `/woostack-debug` with no argument → ask what's broken; do not guess
  (mirror `woostack-execute`'s no-argument behavior).

## Memory

woostack-debug reads and writes the scoped `.woostack/memory/` store. The note schema, the
recall procedure, the reject-by-default distillation gate, and the degradation contract are
defined once in [memory.md](../woostack-init/references/memory.md) — this section says only how
debugging uses them.

- **Recall (start).** Compute the working set — the target's files: the failing test file and
  the code under suspicion. Run the recall procedure: `recall.sh` when the `woostack-init`
  scripts are present, the manual procedure (load `MEMORY.md` + the flat `memory.md`, scope-
  match, one-hop link expand) otherwise. Surface matching `gotcha`/`hotspot`/`pattern` notes
  before investigating — a matching note may already name the root cause. State whether recall
  was script-assisted or manual; never fail silently.
- **Distill (end, on a confirmed fix).** Write **one** `gotcha` note through the reject-by-
  default gate: a narrow glob `scope:` covering the touched files (a single-literal-path scope
  is trivia and is rejected), `source:` set to the owning spec/plan or `pr-N`, a terse body
  with `[[wikilinks]]` to related notes, and `updated:` stamped today. Dedupe against
  `MEMORY.md` first — update an existing note rather than adding a near-duplicate. Then run
  `build-index.sh` and `doctor.sh`. The note records the **root cause and its fix**, not the
  symptom.

## Red flags — stop and return to Phase 1

If you catch yourself thinking any of these, stop and restart at Phase 1:

- "Quick fix for now, investigate later."
- "Just try changing X and see if it works."
- "Add multiple changes, run the tests."
- "Skip the test, I'll manually verify."
- "It's probably X, let me fix that."
- "I don't fully understand but this might work."
- Proposing fixes before tracing data flow.
- "One more fix attempt" (when you have already tried 2+).
- Each fix reveals a new problem in a different place. → That is the ≥3-fixes architectural
  signal: question the architecture, don't fix again.

## Common rationalizations

| Excuse | Reality |
|---|---|
| "Issue is simple, no process needed." | Simple issues have root causes too; the process is fast for them. |
| "Emergency, no time for process." | Systematic debugging is faster than guess-and-check thrashing. |
| "I'll write the test after the fix works." | Untested fixes don't stick. The failing test first proves the fix. |
| "Multiple fixes at once saves time." | You can't isolate what worked, and it causes new bugs. |
| "I see the problem, let me fix it." | Seeing symptoms is not understanding the root cause. |

## When investigation reveals no root cause

If a genuine investigation shows the issue is truly environmental, timing-dependent, or
external: document what you investigated, implement appropriate handling (retry, timeout,
condition-based wait, a clear error message) plus logging for future investigation, and say so.
But treat this as rare — most "no root cause" outcomes are incomplete investigation.

## Hard constraints

- **Iron Law.** No fix proposed or applied before Phase 1 is complete. It and the ≥3-fixes
  ESCALATION are load-bearing blocks — keep them prominent so they survive summarization.
- **Owns no spec/plan/status.** Never writes a `.woostack/specs/` or `.woostack/plans/` file
  and never touches a spec's `status:`/`branch:`. The `spec : plan : PRs = 1 : 1 : N` invariant
  is untouched. The phase enum and join contracts live in
  [conventions.md](../woostack-status/references/conventions.md) — link, never restate.
- **Never commits or merges.** Hands the fix back: standalone names `woostack-commit`; `--auto`
  lets the caller commit in its own cadence.
- **Mode is explicit.** `--auto` ⇒ autonomous; its absence ⇒ the look-before-fix gate. Fail-
  safe to gated; never apply an unrequested fix.
- **One minimal fix at a time.** No bundled refactoring, no "while I'm here" changes.
- **Distill durable knowledge only.** Reject-by-default; dedupe; one `gotcha` per confirmed
  fix; never feature-specific trivia.
