---
type: fix
status: hardened
branch: fix/execute-subagent-brief-skill-scope
---

# Fix: execute subagent briefs misroute into the full woostack-review skill

## 1. Root Cause

woostack-execute's subagent driver dispatches three kinds of fresh subagent — an
implementer ([`implementer.md`](../../skills/woostack-execute/prompts/implementer.md)), a
spec-compliance reviewer
([`spec-reviewer.md`](../../skills/woostack-execute/prompts/spec-reviewer.md)), and a
code-quality reviewer
([`quality-reviewer.md`](../../skills/woostack-execute/prompts/quality-reviewer.md)) — each with a
fenced, self-standing brief. None of those briefs tell the subagent it is self-contained.

A fresh subagent boots inside the consumer repo, so it inherits that repo's `AGENTS.md`, which
says "use `using-woostack` to load repo rules and route `/woostack-*` requests." The subagent
therefore reads `skill://using-woostack`, and its task text begins `SPEC COMPLIANCE review …` /
`CODE QUALITY review …`. `using-woostack`'s routing table maps review intent to
`woostack-review` ("`/woostack-review [PR#]`, review a PR or local diff → `woostack-review`", plus
the explicit intent-routing rule "'use woostack to review this PR' means load `woostack-review`").
The subagent then reads the full **`skill://woostack-review`** orchestrator (~14.7K tokens / ~59KB).

**Evidence (recent OMP session logs, 2026-07-09):**

- The read order in every affected reviewer subagent is `skill://using-woostack` **then**
  `skill://woostack-review` (verified in `Inc2Task2SpecReview`, `Inc2Task4SpecReview`,
  `Inc4Task1SpecReview2`, and others).
- 16 execute-dispatched reviewer subagents loaded the 14.7K review skill in one day
  (~225K tokens). All 16 readers of `skill://woostack-review` were `Inc*Task*SpecReview` /
  `Inc*Task*QualityReview` subagents — never the review swarm's own angle workers.

This is two problems, not one:

1. **Token waste** — ~14.7K tokens per affected reviewer subagent, on every execute /
   execute-overnight run that uses the subagent driver.
2. **Correctness risk** — `woostack-review` is the PR-review *orchestrator* (prefetch a PR diff,
   write `findings.*.json`, post inline comments, compute a merge event). A task-scoped reviewer
   that follows it instead of its lean `spec-reviewer.md` / `quality-reviewer.md` brief is
   following the wrong contract.

This is the **same bug class as issue #447**, which already fixed it for `woostack-review`'s *own*
local angle workers: their brief states "The worker brief is self-contained: do not load or follow
`skill://woostack-review` …", enforced by
[`test-worker-brief-skill-scope.sh`](../../skills/woostack-review/scripts/tests/test-worker-brief-skill-scope.sh).
The execute subagent path was never given the same guard.

Scope note: `woostack-execute-overnight` reuses execute's `subagent-driver.md` and these same three
prompt files, so fixing them there covers the overnight path too (confirmed during Step 1 —
overnight ships no duplicate reviewer/implementer prompts).

## 2. Proposed Fix

Extend #447's self-contained-brief guard to woostack-execute's dispatched subagents — a
prompt/docs change only, no script-behavior change.

Add one guard sentence **inside the fenced brief** of each of the three prompts, so it lands in the
subagent's actual context:

> This brief is self-contained. Do NOT load or follow `skill://woostack-review`, the
> `woostack-review` `SKILL.md`, or `using-woostack` command routing — that is the PR-review
> orchestrator, not your contract; if the host auto-injected them, ignore them and follow ONLY
> this brief and the files it names.

- `implementer.md` keeps its one explicitly-named skill read (the `woostack-tdd` kernel); the
  "files it names" clause preserves that.
- Add a matching one-line reinforcement to
  [`subagent-driver.md`](../../skills/woostack-execute/references/subagent-driver.md) so the
  dispatch contract itself records that these briefs are self-contained and workers run on a
  plain/general-purpose profile (mirroring `woostack-review`'s Stage-3 wording).

Guard against regression with a new test mirroring #447, since woostack-execute currently has **no**
test harness.

## 3. Implementation Plan

- [ ] **Step 1: Reproduce with a failing test.**
  - Add `skills/woostack-execute/scripts/tests/test-subagent-brief-skill-scope.sh` (source the
    shared `skills/woostack-init/scripts/tests/assert.sh`, mirror
    `woostack-review/scripts/tests/test-worker-brief-skill-scope.sh`). For each of
    `implementer.md`, `spec-reviewer.md`, `quality-reviewer.md`, assert the file (a) contains
    `self-contained` and (b) matches `skill://woostack-review` preceded by a negation, matched
    case-insensitively (`grep -Eiq '(do not|never).*skill://woostack-review'`) so the guard's
    emphatic `Do NOT` still passes. Also assert `subagent-driver.md` records the boundary.
  - Add `skills/woostack-execute/scripts/tests/run-tests.sh` (copy the canonical runner used by
    `woostack-doctor`/`woostack-init`).
  - Run it; it MUST fail now (guard text absent) — the red state.

- [ ] **Step 2: Apply the minimal fix.**
  - Insert the guard sentence into the fenced brief of `spec-reviewer.md`, `quality-reviewer.md`,
    and `implementer.md`.
  - Add the reinforcing self-contained-brief line to `subagent-driver.md`.

- [ ] **Step 3: Verification.**
  - `bash skills/woostack-execute/scripts/tests/run-tests.sh` → green.
  - `bash skills/woostack-review/scripts/tests/run-tests.sh` → still green (no cross-skill
    regression; the #447 test is untouched).
  - Grep the three prompts to confirm the guard is inside the fenced brief block, not the prose
    preamble.
