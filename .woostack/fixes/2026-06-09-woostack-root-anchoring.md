---
type: fix
status: in-review
branch: fix/woostack-root-anchoring
---

# Fix: `.woostack/` anchored to CWD, not repo root — pollutes packages in monorepos

GitHub issue: https://github.com/howarewoo/woostack/issues/272

## 1. Root Cause

Several woostack scripts compute the `.woostack/` parent directory by falling back to the
**current working directory** (`$(pwd)`) instead of the **git repository root**. When the host
agent's CWD drifts into a workspace package (e.g. `packages/infrastructure/ai`), these scripts
create/read `.woostack/` *inside that package* and append to the package's `.gitignore`,
splitting woostack state across the tree.

Confirmed sites (grep, line-level):

| Script | Line | Defect |
|---|---|---|
| `skills/woostack-review/scripts/metrics-fold.sh` | 20 | `ROOT="${GITHUB_WORKSPACE:-$(pwd)}"` → writes `<cwd>/.woostack/metrics.json`, appends `.woostack/metrics.json` to `<cwd>/.gitignore` |
| `skills/woostack-review/scripts/load-config.sh` | 67 | `ROOT="${GITHUB_WORKSPACE:-$(pwd)}"` → reads `<cwd>/.woostack/config.json`; under a package the config is silently missed → defaults used |
| `skills/woostack-review/scripts/prefetch.sh` | 752 | `WOOSTACK_DIR="${GITHUB_WORKSPACE:-$(pwd)}/.woostack"` → memory recall reads the wrong dir |
| `skills/woostack-review/scripts/memory-append.sh` | 13 | `MEMORY_FILE="${MEMORY_FILE:-.woostack/memory.md}"` (bare CWD-relative default) |
| `skills/woostack-review/scripts/memory-record.sh` | 11-12 | `MEMORY_DIR="${MEMORY_DIR:-.woostack/memory}"`, `MEMORY_FILE="${MEMORY_FILE:-.woostack/memory.md}"` (bare CWD-relative defaults) |

Same defect class in the **woostack-address-comments** copies (separate files, not symlinks):

| Script | Line | Defect |
|---|---|---|
| `skills/woostack-address-comments/scripts/memory-append.sh` | 13 | bare `.woostack/memory.md` default |
| `skills/woostack-address-comments/scripts/memory-record.sh` | 11-12 | bare `.woostack/memory{,.md}` defaults |
| `skills/woostack-address-comments/scripts/prefetch.sh` | 30-33 | bare `.woostack/memory`, `.woostack/memory.md` reads |

**Evidence of inconsistency:** `resolve-outdir.sh` (sourced by every review/address script for
`OUTDIR`) already resolves the root correctly via `git rev-parse --show-toplevel 2>/dev/null ||
pwd`. So `OUTDIR` lands at `<root>/.woostack/tmp/...` while `metrics-fold` / `load-config` /
`memory-*` / `prefetch WOOSTACK_DIR` land relative to CWD. The two disagree whenever CWD ≠ repo
root. The bug was hit in the wild on a Claude Code host where a `cd packages/infrastructure/ai`
persisted as the shell CWD across tool calls, so `metrics-fold.sh` created
`packages/infrastructure/ai/.woostack/`.

**Why the bad value originates:** each script independently picks `$(pwd)` (or a bare relative
path) as the fallback root rather than the git toplevel. There is no single shared resolver, so
each new script re-introduces the CWD assumption.

## 2. Proposed Fix

Introduce one shared resolver, `resolve-root.sh`, sourced exactly like `resolve-outdir.sh`,
exporting `WOOSTACK_ROOT` with this precedence:

```sh
#!/usr/bin/env bash
# Single source of truth for the woostack repo root.
# Sourced (not executed). Honors an explicit WOOSTACK_ROOT override; otherwise
# prefers the CI checkout root, then the git toplevel, then the current directory.
if [ -z "${WOOSTACK_ROOT:-}" ]; then
  if [ -n "${GITHUB_WORKSPACE:-}" ]; then
    WOOSTACK_ROOT="$GITHUB_WORKSPACE"
  else
    WOOSTACK_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  fi
fi
export WOOSTACK_ROOT
```

Then anchor every default `.woostack/` path to `$WOOSTACK_ROOT`, keeping all existing explicit
overrides (`MEMORY_DIR`, `MEMORY_FILE`, `OUTDIR`) working unchanged — only the *default* switches
from CWD-relative to root-anchored:

- `metrics-fold.sh`: `ROOT="$WOOSTACK_ROOT"` (source `resolve-root.sh`).
- `load-config.sh`: `ROOT="$WOOSTACK_ROOT"` (source `resolve-root.sh`).
- `prefetch.sh`: `WOOSTACK_DIR="$WOOSTACK_ROOT/.woostack"` (source `resolve-root.sh`).
- `memory-append.sh`: default `MEMORY_FILE="$WOOSTACK_ROOT/.woostack/memory.md"` when unset.
- `memory-record.sh`: default `MEMORY_DIR`/`MEMORY_FILE` under `$WOOSTACK_ROOT/.woostack/` when unset.
- `resolve-outdir.sh`: source `resolve-root.sh` and reuse `WOOSTACK_ROOT` for its root computation
  (zero behavior change — in CI `GITHUB_WORKSPACE == toplevel`; locally the git toplevel; keeps the
  two resolvers from drifting, which is exactly the bug's root cause).

`resolve-root.sh` is duplicated per-skill-scripts dir, matching the existing `resolve-outdir.sh`
duplication pattern (review and address-comments each keep their own copy).

**Scope (RESOLVED):** fix BOTH woostack-review and woostack-address-comments — identical root
cause, one PR closes it everywhere. The address-comments dir gets its own `resolve-root.sh` copy
plus the same `memory-append.sh` / `memory-record.sh` / `prefetch.sh` edits.

## 3. Implementation Plan

- [x] **Step 1: Failing tests (RED)** under `skills/woostack-review/scripts/tests/`
  - `test-resolve-root.sh` — unit the resolver precedence: (a) `GITHUB_WORKSPACE` set wins even
    inside a git repo; (b) unset + git subdir → git toplevel; (c) explicit `WOOSTACK_ROOT` honored.
    Fails first because `resolve-root.sh` does not exist yet.
  - `test-metrics-fold-root.sh` — in a real git repo with a subdir, `GITHUB_WORKSPACE` unset, run
    `metrics-fold.sh` from the subdir; assert `metrics.json` + the `.gitignore` append land at the
    git toplevel `.woostack/`, and **no** `.woostack/` is created in the subdir. Fails first
    (current code writes `<subdir>/.woostack/`).
  - `test-load-config-root.sh` — config at `<root>/.woostack/config.json` with a non-default value;
    run `load-config.sh` from a subdir with `GITHUB_WORKSPACE` unset; assert the emitted config
    reflects the root config (not silent defaults). Fails first.
  - `test-memory-record-root.sh` — no `MEMORY_DIR` override; run `memory-record.sh` from a subdir
    of a git repo whose root has `.woostack/memory/`; assert the note lands under
    `<root>/.woostack/memory/`, not `<subdir>/.woostack/memory/`. Fails first.
  - Confirm each new test FAILS against current code before editing scripts.
  - ✅ Done. All 4 confirmed RED before edits (e.g. metrics-fold wrote `<subdir>/.woostack/`;
    load-config emitted `severity_floor=high` default instead of the root's `low`).
- [x] **Step 2: Minimal fix (GREEN)**
  - Add `skills/woostack-review/scripts/resolve-root.sh` (the resolver above).
  - Edit review `metrics-fold.sh`, `load-config.sh`, `prefetch.sh`, `memory-append.sh`,
    `memory-record.sh`, `resolve-outdir.sh` to source the resolver and anchor defaults to
    `$WOOSTACK_ROOT`.
  - Mirror into `skills/woostack-address-comments/scripts/`: add `resolve-root.sh`, then edit
    `memory-append.sh`, `memory-record.sh`, `prefetch.sh`, and `resolve-outdir.sh` to anchor on
    `$WOOSTACK_ROOT` (prefetch's `ROOT` for skill-script discovery stays script-relative; only the
    `.woostack/` memory reads switch from bare-CWD to root-anchored).
  - No bundled refactors beyond the resolver consolidation named above.
  - ✅ Done. Added `resolve-root.sh` to both `woostack-review/scripts/` and
    `woostack-address-comments/scripts/`; anchored `metrics-fold.sh`, `load-config.sh`,
    `prefetch.sh`, `memory-append.sh`, `memory-record.sh`, `resolve-outdir.sh` (review) and
    `memory-append.sh`, `memory-record.sh`, `prefetch.sh`, `resolve-outdir.sh` (address-comments)
    on `$WOOSTACK_ROOT`.
- [x] **Step 3: Verification**
  - ✅ All 4 new `test-*-root.sh` green; existing `test-metrics-fold-overlap.sh`,
    `test-load-config-nits.sh`, `test-memory-record.sh` stay green; full review suite + the
    woostack-init (27+14) and woostack-status (59) runners pass. (Two pre-existing
    `test-detect-angles-*` files lack a `finish` line and print no summary — unrelated to #272,
    identical on baseline, left untouched.)
  - ✅ `shellcheck -x` clean on every new/edited script (intentional SC2016 in the resolver test
    suppressed with a directive; prefetch's remaining style infos are pre-existing, on untouched lines).
  - ✅ Wild repro closed: `test-metrics-fold-root.sh` proves that from a package subdir with
    `GITHUB_WORKSPACE` unset, `metrics-fold.sh` writes only the git-toplevel `.woostack/` and
    creates no `.woostack/` (and no `.gitignore`) inside the package.

## Open Questions

1. ~~**Address-comments scope** — fix the woostack-address-comments copies in this PR, or
   review-only?~~ **RESOLVED: include them (both).**

## Notes

- `GITHUB_WORKSPACE` first is correct for CI (it *is* the checkout root there).
- The optional "warn if `.woostack` parent ≠ git toplevel" guard from the issue is intentionally
  omitted: with a single shared resolver it is redundant, and it would mis-fire on legitimate
  non-git checkouts (where `pwd` is the correct fallback).
