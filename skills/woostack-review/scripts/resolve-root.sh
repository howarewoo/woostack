#!/usr/bin/env bash
# Single source of truth for the woostack repo root (issue #272).
#
# Sourced (not executed) by every woostack script that anchors a `.woostack/`
# path — metrics, config, memory, prefetch, and resolve-outdir. Resolving ONE
# root here keeps the `.woostack/` tree from splitting across a monorepo when the
# host agent's CWD drifts into a workspace package: every consumer lands at the
# repo root, never `<cwd>/.woostack/` inside a package.
#
# Precedence:
#   1. explicit WOOSTACK_ROOT override (host pins, tests) — honored as-is
#   2. GITHUB_WORKSPACE — the CI checkout root (it *is* the repo root there)
#   3. git rev-parse --show-toplevel — the repo root for any subdir of a clone
#   4. pwd — fallback when not inside a git repo
#
# Honors explicit MEMORY_DIR / MEMORY_FILE / OUTDIR overrides downstream
# unchanged; only the *default* base switches from CWD-relative to root-anchored.
if [ -z "${WOOSTACK_ROOT:-}" ]; then
  if [ -n "${GITHUB_WORKSPACE:-}" ]; then
    WOOSTACK_ROOT="$GITHUB_WORKSPACE"
  else
    WOOSTACK_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  fi
fi
export WOOSTACK_ROOT
