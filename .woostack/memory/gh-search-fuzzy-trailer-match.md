---
name: gh-search-fuzzy-trailer-match
type: gotcha
scope: skills/woostack-status/scripts/**
tags: gh, search, prs, matching
hook: `gh pr list --search` tokenizes paths and cross-matches; exact-match the trailer in the PR body.
updated: 2026-06-04
source: .woostack/plans/2026-06-04-woostack-status.md
recall_count: 15
last_recalled: 2026-06-05
---
`gh pr list --search "Spec: <path>"` is fuzzy full-text search: it tokenizes the path (on
`/`, `-`, `.`), so a query for one spec matches PRs trailered for look-alike specs that share
`woostack`/`specs`/date tokens. For a precise PR↔spec join, use the search only to narrow
candidates, then exact-match the trailer substring (`specs/<basename>`) against each PR
`body` in jq. The basename is date-stamped and unique, and the match is WOO_DIR-independent.
Same gotcha applies to any identifier lookup via `gh --search`.
See [[woostack-feature-state-invariant]].
