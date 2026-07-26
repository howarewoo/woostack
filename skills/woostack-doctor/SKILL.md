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
  and hands approved file changes to [`woostack-commit`](../woostack-commit/SKILL.md). Linear
  resources and legacy development records are report-only; doctor never merges.

## Commands

- `/woostack-doctor [path]` — diagnose the workspace at `path` (default: current repo), then
  **offer** a gated repair changeset for the auto-fixable findings.
- `/woostack-doctor [path] --check` — **CI mode**: diagnose only. Prints GitHub-style annotations
  and sets the exit code (nonzero iff any `error`); suppresses the machine-readable findings dump.
  Mutates nothing.
- `/woostack-doctor [path] --live` — after static checks, discover the host's official Linear MCP
  tools and authenticate through the host connection. Resolve the configured workspace/team,
  validate project/update/issue/comment/relation/owner/read-back capabilities and native mappings,
  independently read back the probe results, write only the normalized non-secret result to a
  mode-0600 temporary receipt, invoke `doctor.sh --live-receipt <path> [path]`, then delete the
  receipt. Missing MCP, authentication, identity, team, state mapping, mutation capability, or
  read-back is an `error` before artifact or Git access. Read-only MCP reports the exact missing
  mutation capabilities.
- `/woostack-doctor [path] --check --live` — the same controller-owned live preflight with
  CI-style annotations and exit behavior.

The engine depends on [`woostack-init`](../woostack-init/SKILL.md) being installed (it sources the
shared libs and reads the `templates/` it ships); the woostack collection installs both as
siblings, so this holds by construction.

## Procedure

1. **Diagnose statically.** Run `bash <doctor>/scripts/doctor.sh [path]`. This makes no provider
   call. It validates the non-secret Linear policy, knowledge stores, diagnostics, and local
   worktree hygiene. Legacy `.woostack/specs/`, `.woostack/plans/`, `.woostack/fixes/`, or
   `.woostack/overnight/` sets produce one blocking migration finding per active or ambiguous set;
   doctor does not run normal spec/plan lifecycle lint on them. Findings use
   `severity⇥code⇥fixable⇥path⇥message`; see [references/checks.md](references/checks.md).
2. **Optionally validate Linear live.** Only on explicit `--live`, the skill controller discovers
   host MCP capabilities and supplies `doctor.sh --live-receipt <path>` with a normalized,
   non-secret receipt. The script validates the receipt and never impersonates a provider call.
   Missing, partial, stale, foreign, ambiguous, read-only, or conflicting receipts are errors.
3. **No workspace?** If the engine exits 2 with "no `.woostack/`", **stop** and tell the user to
   run [`woostack-init`](../woostack-init/SKILL.md). Doctor never scaffolds.
4. **Propose a changeset.** Group the local `fixable=auto` findings into a proposed repair set —
   one line per repair: the `code`, the `path`, and exactly what will change. List `report`-only
   findings separately as "manual / judgment" items. Linear findings are always report-only.
5. **HARD GATE — approval.** Mutate nothing until the user approves. Silence is not a yes. The user
   may approve all, a subset, or none. `report`-only findings are never auto-applied.
6. **Apply locally.** For each approved local finding, invoke the owning check's `--fix` path with
   the uniform convention `<check> --fix <WOO_ROOT> <extra-args...>` (see
   [references/checks.md](references/checks.md) for each check's args). File repairs mutate the
   working tree; the filesystem-only repair (`orphan-worktree --fix`, a safe `git worktree prune`)
   runs directly. No repair command calls Linear or mutates remote content.
7. **Commit.** After file repairs, hand to [`woostack-commit`](../woostack-commit/SKILL.md) — it
   creates a fresh `feature/*` branch and opens a PR (respects branch protection; **never merges**).
   Filesystem-only repairs need no commit.
8. **Confirm.** Re-run the same static or explicitly live engine mode and report residual findings.

## Hard constraints

- **Never scaffold.** Absent `.woostack/` → point at `woostack-init`; never create the workspace.
- **Never reconcile the board** (that is `woostack-status`) and **never curate memory content**
  (that is `woostack-dream`). Doctor repairs static knowledge/config drift and reports judgment-only
  signals; it never computes or writes lifecycle state.
- **Linear is the only development authority.** Static diagnosis validates non-secret policy.
  Local development-record directories are migration blockers, not a backend and not normal lint
  input. Doctor never creates, repairs, adopts, or deletes them.
- **Provider access belongs to the skill controller.** Ordinary diagnosis and every repair path
  are provider-free. Explicit `--live` discovers official host MCP tools, performs authenticated
  read/write/update/comment/relation/owner/read-back preflight, and passes only a normalized
  non-secret receipt to the shell engine. The temporary receipt is mode 0600 and deleted after
  consumption. The shell never reads a provider credential or invokes HTTP, GraphQL, an API-key
  adapter, or a hard-coded MCP tool name. Unknown or partial outcomes fail closed.
- **Gate every repair.** Nothing mutates before explicit approval; `report` findings are never
  auto-applied.
- **Safety is never relaxed.** The only filesystem repair is `git worktree prune` (admin-only);
  a present worktree dir that may hold work is always `report`, never auto-removed.
- **Never merge.** Approved file repairs land via `woostack-commit` (branch + PR), never a merge.
- **Cross-link, don't restate.** The spec↔plan join contract lives in
  [`../woostack-status/references/conventions.md`](../woostack-status/references/conventions.md);
  link it.
