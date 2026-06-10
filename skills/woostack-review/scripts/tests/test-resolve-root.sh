#!/usr/bin/env bash
# Unit the shared woostack-root resolver precedence:
#   explicit WOOSTACK_ROOT override > GITHUB_WORKSPACE > git toplevel > pwd.
# Both the woostack-review and woostack-address-comments copies must agree.
#
# shellcheck disable=SC2016  # single quotes are intentional: $0/$WOOSTACK_ROOT
# must expand inside the child `bash -c`, not in this parent shell.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"

# Resolve WOOSTACK_ROOT in a clean child shell with controlled env + cwd.
#   $1 resolver path, $2 cwd, $3..$n env assignments (KEY=VALUE), `-u KEY` honored.
resolve() {
  local resolver="$1" cwd="$2"; shift 2
  ( cd "$cwd" && env -u WOOSTACK_ROOT "$@" bash -c \
      'source "$0"; printf "%s" "$WOOSTACK_ROOT"' "$resolver" )
}

# Build a throwaway git repo with a nested package subdir.
repo="$(mktemp -d)"
( cd "$repo" && git init -q )
toplevel="$(cd "$repo" && git rev-parse --show-toplevel)"
sub="$toplevel/packages/pkg"
mkdir -p "$sub"
ws="$(mktemp -d)"

for resolver in "$DIR/resolve-root.sh" "$ROOT/skills/woostack-address-comments/scripts/resolve-root.sh"; do
  tag="$(basename "$(dirname "$(dirname "$resolver")")")"  # skill dir name

  # (a) GITHUB_WORKSPACE wins even when cwd is inside a git repo.
  got="$(resolve "$resolver" "$sub" -u GITHUB_WORKSPACE GITHUB_WORKSPACE="$ws")"
  assert_eq "$got" "$ws" "[$tag] GITHUB_WORKSPACE wins over git toplevel"

  # (b) No GITHUB_WORKSPACE, inside a git subdir -> git toplevel.
  got="$(resolve "$resolver" "$sub" -u GITHUB_WORKSPACE)"
  assert_eq "$got" "$toplevel" "[$tag] git toplevel used from a subdir when GITHUB_WORKSPACE unset"

  # (c) Explicit WOOSTACK_ROOT override is honored above everything.
  got="$( cd "$sub" && env -u GITHUB_WORKSPACE WOOSTACK_ROOT=/custom/root \
            bash -c 'source "$0"; printf "%s" "$WOOSTACK_ROOT"' "$resolver" )"
  assert_eq "$got" "/custom/root" "[$tag] explicit WOOSTACK_ROOT override honored"
done

rm -rf "$repo" "$ws"
finish
