---
name: woostack-status
description: Use to show the derived woostack feature board — for every spec in .woostack/, its reconciled phase, plan progress, increment-PR state, owner, age, and the single next action, plus flags for any drift between the authored status: and the artifacts on disk. Read-only; never fetches, commits, or pushes. Use for /woostack-status, "what's in flight", or "what should I do next".
---

# woostack-status

## Overview

Prints an on-demand, read-only **feature board** derived from the real `.woostack/`
artifacts. For every spec it shows the reconciled phase, plan progress (`N/M` boxes), the
increment-PR rollup, owner, age, and the single concrete **next action** — and flags any
drift between the authored `status:` and what the artifacts actually say.

The board is computed fresh each run and printed to the terminal; it is **never** written to
a tracked file (no `STATUS.md`, no snapshot — that would churn and merge-conflict every time
anyone advances a feature). It never fetches, commits, or pushes.

The board is backed by the `spec : plan : PRs = 1 : 1 : N` invariant and the phase enum, both
defined once in [references/conventions.md](references/conventions.md). This skill does not
restate them — that file is the canonical home for the phase vocabulary, the join contracts
(`**Source:**` plan line, `Spec:` PR trailer, `branch:`), and the reconcile rules.

## Commands

- `/woostack-status` — render the in-flight feature board for the current project.
- `/woostack-status --all` — also expand the `done` and `abandoned` features (hidden by
  default, surfaced as a footer count).
- `/woostack-status --fetch` — opt in to a `git fetch` first so PR-less branch data is fresh.
  This is the only network access the board ever does; it still never commits or pushes.

## Procedure

1. **Run the deriver.** From the project root, resolve the installed skill directory, then
   run the bundled script from that directory so it reads the project's `./.woostack`:

   ```
   WOO_STATUS_ACTION_PATH="<directory containing this SKILL.md>"
   bash "$WOO_STATUS_ACTION_PATH/scripts/status.sh" [--all] [--fetch]
   ```

   Keep the current working directory at the consumer project root; only the script path comes
   from the skill bundle. `WOO_DIR` defaults to `./.woostack` (override only for tests). The
   script is read-only and exits `0` even when it emits drift flags — operational failure is
   the only non-zero exit — so it is safe to run anywhere, including CI.

2. **Narrate the board.** Present the table as printed, then for each in-flight feature call
   out its single **next action** (the `NEXT` column). Lead with whatever is actionable now.

3. **Surface the flags.** If the `! FLAGS` block is non-empty, list each drift and what
   resolves it — for example a second plan resolving to one spec, a blank or `unknown`
   `branch:`, an unknown `status:` value, a head-state phase while a PR already exists, a
   stale executing spec, or a same-branch collision. Flags are advisory, never a blocking
   stop.

4. **Note degradation.** If `gh` is absent or unauthenticated the board still renders,
   omitting PR / increment / owner data for PR-phase rows; relay the script's notice rather
   than hiding it. The footer also notes when PR-less branch data may be stale (pass
   `--fetch`).

## Hard constraints

- **Read-only.** Never fetches (except the explicit `--fetch`), commits, pushes, or mutates
  any spec, plan, or git state. The board only reads.
- **No committed status file.** Print to the terminal; never write `STATUS.md` or any tracked
  snapshot.
- **The artifacts are the source of truth.** Display the authored `status:` for head states
  but the *computed* phase for the execute → review → done band; a disagreement is a flag, not
  displayed truth. The contracts live in
  [references/conventions.md](references/conventions.md) — link it, do not restate it.
- **Degrade, never hard-fail.** Missing `gh`, no specs, malformed frontmatter, or a missing
  plan each produce a friendly notice or a flag and a clean exit, never a crash.
