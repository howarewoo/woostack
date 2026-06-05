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
