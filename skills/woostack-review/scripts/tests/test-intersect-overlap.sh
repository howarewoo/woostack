#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/intersect-findings.sh"

work="$(mktemp -d)"
export OUTDIR="$work"

# Metrics on; defender-only (no prosecutor) keeps the fixture minimal — overlap
# is computed from raw_findings.json regardless of validator mode.
printf '%s\n' '{"metrics": true, "disable_adversarial": true}' > "$work/config.json"

# Raw set: one 3-angle cluster (bugs+security+types at foo.ts:42, same title),
# one solo finding (bugs at bar.ts:7), one UNANCHORED finding (no line) that
# must be excluded from overlap.
cat > "$work/raw_findings.json" <<'JSON'
[
  {"angle":"bugs","file":"foo.ts","line":42,"title":"Null deref on user","severity":"HIGH"},
  {"angle":"security","file":"foo.ts","line":42,"title":"Null deref on user","severity":"HIGH"},
  {"angle":"types","file":"foo.ts","line":42,"title":"Null deref on user","severity":"MEDIUM"},
  {"angle":"bugs","file":"bar.ts","line":7,"title":"Off by one","severity":"LOW"},
  {"angle":"security","file":"baz.ts","title":"Unanchored secret","severity":"HIGH"}
]
JSON

# Defender output is mandatory and becomes findings.json in defender-only mode.
cp "$work/raw_findings.json" "$work/findings.defender.json"

bash "$SCRIPT" >/tmp/intersect-overlap.out 2>&1

M="$work/findings.metrics.json"
assert_eq "$(test -f "$M" && echo yes || echo no)" "yes" "findings.metrics.json emitted"

# bugs co-occurs with security and types once each at foo.ts:42 → total 2.
assert_eq "$(jq -r '.angles.bugs.overlap_total' "$M")" "2" "bugs overlap_total == 2"
assert_eq "$(jq -r '.angles.bugs.overlap_with.security' "$M")" "1" "bugs overlaps security once"
assert_eq "$(jq -r '.angles.bugs.overlap_with.types' "$M")" "1" "bugs overlaps types once"

# security overlaps bugs + types; the unanchored baz.ts finding is excluded.
assert_eq "$(jq -r '.angles.security.overlap_total' "$M")" "2" "security overlap_total == 2"
assert_eq "$(jq -r '.angles.security.overlap_with | has("baz")' "$M")" "false" "no phantom angle key"

# types overlaps bugs + security.
assert_eq "$(jq -r '.angles.types.overlap_total' "$M")" "2" "types overlap_total == 2"

# The solo bugs finding at bar.ts adds no self-overlap; bugs map has exactly
# two keys (security, types).
assert_eq "$(jq -r '.angles.bugs.overlap_with | keys | length' "$M")" "2" "bugs overlap_with has 2 keys, no self"
assert_eq "$(jq -r '.angles.bugs.overlap_with | has("bugs")' "$M")" "false" "bugs never overlaps itself"

# schema_version of the per-run doc bumped to 3 (nit_count addition).
assert_eq "$(jq -r '.schema_version' "$M")" "3" "per-run metrics schema_version == 3"

rm -rf "$work"
finish
