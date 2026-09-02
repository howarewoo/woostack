# Bootstrap procedure

This reference owns the collision-safe greenfield filesystem procedure. The design-approval gate in
[`../SKILL.md`](../SKILL.md) is the authority boundary. Optional Linear, Plane, or GitHub persistence records the
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

Before design approval and target collision check, do not mutate, create, delete, overwrite, or
scaffold the target, and do not invoke Git against it. Target inspection before write admission is
strictly read-only (stat, directory listing, no-follow symlink check). Create no local specification/plan,
provider resource, branch, commit, or PR. Zero GitHub, Linear, or Plane operations occur before
design approval and collision admission.

## Filesystem write barrier and collision check

All of these must hold before target admission:

1. complete design explicitly approved in the current conversation;
2. stable run identity plus intended canonical repository/base retained; and
3. read-only collision check proves the target is absent or an empty non-Git directory.

Reject a symlink, non-directory object, unreadable/ambiguous result, existing Git worktree or
repository, populated directory, or path owned by another process/run. Never reset, clean, delete,
overwrite, reuse, or scaffold around an existing path.

## Optional design artifact

Only after explicit design approval and successful collision admission, and only when the caller
requested persistence or supplied an exact Linear/Plane project URL-or-UUID or canonical GitHub Project URL, follow the shared
[artifact contract](../../woostack-init/references/artifact-backends.md) and load only the configured
[GitHub](../../woostack-init/references/artifact-providers/github.md),
[Linear](../../woostack-init/references/artifact-providers/linear.md), or
[Plane](../../woostack-init/references/artifact-providers/plane.md) profile:

- prove the selected profile's official capability (MCP for Linear or Plane; host-authenticated gh for GitHub) and exact scope;
- resolve the exact supplied project or create one only when requested;
- write the approved goal, architecture, scope, decisions, and repository/base intent;
- use the profile's stable operation identity;
- preserve unrelated human content; and
- independently read the exact resource, labels, identity, scope, and content back.

Missing, partial, ambiguous, or unknown artifact outcomes block that requested synchronization only
unless persistence was explicitly part of the deliverable. Without artifact mode make no provider
call. Never create a provider document or increment issue/work-item during bootstrap. Zero provider
operations occur before collision admission. Artifact metadata, native status, provider response,
remembered approval, or target-path availability cannot substitute for design approval.

## Scaffold the approved architecture

After any provider synchronization and immediately before scaffold creation, re-run the exact
no-follow collision check; a changed result blocks before any target write. Create only the approved
surfaces using [architecture.md](architecture.md), [frameworks.md](frameworks.md),
[infrastructure.md](infrastructure.md), and [patterns.md](patterns.md).

The default shape is:

```text
apps/ or products/       deployable surfaces and their app-local code
packages/                code shared by multiple apps; omit when unused
```

Exact app directories follow the selected ecosystem. All new code starts in its owning app.
Extract the smallest coherent shared package only after multiple apps need the same implementation
or contract. Do not create empty layers, placeholder packages, example features, speculative
abstractions, or duplicate tooling.

For each approved surface:

1. resolve every exact dependency version live from the authoritative registry;
2. initialize the smallest supported scaffold;
3. remove demo/example code not part of the approved product;
4. establish each app's native structure and only the shared packages the approved surfaces need;
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

Do not commit or push until generated files, environment files, lockfiles, ignore rules, and code
ownership are classified under repository policy.

## README handoff

Write the project README only after the scaffold works. Include:

- product purpose and approved surfaces;
- architecture and app-local/shared-code placement decisions;
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
output, stray examples, premature or duplicated shared packages, unexpected files, missing
lockfiles, or dirty formatter output. A command that does not exist is not a passing check; fix the
scaffold or report the explicit gap.

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
