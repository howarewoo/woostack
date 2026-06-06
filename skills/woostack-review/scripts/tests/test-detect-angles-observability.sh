#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/detect-angles.sh"

# setup $1 = a changed file path, $2 = one added (+) diff line
setup_diff() {
  work="$(mktemp -d)"
  export OUTDIR="$work/out"
  mkdir -p "$OUTDIR"
  printf '{"files":[{"path":"%s"}]}\n' "$1" > "$OUTDIR/meta.json"
  printf '%s\n' "$2" > "$OUTDIR/diff.txt"
}

# A production Mock/Fake/Stub fallback construction enables observability (silent-failure
# fallback that hides an outage behind synthetic data).
setup_diff "src/pay.ts" "+  if (!client) return new MockPaymentClient()"
bash "$SCRIPT" >/dev/null 2>&1
assert_contains "$(cat "$OUTDIR/angles.txt")" "observability" "mock/stub/fake fallback enables observability"
rm -rf "$work"

# Raw ?./?? must NOT broaden the trigger (it is pervasive in normal code; the suppressor
# check rides on the prompt when the angle already fires for another reason).
setup_diff "src/util.ts" '+  const name = user?.name ?? "anon"'
bash "$SCRIPT" >/dev/null 2>&1
assert_eq "$(grep -cx 'observability' "$OUTDIR/angles.txt" || true)" "0" "raw ?./?? does not enable observability"
rm -rf "$work"
