#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
PROMPT="$ROOT/skills/woostack-review/prompts/angles/acceptance.md"

text="$(cat "$PROMPT")"
assert_contains "$text" 'tier: standard' "acceptance uses standard tier"
assert_contains "$text" 'every explicit acceptance criterion' "worker evaluates every criterion"
assert_contains "$text" 'checked `[x]`' "worker verifies checked steps"
assert_contains "$text" 'A checked box is a claim to verify, never proof' "checked box is not accepted as proof"
assert_contains "$text" 'Unticked `[ ]` steps' "unticked steps are not completion claims"
assert_contains "$text" 'code/line reference' "worker validates artifact references"
assert_contains "$text" 'If `$OUTDIR/intent.md` is absent' "worker no-ops without intent"
assert_contains "$text" 'write `[]`' "no-intent fallback emits empty findings"
assert_contains "$text" 'only the defender validator' "defender owns deferral decisions"
assert_contains "$text" 'Never self-demote or suppress' "worker cannot trust deferral marker alone"
assert_contains "$text" 'RIGHT-side line' "worker uses post-patch anchors"
assert_contains "$text" 'resolve-diff-line.sh' "worker validates anchors"
assert_contains "$text" '"angle": "acceptance"' "worker emits acceptance schema value"
assert_contains "$text" 'deferred_to: null' "worker leaves deferred_to to defender"

finish
