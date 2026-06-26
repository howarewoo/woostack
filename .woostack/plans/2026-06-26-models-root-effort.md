---
type: plan
source: .woostack/specs/2026-06-26-models-root-effort.md
status: ready
branch: feature/models-root-effort
---

**Source:** [[specs/2026-06-26-models-root-effort]]

# Root model-tier config with per-tier effort — Implementation Plan

**Goal:** Lift model tiers out of `review.models` to a root `models` field (clean break) and make
each tier leaf carry an optional per-tier `effort`, resolved config-first.

**Architecture:** The tier-leaf shape is a multi-reader contract (`lockstep-edit-sites` wisdom):
the loader (`load-config.sh`) is the sole producer of the flat `$OUTDIR/config.json`; the readers
are `resolve-model.sh`, `verify-receipts.sh`, and `load-prompt.sh`. Increment 1 moves the producer
and **all** readers together — the loader normalizes every leaf to an object `{model, effort?}`,
and the readers become leaf-shape-agnostic (`object → .model`, `string → itself`) so existing
raw-string flat-config test fixtures keep passing while new object leaves resolve correctly. The
clean break (`review.models` → tailored loader error) ships in the same increment, with this
repo's own dogfood config migrated alongside. Increment 2 adds the template key + a diagnose-only
doctor migration warning. Increment 3 updates the docs/prompts to the new shape.

**Tech Stack:** Bash + embedded Python 3 (`load-config.sh`), `jq`, the repo's `assert.sh` test
harness. No new dependencies.

---

## Increment 1: Loader relocation + leaf normalization + effort, with all flat-config readers

> One independently shippable PR. Producer + every reader of the tier-leaf shape move in lockstep,
> so no runtime path ever sees an unexpected leaf shape. ~340 LOC incl tests.

### Task 1: Loader — root `models`, clean break, object normalization, effort enum

**Files:**
- Modify: `skills/woostack-review/scripts/load-config.sh:96-103` (key sets), `:140-167` (top
  capture + `review.models` rejection + legacy unknown-key exclusion), `:264-301` (models block)
- Modify: `.woostack/config.json` (this repo's dogfood config — migrated in the **same commit** as
  the loader so no intermediate commit leaves this repo's config invalid under the clean break)
- Test: `skills/woostack-review/scripts/tests/test-load-config-models-root.sh` (new)

- [ ] **Step 1: Write the failing test**
  ```bash
  cat > skills/woostack-review/scripts/tests/test-load-config-models-root.sh <<'EOF'
  #!/usr/bin/env bash
  # Root `models` field: relocation (clean break from review.models), string|object
  # leaf normalization, effort enum, empty-effort-unset, host-agnostic flat leaves.
  set -uo pipefail
  DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  ROOT="$(cd "$DIR/../../.." && pwd)"
  source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
  SCRIPT="$DIR/load-config.sh"

  # run_loader <config-json> : sets OUT (flat config dir), ERRLOG, RC.
  run_loader() {
    local cfg="$1"
    REPO="$(mktemp -d)"; ( cd "$REPO" && git init -q )
    local top; top="$(cd "$REPO" && git rev-parse --show-toplevel)"
    mkdir -p "$top/.woostack"
    printf '%s\n' "$cfg" > "$top/.woostack/config.json"
    OUT="$(mktemp -d)/out"; mkdir -p "$OUT"; ERRLOG="$OUT/err"
    ( cd "$top" && env -u GITHUB_WORKSPACE OUTDIR="$OUT" bash "$SCRIPT" ) \
      >"$OUT/out.log" 2>"$ERRLOG" && RC=0 || RC=$?
  }

  # 1. object leaf normalized + preserved
  run_loader '{"models":{"openai":{"standard":{"model":"gpt-5.4-mini","effort":"low"}}}}'
  assert_exit 0 "$RC" "root models object leaf accepted"
  assert_eq "$(jq -c '.models.openai.standard' "$OUT/config.json")" \
    '{"effort":"low","model":"gpt-5.4-mini"}' "object leaf preserved (sorted keys)"

  # 2. string leaf normalized to object
  run_loader '{"models":{"openai":{"standard":"gpt-5.4-mini"}}}'
  assert_eq "$(jq -c '.models.openai.standard' "$OUT/config.json")" \
    '{"model":"gpt-5.4-mini"}' "string leaf normalized to {model}"

  # 3. review.models rejected (clean break, tailored message)
  run_loader '{"review":{"models":{"openai":{"standard":"x"}}}}'
  assert_exit 1 "$RC" "review.models rejected"
  assert_contains "$(cat "$ERRLOG")" "has moved to a top-level" "tailored relocation message"

  # 4. object leaf missing model
  run_loader '{"models":{"openai":{"standard":{"effort":"low"}}}}'
  assert_exit 1 "$RC" "object leaf without model rejected"
  assert_contains "$(cat "$ERRLOG")" "model must be a non-empty string" "names missing model"

  # 5. unknown leaf key
  run_loader '{"models":{"openai":{"standard":{"model":"x","bogus":1}}}}'
  assert_exit 1 "$RC" "unknown leaf key rejected"
  assert_contains "$(cat "$ERRLOG")" "unknown key(s): bogus" "names unknown leaf key"

  # 6. invalid effort
  run_loader '{"models":{"openai":{"standard":{"model":"x","effort":"turbo"}}}}'
  assert_exit 1 "$RC" "invalid effort rejected"
  assert_contains "$(cat "$ERRLOG")" "effort must be one of" "names effort enum"

  # 7. empty effort = unset (no error, no effort key emitted)
  run_loader '{"models":{"openai":{"standard":{"model":"x","effort":""}}}}'
  assert_exit 0 "$RC" "empty effort accepted as unset"
  assert_eq "$(jq -c '.models.openai.standard' "$OUT/config.json")" '{"model":"x"}' \
    "empty effort dropped from normalized leaf"

  # 8. host-agnostic flat tier leaf normalized
  run_loader '{"models":{"standard":"flat-x"}}'
  assert_eq "$(jq -c '.models.standard' "$OUT/config.json")" '{"model":"flat-x"}' \
    "flat tier leaf normalized to {model}"

  # 9. root models alongside a (models-free) review block: both parsed
  run_loader '{"review":{"metrics":true},"models":{"openai":{"standard":"x"}}}'
  assert_exit 0 "$RC" "root models next to review block accepted"
  assert_eq "$(jq -r '.metrics' "$OUT/config.json")" "true" "review.metrics still parsed"
  assert_eq "$(jq -c '.models.openai.standard' "$OUT/config.json")" '{"model":"x"}' \
    "sibling root models parsed (not silently ignored)"

  finish
  EOF
  chmod +x skills/woostack-review/scripts/tests/test-load-config-models-root.sh
  ```

- [ ] **Step 2: Run the test, confirm it fails**
  Run: `bash skills/woostack-review/scripts/tests/test-load-config-models-root.sh`
  Expected: FAIL — case 3 fails (`review.models` is currently accepted, loader exits 0), and the
  object-leaf cases fail (current loader requires string leaves: `models.openai.standard must be a
  non-empty string`).

- [ ] **Step 3: Minimal implementation**
  Edit `skills/woostack-review/scripts/load-config.sh`.

  (a) Key sets — remove `"models"` from `REVIEW_KEYS`, add `EFFORT_LEVELS` (lines 96-103):
  ```python
  REVIEW_KEYS = {
      "angles", "severity_floor", "ignore", "project_rules",
      "authors_skip", "release_rollup_pattern", "fix_commands",
      "disable_adversarial", "metrics", "chunking", "force_tier", "nits",
      "defer_markers",
  }
  MODEL_TIERS = {"fast", "standard", "deep"}
  MODEL_PROVIDERS = {"anthropic", "openai", "google", "openrouter"}
  EFFORT_LEVELS = {"minimal", "low", "medium", "high", "xhigh"}
  ```

  (b) Capture true top-level + reject `review.models` + exclude `models` from legacy unknown check.
  Replace the block at lines 140-167:
  ```python
  if not isinstance(raw, dict):
      loud("top-level JSON must be an object, got {}".format(type(raw).__name__))

  # Capture the true top-level object before the review-block reassignment below.
  # Root-level `models` is read from `top`, independent of the `review` block, so a
  # root `models` sibling next to a `review` block is parsed (not silently ignored).
  top = raw

  # Resolve the review config block. Canonical form nests it under `review`;
  # sibling top-level namespaces (e.g. build/bootstrap config, and `models`) are
  # left alone. Legacy form puts review keys at the top level — accepted with a
  # deprecation notice during the transition.
  if "review" in raw:
      rc = raw["review"]
      if not isinstance(rc, dict):
          loud("`review` must be an object, got {}".format(type(rc).__name__))
      if "models" in rc:
          loud("`review.models` has moved to a top-level `models` field; "
               "move it out of `review`, e.g. "
               "{\"models\": {\"openai\": {\"standard\": "
               "{\"model\": \"gpt-5.4-mini\", \"effort\": \"xhigh\"}}}}")
      unknown = sorted(set(rc.keys()) - REVIEW_KEYS)
      if unknown:
          loud("unknown `review` key(s): {}".format(", ".join(unknown)))
  else:
      rc = raw
      legacy_review = sorted(set(rc.keys()) & REVIEW_KEYS)
      unknown = sorted(set(rc.keys()) - REVIEW_KEYS - {"models"})
      if unknown:
          loud("unknown top-level key(s): {} (review settings now nest under `review`)".format(", ".join(unknown)))
      if legacy_review:
          sys.stderr.write(
              "::warning file=.woostack/config.json::review settings at the top level are deprecated; "
              "nest them under a `review` object, e.g. {\"review\": {...}}\n"
          )

  out = {}
  raw = rc
  ```

  (c) Models block — read from `top`, normalize each leaf. Replace lines 264-301:
  ```python
  def parse_model_leaf(label, val):
      # A tier leaf is a model-slug string OR an object {model, effort?}; normalize
      # both to {model, [effort]}. Empty effort string = unset (mirrors force_tier).
      if isinstance(val, str):
          if not val.strip():
              loud("{} must be a non-empty string".format(label))
          return {"model": val.strip()}
      if isinstance(val, dict):
          bad_leaf = sorted(set(val.keys()) - {"model", "effort"})
          if bad_leaf:
              loud("{} has unknown key(s): {} (valid: model, effort)".format(label, ", ".join(bad_leaf)))
          model = val.get("model")
          if not isinstance(model, str) or not model.strip():
              loud("{}.model must be a non-empty string".format(label))
          leaf = {"model": model.strip()}
          if "effort" in val:
              eff = val["effort"]
              if not isinstance(eff, str):
                  loud("{}.effort must be a string".format(label))
              eff_lc = eff.strip().lower()
              if eff_lc:
                  if eff_lc not in EFFORT_LEVELS:
                      loud("{}.effort must be one of: {} (got '{}')".format(
                          label, ", ".join(sorted(EFFORT_LEVELS)), eff))
                  leaf["effort"] = eff_lc
          return leaf
      loud("{} must be a string or an object with a `model` key".format(label))

  if "models" in top:
      models = top["models"]
      if not isinstance(models, dict):
          loud("`models` must be an object with fast/standard/deep keys and/or provider objects")
      valid_model_keys = MODEL_TIERS | MODEL_PROVIDERS
      bad = sorted(set(models.keys()) - valid_model_keys)
      if bad:
          loud("unknown models key(s): {} (valid tiers: {}; valid providers: {})".format(
              ", ".join(bad), ", ".join(sorted(MODEL_TIERS)), ", ".join(sorted(MODEL_PROVIDERS))))
      cleaned_models = {}
      for key, val in models.items():
          if key in MODEL_TIERS:
              cleaned_models[key] = parse_model_leaf("models.{}".format(key), val)
              continue
          if not isinstance(val, dict):
              loud("models.{} must be an object with fast/standard/deep keys".format(key))
          bad_tiers = sorted(set(val.keys()) - MODEL_TIERS)
          if bad_tiers:
              loud("unknown models.{} tier(s): {} (valid: {})".format(
                  key, ", ".join(bad_tiers), ", ".join(sorted(MODEL_TIERS))))
          cleaned_provider = {}
          for tier, leaf in val.items():
              cleaned_provider[tier] = parse_model_leaf("models.{}.{}".format(key, tier), leaf)
          cleaned_models[key] = cleaned_provider
      out["models"] = cleaned_models
  ```

- [ ] **Step 4: Run the test, confirm it passes**
  Run: `bash skills/woostack-review/scripts/tests/test-load-config-models-root.sh`
  Expected: PASS

- [ ] **Step 5: Confirm the existing loader test still passes (no regression on the review path)**
  Run: `bash skills/woostack-review/scripts/tests/test-load-config-root.sh`
  Expected: PASS (the `{"review":{"severity_floor":"low"}}` path is untouched)

- [ ] **Step 6: Migrate this repo's dogfood config in the same change**
  The clean break now rejects this repo's own pre-migration `.woostack/config.json` (it still has
  `review.models`). Confirm the rejection, then migrate. First confirm the failure:
  ```bash
  OUT="$(mktemp -d)"; OUTDIR="$OUT" bash skills/woostack-review/scripts/load-config.sh; echo "exit=$?"
  ```
  Expected: FAIL — `exit=1`, `::error ... review.models has moved to a top-level models field`.
  Then write `.woostack/config.json` (models to root, object leaf with effort — dogfoods the feature):
  ```json
  {"models":{"openai":{"standard":{"model":"gpt-5.4-mini","effort":"xhigh"}}},"review":{"metrics":true},"status":{"staleDays":14}}
  ```

- [ ] **Step 7: Confirm the migrated repo config parses**
  ```bash
  OUT="$(mktemp -d)"; OUTDIR="$OUT" bash skills/woostack-review/scripts/load-config.sh && \
    jq -c '.models.openai.standard' "$OUT/config.json"
  ```
  Expected: PASS — exit 0, prints `{"effort":"xhigh","model":"gpt-5.4-mini"}`.

- [ ] **Step 8: Commit (loader + dogfood config together)**
  ```bash
  gt create -m "feat(review): root models config field + per-tier effort (clean break)"
  ```

### Task 2: `resolve-model.sh` — leaf-shape-agnostic model lookup

**Files:**
- Modify: `skills/woostack-review/scripts/resolve-model.sh:67,72`
- Test: `skills/woostack-review/scripts/tests/test-resolve-model.sh` (extend)

- [ ] **Step 1: Write the failing test** — append object-leaf cases before `finish` (line 103):
  ```bash
  # --- object leaf {model,effort}: resolver returns .model ---
  outdir="$(mktemp -d)"
  printf '%s\n' '{"models":{"openai":{"standard":{"model":"obj-standard-x","effort":"low"}}}}' > "$outdir/config.json"
  assert_eq "$(run_resolve "$outdir" --provider openai --tier standard)" "obj-standard-x" \
    "object leaf {model,effort}: resolver returns .model"
  rm -rf "$outdir"

  # --- flat object leaf ---
  outdir="$(mktemp -d)"
  printf '%s\n' '{"models":{"standard":{"model":"flat-obj-y"}}}' > "$outdir/config.json"
  assert_eq "$(run_resolve "$outdir" --provider openai --tier standard)" "flat-obj-y" \
    "flat object leaf: resolver returns .model"
  rm -rf "$outdir"
  ```

- [ ] **Step 2: Run the test, confirm it fails**
  Run: `bash skills/woostack-review/scripts/tests/test-resolve-model.sh`
  Expected: FAIL — object leaf returns the JSON object string (e.g. `{"effort":"low","model":...}`),
  not `obj-standard-x`.

- [ ] **Step 3: Minimal implementation** — make both jq lookups object-safe.
  `resolve-model.sh:67`:
  ```bash
      override="$(jq -r --arg p "$provider" --arg t "$tier" '(.models[$p][$t] | if type=="object" then .model else . end) // empty' "$config" 2>/dev/null || true)"
  ```
  `resolve-model.sh:72`:
  ```bash
      override="$(jq -r --arg t "$tier" '(.models[$t] | if type=="object" then .model else . end) // empty' "$config" 2>/dev/null || true)"
  ```

- [ ] **Step 4: Run the test, confirm it passes**
  Run: `bash skills/woostack-review/scripts/tests/test-resolve-model.sh`
  Expected: PASS (string-leaf cases unchanged: `else .` returns the bare slug)

- [ ] **Step 5: Commit**
  ```bash
  gt modify -c -m "feat(review): resolve-model reads object {model} tier leaves"
  ```

### Task 3: `verify-receipts.sh` — leaf-shape-agnostic expected-model lookup

**Files:**
- Modify: `skills/woostack-review/scripts/verify-receipts.sh:67,72`
- Test: `skills/woostack-review/scripts/tests/test-verify-receipts-openai-models.sh` (extend)

- [ ] **Step 1: Write the failing test** — insert an object-leaf case after line 33 (before the
  `unset WOO_REVIEW_PROVIDER` at line 35, while provider is still openai):
  ```bash
  printf '{"models":{"openai":{"standard":{"model":"gpt-obj-standard","effort":"low"}}}}\n' > "$OUTDIR/config.json"
  printf '{"angle":"bugs","chunk":null,"runner":"codex-subagent","model":"gpt-obj-standard","tier":"standard","ts":"t"}\n' > "$OUTDIR/receipt.bugs.json"
  rc=0; bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
  assert_exit 0 "$rc" "OpenAI object-leaf {model,effort} config override resolves to .model"
  ```

- [ ] **Step 2: Run the test, confirm it fails**
  Run: `bash skills/woostack-review/scripts/tests/test-verify-receipts-openai-models.sh`
  Expected: FAIL — expected model resolves to the object JSON string, so the matching receipt is
  judged a mismatch and the script exits 1.

- [ ] **Step 3: Minimal implementation** — make both jq lookups object-safe.
  `verify-receipts.sh:67`:
  ```bash
      override="$(jq -r --arg p "$provider" --arg t "$tier" '(.models[$p][$t] | if type=="object" then .model else . end) // empty' "$config" 2>/dev/null || true)"
  ```
  `verify-receipts.sh:72`:
  ```bash
      override="$(jq -r --arg t "$tier" '(.models[$t] | if type=="object" then .model else . end) // empty' "$config" 2>/dev/null || true)"
  ```

- [ ] **Step 4: Run the test, confirm it passes**
  Run: `bash skills/woostack-review/scripts/tests/test-verify-receipts-openai-models.sh`
  Expected: PASS (string-leaf override cases at lines 25/30 unchanged)

- [ ] **Step 5: Commit**
  ```bash
  gt modify -c -m "feat(review): verify-receipts reads object {model} tier leaves"
  ```

### Task 4: `load-prompt.sh` — effort resolved config-first

**Files:**
- Modify: `skills/woostack-review/scripts/load-prompt.sh` (add `config_effort_for`; wire into the
  openai effort block at lines 115-120)
- Test: `skills/woostack-review/scripts/tests/test-load-prompt-models.sh` (extend)

- [ ] **Step 1: Write the failing test** — append before `finish` (line 155):
  ```bash
  # Config object-leaf effort wins over the model/tier default.
  outdir="$(mktemp -d)"; github_output="$outdir/github_output"; touch "$github_output"
  printf '%s\n' '{"models":{"openai":{"standard":{"model":"gpt-5.4-mini","effort":"low"}}}}' > "$outdir/config.json"
  run_load_prompt "$outdir" "$github_output"
  run_model="$(grep '^run_model=' "$github_output" | cut -d= -f2 || echo "")"
  run_effort="$(grep '^run_effort=' "$github_output" | cut -d= -f2 || echo "")"
  assert_eq "$run_model" "gpt-5.4-mini" "config object leaf model resolves"
  assert_eq "$run_effort" "low" "config .effort wins over tier/model default"
  rm -rf "$outdir"

  # INPUT_OPENAI_EFFORT still beats config .effort.
  outdir="$(mktemp -d)"; github_output="$outdir/github_output"; touch "$github_output"
  printf '%s\n' '{"models":{"openai":{"standard":{"model":"gpt-5.4-mini","effort":"low"}}}}' > "$outdir/config.json"
  run_load_prompt "$outdir" "$github_output" INPUT_OPENAI_EFFORT="high"
  run_effort="$(grep '^run_effort=' "$github_output" | cut -d= -f2 || echo "")"
  assert_eq "$run_effort" "high" "explicit INPUT_OPENAI_EFFORT beats config .effort"
  rm -rf "$outdir"

  # Object leaf without effort falls through to the model default (xhigh for gpt-5.4-mini).
  outdir="$(mktemp -d)"; github_output="$outdir/github_output"; touch "$github_output"
  printf '%s\n' '{"models":{"openai":{"standard":{"model":"gpt-5.4-mini"}}}}' > "$outdir/config.json"
  run_load_prompt "$outdir" "$github_output"
  run_effort="$(grep '^run_effort=' "$github_output" | cut -d= -f2 || echo "")"
  assert_eq "$run_effort" "xhigh" "object leaf without effort uses model/tier default"
  rm -rf "$outdir"
  ```

- [ ] **Step 2: Run the test, confirm it fails**
  Run: `bash skills/woostack-review/scripts/tests/test-load-prompt-models.sh`
  Expected: FAIL — the first new case expects `run_effort=low` but, with `model=gpt-5.4-mini`,
  the current code derives `xhigh` from the model default (config `.effort` is never read).

- [ ] **Step 3: Minimal implementation**
  Add the helper after the `resolve-model.sh` source (after line 65), e.g. just below it:
  ```bash
  # config_effort_for <provider> <tier> → per-tier effort from $CONFIG_PATH, else empty.
  # The loader normalizes every tier leaf to {model,[effort]}; read .effort provider-scoped
  # first, then flat. Empty when unset → caller falls back to model/tier defaults.
  config_effort_for() {
    local provider="$1" tier="$2" eff=""
    if [ -n "${CONFIG_PATH:-}" ] && [ -f "$CONFIG_PATH" ]; then
      eff="$(jq -r --arg p "$provider" --arg t "$tier" \
        '(.models[$p][$t].effort? // .models[$t].effort?) // empty' "$CONFIG_PATH" 2>/dev/null || true)"
    fi
    printf '%s' "$eff"
  }
  ```
  Wire config-first into the openai effort block — replace lines 115-120:
  ```bash
    if [ -z "$RUN_EFFORT" ]; then
      RUN_EFFORT="$(config_effort_for "$PROVIDER" "$RUN_TIER")"
    fi
    if [ -z "$RUN_EFFORT" ]; then
      RUN_EFFORT="$(default_openai_effort_for_model "$RUN_MODEL")"
      if [ -z "$RUN_EFFORT" ]; then
        RUN_EFFORT="$(default_openai_effort_for "$RUN_TIER")"
      fi
    fi
  ```
  (Precedence: `INPUT_OPENAI_EFFORT` → config `.effort` → model default → tier default. The
  existing `minimal|low|medium|high|xhigh` validation at lines 121-127 still runs, so a config
  effort is re-validated host-side too.)

- [ ] **Step 4: Run the test, confirm it passes**
  Run: `bash skills/woostack-review/scripts/tests/test-load-prompt-models.sh`
  Expected: PASS (existing string-leaf case at line 135 still yields `medium` — string leaf has no
  `.effort`, so it falls through to the gpt-5.5 model default)

- [ ] **Step 5: Commit**
  ```bash
  gt modify -c -m "feat(review): load-prompt resolves OpenAI effort config-first"
  ```

---

## Increment 2: Template key + diagnose-only doctor migration check

> One independently shippable PR. Adds the discoverable template key and a proactive warning so a
> stale `review.models` is caught before a review run fails. ~70 LOC. Stacks on Increment 1.

### Task 1: Init template — root `models` key

**Files:**
- Modify: `skills/woostack-init/templates/config.json`
- Test: `skills/woostack-doctor/scripts/tests/test-health-checks.sh` (or `test-doctor.sh`) — verify
  config-keys requires the new key (see Step 1)

- [ ] **Step 1: Write the failing check** — confirm the template lacks a root `models` key today:
  Run: `jq -e 'has("models")' skills/woostack-init/templates/config.json; echo "exit=$?"`
  Expected: FAIL — `exit=1` (key absent; `jq -e` false → exit 1).

- [ ] **Step 2: Confirm the failure** (same command) — Expected: `false` / exit 1.

- [ ] **Step 3: Add the key** — write `skills/woostack-init/templates/config.json`:
  ```json
  {
    "models": {},
    "review": {},
    "status": {
      "staleDays": 14
    }
  }
  ```

- [ ] **Step 4: Run the check, confirm it passes**
  Run: `jq -e 'has("models")' skills/woostack-init/templates/config.json; echo "exit=$?"`
  Expected: PASS — `true` / `exit=0`. (The doctor `config-keys.sh` check reads template top-level
  keys and will now require root `models` in consumer configs; this repo's config already has it
  after Increment 1.)

- [ ] **Step 5: Verify the doctor still passes on this repo**
  Run: `bash skills/woostack-doctor/scripts/doctor.sh --check . ; echo "exit=$?"`
  Expected: PASS — `exit=0` (this repo's config has root `models` from Increment 1, so config-keys
  finds the now-required key).

- [ ] **Step 6: Commit**
  ```bash
  gt create -m "feat(init): add root models key to config template"
  ```

### Task 2: Doctor migration check — warn on lingering `review.models`

**Files:**
- Create: `skills/woostack-doctor/scripts/checks/review-models-moved.sh`
- Test: `skills/woostack-doctor/scripts/tests/test-review-models-moved.sh` (new)

- [ ] **Step 1: Write the failing test**
  ```bash
  cat > skills/woostack-doctor/scripts/tests/test-review-models-moved.sh <<'EOF'
  #!/usr/bin/env bash
  set -uo pipefail
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source "$HERE/../../../woostack-init/scripts/tests/assert.sh"
  set +e
  C="$HERE/../checks"
  r="$(mktemp -d)"; mkdir -p "$r/.woostack"

  printf '%s\n' '{"review":{"models":{"openai":{"standard":"x"}}}}' > "$r/.woostack/config.json"
  out="$(bash "$C/review-models-moved.sh" "$r")"
  assert_contains "$out" "$(printf 'warn\treview-models-moved')" "review.models present → warn"
  assert_contains "$out" ".woostack/config.json" "names the config file"

  printf '%s\n' '{"models":{"openai":{"standard":{"model":"x"}}}}' > "$r/.woostack/config.json"
  assert_eq "$(bash "$C/review-models-moved.sh" "$r")" "" "root models only → silent"

  printf '%s\n' '{"review":{"metrics":true}}' > "$r/.woostack/config.json"
  assert_eq "$(bash "$C/review-models-moved.sh" "$r")" "" "review block without models → silent"

  rm -f "$r/.woostack/config.json"
  assert_eq "$(bash "$C/review-models-moved.sh" "$r")" "" "no config → silent"

  assert_eq "$(grep -nE '(^|[^[:alnum:]_])(git|gh)[[:space:]]' "$C/review-models-moved.sh")" "" \
    "migration check calls no git/gh"
  rm -rf "$r"
  finish
  EOF
  chmod +x skills/woostack-doctor/scripts/tests/test-review-models-moved.sh
  ```

- [ ] **Step 2: Run the test, confirm it fails**
  Run: `bash skills/woostack-doctor/scripts/tests/test-review-models-moved.sh`
  Expected: FAIL — `review-models-moved.sh` does not exist yet.

- [ ] **Step 3: Minimal implementation**
  ```bash
  cat > skills/woostack-doctor/scripts/checks/review-models-moved.sh <<'EOF'
  #!/usr/bin/env bash
  # review-models-moved.sh — migration aid: model tiers moved from `review.models` to a
  # top-level `models` field (clean break in woostack-review/scripts/load-config.sh).
  # Diagnose-only: warns when a consumer config still nests models under `review`.
  set -uo pipefail
  emit() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"; }
  command -v jq >/dev/null 2>&1 || exit 0
  WOO_ROOT="${1:-.}"
  CFG="$WOO_ROOT/.woostack/config.json"
  [ -f "$CFG" ] || exit 0
  has="$(jq -r 'try (.review.models != null) catch false' "$CFG" 2>/dev/null || echo false)"
  if [ "$has" = "true" ]; then
    emit warn review-models-moved report ".woostack/config.json" \
      "review.models has moved to a top-level \`models\` field; move it out of \`review\` (see woostack-review SKILL.md)"
  fi
  EOF
  chmod +x skills/woostack-doctor/scripts/checks/review-models-moved.sh
  ```

- [ ] **Step 4: Run the test, confirm it passes**
  Run: `bash skills/woostack-doctor/scripts/tests/test-review-models-moved.sh`
  Expected: PASS

- [ ] **Step 5: Confirm the check is discovered by the orchestrator and this repo stays clean**
  Run: `bash skills/woostack-doctor/scripts/doctor.sh . >/dev/null; echo "exit=$?"`
  Expected: PASS — `exit=0`. This repo's config has root `models` (no `review.models`), so the new
  check is silent; `doctor.sh` auto-runs every `checks/*.sh`, so no registration step is needed.

- [ ] **Step 6: Commit**
  ```bash
  gt modify -c -m "feat(doctor): warn on lingering review.models (migration aid)"
  ```

---

## Increment 3: Docs + provider prompts to the new shape

> One independently shippable, docs-only PR. Updates the authored schema/reference text and the
> provider-prompt jq snippets so the documented contract matches the code. ~80 LOC. Stacks on
> Increment 2.

### Task 1: `woostack-review/SKILL.md` — schema, key reference, precedence

**Files:**
- Modify: `skills/woostack-review/SKILL.md:171-185` (schema example), `:206` (key reference),
  `:212` (precedence line)

- [ ] **Step 1: Write the failing check** — confirm `models` is still nested under `review` in the
  schema example:
  Run: `awk 'NR>=149 && NR<=194' skills/woostack-review/SKILL.md | grep -n '"models"'`
  Expected: FAIL-state evidence — `"models"` appears indented inside the `"review": { ... }` block
  (line ~171).

- [ ] **Step 2: Confirm the failure** (same command) — Expected: shows the nested `"models"` line.

- [ ] **Step 3: Edit the doc.**
  (a) In the JSON example, **remove** the `models` block (lines 171-185) from inside `"review"`,
  and add a sibling root `"models"` block before `"review"` (so the example shows the new home).
  The root block:
  ```json
    "models": {
      "fast": "anthropic/claude-haiku-4-5",
      "standard": { "model": "openai/gpt-5.4-mini", "effort": "xhigh" },
      "deep": "anthropic/claude-opus-4-8",
      "openai": {
        "fast": { "model": "gpt-5.3-codex-spark", "effort": "xhigh" },
        "standard": { "model": "gpt-5.4-mini", "effort": "low" },
        "deep": { "model": "gpt-5.5", "effort": "medium" }
      },
      "anthropic": {
        "fast": "claude-haiku-4-5",
        "standard": "claude-sonnet-4-6",
        "deep": "claude-opus-4-8"
      }
    },
  ```
  (b) Replace the `**`models`**` key-reference bullet (line 206):
  ```markdown
  - **`models`** — **root-level** per-tier model overrides (moved out of `review.models`; a
    lingering `review.models` is now a hard loader error). Each tier leaf is a model-slug string
    **or** an object `{ "model": "<slug>", "effort": "<level>" }` where `effort` is one of
    `minimal | low | medium | high | xhigh` (empty = unset). Use flat `models.fast` / `.standard`
    / `.deep` as provider-agnostic fallbacks, or provider-scoped maps such as
    `models.openai.deep`, `models.anthropic.standard`. The action input `inputs.model` still wins.
    Effort is consumed by OpenAI/Codex (`load-prompt.sh`), config-first over the built-in default.
  ```
  (c) Update the precedence line (line 212): replace `→ `models.<provider>.<tier>` → flat
  `models.<tier>`` with the same wording but note these are now **root** `models.*` keys (drop any
  `review.` implication). Concretely, ensure the sentence reads
  `… → action input `inputs.model` → root `models.<provider>.<tier>` → flat root `models.<tier>` →
  table default …`.

- [ ] **Step 4: Run the check, confirm it passes**
  Run: `awk 'NR>=148 && NR<=200' skills/woostack-review/SKILL.md | grep -nE '"models"|effort'`
  Expected: PASS — `"models"` now appears as a top-level sibling (not inside `review`) and `effort`
  appears in the leaf objects.

- [ ] **Step 5: Commit**
  ```bash
  gt create -m "docs(review): document root models field + per-tier effort"
  ```

### Task 2: `_header.md` — tier-resolution binding + per-repo config table

**Files:**
- Modify: `skills/woostack-review/prompts/_header.md:73-78` (binding paragraph), `:94` (config
  table row)

- [ ] **Step 1: Write the failing check**
  Run: `grep -n 'models.<provider>.<tier>` / `models.<tier>` in `/tmp/pr-review/config.json' skills/woostack-review/prompts/_header.md`
  Expected: FAIL-state evidence — line 75 still describes the override keys without noting they are
  root-level or that leaves may carry effort.

- [ ] **Step 2: Confirm the failure** (same command) — Expected: shows line 75.

- [ ] **Step 3: Edit the doc.**
  (a) In the binding paragraph (line 75), change the override-key description to make clear the keys
  are **root** `models.<provider>.<tier>` / `models.<tier>` (no longer under `review`), and that a
  leaf is `"<slug>"` or `{ "model", "effort" }`.
  (b) Replace the config-table row at line 94:
  ```markdown
  | root `models.fast` / `.standard` / `.deep`; `models.<provider>.<tier>` (leaf: `"<slug>"` or `{model, effort}`) | orchestrator prompts (tier resolution) + `load-prompt.sh` (OpenAI effort) | Stage 2 |
  ```

- [ ] **Step 4: Run the check, confirm it passes**
  Run: `grep -nE 'root `models|\{model, effort\}' skills/woostack-review/prompts/_header.md`
  Expected: PASS — the binding paragraph and table row now reference root `models` and the
  `{model, effort}` leaf.

- [ ] **Step 5: Commit**
  ```bash
  gt modify -c -m "docs(review): _header reflects root models + effort leaf"
  ```

### Task 3: `model-tiers.md` — formalize effort + override precedence

**Files:**
- Modify: `skills/using-woostack/references/model-tiers.md` (Override precedence section + a note
  formalizing `effort` as a config field)

- [ ] **Step 1: Write the failing check**
  Run: `grep -n 'review' skills/using-woostack/references/model-tiers.md`
  Expected: FAIL-state evidence — the precedence section binds review to
  `models.<provider>.<tier>` in `/tmp/pr-review/config.json` but does not mention that the source
  consumer key is now **root** `models` nor that a leaf may carry `effort`.

- [ ] **Step 2: Confirm the failure** (same command) — Expected: shows the binding paragraph.

- [ ] **Step 3: Edit the doc.** In the "Override precedence (generic)" section, update the
  `woostack-review` binding sentence so the per-provider/per-tier and flat keys are described as
  **root** `models.*` keys in the consumer `.woostack/config.json` (canonicalized into
  `/tmp/pr-review/config.json`), and add one sentence: each tier leaf is a model-slug string or an
  object `{ model, effort }`, where `effort` (`minimal | low | medium | high | xhigh`) is a config
  field — replacing the table's informational `reasoning_effort:` annotations as the source of
  truth for effort; the table annotations remain illustrative defaults.

- [ ] **Step 4: Run the check, confirm it passes**
  Run: `grep -nE 'root `models|\{ model, effort \}|effort' skills/using-woostack/references/model-tiers.md`
  Expected: PASS — the precedence section now references root `models` and the `{model, effort}`
  leaf / config effort field.

- [ ] **Step 5: Commit**
  ```bash
  gt modify -c -m "docs(model-tiers): formalize effort as a config field"
  ```

### Task 4: Provider prompts — object-safe override jq + effort note

**Files:**
- Modify: `skills/woostack-review/prompts/anthropic.md:67`, `skills/woostack-review/prompts/openai.md:21,25`,
  `skills/woostack-review/prompts/opencode.md:27`

- [ ] **Step 1: Write the failing check**
  Run: `grep -nE '\.models\.[a-z]+\.(deep|standard|fast) // \.models\.(deep|standard|fast) // empty' skills/woostack-review/prompts/anthropic.md skills/woostack-review/prompts/openai.md skills/woostack-review/prompts/opencode.md`
  Expected: FAIL-state evidence — the three prompts document the **string-leaf** jq
  (`.models.<p>.<tier> // .models.<tier> // empty`), which returns the whole object for an object
  leaf.

- [ ] **Step 2: Confirm the failure** (same command) — Expected: lists the three jq lines.

- [ ] **Step 3: Edit the prompts.** Update each documented override lookup to read the normalized
  object leaf's `.model`, e.g. `anthropic.md:67`:
  ```text
  3. **Per-repo override**: check `$OUTDIR/config.json` for `models.anthropic.<effective_tier>`,
     then flat `models.<effective_tier>`. The loader normalizes each tier leaf to an object
     `{model, effort?}`, so read `.model` (e.g. when `run_tier=deep`:
     `jq -r '((.models.anthropic.deep // .models.deep) | if type=="object" then .model else . end) // empty' $OUTDIR/config.json`).
     If non-empty, use that slug instead of the table value.
  ```
  Apply the same object-safe form to `openai.md:25` (`.models.openai.<run_tier>`) and
  `opencode.md:27` (`.models.openrouter.<effective_tier>`). In `openai.md:23`, add one clause that
  the per-tier `effort` may now also come from the config leaf (`models.openai.<tier>.effort`),
  resolved config-first by `load-prompt.sh` before the built-in default.

- [ ] **Step 4: Run the check, confirm it passes**
  Run: `grep -nE 'if type=="object" then .model else . end' skills/woostack-review/prompts/anthropic.md skills/woostack-review/prompts/openai.md skills/woostack-review/prompts/opencode.md`
  Expected: PASS — all three prompts now document the object-safe lookup.

- [ ] **Step 5: Commit**
  ```bash
  gt modify -c -m "docs(review): provider prompts read object {model} tier leaves"
  ```

---

## Plan Checks

- **Spec coverage** — AC1→Inc1/Task1; AC2→Inc1/Task1; AC3→Inc1/Task1; AC4→Inc1/Task4;
  AC5→Inc1/Task2; AC6→Inc1/Task3; AC7→Inc2/Task1; AC8→Inc2/Task2. Docs (§4 doc edits)→Inc3. Dogfood
  migration (§4)→Inc1/Task1 (Steps 6-8, same commit as the loader). Every AC and each
  happy/error/edge case maps to a test/check.
- **AC coverage** — every §7 AC has a failing-test step (no `N/A` in the spec).
- **No placeholders** — every step carries the actual code/edit and an exact command + expected
  output. Doc tasks use concrete `grep`/`awk`/`jq -e` verification commands (this is a skills repo;
  per plan-template a "failing test" may be a concrete verification command).
- **Type consistency** — the normalized leaf is `{model, effort?}` everywhere; the object-safe jq
  `(. | if type=="object" then .model else . end) // empty` is identical in `resolve-model.sh`,
  `verify-receipts.sh`, and the provider prompts; effort enum `minimal|low|medium|high|xhigh`
  matches `load-prompt.sh`'s existing validation set and the loader's `EFFORT_LEVELS`.
- **Angle coverage** — *architecture*: producer + readers move in one increment (lockstep),
  docs/doctor stack after; *api/config-contract*: the breaking change is the loader's tailored
  error (Inc1) + proactive doctor warn (Inc2); *tests*: each AC has a red→green step;
  *observability*: loader error names the offending key + the fix, doctor warn names the file;
  *edge/error*: string vs object leaf, empty effort, missing model, unknown leaf key, root-sibling
  trap all have tests. No security/database/i18n surface (local config parsing only).

> The `spec : plan : PRs = 1 : 1 : N` join holds: this is the single plan for
> `.woostack/specs/2026-06-26-models-root-effort.md`, owning the 3 increment PRs above (linear
> stack on the spec+plan base PR #429).
