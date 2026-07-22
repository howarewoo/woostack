import { isUtf8 } from 'node:buffer';
import { createHash } from 'node:crypto';
import path from 'node:path';

import { hashPackage } from '../../../../skills/using-woostack/scripts/validate-skill-package.mjs';
import {
  comparative,
  durationMetric,
  metric,
  tokenComparison,
  tokenMetric,
  triggerMetric,
} from './metrics.mjs';
import { sanitizeMessage } from './contracts.mjs';
import {
  KEBAB,
  SHA256,
  VARIANTS,
  WORKER_KINDS,
  caseIdValid,
  compareText,
  exactKeys,
  isObject,
  nonEmptyString,
  optionalString,
  requireManifest,
  same,
} from './schema.mjs';
import {
  capabilitiesValid,
  completionIdentityValid,
  completionPayloadError,
  gradeFilename,
  inputFilename,
  pointerValue,
  qualitativePayloadError,
} from './grading.mjs';
import {
  buildRunSnapshot,
  indexRunSnapshot,
  contained,
  listDirectoryNames,
  parseFile,
  regularFile,
  relativeTo,
  requireDirectoryChain,
  requireManifestWorkspaces,
  requirePrivateRunRoot,
  requireQuiescenceProof,
  revalidateRunSnapshot,
  writeCreateNew,
} from './safe-access.mjs';

const RECEIPT_FIELDS = [
  'schemaVersion', 'runId', 'caseId', 'repetition', 'variant', 'kind', 'targetSkill',
  'baseline', 'packageHash', 'capabilities', 'host', 'runner', 'model',
  'sessionIdentity', 'tier', 'effort', 'startedAt', 'durationMs', 'output',
  'transcript', 'tokenUsage', 'selectedSkill', 'completionStatus', 'error',
];
const GRADE_FIELDS = [
  'schemaVersion', 'runId', 'caseId', 'repetition', 'graderId', 'assertionId',
  'anonymizedOutputId', 'completionStatus', 'pass', 'rationale', 'error', 'input', 'receipt',
];
const INPUT_FIELDS = [
  'schemaVersion', 'runId', 'caseId', 'repetition', 'graderId', 'assertionId',
  'anonymizedOutputId', 'source',
];
const AGGREGATE_ERROR_CODES = new Set([
  'anonymized-output-collision',
  'configuration-mismatch',
  'duplicate-receipt',
  'evidence-too-large',
  'grade-input-hash-mismatch',
  'grade-input-mismatch',
  'grade-receipt-hash-mismatch',
  'grader-configuration-mismatch',
  'grader-identity-mismatch',
  'identity-mismatch',
  'incomplete-receipt',
  'malformed-receipt',
  'missing-completion-identity',
  'missing-field',
  'missing-grade-input',
  'missing-grade-receipt',
  'missing-receipt',
  'non-regular-evidence',
  'output-bytes-mismatch',
  'output-hash-mismatch',
  'package-hash-mismatch',
  'snapshot-limit-exceeded',
  'snapshot-mutation',
  'transcript-bytes-mismatch',
  'transcript-hash-mismatch',
  'unknown-receipt',
  'unsafe-evidence-path',
]);
const RFC3339_UTC = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?Z$/;
const MAX_MATERIALIZED_BYTES = 1024 * 1024;
const UNAVAILABLE = 'unavailable';

function parseArguments(argv) {
  const options = {};
  for (let index = 0; index < argv.length; index += 1) {
    const flag = argv[index];
    if (!['--manifest', '--evidence', '--out'].includes(flag) || options[flag]) {
      throw new Error('usage: node aggregate.mjs --manifest <manifest.json> --evidence <dir> --out <aggregate.json>');
    }
    const value = argv[index + 1];
    if (!value || value.startsWith('--')) {
      throw new Error(`missing value for ${flag}`);
    }
    options[flag] = value;
    index += 1;
  }
  for (const flag of ['--manifest', '--evidence', '--out']) {
    if (!options[flag]) throw new Error(`missing required option ${flag}`);
  }
  return { manifest: options['--manifest'], evidence: options['--evidence'], out: options['--out'] };
}


function validRfc3339Utc(value) {
  if (typeof value !== 'string') return false;
  const match = RFC3339_UTC.exec(value);
  if (!match) return false;
  const timestamp = Date.parse(value);
  if (!Number.isFinite(timestamp)) return false;
  const date = new Date(timestamp);
  const components = match.slice(1, 7).map(Number);
  return date.getUTCFullYear() === components[0]
    && date.getUTCMonth() + 1 === components[1]
    && date.getUTCDate() === components[2]
    && date.getUTCHours() === components[3]
    && date.getUTCMinutes() === components[4]
    && date.getUTCSeconds() === components[5];
}


function sha256(bytes) {
  return `sha256:${createHash('sha256').update(bytes).digest('hex')}`;
}



function errorRecord(code, field, evidencePath, message) {
  if (!AGGREGATE_ERROR_CODES.has(code)) throw new Error(`undocumented aggregate error code: ${code}`);
  return { code, field, path: evidencePath, message: sanitizeMessage(message) };
}


function sortErrors(errors) {
  return errors.sort((left, right) =>
    compareText(left.path, right.path)
    || compareText(left.field, right.field)
    || compareText(left.code, right.code));
}

function expectedKey(value) {
  return `${value.kind}\u0000${value.caseId}\u0000${value.variant}\u0000${value.repetition}`;
}

function expectedReceiptName(value) {
  return `action.${value.kind}.${value.caseId}.${value.variant}.${value.repetition}.json`;
}

function gradingPlanKey(value) {
  return `${value.caseId}\u0000${value.repetition}\u0000${value.assertionId}`;
}

async function requireResolvedGradingPlan(runRoot, manifest, snapshot) {
  const expectedKinds = new Map(manifest.expected.map((item) => [item.caseId, item.kind]));
  const canonicalEntries = [];
  for (const pair of manifest.pairs) {
    const kind = expectedKinds.get(pair.caseId);
    const parsed = await parseFile(runRoot, `definitions/${kind}.${pair.caseId}.json`, snapshot);
    if (parsed.state.kind !== 'file' || parsed.malformed || parsed.value.id !== pair.caseId) {
      throw new Error(`frozen ${kind} definition is missing or invalid`);
    }
    const qualitativeAssertions = Array.isArray(parsed.value.assertions)
      ? parsed.value.assertions.filter((assertion) => assertion.kind === 'qualitative')
      : [];
    for (const assertion of qualitativeAssertions) {
      canonicalEntries.push({
        caseId: pair.caseId,
        repetition: pair.repetition,
        assertionId: assertion.id,
      });
    }
  }
  const canonicalKeys = canonicalEntries
    .sort((left, right) =>
      compareText(left.caseId, right.caseId)
      || left.repetition - right.repetition
      || compareText(left.assertionId, right.assertionId))
    .map(gradingPlanKey);

  const plan = new Map();
  const orderedKeys = [];
  const graderSlots = new Set();
  for (const entry of manifest.gradingPlan) {
    if (!exactKeys(entry, ['caseId', 'repetition', 'assertionId', 'graderId'])
      || !caseIdValid(entry.caseId)
      || !Number.isSafeInteger(entry.repetition)
      || entry.repetition < 1
      || entry.repetition > manifest.runs
      || !KEBAB.test(entry.assertionId ?? '')
      || !KEBAB.test(entry.graderId ?? '')) {
      throw new Error('manifest grading plan is unresolved or invalid');
    }
    const key = gradingPlanKey(entry);
    if (plan.has(key)) throw new Error('manifest grading plan contains duplicate identities');
    const graderSlot = `${entry.caseId}\u0000${entry.repetition}\u0000${entry.graderId}`;
    if (graderSlots.has(graderSlot)) {
      throw new Error('manifest grading plan contains duplicate grader identities');
    }
    graderSlots.add(graderSlot);
    plan.set(key, entry);
    orderedKeys.push(key);
  }
  if (!same(orderedKeys, canonicalKeys)) {
    throw new Error('manifest grading plan does not match frozen qualitative assertions');
  }
  return plan;
}


async function validateIdentityFile(runRoot, identity, field, receiptPath, label, snapshot) {
  if (!isObject(identity)) {
    return { error: errorRecord('missing-field', field.slice(0, field.lastIndexOf('/')) || field, receiptPath, `${label} identity is required`) };
  }
  if (typeof identity.path !== 'string') {
    return { error: errorRecord('missing-field', `${field}/path`, receiptPath, `${label} path is required`) };
  }
  if (!same(Object.keys(identity).sort(), ['bytes', 'path', 'sha256'])) {
    return { error: errorRecord('malformed-receipt', '', receiptPath, `${label} identity key set is not canonical`) };
  }
  const materialize = label !== 'Transcript';
  const state = await regularFile(runRoot, identity.path, { materialize, snapshot });
  if (state.kind === 'unsafe') {
    return { error: errorRecord('unsafe-evidence-path', `${field}/path`, receiptPath, `${label} path is unsafe`) };
  }
  if (state.kind === 'too-large') {
    return { error: errorRecord('evidence-too-large', `${field}/path`, receiptPath, `${label} exceeds the materialization limit`) };
  }
  if (state.kind !== 'file') {
    return { error: errorRecord('non-regular-evidence', `${field}/path`, receiptPath, `${label} must be a stable regular non-symlink file`) };
  }
  if (!SHA256.test(identity.sha256 ?? '') || state.sha256 !== identity.sha256) {
    const code = label === 'Transcript' ? 'transcript-hash-mismatch' : 'output-hash-mismatch';
    return { error: errorRecord(code, `${field}/sha256`, receiptPath, `${label} SHA-256 does not match its bytes`) };
  }
  if (!Number.isSafeInteger(identity.bytes) || identity.bytes < 0 || state.byteCount !== identity.bytes) {
    const code = label === 'Transcript' ? 'transcript-bytes-mismatch' : 'output-bytes-mismatch';
    return { error: errorRecord(code, `${field}/bytes`, receiptPath, `${label} byte count does not match its bytes`) };
  }
  return { bytes: state.bytes };
}


function firstMissing(value, fields) {
  return fields.find((field) => !Object.hasOwn(value, field));
}

async function validateActionReceipt(receipt, expected, manifest, runRoot, receiptPath, snapshot, isGrader = false) {
  const missing = firstMissing(receipt, RECEIPT_FIELDS);
  if (missing) return { error: errorRecord('missing-field', `/${missing}`, receiptPath, `Receipt field ${missing} is required`) };
  if (!same(Object.keys(receipt).sort(), [...RECEIPT_FIELDS].sort())) {
    return { error: errorRecord('malformed-receipt', '', receiptPath, 'Receipt key set is not canonical') };
  }

  for (const [field, wanted] of [
    ['schemaVersion', 1], ['runId', manifest.runId], ['caseId', expected.caseId],
    ['repetition', expected.repetition], ['variant', expected.variant], ['kind', expected.kind],
    ['targetSkill', manifest.targetSkill], ['baseline', manifest.baseline],
  ]) {
    if (!same(receipt[field], wanted)) {
      return { error: errorRecord('identity-mismatch', `/${field}`, receiptPath, `Receipt ${field} does not match its expected identity`) };
    }
  }

  for (const field of ['host', 'runner']) {
    if (!nonEmptyString(receipt[field])) {
      return { error: errorRecord('identity-mismatch', `/${field}`, receiptPath, `Receipt ${field} must be a non-empty string`) };
    }
  }
  if (!capabilitiesValid(receipt.capabilities)) {
    return { error: errorRecord('identity-mismatch', '/capabilities', receiptPath, 'Receipt capabilities must be a unique array of documented capabilities') };
  }
  if (isGrader && receipt.capabilities.length !== 0) {
    return { error: errorRecord('grader-configuration-mismatch', '/capabilities', receiptPath, 'Grader receipt capabilities must be exactly empty') };
  }
  if (!completionIdentityValid(receipt)) {
    return { error: errorRecord('missing-completion-identity', '/model', receiptPath, 'Receipt requires exactly one concrete completion identity') };
  }
  for (const field of ['tier', 'effort']) {
    if (!optionalString(receipt[field])) {
      return { error: errorRecord('identity-mismatch', `/${field}`, receiptPath, `Receipt ${field} must be a string or null`) };
    }
  }
  if (!isGrader) {
    for (const field of ['host', 'runner', 'model', 'sessionIdentity', 'tier', 'effort']) {
      if (!same(receipt[field], manifest.runConfiguration[field])) {
        return { error: errorRecord('configuration-mismatch', `/${field}`, receiptPath, `Worker ${field} does not match the manifest run configuration`) };
      }
    }
  } else if (!SHA256.test(receipt.packageHash ?? '')
    || receipt.packageHash !== manifest.packageHashes.candidate) {
    return {
      error: errorRecord(
        'package-hash-mismatch',
        '/packageHash',
        receiptPath,
        'Grader package hash must equal the frozen candidate package identity',
      ),
    };
  }
  const completionError = completionPayloadError(receipt.completionStatus, receipt.error);
  if (completionError) {
    return { error: errorRecord('identity-mismatch', completionError.field, receiptPath, completionError.message) };
  }
  if (!validRfc3339Utc(receipt.startedAt)) {
    return { error: errorRecord('identity-mismatch', '/startedAt', receiptPath, 'Receipt start time must be RFC 3339 UTC') };
  }
  if (!Number.isSafeInteger(receipt.durationMs) || receipt.durationMs < 0) {
    return { error: errorRecord('identity-mismatch', '/durationMs', receiptPath, 'Receipt duration must be a non-negative integer') };
  }
  if (receipt.tokenUsage !== UNAVAILABLE) {
    if (!isObject(receipt.tokenUsage)) {
      return { error: errorRecord('identity-mismatch', '/tokenUsage', receiptPath, 'Receipt token usage is invalid') };
    }
    if (!same(Object.keys(receipt.tokenUsage).sort(), ['input', 'output', 'total'])) {
      return { error: errorRecord('malformed-receipt', '', receiptPath, 'Token usage key set is not canonical') };
    }
    if (!['input', 'output', 'total'].every((field) =>
      Number.isSafeInteger(receipt.tokenUsage[field]) && receipt.tokenUsage[field] >= 0)
      || receipt.tokenUsage.total !== receipt.tokenUsage.input + receipt.tokenUsage.output) {
      return { error: errorRecord('identity-mismatch', '/tokenUsage', receiptPath, 'Receipt token usage is invalid') };
    }
  }
  if (expected.kind === 'trigger') {
    if (typeof receipt.selectedSkill !== 'string' || (!KEBAB.test(receipt.selectedSkill) && receipt.selectedSkill !== 'none')) {
      return { error: errorRecord('identity-mismatch', '/selectedSkill', receiptPath, 'Trigger receipt selectedSkill is invalid') };
    }
  } else if (receipt.selectedSkill !== null) {
    return { error: errorRecord('identity-mismatch', '/selectedSkill', receiptPath, 'Non-trigger receipt selectedSkill must be null') };
  }

  const output = await validateIdentityFile(runRoot, receipt.output, '/output', receiptPath, 'Output', snapshot);
  if (output.error) return output;
  let transcriptBytes = null;
  if (receipt.transcript !== UNAVAILABLE) {
    const transcript = await validateIdentityFile(runRoot, receipt.transcript, '/transcript', receiptPath, 'Transcript', snapshot);
    if (transcript.error) return transcript;
    transcriptBytes = transcript.bytes;
  }
  if (receipt.completionStatus !== 'complete') {
    return { error: errorRecord('incomplete-receipt', '/completionStatus', receiptPath, 'Required action did not complete') };
  }
  return { outputBytes: output.bytes, transcriptBytes };
}

function receiptIdentity(relativePath, bytes) {
  return { path: relativePath, sha256: sha256(bytes) };
}

function blockedResult(repetition) {
  return { repetition, completionStatus: 'blocked', receipt: null, assertions: [] };
}


async function assertionPathState(context, relativePath) {
  if (context.fileCache.has(relativePath)) return context.fileCache.get(relativePath);
  const state = await regularFile(context.workspaceRoot, relativePath, {
    snapshot: context.snapshot,
    snapshotPath: `${context.workspacePrefix}/${relativePath}`,
  });
  context.fileCache.set(relativePath, state);
  return state;
}

async function evaluateAssertion(assertion, context) {
  const base = { assertionId: assertion.id, critical: assertion.critical === true };
  if (assertion.kind === 'qualitative') {
    return { ...base, pass: null, rationale: null, anonymizedOutputId: null, grade: null, graderReceipt: null };
  }

  let pass = false;
  let observed = null;
  if (assertion.kind === 'final-contains' || assertion.kind === 'final-excludes') {
    const contains = context.outputText.includes(assertion.substring);
    pass = assertion.kind === 'final-contains' ? contains : !contains;
    observed = context.receipt.output;
  } else if (assertion.kind === 'final-json-path-equals') {
    observed = context.receipt.output;
    if (context.outputJson.parsed) {
      const actual = pointerValue(context.outputJson.value, assertion.pointer);
      pass = actual.found && same(actual.value, assertion.expected);
    }
  } else if (assertion.kind === 'receipt-field-equals') {
    const actual = pointerValue(context.receipt, assertion.pointer);
    pass = actual.found && same(actual.value, assertion.expected);
    observed = context.receiptIdentity;
  } else if (assertion.kind === 'path-exists' || assertion.kind === 'path-absent') {
    const state = await assertionPathState(context, assertion.path);
    const exists = state.kind === 'file';
    pass = assertion.kind === 'path-exists' ? exists : state.kind === 'missing';
    observed = { path: assertion.path };
  } else if (['file-contains', 'file-excludes', 'file-sha256-equals', 'json-path-equals'].includes(assertion.kind)) {
    const relativePath = assertion.path ?? assertion.file;
    const state = await assertionPathState(context, relativePath);
    if (state.kind === 'file') {
      observed = { path: relativePath, sha256: state.sha256, bytes: state.byteCount };
      if (assertion.kind === 'file-sha256-equals') {
        pass = state.sha256 === assertion.sha256;
      } else if (assertion.kind === 'file-contains' || assertion.kind === 'file-excludes') {
        const contains = state.bytes.toString('utf8').includes(assertion.substring);
        pass = assertion.kind === 'file-contains' ? contains : !contains;
      } else {
        try {
          const value = JSON.parse(state.bytes.toString('utf8'));
          const actual = pointerValue(value, assertion.pointer);
          pass = actual.found && same(actual.value, assertion.expected);
        } catch {
          pass = false;
        }
      }
    }
  }
  return { ...base, pass, observed };
}

async function loadCaseDefinition(runRoot, pair, expected, snapshot) {
  const workspacePrefix = pair[expected.variant];
  const workspaceRoot = path.resolve(runRoot, ...workspacePrefix.split('/'));
  const definitionPath = `definitions/${expected.kind}.${expected.caseId}.json`;
  const parsed = await parseFile(runRoot, definitionPath, snapshot);
  if (parsed.state.kind !== 'file' || parsed.malformed) {
    throw new Error(`frozen ${expected.kind} definition is missing or invalid`);
  }
  if (parsed.value.id !== expected.caseId) {
    throw new Error('frozen definition identity does not match the manifest');
  }
  return { definition: parsed.value, workspaceRoot, workspacePrefix };
}

async function validateWorkspacePackage(runRoot, pair, expected, receipt, manifest, receiptPath) {
  const frozenHash = manifest.packageHashes[expected.variant];
  if (expected.variant === 'baseline' && manifest.baseline.kind === 'none') {
    return receipt.packageHash === null
      ? null
      : errorRecord(
          'package-hash-mismatch',
          '/packageHash',
          receiptPath,
          'A no-skill baseline must carry the frozen null package identity',
        );
  }
  const packageRoot = path.resolve(runRoot, ...pair[expected.variant].split('/'), 'package');
  await requireDirectoryChain(runRoot, packageRoot, 'copied package');
  const currentHash = await hashPackage(packageRoot, { trackedOnly: false });
  if (!SHA256.test(receipt.packageHash ?? '')
    || currentHash !== frozenHash
    || receipt.packageHash !== frozenHash) {
    return errorRecord(
      'package-hash-mismatch',
      '/packageHash',
      receiptPath,
      'Copied package hash does not match its frozen manifest identity',
    );
  }
  return null;
}


async function validateGradeInput(runRoot, evidencePrefix, proof, gradePath, snapshot) {
  const { grade, filenameIdentity, expectedGrade } = proof;
  if (!exactKeys(grade.input, ['path', 'sha256'])) {
    return { error: errorRecord('malformed-receipt', '/input', gradePath, 'Grade input identity is not canonical') };
  }
  const expectedPath = `${evidencePrefix}/input.${grade.caseId}.${filenameIdentity.variant}.${grade.repetition}.${grade.graderId}.json`;
  if (grade.input.path !== expectedPath) {
    return { error: errorRecord('identity-mismatch', '/input/path', gradePath, 'Grade input path is not deterministic') };
  }
  const state = await regularFile(runRoot, grade.input.path, { snapshot });
  if (state.kind === 'too-large') {
    return { error: errorRecord('evidence-too-large', '/input/path', gradePath, 'Grade input mapping exceeds the materialization limit') };
  }
  if (state.kind !== 'file') {
    return { error: errorRecord('missing-grade-input', '/input/path', gradePath, 'Grade input mapping is absent') };
  }
  if (!SHA256.test(grade.input.sha256) || state.sha256 !== grade.input.sha256) {
    return { error: errorRecord('grade-input-hash-mismatch', '/input/sha256', gradePath, 'Grade input mapping hash does not match') };
  }
  let input;
  try {
    input = JSON.parse(state.bytes.toString('utf8'));
  } catch {
    input = null;
  }
  if (!exactKeys(input, INPUT_FIELDS)) {
    return { error: errorRecord('malformed-receipt', '', grade.input.path, 'Grade input mapping is not canonical') };
  }
  for (const [field, wanted] of [
    ['schemaVersion', 1], ['runId', grade.runId], ['caseId', grade.caseId],
    ['repetition', grade.repetition], ['graderId', grade.graderId],
    ['assertionId', grade.assertionId], ['anonymizedOutputId', grade.anonymizedOutputId],
    ['source', expectedGrade.result.output],
  ]) {
    if (!same(input[field], wanted)) {
      return { error: errorRecord('grade-input-mismatch', `/${field}`, grade.input.path, `Grade input ${field} does not match its source proof`) };
    }
  }
  return { input, bytes: state.bytes };
}

async function aggregate(options) {
  const manifestPath = path.resolve(options.manifest);
  const evidenceRoot = path.resolve(options.evidence);
  const outPath = path.resolve(options.out);
  const runRoot = path.dirname(manifestPath);
  if (!contained(runRoot, evidenceRoot) || evidenceRoot === runRoot) throw new Error('evidence directory must be contained by the run root');
  if (!contained(runRoot, outPath) || outPath === runRoot) throw new Error('output must be contained by the run root');
  await requirePrivateRunRoot(runRoot);

  await requireDirectoryChain(runRoot, evidenceRoot, 'evidence directory');
  await requireDirectoryChain(runRoot, path.dirname(outPath), 'output parent');
  const manifestRelativePath = relativeTo(runRoot, manifestPath);
  const runSnapshot = await buildRunSnapshot(runRoot);
  const snapshot = indexRunSnapshot(runSnapshot);
  const manifestState = await regularFile(runRoot, manifestRelativePath, { snapshot });
  if (manifestState.kind !== 'file') throw new Error('manifest must be a stable regular non-symlink file');
  const manifest = JSON.parse(manifestState.bytes.toString('utf8'));
  requireManifest(manifest);
  await requireManifestWorkspaces(runRoot, manifest);
  await requireQuiescenceProof(runRoot, manifest, snapshot);
  const gradingPlanByKey = await requireResolvedGradingPlan(runRoot, manifest, snapshot);

  const evidencePrefix = relativeTo(runRoot, evidenceRoot);
  const names = await listDirectoryNames(runRoot, evidencePrefix, snapshot);
  const evidencePaths = names.map((name) => `${evidencePrefix}/${name}`);
  const errors = [];
  const expectedByKey = new Map(manifest.expected.map((item) => [expectedKey(item), item]));
  const expectedByPath = new Map(manifest.expected.map((item) => [
    `${evidencePrefix}/${expectedReceiptName(item)}`, item,
  ]));
  const claimed = new Map();
  const gradePaths = [];
  const graderActionPaths = new Set();
  const inputPaths = new Set();

  evidencePaths.sort((left, right) =>
    Number(expectedByPath.has(right)) - Number(expectedByPath.has(left))
    || compareText(left, right));
  for (const evidencePath of evidencePaths) {
    if (!evidencePath.endsWith('.json')) continue;
    if (gradeFilename(evidencePath)) {
      gradePaths.push(evidencePath);
      continue;
    }
    if (inputFilename(evidencePath)) {
      inputPaths.add(evidencePath);
      continue;
    }
    if (path.basename(evidencePath).startsWith('action.grader.')) {
      graderActionPaths.add(evidencePath);
      continue;
    }
    const parsed = await parseFile(runRoot, evidencePath, snapshot);
    const namedExpected = expectedByPath.get(evidencePath);
    if (parsed.state.kind === 'too-large') {
      errors.push(errorRecord('evidence-too-large', '', evidencePath, 'Action receipt exceeds the materialization limit'));
      if (namedExpected) claimed.set(expectedKey(namedExpected), { invalid: true, path: evidencePath });
      continue;
    }
    if (parsed.state.kind !== 'file' || parsed.malformed) {
      errors.push(errorRecord('malformed-receipt', '', evidencePath, 'Action receipt must be a regular JSON object'));
      if (namedExpected) claimed.set(expectedKey(namedExpected), { invalid: true, path: evidencePath });
      continue;
    }
    const receipt = parsed.value;
    const payloadExpected = expectedByKey.get(expectedKey(receipt));
    if (!namedExpected) {
      if (payloadExpected) {
        const key = expectedKey(payloadExpected);
        if (claimed.has(key)) {
          errors.push(errorRecord('duplicate-receipt', '', evidencePath, 'More than one receipt claims the same expected identity'));
        } else {
          errors.push(errorRecord('unknown-receipt', '', evidencePath, 'Receipt is not at its deterministic expected path'));
          claimed.set(key, { invalid: true, path: evidencePath });
        }
      } else {
        let field = '';
        if (!manifest.expected.some((item) => item.caseId === receipt.caseId)) field = '/caseId';
        else if (!VARIANTS.includes(receipt.variant)) field = '/variant';
        else if (!Number.isSafeInteger(receipt.repetition) || receipt.repetition < 1 || receipt.repetition > manifest.runs) field = '/repetition';
        else if (!WORKER_KINDS.has(receipt.kind)) field = '/kind';
        errors.push(errorRecord('unknown-receipt', field, evidencePath, 'Receipt does not claim a manifest expected identity'));
      }
      continue;
    }
    const key = expectedKey(namedExpected);
    if (claimed.has(key)) {
      errors.push(errorRecord('duplicate-receipt', '', evidencePath, 'More than one receipt claims the same expected identity'));
      claimed.set(key, { invalid: true, path: evidencePath });
      continue;
    }
    claimed.set(key, {
      expected: namedExpected,
      receipt,
      path: evidencePath,
      bytes: parsed.state.bytes,
    });
  }

  const pairMap = new Map(manifest.pairs.map((pair) => [`${pair.caseId}\u0000${pair.repetition}`, pair]));
  const definitionCache = new Map();
  const caseOrder = [];
  const aggregateCases = new Map();
  for (const expected of manifest.expected) {
    if (!aggregateCases.has(expected.caseId)) {
      aggregateCases.set(expected.caseId, {
        caseId: expected.caseId,
        kind: expected.kind,
        candidate: [],
        baseline: [],
        definition: null,
      });
      caseOrder.push(expected.caseId);
    } else if (aggregateCases.get(expected.caseId).kind !== expected.kind) {
      throw new Error('manifest contains kind drift for one case');
    }
  }

  for (const expected of manifest.expected) {
    const key = expectedKey(expected);
    const claim = claimed.get(key);
    const target = aggregateCases.get(expected.caseId)[expected.variant];
    if (!claim) {
      const receiptPath = `${evidencePrefix}/${expectedReceiptName(expected)}`;
      errors.push(errorRecord('missing-receipt', '', receiptPath, 'Expected action receipt is absent'));
      target.push(blockedResult(expected.repetition));
      continue;
    }
    if (claim.invalid) {
      target.push(blockedResult(expected.repetition));
      continue;
    }
    const validated = await validateActionReceipt(claim.receipt, expected, manifest, runRoot, claim.path, snapshot);
    if (validated.error) {
      errors.push(validated.error);
      target.push(blockedResult(expected.repetition));
      continue;
    }

    const pair = pairMap.get(`${expected.caseId}\u0000${expected.repetition}`);
    const packageError = await validateWorkspacePackage(
      runRoot,
      pair,
      expected,
      claim.receipt,
      manifest,
      claim.path,
    );
    if (packageError) {
      errors.push(packageError);
      target.push(blockedResult(expected.repetition));
      continue;
    }
    const definitionKey = `${expected.kind}\u0000${expected.caseId}`;
    let loaded = definitionCache.get(definitionKey);
    if (!loaded) {
      loaded = await loadCaseDefinition(runRoot, pair, expected, snapshot);
      definitionCache.set(definitionKey, loaded);
    } else {
      loaded = {
        ...loaded,
        workspaceRoot: path.resolve(runRoot, ...pair[expected.variant].split('/')),
        workspacePrefix: pair[expected.variant],
      };
    }
    aggregateCases.get(expected.caseId).definition = loaded.definition;
    const expectedCapabilities = loaded.definition.capabilities ?? ['read-workspace'];
    if (!same(claim.receipt.capabilities, expectedCapabilities)) {
      errors.push(errorRecord(
        'configuration-mismatch',
        '/capabilities',
        claim.path,
        'Receipt capabilities do not match the copied case definition',
      ));
      target.push(blockedResult(expected.repetition));
      continue;
    }
    const receiptProof = receiptIdentity(claim.path, claim.bytes);
    const assertions = [];
    const outputText = validated.outputBytes.toString('utf8');
    const fileCache = new Map();
    if (expected.kind === 'behavior') {
      let outputJson = null;
      if (loaded.definition.assertions.some((item) =>
        item.kind === 'final-json-path-equals')) {
        outputJson = { parsed: false };
        if (isUtf8(validated.outputBytes)) {
          try {
            outputJson = { parsed: true, value: JSON.parse(outputText) };
          } catch {
            outputJson = { parsed: false };
          }
        }
      }
      const assertionContext = {
        workspaceRoot: loaded.workspaceRoot,
        workspacePrefix: loaded.workspacePrefix,
        snapshot,
        receipt: claim.receipt,
        receiptIdentity: receiptProof,
        outputText,
        outputJson,
        fileCache,
      };
      for (const assertion of loaded.definition.assertions) {
        assertions.push(await evaluateAssertion(assertion, assertionContext));
      }
    }
    target.push({
      repetition: expected.repetition,
      completionStatus: 'complete',
      receipt: receiptProof,
      output: claim.receipt.output,
      transcript: claim.receipt.transcript,
      durationMs: claim.receipt.durationMs,
      tokenUsage: claim.receipt.tokenUsage,
      selectedSkill: claim.receipt.selectedSkill,
      assertions,
    });
  }

  const qualitativeExpected = new Map();
  for (const entry of aggregateCases.values()) {
    const assertions = entry.definition?.assertions ?? [];
    for (const assertion of assertions.filter((item) => item.kind === 'qualitative')) {
      for (const variant of VARIANTS) {
        for (const result of entry[variant]) {
          if (result.completionStatus === 'complete') {
            const plan = gradingPlanByKey.get(gradingPlanKey({
              caseId: entry.caseId,
              repetition: result.repetition,
              assertionId: assertion.id,
            }));
            qualitativeExpected.set(`${entry.caseId}\u0000${variant}\u0000${result.repetition}\u0000${assertion.id}`, {
              entry, variant, result, assertion, graderId: plan.graderId,
            });
          }
        }
      }
    }
  }

  const gradeProofs = [];
  const referencedGraderReceipts = new Set();
  for (const expectedGrade of qualitativeExpected.values()) {
    referencedGraderReceipts.add(
      `${evidencePrefix}/action.grader.${expectedGrade.entry.caseId}.${expectedGrade.variant}.${expectedGrade.result.repetition}.${expectedGrade.graderId}.json`,
    );
  }
  const qualitativeBySlot = new Map();
  for (const qualitativeKey of qualitativeExpected.keys()) {
    const parts = qualitativeKey.split('\u0000');
    const slot = parts.slice(0, 3).join('\u0000');
    const keys = qualitativeBySlot.get(slot) ?? [];
    keys.push(qualitativeKey);
    qualitativeBySlot.set(slot, keys);
  }
  const qualitativeByGraderSlot = new Map();
  for (const [qualitativeKey, expectedGrade] of qualitativeExpected) {
    qualitativeByGraderSlot.set(
      `${expectedGrade.entry.caseId}\u0000${expectedGrade.variant}\u0000${expectedGrade.result.repetition}\u0000${expectedGrade.graderId}`,
      qualitativeKey,
    );
  }
  const accountedQualitative = new Set();
  const claimedQualitative = new Map();
  const anonymizedInputClaims = new Map();
  for (const inputPath of [...inputPaths].sort(compareText)) {
    const filenameIdentity = inputFilename(inputPath);
    const parsed = await parseFile(runRoot, inputPath, snapshot);
    if (parsed.state.kind !== 'file' || parsed.malformed || !exactKeys(parsed.value, INPUT_FIELDS)) {
      continue;
    }
    const input = parsed.value;
    if (input.schemaVersion !== 1
      || input.runId !== manifest.runId
      || input.caseId !== filenameIdentity.caseId
      || input.repetition !== filenameIdentity.repetition
      || input.graderId !== filenameIdentity.graderId
      || !KEBAB.test(input.assertionId ?? '')
      || !KEBAB.test(input.anonymizedOutputId ?? '')
      || !exactKeys(input.source, ['path', 'sha256', 'bytes'])
      || typeof input.source.path !== 'string'
      || !SHA256.test(input.source.sha256 ?? '')
      || !Number.isSafeInteger(input.source.bytes)
      || input.source.bytes < 0) {
      continue;
    }
    const claims = anonymizedInputClaims.get(input.anonymizedOutputId) ?? [];
    claims.push({
      path: inputPath,
    });
    anonymizedInputClaims.set(input.anonymizedOutputId, claims);
  }
  const collidedAnonymizedOutputs = new Set();
  for (const [anonymizedOutputId, claims] of anonymizedInputClaims) {
    if (claims.length < 2) continue;
    collidedAnonymizedOutputs.add(anonymizedOutputId);
    for (const claim of claims.slice(1)) {
      errors.push(errorRecord(
        'anonymized-output-collision',
        '/anonymizedOutputId',
        claim.path,
        'An anonymized output identity may be used by only one host-owned input mapping in the run',
      ));
    }
  }

  for (const gradePath of gradePaths) {
    const filenameIdentity = gradeFilename(gradePath);
    const slot = `${filenameIdentity.caseId}\u0000${filenameIdentity.variant}\u0000${filenameIdentity.repetition}`;
    const slotQualitative = qualitativeBySlot.get(slot) ?? [];
    const filenameQualitative = qualitativeByGraderSlot.get(
      `${slot}\u0000${filenameIdentity.graderId}`,
    );
    if (filenameQualitative) accountedQualitative.add(filenameQualitative);
    inputPaths.delete(
      `${evidencePrefix}/input.${filenameIdentity.caseId}.${filenameIdentity.variant}.${filenameIdentity.repetition}.${filenameIdentity.graderId}.json`,
    );
    referencedGraderReceipts.add(
      `${evidencePrefix}/action.grader.${filenameIdentity.caseId}.${filenameIdentity.variant}.${filenameIdentity.repetition}.${filenameIdentity.graderId}.json`,
    );
    const parsed = await parseFile(runRoot, gradePath, snapshot);
    if (parsed.state.kind === 'too-large') {
      if (slotQualitative.length === 1) accountedQualitative.add(slotQualitative[0]);
      errors.push(errorRecord('evidence-too-large', '', gradePath, 'Grade exceeds the materialization limit'));
      continue;
    }
    if (parsed.state.kind !== 'file' || parsed.malformed) {
      if (slotQualitative.length === 1) accountedQualitative.add(slotQualitative[0]);
      errors.push(errorRecord('malformed-receipt', '', gradePath, 'Grade must be a regular JSON object'));
      continue;
    }
    const grade = parsed.value;
    const directKey = typeof grade.caseId === 'string'
      && Number.isSafeInteger(grade.repetition)
      && typeof grade.assertionId === 'string'
      ? `${grade.caseId}\u0000${filenameIdentity.variant}\u0000${grade.repetition}\u0000${grade.assertionId}`
      : null;
    if (directKey && qualitativeExpected.has(directKey)) accountedQualitative.add(directKey);
    if ((!directKey || !qualitativeExpected.has(directKey)) && slotQualitative.length === 1) {
      accountedQualitative.add(slotQualitative[0]);
    }
    const missing = firstMissing(grade, GRADE_FIELDS);
    if (missing) {
      errors.push(errorRecord('missing-field', `/${missing}`, gradePath, `Grade field ${missing} is required`));
      continue;
    }
    if (!same(Object.keys(grade).sort(), [...GRADE_FIELDS].sort())) {
      errors.push(errorRecord('malformed-receipt', '', gradePath, 'Grade key set is not canonical'));
      continue;
    }
    const invalidStableId = ['graderId', 'assertionId', 'anonymizedOutputId']
      .find((field) => !KEBAB.test(grade[field] ?? ''));
    if (invalidStableId) {
      errors.push(errorRecord('identity-mismatch', `/${invalidStableId}`, gradePath, `Grade ${invalidStableId} must be stable kebab-case`));
      continue;
    }
    let mismatch = null;
    for (const [field, wanted] of [
      ['schemaVersion', 1], ['runId', manifest.runId], ['caseId', filenameIdentity.caseId],
      ['repetition', filenameIdentity.repetition], ['graderId', filenameIdentity.graderId],
    ]) {
      if (!same(grade[field], wanted)) { mismatch = field; break; }
    }
    if (mismatch) {
      errors.push(errorRecord('identity-mismatch', `/${mismatch}`, gradePath, `Grade ${mismatch} does not match its host-owned identity`));
      continue;
    }

    const expectedGrade = qualitativeExpected.get(directKey);
    if (!expectedGrade) {
      const field = aggregateCases.has(grade.caseId) ? '/assertionId' : '/caseId';
      errors.push(errorRecord('unknown-receipt', field, gradePath, 'Grade does not match an expected qualitative assertion'));
      continue;
    }
    if (grade.graderId !== expectedGrade.graderId) {
      errors.push(errorRecord(
        'identity-mismatch',
        '/graderId',
        gradePath,
        'Grade graderId does not match the resolved host-owned grading plan',
      ));
      continue;
    }
    if (claimedQualitative.has(directKey)) {
      errors.push(errorRecord('duplicate-receipt', '', gradePath, 'More than one grade claims one expected qualitative assertion'));
      continue;
    }
    claimedQualitative.set(directKey, gradePath);
    const payloadError = qualitativePayloadError(grade);
    if (payloadError) {
      errors.push(errorRecord('malformed-receipt', payloadError.field, gradePath, payloadError.message));
      continue;
    }
    if (!isObject(grade.receipt)) {
      errors.push(errorRecord('missing-grade-receipt', '/receipt/path', gradePath, 'Grade does not identify its grader receipt'));
      continue;
    }
    const missingReceiptField = firstMissing(grade.receipt, ['path', 'sha256']);
    if (missingReceiptField) {
      errors.push(errorRecord('missing-field', `/receipt/${missingReceiptField}`, gradePath, `Grade receipt ${missingReceiptField} is required`));
      continue;
    }
    if (!same(Object.keys(grade.receipt).sort(), ['path', 'sha256'])) {
      errors.push(errorRecord('malformed-receipt', '', gradePath, 'Grade receipt identity key set is not canonical'));
      continue;
    }
    if (typeof grade.receipt.path !== 'string') {
      errors.push(errorRecord('identity-mismatch', '/receipt/path', gradePath, 'Grade receipt path must be a string'));
      continue;
    }
    if (typeof grade.receipt.sha256 !== 'string') {
      errors.push(errorRecord('identity-mismatch', '/receipt/sha256', gradePath, 'Grade receipt SHA-256 must be a string'));
      continue;
    }
    const inputProof = await validateGradeInput(
      runRoot,
      evidencePrefix,
      { grade, filenameIdentity, expectedGrade },
      gradePath,
      snapshot,
    );
    if (inputProof.error) {
      errors.push(inputProof.error);
      continue;
    }
    inputPaths.delete(grade.input.path);
    if (grade.completionStatus !== 'complete') {
      errors.push(errorRecord('incomplete-receipt', '/completionStatus', gradePath, 'Required grade did not complete'));
      continue;
    }
    referencedGraderReceipts.add(grade.receipt.path);
    const linked = await regularFile(runRoot, grade.receipt.path, { snapshot });
    if (linked.kind === 'unsafe') {
      errors.push(errorRecord('unsafe-evidence-path', '/receipt/path', gradePath, 'Grade receipt path is unsafe'));
      continue;
    }
    if (linked.kind !== 'file') {
      const code = linked.kind === 'missing'
        && grade.receipt.path === `${evidencePrefix}/action.grader.${grade.caseId}.${filenameIdentity.variant}.${grade.repetition}.${grade.graderId}.json`
        ? 'missing-grade-receipt'
        : 'non-regular-evidence';
      errors.push(errorRecord(code, '/receipt/path', gradePath, 'Linked grader receipt is absent or not a regular file'));
      continue;
    }
    const expectedGraderReceiptPath =
      `${evidencePrefix}/action.grader.${grade.caseId}.${filenameIdentity.variant}.${grade.repetition}.${grade.graderId}.json`;
    if (grade.receipt.path !== expectedGraderReceiptPath) {
      errors.push(errorRecord(
        'identity-mismatch',
        '/receipt/path',
        gradePath,
        'Grade must link the deterministic expected grader receipt path',
      ));
      continue;
    }
    if (!SHA256.test(grade.receipt.sha256) || sha256(linked.bytes) !== grade.receipt.sha256) {
      errors.push(errorRecord('grade-receipt-hash-mismatch', '/receipt/sha256', gradePath, 'Linked grader receipt SHA-256 does not match'));
      continue;
    }
    let graderReceipt;
    try {
      graderReceipt = JSON.parse(linked.bytes.toString('utf8'));
    } catch {
      graderReceipt = null;
    }
    if (!isObject(graderReceipt)) {
      errors.push(errorRecord('malformed-receipt', '', grade.receipt.path, 'Grader receipt must be a JSON object'));
      continue;
    }
    const expectedReceipt = {
      caseId: grade.caseId,
      variant: filenameIdentity.variant,
      repetition: grade.repetition,
      kind: 'grader',
    };
    const validated = await validateActionReceipt(
      graderReceipt,
      expectedReceipt,
      manifest,
      runRoot,
      grade.receipt.path,
      snapshot,
      true,
    );
    if (validated.error) {
      errors.push(validated.error);
      continue;
    }
    gradeProofs.push({
      gradePath,
      gradeBytes: parsed.state.bytes,
      grade,
      filenameIdentity,
      expectedGrade,
      input: inputProof.input,
      inputBytes: inputProof.bytes,
      graderReceipt,
      graderReceiptBytes: linked.bytes,
      graderReceiptPath: grade.receipt.path,
      valid: !collidedAnonymizedOutputs.has(grade.anonymizedOutputId),
      pairMatched: false,
    });
  }
  for (const [qualitativeKey, expectedGrade] of qualitativeExpected) {
    if (accountedQualitative.has(qualitativeKey)) continue;
    const missingPath = `${evidencePrefix}/grade.${expectedGrade.entry.caseId}.${expectedGrade.variant}.${expectedGrade.result.repetition}.${expectedGrade.graderId}.json`;
    errors.push(errorRecord('missing-receipt', '', missingPath, 'Expected qualitative grade is absent'));
  }


  const gradeGroups = new Map();
  for (const proof of gradeProofs) {
    const key = `${proof.grade.caseId}\u0000${proof.grade.repetition}\u0000${proof.grade.assertionId}`;
    if (!gradeGroups.has(key)) gradeGroups.set(key, {});
    const group = gradeGroups.get(key);
    if (group[proof.filenameIdentity.variant]) {
      errors.push(errorRecord('duplicate-receipt', '', proof.gradePath, 'More than one grade claims one expected assertion'));
      proof.valid = false;
      group[proof.filenameIdentity.variant].valid = false;
    } else {
      group[proof.filenameIdentity.variant] = proof;
    }
  }
  for (const group of gradeGroups.values()) {
    if (!group.candidate || !group.baseline) {
      const present = group.candidate ?? group.baseline;
      if (present) present.valid = false;
      continue;
    }
    let matched = group.candidate.valid && group.baseline.valid;
    if (group.candidate.grade.graderId !== group.baseline.grade.graderId) {
      errors.push(errorRecord(
        'grader-identity-mismatch',
        '/graderId',
        group.candidate.gradePath,
        'Paired qualitative grades must use the same grader identity',
      ));
      matched = false;
    }
    for (const field of matched
      ? ['host', 'runner', 'model', 'sessionIdentity', 'tier', 'effort']
      : []) {
      if (!same(group.candidate.graderReceipt[field], group.baseline.graderReceipt[field])) {
        errors.push(errorRecord(
          'grader-configuration-mismatch',
          `/${field}`,
          group.candidate.graderReceiptPath,
          `Paired grader receipt ${field} does not match`,
        ));
        matched = false;
        break;
      }
    }
    group.candidate.valid = group.candidate.valid && matched;
    group.baseline.valid = group.baseline.valid && matched;
    group.candidate.pairMatched = matched;
    group.baseline.pairMatched = matched;
  }

  for (const proof of gradeProofs.filter((item) => item.valid && item.pairMatched)) {
    const assertionResult = proof.expectedGrade.result.assertions
      .find((item) => item.assertionId === proof.grade.assertionId);
    Object.assign(assertionResult, {
      pass: proof.grade.pass,
      rationale: proof.grade.rationale,
      anonymizedOutputId: proof.grade.anonymizedOutputId,
      grade: receiptIdentity(proof.gradePath, proof.gradeBytes),
      graderReceipt: receiptIdentity(proof.graderReceiptPath, proof.graderReceiptBytes),
      graderInput: receiptIdentity(proof.grade.input.path, proof.inputBytes),
    });
  }

  for (const graderPath of graderActionPaths) {
    if (!referencedGraderReceipts.has(graderPath)) {
      errors.push(errorRecord('unknown-receipt', '', graderPath, 'Grader receipt is not linked by an expected qualitative grade'));
    }
  }
  for (const inputPath of inputPaths) {
    errors.push(errorRecord('unknown-receipt', '', inputPath, 'Grader input is not linked by an expected qualitative grade'));
  }

  await revalidateRunSnapshot(runRoot, runSnapshot);

  const status = errors.length > 0 ? 'blocked' : 'complete';
  const cases = caseOrder.map((caseId) => aggregateCases.get(caseId));
  for (const entry of cases) {
    entry.candidate.sort((a, b) => a.repetition - b.repetition);
    entry.baseline.sort((a, b) => a.repetition - b.repetition);
    const candidateDuration = durationMetric(entry.candidate, manifest.runs);
    const baselineDuration = durationMetric(entry.baseline, manifest.runs);
    entry.durationMs = status === 'complete'
      ? { candidate: candidateDuration, baseline: baselineDuration,
          delta: candidateDuration !== UNAVAILABLE && baselineDuration !== UNAVAILABLE
            ? candidateDuration.mean - baselineDuration.mean : UNAVAILABLE }
      : UNAVAILABLE;
    const candidateObjective = entry.candidate.flatMap((item) => item.assertions ?? [])
      .filter((item) => typeof item.pass === 'boolean' && item.grade === undefined);
    const baselineObjective = entry.baseline.flatMap((item) => item.assertions ?? [])
      .filter((item) => typeof item.pass === 'boolean' && item.grade === undefined);
    const rate = (items) => items.length === 0 ? UNAVAILABLE : items.filter((item) => item.pass).length / items.length;
    entry.objectivePassRate = status === 'complete' ? comparative(rate(candidateObjective), rate(baselineObjective)) : UNAVAILABLE;
  }

  const objective = {};
  for (const variant of VARIANTS) {
    const observations = cases.filter((entry) => entry.kind === 'behavior')
      .flatMap((entry) => entry[variant])
      .flatMap((result) => result.assertions ?? [])
      .filter((assertion) => typeof assertion.pass === 'boolean' && assertion.grade === undefined);
    objective[variant] = observations.length === 0
      ? UNAVAILABLE
      : observations.filter((assertion) => assertion.pass).length / observations.length;
  }

  const criticalFailures = [];
  for (const entry of cases) {
    const definitions = entry.definition?.assertions ?? [];
    for (const definition of definitions.filter((assertion) => assertion.critical === true)) {
      const repetitions = {};
      for (const variant of VARIANTS) {
        repetitions[variant] = entry[variant]
          .filter((result) => result.assertions?.some((assertion) => assertion.assertionId === definition.id && assertion.pass === false))
          .map((result) => result.repetition);
      }
      if (repetitions.candidate.length > 0 || repetitions.baseline.length > 0) {
        criticalFailures.push({ caseId: entry.caseId, assertionId: definition.id, repetitions });
      }
    }
  }

  const allResults = Object.fromEntries(VARIANTS.map((variant) => [
    variant,
    cases.filter((entry) => WORKER_KINDS.has(entry.kind)).flatMap((entry) => entry[variant]),
  ]));
  let overallDuration = UNAVAILABLE;
  let overallTokens = UNAVAILABLE;
  let precision = UNAVAILABLE;
  let recall = UNAVAILABLE;
  let objectiveRate = UNAVAILABLE;
  if (status === 'complete') {
    const candidateDuration = durationMetric(allResults.candidate, manifest.runs);
    const baselineDuration = durationMetric(allResults.baseline, manifest.runs);
    overallDuration = {
      candidate: candidateDuration,
      baseline: baselineDuration,
      delta: candidateDuration.mean - baselineDuration.mean,
    };
    overallTokens = tokenComparison(
      tokenMetric(allResults.candidate, manifest.runs),
      tokenMetric(allResults.baseline, manifest.runs),
    );
    const candidatePrecision = triggerMetric(cases, manifest.targetSkill, 'candidate', 'precision');
    const baselinePrecision = triggerMetric(cases, manifest.targetSkill, 'baseline', 'precision');
    precision = comparative(candidatePrecision, baselinePrecision);
    const candidateRecall = triggerMetric(cases, manifest.targetSkill, 'candidate', 'recall');
    const baselineRecall = triggerMetric(cases, manifest.targetSkill, 'baseline', 'recall');
    recall = comparative(candidateRecall, baselineRecall);
    objectiveRate = comparative(objective.candidate, objective.baseline);
  }

  for (const entry of cases) delete entry.definition;
  return {
    schemaVersion: 1,
    runId: manifest.runId,
    targetSkill: manifest.targetSkill,
    executionStatus: status,
    baseline: manifest.baseline,
    runs: manifest.runs,
    cases,
    overall: {
      objectivePassRate: objectiveRate,
      criticalFailures,
      triggerPrecision: precision,
      triggerRecall: recall,
      durationMs: overallDuration,
      tokenUsage: overallTokens,
    },
    evidenceErrors: sortErrors(errors),
  };
}


async function main(argv) {
  const options = parseArguments(argv);
  const result = await aggregate(options);
  await writeCreateNew(path.resolve(options.out), result);
}


export {
  aggregate,
  main as runAggregateCli,
  sanitizeMessage,
  writeCreateNew,
};
