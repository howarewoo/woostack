#!/usr/bin/env bash
# Single source of truth for the default OUTDIR.
#
# Sourced (not executed) by every woostack-review script. Respect an explicit
# OUTDIR override (host sandbox dirs, the GitHub Action's pin, tests); otherwise
# derive a per-project path so concurrent reviews of different repos on one
# machine do not share — and clobber — the same /tmp/pr-review tree.
#
# Derivation: hash the woostack root (the git toplevel, via resolve-root.sh —
# stable across subdirs of one repo); two distinct repo roots hash to two
# distinct dirs; the same repo always resolves to the same dir.
#
# NOTE: per-project granularity only. Two concurrent runs of the SAME repo still
# share one dir (rare; accepted). For full per-run isolation, set OUTDIR yourself.
if [ -z "${OUTDIR:-}" ]; then
  # shellcheck source=skills/woostack-review/scripts/resolve-root.sh
  source "$(dirname "${BASH_SOURCE[0]}")/resolve-root.sh"
  _wr_hash="$(printf '%s' "$WOOSTACK_ROOT" | { sha1sum 2>/dev/null || shasum; } | cut -c1-12)"
  # Place inside the workspace's .woostack/tmp/ directory to leverage pre-approved
  # workspace permissions and avoid sandbox permission prompt loops locally.
  if [ -d "${WOOSTACK_ROOT}/.woostack" ]; then
    OUTDIR="${WOOSTACK_ROOT}/.woostack/tmp/pr-review-${_wr_hash}"
  else
    OUTDIR="/tmp/pr-review-${_wr_hash}"
  fi
  unset _wr_hash
fi
export OUTDIR
