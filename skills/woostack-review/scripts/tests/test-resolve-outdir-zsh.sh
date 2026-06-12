#!/usr/bin/env bash
# Regression for issue #314: resolve-outdir.sh must locate its sibling
# resolve-root.sh even when SOURCED from a non-bash shell (zsh), where
# ${BASH_SOURCE[0]} is empty. Pre-fix, the relative `./resolve-root.sh` source
# failed, WOOSTACK_ROOT stayed empty, and OUTDIR resolved to the sha1 of the
# empty string (/tmp/pr-review-da39a3ee5e6b). The fix uses ${BASH_SOURCE[0]:-$0}
# so $0 (the sourced path under zsh) supplies the dir. Both the woostack-review
# and woostack-address-comments copies must agree.
#
# Also pins the widened-scope invariant (issue #314): no production (non-test)
# script in the review/address-comments resolve-* family may use a BARE
# `dirname "${BASH_SOURCE[0]}"` self-path — every one must carry the :-$0 guard.
#
# shellcheck disable=SC2016  # single quotes intentional: $0/$WOOSTACK_ROOT/$OUTDIR
# must expand inside the child shell, not in this parent shell.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"

REVIEW_SCRIPTS="$DIR"
ADDRESS_SCRIPTS="$ROOT/skills/woostack-address-comments/scripts"

# --- Part A: behavioral regression — source resolve-outdir.sh under zsh -------
if ! command -v zsh >/dev/null 2>&1; then
  echo "  SKIP: zsh not available; cannot exercise the non-bash sourcing path"
else
  # The empty-string sha1 prefix the buggy code produced.
  EMPTY_HASH="da39a3ee5e6b"

  # A throwaway git repo gives resolve-root.sh a deterministic toplevel, and a
  # cwd that is NOT the scripts dir (so a bare ./resolve-root.sh would fail).
  repo="$(mktemp -d)"
  ( cd "$repo" && git init -q )
  toplevel="$(cd "$repo" && git rev-parse --show-toplevel)"
  want_hash="$(printf '%s' "$toplevel" | { sha1sum 2>/dev/null || shasum; } | cut -c1-12)"

  for resolver in \
    "$REVIEW_SCRIPTS/resolve-outdir.sh" \
    "$ADDRESS_SCRIPTS/resolve-outdir.sh"; do
    tag="$(basename "$(dirname "$(dirname "$resolver")")")"  # skill dir name

    # Source under zsh from inside the repo, WOOSTACK_ROOT/OUTDIR unset so
    # resolve-outdir.sh must locate and run resolve-root.sh to populate them.
    # GITHUB_ACTIONS is also unset so the review copy takes its LOCAL (per-run)
    # branch — the path the #314 zsh-sourcing bug actually exercised.
    err="$(mktemp)"
    out="$( cd "$toplevel" && env -u WOOSTACK_ROOT -u OUTDIR -u GITHUB_ACTIONS zsh -c \
              'source "$0"; printf "%s|%s" "$WOOSTACK_ROOT" "$OUTDIR"' \
              "$resolver" 2>"$err" )" || true
    got_root="${out%%|*}"
    got_outdir="${out#*|}"
    stderr="$(cat "$err")"; rm -f "$err"

    assert_eq "$got_root" "$toplevel" \
      "[$tag] resolve-root.sh sourced under zsh -> WOOSTACK_ROOT == git toplevel"
    assert_not_contains "$got_outdir" "$EMPTY_HASH" \
      "[$tag] OUTDIR not derived from sha1 of empty string under zsh"
    # The two copies intentionally diverge on shape (issue #321): the review copy
    # mints a per-RUN dir locally (pr-review-<hash>-<ts>-<pid>), while the
    # address-comments copy stays per-project (pr-review-<hash>). Both still
    # derive from the real root hash — the #314 regression this test pins.
    if [ "$tag" = "woostack-review" ]; then
      assert_contains "$got_outdir" "/tmp/pr-review-$want_hash-" \
        "[$tag] OUTDIR derives from the real root hash + per-run suffix under zsh"
    else
      assert_eq "$got_outdir" "/tmp/pr-review-$want_hash" \
        "[$tag] OUTDIR derives from the real root hash under zsh"
    fi
    assert_not_contains "$stderr" "resolve-root.sh" \
      "[$tag] no missing-file error when sourcing resolve-root.sh under zsh"
  done

  rm -rf "$repo"
fi

# --- Part B: static invariant — no bare BASH_SOURCE self-path remains ---------
# Every production (non-test) source-site must carry the :-$0 fallback. The
# dual-mode execution guard `[ "${BASH_SOURCE[0]}" = "${0}" ]` has no `dirname`
# and is correctly excluded by this pattern.
for scripts in "$REVIEW_SCRIPTS" "$ADDRESS_SCRIPTS"; do
  bare="$(grep -rlnF --include='*.sh' 'dirname "${BASH_SOURCE[0]}"' "$scripts" \
            | grep -v '/tests/' || true)"
  assert_eq "$bare" "" \
    "[$(basename "$(dirname "$scripts")")] no production script uses a bare dirname \"\${BASH_SOURCE[0]}\""
done

finish
