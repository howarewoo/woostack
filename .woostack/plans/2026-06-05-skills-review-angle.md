---
type: plan
source: .woostack/specs/2026-06-05-skills-review-angle.md
status: done
branch: feature/skills-review-angle
---

**Source:** .woostack/specs/2026-06-05-skills-review-angle.md

# Skills Review Angle Implementation Plan

**Goal:** Add a `skills` review angle to `woostack-review` that audits changed `SKILL.md` files against Anthropic's skill best-practices guide, wired into the existing detect → swarm → merge → validate pipeline.

**Architecture:** Reuse the established angle contract end to end — a new `prompts/angles/skills.md` worker prompt (`tier: standard`), a gate in `detect-angles.sh` (fires on a `SKILL.md` in the diff) that also hands `SKILL.md` ownership over from the `docs` gate, registration in the `VALID_ANGLES` config allow-list and the three angle→tier enumerations (`SKILL.md`, `_header.md`, `anthropic.md`), and a focused `detect-angles.sh` gating test. No new runtime machinery.

**Tech Stack:** Bash (POSIX-ish, macOS Bash 3.2 safe), `jq`, Python3 (existing scripts), the `scripts/tests/*.sh` + `assert.sh` test harness, Markdown angle prompts.

---

## Increment 1: skills angle (gating, prompt, registration, test)

> One independently shippable PR (≤500 LOC soft target) — its own Graphite-stacked branch. All seven touch points are small and tightly coupled; the spec sets `spec : plan : PRs = 1 : 1 : 1`.

All paths below are relative to the repo root; the review skill lives at `skills/woostack-review/`.

### Task 1: Gate the angle in `detect-angles.sh` (+ hand `SKILL.md` off the `docs` gate)

**Files:**
- Test: `skills/woostack-review/scripts/tests/test-detect-angles-skills.sh` (create)
- Modify: `skills/woostack-review/scripts/detect-angles.sh` (add `has_skills_file()`, an `ANGLES+=("skills")` block, the `SKILL.md` exclusion in `has_docs_file()`, and header-catalog comments)

- [x] **Step 1: Write the failing test**

Create `skills/woostack-review/scripts/tests/test-detect-angles-skills.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/detect-angles.sh"

# setup $1 = newline-separated changed file paths
setup() {
  work="$(mktemp -d)"
  export OUTDIR="$work/out"
  mkdir -p "$OUTDIR"
  printf '%s\n' "$1" | jq -R . | jq -s '{files: [.[] | {path: .}]}' > "$OUTDIR/meta.json"
  : > "$OUTDIR/diff.txt"
}

# A SKILL.md in the diff enables the skills angle and NOT docs.
setup "skills/foo/SKILL.md"
bash "$SCRIPT" >/dev/null 2>&1
assert_contains "$(cat "$OUTDIR/angles.txt")" "skills" "SKILL.md enables skills angle"
assert_eq "$(grep -cx 'docs' "$OUTDIR/angles.txt" || true)" "0" "SKILL.md-only does not enable docs"
rm -rf "$work"

# A non-SKILL code file does not enable skills.
setup "src/index.ts"
bash "$SCRIPT" >/dev/null 2>&1
assert_eq "$(grep -cx 'skills' "$OUTDIR/angles.txt" || true)" "0" "no SKILL.md -> no skills angle"
rm -rf "$work"

# A real README still enables docs (exclusion is SKILL.md-specific, not all .md).
setup "README.md"
bash "$SCRIPT" >/dev/null 2>&1
assert_contains "$(cat "$OUTDIR/angles.txt")" "docs" "README.md still enables docs"
rm -rf "$work"

finish
```

- [x] **Step 2: Run the test, confirm it fails**

Run: `bash skills/woostack-review/scripts/tests/test-detect-angles-skills.sh`
Expected: FAIL — first assertion errors, `SKILL.md enables skills angle` (the `skills` angle is not emitted yet; `angles.txt` for a SKILL.md-only diff currently contains `bugs security docs`).

- [x] **Step 3: Add `has_skills_file()` next to the other `has_*_file` helpers**

In `skills/woostack-review/scripts/detect-angles.sh`, after the `has_deps_file()` function (ends at the `}` before `ANGLES=("bugs" "security")`), add:

```bash
has_skills_file() {
  # Canonical Agent Skill manifest signal: a file named SKILL.md at any depth.
  echo "$CHANGED_PATHS" | grep -qE '(^|/)SKILL\.md$'
}
```

- [x] **Step 4: Exclude `SKILL.md` from the `docs` gate**

In the same file, in `has_docs_file()`, add a `SKILL.md` exclusion to the trailing `*.md` filter pipe so a SKILL.md-only PR routes to `skills`, not `docs` (mirrors the existing rule-file exclusions). Change:

```bash
  echo "$CHANGED_PATHS" \
    | grep -vE '(^|/)(AGENTS|CLAUDE|GEMINI)\.md$' \
    | grep -vE '(^|/)\.(cursorrules|windsurfrules)$' \
    | grep -qE '\.(md|mdx)$' && return 0
```

to:

```bash
  echo "$CHANGED_PATHS" \
    | grep -vE '(^|/)(AGENTS|CLAUDE|GEMINI)\.md$' \
    | grep -vE '(^|/)\.(cursorrules|windsurfrules)$' \
    | grep -vE '(^|/)SKILL\.md$' \
    | grep -qE '\.(md|mdx)$' && return 0
```

- [x] **Step 5: Add the `skills` angle to the `ANGLES` assembly**

In the same file, immediately after the `if has_docs_file; then ANGLES+=("docs") fi` block, add:

```bash
if has_skills_file; then
  ANGLES+=("skills")
fi
```

- [x] **Step 6: Update the header-comment catalog**

In the leading comment block of `detect-angles.sh`, (a) update the `docs` entry to note the new exclusion, and (b) add a `skills` entry. In the `docs —` comment, append `SKILL.md (owned by the skills angle)` to its existing exclusion parenthetical. After the `architecture —` catalog entry, add:

```bash
#   skills    — a file named SKILL.md anywhere in the diff (Agent Skill manifest).
#               Audits the changed skill against Anthropic's skill best-practices
#               guide. SKILL.md is excluded from the docs gate so a SKILL.md-only
#               PR routes here, not to docs.
```

- [x] **Step 7: Lint, then run the test, confirm it passes**

Run: `bash -n skills/woostack-review/scripts/detect-angles.sh && bash skills/woostack-review/scripts/tests/test-detect-angles-skills.sh`
Expected: PASS (no syntax error; all assertions pass; `finish` prints the success summary).

### Task 2: Register `skills` in the config allow-list (`load-config.sh`)

**Files:**
- Modify: `skills/woostack-review/scripts/load-config.sh:85` (`VALID_ANGLES`)

- [x] **Step 1: Write the failing verification**

Run (this is the "failing test" — config `force: ["skills"]` is rejected before the change):

```bash
work="$(mktemp -d)"; export OUTDIR="$work/out"; export GITHUB_WORKSPACE="$work/repo"
mkdir -p "$OUTDIR" "$GITHUB_WORKSPACE/.woostack"
printf '%s\n' '{"review":{"angles":{"force":["skills"]}}}' > "$GITHUB_WORKSPACE/.woostack/config.json"
bash skills/woostack-review/scripts/load-config.sh; echo "rc=$?"; rm -rf "$work"
```

Expected: FAIL — non-zero exit with an annotation containing `angles.force contains unknown angle(s): skills`.

- [x] **Step 2: Add `"skills"` to `VALID_ANGLES`**

In `skills/woostack-review/scripts/load-config.sh`, change line 85 from:

```python
VALID_ANGLES = {"bugs", "security", "conventions", "seo", "aeo", "design", "react", "database", "tests", "api", "infra", "observability", "types", "i18n", "docs", "deps", "architecture"}
```

to (append `, "skills"` before the closing brace):

```python
VALID_ANGLES = {"bugs", "security", "conventions", "seo", "aeo", "design", "react", "database", "tests", "api", "infra", "observability", "types", "i18n", "docs", "deps", "architecture", "skills"}
```

- [x] **Step 3: Re-run the verification, confirm it passes**

Run:

```bash
work="$(mktemp -d)"; export OUTDIR="$work/out"; export GITHUB_WORKSPACE="$work/repo"
mkdir -p "$OUTDIR" "$GITHUB_WORKSPACE/.woostack"
printf '%s\n' '{"review":{"angles":{"force":["skills"]}}}' > "$GITHUB_WORKSPACE/.woostack/config.json"
bash skills/woostack-review/scripts/load-config.sh; echo "rc=$?"
jq -r '.angles.force[]' "$OUTDIR/config.json"; rm -rf "$work"
```

Expected: PASS — `rc=0` and the final line prints `skills`.

### Task 3: Create the `skills` angle prompt

**Files:**
- Create: `skills/woostack-review/prompts/angles/skills.md`

- [x] **Step 1: Write the angle prompt**

Create `skills/woostack-review/prompts/angles/skills.md` with exactly:

```markdown
---
tier: standard
---

# Angle: Skills

**Scope.** Audit Agent Skills changed by this PR against Anthropic's skill best-practices guide (https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices). This angle fires when a `SKILL.md` is in the diff. For each touched `SKILL.md`, audit the **whole file** — its full content is in `/tmp/pr-review/diff.txt` — not only the changed lines. When the working tree is available you MAY read sibling `references/*` and `scripts/*` in the same skill directory to judge progressive disclosure and script quality; when only the diff is available, audit what it contains. A newly-added `SKILL.md` is entirely `+` lines, so every finding anchors; on an edit, only findings near the changed hunks anchor (see Output).

**Find:**

- **Frontmatter validity (breaks discovery/load):**
  - `name` longer than 64 chars, not matching `^[a-z0-9-]+$`, containing a reserved word (`anthropic` / `claude`), or containing XML tags.
  - `description` empty, longer than 1024 chars, or containing XML tags.
- **Description quality:**
  - Vague description that won't drive discovery ("Helps with documents", "Processes data").
  - Written in first/second person ("I can help…", "You can use this…") instead of third person.
  - Missing the *what it does* **and** *when to use it* pair.
- **Naming:**
  - Vague/generic name (`helper`, `utils`, `tools`, `documents`) or one inconsistent with the collection's pattern.
- **Body size & progressive disclosure:**
  - SKILL.md body over ~500 lines — recommend splitting into reference files.
  - References nested more than one level deep (SKILL.md → a.md → b.md); every reference file should link directly from SKILL.md.
  - A reference file over ~100 lines with no table of contents.
  - Non-descriptive bundled filenames (`doc2.md`, `file1.md`).
- **Conciseness:**
  - Explaining things Claude already knows (e.g. "PDF is a file format…"); paragraphs that do not justify their token cost.
- **Content hygiene:**
  - Time-sensitive info ("after August 2025…") not quarantined in an "old patterns" section.
  - Inconsistent terminology for one concept.
  - Abstract examples where concrete input/output pairs are needed.
  - Offering many options with no recommended default.
  - Windows-style backslash paths (`scripts\helper.py`) instead of forward slashes.
- **Scripts (only when the skill bundles them):**
  - A script that punts errors to Claude instead of handling them.
  - Voodoo constants (magic numbers with no justification).
  - Assuming a package is installed without an install step.
  - Un-qualified MCP tool names (use `Server:tool`).
- **Workflows:**
  - A complex multi-step task with no clear steps/checklist, or a quality-critical task with no validate→fix feedback loop.

**Skip:**

- Pre-existing issues on lines the PR did not touch that cannot be anchored on the diff's RIGHT side (see Output) — do not invent a line to report them.
- Non-`SKILL.md` markdown (README / CHANGELOG / docs) — that is the `docs` angle.
- Subjective wording nits with no basis in the best-practices guide.
- Plugin/host-specific frontmatter keys beyond `name` / `description`.

**Severity rubric:**

- `HIGH` + `blocking: true` — frontmatter that breaks discovery or loading: `name` violates charset/length/reserved-word, or `description` is empty / >1024 chars / contains XML tags.
- `MEDIUM` + `blocking: false` — vague or non-third-person description, body over ~500 lines, nested references, a script that punts errors / uses voodoo constants / assumes installs, Windows-style paths.
- `LOW` + `blocking: false` — vague name, missing TOC on a long reference, verbosity, inconsistent terminology, abstract examples, too-many-options, missing feedback loop.

**Output.** Write findings as a JSON array to `/tmp/pr-review/findings.skills.json` using the schema in `_header.md`. Each finding gets `"angle": "skills"` and MUST populate `title` (bold headline ≤60 chars), `description` (the violation — name the file + the best-practice broken, no fix), `fix` (recommended change in prose), and `fix_type`. Anchor each finding's `line` to the most relevant diff-visible line — the frontmatter `name:` / `description:` line for frontmatter findings, the nearest changed line for structural ones — and validate it with `resolve-diff-line.sh`; DROP any finding whose line resolves to `null`. Set `fix_type: "suggestion"` only when a ≤10-line single-file drop-in replacement at `line` is safe — and populate `suggestion`. Otherwise set `fix_type: "prose"` with `suggestion: null`. See `_header.md` for the full rule.
```

- [x] **Step 2: Verify the prompt's shape and that it dogfoods its own rules**

Run:

```bash
f=skills/woostack-review/prompts/angles/skills.md
head -3 "$f"                                                           # tier frontmatter
grep -cE '^\*\*(Scope|Find|Skip|Severity rubric|Output)[.:]\*\*' "$f"  # the 5 sections (. or : terminator)
grep -c 'findings.skills.json' "$f"                                    # writes the right artifact
wc -l < "$f"                                                           # body well under 500 lines
```

Expected: line 2 is `tier: standard`; the section count prints `5` (the regex accepts both the `.` terminator of Scope/Output and the `:` terminator of Find/Skip/Severity rubric); the artifact count prints `1`; the line count is well under 500 (≈80).

### Task 4: Register `skills` in the three angle→tier enumerations + Stage 2 list

**Files:**
- Modify: `skills/woostack-review/SKILL.md` (Stage 2 conditional-angle list ~line 270; Stage 3 tier table ~line 348)
- Modify: `skills/woostack-review/prompts/_header.md` (Model Tiers `standard` row ~line 60)
- Modify: `skills/woostack-review/prompts/anthropic.md` (tier table `standard` row ~line 51)

- [x] **Step 1: SKILL.md Stage 2 list — add `skills`**

In `skills/woostack-review/SKILL.md`, in the Stage 2 paragraph that enumerates conditional angles, insert `skills` after `deps`. Change `…, \`docs\`, \`deps\`, \`architecture\` (when the diff touches general-purpose source files).` to `…, \`docs\`, \`deps\`, \`skills\` (when a \`SKILL.md\` is in the diff), \`architecture\` (when the diff touches general-purpose source files).`

- [x] **Step 2: SKILL.md Stage 3 tier table — add a `skills` row**

In the Stage 3 "Tier assignments" table, after the `| \`tests\`, \`api\`, \`infra\` workers | \`standard\` | Coverage/contract/IaC reasoning. |` row, add:

```markdown
| `skills` worker | `standard` | Skill-authoring judgment against the best-practices guide. |
```

- [x] **Step 3: `_header.md` Model Tiers — add `skills` to the standard row**

In `skills/woostack-review/prompts/_header.md`, in the `| \`standard\` |` Model Tiers row, append `, \`skills\`` to the parenthesized worker list so it reads `…\`tests\`, \`api\`, \`infra\`, \`skills\`)`.

- [x] **Step 4: `anthropic.md` tier table — add `skills` to the standard row**

In `skills/woostack-review/prompts/anthropic.md`, in the `| \`standard\` | \`claude-sonnet-4-6\` | …` row, append `, \`skills\`` to the angle list so it ends `…\`api\`, \`infra\`, \`skills\` |`.

- [x] **Step 5: Verify all four registrations**

Run:

```bash
grep -n '`skills` (when a `SKILL.md`' skills/woostack-review/SKILL.md
grep -n '`skills` worker' skills/woostack-review/SKILL.md
grep -n 'skills`)' skills/woostack-review/prompts/_header.md
grep -n 'infra`, `skills`' skills/woostack-review/prompts/anthropic.md
```

Expected: each `grep` prints exactly one matching line (four matches total).

### Task 5: Full verification sweep + commit

- [x] **Step 1: Run the whole review-skill test suite**

Run:

```bash
for t in skills/woostack-review/scripts/tests/test-*.sh; do echo "== $t"; bash "$t"; done
```

Expected: every test prints its success summary and exits 0 — including the new `test-detect-angles-skills.sh`.

- [x] **Step 2: Lint every shell script touched**

Run: `bash -n skills/woostack-review/scripts/detect-angles.sh && bash -n skills/woostack-review/scripts/load-config.sh && echo OK`
Expected: prints `OK`.

- [x] **Step 3: Smoke-test the end-to-end gate against a real skill path**

Run:

```bash
work="$(mktemp -d)"; export OUTDIR="$work/out"; mkdir -p "$OUTDIR"
printf '%s\n' "skills/woostack-review/SKILL.md" | jq -R . | jq -s '{files: [.[] | {path: .}]}' > "$OUTDIR/meta.json"
: > "$OUTDIR/diff.txt"
bash skills/woostack-review/scripts/detect-angles.sh >/dev/null 2>&1
cat "$OUTDIR/angles.txt"; rm -rf "$work"
```

Expected: output contains `skills` and does **not** contain `docs`.

- [x] **Step 4: Commit the increment**

Commit via `woostack-commit` (it creates the Graphite branch, pushes, and writes the PR fields). This increment stacks on top of the spec+plan PR.

---

## Self-review (run before handing back)

- [x] **Spec coverage** — every spec requirement maps to a task: angle prompt (Task 3) ✓; gating + docs-gate exclusion (Task 1) ✓; `VALID_ANGLES` (Task 2) ✓; SKILL.md Stage 2 + Stage 3, `_header.md`, `anthropic.md` (Task 4) ✓; detect-angles test (Task 1) ✓; severity rubric embedded in the prompt (Task 3) ✓.
- [x] **No placeholders** — every step carries the actual code/commands and exact expected output; no TBD/TODO.
- [x] **Type consistency** — angle name is `skills` everywhere (artifact `findings.skills.json`, `"angle": "skills"`, `VALID_ANGLES`, all tier tables, gate function `has_skills_file`); tier is `standard` everywhere.
