#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"

SKILL="$ROOT/skills/woostack-build/SKILL.md"
MARKDOWN_REF="$ROOT/skills/woostack-build/references/markdown-procedure.md"
LINEAR_REF="$ROOT/skills/woostack-build/references/linear-procedure.md"
ROOT_TEXT="$(cat "$SKILL")"

assert_matches() { # content regex message
  if grep -Eq -- "$2" <<< "$1"; then pass; else
    fail "$3"
    echo "    content does not match [$2]"
  fi
}

assert_ordered() { # content scope tokens...
  local content="$1" scope="$2" token rest
  shift 2
  rest="$content"
  for token in "$@"; do
    if [[ "$rest" == *"$token"* ]]; then
      rest="${rest#*"$token"}"
    else
      fail "$scope missing or misorders [$token]"
      return
    fi
  done
  pass
}

paragraph_for_href() { # file href
  awk -v href="$2" 'BEGIN { RS=""; ORS="\n" } index($0, href) { gsub(/[[:space:]]+/, " "); print }' "$1"
}

MARKDOWN=""
LINEAR=""
if [ -f "$MARKDOWN_REF" ]; then pass; MARKDOWN="$(cat "$MARKDOWN_REF")"; else fail 'direct reference exists: references/markdown-procedure.md'; fi
if [ -f "$LINEAR_REF" ]; then pass; LINEAR="$(cat "$LINEAR_REF")"; else fail 'direct reference exists: references/linear-procedure.md'; fi

# Root remains a useful orchestrator: resolve once, run the shared chain, expose
# the three approval barriers, terminal states, and the non-negotiable rules.
assert_matches "$ROOT_TEXT" '^## .*([Bb]ackend|[Rr]esol)' 'root retains backend resolution'
assert_matches "$ROOT_TEXT" 'resolve-backend\.sh.*<repo-root>' 'root retains the backend resolver argument contract'
assert_matches "$ROOT_TEXT" '^## .*[Ss]hared.*([Cc]hain|[Pp]rocedure)|^## (Procedure|Shared chain)$' 'root retains the shared chain'
assert_matches "$ROOT_TEXT" '^## Shared terminal states' 'root retains shared terminal states'
assert_matches "$ROOT_TEXT" '^## Hard constraints' 'root has a prominent Hard constraints section'
for gate in design-approval spec-approval execution-handoff; do
  assert_matches "$ROOT_TEXT" "${gate}|${gate//-/[ -]}" "root names the $gate barrier"
done
assert_matches "$ROOT_TEXT" 'silence is not (a yes|approval)|[Ss]ilence.*(does not|never).*([Aa]pprov|gate)' 'Hard constraints say silence is not approval'
assert_matches "$ROOT_TEXT" '[Ee]xactly three hard gates|three hard gates' 'Hard constraints retain exactly three gates'
assert_matches "$ROOT_TEXT" '[Nn]ever mix backends|Linear failure never falls back' 'Hard constraints prohibit backend mixing'

# Each backend is selected directly and conditionally from root; neither reader
# has to discover or traverse the other backend's procedure.
for reference in markdown-procedure.md linear-procedure.md; do
  href="(references/$reference)"
  context="$(paragraph_for_href "$SKILL" "$href")"
  if [ -n "$context" ]; then pass; else fail "root directly links exact href references/$reference"; continue; fi
  assert_matches "$context" '([Ww]hen|[Ii]f|[Oo]nly|[Rr]ead.*(when|for)|[Uu]se.*(when|for)|[Ss]elected)' "references/$reference link has meaningful when-to-read context"
  case "$reference" in
    markdown-procedure.md)
      assert_matches "$context" '[Mm]arkdown' 'Markdown reader is conditional on Markdown selection'
      assert_not_contains "$context" 'references/linear-procedure.md' 'Markdown reader does not select Linear procedure'
      ;;
    linear-procedure.md)
      assert_matches "$context" '[Ll]inear' 'Linear reader is conditional on Linear selection'
      assert_not_contains "$context" 'references/markdown-procedure.md' 'Linear reader does not select Markdown procedure'
      ;;
  esac
done
assert_not_contains "$ROOT_TEXT" 'Read both' 'root never requires both backend references'
assert_not_contains "$ROOT_TEXT" 'read both' 'root never requires both backend references (lowercase)'

root_lines="$(wc -l < "$SKILL" | tr -d ' ')"
if [ "$root_lines" -le 500 ]; then pass; else fail "root stays at or below approximately 500 lines (actual: $root_lines)"; fi

# Both direct references independently retain the same explicit, ordered gate
# barriers. Tags and comments make the barriers resistant to prose reshuffling.
for backend in markdown linear; do
  if [ "$backend" = markdown ]; then procedure="$MARKDOWN"; other=linear; else procedure="$LINEAR"; other=markdown; fi
  [ -n "$procedure" ] || continue
  assert_contains "$procedure" "<!-- $backend-gates: design-approval | spec-approval | execution-handoff -->" "$backend reference retains the ordered gate manifest"
  assert_ordered "$procedure" "$backend reference gate barriers" \
    "<HARD-GATE backend=\"$backend\" name=\"design-approval\">" '</HARD-GATE>' \
    "<HARD-GATE backend=\"$backend\" name=\"spec-approval\">" '</HARD-GATE>' \
    "<HARD-GATE backend=\"$backend\" name=\"execution-handoff\">" '</HARD-GATE>'
  count="$(grep -Ec "<HARD-GATE backend=\"$backend\" name=\"(design-approval|spec-approval|execution-handoff)\">" <<< "$procedure" || true)"
  assert_eq "$count" 3 "$backend reference has exactly three structural barriers"
  assert_not_contains "$procedure" "$other-procedure.md" "$backend reference does not nest the $other reader"
  assert_not_contains "$procedure" "backend=\"$other\"" "$backend reference contains no $other gate"
done

# The split moves content, not behavior: pin distinctive markers spanning the
# complete existing procedures, including ordering, handoff, and terminal work.
for token in \
  '.woostack/specs/YYYY-MM-DD-<slug>.md' \
  '`**Source:** [[specs/<basename>]]`' \
  'close the now-open PR' \
  'per-increment commit/review/distill cadence' \
  'terminal `status: done`' \
  'only the spec+plan PR is open (no increment PRs)' \
  'reviewed increment PR' \
  'morning report under'; do
  [ -z "$MARKDOWN" ] || assert_contains "$MARKDOWN" "$token" "Markdown procedure retains $token"
done
for token in \
  'linear.sh preflight' 'LINEAR_CONTEXT' 'LINEAR_TEAM_ID' \
  'linear.sh feature-resolve' 'linear.sh feature-create' \
  'linear.sh plan-reconcile' 'baseBranch' 'baseCommitSha' \
  'Explicit replan sequence' '--target planning --replan' \
  'linear.sh plan-read' 'linear.sh spec-read' 'linear.sh spec-write' \
  'designState: executionApproved' 'preserve the project/document audit history' \
  'root increment branches start from the frozen SHA'; do
  [ -z "$LINEAR" ] || assert_contains "$LINEAR" "$token" "Linear procedure retains $token"
done
if [ -n "$LINEAR" ]; then
  assert_not_contains "$LINEAR" 'git worktree add' 'Linear procedure has no Markdown worktree authoring'
  assert_not_contains "$LINEAR" 'gt create' 'Linear procedure has no docs-only Graphite authoring'
  assert_not_contains "$LINEAR" 'api.linear.app/graphql' 'Linear procedure uses adapters, not GraphQL'
  assert_not_contains "$LINEAR" 'query {' 'Linear procedure contains no raw GraphQL query'
  assert_not_contains "$LINEAR" 'mutation {' 'Linear procedure contains no raw GraphQL mutation'
fi

finish
