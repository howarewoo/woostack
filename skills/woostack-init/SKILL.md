---
name: woostack-init
description: Use when initializing, scaffolding, or repairing the .woostack/ workspace — creates the memory store, specs and plans directories, config.json, and .gitignore from canonical templates, then runs the index builder and store linter. Invoke at project setup (brownfield) or from woostack-bootstrap (greenfield).
---

# woostack-init

## Overview

Creates or repairs the `.woostack/` workspace directory tree for a project. It
writes every missing piece from the skill's `templates/` directory, runs
`build-index.sh` to regenerate the derived memory index, and then runs
`doctor.sh` to lint the store. At the end it reports what was created, what
was skipped, and any doctor warnings or errors.

Two callers:

- **Brownfield (user-invoked):** the developer runs `/woostack-init` once to
  set up `.woostack/` in an existing project, or later to repair a partial or
  stale workspace.
- **Greenfield (via woostack-bootstrap):** the bootstrap skill calls
  `/woostack-init` as a step in its scaffolding sequence so every new project
  starts with a consistent workspace.

## Procedure

1. **Resolve the target directory.** If an argument is given, treat it as the
   project root; otherwise use the current working directory. Check whether
   `.woostack/` already exists and note each file that is present — these are
   candidates for the keep/overwrite prompt.

2. **Create missing pieces from `templates/`.** For each item below, create it
   only if it is absent (unless `--force` is active):

   | Item | Source |
   |---|---|
   | `.woostack/memory/` directory | (create empty) |
   | `.woostack/memory/.gitkeep` | (touch) |
   | `.woostack/memory.md` | (create empty — **never clobber an existing file**) |
   | `.woostack/specs/` directory | (create empty) |
   | `.woostack/plans/` directory | (create empty) |
   | `.woostack/config.json` | `templates/config.json` (`{ "review": {} }`) |
   | `.woostack/.gitignore` | `templates/gitignore` |

   `config.json` ships as `{ "review": {} }`. Each tool owns its own
   namespace inside that object; for the `review` namespace see
   [references/memory.md](references/memory.md).

3. **Handle existing files.** For any file that already exists and `--force`
   is not active: prompt the user to keep or overwrite it. Under `--no-clobber`
   skip all existing files silently without prompting. After the run, state
   which mode was used (interactive / force / no-clobber) in the summary.

4. **Run the scripts.**

   ```
   bash scripts/build-index.sh .woostack/memory
   bash scripts/doctor.sh .woostack/memory
   ```

   Run `build-index.sh` first so the index is current before `doctor.sh` checks
   for wikilink targets.

5. **Report.** Print a summary listing each file as `created` or `skipped`,
   then echo the doctor output (warnings and error count). If doctor exits
   non-zero, surface the errors prominently so the user can act on them before
   committing.

## Flags

- `--force` — overwrite every existing file without prompting. Use with
  caution: this will replace `memory.md`, `config.json`, and any notes that
  happen to share a template name.
- `--no-clobber` — skip every existing file silently, no prompts. Useful in
  automated contexts (CI, bootstrap) where the workspace may already be
  partially initialized.

## Hard constraints

- **Never clobber `memory.md`, notes, or `config.json`** without an explicit
  overwrite instruction (user confirmation or `--force`). These files contain
  project-specific knowledge that cannot be regenerated.
- **The flat `.woostack/memory.md` is out of scope.** That global shard is
  owned by individual skills and the user; `/woostack-init` creates it empty
  if absent and never rewrites it.
- **Other skills' files are out of scope.** Do not touch anything under
  `skills/`, `action.yml`, or any path outside `.woostack/` in the target
  project.
- **Pure bash, no new runtime dependencies.** The scripts (`build-index.sh`,
  `doctor.sh`, `scope-match.sh`) use only bash and coreutils. Do not introduce
  node, python, or any other runtime to fulfill this verb.

## Reference

The full memory store contract — note frontmatter schema, glob semantics,
derived index format, recall procedure, and script usage — is in
[references/memory.md](references/memory.md).
