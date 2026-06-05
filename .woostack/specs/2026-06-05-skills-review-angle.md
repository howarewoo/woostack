---
name: skills-review-angle
type: spec
status: planning
date: 2026-06-05
branch: feature/skills-review-angle
links:
---

# Skills Review Angle — Design Spec

> Visualize on demand: render this file with [spec-template.html](spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../woostack-status/references/conventions.md).

## 1. Problem

`woostack-review` fans out a swarm of angle reviewers, each scoped to one dimension
(`bugs`, `security`, `docs`, `conventions`, …). There is no angle that reviews **Agent
Skills** against their own authoring best practices. When a PR adds or edits a `SKILL.md`,
nothing in the review catches the failure modes Anthropic's
[skill best-practices guide](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
warns about: a vague or second-person `description` that breaks discovery, a `name` that
violates the frontmatter charset/length/reserved-word rules, a body over 500 lines, nested
references, scripts that punt errors, Windows-style paths, and so on. This repo is itself a
published skills collection, so the gap is felt on its own PRs first.

## 2. Goal

Add one new review angle, `skills`, that audits changed skills against the best-practices
guide and reports violations as standard woostack-review findings. The rubric ships embedded
in the prompt (self-sufficient, like `seo`/`aeo`), with the canonical URL cited for
provenance. The angle is conditional — it fires only when a `SKILL.md` is in the diff — and
slots into the existing detect → swarm → merge → validate → post pipeline with no new
machinery.

## 3. Non-goals

- **No new pipeline machinery.** Reuse the existing angle contract end to end: gating in
  `detect-angles.sh`, the `_header.md` JSON-array output schema, `resolve-diff-line.sh`
  anchoring, merge/validator/intersect, tier routing. No new scripts beyond a test.
- **No always-on behavior.** `skills` is conditional like `docs`; it does not join the
  always-on `bugs`/`security` pair.
- **No live network fetch of the guide.** The rubric is embedded, not fetched at review time
  (consistent with the self-sufficiency rule in `SKILL.md` Knowledge Aggregation).
- **No general skill linting outside review.** This is a review angle only — not a standalone
  `lint-skills` command, not a pre-commit hook.
- **No broadening the trigger to non-`SKILL.md` skill assets.** A PR that edits only a
  reference file or script without touching `SKILL.md` does not fire the angle. (Once fired,
  the angle may *read* those sibling files to judge the skill, but they are not a trigger.)

## 4. Approach

A new angle reuses the established pattern exactly. Decisions locked during ideation:

- **Name:** `skills` — single-token, matching the existing convention (`docs`, `deps`,
  `tests`, `types`). Maps to `prompts/angles/skills.md`, `findings.skills.json`,
  `"angle": "skills"`.
- **Tier:** `standard`. The audit is judgment-heavy (is this description vague? does this
  paragraph justify its tokens? is the freedom level appropriate?), closer to `conventions`
  (standard) than mechanical `docs` (fast). Frontmatter charset/length checks are mechanical,
  but the high-value findings need reasoning.
- **Gating:** fires when any changed path has basename `SKILL.md` (any depth, forward-slash).
  Conditional, like `docs`.
- **Scope:** whole-file audit. When a PR adds or edits a `SKILL.md`, the angle audits the
  entire skill against the rubric, not only the changed lines. It may read sibling
  `references/*` and `scripts/*` in the same skill directory to judge progressive disclosure
  and script quality. Findings anchor to diff-visible lines via `resolve-diff-line.sh`;
  unanchorable findings are dropped per the standard `_header.md` rule (a newly-added
  `SKILL.md` anchors fully, since all its lines are on the diff's RIGHT side).
- **Rubric:** embedded in the prompt, distilled from the best-practices guide, organized into
  the standard angle sections (Scope / Find / Skip / Severity rubric / Output).

## 5. Components & data flow

Seven touch points; no new runtime components.

1. **`skills/woostack-review/prompts/angles/skills.md`** (new). Frontmatter `tier: standard`.
   Sections mirror the existing angle prompts:
   - **Scope** — audit each touched `SKILL.md` (whole file) against the best-practices guide.
     The full `SKILL.md` content is in `diff.txt`, so the core checks (frontmatter, description,
     naming, body length, content hygiene) need nothing else. Reading sibling
     `references/*`/`scripts/*` is **best-effort**: when the working tree is available (local
     `/woostack-review`, or CI with a checkout) the worker reads them to judge
     progressive-disclosure depth and script quality; when only `diff.txt` is available, those
     sibling-dependent checks degrade gracefully and the worker audits what is in the diff. Cite
     the guide URL.
   - **Find** — grouped by best-practices area:
     - *Frontmatter validity:* `name` >64 chars, not `^[a-z0-9-]+$`, contains a reserved word
       (`anthropic`/`claude`), or XML tags; `description` empty, >1024 chars, or XML tags.
     - *Description quality:* vague ("helps with documents"), written in 1st/2nd person
       instead of 3rd, or missing the "what + when to use" pair.
     - *Naming:* vague names (`helper`, `utils`, `tools`), inconsistent with the collection.
     - *Body size:* SKILL.md body over ~500 lines → recommend splitting into reference files.
     - *Progressive disclosure:* references nested more than one level deep; reference files
       over ~100 lines without a table of contents; non-descriptive filenames (`doc2.md`).
     - *Conciseness:* explaining things Claude already knows; paragraphs that don't justify
       their token cost.
     - *Content hygiene:* time-sensitive info not quarantined in an "old patterns" section;
       inconsistent terminology; abstract (not concrete) examples; offering too many options
       without a default.
     - *Scripts (when the skill bundles them):* punting errors to Claude instead of handling
       them; voodoo constants; assuming packages are installed; un-qualified MCP tool names;
       Windows-style backslash paths.
     - *Workflows:* complex multi-step tasks lacking clear steps/checklists or feedback loops
       where quality is critical.
   - **Skip** — pre-existing issues on lines the PR did not touch *and* cannot be anchored;
     non-`SKILL.md` markdown (owned by `docs`); subjective wording nits with no
     best-practice basis.
   - **Severity rubric** — see §6.
   - **Output** — write `findings.skills.json` per the `_header.md` schema; each finding gets
     `"angle": "skills"`, populated `title`/`description`/`fix`/`fix_type`.
2. **`skills/woostack-review/scripts/detect-angles.sh`** — add `has_skills_file()` (basename
   `SKILL.md` match against `CHANGED_PATHS`), an `ANGLES+=("skills")` block, and a catalog
   entry in the leading header comment. **Also exclude `SKILL.md` from `has_docs_file()`'s
   `\.md$` catch** by adding it to the existing `grep -vE` exclusion list (alongside
   `AGENTS.md`/`CLAUDE.md`/`GEMINI.md`), so a SKILL.md-only PR routes to `skills` rather than
   firing `docs` too. Update the `docs` catalog comment to note the new exclusion.
3. **`skills/woostack-review/scripts/load-config.sh`** — add `"skills"` to the `VALID_ANGLES`
   set (line ~85). Without this, a consumer's `.woostack/config.json` with
   `review.angles.force`/`skip: ["skills"]` fails the loader with "unknown angle".
4. **`skills/woostack-review/SKILL.md`** — add `skills` to the Stage 2 conditional-angle list
   (line ~270) and to the Stage 3 tier-assignment table (line ~348, `standard` group).
5. **`skills/woostack-review/prompts/_header.md`** — add `skills` to the Model Tiers table
   `standard` row's angle list.
6. **`skills/woostack-review/prompts/anthropic.md`** — add `skills` to the per-provider tier
   table's `standard` row (line ~51). The `openai`/`google`/`opencode` prompts read each
   angle's tier from its frontmatter and do **not** enumerate angles, so they need no edit.
7. **`skills/woostack-review/scripts/tests/`** — a focused test that constructs a diff/meta
   fixture touching a `SKILL.md` and asserts `detect-angles.sh` enables `skills` (and that a
   no-`SKILL.md` diff does not), following the existing `test-*.sh` harness (`assert.sh`,
   `OUTDIR`+`meta.json`+`diff.txt` fixtures). `detect-angles.sh` has no test today; this locks
   the gate. May optionally also assert `load-config.sh` accepts `skills` in `force`/`skip`.

Data flow is unchanged: `detect-angles.sh` → `angles.txt` includes `skills` → Stage 3 swarm
spawns the `skills` worker reading `prompts/angles/skills.md` + diff → `findings.skills.json`
→ `merge-findings.sh` → validator/intersect → posted review.

## 6. Error handling

- **Angle worker contract.** The worker writes `[]` to `findings.skills.json` first, replaces
  it with the real array before exit, and drops any finding whose `line` does not resolve via
  `resolve-diff-line.sh` — identical to every other angle. No bespoke error handling.
- **Anchoring file-level findings.** `resolve-diff-line.sh` only accepts `+`/context lines, so
  for a *new* `SKILL.md` every line anchors and the audit posts in full; for an *edit*, only
  findings near the changed hunks anchor. File-level findings with no single natural line (body
  over ~500 lines, missing TOC) anchor to the most relevant diff-visible line — the frontmatter
  `name:`/`description:` line for frontmatter findings, the nearest changed line for structural
  ones — and are dropped when nothing anchors. This is the standard contract, not new behavior.
- **Severity rubric (false-positive control):**
  - `HIGH` + `blocking: true` — frontmatter that breaks discovery or loading: `name` violates
    charset/length/reserved-word, or `description` is empty / >1024 chars / contains XML tags.
    These genuinely break the skill.
  - `MEDIUM` + `blocking: false` — vague or 2nd-person `description` (hurts discovery), body
    over ~500 lines, nested references, scripts that punt errors / use voodoo constants /
    assume installs, Windows-style paths.
  - `LOW` + `blocking: false` — vague name, missing TOC on a long reference, verbosity,
    inconsistent terminology, abstract examples, too-many-options.
- **Noise control.** The angle inherits the standard `severity_floor` (default `high`) and
  nits behavior, and the adversarial validator intersection. LOW/MEDIUM findings surface as
  non-blocking nits under the default floor — the angle does not gate PRs on style.
- **Self-review guard.** Because this repo's own PRs touch `SKILL.md`, the angle will review
  itself; the `~500`/`~100`-line thresholds are soft ("over" with a recommendation), never
  hard failures, to avoid the angle flagging its own prompt or large legitimate skills.

## 7. Testing

- **Automated:** add a `detect-angles.sh` gating test under `scripts/tests/`, following the
  existing harness (`source ../../woostack-init/scripts/tests/assert.sh`; `mktemp -d` for
  `OUTDIR`; write `meta.json` with `.files[].path` + a `diff.txt`) — a `SKILL.md` in the
  synthesized changed-paths enables `skills`; a diff with no `SKILL.md` does not. Run alongside
  the existing `scripts/tests/test-*.sh`.
- **Manual:** run `/woostack-review` locally on a branch that edits a `SKILL.md` (e.g. this
  repo's own) and confirm (a) `skills` appears in `angles.txt`, (b) the worker writes a valid
  `findings.skills.json`, (c) seeded violations (a vague description, a reserved-word name)
  surface with the expected severities, and (d) a diff with no `SKILL.md` does not enable the
  angle.

## 8. Open questions

None open. Resolved during ideation and hardening:

- **Name `skills`, tier `standard`** — settled in ideation.
- **`docs`/`skills` gate overlap** — exclude `SKILL.md` from the `docs` gate so a SKILL.md-only
  PR routes to `skills` (mirrors the existing rule-file exclusions). See §5 item 2.
- **Whole-file audit vs. line anchoring** — `resolve-diff-line.sh` only anchors `+`/context
  lines, so the audit posts in full on a new `SKILL.md` and near-the-change on an edit; sibling
  `references/*`/`scripts/*` reads are best-effort (graceful degradation when only `diff.txt` is
  available). See §5 item 1 and §6.
- **Touch-point completeness** — hardening found two enumeration sites beyond the original five:
  `load-config.sh` `VALID_ANGLES` and `anthropic.md`'s tier table. Total is seven (§5).
