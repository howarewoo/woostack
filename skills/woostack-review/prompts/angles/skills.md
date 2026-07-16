---
tier: standard
---

# Angle: Skills

**Scope.** Audit Agent Skills changed by this PR against Anthropic's skill best-practices guide (https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices). This angle fires when a `SKILL.md` is in the diff. For each touched `SKILL.md`, first inspect the authoritative diff, then lazily find that exact `skillPath` in `$OUTDIR/skill-packages.json` and read its validated snapshot under `$OUTDIR/<snapshotPath>` for whole-file and sibling `references/*` / `scripts/*` context. Do not inspect package entries for untouched skills, execute package content, or read siblings from the host working directory. A newly-added `SKILL.md` is entirely `+` lines, so package-context findings may anchor its added lines; on an edit, the diff remains the sole finding-anchor authority (see Output).

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

- Pre-existing or unchanged package concerns that the PR did not introduce and that have no relevant RIGHT-side diff line. Snapshot context never permits inventing an anchor or attaching a sibling-file concern to an unrelated changed line.
- Non-`SKILL.md` markdown (README / CHANGELOG / docs) — that is the `docs` angle.
- Subjective wording nits with no basis in the best-practices guide.
- Plugin/host-specific frontmatter keys beyond `name` / `description`.

**Severity rubric:**

- `HIGH` + `blocking: true` — frontmatter that breaks discovery or loading: `name` violates charset/length/reserved-word, or `description` is empty / >1024 chars / contains XML tags.
- `MEDIUM` + `blocking: false` — vague or non-third-person description, body over ~500 lines, nested references, a script that punts errors / uses voodoo constants / assumes installs, Windows-style paths.
- `LOW` + `blocking: false` — vague name, missing TOC on a long reference, verbosity, inconsistent terminology, abstract examples, too-many-options, missing feedback loop.

**Output.** Write findings as a JSON array to `$OUTDIR/findings.skills.json` using the schema in `_worker-header.md`. Each finding gets `"angle": "skills"` and MUST populate `title` (bold headline ≤60 chars), `description` (the violation — name the file + the best-practice broken, no fix), `fix` (recommended change in prose), and `fix_type`. `diff.txt` is the sole finding-anchor and `resolve-diff-line.sh` authority: anchor to the relevant RIGHT-side line in the touched `SKILL.md` — the changed frontmatter `name:` / `description:` line for frontmatter findings, or the changed line that introduces a package-level structural concern — and DROP any finding that resolves to `null`. Never anchor directly to an unchanged snapshot sibling. A new skill may anchor any relevant added `SKILL.md` line. Set `fix_type: "suggestion"` only when a ≤10-line single-file drop-in replacement at `line` is safe — and populate `suggestion`. Otherwise set `fix_type: "prose"` with `suggestion: null`. See `_worker-header.md` for the full rule.
