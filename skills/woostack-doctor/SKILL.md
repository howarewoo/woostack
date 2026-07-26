---
name: woostack-doctor
description: Use to diagnose and (gated) repair a repo's `.woostack/` workspace health — static knowledge/config checks, legacy-development-record migration blockers, and explicit host-verified Linear MCP capability receipts. Remote content is never auto-repaired. Includes exit-coded CI mode and an interactive local repair gate.
---

# woostack-doctor

Diagnose — and, with your approval, repair — the health of a repo's `.woostack/` workspace.
This is the 17th public command and the **store-integrity + convention** quadrant of woostack
health: `woostack-init` scaffolds (creates missing structure), `woostack-status` reconciles the
feature board, `woostack-dream` curates memory *content*, and **`woostack-doctor` lints and repairs
existing content and conventions**.

It has two layers:

- A **headless diagnose engine** (`scripts/doctor.sh`) — pure bash and exit-coded. Static diagnosis
  reads no credentials and calls no provider. For explicit live diagnosis it validates a
  normalized, non-secret receipt supplied by the skill controller through
  `--live-receipt <path>`; the script never calls MCP, HTTP, GraphQL, or a hard-coded provider tool.
- An **interactive repair layer** — proposes local auto-fixes, mutates nothing before approval,
  routes approved tracked repairs through [`woostack-change`](../woostack-change/SKILL.md) before
  any file mutation, and runs filesystem-only repairs directly. Linear resources and legacy
  development records are report-only; doctor never merges.

## Commands

- `/woostack-doctor [path]` — diagnose the workspace at `path` (default: current repo), then
  **offer** a gated repair changeset for the auto-fixable findings.
- `/woostack-doctor [path] --check` — **CI mode**: diagnose only. Prints GitHub-style annotations
  and sets the exit code (nonzero iff any `error`); suppresses the machine-readable findings dump.
  Mutates nothing.
- `/woostack-doctor [path] --live` — before touching the target, discover the host's official
  Linear MCP tools, authenticate through the host connection, and verify provider availability
  plus required read/mutation capabilities. Then resolve the target and its effective layered
  policy, verify workspace/team, native mappings, and independent read-back, write only the
  normalized non-secret result to a mode-0600 temporary receipt, invoke
  `doctor.sh --live-receipt <path> [path]`, and delete the receipt. Missing MCP, authentication,
  capability, identity, mapping, or read-back blocks at its phase; provider-only failures occur
  before target filesystem or Git access.
- `/woostack-doctor [path] --check --live` — the same controller-owned live preflight with
  CI-style annotations and exit behavior.

The engine depends on [`woostack-init`](../woostack-init/SKILL.md) being installed (it sources the
shared libs and reads the `templates/` it ships); the woostack collection installs both as
siblings, so this holds by construction.

## Procedure

1. **Capture the target.** Retain the requested path without statting, reading, canonicalizing, or
   invoking Git.
2. **Preflight the provider first in live mode.** For explicit `--live`, discover and authenticate
   official host MCP before target access. Verify provider availability and required
   project/update/issue/comment/relation/owner read and mutation capabilities. A provider-only
   failure stops with zero target filesystem or Git access.
3. **Resolve policy and diagnose once.** Resolve the target and primary checkout, then load the
   effective committed plus primary-checkout local team policy. In live mode, verify the configured
   workspace/team, native mappings, and independent read-back, write the normalized non-secret
   mode-0600 receipt, and run `doctor.sh --live-receipt <path> [path]`. Otherwise run
   `doctor.sh [path]`. The engine validates policy, knowledge stores, diagnostics, and local
   worktree hygiene.

   <!-- woostack-legacy-compatibility reader="woostack-doctor" operation="inspect" paths=".woostack/specs/|.woostack/plans/|.woostack/fixes/|.woostack/overnight/" purpose="migration-classification-only" lifecycle-use="prohibited" -->
   Inspect `.woostack/specs/`, `.woostack/plans/`, `.woostack/fixes/`, and
   `.woostack/overnight/` for migration classification only. Never use them for normal, routine,
   or day-to-day lifecycle work.
   <!-- /woostack-legacy-compatibility -->

   Report one blocking migration finding per active or ambiguous legacy set. Never adopt a legacy
   set as normal lifecycle input. Point at the explicit
   [migration procedure](../woostack-init/references/migration.md).
4. **No workspace?** If the engine exits 2 with "no `.woostack/`", **stop** and tell the user to
   run [`woostack-init`](../woostack-init/SKILL.md). Doctor never scaffolds.
5. **Propose a changeset.** Group the local `fixable=auto` findings into a proposed repair set —
   one line per repair: the `code`, the `path`, and exactly what will change. List `report`-only
   findings separately as "manual / judgment" items. Linear findings are always report-only.
6. **HARD GATE — approval.** Mutate nothing until the user approves. Silence is not a yes. The user
   may approve all, a subset, or none. `report`-only findings are never auto-applied.
7. **Route tracked repairs before mutation.** If the approved set includes a file repair, hand its
   exact finding codes, paths, changes, target, and validation mode to
   [`woostack-change`](../woostack-change/SKILL.md) before invoking any `--fix` path. That workflow
   binds or creates the standalone issue, records the approved bounded contract, establishes its
   worktree, invokes each owning check as `<check> --fix <WOO_ROOT> <extra-args...>` (see
   [references/checks.md](references/checks.md)), re-runs the same engine mode, and commits through
   the verified issue. Doctor never hands tracked repairs directly to `woostack-commit`. If every
   approved repair is filesystem-only, run `orphan-worktree --fix` (a safe `git worktree prune`)
   directly after the gate; it needs no issue or commit. No repair shell command calls Linear or
   mutates remote content.
8. **Confirm.** Require the change workflow's retained re-run result for tracked repairs, or re-run
   the same static or explicitly live engine mode after a filesystem-only repair, and report
   residual findings.

## Hard constraints

- **Never scaffold.** Absent `.woostack/` → point at `woostack-init`; never create the workspace.
- **Never reconcile the board** (that is `woostack-status`) and **never curate memory content**
  (that is `woostack-dream`). Doctor repairs static knowledge/config drift and reports judgment-only
  signals; it never computes or writes lifecycle state.
- **Linear is the only development authority.** Static diagnosis validates non-secret policy.
  Local development-record directories are migration blockers, not a backend and not normal lint
  input. Doctor never creates, repairs, adopts, or deletes them.
- **Provider access belongs to skill controllers.** Diagnosis and every doctor shell repair remain
  provider-free. For approved tracked repairs, `woostack-change` owns official Linear MCP access,
  issue identity, and mutation receipts before the first file edit. Explicit `--live` discovers
  official host MCP tools, performs authenticated read/write/update/comment/relation/owner/read-back
  preflight, and passes only a normalized non-secret receipt to the shell engine. The temporary
  receipt is mode 0600 and deleted after consumption. The shell never reads a provider credential
  or invokes HTTP, GraphQL, an API-key adapter, or a hard-coded MCP tool name. Unknown or partial
  outcomes fail closed.
- **Gate every repair.** Nothing mutates before explicit approval; `report` findings are never
  auto-applied.
- **Safety is never relaxed.** The only filesystem repair is `git worktree prune` (admin-only);
  a present worktree dir that may hold work is always `report`, never auto-removed.
- **Never merge.** Approved file repairs enter `woostack-change` before mutation and commit through
  that workflow's verified standalone issue; doctor never invokes `woostack-commit` directly.
- **Cross-link, don't restate.** The spec↔plan join contract lives in
  [`../woostack-status/references/conventions.md`](../woostack-status/references/conventions.md);
  link it.
