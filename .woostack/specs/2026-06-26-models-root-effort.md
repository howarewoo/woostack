---
name: 2026-06-26-models-root-effort
type: spec
status: approved
date: 2026-06-26
branch: feature/models-root-effort
links:
---

# Root model-tier config with per-tier effort — Design Spec

> Visualize on demand: render this file with [spec-template.html](../../../skills/woostack-build/references/spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → ready → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../../skills/woostack-status/references/conventions.md).

> **Plan:** [[plans/2026-06-26-models-root-effort]]

## 1. Problem

Model tiers (`fast` / `standard` / `deep` → provider model slugs) are configured under
`review.models` in `.woostack/config.json`. They are parsed only by `woostack-review`'s
`load-config.sh`, which hoists `review.*` into a flat internal `$OUTDIR/config.json`
(`.models[provider][tier]`, leaf = a model-slug **string**).

Two problems:

1. **Tiers are review-scoped but want to be shared infra.** The same tier vocabulary should
   drive `woostack-execute` subagent/model selection, not only review. Nesting under `review`
   structurally signals "review owns this" and blocks any non-review consumer from reading it
   as a first-class field.

2. **Effort is not configurable.** Reasoning effort (`reasoning_effort`) is hardcoded in
   `load-prompt.sh` (`default_openai_effort_for`), is OpenAI-only, and has exactly one override
   surface — the global CI action input `openai_effort`. There is no way to say, per tier,
   "`standard` = `gpt-5.4` at `xhigh`, `fast` = `gpt-5.4` at `low`" — i.e. the **same model at a
   different effort per tier**. Effort lives only as a documentation annotation in
   `model-tiers.md`, never as a real config key.

## 2. Goal

- **Relocate** `review.models` → a **root-level `models`** field in `.woostack/config.json`.
- **Clean break:** `review.models` is no longer accepted; encountering it is a hard,
  actionable loader error (no deprecation shim).
- **Per-tier effort as a first-class config attribute.** Each tier leaf may be an object
  `{ "model": "<slug>", "effort": "<level>" }`. A bare **string leaf remains accepted** as an
  ergonomic shorthand meaning "this model at the default effort."
- **Loader normalizes** every leaf to the object shape in the flat `$OUTDIR/config.json`
  output, so all downstream readers handle exactly **one** leaf shape (`.model` / `.effort`).
- **Effort becomes config-first:** `load-prompt.sh` consults the resolved config leaf's
  `.effort` before falling back to its existing hardcoded tier defaults.
- Internal flat lookup key stays `.models[provider][tier]` so the resolver's lookup paths are
  preserved; only the leaf *shape* upgrades (string → normalized object).

## 3. Non-goals

- **Wiring `woostack-execute` to consume tiers.** This change relocates the field to root and
  makes it consumable; rewiring execute's subagent/model selection is a separate later
  increment. (Relocate-only — the chosen scope.)
- **Moving `resolve-model.sh` out of the `woostack-review` bundle** into shared infra. It stays
  where it is; a future execute-wiring increment can promote it.
- **Adding `max` to the effort enum.** The validated set stays `minimal|low|medium|high|xhigh`
  (review's existing set), even though the harness exposes `max` elsewhere.
- **A deprecation shim / dual-read for `review.models`.** Explicitly rejected (clean break).
- **Doctor `--fix` auto-migration of `review.models` → root `models`.** The doctor migration
  check is **diagnose-only** (warns); it does not move config values.
- **New per-provider effort *semantics*** for Google/OpenRouter beyond letting config carry an
  effort value. Whether a provider acts on it is unchanged by this spec.

## 4. Approach

A contained relocation + leaf upgrade, confined to `woostack-review` scripts/prompts/docs, the
`woostack-init` template, this repo's own dogfood `.woostack/config.json`, and the
`woostack-doctor` config-keys coupling.

**Loader — `skills/woostack-review/scripts/load-config.sh`:**
- **Read `models` from the true top-level object, not the review-resolved block.** Today the
  loader resolves a `review` block into `rc`, sets `raw = rc`, and parses every key (including
  `models`) from `rc`. Root `models` must instead be read from the **original top-level dict**
  before that reassignment, because a top-level sibling next to a `review` block is currently
  *left alone / silently ignored* (the loader comment: "sibling top-level namespaces … are left
  alone"). The new block closes that trap: root `models` is parsed whether or not a `review`
  block is present.
- **Remove `"models"` from `REVIEW_KEYS`.** That removal is what turns a nested `review.models`
  into a rejected key. The generic path would emit `unknown review key(s): models`; add a
  **tailored, actionable message** for this specific key — "models moved to a root `models`
  field" with the corrected shape — rather than the generic unknown-key text (clean break with a
  good error).
- **Allow `models` as a recognized top-level key in both branches** so it is neither flagged as
  an `unknown top-level key` in legacy (no-`review`) mode nor silently ignored when a `review`
  block exists. Add it to the allowed-root set used by the unknown-top-level-key check.
- Provider/tier key sets unchanged: `MODEL_TIERS = {fast, standard, deep}`,
  `MODEL_PROVIDERS = {anthropic, openai, google, openrouter}`.
- **Leaf parsing** (applies uniformly to host-agnostic flat-tier leaves *and* provider→tier
  leaves): accept a non-empty **string** OR an **object** `{model, effort?}`.
  - object: `model` required non-empty string; `effort` optional. An **empty-string `effort`**
    is treated as **unset** (skipped), mirroring the loader's existing `force_tier` handling
    (`if ft_lc:`), not an error. A present non-empty `effort` is validated against
    `{minimal, low, medium, high, xhigh}`; any other key in the object → error.
  - string: treated as `model` with no effort.
- **Normalize on output:** every leaf in the flat `$OUTDIR/config.json` is written as an object
  `{ "model": "<slug>" }` (plus `"effort"` when set and non-empty). Downstream readers therefore
  only ever see object leaves. The loader normalizes **shape only** — it does **not**
  materialize a default effort; the hardcoded tier-default table in `load-prompt.sh` stays the
  single source of the default value.

**Model resolver — `skills/woostack-review/scripts/resolve-model.sh`:**
- `provider_tier_model()` reads `.models[p][t].model // .models[t].model` (object leaf) from the
  flat output. The hardcoded `default_model_for()` fallback table is unchanged.

**Effort — `skills/woostack-review/scripts/load-prompt.sh`:**
- New/updated effort resolution: read `.models[p][t].effort // .models[t].effort` from the flat
  config first; if present (and valid), use it; else fall back to the existing hardcoded
  `default_openai_effort_for()` tier defaults (`fast`/`standard` → `xhigh`, `deep` → `medium`).
  The hardcoded table remains the single fallback source of truth.
- The CI action input `openai_effort` (`INPUT_OPENAI_EFFORT`) stays as a top-priority one-run
  override layered above config (precedence: action input → config `.effort` → hardcoded
  default).

**Receipt validation — `skills/woostack-review/scripts/verify-receipts.sh`:**
- `config_model_for_tier()` reads `.model` from the (now always-object) flat leaf.

**Provider prompts** (`prompts/anthropic.md`, `openai.md`, `opencode.md`, `google.md`):
- Update the `jq` override-lookup snippets to read `.models.<provider>.<tier>.model //
  .models.<tier>.model` (object leaf) and document the `effort` field where the prompt explains
  tier resolution.

**Init template — `skills/woostack-init/templates/config.json`:**
- Add a root `"models": {}` alongside `"review"` and `"status"`. The `woostack-doctor`
  config-keys check reads template top-level keys and requires them in consumer configs, so this
  automatically makes root `models` an expected key (empty object satisfies the presence check).

**Doctor migration check — `skills/woostack-doctor/scripts/checks/`:**
- Add a **diagnose-only** check that flags a lingering `review.models` in the consumer's
  `.woostack/config.json` and points at the root `models` relocation. It **warns** (does not
  auto-move values — no `--fix`), pairing with the loader's tailored hard-error so a stale config
  is caught proactively, before a review run fails. Registered alongside the existing checks per
  the doctor's check-discovery convention.

**Dogfood config — this repo's `.woostack/config.json`:**
- Migrate the existing `review.models.openai.standard` value out of `review` to root
  `models.openai.standard`, in the new object form (demonstrates the feature and keeps this
  repo's own config valid under the clean break).

**Docs:**
- `skills/woostack-review/SKILL.md` — move `models` out of the `review` block in the schema
  example; document the object leaf + `effort`; update the precedence paragraph and the tier
  table footnote.
- `skills/woostack-review/prompts/_header.md` — update the "Per-repo Config" consumption table
  (now root `models`, with `effort`).
- `skills/using-woostack/references/model-tiers.md` — formalize `reasoning_effort`/`effort` as a
  real config field (object leaf) rather than a table annotation; update the override-precedence
  binding section (no longer `review.models`).
- `load-config.sh` top-of-file schema comment.

## 5. Components & data flow

```
.woostack/config.json (consumer)
  root "models": { <provider|tier>: <string | {model, effort?}> }
        │
        ▼  load-config.sh  (validate · reject review.models · normalize leaf → object)
$OUTDIR/config.json (flat, internal)
  ".models": { <provider|tier>: { "model": <slug>, "effort"?: <level> } }   ← single shape
        │
        ├──► resolve-model.sh   provider_tier_model() reads .model
        ├──► load-prompt.sh     effort = action-input // .effort // hardcoded default
        └──► verify-receipts.sh config_model_for_tier() reads .model

skills/woostack-init/templates/config.json  (root "models": {})
        └──► woostack-doctor config-keys.sh  requires root "models" in consumer config
```

Only `woostack-review` reads the tier config in this change. `woostack-execute` continues to
read `model-tiers.md` as documentation; its config consumption is deferred (Non-goals).

## 6. Error handling

- **`review.models` present** → loader exits non-zero with a **tailored** actionable message:
  models moved to a root `models` field; show the corrected shape. (Clean break — primary new
  error path. Not the generic `unknown review key` text.)
- **Root `models` next to a `review` block** → parsed normally (the previously-ignored sibling
  trap is closed). Only `review.models` specifically is rejected; a root `models` alongside a
  valid `review` block is fine.
- **Object leaf missing `model`** → error (leaf must name a model).
- **Unknown key inside an object leaf** (anything but `model`/`effort`) → error.
- **Invalid `effort` value** (non-empty, not in `{minimal,low,medium,high,xhigh}`) → error
  naming the allowed set.
- **Empty-string `effort`** → **not** an error: treated as unset (skipped), downstream applies
  the hardcoded tier default.
- **Unknown provider/tier key** under `models` → error (existing behavior, now at root).
- **Empty-string model leaf** → error (a leaf string / object `model` must be a non-empty slug).
- **Effort absent** (string leaf, or object with only `model`) → **not** an error: downstream
  applies the hardcoded tier default.

> **Angle pre-flight.** Implicated lenses: **api/config-contract** (the `review.models` →
> root `models` break is a breaking config-schema change — surfaced as the primary §6 error and
> AC1/AC7), **observability** (loader error messages must name the offending key and the fix —
> AC1 error class), **edge/error** (string-vs-object leaf, empty leaf, missing effort — AC2/AC3
> edges). No security/database surface (local config parsing only).

## 7. Acceptance criteria

Each AC is a testable behavior → ≥1 plan task.

- **AC1 — root `models` accepted; `review.models` rejected**
  - happy: root `models.openai.standard = {model, effort}` parses → flat
    `$OUTDIR/config.json .models.openai.standard` present
  - error: `review.models` present → loader exits non-zero with the relocation message
  - edge: neither root `models` nor `review.models` present → empty models, exit 0, no error
- **AC2 — leaf accepts string OR object, normalized to object on output**
  - happy: object `{model:"gpt-5.4",effort:"low"}` and string `"gpt-5.4"` both parse
  - error: object leaf missing `model` → error; unknown leaf key → error; empty-string leaf →
    error
  - edge: every flat-output leaf is an object (string input `"gpt-5.4"` → `{model:"gpt-5.4"}`)
- **AC3 — effort enum validation**
  - happy: `effort:"xhigh"` accepted
  - error: `effort:"turbo"` → error naming `{minimal,low,medium,high,xhigh}`
  - edge: object with `model` and no `effort` → accepted; `effort` absent from that flat leaf
- **AC4 — effort resolved config-first with hardcoded fallback**
  - happy: config `.effort=low` for `openai.standard` → `load-prompt.sh` emits `run_effort=low`
  - error: N/A — resolution can't fail on already-validated config
  - edge: no `.effort` in config → hardcoded tier default (`xhigh` fast/standard, `medium` deep);
    CI `openai_effort` input still overrides both
- **AC5 — model resolution reads the object leaf**
  - happy: object leaf → `resolve-model.sh` `provider_tier_model()` returns the `.model` slug
  - error: N/A
  - edge: tier with no override → hardcoded `default_model_for()` slug unchanged
- **AC6 — receipt validation reads the object leaf**
  - happy: config object leaf → `verify-receipts.sh` expects the `.model` slug for that tier
  - error: receipt model ≠ expected `.model` → existing mismatch failure still fires
  - edge: no config override for the tier → expected = default table slug (unchanged)
- **AC7 — doctor requires root `models`; template provides it**
  - happy: consumer config with root `models` (even `{}`) → `config-keys.sh` passes
  - error: consumer config missing root `models` → doctor flags it (template now carries the key)
  - edge: empty `models: {}` satisfies the presence check (no descent into tiers)
- **AC8 — doctor flags a lingering `review.models` (diagnose-only)**
  - happy: consumer config with no `review.models` → migration check is silent
  - error: consumer config with `review.models` present → doctor **warns** with the root-`models`
    relocation hint (no value is moved — diagnose-only)
  - edge: `review` block present but without a `models` sub-key → migration check stays silent

## 8. Testing

Bash, via the existing `skills/woostack-review/scripts/tests/` harness (no new framework):
- `test-load-config*` (or the relevant loader test): add cases for root `models` acceptance,
  `review.models` rejection, string-vs-object leaf normalization, object-missing-`model`,
  unknown-leaf-key, effort enum, empty-leaf.
- `test-resolve-model.sh`: update fixtures to the object-leaf flat form; assert `.model`
  extraction; default-table assertions unchanged.
- `test-load-prompt-models.sh`: add effort config-first cases (config `.effort` honored;
  absent → hardcoded default; `openai_effort` input still wins); existing default-effort
  assertions preserved.
- `verify-receipts` test (if present) updated to object-leaf flat form.
- `woostack-doctor` config-keys: a smoke that a config with root `models` passes and one
  without is flagged.
- `woostack-doctor` migration check: a config with `review.models` warns; one without is silent;
  a `review` block without `models` is silent (AC8).
- Run the full review-scripts suite green; run `pnpm -C site build` only if an authored docs
  page changed (none expected here — changes are skill assets + references).

## 9. Open questions

**Resolved during harden:**

- **Empty-string `effort`** → treated as **unset → default** (not an error), mirroring the
  loader's existing `force_tier` empty-string handling (`if ft_lc:`). Folded into §4/§6.
- **Flat-output `effort` default materialization** → the loader normalizes leaf **shape only**;
  it does **not** fill a default effort. The hardcoded tier-default table in `load-prompt.sh`
  remains the single source of the default value (loader normalizes shape; `load-prompt.sh` owns
  the default). Folded into §4.
- **Host-agnostic flat tier leaves** (`models.fast`/`.standard`/`.deep`) → get the **same**
  string|object normalization and effort handling as provider-scoped leaves. Folded into §4.
- **CI `openai_effort` precedence** → explicit per-run action input **wins over** config
  `.effort`, which wins over the hardcoded default (`action input → config → default`). An
  explicit one-run override should beat the persistent repo default. Folded into §4.

- **Doctor migration aid for the clean break** → **resolved: doctor warns (diagnose-only).** A
  new `woostack-doctor` check flags a lingering `review.models` and points at root `models`; it
  does not auto-move values. Folded into §3 (non-goal: no `--fix` auto-migration), §4 (doctor
  check), §7 (AC8), §8 (test).

_No open questions remain._
