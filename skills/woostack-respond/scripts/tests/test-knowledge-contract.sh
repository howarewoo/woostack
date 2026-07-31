#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/assert.sh"
ROOT="$(cd "$HERE/../../../.." && pwd)"
dream="$(cat "$ROOT/skills/woostack-dream/SKILL.md")"
wisdom="$(cat "$ROOT/skills/woostack-init/references/wisdom.md")"
memory="$(cat "$ROOT/site/content/docs/concepts/memory.mdx")"
build="$(cat "$ROOT/skills/woostack-init/scripts/build-index.sh")"

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
  assert_contains "$dream" "$phrase" "dream diagnostic-corroboration contract includes $phrase"
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
  'A single incident report cannot establish' \
  '**Only scratch is prunable:** `.woostack/memory/` notes and `.woostack/overnight/` reports.'
do
  assert_contains "$wisdom" "$phrase" "wisdom keeps diagnostic evidence bounded: $phrase"
done

for phrase in \
  'one incident cannot establish generalized wisdom' \
  'Response reports never enter `MEMORY.md` and are never pruned.' \
  'dream and recall never read it.'
do
  assert_contains "$memory" "$phrase" "authored memory keeps diagnostic evidence bounded: $phrase"
done

assert_not_contains "$build" 'respond' "build-index remains memory-only"
finish
