#!/usr/bin/env bash
# review-models-moved.sh — migration aid: model tiers moved from `review.models` to a
# top-level `models` field (clean break in woostack-review/scripts/load-config.sh).
# Diagnose-only: warns when a consumer config still nests models under `review`.
set -uo pipefail
emit() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"; }
command -v jq >/dev/null 2>&1 || exit 0
WOO_ROOT="${1:-.}"
CFG="$WOO_ROOT/.woostack/config.json"
[ -f "$CFG" ] || exit 0
has="$(jq -r 'try (.review.models != null) catch false' "$CFG" 2>/dev/null || echo false)"
if [ "$has" = "true" ]; then
  emit warn review-models-moved report ".woostack/config.json" \
    "review.models has moved to a top-level \`models\` field; move it out of \`review\` (see woostack-review SKILL.md)"
fi
