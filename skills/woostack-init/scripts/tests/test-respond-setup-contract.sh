#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/assert.sh"
skill="$(cat "$HERE/../../SKILL.md")"
memory="$(cat "$HERE/../../references/memory.md")"
respond="$(cat "$HERE/../../../woostack-respond/SKILL.md")"

for phrase in '--respond' '--no-respond' 'Set up production error response? [y/N]' 'dependencies' 'configuration filenames' 'instrumentation imports' 'environment-variable **names**' 'provider, environment, window, maximum groups, and remediation' 'Never read or print credential values' 'missing authentication is a warning' 'Semantically merge only accepted values' 'preserve every sibling and unknown top-level namespace' 'Under `--no-clobber`' '`--force`' 'hard error'; do
  assert_contains "$skill" "$phrase" "init response contract includes $phrase"
done
assert_contains "$skill" '| `.woostack/respond/.gitkeep` | `templates/respond/.gitkeep` |' "init maps response scaffold"
assert_contains "$memory" 'respond/evidence/' "memory layout names ignored evidence"
assert_contains "$memory" 'Sanitized response reports remain tracked' "memory layout keeps reports tracked"
assert_not_contains "$respond" 'woostack-defer(increment 2)' "increment 2 marker is removed"
assert_contains "$respond" 'woostack-defer(increment 3)' "increment 3 marker remains"
finish
