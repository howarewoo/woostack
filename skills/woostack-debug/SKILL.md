---
name: woostack-debug
description: "Use as woostack's systematic-debugging phase — find the root cause of a bug, test failure, or unexpected behavior before any fix. Retells the four-phase method (root-cause investigation → pattern analysis → hypothesis/test → handback) with the Iron Law (no fix without root cause), wired to the .woostack/memory store (recall known gotchas at start). Invoke via /woostack-debug <target>; it runs the four-phase root-cause analysis automatically and hands the findings back. Investigative only — autonomous is its sole mode (no flag), and it never writes code, commits, or merges."
---

# woostack-debug

Find the root cause of any bug, test failure, or unexpected behavior **before** attempting a
fix. This is woostack's own systematic-debugging phase: a place every woostack skill can route
a stuck verification or a confirmed bug instead of falling back to guess-and-check. It owns no
approval gate, never writes code, never commits, and never merges — it hands the diagnosed root cause back.

It is a public command — `/woostack-debug <target>` — and an internal hook:
[`woostack-execute`](../woostack-execute/SKILL.md) and
[`woostack-execute-overnight`](../woostack-execute-overnight/SKILL.md) dispatch it on a
repeatedly-failing verification, and [`woostack-review`](../woostack-review/SKILL.md) points the
author at it for a confirmed bug. It always runs autonomously — there is no interactive mode and
no flag; running it performs a full root-cause analysis and hands the findings back.

<IRON-LAW>
NO FIX WITHOUT ROOT CAUSE INVESTIGATION FIRST.

A symptom fix is a failure. If you have not completed Phase 1 (root-cause investigation), you
may not propose or apply a fix. This holds for EVERY issue regardless of perceived simplicity
and ESPECIALLY under time pressure — systematic debugging is faster than thrashing. The root
cause is always narrated before any fix is proposed, so the "why" is always visible.
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
2. **Test minimally.** Probe the hypothesis with the smallest non-destructive check — read the
   relevant source, trace the call path, or run an existing test/command; isolate one variable at
   a time. Make no persistent code change (revert any temporary probe before handback).
3. **Verify before continuing.** Worked → Phase 4. Didn't work → form a **new** hypothesis;
   don't stack more fixes on top.
4. **When you don't know,** say "I don't understand X" and research or ask — don't pretend.

### Phase 4 — Handback

1. **Summarize findings**: Clearly list the root cause, files/lines affected, and evidence gathered.
2. **Propose minimal fix**: Detail the exact logic change required. Do not apply it.
3. **TDD context**: Name the test file and exact test cases needed to reproduce the issue (the failing test description) so the caller or fix flow can implement it.

For timing-dependent or flaky failures, recommend replacing arbitrary timeouts with **condition-based
waiting** (poll for the condition) rather than sleeping a fixed interval.

## Operation

woostack-debug always runs autonomously. Running `/woostack-debug <target>` works through
Phases 1–4 end to end — no per-hypothesis approval gate — and hands back the Phase 4 result: the
root-cause summary, the proposed minimal fix, and the TDD context. There is no interactive mode
and no `--auto` flag; autonomous is the only mode. The Iron Law still forces narrating the root
cause before any fix is proposed, so the "why" is always visible. It is investigative only — it
hands the findings back and never applies the fix itself.

- **No target given.** `/woostack-debug` with no argument → ask what's broken; do not guess
  (mirror `woostack-execute`'s no-argument behavior).

## Memory

woostack-debug reads and writes the scoped `.woostack/memory/` store and **reads** the
wholesale-loaded `.woostack/wisdom/` store. The note schema, the recall procedure, the
reject-by-default distillation gate, and the degradation contract are defined once in
[memory.md](../woostack-init/references/memory.md) (the wisdom contract in
[wisdom.md](../woostack-init/references/wisdom.md)) — this section says only how debugging uses
them.

- **Recall (start).** Compute the working set — the target's files: the failing test file and
  the code under suspicion. Run the recall procedure: `recall.sh` when the `woostack-init`
  scripts are present, the manual procedure (load `MEMORY.md` + the flat `memory.md`, scope-
  match, one-hop link expand) otherwise. Also **wholesale-load every `.woostack/wisdom/*.md`**
  when that store is present; skip silently when absent. Surface the matching scoped
  `gotcha`/`hotspot`/`pattern` notes **and** the wisdom findings before investigating — a scoped
  note names a *specific* trap, wisdom names a recurring failure *class*, and either may point at
  the root cause. Treat both as **candidate hypotheses, never answers**: a recalled note seeds a
  Phase 3 hypothesis that must still survive its test (the Iron Law holds), and you **verify any
  file, line, or symbol the note names still exists** before trusting it — notes reflect what was
  true when written and can be stale. State whether recall was script-assisted or manual; never
  fail silently.
- **Distill (end).** `woostack-debug` does not write code, so it does not distill gotcha notes directly. Memory note distillation is owned by the caller (such as `woostack-fix` or `woostack-execute`) once the minimal fix has been implemented and verified.

## Red flags — stop and return to Phase 1

If you catch yourself thinking any of these, stop and restart at Phase 1:

- "Quick fix for now, investigate later."
- "Just try changing X and see if it works."
- "Proposing fixes before tracing data flow."
- "Skip the test/reproduction, I'll manually verify."
- "It's probably X, let me write code for that."
- "I don't fully understand but this might work."

## Common rationalizations

| Excuse | Reality |
|---|---|
| "Issue is simple, no process needed." | Simple issues have root causes too; the process is fast for them. |
| "Emergency, no time for process." | Systematic debugging is faster than guess-and-check thrashing. |
| "I see the symptom, let me fix it." | Seeing symptoms is not understanding the root cause. |

## When investigation reveals no root cause

If a genuine investigation shows the issue is truly environmental, timing-dependent, or
external: document what you investigated and log findings for future investigation. But treat this as rare — most "no root cause" outcomes are incomplete investigation.

## Hard constraints

- **Iron Law.** No fix proposed or applied before Phase 1 is complete. Keep this prominent so it survives summarization.
- **Recall primes, never concludes.** A recalled scoped note or wisdom finding enters as a candidate Phase 3 hypothesis that must survive its test — never as the root-cause verdict, and never trusted before verifying the file/line/symbol it names still exists. The Iron Law is not satisfied by a recalled note.
- **Owns no spec/plan/status.** Never writes a `.woostack/specs/`, `.woostack/plans/`, or `.woostack/fixes/` file. The phase enum and join contracts live in [conventions.md](../woostack-status/references/conventions.md) — link, never restate.
- **Never writes code, commits, or merges.** Hands the findings back; does not touch repository code files.
- **Always autonomous.** Runs the four phases end to end without a user gate and hands back; owns no `--auto` flag (autonomous is the only mode) and never runs interactively. Investigative only — it never applies the fix.
