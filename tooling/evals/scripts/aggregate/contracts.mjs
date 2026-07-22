import { isDeepStrictEqual } from 'node:util';

const VARIANTS = ['candidate', 'baseline'];
const WORKER_KINDS = new Set(['behavior', 'trigger']);
const CAPABILITIES = new Set(['read-workspace', 'write-workspace', 'shell-workspace']);
const COMPLETION_STATUSES = new Set(['complete', 'failed', 'timed-out']);
const SHA256 = /^sha256:[0-9a-f]{64}$/;
const KEBAB = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
const RUN_ID = /^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/;
const GIT_COMMIT = /^[0-9a-f]{40}$/;
const ABSENT_BASELINE = /^[0-9a-f]{40}:absent$/;
const MAX_CASE_ID_BYTES = 64;
const MAX_RUNS = 10;

function isObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function same(left, right) {
  return isDeepStrictEqual(left, right);
}

function exactKeys(value, fields) {
  return isObject(value) && same(Object.keys(value).sort(), [...fields].sort());
}

function nonEmptyString(value) {
  return typeof value === 'string' && value.length > 0;
}

function optionalString(value) {
  return value === null || typeof value === 'string';
}

function caseIdValid(value) {
  return typeof value === 'string'
    && Buffer.byteLength(value, 'utf8') <= MAX_CASE_ID_BYTES
    && KEBAB.test(value);
}

function baselineIdentityValid(baseline) {
  if (!exactKeys(baseline, ['kind', 'identity']) || typeof baseline.identity !== 'string') {
    return false;
  }
  if (baseline.kind === 'git-ref') return GIT_COMMIT.test(baseline.identity);
  if (baseline.kind === 'path') return SHA256.test(baseline.identity);
  return baseline.kind === 'none' && ABSENT_BASELINE.test(baseline.identity);
}

function completionIdentityValid(receipt) {
  return (nonEmptyString(receipt.model) && receipt.sessionIdentity === null)
    || (nonEmptyString(receipt.sessionIdentity) && receipt.model === null);
}

function sanitizeMessage(value) {
  return String(value)
    .replace(/[\u0000-\u001f\u007f]/g, ' ')
    .replace(/\s+/g, ' ')
    .slice(0, 240)
    .trim() || 'Aggregation failed';
}

function compareText(left, right) {
  return left < right ? -1 : left > right ? 1 : 0;
}

export {
  ABSENT_BASELINE,
  CAPABILITIES,
  COMPLETION_STATUSES,
  GIT_COMMIT,
  KEBAB,
  MAX_CASE_ID_BYTES,
  MAX_RUNS,
  RUN_ID,
  SHA256,
  VARIANTS,
  WORKER_KINDS,
  baselineIdentityValid,
  caseIdValid,
  compareText,
  completionIdentityValid,
  exactKeys,
  isObject,
  nonEmptyString,
  optionalString,
  sanitizeMessage,
  same,
};
