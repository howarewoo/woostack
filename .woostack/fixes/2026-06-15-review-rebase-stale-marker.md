---
type: fix
status: approved
branch: fix/review-rebase-stale-marker
---

# Fix: Incremental review uses a stale marker on rebased branches → reviews out-of-PR files, POST 422s

Resolves [#374](https://github.com/howarewoo/woostack/issues/374).

## 1. Root Cause

When a PR branch is **rebased** (or otherwise rewritten) since the last
`woostack-review` run, the recorded incremental marker `$LAST_SHA` is still
reachable on GitHub (GitHub retains unreachable commits for months) but is **no
longer an ancestor of `HEAD`**. `prefetch.sh` computes the incremental diff with
a *three-dot* compare:

`skills/woostack-review/scripts/prefetch.sh:404`
```bash
elif COMPARE_JSON=$(gh api "repos/${GITHUB_REPOSITORY}/compare/${LAST_SHA}...${HEAD_SHA}" 2>/dev/null); then
```

Three-dot semantics (`base...head`) diff from the **merge-base** of the two
SHAs, not from a direct ancestor. After a rebase the merge-base of the old
`$LAST_SHA` and the new `$HEAD_SHA` is the pre-rebase base tip, so GitHub returns
every commit reachable from `HEAD` but not from that old merge-base — i.e. the
commits the branch was rebased *over*, which are **not part of this PR**. The
Python block at `prefetch.sh:413-429` writes one `diff --git` section per file in
that bloated compare response into `diff.txt`, sets
`INCREMENTAL_USED="$LAST_SHA"` (`:431`), and continues.

**Why the existing fallback misses it.** The only fallback to the full PR diff
fires when the compare API exits non-zero — i.e. HTTP 404, which happens only
when GitHub has *expired* `$LAST_SHA` (`prefetch.sh:433-435`, documented at
`:396`). A rebase that keeps `$LAST_SHA` reachable but makes it a non-ancestor
returns **HTTP 200** with the divergence diff, so the stale three-dot range is
accepted as-is.

**No PR-scope guard exists.** `meta.json` (written at `prefetch.sh:~322`)
carries the authoritative PR file set as `.files[].path` (key confirmed by the
existing full-diff counting at `prefetch.sh:457`, `jq -r '.files[].path'`). The
incremental path **never intersects** the compare-derived file list against
`meta.json .files`. The downstream `ignore[]` walk (`prefetch.sh:688-733`)
filters against user globs, not PR scope.

**Downstream → 422.** The off-PR sections in `diff.txt` flow to
`detect-angles.sh` (angle gating) and to the angle workers via the `_header.md`
prompt; workers emit findings with `file`/`line` from those off-PR paths. The
`resolve-diff-line.sh` safety net in `merge-findings.sh` resolves those lines
*within `diff.txt`* — and since the off-PR sections are physically present in
`diff.txt`, the net passes them. The posting stage then calls the PR reviews API
with paths that are not in the PR diff → **HTTP 422 `Path could not be
resolved`**.

Sibling issue [#375](https://github.com/howarewoo/woostack/issues/375) shares
the same family (`path`/`line` never re-validated against the postable PR diff)
but its fix lives in the **final-findings** re-resolution in `merge-findings.sh`,
not in `prefetch.sh`. This fix is scoped to **#374** (prefetch incremental
scope). The PR-file-set intersection here narrows the *diff surface* and so
reduces #375's blast radius, but does not close #375 on its own.

## 2. Proposed Fix

**Scope (hardened decision):** one change in
`skills/woostack-review/scripts/prefetch.sh` — the PR-file-set intersection. An
ancestor-guard variant and a CI `fetch-depth` bump were considered and
**deferred** (see §4); the intersection alone resolves the 422 in CI *and*
locally, keeps `prefetch.sh` git-API-pure (it adds no local-git dependency), and
is the maintainer's stated core fix.

### PR-file-set intersection

After the incremental block resolves and `last_sha.txt` is written
(`prefetch.sh:~445`), and **only when an incremental diff was actually used**
(`[ -n "$INCREMENTAL_USED" ]`), filter `diff.txt` in place to keep only the
`diff --git a/<x> b/<path>` sections whose `<path>` (the `b/`-side) is in
`meta.json .files[].path`. This runs **before** the
`DIFF_BYTES`/`CODE_FILES`/`LOC_CHANGED` counts (`prefetch.sh:447-455`), so every
downstream stage operates on the PR-scoped diff: the byte/file/LOC sizing
(`:447-455`), the section-aware diff cap (`:498-600`), and the `ignore[]` glob
filter (`:688-733`) all see only in-PR sections.

Reuse the **section-split already proven at `prefetch.sh:514-527`** (the diff-cap
ranker splits the diff into whole `diff --git` sections); the only new logic is
the membership test against the PR path set, mirroring the membership shape of
the ignore filter at `:688-733`. Implement as a `python3` heredoc (consistent
with both existing blocks) taking `diff.txt` + `meta.json`, rewriting `diff.txt`.

Key mapping (matches existing code at `:457` and `:711`): `meta.json` files use
key `.path`; the diff section header carries the new path as `b/<path>`. Keep a
section iff its `b/`-path ∈ the PR path set. Renames are handled correctly — the
`b/`-side is the new path, which is what `gh pr view --json files` reports.

Emit a one-line log when sections are dropped, mirroring the diff-cap log at
`:595` — e.g.
`prefetch: dropped N off-PR diff section(s) not in PR file set (rebased marker?)`.
This recovers the operational signal that a deferred ancestor-guard warning would
have given, at zero extra cost.

Degradation: if `meta.json` is missing or unparseable, the filter is a **no-op**
(no narrowing) — never worse than today. The full-diff path
(`INCREMENTAL_USED=""`) is never filtered: it is already PR-scoped by
construction (`gh pr diff`).

## 3. Implementation Plan

- [ ] **Step 1: Reproduce with a failing test.**
  - Add `skills/woostack-review/scripts/tests/test-prefetch-incremental-rebase.sh`
    (standalone `set -euo pipefail`, mirroring `test-prefetch-flat-memory.sh`:
    `git init` a tmp repo, `source` the `assert.sh` helper, run `prefetch.sh`
    under `WOO_REVIEW_TEST_MODE=1`).
  - Drive the incremental path via the existing test hooks (all confirmed
    present in `prefetch.sh`): set `WOO_REVIEW_FAKE_META_JSON` with
    `headRefOid` = a HEAD sha and `.files = [{"path":"src/app.sh","additions":5,"deletions":0}]`
    (in-PR file only); set `WOO_REVIEW_FAKE_PR_REVIEWS_JSON` to a trusted-author
    review whose body carries a prior-run marker whose sha **differs** from
    `headRefOid` (the marker comment syntax + trust gate live in
    `resolve-marker.sh` — copy the shape from `tests/test-resolve-marker.sh`);
    set `WOO_REVIEW_FAKE_INCREMENTAL_DIFF` to a unified diff with **two**
    `diff --git` sections — `b/src/app.sh` (in-PR) and `b/src/leaked.sh`
    (off-PR, the rebase leak).
  - Assert `diff.txt` **contains** a `b/src/app.sh` section and **does not
    contain** `b/src/leaked.sh`. This **fails today** — the fake-hook branch
    (`prefetch.sh:400-403`) writes the injected diff verbatim with no PR-scope
    filter — and passes after Step 2.

- [ ] **Step 2: Apply the PR-file-set intersection.**
  - Insert the gated `python3` diff filter after `prefetch.sh:445`
    (`last_sha.txt` write) and before `:447` (`DIFF_BYTES`), guarded by
    `[ -n "$INCREMENTAL_USED" ]`.
  - Split `diff.txt` into whole `diff --git` sections (reuse the splitter shape
    from `:514-527`); keep a section iff its `b/`-path ∈ the set
    `jq -r '.files[].path' meta.json`; rewrite `diff.txt` with the kept sections
    in original order. No-op when `meta.json` is absent/unparseable.
  - Emit the drop-count log line (mirror `:595`) when `N > 0`.
  - Run Step 1's test → green.

- [ ] **Step 3: Verification.**
  - Run the new test directly:
    `bash skills/woostack-review/scripts/tests/test-prefetch-incremental-rebase.sh`.
  - Re-run the existing prefetch/marker tests for no regression:
    `bash skills/woostack-review/scripts/tests/test-prefetch-flat-memory.sh`,
    `bash skills/woostack-review/scripts/tests/test-resolve-marker.sh`.
  - `bash -n skills/woostack-review/scripts/prefetch.sh` (syntax); run
    `shellcheck` on the script if available.

## 4. Deferred follow-up (out of scope for this fix)

Considered during hardening and intentionally **not** shipped here:

- **Ancestor guard in `prefetch.sh`** (`git merge-base --is-ancestor "$LAST_SHA"
  "$HEAD_SHA"` → `::warning::` + full-diff fallback). It is the "correct" upstream
  gate, but `prefetch.sh` is currently git-API-pure and this adds the first
  local-git dependency — and it **cannot fire in default CI**: the reusable review
  workflow's `actions/checkout` steps (`.github/workflows/reusable-review.yml:88,
  121, 209`) specify no `fetch-depth`, so the clone is shallow (depth 1) and the
  marker/head objects are absent. Without a paired `fetch-depth: 0` bump the guard
  is inert in the exact environment #374 was reported in.
- **`fetch-depth: 0` on the review checkout(s)**, which would make the guard
  usable in CI at the cost of a full-history clone on every review run.

The drop-count log line in §2 recovers the operational "a rebase happened" signal
without either of these. If the loud warning + early exit is wanted later, ship
both together as a separate change.

## Notes / Gotchas (distill candidates)

- **`gh pr view --json files` caps at 300 files.** For >300-file PRs `meta.json
  .files` is truncated and the intersection could over-drop sections beyond
  position 300. This is a pre-existing limitation of the full-diff counting path
  too, and the diff-cap machinery already truncates huge diffs — not a new
  regression, but worth a code comment at the filter.
- **Root-cause gotcha (the reusable lesson):** a *three-dot* GitHub compare with
  a non-ancestor base silently diffs from the merge-base, returning HTTP 200 with
  off-PR commits — it does **not** 404, so a 404-only fallback never catches a
  rebase. Reachability ≠ ancestry. Any incremental-diff marker result must be
  intersected against the authoritative PR file set (`meta.json .files`) before it
  reaches angle workers / the posting stage, or off-PR paths 422 at
  `POST .../reviews`.
