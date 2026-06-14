---
name: status-ready-phase-pr-not-drift
type: gotcha
scope: skills/woostack-status/scripts/**
tags: status, drift, ready, lag-flag, phase-enum
hook: The lag-flag head-state list must EXCLUDE any phase where a PR is legitimately expected (ready opens the spec+plan PR) — and mkplan defaults the plan to `planning`, so a "ready" test that omits the status arg never tests ready.
updated: 2026-06-14
source: .woostack/fixes/2026-06-14-status-ready-pr-drift.md
---
`/woostack-status` raises a "status lags" drift when an authored head-state
`phase` coexists with a discovered PR (`prcount > 0`). The head-state `case` in
`status.sh` must list only **pre-PR** phases (`draft`/`hardened`/`approved`/
`planning`). `ready` is NOT pre-PR: per
[[woostack-feature-state-invariant]] / conventions.md, the spec+plan handoff PR
is opened *at* `ready`, so a PR there is expected, not drift. Including `ready`
contradicts its own `next_action` ("open spec+plan PR, then execute"). Rule when
adding a plan phase (see [[woostack-add-phase-enum-value]] wiring sites): if the
phase legitimately has an open PR, keep it out of the lag `case`.

Test pitfall that hid this: the status tests' `mkplan` helper defaults the plan
`status:` to `planning` when the 6th arg is omitted. The board reads the **plan**
status once a plan resolves, so a test that sets the *spec* to `ready` but calls
`mkplan ... 0 5` (no status) actually exercises `planning`+PR — a "ready" test
that never touches `ready`. Author the plan at the phase under test:
`mkplan "$d" oscar <file> 0 5 ready feature/oscar`.
