#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
VALIDATOR="$SCRIPT_DIR/../validate.mjs"
PREPARER="$SCRIPT_DIR/../prepare.mjs"
AGGREGATOR="$SCRIPT_DIR/../aggregate.mjs"
RENDERER="$SCRIPT_DIR/../render-report.mjs"
NODE=${NODE:-node}
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/woostack-eval-e2e.XXXXXX")
TMP_ROOT=$(CDPATH= cd -- "$TMP_ROOT" && pwd -P)

cleanup() {
  status=$?
  trap - EXIT HUP INT TERM
  rm -rf "$TMP_ROOT"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

if [ -n "${WOOSTACK_E2E_SIGNAL_PROBE:-}" ]; then
  printf '%s\n' "$TMP_ROOT" >"$WOOSTACK_E2E_SIGNAL_PATH_FILE"
  kill -s "$WOOSTACK_E2E_SIGNAL_PROBE" "$$"
  exit 99
fi

NETWORK_GUARD="$TMP_ROOT/deny-network.cjs"
cat >"$NETWORK_GUARD" <<'NODE'
'use strict';
const deny = () => {
  throw new Error('woostack-eval e2e network disabled');
};
globalThis.fetch = deny;
globalThis.WebSocket = class DisabledWebSocket {
  constructor() { deny(); }
};
globalThis.EventSource = class DisabledEventSource {
  constructor() { deny(); }
};
function patch(name, methods) {
  const api = require(name);
  for (const method of methods) {
    if (method in api) api[method] = deny;
  }
  return api;
}
patch('node:http', ['request', 'get', 'createServer']);
patch('node:https', ['request', 'get', 'createServer']);
patch('node:http2', ['connect', 'createServer', 'createSecureServer']);
const net = patch('node:net', ['connect', 'createConnection', 'createServer']);
net.Socket.prototype.connect = deny;
const tls = patch('node:tls', ['connect', 'createServer']);
tls.TLSSocket.prototype.connect = deny;
patch('node:dgram', ['createSocket']);
const dns = patch('node:dns', [
  'lookup', 'lookupService', 'resolve', 'resolve4', 'resolve6', 'resolveAny',
  'resolveCaa', 'resolveCname', 'resolveMx', 'resolveNaptr', 'resolveNs',
  'resolvePtr', 'resolveSoa', 'resolveSrv', 'resolveTxt', 'reverse',
]);
for (const method of Object.keys(dns.promises)) {
  if (typeof dns.promises[method] === 'function') dns.promises[method] = deny;
}
NODE
export NODE_OPTIONS="--require=$NETWORK_GUARD${NODE_OPTIONS:+ $NODE_OPTIONS}"

run_signal_probe() {
  signal=$1
  expected=$2
  path_file="$TMP_ROOT/signal-$signal.path"
  stderr_file="$TMP_ROOT/signal-$signal.stderr"
  if WOOSTACK_E2E_SIGNAL_PROBE="$signal" \
    WOOSTACK_E2E_SIGNAL_PATH_FILE="$path_file" \
    bash "$0" >"$TMP_ROOT/signal-$signal.stdout" 2>"$stderr_file"; then
    fail "$signal probe unexpectedly exited zero"
  else
    actual=$?
  fi
  [ "$actual" -eq "$expected" ] || fail "$signal probe exited $actual, expected $expected"
  [ -s "$path_file" ] || fail "$signal probe did not report its temporary root"
  probe_root=$(cat "$path_file")
  [ ! -e "$probe_root" ] || fail "$signal probe did not clean $probe_root"
}
run_signal_probe HUP 129
run_signal_probe INT 130
run_signal_probe TERM 143

assert_network_blocked() {
  label=$1
  code=$2
  if "$NODE" -e "$code" >"$TMP_ROOT/network-$label.stdout" 2>"$TMP_ROOT/network-$label.stderr"; then
    fail "$label network probe unexpectedly succeeded"
  fi
  grep -F 'woostack-eval e2e network disabled' "$TMP_ROOT/network-$label.stderr" >/dev/null ||
    fail "$label network probe did not fail through the preload"
}
assert_network_blocked fetch "fetch('https://example.invalid')"
assert_network_blocked net "require('node:net').connect({ host: '127.0.0.1', port: 9 })"

for helper in "$VALIDATOR" "$PREPARER" "$AGGREGATOR" "$RENDERER"; do
  [ -f "$helper" ] || fail "missing runtime helper: $helper"
done


TARGET="$TMP_ROOT/candidate/e2e-target"
BASELINE="$TMP_ROOT/baseline/e2e-target"
mkdir -p "$TARGET/references" "$TARGET/evals/fixtures" "$TARGET/evals/tests" \
  "$TARGET/scripts/tests" "$TARGET/tests" \
  "$BASELINE/references" "$BASELINE/evals/fixtures" "$BASELINE/evals/tests" \
  "$BASELINE/scripts/tests" "$BASELINE/tests"

cat >"$TARGET/SKILL.md" <<'EOF'
---
name: e2e-target
description: Deterministic temporary skill used only by the evaluator end-to-end contract.
---
# E2E target

Read the [guide](references/guide.md) and return a terminal handback.
EOF
cat >"$BASELINE/SKILL.md" <<'EOF'
---
name: e2e-target
description: Deterministic baseline skill used only by the evaluator end-to-end contract.
---
# E2E target baseline

Read the [guide](references/guide.md) and return a terminal handback.
EOF
printf '# Candidate guide\n\nReturn a simulated handback.\n' >"$TARGET/references/guide.md"
printf '# Baseline guide\n\nReturn a simulated handback.\n' >"$BASELINE/references/guide.md"
printf 'transient fixture payload\n' >"$TARGET/evals/fixtures/request.txt"
printf 'transient fixture payload\n' >"$BASELINE/evals/fixtures/request.txt"
for package in "$TARGET" "$BASELINE"; do
  printf 'export const runtimeReady = true;\n' >"$package/scripts/runtime.mjs"
  printf 'throw new Error("worker-visible test leak");\n' >"$package/scripts/tests/test-runtime.mjs"
  printf 'throw new Error("worker-visible test leak");\n' >"$package/tests/runtime.test.mjs"
  printf 'throw new Error("worker-visible grader leak");\n' >"$package/evals/grader.mjs"
  printf 'throw new Error("worker-visible grader test leak");\n' >"$package/evals/tests/test-grader.mjs"
  printf '{"expected":{"status":"complete","reason":"undeclared-oracle"}}\n' \
    >"$package/evals/fixtures/undeclared-answer.json"
done

write_corpus() {
  package=$1
  cat >"$package/evals/evals.json" <<'EOF'
{
  "schemaVersion": 1,
  "skill": "e2e-target",
  "cases": [{
    "id": "terminal-handback",
    "prompt": "Read request.txt and return the deterministic terminal handback.",
    "fixtures": ["request.txt"],
    "capabilities": ["read-workspace"],
    "expected": "The response reports the simulated handback without modifying the workspace.",
    "assertions": [{
      "id": "fixture-is-frozen",
      "kind": "file-contains",
      "file": "fixtures/request.txt",
      "substring": "transient fixture payload",
      "critical": true
    }, {
      "id": "reports-handback",
      "kind": "final-contains",
      "substring": "simulated handback",
      "critical": true
    }, {
      "id": "clear-terminal-status",
      "kind": "qualitative",
      "rubric": "Does the response clearly state a terminal handback?",
      "critical": false
    }]
  }]
}
EOF
}
write_corpus "$TARGET"
write_corpus "$BASELINE"

validate_package() {
  package=$1
  output=$2
  stderr=$3
  if ! "$NODE" "$VALIDATOR" --package "$package" --repository-root "$(dirname -- "$package")" --json >"$output" 2>"$stderr"; then
    cat "$stderr" >&2
    fail "temporary package did not validate: $package"
  fi
  "$NODE" - "$output" <<'NODE'
const fs = require('node:fs');
const result = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
if (result.schemaVersion !== 1 || result.valid !== true || result.errors.length !== 0) {
  throw new Error(`invalid transient fixture: ${JSON.stringify(result)}`);
}
NODE
}
validate_package "$TARGET" "$TMP_ROOT/candidate-validation.json" "$TMP_ROOT/candidate-validation.stderr"
validate_package "$BASELINE" "$TMP_ROOT/baseline-validation.json" "$TMP_ROOT/baseline-validation.stderr"

# Capture two independent source proofs before preparation: the runtime's canonical package hash
# and an inventory of every relative path plus its exact raw bytes.
package_hash() {
  "$NODE" --input-type=module - "$VALIDATOR" "$1" <<'NODE'
import { pathToFileURL } from 'node:url';
const { hashPackage } = await import(pathToFileURL(process.argv[2]).href);
process.stdout.write(`${await hashPackage(process.argv[3], { trackedOnly: false })}\n`);
NODE
}

assert_canonical_hash() {
  value=$1
  label=$2
  printf '%s\n' "$value" | grep -E '^sha256:[0-9a-f]{64}$' >/dev/null ||
    fail "noncanonical $label hash: $value"
}

inventory_package() {
  package=$1
  output=$2
  "$NODE" --input-type=module - "$package" "$output" <<'NODE'
import { lstat, readFile, readdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
const root = process.argv[2];
const output = process.argv[3];
const inventory = [];
async function walk(directory, prefix = '') {
  const names = (await readdir(directory)).sort();
  for (const name of names) {
    const absolute = path.join(directory, name);
    const relative = prefix ? `${prefix}/${name}` : name;
    const state = await lstat(absolute);
    if (state.isSymbolicLink()) throw new Error(`inventory refuses symlink: ${relative}`);
    if (state.isDirectory()) {
      await walk(absolute, relative);
    } else if (state.isFile()) {
      inventory.push({ path: relative, bytesBase64: (await readFile(absolute)).toString('base64') });
    } else {
      throw new Error(`inventory refuses non-regular path: ${relative}`);
    }
  }
}
await walk(root);
await writeFile(output, `${JSON.stringify(inventory)}\n`, { flag: 'wx', mode: 0o600 });
NODE
}

assert_inventory_equal() {
  expected=$1
  actual=$2
  label=$3
  "$NODE" - "$expected" "$actual" "$label" <<'NODE'
const fs = require('node:fs');
const [expectedPath, actualPath, label] = process.argv.slice(2);
const expected = fs.readFileSync(expectedPath);
const actual = fs.readFileSync(actualPath);
if (!expected.equals(actual)) throw new Error(`${label} changed the source path/byte inventory`);
NODE
}

TARGET_HASH_BEFORE=$(package_hash "$TARGET")
assert_canonical_hash "$TARGET_HASH_BEFORE" 'source package'
TARGET_INVENTORY_BEFORE="$TMP_ROOT/target.inventory.before.json"
inventory_package "$TARGET" "$TARGET_INVENTORY_BEFORE"

# Mutation-guard control: independently prove that one included-byte change is visible to both
# the raw inventory and hashPackage before relying on those proofs for the real target.
MUTATION_GUARD="$TMP_ROOT/mutation-guard/e2e-target"
"$NODE" --input-type=module - "$TARGET" "$MUTATION_GUARD" <<'NODE'
import { cp, mkdir, appendFile } from 'node:fs/promises';
import path from 'node:path';
await mkdir(path.dirname(process.argv[3]), { recursive: true });
await cp(process.argv[2], process.argv[3], { recursive: true, errorOnExist: true });
await appendFile(path.join(process.argv[3], 'references/guide.md'), 'mutation guard byte\n');
NODE
MUTATION_INVENTORY="$TMP_ROOT/mutation-guard.inventory.json"
inventory_package "$MUTATION_GUARD" "$MUTATION_INVENTORY"
"$NODE" - "$TARGET_INVENTORY_BEFORE" "$MUTATION_INVENTORY" <<'NODE'
const fs = require('node:fs');
const before = fs.readFileSync(process.argv[2]);
const mutated = fs.readFileSync(process.argv[3]);
if (before.equals(mutated)) throw new Error('independent inventory missed an included-file mutation');
NODE
MUTATION_HASH=$(package_hash "$MUTATION_GUARD")
assert_canonical_hash "$MUTATION_HASH" 'mutation-guard'
[ "$MUTATION_HASH" != "$TARGET_HASH_BEFORE" ] ||
  fail 'hashPackage missed an included-file mutation'

RUN_ROOT=$("$NODE" "$PREPARER" \
  --target "$TARGET/SKILL.md" \
  --mode behavior \
  --runs 1 \
  --baseline-path "$BASELINE" \
  --out-root "$TMP_ROOT/runs" \
  --run-id deterministic-e2e \
  2>"$TMP_ROOT/prepare.stderr")
[ "$RUN_ROOT" = "$TMP_ROOT/runs/deterministic-e2e" ] || fail "unexpected prepared run root: $RUN_ROOT"
[ -f "$RUN_ROOT/manifest.json" ] || fail 'prepare did not publish manifest.json'
[ -d "$RUN_ROOT/evidence" ] || fail 'prepare did not create the evidence directory'

# Simulate host-owned dispatch. This writes deterministic local bytes only: no provider SDK,
# network client, model process, or shell command is invoked. Worker/grader outputs precede their
# create-new last-action receipts, and blind mappings use the frozen grading plan.
"$NODE" --input-type=module - "$RUN_ROOT" "$VALIDATOR" <<'NODE'
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { lstat, mkdir, readFile, readdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const runRoot = process.argv[2];
await mkdir(path.join(runRoot, 'outputs'));
const { hashPackage } = await import(pathToFileURL(process.argv[3]).href);
const manifestPath = path.join(runRoot, 'manifest.json');
const manifest = JSON.parse(await readFile(manifestPath, 'utf8'));
assert.equal(manifest.schemaVersion, 1);
assert.equal(manifest.runId, 'deterministic-e2e');
assert.equal(manifest.targetSkill, 'e2e-target');
assert.equal(manifest.mode, 'behavior');
assert.equal(manifest.runs, 1);
assert.deepEqual(manifest.baseline, {
  kind: 'path',
  identity: manifest.packageHashes.baseline,
});
assert.deepEqual(manifest.expected, [
  { caseId: 'terminal-handback', variant: 'candidate', repetition: 1, kind: 'behavior' },
  { caseId: 'terminal-handback', variant: 'baseline', repetition: 1, kind: 'behavior' },
]);
assert.deepEqual(manifest.pairs, [{
  caseId: 'terminal-handback',
  repetition: 1,
  candidate: 'cases/terminal-handback/1/candidate',
  baseline: 'cases/terminal-handback/1/baseline',
}]);
assert.deepEqual(manifest.gradingPlan, [{
  caseId: 'terminal-handback',
  repetition: 1,
  assertionId: 'clear-terminal-status',
  graderId: null,
}]);

manifest.runConfiguration = {
  host: 'deterministic-host',
  runner: 'simulated-worker',
  model: null,
  sessionIdentity: 'deterministic-e2e-session',
  tier: null,
  effort: null,
};
manifest.gradingPlan = manifest.gradingPlan.map((entry) => ({
  ...entry,
  graderId: 'isolated-grader',
}));
await writeFile(manifestPath, `${JSON.stringify(manifest)}\n`);

function sha256(bytes) {
  return `sha256:${createHash('sha256').update(bytes).digest('hex')}`;
}
async function writeIdentity(relativePath, text) {
  const bytes = Buffer.from(text, 'utf8');
  await writeFile(path.join(runRoot, relativePath), bytes, { flag: 'wx', mode: 0o600 });
  return { path: relativePath, sha256: sha256(bytes), bytes: bytes.length };
}
async function writeJsonCreateNew(relativePath, value) {
  const bytes = Buffer.from(`${JSON.stringify(value)}\n`, 'utf8');
  await writeFile(path.join(runRoot, relativePath), bytes, { flag: 'wx', mode: 0o600 });
  return bytes;
}

const pair = manifest.pairs[0];
const definition = JSON.parse(await readFile(
  path.join(runRoot, 'definitions/behavior.terminal-handback.json'),
  'utf8',
));
assert.deepEqual(definition.capabilities, ['read-workspace']);
const workerProofs = new Map();

// Promise.all plus a two-party start barrier models one inseparable same-wave pair. Both workers
// must enter, and both output/evidence directories must still be empty, before either is released
// to create an output or last-action receipt.
const opaqueWorkerPaths = {
  candidate: 'outputs/output-2f71a9.txt',
  baseline: 'outputs/output-8c34e2.txt',
};
let workersEntered = 0;
let releasePair;
const pairStarted = new Promise((resolve) => { releasePair = resolve; });
const writeStartEntrants = [];
async function simulateWorker(variant) {
  assert.deepEqual(await readdir(path.join(runRoot, 'outputs')), []);
  assert.deepEqual(await readdir(path.join(runRoot, 'evidence')), []);
  workersEntered += 1;
  if (workersEntered === 2) releasePair();
  await pairStarted;
  assert.equal(workersEntered, 2);
  writeStartEntrants.push(workersEntered);

  const workspaceRoot = path.join(runRoot, pair[variant]);
  assert.equal(
    (await readFile(path.join(workspaceRoot, 'fixtures/request.txt'), 'utf8')).trim(),
    'transient fixture payload',
  );
  assert.equal(
    (await readFile(path.join(workspaceRoot, 'package/scripts/runtime.mjs'), 'utf8')).trim(),
    'export const runtimeReady = true;',
  );
  for (const forbidden of [
    'package/evals',
    'package/tests',
    'package/scripts/tests',
    'fixtures/undeclared-answer.json',
  ]) {
    await assert.rejects(
      lstat(path.join(workspaceRoot, forbidden)),
      (error) => error?.code === 'ENOENT',
      `${variant} worker retained forbidden ${forbidden}`,
    );
  }
  assert.deepEqual(await readdir(path.join(workspaceRoot, 'fixtures')), ['request.txt']);
  const copiedHash = await hashPackage(path.join(workspaceRoot, 'package'), { trackedOnly: false });
  assert.equal(copiedHash, manifest.packageHashes[variant]);
  const output = await writeIdentity(
    opaqueWorkerPaths[variant],
    'simulated handback complete\n',
  );
  assert.doesNotMatch(output.path, /candidate|baseline/i);
  const receipt = {
    schemaVersion: 1,
    runId: manifest.runId,
    caseId: 'terminal-handback',
    repetition: 1,
    variant,
    kind: 'behavior',
    targetSkill: manifest.targetSkill,
    baseline: manifest.baseline,
    packageHash: manifest.packageHashes[variant],
    capabilities: definition.capabilities,
    host: manifest.runConfiguration.host,
    runner: manifest.runConfiguration.runner,
    model: manifest.runConfiguration.model,
    sessionIdentity: manifest.runConfiguration.sessionIdentity,
    tier: manifest.runConfiguration.tier,
    effort: manifest.runConfiguration.effort,
    startedAt: '2026-07-16T12:00:00.000Z',
    durationMs: variant === 'candidate' ? 10 : 12,
    output,
    transcript: 'unavailable',
    tokenUsage: 'unavailable',
    selectedSkill: null,
    completionStatus: 'complete',
    error: null,
  };
  const receiptPath = `evidence/action.behavior.terminal-handback.${variant}.1.json`;
  await writeJsonCreateNew(receiptPath, receipt); // receipt is the worker's last action
  workerProofs.set(variant, { output, receiptPath });
}
await Promise.all(['candidate', 'baseline'].map(simulateWorker));
assert.deepEqual(writeStartEntrants, [2, 2]);
assert.equal(workerProofs.size, 2);

const qualitative = definition.assertions.find((item) => item.id === 'clear-terminal-status');
assert.equal(qualitative.kind, 'qualitative');
const blindIdentities = {
  candidate: { anonymizedOutputId: 'output-7f3a2d', graderPath: 'outputs/output-4e2c1b.txt' },
  baseline: { anonymizedOutputId: 'output-91bc4e', graderPath: 'outputs/output-6a8d5f.txt' },
};
assert.equal(
  new Set(Object.values(blindIdentities).map((item) => item.anonymizedOutputId)).size,
  2,
);

for (const variant of ['candidate', 'baseline']) {
  const plan = manifest.gradingPlan[0];
  const worker = workerProofs.get(variant);
  const blind = blindIdentities[variant];
  assert.match(blind.anonymizedOutputId, /^output-[0-9a-f]{6}$/);
  assert.doesNotMatch(blind.anonymizedOutputId, /candidate|baseline/i);
  assert.doesNotMatch(blind.graderPath, /candidate|baseline/i);

  // This exact serialized object is the whole grader-visible view. It carries opaque content and
  // the boolean rubric only: no variant, workspace, host path, mapping filename, or receipt name.
  const graderVisiblePayload = {
    anonymizedOutputId: blind.anonymizedOutputId,
    rubric: qualitative.rubric,
    output: (await readFile(path.join(runRoot, worker.output.path), 'utf8')),
  };
  assert.deepEqual(Object.keys(graderVisiblePayload), ['anonymizedOutputId', 'rubric', 'output']);
  const graderVisibleBytes = Buffer.from(JSON.stringify(graderVisiblePayload), 'utf8');
  assert.doesNotMatch(graderVisibleBytes.toString('utf8'), /candidate|baseline/i);

  const inputPath = `evidence/input.terminal-handback.${variant}.1.${plan.graderId}.json`;
  const mapping = {
    schemaVersion: 1,
    runId: manifest.runId,
    caseId: plan.caseId,
    repetition: plan.repetition,
    graderId: plan.graderId,
    assertionId: plan.assertionId,
    anonymizedOutputId: blind.anonymizedOutputId,
    source: worker.output,
  };
  assert.doesNotMatch(JSON.stringify(mapping), /candidate|baseline/i);
  const inputBytes = await writeJsonCreateNew(inputPath, mapping);

  const graderOutput = await writeIdentity(
    blind.graderPath,
    'The response clearly states a terminal handback.\n',
  );
  assert.doesNotMatch(graderOutput.path, /candidate|baseline/i);
  const graderReceiptPath = `evidence/action.grader.terminal-handback.${variant}.1.${plan.graderId}.json`;
  const graderReceipt = {
    schemaVersion: 1,
    runId: manifest.runId,
    caseId: plan.caseId,
    repetition: plan.repetition,
    variant,
    kind: 'grader',
    targetSkill: manifest.targetSkill,
    baseline: manifest.baseline,
    packageHash: manifest.packageHashes.candidate,
    capabilities: [],
    host: 'deterministic-host',
    runner: 'isolated-grader',
    model: null,
    sessionIdentity: 'deterministic-grader-session',
    tier: null,
    effort: null,
    startedAt: '2026-07-16T12:00:01.000Z',
    durationMs: 3,
    output: graderOutput,
    transcript: 'unavailable',
    tokenUsage: 'unavailable',
    selectedSkill: null,
    completionStatus: 'complete',
    error: null,
  };
  assert.equal(graderReceipt.variant, variant);
  assert.deepEqual(graderReceipt.capabilities, []);
  const graderReceiptBytes = Buffer.from(`${JSON.stringify(graderReceipt)}\n`, 'utf8');
  const grade = {
    schemaVersion: 1,
    runId: manifest.runId,
    caseId: plan.caseId,
    repetition: plan.repetition,
    graderId: plan.graderId,
    assertionId: plan.assertionId,
    anonymizedOutputId: blind.anonymizedOutputId,
    completionStatus: 'complete',
    pass: true,
    rationale: 'The anonymized output explicitly states that the handback is complete.',
    error: null,
    input: { path: inputPath, sha256: sha256(inputBytes) },
    receipt: { path: graderReceiptPath, sha256: sha256(graderReceiptBytes) },
  };
  assert.equal(Object.hasOwn(grade, 'variant'), false);
  await writeJsonCreateNew(
    `evidence/grade.terminal-handback.${variant}.1.${plan.graderId}.json`,
    grade,
  );
  await writeFile(path.join(runRoot, graderReceiptPath), graderReceiptBytes, {
    flag: 'wx',
    mode: 0o600,
  }); // only this host-owned last-action receipt restores the grader's variant
}

await writeJsonCreateNew('quiescence.json', {
  schemaVersion: 1,
  runId: manifest.runId,
  dispatchClosed: true,
});
NODE

TARGET_HASH_AFTER=$(package_hash "$TARGET")
assert_canonical_hash "$TARGET_HASH_AFTER" 'post-dispatch source package'
[ "$TARGET_HASH_AFTER" = "$TARGET_HASH_BEFORE" ] ||
  fail 'simulated host or worker mutated the source target hash'
TARGET_INVENTORY_AFTER="$TMP_ROOT/target.inventory.after-dispatch.json"
inventory_package "$TARGET" "$TARGET_INVENTORY_AFTER"
assert_inventory_equal "$TARGET_INVENTORY_BEFORE" "$TARGET_INVENTORY_AFTER" 'simulated dispatch'

AGGREGATE="$RUN_ROOT/aggregate.json"
REPORT="$RUN_ROOT/report.html"
"$NODE" "$AGGREGATOR" --manifest "$RUN_ROOT/manifest.json" --evidence "$RUN_ROOT/evidence" --out "$AGGREGATE"
"$NODE" "$RENDERER" --aggregate "$AGGREGATE" --out "$REPORT" >"$TMP_ROOT/render.stdout" 2>"$TMP_ROOT/render.stderr"

"$NODE" - "$AGGREGATE" "$REPORT" "$RUN_ROOT/manifest.json" <<'NODE'
const fs = require('node:fs');
const [aggregatePath, reportPath, manifestPath] = process.argv.slice(2);
const aggregate = JSON.parse(fs.readFileSync(aggregatePath, 'utf8'));
const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
if (aggregate.schemaVersion !== 1 || aggregate.executionStatus !== 'complete') {
  throw new Error(`unexpected aggregate status: ${aggregate.executionStatus}; evidence: ${JSON.stringify(aggregate.evidenceErrors)}`);
}
if (aggregate.evidenceErrors.length !== 0 || aggregate.cases.length !== 1) {
  throw new Error(`unexpected aggregate evidence: ${JSON.stringify(aggregate.evidenceErrors)}`);
}
const entry = aggregate.cases[0];
if (entry.caseId !== 'terminal-handback' || entry.candidate.length !== 1 || entry.baseline.length !== 1) {
  throw new Error(`candidate/baseline pair was not preserved: ${JSON.stringify(entry)}`);
}
for (const result of [...entry.candidate, ...entry.baseline]) {
  if (result.completionStatus !== 'complete' || result.assertions.length !== 3) {
    throw new Error(`incomplete deterministic result: ${JSON.stringify(result)}`);
  }
  for (const assertion of result.assertions) {
    if (assertion.pass !== true) throw new Error(`assertion did not pass: ${JSON.stringify(assertion)}`);
  }
}
if (manifest.gradingPlan[0].graderId !== 'isolated-grader') {
  throw new Error('host did not freeze the resolved grading plan');
}
const report = fs.readFileSync(reportPath, 'utf8');
for (const marker of [
  "default-src 'none'",
  'e2e-target evaluation report',
  'Complete',
  'terminal-handback',
]) {
  if (!report.includes(marker)) throw new Error(`rendered report missing marker: ${marker}`);
}
if (/<script\b/i.test(report) || /https?:\/\//i.test(report)) {
  throw new Error('rendered report contains executable or network content');
}
NODE

TARGET_HASH_FINAL=$(package_hash "$TARGET")
assert_canonical_hash "$TARGET_HASH_FINAL" 'post-render source package'
[ "$TARGET_HASH_FINAL" = "$TARGET_HASH_BEFORE" ] ||
  fail 'aggregate or renderer mutated the source target hash'
TARGET_INVENTORY_FINAL="$TMP_ROOT/target.inventory.after-render.json"
inventory_package "$TARGET" "$TARGET_INVENTORY_FINAL"
assert_inventory_equal "$TARGET_INVENTORY_BEFORE" "$TARGET_INVENTORY_FINAL" 'aggregate or renderer'

printf 'PASS: deterministic prepare -> aggregate -> render e2e (no model/provider call)\n'
