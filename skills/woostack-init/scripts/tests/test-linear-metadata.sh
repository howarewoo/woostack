#!/usr/bin/env bash
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$TEST_DIR/../artifacts/linear-metadata.py"
FIXTURES="$TEST_DIR/fixtures/linear"
# shellcheck disable=SC1091
source "$TEST_DIR/assert.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

run_metadata() {
  local input="$1"
  shift
  : >"$TMP/stdout"
  : >"$TMP/stderr"
  set +e
  python3 "$SCRIPT" "$@" <"$input" >"$TMP/stdout" 2>"$TMP/stderr"
  RUN_RC=$?
  set -e
  RUN_STDOUT="$(cat "$TMP/stdout")"
  RUN_STDERR="$(cat "$TMP/stderr")"
}

canonical='{"artifactType":"spec","projectId":"project-123","repository":"acme/widgets","schema":1,"state":"approved"}'
run_metadata "$FIXTURES/metadata-valid.md" parse --repository acme/widgets --project-id project-123
assert_exit 0 "$RUN_RC" "canonical managed metadata parses"
assert_eq "$RUN_STDOUT" "$canonical" "parse emits compact sorted canonical JSON"
assert_eq "$RUN_STDERR" "" "successful parse is quiet on stderr"

cat >"$TMP/linear-normalized.md" <<'EOF'
+++ Woostack metadata — managed, do not edit

{"artifactType":"spec","projectId":"project-123","repository":"acme/widgets","schema":1,"state":"approved"}

+++
EOF
run_metadata "$TMP/linear-normalized.md" parse --repository acme/widgets --project-id project-123
assert_exit 0 "$RUN_RC" "Linear-normalized managed metadata parses"
assert_eq "$RUN_STDOUT" "$canonical" "Linear-normalized parse emits canonical JSON"
printf '%b' '+++ Woostack metadata — managed, do not edit\r\n\r\n{"artifactType":"spec","projectId":"project-123","repository":"acme/widgets","schema":1,"state":"approved"}\r\n\r\n+++\r\n' >"$TMP/linear-normalized-crlf.md"
run_metadata "$TMP/linear-normalized-crlf.md" parse
assert_exit 0 "$RUN_RC" "CRLF Linear-normalized managed metadata parses"

autolink='[https://github.com/acme/widgets/pull/11](<https://github.com/acme/widgets/pull/11>)'
{
  printf '%s\n\n' '+++ Woostack metadata — managed, do not edit'
  jq -cnS --arg pr "$autolink" \
    '{artifactType:"increment",branch:"feature/eng-11",dependencies:[],gitParent:"main",incrementId:"track-a",ordinal:1,projectId:"project-123",pullRequest:$pr,repository:"acme/widgets",schema:1}'
  printf '\n%s\n' '+++'
} >"$TMP/autolink.md"
run_metadata "$TMP/autolink.md" parse --repository acme/widgets --project-id project-123
assert_exit 0 "$RUN_RC" "Linear PR autolink metadata parses"
assert_eq "$(jq -r '.pullRequest' <<<"$RUN_STDOUT")" \
  "https://github.com/acme/widgets/pull/11" \
  "Linear PR autolink metadata normalizes to the canonical repository URL"

printf '%s\n' '* first' '  + nested' >"$TMP/provider-markers.md"
printf '%s\n' '- first' '  - nested' >"$TMP/canonical-markers.md"
run_metadata "$TMP/provider-markers.md" compare \
  --expected-file "$TMP/canonical-markers.md" --observed-file "$TMP/provider-markers.md"
assert_exit 0 "$RUN_RC" "provider list-marker normalization compares equivalent"
printf '%s\n' '- different' >"$TMP/different-markers.md"
run_metadata "$TMP/provider-markers.md" compare \
  --expected-file "$TMP/different-markers.md" --observed-file "$TMP/provider-markers.md"
assert_exit 1 "$RUN_RC" "provider content comparison preserves semantic mismatches"
cat >"$TMP/literal-markers-expected.md" <<'EOF'
```text
- fenced
```
    - indented
~~~
- tilde fenced
~~~
EOF
cat >"$TMP/literal-markers-observed.md" <<'EOF'
```text
* fenced
```
    * indented
~~~
* tilde fenced
~~~
EOF
run_metadata "$TMP/literal-markers-observed.md" compare \
  --expected-file "$TMP/literal-markers-expected.md" \
  --observed-file "$TMP/literal-markers-observed.md"
assert_exit 1 "$RUN_RC" "provider normalization preserves fenced and indented code markers"
printf '%s\n' '- * *' >"$TMP/list-item-asterisks.md"
printf '%s\n' '* * *' >"$TMP/thematic-break.md"
run_metadata "$TMP/thematic-break.md" compare \
  --expected-file "$TMP/list-item-asterisks.md" --observed-file "$TMP/thematic-break.md"
assert_exit 1 "$RUN_RC" "provider normalization preserves thematic breaks"
for invalid_padding in \
  $'+++ Woostack metadata — managed, do not edit\n\n{"artifactType":"spec","projectId":"project-123","repository":"acme/widgets","schema":1}\n+++\n' \
  $'+++ Woostack metadata — managed, do not edit\n{"artifactType":"spec","projectId":"project-123","repository":"acme/widgets","schema":1}\n\n+++\n' \
  $'+++ Woostack metadata — managed, do not edit\n\n\n{"artifactType":"spec","projectId":"project-123","repository":"acme/widgets","schema":1}\n\n+++\n'; do
  printf '%s' "$invalid_padding" >"$TMP/invalid-padding.md"
  run_metadata "$TMP/invalid-padding.md" parse
  assert_exit 1 "$RUN_RC" "asymmetric or excessive metadata padding is rejected"
done

printf '%s\n' 'No managed metadata here. SECRET-HUMAN-CONTENT' >"$TMP/absent.md"
run_metadata "$TMP/absent.md" parse
assert_exit 1 "$RUN_RC" "absent metadata is rejected"
assert_not_contains "$RUN_STDERR" "SECRET-HUMAN-CONTENT" "absent-block error does not leak content"
assert_not_contains "$RUN_STDERR" "$TMP" "absent-block error does not leak a path"

run_metadata "$FIXTURES/metadata-duplicate.md" parse
assert_exit 1 "$RUN_RC" "duplicate managed metadata is rejected"
run_metadata "$FIXTURES/metadata-malformed.md" parse
assert_exit 1 "$RUN_RC" "malformed managed JSON is rejected"
assert_not_contains "$RUN_STDERR" "acme/widgets" "malformed-block error does not leak metadata"

cat >"$TMP/noncanonical.md" <<'EOF'
+++ Woostack metadata — managed, do not edit
{ "schema": 1, "repository": "acme/widgets", "projectId": "project-123", "artifactType": "spec" }
+++
EOF
run_metadata "$TMP/noncanonical.md" parse
assert_exit 1 "$RUN_RC" "noncanonical managed JSON is rejected"

python3 - "$FIXTURES/metadata-valid.md" "$TMP/unsupported.md" <<'PY'
from pathlib import Path
source = Path(__import__('sys').argv[1]).read_text(encoding='utf-8')
Path(__import__('sys').argv[2]).write_text(source.replace('"schema":1', '"schema":2'), encoding='utf-8')
PY
run_metadata "$TMP/unsupported.md" parse
assert_exit 1 "$RUN_RC" "unsupported schema is rejected"

run_metadata "$FIXTURES/metadata-valid.md" parse --repository other/repository
assert_exit 1 "$RUN_RC" "foreign repository metadata is rejected"
assert_not_contains "$RUN_STDERR" "other/repository" "ownership error does not echo expected repository"
assert_not_contains "$RUN_STDERR" "acme/widgets" "ownership error does not echo observed repository"
run_metadata "$FIXTURES/metadata-valid.md" parse --project-id foreign-project
assert_exit 1 "$RUN_RC" "foreign project metadata is rejected"
assert_not_contains "$RUN_STDERR" "foreign-project" "ownership error does not echo expected project"
assert_not_contains "$RUN_STDERR" "project-123" "ownership error does not echo observed project"

# Frozen execution base metadata is an all-or-nothing canonical immutable pair.
cat >"$TMP/frozen.md" <<'EOF'
+++ Woostack metadata — managed, do not edit
{"artifactType":"spec","baseBranch":"main","baseCommitSha":"0123456789abcdef0123456789abcdef01234567","designState":"ready","projectId":"project-123","repository":"acme/widgets","schema":1}
+++
EOF
run_metadata "$TMP/frozen.md" parse
assert_exit 0 "$RUN_RC" "canonical frozen base metadata parses"
cat >"$TMP/incomplete-frozen.md" <<'EOF'
+++ Woostack metadata — managed, do not edit
{"artifactType":"spec","baseBranch":"main","projectId":"project-123","repository":"acme/widgets","schema":1}
+++
EOF
run_metadata "$TMP/incomplete-frozen.md" parse
assert_exit 1 "$RUN_RC" "frozen base metadata requires branch and SHA together"
cat >"$TMP/invalid-frozen.md" <<'EOF'
+++ Woostack metadata — managed, do not edit
{"artifactType":"spec","baseBranch":"main","baseCommitSha":"not-a-git-sha","projectId":"project-123","repository":"acme/widgets","schema":1}
+++
EOF
run_metadata "$TMP/invalid-frozen.md" parse
assert_exit 1 "$RUN_RC" "frozen base commit requires a canonical 40-character SHA"
python3 - "$TMP" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
invalid = [
    "feature/a..b",
    "-topic",
    "feature/has space",
    "feature/~tilde",
    "feature/caret^",
    "feature/colon:",
    "feature/question?",
    "feature/star*",
    "feature/[x",
    "feature/back\\slash",
    "feature/trailing.",
    "feature/trailing/",
    "feature//empty",
    "feature/topic.lock",
    "feature/@{bad",
    "feature/./dot",
    ".hidden/topic",
    "@",
    "HEAD",
    "feature/control\u0001",
]
for index, branch in enumerate(invalid):
    metadata = {
        "artifactType": "spec",
        "baseBranch": branch,
        "baseCommitSha": "0123456789abcdef0123456789abcdef01234567",
        "designState": "ready",
        "projectId": "project-123",
        "repository": "acme/widgets",
        "schema": 1,
    }
    body = json.dumps(metadata, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    (root / f"invalid-branch-{index}.md").write_text(
        f"+++ Woostack metadata — managed, do not edit\n{body}\n+++\n",
        encoding="utf-8",
    )
valid = {
    "artifactType": "spec",
    "baseBranch": "feature/release-1.2_topic",
    "baseCommitSha": "0123456789abcdef0123456789abcdef01234567",
    "designState": "ready",
    "projectId": "project-123",
    "repository": "acme/widgets",
    "schema": 1,
}
(root / "valid-branch.md").write_text(
    "+++ Woostack metadata — managed, do not edit\n"
    + json.dumps(valid, sort_keys=True, separators=(",", ":"))
    + "\n+++\n",
    encoding="utf-8",
)
PY
for branch_fixture in "$TMP"/invalid-branch-*.md; do
  run_metadata "$branch_fixture" parse
  assert_exit 1 "$RUN_RC" "non-canonical frozen base branch is rejected"
done
run_metadata "$TMP/valid-branch.md" parse
assert_exit 0 "$RUN_RC" "canonical slash-separated Git branch is accepted"
python3 - "$TMP" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
for state in ("draft", "hardened", "approved", "planning", "ready"):
    current = {
        "artifactType": "spec",
        "designState": state,
        "projectId": "project-123",
        "repository": "acme/widgets",
        "schema": 1,
    }
    replacement = {
        **current,
        "baseBranch": "main",
        "baseCommitSha": "0123456789abcdef0123456789abcdef01234567",
    }
    body = json.dumps(current, sort_keys=True, separators=(",", ":"))
    (root / f"unfrozen-{state}.md").write_text(
        f"+++ Woostack metadata — managed, do not edit\n{body}\n+++\n",
        encoding="utf-8",
    )
    (root / f"freeze-{state}.json").write_text(
        json.dumps(replacement, sort_keys=True, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )
PY
for pre_ready_state in draft hardened approved planning; do
  run_metadata "$TMP/unfrozen-$pre_ready_state.md" replace \
    --metadata-file "$TMP/freeze-$pre_ready_state.json" --increment-evidence '[]'
  assert_exit 1 "$RUN_RC" "execution base cannot be inserted while designState is $pre_ready_state"
done
run_metadata "$TMP/unfrozen-ready.md" replace --metadata-file "$TMP/freeze-ready.json"
assert_exit 1 "$RUN_RC" "initial ready-state base freeze requires live evidence validation"
run_metadata "$TMP/unfrozen-ready.md" replace --metadata-file "$TMP/freeze-ready.json" \
  --increment-evidence '[{"branch":null,"pullRequest":null}]'
assert_exit 0 "$RUN_RC" "evidence-free ready-state base freeze is accepted"
run_metadata "$TMP/unfrozen-ready.md" replace --metadata-file "$TMP/freeze-ready.json" \
  --increment-evidence '[{"branch":"feature/increment","pullRequest":null}]'
assert_exit 1 "$RUN_RC" "implementation evidence blocks the initial ready-state base freeze"
cat >"$TMP/changed-frozen.json" <<'EOF'
{"artifactType":"spec","baseBranch":"main","baseCommitSha":"1123456789abcdef0123456789abcdef01234567","designState":"ready","projectId":"project-123","repository":"acme/widgets","schema":1}
EOF
run_metadata "$TMP/frozen.md" replace --metadata-file "$TMP/changed-frozen.json"
assert_exit 1 "$RUN_RC" "an accidental ready-to-ready base change is rejected"
cat >"$TMP/replanned-frozen.json" <<'EOF'
{"artifactType":"spec","baseBranch":"release/next","baseCommitSha":"2123456789abcdef0123456789abcdef01234567","designState":"planning","projectId":"project-123","repository":"acme/widgets","schema":1}
EOF
run_metadata "$TMP/frozen.md" replace --metadata-file "$TMP/replanned-frozen.json" \
  --increment-evidence '[{"branch":null,"pullRequest":null}]'
assert_exit 0 "$RUN_RC" "explicit ready-to-planning replan may change base before implementation evidence"
run_metadata "$TMP/frozen.md" replace --metadata-file "$TMP/replanned-frozen.json" \
  --increment-evidence '[{"branch":"feature/increment","pullRequest":null}]'
assert_exit 1 "$RUN_RC" "increment branch evidence makes the frozen base immutable"
run_metadata "$TMP/frozen.md" replace --metadata-file "$TMP/replanned-frozen.json" \
  --increment-evidence '[{"branch":"feature/increment","pullRequest":"https://github.com/acme/widgets/pull/1"}]'
assert_exit 1 "$RUN_RC" "increment pull-request evidence makes the frozen base immutable"
cat >"$TMP/approve-execution.json" <<'EOF'
{"artifactType":"spec","baseBranch":"main","baseCommitSha":"0123456789abcdef0123456789abcdef01234567","designState":"executionApproved","projectId":"project-123","repository":"acme/widgets","schema":1}
EOF
run_metadata "$TMP/frozen.md" replace --metadata-file "$TMP/approve-execution.json"
assert_exit 1 "$RUN_RC" "execution approval requires live increment evidence"
run_metadata "$TMP/frozen.md" replace --metadata-file "$TMP/approve-execution.json" \
  --increment-evidence '[]'
assert_exit 0 "$RUN_RC" "execution approval succeeds before implementation evidence"
run_metadata "$TMP/frozen.md" replace --metadata-file "$TMP/approve-execution.json" \
  --increment-evidence '[{"branch":"feature/increment","pullRequest":null}]'
assert_exit 1 "$RUN_RC" "execution approval fails after implementation branch evidence"
cat >"$TMP/execution-approved.md" <<'EOF'
+++ Woostack metadata — managed, do not edit
{"artifactType":"spec","baseBranch":"main","baseCommitSha":"0123456789abcdef0123456789abcdef01234567","designState":"executionApproved","projectId":"project-123","repository":"acme/widgets","schema":1}
+++
EOF
run_metadata "$TMP/execution-approved.md" replace --metadata-file "$TMP/replanned-frozen.json" \
  --increment-evidence '[]'
assert_exit 1 "$RUN_RC" "execution approval makes the frozen base immutable without Git evidence"
# Canonical design lifecycle permits only adjacent forward moves, explicit replan, and abandon.
python3 - "$TMP" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
states = {
    "draft",
    "hardened",
    "approved",
    "planning",
    "ready",
    "executionApproved",
    "executing",
    "inReview",
    "done",
    "abandoned",
}
for state in states:
    metadata = {
        "artifactType": "spec",
        "designState": state,
        "projectId": "project-123",
        "repository": "acme/widgets",
        "schema": 1,
    }
    body = json.dumps(metadata, sort_keys=True, separators=(",", ":"))
    (root / f"lifecycle-{state}.md").write_text(
        f"+++ Woostack metadata — managed, do not edit\n{body}\n+++\n",
        encoding="utf-8",
    )
    (root / f"lifecycle-{state}.json").write_text(body + "\n", encoding="utf-8")
PY
cat >"$TMP/lifecycle-ready-frozen.md" <<'EOF'
+++ Woostack metadata — managed, do not edit
{"artifactType":"spec","baseBranch":"main","baseCommitSha":"0123456789abcdef0123456789abcdef01234567","designState":"ready","projectId":"project-123","repository":"acme/widgets","schema":1}
+++
EOF
cat >"$TMP/lifecycle-executionApproved-frozen.json" <<'EOF'
{"artifactType":"spec","baseBranch":"main","baseCommitSha":"0123456789abcdef0123456789abcdef01234567","designState":"executionApproved","projectId":"project-123","repository":"acme/widgets","schema":1}
EOF
cat >"$TMP/lifecycle-legacy.md" <<'EOF'
+++ Woostack metadata — managed, do not edit
{"artifactType":"spec","projectId":"project-123","repository":"acme/widgets","schema":1}
+++
EOF
run_metadata "$TMP/lifecycle-legacy.md" replace \
  --metadata-file "$TMP/lifecycle-draft.json"
assert_exit 0 "$RUN_RC" "legacy lifecycle initializes at draft"
for invalid_initial_state in hardened approved planning ready executionApproved executing inReview "done" abandoned; do
  run_metadata "$TMP/lifecycle-legacy.md" replace \
    --metadata-file "$TMP/lifecycle-$invalid_initial_state.json"
  assert_exit 1 "$RUN_RC" "legacy lifecycle cannot initialize at $invalid_initial_state"
done
for transition in \
  draft:hardened hardened:approved approved:planning planning:ready \
  executionApproved:executing executing:inReview inReview:done; do
  current_state="${transition%%:*}"
  replacement_state="${transition#*:}"
  run_metadata "$TMP/lifecycle-$current_state.md" replace \
    --metadata-file "$TMP/lifecycle-$replacement_state.json"
  assert_exit 0 "$RUN_RC" "adjacent canonical design lifecycle transition succeeds"
done
run_metadata "$TMP/lifecycle-ready.md" replace \
  --metadata-file "$TMP/lifecycle-ready.json"
assert_exit 0 "$RUN_RC" "same-state design lifecycle replacement is idempotent"
run_metadata "$TMP/lifecycle-ready.md" replace \
  --metadata-file "$TMP/lifecycle-executionApproved.json" --increment-evidence '[]'
assert_exit 1 "$RUN_RC" "execution approval requires the frozen base pair"
run_metadata "$TMP/lifecycle-ready-frozen.md" replace \
  --metadata-file "$TMP/lifecycle-executionApproved-frozen.json" --increment-evidence '[]'
assert_exit 0 "$RUN_RC" "evidence-free execution approval with a frozen base is a canonical forward transition"
run_metadata "$TMP/lifecycle-ready.md" replace \
  --metadata-file "$TMP/lifecycle-planning.json" --increment-evidence '[]'
assert_exit 0 "$RUN_RC" "evidence-free ready-to-planning replan is explicitly allowed"
for abandon_source in draft hardened approved planning ready executionApproved executing inReview; do
  run_metadata "$TMP/lifecycle-$abandon_source.md" replace \
    --metadata-file "$TMP/lifecycle-abandoned.json"
  assert_exit 0 "$RUN_RC" "active design lifecycle may explicitly abandon"
done
for transition in \
  ready:draft planning:approved draft:ready hardened:planning approved:ready \
  executing:ready inReview:executing done:abandoned abandoned:draft; do
  current_state="${transition%%:*}"
  replacement_state="${transition#*:}"
  run_metadata "$TMP/lifecycle-$current_state.md" replace \
    --metadata-file "$TMP/lifecycle-$replacement_state.json" --increment-evidence '[]'
  assert_exit 1 "$RUN_RC" "non-canonical design lifecycle jump is rejected"
done

cat >"$TMP/replacement.json" <<'EOF'
{"state":"hardened","schema":1,"repository":"acme/widgets","projectId":"project-123","artifactType":"spec","label":"Crème 東京"}
EOF
run_metadata "$FIXTURES/metadata-valid.md" replace --metadata-file "$TMP/replacement.json" --repository acme/widgets --project-id project-123
assert_exit 0 "$RUN_RC" "managed metadata can be replaced"
cp "$TMP/stdout" "$TMP/replaced.md"
run_metadata "$TMP/replaced.md" parse --repository acme/widgets --project-id project-123
assert_exit 0 "$RUN_RC" "replacement remains parseable"
assert_eq "$RUN_STDOUT" '{"artifactType":"spec","label":"Crème 東京","projectId":"project-123","repository":"acme/widgets","schema":1,"state":"hardened"}' "replacement sorts keys and preserves Unicode"
python3 - "$FIXTURES/metadata-valid.md" "$TMP/replaced.md" >"$TMP/outside-check" <<'PY'
from pathlib import Path
import re, sys
marker = r'^\+\+\+ Woostack metadata — managed, do not edit\r?\n.*?^\+\+\+(?:\r?\n|$)'
def outside(path):
    text = Path(path).read_text(encoding='utf-8')
    match = re.search(marker, text, re.MULTILINE | re.DOTALL)
    return text[:match.start()] + '\0' + text[match.end():]
print('yes' if outside(sys.argv[1]) == outside(sys.argv[2]) else 'no')
PY
assert_eq "$(cat "$TMP/outside-check")" "yes" "replace preserves every character outside the managed section"

run_metadata "$FIXTURES/metadata-valid.md" revision --updated-at 2026-07-12T12:00:00.000Z
assert_exit 0 "$RUN_RC" "revision is generated"
REVISION="$RUN_STDOUT"
assert_contains "$REVISION" '"contentHash":"' "revision contains a content hash"
assert_contains "$REVISION" '"updatedAt":"2026-07-12T12:00:00.000Z"' "revision contains updatedAt"
run_metadata "$FIXTURES/metadata-valid.md" replace --metadata-file "$TMP/replacement.json" --repository acme/widgets --project-id project-123 --expected-revision "$REVISION" --updated-at 2026-07-12T12:00:00.000Z
assert_exit 0 "$RUN_RC" "matching optimistic revision permits replacement"
run_metadata "$FIXTURES/metadata-valid.md" replace --metadata-file "$TMP/replacement.json" --expected-revision "$REVISION" --updated-at 2026-07-12T12:00:01.000Z
assert_exit 1 "$RUN_RC" "changed updatedAt rejects replacement"
assert_not_contains "$RUN_STDERR" "2026-07-12" "revision error does not leak revision values"
cp "$FIXTURES/metadata-valid.md" "$TMP/changed.md"
printf '\nConcurrent edit' >>"$TMP/changed.md"
run_metadata "$TMP/changed.md" replace --metadata-file "$TMP/replacement.json" --expected-revision "$REVISION" --updated-at 2026-07-12T12:00:00.000Z
assert_exit 1 "$RUN_RC" "changed content hash rejects replacement"
assert_contains "$RUN_STDERR" "optimistic revision mismatch" "changed content hash is classified as an optimistic revision mismatch"
assert_not_contains "$RUN_STDERR" "Concurrent edit" "revision error does not leak content"

cat >"$TMP/feature.json" <<'EOF'
{"backend":"linear","feature":{"baseBranch":"main","baseCommitSha":"0123456789abcdef0123456789abcdef01234567","id":"project-123","status":"ready","title":"Unicode 東京","url":"https://linear.app/acme/project/example"},"increments":[{"branch":null,"content":"One","dependencies":[],"id":"issue-1","identifier":"ENG-1","ordinal":1,"pullRequest":null,"status":"planned"},{"branch":"feature/two","content":"Two","dependencies":["issue-1"],"id":"issue-2","identifier":"ENG-2","ordinal":2,"pullRequest":null,"status":"executing"}],"spec":{"content":"Spec","id":"document-1","revision":{"contentHash":"0000000000000000000000000000000000000000000000000000000000000000","updatedAt":"2026-07-12T12:00:00.000Z"},"url":"https://linear.app/acme/document/example"}}
EOF
run_metadata "$TMP/feature.json" validate-feature --project-id project-123
assert_exit 0 "$RUN_RC" "valid normalized Linear feature passes validation"
assert_eq "$RUN_STDOUT" "" "feature validation emits no data"
jq '.feature.baseBranch="HEAD"' "$TMP/feature.json" >"$TMP/invalid-feature-branch.json"
run_metadata "$TMP/invalid-feature-branch.json" validate-feature --project-id project-123
assert_exit 1 "$RUN_RC" "normalized feature rejects Git's reserved HEAD branch"

python3 - "$TMP/feature.json" "$TMP/bad-feature.json" <<'PY'
from pathlib import Path
import json, sys
value = json.loads(Path(sys.argv[1]).read_text())
value['increments'][1]['ordinal'] = 1
value['increments'][0]['dependencies'] = ['issue-2']
Path(sys.argv[2]).write_text(json.dumps(value), encoding='utf-8')
PY
run_metadata "$TMP/bad-feature.json" validate-feature --project-id project-123
assert_exit 1 "$RUN_RC" "duplicate ordinals and dependency cycle are rejected"
run_metadata "$TMP/feature.json" validate-feature --project-id foreign-project
assert_exit 1 "$RUN_RC" "normalized feature with a foreign project is rejected"
assert_not_contains "$RUN_STDERR" "foreign-project" "feature ownership error is identifier-safe"

# Replacement identity is immutable even when repository ownership still matches.
cat >"$TMP/increment.md" <<'EOF'
+++ Woostack metadata — managed, do not edit
{"artifactType":"increment","dependencies":[],"gitParent":"main","incrementId":"increment-1","ordinal":1,"projectId":"project-123","repository":"acme/widgets","schema":1}
+++
EOF
cat >"$TMP/increment-other-id.json" <<'EOF'
{"artifactType":"increment","dependencies":[],"gitParent":"main","incrementId":"increment-2","ordinal":1,"projectId":"project-123","repository":"acme/widgets","schema":1}
EOF
run_metadata "$TMP/increment.md" replace --metadata-file "$TMP/increment-other-id.json"
assert_exit 1 "$RUN_RC" "replace rejects a changed stable increment ID"
cat >"$TMP/changed-artifact-type.json" <<'EOF'
{"artifactType":"spec","projectId":"project-123","repository":"acme/widgets","schema":1}
EOF
run_metadata "$FIXTURES/metadata-valid.md" replace --metadata-file "$TMP/increment-other-id.json"
assert_exit 1 "$RUN_RC" "replace rejects a changed artifact type"

# JSON hardening applies recursively to every command input.
cat >"$TMP/nested-duplicate.md" <<'EOF'
+++ Woostack metadata — managed, do not edit
{"artifactType":"spec","extra":{"same":1,"same":2},"projectId":"project-123","repository":"acme/widgets","schema":1}
+++
EOF
run_metadata "$TMP/nested-duplicate.md" parse
assert_exit 1 "$RUN_RC" "duplicate keys in nested objects are rejected"
cat >"$TMP/nonfinite.md" <<'EOF'
+++ Woostack metadata — managed, do not edit
{"artifactType":"spec","number":NaN,"projectId":"project-123","repository":"acme/widgets","schema":1}
+++
EOF
run_metadata "$TMP/nonfinite.md" parse
assert_exit 1 "$RUN_RC" "nonfinite JSON constants are rejected"
cat >"$TMP/overflow.md" <<'EOF'
+++ Woostack metadata — managed, do not edit
{"artifactType":"spec","number":1e400,"projectId":"project-123","repository":"acme/widgets","schema":1}
+++
EOF
run_metadata "$TMP/overflow.md" parse
assert_exit 1 "$RUN_RC" "overflowing JSON floats are rejected"
cat >"$TMP/schema-type.md" <<'EOF'
+++ Woostack metadata — managed, do not edit
{"artifactType":"spec","projectId":"project-123","repository":"acme/widgets","schema":[]}
+++
EOF
run_metadata "$TMP/schema-type.md" parse
assert_exit 1 "$RUN_RC" "wrong schema field types are rejected safely"
assert_not_contains "$RUN_STDERR" "Traceback" "wrong schema type does not escape a traceback"
cat >"$TMP/artifact-type.md" <<'EOF'
+++ Woostack metadata — managed, do not edit
{"artifactType":[],"projectId":"project-123","repository":"acme/widgets","schema":1}
+++
EOF
run_metadata "$TMP/artifact-type.md" parse
assert_exit 1 "$RUN_RC" "wrong artifact field types are rejected safely"
printf '%b' '+++ Woostack metadata — managed, do not edit\n{"artifactType":"spec","projectId":"project-123","repository":"acme/widgets","schema":1}\n+++\n\xff' >"$TMP/invalid-utf8.md"
run_metadata "$TMP/invalid-utf8.md" parse
assert_exit 1 "$RUN_RC" "invalid UTF-8 input is rejected"
assert_not_contains "$RUN_STDERR" "$TMP" "invalid UTF-8 error is path-safe"
cat >"$TMP/surrogate.md" <<'EOF'
+++ Woostack metadata — managed, do not edit
{"artifactType":"spec","label":"\ud800","projectId":"project-123","repository":"acme/widgets","schema":1}
+++
EOF
run_metadata "$TMP/surrogate.md" parse
assert_exit 1 "$RUN_RC" "lone Unicode surrogates are rejected without a crash"
assert_not_contains "$RUN_STDERR" "Traceback" "lone surrogate error has no traceback"
run_metadata "$FIXTURES/metadata-valid.md" replace --metadata-file "$TMP/replacement.json" --expected-revision '[]' --updated-at now
assert_exit 1 "$RUN_RC" "malformed revision shape is rejected"
assert_not_contains "$RUN_STDERR" "$FIXTURES" "malformed revision error is path-safe"
run_metadata "$FIXTURES/metadata-valid.md" replace --metadata-file "$TMP/replacement.json" --expected-revision '{"contentHash":123,"updatedAt":[]}' --updated-at now
assert_exit 1 "$RUN_RC" "wrong revision field types are rejected"
cat >"$TMP/nonfinite-replacement.json" <<'EOF'
{"artifactType":"spec","number":Infinity,"projectId":"project-123","repository":"acme/widgets","schema":1}
EOF
run_metadata "$FIXTURES/metadata-valid.md" replace --metadata-file "$TMP/nonfinite-replacement.json"
assert_exit 1 "$RUN_RC" "replace rejects nonfinite replacement JSON"
run_metadata "$FIXTURES/metadata-valid.md" replace --metadata-file "$TMP/replacement.json" --expected-revision '{"contentHash":NaN,"updatedAt":"now"}' --updated-at now
assert_exit 1 "$RUN_RC" "revision validation rejects nonfinite JSON"
python3 - "$TMP/feature.json" "$TMP/nonfinite-feature.json" <<'PY'
from pathlib import Path
import sys
value = Path(sys.argv[1]).read_text().rstrip()
Path(sys.argv[2]).write_text(value[:-1] + ',"extra":1e400}', encoding='utf-8')
PY
run_metadata "$TMP/nonfinite-feature.json" validate-feature
assert_exit 1 "$RUN_RC" "feature validation rejects overflowing JSON numbers"


# Byte-for-byte replacement fixtures cover line-ending and final-newline boundaries.
python3 - "$TMP" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
old = b'{"artifactType":"spec","projectId":"project-123","repository":"acme/widgets","schema":1,"state":"approved"}'
new = '{"artifactType":"spec","label":"Crème 東京","projectId":"project-123","repository":"acme/widgets","schema":1,"state":"hardened"}'.encode()
header = "+++ Woostack metadata — managed, do not edit".encode()
variants = {
    "lf": (b"before\n\n", b"\n", b"\n", b"\n", b"\nafter\n"),
    "crlf": (b"before\r\n\r\n", b"\r\n", b"\r\n", b"\r\n", b"\r\nafter\r\n"),
    "normalized-lf": (b"before\n\n", b"\n", b"\n", b"\n", b"\nafter\n"),
    "normalized-crlf": (b"before\r\n\r\n", b"\r\n", b"\r\n", b"\r\n", b"\r\nafter\r\n"),
    "mixed": (b"before\r\n", b"\n", b"\n", b"\r\n", b"after\n"),
    "no-final-newline": (b"before\n", b"\n", b"\n", b"", b""),
    "unicode": ("préface 東京\n".encode(), b"\n", b"\n", b"\n", "\nfin naïve 🚀\n".encode()),
}
normalized_inputs = {"normalized-lf", "normalized-crlf"}
for name, (prefix, header_nl, body_nl, closer_nl, suffix) in variants.items():
    source_padding = name in normalized_inputs
    source = prefix + header + header_nl + (header_nl if source_padding else b"") + old + body_nl + (body_nl if source_padding else b"") + b"+++" + closer_nl + suffix
    expected = prefix + header + header_nl + header_nl + new + body_nl + body_nl + b"+++" + closer_nl + suffix
    (root / f"bytes-{name}.md").write_bytes(source)
    (root / f"bytes-{name}.expected").write_bytes(expected)
PY

check_byte_variant() {
  local name="$1"
  set +e
  python3 "$SCRIPT" replace --metadata-file "$TMP/replacement.json" <"$TMP/bytes-$name.md" >"$TMP/bytes-$name.actual" 2>"$TMP/bytes-$name.stderr"
  local rc=$?
  set -e
  if [ "$rc" -eq 0 ] && cmp -s "$TMP/bytes-$name.expected" "$TMP/bytes-$name.actual"; then
    pass
  else
    fail "$name replacement changes bytes outside only the JSON body"
  fi
}
check_byte_variant lf
check_byte_variant crlf
check_byte_variant normalized-lf
check_byte_variant normalized-crlf
check_byte_variant mixed
check_byte_variant no-final-newline
check_byte_variant unicode

# Generate isolated normalized-model dependency cases, including a recursion-depth stress case.
python3 - "$TMP/feature.json" "$TMP" <<'PY'
from pathlib import Path
import copy, json, sys

base = json.loads(Path(sys.argv[1]).read_text())
root = Path(sys.argv[2])
def save(name, value):
    (root / f"feature-{name}.json").write_text(json.dumps(value), encoding="utf-8")

forward = copy.deepcopy(base)
forward["increments"][0]["dependencies"] = ["issue-2"]
save("forward", forward)
self_dependency = copy.deepcopy(base)
self_dependency["increments"][0]["dependencies"] = ["issue-1"]
save("self", self_dependency)
unknown = copy.deepcopy(base)
unknown["increments"][1]["dependencies"] = ["issue-missing"]
save("unknown", unknown)
duplicate = copy.deepcopy(base)
duplicate["increments"][1]["dependencies"] = ["issue-1", "issue-1"]
save("duplicate-dependency", duplicate)
cycle = copy.deepcopy(base)
cycle["increments"][0]["dependencies"] = ["issue-2"]
cycle["increments"][1]["dependencies"] = ["issue-1"]
save("cycle", cycle)
wrong_type = copy.deepcopy(base)
wrong_type["feature"]["status"] = []
save("wrong-type", wrong_type)
disconnected = copy.deepcopy(base)
disconnected["increments"].append({
    "branch": None, "content": "Three", "dependencies": [], "id": "issue-3",
    "identifier": "ENG-3", "ordinal": 3, "pullRequest": None, "status": "planned",
})
save("disconnected", disconnected)
long_graph = copy.deepcopy(base)
long_graph["increments"] = []
for number in range(1, 1101):
    long_graph["increments"].append({
        "branch": None,
        "content": f"Increment {number}",
        "dependencies": [] if number == 1 else [f"issue-{number - 1}"],
        "id": f"issue-{number}",
        "identifier": f"ENG-{number}",
        "ordinal": number,
        "pullRequest": None,
        "status": "planned",
    })
save("long-chain", long_graph)
PY
run_metadata "$TMP/feature-forward.json" validate-feature
assert_exit 1 "$RUN_RC" "forward dependencies are rejected"
run_metadata "$TMP/feature-self.json" validate-feature
assert_exit 1 "$RUN_RC" "self-dependencies are rejected"
run_metadata "$TMP/feature-unknown.json" validate-feature
assert_exit 1 "$RUN_RC" "unknown dependencies are rejected"
run_metadata "$TMP/feature-duplicate-dependency.json" validate-feature
assert_exit 1 "$RUN_RC" "duplicate dependencies are rejected"
run_metadata "$TMP/feature-cycle.json" validate-feature
assert_exit 1 "$RUN_RC" "dependency cycles are rejected"
run_metadata "$TMP/feature-wrong-type.json" validate-feature
assert_exit 1 "$RUN_RC" "wrong normalized field types are rejected safely"
assert_not_contains "$RUN_STDERR" "Traceback" "wrong normalized types do not escape a traceback"
run_metadata "$TMP/feature-disconnected.json" validate-feature
assert_exit 0 "$RUN_RC" "disconnected dependency components are valid"
run_metadata "$TMP/feature-long-chain.json" validate-feature
assert_exit 0 "$RUN_RC" "a 1100-increment chain validates without recursion"

finish
