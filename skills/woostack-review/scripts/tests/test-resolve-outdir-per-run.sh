#!/usr/bin/env bash
# Issue #321: woostack-review's local default OUTDIR must be per-RUN, not
# per-project, so two reviews of the same repo never share a findings/receipt
# tree; and prefetch.sh's in-flight-findings guard must HARD-STOP locally
# (instead of warn-and-continue) while still PRESERVING legitimately-downloaded
# findings.* in CI's validate job.
#
# Covers:
#   1. per-run isolation   — two local resolutions of the same repo differ
#   2. explicit override   — an exported OUTDIR is honored verbatim
#   3. CI determinism      — GITHUB_ACTIONS=true yields the stable per-project form
#   4. prefetch guard      — 4a local hard-stop, 4b CI preserve, 4c FRESH wipe
#
# shellcheck disable=SC2016  # single quotes intentional: $OUTDIR must expand
# inside the child shell, not in this parent shell.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"

RESOLVER="$DIR/resolve-outdir.sh"
PREFETCH="$DIR/prefetch.sh"

# A throwaway git repo gives resolve-root.sh a deterministic toplevel. No
# .woostack/ dir, so the default base is /tmp (not WOOSTACK_ROOT/.woostack/tmp).
repo="$(mktemp -d)"
( cd "$repo" && git init -q )
toplevel="$(cd "$repo" && git rev-parse --show-toplevel)"
want_hash="$(printf '%s' "$toplevel" | { sha1sum 2>/dev/null || shasum; } | cut -c1-12)"

resolve() { # extra env... -> prints the resolved OUTDIR for a fresh process
  ( cd "$toplevel" && env -u WOOSTACK_ROOT -u OUTDIR -u GITHUB_WORKSPACE "$@" \
      bash -c 'source "$0"; printf "%s" "$OUTDIR"' "$RESOLVER" )
}

# --- 1. per-run isolation -----------------------------------------------------
out_a="$(resolve -u GITHUB_ACTIONS)"
out_b="$(resolve -u GITHUB_ACTIONS)"
assert_contains "$out_a" "pr-review-$want_hash-" \
  "local default carries a per-run suffix (pr-review-<hash>-...)"
if [ "$out_a" = "$out_b" ]; then
  fail "two local resolutions of the same repo must differ (got identical: $out_a)"
else
  pass "two local resolutions of the same repo resolve to different dirs"
fi

# --- 2. explicit override honored ---------------------------------------------
out_override="$( env -u WOOSTACK_ROOT -u GITHUB_WORKSPACE OUTDIR=/explicit/outdir \
  bash -c 'source "$0"; printf "%s" "$OUTDIR"' "$RESOLVER" )"
assert_eq "$out_override" "/explicit/outdir" \
  "an explicit OUTDIR override is preserved unchanged"

# --- 3. CI determinism (no per-run suffix under GITHUB_ACTIONS) ---------------
out_ci="$(resolve GITHUB_ACTIONS=true)"
assert_eq "$out_ci" "/tmp/pr-review-$want_hash" \
  "GITHUB_ACTIONS=true yields the stable per-project OUTDIR (no timestamp/pid)"

# --- 4a. prefetch local hard-stop on a contaminated dir -----------------------
work_a="$(mktemp -d)"; seed_a="$work_a/out"; mkdir -p "$seed_a"
: > "$seed_a/findings.bugs.json"
err_a="$(mktemp)"
set +e
env -u GITHUB_ACTIONS -u WOO_REVIEW_FRESH OUTDIR="$seed_a" \
  bash "$PREFETCH" >/dev/null 2>"$err_a"
rc_a=$?
set -e
assert_exit 1 "$rc_a" "local prefetch hard-stops (exit 1) when findings.* already present"
assert_contains "$(cat "$err_a")" "contaminated" "local hard-stop names the contaminated dir"
assert_exit 0 "$([ -e "$seed_a/findings.bugs.json" ]; echo $?)" \
  "local hard-stop preserves the existing findings.* (does not wipe)"

# --- 4b. prefetch CI preserve (findings.* are legit downloaded artifacts) ------
work_b="$(mktemp -d)"; seed_b="$work_b/out"; mkdir -p "$seed_b"
: > "$seed_b/findings.bugs.json"
err_b="$(mktemp)"; out_b_run="$(mktemp)"
set +e
# CI + no PR# -> guard preserves, run continues to the no-PR emit_skip (exit 0).
# WOO_REVIEW_TEST_MODE is refused under GITHUB_ACTIONS, so the no-PR early skip
# (not the fake-data hooks) is what lets this exit cleanly.
env -u WOO_REVIEW_FRESH -u PR_NUMBER GITHUB_ACTIONS=true GITHUB_REPOSITORY=owner/repo \
  OUTDIR="$seed_b" bash "$PREFETCH" >"$out_b_run" 2>"$err_b"
rc_b=$?
set -e
assert_exit 0 "$rc_b" "CI prefetch does not abort at the guard (continues past it)"
assert_exit 0 "$([ -e "$seed_b/findings.bugs.json" ]; echo $?)" \
  "CI preserve keeps the downloaded findings.* in place"
assert_not_contains "$(cat "$err_b")" "contaminated" \
  "CI path uses a warning, not the local hard-stop error"

# --- 4c. WOO_REVIEW_FRESH=1 forces a wipe (no hard-stop) ----------------------
work_c="$(mktemp -d)"
pushd "$work_c" >/dev/null
git init -q
git config user.email test@example.com
git config user.name "Test User"
mkdir -p src
printf 'one\n' > src/app.sh
git add .
git commit -q -m init
seed_c="$work_c/out"; mkdir -p "$seed_c"
: > "$seed_c/findings.bugs.json"
meta='{"headRefOid":"abc123","baseRefName":"main","title":"feature work","body":"","author":{"login":"human"},"files":[{"path":"src/app.sh","additions":12,"deletions":0}]}'
diff=$'diff --git a/src/app.sh b/src/app.sh\n--- a/src/app.sh\n+++ b/src/app.sh\n@@ -1,1 +1,13 @@\n one\n+two\n+three\n+four\n+five\n+six\n+seven\n+eight\n+nine\n+ten\n+eleven\n+twelve\n+thirteen\n'
fresh_out="$(mktemp)"
set +e
env -u GITHUB_ACTIONS \
  WOO_REVIEW_FRESH=1 \
  OUTDIR="$seed_c" \
  PR_NUMBER=1 \
  GITHUB_REPOSITORY=owner/repo \
  WOO_REVIEW_TEST_MODE=1 \
  WOO_REVIEW_FAKE_PR_REVIEWS_JSON='{"reviews":[]}' \
  WOO_REVIEW_FAKE_BOT_COMMENTS=0 \
  WOO_REVIEW_FAKE_META_JSON="$meta" \
  WOO_REVIEW_FAKE_FULL_DIFF="$diff" \
  WOO_REVIEW_FAKE_PRIOR_THREADS_JSON='{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[]}}}}}' \
  bash "$PREFETCH" >"$fresh_out" 2>/dev/null
rc_c=$?
set -e
popd >/dev/null
assert_exit 0 "$rc_c" "WOO_REVIEW_FRESH=1 lets prefetch complete (no hard-stop)"
assert_contains "$(cat "$fresh_out")" "Prefetch complete" "FRESH run reaches Prefetch complete"
assert_exit 1 "$([ -e "$seed_c/findings.bugs.json" ]; echo $?)" \
  "WOO_REVIEW_FRESH=1 wipes the stale findings.*"

rm -rf "$repo" "$work_a" "$work_b" "$work_c" "$err_a" "$err_b" "$out_b_run" "$fresh_out"

finish
