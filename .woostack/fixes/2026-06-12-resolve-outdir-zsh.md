---
type: fix
status: in-review
branch: fix/resolve-outdir-zsh
---

# Fix: resolve-outdir.sh resolves OUTDIR to sha1('') under a zsh host (empty `${BASH_SOURCE[0]}`)

Tracking: [howarewoo/woostack#314](https://github.com/howarewoo/woostack/issues/314)

## 1. Root Cause

`scripts/resolve-outdir.sh:17` locates its sibling `resolve-root.sh` with a **bash-only**
self-path idiom:

```bash
source "$(dirname "${BASH_SOURCE[0]}")/resolve-root.sh"
```

`${BASH_SOURCE[0]}` is populated only by bash. When the host **sources** this script from a
non-bash shell — zsh, which is Claude Code's default Bash-tool shell on macOS — `${BASH_SOURCE[0]}`
is empty, so `dirname ""` → `.` → it tries `./resolve-root.sh`. That exists only if cwd happens to
be the `scripts/` dir; from anywhere else (e.g. a git worktree) the `source` fails:

```
resolve-outdir.sh:source:17: no such file or directory: ./resolve-root.sh
```

`resolve-root.sh` never runs → `WOOSTACK_ROOT` stays empty → `printf '%s' "" | sha1sum` →
`da39a3ee5e6b` → `OUTDIR=/tmp/pr-review-da39a3ee5e6b`. Downstream stages that inherit that exported
`OUTDIR` then read/write the wrong tree, silently reusing a stale `findings.*.json` there.

**Evidence (reproduced):**

```
# zsh, sourced from a non-scripts cwd:
$ source .../woostack-review/scripts/resolve-outdir.sh
resolve-outdir.sh:source:17: no such file or directory: ./resolve-root.sh
OUTDIR=/tmp/pr-review-da39a3ee5e6b   WOOSTACK_ROOT=[]      # da39a3ee5e6b == sha1("")[:12]

# bash control, same cwd:
OUTDIR=/tmp/pr-review-8c393341f536   WOOSTACK_ROOT=[/tmp]  # resolves correctly
```

The repo **already blesses** the zsh-safe idiom at `skills/woostack-review/SKILL.md:223`:
`"$(dirname "${BASH_SOURCE[0]:-$0}")"`. The fix applies that same idiom to the broken `source`
line. Under zsh, `$0` is the sourced file's path (default `FUNCTION_ARGZERO`), so `dirname $0` →
the real `scripts/` dir; under bash, `${BASH_SOURCE[0]}` wins as before. `${BASH_SOURCE[0]:-$0}` is
plain POSIX parameter-expansion syntax — it parses cleanly in bash, zsh, and sh, unlike the
zsh-only `${(%):-%x}` alternative the issue floated.

**Scope of the bug.** `resolve-outdir.sh` is the only script the host **sources** directly
(SKILL.md Stage 1 / lines 244, 271; the address-comments flow likewise). Every other script that
uses `$(dirname "${BASH_SOURCE[0]}")/resolve-*` (prefetch.sh, load-config.sh, metrics-fold.sh, …)
is **`bash`-executed** via its shebang, so `${BASH_SOURCE[0]}` is always populated there and the
bug does not manifest. They are out of scope; see Notes. The identical `resolve-outdir.sh` exists in
**both** `woostack-review` and `woostack-address-comments` — both copies carry the bug and both are
fixed (the existing `test-resolve-root.sh` already enforces "both copies agree").

## 2. Proposed Fix

**Approved scope: widened.** Beyond the one manifesting site (`resolve-outdir.sh`), harden the
entire `${BASH_SOURCE[0]}` self-path **bug class** across the `woostack-review` and
`woostack-address-comments` production scripts, so no script in the resolve-* family mis-resolves
its own dir if it is ever sourced from a non-bash shell.

The transform, everywhere `${BASH_SOURCE[0]}` is used for **path resolution**:

```diff
-  ... "$(dirname "${BASH_SOURCE[0]}")/..."
+  ... "$(dirname "${BASH_SOURCE[0]:-$0}")/..."
```

`${BASH_SOURCE[0]:-$0}` is the repo's already-blessed idiom (`SKILL.md:223`): bash fills
`${BASH_SOURCE[0]}`; zsh falls back to `$0` (the sourced file path under default
`FUNCTION_ARGZERO`); plain POSIX parameter-expansion syntax that parses in bash/zsh/sh. No behavior
change under bash (the fallback is never taken). Fixing the resolution also removes the
broken-`OUTDIR` inheritance and stale-tree-reuse symptoms, which were downstream of the wrong path.

**Sites hardened** (`${BASH_SOURCE[0]}` → `${BASH_SOURCE[0]:-$0}`):

- `woostack-review/scripts/`: `resolve-outdir.sh` (the core bug, L17), `load-config.sh` (69, 71),
  `metrics-fold.sh` (17, 19), `prefetch.sh` (37, 39, 267, 315), `merge-findings.sh` (5, 7),
  `chunk-diff.sh` (26), `detect-angles.sh` (79), `intersect-findings.sh` (59),
  `resolve-diff-line.sh` (32), `load-prompt.sh` (25, 65), `run-bounded-swarm.sh` (19),
  `verify-receipts.sh` (14), `memory-record.sh` (6), `resolve-model.sh` (92 grep-self, 117 source).
- `woostack-address-comments/scripts/`: `resolve-outdir.sh` (L17), `fetch-threads.sh` (18),
  `prefetch.sh` (5), `memory-record.sh` (6).

**Deliberately NOT changed** — `resolve-model.sh:126` `if [ "${BASH_SOURCE[0]}" = "${0}" ]`. This
is the dual-mode **execution guard** (run `main` only on direct execution, not when sourced).
`:-$0` here would make the comparison always-true under zsh and run `main` on every source — the
exact opposite of intent. The guard stays bare.

**Out of scope:** `woostack-init` / `woostack-status` scripts (separate skills, all `bash`-executed,
and `resolve-base.sh:51` is likewise an execution guard) are not in the resolve-* family this fix
covers and are left untouched.

## 3. Implementation Plan

- [x] **Step 1: Reproduce with a failing test**
  - Add `skills/woostack-review/scripts/tests/test-resolve-outdir-zsh.sh`, modeled on the existing
    `test-resolve-root.sh` (bash test, `assert.sh` helpers, loops over both the review and
    address-comments copies).
  - It `source`s `resolve-outdir.sh` **under `zsh`** from inside a throwaway git repo (cwd ≠ the
    `scripts/` dir, `WOOSTACK_ROOT`/`OUTDIR` unset so `resolve-root.sh` must be located and run),
    then asserts: `WOOSTACK_ROOT` == the repo toplevel, `OUTDIR` == `/tmp/pr-review-<sha1(toplevel)>`,
    `OUTDIR` does **not** contain the empty-string hash `da39a3ee5e6b`, and no `resolve-root.sh`
    missing-file error on stderr.
  - Skips gracefully (`SKIP` + pass) when `zsh` is unavailable.
  - Confirm it **fails** against the unpatched scripts (red).

- [x] **Step 2: Apply the fix (widened)**
  - Replace `dirname "${BASH_SOURCE[0]}"` → `dirname "${BASH_SOURCE[0]:-$0}"` at every
    path-resolution site listed in §2, across review + address-comments production scripts (exclude
    `tests/`).
  - Also harden the one non-`dirname` self-path use, `resolve-model.sh:92`
    (`grep ... "${BASH_SOURCE[0]}"` → `"${BASH_SOURCE[0]:-$0}"`).
  - Leave `resolve-model.sh:126` execution guard untouched.

- [x] **Step 3: Verification**
  - New test green: `bash skills/woostack-review/scripts/tests/test-resolve-outdir-zsh.sh`.
  - Static invariant: no production source-site still uses bare `dirname "${BASH_SOURCE[0]}"`
    (the new test also pins this), and the guard line is preserved.
  - No regression in bash: run the existing review + address-comments script tests
    (`test-resolve-root.sh`, `test-load-config-root.sh`, `test-metrics-fold-root.sh`,
    `test-memory-record-root.sh`, `test-resolve-model.sh`, `test-prefetch-flat-memory.sh`,
    address-comments helper tests).
  - Manual re-repro under zsh from a non-scripts cwd: `OUTDIR` is a real-root hash, `WOOSTACK_ROOT`
    non-empty, no `source:17` error.

## Notes

- The widened scope hardens the bug *class* but only `resolve-outdir.sh` *manifested* it (it is the
  sole host-**sourced** script per SKILL.md Stage 1; the rest are `bash`-executed, where
  `${BASH_SOURCE[0]}` is always populated). The other edits are defensive — no behavior change
  today — and pin the idiom so a future host-sourced refactor cannot regress.
