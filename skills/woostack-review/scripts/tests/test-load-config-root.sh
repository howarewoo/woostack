#!/usr/bin/env bash
# Regression for issue #272: load-config must read .woostack/config.json from the
# git repo root, not the current working directory. Run it from a package subdir
# with GITHUB_WORKSPACE unset; a non-default severity_floor in the ROOT config
# must be honored (CWD-anchored code silently misses it and emits defaults).
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/load-config.sh"

repo="$(mktemp -d)"
( cd "$repo" && git init -q )
toplevel="$(cd "$repo" && git rev-parse --show-toplevel)"
sub="$toplevel/packages/pkg"
mkdir -p "$sub" "$toplevel/.woostack"
# Non-default value (loader default is severity_floor=high).
printf '%s\n' '{"review":{"severity_floor":"low"}}' > "$toplevel/.woostack/config.json"

out="$(mktemp -d)/out"
mkdir -p "$out"

( cd "$sub" && env -u GITHUB_WORKSPACE OUTDIR="$out" bash "$SCRIPT" ) >"$out/load-config-root.out" 2>&1

assert_eq "$(jq -r '.severity_floor' "$out/config.json")" "low" \
  "root .woostack/config.json honored from a subdir (not silent defaults)"

rm -rf "$repo" "$(dirname "$out")"
finish
