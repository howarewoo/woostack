---
type: fix
status: in-review
branch: fix/review-local-model-resolution
---

# Fix: woostack-review local workers ignore config model overrides (issue #295)

## 1. Root Cause

`woostack-review`'s shell resolver `scripts/load-prompt.sh` (`provider_tier_model`,
lines 94–110) already implements the documented model-resolution precedence:
`models.<provider>.<tier>` → flat `models.<tier>` (both from `$OUTDIR/config.json`) →
default model table. `test-load-prompt-models.sh:132-143` proves a config
`models.openai.standard` override wins there.

But that resolver runs **only on the CI/Action path**: `load-prompt.sh` requires
`PROVIDER`/`ACTION_PATH`, builds the entire prompt, and emits a single
`run_model` to `$GITHUB_OUTPUT` for *single-session* hosts. The **local
per-call-routing path** (Claude Code `Task`, where each angle is its own
sub-agent with a `model` override) never calls it.

For local runs, `SKILL.md` Stage 3 / "Model routing" (line 367) instructs the
host: "The host resolves the tier to a concrete model via the table in
`prompts/_header.md`." That table is the **default** table — precedence step 5
only. Nothing on the local dispatch path reads `$OUTDIR/config.json`'s
`models.<provider>.<tier>` / `models.<tier>` overrides (steps 3–4). So when a repo
sets `review.models.openai.standard: gpt-5.3-codex-spark` (correctly flattened by
`prefetch.sh` into `$OUTDIR/config.json` as `models.openai.standard`), the host
still spawns standard-tier workers (`bugs`, `security`, `conventions`, `skills`)
with the hardcoded default `gpt-5.4-mini`, and writes that wrong model into the
receipts.

**Evidence:** `$OUTDIR/config.json` carries `models.openai.standard` (issue body);
`load-prompt.sh:94-110` reads it but only via `GITHUB_OUTPUT`; `SKILL.md:367,
395-400` point local hosts at the static `_header.md` table with no config-read
step; `grep` shows `provider_tier_model` has exactly one caller (`load-prompt.sh`)
— there is no standalone per-spawn resolver a local host can call.

**Gotcha (most reusable takeaway):** woostack-review has *two* execution paths
that must honor the same precedence — the CI single-session host (resolved once in
`load-prompt.sh` → `GITHUB_OUTPUT`) and the local per-call-routing host (resolves
per spawn). A resolver wired into only one path silently regresses the other.

## 2. Proposed Fix

Extract the tier→model precedence into a standalone, config-aware helper that the
local dispatch path can call per spawn, and make it the single source of truth so
the CI path cannot diverge.

1. **New `scripts/resolve-model.sh`** — `resolve-model.sh --provider <p> --tier
   <fast|standard|deep>` prints the resolved model slug to stdout. Honors an
   explicit `OUTDIR`, else sources `resolve-outdir.sh`; reads `$OUTDIR/config.json`
   with precedence `models.<provider>.<tier>` → `models.<tier>` → default table
   (the canonical mirror of `using-woostack/references/model-tiers.md`). Errors
   (non-zero) on unknown provider or missing/invalid `--provider`/`--tier`. Safe to
   `source` (dual-mode guard: defines `default_model_for`/`provider_tier_model`
   without running main when sourced).
2. **Refactor `load-prompt.sh`** to `source resolve-model.sh` and drop its
   duplicated `default_model_for` / `provider_tier_model` — single source of truth,
   CI behavior unchanged (`test-load-prompt-models.sh` stays green).
3. **Update `SKILL.md`** Stage 3 + "Model routing": local per-call-routing hosts
   MUST resolve each spawn's model via
   `bash $WOO_REVIEW_ACTION_PATH/scripts/resolve-model.sh --provider <provider>
   --tier <tier>` (which consults `$OUTDIR/config.json`), and use that value for
   **both** the spawn `model` field **and** the receipt `model`. State that
   `_header.md`'s table is the precedence-step-5 default; config `models.*`
   overrides win.
4. **Regression test `tests/test-resolve-model.sh`** covering the issue's exact
   config (`models.openai.standard: gpt-5.3-codex-spark` ⇒ standard resolves to
   `gpt-5.3-codex-spark`, not `gpt-5.4-mini`), plus flat-tier fallback,
   provider-scoped-beats-flat, no-config default, and unknown-provider error.

**Scope boundary (hardened):** `resolve-model.sh` owns precedence steps **3–5**
(config `models.<provider>.<tier>` → flat `models.<tier>` → default table) for a
*given* `(provider, tier)`. Steps **1–2** stay with the host: `FORCE_TIER` /
comment override selects *which tier* to pass, and a global `inputs.model`, when
present, wins outright (the host skips the helper). This mirrors `load-prompt.sh`,
which already separates `RUN_TIER` selection from `provider_tier_model`. The helper
emits the **model slug only** — `reasoning_effort` is a single-session-host knob
owned by `load-prompt.sh`; the local per-call path and receipts need only the slug.
The shared resolver reads `"${CONFIG_PATH:-${OUTDIR:-}/config.json}"` so both
`load-prompt.sh` (sets `CONFIG_PATH`) and `resolve-model.sh` main (sets it from
`OUTDIR`) work unchanged.

## 3. Implementation Plan

- [x] **Step 1: Reproduce with a failing test (Red)**
  - Add `skills/woostack-review/scripts/tests/test-resolve-model.sh` (mirror
    `test-load-prompt-models.sh` harness style: `env -i` + `assert.sh` from
    `woostack-init/scripts/tests/assert.sh`; per-case `mktemp -d` OUTDIR).
  - Assertions: with `$OUTDIR/config.json` = `{"models":{"openai":{"standard":"gpt-5.3-codex-spark"}}}`,
    `resolve-model.sh --provider openai --tier standard` ⇒ `gpt-5.3-codex-spark`.
    Also: flat `{"models":{"standard":"flat-x"}}` ⇒ `flat-x`; provider-scoped wins
    over flat when both set; no config ⇒ `gpt-5.4-mini` (openai/standard) and
    `claude-sonnet-4-6` (anthropic/standard); unknown provider ⇒ non-zero exit.
  - Confirm it fails (script absent).
- [x] **Step 2: Apply the minimal fix (Green)**
  - Create `scripts/resolve-model.sh` with `default_model_for` +
    `provider_tier_model` (precedence `.models[$p][$t]` → `.models[$t]` →
    default), `--provider`/`--tier` arg parsing, OUTDIR/config resolution, dual-mode
    sourcing guard. `chmod +x`.
  - Re-run `test-resolve-model.sh` → green.
- [x] **Step 3: De-duplicate the resolver (Refactor)**
  - Refactor `load-prompt.sh` to `source resolve-model.sh` and remove its inline
    `default_model_for` / `provider_tier_model`.
  - Run `test-load-prompt-models.sh` → still green (CI path unchanged).
- [x] **Step 4: Wire the local dispatch path (docs)**
  - Update `SKILL.md` Stage 3 (≈line 367) and the per-call-routing bullet
    (≈lines 395–400) plus the sub-agent brief's receipt `model` note (≈lines
    357–360) to require `resolve-model.sh` for both the spawn model override and
    receipt metadata; clarify `_header.md` table = default fallback.
- [x] **Step 5: Verification**
  - Run the full review test suite:
    `for t in skills/woostack-review/scripts/tests/test-*.sh; do echo "== $t"; bash "$t" || break; done`
  - `shellcheck skills/woostack-review/scripts/resolve-model.sh skills/woostack-review/scripts/load-prompt.sh`
  - Manual: `OUTDIR=$(mktemp -d); echo '{"models":{"openai":{"standard":"gpt-5.3-codex-spark"}}}' > "$OUTDIR/config.json"; OUTDIR="$OUTDIR" bash skills/woostack-review/scripts/resolve-model.sh --provider openai --tier standard` ⇒ prints `gpt-5.3-codex-spark`.
