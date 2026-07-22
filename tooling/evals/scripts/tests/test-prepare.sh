#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/path-utils.sh"
REPOSITORY_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../../../.." && pwd)
SOURCE_PREPARER="$SCRIPT_DIR/../prepare.mjs"
SOURCE_VALIDATOR="$REPOSITORY_ROOT/skills/using-woostack/scripts/validate-skill-package.mjs"
if command -v cygpath >/dev/null 2>&1; then
  git() {
    local converted=()
    local argument
    for argument in "$@"; do
      if [[ "$argument" == /[A-Za-z]/* || "$argument" == /tmp/* ]]; then
        argument=$(node_native_path "$argument")
      fi
      converted+=("$argument")
    done
    command git "${converted[@]}"
  }
fi
NODE=${NODE:-node}
NODE_PLATFORM=$("$NODE" -p 'process.platform')
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/woostack-eval-prepare.XXXXXX")
CANONICAL_TMP_ROOT=$(CDPATH= cd -- "$TMP_ROOT" && pwd -P)
CHILD_PIDS=()

untrack_pid() {
  removed=$1
  for child_index in "${!CHILD_PIDS[@]}"; do
    if [ "${CHILD_PIDS[$child_index]}" = "$removed" ]; then
      unset 'CHILD_PIDS[child_index]'
      return
    fi
  done
}

cleanup() {
  cleanup_status=$?
  trap - EXIT HUP INT TERM
  for tracked in "${CHILD_PIDS[@]-}"; do
    [ -n "$tracked" ] && kill -TERM "$tracked" 2>/dev/null || :
  done
  for tracked in "${CHILD_PIDS[@]-}"; do
    [ -n "$tracked" ] && wait "$tracked" 2>/dev/null || :
  done
  rm -rf "$TMP_ROOT"
  exit "$cleanup_status"
}
trap cleanup EXIT HUP INT TERM

start_timed() {
  timeout_seconds=$1
  timed_stdout=$2
  timed_stderr=$3
  shift 3
  TIMED_OUT_MARKER="$timed_stderr.timeout"
  rm -f "$TIMED_OUT_MARKER"
  "$@" >"$timed_stdout" 2>"$timed_stderr" &
  TIMED_PID=$!
  CHILD_PIDS+=("$TIMED_PID")
  "$NODE" - "$TIMED_PID" "$timeout_seconds" "$TIMED_OUT_MARKER" <<'NODE' &
const fs = require('node:fs');
const [pidText, timeoutText, marker] = process.argv.slice(2);
const pid = Number(pidText);
setTimeout(() => {
  try {
    process.kill(pid, 0);
    fs.writeFileSync(marker, `process exceeded ${timeoutText} seconds\n`);
    process.kill(pid, 'SIGTERM');
    setTimeout(() => {
      try {
        process.kill(pid, 'SIGKILL');
      } catch {}
      process.exit(0);
    }, 1000);
  } catch {
    process.exit(0);
  }
}, Number(timeoutText) * 1000);
NODE
  TIMED_WATCHDOG_PID=$!
  CHILD_PIDS+=("$TIMED_WATCHDOG_PID")
}

finish_timed() {
  timed_pid=$1
  watchdog_pid=$2
  timeout_marker=$3
  if wait "$timed_pid"; then
    timed_status=0
  else
    timed_status=$?
  fi
  untrack_pid "$timed_pid"
  kill "$watchdog_pid" 2>/dev/null || :
  wait "$watchdog_pid" 2>/dev/null || :
  untrack_pid "$watchdog_pid"
  if [ -f "$timeout_marker" ]; then
    return 124
  fi
  return "$timed_status"
}

run_timed() {
  timeout_seconds=$1
  timed_stdout=$2
  timed_stderr=$3
  shift 3
  start_timed "$timeout_seconds" "$timed_stdout" "$timed_stderr" "$@"
  child_pid=$TIMED_PID
  watchdog_pid=$TIMED_WATCHDOG_PID
  timeout_marker=$TIMED_OUT_MARKER
  finish_timed "$child_pid" "$watchdog_pid" "$timeout_marker"
}

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_file_contains() {
  file=$1
  text=$2
  label=$3
  [ -f "$file" ] || fail "$label: missing $file"
  grep -F -- "$text" "$file" >/dev/null || fail "$label: expected '$text' in $file"
}

write_skill() {
  package=$1
  name=$2
  description=$3
  mkdir -p "$package/references"
  cat >"$package/SKILL.md" <<EOF
---
name: $name
description: $description
---
# $name

[Guide](references/guide.md)
EOF
  printf '# Guide\n\n%s\n' "$description" >"$package/references/guide.md"
}

write_public_authority() {
  package=$1
  extra_route=${2:-}
  mkdir -p "$package/references"
  cat >"$package/SKILL.md" <<'EOF'
---
name: using-woostack
description: Installed public command-routing authority.
---
# using-woostack

[Guide](references/guide.md)

## Command Routing

| Request | Load |
|---|---|
| `/catalog-peer`, load the synthetic public peer | `catalog-peer` |
EOF
  if [ -n "$extra_route" ]; then
    printf '| `/%s`, load the selected-catalog fixture | `%s` |\n' \
      "$extra_route" "$extra_route" >>"$package/SKILL.md"
  fi
  printf '# Guide\n' >"$package/references/guide.md"
}

write_corpora() {
  package=$1
  name=$2
  fixture_text=$3
  mkdir -p "$package/evals/fixtures"
  printf '%s alpha\n' "$fixture_text" >"$package/evals/fixtures/alpha.txt"
  printf '%s zeta\n' "$fixture_text" >"$package/evals/fixtures/zeta.txt"
  cat >"$package/evals/evals.json" <<EOF
{
  "schemaVersion": 1,
  "skill": "$name",
  "cases": [{
    "id": "zeta-behavior",
    "prompt": "Use only the zeta fixture without changing the source package.",
    "fixtures": ["zeta.txt"],
    "capabilities": ["read-workspace", "write-workspace"],
    "expected": "Only the copied zeta fixture is available in this isolated workspace.",
    "assertions": [{
      "id": "zeta-fixture-present",
      "kind": "file-contains",
      "file": "fixtures/zeta.txt",
      "substring": "$fixture_text zeta",
      "critical": true
    }]
  }, {
    "id": "alpha-behavior",
    "prompt": "Use only the alpha fixture without changing the source package.",
    "fixtures": ["alpha.txt"],
    "capabilities": ["read-workspace", "write-workspace"],
    "expected": "Only the copied alpha fixture is available in this isolated workspace.",
    "assertions": [{
      "id": "alpha-fixture-present",
      "kind": "file-contains",
      "file": "fixtures/alpha.txt",
      "substring": "$fixture_text alpha",
      "critical": true
    }, {
      "id": "alpha-quality",
      "kind": "qualitative",
      "rubric": "Does the response clearly explain the alpha result?",
      "critical": false
    }, {
      "id": "aardvark-quality",
      "kind": "qualitative",
      "rubric": "Does the response state the alpha result directly?",
      "critical": true
    }]
  }]
}
EOF
  cat >"$package/evals/trigger-evals.json" <<EOF
{
  "schemaVersion": 1,
  "skill": "$name",
  "cases": [{
    "id": "zeta-trigger",
    "query": "Do not run the target evaluator workflow.",
    "shouldTrigger": false,
    "expectedSkill": "none",
    "conflictsWith": ["$name"]
  }, {
    "id": "alpha-trigger",
    "query": "Run the target evaluator workflow.",
    "shouldTrigger": true,
    "expectedSkill": "$name",
    "conflictsWith": ["catalog-peer"]
  }]
}
EOF
}

validate_setup_package() {
  package=$1
  result=$2
  errors="$result.stderr"
  if ! run_timed 10 "$result" "$errors" "$NODE" "$SOURCE_VALIDATOR" --package "$package" \
    --repository-root "$(dirname -- "$package")" --json; then
    cat "$errors" >&2
    fail "temporary package setup must validate before the Red assertion"
  fi
  "$NODE" - "$result" <<'NODE'
const fs = require('node:fs');
const result = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
if (result.schemaVersion !== 1 || result.valid !== true || result.errors.length !== 0) {
  throw new Error(`invalid temporary package setup: ${JSON.stringify(result)}`);
}
NODE
}

# Prove the synthetic package setup is valid before reporting the intentional Red failure.
SETUP_PACKAGE="$TMP_ROOT/setup/prepare-target"
write_skill "$SETUP_PACKAGE" prepare-target 'Candidate package used by the preparation contract.'
write_corpora "$SETUP_PACKAGE" prepare-target 'fixture payload'
validate_setup_package "$SETUP_PACKAGE" "$TMP_ROOT/setup-validation.json"

if [ ! -f "$SOURCE_PREPARER" ]; then
  fail "prepare.mjs is missing (expected Red: temporary package setup validated)"
fi

# Run against a synthetic maintainer checkout so the default catalog root and canonical
# resolve-base.sh location are observable rather than inherited from this checkout.
INSTALL_ROOT="$TMP_ROOT/maintainer-checkout"
PREPARER="$INSTALL_ROOT/tooling/evals/scripts/prepare.mjs"
VALIDATOR="$INSTALL_ROOT/skills/using-woostack/scripts/validate-skill-package.mjs"
HASH_HELPER="$TMP_ROOT/hash-package.mjs"
cat >"$HASH_HELPER" <<'NODE'
import { pathToFileURL } from 'node:url';
const [validatorPath, packagePath] = process.argv.slice(2);
const { hashPackage } = await import(pathToFileURL(validatorPath).href);
const hash = await hashPackage(packagePath);
if (!/^sha256:[0-9a-f]{64}$/.test(hash ?? '')) {
  throw new Error(`cannot inventory-hash copied package: ${packagePath}`);
}
process.stdout.write(hash);
NODE
RESOLVER="$INSTALL_ROOT/skills/woostack-init/scripts/resolve-base.sh"
mkdir -p "$(dirname -- "$PREPARER")" "$(dirname -- "$VALIDATOR")" "$(dirname -- "$RESOLVER")"
cp "$SOURCE_PREPARER" "$PREPARER"
cp "$SOURCE_VALIDATOR" "$VALIDATOR"
cat >"$RESOLVER" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
: "${RESOLVER_MARKER:?RESOLVER_MARKER is required by the contract test}"
printf 'invoked\n' >>"$RESOLVER_MARKER"
if [ -n "${RESOLVER_MUTATE_FILE:-}" ]; then
  printf '\nmutation during preparation\n' >>"$RESOLVER_MUTATE_FILE"
  git add -- "$RESOLVER_MUTATE_FILE"
  git commit -qm 'mutate during preparation'
fi
printf '%s\n' "${WOOSTACK_BASE_BRANCH:?WOOSTACK_BASE_BRANCH is required by the contract test}"
SH
chmod 0755 "$RESOLVER"
write_skill "$INSTALL_ROOT/skills/woostack-init" woostack-init 'Installed resolver skill description.'
write_skill "$INSTALL_ROOT/skills/catalog-peer" catalog-peer 'Installed catalog peer description.'
write_public_authority "$INSTALL_ROOT/skills/using-woostack"

SYSTEM_TMP="$TMP_ROOT/system-tmp"
mkdir -p "$SYSTEM_TMP"
CANONICAL_SYSTEM_TMP=$(CDPATH= cd -- "$SYSTEM_TMP" && pwd -P)
INVOCATION=0
STATUS=0
STDOUT_FILE=
STDERR_FILE=
RUN_ROOT=

run_prepare() {
  INVOCATION=$((INVOCATION + 1))
  STDOUT_FILE="$TMP_ROOT/stdout.$INVOCATION"
  STDERR_FILE="$TMP_ROOT/stderr.$INVOCATION"
  set +e
  run_timed 10 "$STDOUT_FILE" "$STDERR_FILE" env \
    TMPDIR="${TEST_TMPDIR:-$SYSTEM_TMP}" \
    WOOSTACK_BASE_BRANCH="${TEST_BASE_BRANCH:-base}" \
    RESOLVER_MARKER="$TMP_ROOT/resolver-marker" \
    "$NODE" "$PREPARER" "$@"
  STATUS=$?
  set -e
  RUN_ROOT=
  if [ "$STATUS" -eq 0 ]; then
    RUN_ROOT=$(shell_native_path "$(cat "$STDOUT_FILE")")
  fi
}

expect_success() {
  label=$1
  shift
  run_prepare "$@"
  if [ "$STATUS" -ne 0 ]; then
    printf 'FAIL: %s should succeed (exit %s)\n' "$label" "$STATUS" >&2
    cat "$STDERR_FILE" >&2
    exit 1
  fi
  [ -n "$RUN_ROOT" ] || fail "$label: missing run-root output"
  [ "$(printf '%s\n' "$RUN_ROOT" | wc -l | tr -d ' ')" -eq 1 ] || fail "$label: stdout must be one path"
  [ -d "$RUN_ROOT" ] || fail "$label: reported run root does not exist: $RUN_ROOT"
  [ -f "$RUN_ROOT/manifest.json" ] || fail "$label: manifest.json is missing"
}

snapshot_entries() {
  directory=$1
  output=$2
  "$NODE" - "$directory" "$output" <<'NODE'
const fs = require('node:fs');
const [directory, output] = process.argv.slice(2);
let entries = [];
try {
  entries = fs.readdirSync(directory).sort();
} catch (error) {
  if (error.code !== 'ENOENT' && error.code !== 'ENOTDIR') throw error;
}
fs.writeFileSync(output, `${JSON.stringify(entries)}\n`);
NODE
}

expect_failure() {
  label=$1
  shift
  failure_out_root=
  failure_run_id=
  wanted_value=
  for argument in "$@"; do
    if [ -n "$wanted_value" ]; then
      case "$wanted_value" in
        out-root) failure_out_root=$argument ;;
        run-id) failure_run_id=$argument ;;
      esac
      wanted_value=
      continue
    fi
    case "$argument" in
      --out-root) wanted_value=out-root ;;
      --run-id) wanted_value=run-id ;;
    esac
  done
  residue_before="$TMP_ROOT/residue.$((INVOCATION + 1)).before.json"
  residue_after="$TMP_ROOT/residue.$((INVOCATION + 1)).after.json"
  if [ -n "$failure_out_root" ] && [ -n "$failure_run_id" ]; then
    snapshot_entries "$failure_out_root" "$residue_before"
  fi
  run_prepare "$@"
  [ "$STATUS" -ne 0 ] || fail "$label should fail"
  [ ! -s "$STDOUT_FILE" ] || fail "$label: failure emitted a success path"
  [ -s "$STDERR_FILE" ] || fail "$label: failure must explain itself on stderr"
  if [ -n "$failure_out_root" ] && [ -n "$failure_run_id" ]; then
    snapshot_entries "$failure_out_root" "$residue_after"
    cmp -s "$residue_before" "$residue_after" ||
      fail "$label: failure left a final or staging run-root residue"
  fi
}

package_hash() {
  package=$1
  output=$2
  errors="$output.stderr"
  if ! run_timed 10 "$output" "$errors" "$NODE" "$VALIDATOR" --package "$package" \
    --repository-root "$(dirname -- "$package")" --json; then
    cat "$errors" >&2
    fail "validator failed while hashing $package"
  fi
  "$NODE" - "$output" <<'NODE'
const fs = require('node:fs');
const result = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
if (!result.valid || !/^sha256:[0-9a-f]{64}$/.test(result.packageHash)) {
  throw new Error(`cannot hash package: ${JSON.stringify(result)}`);
}
process.stdout.write(result.packageHash);
NODE
}

raw_package_hash() {
  package=$1
  output=$2
  errors="$output.stderr"
  if ! run_timed 10 "$output" "$errors" "$NODE" "$HASH_HELPER" "$VALIDATOR" "$package"; then
    cat "$errors" >&2
    fail "hashPackage failed for copied capability package $package"
  fi
  cat "$output"
}

assert_private_run_root() {
  "$NODE" - "$1" <<'NODE'
const fs = require('node:fs');
const root = process.argv[2];
if (process.platform !== 'win32') {
  const mode = fs.statSync(root).mode & 0o777;
  if (mode !== 0o700) throw new Error(`${root} mode is ${mode.toString(8)}, expected 700`);
}
NODE
}

assert_bounded_diagnostic() {
  "$NODE" - "$1" <<'NODE'
const fs = require('node:fs');
const content = fs.readFileSync(process.argv[2]);
if (content.byteLength > 1100) throw new Error(`diagnostic exceeds bound: ${content.byteLength}`);
const text = content.toString('utf8');
if (!text.endsWith('\n') || text.slice(0, -1).includes('\n')) {
  throw new Error(`diagnostic must occupy exactly one line: ${JSON.stringify(text)}`);
}
if (/[\x00-\x1F\x7F]/.test(text.slice(0, -1))) {
  throw new Error(`diagnostic contains ASCII control bytes: ${JSON.stringify(text)}`);
}
NODE
}

assert_manifest() {
  manifest=$1
  expected_run_id=$2
  expected_target=$3
  expected_mode=$4
  expected_runs=$5
  expected_baseline=$6
  expected_hash=$7
  "$NODE" - "$manifest" "$expected_run_id" "$expected_target" "$expected_mode" \
    "$expected_runs" "$expected_baseline" "$expected_hash" <<'NODE'
const fs = require('node:fs');
const assert = require('node:assert/strict');
const [file, runId, targetSkill, mode, runsText, baselineText, packageHash] = process.argv.slice(2);
const actual = JSON.parse(fs.readFileSync(file, 'utf8'));
const runs = Number(runsText);
const baseline = JSON.parse(baselineText);
const canonical = (value) => {
  if (Array.isArray(value)) return value.map(canonical);
  if (value !== null && typeof value === 'object') {
    return Object.fromEntries(Object.keys(value).sort().map((key) => [key, canonical(value[key])]));
  }
  return value;
};
const same = (a, b) => JSON.stringify(canonical(a)) === JSON.stringify(canonical(b));
const exactTopKeys = [
  'baseline', 'expected', 'gradingPlan', 'mode', 'originalPackageHash', 'packageHashes',
  'pairs', 'runConfiguration', 'runId', 'runs', 'schemaVersion', 'targetSkill',
];
if (!same(Object.keys(actual).sort(), exactTopKeys)) {
  throw new Error(`unexpected manifest keys: ${Object.keys(actual).sort().join(',')}`);
}
if (baseline.kind === 'git-ref' && !/^[0-9a-f]{40}$/.test(baseline.identity)) {
  throw new Error(`git-ref identity is not a resolved lowercase commit: ${baseline.identity}`);
}
const selected = [];
if (mode === 'behavior' || mode === 'all') {
  selected.push(['alpha-behavior', 'behavior'], ['zeta-behavior', 'behavior']);
}
if (mode === 'triggers' || mode === 'all') {
  selected.push(['alpha-trigger', 'trigger'], ['zeta-trigger', 'trigger']);
}
const expected = [];
const pairs = [];
for (const [caseId, kind] of selected) {
  for (let repetition = 1; repetition <= runs; repetition += 1) {
    expected.push({ caseId, variant: 'candidate', repetition, kind });
    expected.push({ caseId, variant: 'baseline', repetition, kind });
    pairs.push({
      caseId,
      repetition,
      candidate: `cases/${caseId}/${repetition}/candidate`,
      baseline: `cases/${caseId}/${repetition}/baseline`,
    });
  }
}
assert.deepEqual(Object.keys(actual.packageHashes).sort(), ['baseline', 'candidate']);
assert.match(actual.packageHashes.candidate, /^sha256:[0-9a-f]{64}$/);
if (actual.baseline.kind === 'none') {
  assert.equal(actual.packageHashes.baseline, null);
} else {
  assert.match(actual.packageHashes.baseline, /^sha256:[0-9a-f]{64}$/);
}
const expectedGradingPlan = [];
for (const entry of expected) {
  if (entry.variant === 'candidate'
      && entry.kind === 'behavior'
      && entry.caseId === 'alpha-behavior') {
    for (const assertionId of ['aardvark-quality', 'alpha-quality']) {
      expectedGradingPlan.push({
        caseId: entry.caseId,
        repetition: entry.repetition,
        assertionId,
        graderId: null,
      });
    }
  }
}
assert.deepEqual(actual.gradingPlan, expectedGradingPlan);
const wanted = {
  schemaVersion: 1,
  runId,
  targetSkill,
  mode,
  runs,
  baseline,
  runConfiguration: {
    host: null,
    runner: null,
    model: null,
    sessionIdentity: null,
    tier: null,
    effort: null,
  },
  originalPackageHash: packageHash,
  packageHashes: actual.packageHashes,
  gradingPlan: expectedGradingPlan,
  expected,
  pairs,
};
if (!same(actual, wanted)) {
  throw new Error(`manifest mismatch\nactual=${JSON.stringify(actual)}\nwanted=${JSON.stringify(wanted)}`);
}
for (const entry of actual.expected) {
  if (!same(Object.keys(entry).sort(), ['caseId', 'kind', 'repetition', 'variant'])) {
    throw new Error(`unexpected expected identity shape: ${JSON.stringify(entry)}`);
  }
  if (!['candidate', 'baseline'].includes(entry.variant) || !['behavior', 'trigger'].includes(entry.kind)) {
    throw new Error(`invalid expected identity status: ${JSON.stringify(entry)}`);
  }
}
for (const pair of actual.pairs) {
  if (!same(Object.keys(pair).sort(), ['baseline', 'candidate', 'caseId', 'repetition'])) {
    throw new Error(`pair must not decide waves or concurrency: ${JSON.stringify(pair)}`);
  }
}
NODE
}

assert_frozen_definitions() {
  root=$1
  source_package=$2
  mode=$3
  "$NODE" - "$root" "$source_package" "$mode" <<'NODE'
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const [root, sourcePackage, mode] = process.argv.slice(2);
const expected = new Map();
for (const [kind, sourceName, enabled] of [
  ['behavior', 'evals.json', mode === 'behavior' || mode === 'all'],
  ['trigger', 'trigger-evals.json', mode === 'triggers' || mode === 'all'],
]) {
  if (!enabled) continue;
  const corpus = JSON.parse(
    fs.readFileSync(path.join(sourcePackage, 'evals', sourceName), 'utf8'),
  );
  for (const definition of corpus.cases) {
    expected.set(`${kind}.${definition.id}.json`, definition);
  }
}
const definitionsRoot = path.join(root, 'definitions');
const actualNames = fs.readdirSync(definitionsRoot).sort();
assert.deepEqual(actualNames, [...expected.keys()].sort());
for (const name of actualNames) {
  const definitionPath = path.join(definitionsRoot, name);
  const stats = fs.lstatSync(definitionPath);
  assert.equal(stats.isFile(), true, `${name} must be a regular file`);
  assert.equal(stats.isSymbolicLink(), false, `${name} must not be a symlink`);
  if (process.platform !== 'win32') {
    assert.equal(stats.mode & 0o777, 0o600, `${name} must be host-private`);
  }
  const bytes = fs.readFileSync(definitionPath, 'utf8');
  assert.equal(bytes.endsWith('\n'), true, `${name} must end with one newline`);
  assert.deepEqual(JSON.parse(bytes), expected.get(name));
}
const pending = [path.join(root, 'cases')];
while (pending.length > 0) {
  const directory = pending.pop();
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const child = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      assert.notEqual(entry.name, 'definitions', 'definitions leaked into a worker root');
      pending.push(child);
    }
  }
}
NODE
}

assert_frozen_package_hashes() {
  manifest=$1
  candidate_hash=$2
  baseline_hash=$3
  "$NODE" - "$manifest" "$candidate_hash" "$baseline_hash" <<'NODE'
const assert = require('node:assert/strict');
const fs = require('node:fs');

const [manifestPath, candidateHash, baselineHash] = process.argv.slice(2);
const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
assert.equal(manifest.packageHashes.candidate, candidateHash);
assert.equal(
  manifest.packageHashes.baseline,
  baselineHash === 'null' ? null : baselineHash,
);
NODE
}

assert_catalog() {
  catalog=$1
  expected_json=$2
  "$NODE" - "$catalog" "$expected_json" <<'NODE'
const fs = require('node:fs');
const actual = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const expected = JSON.parse(process.argv[3]);
const canonical = (value) => {
  if (Array.isArray(value)) return value.map(canonical);
  if (value !== null && typeof value === 'object') {
    return Object.fromEntries(Object.keys(value).sort().map((key) => [key, canonical(value[key])]));
  }
  return value;
};
const same = (a, b) => JSON.stringify(canonical(a)) === JSON.stringify(canonical(b));
if (!same(actual, expected)) {
  throw new Error(`catalog mismatch: ${JSON.stringify(actual)} != ${JSON.stringify(expected)}`);
}
if (!same(Object.keys(actual).sort(), ['schemaVersion', 'skills'])) {
  throw new Error(`unexpected catalog keys: ${Object.keys(actual)}`);
}
for (const skill of actual.skills) {
  if (!same(Object.keys(skill).sort(), ['description', 'name'])) {
    throw new Error(`unexpected catalog entry: ${JSON.stringify(skill)}`);
  }
}
NODE
}

assert_isolated_all_workspace() {
  root=$1
  candidate_description=$2
  baseline_description=$3
  assert_file_contains "$root/cases/alpha-behavior/1/candidate/package/SKILL.md" "$candidate_description" 'candidate package copy'
  assert_file_contains "$root/cases/alpha-behavior/1/baseline/package/SKILL.md" "$baseline_description" 'baseline package copy'
  assert_file_contains "$root/cases/alpha-behavior/1/candidate/fixtures/alpha.txt" 'candidate fixture alpha' 'candidate alpha fixture copy'
  assert_file_contains "$root/cases/alpha-behavior/1/baseline/fixtures/alpha.txt" 'candidate fixture alpha' 'baseline alpha fixture copy'
  assert_file_contains "$root/cases/zeta-behavior/1/candidate/fixtures/zeta.txt" 'candidate fixture zeta' 'candidate zeta fixture copy'
  assert_file_contains "$root/cases/zeta-behavior/1/baseline/fixtures/zeta.txt" 'candidate fixture zeta' 'baseline zeta fixture copy'
  "$NODE" - "$root" <<'NODE'
const fs = require('node:fs');
const path = require('node:path');
const root = process.argv[2];
const files = [
  'cases/alpha-behavior/1/candidate/package/SKILL.md',
  'cases/alpha-behavior/1/baseline/package/SKILL.md',
  'cases/alpha-behavior/1/candidate/fixtures/alpha.txt',
  'cases/alpha-behavior/1/baseline/fixtures/alpha.txt',
  'cases/zeta-behavior/1/candidate/fixtures/zeta.txt',
  'cases/zeta-behavior/1/baseline/fixtures/zeta.txt',
];
for (const relative of files) {
  const full = path.join(root, relative);
  const stat = fs.lstatSync(full);
  if (!stat.isFile() || stat.isSymbolicLink()) throw new Error(`unsafe copied file: ${relative}`);
}
for (const [caseId, own, other] of [
  ['alpha-behavior', 'alpha.txt', 'zeta.txt'],
  ['zeta-behavior', 'zeta.txt', 'alpha.txt'],
]) {
  for (const variant of ['candidate', 'baseline']) {
    const fixtureRoot = path.join(root, 'cases', caseId, '1', variant, 'fixtures');
    if (!fs.existsSync(path.join(fixtureRoot, own))) throw new Error(`${caseId}/${variant} lost ${own}`);
    if (fs.existsSync(path.join(fixtureRoot, other))) {
      throw new Error(`${caseId}/${variant} received undeclared fixture ${other}`);
    }
  }
}
for (const [candidateRelative, baselineRelative, label] of [
  [files[0], files[1], 'packages'],
  [files[2], files[3], 'alpha fixtures'],
  [files[4], files[5], 'zeta fixtures'],
]) {
  const left = fs.statSync(path.join(root, candidateRelative));
  const right = fs.statSync(path.join(root, baselineRelative));
  if (left.dev === right.dev && left.ino === right.ino) throw new Error(`${label} are hard-linked`);
}
const evidence = path.join(root, 'evidence');
if (!fs.statSync(evidence).isDirectory()) throw new Error('evidence must be a directory');
if (fs.readdirSync(evidence).length !== 0) throw new Error('preparation must not prefill success evidence');
for (const caseId of ['alpha-behavior', 'zeta-behavior']) {
  for (const variant of ['candidate', 'baseline']) {
    const capabilityRoot = path.join(root, 'cases', caseId, '1', variant);
    const relative = path.relative(capabilityRoot, evidence);
    if (relative === '' || (!relative.startsWith('..' + path.sep) && relative !== '..')) {
      throw new Error('evidence must be outside worker capability roots');
    }
  }
}
NODE
}

# Build a repository whose baseline and dirty candidate differ while retaining the same corpora.
GIT_REPO="$TMP_ROOT/git-repo"
git init -q -b base "$GIT_REPO"
CANONICAL_GIT_REPO=$(CDPATH= cd -- "$GIT_REPO" && pwd -P)
git -C "$GIT_REPO" config user.email evaluator@example.invalid
git -C "$GIT_REPO" config user.name 'Evaluator Contract'
TARGET="$GIT_REPO/skills/prepare-target"
write_skill "$TARGET" prepare-target 'Baseline target description.'
write_corpora "$TARGET" prepare-target 'candidate fixture'
printf '#!/usr/bin/env bash\nexit 0\n' >"$TARGET/references/executable.sh"
chmod 0755 "$TARGET/references/executable.sh"
write_skill "$GIT_REPO/skills/catalog-peer" catalog-peer 'Repository catalog peer description.'
write_public_authority "$GIT_REPO/skills/using-woostack"
printf '\n[Catalog peer guide](../catalog-peer/references/guide.md)\n' >>"$TARGET/SKILL.md"
printf '.woostack/tmp/skill-evals/\n' >"$GIT_REPO/.gitignore"
BASELINE_HASH=$(package_hash "$TARGET" "$TMP_ROOT/baseline-validation.json")
git -C "$GIT_REPO" add .
git -C "$GIT_REPO" commit -qm 'baseline package'
BASE_COMMIT=$(git -C "$GIT_REPO" rev-parse HEAD)
git -C "$GIT_REPO" tag -a baseline-package -m 'annotated baseline package' "$BASE_COMMIT"
git -C "$GIT_REPO" switch -qc feature
write_skill "$TARGET" prepare-target 'Dirty candidate target description.'
printf '\n[Catalog peer guide](../catalog-peer/references/guide.md)\n' >>"$TARGET/SKILL.md"
printf 'dirty candidate only\n' >"$TARGET/references/dirty-only.txt"
CANDIDATE_HASH=$(package_hash "$TARGET" "$TMP_ROOT/candidate-validation.json")
HEAD_BEFORE=$(git -C "$GIT_REPO" rev-parse HEAD)
INDEX_TREE_BEFORE=$(git -C "$GIT_REPO" write-tree)
git -C "$GIT_REPO" status --porcelain=v1 -z --untracked-files=all >"$TMP_ROOT/status.before"

# An annotated explicit ref takes precedence and resolves to the peeled lowercase commit even
# when the implicit resolver points to an invalid branch.
TEST_BASE_BRANCH=does-not-exist expect_success 'explicit annotated baseline ref precedence' \
  --target "$TARGET/SKILL.md" --mode all --runs 2 --baseline-ref baseline-package \
  --catalog-root "$GIT_REPO/skills" --out-root "$TMP_ROOT/runs" --run-id explicit-ref
[ "$RUN_ROOT" = "$CANONICAL_TMP_ROOT/runs/explicit-ref" ] || fail 'explicit run root path mismatch'
assert_private_run_root "$RUN_ROOT"
assert_manifest "$RUN_ROOT/manifest.json" explicit-ref prepare-target all 2 \
  "{\"kind\":\"git-ref\",\"identity\":\"$BASE_COMMIT\"}" "$CANDIDATE_HASH"
assert_frozen_definitions "$RUN_ROOT" "$TARGET" all
assert_isolated_all_workspace "$RUN_ROOT" 'Dirty candidate target description.' 'Baseline target description.'
[ -f "$RUN_ROOT/cases/alpha-behavior/1/candidate/package/references/dirty-only.txt" ] || fail 'dirty candidate file was not preserved'
[ ! -e "$RUN_ROOT/cases/alpha-behavior/1/baseline/package/references/dirty-only.txt" ] || fail 'baseline was read from the dirty worktree'
"$NODE" - "$RUN_ROOT/cases/alpha-behavior/1/baseline/package/references/executable.sh" <<'NODE'
const fs = require('node:fs');
if (process.platform !== 'win32') {
  const mode = fs.statSync(process.argv[2]).mode & 0o777;
  if (mode !== 0o755) throw new Error(`Git baseline executable mode lost: ${mode.toString(8)}`);
}
NODE
assert_catalog "$RUN_ROOT/cases/alpha-trigger/1/candidate/catalog.json" \
  '{"schemaVersion":1,"skills":[{"name":"catalog-peer","description":"Repository catalog peer description."},{"name":"prepare-target","description":"Dirty candidate target description."},{"name":"using-woostack","description":"Installed public command-routing authority."}]}'
assert_catalog "$RUN_ROOT/cases/alpha-trigger/1/baseline/catalog.json" \
  '{"schemaVersion":1,"skills":[{"name":"catalog-peer","description":"Repository catalog peer description."},{"name":"prepare-target","description":"Baseline target description."},{"name":"using-woostack","description":"Installed public command-routing authority."}]}'
[ ! -e "$TMP_ROOT/resolver-marker" ] || fail 'explicit baseline-ref must not invoke the implicit resolver'
CANDIDATE_HASH_AFTER=$(package_hash "$TARGET" "$TMP_ROOT/candidate-validation-after.json")
COPIED_BASELINE_HASH=$(raw_package_hash "$RUN_ROOT/cases/alpha-behavior/1/baseline/package" "$TMP_ROOT/copied-baseline-hash.txt")
COPIED_CANDIDATE_HASH=$(raw_package_hash "$RUN_ROOT/cases/alpha-behavior/1/candidate/package" "$TMP_ROOT/copied-candidate-hash.txt")
assert_frozen_package_hashes \
  "$RUN_ROOT/manifest.json" "$COPIED_CANDIDATE_HASH" "$COPIED_BASELINE_HASH"
HEAD_AFTER=$(git -C "$GIT_REPO" rev-parse HEAD)
INDEX_TREE_AFTER=$(git -C "$GIT_REPO" write-tree)
git -C "$GIT_REPO" status --porcelain=v1 -z --untracked-files=all >"$TMP_ROOT/status.after"
[ "$CANDIDATE_HASH_AFTER" = "$CANDIDATE_HASH" ] || fail 'preparation changed the full candidate package hash'
[ "$COPIED_BASELINE_HASH" != "$BASELINE_HASH" ] ||
  fail 'Git-object capability package unexpectedly retained excluded fixture files'
[ ! -e "$RUN_ROOT/cases/alpha-behavior/1/candidate/package/evals/fixtures" ] ||
  fail 'candidate capability package retained evals/fixtures'
[ ! -e "$RUN_ROOT/cases/alpha-behavior/1/baseline/package/evals/fixtures" ] ||
  fail 'baseline capability package retained evals/fixtures'
[ "$HEAD_AFTER" = "$HEAD_BEFORE" ] || fail 'preparation moved HEAD'
[ "$INDEX_TREE_AFTER" = "$INDEX_TREE_BEFORE" ] || fail 'preparation changed the index tree'
cmp -s "$TMP_ROOT/status.before" "$TMP_ROOT/status.after" || fail 'preparation changed NUL-safe porcelain state'

# Explicit IDs are create-once and never overwrite an existing manifest.
MANIFEST_BEFORE=$(shasum -a 256 "$RUN_ROOT/manifest.json" | cut -d ' ' -f 1)
expect_failure 'duplicate explicit run ID' \
  --target "$TARGET" --mode behavior --runs 1 --baseline-ref "$BASE_COMMIT" \
  --catalog-root "$GIT_REPO/skills" --out-root "$TMP_ROOT/runs" --run-id explicit-ref
MANIFEST_AFTER=$(shasum -a 256 "$TMP_ROOT/runs/explicit-ref/manifest.json" | cut -d ' ' -f 1)
[ "$MANIFEST_AFTER" = "$MANIFEST_BEFORE" ] || fail 'duplicate run ID overwrote the first manifest'

# Two concurrent preparers forced onto the same explicit ID produce exactly one complete run.
for collision_index in 1 2; do
  start_timed 10 "$TMP_ROOT/collision.$collision_index.out" "$TMP_ROOT/collision.$collision_index.err" env \
    TMPDIR="$SYSTEM_TMP" WOOSTACK_BASE_BRANCH=base RESOLVER_MARKER="$TMP_ROOT/resolver-marker" \
    "$NODE" "$PREPARER" --target "$TARGET" --mode behavior --runs 1 \
      --baseline-ref "$BASE_COMMIT" --catalog-root "$GIT_REPO/skills" \
      --out-root "$TMP_ROOT/runs" --run-id forced-collision
  eval "collision_pid_$collision_index=\$TIMED_PID"
  eval "collision_watchdog_$collision_index=\$TIMED_WATCHDOG_PID"
  eval "collision_marker_$collision_index=\$TIMED_OUT_MARKER"
done
set +e
finish_timed "$collision_pid_1" "$collision_watchdog_1" "$collision_marker_1"
collision_status_1=$?
finish_timed "$collision_pid_2" "$collision_watchdog_2" "$collision_marker_2"
collision_status_2=$?
set -e
case "$collision_status_1:$collision_status_2" in
  0:1|1:0) ;;
  *) fail "same-ID collision must yield one success and one collision failure: $collision_status_1/$collision_status_2" ;;
esac
if [ "$collision_status_1" -eq 0 ]; then
  collision_loser=2
else
  collision_loser=1
fi
[ ! -s "$TMP_ROOT/collision.$collision_loser.out" ] ||
  fail 'same-ID collision loser emitted a success path'
assert_file_contains "$TMP_ROOT/collision.$collision_loser.err" 'already exists' \
  'same-ID collision diagnostic'
[ -f "$TMP_ROOT/runs/forced-collision/manifest.json" ] ||
  fail 'same-ID collision did not leave exactly one complete run'
assert_private_run_root "$TMP_ROOT/runs/forced-collision"

# An explicit absolute package path also bypasses the implicit resolver and is content-identified.
PATH_BASELINE="$TMP_ROOT/path-baseline/prepare-target"
write_skill "$PATH_BASELINE" prepare-target 'Explicit path baseline description.'
write_corpora "$PATH_BASELINE" prepare-target 'path baseline fixture'
PATH_BASELINE_HASH=$(package_hash "$PATH_BASELINE" "$TMP_ROOT/path-baseline-validation.json")
rm -f "$TMP_ROOT/resolver-marker"
TEST_BASE_BRANCH=does-not-exist expect_success 'explicit baseline path precedence' \
  --target "$TARGET" --mode behavior --runs 1 --baseline-path "$PATH_BASELINE" \
  --catalog-root "$GIT_REPO/skills" --out-root "$TMP_ROOT/runs" --run-id explicit-path
COPIED_PATH_BASELINE_HASH=$(raw_package_hash "$RUN_ROOT/cases/alpha-behavior/1/baseline/package" "$TMP_ROOT/copied-path-baseline-hash.txt")
COPIED_PATH_CANDIDATE_HASH=$(raw_package_hash "$RUN_ROOT/cases/alpha-behavior/1/candidate/package" "$TMP_ROOT/copied-path-candidate-hash.txt")
assert_manifest "$RUN_ROOT/manifest.json" explicit-path prepare-target behavior 1 \
  "{\"kind\":\"path\",\"identity\":\"$COPIED_PATH_BASELINE_HASH\"}" "$CANDIDATE_HASH"
assert_frozen_package_hashes \
  "$RUN_ROOT/manifest.json" "$COPIED_PATH_CANDIDATE_HASH" "$COPIED_PATH_BASELINE_HASH"
assert_file_contains "$RUN_ROOT/cases/alpha-behavior/1/baseline/package/SKILL.md" \
  'Explicit path baseline description.' 'explicit path baseline copy'
[ "$COPIED_PATH_BASELINE_HASH" != "$PATH_BASELINE_HASH" ] ||
  fail 'path capability package unexpectedly retained excluded fixture files'
[ ! -e "$TMP_ROOT/resolver-marker" ] || fail 'explicit baseline-path must not invoke the implicit resolver'

expect_failure 'output root inside explicit baseline package' \
  --target "$TARGET" --mode behavior --runs 1 --baseline-path "$PATH_BASELINE" \
  --out-root "$PATH_BASELINE/evals/output" --run-id baseline-contained-output
[ ! -e "$PATH_BASELINE/evals/output" ] || fail 'baseline-contained output root was created'
TEST_TMPDIR="$PATH_BASELINE/evals/tmp" expect_success 'explicit output ignores unrelated TMPDIR inside baseline package' \
  --target "$TARGET" --mode behavior --runs 1 --baseline-path "$PATH_BASELINE" \
  --out-root "$TMP_ROOT/runs" --run-id baseline-contained-tmpdir-explicit
[ -f "$TMP_ROOT/runs/baseline-contained-tmpdir-explicit/manifest.json" ] ||
  fail 'explicit output root did not produce a complete run'
[ ! -e "$PATH_BASELINE/evals/tmp" ] || fail 'baseline-contained TMPDIR was created'

EQUIVALENT_TARGET="$TMP_ROOT/target-equivalence/equivalent-target"
write_skill "$EQUIVALENT_TARGET" equivalent-target 'Target path-form containment fixture.'
printf 'outside target root\n' >"$TMP_ROOT/target-equivalence/outside.md"
printf '\n[Escaped resource](../outside.md)\n' >>"$EQUIVALENT_TARGET/SKILL.md"
expect_failure 'target directory form enforces package-root containment' \
  --target "$EQUIVALENT_TARGET" --mode behavior --runs 1 \
  --baseline-path "$PATH_BASELINE" --out-root "$TMP_ROOT/runs" --run-id target-dir-containment
assert_file_contains "$STDERR_FILE" 'link-target-outside' 'target directory containment diagnostic'
expect_failure 'target SKILL.md form enforces package-root containment' \
  --target "$EQUIVALENT_TARGET/SKILL.md" --mode behavior --runs 1 \
  --baseline-path "$PATH_BASELINE" --out-root "$TMP_ROOT/runs" --run-id target-file-containment
assert_file_contains "$STDERR_FILE" 'link-target-outside' 'target SKILL.md containment diagnostic'

# Once the private baseline snapshot is complete, preparation announces that it is frozen and
# waits for an explicit release. Mutating the caller-owned baseline while preparation is paused
# must invalidate the run instead of changing prepared variants or identity.
if [ "$NODE_PLATFORM" != win32 ]; then
MUTABLE_BASELINE="$TMP_ROOT/mutable-baseline/prepare-target"
write_skill "$MUTABLE_BASELINE" prepare-target 'Baseline mutation detection fixture.'
write_corpora "$MUTABLE_BASELINE" prepare-target 'mutable fixture'
MUTATION_OUT="$TMP_ROOT/baseline-mutation-runs"
MUTATION_BARRIER="$TMP_ROOT/baseline-mutation-barrier"
mkdir -p "$MUTATION_OUT" "$MUTATION_BARRIER"
mkfifo "$MUTATION_BARRIER/ready" "$MUTATION_BARRIER/release"
start_timed 20 "$TMP_ROOT/baseline-mutation.out" "$TMP_ROOT/baseline-mutation.err" env \
  TMPDIR="$SYSTEM_TMP" WOOSTACK_BASE_BRANCH=base RESOLVER_MARKER="$TMP_ROOT/resolver-marker" \
  WOOSTACK_EVAL_TEST_MODE=1 \
  WOOSTACK_EVAL_TEST_BASELINE_SNAPSHOT_READY="$MUTATION_BARRIER/ready" \
  WOOSTACK_EVAL_TEST_BASELINE_SNAPSHOT_RELEASE="$MUTATION_BARRIER/release" \
  "$NODE" "$PREPARER" --target "$TARGET" --mode all --runs 1 \
    --baseline-path "$MUTABLE_BASELINE" --catalog-root "$GIT_REPO/skills" \
    --out-root "$MUTATION_OUT" --run-id baseline-mutated
baseline_mutation_pid=$TIMED_PID
baseline_mutation_watchdog=$TIMED_WATCHDOG_PID
baseline_mutation_marker=$TIMED_OUT_MARKER
if ! run_timed 10 "$MUTATION_BARRIER/state" "$MUTATION_BARRIER/error" \
  bash -c 'IFS= read -r state <"$1" && printf "%s\n" "$state"' sh "$MUTATION_BARRIER/ready"; then
  fail 'baseline mutation test never reached the frozen-snapshot barrier'
fi
baseline_barrier_state=$(cat "$MUTATION_BARRIER/state")
[ "$baseline_barrier_state" = ready ] ||
  fail "baseline mutation barrier returned unexpected state: $baseline_barrier_state"
printf '\nmutation after snapshot\n' >>"$MUTABLE_BASELINE/references/guide.md"
if ! run_timed 10 "$MUTATION_BARRIER/release.out" "$MUTATION_BARRIER/release.error" \
  bash -c 'printf "release\n" >"$1"' sh "$MUTATION_BARRIER/release"; then
  fail 'baseline mutation test could not release the frozen-snapshot barrier'
fi
set +e
finish_timed "$baseline_mutation_pid" "$baseline_mutation_watchdog" "$baseline_mutation_marker"
baseline_mutation_status=$?
set -e
[ "$baseline_mutation_status" -eq 1 ] ||
  fail "baseline mutation should fail preparation, got $baseline_mutation_status"
[ ! -s "$TMP_ROOT/baseline-mutation.out" ] || fail 'baseline mutation emitted a success path'
assert_file_contains "$TMP_ROOT/baseline-mutation.err" 'baseline source changed' \
  'baseline mutation diagnostic'
[ ! -e "$MUTATION_OUT/baseline-mutated" ] || fail 'baseline mutation left reserved run residue'
fi

CONTAINED_BASELINE="$TMP_ROOT/contained-baseline/prepare-target"
write_skill "$CONTAINED_BASELINE" prepare-target 'Baseline with an escaping resource link.'
printf 'outside baseline root\n' >"$TMP_ROOT/contained-baseline/outside.md"
printf '\n[Escaped resource](../outside.md)\n' >>"$CONTAINED_BASELINE/SKILL.md"
expect_failure 'baseline path resources stay inside the explicit allowed root' \
  --target "$TARGET" --mode behavior --runs 1 --baseline-path "$CONTAINED_BASELINE" \
  --out-root "$TMP_ROOT/runs" --run-id baseline-outside-resource

expect_failure 'baseline flag mutual exclusion' \
  --target "$TARGET" --mode all --runs 1 --baseline-ref "$BASE_COMMIT" \
  --baseline-path "$PATH_BASELINE" --out-root "$TMP_ROOT/runs" --run-id invalid-both
[ ! -e "$TMP_ROOT/runs/invalid-both" ] || fail 'mutually exclusive flags left a run directory'

expect_failure 'baseline path must be a directory' \
  --target "$TARGET" --mode behavior --runs 1 --baseline-path "$PATH_BASELINE/SKILL.md" \
  --out-root "$TMP_ROOT/runs" --run-id baseline-skill-file
OTHER_BASELINE="$TMP_ROOT/path-baseline/other-target"
write_skill "$OTHER_BASELINE" other-target 'Different skill baseline description.'
expect_failure 'baseline path must identify the target skill' \
  --target "$TARGET" --mode behavior --runs 1 --baseline-path "$OTHER_BASELINE" \
  --out-root "$TMP_ROOT/runs" --run-id baseline-other-skill
expect_failure 'output root inside target package' \
  --target "$TARGET" --mode behavior --runs 1 --baseline-ref "$BASE_COMMIT" \
  --catalog-root "$GIT_REPO/skills" --out-root "$TARGET/evals/output" --run-id nested-output
[ ! -e "$TARGET/evals/output" ] || fail 'rejected target-contained output root was created'

# With no explicit baseline, the installed canonical resolver is the only merge-base authority.
rm -f "$TMP_ROOT/resolver-marker"
TEST_BASE_BRANCH=base expect_success 'canonical merge-base resolver' \
  --target "$TARGET" --mode triggers --runs 1 --catalog-root "$GIT_REPO/skills" \
  --out-root "$TMP_ROOT/runs" --run-id merge-base
assert_manifest "$RUN_ROOT/manifest.json" merge-base prepare-target triggers 1 \
  "{\"kind\":\"git-ref\",\"identity\":\"$BASE_COMMIT\"}" "$CANDIDATE_HASH"
[ "$(wc -l <"$TMP_ROOT/resolver-marker" | tr -d ' ')" -eq 1 ] || fail 'canonical resolver was not invoked exactly once'

# A non-skills Git package uses the repository boundary in both the live tree and target-only
# materializations. A symlinked invocation prefix does not change that Git-relative policy.
NESTED_REPO="$TMP_ROOT/nested-boundary-repo"
git init -q -b base "$NESTED_REPO"
git -C "$NESTED_REPO" config user.email evaluator@example.invalid
git -C "$NESTED_REPO" config user.name 'Evaluator Contract'
CANONICAL_NESTED_REPO=$(CDPATH= cd -- "$NESTED_REPO" && pwd -P)
NESTED_TARGET="$CANONICAL_NESTED_REPO/packages/nested-target"
write_skill "$NESTED_TARGET" nested-target 'Nested Git baseline description.'
write_corpora "$NESTED_TARGET" nested-target 'nested Git fixture'
printf '# Repository guide\n' >"$CANONICAL_NESTED_REPO/shared.md"
printf '\n[Repository guide](../../shared.md)\n' >>"$NESTED_TARGET/SKILL.md"
git -C "$CANONICAL_NESTED_REPO" add .
git -C "$CANONICAL_NESTED_REPO" commit -qm 'nested baseline'
NESTED_BASE=$(git -C "$CANONICAL_NESTED_REPO" rev-parse HEAD)
git -C "$CANONICAL_NESTED_REPO" switch -qc feature
write_skill "$NESTED_TARGET" nested-target 'Nested Git candidate description.'
printf '\n[Repository guide](../../shared.md)\n' >>"$NESTED_TARGET/SKILL.md"
expect_success 'nested Git explicit baseline shares repository boundary' \
  --target "$NESTED_TARGET" --mode behavior --runs 1 --baseline-ref "$NESTED_BASE" \
  --out-root "$TMP_ROOT/runs" --run-id nested-git-explicit
TEST_BASE_BRANCH=base expect_success 'nested Git merge-base shares repository boundary' \
  --target "$NESTED_TARGET" --mode behavior --runs 1 \
  --out-root "$TMP_ROOT/runs" --run-id nested-git-merge-base
NESTED_ALIAS="$TMP_ROOT/nested-boundary-alias"
ln -s "$CANONICAL_NESTED_REPO" "$NESTED_ALIAS"
expect_success 'nested Git target through symlinked prefix' \
  --target "$NESTED_ALIAS/packages/nested-target/SKILL.md" --mode behavior --runs 1 \
  --baseline-ref "$NESTED_BASE" --out-root "$TMP_ROOT/runs" --run-id nested-git-alias

# A nested `vendor/skills/<package>` collection keeps its own parent boundary. Missing sibling
# targets are allowed only in target-only Git snapshots; links beyond that collection still fail.
VENDOR_REPO="$TMP_ROOT/vendor-skills-repo"
git init -q -b base "$VENDOR_REPO"
git -C "$VENDOR_REPO" config user.email evaluator@example.invalid
git -C "$VENDOR_REPO" config user.name 'Evaluator Contract'
CANONICAL_VENDOR_REPO=$(CDPATH= cd -- "$VENDOR_REPO" && pwd -P)
VENDOR_TARGET="$CANONICAL_VENDOR_REPO/vendor/skills/vendor-target"
write_skill "$VENDOR_TARGET" vendor-target 'Nested collection baseline description.'
write_corpora "$VENDOR_TARGET" vendor-target 'nested collection fixture'
write_skill "$CANONICAL_VENDOR_REPO/vendor/skills/vendor-peer" vendor-peer 'Nested collection sibling.'
printf '\n[Sibling](../vendor-peer/references/guide.md)\n' >>"$VENDOR_TARGET/SKILL.md"
printf '# Outside collection\n' >"$CANONICAL_VENDOR_REPO/outside.md"
git -C "$CANONICAL_VENDOR_REPO" add .
git -C "$CANONICAL_VENDOR_REPO" commit -qm 'valid nested collection baseline'
VENDOR_VALID_BASE=$(git -C "$CANONICAL_VENDOR_REPO" rev-parse HEAD)
git -C "$CANONICAL_VENDOR_REPO" switch -qc invalid-base
write_skill "$VENDOR_TARGET" vendor-target 'Escaping nested collection baseline.'
printf '\n[Outside collection](../../../outside.md)\n' >>"$VENDOR_TARGET/SKILL.md"
git -C "$CANONICAL_VENDOR_REPO" add "$VENDOR_TARGET/SKILL.md"
git -C "$CANONICAL_VENDOR_REPO" commit -qm 'escaping nested collection baseline'
VENDOR_INVALID_BASE=$(git -C "$CANONICAL_VENDOR_REPO" rev-parse HEAD)
git -C "$CANONICAL_VENDOR_REPO" switch -qc feature
write_skill "$VENDOR_TARGET" vendor-target 'Nested collection candidate description.'
printf '\n[Sibling](../vendor-peer/references/guide.md)\n' >>"$VENDOR_TARGET/SKILL.md"
expect_success 'nested skills collection explicit baseline accepts sibling' \
  --target "$VENDOR_TARGET" --mode behavior --runs 1 --baseline-ref "$VENDOR_VALID_BASE" \
  --out-root "$TMP_ROOT/runs" --run-id vendor-skills-explicit
TEST_BASE_BRANCH=base expect_success 'nested skills collection merge-base accepts sibling' \
  --target "$VENDOR_TARGET" --mode behavior --runs 1 \
  --out-root "$TMP_ROOT/runs" --run-id vendor-skills-merge-base
expect_failure 'nested skills collection explicit baseline rejects collection escape' \
  --target "$VENDOR_TARGET" --mode behavior --runs 1 --baseline-ref "$VENDOR_INVALID_BASE" \
  --out-root "$TMP_ROOT/runs" --run-id vendor-skills-explicit-escape
assert_file_contains "$STDERR_FILE" 'link-target-outside' 'nested explicit collection escape diagnostic'
TEST_BASE_BRANCH=invalid-base expect_failure \
  'nested skills collection merge-base rejects collection escape' \
  --target "$VENDOR_TARGET" --mode behavior --runs 1 \
  --out-root "$TMP_ROOT/runs" --run-id vendor-skills-merge-escape

# Missing canonical resolution fails closed, while an explicit baseline remains usable.
mv "$RESOLVER" "$RESOLVER.disabled"
expect_failure 'missing canonical resolver without explicit baseline' \
  --target "$TARGET" --mode all --runs 1 --catalog-root "$GIT_REPO/skills" \
  --out-root "$TMP_ROOT/runs" --run-id missing-resolver
expect_success 'explicit baseline does not need resolver' \
  --target "$TARGET" --mode behavior --runs 1 --baseline-ref "$BASE_COMMIT" \
  --catalog-root "$GIT_REPO/skills" --out-root "$TMP_ROOT/runs" --run-id no-resolver-explicit
mv "$RESOLVER.disabled" "$RESOLVER"

# Repository-local Git config must not execute a caller-controlled fsmonitor hook.
FSMONITOR_MARKER="$TMP_ROOT/fsmonitor-invoked"
FSMONITOR_HOOK="$TMP_ROOT/fsmonitor-hook.sh"
cat >"$FSMONITOR_HOOK" <<EOF
#!/bin/sh
printf 'invoked\n' >>"$FSMONITOR_MARKER"
EOF
chmod +x "$FSMONITOR_HOOK"
git -C "$GIT_REPO" config core.fsmonitor "$FSMONITOR_HOOK"
expect_success 'target Git config cannot execute fsmonitor hooks' \
  --target "$TARGET" --mode behavior --runs 1 --baseline-ref "$BASE_COMMIT" \
  --catalog-root "$GIT_REPO/skills" --out-root "$TMP_ROOT/runs" --run-id safe-git-config
git -C "$GIT_REPO" config --unset core.fsmonitor
[ ! -e "$FSMONITOR_MARKER" ] || fail 'preparation executed repository-local fsmonitor code'

# Invalid explicit or implicit Git lookups never fall through to another baseline kind.
expect_failure 'invalid explicit Git ref fails closed' \
  --target "$TARGET" --mode behavior --runs 1 --baseline-ref refs/heads/not-present \
  --out-root "$TMP_ROOT/runs" --run-id invalid-ref
TEST_BASE_BRANCH=not-present expect_failure 'invalid merge-base lookup fails closed' \
  --target "$TARGET" --mode behavior --runs 1 --out-root "$TMP_ROOT/runs" --run-id invalid-merge-base

# A package proven absent at a valid merge base is the Git no-skill baseline.
NEW_REPO="$TMP_ROOT/new-skill-repo"
git init -q -b base "$NEW_REPO"
git -C "$NEW_REPO" config user.email evaluator@example.invalid
git -C "$NEW_REPO" config user.name 'Evaluator Contract'
write_skill "$NEW_REPO/skills/catalog-peer" catalog-peer 'New repository peer.'
write_public_authority "$NEW_REPO/skills/using-woostack"
git -C "$NEW_REPO" add .
git -C "$NEW_REPO" commit -qm 'base without target'
ABSENT_BASE=$(git -C "$NEW_REPO" rev-parse HEAD)
git -C "$NEW_REPO" switch -qc feature
NEW_TARGET="$NEW_REPO/skills/new-target"
write_skill "$NEW_TARGET" new-target 'New target candidate description.'
write_corpora "$NEW_TARGET" new-target 'new target fixture'
NEW_HASH=$(package_hash "$NEW_TARGET" "$TMP_ROOT/new-target-validation.json")
rm -f "$TMP_ROOT/resolver-marker"
TEST_BASE_BRANCH=base expect_success 'Git target absent at merge base' \
  --target "$NEW_TARGET" --mode all --runs 1 --catalog-root "$NEW_REPO/skills" \
  --out-root "$TMP_ROOT/runs" --run-id git-no-skill
assert_manifest "$RUN_ROOT/manifest.json" git-no-skill new-target all 1 \
  "{\"kind\":\"none\",\"identity\":\"$ABSENT_BASE:absent\"}" "$NEW_HASH"
NO_SKILL_COPIED_HASH=$(raw_package_hash \
  "$RUN_ROOT/cases/alpha-behavior/1/candidate/package" \
  "$TMP_ROOT/no-skill-copied-candidate-hash.txt")
assert_frozen_package_hashes "$RUN_ROOT/manifest.json" "$NO_SKILL_COPIED_HASH" null
[ ! -e "$RUN_ROOT/cases/alpha-behavior/1/baseline/package" ] || fail 'no-skill baseline must omit the package'
assert_catalog "$RUN_ROOT/cases/alpha-trigger/1/candidate/catalog.json" \
  '{"schemaVersion":1,"skills":[{"name":"catalog-peer","description":"New repository peer."},{"name":"new-target","description":"New target candidate description."},{"name":"using-woostack","description":"Installed public command-routing authority."}]}'
assert_catalog "$RUN_ROOT/cases/alpha-trigger/1/baseline/catalog.json" \
  '{"schemaVersion":1,"skills":[{"name":"catalog-peer","description":"New repository peer."},{"name":"using-woostack","description":"Installed public command-routing authority."}]}'

# A parent named `skills` is not a proven collection boundary outside Git.
STRICT_NON_GIT_TARGET="$TMP_ROOT/non-git-named-collection/skills/non-git-strict"
STRICT_NON_GIT_BASELINE="$TMP_ROOT/non-git-strict-baseline/non-git-strict"
write_skill "$STRICT_NON_GIT_TARGET" non-git-strict 'Non-Git skills-parent boundary target.'
write_corpora "$STRICT_NON_GIT_TARGET" non-git-strict 'non-Git strict fixture'
write_skill "$TMP_ROOT/non-git-named-collection/skills/sibling" sibling 'Unproven non-Git sibling.'
printf '\n[Unproven sibling](../sibling/references/guide.md)\n' >>"$STRICT_NON_GIT_TARGET/SKILL.md"
write_skill "$STRICT_NON_GIT_BASELINE" non-git-strict 'Non-Git skills-parent boundary baseline.'
expect_failure 'non-Git skills-named parent remains package-root strict' \
  --target "$STRICT_NON_GIT_TARGET" --mode behavior --runs 1 \
  --baseline-path "$STRICT_NON_GIT_BASELINE" --out-root "$TMP_ROOT/runs" \
  --run-id non-git-unproven-collection
assert_file_contains "$STDERR_FILE" 'link-target-outside' 'non-Git skills-parent containment diagnostic'

# An exact target outside Git defaults to a deterministic no-skill baseline. Explicit baselines
# still take precedence. The installed catalog remains the default authority, while a non-Git
# target requires an explicit output root.
NON_GIT_TARGET="$TMP_ROOT/outside-git/external-target"
write_skill "$NON_GIT_TARGET" external-target 'External target description.'
write_corpora "$NON_GIT_TARGET" external-target 'external fixture'
NON_GIT_HASH=$(package_hash "$NON_GIT_TARGET" "$TMP_ROOT/non-git-validation.json")
expect_failure 'non-Git target rejects an unproven output root' \
  --target "$NON_GIT_TARGET" --mode triggers --runs 1 --run-id non-git-no-output-root
assert_file_contains "$STDERR_FILE" 'pass --out-root explicitly' 'non-Git output-root diagnostic'
expect_success 'non-Git target defaults to no-skill baseline with explicit output root' \
  --target "$NON_GIT_TARGET" --mode triggers --runs 1 --out-root "$TMP_ROOT/runs" --run-id non-git-no-baseline
assert_manifest "$RUN_ROOT/manifest.json" non-git-no-baseline external-target triggers 1 \
  "{\"kind\":\"none\",\"identity\":\"non-git:$NON_GIT_HASH:absent\"}" "$NON_GIT_HASH"
[ ! -e "$RUN_ROOT/cases/alpha-trigger/1/baseline/package" ] ||
  fail 'non-Git no-skill baseline must omit the package'
assert_catalog "$RUN_ROOT/cases/alpha-trigger/1/baseline/catalog.json" \
  '{"schemaVersion":1,"skills":[{"name":"catalog-peer","description":"Installed catalog peer description."},{"name":"using-woostack","description":"Installed public command-routing authority."}]}'
NON_GIT_BASELINE="$TMP_ROOT/outside-git-baseline/external-target"
write_skill "$NON_GIT_BASELINE" external-target 'External baseline description.'
expect_success 'non-Git target with explicit baseline and output root' \
  --target "$NON_GIT_TARGET" --mode triggers --runs 1 \
  --baseline-path "$NON_GIT_BASELINE" --out-root "$TMP_ROOT/runs" --run-id non-git-target
NON_GIT_BASELINE_HASH=$(package_hash "$NON_GIT_BASELINE" "$TMP_ROOT/non-git-baseline-validation.json")
assert_manifest "$RUN_ROOT/manifest.json" non-git-target external-target triggers 1 \
  "{\"kind\":\"path\",\"identity\":\"$NON_GIT_BASELINE_HASH\"}" "$NON_GIT_HASH"
assert_catalog "$RUN_ROOT/cases/alpha-trigger/1/candidate/catalog.json" \
  '{"schemaVersion":1,"skills":[{"name":"catalog-peer","description":"Installed catalog peer description."},{"name":"external-target","description":"External target description."},{"name":"using-woostack","description":"Installed public command-routing authority."}]}'
assert_catalog "$RUN_ROOT/cases/alpha-trigger/1/baseline/catalog.json" \
  '{"schemaVersion":1,"skills":[{"name":"catalog-peer","description":"Installed catalog peer description."},{"name":"external-target","description":"External baseline description."},{"name":"using-woostack","description":"Installed public command-routing authority."}]}'

# Catalogs contain public commands only and reject corrupt public entries.

PUBLIC_CATALOG="$TMP_ROOT/public-catalog"
write_public_authority "$PUBLIC_CATALOG/using-woostack" unknown-support
write_skill "$PUBLIC_CATALOG/catalog-peer" catalog-peer 'Public catalog peer.'
write_skill "$PUBLIC_CATALOG/woostack-ask" woostack-ask 'Supporting read-only utility.'
write_skill "$PUBLIC_CATALOG/woostack-harden" woostack-harden 'Internal hardening utility.'
write_skill "$PUBLIC_CATALOG/woostack-ideate" woostack-ideate 'Internal design utility.'
write_skill "$PUBLIC_CATALOG/unknown-support" unknown-support 'Unknown directory must not become public.'
expect_success 'selected catalog root owns its public command authority' \
  --target "$NON_GIT_TARGET" --mode triggers --runs 1 --catalog-root "$PUBLIC_CATALOG" \
  --baseline-path "$NON_GIT_BASELINE" --out-root "$TMP_ROOT/runs" --run-id public-catalog
assert_catalog "$RUN_ROOT/cases/alpha-trigger/1/candidate/catalog.json" \
  '{"schemaVersion":1,"skills":[{"name":"catalog-peer","description":"Public catalog peer."},{"name":"external-target","description":"External target description."},{"name":"unknown-support","description":"Unknown directory must not become public."},{"name":"using-woostack","description":"Installed public command-routing authority."}]}'
assert_catalog "$RUN_ROOT/cases/alpha-trigger/1/baseline/catalog.json" \
  '{"schemaVersion":1,"skills":[{"name":"catalog-peer","description":"Public catalog peer."},{"name":"external-target","description":"External baseline description."},{"name":"unknown-support","description":"Unknown directory must not become public."},{"name":"using-woostack","description":"Installed public command-routing authority."}]}'

MISSING_CATALOG="$TMP_ROOT/missing-catalog"
write_public_authority "$MISSING_CATALOG/using-woostack" broken-entry
write_skill "$MISSING_CATALOG/catalog-peer" catalog-peer 'Valid peer beside missing route.'
expect_failure 'missing routed catalog entry fails closed' \
  --target "$NON_GIT_TARGET" --mode triggers --runs 1 --catalog-root "$MISSING_CATALOG" \
  --baseline-path "$NON_GIT_BASELINE" --out-root "$TMP_ROOT/runs" --run-id missing-catalog
assert_file_contains "$STDERR_FILE" 'catalog entry missing: broken-entry' \
  'missing routed catalog entry diagnostic'

INVALID_CATALOG="$TMP_ROOT/invalid-catalog"
write_public_authority "$INVALID_CATALOG/using-woostack" broken-entry
write_skill "$INVALID_CATALOG/catalog-peer" catalog-peer 'Valid peer beside corruption.'
mkdir -p "$INVALID_CATALOG/broken-entry"
printf 'not frontmatter\n' >"$INVALID_CATALOG/broken-entry/SKILL.md"
expect_failure 'invalid public catalog entry fails closed' \
  --target "$NON_GIT_TARGET" --mode triggers --runs 1 --catalog-root "$INVALID_CATALOG" \
  --baseline-path "$NON_GIT_BASELINE" --out-root "$TMP_ROOT/runs" --run-id invalid-catalog

# An ignored repository-local evaluator root is preferred; unignored roots fail closed.
TEST_BASE_BRANCH=base expect_success 'ignored repository-local run root' \
  --target "$TARGET" --mode behavior --runs 1 --baseline-ref "$BASE_COMMIT" --run-id ignored-root
case "$RUN_ROOT" in
  "$CANONICAL_GIT_REPO/.woostack/tmp/skill-evals/ignored-root") ;;
  *) fail "ignored repository root was not selected: $RUN_ROOT" ;;
esac
assert_private_run_root "$RUN_ROOT"
printf '' >"$GIT_REPO/.gitignore"
expect_failure 'unignored repository root fails closed' \
  --target "$TARGET" --mode behavior --runs 1 --baseline-ref "$BASE_COMMIT" --run-id unignored-root
assert_file_contains "$STDERR_FILE" 'pass --out-root explicitly' 'unignored output-root diagnostic'

# Auto-generated IDs are safe and concurrent allocation is atomic and unique.
CONCURRENT_OUT="$TMP_ROOT/concurrent-runs"
mkdir -p "$CONCURRENT_OUT"
CONCURRENT_OUT=$(CDPATH= cd -- "$CONCURRENT_OUT" && pwd -P)
concurrent_pids=()
concurrent_watchdogs=()
concurrent_markers=()
for index in 1 2 3 4 5 6; do
  start_timed 10 "$TMP_ROOT/concurrent.$index.out" "$TMP_ROOT/concurrent.$index.err" env \
    TMPDIR="$SYSTEM_TMP" WOOSTACK_BASE_BRANCH=base \
    RESOLVER_MARKER="$TMP_ROOT/resolver-marker" \
    "$NODE" "$PREPARER" --target "$TARGET" --mode behavior --runs 1 \
      --baseline-ref "$BASE_COMMIT" --catalog-root "$GIT_REPO/skills" \
      --out-root "$CONCURRENT_OUT"
  concurrent_pids+=("$TIMED_PID")
  concurrent_watchdogs+=("$TIMED_WATCHDOG_PID")
  concurrent_markers+=("$TIMED_OUT_MARKER")
done
for offset in 0 1 2 3 4 5; do
  if ! finish_timed "${concurrent_pids[$offset]}" "${concurrent_watchdogs[$offset]}" \
    "${concurrent_markers[$offset]}"; then
    cat "$TMP_ROOT/concurrent.$((offset + 1)).err" >&2
    fail "concurrent preparation process ${concurrent_pids[$offset]} failed or timed out"
  fi
done
"$NODE" - "$CONCURRENT_OUT" "$TMP_ROOT" <<'NODE'
const fs = require('node:fs');
const path = require('node:path');
const [outRoot, tempRoot] = process.argv.slice(2);
const reported = [];
for (let index = 1; index <= 6; index += 1) {
  const value = fs.readFileSync(path.join(tempRoot, `concurrent.${index}.out`), 'utf8').trim();
  if (!path.isAbsolute(value) || path.dirname(value) !== outRoot) throw new Error(`invalid reported root: ${value}`);
  reported.push(value);
}
if (new Set(reported).size !== reported.length) throw new Error(`run IDs collided: ${reported.join(',')}`);
for (const root of reported) {
  const id = path.basename(root);
  if (!/^\d{8}T\d{6}Z-[1-9]\d*$/.test(id)) throw new Error(`unsafe automatic run ID: ${id}`);
  if (process.platform !== 'win32' && (fs.statSync(root).mode & 0o777) !== 0o700) {
    throw new Error(`non-private concurrent run: ${root}`);
  }
  const manifest = JSON.parse(fs.readFileSync(path.join(root, 'manifest.json'), 'utf8'));
  if (manifest.runId !== id) throw new Error(`manifest run ID mismatch: ${root}`);
}
NODE

# Safe CLI and path handling fail before a complete run becomes visible.
expect_failure 'missing target flag' --mode all --runs 1 --out-root "$TMP_ROOT/runs" --run-id missing-target
expect_failure 'missing mode flag' --target "$TARGET" --runs 1 --out-root "$TMP_ROOT/runs" --run-id missing-mode
expect_failure 'missing runs flag' --target "$TARGET" --mode all --out-root "$TMP_ROOT/runs" --run-id missing-runs
expect_failure 'unknown flag' --target "$TARGET" --mode all --runs 1 --unknown value
expect_failure 'repeated singleton flag' --target "$TARGET" --target "$TARGET" --mode all --runs 1
expect_failure 'unsupported mode' --target "$TARGET" --mode smoke --runs 1
expect_failure 'zero runs' --target "$TARGET" --mode all --runs 0
expect_failure 'too many runs' --target "$TARGET" --mode all --runs 11
expect_failure 'fractional runs' --target "$TARGET" --mode all --runs 1.5

# Interrupt cleanup kills the entire spawned command group, not only its direct shell.
if [ "$NODE_PLATFORM" != win32 ]; then
PROCESS_GROUP_BIN="$TMP_ROOT/process-group-bin"
PROCESS_GROUP_READY="$TMP_ROOT/process-group-descendant.ready"
PROCESS_GROUP_SURVIVED="$TMP_ROOT/process-group-descendant.survived"
mkdir -p "$PROCESS_GROUP_BIN"
cat >"$PROCESS_GROUP_BIN/git" <<'EOF'
#!/bin/sh
(
  sleep 1
  printf 'survived\n' >"$WOOSTACK_EVAL_TEST_DESCENDANT_SURVIVED"
) &
printf 'ready\n' >"$WOOSTACK_EVAL_TEST_DESCENDANT_READY"
wait
EOF
chmod +x "$PROCESS_GROUP_BIN/git"
start_timed 20 "$TMP_ROOT/process-group.out" "$TMP_ROOT/process-group.err" env \
  PATH="$PROCESS_GROUP_BIN:$PATH" \
  WOOSTACK_EVAL_TEST_DESCENDANT_READY="$PROCESS_GROUP_READY" \
  WOOSTACK_EVAL_TEST_DESCENDANT_SURVIVED="$PROCESS_GROUP_SURVIVED" \
  "$NODE" "$PREPARER" --target "$TARGET" --mode behavior --runs 1 \
    --baseline-ref "$BASE_COMMIT" --out-root "$TMP_ROOT/runs" --run-id process-group
process_group_pid=$TIMED_PID
process_group_watchdog=$TIMED_WATCHDOG_PID
process_group_timeout_marker=$TIMED_OUT_MARKER
if ! run_timed 5 "$TMP_ROOT/process-group-ready.out" "$TMP_ROOT/process-group-ready.err" \
  bash -c 'while [ ! -s "$1" ]; do sleep 0.05; done' sh "$PROCESS_GROUP_READY"; then
  fail 'spawned descendant did not start'
fi
kill -TERM "$process_group_pid"
set +e
finish_timed "$process_group_pid" "$process_group_watchdog" "$process_group_timeout_marker"
process_group_status=$?
set -e
sleep 1.2
[ ! -e "$PROCESS_GROUP_SURVIVED" ] ||
  fail 'spawned descendant survived preparation interrupt cleanup'
[ "$process_group_status" -eq 143 ] ||
  fail "interrupted preparation returned $process_group_status instead of 143"
assert_file_contains "$TMP_ROOT/process-group.err" 'received SIGTERM' \
  'signal cleanup diagnostic'
signal_diagnostic_count=$(grep -Fc -- 'received SIGTERM' "$TMP_ROOT/process-group.err")
[ "$signal_diagnostic_count" -eq 1 ] ||
  fail "signal cleanup emitted $signal_diagnostic_count SIGTERM diagnostics instead of one"

# The command's own watchdog must kill a hanging Git descendant and return before the outer guard.
INTERNAL_TIMEOUT_BIN="$TMP_ROOT/internal-timeout-bin"
INTERNAL_TIMEOUT_READY="$TMP_ROOT/internal-timeout-descendant.ready"
INTERNAL_TIMEOUT_SURVIVED="$TMP_ROOT/internal-timeout-descendant.survived"
mkdir -p "$INTERNAL_TIMEOUT_BIN"
cat >"$INTERNAL_TIMEOUT_BIN/git" <<'EOF'
#!/bin/sh
(
  sleep 11.5
  printf 'survived\n' >"$WOOSTACK_EVAL_TEST_DESCENDANT_SURVIVED"
) &
printf 'ready\n' >"$WOOSTACK_EVAL_TEST_DESCENDANT_READY"
wait
EOF
chmod +x "$INTERNAL_TIMEOUT_BIN/git"
set +e
run_timed 15 "$TMP_ROOT/internal-timeout.out" "$TMP_ROOT/internal-timeout.err" env \
  PATH="$INTERNAL_TIMEOUT_BIN:$PATH" \
  WOOSTACK_EVAL_TEST_DESCENDANT_READY="$INTERNAL_TIMEOUT_READY" \
  WOOSTACK_EVAL_TEST_DESCENDANT_SURVIVED="$INTERNAL_TIMEOUT_SURVIVED" \
  "$NODE" "$PREPARER" --target "$TARGET" --mode behavior --runs 1 \
    --baseline-ref "$BASE_COMMIT" --out-root "$TMP_ROOT/runs" --run-id internal-timeout
internal_timeout_status=$?
set -e
[ "$internal_timeout_status" -eq 1 ] ||
  fail "internal command timeout returned $internal_timeout_status instead of 1"
sleep 1.7
[ ! -e "$INTERNAL_TIMEOUT_SURVIVED" ] ||
  fail 'internal command timeout left a Git descendant running'
[ ! -e "$TMP_ROOT/runs/internal-timeout" ] ||
  fail 'internal command timeout left run-root residue'
assert_file_contains "$TMP_ROOT/internal-timeout.err" 'command timeout: git' \
  'internal command timeout diagnostic'
fi


EMPTY_TARGET="$TMP_ROOT/empty-selection/empty-target"
EMPTY_BASELINE="$TMP_ROOT/empty-selection-baseline/empty-target"
write_skill "$EMPTY_TARGET" empty-target 'Package without evaluation cases.'
write_skill "$EMPTY_BASELINE" empty-target 'Empty-selection baseline.'
expect_failure 'selected mode requires at least one case' --target "$EMPTY_TARGET" \
  --mode behavior --runs 1 --baseline-path "$EMPTY_BASELINE" \
  --out-root "$TMP_ROOT/runs" --run-id empty-selection
assert_file_contains "$STDERR_FILE" 'no behavior evaluation cases selected' \
  'empty selection diagnostic'
FIXTURELESS_TARGET="$TMP_ROOT/fixtureless/fixtureless-target"
FIXTURELESS_BASELINE="$TMP_ROOT/fixtureless-baseline/fixtureless-target"
write_skill "$FIXTURELESS_TARGET" fixtureless-target 'Behavior package without declared fixtures.'
write_skill "$FIXTURELESS_BASELINE" fixtureless-target 'Fixtureless baseline package.'
mkdir -p "$FIXTURELESS_TARGET/evals"
cat >"$FIXTURELESS_TARGET/evals/evals.json" <<'EOF'
{"schemaVersion":1,"skill":"fixtureless-target","cases":[{
  "id":"fixtureless-case",
  "prompt":"Complete without fixtures.",
  "expected":"The capability root still contains an empty fixtures directory.",
  "assertions":[{"id":"done","kind":"final-contains","substring":"done"}]
}]}
EOF
expect_success 'fixtureless behavior creates empty fixture roots' \
  --target "$FIXTURELESS_TARGET" --mode behavior --runs 1 \
  --baseline-path "$FIXTURELESS_BASELINE" --out-root "$TMP_ROOT/runs" --run-id fixtureless
[ -d "$RUN_ROOT/cases/fixtureless-case/1/candidate/fixtures" ] ||
  fail 'fixtureless candidate workspace omitted fixtures directory'
[ -d "$RUN_ROOT/cases/fixtureless-case/1/baseline/fixtures" ] ||
  fail 'fixtureless baseline workspace omitted fixtures directory'

CASE_LIMIT_TARGET="$TMP_ROOT/case-limit/case-limit-target"
CASE_LIMIT_BASELINE="$TMP_ROOT/case-limit-baseline/case-limit-target"
write_skill "$CASE_LIMIT_TARGET" case-limit-target 'Package exceeding the preparation case limit.'
write_skill "$CASE_LIMIT_BASELINE" case-limit-target 'Case-limit baseline package.'
mkdir -p "$CASE_LIMIT_TARGET/evals"
"$NODE" - "$CASE_LIMIT_TARGET/evals/evals.json" <<'NODE'
const fs = require('node:fs');
const cases = Array.from({ length: 101 }, (_, index) => {
  const ordinal = String(index + 1).padStart(3, '0');
  return {
    id: `case-${ordinal}`,
    prompt: `Run case ${ordinal}.`,
    expected: `Complete case ${ordinal}.`,
    assertions: [{ id: 'done', kind: 'final-contains', substring: 'done' }],
  };
});
fs.writeFileSync(process.argv[2], `${JSON.stringify({
  schemaVersion: 1,
  skill: 'case-limit-target',
  cases,
})}\n`);
NODE
expect_failure 'selected case count is bounded' \
  --target "$CASE_LIMIT_TARGET" --mode behavior --runs 1 \
  --baseline-path "$CASE_LIMIT_BASELINE" --out-root "$TMP_ROOT/runs" --run-id case-limit
assert_file_contains "$STDERR_FILE" 'selected case count exceeds 100' \
  'selected case count diagnostic'
[ ! -e "$TMP_ROOT/runs/case-limit" ] || fail 'case-limit rejection allocated a run root'

BUDGET_TARGET="$TMP_ROOT/workspace-budget/budget-target"
BUDGET_BASELINE="$TMP_ROOT/workspace-budget-baseline/budget-target"
write_skill "$BUDGET_TARGET" budget-target 'Package exceeding the projected workspace budget.'
write_skill "$BUDGET_BASELINE" budget-target 'Workspace-budget baseline package.'
mkdir -p "$BUDGET_TARGET/evals"
cat >"$BUDGET_TARGET/evals/evals.json" <<'EOF'
{"schemaVersion":1,"skill":"budget-target","cases":[{
  "id":"budget-case",
  "prompt":"Exercise the workspace budget.",
  "expected":"Preparation rejects the projected copies.",
  "assertions":[{"id":"done","kind":"final-contains","substring":"done"}]
}]}
EOF
"$NODE" - "$BUDGET_TARGET/payload.bin" <<'NODE'
const fs = require('node:fs');
fs.writeFileSync(process.argv[2], Buffer.alloc(7 * 1024 * 1024));
NODE
expect_failure 'projected workspace bytes are bounded' \
  --target "$BUDGET_TARGET" --mode behavior --runs 10 \
  --baseline-path "$BUDGET_BASELINE" --out-root "$TMP_ROOT/runs" --run-id workspace-budget
assert_file_contains "$STDERR_FILE" 'projected workspace exceeds 67108864 bytes' \
  'projected workspace budget diagnostic'
[ ! -e "$TMP_ROOT/runs/workspace-budget" ] ||
  fail 'workspace-budget rejection allocated a run root'


expect_failure 'relative baseline path' --target "$TARGET" --mode all --runs 1 --baseline-path relative/path
expect_failure 'relative catalog root' --target "$TARGET" --mode triggers --runs 1 --catalog-root relative/path
expect_failure 'relative output root' --target "$TARGET" --mode all --runs 1 --out-root relative/path
expect_failure 'run ID traversal' --target "$TARGET" --mode all --runs 1 --baseline-ref "$BASE_COMMIT" \
  --out-root "$TMP_ROOT/runs" --run-id ../escaped
expect_failure 'run ID absolute path' --target "$TARGET" --mode all --runs 1 --baseline-ref "$BASE_COMMIT" \
  --out-root "$TMP_ROOT/runs" --run-id /absolute
expect_failure 'run ID dot segment' --target "$TARGET" --mode all --runs 1 --baseline-ref "$BASE_COMMIT" \
  --out-root "$TMP_ROOT/runs" --run-id ..
[ ! -e "$TMP_ROOT/escaped" ] || fail 'traversal created a directory outside the output root'

expect_failure 'newline in CLI value' --target "$TARGET" --mode $'all\ninjected' --runs 1
assert_bounded_diagnostic "$STDERR_FILE"
expect_failure 'tab in CLI value' --target "$TARGET" --mode $'all\tinjected' --runs 1
assert_bounded_diagnostic "$STDERR_FILE"
OVERSIZED_ARGUMENT=$(printf 'a%.0s' {1..5000})
expect_failure 'oversized CLI value' --target "$TARGET" --mode behavior --runs 1 \
  --baseline-ref "$OVERSIZED_ARGUMENT"
assert_bounded_diagnostic "$STDERR_FILE"

# Selected case IDs are bounded before allocation, and behavior/trigger identities share one
# namespace because both feed deterministic workspace and evidence names.
CASE_ID_TARGET="$TMP_ROOT/case-ids/case-id-target"
CASE_ID_BASELINE="$TMP_ROOT/case-id-baseline/case-id-target"
write_skill "$CASE_ID_TARGET" case-id-target 'Case identifier boundary fixture.'
write_skill "$CASE_ID_BASELINE" case-id-target 'Case identifier baseline.'
mkdir -p "$CASE_ID_TARGET/evals"
write_case_id_behavior() {
  case_id=$1
  cat >"$CASE_ID_TARGET/evals/evals.json" <<EOF
{"schemaVersion":1,"skill":"case-id-target","cases":[{
  "id":"$case_id",
  "prompt":"Prepare an isolated workspace.",
  "expected":"No unexpected path exists.",
  "assertions":[{"id":"path-stays-absent","kind":"path-absent","path":"unexpected"}]
}]}
EOF
}
MAX_CASE_ID=$(printf 'a%.0s' {1..64})
write_case_id_behavior "$MAX_CASE_ID"
validate_setup_package "$CASE_ID_TARGET" "$TMP_ROOT/case-id-64-validation.json"
expect_success 'maximum conservative case ID length' --target "$CASE_ID_TARGET" \
  --mode behavior --runs 1 --baseline-path "$CASE_ID_BASELINE" \
  --out-root "$TMP_ROOT/runs" --run-id case-id-64
TOO_LONG_CASE_ID="${MAX_CASE_ID}a"
write_case_id_behavior "$TOO_LONG_CASE_ID"
validate_setup_package "$CASE_ID_TARGET" "$TMP_ROOT/case-id-65-validation.json"
expect_failure 'case ID beyond evidence-safe boundary' --target "$CASE_ID_TARGET" \
  --mode behavior --runs 1 --baseline-path "$CASE_ID_BASELINE" \
  --out-root "$TMP_ROOT/runs" --run-id case-id-65
write_case_id_behavior shared-case
cat >"$CASE_ID_TARGET/evals/trigger-evals.json" <<'EOF'
{"schemaVersion":1,"skill":"case-id-target","cases":[{
  "id":"shared-case",
  "query":"Select the target skill.",
  "shouldTrigger":true,
  "expectedSkill":"case-id-target"
}]}
EOF
validate_setup_package "$CASE_ID_TARGET" "$TMP_ROOT/cross-corpus-validation.json"
expect_failure 'cross-corpus duplicate selected case ID' --target "$CASE_ID_TARGET" \
  --mode all --runs 1 --baseline-path "$CASE_ID_BASELINE" \
  --out-root "$TMP_ROOT/runs" --run-id duplicate-cross-corpus

if [ "$NODE_PLATFORM" != win32 ]; then
ln -s "$PATH_BASELINE" "$TMP_ROOT/symlink-baseline"
expect_failure 'symlink baseline root' --target "$TARGET" --mode all --runs 1 \
  --baseline-path "$TMP_ROOT/symlink-baseline" --out-root "$TMP_ROOT/runs" --run-id symlink-baseline
ln -s "$TARGET" "$TMP_ROOT/symlink-target"
expect_failure 'symlink target root' --target "$TMP_ROOT/symlink-target" --mode all --runs 1 \
  --baseline-path "$PATH_BASELINE" --out-root "$TMP_ROOT/runs" --run-id symlink-target
mkdir -p "$TMP_ROOT/real-output"
ln -s "$TMP_ROOT/real-output" "$TMP_ROOT/symlink-output"
expect_failure 'symlink output root' --target "$TARGET" --mode all --runs 1 --baseline-ref "$BASE_COMMIT" \
  --out-root "$TMP_ROOT/symlink-output" --run-id symlink-output

UNSAFE_FIXTURE_TARGET="$TMP_ROOT/unsafe-fixture/unsafe-target"
write_skill "$UNSAFE_FIXTURE_TARGET" unsafe-target 'Unsafe fixture package.'
write_corpora "$UNSAFE_FIXTURE_TARGET" unsafe-target 'safe before replacement'
rm "$UNSAFE_FIXTURE_TARGET/evals/fixtures/alpha.txt"
printf 'outside fixture\n' >"$TMP_ROOT/outside-fixture.txt"
ln -s "$TMP_ROOT/outside-fixture.txt" "$UNSAFE_FIXTURE_TARGET/evals/fixtures/alpha.txt"
expect_failure 'symlink fixture' --target "$UNSAFE_FIXTURE_TARGET" --mode behavior --runs 1 \
  --baseline-path "$PATH_BASELINE" --out-root "$TMP_ROOT/runs" --run-id symlink-fixture
fi

# Git metadata failures are not silently treated as a non-Git target.
BROKEN_GIT_ROOT="$TMP_ROOT/broken-git"
BROKEN_GIT_TARGET="$BROKEN_GIT_ROOT/skills/broken-target"
mkdir -p "$BROKEN_GIT_ROOT/.git"
write_skill "$BROKEN_GIT_TARGET" broken-target 'Target beneath malformed Git metadata.'
write_corpora "$BROKEN_GIT_TARGET" broken-target 'broken git fixture'
expect_failure 'malformed Git metadata fails closed' \
  --target "$BROKEN_GIT_TARGET" --mode behavior --runs 1 \
  --out-root "$TMP_ROOT/runs" --run-id malformed-git

# Resolver-time source mutation changes package, HEAD, and index after the preflight snapshot.
MUTATION_REPO="$TMP_ROOT/mutation-repo"
git init -q -b base "$MUTATION_REPO"
git -C "$MUTATION_REPO" config user.email evaluator@example.invalid
git -C "$MUTATION_REPO" config user.name 'Evaluator Contract'
MUTATION_TARGET="$MUTATION_REPO/skills/mutation-target"
write_skill "$MUTATION_TARGET" mutation-target 'Source snapshot mutation target.'
write_corpora "$MUTATION_TARGET" mutation-target 'mutation fixture'
git -C "$MUTATION_REPO" add .
git -C "$MUTATION_REPO" commit -qm 'mutation baseline'
git -C "$MUTATION_REPO" switch -qc feature
rm -f "$TMP_ROOT/resolver-marker"
RESOLVER_MUTATE_FILE="$MUTATION_TARGET/references/guide.md" TEST_BASE_BRANCH=base \
  expect_failure 'source mutation after snapshot fails closed' \
  --target "$MUTATION_TARGET" --mode behavior --runs 1 \
  --out-root "$TMP_ROOT/runs" --run-id source-mutated
assert_file_contains "$MUTATION_TARGET/references/guide.md" \
  'mutation during preparation' 'snapshot mutation hook'

# A target present but invalid in a Git object is corruption, not a no-skill baseline.
CORRUPT_REPO="$TMP_ROOT/corrupt-baseline-repo"
git init -q -b base "$CORRUPT_REPO"
git -C "$CORRUPT_REPO" config user.email evaluator@example.invalid
git -C "$CORRUPT_REPO" config user.name 'Evaluator Contract'
mkdir -p "$CORRUPT_REPO/skills/corrupt-target"
printf 'not a package\n' >"$CORRUPT_REPO/not-a-skill"
ln -s ../../not-a-skill "$CORRUPT_REPO/skills/corrupt-target/SKILL.md"
git -C "$CORRUPT_REPO" add .
git -C "$CORRUPT_REPO" commit -qm 'symlinked baseline target'
git -C "$CORRUPT_REPO" switch -qc feature
rm "$CORRUPT_REPO/skills/corrupt-target/SKILL.md"
write_skill "$CORRUPT_REPO/skills/corrupt-target" corrupt-target 'Valid candidate replacing corrupt baseline.'
write_corpora "$CORRUPT_REPO/skills/corrupt-target" corrupt-target 'corrupt baseline fixture'
TEST_BASE_BRANCH=base expect_failure 'present invalid Git baseline fails closed' \
  --target "$CORRUPT_REPO/skills/corrupt-target" --mode all --runs 1 \
  --out-root "$TMP_ROOT/runs" --run-id corrupt-baseline

printf 'PASS: prepare contract\n'
