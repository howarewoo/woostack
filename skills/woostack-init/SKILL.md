---
name: woostack-init
description: Initialize or repair a repository's .woostack workspace, diagnostic stores, non-secret policy, and safe Linear defaults. Guarded legacy migration is optional.
---

# woostack-init

Create or repair `.woostack/` support without creating development authority. Initialization never
creates a spec, plan, fix, issue, project, branch, PR, or lifecycle state.

## Commands

```text
/woostack-init [path]
/woostack-init [path] --migrate-legacy
/woostack-init [path] --respond
/woostack-init [path] --no-respond
```

Every run attempts automatic Linear setup. `--migrate-legacy` remains an explicit optional mode and
does not change the setup or artifact-selection boundaries below.

## Procedure
`<wi>` below means the installed `woostack-init` skill directory.


1. Resolve the canonical target repository without changing it. Verify repository root, branch,
   working state, existing `.woostack/` files, and collision/symlink/path safety.
2. Read existing configuration and preserve every valid user-owned value. Never clobber reports or
   policy without an exact approved repair.
3. Create missing local support paths only:
   - `.woostack/config.json` from the shipped non-secret template;
   - local diagnostic report roots for doctor, audit, QA, and response;
   - worktree/recovery support declared by the canonical worktree contract; and
   - the three managed project OMP role agents by running
     `bash <wi>/scripts/provision-omp-agents.sh <canonical-repository>`. This
     deterministic provisioner updates only `woostack-fast`, `woostack-standard`, and
     `woostack-deep` under `.omp/agents/`, preserves every other agent, ensures exactly one scoped
     `woostack-*.md` rule without overwriting consumer-owned `.omp/agents/.gitignore` lines, and
     never reads model configuration.
4. Perform the automatic read-only [Linear setup](#automatic-linear-setup). Its configured,
   preserved, skipped, or setup-blocked outcome is separate from local initialization.
5. Validate JSON/schema/path permissions, ignore policy, report roots, managed OMP role agents, and
   cross-links. Run the shipped doctor checks.
6. Report created, repaired, preserved, skipped, and blocked local paths with exact validation
   results. Report the Linear configured, preserved, skipped, or setup-blocked outcome separately;
   a Linear setup outcome never changes a successful ordinary local-init result.

## Automatic Linear setup

On every run, discover official host-exposed Linear MCP capability. When it is available, use only
the minimum authenticated read calls needed to resolve and validate the canonical repository
association, one workspace/team, and the native project-status and issue-state names accepted by
the existing config schema. Authenticated read access is sufficient: do not require, probe, or use
provider write or post-mutation read-back capability. Credentials remain in the host's MCP/OAuth
store.

Preserve every valid existing `.woostack/config.json` value. Semantically add only missing,
validated, non-secret `linear` repository/workspace/team/native-name defaults; never replace a
valid value merely because discovery differs. After a local config write, independently reopen and
parse the file, compare the intended fields and preserved siblings, and report the write configured
only when that read-back succeeds.

This setup is the narrow read-only exception defined by the
[optional artifact contract](references/artifact-backends.md). It never selects artifact mode,
reads an issue/project, creates or mutates a provider resource, or authorizes later provider access.
If the official MCP is absent, report Linear setup as skipped. If it is unauthenticated,
insufficient, partial, ambiguous, or conflicts with a preserved value, report setup-blocked. In
both cases continue ordinary local initialization and doctor validation. Never hard-code provider
tool names, read credential values, use direct GraphQL/HTTP, or test connectivity with a provider
write.

## Optional guarded legacy migration

Tracked legacy `.woostack/specs/`, `.woostack/plans/`, `.woostack/fixes/`, and overnight records are
ordinary user-owned files. Never migrate or delete them implicitly.

For `--migrate-legacy`:

1. inventory every tracked legacy record and its provenance;
2. present an exact one-way migration plan and require explicit confirmation;
3. require working official MCP artifact connectivity;
4. create/update only approved destination artifacts with stable mutation IDs and independent
   read-back;
5. verify every source-to-destination mapping completely; and
6. delete local legacy files only after explicit deletion approval and direct proof that no data is
   lost.

Unknown/partial provider outcomes stop migration with retained IDs and all local files preserved.
There is no alternate transport or silent fallback.

## Optional response setup

Use `--respond` to opt in or `--no-respond` to skip. In an interactive run with neither flag, ask
`Set up production error response? [y/N]`.

1. Inspect only declared dependencies, configuration filenames, instrumentation imports, and
   environment-variable **names**. Never read or print credential values.
2. Show detected providers and ask sequentially for `provider, environment, window, maximum groups, and remediation`.
   `missing authentication is a warning` and next action, not an init failure.
3. Semantically merge only accepted values into `.woostack/config.json`; `preserve every sibling and unknown top-level namespace`.
4. Create the ignored evidence root from the shipped placeholder:

   | Destination | Template |
   |---|---|
   | `.woostack/respond/.gitkeep` | `templates/respond/.gitkeep` |

Under `--no-clobber`, any conflicting existing value or unsafe path blocks that field without
rewriting siblings. Under `--force`, replacement still requires explicit response setup and may
change only the accepted response subtree; a destructive, malformed, or symlinked destination is a
hard error.

The setup never queries production, changes provider configuration, validates secret values, or
turns observability configuration into development authority.

## Hard constraints

- Artifact persistence remains explicit. Automatic Linear setup is read-only, selects no artifact,
  and is never required for successful local initialization or repair.
- No source edit outside `.woostack/` except the three init-managed `.omp/agents/woostack-*.md`
  role definitions; no application scaffold.
- No credential read/write, implicit migration, destructive cleanup, commit, push, PR, or merge.
- Preserve user-owned content and fail closed on symlink/path/collision ambiguity.
