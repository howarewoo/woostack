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
    WOOSTACK_ROOT="$(cd "$GITHUB_WORKSPACE" && pwd -P)"
  else
    WOOSTACK_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
    WOOSTACK_ROOT="$(cd "$WOOSTACK_ROOT" 2>/dev/null && pwd -P || printf '%s\n' "$WOOSTACK_ROOT")"
  fi
else
  WOOSTACK_ROOT="$(cd "$WOOSTACK_ROOT" 2>/dev/null && pwd -P || printf '%s\n' "$WOOSTACK_ROOT")"
fi
export WOOSTACK_ROOT

if [ -z "${WOOSTACK_COMMON_ROOT:-}" ]; then
  if [ -n "${GITHUB_WORKSPACE:-}" ]; then
    WOOSTACK_COMMON_ROOT="$(cd "$GITHUB_WORKSPACE" && pwd -P)"
  else
    _woo_common_git_dir="$(git rev-parse --git-common-dir 2>/dev/null || true)"
    if [ -n "$_woo_common_git_dir" ]; then
      WOOSTACK_COMMON_ROOT="$(cd "$_woo_common_git_dir/.." 2>/dev/null && pwd -P || printf '%s\n' "$WOOSTACK_ROOT")"
    else
      WOOSTACK_COMMON_ROOT="$WOOSTACK_ROOT"
    fi
  fi
else
  WOOSTACK_COMMON_ROOT="$(cd "$WOOSTACK_COMMON_ROOT" 2>/dev/null && pwd -P || printf '%s\n' "$WOOSTACK_COMMON_ROOT")"
fi
export WOOSTACK_COMMON_ROOT
