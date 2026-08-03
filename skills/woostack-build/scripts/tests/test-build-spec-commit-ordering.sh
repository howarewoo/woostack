#!/usr/bin/env bash
set -euo pipefail

# Legacy filename retained so existing test runners keep discovering the build ordering contract.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"

BUILD_SKILL="$ROOT/skills/woostack-build/SKILL.md"
PROCEDURE="$ROOT/skills/woostack-build/references/linear-procedure.md"
CONTEXT="$ROOT/skills/woostack-build/references/linear-context.md"
AUTHORITY="$ROOT/skills/woostack-init/references/artifact-backends.md"

assert_literal() { # file literal message
  local text
  text="$(cat "$1")"
  if [[ "$text" == *"$2"* ]]; then pass; else fail "$3"; fi
}

for file in "$BUILD_SKILL" "$PROCEDURE" "$CONTEXT" "$AUTHORITY"; do
  if [ -f "$file" ]; then pass; else fail "required build contract exists: ${file#"$ROOT/"}"; fi
done

assert_literal "$BUILD_SKILL" \
  'Resolve the exact supplied project or create exactly one project' \
  'build always resolves or creates its canonical project'
assert_literal "$BUILD_SKILL" \
  'Build has no artifact-free fallback' \
  'build has no artifact-free authority fallback'
assert_literal "$BUILD_SKILL" \
  'ideate and synchronize evolving project specification' \
  'build synchronizes material specification decisions'
assert_literal "$BUILD_SKILL" \
  'approve exact project-spec revision' \
  'project specification approval precedes planning'
assert_literal "$BUILD_SKILL" \
  'delegate candidate planning without provider mutation' \
  'build delegates candidate planning without provider writes'
assert_literal "$BUILD_SKILL" \
  'synchronize/read back direct issues and native dependencies' \
  'build synchronizes the direct issue graph'
assert_literal "$BUILD_SKILL" \
  'approve exact execution-plan revision set' \
  'execution-plan approval follows complete graph synchronization'
assert_literal "$BUILD_SKILL" \
  '## Exactly two hard gates' \
  'build has exactly two explicit gates'
assert_literal "$BUILD_SKILL" \
  'No implementation branch, worktree, commit, or PR may exist before' \
  'implementation stays behind exact Linear execution-plan approval'
assert_literal "$BUILD_SKILL" \
  'Build never merges' \
  'build never merges'

assert_literal "$PROCEDURE" \
  'one direct project issue per current increment' \
  'plan graph has one direct issue per increment'
assert_literal "$PROCEDURE" \
  'direct project membership and no parent/container relation' \
  'increment issues have no wrapper hierarchy'
assert_literal "$PROCEDURE" \
  'complete executor-ready issue descriptions' \
  'increment issues contain executable plans'
assert_literal "$PROCEDURE" \
  'Independently read the complete relation set back' \
  'native dependencies require complete read-back'
assert_literal "$CONTEXT" \
  'Gate 1 requires an independently read complete project snapshot' \
  'project approval binds an exact canonical revision'
assert_literal "$CONTEXT" \
  'Gate 2 requires complete exact issue fingerprints' \
  'execution approval binds the complete direct issue graph'
assert_literal "$AUTHORITY" \
  'Linear projects and issues are canonical product records for `woostack-build`' \
  'shared contract makes build records canonical'
assert_literal "$AUTHORITY" \
  'Graphite, and canonical GitHub reads prove source, ancestry, PR, review, and merge facts.' \
  'source-control truth remains separate'

finish
