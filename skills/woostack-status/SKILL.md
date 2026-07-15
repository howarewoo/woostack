---
name: woostack-status
description: Use to show the backend-aware woostack feature board — Markdown specs/fixes remain read-only, while Linear-backed runs authenticate and reconcile only verified merge-backed terminal issue/project transitions before rendering phase, progress, PR state, owner, age, next action, and drift. Use for /woostack-status, "what's in flight", or "what should I do next".
---

# woostack-status

## Overview

Prints an on-demand **feature board** from the configured spec/plan artifact backend. The
default Markdown backend remains read-only and derives every spec in `.woostack/specs/` plus
every self-contained fix in `.woostack/fixes/`. The Linear backend reads managed projects,
their spec documents, and ordered increment issues through the normalized artifact adapter.
Both render the reconciled phase, plan progress, increment-PR rollup, owner, age, and one
concrete **next action**.

The board is computed fresh each run, printed to the terminal, and rendered to a local HTML
board. Markdown mode never fetches unless asked, commits, pushes, or mutates artifacts.
Linear mode always authenticates, verifies exact PR attribution and merged state, previews
each eligible terminal write, applies only `inReview → done`, verifies read-back, and moves
the project to `done` only after every managed issue is observed `done`. It never reopens,
downgrades, or writes a non-terminal state.

Markdown's `spec : plan : PRs = 1 : 1 : N` invariant and the canonical phase enum live in
[references/conventions.md](references/conventions.md). Fixes bypass the Markdown spec-to-plan
join because the file acts as both spec and plan. Linear uses the backend's normalized
project/document/issues model. This skill does not duplicate either backend contract.

## Commands

- `/woostack-status` — render the in-flight feature board for the current project.
- `/woostack-status --all` — also expand the `done` and `abandoned` features (hidden by
  default, surfaced as a footer count).
- `/woostack-status --fetch` — in Markdown mode, opt in to a `git fetch` first so PR-less
  branch data is fresh. Linear mode already performs authenticated API reads and ignores this
  freshness hint after the fetch.
- `/woostack-status --no-open` — write the HTML board but do not open a browser (also
  suppressed by `WOO_STATUS_NO_OPEN=1` or a `CI`/`GITHUB_ACTIONS` environment).

## Procedure

1. **Run the deriver.** From the project root, resolve the installed skill directory, then
   run the bundled script from that directory so it reads the project's `./.woostack`:

   ```
   WOO_STATUS_ACTION_PATH="<directory containing this SKILL.md>"
   bash "$WOO_STATUS_ACTION_PATH/scripts/status.sh" [--all] [--fetch] [--no-open]
   ```

   Keep the current working directory at the consumer project root; only the script path comes
   from the skill bundle. `WOO_DIR` defaults to `./.woostack` (override only for tests). The
   script resolves the backend before enumeration. Markdown drift flags still exit `0`;
   operational failures exit non-zero. Linear additionally requires `LINEAR_API_KEY`, a
   successful schema/auth preflight, normalized-model discovery before GitHub parsing,
   unambiguous exact `Linear-Project` and `Linear-Issue` trailers for every referenced PR in
   the complete paginated result, verified merge state, an unchanged pre-write project/issue
   snapshot, successful mutations, and matching read-back. Malformed historical trailers on
   PRs not referenced by a managed increment are ignored.
   Any missing credential, ambiguity, API failure, partial receipt, or mismatch exits non-zero
   without rendering stale success.

   Alongside the terminal table the script writes a self-contained HTML render of the same
   board to the gitignored `.woostack/visuals/status-board.html` and opens it in the default
   browser (suppressed in CI or via `--no-open`); the terminal output remains the canonical
   narration and Linear write-preview surface.

2. **Narrate the board.** Present the table as printed, then for each in-flight feature call
   out its single **next action** (the `NEXT` column). Lead with whatever is actionable now.

3. **Surface the flags.** If the `! FLAGS` block is non-empty, list each drift and what
   resolves it — for example a second plan resolving to one spec, a blank or `unknown`
   `branch:`, an unknown `status:` value, a head-state phase while a PR already exists, a
   stale executing spec, or a same-branch collision. Flags are advisory, never a blocking
   stop.

4. **List open deferrals (read-only).** Scan the working tree for deferral markers —
   `grep -rn 'woostack-defer(' . | grep -v '/.git/'` (or a ripgrep equivalent) — and print each as
   an open deferral: `<file>:<line> — deferred to <ref>`. These are the `woostack-defer(<ref>)`
   markers `woostack-execute` writes for work a later increment completes (issue #224); a marker
   still present after its increment landed is a **stale deferral** worth resolving. This is
   read-only **surfacing** — never edit or remove a marker. Omit the section entirely when the scan
   finds none. (A consumer repo carries the token only at real deferral sites. The woostack repo
   itself also has illustrative `woostack-defer(...)` in `skills/**` / `.woostack/` docs; exclude
   those doc paths if the example noise distracts.)

5. **Note backend-specific degradation.** Markdown mode keeps rendering if `gh` is absent or
   unauthenticated, omitting PR / increment / owner data for PR-phase rows and printing the
   existing notice. Linear cannot safely reconcile terminal state without authenticated Linear
   access and verified GitHub PR evidence, so it fails closed instead of degrading.

## Hard constraints

- **Markdown is read-only.** It never fetches (except explicit `--fetch`), commits, pushes,
  or mutates a spec, plan, fix, or git state.
- **Linear writes only the terminal merge reconciliation.** Authenticate before reading.
  Preview exact eligible issue identities and the project transition, pin the complete
  project/issue status snapshot immediately before writing, permit only merge-backed
  `inReview → done`, and read back target and non-target issue states. Move the project only
  after every managed issue is done; if an earlier issue mutation succeeded despite an unknown
  response, a later run resumes with only the project transition. Never reopen, downgrade,
  abandon, or write any non-terminal state.
- **Fail closed in Linear mode.** Missing credentials, ambiguous/mismatched trailers, foreign
  evidence, API/GraphQL failure, partial receipts, or read-back mismatch are operational
  failures. Do not render them as successful reconciliation.
- **No committed status file.** Print to the terminal; never write `STATUS.md` or any
  *tracked* snapshot. The gitignored `.woostack/visuals/status-board.html` render is the
  sanctioned exception — it is presentation, never source of truth.
- **The configured artifacts are the source of truth.** Consume both backends through their
  normalized adapters. Preserve Markdown's derived execute/review/done truth table and render
  Linear's verified post-reconciliation model. The canonical contracts live in
  [references/conventions.md](references/conventions.md).
- **Markdown degradation stays compatible.** No specs, missing plans, malformed rows, or
  unavailable `gh` retain their friendly notice/flag behavior and clean exit.
