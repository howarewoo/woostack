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
  printf '%s\n' 'Linear-Issue: APP-111' 'authoritative-issue-context: absent' > "$OUTDIR/attribution.md"
  printf '%s\n' '{"files":[{"path":"src/app.ts"}]}' > "$OUTDIR/meta.json"
  printf '%s\n' 'diff --git a/src/app.ts b/src/app.ts' > "$OUTDIR/diff.txt"
  printf '%s\n' '{"angles":{"force":[],"skip":[]},"severity_floor":"high"}' > "$OUTDIR/config.json"
}

setup
bash "$SCRIPT" >/dev/null
without="$(cat "$OUTDIR/angles.txt")"
assert_eq "$(grep -cx 'acceptance' "$OUTDIR/angles.txt" || true)" "0" "unverified attribution without intent omits acceptance"
rm -rf "$work"

setup
printf '%s\n' '## SOURCE: workflow://active-contract' 'Current approved contract' > "$OUTDIR/intent.md"
bash "$SCRIPT" >/dev/null
with="$(cat "$OUTDIR/angles.txt")"
assert_eq "$(grep -cx 'acceptance' "$OUTDIR/angles.txt" || true)" "1" "intent enables acceptance exactly once"
assert_eq "$(printf '%s\n' "$with" | grep -v '^acceptance$')" "$without" "acceptance gate leaves baseline angles unchanged"
rm -rf "$work"

assert_contains "$(cat "$DIR/load-config.sh")" '"acceptance"' "config angle enum includes acceptance"
assert_contains "$(cat "$ROOT/skills/woostack-review/prompts/_worker-header.md")" '**Current contract**' "worker header names the current contract"
assert_contains "$(cat "$ROOT/skills/woostack-review/prompts/_worker-header.md")" 'workflow://active-contract' "worker header permits artifact-free intent provenance"
assert_contains "$(cat "$ROOT/skills/woostack-review/prompts/_orchestrator-header.md")" 'gated on local parent-owned `intent.md` presence' "acceptance stays gated on parent-owned local intent"
assert_contains "$(cat "$ROOT/skills/woostack-review/prompts/_worker-header.md")" 'acceptance |' "worker schema includes acceptance"
assert_contains "$(cat "$ROOT/skills/woostack-review/prompts/_orchestrator-header.md")" '`acceptance`' "orchestrator registers acceptance"
assert_contains "$(cat "$ROOT/skills/woostack-review/prompts/_orchestrator-header.md")" '"acceptance"' "orchestrator schema/attribution includes acceptance"
assert_contains "$(cat "$ROOT/skills/woostack-review/SKILL.md")" 'multi-angle swarm pass' "skill documents one multi-angle pass"
assert_contains "$(cat "$ROOT/skills/woostack-review/prompts/anthropic.md")" 'acceptance' "Anthropic standard effort includes acceptance"

finish
