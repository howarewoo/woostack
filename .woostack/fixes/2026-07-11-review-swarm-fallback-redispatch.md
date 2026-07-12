---
type: fix
status: in-review
branch: fix/review-swarm-fallback-redispatch
---

# Fix: Review/sweep swarm hard-blocks on usage_limit instead of enacting the configured tier fallback (#494)

**Source:** https://github.com/howarewoo/woostack/issues/494

## 1. Root Cause

On the **omp** host a `woostack-review --full` swarm (driven by `woostack-sweep`)
hard-failed on `usage_limit_reached` under a concurrent-spawn burst even though a
usable per-tier fallback (`models.standard = [openai-codex/gpt-5.6-sol, anthropic/claude-opus-4-8]`)
was configured and the generated defs carried the comma-separated selector. Tracing the
failure backward:

1. `woostack-sweep` marked PR #1853 `blocked`
   ← the **receipt-before-clean barrier** (`skills/woostack-sweep/SKILL.md`) — no review
     receipt for HEAD.
2. No receipt for HEAD
   ← the review **receipt gate** hard-failed
     (`skills/woostack-review/scripts/verify-receipts.sh`, invoked from
     `skills/woostack-review/SKILL.md` Stage 3 postflight) — the expected `standard`/`fast`
     angle workers left no `receipt.<angle>.json`.
3. No receipts
   ← every one of ~12 concurrent `woostack-standard` (and 2 `woostack-fast`) workers exited
     `usage_limit_reached` (exit 1) on the **Codex primary** and none rotated to the
     configured `anthropic/claude-opus-4-8` fallback.

There are **two layers** to why the fallback did not engage:

- **omp native layer (out of scope — omp harness defect).** omp is documented
  (`skills/using-woostack/references/hosts/omp.md` §Host-level fallback) to install
  `models.<tier>` entries 1..n as each spawn's in-memory `retry.fallbackChains` and rotate a
  worker on usage limit. Under a **concurrent-spawn burst**, ~12 siblings hit the Codex
  primary's usage limit at the same instant; credential-cooldown state is store-level, so the
  burst collapses the whole chain and every sibling exits `usage_limit_reached` without
  rotating. Reproduced: single/forced Opus dispatch worked, only the burst failed. woostack
  **never reads or writes omp host config** (`~/.omp/`), so it cannot fix omp's spawn-time
  enactment — this is issue #494's direction 1, filed against omp.

- **woostack orchestrator layer (in scope — the real fix).** The review engine has **no
  orchestrator-side fallback enactment**. `skills/woostack-review/SKILL.md` Stage 3's retry
  (step 5: "retry missing, empty, invalid-JSON, or non-array artifacts once after the queue
  drains") re-dispatches a failed worker on the **same** agent def → the **same primary
  model**, so the retry hits the same usage limit and again leaves no receipt. Nothing
  re-dispatches the worker on the **next configured `models.<tier>` entry**, so a configured,
  usable fallback is never tried before `verify-receipts.sh` hard-fails. The operator's manual
  workaround — pinning `anthropic/claude-opus-4-8` via the eval `agent(model=…)` helper —
  completed the full swarm with clean receipts, proving the fallback was usable and that the
  orchestrator simply never enacted it.

Enabling condition confirmed in the resolvers:
`skills/woostack-review/scripts/resolve-model.sh` (and `load-prompt.sh`, which sources it)
**only ever resolve entry 0** of a `models.<tier>` array — there is no way to resolve the
next configured entry for a fallback re-dispatch.

**Receipt-gate interaction (verified — no change needed).** The just-merged fix
`2026-07-11-review-model-fallback-arrays` deliberately made `verify-receipts.sh`'s
Codex/OpenAI model check validate against **entry 0** ("a fallback entry must not satisfy
receipt validation"). That check only fires when `receipt_needs_openai_model_check` is true
(`WOO_REVIEW_PROVIDER=openai`, `WOO_REVIEW_HOST=codex`, or the receipt's own `runner` contains
`codex`). On omp the host is `omp` (not `codex`) and is multi-provider, so `WOO_REVIEW_PROVIDER`
is unset; a **cross-provider** fallback worker (Anthropic) writes an Anthropic runner + model,
the codex check is skipped, and its receipt validates. So codifying re-dispatch on a
cross-provider fallback needs **no** reversal of that guard, and the guard correctly still
rejects a same-provider Codex "fallback" that pretends to be a different Codex slug (which
would not help under provider exhaustion anyway).

## 2. Proposed Fix

Codify the proven manual workaround as automatic orchestrator recovery, so a woostack review
swarm never hard-blocks when a configured, usable `models.<tier>` fallback exists —
independent of whether the host's native fallback engaged (issue #494 directions 2 + 3). Four
in-repo edits, one PR:

1. **`skills/woostack-review/scripts/resolve-model.sh` — resolve the next configured entry.**
   Add `--index N` (default 0). `--index 0` is the unchanged primary path. `--index N` (N≥1)
   returns the model at ordered-array entry N of the **winning** leaf (provider-scoped
   non-empty array preferred, else flat non-empty array), honoring the same primary-precedence
   rule; a non-array leaf and an out-of-range index yield no output and a distinct non-zero
   exit (3) so a caller can tell "no further fallback" from a usage error (exit 1). The
   sourced `provider_tier_model` (2-arg) stays byte-for-byte compatible for `load-prompt.sh`.

2. **`skills/woostack-review/SKILL.md` Stage 3 — orchestrator auto-re-dispatch on fallback.**
   In the local-swarm retry + receipt-gate contract, codify: a worker that exits on a
   usage/rate limit (`usage_limit_reached` / `rate_limit_error`) and leaves **no receipt** is
   re-dispatched **pinned to the next configured `models.<tier>` entry** (resolved via
   `resolve-model.sh --index`), walking the chain until it produces a receipt or the configured
   chain is exhausted — **before** the receipt gate may hard-fail. Only a worker still
   unrecovered after the chain is exhausted leaves no receipt and hard-fails the gate (never a
   silently thinner review, never a manual per-worker downgrade). Scope this to hosts that can
   pin a per-worker model (per-call / agent-by-tier); per-host pin mechanics stay in the host
   file. Preserve the existing "non-empty ordered array" / "entry 0 is the primary" schema
   phrasing.

3. **`skills/using-woostack/references/hosts/omp.md` — reconcile with observed behavior.**
   Document that native `models.<tier>` enactment can fail to engage under a
   **concurrent-spawn burst** (many siblings hit the primary's usage limit simultaneously; the
   store-level credential cooldown collapses the chain), and that the resilient recovery is the
   review orchestrator re-dispatching each usage/rate-limited worker on the next configured
   entry via the eval `agent(model=<slug>)` pin (resolved with `resolve-model.sh --index`)
   before the receipt gate fails — noting the cross-provider fallback receipt validates because
   the codex model-check fires only for codex-runner receipts. Strengthen the overnight
   preflight note's wording (advisory, **not** a refuse-to-start) so it states unattended runs
   now rely on a configured cross-provider fallback for the swarm to auto-recover from primary
   exhaustion, making a run without one materially riskier. Keep
   the required `agent-by-tier`, `gen-omp-agents.sh`, `## Host-level fallback`, and
   `usage-exhaustion` phrases the sync test guards.

4. **`skills/woostack-sweep/SKILL.md` — clarify the blocker boundary.**
   Note that a swarm failing purely on `usage_limit_reached` is **not** an immediate blocker:
   the review engine auto-re-dispatches usage-limited workers on the configured `models.<tier>`
   fallback before its receipt gate fails, so a PR is `blocked` on a missing HEAD receipt only
   after the configured fallback chain is exhausted. Light touch — sweep delegates the loop to
   review.

Tests: extend `test-resolve-model.sh` for the new `--index` behavior (TDD red-first) and
`test-host-references.sh` for the reconciled omp.md + review re-dispatch contract.

Out of scope: omp's native spawn-time chain collapse under burst (direction 1) — an omp
harness defect this repo cannot touch; documented in omp.md and neutralized by the
orchestrator-side recovery so woostack never hard-blocks regardless.

## Resolved decisions (hardening)

- **Walk the whole chain, not just entry 1.** The re-dispatch increments the index
  (`--index 1`, `2`, …) and tries each configured `models.<tier>` entry in order until a
  receipt is produced or the chain is exhausted — a config may declare more than one fallback.
- **Model-only pin.** The re-dispatch pins the fallback **model** slug (the eval
  `agent(model=…)` helper takes model, not effort); this matches `resolve-model.sh` emitting a
  slug only and the proven manual workaround, which pinned the model and produced clean
  receipts. Effort otherwise rides the tier def / `thinkingLevel`.
- **`woostack-audit` inherits it for free.** Audit repoints this same review swarm at an
  all-added diff, so the Stage-3 re-dispatch benefits audit with no separate audit edit.
- **`verify-receipts.sh` unchanged.** Confirmed by reading the gate: the codex/OpenAI
  model-check fires only for codex-runner receipts (or `WOO_REVIEW_PROVIDER=openai` /
  `WOO_REVIEW_HOST=codex`, both unset on omp), so a cross-provider Anthropic fallback receipt
  validates as-is; the just-merged entry-0 guard is preserved.
- **Overnight preflight: strengthen wording, keep advisory** (user-confirmed). No change to
  `woostack-execute-overnight` start semantics — it stays a recommendation, not a refusal
  condition; only the advisory note's wording is firmed up (omp.md).
- **Resolver "no such fallback" signal: exit 3.** `--index N` with no configured entry at that
  index exits 3 (distinct from usage-error exit 1) with empty stdout, so the orchestrator can
  tell "chain exhausted" from a bad invocation.

## 3. Implementation Plan

- [x] **Step 1: Reproduce the resolver gap with a failing test**
  - Extend `skills/woostack-review/scripts/tests/test-resolve-model.sh` with cases that
    currently fail:
    - flat `{model,effort}`-object array leaf → `--index 1` prints entry-1 `.model`; `--index 0`
      still prints entry-0 `.model` (regression guard).
    - flat string array leaf → `--index 1` prints the entry-1 slug.
    - provider-scoped array leaf → `--index 1` prints its entry-1 model (provider-scoped
      preferred over flat for fallbacks too).
    - out-of-range `--index` on a real array → exit 3, empty stdout.
    - scalar / single-object leaf → `--index 1` → exit 3 (no fallback).
    - no config / empty array → `--index 1` → exit 3; `--index 0` unchanged (default / default).
    - negative or non-integer `--index` → exit 1 (usage error).
  - Run `bash skills/woostack-review/scripts/tests/test-resolve-model.sh` and confirm the new
    `--index` cases fail for the diagnosed reason (option unknown / entry-0-only), while every
    pre-existing case still passes.
- [x] **Step 2: Add `--index N` fallback resolution to `resolve-model.sh`**
  - Add a `fallback_model_at <provider> <tier> <index>` helper that selects the winning leaf
    (provider-scoped non-empty array, else flat non-empty array; a non-array winning leaf has
    no fallback) and returns entry `<index>`'s model (`.model` for object entries, raw slug for
    strings), non-zero when out of range or non-array.
  - Parse `--index N` in `main` (validate non-negative integer → else exit 1). Route `--index 0`
    through the existing `provider_tier_model` (unchanged); route `--index N≥1` through
    `fallback_model_at`, exiting 3 with an informational `::notice` on stderr when no entry
    exists at that index. Update the `# Usage:` header line so `--help` reflects `[--index N]`.
  - Keep `provider_tier_model`'s 2-arg signature and behavior intact (sourced by
    `load-prompt.sh`).
  - Run `test-resolve-model.sh` until all new and existing cases pass.
- [x] **Step 3: Codify orchestrator auto-re-dispatch in `woostack-review/SKILL.md`**
  - Amend Stage 3's local-swarm retry list and the receipt-gate paragraph so a usage/rate-limit
    worker with no receipt is re-dispatched on the next configured `models.<tier>` entry (via
    `resolve-model.sh --index`), walking the chain before the receipt gate can hard-fail; only
    an exhausted-chain gap hard-fails. Scope to per-call / agent-by-tier hosts; point per-host
    pin mechanics at the host file. Do not downgrade the review or force a manual override.
  - Preserve the schema phrases the sync test asserts.
- [x] **Step 4: Reconcile `hosts/omp.md` and clarify `woostack-sweep/SKILL.md`**
  - Update omp.md §Host-level fallback (fallback-lists paragraph), the woostack-review per-skill
    note, and the overnight preflight note per §2.3, keeping the guarded phrases.
  - Add the blocker-boundary clarification to woostack-sweep/SKILL.md per §2.4.
- [x] **Step 5: Extend the documentation-sync test**
  - Extend `skills/woostack-init/scripts/tests/test-host-references.sh` to assert omp.md
    documents the concurrent-spawn-burst limitation and the orchestrator re-dispatch recovery,
    and that `woostack-review/SKILL.md` carries the fallback re-dispatch instruction.
- [x] **Step 6: Verification**
  - `bash skills/woostack-review/scripts/tests/test-resolve-model.sh`
  - `bash skills/woostack-review/scripts/tests/test-load-prompt-models.sh` (back-compat of the
    sourced resolver)
  - `bash skills/woostack-review/scripts/tests/test-verify-receipts-openai-models.sh` (unchanged
    gate still green)
  - `bash skills/woostack-init/scripts/tests/test-host-references.sh`
  - No authored `site/content/docs/**` page changes, so no `pnpm -C site build` is required.
