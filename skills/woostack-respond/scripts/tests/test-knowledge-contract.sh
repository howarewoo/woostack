#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/assert.sh"
ROOT="$(cd "$HERE/../../../.." && pwd)"
dream="$(cat "$ROOT/skills/woostack-dream/SKILL.md")"; wisdom="$(cat "$ROOT/skills/woostack-init/references/wisdom.md")"; memory="$(cat "$ROOT/site/content/docs/concepts/memory.mdx")"; build="$(cat "$ROOT/skills/woostack-init/scripts/build-index.sh")"
for phrase in 'specs/plans/fixes/respond' '.woostack/respond/*.md' '.woostack/respond/evidence/' 'One incident report alone' 'provenance-only' 'never appear on a prune list' '.woostack/respond'; do assert_contains "$dream" "$phrase" "dream response corpus contract includes $phrase"; done
for phrase in 'fixes,specs,plans,respond' 'respond/evidence/' '.woostack/respond/<file>.md' 'never enter `MEMORY.md`' 'One report alone cannot create wisdom'; do assert_contains "$wisdom" "$phrase" "wisdom response contract includes $phrase"; done
for phrase in 'decision evidence' 'third knowledge' 'never enter `MEMORY.md`' 'never pruned' 'respond/evidence/' 'one incident'; do assert_contains "$memory" "$phrase" "authored memory distinguishes $phrase"; done
assert_not_contains "$build" 'respond' "build-index remains memory-only"
finish
