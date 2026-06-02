#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/memory-record.sh"

work="$(mktemp -d)"
pushd "$work" >/dev/null

# Scoped store present: write an individual note and rebuild MEMORY.md.
mkdir -p .woostack/memory
WOOSTACK_NOW=2026-06-02 PR_NUMBER=165 \
  LEARNING='.woostack/specs and .woostack/plans are tracked skill artifacts; do not flag them as stray.' \
  MEMORY_SCOPE='.woostack/specs/**,.woostack/plans/**' \
  bash "$SCRIPT" >/tmp/memory-record-1.out

note_count="$(find .woostack/memory -maxdepth 1 -type f -name '*.md' ! -name MEMORY.md | wc -l | tr -d ' ')"
assert_eq "$note_count" "1" "scoped store writes one note"
note="$(find .woostack/memory -maxdepth 1 -type f -name '*.md' ! -name MEMORY.md | head -1)"
assert_contains "$(cat "$note")" "type: convention" "note type defaults to convention"
assert_contains "$(cat "$note")" "scope: .woostack/specs/**,.woostack/plans/**" "note scope comes from MEMORY_SCOPE"
assert_contains "$(cat "$note")" "updated: 2026-06-02" "note updated uses WOOSTACK_NOW"
assert_contains "$(cat "$note")" "source: pr-165" "note source uses PR_NUMBER"
assert_contains "$(cat "$note")" "tracked skill artifacts" "note body contains learning"
assert_contains "$(cat .woostack/memory/MEMORY.md)" "tracked skill artifacts" "index rebuilt after scoped write"

# Re-running the same learning should not create a duplicate note.
WOOSTACK_NOW=2026-06-03 PR_NUMBER=165 \
  LEARNING='.woostack/specs and .woostack/plans are tracked skill artifacts; do not flag them as stray.' \
  MEMORY_SCOPE='.woostack/specs/**,.woostack/plans/**' \
  bash "$SCRIPT" >/tmp/memory-record-2.out
note_count="$(find .woostack/memory -maxdepth 1 -type f -name '*.md' ! -name MEMORY.md | wc -l | tr -d ' ')"
assert_eq "$note_count" "1" "scoped write dedupes existing learning"
assert_contains "$(cat /tmp/memory-record-2.out)" "already present" "duplicate scoped write reports skip"

popd >/dev/null
rm -rf "$work"

# No scoped store: fall back to the flat memory.md append path.
flat_work="$(mktemp -d)"
pushd "$flat_work" >/dev/null
WOOSTACK_NOW=2026-06-02 PR_NUMBER=166 \
  LEARNING='Flat fallback learning: accepted without scoped store.' \
  MEMORY_SCOPE='*' \
  bash "$SCRIPT" >/tmp/memory-record-flat.out
assert_contains "$(cat .woostack/memory.md)" "Flat fallback learning" "flat fallback writes memory.md"
assert_not_contains "$(find .woostack -maxdepth 2 -type f | sort)" ".woostack/memory/MEMORY.md" "flat fallback does not create scoped index"
popd >/dev/null
rm -rf "$flat_work"

finish
