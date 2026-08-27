---
name: woostack-doctor
description: Diagnose and, after approval, repair a repo's `.woostack/` workspace health—static config checks, guarded legacy-record checks, and optional live Linear/Plane artifact connectivity. Remote content is never auto-repaired. Includes exit-coded CI mode and an interactive local repair gate.
---

# woostack-doctor

Diagnose — and, with your approval, repair — the health of a repo's `.woostack/` workspace.
This is the **workspace-integrity + convention** quadrant of woostack health:
`woostack-init` scaffolds missing structure, `woostack-status` reconciles the feature board, and
**`woostack-doctor` lints and repairs local policy and conventions**.

It has two layers:

- A **headless diagnose engine** (`scripts/doctor.sh`) — pure bash and exit-coded. Static diagnosis
  reads no credentials and calls no provider. For explicit live diagnosis it validates a
  normalized, non-secret receipt supplied by the skill controller through
  `--live-receipt <path>`; the script never calls MCP, HTTP, GraphQL, or a hard-coded provider tool.
- An **interactive repair layer** — proposes local auto-fixes, mutates nothing before approval,
  routes approved tracked repairs through [`woostack-change`](../woostack-change/SKILL.md) before
  any file mutation, and runs filesystem-only repairs directly. Remote provider resources and legacy
  development records are report-only; doctor never merges.

## Commands

- `/woostack-doctor [path]` — diagnose the workspace at `path` (default: current repo), then
  **offer** a gated repair changeset for the auto-fixable findings.
- `/woostack-doctor [path] --check` — **CI mode**: diagnose only. Prints GitHub-style annotations
  and sets the exit code (nonzero iff any `error`); suppresses the machine-readable findings dump.
  Mutates nothing.
- `/woostack-doctor [path] --live` — resolve the target and its effective layered policy first.
  When `artifacts.provider` is `"local"` or omitted, provider preflight is skipped.
  When `artifacts.provider: "linear"`, discover the host's official Linear MCP tools, authenticate,
  and verify Linear availability plus required project/update/issue/comment/relation/owner read and
  mutation capabilities (and label capabilities when `projectLabels` is configured), then verify
  the OAuth workspace slug, native team ID/key, native mappings, and independent read-back.
  When `artifacts.provider: "plane"`, discover the host's official Plane MCP tools, authenticate,
  and verify Plane availability plus required project/issue/relation/label read and mutation capabilities,
  then verify canonical instance `baseUrl`, workspace, exact configured project, native mappings, and independent read-back.
  Write only the normalized non-secret result to a mode-0600 temporary receipt, invoke
  `doctor.sh --live-receipt <path> [path]`, and delete the receipt. Missing MCP, authentication,
  capability, identity, mapping, or read-back blocks at its phase.
- `/woostack-doctor [path] --check --live` — the same controller-owned live preflight with
  CI-style annotations and exit behavior.

The engine depends on [`woostack-init`](../woostack-init/SKILL.md) being installed because it reads
the `templates/` shipped there; the woostack collection installs both as siblings.

## Procedure

1. **Capture the target.** Retain the requested path without statting, reading, canonicalizing, or
   invoking Git.
2. **Resolve effective policy first.** Resolve the target and primary checkout, then load the
   effective committed plus primary-checkout local policy to determine the selected `artifacts.provider`.
3. **Preflight the configured provider in live mode.** For explicit `--live`:
   - When `artifacts.provider: "linear"`, discover and authenticate official Linear MCP (`official-linear-mcp`).
     Verify Linear availability and required `projectRead`, `projectWrite`, `projectUpdateRead`,
     `projectUpdateWrite`, `issueRead`, `issueWrite`, `commentRead`, `commentWrite`, `relationRead`,
     `relationWrite`, `ownerRead`, `ownerWrite`, and `independentReadBack` capabilities (plus
     `projectLabelRead`/`projectLabelWrite` if `projectLabels` is configured). Verify the OAuth workspace slug,
     unique native team ID/key, native project status and issue state mappings, and independent read-back.
   - When `artifacts.provider: "plane"`, discover and authenticate official Plane MCP (`official-plane-mcp`).
     Verify Plane availability and required `projectRead`, `projectWrite`, `issueRead`, `issueWrite`,
     `relationRead`, `relationWrite`, `projectLabelRead`, `projectLabelWrite`, and `independentReadBack`
     capabilities. Verify canonical instance `baseUrl`, workspace, exact configured project, native issue-state
     mappings, and independent read-back.
   - When `artifacts.provider: "local"` or omitted, live provider preflight is skipped.
   Write the normalized non-secret mode-0600 receipt matching the resolved provider schema, and run
   `doctor.sh --live-receipt <path> [path]`. Otherwise run `doctor.sh [path]`. The engine validates policy,
   diagnostics, managed project OMP role-agent definitions, and local worktree hygiene. OMP diagnosis is
   read-only; only the approved, auto-fixable doctor path may invoke the init provisioner.
   Legacy `.woostack/specs/`, `.woostack/plans/`, `.woostack/fixes/`, or
   `.woostack/overnight/` sets produce one blocking migration finding per active or ambiguous set;
   doctor does not run normal lifecycle lint on them and points at the explicit
   [legacy migration procedure](../woostack-init/references/legacy-migration.md). Old local artifacts
   and existing provider resources are preserved; doctor never rewrites, reparents, or migrates
   remote Linear or Plane resources in place. Incompatible retained Plane runs block with precise
   regeneration guidance via `/woostack-build <goal>` or `/woostack-fix <prompt>` without mutation.
4. **No workspace?** If the engine exits 2 with "no `.woostack/`", **stop** and tell the user to
   run [`woostack-init`](../woostack-init/SKILL.md). Doctor never scaffolds.
5. **Propose a changeset.** Group the local `fixable=auto` findings into a proposed repair set —
   one line per repair: the `code`, the `path`, and exactly what will change. List `report`-only
   findings separately as "manual / judgment" items. Provider findings are always report-only.
6. **HARD GATE — approval.** Mutate nothing until the user approves. Silence is not a yes. The user
   may approve all, a subset, or none. `report`-only findings are never auto-applied.
7. **Route tracked repairs before mutation.** If the approved set includes a file repair, hand its
   exact finding codes, paths, changes, target, and validation mode to
   [`woostack-change`](../woostack-change/SKILL.md) before invoking any `--fix` path. That workflow
   records the approved bounded contract in the active run, establishes its isolated worktree,
   invokes each owning check as `<check> --fix <WOO_ROOT> <extra-args...>` (see
   [references/checks.md](references/checks.md)), re-runs the same engine mode, and commits through
   its repository-first delivery path. Doctor never hands tracked repairs directly to
   `woostack-commit`. If every approved repair is filesystem-only, run `orphan-worktree --fix` (a
   safe `git worktree prune`) directly after the gate; it needs no issue or commit. No repair shell
   command calls a provider or mutates remote content.
8. **Confirm.** Require the change workflow's retained re-run result for tracked repairs, or re-run
   the same static or explicitly live engine mode after a filesystem-only repair, and report
   residual findings.

## Hard constraints

- **Never scaffold.** Absent `.woostack/` → point at `woostack-init`; never create the workspace.
- **Never reconcile the board** (that is `woostack-status`). Doctor repairs static config/workspace
  drift and reports judgment-only signals; it never computes or writes lifecycle state.
- **Artifacts are optional.** Static diagnosis validates non-secret policy. Local legacy
  development-record directories are migration blockers, not a backend and not normal lint input.
  Doctor preserves old local and remote artifacts; it never creates, repairs, adopts, rewrites, reparents,
  or deletes them. Incompatible retained Plane runs fail closed with regeneration guidance.
- **Provider access belongs to skill controllers.** Diagnosis and every doctor shell repair remain
  provider-free. Approved tracked repairs run through artifact-free `woostack-change` unless the
  caller explicitly selected an exact artifact. Explicit `--live` may validate official
  host MCP connectivity for optional artifact use and passes only a normalized non-secret receipt
  to the shell engine. The temporary receipt is mode 0600 and deleted after consumption. The shell
  never reads a provider credential or invokes HTTP, GraphQL, an API-key adapter, or a hard-coded
  MCP tool name. Unknown or partial provider outcomes block optional artifact operations only.
- **Gate every repair.** Nothing mutates before explicit approval; `report` findings are never
  auto-applied.
- **Safety is never relaxed.** The only filesystem repair is `git worktree prune` (admin-only);
  a present worktree dir that may hold work is always `report`, never auto-removed.
- **Never merge.** Approved file repairs enter `woostack-change` before mutation; doctor never
  invokes `woostack-commit` directly.
- **Cross-link, don't restate.** Repository-derived board rules live in
  [`../woostack-status/references/conventions.md`](../woostack-status/references/conventions.md).


Wall time: 0.20 seconds