# Bootstrap procedure

This reference owns the collision-safe greenfield filesystem procedure. The design-approval gate in
[`../SKILL.md`](../SKILL.md) is the authority boundary. Optional Linear or Plane persistence records the
approved design; it never releases a write barrier.

## Inputs retained before target access

Keep only in active run context:

1. opaque requested target path;
2. product goal and users;
3. required application surfaces;
4. security, compliance, scale, budget, and deployment constraints;
5. researched stack options and live-resolved package/tool versions;
6. complete approved architecture, scope, and initial feature set;
7. intended canonical future repository URL and integration branch; and
8. deterministic stable run/project identity.

Before design approval, do not stat, list, canonicalize, create, or write the target and do not
invoke Git against it. Create no local specification/plan, provider resource, branch, commit, or PR.

## Optional design artifact

Only after explicit design approval, and only when the caller requested persistence or supplied an
exact project URL/UUID, follow the shared
[artifact contract](../../woostack-init/references/artifact-backends.md) and load only the configured
[Linear](../../woostack-init/references/artifact-providers/linear.md) or
[Plane](../../woostack-init/references/artifact-providers/plane.md) profile:

- prove the selected profile's official-MCP capabilities and exact scope;
- resolve the exact supplied project or create one only when requested;
- write the approved goal, architecture, scope, decisions, and repository/base intent;
- use the profile's stable operation identity;
- preserve unrelated human content; and
- independently read the exact resource, labels, identity, scope, and content back.

Missing, partial, ambiguous, or unknown artifact outcomes block that requested synchronization only
unless persistence was explicitly part of the deliverable. Without artifact mode make no provider
call. Never create a provider document or increment issue/work-item during bootstrap.

## Filesystem write barrier

All of these must hold before the first target mutation:

1. complete design explicitly approved in the current conversation;
2. stable run identity plus intended canonical repository/base retained;
3. optional artifact synchronization either not selected, successfully read back, or explicitly
   allowed to degrade by the caller; and
4. collision check proves the target is absent or an empty non-Git directory.

Artifact metadata, native status, provider response, remembered approval, or target-path
availability cannot substitute for design approval.

## First target access and collision check

After the barrier's non-filesystem conditions hold, perform one read-only target check:

- reject a symlink, non-directory object, unreadable/ambiguous result, existing Git worktree or
  repository, populated directory, or path owned by another process/run;
- permit an absent target or an empty non-Git directory only; and
- retain the exact resolved parent/target identity used for creation.

Never reset, clean, delete, overwrite, reuse, or scaffold around an existing path. A changed result
between check and creation blocks.

## Scaffold the approved architecture

Create only the approved surfaces using
[architecture.md](architecture.md), [frameworks.md](frameworks.md),
[infrastructure.md](infrastructure.md), and [patterns.md](patterns.md).

The default package-slice shape is:

```text
apps/ or products/       deployable surfaces
features/                product capabilities and use cases
infrastructure/          adapters for data, auth, queues, email, observability, etc.
packages/                 narrow shared primitives/tooling when justified
```

Exact directories follow the selected ecosystem, but dependency direction remains apps → features
→ infrastructure contracts, with composition at the application boundary. Do not create empty
layers, placeholder packages, example features, speculative abstractions, or duplicate tooling.

For each approved surface:

1. resolve every exact dependency version live from the authoritative registry;
2. initialize the smallest supported scaffold;
3. remove demo/example code not part of the approved product;
4. establish workspace/package boundaries and import rules;
5. implement only the minimum vertical slice needed to prove the architecture;
6. configure environment-variable validation without secret values;
7. add security, error, accessibility, data-loss, migration, and observability protections that the
   approved requirements demand; and
8. keep generated output and runtime evidence out of source control.

Never hard-code remembered versions. Never create a second convention when the selected framework
already supplies one.

## Repository initialization

Because a genuinely greenfield target has no base branch, the initial scaffold is the sole primary
worktree exemption.

1. initialize Git only after scaffold creation at the verified target;
2. configure the intended integration branch and canonical remote without embedding credentials;
3. initialize `.woostack/` non-authoritative support through
   [`woostack-init`](../../woostack-init/SKILL.md);
4. do not create `.woostack/specs/`, `.woostack/plans/`, `.woostack/fixes/`, or a shadow development
   ledger; and
5. use Graphite/worktrees for every later bounded feature or fix.

Do not commit or push until generated files, environment files, lockfiles, ignore rules, and package
boundaries are classified under repository policy.

## README handoff

Write the project README only after the scaffold works. Include:

- product purpose and approved surfaces;
- architecture/package dependency rules;
- exact selected technologies and live-resolved versions;
- setup prerequisites and non-secret environment variable names;
- development, build, test, lint, format, migration, and boot commands that actually exist;
- deployment and observability assumptions;
- rationale for material choices; and
- optional artifact link only when selected and verified.

Do not copy the full workflow contract or remote artifact prose into the repository.

## Verification

Run the generated project's real commands from the target:

1. dependency installation with the selected lockfile/package manager;
2. formatter/check mode;
3. lint/static analysis;
4. typecheck/compile where applicable;
5. tests that the scaffold actually defines;
6. production build; and
7. boot/smoke of each approved deployable surface, exercising at least one vertical path.

Inspect the target tree and Git status afterward. Reject committed secrets, `.env*`, generated build
output, stray examples, broken package boundaries, unexpected files, missing lockfile, or dirty
formatter output. A command that does not exist is not a passing check; fix the scaffold or report
the explicit gap.

## Optional artifact delivery note

When selected, append the verified repository URL, branch, resolved stack/versions, created
surfaces, and observed checks to the exact project artifact in the configured provider and independently read it back. Do not
create issues/work-items, assign owners, transition lifecycle, accept work, or claim source state from the provider.
Artifact failure remains separate from scaffold verification.

## Handoff

Return:

- target path and collision-check result;
- approved architecture and created surfaces;
- exact resolved technology versions and authoritative lookup source;
- canonical repository/base intent;
- verification commands and observed results;
- boot/smoke observations;
- README and environment/setup status;
- optional artifact URL/read-back result; and
- any blocker plus safe next action.

Never claim the scaffold, Git repository, command, or artifact exists unless directly observed.
