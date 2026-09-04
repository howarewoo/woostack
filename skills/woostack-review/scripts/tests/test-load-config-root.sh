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
( cd "$repo" && git init -q && git config user.email test@example.com && git config user.name Test && git commit -q --allow-empty -m init )
toplevel="$(cd "$repo" && git rev-parse --show-toplevel)"
sub="$toplevel/packages/pkg"
mkdir -p "$sub" "$toplevel/.woostack"
# Non-default value (loader default is severity_floor=high).
printf '%s\n' '{"review":{"severity_floor":"low","nits":true}}' > "$toplevel/.woostack/config.json"
git -C "$toplevel" add .woostack/config.json && git -C "$toplevel" commit -qm "add config"

out="$(mktemp -d)/out"
mkdir -p "$out"

( cd "$sub" && env -u GITHUB_WORKSPACE OUTDIR="$out" bash "$SCRIPT" ) >"$out/load-config-root.out" 2>&1

assert_eq "$(jq -r '.severity_floor' "$out/config.json")" "low" \
  "root .woostack/config.json honored from a subdir (not silent defaults)"

# Local override honored from subdir
printf '%s\n' '{"review":{"severity_floor":"medium"}}' > "$toplevel/.woostack/config.local.json"
( cd "$sub" && env -u GITHUB_WORKSPACE OUTDIR="$out" bash "$SCRIPT" ) >"$out/load-config-root.out" 2>&1
assert_eq "$(jq -r '.severity_floor' "$out/config.json")" "medium" \
  "local config override honored from a subdir"
assert_eq "$(jq -r '.nits' "$out/config.json")" "true" \
  "sibling base review keys preserved during local merge"

# Linked worktree inherits primary checkout local config
wt="$(mktemp -d)/wt"
git -C "$toplevel" worktree add -q "$wt"
wt_sub="$wt/packages/pkg"
mkdir -p "$wt_sub"
( cd "$wt_sub" && env -u GITHUB_WORKSPACE OUTDIR="$out" bash "$SCRIPT" ) >"$out/load-config-root.out" 2>&1
assert_eq "$(jq -r '.severity_floor' "$out/config.json")" "medium" \
  "linked worktree inherits primary checkout local config"

# Both absent -> review retains defaults (severity_floor=high)
empty_repo="$(mktemp -d)"
( cd "$empty_repo" && git init -q )
empty_sub="$empty_repo/sub"
mkdir -p "$empty_sub"
( cd "$empty_sub" && env -u GITHUB_WORKSPACE OUTDIR="$out" bash "$SCRIPT" ) >"$out/load-config-root.out" 2>&1
assert_eq "$(jq -r '.severity_floor' "$out/config.json")" "high" \
  "both config files absent yields review defaults (severity_floor=high)"

# Empty base file -> review rejects empty base (fails with non-zero exit)
empty_cfg_repo="$(mktemp -d)"
mkdir -p "$empty_cfg_repo/.woostack"
: >"$empty_cfg_repo/.woostack/config.json"
set +e
( cd "$empty_cfg_repo" && env -u GITHUB_WORKSPACE OUTDIR="$out" bash "$SCRIPT" ) >"$out/load-config-empty.out" 2>"$out/load-config-empty.err"
rc=$?
set -e
assert_exit 1 "$rc" "empty base config fails review loader"
assert_contains "$(cat "$out/load-config-empty.err")" "::error file=.woostack/config.json::" "empty base config emits error annotation"

# Removed specialized angle names fail through the existing unknown-angle path.
invalid_cfg_root="$(mktemp -d)"
for angle in react types; do
  invalid_repo="$invalid_cfg_root/$angle"
  mkdir -p "$invalid_repo/.woostack"
  printf '{"review":{"angles":{"force":["%s"]}}}\n' "$angle" > "$invalid_repo/.woostack/config.json"
  set +e
  ( cd "$invalid_repo" && env -u GITHUB_WORKSPACE OUTDIR="$out" bash "$SCRIPT" ) \
    >"$out/load-config-$angle.out" 2>"$out/load-config-$angle.err"
  rc=$?
  set -e
  assert_exit 1 "$rc" "$angle angle is rejected"
  assert_contains "$(cat "$out/load-config-$angle.err")" "unknown angle(s): $angle" \
    "$angle rejection uses unknown-angle error"
done

rm -rf "$repo" "$wt" "$empty_repo" "$empty_cfg_repo" "$invalid_cfg_root" "$(dirname "$out")"
finish
