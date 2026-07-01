---
type: fix
status: hardened
branch: fix/anthropic-opus-effort-tiers
---

# Fix: Anthropic default model tiers → Opus everywhere, differentiated by effort

## 1. Root Cause

Not a defect — a deliberate change to the **default** Anthropic review model tiers. "Diagnosis"
here means locating every authoritative site that defines or documents the Anthropic tier defaults
plus their effort wiring, so the change stays in sync across code, prompt, canonical table, tests,
and authored docs.

Today the Anthropic column resolves per tier to three *different* models:

- `fast` → `claude-haiku-4-5`
- `standard` → `claude-sonnet-4-6`
- `deep` → `claude-opus-4-8`

Two authoritative sources must agree (they self-document as mirrors):

- **Canonical table**: `skills/using-woostack/references/model-tiers.md` (Anthropic column).
- **Executable mirror**: `resolve-model.sh::default_model_for()` (slug only — its header comment says
  "emits the model slug only").

**Effort wiring today (evidence):**

- Effort is a real config field `{model, effort}`, validated by `load-config.sh` (`EFFORT_LEVELS`
  includes `xhigh`).
- `load-prompt.sh` computes/emits `run_effort` **only when `PROVIDER == openai`** (`load-prompt.sh:125`),
  via `default_openai_effort_for` (low/medium/high). There is **no** `default_anthropic_effort_for`.
- The CI Anthropic runner step (`action.yml:246`, `anthropics/claude-code-action@v1`) passes **only**
  `--model ${run_model}` — no effort/reasoning arg (unlike the Codex step `effort:` at `action.yml:325`).
  So the CI single-session Anthropic path has **no** effort-input target.
- The per-call Anthropic path (Claude Code `Task` spawns driven by `prompts/anthropic.md`) resolves
  model per spawn in the prompt and passes `model:`. `prompts/openai.md:35` establishes the pattern
  for per-call effort: *"If the spawn API accepts a reasoning-effort override, pass the mapped effort
  too … If it only accepts `model`, still pass `model`."*

Consequence of the requested change: with **Opus on all three tiers**, model routing becomes a no-op —
**effort is the only remaining tier differentiator**, so the effort default must actually reach the
worker for the change to be non-cosmetic. The applicable target is the per-call host (Claude Code
`Task`), resolved in `prompts/anthropic.md`; the CI single-session step cannot apply effort without a
fabricated `claude_args` flag (out of scope — no fabricated flags).

## 2. Proposed Fix

Set the Anthropic default tier mapping to:

| Tier | Model | Effort |
|---|---|---|
| `fast` | `claude-opus-4-8` | `low` |
| `standard` | `claude-opus-4-8` | `medium` |
| `deep` | `claude-opus-4-8` | `xhigh` |

Apply across every authoritative site; keep the model-slug mirror (`resolve-model.sh`) and the
canonical table byte-for-byte consistent. Document the per-tier effort defaults as illustrative
annotations in `model-tiers.md` (matching how the OpenAI column annotates `reasoning_effort:`), and
make the effort **apply** on per-call Anthropic hosts by teaching `prompts/anthropic.md` to pass a
per-tier `effort:` on each `Task` spawn (config `models.anthropic.<tier>.effort` → tier default),
using the same conditional hedge as `openai.md:35`.

**Resolved (harden):** `load-prompt.sh` is **left untouched** — no `default_anthropic_effort_for`,
no Anthropic `run_effort` emission. The CI Anthropic step (`action.yml:246`, `claude-code-action`)
consumes only `--model`, so an emitted `run_effort` for Anthropic would be unconsumed dead output.
Per-call effort is resolved in `prompts/anthropic.md` (mirroring `openai.md:35`, which hardcodes its
inline mapping for per-call hosts). The Anthropic effort default therefore lives in the canonical
table + prompt only. The per-spawn `effort:` is passed **conditionally** ("if the spawn API accepts
a reasoning-effort override") — identical hedge to `openai.md:35` — so the instruction is correct
whether or not the host's `Task` tool exposes an effort knob today; no flag is fabricated.

**Explicitly out of scope (incidental slug mentions, not the default table — do NOT edit):**
`_header.md:393,406` and `opencode.md:9` (credits-line *examples* of override/introspection);
`test-verify-receipts-*.sh` (receipt fixtures, not default assertions); `woostack-commit` (commit
model). Generated + gitignored per-skill pages `site/content/docs/skills/woostack-review.mdx` and
`woostack-commit.mdx` regenerate from `SKILL.md` — do NOT hand-edit.

## 3. Implementation Plan

- [ ] **Step 1: Failing test — pin the new Anthropic defaults**
  - In `skills/woostack-review/scripts/tests/test-resolve-model.sh` update the three Anthropic
    default assertions (currently L62-72) to expect `claude-opus-4-8` for `fast`, `standard`, and
    `deep`. Run the test → it fails (Red) against the current `default_model_for`.
- [ ] **Step 2: Executable mirror — `resolve-model.sh`**
  - Change `default_model_for()` Anthropic `fast`/`standard`/`deep` cases all to `claude-opus-4-8`.
    Update the "keep in sync with model-tiers.md" comment. Re-run Step-1 test → Green.
- [ ] **Step 3: Canonical table — `model-tiers.md`**
  - Anthropic column (rows `fast`/`standard`/`deep`) → `claude-opus-4-8` with effort annotations
    `+ effort: low` / `+ effort: medium` / `+ effort: xhigh` (mirror the OpenAI `reasoning_effort:`
    annotation style). Rewrite the Anthropic **provider note**: all tiers collapse onto
    `claude-opus-4-8`; per-tier behavior is driven by `effort` (low/medium/xhigh), which is the sole
    tier differentiator. `effort` remains a real config field (`models.anthropic.<tier>.effort`).
- [ ] **Step 4: Prompt — `prompts/anthropic.md` (make effort apply per-call)**
  - Inline tier mention (L49): `fast/standard/deep → claude-opus-4-8` with effort low/medium/xhigh.
  - Model-routing section + concrete `Task({...})` example: after resolving the model slug, resolve
    per-tier `effort` = config `models.anthropic.<tier>.effort` (jq, object-safe) → tier default
    (fast=low, standard=medium, deep=xhigh), and pass `effort:` on the spawn **when the spawn API
    accepts it** (conditional hedge mirroring `openai.md:35`); still pass `model:` regardless.
  - Step 1 context/summary subagent (L74-76): `claude-haiku-4-5 (fast tier)` → `claude-opus-4-8
    (fast tier, effort low)`.
  - Step 2 per-angle line (L95): replace the "Sonnet for bugs/…; Haiku for seo/…" model split with
    "`claude-opus-4-8` for every angle; effort follows the angle's tier (standard→medium, fast→low)".
- [ ] **Step 5: `load-prompt.sh` — no change (decided)**
  - Intentionally untouched (see Resolved note above): Anthropic effort default lives in the
    canonical table + prompt, not in `load-prompt.sh`, because the CI Anthropic step has no effort
    input. Verify no Anthropic effort code is added here.
- [ ] **Step 6: `woostack-review/SKILL.md`**
  - Tier table (L392-394) Anthropic column → `claude-opus-4-8` + effort annotations (match
    `model-tiers.md`). Refresh the config-override *example* (L151-162) sample values so they don't
    contradict the new defaults.
- [ ] **Step 7: Authored site pages (hard constraint — keep in sync)**
  - `site/content/docs/configuration.mdx:134` — Anthropic tier row → `claude-opus-4-8` ×3 (+ effort
    if the table carries an effort column).
  - `site/content/docs/concepts.mdx:128-130` — Anthropic column → `claude-opus-4-8` ×3.
  - `site/content/docs/concepts/context-management.mdx:48-50` — Anthropic column → `claude-opus-4-8` ×3.
  - Do NOT touch the generated `site/content/docs/skills/*.mdx` (regenerate from `SKILL.md`).
- [ ] **Step 8: Verification**
  - `bash skills/woostack-review/scripts/tests/test-resolve-model.sh` (+ `test-load-prompt-models.sh`
    and `test-load-config-*` if the alternative load-prompt path was taken) → all Green.
  - `grep -rn 'claude-haiku-4-5\|claude-sonnet-4-6' skills/using-woostack/references/model-tiers.md
    skills/woostack-review/scripts/resolve-model.sh skills/woostack-review/SKILL.md
    skills/woostack-review/prompts/anthropic.md site/content/docs` returns no default-table lines
    (only the intentionally-kept credits/introspection examples in `_header.md`/`opencode.md`).
  - `pnpm -C site build` if `site/node_modules` present; otherwise note it was skipped (plain-MD
    edits, low break risk) and flag for local verification.
