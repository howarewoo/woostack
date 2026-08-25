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
```

Every run attempts automatic Linear setup. `--migrate-legacy` remains an explicit optional mode and
does not change the setup or artifact-selection boundaries below.

## Procedure
`<wi>` below means the installed `woostack-init` skill directory.


1. Resolve the canonical target repository without changing it. Verify repository root, branch,
   working state, existing `.woostack/` files, and collision/symlink/path safety.
2. Read existing configuration under the
   [effective configuration contract](references/artifact-backends.md#effective-repository-configuration-and-precedence)
   and preserve every valid user-owned value. Never clobber reports or policy without an exact
   approved repair.
3. Create missing local support paths only:
   - `.woostack/config.json` from the shipped non-secret template;
   - local diagnostic report roots for doctor, audit, and QA;
   - worktree/recovery support declared by the canonical worktree contract; and
   - the three managed project OMP role agents by running
     `bash <wi>/scripts/provision-omp-agents.sh <canonical-repository>`. This
     deterministic provisioner updates only `woostack-fast`, `woostack-standard`, and
     `woostack-deep` under `.omp/agents/`, preserves every other agent, ensures exactly one scoped
     `woostack-*.md` rule without overwriting consumer-owned `.omp/agents/.gitignore` lines, and
     never reads model configuration.
   - the managed project OMP session-naming extension, settings entry, and ignore rules by running
     `bash <wi>/scripts/provision-omp-session-name.sh <canonical-repository>`. This
     deterministic provisioner updates only `.omp/extensions/woostack-session-name.ts`,
     `.omp/settings.json`, and `.omp/.gitignore`, preserves other extensions, settings keys, and
     ignore lines, and rejects tracked settings.
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

Preserve every valid existing tracked `.woostack/config.json` value under the
[effective configuration contract](references/artifact-backends.md#effective-repository-configuration-and-precedence).
Semantically add only missing,
validated, non-secret `artifacts.linear` repository/workspace/team/native-name defaults; never replace a
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

For `--migrate-legacy`, follow the
[canonical legacy migration contract](references/legacy-migration.md). The route is explicitly
one-way: any unknown or partial outcome preserves every local source, and deletion requires the
contract's fresh terminal proof plus explicit approval.

## Hard constraints

- Artifact persistence remains explicit. Automatic Linear setup is read-only, selects no artifact,
  and is never required for successful local initialization or repair.
- No source edit outside `.woostack/` except the three init-managed `.omp/agents/woostack-*.md`
  role definitions and the local managed OMP session-naming assets
  (`.omp/extensions/woostack-session-name.ts`, `.omp/settings.json`, and `.omp/.gitignore`); no
  application scaffold.
- No credential read/write, implicit migration, destructive cleanup, commit, push, PR, or merge.
- Preserve user-owned content and fail closed on symlink/path/collision ambiguity.
