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

1. **Resolve the target directory.** If an argument is given, treat it as the
   project root; otherwise use the current working directory. Check whether
   `.woostack/` already exists and note each file that is present — these are
   candidates for the keep/overwrite prompt.

2. **Validate official Linear MCP before filesystem writes.** Discover the host-exposed MCP tools
   at `https://mcp.linear.app/mcp`; authenticate through the host's OAuth/MCP secret store. Resolve
   exactly one configured workspace and team. Verify the repository identity, every configured
   project-status category and issue-state mapping, and the required project/issue/update/comment/
   relation/owner/read-back capabilities. Prefer reversible or non-destructive reads. Missing,
   read-only, ambiguous, or unauthenticated access is an actionable hard stop before creating or
   modifying project files. Tool names are host-discovered rather than hard-coded. The canonical
   capability, policy, and receipt contract is
   [Linear MCP development authority](references/artifact-backends.md).

3. **Create missing pieces from `templates/`.** After the preflight succeeds, create each item
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

   Do not create `.woostack/specs/`, `.woostack/plans/`, or `.woostack/fixes/`. Existing copies
   are legacy migration input; leave them untouched and let doctor report one blocking migration
   finding per active or ambiguous record set.

   `config.json` contains non-secret repository policy plus tool-owned `models`, `review`,
   `respond`, and `status` namespaces. Initialization persists the verified canonical repository
   URL, workspace, team, `projectStatuses`, and `issueStates` under `linear`. It stores no
   development record, backend selector, provider credential, authorization header, or credential
   path. The exact policy schema is in
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

4. **Handle existing files.** For any file that already exists and `--force`
   is not active: prompt the user to keep or overwrite it. Under `--no-clobber`
   skip all existing files silently without prompting. After the run, state
   which mode was used (interactive / force / no-clobber) in the summary.

5. **Production-error response setup (optional).** If `--respond` was passed, or if
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

6. **Obsidian vault config (optional).** If `--obsidian` was passed, or if
   `--no-obsidian` was not passed and the user accepts the prompt ("Set up
   Obsidian vault config? [y/N]", default no), copy
   `templates/obsidian/` into `.woostack/.obsidian/`. Never clobber an
   existing `.woostack/.obsidian/` directory. This makes the local memory and wisdom stores
   available as an optional `[[wikilink]]` graph; development records remain in Linear.
   All memory tooling works without Obsidian.

7. **Run the scripts.**

   ```
   bash scripts/build-index.sh .woostack/memory
   bash ../woostack-doctor/scripts/doctor.sh --live-receipt "$receipt" .woostack/memory
   ```

   The skill controller writes the normalized non-secret MCP preflight receipt to a mode-0600
   temporary file, passes it to doctor, and deletes it after consumption.

8. **Report.** Print a summary listing MCP readiness and each file as `created` or `skipped`,
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
  (step 6) without prompting.
- `--no-obsidian` — force-skip the optional Obsidian vault config scaffold
  (step 6) without prompting.
- `--respond` — opt into guided non-secret production-error response configuration without the
  initial prompt.
- `--no-respond` — suppress production-error response discovery and configuration. Mutually
  exclusive with `--respond`.

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
