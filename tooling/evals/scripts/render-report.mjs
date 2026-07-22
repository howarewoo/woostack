import { createHash } from 'node:crypto';
import { constants as fsConstants } from 'node:fs';
import { lstat, open, realpath } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  contained,
  publishCreateNew,
  rollbackCreateNew,
} from './aggregate/safe-access.mjs';
import {
  durationMetric as deriveDurationMetric,
  tokenComparison as deriveTokenComparison,
  tokenMetric as deriveTokenMetric,
} from './aggregate/metrics.mjs';

const USAGE = 'usage: node render-report.mjs --aggregate <aggregate.json> --out <report.html> [--terminal]';
const MAX_AGGREGATE_BYTES = 8 * 1024 * 1024;
const MAX_STRING_LENGTH = 64 * 1024;
const MAX_PATH_BYTES = 4096;
const MAX_CASES = 5000;
const MAX_ASSERTIONS = 10000;
const EVIDENCE_OVERSIZE_BYTES = 64 * 1024;
const MAX_EVIDENCE_FILE_BYTES = 4 * 1024 * 1024;
const MAX_EVIDENCE_TOTAL_BYTES = 8 * 1024 * 1024;
const LINKABLE_EVIDENCE_EXTENSIONS = new Set(['.json', '.txt']);
const UNAVAILABLE = 'unavailable';
const TRIGGER_METHODOLOGY = 'Trigger metrics measure controlled catalog selection, not host-loader proof.';
const SHA256 = /^sha256:[0-9a-f]{64}$/;
const KEBAB = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
const CSP = "default-src 'none'; script-src 'none'; style-src 'unsafe-inline'; img-src 'none'; font-src 'none'; connect-src 'none'; media-src 'none'; object-src 'none'; frame-src 'none'; child-src 'none'; worker-src 'none'; manifest-src 'none'; base-uri 'none'; form-action 'none'";

function parseArguments(argv) {
  const options = { terminal: false };
  for (let index = 0; index < argv.length; index += 1) {
    const flag = argv[index];
    if (flag === '--terminal') {
      if (options.terminal) throw new Error(USAGE);
      options.terminal = true;
      continue;
    }
    if (!['--aggregate', '--out'].includes(flag) || Object.hasOwn(options, flag)) {
      throw new Error(USAGE);
    }
    const value = argv[index + 1];
    if (!value || value.startsWith('--') || Buffer.byteLength(value, 'utf8') > MAX_PATH_BYTES) {
      throw new Error(USAGE);
    }
    options[flag] = value;
    index += 1;
  }
  if (!options['--aggregate'] || !options['--out']) throw new Error(USAGE);
  return {
    aggregate: path.resolve(options['--aggregate']),
    out: path.resolve(options['--out']),
    terminal: options.terminal,
  };
}

function sameFileIdentity(left, right) {
  return left.dev === right.dev
    && left.ino === right.ino
    && left.size === right.size
    && left.mtimeNs === right.mtimeNs;
}

async function readAggregate(aggregatePath) {
  let handle;
  try {
    handle = await open(
      aggregatePath,
      fsConstants.O_RDONLY
        | (fsConstants.O_NONBLOCK ?? 0)
        | (fsConstants.O_NOFOLLOW ?? 0),
    );
  } catch {
    throw new Error('aggregate must be a readable non-symlink file');
  }
  try {
    const before = await handle.stat({ bigint: true });
    if (!before.isFile()) throw new Error('aggregate must be a regular file');
    if (before.size > BigInt(MAX_AGGREGATE_BYTES)) {
      throw new Error('aggregate exceeds the rendering size limit');
    }
    const expectedBytes = Number(before.size);
    const bytes = Buffer.alloc(expectedBytes);
    let offset = 0;
    while (offset < expectedBytes) {
      const { bytesRead } = await handle.read(bytes, offset, expectedBytes - offset, offset);
      if (bytesRead === 0) break;
      offset += bytesRead;
    }
    const after = await handle.stat({ bigint: true });
    if (offset !== expectedBytes || !sameFileIdentity(before, after)) {
      throw new Error('aggregate changed while it was read');
    }
    let source;
    try {
      source = new TextDecoder('utf-8', { fatal: true }).decode(bytes);
    } catch {
      throw new Error('aggregate is not valid UTF-8');
    }
    try {
      return JSON.parse(source);
    } catch {
      throw new Error('aggregate JSON is malformed');
    }
  } finally {
    await handle.close();
  }
}

function schemaError(location) {
  throw new Error(`aggregate schema is invalid at ${location}`);
}

function isObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function exactKeys(value, keys, location) {
  if (!isObject(value)) schemaError(location);
  const actual = Object.keys(value).sort();
  const expected = [...keys].sort();
  if (actual.length !== expected.length
    || actual.some((key, index) => key !== expected[index])) {
    schemaError(location);
  }
}

function text(value, location, { nullable = false, maxLength = MAX_STRING_LENGTH } = {}) {
  if (nullable && value === null) return;
  if (typeof value !== 'string' || value.length > maxLength) schemaError(location);
}

function integer(value, location, { minimum = 0, maximum = Number.MAX_SAFE_INTEGER } = {}) {
  if (!Number.isSafeInteger(value) || value < minimum || value > maximum) schemaError(location);
}

function finiteNumber(value, location) {
  if (typeof value !== 'number' || !Number.isFinite(value)) schemaError(location);
}

function localPath(value, location) {
  text(value, location, { maxLength: 1024 });
  if (value.length === 0
    || path.posix.isAbsolute(value)
    || value.includes('\\')
    || value.includes(':')
    || /[\u0000-\u001f\u007f]/.test(value)) {
    schemaError(location);
  }
  const parts = value.split('/');
  if (parts.some((part) => part === '' || part === '.' || part === '..')) schemaError(location);
}

function identity(value, location, shape) {
  const keys = shape === 'receipt'
    ? ['path', 'sha256']
    : shape === 'file'
      ? ['path', 'sha256', 'bytes']
      : Object.keys(value ?? {}).sort();
  if (shape === 'observed'
    && ![
      'path',
      'path,sha256',
      'bytes,path,sha256',
    ].includes(keys.join(','))) {
    schemaError(location);
  }
  exactKeys(value, keys, location);
  localPath(value.path, `${location}/path`);
  if (Object.hasOwn(value, 'sha256') && !SHA256.test(value.sha256)) {
    schemaError(`${location}/sha256`);
  }
  if (Object.hasOwn(value, 'bytes')) integer(value.bytes, `${location}/bytes`);
}

function tokenUsage(value, location) {
  if (value === UNAVAILABLE) return;
  exactKeys(value, ['input', 'output', 'total'], location);
  for (const field of ['input', 'output', 'total']) integer(value[field], `${location}/${field}`);
  if (value.total !== value.input + value.output) schemaError(location);
}

function validateAssertion(value, location) {
  if (!isObject(value)) schemaError(location);
  if (Object.hasOwn(value, 'observed')) {
    exactKeys(value, ['assertionId', 'critical', 'pass', 'observed'], location);
    if (typeof value.pass !== 'boolean') schemaError(`${location}/pass`);
    if (value.observed !== null) identity(value.observed, `${location}/observed`, 'observed');
  } else {
    const keys = ['assertionId', 'critical', 'pass', 'rationale', 'anonymizedOutputId', 'grade', 'graderReceipt'];
    if (Object.hasOwn(value, 'graderInput')) keys.push('graderInput');
    exactKeys(value, keys, location);
    if (value.pass !== null && typeof value.pass !== 'boolean') schemaError(`${location}/pass`);
    text(value.rationale, `${location}/rationale`, { nullable: true });
    text(value.anonymizedOutputId, `${location}/anonymizedOutputId`, { nullable: true, maxLength: 1024 });
    for (const field of ['grade', 'graderReceipt', ...(Object.hasOwn(value, 'graderInput') ? ['graderInput'] : [])]) {
      if (value[field] !== null) identity(value[field], `${location}/${field}`, 'receipt');
    }
  }
  text(value.assertionId, `${location}/assertionId`, { maxLength: 1024 });
  if (typeof value.critical !== 'boolean') schemaError(`${location}/critical`);
}

function validateResult(value, location, runs, caseKind) {
  if (!isObject(value)) schemaError(location);
  if (value.completionStatus === 'blocked') {
    exactKeys(value, ['repetition', 'completionStatus', 'receipt', 'assertions'], location);
    if (value.receipt !== null) schemaError(`${location}/receipt`);
  } else if (value.completionStatus === 'complete') {
    exactKeys(value, [
      'repetition', 'completionStatus', 'receipt', 'output', 'transcript',
      'durationMs', 'tokenUsage', 'selectedSkill', 'assertions',
    ], location);
    identity(value.receipt, `${location}/receipt`, 'receipt');
    identity(value.output, `${location}/output`, 'file');
    if (value.transcript !== UNAVAILABLE) identity(value.transcript, `${location}/transcript`, 'file');
    if (value.durationMs !== UNAVAILABLE) integer(value.durationMs, `${location}/durationMs`);
    tokenUsage(value.tokenUsage, `${location}/tokenUsage`);
    text(value.selectedSkill, `${location}/selectedSkill`, { nullable: true, maxLength: 1024 });
    if (caseKind === 'trigger') {
      if (value.selectedSkill === null || !KEBAB.test(value.selectedSkill)) {
        schemaError(`${location}/selectedSkill`);
      }
    } else if (value.selectedSkill !== null) {
      schemaError(`${location}/selectedSkill`);
    }
  } else {
    schemaError(`${location}/completionStatus`);
  }
  integer(value.repetition, `${location}/repetition`, { minimum: 1, maximum: runs });
  if (!Array.isArray(value.assertions) || value.assertions.length > MAX_ASSERTIONS) {
    schemaError(`${location}/assertions`);
  }
  value.assertions.forEach((assertion, index) =>
    validateAssertion(assertion, `${location}/assertions/${index}`));
}

function nearlyEqual(actual, expected) {
  const scale = Math.max(1, Math.abs(actual), Math.abs(expected));
  return Math.abs(actual - expected) <= Number.EPSILON * scale * 16;
}

function unavailableOrRate(value, location) {
  if (value === UNAVAILABLE) return;
  finiteNumber(value, location);
  if (value < 0 || value > 1) schemaError(location);
}

function sampleMetric(value, location) {
  exactKeys(value, ['mean', 'variance'], location);
  finiteNumber(value.mean, `${location}/mean`);
  if (value.mean < 0) schemaError(`${location}/mean`);
  if (value.variance !== UNAVAILABLE) {
    finiteNumber(value.variance, `${location}/variance`);
    if (value.variance < 0) schemaError(`${location}/variance`);
  }
}

function scalarComparison(value, location) {
  if (value === UNAVAILABLE) return;
  exactKeys(value, ['candidate', 'baseline', 'delta'], location);
  unavailableOrRate(value.candidate, `${location}/candidate`);
  unavailableOrRate(value.baseline, `${location}/baseline`);
  if (typeof value.candidate === 'number' && typeof value.baseline === 'number') {
    finiteNumber(value.delta, `${location}/delta`);
    if (!nearlyEqual(value.delta, value.candidate - value.baseline)) {
      schemaError(`${location}/delta`);
    }
  } else if (value.delta !== UNAVAILABLE) {
    schemaError(`${location}/delta`);
  }
}

function durationComparison(value, location) {
  if (value === UNAVAILABLE) return;
  exactKeys(value, ['candidate', 'baseline', 'delta'], location);
  sampleMetric(value.candidate, `${location}/candidate`);
  sampleMetric(value.baseline, `${location}/baseline`);
  finiteNumber(value.delta, `${location}/delta`);
  if (!nearlyEqual(value.delta, value.candidate.mean - value.baseline.mean)) {
    schemaError(`${location}/delta`);
  }
}

function tokenMetricSet(value, location) {
  exactKeys(value, ['input', 'output', 'total'], location);
  for (const field of ['input', 'output', 'total']) {
    sampleMetric(value[field], `${location}/${field}`);
  }
  if (!nearlyEqual(value.total.mean, value.input.mean + value.output.mean)) {
    schemaError(`${location}/total/mean`);
  }
}

function tokenComparison(value, location) {
  if (value === UNAVAILABLE) return;
  exactKeys(value, ['candidate', 'baseline', 'delta'], location);
  tokenMetricSet(value.candidate, `${location}/candidate`);
  tokenMetricSet(value.baseline, `${location}/baseline`);
  exactKeys(value.delta, ['input', 'output', 'total'], `${location}/delta`);
  for (const field of ['input', 'output', 'total']) {
    finiteNumber(value.delta[field], `${location}/delta/${field}`);
    if (!nearlyEqual(
      value.delta[field],
      value.candidate[field].mean - value.baseline[field].mean,
    )) {
      schemaError(`${location}/delta/${field}`);
    }
  }
}

function validateOverall(value, location, runs) {
  exactKeys(value, [
    'objectivePassRate', 'criticalFailures', 'triggerPrecision', 'triggerRecall',
    'durationMs', 'tokenUsage',
  ], location);
  scalarComparison(value.objectivePassRate, `${location}/objectivePassRate`);
  scalarComparison(value.triggerPrecision, `${location}/triggerPrecision`);
  scalarComparison(value.triggerRecall, `${location}/triggerRecall`);
  durationComparison(value.durationMs, `${location}/durationMs`);
  tokenComparison(value.tokenUsage, `${location}/tokenUsage`);
  if (!Array.isArray(value.criticalFailures) || value.criticalFailures.length > MAX_ASSERTIONS) {
    schemaError(`${location}/criticalFailures`);
  }
  value.criticalFailures.forEach((failure, index) => {
    const failureLocation = `${location}/criticalFailures/${index}`;
    exactKeys(failure, ['caseId', 'assertionId', 'repetitions'], failureLocation);
    text(failure.caseId, `${failureLocation}/caseId`, { maxLength: 1024 });
    text(failure.assertionId, `${failureLocation}/assertionId`, { maxLength: 1024 });
    exactKeys(failure.repetitions, ['candidate', 'baseline'], `${failureLocation}/repetitions`);
    for (const variant of ['candidate', 'baseline']) {
      const repetitions = failure.repetitions[variant];
      if (!Array.isArray(repetitions) || repetitions.length > runs) {
        schemaError(`${failureLocation}/repetitions/${variant}`);
      }
      repetitions.forEach((repetition, repetitionIndex) =>
        integer(repetition, `${failureLocation}/repetitions/${variant}/${repetitionIndex}`, {
          minimum: 1,
          maximum: runs,
        }));
    }
  });
}

function objectiveRate(results) {
  let passed = 0;
  let total = 0;
  for (const result of results) {
    for (const assertion of result.assertions) {
      if (!Object.hasOwn(assertion, 'observed')) continue;
      total += 1;
      if (assertion.pass) passed += 1;
    }
  }
  return total === 0 ? UNAVAILABLE : passed / total;
}

function comparisonUnavailable(value) {
  return isObject(value)
    && value.candidate === UNAVAILABLE
    && value.baseline === UNAVAILABLE
    && value.delta === UNAVAILABLE;
}

function matchesRateComparison(value, candidate, baseline, applicable) {
  if (!applicable) return comparisonUnavailable(value);
  if (value === UNAVAILABLE) return false;
  const candidateMatches = candidate === UNAVAILABLE
    ? value.candidate === UNAVAILABLE
    : nearlyEqual(value.candidate, candidate);
  const baselineMatches = baseline === UNAVAILABLE
    ? value.baseline === UNAVAILABLE
    : nearlyEqual(value.baseline, baseline);
  const expectedDelta = typeof candidate === 'number' && typeof baseline === 'number'
    ? candidate - baseline
    : UNAVAILABLE;
  const deltaMatches = expectedDelta === UNAVAILABLE
    ? value.delta === UNAVAILABLE
    : nearlyEqual(value.delta, expectedDelta);
  return candidateMatches && baselineMatches && deltaMatches;
}

function canonicalCriticalFailures(failures) {
  return failures.map((failure) => ({
    caseId: failure.caseId,
    assertionId: failure.assertionId,
    repetitions: {
      candidate: [...failure.repetitions.candidate].sort((a, b) => a - b),
      baseline: [...failure.repetitions.baseline].sort((a, b) => a - b),
    },
  })).sort((a, b) =>
    `${a.caseId}\u0000${a.assertionId}`.localeCompare(`${b.caseId}\u0000${b.assertionId}`));
}

function derivedCriticalFailures(cases) {
  const failures = new Map();
  for (const entry of cases) {
    for (const variant of ['candidate', 'baseline']) {
      for (const result of entry[variant]) {
        for (const assertion of result.assertions) {
          if (!assertion.critical || assertion.pass !== false) continue;
          const key = JSON.stringify([entry.caseId, assertion.assertionId]);
          if (!failures.has(key)) {
            failures.set(key, {
              caseId: entry.caseId,
              assertionId: assertion.assertionId,
              repetitions: { candidate: new Set(), baseline: new Set() },
            });
          }
          failures.get(key).repetitions[variant].add(result.repetition);
        }
      }
    }
  }
  return [...failures.values()].map((failure) => ({
    ...failure,
    repetitions: {
      candidate: [...failure.repetitions.candidate],
      baseline: [...failure.repetitions.baseline],
    },
  }));
}

function derivedValueMatches(actual, expected) {
  if (typeof actual === 'number' && typeof expected === 'number') {
    return nearlyEqual(actual, expected);
  }
  if (actual === expected) return true;
  if (!isObject(actual) || !isObject(expected)) return false;
  const keys = Object.keys(expected);
  return Object.keys(actual).length === keys.length
    && keys.every((key) => Object.hasOwn(actual, key)
      && derivedValueMatches(actual[key], expected[key]));
}

function deriveDurationComparison(candidate, baseline) {
  return {
    candidate,
    baseline,
    delta: candidate === UNAVAILABLE || baseline === UNAVAILABLE
      ? UNAVAILABLE
      : candidate.mean - baseline.mean,
  };
}

function validateDerivedEvidence(value) {
  if (value.executionStatus === 'complete') {
    value.cases.forEach((entry, caseIndex) => {
      const candidate = entry.kind === 'behavior' ? objectiveRate(entry.candidate) : UNAVAILABLE;
      const baseline = entry.kind === 'behavior' ? objectiveRate(entry.baseline) : UNAVAILABLE;
      if (!matchesRateComparison(
        entry.objectivePassRate,
        candidate,
        baseline,
        entry.kind === 'behavior',
      )) {
        schemaError(`/cases/${caseIndex}/objectivePassRate`);
      }
      const expectedDuration = deriveDurationComparison(
        deriveDurationMetric(entry.candidate, value.runs),
        deriveDurationMetric(entry.baseline, value.runs),
      );
      if (!derivedValueMatches(entry.durationMs, expectedDuration)) {
        schemaError(`/cases/${caseIndex}/durationMs`);
      }
      for (const variant of ['candidate', 'baseline']) {
        entry[variant].forEach((result, resultIndex) => {
          result.assertions.forEach((assertion, assertionIndex) => {
            if (Object.hasOwn(assertion, 'observed')) return;
            if (typeof assertion.pass !== 'boolean'
              || assertion.grade === null
              || assertion.graderReceipt === null
              || !Object.hasOwn(assertion, 'graderInput')
              || assertion.graderInput === null) {
              schemaError(
                `/cases/${caseIndex}/${variant}/${resultIndex}/assertions/${assertionIndex}`,
              );
            }
          });
        });
      }
    });
    const behaviorCases = value.cases.filter((entry) => entry.kind === 'behavior');
    const candidate = objectiveRate(behaviorCases.flatMap((entry) => entry.candidate));
    const baseline = objectiveRate(behaviorCases.flatMap((entry) => entry.baseline));
    if (!matchesRateComparison(
      value.overall.objectivePassRate,
      candidate,
      baseline,
      behaviorCases.length > 0,
    )) {
      schemaError('/overall/objectivePassRate');
    }
    const allResults = Object.fromEntries(['candidate', 'baseline'].map((variant) => [
      variant,
      value.cases.flatMap((entry) => entry[variant]),
    ]));
    const expectedDuration = deriveDurationComparison(
      deriveDurationMetric(allResults.candidate, value.runs),
      deriveDurationMetric(allResults.baseline, value.runs),
    );
    if (!derivedValueMatches(value.overall.durationMs, expectedDuration)) {
      schemaError('/overall/durationMs');
    }
    const expectedTokens = deriveTokenComparison(
      deriveTokenMetric(allResults.candidate, value.runs),
      deriveTokenMetric(allResults.baseline, value.runs),
    );
    if (!derivedValueMatches(value.overall.tokenUsage, expectedTokens)) {
      schemaError('/overall/tokenUsage');
    }
  }
  const expectedFailures = canonicalCriticalFailures(derivedCriticalFailures(value.cases));
  const actualFailures = canonicalCriticalFailures(value.overall.criticalFailures);
  if (JSON.stringify(actualFailures) !== JSON.stringify(expectedFailures)) {
    schemaError('/overall/criticalFailures');
  }
}

function validateExecutionConsistency(value) {
  const candidateComplete = value.cases.every((entry) =>
    entry.candidate.length === value.runs
      && entry.candidate.every((result) => result.completionStatus === 'complete'));
  const baselineComplete = value.cases.every((entry) =>
    entry.baseline.length === value.runs
      && entry.baseline.every((result) => result.completionStatus === 'complete'));
  if (value.cases.some((entry) =>
    entry.candidate.length !== value.runs || entry.baseline.length !== value.runs)) {
    schemaError('/cases');
  }
  const hasBehaviorCases = value.cases.some((entry) => entry.kind === 'behavior');
  const hasTriggerCases = value.cases.some((entry) => entry.kind === 'trigger');
  const metricAvailabilityIsInvalid = (metricValue, applicable) =>
    applicable ? metricValue === UNAVAILABLE : !comparisonUnavailable(metricValue);
  const caseMetricsUnavailable = value.cases.every((entry) =>
    entry.durationMs === UNAVAILABLE && entry.objectivePassRate === UNAVAILABLE);
  const overallMetricsUnavailable = [
    value.overall.objectivePassRate,
    value.overall.triggerPrecision,
    value.overall.triggerRecall,
    value.overall.durationMs,
    value.overall.tokenUsage,
  ].every((metricValue) => metricValue === UNAVAILABLE);

  if (value.executionStatus === 'complete') {
    if (!candidateComplete
      || !baselineComplete
      || value.evidenceErrors.length !== 0
      || value.cases.some((entry) =>
        entry.durationMs === UNAVAILABLE
          || metricAvailabilityIsInvalid(entry.objectivePassRate, entry.kind === 'behavior'))
      || metricAvailabilityIsInvalid(value.overall.objectivePassRate, hasBehaviorCases)
      || metricAvailabilityIsInvalid(value.overall.triggerPrecision, hasTriggerCases)
      || metricAvailabilityIsInvalid(value.overall.triggerRecall, hasTriggerCases)
      || value.overall.durationMs === UNAVAILABLE) {
      schemaError('/executionStatus');
    }
    return;
  }
  if (value.evidenceErrors.length === 0
    || !caseMetricsUnavailable
    || !overallMetricsUnavailable) {
    schemaError('/executionStatus');
  }
}

function validateAggregate(value) {
  exactKeys(value, [
    'schemaVersion', 'runId', 'targetSkill', 'executionStatus', 'baseline',
    'runs', 'cases', 'overall', 'evidenceErrors',
  ], '');
  if (value.schemaVersion !== 1) schemaError('/schemaVersion');
  text(value.runId, '/runId', { maxLength: 1024 });
  text(value.targetSkill, '/targetSkill', { maxLength: 1024 });
  if (!['complete', 'blocked'].includes(value.executionStatus)) {
    schemaError('/executionStatus');
  }
  integer(value.runs, '/runs', { minimum: 1, maximum: 10 });
  exactKeys(value.baseline, ['kind', 'identity'], '/baseline');
  if (!['git-ref', 'path', 'none'].includes(value.baseline.kind)) schemaError('/baseline/kind');
  text(value.baseline.identity, '/baseline/identity', { maxLength: 1024 });
  if (!Array.isArray(value.cases) || value.cases.length === 0 || value.cases.length > MAX_CASES) schemaError('/cases');
  const caseIds = new Set();
  value.cases.forEach((entry, caseIndex) => {
    const location = `/cases/${caseIndex}`;
    exactKeys(entry, [
      'caseId', 'kind', 'candidate', 'baseline', 'durationMs', 'objectivePassRate',
    ], location);
    text(entry.caseId, `${location}/caseId`, { maxLength: 1024 });
    if (caseIds.has(entry.caseId)) schemaError(`${location}/caseId`);
    caseIds.add(entry.caseId);
    if (!['behavior', 'trigger'].includes(entry.kind)) schemaError(`${location}/kind`);
    for (const variant of ['candidate', 'baseline']) {
      if (!Array.isArray(entry[variant]) || entry[variant].length > value.runs) {
        schemaError(`${location}/${variant}`);
      }
      const repetitions = new Set();
      entry[variant].forEach((result, resultIndex) => {
        validateResult(result, `${location}/${variant}/${resultIndex}`, value.runs, entry.kind);
        if (repetitions.has(result.repetition)) schemaError(`${location}/${variant}/${resultIndex}/repetition`);
        repetitions.add(result.repetition);
      });
    }
    durationComparison(entry.durationMs, `${location}/durationMs`);
    scalarComparison(entry.objectivePassRate, `${location}/objectivePassRate`);
  });
  validateOverall(value.overall, '/overall', value.runs);
  if (!Array.isArray(value.evidenceErrors) || value.evidenceErrors.length > MAX_ASSERTIONS) {
    schemaError('/evidenceErrors');
  }
  value.evidenceErrors.forEach((error, index) => {
    const location = `/evidenceErrors/${index}`;
    exactKeys(error, ['code', 'field', 'path', 'message'], location);
    for (const field of ['code', 'field', 'path', 'message']) {
      text(error[field], `${location}/${field}`);
    }
  });
  validateExecutionConsistency(value);
  validateDerivedEvidence(value);
  return value;
}

function cleanText(value) {
  return String(value).replace(/[\u0000-\u001f\u007f-\u009f]/g, ' ');
}

function escapeHtml(value) {
  return cleanText(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function titleCase(value) {
  return value.charAt(0).toUpperCase() + value.slice(1);
}

function formatNumber(value) {
  if (value === UNAVAILABLE) return 'Unavailable';
  if (Object.is(value, -0)) return '0';
  return Number.isInteger(value) ? String(value) : String(Number(value.toFixed(4)));
}

function formatRate(value) {
  if (value === UNAVAILABLE) return 'Unavailable';
  return `${Number((value * 100).toFixed(2))}%`;
}

function changeText(delta) {
  if (delta === UNAVAILABLE) return 'Unavailable';
  return Object.is(delta, 0) || Object.is(delta, -0) ? 'Equal' : 'Changed';
}

function statusClass(status) {
  if (status === 'complete') return 'status-complete';
  return 'status-blocked';
}


function encodedRelativePath(relativePath) {
  return relativePath.split(path.sep).map((segment) => {
    if (segment === '..') return '..';
    if (segment === '.') return '.';
    return encodeURIComponent(segment);
  }).join('/');
}

function evidenceKey(identityValue) {
  return JSON.stringify([
    identityValue.path,
    identityValue.sha256,
    identityValue.bytes ?? null,
  ]);
}

function collectEvidenceIdentities(value, identities = new Map()) {
  if (Array.isArray(value)) {
    value.forEach((item) => collectEvidenceIdentities(item, identities));
  } else if (isObject(value)) {
    if (typeof value.path === 'string' && SHA256.test(value.sha256 ?? '')) {
      identities.set(evidenceKey(value), value);
    }
    Object.values(value).forEach((item) => collectEvidenceIdentities(item, identities));
  }
  return identities;
}

async function verifiedEvidenceHref(
  aggregateRoot,
  reportPath,
  identityValue,
  budget,
  publishedAssets,
) {
  try {
    const relativePath = identityValue.path;
    const extension = path.posix.extname(relativePath).toLowerCase();
    if (!LINKABLE_EVIDENCE_EXTENSIONS.has(extension)) return null;
    const rootState = await lstat(aggregateRoot, { bigint: true });
    if (!rootState.isDirectory() || rootState.isSymbolicLink()) return null;
    const canonicalRoot = await realpath(aggregateRoot);
    const absoluteEvidence = path.resolve(aggregateRoot, ...relativePath.split('/'));
    if (!contained(aggregateRoot, absoluteEvidence) || absoluteEvidence === aggregateRoot) return null;

    let cursor = aggregateRoot;
    const parts = relativePath.split('/');
    for (const [index, part] of parts.entries()) {
      cursor = path.join(cursor, part);
      const state = await lstat(cursor, { bigint: true });
      if (state.isSymbolicLink()) return null;
      if (index < parts.length - 1 ? !state.isDirectory() : !state.isFile()) return null;
    }
    const finalHandle = await open(
      absoluteEvidence,
      fsConstants.O_RDONLY
        | (fsConstants.O_NONBLOCK ?? 0)
        | (fsConstants.O_NOFOLLOW ?? 0),
    );
    let contents;
    try {
      const opened = await finalHandle.stat({ bigint: true });
      if (!opened.isFile()
        || opened.size > BigInt(MAX_EVIDENCE_FILE_BYTES)
        || opened.size > budget.remaining
        || (Object.hasOwn(identityValue, 'bytes')
          && opened.size !== BigInt(identityValue.bytes))) {
        return null;
      }
      budget.remaining -= opened.size;

      const hash = createHash('sha256');
      contents = Buffer.allocUnsafe(Number(opened.size));
      let offset = 0;
      while (BigInt(offset) < opened.size) {
        const { bytesRead } = await finalHandle.read(
          contents,
          offset,
          contents.length - offset,
          offset,
        );
        if (bytesRead === 0) break;
        hash.update(contents.subarray(offset, offset + bytesRead));
        offset += bytesRead;
      }

      const after = await finalHandle.stat({ bigint: true });
      const listed = await lstat(absoluteEvidence, { bigint: true });
      if (BigInt(offset) !== opened.size
        || !sameFileIdentity(opened, after)
        || listed.isSymbolicLink()
        || !sameFileIdentity(after, listed)
        || (Object.hasOwn(identityValue, 'bytes') && offset !== identityValue.bytes)
        || `sha256:${hash.digest('hex')}` !== identityValue.sha256) {
        return null;
      }
    } finally {
      await finalHandle.close();
    }
    const canonicalEvidence = await realpath(absoluteEvidence);
    if (!contained(canonicalRoot, canonicalEvidence) || canonicalEvidence === canonicalRoot) {
      return null;
    }
    const reportRoot = path.dirname(reportPath);
    const reportDigest = createHash('sha256').update(path.resolve(reportPath)).digest('hex').slice(0, 16);
    const identityDigest = createHash('sha256').update(evidenceKey(identityValue)).digest('hex');
    const assetName = `.woostack-report-${reportDigest}-${identityDigest}${extension}`;
    const assetPath = path.join(reportRoot, assetName);
    let publicationIdentity;
    try {
      publicationIdentity = await publishCreateNew(assetPath, contents);
    } catch (error) {
      if (error?.code !== 'publication-committed') throw error;
      publicationIdentity = error.publicationIdentity;
    }
    publishedAssets.push({ path: assetPath, identity: publicationIdentity });
    return encodedRelativePath(assetName);
  } catch {
    return null;
  }
}

async function buildEvidenceHrefs(aggregate, options) {
  const hrefs = new Map();
  const publishedAssets = [];
  const budget = { remaining: BigInt(MAX_EVIDENCE_TOTAL_BYTES) };
  for (const identityValue of collectEvidenceIdentities(aggregate).values()) {
    hrefs.set(evidenceKey(identityValue), await verifiedEvidenceHref(
      path.dirname(options.aggregate),
      options.out,
      identityValue,
      budget,
      publishedAssets,
    ));
  }
  return { hrefs, publishedAssets };
}

function evidenceReference(identityValue, context) {
  const href = context.evidenceHrefs.get(evidenceKey(identityValue)) ?? null;
  const oversized = Object.hasOwn(identityValue, 'bytes')
    && identityValue.bytes > EVIDENCE_OVERSIZE_BYTES;
  const linkLabel = oversized ? 'Open oversized local evidence' : 'Open local evidence';
  const identityParts = [identityValue.path];
  if (Object.hasOwn(identityValue, 'sha256')) identityParts.push(identityValue.sha256);
  if (Object.hasOwn(identityValue, 'bytes')) identityParts.push(`${identityValue.bytes} bytes`);
  const access = href === null
    ? '<span class="evidence-note">Local evidence is missing or unsafe; identity only.</span>'
    : `<a href="${escapeHtml(href)}">${linkLabel}</a>`;
  return `${access}<span class="evidence-identity">${escapeHtml(identityParts.join(' · '))}</span>${oversized ? '<span class="evidence-note">Oversized local evidence is referenced, not embedded.</span>' : ''}`;
}

function observedReference(value, context) {
  if (value === null) return 'No observation';
  if (Object.hasOwn(value, 'sha256')) return evidenceReference(value, context);
  return `<span class="evidence-identity">${escapeHtml(value.path)}</span>`;
}

function comparisonRow(label, value, formatter = formatNumber) {
  if (value === UNAVAILABLE) {
    return `<tr><th scope="row">${escapeHtml(label)}</th><td colspan="3">Unavailable</td><td>Unavailable</td></tr>`;
  }
  return `<tr><th scope="row">${escapeHtml(label)}</th><td>${formatter(value.candidate)}</td><td>${formatter(value.baseline)}</td><td>${formatter(value.delta)}</td><td>${changeText(value.delta)}</td></tr>`;
}

function durationRow(label, value) {
  if (value === UNAVAILABLE) return comparisonRow(label, value);
  const candidate = value.candidate === UNAVAILABLE ? UNAVAILABLE : value.candidate.mean;
  const baseline = value.baseline === UNAVAILABLE ? UNAVAILABLE : value.baseline.mean;
  return comparisonRow(label, { candidate, baseline, delta: value.delta });
}

function renderTokenRows(value) {
  if (value === UNAVAILABLE) {
    return '<tr><th scope="row">Token usage</th><td colspan="4">Token telemetry unavailable</td></tr>';
  }
  return ['input', 'output', 'total'].map((field) => comparisonRow(
    `Token usage — ${field}`,
    {
      candidate: value.candidate[field] === UNAVAILABLE ? UNAVAILABLE : value.candidate[field].mean,
      baseline: value.baseline[field] === UNAVAILABLE ? UNAVAILABLE : value.baseline[field].mean,
      delta: value.delta[field],
    },
  )).join('\n');
}

function renderAssertion(assertion, context) {
  const state = assertion.pass === null ? 'Pending' : assertion.pass ? 'Pass' : 'Fail';
  const critical = assertion.critical ? ' · Critical' : '';
  const evidence = Object.hasOwn(assertion, 'observed')
    ? observedReference(assertion.observed, context)
    : [assertion.grade, assertion.graderReceipt, assertion.graderInput]
      .filter(Boolean)
      .map((item) => evidenceReference(item, context))
      .join('<br>') || 'No grade evidence';
  const rationale = Object.hasOwn(assertion, 'rationale') && assertion.rationale !== null
    ? `<p><strong>Rationale:</strong> ${escapeHtml(assertion.rationale)}</p>`
    : '';
  return `<li><strong>${escapeHtml(assertion.assertionId)}</strong> — ${state}${critical}${rationale}<div class="evidence">${evidence}</div></li>`;
}

function renderRun(result, context) {
  const status = titleCase(result.completionStatus);
  const selectedSkill = result.completionStatus === 'blocked'
    ? 'Unavailable'
    : result.selectedSkill === null ? 'Not applicable' : escapeHtml(result.selectedSkill);
  const assertions = result.assertions.length === 0
    ? 'No assertions'
    : `<ul class="assertions">${result.assertions.map((item) => renderAssertion(item, context)).join('')}</ul>`;
  if (result.completionStatus === 'blocked') {
    return `<tr><th scope="row">${result.repetition}</th><td><span class="status status-blocked">${status}</span></td><td>${selectedSkill}</td><td>Unavailable</td><td>Unavailable</td><td>No receipt</td><td>${assertions}</td></tr>`;
  }
  const tokens = result.tokenUsage === UNAVAILABLE ? 'Unavailable' : formatNumber(result.tokenUsage.total);
  const evidence = [result.receipt, result.output, result.transcript === UNAVAILABLE ? null : result.transcript]
    .filter(Boolean)
    .map((item) => evidenceReference(item, context))
    .join('<br>');
  return `<tr><th scope="row">${result.repetition}</th><td><span class="status status-complete">${status}</span></td><td>${selectedSkill}</td><td>${formatNumber(result.durationMs)}</td><td>${tokens}</td><td class="evidence">${evidence}</td><td>${assertions}</td></tr>`;
}

function renderVariant(entry, variant, context) {
  const results = entry[variant];
  if (results.length === 0) return `<p>${titleCase(variant)} evidence is unavailable.</p>`;
  return `<h4>${titleCase(variant)}</h4>
<table>
<caption>${escapeHtml(entry.caseId)} — ${titleCase(variant)} repetitions</caption>
<thead><tr><th scope="col">Repetition</th><th scope="col">Status</th><th scope="col">Selected skill</th><th scope="col">Duration (ms)</th><th scope="col">Tokens</th><th scope="col">Evidence</th><th scope="col">Assertions</th></tr></thead>
<tbody>${results.map((result) => renderRun(result, context)).join('\n')}</tbody>
</table>`;
}

function renderCase(entry, context) {
  const caseStatus = entry.candidate.some((result) => result.completionStatus === 'blocked')
    || entry.baseline.some((result) => result.completionStatus === 'blocked')
    ? 'blocked' : 'complete';
  return `<details>
<summary><h3><span class="status ${statusClass(caseStatus)}">${titleCase(caseStatus)}</span> ${escapeHtml(entry.caseId)} <span class="case-kind">(${escapeHtml(entry.kind)})</span></h3></summary>
<div class="case-content">
<table>
<caption>${escapeHtml(entry.caseId)} metrics</caption>
<thead><tr><th scope="col">Metric</th><th scope="col">Candidate</th><th scope="col">Baseline</th><th scope="col">Delta</th><th scope="col">Comparison</th></tr></thead>
<tbody>${comparisonRow('Objective pass rate', entry.objectivePassRate, formatRate)}${durationRow('Mean duration (ms)', entry.durationMs)}</tbody>
</table>
${renderVariant(entry, 'candidate', context)}
${renderVariant(entry, 'baseline', context)}
</div>
</details>`;
}

function renderCriticalFailures(failures) {
  if (failures.length === 0) return '<p>No critical assertion failures recorded.</p>';
  const rows = failures.map((failure) => `<tr><th scope="row">${escapeHtml(failure.caseId)}</th><td>${escapeHtml(failure.assertionId)}</td><td>${escapeHtml(failure.repetitions.candidate.join(', ') || 'None')}</td><td>${escapeHtml(failure.repetitions.baseline.join(', ') || 'None')}</td></tr>`).join('\n');
  return `<table>
<caption>Critical assertion failures</caption>
<thead><tr><th scope="col">Case</th><th scope="col">Assertion</th><th scope="col">Candidate repetitions</th><th scope="col">Baseline repetitions</th></tr></thead>
<tbody>${rows}</tbody>
</table>`;
}

function renderEvidenceErrors(errors) {
  if (errors.length === 0) return '<p>No evidence errors recorded.</p>';
  const rows = errors.map((error) => `<tr><th scope="row">${escapeHtml(error.code)}</th><td>${escapeHtml(error.field || '—')}</td><td>${escapeHtml(error.path || '—')}</td><td>${escapeHtml(error.message)}</td></tr>`).join('\n');
  return `<table>
<caption>Evidence errors</caption>
<thead><tr><th scope="col">Code</th><th scope="col">Field</th><th scope="col">Path</th><th scope="col">Message</th></tr></thead>
<tbody>${rows}</tbody>
</table>`;
}

function containsTriggerEvidence(aggregate) {
  return aggregate.cases.some((entry) => entry.kind === 'trigger');
}

function renderReport(aggregate, options) {
  const context = { evidenceHrefs: options.evidenceHrefs ?? new Map() };
  const executionStatus = titleCase(aggregate.executionStatus);
  const triggerMethodology = containsTriggerEvidence(aggregate)
    ? `<p>${TRIGGER_METHODOLOGY}</p>`
    : '';
  const cases = aggregate.cases.map((entry) => renderCase(entry, context)).join('\n');
  return `<!doctype html>
<html lang="en">
<head>
<meta http-equiv="Content-Security-Policy" content="${CSP}">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escapeHtml(aggregate.targetSkill)} evaluation report</title>
<style>
:root { color-scheme: light; font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; line-height: 1.5; }
body { margin: 0; color: #1b1b1b; background: #ffffff; }
main { max-width: 1120px; margin: 0 auto; padding: 2rem 1rem 4rem; }
h1, h2, h3, h4 { line-height: 1.2; }
h2 { margin-top: 2.25rem; border-bottom: 2px solid #d7d7d7; padding-bottom: .35rem; }
table { width: 100%; border-collapse: collapse; margin: 1rem 0 1.5rem; }
caption { text-align: left; font-weight: 700; padding: .4rem 0; }
th, td { border: 1px solid #b8b8b8; padding: .55rem; text-align: left; vertical-align: top; overflow-wrap: anywhere; }
thead th { background: #f1f3f5; }
.status { display: inline-block; border: 1px solid currentColor; border-radius: .25rem; padding: .1rem .45rem; font-weight: 700; }
.status-complete { color: #153e25; background: #e4f5e8; }
.status-blocked { color: #6b1515; background: #fde7e7; }
details { border: 1px solid #b8b8b8; border-radius: .3rem; margin: 1rem 0; }
summary { cursor: pointer; font-weight: 700; padding: .8rem; }
summary h3 { display: inline; margin: 0; font-size: 1.15rem; }
summary:focus-visible, a:focus-visible { outline: 3px solid #164e83; outline-offset: 2px; }
.case-content { padding: 0 .8rem .8rem; }
.case-kind { font-weight: 400; }
.evidence { min-width: 16rem; }
.evidence-identity, .evidence-note { display: block; margin-top: .2rem; font-family: ui-monospace, SFMono-Regular, Consolas, monospace; font-size: .82rem; overflow-wrap: anywhere; }
.evidence-note { font-family: inherit; font-weight: 600; }
.assertions { margin: 0; padding-left: 1.2rem; }
a { color: #164e83; text-decoration-thickness: .1em; }
</style>
</head>
<body>
<main>
<header>
<h1>Skill evaluation report</h1>
<p class="status ${statusClass(aggregate.executionStatus)}">Execution status: <strong>${executionStatus}</strong></p>
</header>
<section aria-labelledby="run-summary-heading">
<h2 id="run-summary-heading">Run summary</h2>
<table>
<caption>Evaluation identity</caption>
<tbody>
<tr><th scope="row">Run ID</th><td>${escapeHtml(aggregate.runId)}</td></tr>
<tr><th scope="row">Target skill</th><td>${escapeHtml(aggregate.targetSkill)}</td></tr>
<tr><th scope="row">Configured repetitions</th><td>${aggregate.runs}</td></tr>
<tr><th scope="row">Baseline</th><td>${escapeHtml(aggregate.baseline.kind)} · ${escapeHtml(aggregate.baseline.identity)}</td></tr>
</tbody>
</table>
</section>
<section aria-labelledby="overall-heading">
<h2 id="overall-heading">Overall metrics</h2>
${triggerMethodology}
<table>
<caption>Candidate and baseline comparison</caption>
<thead><tr><th scope="col">Metric</th><th scope="col">Candidate</th><th scope="col">Baseline</th><th scope="col">Delta</th><th scope="col">Comparison</th></tr></thead>
<tbody>
${comparisonRow('Objective pass rate', aggregate.overall.objectivePassRate, formatRate)}
${comparisonRow('Trigger precision', aggregate.overall.triggerPrecision, formatRate)}
${comparisonRow('Trigger recall', aggregate.overall.triggerRecall, formatRate)}
${durationRow('Mean duration (ms)', aggregate.overall.durationMs)}
${renderTokenRows(aggregate.overall.tokenUsage)}
</tbody>
</table>
${renderCriticalFailures(aggregate.overall.criticalFailures)}
</section>
<section aria-labelledby="cases-heading">
<h2 id="cases-heading">Cases</h2>
${cases}
</section>
<section aria-labelledby="errors-heading">
<h2 id="errors-heading">Evidence errors</h2>
${renderEvidenceErrors(aggregate.evidenceErrors)}
</section>
</main>
</body>
</html>
`;
}


function terminalField(value, maxBytes) {
  let cleaned = cleanText(value).replace(/\s+/g, ' ').trim();
  while (Buffer.byteLength(cleaned, 'utf8') > maxBytes) cleaned = cleaned.slice(0, -1);
  return cleaned;
}

function terminalSummary(aggregate, options) {
  const summary = [
    `Execution status: ${aggregate.executionStatus}`,
    ...(containsTriggerEvidence(aggregate) ? [`Methodology: ${TRIGGER_METHODOLOGY}`] : []),
    `Aggregate: ${terminalField(options.aggregate, 360)}`,
    `Report: ${terminalField(options.out, 360)}`,
    `Cases: ${aggregate.cases.length}`,
  ].join('\n') + '\n';
  if (Buffer.byteLength(summary, 'utf8') > 1024) throw new Error('terminal summary exceeded its byte limit');
  return summary;
}

function sanitizeError(value) {
  const cleaned = cleanText(value).replace(/\s+/g, ' ').trim() || 'Report rendering failed';
  return terminalField(cleaned, 400);
}

async function main(argv) {
  const options = parseArguments(argv);
  const aggregate = validateAggregate(await readAggregate(options.aggregate));
  if (options.terminal) process.stdout.write(terminalSummary(aggregate, options));
  const { hrefs: evidenceHrefs, publishedAssets } = await buildEvidenceHrefs(aggregate, options);
  try {
    const report = renderReport(aggregate, { evidenceHrefs });
    await publishCreateNew(options.out, report);
  } catch (error) {
    if (error?.code === 'publication-committed') throw error;
    const failures = [error];
    for (const asset of publishedAssets.reverse()) {
      try {
        await rollbackCreateNew(asset.path, asset.identity);
      } catch (rollbackError) {
        failures.push(rollbackError);
      }
    }
    if (failures.length > 1) {
      throw new AggregateError(failures, 'report publication and evidence rollback failed');
    }
    throw error;
  }
}

const entrypoint = process.argv[1] ? path.resolve(process.argv[1]) : null;
if (entrypoint && fileURLToPath(import.meta.url) === entrypoint) {
  main(process.argv.slice(2)).catch((error) => {
    process.stderr.write(`render-report: ${sanitizeError(error?.message ?? error)}\n`);
    process.exitCode = 1;
  });
}

export {
  main as runRenderReportCli,
  publishCreateNew,
  renderReport,
  validateAggregate,
};
