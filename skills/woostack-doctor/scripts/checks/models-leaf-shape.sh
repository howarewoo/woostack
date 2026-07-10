#!/usr/bin/env bash
# models-leaf-shape.sh — validate every tier leaf under .models:
#   null (unset) | string | object-with-.model | nonempty array of
#   (string | object-with-.model)
# Arrays are ordered fallback lists (entry 0 = primary); an empty array, a
# malformed entry, or a non-object .models is a hard config error, never a
# silent fallback (spec 2026-07-10-tier-fallback-list AC3). Diagnose-only; no --fix.
set -uo pipefail
emit() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"; }
command -v jq >/dev/null 2>&1 || exit 0
WOO_ROOT="${1:-.}"
CFG="$WOO_ROOT/.woostack/config.json"
[ -f "$CFG" ] || exit 0

# Emit "path<TAB>problem" per bad leaf. Tier keys are fast|standard|deep; any
# other key under .models is a provider map whose values are tier leaves.
# Keys are sanitized (tab/newline -> space) to keep the 5-field TSV protocol
# intact for user-controlled key names. jq 1.5-safe: no IN().
problems="$(jq -r '
  def is_tier: . == "fast" or . == "standard" or . == "deep";
  def entry_ok: type == "string" or (type == "object" and has("model"));
  def leaf_problem:
    type as $t
    | if $t == "null" then empty
      elif $t == "string" then empty
      elif $t == "object" then (if has("model") then empty else "object missing .model" end)
      elif $t == "array" then
        (if length == 0 then "empty array"
         else ([.[] | select(entry_ok | not)] | if length > 0 then "entry must be a string or {model,...} (got \(.[0] | type))" else empty end)
         end)
      else "type \($t)"
      end;
  def clean: gsub("[\t\n]"; " ");
  if (.models // {}) | type != "object" then "models\tmust be an object (got \(.models | type))"
  else
    (.models // {}) | to_entries[]
    | if (.key | is_tier)
      then ["models.\(.key)", (.value | leaf_problem)]
      else .key as $p
        | (.value
           | if type == "object" then to_entries[] | ["models.\($p).\(.key)", (.value | leaf_problem)]
             elif type == "null" then empty
             else ["models.\($p)", "provider value is not an object"]
             end)
      end
    | select(.[1] != null)
    | "\(.[0] | clean)\t\(.[1] | clean)"
  end
' "$CFG" 2>/dev/null)"
rc=$?
if [ $rc -ne 0 ]; then
  emit error models-leaf-shape report ".woostack/config.json" \
    "config is not valid JSON or the models block is unreadable (jq exit $rc)"
  exit 0
fi

[ -n "$problems" ] || exit 0
while IFS=$'\t' read -r path problem; do
  [ -n "$path" ] || continue
  emit error models-leaf-shape report ".woostack/config.json" \
    "$path: $problem (leaf must be string, {model,...}, or nonempty array of those; arrays are ordered fallback lists)"
done <<EOF
$problems
EOF
