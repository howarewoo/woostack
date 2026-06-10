#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/detect-stack.sh"

# setup $1 = headRefName of the PR under review; $2 = stack_aware ("true"/"false")
setup() {
  work="$(mktemp -d)"
  export OUTDIR="$work/out"
  mkdir -p "$OUTDIR"
  jq -n --arg h "$1" '{headRefName:$h, baseRefName:"main", title:"PR0", body:"", files:[]}' \
    > "$OUTDIR/meta.json"
  printf '{"stack_aware":%s}\n' "$2" > "$OUTDIR/config.json"
  export WOO_REVIEW_TEST_MODE=1
}

# A linear stack: feat-1 (under review) -> feat-2 (child) -> feat-3 (grandchild).
setup "feat-1" "true"
export WOO_REVIEW_FAKE_STACK_PRS_JSON='[
  {"number":225,"baseRefName":"feat-1","headRefName":"feat-2","title":"Increment 2","body":"wires call sites","files":[{"path":"skills/x/SKILL.md"},{"path":"x.ts"}]},
  {"number":226,"baseRefName":"feat-2","headRefName":"feat-3","title":"Increment 3","body":"adds enum","files":[{"path":"y.ts"}]},
  {"number":999,"baseRefName":"main","headRefName":"unrelated","title":"Other","body":"","files":[{"path":"z.ts"}]}
]'
export WOO_REVIEW_FAKE_STACK_DIFFS_JSON='{"225":"diff --git a/x.ts b/x.ts\n+wire()\n","226":"diff --git a/y.ts b/y.ts\n+enum()\n"}'
bash "$SCRIPT" >/tmp/detect-stack.out 2>&1
assert_contains "$(cat "$OUTDIR/stack.md")" "#225" "child 225 present"
assert_contains "$(cat "$OUTDIR/stack.md")" "#226" "grandchild 226 present"
assert_not_contains "$(cat "$OUTDIR/stack.md")" "#999" "unrelated PR absent"
assert_contains "$(cat "$OUTDIR/stack.md")" "+wire()" "child diff included"
rm -rf "$work"; unset WOO_REVIEW_FAKE_STACK_PRS_JSON WOO_REVIEW_FAKE_STACK_DIFFS_JSON

# Degraded diff: a matched descendant absent from the diffs map gets the degraded
# placeholder (AC3 error / AC4 error — never deferred against an unverified diff).
setup "feat-1" "true"
export WOO_REVIEW_FAKE_STACK_PRS_JSON='[{"number":225,"baseRefName":"feat-1","headRefName":"feat-2","title":"I2","body":"","files":[]}]'
export WOO_REVIEW_FAKE_STACK_DIFFS_JSON='{}'
bash "$SCRIPT" >/tmp/detect-stack.out 2>&1
assert_contains "$(cat "$OUTDIR/stack.md")" "degraded" "missing descendant diff -> degraded placeholder"
rm -rf "$work"; unset WOO_REVIEW_FAKE_STACK_PRS_JSON WOO_REVIEW_FAKE_STACK_DIFFS_JSON

# Off-switch: stack_aware:false -> no stack.md, no work.
setup "feat-1" "false"
export WOO_REVIEW_FAKE_STACK_PRS_JSON='[{"number":225,"baseRefName":"feat-1","headRefName":"feat-2","title":"x","body":"","files":[]}]'
bash "$SCRIPT" >/tmp/detect-stack.out 2>&1
assert_eq "$([ -f "$OUTDIR/stack.md" ] && echo yes || echo no)" "no" "off-switch writes no stack.md"
rm -rf "$work"; unset WOO_REVIEW_FAKE_STACK_PRS_JSON

# No descendants -> no stack.md.
setup "leaf" "true"
export WOO_REVIEW_FAKE_STACK_PRS_JSON='[{"number":225,"baseRefName":"main","headRefName":"other","title":"x","body":"","files":[]}]'
export WOO_REVIEW_FAKE_STACK_DIFFS_JSON='{}'
bash "$SCRIPT" >/tmp/detect-stack.out 2>&1
assert_eq "$([ -f "$OUTDIR/stack.md" ] && echo yes || echo no)" "no" "no descendants -> no stack.md"
rm -rf "$work"; unset WOO_REVIEW_FAKE_STACK_PRS_JSON WOO_REVIEW_FAKE_STACK_DIFFS_JSON

# Cycle guard: feat-1 -> feat-2 -> feat-1 (malformed) terminates without hanging.
setup "feat-1" "true"
export WOO_REVIEW_FAKE_STACK_PRS_JSON='[
  {"number":225,"baseRefName":"feat-1","headRefName":"feat-2","title":"A","body":"","files":[]},
  {"number":226,"baseRefName":"feat-2","headRefName":"feat-1","title":"B","body":"","files":[]}
]'
export WOO_REVIEW_FAKE_STACK_DIFFS_JSON='{"225":"d1","226":"d2"}'
bash "$SCRIPT" >/tmp/detect-stack.out 2>&1
assert_contains "$(cat "$OUTDIR/stack.md")" "#225" "cycle: 225 captured"
assert_eq "$(grep -c '^## #' "$OUTDIR/stack.md")" "2" "cycle: each PR appears once (no infinite loop)"
rm -rf "$work"; unset WOO_REVIEW_FAKE_STACK_PRS_JSON WOO_REVIEW_FAKE_STACK_DIFFS_JSON

# Depth cap: a chain longer than 10 stops at exactly 10 descendants (AC1 edge).
setup "b0" "true"
export WOO_REVIEW_FAKE_STACK_PRS_JSON="$(python3 -c 'import json; print(json.dumps([{"number":100+i,"baseRefName":"b%d"%i,"headRefName":"b%d"%(i+1),"title":"L%d"%i,"body":"","files":[]} for i in range(15)]))')"
export WOO_REVIEW_FAKE_STACK_DIFFS_JSON="$(python3 -c 'import json; print(json.dumps({str(100+i):"d" for i in range(15)}))')"
bash "$SCRIPT" >/tmp/detect-stack.out 2>&1
assert_eq "$(grep -c '^## #' "$OUTDIR/stack.md")" "10" "depth cap stops at 10 descendants"
rm -rf "$work"; unset WOO_REVIEW_FAKE_STACK_PRS_JSON WOO_REVIEW_FAKE_STACK_DIFFS_JSON

# CI refusal: fake hooks rejected when GITHUB_ACTIONS=true.
setup "feat-1" "true"
export GITHUB_ACTIONS=true
export WOO_REVIEW_FAKE_STACK_PRS_JSON='[]'
set +e
bash "$SCRIPT" >/tmp/detect-stack.out 2>&1
rc=$?
set -e
assert_eq "$([ "$rc" -ne 0 ] && echo nonzero || echo zero)" "nonzero" "fake hooks refused under GITHUB_ACTIONS"
unset GITHUB_ACTIONS WOO_REVIEW_FAKE_STACK_PRS_JSON
rm -rf "$work"

finish
