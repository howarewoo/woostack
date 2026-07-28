---
name: woostack-init
description: Use when initializing, scaffolding, or repairing a Linear-backed `.woostack/` workspace — verifies the host's official Linear MCP connection, writes non-secret repository policy and local knowledge/diagnostic stores, then runs the index builder and `woostack-doctor`. For ongoing workspace-health checks and convention repair, use [`woostack-doctor`](../woostack-doctor/SKILL.md).
---

# woostack-init

## Overview

Verifies mandatory official Linear MCP access, then creates or repairs the non-authoritative
`.woostack/` knowledge, response, worktree, and diagnostic stores. It never creates local
development specs, plans, or fixes. At the end it reports MCP readiness, created/skipped files,
and doctor findings.

Two callers:

- **Brownfield (user-invoked):** the developer runs `/woostack-init` once to
  set up `.woostack/` in an existing project, or later to repair a partial or
  stale workspace.
- **Greenfield (via woostack-bootstrap):** the bootstrap skill calls
  `/woostack-init` as a step in its scaffolding sequence so every new project
  starts with a consistent workspace.

## Procedure

1. **Capture the target without touching it.** If an argument is given, retain that path as the
   requested project root; otherwise retain the current-directory path supplied by the host. Do
   not stat, list, read, canonicalize, or search the target, and do not invoke Git yet.

2. **Preflight official Linear MCP independently of the target.** Discover the host-exposed MCP
   tools at `https://mcp.linear.app/mcp` and authenticate through the host's OAuth/MCP secret
   store. Verify provider availability and the required project/issue/update/comment/relation/
   owner read and mutation capabilities with an independent read-back. Missing MCP,
   authentication, mutation capability, or conclusive read-back is an actionable hard stop with
   zero target filesystem or Git access. Tool names are host-discovered rather than hard-coded.

3. **Resolve the target, then validate target-specific policy before writing.** After the
   provider-only preflight succeeds, resolve the retained target to the repository root and use
   Git's common directory to identify the primary checkout. Derive the canonical repository
   identity, read the committed policy plus the primary-checkout `.woostack/config.local.json`
   team override, and verify exactly one workspace and effective team plus every project-status
   and issue-state mapping through MCP. Require a complete independent read-back. Only then
   inspect which managed workspace files already exist. The canonical capability, layering,
   policy, and receipt contracts are in the
   [Linear MCP development authority](references/artifact-backends.md). The repository-wide
   [Linear-only development authority](../woostack-bootstrap/references/development.md#linear-development-authority)
   defines the adoption model and links the build, worktree, and status authorities.

4. **Create missing pieces from `templates/`.** After the preflight succeeds, create each item
   only if it is absent (unless `--force` is active):

   | Item | Source |
   |---|---|
   | `.woostack/memory/` directory | (create empty) |
   | `.woostack/memory/.gitkeep` | (touch) |
   | `.woostack/wisdom/` directory | (create empty) |
   | `.woostack/wisdom/.gitkeep` | `templates/wisdom/.gitkeep` |
   | `.woostack/respond/` directory | (create empty — tracked sanitized response reports) |
   | `.woostack/respond/.gitkeep` | `templates/respond/.gitkeep` |
   | `.woostack/config.json` | `templates/config.json` |
   | `.woostack/.gitignore` | `templates/gitignore` |
   | `.woostack/worktrees/` directory | (create empty — per-PR Git worktrees, gitignored) |

   Do not create legacy local development-record directories.

   <!-- woostack-legacy-compatibility reader="woostack-init" operation="inspect" paths=".woostack/specs/|.woostack/plans/|.woostack/fixes/|.woostack/overnight/" purpose="migration-classification-only" lifecycle-use="prohibited" -->
   Inspect `.woostack/specs/`, `.woostack/plans/`, `.woostack/fixes/`, and
   `.woostack/overnight/` for migration classification only. Never use them for normal, routine,
   or day-to-day lifecycle work.
   <!-- /woostack-legacy-compatibility -->

   Leave legacy records untouched during an ordinary init and let doctor report one blocking
   finding per active or ambiguous record set. Init never adopts, deletes, or runs normal
   lifecycle processing on legacy development records. `/woostack-init --migrate` follows the
   resumable, no-deletion-on-uncertainty procedure in
   [Linear development-record migration](references/migration.md).

   `config.json` contains shared non-secret repository policy plus tool-owned `models`, `review`,
   `respond`, and `status` namespaces. Initialization persists the canonical repository URL,
   workspace, project-status mappings, issue-state mappings, and any optional repository-default
   team under `linear`. It writes the selected team as the sole override in the ignored
   primary-checkout `.woostack/config.local.json`, so every linked worktree in that clone resolves
   the same effective team. It stores no development record, backend selector, provider
   credential, authorization header, or credential path. The exact policy schema is in
   [Linear MCP development authority](references/artifact-backends.md).

   The optional `respond` namespace accepts only non-secret workflow defaults: `provider`,
   `environment`, `window`, `max_groups`, and `remediation`; provider credentials remain in
   provider-native stores. The `status` namespace holds `staleDays` (default 14), defined in
   [../woostack-status/references/conventions.md](../woostack-status/references/conventions.md).

   The optional top-level `base_branch` key sets the integration/trunk branch that base branches
   are cut from and PRs target; unset, it auto-detects the remote default (`origin/HEAD`, else
   `main`). Resolution lives in [`scripts/resolve-base.sh`](scripts/resolve-base.sh); the per-PR
   worktree lifecycle that consumes it is the [worktree contract](references/worktrees.md).

   **Host-specific initialization:** after writing `config.json` (or if it is already present),
   follow any initialization step the current host's reference file explicitly names. **Host mechanics:** before any host-dependent step (subagent dispatch, scaffold, draft), load `skills/using-woostack/references/hosts/<current-host>.md`; no matching file -> treat the host as having no per-call routing and say so (degraded).
   Under omp there is no host-specific scaffold: omp owns its built-in workers and role
   configuration, and woostack does not create or edit `.omp/agents/`.

5. **Handle existing files.** For any file that already exists and `--force`
   is not active: prompt the user to keep or overwrite it. Under `--no-clobber`
   skip all existing files silently without prompting. After the run, state
   which mode was used (interactive / force / no-clobber) in the summary.

6. **Production-error response setup (optional).** If `--respond` was passed, or if
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

7. **Obsidian vault config (optional).** If `--obsidian` was passed, or if
   `--no-obsidian` was not passed and the user accepts the prompt ("Set up
   Obsidian vault config? [y/N]", default no), copy
   `templates/obsidian/` into `.woostack/.obsidian/`. Never clobber an
   existing `.woostack/.obsidian/` directory. This makes the local memory and wisdom stores
   available as an optional `[[wikilink]]` graph; development records remain in Linear.
   All memory tooling works without Obsidian.

8. **Run the scripts.** Use the resolved repository root as the doctor target; the memory
   directory is only the index builder's target.

   ```
   bash scripts/build-index.sh "$repository_root/.woostack/memory"
   bash ../woostack-doctor/scripts/doctor.sh --live-receipt "$receipt" "$repository_root"
   ```

   The skill controller writes the normalized non-secret MCP preflight receipt to a mode-0600
   temporary file, passes it to doctor, and deletes it after consumption.

9. **Report.** Print a summary listing MCP readiness and each file as `created` or `skipped`,
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
  (step 7) without prompting.
- `--no-obsidian` — force-skip the optional Obsidian vault config scaffold
  (step 7) without prompting.
- `--respond` — opt into guided non-secret production-error response configuration without the
  initial prompt.
- `--no-respond` — suppress production-error response discovery and configuration. Mutually
  exclusive with `--respond`.
- `--migrate` — after successful MCP and target-specific preflight, classify and migrate legacy
  local development records through [`references/migration.md`](references/migration.md).
  Ambiguous, partial, or foreign evidence preserves every local record.

## Hard constraints

- **Never clobber `memory.md`, notes, or `config.json`** without an explicit
  overwrite instruction (user confirmation or `--force`). These files contain
  project-specific knowledge that cannot be regenerated.
- **Legacy development records are migration-only.** Never create or repair local specs, plans,
  or fixes. Preserve legacy sets until the verified one-way migration authorizes deletion.
- **Other skills' files are out of scope.** Do not touch anything under
  `skills/`, `action.yml`, or any path outside `.woostack/` in the target
  project.
- **Pure bash, no new runtime dependencies.** The scripts (`build-index.sh`,
  `doctor.sh`, `scope-match.sh`) use only bash and coreutils. Do not introduce
  node, python, or any other runtime to fulfill this verb.
- **Response setup is non-secret and non-operational.** It may detect instrumentation and host
  capabilities, but never reads credential values, authenticates, or queries production.
- **Obsidian is never required.** The `.obsidian/` scaffold is opt-in (step 7).
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
