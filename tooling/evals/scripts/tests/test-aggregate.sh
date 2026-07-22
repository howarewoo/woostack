#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../../../.." && pwd)
AGGREGATOR="$SCRIPT_DIR/../aggregate.mjs"
NODE=${NODE:-node}
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/woostack-eval-aggregate.XXXXXX")

cleanup() {
  cleanup_status=$?
  trap - EXIT HUP INT TERM
  rm -rf "$TMP_ROOT"
  exit "$cleanup_status"
}
trap cleanup EXIT HUP INT TERM

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

# Build every fixture before the intentional missing-implementation check. This keeps Red honest:
# malformed fixture JSON, a missing evidence file, or an inconsistent expected identity fails here.
"$NODE" --input-type=module - "$TMP_ROOT" "$REPOSITORY_ROOT/skills/using-woostack/scripts/validate-skill-package.mjs" <<'NODE'
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { chmod, cp, link, lstat, mkdir, readFile, readdir, rm, symlink, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const root = process.argv[2];
const { hashPackage } = await import(pathToFileURL(process.argv[3]).href);
const runId = '20260715T120000Z-4242';
const targetSkill = 'woostack-example';
let packageHash = null;
const baseline = { kind: 'git-ref', identity: '0123456789abcdef0123456789abcdef01234567' };
const materializationLimit = 1024 * 1024;
const runConfiguration = {
  host: 'omp',
  runner: 'worker',
  model: 'model-a',
  sessionIdentity: null,
  tier: 'standard',
  effort: 'high',
};
const cases = [
  {
    caseId: 'objective-check',
    kind: 'behavior',
    definition: {
      id: 'objective-check',
      prompt: 'Return the observable marker.',
      capabilities: ['read-workspace'],
      expected: 'Candidate output contains the new marker.',
      assertions: [{
        id: 'candidate-gain',
        kind: 'final-contains',
        substring: 'candidate marker',
        critical: true,
      }, {
        id: 'shared-observation',
        kind: 'final-contains',
        substring: 'shared marker',
        critical: false,
      }],
    },
  },
  {
    caseId: 'qualitative-check',
    kind: 'behavior',
    definition: {
      id: 'qualitative-check',
      prompt: 'Write a concise handoff.',
      capabilities: ['read-workspace'],
      expected: 'The handoff is clear.',
      assertions: [{
        id: 'clear-handoff',
        kind: 'qualitative',
        rubric: 'Does the handoff clearly state the next action?',
        critical: false,
      }],
    },
  },
  {
    caseId: 'negative-trigger',
    kind: 'trigger',
    definition: {
      id: 'negative-trigger',
      query: 'Review an existing pull request.',
      shouldTrigger: false,
      expectedSkill: 'none',
      conflictsWith: [targetSkill, 'catalog-peer'],
    },
  },
  {
    caseId: 'positive-trigger',
    kind: 'trigger',
    definition: {
      id: 'positive-trigger',
      query: 'Evaluate the example skill.',
      shouldTrigger: true,
      expectedSkill: targetSkill,
      conflictsWith: ['catalog-peer'],
    },
  },
];

function sha256(data) {
  return `sha256:${createHash('sha256').update(data).digest('hex')}`;
}

async function writeIdentity(runRoot, relativePath, contents) {
  const bytes = Buffer.from(contents, 'utf8');
  const absolutePath = path.join(runRoot, relativePath);
  await mkdir(path.dirname(absolutePath), { recursive: true });
  await writeFile(absolutePath, bytes, { flag: 'wx' });
  return { path: relativePath, sha256: sha256(bytes), bytes: bytes.length };
}

function receiptName(kind, caseId, variant, repetition) {
  return `action.${kind}.${caseId}.${variant}.${repetition}.json`;
}

function selectedSkill(caseId, variant) {
  if (caseId === 'positive-trigger') {
    return variant === 'candidate' ? targetSkill : 'none';
  }
  if (caseId === 'negative-trigger') {
    return variant === 'candidate' ? targetSkill : 'catalog-peer';
  }
  return null;
}

function actionOutput(caseId, variant) {
  if (caseId === 'objective-check') {
    return variant === 'candidate'
      ? 'candidate marker\nshared marker\n'
      : 'baseline output\nshared marker\n';
  }
  if (caseId === 'qualitative-check') {
    return variant === 'candidate' ? 'Next: run the focused check.\n' : 'Looks okay.\n';
  }
  return `catalog selection recorded for ${caseId}\n`;
}

async function writeActionReceipt(runRoot, item, variant, repetition) {
  const stem = `${item.kind}.${item.caseId}.${variant}.${repetition}`;
  const output = await writeIdentity(runRoot, `outputs/${stem}.txt`, actionOutput(item.caseId, variant));
  // Transcript prose deliberately contradicts trigger selection. Aggregate metrics must use
  // selectedSkill, never transcript text.
  const transcriptText = item.kind === 'trigger'
    ? (selectedSkill(item.caseId, variant) === targetSkill
        ? 'Transcript says selected none.\n'
        : `Transcript says selected ${targetSkill}.\n`)
    : `Observed ${item.caseId}.\n`;
  const transcript = await writeIdentity(runRoot, `transcripts/${stem}.txt`, transcriptText);
  const receiptPackageHash = await hashPackage(
    path.join(runRoot, 'cases', item.caseId, String(repetition), variant, 'package'),
    { trackedOnly: false },
  );
  if (packageHash === null) packageHash = receiptPackageHash;
  assert.equal(receiptPackageHash, packageHash, 'synthetic copied packages must hash identically');
  const receipt = {
    schemaVersion: 1,
    runId,
    caseId: item.caseId,
    repetition,
    variant,
    kind: item.kind,
    targetSkill,
    baseline,
    packageHash: receiptPackageHash,
    capabilities: ['read-workspace'],
    host: runConfiguration.host,
    runner: runConfiguration.runner,
    model: runConfiguration.model,
    sessionIdentity: runConfiguration.sessionIdentity,
    tier: runConfiguration.tier,
    effort: runConfiguration.effort,
    startedAt: `2026-07-15T12:00:0${repetition}.000Z`,
    durationMs: variant === 'candidate' ? repetition * 100 : repetition * 200 + 100,
    output,
    transcript,
    tokenUsage: 'unavailable',
    selectedSkill: selectedSkill(item.caseId, variant),
    completionStatus: 'complete',
    error: null,
  };
  await writeFile(
    path.join(runRoot, 'evidence', receiptName(item.kind, item.caseId, variant, repetition)),
    `${JSON.stringify(receipt, null, 2)}\n`,
    { flag: 'wx' },
  );
}

async function writeGrade(runRoot, variant, repetition) {
  const graderId = 'clarity-grader';
  const anonymizedOutputId =
    variant === 'candidate' ? `output-7f3a-${repetition}` : `output-91bc-${repetition}`;
  const graderOutput = await writeIdentity(
    runRoot,
    `outputs/grader.qualitative-check.${variant}.${graderId}.${repetition}.txt`,
    variant === 'candidate' ? 'The next action is missing.\n' : 'The next action is explicit.\n',
  );
  // The host-owned action.grader.* receipt carries the manifest variant. The grade payload stays
  // blind; aggregate may restore its variant only after this linked receipt validates.
  const graderReceipt = {
    schemaVersion: 1,
    runId,
    caseId: 'qualitative-check',
    repetition,
    variant,
    kind: 'grader',
    targetSkill,
    baseline,
    packageHash,
    capabilities: [],
    host: runConfiguration.host,
    runner: 'grader',
    model: 'grader-model',
    sessionIdentity: null,
    tier: 'standard',
    effort: 'high',
    startedAt: `2026-07-15T12:01:0${repetition}.000Z`,
    durationMs: 50,
    output: graderOutput,
    transcript: 'unavailable',
    tokenUsage: 'unavailable',
    selectedSkill: null,
    completionStatus: 'complete',
    error: null,
  };
  const receiptPath = `evidence/action.grader.qualitative-check.${variant}.${repetition}.${graderId}.json`;
  const receiptBytes = Buffer.from(`${JSON.stringify(graderReceipt, null, 2)}\n`, 'utf8');
  await writeFile(path.join(runRoot, receiptPath), receiptBytes, { flag: 'wx' });
  const workerReceipt = JSON.parse(await readFile(path.join(
    runRoot,
    'evidence',
    receiptName('behavior', 'qualitative-check', variant, repetition),
  ), 'utf8'));
  const inputPath =
    `evidence/input.qualitative-check.${variant}.${repetition}.${graderId}.json`;
  const inputMapping = {
    schemaVersion: 1,
    runId,
    caseId: 'qualitative-check',
    repetition,
    graderId,
    assertionId: 'clear-handoff',
    anonymizedOutputId,
    source: workerReceipt.output,
  };
  const inputBytes = Buffer.from(`${JSON.stringify(inputMapping, null, 2)}\n`, 'utf8');
  await writeFile(path.join(runRoot, inputPath), inputBytes, { flag: 'wx' });
  const grade = {
    schemaVersion: 1,
    runId,
    caseId: 'qualitative-check',
    repetition,
    graderId,
    assertionId: 'clear-handoff',
    anonymizedOutputId,
    completionStatus: 'complete',
    pass: variant === 'baseline',
    rationale: variant === 'candidate'
      ? 'The handoff does not identify a next action.'
      : 'The handoff names the required next action.',
    error: null,
    input: { path: inputPath, sha256: sha256(inputBytes) },
    receipt: { path: receiptPath, sha256: sha256(receiptBytes) },
  };
  assert.equal(Object.hasOwn(grade, 'variant'), false, 'qualitative grade must stay blinded');
  await writeFile(
    path.join(runRoot, 'evidence', `grade.qualitative-check.${variant}.${repetition}.${graderId}.json`),
    `${JSON.stringify(grade, null, 2)}\n`,
    { flag: 'wx' },
  );
}

async function writeCorpus(runRoot, item, repetition, variant) {
  const evalRoot = path.join(runRoot, 'cases', item.caseId, String(repetition), variant, 'package', 'evals');
  await mkdir(evalRoot, { recursive: true });
  await writeFile(
    path.join(path.dirname(evalRoot), 'SKILL.md'),
    `---\nname: ${targetSkill}\ndescription: Synthetic aggregate fixture.\n---\n`,
  );
  const behavior = {
    schemaVersion: 1,
    skill: targetSkill,
    cases: cases.filter((entry) => entry.kind === 'behavior').map((entry) => entry.definition),
  };
  const trigger = {
    schemaVersion: 1,
    skill: targetSkill,
    cases: cases.filter((entry) => entry.kind === 'trigger').map((entry) => entry.definition),
  };
  await writeFile(path.join(evalRoot, 'evals.json'), `${JSON.stringify(behavior, null, 2)}\n`);
  await writeFile(path.join(evalRoot, 'trigger-evals.json'), `${JSON.stringify(trigger, null, 2)}\n`);
}

async function createRun(name, repetitions) {
  const runRoot = path.join(root, name);
  await mkdir(runRoot, { mode: 0o700 });
  await mkdir(path.join(runRoot, 'evidence'));
  await mkdir(path.join(runRoot, 'definitions'));
  for (const item of cases) {
    await writeFile(
      path.join(runRoot, 'definitions', `${item.kind}.${item.caseId}.json`),
      `${JSON.stringify(item.definition)}\n`,
      { flag: 'wx' },
    );
  }
  const expected = [];
  const pairs = [];
  for (const item of cases) {
    for (let repetition = 1; repetition <= repetitions; repetition += 1) {
      const candidate = `cases/${item.caseId}/${repetition}/candidate`;
      const baselinePath = `cases/${item.caseId}/${repetition}/baseline`;
      for (const variant of ['candidate', 'baseline']) {
        expected.push({ caseId: item.caseId, variant, repetition, kind: item.kind });
        await writeCorpus(runRoot, item, repetition, variant);
        await writeActionReceipt(runRoot, item, variant, repetition);
      }
      pairs.push({ caseId: item.caseId, repetition, candidate, baseline: baselinePath });
      if (item.caseId === 'qualitative-check') {
        await writeGrade(runRoot, 'candidate', repetition);
        await writeGrade(runRoot, 'baseline', repetition);
      }
    }
  }
  const manifest = {
    schemaVersion: 1,
    runId,
    targetSkill,
    mode: 'all',
    runs: repetitions,
    baseline,
    runConfiguration,
    originalPackageHash: packageHash,
    packageHashes: { candidate: packageHash, baseline: packageHash },
    gradingPlan: Array.from({ length: repetitions }, (_, index) => ({
      caseId: 'qualitative-check',
      repetition: index + 1,
      assertionId: 'clear-handoff',
      graderId: 'clarity-grader',
    })),
    expected,
    pairs,
  };
  await writeFile(path.join(runRoot, 'manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`);
  await writeFile(
    path.join(runRoot, 'quiescence.json'),
    `${JSON.stringify({ schemaVersion: 1, runId, dispatchClosed: true }, null, 2)}\n`,
    { flag: 'wx', mode: 0o600 },
  );
  return runRoot;
}

async function cloneRun(sourceName, targetName) {
  await cp(path.join(root, sourceName), path.join(root, targetName), { recursive: true, errorOnExist: true });
  await rm(path.join(root, targetName, 'aggregate.json'), { force: true });
  return path.join(root, targetName);
}

async function treeUsage(directory) {
  let entries = 1;
  let bytes = 0;
  async function walk(current) {
    for (const entry of await readdir(current, { withFileTypes: true })) {
      entries += 1;
      const absolute = path.join(current, entry.name);
      if (entry.isDirectory()) {
        await walk(absolute);
      } else if (entry.isFile()) {
        bytes += Number((await lstat(absolute, { bigint: true })).size);
      }
    }
  }
  await walk(directory);
  return { entries, bytes };
}

async function mutateReceipt(runRoot, transform) {
  const receiptPath = path.join(runRoot, 'evidence', receiptName('behavior', 'objective-check', 'candidate', 1));
  const receipt = JSON.parse(await readFile(receiptPath, 'utf8'));
  transform(receipt);
  await writeFile(receiptPath, `${JSON.stringify(receipt, null, 2)}\n`);
}

async function mutateActionReceipt(runRoot, kind, caseId, variant, repetition, transform) {
  const receiptPath = path.join(
    runRoot,
    'evidence',
    receiptName(kind, caseId, variant, repetition),
  );
  const receipt = JSON.parse(await readFile(receiptPath, 'utf8'));
  transform(receipt);
  await writeFile(receiptPath, `${JSON.stringify(receipt, null, 2)}\n`);
}

async function configureObjectiveAssertions(runRoot, assertions, outputs = null) {
  const definitionPath = path.join(runRoot, 'definitions', 'behavior.objective-check.json');
  const definition = JSON.parse(await readFile(definitionPath, 'utf8'));
  definition.assertions = assertions;
  await writeFile(definitionPath, `${JSON.stringify(definition, null, 2)}\n`);
  if (outputs === null) return;
  for (const variant of ['candidate', 'baseline']) {
    const bytes = Buffer.from(outputs[variant], 'utf8');
    await writeFile(
      path.join(runRoot, 'outputs', `behavior.objective-check.${variant}.1.txt`),
      bytes,
    );
    await mutateActionReceipt(
      runRoot,
      'behavior',
      'objective-check',
      variant,
      1,
      (receipt) => {
        receipt.output.sha256 = sha256(bytes);
        receipt.output.bytes = bytes.length;
      },
    );
  }
}

async function mutateGraderReceiptForVariant(runRoot, variant, transform) {
  const receiptPath = path.join(
    runRoot,
    'evidence',
    `action.grader.qualitative-check.${variant}.1.clarity-grader.json`,
  );
  const receipt = JSON.parse(await readFile(receiptPath, 'utf8'));
  transform(receipt);
  const receiptBytes = Buffer.from(`${JSON.stringify(receipt, null, 2)}\n`, 'utf8');
  await writeFile(receiptPath, receiptBytes);

  const gradePath = path.join(
    runRoot,
    'evidence',
    `grade.qualitative-check.${variant}.1.clarity-grader.json`,
  );
  const grade = JSON.parse(await readFile(gradePath, 'utf8'));
  grade.receipt.sha256 = sha256(receiptBytes);
  await writeFile(gradePath, `${JSON.stringify(grade, null, 2)}\n`);
}

async function mutateGraderReceipt(runRoot, transform) {
  await mutateGraderReceiptForVariant(runRoot, 'candidate', transform);
}

async function mutateCandidateGrade(runRoot, transform) {
  const gradePath = path.join(
    runRoot,
    'evidence',
    'grade.qualitative-check.candidate.1.clarity-grader.json',
  );
  const grade = JSON.parse(await readFile(gradePath, 'utf8'));
  transform(grade);
  await writeFile(gradePath, `${JSON.stringify(grade, null, 2)}\n`);
}

async function mutateGradeInput(runRoot, variant, transform) {
  const inputPath = path.join(
    runRoot,
    'evidence',
    `input.qualitative-check.${variant}.1.clarity-grader.json`,
  );
  const input = JSON.parse(await readFile(inputPath, 'utf8'));
  transform(input);
  const inputBytes = Buffer.from(`${JSON.stringify(input, null, 2)}\n`, 'utf8');
  await writeFile(inputPath, inputBytes);
  const gradePath = path.join(
    runRoot,
    'evidence',
    `grade.qualitative-check.${variant}.1.clarity-grader.json`,
  );
  const grade = JSON.parse(await readFile(gradePath, 'utf8'));
  grade.input.sha256 = sha256(inputBytes);
  await writeFile(gradePath, `${JSON.stringify(grade, null, 2)}\n`);
}

async function addObjectiveQualitativePair(runRoot) {
  const definitionPath = path.join(runRoot, 'definitions', 'behavior.objective-check.json');
  const definition = JSON.parse(await readFile(definitionPath, 'utf8'));
  definition.assertions.push({
    id: 'cross-case-grade',
    kind: 'qualitative',
    rubric: 'Does the output provide a clear marker?',
    critical: false,
  });
  await writeFile(definitionPath, `${JSON.stringify(definition)}\n`);

  for (const variant of ['candidate', 'baseline']) {
    const sourceReceiptPath = path.join(
      runRoot,
      'evidence',
      `action.grader.qualitative-check.${variant}.1.clarity-grader.json`,
    );
    const graderReceipt = JSON.parse(await readFile(sourceReceiptPath, 'utf8'));
    graderReceipt.caseId = 'objective-check';
    const graderReceiptPath = `evidence/action.grader.objective-check.${variant}.1.clarity-grader.json`;
    const graderReceiptBytes =
      Buffer.from(`${JSON.stringify(graderReceipt, null, 2)}\n`, 'utf8');
    await writeFile(path.join(runRoot, graderReceiptPath), graderReceiptBytes, { flag: 'wx' });

    const workerReceipt = JSON.parse(await readFile(path.join(
      runRoot,
      'evidence',
      receiptName('behavior', 'objective-check', variant, 1),
    ), 'utf8'));
    const anonymizedOutputId =
      variant === 'candidate' ? 'output-7f3a-1' : 'output-objective-baseline-1';
    const inputPath = `evidence/input.objective-check.${variant}.1.clarity-grader.json`;
    const input = {
      schemaVersion: 1,
      runId,
      caseId: 'objective-check',
      repetition: 1,
      graderId: 'clarity-grader',
      assertionId: 'cross-case-grade',
      anonymizedOutputId,
      source: workerReceipt.output,
    };
    const inputBytes = Buffer.from(`${JSON.stringify(input, null, 2)}\n`, 'utf8');
    await writeFile(path.join(runRoot, inputPath), inputBytes, { flag: 'wx' });
    const grade = {
      schemaVersion: 1,
      runId,
      caseId: 'objective-check',
      repetition: 1,
      graderId: 'clarity-grader',
      assertionId: 'cross-case-grade',
      anonymizedOutputId,
      completionStatus: 'complete',
      pass: true,
      rationale: 'The output provides the requested marker.',
      error: null,
      input: { path: inputPath, sha256: sha256(inputBytes) },
      receipt: { path: graderReceiptPath, sha256: sha256(graderReceiptBytes) },
    };
    await writeFile(
      path.join(runRoot, 'evidence', `grade.objective-check.${variant}.1.clarity-grader.json`),
      `${JSON.stringify(grade, null, 2)}\n`,
      { flag: 'wx' },
    );
  }
}

const complete = await createRun('complete', 2);
const oneRun = await createRun('one-run', 1);

const sessionIdentityRun = await cloneRun('one-run', 'session-identity');
const sessionManifestPath = path.join(sessionIdentityRun, 'manifest.json');
const sessionManifest = JSON.parse(await readFile(sessionManifestPath, 'utf8'));
sessionManifest.runConfiguration.model = null;
sessionManifest.runConfiguration.sessionIdentity = 'shared-session';
await writeFile(sessionManifestPath, `${JSON.stringify(sessionManifest, null, 2)}\n`);
for (const expected of sessionManifest.expected) {
  await mutateActionReceipt(
    sessionIdentityRun,
    expected.kind,
    expected.caseId,
    expected.variant,
    expected.repetition,
    (receipt) => {
      receipt.model = null;
      receipt.sessionIdentity = 'shared-session';
    },
  );
}
for (const variant of ['candidate', 'baseline']) {
  await mutateGraderReceiptForVariant(sessionIdentityRun, variant, (receipt) => {
    receipt.model = null;
    receipt.sessionIdentity = 'shared-grader-session';
  });
}

const tokenUsageRun = await cloneRun('one-run', 'token-usage');
const tokenUsageManifest =
  JSON.parse(await readFile(path.join(tokenUsageRun, 'manifest.json'), 'utf8'));
for (const expected of tokenUsageManifest.expected) {
  await mutateActionReceipt(
    tokenUsageRun,
    expected.kind,
    expected.caseId,
    expected.variant,
    expected.repetition,
    (receipt) => {
      receipt.tokenUsage = expected.variant === 'candidate'
        ? { input: 10, output: 5, total: 15 }
        : { input: 8, output: 4, total: 12 };
    },
  );
}

const objectiveAssertionKinds = await cloneRun('one-run', 'objective-assertion-kinds');
const objectiveDefinitionPath =
  path.join(objectiveAssertionKinds, 'definitions', 'behavior.objective-check.json');
const objectiveDefinition = JSON.parse(await readFile(objectiveDefinitionPath, 'utf8'));
objectiveDefinition.assertions.push(
  { id: 'final-excludes-pass', kind: 'final-excludes', substring: 'forbidden marker', critical: false },
  { id: 'final-excludes-fail', kind: 'final-excludes', substring: 'shared marker', critical: false },
  { id: 'receipt-field-pass', kind: 'receipt-field-equals', pointer: '/selectedSkill', expected: null, critical: false },
  { id: 'receipt-field-fail', kind: 'receipt-field-equals', pointer: '/selectedSkill', expected: 'none', critical: false },
  { id: 'path-absent-pass', kind: 'path-absent', path: 'missing-dir/result.txt', critical: false },
  { id: 'path-exists-pass', kind: 'path-exists', path: 'assertions/present.txt', critical: false },
  { id: 'path-absent-fail', kind: 'path-absent', path: 'assertions/present.txt', critical: false },
  { id: 'file-contains-pass', kind: 'file-contains', file: 'assertions/present.txt', substring: 'present marker', critical: false },
  { id: 'file-contains-fail', kind: 'file-contains', file: 'assertions/present.txt', substring: 'absent marker', critical: false },
  { id: 'file-contains-missing', kind: 'file-contains', file: 'assertions/missing.txt', substring: 'marker', critical: false },
  { id: 'file-sha256-pass', kind: 'file-sha256-equals', file: 'assertions/present.txt', sha256: 'sha256:688fd6bd79488b16291edc13a90ca17ad758115f04ac715a75abf2914229b226', critical: false },
  { id: 'file-sha256-fail', kind: 'file-sha256-equals', file: 'assertions/present.txt', sha256: 'sha256:0000000000000000000000000000000000000000000000000000000000000000', critical: false },
  { id: 'file-sha256-missing', kind: 'file-sha256-equals', file: 'assertions/missing.txt', sha256: 'sha256:688fd6bd79488b16291edc13a90ca17ad758115f04ac715a75abf2914229b226', critical: false },
  { id: 'file-excludes-pass', kind: 'file-excludes', file: 'assertions/present.txt', substring: 'absent marker', critical: false },
  { id: 'file-excludes-fail', kind: 'file-excludes', file: 'assertions/present.txt', substring: 'present marker', critical: false },
  { id: 'file-excludes-missing', kind: 'file-excludes', file: 'assertions/missing.txt', substring: 'marker', critical: false },
  { id: 'json-path-pass', kind: 'json-path-equals', file: 'assertions/valid.json', pointer: '/status', expected: 'ready', critical: false },
  { id: 'json-path-mismatch', kind: 'json-path-equals', file: 'assertions/valid.json', pointer: '/status', expected: 'blocked', critical: false },
  { id: 'json-path-missing', kind: 'json-path-equals', file: 'assertions/missing.json', pointer: '/status', expected: 'ready', critical: false },
  { id: 'json-path-malformed', kind: 'json-path-equals', file: 'assertions/malformed.json', pointer: '/status', expected: 'ready', critical: false },
);
await writeFile(objectiveDefinitionPath, `${JSON.stringify(objectiveDefinition)}\n`);
for (const variant of ['candidate', 'baseline']) {
  const assertionRoot = path.join(
    objectiveAssertionKinds,
    'cases',
    'objective-check',
    '1',
    variant,
    'assertions',
  );
  await mkdir(assertionRoot);
  await writeFile(path.join(assertionRoot, 'present.txt'), 'present marker\n');
  await writeFile(path.join(assertionRoot, 'valid.json'), '{"status":"ready"}\n');
  await writeFile(path.join(assertionRoot, 'malformed.json'), '{"status":\n');
}

const snapshotFileBoundary = await cloneRun('one-run', 'snapshot-file-boundary');
await writeFile(
  path.join(snapshotFileBoundary, 'snapshot-file-boundary.bin'),
  Buffer.alloc(16 * 1024 * 1024),
);

const snapshotTotalBoundary = await cloneRun('one-run', 'snapshot-total-boundary');
const snapshotTotalBoundaryRoot = path.join(snapshotTotalBoundary, 'snapshot-total-boundary');
await mkdir(snapshotTotalBoundaryRoot);
const snapshotTotalUsage = await treeUsage(snapshotTotalBoundary);
let snapshotTotalPadding = (128 * 1024 * 1024) - snapshotTotalUsage.bytes;
for (let index = 0; snapshotTotalPadding > 0; index += 1) {
  const bytes = Math.min(snapshotTotalPadding, 16 * 1024 * 1024);
  await writeFile(
    path.join(snapshotTotalBoundaryRoot, `${String(index).padStart(2, '0')}.bin`),
    Buffer.alloc(bytes),
  );
  snapshotTotalPadding -= bytes;
}
assert.equal((await treeUsage(snapshotTotalBoundary)).bytes, 128 * 1024 * 1024);

const snapshotEntryBoundary = await cloneRun('one-run', 'snapshot-entry-boundary');
const snapshotEntryBoundaryRoot = path.join(snapshotEntryBoundary, 'snapshot-entry-boundary');
await mkdir(snapshotEntryBoundaryRoot);
const snapshotEntryPadding = 4096 - (await treeUsage(snapshotEntryBoundary)).entries;
assert.equal(snapshotEntryPadding > 0, true);
for (let offset = 0; offset < snapshotEntryPadding; offset += 256) {
  await Promise.all(Array.from(
    { length: Math.min(256, snapshotEntryPadding - offset) },
    (_, index) => writeFile(
      path.join(snapshotEntryBoundaryRoot, `${offset + index}.txt`),
      '',
    ),
  ));
}
assert.equal((await treeUsage(snapshotEntryBoundary)).entries, 4096);

const snapshotFileLimit = await cloneRun('one-run', 'snapshot-file-limit');
await writeFile(
  path.join(snapshotFileLimit, 'snapshot-file-limit.bin'),
  Buffer.alloc((16 * 1024 * 1024) + 1),
);

const snapshotTotalLimit = await cloneRun('one-run', 'snapshot-total-limit');
const snapshotTotalRoot = path.join(snapshotTotalLimit, 'snapshot-total');
await mkdir(snapshotTotalRoot);
const snapshotTotalSource = path.join(snapshotTotalRoot, '00.bin');
await writeFile(snapshotTotalSource, Buffer.alloc(16 * 1024 * 1024));
for (let index = 1; index < 8; index += 1) {
  await link(snapshotTotalSource, path.join(snapshotTotalRoot, `${String(index).padStart(2, '0')}.bin`));
}

const snapshotEntryLimit = await cloneRun('one-run', 'snapshot-entry-limit');
const snapshotEntryRoot = path.join(snapshotEntryLimit, 'snapshot-entry-limit');
await mkdir(snapshotEntryRoot);
for (let offset = 0; offset < 4096; offset += 256) {
  await Promise.all(Array.from({ length: 256 }, (_, index) =>
    writeFile(path.join(snapshotEntryRoot, `${offset + index}.txt`), '')));
}

const missingQuiescence = await cloneRun('one-run', 'missing-quiescence');
await rm(path.join(missingQuiescence, 'quiescence.json'));

const invalidQuiescence = await cloneRun('one-run', 'invalid-quiescence');
await writeFile(
  path.join(invalidQuiescence, 'quiescence.json'),
  `${JSON.stringify({ schemaVersion: 1, runId, dispatchClosed: false }, null, 2)}\n`,
);

for (const snapshotName of ['snapshot-rewrite', 'snapshot-replacement']) {
  const snapshotRun = await cloneRun('one-run', snapshotName);
  await writeFile(
    path.join(snapshotRun, 'definitions', 'snapshot-target.json'),
    `${'a'.repeat(256 * 1024)}\n`,
    { flag: 'wx' },
  );
}
const snapshotDirectorySwap =
  await cloneRun('one-run', 'snapshot-directory-swap');
const snapshotSwapTarget = path.join(snapshotDirectorySwap, 'snapshot-swap-target');
await mkdir(snapshotSwapTarget);
await writeFile(path.join(snapshotSwapTarget, 'marker.txt'), 'directory\n');
const snapshotReadBinding =
  await cloneRun('one-run', 'snapshot-read-binding');

const publicRunRoot = await cloneRun('one-run', 'public-run-root');
await chmod(publicRunRoot, 0o755);

const duplicate = await cloneRun('one-run', 'duplicate');
await cp(
  path.join(duplicate, 'evidence', receiptName('behavior', 'objective-check', 'candidate', 1)),
  path.join(duplicate, 'evidence', 'duplicate-objective-receipt.json'),
);

const unknown = await cloneRun('one-run', 'unknown');
const unknownReceiptPath = path.join(unknown, 'evidence', 'action.behavior.unknown-case.candidate.1.json');
const unknownReceipt = JSON.parse(await readFile(
  path.join(unknown, 'evidence', receiptName('behavior', 'objective-check', 'candidate', 1)),
  'utf8',
));
unknownReceipt.caseId = 'unknown-case';
await writeFile(unknownReceiptPath, `${JSON.stringify(unknownReceipt, null, 2)}\n`);

const malformed = await cloneRun('one-run', 'malformed');
await writeFile(
  path.join(malformed, 'evidence', receiptName('behavior', 'objective-check', 'candidate', 1)),
  '{"schemaVersion":1,\n',
);

for (const [name, status] of [['timed-out', 'timed-out'], ['failed', 'failed']]) {
  const runRoot = await cloneRun('one-run', name);
  await mutateReceipt(runRoot, (receipt) => {
    receipt.completionStatus = status;
    receipt.error = { code: `worker-${status}`, message: `Worker ${status}.` };
  });
}

const invalidActionStatus = await cloneRun('one-run', 'invalid-action-status');
await mutateReceipt(invalidActionStatus, (receipt) => {
  receipt.completionStatus = 'blocked';
});

const completeActionError = await cloneRun('one-run', 'complete-action-error');
await mutateReceipt(completeActionError, (receipt) => {
  receipt.error = { code: 'unexpected-error', message: 'Unexpected error.' };
});

const failedActionNullError = await cloneRun('one-run', 'failed-action-null-error');
await mutateReceipt(failedActionNullError, (receipt) => {
  receipt.completionStatus = 'failed';
  receipt.error = null;
});

for (const [name, error] of [
  ['failed-action-extra-error-key', { code: 'worker-failed', message: 'Worker failed.', extra: true }],
  ['failed-action-invalid-error-code', { code: 'WorkerFailed', message: 'Worker failed.' }],
  ['failed-action-unsanitized-message', { code: 'worker-failed', message: ' Worker\nfailed. ' }],
]) {
  const runRoot = await cloneRun('one-run', name);
  await mutateReceipt(runRoot, (receipt) => {
    receipt.completionStatus = 'failed';
    receipt.error = error;
  });
}

for (const [name, field, value] of [
  ['model-mismatch', 'model', 'model-b'],
  ['tier-mismatch', 'tier', 'deep'],
  ['effort-mismatch', 'effort', 'low'],
]) {
  const runRoot = await cloneRun('one-run', name);
  await mutateReceipt(runRoot, (receipt) => { receipt[field] = value; });
}

const repetitionMismatch = await cloneRun('one-run', 'repetition-mismatch');
await mutateReceipt(repetitionMismatch, (receipt) => { receipt.repetition = 2; });

const identityMismatch = await cloneRun('one-run', 'identity-mismatch');
await mutateReceipt(identityMismatch, (receipt) => { receipt.runId = 'other-run'; });

const packageMismatch = await cloneRun('one-run', 'package-mismatch');
await mutateReceipt(packageMismatch, (receipt) => { receipt.packageHash = `sha256:${'b'.repeat(64)}`; });

const refreshedBaselineMutation =
  await cloneRun('one-run', 'refreshed-baseline-mutation');
await writeFile(
  path.join(
    refreshedBaselineMutation,
    'cases',
    'objective-check',
    '1',
    'baseline',
    'package',
    'mutation.txt',
  ),
  'mutated baseline package\n',
  { flag: 'wx' },
);
const refreshedBaselineHash = await hashPackage(
  path.join(
    refreshedBaselineMutation,
    'cases',
    'objective-check',
    '1',
    'baseline',
    'package',
  ),
  { trackedOnly: false },
);
await mutateActionReceipt(
  refreshedBaselineMutation,
  'behavior',
  'objective-check',
  'baseline',
  1,
  (receipt) => { receipt.packageHash = refreshedBaselineHash; },
);

const distinctOriginalPackageHash =
  await cloneRun('one-run', 'distinct-original-package-hash');
const distinctOriginalManifestPath = path.join(distinctOriginalPackageHash, 'manifest.json');
const distinctOriginalManifest =
  JSON.parse(await readFile(distinctOriginalManifestPath, 'utf8'));
distinctOriginalManifest.originalPackageHash = `sha256:${'f'.repeat(64)}`;
await writeFile(
  distinctOriginalManifestPath,
  `${JSON.stringify(distinctOriginalManifest, null, 2)}\n`,
);

const missingDuration = await cloneRun('one-run', 'missing-duration');
await mutateReceipt(missingDuration, (receipt) => { delete receipt.durationMs; });

const invalidStartedAt = await cloneRun('one-run', 'invalid-started-at');
await mutateReceipt(invalidStartedAt, (receipt) => {
  receipt.startedAt = '2026-02-30T12:00:00Z';
});

const unsafeDuration = await cloneRun('one-run', 'unsafe-duration');
await mutateReceipt(unsafeDuration, (receipt) => {
  receipt.durationMs = Number.MAX_SAFE_INTEGER + 1;
});

const unsafeTokenUsage = await cloneRun('one-run', 'unsafe-token-usage');
await mutateReceipt(unsafeTokenUsage, (receipt) => {
  receipt.tokenUsage = {
    input: Number.MAX_SAFE_INTEGER + 1,
    output: 0,
    total: Number.MAX_SAFE_INTEGER + 1,
  };
});

const unsafeOutputBytes = await cloneRun('one-run', 'unsafe-output-bytes');
await mutateReceipt(unsafeOutputBytes, (receipt) => {
  receipt.output.bytes = Number.MAX_SAFE_INTEGER + 1;
});

const missingCompletionIdentity = await cloneRun('one-run', 'missing-completion-identity');
await mutateReceipt(missingCompletionIdentity, (receipt) => {
  receipt.model = null;
  receipt.sessionIdentity = null;
});

const ambiguousCompletionIdentity = await cloneRun('one-run', 'ambiguous-completion-identity');
await mutateReceipt(ambiguousCompletionIdentity, (receipt) => {
  receipt.sessionIdentity = 'shared-session';
});

const duplicateCapability = await cloneRun('one-run', 'duplicate-capability');
await mutateReceipt(duplicateCapability, (receipt) => {
  receipt.capabilities = ['read-workspace', 'read-workspace'];
});

const capabilityMismatch = await cloneRun('one-run', 'capability-mismatch');
await mutateReceipt(capabilityMismatch, (receipt) => {
  receipt.capabilities = ['write-workspace'];
});

const missingOutput = await cloneRun('one-run', 'missing-output');
await mutateReceipt(missingOutput, (receipt) => { delete receipt.output; });

const outputHashMismatch = await cloneRun('one-run', 'output-hash-mismatch');
await mutateReceipt(outputHashMismatch, (receipt) => {
  receipt.output.sha256 = `sha256:${'b'.repeat(64)}`;
});

const oversizedOutput = await cloneRun('one-run', 'oversized-output');
const oversizedOutputBytes = Buffer.alloc(materializationLimit + 1, 'a');
await writeFile(
  path.join(oversizedOutput, 'outputs', 'behavior.objective-check.candidate.1.txt'),
  oversizedOutputBytes,
);
await mutateReceipt(oversizedOutput, (receipt) => {
  receipt.output.sha256 = sha256(oversizedOutputBytes);
  receipt.output.bytes = oversizedOutputBytes.length;
});

const streamedTranscript = await cloneRun('one-run', 'streamed-transcript');
const streamedTranscriptBytes = Buffer.alloc(materializationLimit + 1, 't');
await writeFile(
  path.join(streamedTranscript, 'transcripts', 'behavior.objective-check.candidate.1.txt'),
  streamedTranscriptBytes,
);
await mutateReceipt(streamedTranscript, (receipt) => {
  receipt.transcript.sha256 = sha256(streamedTranscriptBytes);
  receipt.transcript.bytes = streamedTranscriptBytes.length;
});

const outputBytesMismatch = await cloneRun('one-run', 'output-bytes-mismatch');
await mutateReceipt(outputBytesMismatch, (receipt) => { receipt.output.bytes += 1; });

const escapingOutput = await cloneRun('one-run', 'escaping-output');
await mutateReceipt(escapingOutput, (receipt) => { receipt.output.path = '../escape.txt'; });

const transcriptHashMismatch = await cloneRun('one-run', 'transcript-hash-mismatch');
await mutateReceipt(transcriptHashMismatch, (receipt) => {
  receipt.transcript.sha256 = `sha256:${'b'.repeat(64)}`;
});

const transcriptBytesMismatch = await cloneRun('one-run', 'transcript-bytes-mismatch');
await mutateReceipt(transcriptBytesMismatch, (receipt) => { receipt.transcript.bytes += 1; });

const escapingTranscript = await cloneRun('one-run', 'escaping-transcript');
await mutateReceipt(escapingTranscript, (receipt) => {
  receipt.transcript.path = '../escape-transcript.txt';
});

const nonRegularTranscript = await cloneRun('one-run', 'non-regular-transcript');
await mkdir(path.join(nonRegularTranscript, 'transcripts', 'non-regular'));
await mutateReceipt(nonRegularTranscript, (receipt) => {
  receipt.transcript.path = 'transcripts/non-regular';
});

const nonRegularOutput = await cloneRun('one-run', 'non-regular-output');
await mkdir(path.join(nonRegularOutput, 'outputs', 'non-regular'));
await mutateReceipt(nonRegularOutput, (receipt) => {
  receipt.output.path = 'outputs/non-regular';
});

const fifoOutput = await cloneRun('one-run', 'fifo-output');
await mutateReceipt(fifoOutput, (receipt) => {
  receipt.output.path = 'outputs/fifo';
});

const symlinkOutput = await cloneRun('one-run', 'symlink-output');
try {
  await symlink(
    'behavior.objective-check.candidate.1.txt',
    path.join(symlinkOutput, 'outputs', 'symlink.txt'),
  );
  await mutateReceipt(symlinkOutput, (receipt) => {
    receipt.output.path = 'outputs/symlink.txt';
  });
  await writeFile(path.join(root, 'symlink-supported'), 'yes\n');
} catch (error) {
  if (!['EACCES', 'ENOSYS', 'ENOTSUP', 'EPERM'].includes(error?.code)) throw error;
  await rm(symlinkOutput, { recursive: true, force: true });
}

for (const [name, status] of [
  ['grader-failed', 'failed'],
  ['grader-timed-out', 'timed-out'],
]) {
  const runRoot = await cloneRun('one-run', name);
  await mutateGraderReceipt(runRoot, (receipt) => {
    receipt.completionStatus = status;
    receipt.error = { code: `grader-${status}`, message: `Grader ${status}.` };
  });
}

const graderVariantMismatch = await cloneRun('one-run', 'grader-variant-mismatch');
await mutateGraderReceipt(graderVariantMismatch, (receipt) => {
  receipt.variant = 'baseline';
});

for (const [name, packageIdentity] of [
  ['grader-package-noncanonical', 'not-a-hash'],
  ['grader-package-mismatch', `sha256:${'e'.repeat(64)}`],
]) {
  const runRoot = await cloneRun('one-run', name);
  await mutateGraderReceipt(runRoot, (receipt) => {
    receipt.packageHash = packageIdentity;
  });
}

for (const [name, field, value] of [
  ['grader-host-mismatch', 'host', 'other-host'],
  ['grader-runner-mismatch', 'runner', 'other-grader'],
  ['grader-model-mismatch', 'model', 'other-grader-model'],
  ['grader-tier-mismatch', 'tier', 'deep'],
  ['grader-effort-mismatch', 'effort', 'low'],
]) {
  const runRoot = await cloneRun('one-run', name);
  await mutateGraderReceipt(runRoot, (receipt) => { receipt[field] = value; });
}

for (const [name, transform] of [
  ['paired-grader-wrong-host-type', (receipt) => { receipt.host = 7; }],
  ['paired-grader-non-empty-capability', (receipt) => {
    receipt.capabilities = ['read-workspace'];
  }],
  ['paired-grader-unknown-capability', (receipt) => {
    receipt.capabilities = ['network'];
  }],
]) {
  const runRoot = await cloneRun('one-run', name);
  for (const variant of ['candidate', 'baseline']) {
    await mutateGraderReceiptForVariant(runRoot, variant, transform);
  }
}

const graderMissingCompletionIdentity = await cloneRun(
  'one-run',
  'grader-missing-completion-identity',
);
await mutateGraderReceipt(graderMissingCompletionIdentity, (receipt) => {
  receipt.model = null;
  receipt.sessionIdentity = null;
});

const graderOutputHashMismatch = await cloneRun('one-run', 'grader-output-hash-mismatch');
await mutateGraderReceipt(graderOutputHashMismatch, (receipt) => {
  receipt.output.sha256 = `sha256:${'b'.repeat(64)}`;
});
const graderHashReceiptPath = path.join(
  graderOutputHashMismatch,
  'evidence',
  'action.grader.qualitative-check.candidate.1.clarity-grader.json',
);
const graderHashReceiptBytes = await readFile(graderHashReceiptPath);
const graderHashReceipt = JSON.parse(graderHashReceiptBytes);
const graderHashGrade = JSON.parse(await readFile(path.join(
  graderOutputHashMismatch,
  'evidence',
  'grade.qualitative-check.candidate.1.clarity-grader.json',
)));
assert.equal(graderHashReceipt.output.sha256, `sha256:${'b'.repeat(64)}`);
assert.equal(
  graderHashGrade.receipt.sha256,
  sha256(graderHashReceiptBytes),
  'only the outer grade link is refreshed; the tested grader output hash stays tampered',
);

const graderOutputBytesMismatch = await cloneRun('one-run', 'grader-output-bytes-mismatch');
await mutateGraderReceipt(graderOutputBytesMismatch, (receipt) => {
  receipt.output.bytes += 1;
});

const graderEscapingOutput = await cloneRun('one-run', 'grader-escaping-output');
await mutateGraderReceipt(graderEscapingOutput, (receipt) => {
  receipt.output.path = '../grader-escape.txt';
});

const graderNonRegularOutput = await cloneRun('one-run', 'grader-non-regular-output');
await mkdir(path.join(graderNonRegularOutput, 'outputs', 'grader-non-regular'));
await mutateGraderReceipt(graderNonRegularOutput, (receipt) => {
  receipt.output.path = 'outputs/grader-non-regular';
});

const staleGradeReceiptHash = await cloneRun('one-run', 'stale-grade-receipt-hash');
await mutateCandidateGrade(staleGradeReceiptHash, (grade) => {
  grade.receipt.sha256 = `sha256:${'b'.repeat(64)}`;
});
const staleGrade = JSON.parse(await readFile(path.join(
  staleGradeReceiptHash,
  'evidence',
  'grade.qualitative-check.candidate.1.clarity-grader.json',
)));
const linkedReceiptBytes = await readFile(path.join(
  staleGradeReceiptHash,
  staleGrade.receipt.path,
));
assert.notEqual(
  staleGrade.receipt.sha256,
  sha256(linkedReceiptBytes),
  'stale grade receipt hash fixture must not auto-refresh the tested hash',
);

const unsafeGradeReceiptPath = await cloneRun('one-run', 'unsafe-grade-receipt-path');
await mutateCandidateGrade(unsafeGradeReceiptPath, (grade) => {
  grade.receipt.path = '../grader-receipt.json';
});

const nonRegularGradeReceipt = await cloneRun('one-run', 'non-regular-grade-receipt');
await mkdir(path.join(nonRegularGradeReceipt, 'evidence', 'receipt-directory'));
await mutateCandidateGrade(nonRegularGradeReceipt, (grade) => {
  grade.receipt.path = 'evidence/receipt-directory';
});

const twoFaults = await cloneRun('one-run', 'two-faults');
await mutateReceipt(twoFaults, (receipt) => {
  receipt.output.sha256 = `sha256:${'b'.repeat(64)}`;
});
await mutateActionReceipt(
  twoFaults,
  'trigger',
  'negative-trigger',
  'baseline',
  1,
  (receipt) => {
    receipt.completionStatus = 'failed';
    receipt.error = { code: 'worker-failed', message: 'Worker failed.' };
  },
);

const partial = await cloneRun('one-run', 'partial');
await rm(path.join(partial, 'evidence', receiptName('behavior', 'objective-check', 'candidate', 1)));

const smoke = await cloneRun('one-run', 'smoke');
// Candidate-only smoke selects only candidate actions for qualitative behavior cases. Its pairs
// retain both prepared paths for those selected cases, but no baseline action or grade is evidence.
const smokeManifestPath = path.join(smoke, 'manifest.json');
const smokeManifest = JSON.parse(await readFile(smokeManifestPath, 'utf8'));
smokeManifest.expected = smokeManifest.expected.filter((entry) =>
  entry.caseId === 'qualitative-check' && entry.variant === 'candidate');
smokeManifest.pairs =
  smokeManifest.pairs.filter((entry) => entry.caseId === 'qualitative-check');
smokeManifest.gradingPlan =
  smokeManifest.gradingPlan.filter((entry) => entry.caseId === 'qualitative-check');
await writeFile(smokeManifestPath, `${JSON.stringify(smokeManifest, null, 2)}\n`);
const smokeDefinitionPath =
  path.join(smoke, 'definitions', 'behavior.qualitative-check.json');
const smokeDefinition = JSON.parse(await readFile(smokeDefinitionPath, 'utf8'));
smokeDefinition.assertions.push({
  id: 'smoke-objective',
  kind: 'final-contains',
  substring: 'candidate output',
  critical: false,
});
await writeFile(smokeDefinitionPath, `${JSON.stringify(smokeDefinition)}\n`);
for (const item of cases) {
  for (const variant of ['candidate', 'baseline']) {
    if (item.caseId === 'qualitative-check' && variant === 'candidate') continue;
    await rm(path.join(smoke, 'evidence', receiptName(item.kind, item.caseId, variant, 1)));
  }
}
await rm(path.join(smoke, 'evidence', 'grade.qualitative-check.baseline.1.clarity-grader.json'));
await rm(path.join(smoke, 'evidence', 'action.grader.qualitative-check.baseline.1.clarity-grader.json'));
await rm(path.join(smoke, 'evidence', 'input.qualitative-check.baseline.1.clarity-grader.json'));
assert.deepEqual(smokeManifest.expected, [{
  caseId: 'qualitative-check',
  variant: 'candidate',
  repetition: 1,
  kind: 'behavior',
}]);
assert.equal(smokeManifest.pairs.length, 1);
assert.equal(smokeManifest.pairs[0].candidate.endsWith('/candidate'), true);
assert.equal(smokeManifest.pairs[0].baseline.endsWith('/baseline'), true);
assert.equal(smokeManifest.gradingPlan.length, 1);

const unsafeSmokePair = await cloneRun('smoke', 'unsafe-smoke-pair');
const unsafeSmokePairManifestPath = path.join(unsafeSmokePair, 'manifest.json');
const unsafeSmokePairManifest =
  JSON.parse(await readFile(unsafeSmokePairManifestPath, 'utf8'));
unsafeSmokePairManifest.pairs[0].baseline = '../baseline';
await writeFile(
  unsafeSmokePairManifestPath,
  `${JSON.stringify(unsafeSmokePairManifest, null, 2)}\n`,
);

const missingSmokeBaselineWorkspace =
  await cloneRun('smoke', 'missing-smoke-baseline-workspace');
await rm(
  path.join(missingSmokeBaselineWorkspace, 'cases', 'qualitative-check', '1', 'baseline'),
  { recursive: true },
);

for (const [name, caseId] of [
  ['candidate-only-trigger', 'positive-trigger'],
  ['candidate-only-objective', 'objective-check'],
]) {
  const runRoot = await cloneRun('one-run', name);
  const manifestPath = path.join(runRoot, 'manifest.json');
  const manifest = JSON.parse(await readFile(manifestPath, 'utf8'));
  manifest.expected = manifest.expected.filter((entry) =>
    entry.caseId === caseId && entry.variant === 'candidate');
  manifest.pairs = manifest.pairs.filter((entry) => entry.caseId === caseId);
  manifest.gradingPlan = manifest.gradingPlan.filter((entry) => entry.caseId === caseId);
  await writeFile(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
}

const orphanGrade = await cloneRun('one-run', 'orphan-grade');
await rm(path.join(orphanGrade, 'evidence', 'action.grader.qualitative-check.candidate.1.clarity-grader.json'));

const relocatedReceipt = await cloneRun('one-run', 'relocated-receipt');
await cp(
  path.join(relocatedReceipt, 'evidence', receiptName('behavior', 'objective-check', 'candidate', 1)),
  path.join(relocatedReceipt, 'evidence', 'relocated-objective-receipt.json'),
);
await rm(path.join(
  relocatedReceipt,
  'evidence',
  receiptName('behavior', 'objective-check', 'candidate', 1),
));

for (const [name, transform] of [
  ['extra-output-key', (receipt) => { receipt.output.extra = true; }],
  ['extra-transcript-key', (receipt) => { receipt.transcript.extra = true; }],
  ['extra-token-key', (receipt) => {
    receipt.tokenUsage = { input: 1, output: 2, total: 3, cached: 0 };
  }],
]) {
  const runRoot = await cloneRun('one-run', name);
  await mutateReceipt(runRoot, transform);
}

const extraGradeReceiptKey = await cloneRun('one-run', 'extra-grade-receipt-key');
await mutateCandidateGrade(extraGradeReceiptKey, (grade) => { grade.receipt.bytes = 1; });

for (const [name, field, value] of [
  ['invalid-grader-id', 'graderId', 'Not-Kebab'],
  ['invalid-assertion-id', 'assertionId', 'Not-Kebab'],
  ['invalid-anonymized-output-id', 'anonymizedOutputId', 'Not-Kebab'],
]) {
  const runRoot = await cloneRun('one-run', name);
  await mutateCandidateGrade(runRoot, (grade) => { grade[field] = value; });
}

const invalidGradeStatus = await cloneRun('one-run', 'invalid-grade-status');
await mutateCandidateGrade(invalidGradeStatus, (grade) => {
  grade.completionStatus = 'blocked';
});

const completeGradeError = await cloneRun('one-run', 'complete-grade-error');
await mutateCandidateGrade(completeGradeError, (grade) => {
  grade.error = { code: 'unexpected-error', message: 'Unexpected error.' };
});

const failedGradeNullError = await cloneRun('one-run', 'failed-grade-null-error');
await mutateCandidateGrade(failedGradeNullError, (grade) => {
  grade.completionStatus = 'failed';
  grade.pass = null;
  grade.rationale = null;
  grade.error = null;
});

const failedGradeInvalidCode = await cloneRun('one-run', 'failed-grade-invalid-code');
await mutateCandidateGrade(failedGradeInvalidCode, (grade) => {
  grade.completionStatus = 'failed';
  grade.pass = null;
  grade.rationale = null;
  grade.error = { code: 'GraderFailed', message: 'Grader failed.' };
});

const failedGradeNonNullPass = await cloneRun('one-run', 'failed-grade-non-null-pass');
await mutateCandidateGrade(failedGradeNonNullPass, (grade) => {
  grade.completionStatus = 'failed';
  grade.pass = false;
  grade.rationale = null;
  grade.error = { code: 'grader-failed', message: 'Grader failed.' };
});

const failedGradeInvalidReceiptType =
  await cloneRun('one-run', 'failed-grade-invalid-receipt-type');
await mutateCandidateGrade(failedGradeInvalidReceiptType, (grade) => {
  grade.completionStatus = 'failed';
  grade.pass = null;
  grade.rationale = null;
  grade.error = { code: 'grader-failed', message: 'Grader failed.' };
  grade.receipt = 42;
});

const swappedGradeInputs = await cloneRun('one-run', 'swapped-grade-inputs');
await mutateGradeInput(swappedGradeInputs, 'candidate', (input) => {
  input.anonymizedOutputId = 'output-91bc-1';
});
await mutateGradeInput(swappedGradeInputs, 'baseline', (input) => {
  input.anonymizedOutputId = 'output-7f3a-1';
});

const duplicateAnonymizedInput = await cloneRun('one-run', 'duplicate-anonymized-input');
await mutateGradeInput(duplicateAnonymizedInput, 'baseline', (input) => {
  input.anonymizedOutputId = 'output-7f3a-1';
});
const duplicateAnonymizedGradePath = path.join(
  duplicateAnonymizedInput,
  'evidence',
  'grade.qualitative-check.baseline.1.clarity-grader.json',
);
const duplicateAnonymizedGrade =
  JSON.parse(await readFile(duplicateAnonymizedGradePath, 'utf8'));
duplicateAnonymizedGrade.anonymizedOutputId = 'output-7f3a-1';
await writeFile(
  duplicateAnonymizedGradePath,
  `${JSON.stringify(duplicateAnonymizedGrade, null, 2)}\n`,
);

const duplicateInvalidProof =
  await cloneRun('duplicate-anonymized-input', 'duplicate-invalid-proof');
const duplicateInvalidGradePath = path.join(
  duplicateInvalidProof,
  'evidence',
  'grade.qualitative-check.baseline.1.clarity-grader.json',
);
const duplicateInvalidGrade =
  JSON.parse(await readFile(duplicateInvalidGradePath, 'utf8'));
duplicateInvalidGrade.receipt.sha256 = `sha256:${'d'.repeat(64)}`;
await writeFile(
  duplicateInvalidGradePath,
  `${JSON.stringify(duplicateInvalidGrade, null, 2)}\n`,
);

const duplicateOrphanMapping =
  await cloneRun('one-run', 'duplicate-orphan-mapping');
const orphanSourcePath = path.join(
  duplicateOrphanMapping,
  'evidence',
  'input.qualitative-check.candidate.1.clarity-grader.json',
);
const orphanMapping = JSON.parse(await readFile(orphanSourcePath, 'utf8'));
orphanMapping.graderId = 'orphan-grader';
const orphanMappingPath =
  path.join(
    duplicateOrphanMapping,
    'evidence',
    'input.qualitative-check.candidate.1.orphan-grader.json',
  );
await writeFile(
  orphanMappingPath,
  `${JSON.stringify(orphanMapping, null, 2)}\n`,
  { flag: 'wx' },
);

const repeatedAnonymizedInput = await cloneRun('complete', 'repeated-anonymized-input');
const repeatedGradePath = path.join(
  repeatedAnonymizedInput,
  'evidence',
  'grade.qualitative-check.candidate.2.clarity-grader.json',
);
const repeatedGrade = JSON.parse(await readFile(repeatedGradePath, 'utf8'));
const repeatedInputPath =
  path.join(repeatedAnonymizedInput, 'evidence', 'input.qualitative-check.candidate.2.clarity-grader.json');
const repeatedInput = JSON.parse(await readFile(repeatedInputPath, 'utf8'));
repeatedInput.anonymizedOutputId = 'output-7f3a-1';
const repeatedInputBytes = Buffer.from(`${JSON.stringify(repeatedInput, null, 2)}\n`, 'utf8');
await writeFile(repeatedInputPath, repeatedInputBytes);
repeatedGrade.anonymizedOutputId = 'output-7f3a-1';
repeatedGrade.input.sha256 = sha256(repeatedInputBytes);
await writeFile(repeatedGradePath, `${JSON.stringify(repeatedGrade, null, 2)}\n`);

const crossCaseAnonymizedInput = await cloneRun('one-run', 'cross-case-anonymized-input');
await addObjectiveQualitativePair(crossCaseAnonymizedInput);
const crossCaseManifestPath = path.join(crossCaseAnonymizedInput, 'manifest.json');
const crossCaseManifest = JSON.parse(await readFile(crossCaseManifestPath, 'utf8'));
crossCaseManifest.gradingPlan.unshift({
  caseId: 'objective-check',
  repetition: 1,
  assertionId: 'cross-case-grade',
  graderId: 'clarity-grader',
});
await writeFile(crossCaseManifestPath, `${JSON.stringify(crossCaseManifest, null, 2)}\n`);

const wrongSourceGradeInput = await cloneRun('one-run', 'wrong-source-grade-input');
const baselineWorkerReceipt = JSON.parse(await readFile(path.join(
  wrongSourceGradeInput,
  'evidence',
  receiptName('behavior', 'qualitative-check', 'baseline', 1),
), 'utf8'));
await mutateGradeInput(wrongSourceGradeInput, 'candidate', (input) => {
  input.source = baselineWorkerReceipt.output;
});

const differentValidGraderIds = await cloneRun('one-run', 'different-valid-grader-ids');
const oldBaselineInputPath = path.join(
  differentValidGraderIds,
  'evidence',
  'input.qualitative-check.baseline.1.clarity-grader.json',
);
const renamedBaselineInput = JSON.parse(await readFile(oldBaselineInputPath, 'utf8'));
renamedBaselineInput.graderId = 'alternate-grader';
const renamedBaselineInputBytes =
  Buffer.from(`${JSON.stringify(renamedBaselineInput, null, 2)}\n`, 'utf8');
const newBaselineInputRelative =
  'evidence/input.qualitative-check.baseline.1.alternate-grader.json';
await writeFile(
  path.join(differentValidGraderIds, newBaselineInputRelative),
  renamedBaselineInputBytes,
  { flag: 'wx' },
);
await rm(oldBaselineInputPath);
const oldBaselineGradePath = path.join(
  differentValidGraderIds,
  'evidence',
  'grade.qualitative-check.baseline.1.clarity-grader.json',
);
const renamedBaselineGrade = JSON.parse(await readFile(oldBaselineGradePath, 'utf8'));
renamedBaselineGrade.graderId = 'alternate-grader';
renamedBaselineGrade.input = {
  path: newBaselineInputRelative,
  sha256: sha256(renamedBaselineInputBytes),
};
await writeFile(
  path.join(
    differentValidGraderIds,
    'evidence',
    'grade.qualitative-check.baseline.1.alternate-grader.json',
  ),
  `${JSON.stringify(renamedBaselineGrade, null, 2)}\n`,
  { flag: 'wx' },
);
await rm(oldBaselineGradePath);

const mismatchedGradingPlan = await cloneRun('one-run', 'mismatched-grading-plan');
const mismatchedPlanPath = path.join(mismatchedGradingPlan, 'manifest.json');
const mismatchedPlan = JSON.parse(await readFile(mismatchedPlanPath, 'utf8'));
mismatchedPlan.gradingPlan[0].graderId = 'planned-grader';
await writeFile(mismatchedPlanPath, `${JSON.stringify(mismatchedPlan, null, 2)}\n`);

const missingSecondGrade = await cloneRun('one-run', 'missing-second-grade');
const missingSecondDefinitionPath =
  path.join(missingSecondGrade, 'definitions', 'behavior.qualitative-check.json');
const missingSecondDefinition =
  JSON.parse(await readFile(missingSecondDefinitionPath, 'utf8'));
missingSecondDefinition.assertions.push({
  id: 'second-grade',
  kind: 'qualitative',
  rubric: 'Does the handoff include sufficient context?',
  critical: false,
});
await writeFile(
  missingSecondDefinitionPath,
  `${JSON.stringify(missingSecondDefinition, null, 2)}\n`,
);
const missingSecondManifestPath = path.join(missingSecondGrade, 'manifest.json');
const missingSecondManifest = JSON.parse(await readFile(missingSecondManifestPath, 'utf8'));
missingSecondManifest.gradingPlan.push({
  caseId: 'qualitative-check',
  repetition: 1,
  assertionId: 'second-grade',
  graderId: 'context-grader',
});
await writeFile(
  missingSecondManifestPath,
  `${JSON.stringify(missingSecondManifest, null, 2)}\n`,
);

const distinctGraders = await cloneRun('missing-second-grade', 'distinct-graders');
for (const variant of ['candidate', 'baseline']) {
  const sourceReceiptPath = path.join(
    distinctGraders,
    'evidence',
    `action.grader.qualitative-check.${variant}.1.clarity-grader.json`,
  );
  const receiptPath =
    `evidence/action.grader.qualitative-check.${variant}.1.context-grader.json`;
  const receiptBytes = await readFile(sourceReceiptPath);
  await writeFile(path.join(distinctGraders, receiptPath), receiptBytes, { flag: 'wx' });

  const workerReceipt = JSON.parse(await readFile(path.join(
    distinctGraders,
    'evidence',
    receiptName('behavior', 'qualitative-check', variant, 1),
  ), 'utf8'));
  const inputPath =
    `evidence/input.qualitative-check.${variant}.1.context-grader.json`;
  const input = {
    schemaVersion: 1,
    runId,
    caseId: 'qualitative-check',
    repetition: 1,
    graderId: 'context-grader',
    assertionId: 'second-grade',
    anonymizedOutputId: `output-context-${variant}-1`,
    source: workerReceipt.output,
  };
  const inputBytes = Buffer.from(`${JSON.stringify(input, null, 2)}\n`, 'utf8');
  await writeFile(path.join(distinctGraders, inputPath), inputBytes, { flag: 'wx' });
  const grade = {
    schemaVersion: 1,
    runId,
    caseId: 'qualitative-check',
    repetition: 1,
    graderId: 'context-grader',
    assertionId: 'second-grade',
    anonymizedOutputId: input.anonymizedOutputId,
    completionStatus: 'complete',
    pass: true,
    rationale: 'The handoff includes sufficient context.',
    error: null,
    input: { path: inputPath, sha256: sha256(inputBytes) },
    receipt: { path: receiptPath, sha256: sha256(receiptBytes) },
  };
  await writeFile(
    path.join(
      distinctGraders,
      'evidence',
      `grade.qualitative-check.${variant}.1.context-grader.json`,
    ),
    `${JSON.stringify(grade, null, 2)}\n`,
    { flag: 'wx' },
  );
}

const duplicateGraderPlan = await cloneRun('missing-second-grade', 'duplicate-grader-plan');
const duplicateGraderPlanPath = path.join(duplicateGraderPlan, 'manifest.json');
const duplicateGraderManifest =
  JSON.parse(await readFile(duplicateGraderPlanPath, 'utf8'));
duplicateGraderManifest.gradingPlan[1].graderId = 'clarity-grader';
await writeFile(
  duplicateGraderPlanPath,
  `${JSON.stringify(duplicateGraderManifest, null, 2)}\n`,
);

const malformedDistinctGrader =
  await cloneRun('distinct-graders', 'malformed-distinct-grader');
await writeFile(
  path.join(
    malformedDistinctGrader,
    'evidence',
    'grade.qualitative-check.candidate.1.context-grader.json',
  ),
  '{"schemaVersion":1,\n',
);

const oversizedDistinctGrader =
  await cloneRun('distinct-graders', 'oversized-distinct-grader');
await writeFile(
  path.join(
    oversizedDistinctGrader,
    'evidence',
    'grade.qualitative-check.candidate.1.context-grader.json',
  ),
  Buffer.alloc((1024 * 1024) + 1),
);

const pathDirectory = await cloneRun('one-run', 'path-directory');
const pathDirectoryDefinitionPath =
  path.join(pathDirectory, 'definitions', 'behavior.objective-check.json');
const pathDirectoryDefinition =
  JSON.parse(await readFile(pathDirectoryDefinitionPath, 'utf8'));
pathDirectoryDefinition.assertions.push({
  id: 'directory-is-not-regular',
  kind: 'path-exists',
  path: 'package/evals',
  critical: false,
});
await writeFile(
  pathDirectoryDefinitionPath,
  `${JSON.stringify(pathDirectoryDefinition, null, 2)}\n`,
);

const semanticJson = await cloneRun('one-run', 'semantic-json');
const semanticJsonValue = {
  items: [{ enabled: false }, { enabled: true }],
  meta: { status: 'ready' },
  objectTokens: { length: 2, '01': 'leading zero', '-': 'hyphen' },
};
await configureObjectiveAssertions(semanticJson, [{
  id: 'final-json-root',
  kind: 'final-json-path-equals',
  pointer: '',
  expected: semanticJsonValue,
}, {
  id: 'final-json-array',
  kind: 'final-json-path-equals',
  pointer: '/items',
  expected: semanticJsonValue.items,
}, {
  id: 'final-json-object',
  kind: 'final-json-path-equals',
  pointer: '/meta',
  expected: semanticJsonValue.meta,
}, {
  id: 'final-json-boolean',
  kind: 'final-json-path-equals',
  pointer: '/items/1/enabled',
  expected: true,
}, {
  id: 'final-json-array-length',
  kind: 'final-json-path-equals',
  pointer: '/items/length',
  expected: 2,
}, {
  id: 'final-json-array-leading-zero',
  kind: 'final-json-path-equals',
  pointer: '/items/01',
  expected: semanticJsonValue.items[1],
}, {
  id: 'final-json-array-hyphen',
  kind: 'final-json-path-equals',
  pointer: '/items/-',
  expected: null,
}, {
  id: 'final-json-array-out-of-range',
  kind: 'final-json-path-equals',
  pointer: '/items/2',
  expected: null,
}, {
  id: 'final-json-object-length',
  kind: 'final-json-path-equals',
  pointer: '/objectTokens/length',
  expected: 2,
}, {
  id: 'final-json-object-leading-zero',
  kind: 'final-json-path-equals',
  pointer: '/objectTokens/01',
  expected: 'leading zero',
}, {
  id: 'final-json-object-hyphen',
  kind: 'final-json-path-equals',
  pointer: '/objectTokens/-',
  expected: 'hyphen',
}, {
  id: 'final-json-missing',
  kind: 'final-json-path-equals',
  pointer: '/missing',
  expected: null,
}, {
  id: 'final-json-unequal',
  kind: 'final-json-path-equals',
  pointer: '/items/0/enabled',
  expected: true,
}], {
  candidate: `${JSON.stringify(semanticJsonValue, null, 2)}\n`,
  baseline: '{"items":[\n',
});

const invalidUtf8Json = await cloneRun('semantic-json', 'invalid-utf8-json');
const invalidUtf8Bytes = Buffer.concat([
  Buffer.from('{"items":"', 'utf8'),
  Buffer.from([0xc3, 0x28]),
  Buffer.from('"}\n', 'utf8'),
]);
for (const variant of ['candidate', 'baseline']) {
  await writeFile(
    path.join(invalidUtf8Json, 'outputs', `behavior.objective-check.${variant}.1.txt`),
    invalidUtf8Bytes,
  );
  await mutateActionReceipt(
    invalidUtf8Json,
    'behavior',
    'objective-check',
    variant,
    1,
    (receipt) => {
      receipt.output.sha256 = sha256(invalidUtf8Bytes);
      receipt.output.bytes = invalidUtf8Bytes.length;
    },
  );
}

const pathAbsence = await cloneRun('one-run', 'path-absence');
await configureObjectiveAssertions(pathAbsence, [{
  id: 'missing-ancestor-is-absent',
  kind: 'path-absent',
  path: 'uncreated/nested/result.txt',
}, {
  id: 'missing-target-is-absent',
  kind: 'path-absent',
  path: 'existing-directory/result.txt',
}, {
  id: 'file-ancestor-is-unsafe',
  kind: 'path-absent',
  path: 'file-ancestor/result.txt',
}, {
  id: 'fifo-ancestor-is-unsafe',
  kind: 'path-absent',
  path: 'fifo-ancestor/result.txt',
}, {
  id: 'directory-target-is-not-absent',
  kind: 'path-absent',
  path: 'existing-directory',
}]);
for (const variant of ['candidate', 'baseline']) {
  const workspace = path.join(
    pathAbsence,
    'cases',
    'objective-check',
    '1',
    variant,
  );
  await writeFile(path.join(workspace, 'file-ancestor'), 'not a directory\n');
  await mkdir(path.join(workspace, 'existing-directory'));
}

const pathSymlinkAncestor = await cloneRun('one-run', 'path-symlink-ancestor');
try {
  await configureObjectiveAssertions(pathSymlinkAncestor, [{
    id: 'symlink-ancestor-is-unsafe',
    kind: 'path-absent',
    path: 'linked-ancestor/SKILL.md',
  }]);
  for (const variant of ['candidate', 'baseline']) {
    await symlink(
      'package',
      path.join(
        pathSymlinkAncestor,
        'cases',
        'objective-check',
        '1',
        variant,
        'linked-ancestor',
      ),
    );
  }
  await writeFile(path.join(root, 'path-symlink-supported'), 'yes\n');
} catch (error) {
  if (!['EACCES', 'ENOSYS', 'ENOTSUP', 'EPERM'].includes(error?.code)) throw error;
  await rm(pathSymlinkAncestor, { recursive: true, force: true });
}

const corpusMutation = await cloneRun('one-run', 'corpus-mutation');
const mutatedCorpusPath = path.join(
  corpusMutation,
  'cases',
  'objective-check',
  '1',
  'candidate',
  'package',
  'evals',
  'evals.json',
);
const mutatedCorpus = JSON.parse(await readFile(mutatedCorpusPath, 'utf8'));
mutatedCorpus.cases.find((entry) => entry.id === 'objective-check').expected = 'Tampered.';
await writeFile(mutatedCorpusPath, `${JSON.stringify(mutatedCorpus, null, 2)}\n`);

for (const [name, select] of [
  ['mixed-expected', (entry) =>
    entry.variant === 'candidate' || entry.caseId !== 'objective-check'],
  ['baseline-only-expected', (entry) => entry.variant === 'baseline'],
  ['incomplete-expected', (entry) => entry.caseId !== 'objective-check'],
]) {
  const runRoot = await cloneRun('one-run', name);
  const manifestPath = path.join(runRoot, 'manifest.json');
  const manifest = JSON.parse(await readFile(manifestPath, 'utf8'));
  manifest.expected = manifest.expected.filter(select);
  await writeFile(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
}

for (const [name, transform] of [
  ['invalid-run-id-dot', (manifest) => { manifest.runId = '.'; }],
  ['invalid-run-id-dotdot', (manifest) => { manifest.runId = '..'; }],
  ['invalid-run-id-long', (manifest) => { manifest.runId = 'a'.repeat(129); }],
  ['invalid-run-id-type', (manifest) => { manifest.runId = ['valid-run']; }],
  ['invalid-runs-high', (manifest) => { manifest.runs = 11; }],
  ['invalid-case-id-long', (manifest) => {
    manifest.expected[0].caseId = 'a'.repeat(65);
  }],
  ['invalid-baseline-git-ref', (manifest) => {
    manifest.baseline = { kind: 'git-ref', identity: 'not-a-commit' };
  }],
  ['invalid-baseline-uppercase-git-ref', (manifest) => {
    manifest.baseline = {
      kind: 'git-ref',
      identity: 'ABCDEF0123456789ABCDEF0123456789ABCDEF01',
    };
  }],
  ['invalid-baseline-identity-type', (manifest) => {
    manifest.baseline = {
      kind: 'git-ref',
      identity: ['0123456789abcdef0123456789abcdef01234567'],
    };
  }],
  ['invalid-baseline-path', (manifest) => {
    manifest.baseline = { kind: 'path', identity: `sha256:${'A'.repeat(64)}` };
  }],
  ['invalid-baseline-none', (manifest) => {
    manifest.baseline = { kind: 'none', identity: `${'a'.repeat(40)}:missing` };
  }],
  ['invalid-baseline-uppercase-none', (manifest) => {
    manifest.baseline = {
      kind: 'none',
      identity: '0123456789ABCDEF0123456789ABCDEF01234567:absent',
    };
  }],
  ['manifest-model-empty', (manifest) => {
    manifest.runConfiguration.model = '';
  }],
  ['manifest-inactive-empty', (manifest) => {
    manifest.runConfiguration.sessionIdentity = '';
  }],
  ['manifest-inactive-wrong-type', (manifest) => {
    manifest.runConfiguration.sessionIdentity = {};
  }],
  ['manifest-both-completion-identities', (manifest) => {
    manifest.runConfiguration.sessionIdentity = 'other-session';
  }],
  ['path-baseline-hash-mismatch', (manifest) => {
    manifest.baseline = { kind: 'path', identity: `sha256:${'e'.repeat(64)}` };
  }],
  ['behavior-mode-with-trigger', (manifest) => { manifest.mode = 'behavior'; }],
  ['triggers-mode-with-behavior', (manifest) => { manifest.mode = 'triggers'; }],
]) {
  const runRoot = await cloneRun('one-run', name);
  const manifestPath = path.join(runRoot, 'manifest.json');
  const manifest = JSON.parse(await readFile(manifestPath, 'utf8'));
  transform(manifest);
  await writeFile(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
}

const missingRepetition = await cloneRun('complete', 'missing-repetition');
const missingRepetitionManifestPath = path.join(missingRepetition, 'manifest.json');
const missingRepetitionManifest =
  JSON.parse(await readFile(missingRepetitionManifestPath, 'utf8'));
missingRepetitionManifest.expected =
  missingRepetitionManifest.expected.filter((entry) => entry.repetition === 1);
missingRepetitionManifest.pairs =
  missingRepetitionManifest.pairs.filter((pair) => pair.repetition === 1);
await writeFile(
  missingRepetitionManifestPath,
  `${JSON.stringify(missingRepetitionManifest, null, 2)}\n`,
);

const outOfOrderExpected = await cloneRun('one-run', 'out-of-order-expected');
const outOfOrderExpectedManifestPath = path.join(outOfOrderExpected, 'manifest.json');
const outOfOrderExpectedManifest =
  JSON.parse(await readFile(outOfOrderExpectedManifestPath, 'utf8'));
[outOfOrderExpectedManifest.expected[0], outOfOrderExpectedManifest.expected[1]] =
  [outOfOrderExpectedManifest.expected[1], outOfOrderExpectedManifest.expected[0]];
await writeFile(
  outOfOrderExpectedManifestPath,
  `${JSON.stringify(outOfOrderExpectedManifest, null, 2)}\n`,
);

const outOfOrderPairs = await cloneRun('one-run', 'out-of-order-pairs');
const outOfOrderPairsManifestPath = path.join(outOfOrderPairs, 'manifest.json');
const outOfOrderPairsManifest =
  JSON.parse(await readFile(outOfOrderPairsManifestPath, 'utf8'));
[outOfOrderPairsManifest.pairs[0], outOfOrderPairsManifest.pairs[1]] =
  [outOfOrderPairsManifest.pairs[1], outOfOrderPairsManifest.pairs[0]];
await writeFile(
  outOfOrderPairsManifestPath,
  `${JSON.stringify(outOfOrderPairsManifest, null, 2)}\n`,
);

const noBaselinePackage = await cloneRun('one-run', 'no-baseline-package');
const noBaselineManifestPath = path.join(noBaselinePackage, 'manifest.json');
const noBaselineManifest = JSON.parse(await readFile(noBaselineManifestPath, 'utf8'));
noBaselineManifest.baseline = {
  kind: 'none',
  identity: '0123456789abcdef0123456789abcdef01234567:absent',
};
noBaselineManifest.packageHashes.baseline = null;
await writeFile(noBaselineManifestPath, `${JSON.stringify(noBaselineManifest, null, 2)}\n`);
for (const item of cases) {
  await rm(path.join(noBaselinePackage, 'cases', item.caseId, '1', 'baseline', 'package'), {
    recursive: true,
  });
}
const noBaselineEvidenceNames = await readdir(path.join(noBaselinePackage, 'evidence'));
for (const name of noBaselineEvidenceNames.filter((entry) => entry.startsWith('action.'))) {
  const receiptPath = path.join(noBaselinePackage, 'evidence', name);
  const receipt = JSON.parse(await readFile(receiptPath, 'utf8'));
  receipt.baseline = noBaselineManifest.baseline;
  receipt.packageHash =
    receipt.kind === 'grader' || receipt.variant === 'candidate'
      ? noBaselineManifest.packageHashes.candidate
      : null;
  await writeFile(receiptPath, `${JSON.stringify(receipt, null, 2)}\n`);
}
for (const name of noBaselineEvidenceNames.filter((entry) => entry.startsWith('grade.'))) {
  const gradePath = path.join(noBaselinePackage, 'evidence', name);
  const grade = JSON.parse(await readFile(gradePath, 'utf8'));
  const receiptBytes = await readFile(path.join(noBaselinePackage, grade.receipt.path));
  grade.receipt.sha256 = sha256(receiptBytes);
  await writeFile(gradePath, `${JSON.stringify(grade, null, 2)}\n`);
}

// Fixture self-review: every valid base manifest has the documented exact key sets, all expected
// workspaces and receipts exist, output hashes/byte counts match, and grades expose no variant.
for (const runRoot of [complete, oneRun, sessionIdentityRun, tokenUsageRun]) {
  const manifest = JSON.parse(await readFile(path.join(runRoot, 'manifest.json'), 'utf8'));
  assert.deepEqual(Object.keys(manifest).sort(), [
    'baseline', 'expected', 'gradingPlan', 'mode', 'originalPackageHash', 'packageHashes',
    'pairs', 'runConfiguration', 'runId', 'runs', 'schemaVersion', 'targetSkill',
  ]);
  assert.deepEqual(manifest.packageHashes, {
    candidate: manifest.originalPackageHash,
    baseline: manifest.originalPackageHash,
  });
  assert.deepEqual(manifest.gradingPlan, Array.from({ length: manifest.runs }, (_, index) => ({
    caseId: 'qualitative-check',
    repetition: index + 1,
    assertionId: 'clear-handoff',
    graderId: 'clarity-grader',
  })));
  assert.equal(manifest.expected.length, cases.length * manifest.runs * 2);
  assert.equal(manifest.pairs.length, cases.length * manifest.runs);
  const identities = new Set();
  for (const expected of manifest.expected) {
    const identity = `${expected.kind}:${expected.caseId}:${expected.variant}:${expected.repetition}`;
    assert.equal(identities.has(identity), false, `duplicate manifest identity ${identity}`);
    identities.add(identity);
    const workspace = path.join(runRoot, 'cases', expected.caseId, String(expected.repetition), expected.variant);
    assert.equal(path.resolve(workspace).startsWith(`${path.resolve(runRoot)}${path.sep}`), true);
    const receiptPath = path.join(
      runRoot,
      'evidence',
      receiptName(expected.kind, expected.caseId, expected.variant, expected.repetition),
    );
    const receipt = JSON.parse(await readFile(receiptPath, 'utf8'));
    assert.equal(receipt.runId, manifest.runId);
    assert.equal(receipt.caseId, expected.caseId);
    assert.equal(receipt.variant, expected.variant);
    assert.equal(receipt.repetition, expected.repetition);
    assert.equal(receipt.kind, expected.kind);
    assert.equal(receipt.targetSkill, manifest.targetSkill);
    assert.deepEqual(receipt.baseline, manifest.baseline);
    assert.equal(receipt.packageHash, manifest.packageHashes[expected.variant]);
    assert.equal(receipt.model, manifest.runConfiguration.model);
    assert.equal(receipt.sessionIdentity, manifest.runConfiguration.sessionIdentity);
    assert.equal(Number.isInteger(receipt.durationMs) && receipt.durationMs >= 0, true);
    for (const evidence of [receipt.output, receipt.transcript]) {
      if (evidence === 'unavailable') continue;
      const bytes = await readFile(path.join(runRoot, evidence.path));
      assert.equal(bytes.length, evidence.bytes);
      assert.equal(sha256(bytes), evidence.sha256);
    }
  }
  for (let repetition = 1; repetition <= manifest.runs; repetition += 1) {
    const pairedReceipts = [];
    for (const variant of ['candidate', 'baseline']) {
      const graderId = 'clarity-grader';
      const gradePath = path.join(
        runRoot,
        'evidence',
        `grade.qualitative-check.${variant}.${repetition}.${graderId}.json`,
      );
      const grade = JSON.parse(await readFile(gradePath, 'utf8'));
      assert.deepEqual(Object.keys(grade).sort(), [
        'anonymizedOutputId', 'assertionId', 'caseId', 'completionStatus', 'error',
        'graderId', 'input', 'pass', 'rationale', 'receipt', 'repetition', 'runId', 'schemaVersion',
      ]);
      assert.equal(Object.hasOwn(grade, 'variant'), false);
      const receiptBytes = await readFile(path.join(runRoot, grade.receipt.path));
      assert.equal(sha256(receiptBytes), grade.receipt.sha256);
      const graderReceipt = JSON.parse(receiptBytes);
      assert.equal(graderReceipt.kind, 'grader');
      assert.equal(graderReceipt.variant, variant);
      assert.equal(graderReceipt.completionStatus, 'complete');
      assert.equal(
        Boolean(graderReceipt.model) !== Boolean(graderReceipt.sessionIdentity),
        true,
        'grader receipt requires exactly one concrete completion identity',
      );
      pairedReceipts.push(graderReceipt);
    }
    for (const field of ['host', 'runner', 'model', 'sessionIdentity', 'tier', 'effort']) {
      assert.equal(pairedReceipts[0][field], pairedReceipts[1][field],
        `paired grader receipt mismatch at ${field}`);
    }
  }
}
NODE

mkfifo "$TMP_ROOT/path-absence/cases/objective-check/1/candidate/fifo-ancestor"
mkfifo "$TMP_ROOT/path-absence/cases/objective-check/1/baseline/fifo-ancestor"
mkfifo "$TMP_ROOT/fifo-output/outputs/fifo"

"$NODE" --input-type=module - "$SCRIPT_DIR/../aggregate/safe-access.mjs" \
  "$TMP_ROOT/missing-revalidation" <<'NODE'
import assert from 'node:assert/strict';
import { mkdir, rename } from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const [safeAccessPath, root] = process.argv.slice(2);
const { regularFile } = await import(pathToFileURL(safeAccessPath).href);
const parent = path.join(root, 'parent');
await mkdir(parent, { recursive: true });
let hookCalls = 0;
const state = await regularFile(root, 'parent/missing/result.txt', {
  beforeMissingRevalidation: async () => {
    hookCalls += 1;
    await rename(parent, path.join(root, 'replaced-parent'));
    await mkdir(parent);
  },
});
assert.equal(hookCalls, 1);
assert.equal(state.kind, 'replaced');

const leafParent = path.join(root, 'leaf-parent');
await mkdir(leafParent);
let leafHookCalls = 0;
const leafState = await regularFile(root, 'leaf-parent/result.txt', {
  beforeMissingRevalidation: async () => {
    leafHookCalls += 1;
    await rename(leafParent, path.join(root, 'replaced-leaf-parent'));
    await mkdir(leafParent);
  },
});
assert.equal(leafHookCalls, 1);
assert.equal(leafState.kind, 'replaced');
NODE

if [ ! -f "$AGGREGATOR" ]; then
  fail "aggregate.mjs is missing (expected Red: deterministic aggregate fixtures self-validated)"
fi

"$NODE" --input-type=module - "$SCRIPT_DIR/../aggregate/core.mjs" \
  "$SCRIPT_DIR/../../references/schemas.md" <<'NODE'
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const [implementationPath, schemaPath] = process.argv.slice(2);
const implementation = await readFile(implementationPath, 'utf8');
const schemas = await readFile(schemaPath, 'utf8');
const codeBlock = implementation.match(
  /const AGGREGATE_ERROR_CODES = new Set\(\[([\s\S]*?)\]\);/,
);
assert.notEqual(codeBlock, null, 'aggregate must declare its emitted error-code set');
const emitted = new Set(
  [...codeBlock[1].matchAll(/'([a-z0-9]+(?:-[a-z0-9]+)*)'/g)].map((match) => match[1]),
);
const documented = new Set(
  [...schemas.matchAll(/^\| `([a-z0-9]+(?:-[a-z0-9]+)*)` \|/gm)].map((match) => match[1]),
);
assert.deepEqual(
  [...emitted].filter((code) => !documented.has(code)),
  [],
  'every implementation-emitted aggregate error code must be documented',
);
NODE

INVOCATION=0
STATUS=0
STDOUT_FILE=
STDERR_FILE=

run_aggregate() {
  run_name=$1
  shift
  INVOCATION=$((INVOCATION + 1))
  STDOUT_FILE="$TMP_ROOT/stdout.$INVOCATION"
  STDERR_FILE="$TMP_ROOT/stderr.$INVOCATION"
  set +e
  "$NODE" "$AGGREGATOR" \
    --manifest "$TMP_ROOT/$run_name/manifest.json" \
    --evidence "$TMP_ROOT/$run_name/evidence" \
    --out "$TMP_ROOT/$run_name/aggregate.json" \
    "$@" >"$STDOUT_FILE" 2>"$STDERR_FILE"
  STATUS=$?
  set -e
  [ "$STATUS" -eq 0 ] || {
    cat "$STDERR_FILE" >&2
    fail "$run_name: aggregate command exited $STATUS"
  }
  [ ! -s "$STDOUT_FILE" ] || fail "$run_name: aggregate command must not print success prose"
  [ -f "$TMP_ROOT/$run_name/aggregate.json" ] || fail "$run_name: aggregate.json was not written"
}

assert_external_path_rejected() {
  label=$1
  evidence_path=$2
  output_path=$3
  expected_message=$4
  INVOCATION=$((INVOCATION + 1))
  STDOUT_FILE="$TMP_ROOT/stdout.$INVOCATION"
  STDERR_FILE="$TMP_ROOT/stderr.$INVOCATION"
  set +e
  "$NODE" "$AGGREGATOR" \
    --manifest "$TMP_ROOT/complete/manifest.json" \
    --evidence "$evidence_path" \
    --out "$output_path" >"$STDOUT_FILE" 2>"$STDERR_FILE"
  STATUS=$?
  set -e
  [ "$STATUS" -ne 0 ] || fail "$label: aggregate must reject a path outside the run root"
  [ ! -e "$output_path" ] || fail "$label: rejected aggregate must not publish output"
  case "$(cat "$STDERR_FILE")" in
    *"$expected_message"*) ;;
    *) fail "$label: aggregate did not report the containment failure" ;;
  esac
}
run_bounded_aggregate() {
  run_name=$1
  "$NODE" --input-type=module - "$AGGREGATOR" "$TMP_ROOT/$run_name" <<'NODE'
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import path from 'node:path';

const [aggregator, runRoot] = process.argv.slice(2);
const child = spawn(process.execPath, [
  aggregator,
  '--manifest', path.join(runRoot, 'manifest.json'),
  '--evidence', path.join(runRoot, 'evidence'),
  '--out', path.join(runRoot, 'aggregate.json'),
], { stdio: ['ignore', 'pipe', 'pipe'] });
const stdout = [];
const stderr = [];
child.stdout.on('data', (chunk) => stdout.push(chunk));
child.stderr.on('data', (chunk) => stderr.push(chunk));
let timedOut = false;
const timer = setTimeout(() => {
  timedOut = true;
  child.kill('SIGKILL');
}, 5000);
const [code] = await new Promise((resolve) => {
  child.once('exit', (...result) => resolve(result));
});
clearTimeout(timer);
assert.equal(timedOut, false, 'aggregate blocked while opening FIFO evidence');
assert.equal(code, 0, Buffer.concat(stderr).toString('utf8'));
assert.equal(Buffer.concat(stdout).length, 0);
NODE
}


assert_no_clobber() {
  run_name=$1
  aggregate_path="$TMP_ROOT/$run_name/aggregate.json"
  before=$(cksum <"$aggregate_path")
  INVOCATION=$((INVOCATION + 1))
  STDOUT_FILE="$TMP_ROOT/stdout.$INVOCATION"
  STDERR_FILE="$TMP_ROOT/stderr.$INVOCATION"
  set +e
  "$NODE" "$AGGREGATOR" \
    --manifest "$TMP_ROOT/$run_name/manifest.json" \
    --evidence "$TMP_ROOT/$run_name/evidence" \
    --out "$aggregate_path" >"$STDOUT_FILE" 2>"$STDERR_FILE"
  STATUS=$?
  set -e
  [ "$STATUS" -ne 0 ] || fail "$run_name: aggregate output must be create-new"
  [ ! -s "$STDOUT_FILE" ] || fail "$run_name: failed output write must not print success prose"
  [ "$(cksum <"$aggregate_path")" = "$before" ] ||
    fail "$run_name: failed output write changed the existing aggregate"
  [ "$(wc -c <"$STDERR_FILE")" -le 512 ] ||
    fail "$run_name: failed output write diagnostic is not bounded"
  for temp_path in "$TMP_ROOT/$run_name"/.aggregate.json.*.tmp; do
    [ ! -e "$temp_path" ] || fail "$run_name: failed output write left a temp file"
  done
}

assert_snapshot_rejected() {
  run_name=$1
  mutation=$2
  "$NODE" --input-type=module - "$AGGREGATOR" "$TMP_ROOT/$run_name" "$mutation" <<'NODE'
import assert from 'node:assert/strict';
import { open, rename, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const [aggregatorPath, runRoot, mutation] = process.argv.slice(2);
const { aggregate } = await import(pathToFileURL(aggregatorPath).href);
const target = path.join(runRoot, 'definitions', 'snapshot-target.json');
let running = true;
let iteration = 0;
const mutator = (async () => {
  while (running) {
    const bytes = `${iteration % 2 === 0 ? 'b' : 'c'}${'a'.repeat((256 * 1024) - 1)}\n`;
    if (mutation === 'replacement') {
      const temporary = path.join(path.dirname(runRoot), `.snapshot-replacement-${process.pid}`);
      await writeFile(temporary, bytes);
      await rename(temporary, target);
    } else {
      const handle = await open(target, 'r+');
      try {
        await handle.writeFile(bytes);
        await handle.sync();
      } finally {
        await handle.close();
      }
    }
    iteration += 1;
    await new Promise((resolve) => setImmediate(resolve));
  }
})();

let failure;
try {
  await aggregate({
    manifest: path.join(runRoot, 'manifest.json'),
    evidence: path.join(runRoot, 'evidence'),
    out: path.join(runRoot, 'aggregate.json'),
  });
} catch (error) {
  failure = error;
} finally {
  running = false;
  await mutator;
}
assert.equal(failure?.code, 'snapshot-mutation');
assert.equal(failure?.field, '');
assert.equal(
  ['', 'definitions', 'definitions/snapshot-target.json'].includes(failure?.path),
  true,
);
NODE
  [ ! -e "$TMP_ROOT/$run_name/aggregate.json" ] ||
    fail "$run_name: snapshot mutation must prevent publication"
}

assert_snapshot_limit() {
  run_name=$1
  expected_path_prefix=$2
  "$NODE" --input-type=module - "$AGGREGATOR" "$TMP_ROOT/$run_name" "$expected_path_prefix" <<'NODE'
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const [aggregatorPath, runRoot, expectedPathPrefix] = process.argv.slice(2);
const { aggregate } = await import(pathToFileURL(aggregatorPath).href);
let failure;
try {
  await aggregate({
    manifest: path.join(runRoot, 'manifest.json'),
    evidence: path.join(runRoot, 'evidence'),
    out: path.join(runRoot, 'aggregate.json'),
  });
} catch (error) {
  failure = error;
}
assert.equal(failure?.code, 'snapshot-limit-exceeded');
assert.equal(failure?.field, '');
assert.equal(failure?.path.startsWith(expectedPathPrefix), true);
await assert.rejects(
  readFile(path.join(runRoot, 'aggregate.json')),
  (error) => error?.code === 'ENOENT',
);
NODE
}

assert_rejected_manifest() {
  run_name=$1
  expected_diagnostic=${2:-}
  INVOCATION=$((INVOCATION + 1))
  STDOUT_FILE="$TMP_ROOT/stdout.$INVOCATION"
  STDERR_FILE="$TMP_ROOT/stderr.$INVOCATION"
  set +e
  "$NODE" "$AGGREGATOR" \
    --manifest "$TMP_ROOT/$run_name/manifest.json" \
    --evidence "$TMP_ROOT/$run_name/evidence" \
    --out "$TMP_ROOT/$run_name/aggregate.json" >"$STDOUT_FILE" 2>"$STDERR_FILE"
  STATUS=$?
  set -e
  [ "$STATUS" -ne 0 ] || fail "$run_name: invalid manifest must fail"
  [ ! -e "$TMP_ROOT/$run_name/aggregate.json" ] ||
    fail "$run_name: invalid manifest must not write an aggregate"
  [ ! -s "$STDOUT_FILE" ] || fail "$run_name: invalid manifest must not print success prose"
  [ -s "$STDERR_FILE" ] || fail "$run_name: invalid manifest must emit bounded diagnostics"
  [ "$(wc -c <"$STDERR_FILE")" -le 512 ] || fail "$run_name: diagnostics are not bounded"
  if [ -n "$expected_diagnostic" ]; then
    [ "$(cat "$STDERR_FILE")" = "aggregate: $expected_diagnostic" ] ||
      fail "$run_name: unexpected manifest diagnostic"
  fi
}

assert_aggregate() {
  run_name=$1
  assertion=$2
  "$NODE" --input-type=module - "$TMP_ROOT/$run_name/aggregate.json" "$assertion" <<'NODE'
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import path from 'node:path';

const [aggregatePath, assertion] = process.argv.slice(2);
const runRoot = path.dirname(aggregatePath);
const aggregate = JSON.parse(await readFile(aggregatePath, 'utf8'));
assert.deepEqual(Object.keys(aggregate).sort(), [
  'baseline', 'cases', 'evidenceErrors', 'executionStatus', 'overall',
  'runId', 'runs', 'schemaVersion', 'targetSkill',
]);
assert.equal(aggregate.schemaVersion, 1);
assert.equal(aggregate.runId, '20260715T120000Z-4242');
assert.equal(aggregate.targetSkill, 'woostack-example');
const expectedBaseline = assertion === 'no-baseline-package'
  ? {
      kind: 'none',
      identity: '0123456789abcdef0123456789abcdef01234567:absent',
    }
  : {
      kind: 'git-ref',
      identity: '0123456789abcdef0123456789abcdef01234567',
    };
assert.deepEqual(aggregate.baseline, expectedBaseline);
assert.equal(Array.isArray(aggregate.cases), true);
assert.equal(Array.isArray(aggregate.evidenceErrors), true);
const expectedCases = assertion === 'smoke'
  ? ['qualitative-check|behavior']
  : [
      'negative-trigger|trigger',
      'objective-check|behavior',
      'positive-trigger|trigger',
      'qualitative-check|behavior',
    ];
assert.deepEqual(
  aggregate.cases
    .map((entry) => `${entry.caseId}|${entry.kind}`)
    .sort(),
  expectedCases,
  'aggregate cases must have the exact manifest membership and kinds',
);

function caseResult(caseId) {
  const matches = aggregate.cases.filter((entry) => entry.caseId === caseId);
  assert.equal(matches.length, 1, `expected exactly one aggregate case ${caseId}`);
  return matches[0];
}

function repetition(caseId, variant, number = 1) {
  const entry = caseResult(caseId);
  assert.equal(Array.isArray(entry[variant]), true, `${caseId}.${variant} must be an array`);
  const matches = entry[variant].filter((result) => result.repetition === number);
  assert.equal(matches.length, 1, `expected ${caseId}.${variant} repetition ${number}`);
  return matches[0];
}

function assertionResult(caseId, variant, assertionId, number = 1) {
  const result = repetition(caseId, variant, number);
  assert.equal(Array.isArray(result.assertions), true);
  const matches = result.assertions.filter((entry) => entry.assertionId === assertionId);
  assert.equal(matches.length, 1, `expected assertion ${assertionId}`);
  return matches[0];
}

function assertExactErrors(expected) {
  const normalized = aggregate.evidenceErrors.map((error) => {
    assert.deepEqual(Object.keys(error).sort(), ['code', 'field', 'message', 'path']);
    assert.equal(typeof error.message, 'string');
    assert.notEqual(error.message.length, 0);
    return { code: error.code, field: error.field, path: error.path };
  });
  assert.deepEqual(normalized, expected, 'evidenceErrors must contain only the canonical fault');
}

function assertExactRepetitions(count) {
  const expected = Array.from({ length: count }, (_, index) => index + 1);
  for (const entry of aggregate.cases) {
    for (const variant of ['candidate', 'baseline']) {
      assert.deepEqual(
        entry[variant].map((result) => result.repetition).sort((a, b) => a - b),
        expected,
        `${entry.caseId}.${variant} repetition set`,
      );
    }
  }
}

function assertBlockedMetricsAndProof() {
  assert.equal(aggregate.executionStatus, 'blocked');
  for (const metric of [
    'objectivePassRate', 'durationMs', 'tokenUsage', 'triggerPrecision', 'triggerRecall',
  ]) {
    assert.equal(aggregate.overall[metric], 'unavailable', `blocked ${metric}`);
  }
  for (const variant of ['candidate', 'baseline']) {
    const proven = repetition('positive-trigger', variant);
    assert.equal(proven.completionStatus, 'complete');
    assert.equal(
      proven.receipt.path,
      `evidence/action.trigger.positive-trigger.${variant}.1.json`,
    );
  }
}

function assertBlindGrade(variant, number = 1) {
  const result = repetition('qualitative-check', variant, number);
  const leaked = result.assertions?.some((entry) =>
    entry.assertionId === 'clear-handoff' && (entry.pass !== null || entry.rationale !== null));
  assert.notEqual(leaked, true, `invalid paired grader proof must not unblind ${variant} grade`);
}

async function identity(relativePath) {
  const bytes = await readFile(path.join(runRoot, relativePath));
  return {
    path: relativePath,
    sha256: `sha256:${createHash('sha256').update(bytes).digest('hex')}`,
  };
}

async function assertGradeProof(variant, number = 1) {
  const result = assertionResult('qualitative-check', variant, 'clear-handoff', number);
  const gradePath = `evidence/grade.qualitative-check.${variant}.${number}.clarity-grader.json`;
  const receiptPath = `evidence/action.grader.qualitative-check.${variant}.${number}.clarity-grader.json`;
  assert.deepEqual(result.grade, await identity(gradePath));
  assert.deepEqual(result.graderReceipt, await identity(receiptPath));
  return result;
}

if (assertion === 'complete') {
  assert.equal(aggregate.executionStatus, 'complete', 'assertion failures are not execution failure');
  assert.equal(aggregate.runs, 2);
  assert.deepEqual(aggregate.evidenceErrors, []);
  assertExactRepetitions(2);
  assert.deepEqual(aggregate.overall.objectivePassRate, { candidate: 1, baseline: 0.5, delta: 0.5 });
  assert.deepEqual(aggregate.overall.criticalFailures, [{
    caseId: 'objective-check',
    assertionId: 'candidate-gain',
    repetitions: { candidate: [], baseline: [1, 2] },
  }]);
  assert.deepEqual(aggregate.overall.durationMs, {
    candidate: { mean: 150, variance: 2500 },
    baseline: { mean: 400, variance: 10000 },
    delta: -250,
  });
  assert.equal(aggregate.overall.tokenUsage, 'unavailable');
  assert.deepEqual(aggregate.overall.triggerPrecision, {
    candidate: 0.5,
    baseline: 'unavailable',
    delta: 'unavailable',
  });
  assert.deepEqual(aggregate.overall.triggerRecall, { candidate: 1, baseline: 0, delta: 1 });

  for (let number = 1; number <= 2; number += 1) {
    assert.equal(assertionResult('objective-check', 'candidate', 'candidate-gain', number).pass, true);
    assert.equal(assertionResult('objective-check', 'baseline', 'candidate-gain', number).pass, false);
    assert.equal(
      assertionResult('objective-check', 'candidate', 'shared-observation', number).pass,
      true,
    );
    assert.equal(
      assertionResult('objective-check', 'baseline', 'shared-observation', number).pass,
      true,
    );
    for (const variant of ['candidate', 'baseline']) {
      const grade = assertionResult('qualitative-check', variant, 'clear-handoff', number);
      const gradePath =
        `evidence/grade.qualitative-check.${variant}.${number}.clarity-grader.json`;
      const receiptPath = `evidence/action.grader.qualitative-check.${variant}.${number}.clarity-grader.json`;
      assert.deepEqual(grade.grade, await identity(gradePath));
      assert.deepEqual(grade.graderReceipt, await identity(receiptPath));
      assert.equal(Object.hasOwn(grade, 'anonymizedOutputId'), true);
      assert.equal(grade.pass, variant === 'baseline');
      assert.equal(
        grade.rationale,
        variant === 'candidate'
          ? 'The handoff does not identify a next action.'
          : 'The handoff names the required next action.',
      );
    }
  }
  assert.notDeepEqual(
    [
      assertionResult('qualitative-check', 'candidate', 'clear-handoff').pass,
      assertionResult('qualitative-check', 'baseline', 'clear-handoff').pass,
    ],
    [
      assertionResult('objective-check', 'candidate', 'candidate-gain').pass,
      assertionResult('objective-check', 'baseline', 'candidate-gain').pass,
    ],
    'opposite qualitative outcomes must not affect objective rates',
  );
  assert.equal(repetition('positive-trigger', 'candidate').completionStatus, 'complete');
  assert.equal(repetition('negative-trigger', 'baseline').completionStatus, 'complete');
} else if (assertion === 'one-run') {
  assert.equal(aggregate.executionStatus, 'complete');
  assert.equal(aggregate.runs, 1);
  assertExactRepetitions(1);
  assert.deepEqual(aggregate.overall.durationMs, {
    candidate: { mean: 100, variance: 'unavailable' },
    baseline: { mean: 300, variance: 'unavailable' },
    delta: -200,
  });
  for (const entry of aggregate.cases) {
    assert.equal(entry.durationMs.candidate.variance, 'unavailable');
    assert.equal(entry.durationMs.baseline.variance, 'unavailable');
  }
} else if (assertion === 'token-usage') {
  assert.equal(aggregate.executionStatus, 'complete');
  assert.deepEqual(aggregate.evidenceErrors, []);
  assert.deepEqual(aggregate.overall.tokenUsage, {
    candidate: {
      input: { mean: 40, variance: 'unavailable' },
      output: { mean: 20, variance: 'unavailable' },
      total: { mean: 60, variance: 'unavailable' },
    },
    baseline: {
      input: { mean: 32, variance: 'unavailable' },
      output: { mean: 16, variance: 'unavailable' },
      total: { mean: 48, variance: 'unavailable' },
    },
    delta: { input: 8, output: 4, total: 12 },
  });
  for (const entry of aggregate.cases) {
    assert.deepEqual(entry.candidate[0].tokenUsage, { input: 10, output: 5, total: 15 });
    assert.deepEqual(entry.baseline[0].tokenUsage, { input: 8, output: 4, total: 12 });
  }
} else if (assertion === 'objective-assertion-kinds') {
  assert.equal(aggregate.executionStatus, 'complete');
  assert.deepEqual(aggregate.evidenceErrors, []);
  const passing = [
    'final-excludes-pass',
    'receipt-field-pass',
    'path-absent-pass',
    'path-exists-pass',
    'file-contains-pass',
    'file-sha256-pass',
    'file-excludes-pass',
    'json-path-pass',
  ];
  const failing = [
    'final-excludes-fail',
    'receipt-field-fail',
    'path-absent-fail',
    'file-contains-fail',
    'file-contains-missing',
    'file-sha256-fail',
    'file-sha256-missing',
    'file-excludes-fail',
    'file-excludes-missing',
    'json-path-mismatch',
    'json-path-missing',
    'json-path-malformed',
  ];
  for (const variant of ['candidate', 'baseline']) {
    for (const assertionId of passing) {
      assert.equal(
        assertionResult('objective-check', variant, assertionId).pass,
        true,
        `${assertionId} must pass for ${variant}`,
      );
    }
    for (const assertionId of failing) {
      assert.equal(
        assertionResult('objective-check', variant, assertionId).pass,
        false,
        `${assertionId} must fail for ${variant}`,
      );
    }
  }
} else if (assertion === 'partial') {
  assertBlockedMetricsAndProof();
  assertExactErrors([{
    code: 'missing-receipt',
    field: '',
    path: 'evidence/action.behavior.objective-check.candidate.1.json',
  }]);
  assertExactRepetitions(1);
  for (const [caseId, kind] of [
    ['objective-check', 'behavior'],
    ['qualitative-check', 'behavior'],
    ['positive-trigger', 'trigger'],
    ['negative-trigger', 'trigger'],
  ]) {
    for (const variant of ['candidate', 'baseline']) {
      if (caseId === 'objective-check' && variant === 'candidate') continue;
      const result = repetition(caseId, variant);
      assert.equal(result.completionStatus, 'complete');
      const receiptPath = `evidence/action.${kind}.${caseId}.${variant}.1.json`;
      assert.deepEqual(result.receipt, await identity(receiptPath));
    }
  }
  const missing = repetition('objective-check', 'candidate');
  assert.deepEqual(
    Object.keys(missing).sort(),
    ['assertions', 'completionStatus', 'receipt', 'repetition'],
    'missing expected identity must have one explicit blocked/absent result',
  );
  assert.equal(missing.completionStatus, 'blocked');
  assert.equal(missing.receipt, null);
  assert.deepEqual(missing.assertions, []);
  assert.equal(assertionResult('objective-check', 'baseline', 'candidate-gain').pass, false);
  assert.equal(assertionResult('objective-check', 'baseline', 'shared-observation').pass, true);
  assert.equal((await assertGradeProof('candidate')).pass, false);
  assert.equal((await assertGradeProof('baseline')).pass, true);
} else if (assertion.startsWith('grader-invalid|')) {
  const [, code, field, errorPath] = assertion.split('|');
  assertBlockedMetricsAndProof();
  assertExactErrors([{ code, field, path: errorPath }]);
  assertBlindGrade('candidate');
  assertBlindGrade('baseline');
} else if (assertion.startsWith('paired-grader-invalid|')) {
  const [, code, field] = assertion.split('|');
  assertBlockedMetricsAndProof();
  assertExactErrors(['baseline', 'candidate'].map((variant) => ({
    code,
    field,
    path: `evidence/action.grader.qualitative-check.${variant}.1.clarity-grader.json`,
  })));
  assertBlindGrade('candidate');
  assertBlindGrade('baseline');
} else if (assertion.startsWith('qualitative-binding|')) {
  const [, scenario] = assertion.split('|');
  assertBlockedMetricsAndProof();
  const expected = {
    'swapped-grade-inputs': ['baseline', 'candidate'].map((variant) => ({
      code: 'grade-input-mismatch',
      field: '/anonymizedOutputId',
      path: `evidence/input.qualitative-check.${variant}.1.clarity-grader.json`,
    })),
    'duplicate-anonymized-input': [{
      code: 'anonymized-output-collision',
      field: '/anonymizedOutputId',
      path: 'evidence/input.qualitative-check.candidate.1.clarity-grader.json',
    }],
    'repeated-anonymized-input': [{
      code: 'anonymized-output-collision',
      field: '/anonymizedOutputId',
      path: 'evidence/input.qualitative-check.candidate.2.clarity-grader.json',
    }],
    'cross-case-anonymized-input': [{
      code: 'anonymized-output-collision',
      field: '/anonymizedOutputId',
      path: 'evidence/input.qualitative-check.candidate.1.clarity-grader.json',
    }],
    'duplicate-invalid-proof': [{
      code: 'grade-receipt-hash-mismatch',
      field: '/receipt/sha256',
      path: 'evidence/grade.qualitative-check.baseline.1.clarity-grader.json',
    }, {
      code: 'anonymized-output-collision',
      field: '/anonymizedOutputId',
      path: 'evidence/input.qualitative-check.candidate.1.clarity-grader.json',
    }],
    'duplicate-orphan-mapping': [{
      code: 'unknown-receipt',
      field: '',
      path: 'evidence/input.qualitative-check.candidate.1.orphan-grader.json',
    }, {
      code: 'anonymized-output-collision',
      field: '/anonymizedOutputId',
      path: 'evidence/input.qualitative-check.candidate.1.orphan-grader.json',
    }],
    'wrong-source-grade-input': [{
      code: 'grade-input-mismatch',
      field: '/source',
      path: 'evidence/input.qualitative-check.candidate.1.clarity-grader.json',
    }],
    'different-valid-grader-ids': [{
      code: 'identity-mismatch',
      field: '/graderId',
      path: 'evidence/grade.qualitative-check.baseline.1.alternate-grader.json',
    }],
    'mismatched-grading-plan': ['baseline', 'candidate'].map((variant) => ({
      code: 'identity-mismatch',
      field: '/graderId',
      path: `evidence/grade.qualitative-check.${variant}.1.clarity-grader.json`,
    })),
  }[scenario];
  assertExactErrors(expected);
  assertBlindGrade('candidate');
  assertBlindGrade('baseline');
  if (scenario === 'repeated-anonymized-input') {
    assertBlindGrade('candidate', 2);
    assertBlindGrade('baseline', 2);
  }
  if (scenario === 'cross-case-anonymized-input') {
    for (const variant of ['candidate', 'baseline']) {
      const objectiveGrade =
        assertionResult('objective-check', variant, 'cross-case-grade');
      assert.equal(objectiveGrade.pass, null);
      assert.equal(objectiveGrade.rationale, null);
    }
  }
} else if (assertion === 'orphan-grade') {
  assertBlockedMetricsAndProof();
  assertExactErrors([{
    code: 'missing-grade-receipt',
    field: '/receipt/path',
    path: 'evidence/grade.qualitative-check.candidate.1.clarity-grader.json',
  }]);
  assertBlindGrade('candidate');
  assertBlindGrade('baseline');
} else if (assertion === 'distinct-graders') {
  assert.equal(aggregate.executionStatus, 'complete');
  assert.deepEqual(aggregate.evidenceErrors, []);
  for (const variant of ['candidate', 'baseline']) {
    assert.equal(
      assertionResult('qualitative-check', variant, 'second-grade').pass,
      true,
    );
  }
} else if (assertion === 'missing-second-grade') {
  assertBlockedMetricsAndProof();
  assertExactErrors([{
    code: 'missing-receipt',
    field: '',
    path: 'evidence/grade.qualitative-check.baseline.1.context-grader.json',
  }, {
    code: 'missing-receipt',
    field: '',
    path: 'evidence/grade.qualitative-check.candidate.1.context-grader.json',
  }]);
} else if (assertion === 'path-directory') {
  assert.equal(aggregate.executionStatus, 'complete');
  assert.equal(
    assertionResult('objective-check', 'candidate', 'directory-is-not-regular').pass,
    false,
  );
  assert.equal(
    assertionResult('objective-check', 'baseline', 'directory-is-not-regular').pass,
    false,
  );
} else if (assertion === 'semantic-json') {
  assert.equal(aggregate.executionStatus, 'complete');
  assert.deepEqual(aggregate.evidenceErrors, []);
  const expectedCandidate = {
    'final-json-root': true,
    'final-json-array': true,
    'final-json-object': true,
    'final-json-boolean': true,
    'final-json-array-length': false,
    'final-json-array-leading-zero': false,
    'final-json-array-hyphen': false,
    'final-json-array-out-of-range': false,
    'final-json-object-length': true,
    'final-json-object-leading-zero': true,
    'final-json-object-hyphen': true,
    'final-json-missing': false,
    'final-json-unequal': false,
  };
  for (const [assertionId, expectedPass] of Object.entries(expectedCandidate)) {
    const result = assertionResult('objective-check', 'candidate', assertionId);
    assert.equal(result.pass, expectedPass, assertionId);
    assert.deepEqual(result.observed, repetition('objective-check', 'candidate').output);
    assert.equal(
      assertionResult('objective-check', 'baseline', assertionId).pass,
      false,
      `${assertionId} must fail for malformed JSON`,
    );
  }
} else if (assertion === 'invalid-utf8-json') {
  assert.equal(aggregate.executionStatus, 'complete');
  assert.deepEqual(aggregate.evidenceErrors, []);
  for (const variant of ['candidate', 'baseline']) {
    for (const assertionId of [
      'final-json-root',
      'final-json-array',
      'final-json-object',
      'final-json-boolean',
      'final-json-array-length',
      'final-json-array-leading-zero',
      'final-json-array-hyphen',
      'final-json-array-out-of-range',
      'final-json-object-length',
      'final-json-object-leading-zero',
      'final-json-object-hyphen',
      'final-json-missing',
      'final-json-unequal',
    ]) {
      assert.equal(
        assertionResult('objective-check', variant, assertionId).pass,
        false,
        `${assertionId} must fail for invalid UTF-8 ${variant} output`,
      );
    }
  }
} else if (assertion === 'path-absence') {
  assert.equal(aggregate.executionStatus, 'complete');
  assert.deepEqual(aggregate.evidenceErrors, []);
  for (const variant of ['candidate', 'baseline']) {
    for (const assertionId of [
      'missing-ancestor-is-absent',
      'missing-target-is-absent',
    ]) {
      assert.equal(assertionResult('objective-check', variant, assertionId).pass, true);
    }
    const unsafeAssertions = [
      'file-ancestor-is-unsafe',
      'directory-target-is-not-absent',
      ...(process.platform === 'win32' ? [] : ['fifo-ancestor-is-unsafe']),
    ];
    for (const assertionId of unsafeAssertions) {
      assert.equal(assertionResult('objective-check', variant, assertionId).pass, false);
    }
  }
} else if (assertion === 'path-symlink-ancestor') {
  assert.equal(aggregate.executionStatus, 'complete');
  assert.deepEqual(aggregate.evidenceErrors, []);
  for (const variant of ['candidate', 'baseline']) {
    assert.equal(
      assertionResult('objective-check', variant, 'symlink-ancestor-is-unsafe').pass,
      false,
    );
  }
} else if (assertion === 'no-baseline-package') {
  assert.equal(aggregate.executionStatus, 'complete');
  assert.deepEqual(aggregate.evidenceErrors, []);
  assert.equal(assertionResult('objective-check', 'baseline', 'candidate-gain').pass, false);
  assert.equal(assertionResult('objective-check', 'baseline', 'shared-observation').pass, true);
} else if (assertion === 'two-faults') {
  assertBlockedMetricsAndProof();
  assertExactErrors([{
    code: 'output-hash-mismatch',
    field: '/output/sha256',
    path: 'evidence/action.behavior.objective-check.candidate.1.json',
  }, {
    code: 'incomplete-receipt',
    field: '/completionStatus',
    path: 'evidence/action.trigger.negative-trigger.baseline.1.json',
  }]);
} else {
  const [status, code, field, errorPath] = assertion.split('|');
  assert.equal(status, 'blocked');
  assertBlockedMetricsAndProof();
  assertExactErrors([{ code, field, path: errorPath }]);
}
NODE
}

run_aggregate complete
assert_aggregate complete complete
assert_no_clobber complete
assert_external_path_rejected \
  outside-evidence \
  "$TMP_ROOT/one-run/evidence" \
  "$TMP_ROOT/complete/outside-evidence.json" \
  'evidence directory must be contained by the run root'
assert_external_path_rejected \
  outside-output \
  "$TMP_ROOT/complete/evidence" \
  "$TMP_ROOT/outside-output.json" \
  'output must be contained by the run root'
"$NODE" --input-type=module - "$AGGREGATOR" "$TMP_ROOT/publication-rollback" <<'NODE'
import assert from 'node:assert/strict';
import { chmod, mkdir, readFile, readdir, rm, symlink, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const [aggregatorPath, root] = process.argv.slice(2);
const { writeCreateNew } = await import(pathToFileURL(aggregatorPath).href);
await mkdir(root, { mode: 0o700 });
const out = path.join(root, 'aggregate.json');
let syncCalls = 0;
await assert.rejects(
  writeCreateNew(out, { attempt: 1 }, {
    syncDirectory: async (handle) => {
      syncCalls += 1;
      if (syncCalls === 1) throw new Error('injected directory sync failure');
      await handle.sync();
    },
  }),
  /injected directory sync failure/,
);
await assert.rejects(readFile(out), (error) => error?.code === 'ENOENT');
assert.deepEqual(await readdir(root), []);
await writeCreateNew(out, { attempt: 2 });
assert.deepEqual(JSON.parse(await readFile(out, 'utf8')), { attempt: 2 });

if (process.platform !== 'win32') {
  const publicParent = path.join(root, 'public-parent');
  await mkdir(publicParent, { mode: 0o700 });
  await chmod(publicParent, 0o755);
  await assert.rejects(
    writeCreateNew(path.join(publicParent, 'aggregate.json'), { attempt: 'public' }),
    /publication parent must be an owner-private non-symlink directory/,
  );
  assert.deepEqual(await readdir(publicParent), []);

  const symlinkTarget = path.join(root, 'symlink-target');
  const symlinkParent = path.join(root, 'symlink-parent');
  await mkdir(symlinkTarget, { mode: 0o700 });
  await symlink('symlink-target', symlinkParent);
  await assert.rejects(
    writeCreateNew(path.join(symlinkParent, 'aggregate.json'), { attempt: 'symlink' }),
    /publication parent must be an owner-private non-symlink directory/,
  );
  assert.deepEqual(await readdir(symlinkTarget), []);
}

const rollbackFailureRoot = path.join(root, 'rollback-failure');
await mkdir(rollbackFailureRoot, { mode: 0o700 });
let rollbackCloseCalls = 0;
let rollbackFailure;
try {
  await writeCreateNew(
    path.join(rollbackFailureRoot, 'aggregate.json'),
    { attempt: 3 },
    {
      syncDirectory: async () => {
        throw new Error('injected persistent directory sync failure');
      },
      closeOpenedHandle: async (handle) => {
        rollbackCloseCalls += 1;
        await handle.close();
        if (rollbackCloseCalls === 2) {
          throw new Error('injected rollback final-handle close failure');
        }
      },
    },
  );
} catch (error) {
  rollbackFailure = error;
}
assert.equal(rollbackFailure instanceof AggregateError, true);
assert.match(rollbackFailure.message, /publication and rollback failed/);
assert.equal(rollbackFailure.errors.length, 2);
assert.match(rollbackFailure.message, /injected rollback final-handle close failure/);
await assert.rejects(
  readFile(path.join(rollbackFailureRoot, 'aggregate.json')),
  (error) => error?.code === 'ENOENT',
);
assert.deepEqual(await readdir(rollbackFailureRoot), []);

const cleanupFailureRoot = path.join(root, 'cleanup-failure');
await mkdir(cleanupFailureRoot, { mode: 0o700 });
let cleanupFailure;
try {
  await writeCreateNew(
    path.join(cleanupFailureRoot, 'aggregate.json'),
    { attempt: 4 },
    {
      removeTemp: async () => {
        throw new Error('injected temporary-file removal failure');
      },
    },
  );
} catch (error) {
  cleanupFailure = error;
}
assert.equal(cleanupFailure instanceof AggregateError, true);
assert.match(cleanupFailure.message, /publication and temporary-file cleanup failed/);
assert.equal(cleanupFailure.errors.length, 2);
await assert.rejects(
  readFile(path.join(cleanupFailureRoot, 'aggregate.json')),
  (error) => error?.code === 'ENOENT',
);
const cleanupEntries = await readdir(cleanupFailureRoot);
assert.equal(cleanupEntries.length, 1);
assert.match(cleanupEntries[0], /^\.aggregate\.json\..+\.tmp$/);
await rm(cleanupFailureRoot, { recursive: true });

const collisionRoot = path.join(root, 'temporary-collision');
await mkdir(collisionRoot, { mode: 0o700 });
const collisionOut = path.join(collisionRoot, 'aggregate.json');
const collisionTemp = path.join(
  collisionRoot,
  `.aggregate.json.${process.pid}.0000000000000000.tmp`,
);
await writeFile(collisionTemp, 'pre-existing\n', { flag: 'wx', mode: 0o600 });
await assert.rejects(
  writeCreateNew(collisionOut, { attempt: 5 }, {
    randomBytes: () => Buffer.alloc(8),
  }),
  (error) => error?.code === 'EEXIST',
);
assert.equal(await readFile(collisionTemp, 'utf8'), 'pre-existing\n');
assert.deepEqual(await readdir(collisionRoot), [path.basename(collisionTemp)]);

const committedCleanupRoot = path.join(root, 'committed-cleanup-failure');
await mkdir(committedCleanupRoot, { mode: 0o700 });
const committedOut = path.join(committedCleanupRoot, 'aggregate.json');
let committedCloseCalls = 0;
let committedCleanupFailure;
try {
  await writeCreateNew(
    committedOut,
    { attempt: 6 },
    {
      closeOpenedHandle: async (handle) => {
        committedCloseCalls += 1;
        await handle.close();
        if (committedCloseCalls === 2) {
          throw new Error('injected committed directory-handle close failure');
        }
      },
    },
  );
} catch (error) {
  committedCleanupFailure = error;
}
assert.match(
  committedCleanupFailure?.message,
  /publication committed but directory-handle cleanup failed/,
);
assert.deepEqual(JSON.parse(await readFile(committedOut, 'utf8')), { attempt: 6 });
assert.deepEqual(await readdir(committedCleanupRoot), ['aggregate.json']);
await assert.rejects(
  writeCreateNew(committedOut, { attempt: 7 }),
  (error) => error?.code === 'EEXIST',
);
assert.deepEqual(JSON.parse(await readFile(committedOut, 'utf8')), { attempt: 6 });
NODE

run_aggregate one-run
assert_aggregate one-run one-run
run_aggregate session-identity
assert_aggregate session-identity one-run
run_aggregate token-usage
assert_aggregate token-usage token-usage
run_aggregate objective-assertion-kinds
assert_aggregate objective-assertion-kinds objective-assertion-kinds
run_aggregate distinct-original-package-hash
assert_aggregate distinct-original-package-hash one-run
run_aggregate distinct-graders
assert_aggregate distinct-graders distinct-graders
for boundary_run in snapshot-file-boundary snapshot-total-boundary snapshot-entry-boundary; do
  run_aggregate "$boundary_run"
  assert_aggregate "$boundary_run" one-run
done

invalid_case() {
  run_name=$1
  code=$2
  field=$3
  error_path=$4
  run_aggregate "$run_name"
  assert_aggregate "$run_name" "blocked|$code|$field|$error_path"
}

invalid_case duplicate duplicate-receipt '' evidence/duplicate-objective-receipt.json
invalid_case unknown unknown-receipt /caseId evidence/action.behavior.unknown-case.candidate.1.json
invalid_case malformed malformed-receipt '' \
  evidence/action.behavior.objective-check.candidate.1.json
invalid_case timed-out incomplete-receipt /completionStatus \
  evidence/action.behavior.objective-check.candidate.1.json
invalid_case failed incomplete-receipt /completionStatus \
  evidence/action.behavior.objective-check.candidate.1.json
invalid_case invalid-action-status identity-mismatch /completionStatus \
  evidence/action.behavior.objective-check.candidate.1.json
invalid_case complete-action-error identity-mismatch /error \
  evidence/action.behavior.objective-check.candidate.1.json
invalid_case failed-action-null-error identity-mismatch /error \
  evidence/action.behavior.objective-check.candidate.1.json
invalid_case failed-action-extra-error-key identity-mismatch /error \
  evidence/action.behavior.objective-check.candidate.1.json
invalid_case failed-action-invalid-error-code identity-mismatch /error \
  evidence/action.behavior.objective-check.candidate.1.json
invalid_case failed-action-unsanitized-message identity-mismatch /error \
  evidence/action.behavior.objective-check.candidate.1.json
invalid_case model-mismatch configuration-mismatch /model \
  evidence/action.behavior.objective-check.candidate.1.json
invalid_case tier-mismatch configuration-mismatch /tier \
  evidence/action.behavior.objective-check.candidate.1.json
invalid_case effort-mismatch configuration-mismatch /effort \
  evidence/action.behavior.objective-check.candidate.1.json
invalid_case repetition-mismatch identity-mismatch /repetition \
  evidence/action.behavior.objective-check.candidate.1.json
invalid_case identity-mismatch identity-mismatch /runId \
  evidence/action.behavior.objective-check.candidate.1.json
invalid_case package-mismatch package-hash-mismatch /packageHash \
  evidence/action.behavior.objective-check.candidate.1.json
invalid_case refreshed-baseline-mutation package-hash-mismatch /packageHash \
  evidence/action.behavior.objective-check.baseline.1.json
invalid_case corpus-mutation package-hash-mismatch /packageHash \
  evidence/action.behavior.objective-check.candidate.1.json
invalid_case missing-duration missing-field /durationMs \
  evidence/action.behavior.objective-check.candidate.1.json
invalid_case invalid-started-at identity-mismatch /startedAt \
  evidence/action.behavior.objective-check.candidate.1.json
invalid_case unsafe-duration identity-mismatch /durationMs \
  evidence/action.behavior.objective-check.candidate.1.json
invalid_case unsafe-token-usage identity-mismatch /tokenUsage \
  evidence/action.behavior.objective-check.candidate.1.json
invalid_case unsafe-output-bytes output-bytes-mismatch /output/bytes \
  evidence/action.behavior.objective-check.candidate.1.json
invalid_case missing-completion-identity missing-completion-identity /model \
  evidence/action.behavior.objective-check.candidate.1.json
invalid_case ambiguous-completion-identity missing-completion-identity /model \
  evidence/action.behavior.objective-check.candidate.1.json
invalid_case duplicate-capability identity-mismatch /capabilities \
  evidence/action.behavior.objective-check.candidate.1.json
invalid_case capability-mismatch configuration-mismatch /capabilities \
  evidence/action.behavior.objective-check.candidate.1.json
invalid_case missing-output missing-field /output \
  evidence/action.behavior.objective-check.candidate.1.json
invalid_case output-hash-mismatch output-hash-mismatch /output/sha256 \
  evidence/action.behavior.objective-check.candidate.1.json
invalid_case output-bytes-mismatch output-bytes-mismatch /output/bytes \
  evidence/action.behavior.objective-check.candidate.1.json
invalid_case escaping-output unsafe-evidence-path /output/path \
  evidence/action.behavior.objective-check.candidate.1.json
invalid_case transcript-hash-mismatch transcript-hash-mismatch /transcript/sha256 \
  evidence/action.behavior.objective-check.candidate.1.json
invalid_case transcript-bytes-mismatch transcript-bytes-mismatch /transcript/bytes \
  evidence/action.behavior.objective-check.candidate.1.json
invalid_case escaping-transcript unsafe-evidence-path /transcript/path \
  evidence/action.behavior.objective-check.candidate.1.json
invalid_case non-regular-transcript non-regular-evidence /transcript/path \
  evidence/action.behavior.objective-check.candidate.1.json
invalid_case oversized-output evidence-too-large /output/path \
  evidence/action.behavior.objective-check.candidate.1.json
invalid_case non-regular-output non-regular-evidence /output/path \
  evidence/action.behavior.objective-check.candidate.1.json
run_bounded_aggregate fifo-output
assert_aggregate fifo-output \
  'blocked|non-regular-evidence|/output/path|evidence/action.behavior.objective-check.candidate.1.json'
if [ -f "$TMP_ROOT/symlink-supported" ]; then
  invalid_case symlink-output non-regular-evidence /output/path \
    evidence/action.behavior.objective-check.candidate.1.json
fi
invalid_case relocated-receipt unknown-receipt '' \
  evidence/relocated-objective-receipt.json
invalid_case extra-output-key malformed-receipt '' \
  evidence/action.behavior.objective-check.candidate.1.json
invalid_case extra-transcript-key malformed-receipt '' \
  evidence/action.behavior.objective-check.candidate.1.json
invalid_case extra-token-key malformed-receipt '' \
  evidence/action.behavior.objective-check.candidate.1.json

grader_invalid_case() {
  run_name=$1
  code=$2
  field=$3
  error_path=$4
  run_aggregate "$run_name"
  assert_aggregate "$run_name" "grader-invalid|$code|$field|$error_path"
}

paired_grader_invalid_case() {
  run_name=$1
  code=$2
  field=$3
  run_aggregate "$run_name"
  assert_aggregate "$run_name" "paired-grader-invalid|$code|$field"
}

qualitative_binding_invalid_case() {
  run_name=$1
  run_aggregate "$run_name"
  assert_aggregate "$run_name" "qualitative-binding|$run_name"
}

grader_invalid_case grader-failed incomplete-receipt /completionStatus \
  evidence/action.grader.qualitative-check.candidate.1.clarity-grader.json
grader_invalid_case grader-timed-out incomplete-receipt /completionStatus \
  evidence/action.grader.qualitative-check.candidate.1.clarity-grader.json
grader_invalid_case grader-variant-mismatch identity-mismatch /variant \
  evidence/action.grader.qualitative-check.candidate.1.clarity-grader.json
grader_invalid_case grader-package-noncanonical package-hash-mismatch /packageHash \
  evidence/action.grader.qualitative-check.candidate.1.clarity-grader.json
grader_invalid_case grader-package-mismatch package-hash-mismatch /packageHash \
  evidence/action.grader.qualitative-check.candidate.1.clarity-grader.json
grader_invalid_case grader-host-mismatch grader-configuration-mismatch /host \
  evidence/action.grader.qualitative-check.candidate.1.clarity-grader.json
grader_invalid_case grader-runner-mismatch grader-configuration-mismatch /runner \
  evidence/action.grader.qualitative-check.candidate.1.clarity-grader.json
grader_invalid_case grader-model-mismatch grader-configuration-mismatch /model \
  evidence/action.grader.qualitative-check.candidate.1.clarity-grader.json
grader_invalid_case grader-tier-mismatch grader-configuration-mismatch /tier \
  evidence/action.grader.qualitative-check.candidate.1.clarity-grader.json
grader_invalid_case grader-effort-mismatch grader-configuration-mismatch /effort \
  evidence/action.grader.qualitative-check.candidate.1.clarity-grader.json
grader_invalid_case grader-missing-completion-identity missing-completion-identity /model \
  evidence/action.grader.qualitative-check.candidate.1.clarity-grader.json
paired_grader_invalid_case paired-grader-wrong-host-type identity-mismatch /host
paired_grader_invalid_case paired-grader-unknown-capability identity-mismatch /capabilities
paired_grader_invalid_case paired-grader-non-empty-capability \
  grader-configuration-mismatch /capabilities
grader_invalid_case grader-output-hash-mismatch output-hash-mismatch /output/sha256 \
  evidence/action.grader.qualitative-check.candidate.1.clarity-grader.json
grader_invalid_case grader-output-bytes-mismatch output-bytes-mismatch /output/bytes \
  evidence/action.grader.qualitative-check.candidate.1.clarity-grader.json
grader_invalid_case grader-escaping-output unsafe-evidence-path /output/path \
  evidence/action.grader.qualitative-check.candidate.1.clarity-grader.json
grader_invalid_case grader-non-regular-output non-regular-evidence /output/path \
  evidence/action.grader.qualitative-check.candidate.1.clarity-grader.json
grader_invalid_case stale-grade-receipt-hash grade-receipt-hash-mismatch /receipt/sha256 \
  evidence/grade.qualitative-check.candidate.1.clarity-grader.json
grader_invalid_case unsafe-grade-receipt-path unsafe-evidence-path /receipt/path \
  evidence/grade.qualitative-check.candidate.1.clarity-grader.json
grader_invalid_case non-regular-grade-receipt non-regular-evidence /receipt/path \
  evidence/grade.qualitative-check.candidate.1.clarity-grader.json
grader_invalid_case extra-grade-receipt-key malformed-receipt '' \
  evidence/grade.qualitative-check.candidate.1.clarity-grader.json
grader_invalid_case invalid-grader-id identity-mismatch /graderId \
  evidence/grade.qualitative-check.candidate.1.clarity-grader.json
grader_invalid_case invalid-assertion-id identity-mismatch /assertionId \
  evidence/grade.qualitative-check.candidate.1.clarity-grader.json
grader_invalid_case invalid-anonymized-output-id identity-mismatch /anonymizedOutputId \
  evidence/grade.qualitative-check.candidate.1.clarity-grader.json
grader_invalid_case invalid-grade-status malformed-receipt /completionStatus \
  evidence/grade.qualitative-check.candidate.1.clarity-grader.json
grader_invalid_case complete-grade-error malformed-receipt /error \
  evidence/grade.qualitative-check.candidate.1.clarity-grader.json
grader_invalid_case failed-grade-null-error malformed-receipt /error \
  evidence/grade.qualitative-check.candidate.1.clarity-grader.json
grader_invalid_case failed-grade-invalid-code malformed-receipt /error \
  evidence/grade.qualitative-check.candidate.1.clarity-grader.json
grader_invalid_case failed-grade-non-null-pass malformed-receipt /pass \
  evidence/grade.qualitative-check.candidate.1.clarity-grader.json
grader_invalid_case failed-grade-invalid-receipt-type missing-grade-receipt /receipt/path \
  evidence/grade.qualitative-check.candidate.1.clarity-grader.json
qualitative_binding_invalid_case swapped-grade-inputs
qualitative_binding_invalid_case duplicate-anonymized-input
qualitative_binding_invalid_case duplicate-invalid-proof
qualitative_binding_invalid_case duplicate-orphan-mapping
qualitative_binding_invalid_case repeated-anonymized-input
qualitative_binding_invalid_case cross-case-anonymized-input
qualitative_binding_invalid_case wrong-source-grade-input
qualitative_binding_invalid_case different-valid-grader-ids
qualitative_binding_invalid_case mismatched-grading-plan

invalid_case malformed-distinct-grader malformed-receipt '' \
  evidence/grade.qualitative-check.candidate.1.context-grader.json
invalid_case oversized-distinct-grader evidence-too-large '' \
  evidence/grade.qualitative-check.candidate.1.context-grader.json

run_aggregate two-faults
assert_aggregate two-faults two-faults

run_aggregate partial
assert_aggregate partial partial

# Comparative evaluation requires both variants for every expected case/repetition.
run_aggregate streamed-transcript
assert_aggregate streamed-transcript one-run
assert_rejected_manifest smoke \
  'manifest expected pairs must include both candidate and baseline evidence'


run_aggregate orphan-grade
assert_aggregate orphan-grade orphan-grade

run_aggregate missing-second-grade
assert_aggregate missing-second-grade missing-second-grade

run_aggregate path-directory
assert_aggregate path-directory path-directory

run_aggregate semantic-json
assert_aggregate semantic-json semantic-json
run_aggregate invalid-utf8-json
assert_aggregate invalid-utf8-json invalid-utf8-json

run_aggregate path-absence
assert_aggregate path-absence path-absence

if [ -f "$TMP_ROOT/path-symlink-supported" ]; then
  run_aggregate path-symlink-ancestor
  assert_aggregate path-symlink-ancestor path-symlink-ancestor
fi

run_aggregate no-baseline-package
assert_aggregate no-baseline-package no-baseline-package

assert_rejected_manifest mixed-expected
assert_rejected_manifest baseline-only-expected
assert_rejected_manifest incomplete-expected
assert_rejected_manifest invalid-run-id-dot 'manifest identity is invalid'
assert_rejected_manifest invalid-run-id-dotdot 'manifest identity is invalid'
assert_rejected_manifest invalid-run-id-long 'manifest identity is invalid'
assert_rejected_manifest invalid-run-id-type 'manifest identity is invalid'
assert_rejected_manifest invalid-runs-high 'manifest run selection is invalid'
assert_rejected_manifest invalid-case-id-long \
  'manifest contains an invalid expected identity'
assert_rejected_manifest invalid-baseline-git-ref 'manifest baseline is invalid'
assert_rejected_manifest invalid-baseline-uppercase-git-ref 'manifest baseline is invalid'
assert_rejected_manifest invalid-baseline-identity-type 'manifest baseline is invalid'
assert_rejected_manifest invalid-baseline-path 'manifest baseline is invalid'
assert_rejected_manifest invalid-baseline-none 'manifest baseline is invalid'
assert_rejected_manifest invalid-baseline-uppercase-none 'manifest baseline is invalid'
assert_rejected_manifest manifest-model-empty 'manifest run configuration is invalid'
assert_rejected_manifest manifest-inactive-empty 'manifest run configuration is invalid'
assert_rejected_manifest manifest-inactive-wrong-type 'manifest run configuration is invalid'
assert_rejected_manifest manifest-both-completion-identities \
  'manifest run configuration is invalid'
assert_rejected_manifest duplicate-grader-plan \
  'manifest grading plan contains duplicate grader identities'
assert_rejected_manifest path-baseline-hash-mismatch 'manifest package hashes are invalid'
assert_rejected_manifest behavior-mode-with-trigger \
  'manifest contains an invalid expected identity'
assert_rejected_manifest triggers-mode-with-behavior \
  'manifest contains an invalid expected identity'
assert_rejected_manifest candidate-only-trigger \
  'manifest expected pairs must include both candidate and baseline evidence'
assert_rejected_manifest candidate-only-objective \
  'manifest expected pairs must include both candidate and baseline evidence'
assert_rejected_manifest unsafe-smoke-pair \
  'manifest expected pairs must include both candidate and baseline evidence'
assert_rejected_manifest missing-smoke-baseline-workspace \
  'manifest expected pairs must include both candidate and baseline evidence'
assert_rejected_manifest missing-quiescence 'host quiescence proof is missing or unsafe'
assert_rejected_manifest invalid-quiescence 'host quiescence proof is invalid'
if [ "$("$NODE" -p 'process.platform')" != win32 ]; then
  assert_rejected_manifest public-run-root 'run root must be a private mode-0700 non-symlink directory'
fi
assert_rejected_manifest missing-repetition \
  'manifest expected set is incomplete for configured runs'
assert_rejected_manifest out-of-order-expected \
  'manifest expected identities are not in canonical order'
assert_rejected_manifest out-of-order-pairs \
  'manifest workspace pairs are not in canonical order'

assert_snapshot_rejected snapshot-rewrite rewrite
if [ "$("$NODE" -p 'process.platform')" != win32 ]; then
  assert_snapshot_rejected snapshot-replacement replacement
fi
assert_snapshot_limit snapshot-file-limit snapshot-file-limit.bin
assert_snapshot_limit snapshot-total-limit snapshot-total/
assert_snapshot_limit snapshot-entry-limit snapshot-entry-limit

"$NODE" --input-type=module - "$AGGREGATOR" "$TMP_ROOT/snapshot-directory-swap" <<'NODE'
import assert from 'node:assert/strict';
import { rename, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const [aggregatorPath, runRoot] = process.argv.slice(2);
const safeAccessPath =
  path.join(path.dirname(aggregatorPath), 'aggregate', 'safe-access.mjs');
const { buildRunSnapshot } = await import(pathToFileURL(safeAccessPath).href);
let swapped = false;
let failure;
try {
  await buildRunSnapshot(runRoot, {
    beforeOpenEntry: async ({ absoluteEntry, relativeEntry }) => {
      if (swapped || relativeEntry !== 'snapshot-swap-target') return;
      swapped = true;
      await rename(absoluteEntry, `${absoluteEntry}.original`);
      await writeFile(absoluteEntry, Buffer.alloc((16 * 1024 * 1024) + 1));
    },
  });
} catch (error) {
  failure = error;
}
assert.equal(swapped, true);
assert.equal(failure?.code, 'snapshot-mutation');
assert.equal(failure?.path, 'snapshot-swap-target');
NODE

"$NODE" --input-type=module - "$AGGREGATOR" "$TMP_ROOT/snapshot-read-binding" <<'NODE'
import assert from 'node:assert/strict';
import { rename, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const [aggregatorPath, runRoot] = process.argv.slice(2);
const safeAccessPath =
  path.join(path.dirname(aggregatorPath), 'aggregate', 'safe-access.mjs');
const {
  buildRunSnapshot,
  indexRunSnapshot,
  regularFile,
} = await import(pathToFileURL(safeAccessPath).href);
const relativeTarget = 'evidence/action.behavior.objective-check.candidate.1.json';
const target = path.join(runRoot, ...relativeTarget.split('/'));
const snapshot = indexRunSnapshot(await buildRunSnapshot(runRoot));
await rename(target, `${target}.original`);
await writeFile(target, '{"schemaVersion":1,"runId":"substituted"}\n');
await assert.rejects(
  regularFile(runRoot, relativeTarget, { snapshot }),
  (error) =>
    error?.code === 'snapshot-mutation'
    && error?.path === relativeTarget,
);
NODE

"$NODE" --input-type=module - "$AGGREGATOR" "$TMP_ROOT/snapshot-file-limit" <<'NODE'
import assert from 'node:assert/strict';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const [aggregatorPath, runRoot] = process.argv.slice(2);
const safeAccessPath =
  path.join(path.dirname(aggregatorPath), 'aggregate', 'safe-access.mjs');
const { buildRunSnapshot } = await import(pathToFileURL(safeAccessPath).href);
let failure;
try {
  await buildRunSnapshot(runRoot, {
    closeOpenedHandle: async (handle, evidencePath) => {
      await handle.close();
      if (evidencePath === 'snapshot-file-limit.bin') {
        throw new Error('injected snapshot file-handle close failure');
      }
    },
  });
} catch (error) {
  failure = error;
}
assert.equal(failure?.code, 'snapshot-limit-exceeded');
assert.match(failure.message, /injected snapshot file-handle close failure/);
assert.equal(failure.cleanupErrors?.length, 1);
NODE

printf 'PASS: aggregate receipt, grading, assertion, and metric contract\n'
