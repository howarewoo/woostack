#!/usr/bin/env bash
# Single source of truth for the woostack base / integration branch.
#
# Sourced (or executed) by every woostack skill that cuts a stack-base branch,
# targets a PR base (`--base`), or resolves a worktree base-ref. Resolving ONE
# base here keeps the trunk branch per-repo configurable instead of hardcoded
# `staging`.
#
# Precedence:
#   1. explicit WOOSTACK_BASE_BRANCH override (host pins, tests) — honored as-is
#   2. .woostack/config.json -> base_branch, if set and non-empty
#   3. git symbolic-ref refs/remotes/origin/HEAD -> the remote default branch
#   4. main — fallback when there is no remote / fresh repo
#
# Root resolution mirrors resolve-root.sh (WOOSTACK_ROOT override ->
# GITHUB_WORKSPACE -> git rev-parse --show-toplevel -> pwd) so `.woostack/`
# anchors to the repo root. (woostack-init/scripts has no resolve-root.sh to
# source, so the precedence is inlined here; keep it in sync with
# skills/woostack-review/scripts/resolve-root.sh.)
if [ -z "${WOOSTACK_ROOT:-}" ]; then
  if [ -n "${GITHUB_WORKSPACE:-}" ]; then
    WOOSTACK_ROOT="$GITHUB_WORKSPACE"
  else
    WOOSTACK_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  fi
fi
export WOOSTACK_ROOT

if [ -z "${WOOSTACK_BASE_BRANCH:-}" ]; then
  _wb_cfg="$WOOSTACK_ROOT/.woostack/config.json"
  _wb_base=""
  if [ -f "$_wb_cfg" ]; then
    if command -v jq >/dev/null 2>&1; then
      _wb_base="$(jq -r '.base_branch // empty' "$_wb_cfg" 2>/dev/null || true)"
    else
      printf 'woostack: %s exists but jq is unavailable; cannot read base_branch\n' "$_wb_cfg" >&2
      return 1 2>/dev/null || exit 1
    fi
  fi
  if [ -z "$_wb_base" ]; then
    _wb_base="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)"
    _wb_base="${_wb_base#origin/}"
  fi
  [ -z "$_wb_base" ] && _wb_base="main"
  WOOSTACK_BASE_BRANCH="$_wb_base"
fi
export WOOSTACK_BASE_BRANCH

# When executed (not sourced), print the resolved branch so callers can capture it:
#   base="$(bash <wi>/resolve-base.sh)"
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  printf '%s\n' "$WOOSTACK_BASE_BRANCH"
fi
