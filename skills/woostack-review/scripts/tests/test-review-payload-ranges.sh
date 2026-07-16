#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
HEADER="$ROOT/skills/woostack-review/prompts/_orchestrator-header.md"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/review"
printf 'Review body\n' > "$work/body.txt"
printf '[]\n' > "$work/review/prior-findings.json"
cat > "$work/review/findings.json" <<'JSON'
[
  {"angle":"bugs","file":"src/app.ts","line":2,"title":"Single anchor","description":"d","fix":"f","severity":"HIGH","blocking":false,"nit":false,"fix_type":"prose","suggestion":null},
  {"angle":"bugs","file":"src/app.ts","line":10,"end_line":12,"title":"Range anchor","description":"d","fix":"f","severity":"HIGH","blocking":false,"nit":false,"fix_type":"prose","suggestion":null},
  {"angle":"bugs","file":"src/app.ts","line":30,"title":"Degraded anchor","description":"d","fix":"f","severity":"HIGH","blocking":false,"nit":false,"fix_type":"prose","suggestion":null},
  {"angle":"bugs","file":"src/app.ts","line":40,"title":"Deferred finding","description":"d","fix":"f","severity":"LOW","blocking":false,"nit":true,"fix_type":"prose","suggestion":null,"deferred_to":"increment 4"}
]
JSON

python3 - "$HEADER" "$work/review" "$work/body.txt" > "$work/builder.py" <<'PY'
import sys

header_path, review_dir, body_path = sys.argv[1:4]
text = open(header_path).read()
start_marker = "python3 -c '\n"
end_marker = "\n' > /tmp/pr_review_payload.json"
start = text.index(start_marker) + len(start_marker)
end = text.index(end_marker, start)
code = text[start:end]
code = code.replace('/tmp/pr-review', review_dir)
code = code.replace('/tmp/pr_review_body.txt', body_path)
print(code)
PY

HEAD_SHA=deadbeef AUTH_LOGIN=reviewer PR_AUTHOR=author \
  python3 "$work/builder.py" > "$work/payload.json"

assert_eq "$(jq -c '.comments[0] | {path,line,side}' "$work/payload.json")" '{"path":"src/app.ts","line":2,"side":"RIGHT"}' "single anchor keeps the existing location object"
assert_eq "$(jq -r '.comments[0] | has("start_line") or has("start_side")' "$work/payload.json")" "false" "single anchor emits no range fields"
assert_eq "$(jq -c '.comments[1] | {path,start_line,start_side,line,side}' "$work/payload.json")" '{"path":"src/app.ts","start_line":10,"start_side":"RIGHT","line":12,"side":"RIGHT"}' "valid range maps to GitHub review fields"
assert_eq "$(jq -r '.comments[2] | has("start_line") or has("start_side")' "$work/payload.json")" "false" "degraded anchor emits no range fields"
assert_contains "$(jq -r '.comments[3].body' "$work/payload.json")" '_Deferred to increment 4; non-blocking._' "deferred finding keeps concise rendering"

expected_body='**Single anchor**

d

Fix: f

<sub>— <strong>HIGH</strong> · <code>bugs</code></sub>'
assert_eq "$(jq -r '.comments[0].body' "$work/payload.json")" "$expected_body" "inline finding renders the compact review format"

assert_contains "$(cat "$ROOT/skills/woostack-review/prompts/_worker-header.md")" 'end_line' "worker contract exposes optional range endpoint"
assert_contains "$(cat "$HEADER")" 'end_line' "orchestrator schema exposes optional range endpoint"
assert_contains "$(cat "$ROOT/skills/woostack-review/prompts/validator.md")" 'end_line' "defender preserves range endpoint"
assert_contains "$(cat "$ROOT/skills/woostack-review/prompts/validator-prosecutor.md")" 'end_line' "prosecutor preserves range endpoint"

finish
