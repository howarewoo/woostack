---
name: review-incremental-three-dot-off-pr
type: gotcha
scope: skills/woostack-review/scripts/**
tags: prefetch, incremental, marker, rebase, ancestor, three-dot, compare, 422, github-api, skills-repo
hook: a rebased branch makes the incremental marker a non-ancestor of HEAD, so the three-dot compare returns HTTP 200 with the rebased-over (off-PR) commits — NOT a 404 — and the 404-only fallback misses it; intersect the incremental diff against meta.json .files before it reaches workers/posting, or off-PR paths 422 at POST .../reviews.
updated: 2026-06-15
source: [[fixes/2026-06-15-review-rebase-stale-marker]]
---
`prefetch.sh` builds an incremental diff as `gh api compare/${LAST_SHA}...${HEAD_SHA}`
— a **three-dot** range, which diffs from the *merge-base* of the two SHAs, not from
`LAST_SHA` directly. When the branch was **rebased**, the prior-run marker
`LAST_SHA` is still reachable on GitHub (unreachable commits linger for months) but
is **no longer an ancestor of HEAD**. Its merge-base with the new HEAD is the
pre-rebase base tip, so the compare returns every commit the branch was rebased
*over* — files that are **not in the PR**. Those sections land in `diff.txt`, angle
workers review them, and `POST .../reviews` 422s `Path could not be resolved` on the
off-PR paths.

**Why the existing fallback missed it:** the full-diff fallback fired only when the
compare API returned non-zero (HTTP **404** — `LAST_SHA` fully expired). A
non-ancestor-but-still-reachable SHA returns **HTTP 200** with a bloated divergence
diff, so the 404-only guard never tripped. The trap, reusable: **reachability ≠
ancestry**, and a three-dot compare silently widens to the merge-base. A 404-only (or
"call succeeded → trust it") fallback does not protect a marker/range API against a
rewritten history.

**Fix shape (this repo):** after the incremental `diff.txt` is built and before the
byte/cap/ignore stages, intersect it against the authoritative PR file set
(`meta.json .files[].path`, key `.path`; diff headers carry the new path as
`b/<path>`) and drop any `diff --git` section whose `b/`-path is not in the PR. Reuse
the diff-cap section splitter (`HEADER = ^diff --git a/(.+?) b/(.+?)$`, `group(2)`).
Make it a **no-op** when the diff is the full-diff path (already PR-scoped via
`gh pr diff`) and when `meta.json` is missing/unparseable/has no file list — never
narrower than today; a meta you cannot read must keep the whole diff, not drop it.

Considered and **deferred**: a `git merge-base --is-ancestor` guard + a CI
`fetch-depth: 0` bump. `prefetch.sh` is otherwise git-API-pure and the reusable-review
checkout is shallow (`actions/checkout` default depth 1), so a local-git ancestry
guard no-ops in CI — exactly where the bug bites. The file-set intersection needs no
local objects and fixes CI and local alike; the ancestor guard is only worth adding
*with* the depth bump.

Sibling marker concern: [[review-marker-trust-asymmetry]] (who may author/trust the
marker). The off-PR-path-resolution family also surfaces in final findings, not just
prefetch — see issue #375 (`merge-findings.sh` re-resolution), out of scope here.
