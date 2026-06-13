---
type: plan
source: .woostack/specs/2026-06-05-execute-vary-subagent-model.md
status: done
branch: feature/execute-vary-subagent-model
---

# Vary subagent model in woostack-execute — Implementation Plan

**Source:** .woostack/specs/2026-06-05-execute-vary-subagent-model.md

> **For agentic workers:** execute this plan with `/woostack-execute .woostack/plans/2026-06-05-execute-vary-subagent-model.md` — woostack-execute drives it as PR-sized stacked increments (one `woostack-commit` per increment, no per-task commit). Steps use checkbox (`- [x]`) syntax for tracking. This is a skill-collection (Markdown + Bash) change with **no app test runner**: every "test" is a concrete `grep` / link-check / `load-prompt.sh` dry-run, substituted for TDD per the inline-driver rule.

**Goal:** Make subagent-mode `woostack-execute` vary the per-task model (quality/speed/cost) by operationalizing tier→model dispatch and adding a signal→tier heuristic, on one shared tier mapping that also de-duplicates the four copies in `woostack-review`.

**Architecture:** Promote the canonical tier→model table to a new neutral shared doc (`using-woostack/references/model-tiers.md`); deep-dedup the review prompts onto it while keeping the CI prompt self-contained (`load-prompt.sh` inlines it, fail-loud); then wire + adapt the execute subagent driver. Two stacked PRs: **PR 1** = shared doc + review repoint (CI-isolated, output-neutral); **PR 2** = execute wire + adapt.

**Tech stack:** Markdown skill assets, Bash (`load-prompt.sh`), `grep`/`jq` verifications, Graphite (`gt`) stacked branches.

**Invariants:** review output is byte-unchanged; no model-version edits (slugs move verbatim); the twelve `SKILL.md` files are not moved/renamed; never merge.

---

## Increment 1 (PR 1): Promote tier table → shared doc + deep-dedup review repoint

**Files in this increment:**
- Create: `skills/using-woostack/references/model-tiers.md`
- Modify: `skills/woostack-review/prompts/_header.md` (lines 53–75, the `## Model Tiers (host-agnostic)` block)
- Modify: `skills/woostack-review/prompts/anthropic.md` (lines 39–73, `## Model routing` block)
- Modify: `skills/woostack-review/prompts/opencode.md` (lines 11–25, `## Model selection` block)
- Modify: `skills/woostack-review/scripts/load-prompt.sh` (compose step ~line 163; `default_model_for()` ~line 56)

**Output-neutral guard:** before any edit, capture the current composed review prompt as a baseline, then assert the post-edit composed prompt still contains the same tier→model table text (Task 1.6).

**Sizing (resolves spec open question):** the increment is ~one new ~50-line doc + four small prose swaps + ~18 lines of Bash ≈ **~110 LOC** — under the ≤500 soft target, so PR 1 stays a single PR (no further split). All five files are tightly coupled by the same repoint, so splitting would create an inconsistent intermediate state (e.g. `_header.md` linking the shared doc while `anthropic.md` still claims the table is "in `_header.md`"); keeping them atomic is correct.

---

### Task 1.0: Baseline the composed review prompt (guard fixture)

**Files:**
- Test (scratch): `/tmp/woo-tiers-baseline.txt`

- [x] **Step 1: Capture today's composed prompt containing the table**

Run (from repo root):

```bash
mkdir -p /tmp/woo-tiers-base; rm -f /tmp/woo-base-out.txt
ACTION_PATH="$PWD/skills/woostack-review" PROVIDER=anthropic \
  PR_NUMBER=0 GITHUB_REPOSITORY=x/y EVENT_NAME=push MODE=full \
  ENABLED_ANGLES=bugs OUTDIR=/tmp/woo-tiers-base GITHUB_OUTPUT=/tmp/woo-base-out.txt \
  bash skills/woostack-review/scripts/load-prompt.sh >/dev/null 2>&1; echo "exit=$?"; \
  grep -c -E 'claude-haiku-4-5|claude-sonnet-4-6|claude-opus-4-7' /tmp/woo-base-out.txt
```

Expected: `exit=0` and a slug count **≥ 3** (empirically 16 today — all table slugs are present in
today's composed prompt). The `$GITHUB_OUTPUT` file holds the heredoc-framed `prompt`; grep the
**raw file** directly — the framing lines carry no model slugs, so a slug grep is a clean presence
check (no extraction needed). If `load-prompt.sh` needs more env, add the missing vars.

> Note: `OUTDIR` is set so `resolve-outdir.sh` does not derive a per-project path; `GITHUB_OUTPUT`
> is redirected to a temp file so the emitted `prompt` is inspectable. **Confirmed working** against
> the pre-edit script during plan hardening (exit 0, 16 hits).

---

### Task 1.1: Create the shared tier doc

**Files:**
- Create: `skills/using-woostack/references/model-tiers.md`

- [x] **Step 1: Write the canonical shared doc**

Create `skills/using-woostack/references/model-tiers.md` with exactly:

````markdown
# Model Tiers (shared, host-agnostic)

Canonical tier→model mapping for the woostack collection. Both `woostack-review` (angle workers +
validator) and `woostack-execute` (subagent driver) resolve tiers through this file. Each consumer
keeps only its own **runtime bindings** (env vars, config paths, dispatch calls) and points at the
precedence rules below — there is no second copy of this table.

Tiers are `fast | standard | deep`. A prompt or template declares a `tier:` in frontmatter; the
host resolves it to a concrete model via the table. The context/summary helper subagent is
implicitly `fast`.

| Tier | Use for | Anthropic | OpenAI (Codex) | Google (Gemini) | OpenRouter |
|---|---|---|---|---|---|
| `fast` | rubric checklists, mechanical fully-specified 1–2-file tasks, context summaries | `claude-haiku-4-5` | `gpt-5.3-codex-spark` | `gemini-3-5-flash` | `openrouter/deepseek/deepseek-v4-flash` |
| `standard` | reasoning workers, multi-file integration | `claude-sonnet-4-6` | `gpt-5.4` | `gemini-3-5-flash` | `openrouter/deepseek/deepseek-v4-pro` |
| `deep` | skeptical validation, design/architecture judgment, code-quality review | `claude-opus-4-7` | `gpt-5.5` + `reasoning_effort: xhigh` | `gemini-3-5-flash` | `openrouter/deepseek/deepseek-v4-pro` + `reasoning_effort: xhigh` |

> **Provider notes:**
> - **Google** currently ships only `gemini-3-5-flash` in the 3.5 line; no Pro/Ultra/Thinking variant exists yet, so all tiers collapse onto flash (tier routing is effectively a no-op until Google releases a larger model).
> - **OpenAI** GPT-5-family reasoning is a parameter on the same slug, not a slug suffix. Use `gpt-5.5` for complex review and the skeptical validator, `gpt-5.4` for everyday coding review, and `gpt-5.3-codex-spark` for simple/cost-sensitive rubric workers and latency-first real-time coding checks. Use `gpt-5.4-mini` only as the non-Spark cost-sensitive fallback when Spark is unavailable. There is no `gpt-5-pro`.
> - **OpenRouter** DeepSeek exposes exactly two slugs — `deepseek/deepseek-v4-flash` and `deepseek/deepseek-v4-pro`. Reasoning is a `reasoning_effort` parameter (`high` / `xhigh`, where `xhigh` maps to max). Use plain `v4-pro` for standard and `v4-pro` with `reasoning_effort: xhigh` for deep. Do not route to `deepseek-r1` — V4 supersedes it.

## Routing by host capability (generic)

- **Per-call routing** (Claude Code `Task`, opencode `@subagent`): resolve the effective tier =
  a forced tier if the host sets one, else the prompt's own `tier:` frontmatter; map it to the
  column for the active provider; **pass that model on every spawn.**
- **Single model per session** (Codex Action, Gemini CLI): resolve one run model up front;
  per-tier behavior collapses onto that one model for the whole job.

## Override precedence (generic)

When a host supports per-repo / per-run overrides, resolve highest-precedence first:

1. **Forced tier** — a one-run tier override.
2. **Explicit model** — an explicit model-id input.
3. **Per-provider per-tier** override key.
4. **Flat per-tier** override key.
5. **Table default** (above).

Each consumer binds these to its own surface. For example `woostack-review` binds them to
`FORCE_TIER` (Review Context) › `inputs.model` (action.yml) › `models.<provider>.<tier>` /
`models.<tier>` in `/tmp/pr-review/config.json`, resolved by `scripts/load-prompt.sh`
(`default_model_for()` is the Bash mirror of the Anthropic/OpenAI/Google/OpenRouter columns —
keep it in sync with this table).
````

- [x] **Step 2: Verify the doc exists with all three tiers per provider**

Run:

```bash
test -f skills/using-woostack/references/model-tiers.md && \
grep -Eq '`fast`.*claude-haiku-4-5.*deepseek-v4-flash' skills/using-woostack/references/model-tiers.md && \
grep -Eq '`standard`.*claude-sonnet-4-6' skills/using-woostack/references/model-tiers.md && \
grep -Eq '`deep`.*claude-opus-4-7' skills/using-woostack/references/model-tiers.md && echo OK
```

Expected: `OK`.

---

### Task 1.2: Repoint `_header.md` — table out, link + marker in

**Files:**
- Modify: `skills/woostack-review/prompts/_header.md:53-75`

- [x] **Step 1: Replace the whole `## Model Tiers (host-agnostic)` section**

Replace the block that currently starts at `## Model Tiers (host-agnostic)` (line 53) and runs
through the per-repo-tier-overrides paragraph ending `…still win over per-repo and table defaults.`
(line 75) with:

```markdown
## Model Tiers (host-agnostic)

The canonical tier→model table, provider notes, and generic routing/precedence rules live in the
shared reference [`../../using-woostack/references/model-tiers.md`](../../using-woostack/references/model-tiers.md)
— one source, shared by woostack-review and woostack-execute. The loader **inlines** it here so
single-prompt runners stay self-contained:

<!-- WOO_MODEL_TIERS_TABLE -->

**Review's tier-resolution binding.** Resolve the effective tier per the shared doc's precedence,
bound to review's surface: `FORCE_TIER` (Review Context) → `inputs.model` (action.yml) →
`models.<provider>.<tier>` / `models.<tier>` in `/tmp/pr-review/config.json` → table default.
`run_model` (resolved in `load-prompt.sh`) pins single-session hosts; explicit `FORCE_TIER` and
`run_model` win before per-repo/per-tier overrides. The context+summary subagent is implicitly
`fast`.
```

> The review-pipeline `## Per-repo Config (/tmp/pr-review/config.json)` section that follows
> (currently line 77+) is review plumbing, not tier vocab — **leave it unchanged.**

- [x] **Step 2: Verify `_header.md` links the shared doc, holds the marker, and no longer embeds the table**

Run:

```bash
grep -q 'using-woostack/references/model-tiers.md' skills/woostack-review/prompts/_header.md && \
grep -q 'WOO_MODEL_TIERS_TABLE' skills/woostack-review/prompts/_header.md && \
! grep -q 'openrouter/deepseek/deepseek-v4-flash' skills/woostack-review/prompts/_header.md && echo OK
```

Expected: `OK` (links shared doc, has the marker, table rows gone from the source file).

---

### Task 1.3: `load-prompt.sh` — inline the shared table at the marker (fail-loud) + sync comment

**Files:**
- Modify: `skills/woostack-review/scripts/load-prompt.sh` (compose step ~163; `default_model_for()` ~56)

- [x] **Step 1: Add the inline step before the compose line**

Find (line ~163):

```bash
PROMPT_CONTENT=$(printf '%s\n\n%s\n\n%s\n' "$CONTEXT_HEAD" "$(cat "$HEADER_FILE")" "$(cat "$BODY_FILE")")
```

Replace with:

```bash
# Inline the shared tier→model table into the header so single-prompt runners (which follow no
# markdown links) stay self-contained. Canonical source:
# skills/using-woostack/references/model-tiers.md — kept in sync with default_model_for() below.
TIERS_FILE="$ACTION_PATH/../using-woostack/references/model-tiers.md"
if [ ! -f "$TIERS_FILE" ]; then
  echo "::error::shared model-tiers doc not found: $TIERS_FILE"
  exit 1
fi
HEADER_RAW="$(cat "$HEADER_FILE")"
if ! printf '%s' "$HEADER_RAW" | grep -q 'WOO_MODEL_TIERS_TABLE'; then
  echo "::error::_header.md is missing the <!-- WOO_MODEL_TIERS_TABLE --> inline marker"
  exit 1
fi
# Literal single-occurrence replacement of the marker with the shared doc body.
HEADER_INLINED="${HEADER_RAW/<!-- WOO_MODEL_TIERS_TABLE -->/$(cat "$TIERS_FILE")}"
PROMPT_CONTENT=$(printf '%s\n\n%s\n\n%s\n' "$CONTEXT_HEAD" "$HEADER_INLINED" "$(cat "$BODY_FILE")")
```

> **Mechanism confirmed during plan hardening.** Bash `${var/literal/$(cat file)}` correctly inlines
> multi-line content and preserves `/`-bearing slugs (`openrouter/deepseek/deepseek-v4-flash`) and
> backslashes — the marker is glob-metachar-free so it matches literally, and the `/` inside the
> expanded replacement are data, not delimiters. If a future host's bash chokes on a very large
> replacement, the drop-in fallback is `awk -v tf="$TIERS_FILE" '/WOO_MODEL_TIERS_TABLE/{while((getline l<tf)>0)print l;next}1'` over `$HEADER_FILE`.

- [x] **Step 2: Add the sync comment above `default_model_for()`**

Find (line ~56):

```bash
default_model_for() {
```

Insert immediately above it:

```bash
# canonical source: skills/using-woostack/references/model-tiers.md — keep these slugs in sync
# with that table (Bash cannot read the markdown table, so this is its executable mirror).
default_model_for() {
```

- [x] **Step 3: Verify the script still parses**

Run: `bash -n skills/woostack-review/scripts/load-prompt.sh && echo OK`
Expected: `OK`.

---

### Task 1.4: Dedup `anthropic.md` — delete embedded table, repoint, keep the binding

**Files:**
- Modify: `skills/woostack-review/prompts/anthropic.md:46-71`

- [x] **Step 1: Replace the table + resolution prose, keep the MUST-pass discipline + example**

Replace lines 46–52 (the `Then resolve via the **Model Tiers** table in _header.md:` line through
the embedded 3-row table ending `| deep | claude-opus-4-7 | skeptical validator |`) with:

```markdown
Then resolve via the shared **Model Tiers** table — canonical at
[`../../using-woostack/references/model-tiers.md`](../../using-woostack/references/model-tiers.md)
and inlined into `_header.md` above (Anthropic column: `fast` → `claude-haiku-4-5`,
`standard` → `claude-sonnet-4-6`, `deep` → `claude-opus-4-7`).
```

- [x] **Step 2: Repoint the "tier table above" back-reference**

In the `Resolution rule per spawn:` list (line ~69), change:

```markdown
2. Look up the Anthropic column in the tier table above.
```

to:

```markdown
2. Look up the Anthropic column in the shared Model Tiers table (inlined in `_header.md` above).
```

> Leave lines 54 (`**Every Task/Agent spawn MUST pass model: explicitly.**`), 56–65 (the
> concrete `Task({…model:…})` example), 70–71 (the per-repo override `jq` + pass-the-slug rule),
> and 73 (validator-Opus rule) **unchanged** — they are the Anthropic runtime binding.

- [x] **Step 3: Verify anthropic.md no longer embeds the table and links the shared doc**

Run:

```bash
grep -q 'using-woostack/references/model-tiers.md' skills/woostack-review/prompts/anthropic.md && \
! grep -q '| `deep` | `claude-opus-4-7` | skeptical validator |' skills/woostack-review/prompts/anthropic.md && \
grep -q 'MUST pass .model:. explicitly' skills/woostack-review/prompts/anthropic.md && echo OK
```

Expected: `OK` (links shared doc, embedded table row gone, MUST-pass discipline retained).

---

### Task 1.5: Dedup `opencode.md` — repoint reference, keep OpenRouter binding

**Files:**
- Modify: `skills/woostack-review/prompts/opencode.md:17`

- [x] **Step 1: Repoint the "table in _header.md" reference**

Change line 17:

```markdown
Then resolve that effective tier via the **Model Tiers** table in `_header.md`:
```

to:

```markdown
Then resolve that effective tier via the shared **Model Tiers** table (canonical at
[`../../using-woostack/references/model-tiers.md`](../../using-woostack/references/model-tiers.md),
inlined into `_header.md` above); the OpenRouter column is:
```

> Leave lines 19–25 (the three `fast/standard/deep` → DeepSeek slugs, the `reasoning_effort`
> note, and the per-repo override `jq` precedence) **unchanged** — that is the OpenRouter binding.

- [x] **Step 2: Verify opencode.md links the shared doc**

Run:

```bash
grep -q 'using-woostack/references/model-tiers.md' skills/woostack-review/prompts/opencode.md && \
grep -q 'deepseek-v4-flash' skills/woostack-review/prompts/opencode.md && echo OK
```

Expected: `OK` (links shared doc; keeps its OpenRouter binding slugs).

---

### Task 1.6: Output-neutrality + dedup verification (the increment's real test)

**Files:** _(verification only)_

- [x] **Step 1: Re-compose the prompt and assert the table text survives inlining**

Run (same env as Task 1.0):

```bash
rm -f /tmp/woo-after-out.txt
ACTION_PATH="$PWD/skills/woostack-review" PROVIDER=anthropic \
  PR_NUMBER=0 GITHUB_REPOSITORY=x/y EVENT_NAME=push MODE=full \
  ENABLED_ANGLES=bugs OUTDIR=/tmp/woo-tiers-base GITHUB_OUTPUT=/tmp/woo-after-out.txt \
  bash skills/woostack-review/scripts/load-prompt.sh >/dev/null 2>&1; echo "exit=$?"; \
  grep -c -E 'claude-haiku-4-5|claude-sonnet-4-6|claude-opus-4-7' /tmp/woo-after-out.txt
```

Expected: `exit=0` and slug count **≥ 3** in the **post-edit** composed prompt (the marker was
replaced with the inlined shared table). Compare to the Task 1.0 baseline (~16) — output
neutrality holds. Grep the raw `$GITHUB_OUTPUT` file directly (no `sed` extraction).

- [x] **Step 2: Assert fail-loud when the shared doc is missing**

Run:

```bash
mv skills/using-woostack/references/model-tiers.md /tmp/mt.bak
ACTION_PATH="$PWD/skills/woostack-review" PROVIDER=anthropic PR_NUMBER=0 \
  GITHUB_REPOSITORY=x/y EVENT_NAME=push MODE=full ENABLED_ANGLES=bugs \
  OUTDIR=/tmp/woo-tiers-base GITHUB_OUTPUT=/tmp/woo-fail-out.txt \
  bash skills/woostack-review/scripts/load-prompt.sh; echo "exit=$?"
mv /tmp/mt.bak skills/using-woostack/references/model-tiers.md
```

Expected: prints an `::error::shared model-tiers doc not found` line and `exit=1` (non-zero).

- [x] **Step 3: Dedup grep — no review prompt embeds the table or claims it lives in `_header.md`**

Run:

```bash
! grep -rngE '\| `?(fast|standard|deep)`? \|.*claude-(haiku|sonnet|opus)' skills/woostack-review/prompts/ && \
! grep -rn 'table in `_header.md`' skills/woostack-review/prompts/ && echo OK
```

Expected: `OK` (no embedded tier table rows remain in review prompts; no stale "table in `_header.md`" locator).

- [x] **Step 4: Mirror-sync — `default_model_for()` Anthropic slugs equal the shared doc column**

Run:

```bash
for t in "fast:claude-haiku-4-5" "standard:claude-sonnet-4-6" "deep:claude-opus-4-7"; do
  tier="${t%%:*}"; slug="${t##*:}";
  grep -q "$slug" skills/using-woostack/references/model-tiers.md && \
  grep -q "$slug" skills/woostack-review/scripts/load-prompt.sh || { echo "DRIFT $tier"; break; }
done; echo done
```

Expected: `done` with no `DRIFT` line.

- [x] **Step 5: Commit the increment**

Use [`woostack-commit`](../../skills/woostack-commit/SKILL.md) on this increment's Graphite-stacked
branch (base = the spec+plan PR). PR title e.g. `refactor(review): promote tier→model table to shared model-tiers.md`. Body: the goal, the deep-dedup summary, and the output-neutral evidence from Steps 1–4 as the test plan.

---

## Increment 2 (PR 2): Execute — wire dispatch + adapt tier per task

**Files in this increment:**
- Modify: `skills/woostack-execute/references/subagent-driver.md` (cross-links ~60/65; `## Model tiers` section 58–67; per-task loop steps 1/2/3/4)
- Modify: `skills/woostack-execute/SKILL.md` (description frontmatter + the subagent-driver bullet)
- Verify-only: `skills/woostack-execute/prompts/{implementer,spec-reviewer,quality-reviewer}.md`

> PR 2 stacks on PR 1 — its cross-link target (`model-tiers.md`) is created in PR 1.

---

### Task 2.1: Repoint subagent-driver cross-links to the shared doc

**Files:**
- Modify: `skills/woostack-execute/references/subagent-driver.md:60,65`

- [x] **Step 1: Replace both `_header.md` references in the `## Model tiers` section**

In the `## Model tiers` section (line 59 onward), replace:

```markdown
Use woostack's shared tier vocabulary — `fast | standard | deep` — resolved through the Model
Tiers table in [`../../woostack-review/prompts/_header.md`](../../woostack-review/prompts/_header.md).
Each prompt template declares its `tier:` in frontmatter:
```

with:

```markdown
Use woostack's shared tier vocabulary — `fast | standard | deep` — resolved through the shared
Model Tiers table in
[`../../using-woostack/references/model-tiers.md`](../../using-woostack/references/model-tiers.md).
Each prompt template declares its `tier:` in frontmatter as the role default:
```

- [x] **Step 2: Verify the repoint**

Run:

```bash
grep -q 'using-woostack/references/model-tiers.md' skills/woostack-execute/references/subagent-driver.md && \
! grep -q 'woostack-review/prompts/_header.md' skills/woostack-execute/references/subagent-driver.md && echo OK
```

Expected: `OK`.

---

### Task 2.2: Add the "Dispatch model" contract (the wire)

**Files:**
- Modify: `skills/woostack-execute/references/subagent-driver.md` (end of `## Model tiers`, after the existing tier bullets ~line 66)

- [x] **Step 1: Replace the closing "Where the host cannot route…" line with the full contract**

Replace:

```markdown
Where the host cannot route models per call, fall back to the session model.
```

with:

```markdown
### Dispatch model (resolve → map → pass)

Before each subagent dispatch, resolve the task's **effective tier** (role default, adjusted per
[Tier selection](#tier-selection) below), map it to the host's model via the shared
[model-tiers.md](../../using-woostack/references/model-tiers.md) (use the column for the host's
provider — usually the session's), and **pass that model on the dispatch** (the `model:` arg of
the `Agent`/`Task` call). Pass whatever value the host's subagent API accepts — a concrete slug
where it takes slugs, or the tier's model **family** (`haiku`/`sonnet`/`opus`) where it takes
families.

**When the host supports per-call routing, every dispatch MUST pass the resolved model.** Omitting
it makes the subagent inherit the parent session's model (typically Opus), silently defeating tier
routing and burning multiples of the tokens on cheap work — the same rationale
`woostack-review`'s [`prompts/anthropic.md`](../../woostack-review/prompts/anthropic.md) already
states for its angle spawns. **When the host cannot route per call**, run at the session model and
**say so** (degraded, not equivalent) — never pretend a tier ran.
```

- [x] **Step 2: Verify the contract landed**

Run:

```bash
grep -q 'Dispatch model (resolve → map → pass)' skills/woostack-execute/references/subagent-driver.md && \
grep -q 'MUST pass the resolved model' skills/woostack-execute/references/subagent-driver.md && echo OK
```

Expected: `OK`.

---

### Task 2.3: Replace the static tier bullets with the "Tier selection" heuristic (the adapt)

**Files:**
- Modify: `skills/woostack-execute/references/subagent-driver.md` (the three tier bullets at lines 63–66)

- [x] **Step 1: Replace the `fast/standard/deep` static bullets**

Replace:

```markdown
- **`fast`** — mechanical 1–2-file tasks with a complete spec (an implementer downgrade).
- **`standard`** — multi-file integration; the default implementer and the spec reviewer.
- **`deep`** — design/architecture judgment and the code-quality reviewer.
```

with:

```markdown
### Tier selection

Each role has a **default** tier (its prompt's `tier:` frontmatter): implementer `standard`,
spec-reviewer `standard`, quality-reviewer `deep`. The controller adjusts that default **per task**
from complexity and risk — this table is the single home for the choice:

| Adjust | Effective tier | When |
|---|---|---|
| **Bump UP** | `deep` | the task touches security / auth / crypto, data migrations, concurrency / locking, money / billing, or is cross-cutting / architectural; the task spec is highly ambiguous; or the task previously returned **BLOCKED** for "needs more reasoning". |
| **Bump DOWN** | `fast` | the task is mechanical, fully specified, single-file, and low-risk (rename, copy/string change, mechanical refactor, config tweak, docstring/comment). |
| **Reviewer downgrade** | `fast` / `standard` | spec-reviewer → `fast` on a trivial diff; quality-reviewer → `standard` on a trivial diff (otherwise stays `deep`). |
| **Ambiguous signals** | role default | default-safe — never downgrade risky work on uncertainty. |

The resolved effective tier feeds [Dispatch model](#dispatch-model-resolve--map--pass) above.
```

- [x] **Step 2: Verify the heuristic landed and the old static bullets are gone**

Run:

```bash
grep -q '### Tier selection' skills/woostack-execute/references/subagent-driver.md && \
grep -q 'Bump UP' skills/woostack-execute/references/subagent-driver.md && \
! grep -q 'an implementer downgrade' skills/woostack-execute/references/subagent-driver.md && echo OK
```

Expected: `OK`.

---

### Task 2.4: Tie the per-task loop steps to the contract

**Files:**
- Modify: `skills/woostack-execute/references/subagent-driver.md` (per-task loop steps 1, 2, 3, 4 at lines 31–50)

- [x] **Step 1: Cite the contract in the implementer dispatch (step 1)**

In step 1 (`Dispatch an implementer subagent with …implementer.md`), append to the end of the
sentence "…the subagent never inherits this session's history.":

```markdown
   Resolve and pass its model per [Dispatch model](#dispatch-model-resolve--map--pass) and
   [Tier selection](#tier-selection).
```

- [x] **Step 2: Align the BLOCKED handling (step 2) with the heuristic**

In step 2's `BLOCKED` bullet, change `needs more reasoning (re-dispatch at a higher tier)` to:

```markdown
needs more reasoning (re-dispatch one tier higher per [Tier selection](#tier-selection) — a
prior BLOCKED is itself a bump-UP signal)
```

- [x] **Step 3: Cite the contract in both reviewer dispatches (steps 3 and 4)**

In step 3 (spec-compliance reviewer) and step 4 (code-quality reviewer), append to each dispatch
sentence:

```markdown
Resolve and pass its model per [Dispatch model](#dispatch-model-resolve--map--pass) and
[Tier selection](#tier-selection).
```

- [x] **Step 4: Verify all three dispatch steps reference the contract**

Run:

```bash
test "$(grep -c 'Dispatch model](#dispatch-model-resolve--map--pass)' skills/woostack-execute/references/subagent-driver.md)" -ge 3 && echo OK
```

Expected: `OK` — at least the three dispatch-step citations (implementer step 1, spec-reviewer step 3, quality-reviewer step 4) reference the contract by link. (The exact GitHub-style anchor for `### Dispatch model (resolve → map → pass)` is `dispatch-model-resolve--map--pass`; if you alter the heading text, update the anchor in every citation to match.)

---

### Task 2.5: Note model variation in the execute SKILL

**Files:**
- Modify: `skills/woostack-execute/SKILL.md` (description frontmatter line 3; the subagent bullet in `## Execution mode` ~line 36)

- [x] **Step 1: Add a clause to the `description:`**

In the `description:` frontmatter, change the subagent clause
`per-task spec+quality subagent loops in subagent mode` to
`per-task spec+quality subagent loops in subagent mode, each routed to a tier-appropriate model`.

- [x] **Step 2: Add a sentence to the subagent-mode bullet in `## Execution mode`**

At the end of the `- **subagent** (…subagent-driver.md…)` bullet, append:

```markdown
  In subagent mode the driver also **varies the model per task** — resolving a `fast | standard |
  deep` tier from task complexity/risk and passing it on each dispatch (see
  [references/subagent-driver.md](references/subagent-driver.md) → Tier selection / Dispatch model).
```

- [x] **Step 3: Verify the SKILL mentions model variation**

Run:

```bash
grep -q 'tier-appropriate model' skills/woostack-execute/SKILL.md && \
grep -q 'varies the model per task' skills/woostack-execute/SKILL.md && echo OK
```

Expected: `OK`.

---

### Task 2.6: Verify prompt frontmatter unchanged + final structural checks + commit

**Files:** _(verification only)_

- [x] **Step 1: Confirm prompt `tier:` frontmatter is still the role-default source**

Run:

```bash
grep -q '^tier: standard' skills/woostack-execute/prompts/implementer.md && \
grep -q '^tier: standard' skills/woostack-execute/prompts/spec-reviewer.md && \
grep -q '^tier: deep' skills/woostack-execute/prompts/quality-reviewer.md && echo OK
```

Expected: `OK` (unchanged — defaults match the Tier-selection table).

- [x] **Step 2: No dangling links; twelve SKILL.md files intact**

Run:

```bash
grep -q 'using-woostack/references/model-tiers.md' skills/woostack-execute/references/subagent-driver.md && \
test "$(ls skills/*/SKILL.md | wc -l)" -eq 12 && echo OK
```

Expected: `OK`.

- [x] **Step 3: Dry-run walkthrough (manual, recorded in the PR body)**

Confirm by reading the driver that:
- a trivial single-file task resolves `fast` → implementer dispatched at the fast model;
- a security/migration task resolves `deep` → implementer at the deep model;
- quality-reviewer stays `deep` on a non-trivial diff, `standard` on a trivial one;
- a host without per-call routing runs the session model and reports it as degraded.

- [x] **Step 4: Commit the increment**

Use [`woostack-commit`](../../skills/woostack-commit/SKILL.md) on this increment's Graphite branch
(stacked on PR 1). PR title e.g. `feat(execute): vary subagent model per task (tier wiring + heuristic)`. Body: goal, the wire+adapt summary, and Steps 1–3 as the test plan.

---

## Self-review (against the spec)

- **Spec coverage:** §4.1 shared doc → Task 1.1; §4.2 review repoint → Tasks 1.2–1.5; §4.3 execute repoint → Task 2.1; §4.4 wire → Task 2.2 + 2.4; §4.5 adapt heuristic → Task 2.3; §4.6 SKILL prose → Task 2.5. §6 fail-loud + degrade → Tasks 1.3/1.6, 2.2. §7 testing → Tasks 1.0/1.6, 2.6. ✓ no gaps.
- **Placeholder scan:** every code/edit step shows the literal new text and an exact verify command. ✓
- **Consistency:** the marker is `WOO_MODEL_TIERS_TABLE` in both `_header.md` (Task 1.2) and `load-prompt.sh` (Task 1.3); the shared path `using-woostack/references/model-tiers.md` is identical across Tasks 1.1–1.5, 2.1, 2.2; role defaults (impl/spec=standard, quality=deep) match the prompt frontmatter checked in Task 2.6. ✓
