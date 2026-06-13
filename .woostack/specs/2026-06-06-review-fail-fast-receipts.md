---
name: review-fail-fast-receipts
type: spec
status: approved
date: 2026-06-06
branch: review-fail-fast-receipts
links:
  - https://github.com/howarewoo/woostack/issues/237
---

# woostack-review: fail fast when angle workers cannot execute — Design Spec

> **Plan:** [[plans/2026-06-06-review-fail-fast-receipts]]

> Visualize on demand: render this file with [spec-template.html](../../skills/woostack-build/references/spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../skills/woostack-status/references/conventions.md).

## 1. Problem

`woostack-review` ([issue #237](https://github.com/howarewoo/woostack/issues/237)) can complete
with **zero findings and report a clean PASS even when no angle analysis actually ran**. When the
review environment cannot execute per-angle workers — missing or failed model runner, bad/absent
auth, or a broken orchestrator bridge — the flow still emits `APPROVED — No validated findings`.
That is a false PASS: a quality gate that silently lets changes through without ever analyzing them.

The root cause is an **ambiguity in the empty result**. `findings.json == []` today can mean
either of two very different things:

- the PR is genuinely clean (every expected angle ran and found nothing), or
- the workers never ran (the review didn't happen).

Several mechanics collapse the second case into the first:

- **Pre-initialization to `[]`** — Stage 3 writes `[]` to every expected `findings.<angle>.json`
  *before* workers start (`run-bounded-swarm.sh`, the "initialize every expected findings artifact
  to `[]`" contract step). A worker that crashes or never runs leaves `[]`, indistinguishable from
  a clean angle.
- **Swallowed worker exit codes** — `run-bounded-swarm.sh` consumes worker failures with
  `if ! wait ...; then true; fi`; a failed worker produces no shell-level signal.
- **Swarm always exits 0** — the swarm records `degraded: true` in `swarm-metrics.json` on
  still-invalid artifacts but returns 0 regardless; nothing downstream is forced to react.
- **Downstream cannot distinguish** — `merge-findings.sh` and `intersect-findings.sh` never read
  `swarm-metrics.json`; an all-`[]` merge becomes `findings.json == []` becomes `event: APPROVE`
  in the `_header.md` payload builder.
- **CI tolerates failed angles by design** — `.github/workflows/reusable-review.yml` runs angles
  as a matrix (one job per `angle × chunk`) and explicitly states *"angle failure must not prevent
  posting findings from the angles that did succeed."* A failed angle job simply uploads no
  artifact; the validate job merges fewer files and still posts a complete-looking review.

## 2. Goal

Make `findings.json == []` mean **exactly** "every expected angle executed and found nothing." An
angle that did not execute must **never** reach the verdict stage — the run hard-fails before merge
with a clear, actionable error naming the angles that didn't run and the likely cause (configure
provider/model, install auth, or provide the correct runner override).

Concretely:

1. Add a **per-worker execution receipt** so worker execution is provable independently of whether
   findings were produced.
2. Add a **postflight receipt gate** that hard-fails the run when any expected angle lacks a valid
   receipt.
3. Add a **lightweight preflight** so the common "no provider/runner" case fails early with an
   actionable message before dispatch.
4. Adopt the **strictest threshold — every expected angle must run** — across local swarm and CI.
5. Cover the new failure paths with tests.

## 3. Non-goals

- **No change to the validator-degraded / defender-only concept.** The `degraded` flag in
  `validator-metrics.json` (prosecutor pass missing → defender-only) is a separate axis and is
  untouched. This spec changes only the *swarm*-degraded path (a worker that failed to execute).
- **No deep provider health-check / live API probe.** Preflight stays lightweight (resolve a
  provider/runner, emit an actionable error otherwise). We do not validate that a set token is
  actually valid by making a probe call — the postflight receipt gate is the real safety net and
  catches an invalid-but-present token anyway (the worker fails → no receipt → hard fail).
- **No new finding schema / no findings-envelope change.** `findings.<angle>.json` stays a bare
  JSON array. The receipt is a *separate* artifact, so nothing in merge/intersect/verdict needs to
  parse a new findings shape.
- **No change to angle detection, chunking, the adversarial validator pipeline, or the verdict
  rules themselves** beyond inserting the gate before merge.

## 4. Approach

### 4.1 The invariant

`findings.json == []` ⟺ every expected angle executed (receipt present and valid) and found
nothing. "Didn't run" is detected and hard-fails before it can become a verdict.

### 4.2 Per-worker execution receipt (worker-written)

Each angle worker writes a **receipt** as the *final* action of its brief, separate from findings:

- Path: `$OUTDIR/receipt.<angle>.json` (unchunked) or `$OUTDIR/receipt.<angle>.<chunk>.json`
  (chunked) — mirrors the `findings.<angle>[.<chunk>].json` naming so verification is symmetric
  with the existing findings check.
- Shape (JSON object):

  ```json
  {
    "angle": "<angle>",
    "chunk": "<chunk-id-or-null>",
    "runner": "<host/provider identity, e.g. claude-code | anthropic-action>",
    "model": "<resolved model slug>",
    "tier": "<fast|standard|deep>",
    "ts": "<ISO-8601 timestamp>"
  }
  ```

- A worker may legitimately run and emit `[]` findings — that is a clean angle, **receipt present →
  OK**. Only a *missing or invalid* receipt is a failure.
- **Worker-written, not runner-written**, because that is the only signal that is uniform across
  all dispatch paths: Claude Code `Task` (no shell wrapper), the shell helper
  `run-bounded-swarm.sh`, and the CI matrix (one job per angle). The `runner`/`model` fields are
  the "worker write marker with model/runner identity" the issue calls for.
- **Receipts are NOT pre-initialized** (unlike `findings.<angle>.json`, which Stage 3 pre-writes to
  `[]` for non-destructive failure). The receipt's *presence* is the proof of execution, so writing
  it ahead of time would defeat the mechanism. The receipt is the worker's *last* action; findings
  stay the existing "write `[]` first, replace just before EXIT."

**Valid-receipt contract (what the gate counts as "executed"):** a receipt is valid iff the file
exists, parses as a JSON object, its `angle` matches the expected angle (and `chunk` matches when
chunking is active), and **`runner` and `model` are both non-empty**. `tier`, `chunk`, and `ts` are
recorded but not gating. Requiring non-empty `runner` + `model` makes the marker prove a real model
ran (the issue's "model/runner identity"), not merely that a file appeared. Both dispatch paths can
satisfy this: the GHA worker has `RUN_MODEL`/`RUN_TIER` (exposed in `load-prompt.sh`'s review
context), and the chat-host orchestrator routes per-call so it knows the resolved model/tier and
passes them into the brief.

### 4.3 Lightweight preflight (pre-Stage-3)

- **GHA/CLI:** harden `detect-provider.sh` — the no-provider path already exits 1; make its error
  message actionable ("configure a provider/model, install auth, or set the runner override") and
  ensure the runner-override case is covered.
- **Local hosts:** a documented assertion at the Stage 2 → Stage 3 boundary in `SKILL.md` — the
  host confirms its sub-agent primitive (e.g. `Task`) is available before dispatch and stops with
  the actionable error if it cannot dispatch sub-agents. (Enforcement for local is still the
  postflight gate; the preflight is the earlier, friendlier error.)

### 4.4 Postflight receipt gate (new script — the single contract authority)

New `scripts/verify-receipts.sh` is the **one place** that defines the valid-receipt contract and
the hard-fail decision. It is invoked from **three entry points** (below) so the same authority
covers every dispatch path with no duplicated logic.

Behavior:

- Read the expected work items: `$OUTDIR/angles.txt`, crossed with `$OUTDIR/chunks.txt` when
  chunking is active (the same source of truth the swarm uses).
- For each expected `(angle[, chunk])`: apply the valid-receipt contract from §4.2 to
  `receipt.<angle>[.<chunk>].json`.
- **Default (gate) mode:** if **any** expected receipt is missing/invalid → emit a `::error` that
  lists the non-executing angles plus the actionable cause → **exit non-zero**. Zero valid receipts
  at all → same hard fail, message emphasizes "no angle analysis executed — check
  provider/runner/auth." On success → record `executed_angles` / `expected_angles` into
  `swarm-metrics.json` (best-effort: create or update; on the CI path where the swarm did not run,
  writing the file is optional).
- **`--list-missing` mode:** print the missing/invalid `(angle[, chunk])` items to stdout and exit
  `0` (no fail). This non-failing mode lets `run-bounded-swarm.sh` reuse the *same* validity check
  to compute its retry set, so the contract never drifts between the swarm and the gate.

Three entry points:

1. **`run-bounded-swarm.sh`** calls it (default gate mode) as its final step, so shell-helper users
   get fail-fast for free.
2. **Chat-host orchestrator** (Claude Code `Task` path, which does not use the shell helper) calls
   it directly after the swarm, before `merge-findings.sh`, and aborts the run on non-zero — covers
   both PR and local-no-PR modes.
3. **CI validate job** runs it after downloading receipts, before the prosecutor/defender passes.

### 4.5 Strictness: every expected angle must run

This is the chosen threshold (the strictest of the spectrum considered). It changes today's
tolerant swarm-degraded behavior: a worker that fails to execute is no longer reset to `[]` and
warned past — it is a hard error.

- **`run-bounded-swarm.sh`**: its "is this worker done?" decision extends from "findings is a valid
  array" to "findings is a valid array **AND** the receipt is valid." This matters because a worker
  that dies *after* its first-action `[]` findings write but *before* producing a receipt leaves a
  *valid `[]` findings file* — today's findings-only retry trigger misses it. The retry set becomes
  `(findings-invalid) ∪ (verify-receipts.sh --list-missing)`, so the same single contract drives the
  retry. After the one retry, the script calls `verify-receipts.sh` (default gate mode) as its final
  step → **exit non-zero** if any receipt is still missing, replacing the current silent "reset to
  `[]` + `::warning` + exit 0." The bounded-execution contract step "reset still-invalid artifacts
  to `[]`" changes to "after one retry, a still-missing receipt aborts the run." (Findings are still
  pre-initialized and reset to `[]`; receipts are never pre-initialized — see §4.2.)
- **`SKILL.md` Stage 3**: add the receipt-write instruction to the sub-agent brief, and instruct the
  orchestrator to run `verify-receipts.sh` after the swarm and abort on non-zero before calling
  `merge-findings.sh`. The canonical worker output-contract lives in `prompts/_header.md` (the
  "write `[]` first … replace just before EXIT" block); the receipt instruction is added there so it
  reaches every runner — including single-model-per-session hosts (Codex Action, Gemini CLI), which
  still write one receipt per angle.

### 4.6 CI alignment

- **Receipt upload:** each matrix angle job (`review` job) also produces a `receipt.*.json`. Extend
  the existing upload step's `path:` to include `/tmp/pr-review/receipt.${{ matrix.angle }}*.json`
  alongside the findings glob — same artifact (`findings-<angle>-<chunk>`), so the validate job's
  existing `pattern: findings-*` + `merge-multiple: true` download picks up both. (The receipt write
  itself comes from the shared `_header.md` contract the `mode: review` worker already loads, so no
  per-angle wiring is needed beyond the upload path.)
- **One-retry wrapper:** the `review` job's action step runs with `id: review1` +
  `continue-on-error: true`, followed by a second `if: steps.review1.outcome == 'failure'` step that
  re-invokes the identical action. No new third-party action dependency (the repo pins actions by
  SHA and avoids new deps); a duplicated `uses:` block is the dependency-free retry. Mirrors the
  local swarm's one-retry so transient blips (model timeout, rate limit) self-heal before the gate.
- **Gate placement:** the `validate` job adds a `verify-receipts.sh` step **after** the findings/
  receipt download and **before** the prosecutor/defender passes. It reads `$OUTDIR/angles.txt`
  (× `chunks.txt`) from the downloaded `review-artifacts`. Any missing/invalid receipt → the step
  exits non-zero → the validate job fails → **no review is posted** rather than posting a
  complete-looking one.
- This intentionally **reverses the current "tolerate a failed angle" behavior** (the
  `reusable-review.yml` line-156 comment and the validate job's `if: always()` tolerance). The
  one-retry wrapper absorbs transient flakiness; a genuine, persistent angle failure correctly fails
  the quality gate (correctness over availability, per the issue's framing). The validate job's
  `if:` guard stays `always() && detect == success && review != cancelled` so the gate still *runs*
  on a partial review failure — but now to **fail** it, not tolerate it.

## 5. Components & data flow

```
Stage 2  detect-angles.sh ──► angles.txt (× chunks.txt)
            │
            ├─ PREFLIGHT (light): detect-provider.sh actionable failure (GHA/CLI)
            │                     + documented subagent-availability assertion (local)
            ▼
Stage 3  swarm: per-angle worker
            ├─ writes findings.<angle>[.<chunk>].json   (bare array, may be [])
            └─ writes receipt.<angle>[.<chunk>].json    (object, proof of execution)   ◄── NEW
            │   run-bounded-swarm.sh: missing receipt = failed worker → 1 retry
            │                          still missing → EXIT NON-ZERO                     ◄── CHANGED
            ▼
GATE     verify-receipts.sh: every expected angle has a valid receipt?                  ◄── NEW SCRIPT
            │   no  → ::error (names non-executing angles + cause) → EXIT NON-ZERO (abort)
            │   yes → record executed_angles/expected_angles in swarm-metrics.json
            ▼
Stage 4  merge-findings.sh ──► raw_findings.json ──► prosecutor/defender ──► intersect ──► findings.json
            ▼
Stage 5  _header.md verdict: findings.json == []  now means a TRUE clean review
```

New / changed artifacts:

| Artifact | Producer | Role |
|---|---|---|
| `receipt.<angle>[.<chunk>].json` | angle worker | proof the worker executed (identity + ts) — **new** |
| `swarm-metrics.json` | swarm + `verify-receipts.sh` | gains `executed_angles` / `expected_angles` |

## 6. Error handling

- **Missing/invalid receipt for an expected angle** → `verify-receipts.sh` (or `run-bounded-swarm.sh`
  after retry) emits `::error`, names the offending angle(s) and the actionable cause, exits
  non-zero. The orchestrator aborts before merge; no verdict is produced.
- **Zero receipts at all** → same hard fail, message emphasizes "no angle analysis executed."
- **No provider/runner resolvable (preflight)** → `detect-provider.sh` exits 1 with an actionable
  message before any worker dispatch.
- **Transient single-angle failure** → absorbed by the one retry (local swarm and the new CI
  job-level retry wrapper). Only a failure that persists past the retry aborts the run.
- **Worker runs and legitimately finds nothing** → receipt present + `[]` findings → gate passes →
  honest clean PASS preserved.
- **Local-no-PR path** → the gate runs there too (entry point 2); a missing receipt aborts before
  the terminal findings printout, so a local review cannot misreport "no findings" when nothing ran.
- **`disable_adversarial` is independent** → the gate runs before merge regardless of the validator
  mode; it does not interact with the prosecutor/defender or the validator-`degraded` axis (§3
  non-goal).
- **Backward compatibility / lockstep:** the receipt instruction (in `_header.md` + the SKILL brief)
  and the gate scripts ship together at `@main`, so updated workers always write receipts and the
  gate always finds them. `reusable-review.yml` pins `howarewoo/woostack@main`, so consumers on
  `@main` get the worker change and the gate together — this lockstep is a **hard constraint of the
  plan** (ship the receipt-write and the gate in the same increment, never the gate alone, or every
  run self-fails). Consumers pinned to an older SHA keep today's behavior. A consumer's *custom*
  workflow that calls `mode: review` but never runs the gate simply gets an extra harmless
  `receipt.*.json` file and no new failure mode (no worse than today).

## 7. Testing

New / extended shell tests under `skills/woostack-review/scripts/tests/` (existing convention:
standalone `bash` scripts, `set -euo pipefail`, source `assert.sh`, `mktemp -d` isolation, inline
heredoc stubs):

- `test-verify-receipts-missing.sh` — angles present in `angles.txt`, one receipt absent → gate
  exits non-zero and names the missing angle.
- `test-verify-receipts-none.sh` — no receipts at all → hard fail with "no angle analysis executed."
- `test-verify-receipts-pass.sh` — all receipts present, findings `[]` → gate exits 0 (clean PASS
  still allowed when workers actually ran).
- `test-verify-receipts-chunked.sh` — chunked expected set (`angles.txt × chunks.txt`); a missing
  `(angle, chunk)` receipt fails. *(may fold into the missing test if redundant — decide in plan.)*
- `test-verify-receipts-identity.sh` — receipt file present + valid array-of-one object but `runner`
  or `model` empty → gate fails (proves the identity requirement from §4.2, not just file presence).
- `test-verify-receipts-list-missing.sh` — `--list-missing` mode prints the missing items and exits
  `0` (non-failing), so the swarm can reuse it for the retry set.
- `test-bounded-swarm-receipts.sh` (or extend `test-bounded-swarm.sh`) — worker writes findings but
  no receipt → hard-fail (non-zero exit) after one retry; worker writes both → succeeds.
- **Update existing `test-bounded-swarm.sh`:** its stub workers currently write only findings. Under
  the new contract they must also write valid receipts, or they would trip the gate and change the
  test's meaning. Update the stubs to write receipts so the *findings*-retry assertions still hold,
  and let `test-bounded-swarm-receipts.sh` own the missing-receipt fail path.
- `test-detect-provider-preflight.sh` — no provider env → exit 1 with the actionable message.

## 8. Resolved decisions

All forks resolved through ideation + the spec-harden pass. Recorded here as the settled record:

- **Fail threshold** → every expected angle must run (strictest); a missing receipt is a hard fail,
  replacing today's tolerated swarm-`degraded` warning (§4.5).
- **Preflight** → yes, lightweight, *in addition to* the postflight receipt gate (§4.3).
- **CI transient handling** → one-retry wrapper on matrix angle jobs, via the dependency-free
  `continue-on-error` + `if: failure()` re-run pattern (§4.6).
- **Receipt minimum-valid contract** → file exists, JSON object, `angle` (and `chunk`) matches,
  **`runner` + `model` non-empty**; `tier`/`ts` recorded only (§4.2).
- **merge-findings corroboration** → no. `verify-receipts.sh` is the single enforcement point; the
  merge/intersect scripts are unchanged (§3 non-goal, §4.4).
- **Gate invocation** → `verify-receipts.sh` is the single contract authority with a `--list-missing`
  mode, invoked from three entry points: end of `run-bounded-swarm.sh`, the chat-host orchestrator,
  and the CI validate job. `run-bounded-swarm.sh` reuses `--list-missing` for its retry set; receipts
  are never pre-initialized (§4.2, §4.4, §4.5).
- **Single-model-per-session hosts** → covered by the shared `_header.md` worker contract; one
  receipt per angle regardless of per-call vs per-session model routing (§4.5).
- **Lockstep** → ship the receipt-write instruction and the gate in the same increment; never the
  gate alone (§6).

No open questions remain — the spec is hardened.
