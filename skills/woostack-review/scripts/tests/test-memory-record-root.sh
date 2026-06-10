#!/usr/bin/env bash
# Regression for issue #272: memory-record must anchor its default MEMORY_DIR to
# the git repo root. With no MEMORY_DIR override, running from a package subdir
# (GITHUB_WORKSPACE unset) must write the scoped note under the ROOT .woostack/
# memory store — not create a stray .woostack/ inside the package.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/memory-record.sh"

repo="$(mktemp -d)"
( cd "$repo" && git init -q )
toplevel="$(cd "$repo" && git rev-parse --show-toplevel)"
sub="$toplevel/packages/pkg"
mkdir -p "$sub" "$toplevel/.woostack/memory"

note_count() { find "$toplevel/.woostack/memory" -maxdepth 1 -type f -name '*.md' ! -name MEMORY.md | wc -l | tr -d ' '; }
before="$(note_count)"

( cd "$sub" && env -u GITHUB_WORKSPACE \
    WOOSTACK_NOW=2026-06-09 \
    LEARNING='Issue #272 root anchoring: woostack paths resolve to the git toplevel.' \
    MEMORY_SCOPE='skills/**' \
    bash "$SCRIPT" ) >/tmp/memory-record-root.out 2>&1

after="$(note_count)"
assert_eq "$([ "$after" -gt "$before" ] && echo grew || echo same)" "grew" \
  "scoped note written under the ROOT .woostack/memory store"
assert_eq "$(test -e "$sub/.woostack" && echo yes || echo no)" "no" \
  "no .woostack/ polluting the package subdir"

rm -rf "$repo"
finish
