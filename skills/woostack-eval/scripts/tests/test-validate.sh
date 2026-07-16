#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
VALIDATOR="$SCRIPT_DIR/../validate.mjs"
NODE=${NODE:-node}
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/woostack-eval-validate.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM
RESULT="$TMP_ROOT/result.json"
ERRORS="$TMP_ROOT/stderr.txt"
TIMEOUT_MARKER="$TMP_ROOT/timeout.txt"
PACKAGE=

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

make_package() {
  name=$1
  description_line=$2
  PACKAGE="$TMP_ROOT/$name"
  mkdir -p "$PACKAGE/references"
  cat >"$PACKAGE/SKILL.md" <<EOF
---
name: $name
$description_line
---
# $name

[Guide](references/guide.md)

\`\`\`md
[Ignored missing link](references/not-created.md)
\`\`\`
EOF
  printf '# Guide\n' >"$PACKAGE/references/guide.md"
}

run_validator() {
  rm -f "$TIMEOUT_MARKER"
  set +e
  validator_args=(--package "$PACKAGE" --repository-root "${REPOSITORY_ROOT:-$TMP_ROOT}" --json)
  if [ "${TRACKED_ONLY:-0}" -eq 1 ]; then
    validator_args+=(--tracked-only)
  fi
  "$NODE" "$VALIDATOR" "${validator_args[@]}" >"$RESULT" 2>"$ERRORS" &
  validator_pid=$!
  (
    sleep 5
    if kill -0 "$validator_pid" 2>/dev/null; then
      printf 'validator exceeded 5 seconds\n' >"$TIMEOUT_MARKER"
      kill -TERM "$validator_pid" 2>/dev/null || :
      sleep 1
      kill -KILL "$validator_pid" 2>/dev/null || :
    fi
  ) &
  watchdog_pid=$!
  wait "$validator_pid"
  STATUS=$?
  kill "$watchdog_pid" 2>/dev/null || :
  wait "$watchdog_pid" 2>/dev/null || :
  set -e
  if [ -f "$TIMEOUT_MARKER" ]; then
    fail "$(cat "$TIMEOUT_MARKER"): $PACKAGE"
  fi
}

expect_valid() {
  label=$1
  expected_name=$2
  expected_description=$3
  expected_inventory=${4:-SKILL.md:skill,references/guide.md:reference}
  expected_behavior_count=${5:-0}
  expected_trigger_count=${6:-0}
  run_validator
  if [ "$STATUS" -ne 0 ]; then
    printf 'FAIL: %s should be valid (exit %s)\n' "$label" "$STATUS" >&2
    cat "$ERRORS" >&2
    exit 1
  fi
  "$NODE" - "$RESULT" "$expected_name" "$expected_description" "$expected_inventory" \
    "$expected_behavior_count" "$expected_trigger_count" <<'NODE'
const fs = require('node:fs');
const [file, expectedName, expectedDescription, inventoryText, behaviorText, triggerText] =
  process.argv.slice(2);
const result = JSON.parse(fs.readFileSync(file, 'utf8'));
const exactKeys = ['corpora', 'errors', 'files', 'package', 'packageHash', 'schemaVersion', 'valid'];
const same = (actual, expected) => JSON.stringify(actual) === JSON.stringify(expected);
if (!same(Object.keys(result).sort(), exactKeys)) {
  throw new Error(`unexpected result keys: ${Object.keys(result).sort().join(',')}`);
}
if (result.schemaVersion !== 1 || result.valid !== true || !same(result.errors, [])) {
  throw new Error(`expected a valid schemaVersion 1 result: ${JSON.stringify(result)}`);
}
if (!same(Object.keys(result.package).sort(), ['description', 'name', 'path'])) {
  throw new Error(`unexpected package shape: ${JSON.stringify(result.package)}`);
}
if (
  result.package.name !== expectedName ||
  result.package.description !== expectedDescription ||
  result.package.path !== expectedName
) {
  throw new Error(`unexpected normalized metadata: ${JSON.stringify(result.package)}`);
}
if (!same(Object.keys(result.corpora).sort(), ['behavior', 'triggers'])) {
  throw new Error(`unexpected corpora shape: ${JSON.stringify(result.corpora)}`);
}
for (const key of ['behavior', 'triggers']) {
  if (!same(Object.keys(result.corpora[key]).sort(), ['caseCount', 'present'])) {
    throw new Error(`unexpected ${key} summary shape: ${JSON.stringify(result.corpora[key])}`);
  }
}
const behaviorCount = Number(behaviorText);
const triggerCount = Number(triggerText);
const expectedCorpora = {
  behavior: { present: behaviorCount > 0, caseCount: behaviorCount },
  triggers: { present: triggerCount > 0, caseCount: triggerCount },
};
if (!same(result.corpora, expectedCorpora)) {
  throw new Error(`unexpected corpus summaries: ${JSON.stringify(result.corpora)}`);
}
const inventory = inventoryText.split(',').filter(Boolean);
const actualInventory = result.files.map((entry) => `${entry.path}:${entry.type}`);
if (!same(actualInventory, inventory)) {
  throw new Error(`unexpected sorted inventory: ${JSON.stringify(actualInventory)}`);
}
for (const entry of result.files) {
  if (!same(Object.keys(entry).sort(), ['bytes', 'path', 'sha256', 'type'])) {
    throw new Error(`unexpected file entry shape: ${JSON.stringify(entry)}`);
  }
  if (
    !['skill', 'reference', 'script', 'asset', 'eval'].includes(entry.type) ||
    !Number.isSafeInteger(entry.bytes) ||
    entry.bytes < 0 ||
    !/^sha256:[0-9a-f]{64}$/.test(entry.sha256)
  ) {
    throw new Error(`invalid file entry: ${JSON.stringify(entry)}`);
  }
}
if (!/^sha256:[0-9a-f]{64}$/.test(result.packageHash)) {
  throw new Error(`invalid package hash: ${result.packageHash}`);
}
NODE
}

expect_invalid() {
  label=$1
  expected_code=$2
  expected_path=$3
  expected_field=$4
  run_validator
  [ "$STATUS" -ne 0 ] || fail "$label should exit non-zero"
  "$NODE" - "$RESULT" "$expected_code" "$expected_path" "$expected_field" <<'NODE'
const fs = require('node:fs');
const [file, code, path, field] = process.argv.slice(2);
const result = JSON.parse(fs.readFileSync(file, 'utf8'));
const same = (actual, expected) => JSON.stringify(actual) === JSON.stringify(expected);
const exactKeys = ['corpora', 'errors', 'files', 'package', 'packageHash', 'schemaVersion', 'valid'];
if (!same(Object.keys(result).sort(), exactKeys)) {
  throw new Error(`unexpected result keys: ${Object.keys(result).sort().join(',')}`);
}
if (result.schemaVersion !== 1 || result.valid !== false || !Array.isArray(result.errors)) {
  throw new Error(`expected an invalid schemaVersion 1 result: ${JSON.stringify(result)}`);
}
if (!same(Object.keys(result.package).sort(), ['description', 'name', 'path'])) {
  throw new Error(`unexpected package shape: ${JSON.stringify(result.package)}`);
}
if (
  ![null, 'string'].includes(result.package.name === null ? null : typeof result.package.name) ||
  ![null, 'string'].includes(result.package.description === null ? null : typeof result.package.description) ||
  typeof result.package.path !== 'string'
) {
  throw new Error(`invalid package metadata types: ${JSON.stringify(result.package)}`);
}
if (!same(Object.keys(result.corpora).sort(), ['behavior', 'triggers'])) {
  throw new Error(`unexpected corpora shape: ${JSON.stringify(result.corpora)}`);
}
for (const key of ['behavior', 'triggers']) {
  const summary = result.corpora[key];
  if (
    !same(Object.keys(summary).sort(), ['caseCount', 'present']) ||
    typeof summary.present !== 'boolean' ||
    !Number.isSafeInteger(summary.caseCount) ||
    summary.caseCount < 0
  ) {
    throw new Error(`invalid ${key} summary: ${JSON.stringify(summary)}`);
  }
}
if (!Array.isArray(result.files)) throw new Error('files must be an array');
let previousFile = '';
for (const entry of result.files) {
  if (!same(Object.keys(entry).sort(), ['bytes', 'path', 'sha256', 'type'])) {
    throw new Error(`unexpected file entry shape: ${JSON.stringify(entry)}`);
  }
  if (
    entry.path < previousFile ||
    !['skill', 'reference', 'script', 'asset', 'eval'].includes(entry.type) ||
    !Number.isSafeInteger(entry.bytes) ||
    entry.bytes < 0 ||
    !/^sha256:[0-9a-f]{64}$/.test(entry.sha256)
  ) {
    throw new Error(`invalid or unsorted file entry: ${JSON.stringify(entry)}`);
  }
  previousFile = entry.path;
}
if (result.packageHash !== null && !/^sha256:[0-9a-f]{64}$/.test(result.packageHash)) {
  throw new Error(`invalid package hash: ${result.packageHash}`);
}
const identities = new Set();
let previousErrorKey = '';
for (const error of result.errors) {
  if (!same(Object.keys(error).sort(), ['code', 'field', 'message', 'path'])) {
    throw new Error(`unexpected error shape: ${JSON.stringify(error)}`);
  }
  if (
    !/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(error.code) ||
    typeof error.path !== 'string' ||
    error.path.startsWith('/') ||
    error.path.split('/').includes('..') ||
    typeof error.field !== 'string' ||
    (error.field !== '' && !/^\/(?:[^~\/]|~[01])*(?:\/(?:[^~\/]|~[01])*)*$/.test(error.field)) ||
    typeof error.message !== 'string' ||
    error.message.trim().length === 0 ||
    /[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/.test(error.message)
  ) {
    throw new Error(`invalid error contract: ${JSON.stringify(error)}`);
  }
  const identity = `${error.code}\u0000${error.path}\u0000${error.field}`;
  if (identities.has(identity)) throw new Error(`duplicate error: ${JSON.stringify(error)}`);
  identities.add(identity);
  const sortKey = `${error.path}\u0000${error.field}\u0000${error.code}`;
  if (sortKey < previousErrorKey) {
    throw new Error(`errors are not path/field/code sorted: ${JSON.stringify(result.errors)}`);
  }
  previousErrorKey = sortKey;
}
const error = result.errors.find((entry) =>
  entry.code === code && entry.path === path && entry.field === field
);
if (!error) {
  throw new Error(`missing ${code} at ${path}${field}: ${JSON.stringify(result.errors)}`);
}
NODE
}

expect_exact_errors() {
  label=$1
  expected_json=$2
  run_validator
  [ "$STATUS" -ne 0 ] || fail "$label should exit non-zero"
  "$NODE" - "$RESULT" "$expected_json" <<'NODE'
const fs = require('node:fs');
const [file, expectedText] = process.argv.slice(2);
const result = JSON.parse(fs.readFileSync(file, 'utf8'));
const actual = result.errors.map(({ code, path, field }) => ({ code, path, field }));
const expected = JSON.parse(expectedText);
if (JSON.stringify(actual) !== JSON.stringify(expected)) {
  throw new Error(`unexpected exact errors: ${JSON.stringify(actual)}`);
}
NODE
}

# Supported YAML scalars: quoted colon-space and a plain single-token placeholder.
make_package quoted-description 'description: "Use when the input has status: approved and preserve it."'
expect_valid 'quoted colon-space description' quoted-description \
  'Use when the input has status: approved and preserve it.'

make_package plain-placeholder 'description: Execute the plan at <plan-path> after approval.'
expect_valid 'plain angle-bracket placeholder' plain-placeholder \
  'Execute the plan at <plan-path> after approval.'

# Real YAML plain-scalar hazards and XML-like markup remain fatal.
make_package plain-colon-hazard 'description: Use when the plan has status: approved.'
expect_invalid 'plain colon-space description' frontmatter-plain-colon-space SKILL.md /description

make_package implicit-boolean-description 'description: true'
expect_invalid 'implicit boolean description' frontmatter-non-string-scalar SKILL.md /description

make_package implicit-null-description 'description: null'
expect_invalid 'implicit null description' frontmatter-non-string-scalar SKILL.md /description

make_package implicit-number-description 'description: 42'
expect_invalid 'implicit number description' frontmatter-non-string-scalar SKILL.md /description

make_package malformed-quoted-description 'description: "unterminated'
expect_invalid 'malformed quoted description' frontmatter-invalid-scalar SKILL.md /description

make_package invalid-quoted-escape 'description: "invalid \q escape"'
expect_invalid 'invalid quoted description escape' frontmatter-invalid-scalar SKILL.md /description

make_package script-tag 'description: Use <script> only after approval.'
expect_invalid 'script tag description' frontmatter-xml-markup SKILL.md /description

make_package paired-tags 'description: Use <strong>care</strong> for approvals.'
expect_invalid 'paired markup description' frontmatter-xml-markup SKILL.md /description

# Frontmatter identity and bounds.
make_package directory-name 'description: Valid package description.'
# Keep the directory name but change the declared identity.
printf '%s\n' '---' 'name: other-name' 'description: Valid package description.' '---' '# other-name' \
  >"$PACKAGE/SKILL.md"
expect_invalid 'directory/name mismatch' frontmatter-name-directory-mismatch SKILL.md /name

make_package empty-description 'description: ""'
expect_invalid 'empty description' frontmatter-description-empty SKILL.md /description

LONG_DESCRIPTION=$("$NODE" -e "process.stdout.write('x'.repeat(1025))")
make_package oversized-description "description: $LONG_DESCRIPTION"
expect_invalid 'over-1024 description' frontmatter-description-too-long SKILL.md /description

PACKAGE="$TMP_ROOT/missing-frontmatter"
mkdir -p "$PACKAGE"
printf '# missing-frontmatter\n' >"$PACKAGE/SKILL.md"
expect_invalid 'missing frontmatter' frontmatter-missing SKILL.md ''

PACKAGE="$TMP_ROOT/fenced-frontmatter"
mkdir -p "$PACKAGE"
cat >"$PACKAGE/SKILL.md" <<'EOF'
```yaml
---
name: fenced-frontmatter
description: This block is documentation, not frontmatter.
---
```
EOF
expect_invalid 'fenced frontmatter' frontmatter-missing SKILL.md ''

# Local links outside fences must exist and remain contained. Fenced links above are ignored.
make_package missing-link 'description: Package with a missing link.'
printf '\n[Missing](references/missing.md)\n' >>"$PACKAGE/SKILL.md"
expect_invalid 'missing local Markdown link' link-target-missing SKILL.md /links/1

make_package code-shaped-link 'description: Package with link-shaped code examples.'
cat >>"$PACKAGE/SKILL.md" <<'EOF'

`[Inline code](references/missing-inline.md)`

    [Indented code](references/missing-indented.md)
EOF
expect_valid 'link-shaped Markdown code is ignored' code-shaped-link 'Package with link-shaped code examples.'

make_package escaping-link 'description: Package with an escaping link.'
printf '\n[Outside](../../outside.md)\n' >>"$PACKAGE/SKILL.md"
expect_invalid 'escaping local Markdown link' link-target-outside SKILL.md /links/1

make_package balanced-link 'description: Package with balanced and escaped link destinations.'
printf '# Parenthesized guide\n' >"$PACKAGE/references/guide(1).md"
printf '\n[Balanced](references/guide(1).md)\n[Escaped](references/guide\\(1\\).md)\n' >>"$PACKAGE/SKILL.md"
expect_valid 'balanced and escaped Markdown destinations' balanced-link \
  'Package with balanced and escaped link destinations.' \
  'SKILL.md:skill,references/guide(1).md:reference,references/guide.md:reference'

make_package reference-link 'description: Package with a reference-style link.'
printf '\n[Reference][guide-reference]\n\n[guide-reference]: references/guide.md\n' >>"$PACKAGE/SKILL.md"
expect_valid 'reference-style Markdown link' reference-link 'Package with a reference-style link.'

make_package missing-reference-link 'description: Package with a missing reference target.'
printf '\n[Missing][missing-reference]\n\n[missing-reference]: references/missing(1).md\n' >>"$PACKAGE/SKILL.md"
expect_invalid 'missing reference-style link target' link-target-missing SKILL.md /links/1

make_package titled-followed-link 'description: Package with adjacent titled and missing links.'
printf '\n[Good](references/guide.md "title") [Missing](references/missing.md)\n' >>"$PACKAGE/SKILL.md"
expect_invalid 'titled link does not swallow following link' link-target-missing SKILL.md /links/2

make_package mixed-fence-markers 'description: Package with strict Markdown fences.'
cat >>"$PACKAGE/SKILL.md" <<'EOF'

````md
~~~
[Ignored after different marker](references/missing-one.md)
```
[Ignored after short marker](references/missing-two.md)
```` trailing
[Ignored after suffixed marker](references/missing-three.md)
````
EOF
expect_valid 'strict Markdown fence closing' mixed-fence-markers 'Package with strict Markdown fences.'

# A valid behavior corpus pins every supported assertion and capability.
make_package valid-corpus 'description: Package with a complete behavior corpus.'
mkdir -p "$PACKAGE/evals/fixtures"
printf 'fixture\n' >"$PACKAGE/evals/fixtures/input.txt"
cat >"$PACKAGE/evals/evals.json" <<'EOF'
{
  "schemaVersion": 1,
  "skill": "valid-corpus",
  "cases": [{
    "id": "all-assertions",
    "prompt": "Exercise each deterministic assertion.",
    "fixtures": ["input.txt"],
    "capabilities": ["read-workspace", "write-workspace", "shell-workspace"],
    "expected": "Each assertion is evaluated according to its documented semantics.",
    "assertions": [
      {"id":"exists","kind":"path-exists","path":"result.txt"},
      {"id":"absent","kind":"path-absent","path":"forbidden.txt"},
      {"id":"contains","kind":"file-contains","file":"result.txt","substring":"literal .* text"},
      {"id":"excludes","kind":"file-excludes","file":"result.txt","substring":"secret"},
      {"id":"json","kind":"json-path-equals","file":"result.json","pointer":"/a~1b/~0key","expected":{"ok":true}},
      {"id":"final-has","kind":"final-contains","substring":"done"},
      {"id":"final-lacks","kind":"final-excludes","substring":"failed"},
      {"id":"receipt","kind":"receipt-field-equals","pointer":"/completionStatus","expected":"complete"},
      {"id":"quality","kind":"qualitative","rubric":"Does the answer explain the approval boundary?","critical":true}
    ]
  }]
}
EOF
cat >"$PACKAGE/evals/trigger-evals.json" <<'EOF'
{"schemaVersion":1,"skill":"valid-corpus","cases":[
  {"id":"positive","query":"Use the valid corpus skill.","shouldTrigger":true,"expectedSkill":"valid-corpus"},
  {"id":"near-miss","query":"Review this instead.","shouldTrigger":false,"expectedSkill":"woostack-review","conflictsWith":["woostack-review"]}
]}
EOF
expect_valid 'complete supported corpora' valid-corpus 'Package with a complete behavior corpus.' \
  'SKILL.md:skill,evals/evals.json:eval,evals/fixtures/input.txt:eval,evals/trigger-evals.json:eval,references/guide.md:reference' \
  1 2

make_package duplicate-case-ids 'description: Corpus with duplicate case identifiers.'
mkdir -p "$PACKAGE/evals"
cat >"$PACKAGE/evals/evals.json" <<'EOF'
{"schemaVersion":1,"skill":"duplicate-case-ids","cases":[
  {"id":"same-case","prompt":"One","expected":"One","assertions":[{"id":"one","kind":"final-contains","substring":"one"}]},
  {"id":"same-case","prompt":"Two","expected":"Two","assertions":[{"id":"two","kind":"final-contains","substring":"two"}]}
]}
EOF
expect_invalid 'duplicate corpus IDs' corpus-duplicate-id evals/evals.json /cases/1/id

make_package unsupported-capability 'description: Corpus with an unsupported capability.'
mkdir -p "$PACKAGE/evals"
cat >"$PACKAGE/evals/evals.json" <<'EOF'
{"schemaVersion":1,"skill":"unsupported-capability","cases":[
  {"id":"network-case","prompt":"Do work","capabilities":["network"],"expected":"No network","assertions":[{"id":"done","kind":"final-contains","substring":"done"}]}
]}
EOF
expect_invalid 'unsupported capability' corpus-unsupported-capability evals/evals.json /cases/0/capabilities/0

make_package unsupported-assertion 'description: Corpus with an unsupported assertion.'
mkdir -p "$PACKAGE/evals"
cat >"$PACKAGE/evals/evals.json" <<'EOF'
{"schemaVersion":1,"skill":"unsupported-assertion","cases":[
  {"id":"regex-case","prompt":"Do work","expected":"Literal checks","assertions":[{"id":"regex","kind":"final-matches","pattern":"done.*"}]}
]}
EOF
expect_invalid 'unsupported assertion' corpus-unsupported-assertion evals/evals.json /cases/0/assertions/0/kind

make_package missing-fixture 'description: Corpus with a missing fixture.'
mkdir -p "$PACKAGE/evals"
cat >"$PACKAGE/evals/evals.json" <<'EOF'
{"schemaVersion":1,"skill":"missing-fixture","cases":[
  {"id":"missing-input","prompt":"Read input","fixtures":["missing.txt"],"expected":"Read it","assertions":[{"id":"done","kind":"final-contains","substring":"done"}]}
]}
EOF
expect_invalid 'missing fixture' corpus-fixture-missing evals/evals.json /cases/0/fixtures/0

make_package traversing-fixture 'description: Corpus with a traversing fixture.'
mkdir -p "$PACKAGE/evals/fixtures"
printf 'outside\n' >"$PACKAGE/evals/outside.txt"
cat >"$PACKAGE/evals/evals.json" <<'EOF'
{"schemaVersion":1,"skill":"traversing-fixture","cases":[
  {"id":"outside-input","prompt":"Read input","fixtures":["../outside.txt"],"expected":"Reject traversal","assertions":[{"id":"done","kind":"final-contains","substring":"done"}]}
]}
EOF
expect_invalid 'traversing fixture' corpus-fixture-outside evals/evals.json /cases/0/fixtures/0

make_package aliased-fixture 'description: Corpus with a non-normalized fixture alias.'
mkdir -p "$PACKAGE/evals/fixtures"
printf 'input\n' >"$PACKAGE/evals/fixtures/input.txt"
cat >"$PACKAGE/evals/evals.json" <<'EOF'
{"schemaVersion":1,"skill":"aliased-fixture","cases":[
  {"id":"aliased-input","prompt":"Read input","fixtures":["input.txt","./input.txt"],"expected":"Reject aliases","assertions":[{"id":"done","kind":"final-contains","substring":"done"}]}
]}
EOF
expect_invalid 'dot-segment fixture alias' corpus-fixture-outside evals/evals.json /cases/0/fixtures/1

make_package aliased-assertion-path 'description: Corpus with a non-normalized assertion path.'
mkdir -p "$PACKAGE/evals"
cat >"$PACKAGE/evals/evals.json" <<'EOF'
{"schemaVersion":1,"skill":"aliased-assertion-path","cases":[
  {"id":"aliased-output","prompt":"Write output","expected":"Reject aliases","assertions":[{"id":"done","kind":"path-exists","path":"dir/./result.txt"}]}
]}
EOF
expect_invalid 'dot-segment assertion alias' corpus-invalid-path evals/evals.json /cases/0/assertions/0/path

# Package inventory rejects links, non-regular entries, metadata, env, and secret-looking paths.
make_package symlink-package 'description: Package containing a symlink.'
ln -s references/guide.md "$PACKAGE/linked-guide.md"
expect_invalid 'symlink package file' package-symlink linked-guide.md ''

make_package fifo-package 'description: Package containing a FIFO.'
mkfifo "$PACKAGE/events.pipe"
expect_invalid 'FIFO package file' package-special-file events.pipe ''

make_package git-metadata 'description: Package containing Git metadata.'
mkdir -p "$PACKAGE/.git"
printf 'metadata\n' >"$PACKAGE/.git/config"
expect_invalid '.git package path' package-forbidden-path .git ''

make_package env-file 'description: Package containing an environment file.'
printf 'TOKEN=not-a-real-secret\n' >"$PACKAGE/.env.local"
expect_invalid '.env package path' package-forbidden-path .env.local ''

make_package secret-path 'description: Package containing a secret-looking path.'
mkdir -p "$PACKAGE/secrets"
printf 'not-a-real-key\n' >"$PACKAGE/secrets/api-key.txt"
expect_invalid 'secret-looking package path' package-secret-path secrets/api-key.txt ''

# Tracked-only validation ignores untracked corpora and rejects referenced untracked resources.
TRACKED_ROOT="$TMP_ROOT/tracked-root"
mkdir -p "$TRACKED_ROOT"
git init -q "$TRACKED_ROOT"
REPOSITORY_ROOT=$TRACKED_ROOT
TRACKED_ONLY=1

PACKAGE="$TRACKED_ROOT/untracked-corpus"
mkdir -p "$PACKAGE/evals"
printf '%s\n' '---' 'name: untracked-corpus' 'description: Ignore an untracked corpus.' '---' '# untracked-corpus' \
  >"$PACKAGE/SKILL.md"
git -C "$TRACKED_ROOT" add -- untracked-corpus/SKILL.md
printf '%s\n' '{"schemaVersion":1,"skill":"untracked-corpus","cases":[]}' >"$PACKAGE/evals/evals.json"
run_validator
[ "$STATUS" -eq 0 ] || fail 'untracked corpus should be ignored in tracked-only mode'
"$NODE" - "$RESULT" <<'NODE'
const fs = require('node:fs');
const result = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
if (
  result.corpora.behavior.present ||
  result.files.some(({ path }) => path === 'evals/evals.json')
) {
  throw new Error(`untracked corpus leaked into result: ${JSON.stringify(result)}`);
}
NODE

PACKAGE="$TRACKED_ROOT/untracked-fixture"
mkdir -p "$PACKAGE/evals/fixtures"
printf '%s\n' '---' 'name: untracked-fixture' 'description: Reject an untracked fixture.' '---' '# untracked-fixture' \
  >"$PACKAGE/SKILL.md"
cat >"$PACKAGE/evals/evals.json" <<'EOF'
{"schemaVersion":1,"skill":"untracked-fixture","cases":[
  {"id":"untracked-input","prompt":"Read input","fixtures":["input.txt"],"expected":"Reject it","assertions":[{"id":"done","kind":"final-contains","substring":"done"}]}
]}
EOF
git -C "$TRACKED_ROOT" add -- untracked-fixture/SKILL.md untracked-fixture/evals/evals.json
printf 'input\n' >"$PACKAGE/evals/fixtures/input.txt"
expect_invalid 'untracked fixture reference' corpus-fixture-untracked evals/evals.json /cases/0/fixtures/0

PACKAGE="$TRACKED_ROOT/untracked-link"
mkdir -p "$PACKAGE/references"
cat >"$PACKAGE/SKILL.md" <<'EOF'
---
name: untracked-link
description: Reject an untracked link target.
---
# untracked-link

[Guide](references/guide.md)
EOF
git -C "$TRACKED_ROOT" add -- untracked-link/SKILL.md
printf '# Guide\n' >"$PACKAGE/references/guide.md"
expect_invalid 'untracked local link target' link-target-untracked SKILL.md /links/0

unset REPOSITORY_ROOT TRACKED_ONLY

# Multiple independent errors pin complete error invariants and path/field/code ordering.
make_package multiple-errors 'description: Package with two deterministic errors.'
printf 'TOKEN=not-a-real-secret\n' >"$PACKAGE/.env.local"
printf '\n[Missing](references/missing.md)\n' >>"$PACKAGE/SKILL.md"
expect_invalid 'multiple-error invariants' package-forbidden-path .env.local ''
expect_exact_errors 'multiple sorted errors' \
  '[{"code":"package-forbidden-path","path":".env.local","field":""},{"code":"link-target-missing","path":"SKILL.md","field":"/links/1"}]'

printf 'PASS: validator package and corpus contracts\n'
