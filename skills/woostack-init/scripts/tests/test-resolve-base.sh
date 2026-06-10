#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DIR/tests/assert.sh"
resolver="$DIR/resolve-base.sh"

# Run the resolver SOURCED in a clean env (config/remote path), echo the result.
resolved() { # repo
  ( cd "$1" && env -u WOOSTACK_BASE_BRANCH WOOSTACK_ROOT="$1" \
      bash -c 'set -e; . "$1"; printf "%s" "$WOOSTACK_BASE_BRANCH"' _ "$resolver" )
}

# 1. config.base_branch set -> wins
repo1="$(mktemp -d)"; ( cd "$repo1" && git init -q && git commit -q --allow-empty -m init )
mkdir -p "$repo1/.woostack"; printf '{"base_branch":"trunk"}\n' > "$repo1/.woostack/config.json"
assert_eq "$(resolved "$repo1")" "trunk" "config base_branch wins"

# 2. unset config -> remote default branch (origin/HEAD)
origin="$(mktemp -d)"; ( cd "$origin" && git init -q --bare )
repo2="$(mktemp -d)"
( cd "$repo2" && git init -q && git checkout -q -b dev && git commit -q --allow-empty -m init \
  && git remote add origin "$origin" && git push -q origin dev && git remote set-head origin dev )
assert_eq "$(resolved "$repo2")" "dev" "remote default branch used when no config"

# 3. unset config + no remote -> main
repo3="$(mktemp -d)"; ( cd "$repo3" && git init -q && git commit -q --allow-empty -m init )
assert_eq "$(resolved "$repo3")" "main" "no remote falls back to main"

# 4. explicit WOOSTACK_BASE_BRANCH override honored as-is (config present, but pinned wins)
out4="$( cd "$repo1" && WOOSTACK_ROOT="$repo1" WOOSTACK_BASE_BRANCH="pinned" \
  bash -c '. "$1"; printf "%s" "$WOOSTACK_BASE_BRANCH"' _ "$resolver" )"
assert_eq "$out4" "pinned" "explicit override wins over config"

# 5. EXECUTED (not sourced) prints the resolved branch for $( ) capture
out5="$( cd "$repo1" && env -u WOOSTACK_BASE_BRANCH WOOSTACK_ROOT="$repo1" bash "$resolver" )"
assert_eq "$out5" "trunk" "executed mode prints resolved branch"

finish
