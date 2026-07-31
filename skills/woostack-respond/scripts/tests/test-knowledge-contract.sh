#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/assert.sh"
ROOT="$(cd "$HERE/../../../.." && pwd)"
dream="$(cat "$ROOT/skills/woostack-dream/SKILL.md")"
wisdom="$(cat "$ROOT/skills/woostack-init/references/wisdom.md")"
memory="$(cat "$ROOT/site/content/docs/concepts/memory.mdx")"
build="$(cat "$ROOT/skills/woostack-init/scripts/build-index.sh")"
dream_compact="$(printf '%s' "$dream" | tr '\n' ' ' | tr -s ' ')"
wisdom_compact="$(printf '%s' "$wisdom" | tr '\n' ' ' | tr -s ' ')"

for phrase in \
  'Sanitized `.woostack/respond/*.md` reports (excluding raw evidence)' \
  'non-authoritative evidence' \
  'records are development records protected by the loss-safe all-or-nothing migration boundary' \
  'They may corroborate a validated memory' \
  'cannot supply development authority' \
  'One diagnostic incident or remote artifact alone is insufficient.' \
  'delete only memory notes fully absorbed by an approved wisdom record.' \
  'Development resources, diagnostics,' \
  'overnight records, and documentation never appear on the prune list.'
do
  assert_contains "$dream_compact" "$phrase" "dream diagnostic-corroboration contract includes $phrase"
done

for phrase in \
  'specs/plans/fixes/respond' \
  'fixes,specs,plans,respond' \
  'tracked decision corpus' \
  'provenance-only'
do
  assert_not_contains "$dream" "$phrase" "dream excludes obsolete local development corpus contract $phrase"
done

for phrase in \
  'Raw `respond/evidence/` is excluded.' \
  'A single diagnostic report or remote artifact cannot establish generalized wisdom.' \
  '**Only fully absorbed `.woostack/memory/` notes are prunable.**'
do
  assert_contains "$wisdom_compact" "$phrase" "wisdom keeps diagnostic evidence bounded: $phrase"
done

assert_contains "$dream_compact" 'If `.woostack/overnight/` exists, stop before reading or deleting any file' "dream blocks on legacy overnight records without consuming them"
assert_not_contains "$wisdom" "overnight" "wisdom has no overnight-report corpus or lifecycle"
assert_not_contains "$(cat "$ROOT/skills/woostack-dream/evals/trigger-evals.json")" "overnight report" "dream trigger corpus has no retired report input"
assert_not_contains "$(cat "$ROOT/skills/woostack-status/evals/trigger-evals.json")" "overnight report" "status trigger corpus does not route retired reports to dream"

for phrase in \
  'One report or incident is never enough' \
  'Sanitized response reports never enter `MEMORY.md` and are never pruned as curation scratch.' \
  'Dream can read them as corroborating diagnostics; recall never reads them.'
do
  assert_contains "$memory" "$phrase" "authored memory keeps diagnostic evidence bounded: $phrase"
done

assert_not_contains "$build" 'respond' "build-index remains memory-only"
finish
