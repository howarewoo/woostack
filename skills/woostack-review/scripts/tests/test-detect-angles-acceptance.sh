#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/detect-angles.sh"

setup() {
  work="$(mktemp -d)"
  export OUTDIR="$work/out"
  mkdir -p "$OUTDIR"
  printf '%s\n' '{"files":[{"path":"src/app.ts"}]}' > "$OUTDIR/meta.json"
  printf '%s\n' 'diff --git a/src/app.ts b/src/app.ts' > "$OUTDIR/diff.txt"
  printf '%s\n' '{"angles":{"force":[],"skip":[]},"severity_floor":"high"}' > "$OUTDIR/config.json"
}

setup
bash "$SCRIPT" >/dev/null
without="$(cat "$OUTDIR/angles.txt")"
assert_eq "$(grep -cx 'acceptance' "$OUTDIR/angles.txt" || true)" "0" "no intent omits acceptance"
rm -rf "$work"

setup
printf '%s\n' '## SOURCE: .woostack/fixes/demo.md' > "$OUTDIR/intent.md"
bash "$SCRIPT" >/dev/null
with="$(cat "$OUTDIR/angles.txt")"
assert_eq "$(grep -cx 'acceptance' "$OUTDIR/angles.txt" || true)" "1" "intent enables acceptance exactly once"
assert_eq "$(printf '%s\n' "$with" | grep -v '^acceptance$')" "$without" "acceptance gate leaves baseline angles unchanged"
rm -rf "$work"

assert_contains "$(cat "$DIR/load-config.sh")" '"acceptance"' "config angle enum includes acceptance"
assert_contains "$(cat "$ROOT/skills/woostack-review/prompts/_worker-header.md")" '**Governing intent**' "worker header documents intent"
assert_contains "$(cat "$ROOT/skills/woostack-review/prompts/_worker-header.md")" 'acceptance |' "worker schema includes acceptance"
assert_contains "$(cat "$ROOT/skills/woostack-review/prompts/_orchestrator-header.md")" '`acceptance`' "orchestrator registers acceptance"
assert_contains "$(cat "$ROOT/skills/woostack-review/prompts/_orchestrator-header.md")" '"acceptance"' "orchestrator schema/attribution includes acceptance"
assert_contains "$(cat "$ROOT/skills/woostack-review/SKILL.md")" '`intent.md`' "skill documents intent artifact"
assert_contains "$(cat "$ROOT/skills/woostack-review/SKILL.md")" '`acceptance`' "skill documents acceptance angle"
assert_contains "$(cat "$ROOT/skills/woostack-review/prompts/anthropic.md")" 'acceptance' "Anthropic standard effort includes acceptance"

finish
