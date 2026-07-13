---
name: woostack-init
description: Use when initializing, scaffolding, or repairing the .woostack/ workspace — creates the memory store, specs and plans directories, config.json, and .gitignore from canonical templates, then runs the index builder and the `woostack-doctor` store linter. For ongoing workspace-health checks and convention repair, use [`woostack-doctor`](../woostack-doctor/SKILL.md). Invoke at project setup (brownfield) or from woostack-bootstrap (greenfield).
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
   | `.woostack/specs/` directory | (create empty) |
   | `.woostack/plans/` directory | (create empty) |
   | `.woostack/fixes/` directory | (create empty) |
   | `.woostack/fixes/.gitkeep` | `templates/fixes/.gitkeep` |
   | `.woostack/wisdom/` directory | (create empty) |
   | `.woostack/wisdom/.gitkeep` | `templates/wisdom/.gitkeep` |
   | `.woostack/respond/` directory | (create empty — tracked sanitized response reports) |
   | `.woostack/respond/.gitkeep` | `templates/respond/.gitkeep` |
   | `.woostack/config.json` | `templates/config.json` (`artifacts.specPlan` defaults to `markdown`; tool namespaces follow) |
   | `.woostack/.gitignore` | `templates/gitignore` |
   | `.woostack/worktrees/` directory | (create empty — per-PR git worktrees, gitignored) |

   `config.json` ships with `artifacts.specPlan` set to `markdown`, plus empty `models`, `review`,
   and `respond` namespaces and `status.staleDays` set to 14. Each tool owns its namespace.
   `artifacts.specPlan` selects the spec/plan backend: `markdown` keeps tracked `.woostack`
   artifacts; `linear` stores the build and planning lifecycle in one managed project, one
   managed spec document, and ordered managed increment issues. Linear reaches the verified
   pre-execution handoff without local spec/plan Git artifacts. The accepted keys, lifecycle
   mappings, and current boundary are defined in the
   [artifact backend configuration reference](references/artifact-backends.md). Provider
   credentials never belong in this file.

   The optional `respond` namespace accepts only non-secret workflow defaults: `provider`,
   `environment`, `window`, `max_groups`, and `remediation`; provider credentials remain in
   provider-native stores. The `status` namespace holds `staleDays` (default 14 — the age in days
   past which an executing spec is flagged stale on the `/woostack-status` board), defined in
   [../woostack-status/references/conventions.md](../woostack-status/references/conventions.md).

   `artifacts.specPlan` accepts `markdown` or `linear`; a missing selector also resolves to
   Markdown, so Markdown is the default rather than a universal storage requirement. Linear's
   workspace, team, native project-status, and native issue-state names live in the non-secret
   `linear` config namespace. `LINEAR_API_KEY` is environment only: never store it, another
   credential, or a credential-file path in config or a checked-in env file. The
   [artifact-backend adoption contract](../woostack-bootstrap/references/development.md#artifact-backend)
   owns the canonical project/document/issues model and migration boundary. The resolver owns
   validation; do not duplicate its adapter details here.

   The optional top-level `base_branch` key sets the integration/trunk branch that base branches
   are cut from and PRs target; unset, it auto-detects the remote default (`origin/HEAD`, else
   `main`). Resolution lives in [`scripts/resolve-base.sh`](scripts/resolve-base.sh); the per-PR
   worktree lifecycle that consumes it is the [worktree contract](references/worktrees.md).

   **Host-specific scaffold:** after writing `config.json` (or if it is already present), run any
   scaffold step the current host's reference file names. **Host mechanics:** before any host-dependent step (subagent dispatch, scaffold, draft), load `skills/using-woostack/references/hosts/<current-host>.md`; no matching file -> treat the host as having no per-call routing and say so (degraded).
   (Under omp: run the generator to produce the gitignored tier defs — mechanics in `hosts/omp.md`.)

3. **Handle existing files.** For any file that already exists and `--force`
   is not active: prompt the user to keep or overwrite it. Under `--no-clobber`
   skip all existing files silently without prompting. After the run, state
   which mode was used (interactive / force / no-clobber) in the summary.

4. **Production-error response setup (optional).** If `--respond` was passed, or if
   `--no-respond` was not passed and the user accepts `Set up production error response? [y/N]`,
   inspect repository dependencies, configuration filenames, instrumentation imports,
   configured exporters, and environment-variable **names**, then inventory available host
   CLI/MCP/skill capabilities. Never read or print credential values. Present detected providers,
   coverage gaps, and any provider-native authentication prerequisite; missing authentication is a warning
   and next action, not an init failure.

   Ask sequentially for provider, environment, window, maximum groups, and remediation, showing
   existing values as defaults. Semantically merge only accepted values into `respond`; preserve every sibling and unknown top-level namespace
   byte-for-byte semantically. Existing respond
   values may be kept or explicitly reconfigured. Under `--no-clobber`, an existing config is
   modified only when `--respond` was explicit. Under `--force`, the normal template replacement
   still applies before response setup. `--respond` and `--no-respond` together are a hard error.
   This setup never authenticates a provider, stores a token/DSN/password/cookie/API key, or
   queries production telemetry.

5. **Obsidian vault config (optional).** If `--obsidian` was passed, or if
   `--no-obsidian` was not passed and the user accepts the prompt ("Set up
   Obsidian vault config? [y/N]", default no), copy
   `templates/obsidian/` into `.woostack/.obsidian/`. Never clobber an
   existing `.woostack/.obsidian/` directory — skip silently if it is
   already present. This makes `.woostack/` an Obsidian vault so
   `memory/`, `specs/`, and `plans/` appear as a `[[wikilink]]` graph in the
   desktop app. Obsidian is **optional** — all memory tooling (`recall`,
   `doctor`, `build-index`) works without it.

6. **Run the scripts.**

   ```
   bash scripts/build-index.sh .woostack/memory
   bash ../woostack-doctor/scripts/doctor.sh .woostack/memory
   ```

   Run `build-index.sh` first so the index is current before `doctor.sh` checks
   for wikilink targets.

7. **Report.** Print a summary listing each file as `created` or `skipped`,
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
- `--obsidian` — force-enable the optional Obsidian vault config scaffold
  (step 5) without prompting.
- `--no-obsidian` — force-skip the optional Obsidian vault config scaffold
  (step 5) without prompting.
- `--respond` — opt into guided non-secret production-error response configuration without the
  initial prompt.
- `--no-respond` — suppress production-error response discovery and configuration. Mutually
  exclusive with `--respond`.

## Hard constraints

- **Never clobber `memory.md`, notes, or `config.json`** without an explicit
  overwrite instruction (user confirmation or `--force`). These files contain
  project-specific knowledge that cannot be regenerated.
- **Legacy memory files are out of scope.** `/woostack-init` creates and repairs
  only the scoped `.woostack/memory/` store.
- **Other skills' files are out of scope.** Do not touch anything under
  `skills/`, `action.yml`, or any path outside `.woostack/` in the target
  project.
- **Pure bash, no new runtime dependencies.** The scripts (`build-index.sh`,
  `doctor.sh`, `scope-match.sh`) use only bash and coreutils. Do not introduce
  node, python, or any other runtime to fulfill this verb.
- **Response setup is non-secret and non-operational.** It may detect instrumentation and host
  capabilities, but never reads credential values, authenticates, or queries production.
- **Obsidian is never required.** The `.obsidian/` scaffold is opt-in (step 5).
  All memory tooling (`recall`, `doctor`, `build-index`) works headlessly
  without Obsidian. See
  [references/memory.md](references/memory.md#9-obsidian-optional) for the
  full Obsidian integration contract.

## Reference

The full memory store contract — note frontmatter schema, glob semantics,
derived index format, recall procedure, and script usage — is in
[references/memory.md](references/memory.md).

The sibling `.woostack/wisdom/` store (generalized findings, wholesale-loaded) has its own
contract in [references/wisdom.md](references/wisdom.md).
