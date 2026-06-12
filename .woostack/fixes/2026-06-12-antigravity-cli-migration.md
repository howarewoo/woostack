---
type: fix
status: executing
branch: fix/antigravity-cli-migration
---

# Fix: Migrate gemini CLI support → Antigravity CLI

## 1. Root Cause

Gemini CLI is deprecated; Google's **Antigravity CLI** (`agy`) is its successor. The
woostack repo declares gemini-CLI support in two distinct layers, both now stale:

**Layer A — agent-config (this repo's own dev surface).** Two symlinks let gemini CLI read
this repo's project instructions:

- `GEMINI.md` → `AGENTS.md` (root)
- `.gemini/GEMINI.md` → `../AGENTS.md`

and `AGENTS.md:7-8` documents them as the single source of truth. Antigravity CLI reads
**`AGENTS.md` natively** at the repo root (cross-agent convention, any model) — confirmed via
the Antigravity CLI hands-on guide and the official migration guide — so these gemini-only
symlinks are obsolete and Antigravity needs **no new symlink**.

**Layer B — woostack-review host support.** `woostack-review` is host-agnostic and names
"Gemini CLI" as one supported *review host* (the CLI agent that runs the review), distinct
from the Gemini *model* it judges with. Gemini-CLI-as-host appears in:

- `skills/woostack-review/prompts/google.md` — titled "Google (Gemini CLI)", orchestrates via
  Gemini CLI's static `@generalist` subagent and `~/.gemini/settings.json` overrides.
- `skills/woostack-review/prompts/_header.md` — `<host>` slug whitelist + `GEMINI_*`
  detection hint (line ~395); `gemini --version` introspection example (line ~389).
- `skills/using-woostack/references/model-tiers.md:30` — "single model per session (…, Gemini CLI)".
- `skills/woostack-review/SKILL.md` — host list (l.15), tool-gating `$(...)` claims (l.237, 589),
  `@generalist` cap note (l.326), single-model note (l.398).
- `skills/woostack-review/scripts/prefetch.sh` (l.210, 290) and `detect-angles.sh` (l.371) —
  comments naming Gemini CLI as a local/non-GHA host.

**Antigravity facts that drive the rewrite** (sources below): `agy` is the explicit *successor*
to gemini CLI; subagents are **orchestrated dynamically** (the static `.gemini/agents/` /
`@generalist` model is obsolete — the orchestrator instantiates parallel, isolated-context
subagents on demand, like Claude Code's `Task` fan-out); config moved from `.gemini/` to
`.agents/` (`.agents/settings.json`, `.agents/hooks.json`, `.agents/mcp_config.json`); default
model is Gemini 3.5 Flash. Per-subagent model override has **no documented static path** — the
migration guide says overrides are "handled natively" and subagents inherit the orchestrator
model, so Antigravity stays effectively single-model-per-session.

### Explicitly OUT of scope (the *model*, not the *CLI*)

The Gemini *model provider* is a separate concern and stays unchanged — Antigravity itself runs
Gemini models, so the slug `gemini-3-5-flash` is still correct:

- `detect-provider.sh` `google` branch + `INPUT_GEMINI_API_KEY` (model provider routing).
- `resolve-model.sh:44` `google) → gemini-3-5-flash` (model default — same model `agy` uses).
- `action.yml` / `.github/workflows/reusable-review.yml` `gemini_api_key` (model API key).
- `action.yml`'s `run-gemini-cli` **CI runner** (line ~341) — evaluated for migration and
  **intentionally retained** (decision #6): Antigravity CLI has no first-party GitHub Action and
  authenticates via keyring / Google Sign-In with no documented non-interactive API-key path, so
  it cannot run headlessly in CI. The step keeps running Gemini-model reviews; a deprecation note
  was added at the call site pending a non-interactive Antigravity runner.
- `_header.md:100`, `prompts/angles/conventions.md`, `validator.md`, `prefetch.sh` `GEMINI.md`
  **rule-file discovery** — back-compat reading of *consumer* repos' rule files; harmless to keep.
- `resolve-marker.sh:10` `gemini` — a GitHub *bot-login* prefix example for the trust gate,
  not the CLI host.
- `.woostack/specs|plans|fixes|memory/*` historical mentions — immutable decision corpus, not edited.

**Sources:** [Antigravity CLI hands-on guide (dev.to)](https://dev.to/arindam_1729/antigravity-cli-a-hands-on-guide-to-googles-terminal-coding-agent-5bc7) · [Migrating to Antigravity CLI (Google Cloud, Medium)](https://medium.com/google-cloud/migrating-to-antigravity-cli-a841c6964f37) · [Orchestrating Parallel AI Agents (DataCamp)](https://www.datacamp.com/tutorial/antigravity-cli) · [Antigravity docs](https://antigravity.google/docs/cli-plugins)

## 2. Proposed Fix

Minimal, layer-scoped edits. **Replace** (don't alias) the deprecated gemini-CLI *host* surface
with Antigravity; **leave** the gemini *model* surface and all back-compat readers intact.

**Hardening decisions (resolved):**
1. **Replace, not alias** — gemini CLI is deprecated, so `gemini-cli` is dropped from the active
   `<host>` whitelist and replaced by `antigravity-cli`. (Reading old data stays back-compat:
   `resolve-marker.sh` legacy-token matching and GEMINI.md rule-file discovery are untouched.)
2. **No new repo config** — Antigravity reads `AGENTS.md` natively; the repo adds **no** `.agents/`
   dir (hooks/mcp/subagent config this skills-collection doesn't need).
3. **Model default unchanged** — `gemini-3-5-flash` is Antigravity's own default; keep it.
4. **Single-model-per-session bucket kept** — Antigravity's dynamic subagents inherit the
   orchestrator model (no documented per-subagent override), so the model-tiers classification
   is unchanged apart from the host name.
5. **Generalize tool-gating claims** — the `$(...)` caller-side-substitution constraint was
   gemini-CLI-specific and is unverified for `agy`; reword to "sandboxed hosts" and keep the
   safe self-resolving `prefetch.sh` path, rather than asserting Antigravity has the quirk.
6. **Retain the `run-gemini-cli` CI runner** (discovered during execution) — Antigravity CLI
   cannot authenticate non-interactively in CI (keyring / Google Sign-In, no documented API-key
   path) and ships no first-party GitHub Action, so the `action.yml` Google runner stays on
   gemini CLI with a deprecation note rather than shipping a broken headless `agy -p` step. The
   originally-approved plan had mis-scoped all of `action.yml` as model-layer; this corrects it.

## 3. Implementation Plan

- [x] **Step 1: Agent-config layer — drop gemini symlinks, point doc at Antigravity**
  - `git rm GEMINI.md .gemini/GEMINI.md` (removes both symlinks; the empty `.gemini/` dir drops
    with its last tracked file).
  - Rewrite `AGENTS.md:7-8`: drop `.gemini/GEMINI.md`; state that `.claude/CLAUDE.md` is a symlink
    and **Antigravity CLI (`agy`) reads `AGENTS.md` natively**, so this file is the single source
    of truth across agents.

- [x] **Step 2: Rewrite `prompts/google.md` host orchestration (Gemini CLI → Antigravity CLI)**
  - Title → "Google (Antigravity CLI) — Multi-Angle Orchestration".
  - Replace the static `@generalist` narrative with Antigravity's **dynamic** orchestration: the
    orchestrator instantiates one isolated-context subagent per angle (× chunk), in parallel,
    each given its brief inline — analogous to Claude Code's `Task` fan-out. Update all Phase 1–3
    "spawn one `@generalist`" lines accordingly; keep the briefs, OUTDIR handoff, retry-once,
    merge/intersect logic verbatim.
  - Host identifier default `gemini-cli` → `antigravity-cli`.
  - Model selection: replace the `~/.gemini/settings.json` `agents.overrides` block with
    Antigravity's reality — subagents inherit the orchestrator model (default `gemini-3-5-flash`);
    no documented static per-subagent override; config lives under `.agents/`. Keep the
    `FORCE_TIER`/`inputs.model`/`models.google.<tier>` precedence unchanged.

- [x] **Step 3: `_header.md` — host whitelist + introspection example**
  - Credits `<host>` field (l.~395): replace `gemini-cli` with `antigravity-cli` in the slug list;
    swap detection hint `GEMINI_* → gemini-cli` for `AGY_*` / `ANTIGRAVITY_* → antigravity-cli`.
  - Runtime introspection (l.~389): `gemini --version` → `agy --version`.

- [x] **Step 4: `model-tiers.md` + `SKILL.md` host references**
  - `model-tiers.md:30`: "Gemini CLI" → "Antigravity CLI" in the single-model-per-session bucket.
  - `SKILL.md`: l.15 host list `Gemini CLI` → `Antigravity CLI`; l.326 `@generalist` cap note →
    Antigravity dynamic-subagent equivalent (ref `prompts/google.md`); l.398 single-model note →
    Antigravity CLI; l.237 & l.589 — generalize the `$(...)` tool-gating claim from "Gemini CLI"
    to "sandboxed hosts" while keeping the self-resolving `prefetch.sh` path.

- [x] **Step 5: Script comments**
  - `prefetch.sh` (l.210, 290) and `detect-angles.sh` (l.371): "Gemini CLI" → "Antigravity CLI"
    in the local/non-GHA-host comments. Comment-only; no logic change.

- [x] **Step 7: Retain CI runner with a deprecation note**
  - Add a comment at `action.yml`'s `run-gemini-cli` step explaining why it stays on gemini CLI
    (no non-interactive Antigravity auth, no first-party Action). No functional change to the runner.

- [x] **Step 6: Verification**
  - Symlinks gone, AGENTS.md still present & native-readable:
    ```bash
    test ! -e GEMINI.md && test ! -e .gemini/GEMINI.md && test -f AGENTS.md && echo OK
    ```
  - No active gemini-CLI *host* reference survives (the only permitted "gemini" hits are the
    model layer + back-compat readers enumerated in §1 "out of scope"):
    ```bash
    grep -rni "gemini cli\|@generalist\|\.gemini/" \
      AGENTS.md skills/woostack-review/prompts/google.md \
      skills/woostack-review/prompts/_header.md \
      skills/using-woostack/references/model-tiers.md \
      skills/woostack-review/SKILL.md \
      skills/woostack-review/scripts/prefetch.sh \
      skills/woostack-review/scripts/detect-angles.sh
    # expect: no matches
    ```
  - Markdown links in edited files resolve; provider/model layer untouched
    (`detect-provider.sh`, `resolve-model.sh`, `*.yml gemini_api_key` unchanged).
