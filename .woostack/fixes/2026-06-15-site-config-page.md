---
type: fix
status: hardened
branch: fix/site-config-page
---

# Fix: Docs site has no central page explaining `.woostack/config.json` parameters

## 1. Root Cause

This is a documentation gap, not a runtime bug. Every `.woostack/config.json` parameter
is read and validated somewhere in the skill collection, but the **docs site has no central
reference** that explains them. The authored docs tree is only three pages — `index.mdx`,
`getting-started.mdx`, `concepts.mdx` — and none mentions `config.json`. Configuration is
surfaced only piecemeal across the *generated* per-skill reference pages (`woostack-review`
documents `severity_floor`/`models.*`, `woostack-sweep` documents `review_sweep.max_rounds`,
`woostack-commit` documents `commit.pre_commit`, etc.), so a user who wants to know "what can
I put in config.json and what does each key do" has nowhere to look.

Evidence (authoritative sources, by namespace):

- `review.*` — read/validated by `skills/woostack-review/scripts/load-config.sh` (the schema
  validator), plus `detect-angles.sh`, `intersect-findings.sh`, `prefetch.sh`,
  `resolve-model.sh`, `verify-receipts.sh`.
- `status.staleDays` — `skills/woostack-status/scripts/status.sh`.
- `review_sweep.max_rounds` — `skills/woostack-sweep/SKILL.md`,
  `skills/woostack-execute-overnight/SKILL.md` (agent-interpreted, not a bash read).
- `commit.pre_commit` — `skills/woostack-commit/SKILL.md` §3 (`jq -r '.commit.pre_commit'`).
- `base_branch` — `skills/woostack-init/scripts/resolve-base.sh`.
- Init template ships only `{ "review": {}, "status": { "staleDays": 14 } }`
  (`skills/woostack-init/templates/config.json`); `woostack-doctor`'s `config-key` check
  validates those two top-level keys are present.

## 2. Proposed Fix

Add one authored page — `site/content/docs/configuration.mdx` — and wire it into the sidebar
between **Core concepts** and **Skills** (reading order: orient → install → mental model →
**config reference** → per-skill reference).

Design decisions (confirmed with the user):

- **Format: task-grouped prose + small tables.** Group by what the reader is tuning
  (review noise, models, angles, chunking, adversarial pipeline, sweep, commit hook, status,
  base branch) — a short paragraph of context per group, then a small table of the keys in
  that group (`key | type | default | meaning`). Not one giant flat table.
- **Include all four completeness extras:**
  1. A full annotated example `.woostack/config.json`.
  2. The full `VALID_ANGLES` enum (so `review.angles.force` / `skip` values are documented).
  3. The model-resolution precedence chain + the default model table per provider.
  4. A "defaults & doctor" note: the init template ships `review` + `status`, missing keys
     take built-in defaults, and `woostack-doctor` validates the two template top-level keys.
- Match the authored-page conventions: two-key frontmatter (`title`, `description`,
  sentence-case title, description is a full sentence ending in a period); Fumadocs MDX
  components used without imports (`Callout`, `Cards`, `Card`); standard Markdown tables.
- Keep it accurate to the source, not invented. Do **not** restate framework versions or
  duplicate per-skill prose verbatim — link out to the relevant skill page where a key's full
  behavior lives (e.g. the review angle catalog).

### Harden — residual questions resolved

1. **Example `config.json` comments.** JSON has no comment syntax — the example block is
   strict valid JSON (every namespace populated with representative keys); per-key annotation
   lives in the section tables above it. Add a one-line note that JSON has no comments.
2. **Legacy flat review config.** Out of scope — document only the current nested form.
3. **`review.fix_commands`.** Included for completeness, marked *reserved / not yet active*.
4. **Cross-links.** Model/angle/adversarial depth → `/docs/skills/woostack-review`; sweep →
   `/docs/skills/woostack-sweep`; commit hook → `/docs/skills/woostack-commit`; base branch →
   `/docs/skills/woostack-init`. Link, don't restate.
5. **Title/description.** `title: Configuration`; `description: Every key in
   .woostack/config.json — what it tunes, its type, and its default.`

### Authoritative parameter inventory (write the page from this — do not re-investigate)

Top-level namespaces: `review`, `status`, `review_sweep`, `commit`, `base_branch`.

#### `review.*` — review engine (all optional; `load-config.sh` validates types, unknown keys are hard errors)

Noise control:

| Key | Type | Default | Meaning |
|---|---|---|---|
| `review.severity_floor` | string | `"high"` | Blocking threshold: `low`/`medium`/`high` (case-insensitive). At/above floor = normal finding; below = non-blocking nit (unless `nits:false`). Below-floor `blocking:true` always surfaces. |
| `review.nits` | bool | `true` | `true` posts below-floor findings as `Nit:` (non-blocking); `false` drops them. Below-floor blocking findings always surface. |

Angle control:

| Key | Type | Default | Meaning |
|---|---|---|---|
| `review.angles.force` | array<string> | `[]` | Angles always enabled regardless of auto-detection. `force` beats `skip`. |
| `review.angles.skip` | array<string> | `[]` | Angles never enabled. `bugs` and `security` cannot be skipped (silently kept). |

`VALID_ANGLES` (19): `aeo`, `api`, `architecture`, `bugs`, `comments`, `conventions`,
`database`, `deps`, `design`, `docs`, `i18n`, `infra`, `observability`, `react`, `security`,
`seo`, `skills`, `tests`, `types`.

Diff filtering:

| Key | Type | Default | Meaning |
|---|---|---|---|
| `review.ignore` | array<string> | `[]` | fnmatch globs; matching files excluded from angle detection and the diff body before analysis. |
| `review.project_rules` | array<string> | `[]` | fnmatch globs of extra project-rule files appended to auto-discovered `rules.md`; triggers the `conventions` angle. |

Auto-skip:

| Key | Type | Default | Meaning |
|---|---|---|---|
| `review.authors_skip` | array<string> | `["dependabot[bot]","renovate[bot]","github-actions[bot]"]` | PR author logins that short-circuit the review with a skip comment. Explicit `[]` opts out. |
| `review.release_rollup_pattern` | string | `^(staging\|release\|chore\(release\))` | Python regex on PR title; match short-circuits with a skip comment. `""` opts out. |

Model overrides (`review.models`; unknown sub-keys are hard errors):

| Key | Type | Default | Meaning |
|---|---|---|---|
| `review.models.fast` / `.standard` / `.deep` | string | provider table | Provider-agnostic tier fallback model slug. |
| `review.models.<provider>.<tier>` | string | see table below | Provider-specific override; `<provider>` ∈ {`anthropic`,`openai`,`google`,`openrouter`}, `<tier>` ∈ {`fast`,`standard`,`deep`}. |
| `review.force_tier` | string | absent (= standard) | Bakes a run tier (`fast`/`deep`) into config; empty = absent. |

Default model table:

| Provider | fast | standard | deep |
|---|---|---|---|
| anthropic | `claude-haiku-4-5` | `claude-sonnet-4-6` | `claude-opus-4-8` |
| openai | `gpt-5.3-codex-spark` | `gpt-5.4-mini` | `gpt-5.5` |
| google | `gemini-3-5-flash` | `gemini-3-5-flash` | `gemini-3-5-flash` |
| openrouter | `openrouter/deepseek/deepseek-v4-flash` | `openrouter/deepseek/deepseek-v4-pro` | `openrouter/deepseek/deepseek-v4-pro` |

Model-resolution precedence (highest → lowest): inline comment `--fast`/`--deep` → action
input `force_tier` → `review.force_tier` → action input `model` → `models.<provider>.<tier>`
→ flat `models.<tier>` → provider table default.

Diff chunking / pipeline / metrics:

| Key | Type | Default | Meaning |
|---|---|---|---|
| `review.chunking.max_loc` | int ≥0 | `4000` | Changed-line threshold to split the diff into chunks (angles × chunks fan-out). `0` disables chunking. |
| `review.disable_adversarial` | bool | `false` | `true` skips the prosecutor pass (defender-only); cost opt-out. |
| `review.defer_markers` | bool | `true` | `true` honors inline `woostack-defer(<ref>)` markers (demote to nit). `security` never deferred; bare `TODO` never honored. |
| `review.metrics` | bool | `false` | `true` emits `findings.metrics.json` + folds rolling `.woostack/metrics.json` (local runs). |
| `review.fix_commands` | array<string> | `[]` | Reserved for future `--loop` mode (parsed, not yet consumed). |

#### `status.*`

| Key | Type | Default | Meaning |
|---|---|---|---|
| `status.staleDays` | int | `14` | Days of inactivity before an `executing`-phase spec row is flagged stale on the board. |

#### `review_sweep.*`

| Key | Type | Default | Meaning |
|---|---|---|---|
| `review_sweep.max_rounds` | int >0 | `3` | Max review→address-comments rounds per PR in a sweep before declaring done-with-nits or blocked. Non-positive/non-int warns and falls back to 3. |

#### `commit.*`

| Key | Type | Default | Meaning |
|---|---|---|---|
| `commit.pre_commit` | string | absent (no-op) | Shell command run from repo root before staging. Failure stops the commit; success that changes files triggers a relevance reassess. |

#### Top-level `base_branch`

| Key | Type | Default | Meaning |
|---|---|---|---|
| `base_branch` | string | auto-detect | Trunk/integration branch for PR targeting and worktree base-cutting. Absent → `WOOSTACK_BASE_BRANCH` env → `origin/HEAD` → `main`. |

Defaults & doctor: the init template ships `{ "review": {}, "status": { "staleDays": 14 } }`;
every other key takes its built-in default when absent. `woostack-doctor`'s `config-key`
check validates that the two template top-level keys (`review`, `status`) are present and can
auto-repair a missing one; sub-keys are validated at review runtime by `load-config.sh`.

## 3. Implementation Plan

- [ ] **Step 1: Author `site/content/docs/configuration.mdx`**
  - Two-key frontmatter (`title: Configuration`, one-sentence `description`).
  - Lead paragraph: where the file lives (`.woostack/config.json`), that all keys are
    optional, missing keys take defaults.
  - Task-grouped sections (prose + small `key | type | default | meaning` table each):
    review noise, angles (+ `VALID_ANGLES` list), diff filtering, auto-skip, models
    (+ default table + precedence chain), chunking/adversarial/metrics, sweep, commit hook,
    status, base branch.
  - Extras: full annotated example `config.json` (fenced block); `VALID_ANGLES` enum;
    model-resolution precedence; defaults-&-doctor `Callout`.
  - Cross-link out to skill pages rather than restating per-skill prose.
- [ ] **Step 2: Wire navigation**
  - Edit `site/content/docs/meta.json` `pages` → `["index","getting-started","concepts","configuration","skills"]`.
- [ ] **Step 3: Verification**
  - Run `pnpm -C site build` (runs `gen-skills.mjs` then `next build`) — must pass.
  - Confirm the page renders and appears in the sidebar between Core concepts and Skills.
  - (No content test runner exists; successful build + render is the concrete verification per
    the woostack-tdd no-runner carve-out.)
