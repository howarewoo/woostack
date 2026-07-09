---
name: omp-model-tiers
type: spec
status: hardened
date: 2026-07-09
branch: feature/omp-model-tiers
links:
  - "[[2026-06-05-execute-vary-subagent-model]]"
  - "[[2026-06-26-models-root-effort]]"
---

# omp host support for woostack model tiers — Design Spec

> Visualize on demand: render this file with [spec-template.html](../../skills/woostack-build/references/spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → ready → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../skills/woostack-status/references/conventions.md).

> **Plan:** [[plans/2026-07-09-omp-model-tiers]]

## 1. Problem

Under the **omp (Oh My Pi)** host, every woostack subagent silently runs at the **session model** — the `fast | standard | deep` tier system is inert. Grounded causes:

- **omp's `task` tool has no per-call model knob.** It selects a subagent's model from the resolved **agent definition** (`model` + `thinkingLevel` frontmatter, applied at spawn as `effectiveAgent` — omp `task-agent-discovery.md`). woostack's driver resolves a tier and tries to "pass what it resolves to on the spawn, in whatever form the host's spawn API accepts" (`subagent-driver.md:120-135`); omp accepts no such per-call value, so the driver's own *"host cannot route per call → session model, say so (degraded)"* branch (`subagent-driver.md:134`) fires for **every** spawn.
- **omp is absent from the host taxonomy.** `model-tiers.md:24-34` names only *"per-call routing"* (Claude Code `Task`, Codex local, opencode) and *"single model per session"* (Codex Action, Antigravity CLI). omp fits neither.
- **omp has no single active-provider axis.** A run can mix providers per tier (deep=`anthropic/…`, standard=`openai/…`, fast=`google/…`). The columnar resolver — `detect-provider` → `models.<provider>.<tier>` → `default_model_for()` (`model-tiers.md:24-49`) — assumes one provider column and cannot express this.
- **Execute consumes no config.** The flat root `models.<tier>` key exists ([[2026-06-26-models-root-effort]]) but is read **only** by `woostack-review`'s `load-config.sh`. `woostack-execute` reads `model-tiers.md` as documentation and consumes no config — [[2026-06-05-execute-vary-subagent-model]] explicitly deferred execute's config consumption to *"a separate later increment."*

Net: on omp, tier routing is documentation, not behavior — a trivial rename and a security-critical migration pay the same session model.

## 2. Goal

Make woostack subagents obey `fast | standard | deep` under omp via omp's **native agent-by-tier selection**, driven by a **cross-provider** config:

- **Mechanism.** Ship three generated tier agent-defs — `.omp/agents/woostack-{fast,standard,deep}.md`. Each dispatch selects `agent: woostack-<effective-tier>`; omp applies the def's `model`+`thinkingLevel` at spawn. That *is* per-call tier routing through the `task` tool, keeping batch / isolation / per-call cwd.
- **Config.** The omp tier→model map is the existing root **flat `models.<tier>`** leaf (string `provider/slug`, or `{ model, effort }`), fully-qualified so each tier names its own provider. **No new config key**; columnar `models.<provider>.<tier>` is N/A under omp.
- **Zero-config default.** An unset tier bakes **only `thinkingLevel:`** (fast→`low`, standard→`medium`, deep→`xhigh`) and inherits the session model — effort-based tiering out of the box (the single-model-provider behavior already documented at `model-tiers.md:19`). Adding a `models.<tier>` slug upgrades that tier to full cross-provider model routing.
- **Generation is a single authority.** One generator script bakes config → defs, run by `woostack-init` (scaffold), `woostack-doctor --fix`, and as a `woostack-execute` safety-net when a def is missing. Doctor diagnoses missing/drift.
- **Coverage.** Every omp subagent spawn site obeys tiers: `woostack-execute` subagent-driver (primary; `woostack-execute-overnight` inherits it), `woostack-commit`'s fast draft subagent, and `woostack-review`'s **local** swarm.

## 3. Non-goals

- **review's CI single-session shell path is untouched.** `load-config.sh` / `resolve-model.sh` / `load-prompt.sh` and the columnar `default_model_for()` serve CI / single-session hosts (`claude-code-action` etc.), **not** omp local. Not modified (wisdom `review-ci-local-asymmetry`).
- **No new config key.** Reuse the root flat `models.<tier>` ([[2026-06-26-models-root-effort]]); do **not** add `models.omp.*` or a top-level `omp` key — either would force lockstep edits to review's `MODEL_PROVIDERS` / allowed-root validators.
- **No model-slug changes and no new table column.** omp is a routing **mode** over the existing flat config, not a fifth provider column in the `model-tiers.md` table — so review's **columnar CI model resolution** (`resolve-model.sh` `provider_tier_model`) is byte-unaffected. (The shared doc is inlined *whole* into the review orchestrator prompt — `load-prompt.sh:193` — so the concise omp bucket rides along as informational host-routing context, harmless and consistent with the Claude Code / Codex / Antigravity buckets already inlined.)
- **Generated defs are gitignored, never committed.** Config is the single source of truth; no committed slugs (they churn). No dogfood `models.<tier>` slugs are written into **this** repo's config.
- **No inline-mode variation, no parallel dispatch, no change to gates / never-merge / `spec : plan : PRs = 1 : 1 : N`** (inherited from [[2026-06-05-execute-vary-subagent-model]]).
- **The generator is not a second validation authority.** Authoritative `models` validation stays review's `load-config.sh` (when review runs); the generator is best-effort + loud.

## 4. Approach

### 4.1 `model-tiers.md` — new host bucket + omp precedence

Add a third bucket to **"Routing by host capability"**: **"Per-call routing via agent-by-tier (omp / Oh My Pi)."** omp selects a subagent's model from the resolved **agent definition**, not a per-call arg; woostack ships three generated tier-defs and the driver selects `agent: woostack-<effective-tier>` per spawn (the def carries `model`+`thinkingLevel`). Document that omp has **no active-provider column**, so it resolves the **flat `models.<tier>`** (fully-qualified `provider/slug(:effort)`) and **skips** the columnar `default_model_for()` path. Add omp's row to **"Override precedence"**: forced-tier / explicit-tier still select the *effective tier* (the agent name); flat `models.<tier>` is the model source; per-provider columnar keys are N/A; an unset tier → `thinkingLevel`-only default. State explicitly that **omp adds no table column** — the four-provider table is unchanged, so the columnar CI *resolution* (`resolve-model.sh`) is byte-stable; the whole-file inline gains only the concise omp bucket (see note).

> **CI-inline note.** `load-prompt.sh:186-197` inlines the **whole** `model-tiers.md` body at the `<!-- WOO_MODEL_TIERS_TABLE -->` marker (review *orchestrator* prompts only). The omp bucket therefore appears verbatim there — keep it concise; it is informational (the CI orchestrator still resolves its model via the columnar `resolve-model.sh`, untouched), consistent with the host buckets already inlined.

### 4.2 Three thin tier-defs (tier orthogonal to role)

`.omp/agents/woostack-{fast,standard,deep}.md`, each carrying: `name`, `description`, a **general-purpose worker `systemPrompt`** (deferential — "the task assignment is authoritative"; **not** role-specific), plus `model:` (only when the tier is configured) and `thinkingLevel:`. Role identity and instructions ride on the task-tool `role` / `context` / `assignment` fields — woostack already passes *"the full task text and exactly the context it needs"* (`subagent-driver.md:71`). Rationale: the effective tier is adjusted **per task** (bump up/down, `subagent-driver.md:113-118`), so one role (e.g. implementer) must be able to spawn at `fast` **or** `deep` — role-pinned defs cannot; three tier-defs can. `thinkingLevel` applies independently of `model` at spawn (verified: `AgentDefinition` carries both as separate optional overrides; omp `task-agent-discovery.md`).

**Profile & tools (grounded).** The tier-defs are the **plain/general-purpose worker profile**, not a specialized agent. woostack already dispatches *every* subagent — implementer, spec-reviewer, quality-reviewer (`subagent-driver.md:19`) and review's angle workers (`review/SKILL.md:328-332`) — as plain/general-purpose, enforcing reviewer read-only-ness by **brief**, never by tool restriction. So `agent: woostack-<tier>` is a lateral swap of that same profile with the tier's model+effort baked in — nothing is lost. The defs **omit `tools`** to inherit omp's full default worker set (the capability bundled `task` provides): `tools/task.md:92` applies *explicit `agent.tools` if provided*, else the default, and plan-mode's *restrict-to-read-only* language confirms the non-plan default is the full set (V1 verifies). `systemPrompt` stays minimal/deferential so it never fights the role brief (omp requires a non-empty `systemPrompt`).

### 4.3 Generator (single authority)

`skills/woostack-init/scripts/gen-omp-agents.sh` — jq-based, in the `build-index.sh` / `config-keys.sh` idiom:

- Resolves the **primary** repo root (the `WOOSTACK_ROOT` precedence of the [worktree contract §5](../../skills/woostack-init/references/worktrees.md)) so it always targets the primary `.omp/agents/`, even when invoked from a worktree cwd.
- Reads `.woostack/config.json` `.models.<tier>` for each of `fast` / `standard` / `deep`; leaf = non-empty **string** OR object `{ model, effort }`; extracts `model` + `effort`.
- Effort default per tier (`fast→low`, `standard→medium`, `deep→xhigh`) when the leaf omits it. `thinkingLevel` enum = omp's `off | minimal | low | medium | high | xhigh` (verified, omp `models.md`); woostack `effort` maps 1:1.
- Writes each `.omp/agents/woostack-<tier>.md` with the fixed general-purpose `systemPrompt` + baked `model:` (only when set) + `thinkingLevel:`, emitting **YAML-safe** values (a config slug is quoted / rejected if it would break frontmatter — no injection). Idempotent (overwrite).
- **Best-effort + loud:** a malformed / empty leaf → treat the tier as unset (thinkingLevel-only) + warn on stderr; never hard-fail the caller.

**Callers:** `woostack-init` scaffold, `woostack-doctor --fix`, and the `woostack-execute` safety-net. One script = one authority (wisdom `autonomy-needs-structural-proof`).

### 4.4 `woostack-init`

- The scaffolding step invokes `gen-omp-agents.sh` **when running under omp** (the agent applies host knowledge — the same capability-based detection used across the driver, e.g. `subagent-driver.md:57`; no env-sniffing). The script creates `.omp/agents/` under the primary root if absent.
- The gitignore template gains `.omp/agents/woostack-*.md` (scoped glob — does not clobber a consumer's own `.omp/agents/`).
- `templates/config.json` is unchanged (`"models": {}` already present from [[2026-06-26-models-root-effort]]).

### 4.5 `woostack-doctor`

- New check `scripts/checks/omp-agents.sh` (diagnose + `--fix`), **gated on a project `.omp/` existing** (the omp-in-use artifact signal — silent for non-omp repos, so it never nags a Claude-Code-only consumer). When `.omp/` exists: warn if any `woostack-<tier>.md` is **missing**, or if a present def **drifts** from what the generator would produce from current config. `--fix` invokes `gen-omp-agents.sh`. Emits the standard tab-delimited row; registered per the check-discovery convention (like `config-keys.sh` / `review-models-moved.sh`).
- New test `scripts/tests/test-omp-agents.sh`.
- `references/checks.md` documents the new check.

### 4.6 Dispatch wiring (agent-by-tier under omp)

- **execute `subagent-driver.md` → "Dispatch model":** add the omp case — on a host that selects subagent model by agent-definition (omp), pass **`agent: woostack-<effective-tier>`** on the task spawn (no per-call model arg); the def carries the resolved model+effort. **Ensure-then-select:** a missing def makes omp return *"Unknown agent"* with no subprocess (verified), so if the def is absent the driver first runs `gen-omp-agents.sh`; if still absent (unconfigured / can't generate) it spawns a **plain** task at the session model and **says so** (degraded, never a silent pretend-tier). Slots into the existing *"in whatever form the host's spawn API accepts"* clause.
- **commit `SKILL.md`:** the fast draft subagent (`SKILL.md:42-57`) → under omp, `agent: woostack-fast`.
- **review `SKILL.md` Stage 3 (local swarm, `SKILL.md:326-337`):** add an omp row to the per-host primitive list — angle workers `agent: woostack-<tier>` (per-angle tier), validator `agent: woostack-deep`. **Local only**; the CI single-session path is untouched.

### 4.7 Docs-site sync (lockstep)

Update the authored pages that state the host taxonomy / model-tier config: `site/content/docs/configuration.mdx` (the `models.<tier>` config surface) — add the omp flat cross-provider form + generated defs; and the host / model-tier taxonomy in `site/content/docs/concepts.mdx`. Per-skill reference pages regenerate from `SKILL.md` (no manual edit). Confirm with `pnpm -C site build`.

## 5. Components & data flow

| Component | Role | Change |
| --- | --- | --- |
| `skills/using-woostack/references/model-tiers.md` | Shared tier taxonomy | Edited — add omp host bucket + precedence; note "no table column" |
| `skills/woostack-init/scripts/gen-omp-agents.sh` | Config → tier-defs generator (single authority) | **New** |
| `.omp/agents/woostack-{fast,standard,deep}.md` | Generated tier-defs (model+thinkingLevel) | **New (generated, gitignored)** |
| `skills/woostack-init/SKILL.md` | Run generator under omp at scaffold | Edited |
| `skills/woostack-init/templates/gitignore` | Ignore `.omp/agents/woostack-*.md` | Edited |
| `skills/woostack-doctor/scripts/checks/omp-agents.sh` | Diagnose missing/drift; `--fix` regenerates (gated on `.omp/`) | **New** |
| `skills/woostack-doctor/scripts/tests/test-omp-agents.sh` | Check test | **New** |
| `skills/woostack-doctor/references/checks.md` | Document the check | Edited |
| `skills/woostack-execute/references/subagent-driver.md` | omp agent-by-tier dispatch + ensure-then-select degradation | Edited |
| `skills/woostack-commit/SKILL.md` | Fast draft subagent → `agent: woostack-fast` under omp | Edited |
| `skills/woostack-review/SKILL.md` | Local swarm → omp agent-by-tier row (CI path untouched) | Edited |
| `site/content/docs/{configuration,concepts}.mdx` | Authored host-taxonomy / config sync | Edited |
| structural lockstep test | Pin the omp-host site-list | **New** |

**Spawn flow (per task, under omp):**

```
controller resolves effective tier (role default ± heuristic §subagent-driver Tier selection)
  └─ select  agent: woostack-<tier>
       ├─ ensure def exists → else gen-omp-agents.sh → else plain spawn + say-so (degraded)
       └─ omp applies def's model + thinkingLevel at spawn (effectiveAgent)
            └─ role + brief ride on role / context / assignment
```

**Generation flow:**

```
.woostack/config.json  models.<tier>  (string | {model, effort})
   └─ gen-omp-agents.sh        (init scaffold | doctor --fix | execute safety-net)
        └─ <primary-root>/.omp/agents/woostack-<tier>.md   (model?: + thinkingLevel:)   [gitignored]
             └─ omp discovers project .omp/agents (ancestor of the worktree) → agent-by-tier spawn
```

## 6. Error handling

- **Missing def at spawn** → omp returns *"Unknown agent"* with no subprocess (verified). Driver ensures-then-selects: regenerate; if still absent, plain spawn at session model + say-so — degraded, never silent (wisdom `autonomy-needs-structural-proof`).
- **Unconfigured tier** → thinkingLevel-only def (effort tiering on the session model). Documented, not an error.
- **Malformed `models.<tier>` leaf** → generator warns, treats the tier as unset; init / doctor do not hard-fail. Authoritative validation remains review's `load-config.sh` when review runs.
- **Frontmatter injection via a config slug** (newline / `:` / YAML metachars in a `provider/slug`) → generator emits a quoted / rejected value so a def can never be corrupted by config content.
- **Cross-consumer config coexistence** → flat `models.<tier>` is shared with review's *provider-agnostic fallback*; a consumer that also runs review under a fixed provider should set `models.<provider>.<tier>` (review prefers provider-specific over flat), leaving flat for omp. Documented in `model-tiers.md`.
- **omp spawn policy** (`getSessionSpawns()` allowlist) or `disabledAgents` excluding `woostack-*` → the spawn is denied by omp; the driver reports it (degraded) rather than pretending a tier ran.
- **`model-tiers.md` edits add no table column** → review's CI table-inline is unaffected (asserted by test).

> **Angle pre-flight.** **security** → frontmatter-injection edge (§6, AC1); no secret handling (generator reads config, writes markdown). **observability** → generator warns on skip, doctor emits standard rows, execute says-so on degrade (AC5/AC6). **api/config-contract** → reuses flat `models.<tier>` (no schema break); omp bucket added to `model-tiers.md` without a table column (AC8). **edge/error** → unset / malformed / empty-effort leaves, worktree-cwd targeting (AC1–AC3). **database** → N/A (local file generation only).

## 7. Acceptance criteria

Each AC is a testable behavior → ≥1 plan task.

- **AC1 — generator bakes defs from config**
  - happy: `models.deep = {model:"anthropic/fable-5", effort:"xhigh"}` → `.omp/agents/woostack-deep.md` carries `model: anthropic/fable-5` and `thinkingLevel: xhigh`; `models.fast = "google/gemini-3-5-flash"` (string) → `model: google/gemini-3-5-flash` + default `thinkingLevel: low`.
  - error: a malformed leaf (non-string/non-object, or object missing `model`, or a slug containing frontmatter-breaking chars) → warn on stderr, tier treated unset (thinkingLevel-only), exit 0; the emitted def is valid YAML.
  - edge: unset tier → def has `thinkingLevel: <default>` and **no** `model:` line.
- **AC2 — generator is idempotent and targets the primary root**
  - happy: two consecutive runs produce byte-identical defs.
  - error: N/A.
  - edge: invoked with cwd inside `.woostack/worktrees/<x>/` → writes to `<primary-root>/.omp/agents/`, not the worktree.
- **AC3 — effort → thinkingLevel mapping**
  - happy: unset effort → `fast=low`, `standard=medium`, `deep=xhigh` baked.
  - error: N/A (best-effort; out-of-enum handled as unset per AC1 error).
  - edge: object `{model, effort:""}` (empty) → treated as unset effort → tier default.
- **AC4 — gitignore scoping**
  - happy: `.omp/agents/woostack-fast.md` is git-ignored (init template + this repo).
  - error: N/A.
  - edge: a consumer's own `.omp/agents/custom.md` is **not** ignored.
- **AC5 — doctor diagnoses missing/drift; `--fix` regenerates; gated on `.omp/`**
  - happy: defs match config → check silent.
  - error: a def missing (with `.omp/` present) or drifted from config → warn; `--fix` regenerates → next diagnose silent.
  - edge: no project `.omp/` → check silent (non-omp repo, no nag).
- **AC6 — execute dispatches agent-by-tier under omp with safe degradation**
  - happy: `subagent-driver.md` instructs selecting `agent: woostack-<effective-tier>` on each spawn under omp; a dry-run walkthrough shows a trivial task → `woostack-fast`, a security task → `woostack-deep`.
  - error: def missing → regenerate; still absent → plain spawn at session model + explicit degraded notice (never a silent tier claim).
  - edge: overnight inherits the same driver (no separate wiring).
- **AC7 — commit + review-local dispatch agent-by-tier under omp**
  - happy: `commit/SKILL.md` routes the fast draft subagent to `agent: woostack-fast` under omp; `review/SKILL.md` Stage 3 lists an omp row (angles `woostack-<tier>`, validator `woostack-deep`).
  - error: N/A (prose-doc contract; grep-asserted present).
  - edge: review's **CI single-session** path shows no omp agent-by-tier wiring (asymmetry preserved).
- **AC8 — `model-tiers.md` omp bucket present; no table column; lockstep pinned**
  - happy: `model-tiers.md` has the omp "agent-by-tier" bucket + precedence row.
  - error: N/A.
  - edge: the four-provider table is unchanged (no omp column) → review's composed-prompt table-inline still contains the same table text; a structural test enumerates the omp-host site-list and fails if a site is missing.
- **AC9 — docs-site sync**
  - happy: `configuration.mdx` + `concepts.mdx` describe the omp flat cross-provider form / host bucket; `pnpm -C site build` is green.
  - error: N/A.
  - edge: per-skill generated pages need no manual edit (regenerated from `SKILL.md`).

## 8. Testing

Skill-collection (Markdown / shell) change — checks are structural + behavioral; no app test runner exists in this repo.

- **Generator** — `test-omp-agents.sh` (bash) drives `gen-omp-agents.sh` against fixture `.woostack/config.json` variants (object leaf, string leaf, unset tier, empty effort, malformed leaf, injection slug) and asserts the emitted def frontmatter (AC1–AC3), idempotency, and primary-root targeting from a worktree-shaped cwd (AC2).
- **Doctor** — extend the doctor test harness: defs-match → silent; missing / drift → warn; `--fix` → regenerate; no `.omp/` → silent (AC5).
- **gitignore** — assert `git check-ignore` for `.omp/agents/woostack-*.md` and a negative for a non-woostack agent (AC4).
- **Structural / lockstep** — a test enumerating the omp-host site-list (`model-tiers.md` bucket, `subagent-driver.md` dispatch, `commit` / `review` rows, generator, doctor check) that fails when a site is absent; plus two AC8 assertions: the four-provider table is column-unchanged (so `resolve-model.sh` columnar resolution is byte-stable), and the `<!-- WOO_MODEL_TIERS_TABLE -->` inline still resolves with the omp bucket present in the composed orchestrator prompt.
- **Dispatch prose** — grep-assert the omp agent-by-tier case in `subagent-driver.md` / `commit` / `review` (AC6/AC7) + dry-run walkthroughs.
- **Docs** — `pnpm -C site build` green when authored pages change (AC9).

## 9. Open questions

Resolved during ideation / verified against omp docs:

1. **Enforcement mechanism** → **Option A**: generated per-tier agent-defs dispatched via the `task` tool (agent-by-tier), over the eval-`agent()` bridge (B) and omp global `modelRoles` (D). B/D were weighed and rejected in the ask phase.
2. **Config shape** → reuse the **root flat `models.<tier>`** with fully-qualified `provider/slug`; no new key; columnar form N/A under omp.
3. **Zero-config default** → **thinkingLevel-only** (effort tiering on the session model), upgraded per tier by a configured slug.
4. **Defs lifecycle** → **gitignored + regenerated** (config is the single source of truth); one generator, three callers.
5. **Host detection** → **capability-based** (agent applies omp knowledge; doctor check gated on `.omp/` artifact), not env-sniffing.
6. **Verified omp facts** (omp `task-agent-discovery.md` / `models.md`): `thinkingLevel` applies independently of `model`; enum `off|minimal|low|medium|high|xhigh`; project agents dir `.omp/agents/` (first-wins, overrides bundled); `model:` accepts a fully-qualified `provider/slug`; omp roles are a fixed enum (no custom role); a missing agent errors loudly (no silent session-model fallback).
7. **Worker profile & tools** → tier-defs are the **plain/general-purpose profile** with `tools` **omitted** (inherit omp's full default set), grounded in woostack's existing all-general-purpose dispatch (`subagent-driver.md:19`, `review/SKILL.md:328-332`). **V1 (verify in plan, non-blocking):** empirically confirm the no-`tools` default is the full worker set; fallback = emit an explicit worker `tools` list in the generator.
8. **CI-inline safety** → resolved: `load-prompt.sh:193` inlines the whole shared doc into the review orchestrator prompt; the omp bucket is kept concise and informational only — CI model resolution (`resolve-model.sh`) is untouched.

_Hardened 2026-07-09 — decision tree + spec angle pre-flight (security / observability / bugs / tests / api / deps / infra) walk clean; V1 is the only implementation-time probe and is non-blocking._
