---
name: woostack-doctor
description: Use to diagnose and (gated) repair a repo's .woostack/ workspace health — backend-aware static store/config/convention checks, plus explicit authenticated Linear live validation; Markdown behavior stays unchanged, and remote content is never auto-repaired. Includes exit-coded CI mode and an interactive local repair gate. Never scaffolds, curates memory, reconciles the board, or merges.
---

# woostack-doctor

Diagnose — and, with your approval, repair — the health of a repo's `.woostack/` workspace.
This is the 17th public command and the **store-integrity + convention** quadrant of woostack
health: `woostack-init` scaffolds (creates missing structure), `woostack-status` reconciles the
feature board, `woostack-dream` curates memory *content*, and **`woostack-doctor` lints and repairs
existing content and conventions**.

It has two layers:

- A **headless diagnose engine** (`scripts/doctor.sh`) — pure bash and **exit-coded** (0 = no
  errors, nonzero = at least one `error` finding). Static diagnosis is credential-free. In Linear
  mode, `--live` explicitly opts into authenticated remote validation.
- An **interactive repair layer** (this skill's procedure) — proposes a changeset for local,
  auto-fixable findings, mutates **nothing** before approval, applies approved local repairs, and
  hands file changes to [`woostack-commit`](../woostack-commit/SKILL.md). It **never repairs Linear
  resources and never merges**.

## Commands

- `/woostack-doctor [path]` — diagnose the workspace at `path` (default: current repo), then
  **offer** a gated repair changeset for the auto-fixable findings.
- `/woostack-doctor [path] --check` — **CI mode**: diagnose only. Prints GitHub-style annotations
  and sets the exit code (nonzero iff any `error`); suppresses the machine-readable findings dump.
  Mutates nothing.
- `/woostack-doctor [path] --live` — run static checks, then (only when the configured artifact
  backend is Linear) require `LINEAR_API_KEY` and validate authenticated viewer identity/active
  state, workspace/team/resource visibility, status mappings, schema mutation capabilities, every
  managed repository feature and its resources, referenced provenance resource existence, managed
  ownership/metadata, and native relation agreement. Linear exposes no non-mutating introspection
  of a personal API key's effective write scope, so live doctor reports that limitation and does
  not claim to pre-prove future mutation authorization. Any auth, API, visibility, or drift failure
  is an `error`; live mode fails closed and never falls back to local specs/plans.
- `/woostack-doctor [path] --check --live` — the same explicit live validation with CI-style
  annotations and exit behavior.

The engine depends on [`woostack-init`](../woostack-init/SKILL.md) being installed (it sources the
shared libs and reads the `templates/` it ships); the woostack collection installs both as
siblings, so this holds by construction.

## Procedure

1. **Diagnose statically.** Run `bash <doctor>/scripts/doctor.sh [path]`. This reads no Linear
   credentials and makes no network request. It resolves `artifacts.specPlan`, validates backend
   config and Linear provenance URI shapes, and emits one machine-readable finding per line:
   `severity⇥code⇥fixable⇥path⇥message`. Severity is `error` (structural breakage — fails CI) or
   `warn` (hygiene/convention). `fixable` is `auto` (the owning local check ships a `--fix`) or
   `report` (judgment — surfaced, never auto-applied). The catalog is in
   [references/checks.md](references/checks.md).
2. **Optionally validate Linear live.** Only on an explicit `--live`, let the normalized adapter
   use `LINEAR_API_KEY`. Treat missing auth, schema/capability drift, missing or ambiguous mappings,
   inaccessible resources, foreign ownership, malformed managed metadata, and native
   relation/metadata disagreement as errors. Never retry by reading local spec/plan files.
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
  (that is `woostack-dream`). Doctor repairs **static, authoring-time** doc drift — `type:`, the
  `status:` enum (normalizing exact-match aliases), and the plan→spec `**Source:**` join — and
  **reports** judgment-only signals (dead notes, wrong-band status); it never auto-prunes knowledge.
  It **never computes or writes the git/PR-derived execute→done band**; that stays
  `woostack-status`'s read-only computed truth.
- **Backend boundaries are exact.** Markdown remains the default and keeps every existing
  filesystem check and repair. Linear mode validates selector/config/URI shapes statically, skips
  filesystem spec/plan type/status/source/backlink checks, and reports coexisting local specs/plans
  as inactive legacy artifacts. Backend-neutral fixes remain checked.
- **Remote validation is opt-in and read-only.** Ordinary diagnosis and every repair path are
  credential-free. `--live` alone may authenticate through the normalized adapter. The controller
  performs preflight exactly once before checks, exports a temporary non-secret receipt, and the
  config/resource and memory-provenance checks consume that shared result. Live mode fails closed
  on identity/active-access/API/schema/mapping/capability/resource/ownership/metadata/relation
  failure and never creates, updates, archives, deletes, or repairs a Linear resource. The API
  provides no non-mutating effective write-scope introspection for personal API keys, so doctor
  surfaces `linear-write-scope-unverifiable` rather than claiming future writes are authorized;
  actual adapter mutations remain fail-closed.
- **Gate every repair.** Nothing mutates before explicit approval; `report` findings are never
  auto-applied.
- **Safety is never relaxed.** The only filesystem repair is `git worktree prune` (admin-only);
  a present worktree dir that may hold work is always `report`, never auto-removed.
- **Never merge.** Approved file repairs land via `woostack-commit` (branch + PR), never a merge.
- **Cross-link, don't restate.** The spec↔plan join contract lives in
  [`../woostack-status/references/conventions.md`](../woostack-status/references/conventions.md);
  link it.
