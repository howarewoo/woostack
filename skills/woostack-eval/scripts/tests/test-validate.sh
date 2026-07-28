#!/usr/bin/env bash
set -euo pipefail

ROOT=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)
SCRIPT_DIR="$ROOT/skills/woostack-eval/scripts/tests"
VALIDATOR="$ROOT/skills/woostack-eval/scripts/validate.mjs"
NODE=${NODE:-node}
TMP_ROOT=$(mktemp -d "$ROOT/.woostack-eval-validate.XXXXXX")
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

make_package missing-sibling-link 'description: Package with a missing sibling link.'
printf '\n[Missing sibling](../absent-sibling/references/guide.md)\n' >>"$PACKAGE/SKILL.md"
expect_invalid 'default validation rejects a missing sibling link' link-target-missing SKILL.md /links/1

POLICY_COLLECTION="$TMP_ROOT/baseline-policy"
mkdir -p "$POLICY_COLLECTION/sibling-target/references"
mkfifo "$POLICY_COLLECTION/sibling-target/references/special"

"$NODE" --input-type=module - "$VALIDATOR" "$POLICY_COLLECTION" <<'NODE'
import assert from 'node:assert/strict';
import { mkdir, symlink, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const [validatorPath, collectionRoot] = process.argv.slice(2);
const { validatePackage } = await import(pathToFileURL(validatorPath).href);
const packageRoot = path.join(collectionRoot, 'snapshot-target');
await mkdir(path.join(packageRoot, 'references'), { recursive: true });
await writeFile(path.join(packageRoot, 'references', 'guide.md'), '# Guide\n');
const skill = (link) => `---
name: snapshot-target
description: Baseline snapshot link policy fixture.
---
# snapshot-target

[Guide](references/guide.md)
[Policy target](${link})
`;

await writeFile(path.join(packageRoot, 'SKILL.md'), skill('../sibling-target/references/guide.md'));
const crossPackage = await validatePackage(packageRoot, {
  repositoryRoot: collectionRoot,
  baselineSnapshot: { collectionRoot },
});
assert.equal(crossPackage.valid, true, JSON.stringify(crossPackage.errors));

await writeFile(
  path.join(packageRoot, 'SKILL.md'),
  skill('../absent-sibling/references/guide.md'),
);
const outsideCollection = await validatePackage(packageRoot, {
  repositoryRoot: collectionRoot,
  baselineSnapshot: { collectionRoot: path.join(collectionRoot, '..', 'outside-collection') },
});
assert.equal(outsideCollection.valid, false);
assert.equal(
  outsideCollection.errors.some(({ code }) => code === 'link-target-missing'),
  true,
);
const nonContainingCollection = await validatePackage(packageRoot, {
  repositoryRoot: collectionRoot,
  baselineSnapshot: { collectionRoot: path.join(collectionRoot, 'sibling-target') },
});
assert.equal(nonContainingCollection.valid, false);
assert.equal(
  nonContainingCollection.errors.some(({ code }) => code === 'link-target-missing'),
  true,
);

await writeFile(path.join(packageRoot, 'SKILL.md'), skill('references/missing.md'));
const inPackage = await validatePackage(packageRoot, {
  repositoryRoot: collectionRoot,
  baselineSnapshot: { collectionRoot },
});
assert.equal(inPackage.valid, false);
assert.equal(inPackage.errors.some(({ code }) => code === 'link-target-missing'), true);

await writeFile(path.join(packageRoot, 'SKILL.md'), skill('../../outside.md'));
const escaped = await validatePackage(packageRoot, {
  repositoryRoot: collectionRoot,
  baselineSnapshot: { collectionRoot },
});
assert.equal(escaped.valid, false);
assert.equal(escaped.errors.some(({ code }) => code === 'link-target-outside'), true);

await writeFile(path.join(packageRoot, 'SKILL.md'), skill('../sibling-target/../missing.md'));
const nonNormalized = await validatePackage(packageRoot, {
  repositoryRoot: collectionRoot,
  baselineSnapshot: { collectionRoot },
});
assert.equal(nonNormalized.valid, false);
assert.equal(nonNormalized.errors.some(({ code }) => code === 'link-target-not-normalized'), true);

await symlink(
  path.join(packageRoot, 'references', 'guide.md'),
  path.join(collectionRoot, 'sibling-target', 'references', 'linked.md'),
);
await writeFile(path.join(packageRoot, 'SKILL.md'), skill('../sibling-target/references/linked.md'));
const symlinked = await validatePackage(packageRoot, {
  repositoryRoot: collectionRoot,
  baselineSnapshot: { collectionRoot },
});
assert.equal(symlinked.valid, false);
assert.equal(symlinked.errors.some(({ code }) => code === 'link-target-symlink'), true);

await writeFile(path.join(packageRoot, 'SKILL.md'), skill('../sibling-target/references/special'));
const special = await validatePackage(packageRoot, {
  repositoryRoot: collectionRoot,
  baselineSnapshot: { collectionRoot },
});
assert.equal(special.valid, false);
assert.equal(special.errors.some(({ code }) => code === 'link-target-not-regular'), true);
NODE

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
      {"id":"sha256","kind":"file-sha256-equals","file":"result.txt","sha256":"sha256:688fd6bd79488b16291edc13a90ca17ad758115f04ac715a75abf2914229b226"},
      {"id":"excludes","kind":"file-excludes","file":"result.txt","substring":"secret"},
      {"id":"json","kind":"json-path-equals","file":"result.json","pointer":"/a~1b/~0key","expected":{"ok":true}},
      {"id":"final-json","kind":"final-json-path-equals","pointer":"/items/0/enabled","expected":true},
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

make_package invalid-file-sha256 'description: Corpus with an invalid file digest.'
mkdir -p "$PACKAGE/evals"
cat >"$PACKAGE/evals/evals.json" <<'EOF'
{"schemaVersion":1,"skill":"invalid-file-sha256","cases":[
  {"id":"digest-case","prompt":"Check bytes","expected":"Exact bytes","assertions":[{"id":"digest","kind":"file-sha256-equals","file":"result.txt","sha256":"SHA256:not-a-digest"}]}
]}
EOF
expect_invalid 'file SHA-256 assertion requires a canonical digest' corpus-invalid-sha256 evals/evals.json /cases/0/assertions/0/sha256

make_package missing-final-json-pointer 'description: Corpus with an incomplete final JSON assertion.'
mkdir -p "$PACKAGE/evals"
cat >"$PACKAGE/evals/evals.json" <<'EOF'
{"schemaVersion":1,"skill":"missing-final-json-pointer","cases":[
  {"id":"json-case","prompt":"Return JSON","expected":"Validate the final JSON","assertions":[{"id":"json","kind":"final-json-path-equals","expected":true}]}
]}
EOF
expect_invalid 'final JSON assertion requires pointer' corpus-missing-field evals/evals.json /cases/0/assertions/0/pointer

make_package extra-final-json-field 'description: Corpus with an over-specified final JSON assertion.'
mkdir -p "$PACKAGE/evals"
cat >"$PACKAGE/evals/evals.json" <<'EOF'
{"schemaVersion":1,"skill":"extra-final-json-field","cases":[
  {"id":"json-case","prompt":"Return JSON","expected":"Validate the final JSON","assertions":[{"id":"json","kind":"final-json-path-equals","pointer":"","expected":{"ok":true},"file":"result.json"}]}
]}
EOF
expect_invalid 'final JSON assertion rejects extra fields' corpus-unknown-field evals/evals.json /cases/0/assertions/0/file

make_package invalid-final-json-pointer 'description: Corpus with an invalid final JSON pointer.'
mkdir -p "$PACKAGE/evals"
cat >"$PACKAGE/evals/evals.json" <<'EOF'
{"schemaVersion":1,"skill":"invalid-final-json-pointer","cases":[
  {"id":"json-case","prompt":"Return JSON","expected":"Validate the final JSON","assertions":[{"id":"json","kind":"final-json-path-equals","pointer":"items/0","expected":true}]}
]}
EOF
expect_invalid 'final JSON assertion requires RFC 6901 pointer' corpus-invalid-pointer evals/evals.json /cases/0/assertions/0/pointer

make_package missing-fixture 'description: Corpus with a missing fixture.'
mkdir -p "$PACKAGE/evals"
cat >"$PACKAGE/evals/evals.json" <<'EOF'
{"schemaVersion":1,"skill":"missing-fixture","cases":[
  {"id":"missing-input","prompt":"Read input","fixtures":["missing.txt"],"expected":"Read it","assertions":[{"id":"done","kind":"final-contains","substring":"done"}]}
]}
EOF
expect_invalid 'missing fixture' corpus-fixture-missing evals/evals.json /cases/0/fixtures/0

make_package worker-output-oracle 'description: Corpus with a worker-visible output oracle.'
mkdir -p "$PACKAGE/evals/fixtures"
printf '%s\n' '{"scenario":{"expected":{"status":"complete"}}}' >"$PACKAGE/evals/fixtures/answer.json"
cat >"$PACKAGE/evals/evals.json" <<'EOF'
{"schemaVersion":1,"skill":"worker-output-oracle","cases":[
  {"id":"oracle-input","prompt":"Evaluate the scenario","fixtures":["answer.json"],"expected":"Derive the result","assertions":[{"id":"done","kind":"final-contains","substring":"done"}]}
]}
EOF
expect_invalid 'worker-visible fixture output oracle' corpus-fixture-output-oracle evals/evals.json /cases/0/fixtures/0

make_package worker-terminal-receipt 'description: Corpus with a derived terminal receipt.'
mkdir -p "$PACKAGE/evals/fixtures"
printf '%s\n' '{"observations":[],"terminalReceipt":{"complete":true}}' >"$PACKAGE/evals/fixtures/receipt.json"
cat >"$PACKAGE/evals/evals.json" <<'EOF'
{"schemaVersion":1,"skill":"worker-terminal-receipt","cases":[
  {"id":"receipt-input","prompt":"Evaluate the observations","fixtures":["receipt.json"],"expected":"Derive the result","assertions":[{"id":"done","kind":"final-contains","substring":"done"}]}
]}
EOF
expect_invalid 'worker-visible derived terminal receipt' corpus-fixture-output-oracle evals/evals.json /cases/0/fixtures/0

make_package worker-semantic-oracles 'description: Corpus with semantic worker-visible output oracles.'
mkdir -p "$PACKAGE/evals/fixtures"
printf '%s\n' '{"scenario":"ambiguous"}' >"$PACKAGE/evals/fixtures/scenario.json"
printf '%s\n' '{"receipt":{"outcome":"ambiguous"}}' >"$PACKAGE/evals/fixtures/outcome.json"
printf '%s\n' '{"status":"complete"}' >"$PACKAGE/evals/fixtures/status.json"
printf '%s\n' '{"classification":"ambiguous"}' >"$PACKAGE/evals/fixtures/classification.json"
printf '%s\n' '{"label":"ambiguous"}' >"$PACKAGE/evals/fixtures/semantic-alias.json"
printf '%s\n' '{"reasonCode":"missing-merge-evidence"}' >"$PACKAGE/evals/fixtures/reason-code.json"
printf '%s\n' '{"status":true}' >"$PACKAGE/evals/fixtures/boolean-status.json"
printf '%s\n' '{"classification":{"codes":[1,null],"kind":"ambiguous"}}' >"$PACKAGE/evals/fixtures/object-classification.json"
printf '%s\n' '{"mergeEvidence":{"verified":true}}' >"$PACKAGE/evals/fixtures/derived-verification.json"
printf '%s\n' '{"phase":"complete","blocked":false,"rendered":false,"selectedRound":3,"currentHeadId":null,"nextAction":null,"writesAttempted":[],"result":{"decision":"go"}}' >"$PACKAGE/evals/fixtures/generic-output.json"
cat >"$PACKAGE/evals/evals.json" <<'EOF'
{"schemaVersion":1,"skill":"worker-semantic-oracles","cases":[
  {"id":"scenario-oracle","prompt":"Derive the classification","fixtures":["scenario.json"],"expected":"Derive it","assertions":[{"id":"classification","kind":"final-json-path-equals","pointer":"/classification","expected":"ambiguous"}]},
  {"id":"outcome-oracle","prompt":"Derive the classification","fixtures":["outcome.json"],"expected":"Derive it","assertions":[{"id":"classification","kind":"final-json-path-equals","pointer":"/classification","expected":"ambiguous"}]},
  {"id":"status-oracle","prompt":"Derive the status","fixtures":["status.json"],"expected":"Derive it","assertions":[{"id":"status","kind":"final-json-path-equals","pointer":"/status","expected":"complete"}]},
  {"id":"classification-oracle","prompt":"Derive the classification","fixtures":["classification.json"],"expected":"Derive it","assertions":[{"id":"classification","kind":"final-json-path-equals","pointer":"/classification","expected":"ambiguous"}]},
  {"id":"semantic-alias-oracle","prompt":"Derive the classification","fixtures":["semantic-alias.json"],"expected":"Derive it","assertions":[{"id":"classification","kind":"final-json-path-equals","pointer":"/classification","expected":"ambiguous"}]},
  {"id":"reason-code-oracle","prompt":"Derive the reason code","fixtures":["reason-code.json"],"expected":"Derive it","assertions":[{"id":"reason-code","kind":"final-json-path-equals","pointer":"/reasonCode","expected":"missing-merge-evidence"}]},
  {"id":"boolean-status-oracle","prompt":"Derive the status","fixtures":["boolean-status.json"],"expected":"Derive it","assertions":[{"id":"status","kind":"final-json-path-equals","pointer":"/status","expected":true}]},
  {"id":"object-classification-oracle","prompt":"Derive the classification","fixtures":["object-classification.json"],"expected":"Derive it","assertions":[{"id":"classification","kind":"final-json-path-equals","pointer":"/classification","expected":{"kind":"ambiguous","codes":[1,null]}}]},
  {"id":"derived-verification-oracle","prompt":"Verify the merge evidence","fixtures":["derived-verification.json"],"expected":"Derive it","assertions":[{"id":"verified","kind":"final-json-path-equals","pointer":"/mergeEvidenceVerified","expected":true}]},
  {"id":"string-output-oracle","prompt":"Derive the phase","fixtures":["generic-output.json"],"expected":"Derive it","assertions":[{"id":"phase","kind":"final-json-path-equals","pointer":"/phase","expected":"complete"}]},
  {"id":"boolean-output-oracle","prompt":"Derive whether processing is blocked","fixtures":["generic-output.json"],"expected":"Derive it","assertions":[{"id":"blocked","kind":"final-json-path-equals","pointer":"/blocked","expected":false}]},
  {"id":"boolean-alias-output-oracle","prompt":"Derive whether output rendered","fixtures":["generic-output.json"],"expected":"Derive it","assertions":[{"id":"rendered","kind":"final-json-path-equals","pointer":"/rendered","expected":false}]},
  {"id":"number-output-oracle","prompt":"Select a round","fixtures":["generic-output.json"],"expected":"Derive it","assertions":[{"id":"selected-round","kind":"final-json-path-equals","pointer":"/selectedRound","expected":3}]},
  {"id":"null-output-oracle","prompt":"Derive the current head","fixtures":["generic-output.json"],"expected":"Derive it","assertions":[{"id":"current-head","kind":"final-json-path-equals","pointer":"/currentHeadId","expected":null}]},
  {"id":"null-alias-output-oracle","prompt":"Derive the next action","fixtures":["generic-output.json"],"expected":"Derive it","assertions":[{"id":"next-action","kind":"final-json-path-equals","pointer":"/nextAction","expected":null}]},
  {"id":"array-output-oracle","prompt":"Derive attempted writes","fixtures":["generic-output.json"],"expected":"Derive it","assertions":[{"id":"writes","kind":"final-json-path-equals","pointer":"/writesAttempted","expected":[]}]},
  {"id":"object-output-oracle","prompt":"Derive the result","fixtures":["generic-output.json"],"expected":"Derive it","assertions":[{"id":"result","kind":"final-json-path-equals","pointer":"/result","expected":{"decision":"go"}}]},
  {"id":"file-json-output-oracle","prompt":"Write the classification","fixtures":["classification.json"],"capabilities":["write-workspace"],"expected":"Derive it","assertions":[{"id":"classification","kind":"json-path-equals","file":"result.json","pointer":"/classification","expected":"ambiguous"}]},
  {"id":"receipt-output-oracle","prompt":"Return the classification receipt","fixtures":["classification.json"],"expected":"Derive it","assertions":[{"id":"classification","kind":"receipt-field-equals","pointer":"/classification","expected":"ambiguous"}]}
]}
EOF
expect_invalid 'scenario semantic oracle' corpus-fixture-output-oracle evals/evals.json /cases/0/fixtures/0
expect_invalid 'nested outcome semantic oracle' corpus-fixture-output-oracle evals/evals.json /cases/1/fixtures/0
expect_invalid 'status semantic oracle' corpus-fixture-output-oracle evals/evals.json /cases/2/fixtures/0
expect_invalid 'classification semantic oracle' corpus-fixture-output-oracle evals/evals.json /cases/3/fixtures/0
expect_invalid 'aliased classification value oracle' corpus-fixture-output-oracle evals/evals.json /cases/4/fixtures/0
expect_invalid 'aliased reason code oracle' corpus-fixture-output-oracle evals/evals.json /cases/5/fixtures/0
expect_invalid 'boolean status oracle' corpus-fixture-output-oracle evals/evals.json /cases/6/fixtures/0
expect_invalid 'object classification oracle' corpus-fixture-output-oracle evals/evals.json /cases/7/fixtures/0
expect_invalid 'derived verification alias oracle' corpus-fixture-output-oracle evals/evals.json /cases/8/fixtures/0
expect_invalid 'string assertion-key oracle' corpus-fixture-output-oracle evals/evals.json /cases/9/fixtures/0
expect_invalid 'Boolean assertion-key oracle' corpus-fixture-output-oracle evals/evals.json /cases/10/fixtures/0
expect_invalid 'Boolean alias assertion-key oracle' corpus-fixture-output-oracle evals/evals.json /cases/11/fixtures/0
expect_invalid 'number assertion-key oracle' corpus-fixture-output-oracle evals/evals.json /cases/12/fixtures/0
expect_invalid 'null assertion-key oracle' corpus-fixture-output-oracle evals/evals.json /cases/13/fixtures/0
expect_invalid 'null alias assertion-key oracle' corpus-fixture-output-oracle evals/evals.json /cases/14/fixtures/0
expect_invalid 'array assertion-key oracle' corpus-fixture-output-oracle evals/evals.json /cases/15/fixtures/0
expect_invalid 'object assertion-key oracle' corpus-fixture-output-oracle evals/evals.json /cases/16/fixtures/0
expect_invalid 'file JSON assertion-key oracle' corpus-fixture-output-oracle evals/evals.json /cases/17/fixtures/0
expect_invalid 'receipt assertion-key oracle' corpus-fixture-output-oracle evals/evals.json /cases/18/fixtures/0

make_package worker-arbitrary-oracles 'description: Corpus with arbitrary worker-visible output oracles.'
mkdir -p "$PACKAGE/evals/fixtures"
printf '%s\n' '{"verdict":"deny"}' >"$PACKAGE/evals/fixtures/string.json"
printf '%s\n' '{"verdict":false}' >"$PACKAGE/evals/fixtures/boolean.json"
printf '%s\n' '{"verdict":7}' >"$PACKAGE/evals/fixtures/number.json"
printf '%s\n' '{"verdict":null}' >"$PACKAGE/evals/fixtures/null.json"
printf '%s\n' '{"verdict":[1,null]}' >"$PACKAGE/evals/fixtures/array.json"
printf '%s\n' '{"verdict":{"decision":"deny"}}' >"$PACKAGE/evals/fixtures/object.json"
cat >"$PACKAGE/evals/evals.json" <<'EOF'
{"schemaVersion":1,"skill":"worker-arbitrary-oracles","cases":[
  {"id":"final-string","prompt":"Derive the verdict","fixtures":["string.json"],"expected":"Derive it","assertions":[{"id":"verdict","kind":"final-json-path-equals","pointer":"/verdict","expected":"deny"}]},
  {"id":"final-boolean","prompt":"Derive the verdict","fixtures":["boolean.json"],"expected":"Derive it","assertions":[{"id":"verdict","kind":"final-json-path-equals","pointer":"/verdict","expected":false}]},
  {"id":"final-number","prompt":"Derive the verdict","fixtures":["number.json"],"expected":"Derive it","assertions":[{"id":"verdict","kind":"final-json-path-equals","pointer":"/verdict","expected":7}]},
  {"id":"final-null","prompt":"Derive the verdict","fixtures":["null.json"],"expected":"Derive it","assertions":[{"id":"verdict","kind":"final-json-path-equals","pointer":"/verdict","expected":null}]},
  {"id":"final-array","prompt":"Derive the verdict","fixtures":["array.json"],"expected":"Derive it","assertions":[{"id":"verdict","kind":"final-json-path-equals","pointer":"/verdict","expected":[1,null]}]},
  {"id":"final-object","prompt":"Derive the verdict","fixtures":["object.json"],"expected":"Derive it","assertions":[{"id":"verdict","kind":"final-json-path-equals","pointer":"/verdict","expected":{"decision":"deny"}}]},
  {"id":"file-string","prompt":"Write the verdict","fixtures":["string.json"],"capabilities":["write-workspace"],"expected":"Derive it","assertions":[{"id":"verdict","kind":"json-path-equals","file":"result.json","pointer":"/verdict","expected":"deny"}]},
  {"id":"file-boolean","prompt":"Write the verdict","fixtures":["boolean.json"],"capabilities":["write-workspace"],"expected":"Derive it","assertions":[{"id":"verdict","kind":"json-path-equals","file":"result.json","pointer":"/verdict","expected":false}]},
  {"id":"file-number","prompt":"Write the verdict","fixtures":["number.json"],"capabilities":["write-workspace"],"expected":"Derive it","assertions":[{"id":"verdict","kind":"json-path-equals","file":"result.json","pointer":"/verdict","expected":7}]},
  {"id":"file-null","prompt":"Write the verdict","fixtures":["null.json"],"capabilities":["write-workspace"],"expected":"Derive it","assertions":[{"id":"verdict","kind":"json-path-equals","file":"result.json","pointer":"/verdict","expected":null}]},
  {"id":"file-array","prompt":"Write the verdict","fixtures":["array.json"],"capabilities":["write-workspace"],"expected":"Derive it","assertions":[{"id":"verdict","kind":"json-path-equals","file":"result.json","pointer":"/verdict","expected":[1,null]}]},
  {"id":"file-object","prompt":"Write the verdict","fixtures":["object.json"],"capabilities":["write-workspace"],"expected":"Derive it","assertions":[{"id":"verdict","kind":"json-path-equals","file":"result.json","pointer":"/verdict","expected":{"decision":"deny"}}]},
  {"id":"receipt-string","prompt":"Return the verdict receipt","fixtures":["string.json"],"expected":"Derive it","assertions":[{"id":"verdict","kind":"receipt-field-equals","pointer":"/verdict","expected":"deny"}]},
  {"id":"receipt-boolean","prompt":"Return the verdict receipt","fixtures":["boolean.json"],"expected":"Derive it","assertions":[{"id":"verdict","kind":"receipt-field-equals","pointer":"/verdict","expected":false}]},
  {"id":"receipt-number","prompt":"Return the verdict receipt","fixtures":["number.json"],"expected":"Derive it","assertions":[{"id":"verdict","kind":"receipt-field-equals","pointer":"/verdict","expected":7}]},
  {"id":"receipt-null","prompt":"Return the verdict receipt","fixtures":["null.json"],"expected":"Derive it","assertions":[{"id":"verdict","kind":"receipt-field-equals","pointer":"/verdict","expected":null}]},
  {"id":"receipt-array","prompt":"Return the verdict receipt","fixtures":["array.json"],"expected":"Derive it","assertions":[{"id":"verdict","kind":"receipt-field-equals","pointer":"/verdict","expected":[1,null]}]},
  {"id":"receipt-object","prompt":"Return the verdict receipt","fixtures":["object.json"],"expected":"Derive it","assertions":[{"id":"verdict","kind":"receipt-field-equals","pointer":"/verdict","expected":{"decision":"deny"}}]}
]}
EOF
expect_invalid 'arbitrary string final oracle' corpus-fixture-output-oracle evals/evals.json /cases/0/fixtures/0
expect_invalid 'arbitrary Boolean final oracle' corpus-fixture-output-oracle evals/evals.json /cases/1/fixtures/0
expect_invalid 'arbitrary number final oracle' corpus-fixture-output-oracle evals/evals.json /cases/2/fixtures/0
expect_invalid 'arbitrary null final oracle' corpus-fixture-output-oracle evals/evals.json /cases/3/fixtures/0
expect_invalid 'arbitrary array final oracle' corpus-fixture-output-oracle evals/evals.json /cases/4/fixtures/0
expect_invalid 'arbitrary object final oracle' corpus-fixture-output-oracle evals/evals.json /cases/5/fixtures/0
expect_invalid 'arbitrary string file oracle' corpus-fixture-output-oracle evals/evals.json /cases/6/fixtures/0
expect_invalid 'arbitrary Boolean file oracle' corpus-fixture-output-oracle evals/evals.json /cases/7/fixtures/0
expect_invalid 'arbitrary number file oracle' corpus-fixture-output-oracle evals/evals.json /cases/8/fixtures/0
expect_invalid 'arbitrary null file oracle' corpus-fixture-output-oracle evals/evals.json /cases/9/fixtures/0
expect_invalid 'arbitrary array file oracle' corpus-fixture-output-oracle evals/evals.json /cases/10/fixtures/0
expect_invalid 'arbitrary object file oracle' corpus-fixture-output-oracle evals/evals.json /cases/11/fixtures/0
expect_invalid 'arbitrary string receipt oracle' corpus-fixture-output-oracle evals/evals.json /cases/12/fixtures/0
expect_invalid 'arbitrary Boolean receipt oracle' corpus-fixture-output-oracle evals/evals.json /cases/13/fixtures/0
expect_invalid 'arbitrary number receipt oracle' corpus-fixture-output-oracle evals/evals.json /cases/14/fixtures/0
expect_invalid 'arbitrary null receipt oracle' corpus-fixture-output-oracle evals/evals.json /cases/15/fixtures/0
expect_invalid 'arbitrary array receipt oracle' corpus-fixture-output-oracle evals/evals.json /cases/16/fixtures/0
expect_invalid 'arbitrary object receipt oracle' corpus-fixture-output-oracle evals/evals.json /cases/17/fixtures/0

make_package worker-raw-evidence 'description: Corpus with legitimate raw evidence values.'
mkdir -p "$PACKAGE/evals/fixtures"
printf '%s\n' '{"proposalSnapshot":{"digest":"sha256:1111111111111111111111111111111111111111111111111111111111111111"}}' >"$PACKAGE/evals/fixtures/digest.json"
printf '%s\n' '{"legacyRecords":[{"phase":"complete"}]}' >"$PACKAGE/evals/fixtures/phase.json"
cat >"$PACKAGE/evals/evals.json" <<'EOF'
{"schemaVersion":1,"skill":"worker-raw-evidence","cases":[
  {"id":"digest-evidence","prompt":"Read the approval digest","fixtures":["digest.json"],"expected":"Report the observed digest","assertions":[{"id":"digest","kind":"final-json-path-equals","pointer":"/requiredApprovalDigest","expected":"sha256:1111111111111111111111111111111111111111111111111111111111111111"}]},
  {"id":"phase-evidence","prompt":"Classify the legacy record phase","fixtures":["phase.json"],"expected":"Derive the status","assertions":[{"id":"status","kind":"final-json-path-equals","pointer":"/status","expected":"complete"}]}
]}
EOF
expect_valid 'legitimate raw evidence values' worker-raw-evidence \
  'Corpus with legitimate raw evidence values.' \
  'SKILL.md:skill,evals/evals.json:eval,evals/fixtures/digest.json:eval,evals/fixtures/phase.json:eval,references/guide.md:reference' \
  2 0

make_package worker-undeclared-raw-passthrough 'description: Corpus with an undeclared raw passthrough.'
mkdir -p "$PACKAGE/evals/fixtures"
printf '%s\n' '{"endpoint":"https://mcp.linear.app/mcp"}' >"$PACKAGE/evals/fixtures/observation.json"
cat >"$PACKAGE/evals/evals.json" <<'EOF'
{"schemaVersion":1,"skill":"worker-undeclared-raw-passthrough","cases":[
  {"id":"endpoint-observation","prompt":"Return the observed endpoint","fixtures":["observation.json"],"expected":"Echo the raw observation","assertions":[{"id":"endpoint","kind":"final-json-path-equals","pointer":"/endpoint","expected":"https://mcp.linear.app/mcp"}]}
]}
EOF
expect_invalid 'undeclared same-key raw passthrough' corpus-fixture-output-oracle evals/evals.json /cases/0/fixtures/0

make_package worker-declared-raw-passthrough 'description: Corpus with a declared raw passthrough.'
mkdir -p "$PACKAGE/evals/fixtures"
printf '%s\n' '{"endpoint":"https://mcp.linear.app/mcp"}' >"$PACKAGE/evals/fixtures/observation.json"
cat >"$PACKAGE/evals/evals.json" <<'EOF'
{"schemaVersion":1,"skill":"worker-declared-raw-passthrough","cases":[
  {"id":"endpoint-observation","prompt":"Return the observed endpoint","fixtures":["observation.json"],"fixturePassthroughAssertions":[{"assertionId":"endpoint","fixture":"observation.json","pointer":"/endpoint"}],"expected":"Echo the raw observation","assertions":[{"id":"endpoint","kind":"final-json-path-equals","pointer":"/endpoint","expected":"https://mcp.linear.app/mcp"}]}
]}
EOF
expect_valid 'declared same-key raw passthrough' worker-declared-raw-passthrough \
  'Corpus with a declared raw passthrough.' \
  'SKILL.md:skill,evals/evals.json:eval,evals/fixtures/observation.json:eval,references/guide.md:reference' \
  1 0

make_package worker-invalid-raw-passthrough 'description: Corpus with an invalid raw passthrough declaration.'
mkdir -p "$PACKAGE/evals/fixtures"
printf '%s\n' '{"endpoint":"https://mcp.linear.app/mcp"}' >"$PACKAGE/evals/fixtures/observation.json"
cat >"$PACKAGE/evals/evals.json" <<'EOF'
{"schemaVersion":1,"skill":"worker-invalid-raw-passthrough","cases":[
  {"id":"endpoint-observation","prompt":"Return the observed endpoint","fixtures":["observation.json"],"fixturePassthroughAssertions":["missing"],"expected":"Echo the raw observation","assertions":[{"id":"endpoint","kind":"final-json-path-equals","pointer":"/endpoint","expected":"https://mcp.linear.app/mcp"}]}
]}
EOF
expect_invalid 'raw passthrough names a private assertion' corpus-invalid-fixture-passthrough evals/evals.json /cases/0/fixturePassthroughAssertions/0

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

# A repository-root skill is a valid tracked-only package. Its canonical package
# path is `.`, and Git enumeration still excludes untracked files.
ROOT_PACKAGE="$TMP_ROOT/root-package"
mkdir -p "$ROOT_PACKAGE/references"
git init -q "$ROOT_PACKAGE"
PACKAGE="$ROOT_PACKAGE"
REPOSITORY_ROOT=$ROOT_PACKAGE
cat >"$PACKAGE/SKILL.md" <<'EOF'
---
name: root-package
description: Validate a repository-root skill package.
---
# root-package

[Guide](references/guide.md)
EOF
printf '# Guide\n' >"$PACKAGE/references/guide.md"
printf 'untracked\n' >"$PACKAGE/untracked.txt"
git -C "$ROOT_PACKAGE" add -- SKILL.md references/guide.md
run_validator
[ "$STATUS" -eq 0 ] || fail 'repository-root package should be valid in tracked-only mode'
"$NODE" - "$RESULT" <<'NODE'
const fs = require('node:fs');
const result = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const inventory = result.files.map(({ path, type }) => [path, type]);
if (
  result.package.path !== '.' ||
  JSON.stringify(inventory) !== JSON.stringify([
    ['SKILL.md', 'skill'],
    ['references/guide.md', 'reference'],
  ])
) {
  throw new Error(`root package inventory is not canonical: ${JSON.stringify(result)}`);
}
NODE

unset REPOSITORY_ROOT TRACKED_ONLY

# Multiple independent errors pin complete error invariants and path/field/code ordering.
make_package multiple-errors 'description: Package with two deterministic errors.'
printf 'TOKEN=not-a-real-secret\n' >"$PACKAGE/.env.local"
printf '\n[Missing](references/missing.md)\n' >>"$PACKAGE/SKILL.md"
expect_invalid 'multiple-error invariants' package-forbidden-path .env.local ''
expect_exact_errors 'multiple sorted errors' \
  '[{"code":"package-forbidden-path","path":".env.local","field":""},{"code":"link-target-missing","path":"SKILL.md","field":"/links/1"}]'

printf 'PASS: validator package and corpus contracts\n'
