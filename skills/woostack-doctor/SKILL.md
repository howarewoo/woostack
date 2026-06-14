---
name: woostack-doctor
description: Use to diagnose and (gated) repair a repo's .woostack/ workspace health — a run-anytime check of store integrity and conventions (memory wikilinks/provenance/dead notes, spec/plan/fix templates + the status enum, the spec↔plan Obsidian backlink, orphan worktrees, .gitignore drift, config.json keys), with a headless exit-coded diagnose mode for CI (--check) and an interactive propose→approve→apply→woostack-commit repair flow. Use for /woostack-doctor, "check my .woostack", "repair the workspace", or "is my woostack install healthy". Never scaffolds (that's woostack-init), never reconciles the board (woostack-status), never curates memory content (woostack-dream), and never merges.
---

# woostack-doctor

Diagnose — and, with your approval, repair — the health of a repo's `.woostack/` workspace.
This is the 17th public command and the **store-integrity + convention** quadrant of woostack
health: `woostack-init` scaffolds (creates missing structure), `woostack-status` reconciles the
feature board, `woostack-dream` curates memory *content*, and **`woostack-doctor` lints and repairs
existing content and conventions**.

It has two layers:

- A **headless diagnose engine** (`scripts/doctor.sh`) — pure bash, **exit-coded** (0 = no errors,
  nonzero = at least one `error` finding). Drop it into consumer CI with `--check`.
- An **interactive repair layer** (this skill's procedure) — proposes a changeset for the
  auto-fixable findings, mutates **nothing** before you approve, applies the approved repairs, and
  hands file changes to [`woostack-commit`](../woostack-commit/SKILL.md). It **never merges**.

## Commands

- `/woostack-doctor [path]` — diagnose the workspace at `path` (default: current repo), then
  **offer** a gated repair changeset for the auto-fixable findings.
- `/woostack-doctor [path] --check` — **CI mode**: diagnose only. Prints GitHub-style annotations
  and sets the exit code (nonzero iff any `error`); suppresses the machine-readable findings dump.
  Mutates nothing.

The engine depends on [`woostack-init`](../woostack-init/SKILL.md) being installed (it sources the
shared libs and reads the `templates/` it ships); the woostack collection installs both as
siblings, so this holds by construction.

## Procedure

1. **Diagnose.** Run `bash <doctor>/scripts/doctor.sh [path]`. Read the machine-readable findings
   on stdout — one per line, `severity⇥code⇥fixable⇥path⇥message`. Severity is `error`
   (structural breakage — fails CI) or `warn` (hygiene/convention). `fixable` is `auto`
   (the owning check ships a `--fix`) or `report` (judgment — surfaced, never auto-applied). The
   full catalog is in [references/checks.md](references/checks.md).
2. **No workspace?** If the engine exits 2 with "no `.woostack/`", **stop** and tell the user to
   run [`woostack-init`](../woostack-init/SKILL.md). Doctor never scaffolds.
3. **Propose a changeset.** Group the `fixable=auto` findings into a proposed repair set — one line
   per repair: the `code`, the `path`, and exactly what will change. List the `report`-only
   findings separately as "manual / judgment" items. Present both.
4. **HARD GATE — approval.** Mutate nothing until the user approves. Silence is not a yes. The user
   may approve all, a subset, or none. `report`-only findings are never auto-applied.
5. **Apply.** For each approved finding, invoke the owning check's `--fix` path with the uniform
   convention `<check> --fix <WOO_ROOT> <extra-args...>` (see [references/checks.md](references/checks.md)
   for each check's args). File repairs mutate the working tree; the filesystem-only repair
   (`orphan-worktree --fix`, a safe `git worktree prune`) runs directly.
6. **Commit.** After file repairs, hand to [`woostack-commit`](../woostack-commit/SKILL.md) — it
   creates a fresh `feature/*` branch and opens a PR (respects branch protection; **never merges**).
   Filesystem-only repairs need no commit.
7. **Confirm.** Re-run the engine and report any residual findings.

## Hard constraints

- **Never scaffold.** Absent `.woostack/` → point at `woostack-init`; never create the workspace.
- **Never reconcile the board** (that is `woostack-status`) and **never curate memory content**
  (that is `woostack-dream`). Doctor repairs **static, authoring-time** doc drift — `type:`, the
  `status:` enum (normalizing exact-match aliases), and the plan→spec `**Source:**` join — and
  **reports** judgment-only signals (dead notes, wrong-band status); it never auto-prunes knowledge.
  It **never computes or writes the git/PR-derived execute→done band**; that stays
  `woostack-status`'s read-only computed truth.
- **Gate every repair.** Nothing mutates before explicit approval; `report` findings are never
  auto-applied.
- **Safety is never relaxed.** The only filesystem repair is `git worktree prune` (admin-only);
  a present worktree dir that may hold work is always `report`, never auto-removed.
- **Never merge.** Approved file repairs land via `woostack-commit` (branch + PR), never a merge.
- **Cross-link, don't restate.** The spec↔plan join contract lives in
  [`../woostack-status/references/conventions.md`](../woostack-status/references/conventions.md);
  link it.
