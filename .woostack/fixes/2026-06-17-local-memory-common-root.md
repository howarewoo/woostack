---
type: fix
status: in-review
branch: fix/local-memory-common-root
---

# Fix: Worktree runs cannot see primary-only local memory and metrics

GitHub issue: https://github.com/howarewoo/woostack/issues/279

## 1. Root Cause

`woostack-review` and `woostack-address-comments` currently use one root variable,
`WOOSTACK_ROOT`, for every `.woostack/` path. That root is resolved by
`resolve-root.sh` as:

1. explicit `WOOSTACK_ROOT`
2. `GITHUB_WORKSPACE`
3. `git rev-parse --show-toplevel`
4. `pwd`

That fixed issue #272, where scripts run from a package subdirectory accidentally wrote
`<package>/.woostack`. But a secondary git worktree has its own valid git toplevel. When a
woostack command runs inside `.woostack/worktrees/<slug>`, `git rev-parse --show-toplevel`
therefore resolves to the secondary worktree, not the primary checkout.

Tracked files in `.woostack/` are present in the secondary worktree because they are part of the
branch. Local-only sidecars are not:

- `.woostack/metrics.json`
- `.woostack/memory/.telemetry.tsv`
- `.woostack/memory/.dream-watermark`
- any untracked local memory/wisdom files that exist only in the primary checkout

The affected script paths are:

- `skills/woostack-review/scripts/prefetch.sh` uses `$WOOSTACK_ROOT/.woostack` for memory recall
  and passes `$WOOSTACK_ROOT` to wisdom composition.
- `skills/woostack-review/scripts/memory-record.sh` writes scoped notes under
  `$WOOSTACK_ROOT/.woostack/memory`.
- `skills/woostack-review/scripts/metrics-fold.sh` folds local review metrics into
  `$WOOSTACK_ROOT/.woostack/metrics.json`.
- `skills/woostack-address-comments/scripts/prefetch.sh` recalls memory from
  `$WOOSTACK_ROOT/.woostack`.
- `skills/woostack-address-comments/scripts/memory-record.sh` writes scoped notes under
  `$WOOSTACK_ROOT/.woostack/memory`.

The worktree contract already documents the intended distinction: tracked work belongs in the
active worktree, while local-only metrics and memory sidecars live in the primary checkout. The
scripts do not expose that second root, so they cannot honor the contract.

## 2. Proposed Fix

Keep `WOOSTACK_ROOT` as the active checkout root for tracked files, config, OUTDIR hashing, and
normal worktree-local operations. Add a second exported root in both review and address-comments
root resolvers:

- `WOOSTACK_COMMON_ROOT`: the primary/common checkout root for local-only `.woostack` state.

Resolution rules:

1. honor explicit `WOOSTACK_COMMON_ROOT`
2. in GitHub Actions, use `GITHUB_WORKSPACE`
3. in a local git checkout, derive the primary checkout from `git rev-parse --git-common-dir`
4. fall back to `WOOSTACK_ROOT`

For local git worktrees, `git rev-parse --git-common-dir` resolves to the primary checkout's
shared `.git` directory; its parent is the primary checkout root. The implementation should
normalize that path with `pwd -P` before exporting it.

Then use `$WOOSTACK_COMMON_ROOT/.woostack` only where the path intentionally reads or writes
local-only shared state:

- review memory recall and wisdom composition
- review scoped memory recording
- review metrics folding
- address-comments memory recall
- address-comments scoped memory recording

Do not move tracked plan/spec/fix edits, active diff inspection, or worktree branch operations to
the common root.

Hardened decisions:

- Keep `WOOSTACK_ROOT` unchanged. Reinterpreting it as the primary checkout would regress the
  worktree isolation contract and could send tracked edits back to the primary tree.
- Keep CI behavior unchanged. `GITHUB_WORKSPACE` is both the active checkout and the local state
  root in the reusable-review action.
- Route scoped memory notes written by review/address-comments to the common root. These commands
  are local knowledge-maintenance operations, not increment code edits, and the bug report's
  symptom is that the notes are invisible from worktrees.
- Do not reintroduce the removed flat `.woostack/memory.md` shard. The live memory surface remains
  `.woostack/memory/` plus generated/prefetched `$OUTDIR/memory.md`.

## 3. Implementation Plan

- [x] **Step 1: Reproduce with failing worktree tests**
  - Add review-script regression coverage that creates a primary repo with untracked local
    memory/metrics state, adds a secondary git worktree, runs helpers from that secondary
    worktree, and asserts they use the primary `.woostack` for memory/metrics.
  - Add address-comments regression coverage for memory recall/record from a secondary worktree.
  - Cover the resolver contract directly: in a secondary worktree, `WOOSTACK_ROOT` remains the
    secondary worktree and `WOOSTACK_COMMON_ROOT` resolves to the primary checkout.
  - Cover explicit `WOOSTACK_COMMON_ROOT` override so tests and host adapters can pin a root.
  - Confirm these tests fail before implementation because helpers resolve local state against the
    secondary worktree.

- [x] **Step 2: Add common-root resolution**
  - Update `skills/woostack-review/scripts/resolve-root.sh` and
    `skills/woostack-address-comments/scripts/resolve-root.sh` to export
    `WOOSTACK_COMMON_ROOT` while preserving existing `WOOSTACK_ROOT` behavior.
  - Derive the common root from `git rev-parse --git-common-dir` for local worktrees, with
    explicit override and CI handling.

- [x] **Step 3: Route only local-only state through the common root**
  - Update review memory recall, wisdom composition, scoped memory recording, and metrics folding
    to use `$WOOSTACK_COMMON_ROOT/.woostack`.
  - Update address-comments memory recall and scoped memory recording to use
    `$WOOSTACK_COMMON_ROOT/.woostack`.
  - Leave config, active checkout, OUTDIR hashing, diff collection, and branch/worktree operations
    anchored to `$WOOSTACK_ROOT`.

- [x] **Step 4: Verification**
  - Run `bash skills/woostack-review/scripts/tests/run-tests.sh` if present; otherwise run the
    affected review helper test scripts directly.
  - Run `bash skills/woostack-address-comments/scripts/tests/run-tests.sh` if present; otherwise
    run the affected address-comments helper test scripts directly.
  - Run `bash skills/woostack-doctor/scripts/doctor.sh --check` from the primary checkout.
