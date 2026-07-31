---
name: woostack-init
description: Initialize or repair a repository's .woostack workspace, local knowledge/diagnostic stores, and non-secret policy. Linear artifact connectivity and guarded legacy migration are optional.
---

# woostack-init

Create or repair `.woostack/` support without creating development authority. Initialization never
creates a spec, plan, fix, issue, project, branch, PR, or lifecycle state.

## Commands

```text
/woostack-init [path]
/woostack-init [path] --linear
/woostack-init [path] --migrate-legacy
/woostack-init [path] --respond
/woostack-init [path] --no-respond
```

`--linear` and `--migrate-legacy` are explicit optional modes. Artifact-free initialization makes no
Linear call.

## Procedure

1. Resolve the canonical target repository without changing it. Verify repository root, branch,
   working state, existing `.woostack/` files, and collision/symlink/path safety.
2. Read existing configuration and preserve all valid user-owned values. Never clobber memory,
   wisdom, reports, or policy without an exact approved repair.
3. Create missing local support paths only:
   - `.woostack/config.json` from the shipped non-secret template;
   - `.woostack/memory/` and its generated index contract;
   - `.woostack/wisdom/`;
   - local diagnostic report roots for doctor, audit, QA, and response; and
   - worktree/recovery support declared by the canonical worktree contract.
4. Validate JSON/schema/path permissions, ignore policy, knowledge formats, generated indexes, and
   cross-links. Run the shipped build-index and doctor checks.
5. Report created, repaired, preserved, skipped, and blocked paths with exact validation results.

## Optional Linear setup

Enter this path only for `--linear` or an explicit request to configure artifact connectivity.
Discover official host-exposed Linear MCP capabilities, prove authenticated read access, and store
only non-secret repository defaults in `.woostack/config.json`. Credentials remain in the host's
MCP/OAuth store.

This setup follows the [optional artifact contract](references/artifact-backends.md). Missing or
partial capability is reported as an artifact-setup blocker, not an init failure. Never hard-code
provider tool names, read credential values, use direct GraphQL/HTTP, or create an issue/project as
a connectivity test.

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

- Artifact-free by default; Linear never required for local initialization or repair.
- No source edit outside `.woostack/`; no application scaffold.
- No credential read/write, implicit migration, destructive cleanup, commit, push, PR, or merge.
- Preserve user-owned content and fail closed on symlink/path/collision ambiguity.
