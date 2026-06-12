#!/usr/bin/env bash
# Single source of truth for the default OUTDIR.
#
# Sourced (not executed) by every woostack-review script. Respect an explicit
# OUTDIR override (host sandbox dirs, the GitHub Action's pin, tests) verbatim;
# otherwise derive a default keyed on the woostack root hash (the git toplevel,
# via resolve-root.sh — stable across subdirs of one repo) so reviews of
# different repos on one machine never share — and clobber — one tree.
#
# Local (NOT GitHub Actions): mint a per-RUN dir, pr-review-<hash>-<ts>-<pid>.
# The <hash> isolates repos; the <ts>-<pid> suffix isolates runs, so two reviews
# of the SAME repo never share a findings/receipt tree (issue #321 — stale
# artifacts from a prior run were leaking into merge/validation/posting). The
# suffix is non-deterministic by design: it is minted ONCE per run and the
# orchestrator captures prefetch.sh's printed `outdir=<path>` and exports OUTDIR
# verbatim to every sub-agent and downstream stage (no recompute drift — see
# SKILL.md Stage 1). Set OUTDIR yourself to pin a specific tree.
#
# CI (GITHUB_ACTIONS=true): keep the stable per-project pr-review-<hash> form.
# This branch is effectively dead — action.yml pins OUTDIR=/tmp/pr-review via
# GITHUB_ENV before any script runs — but keeping it deterministic preserves
# CI's hardcoded /tmp/pr-review-* assumptions as defense-in-depth.
if [ -z "${OUTDIR:-}" ]; then
  # shellcheck source=skills/woostack-review/scripts/resolve-root.sh
  source "$(dirname "${BASH_SOURCE[0]:-$0}")/resolve-root.sh"
  _wr_hash="$(printf '%s' "$WOOSTACK_ROOT" | { sha1sum 2>/dev/null || shasum; } | cut -c1-12)"
  # Place inside the workspace's .woostack/tmp/ directory to leverage pre-approved
  # workspace permissions and avoid sandbox permission prompt loops locally.
  if [ -d "${WOOSTACK_ROOT}/.woostack" ]; then
    _wr_base="${WOOSTACK_ROOT}/.woostack/tmp"
  else
    _wr_base="/tmp"
  fi
  if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
    OUTDIR="${_wr_base}/pr-review-${_wr_hash}"
  else
    OUTDIR="${_wr_base}/pr-review-${_wr_hash}-$(date +%Y%m%d%H%M%S)-$$"
  fi
  unset _wr_hash _wr_base
fi
export OUTDIR
