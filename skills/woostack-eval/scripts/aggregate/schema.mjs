import {
  KEBAB,
  MAX_RUNS,
  RUN_ID,
  SHA256,
  VARIANTS,
  WORKER_KINDS,
  baselineIdentityValid,
  caseIdValid,
  compareText,
  completionIdentityValid,
  isObject,
  exactKeys,
  nonEmptyString,
  optionalString,
  same,
} from './contracts.mjs';

function expectedKey(value) {
  return `${value.kind}\u0000${value.caseId}\u0000${value.variant}\u0000${value.repetition}`;
}

function requireManifest(manifest) {
  const manifestFields = [
    'schemaVersion', 'runId', 'targetSkill', 'mode', 'runs', 'baseline',
    'runConfiguration', 'originalPackageHash', 'packageHashes', 'gradingPlan',
    'expected', 'pairs',
  ];
  if (!exactKeys(manifest, manifestFields) || manifest.schemaVersion !== 2) {
    throw new Error('manifest must be a schemaVersion 2 object with the canonical key set');
  }
  if (typeof manifest.runId !== 'string' || !RUN_ID.test(manifest.runId)
    || manifest.runId === '.' || manifest.runId === '..'
    || typeof manifest.targetSkill !== 'string' || !KEBAB.test(manifest.targetSkill)
    || typeof manifest.originalPackageHash !== 'string'
    || !SHA256.test(manifest.originalPackageHash)) {
    throw new Error('manifest identity is invalid');
  }
  if (!['behavior', 'triggers', 'all'].includes(manifest.mode)
    || !Number.isSafeInteger(manifest.runs) || manifest.runs < 1 || manifest.runs > MAX_RUNS) {
    throw new Error('manifest run selection is invalid');
  }
  if (!baselineIdentityValid(manifest.baseline)) {
    throw new Error('manifest baseline is invalid');
  }
  if (!exactKeys(manifest.packageHashes, ['candidate', 'baseline'])
    || !SHA256.test(manifest.packageHashes.candidate ?? '')
    || (manifest.baseline.kind === 'none'
      ? manifest.packageHashes.baseline !== null
      : !SHA256.test(manifest.packageHashes.baseline ?? ''))
    || (manifest.baseline.kind === 'path'
      && manifest.packageHashes.baseline !== manifest.baseline.identity)) {
    throw new Error('manifest package hashes are invalid');
  }
  const configurationFields = [
    'host', 'isolationAssurance', 'runner', 'model', 'sessionIdentity', 'tier', 'effort',
  ];
  if (!exactKeys(manifest.runConfiguration, configurationFields)
    || !nonEmptyString(manifest.runConfiguration.host)
    || !['enforced', 'advisory'].includes(manifest.runConfiguration.isolationAssurance)
    || !nonEmptyString(manifest.runConfiguration.runner)
    || !completionIdentityValid(manifest.runConfiguration)
    || !optionalString(manifest.runConfiguration.tier)
    || !optionalString(manifest.runConfiguration.effort)) {
    throw new Error('manifest run configuration is invalid');
  }
  if (!Array.isArray(manifest.expected)
    || !Array.isArray(manifest.pairs)
    || !Array.isArray(manifest.gradingPlan)) {
    throw new Error('manifest expected set is invalid');
  }

  const identities = new Set();
  const expectedPairs = new Set();
  const expectedShapes = new Map();
  const expectedCases = new Map();
  for (const item of manifest.expected) {
    if (!exactKeys(item, ['caseId', 'variant', 'repetition', 'kind'])
      || !caseIdValid(item.caseId) || !WORKER_KINDS.has(item.kind)
      || (manifest.mode === 'behavior' && item.kind !== 'behavior')
      || (manifest.mode === 'triggers' && item.kind !== 'trigger')
      || !VARIANTS.includes(item.variant) || !Number.isSafeInteger(item.repetition)
      || item.repetition < 1 || item.repetition > manifest.runs) {
      throw new Error('manifest contains an invalid expected identity');
    }
    const key = expectedKey(item);
    if (identities.has(key)) throw new Error('manifest contains duplicate expected identities');
    identities.add(key);
    const pairKey = `${item.caseId}\u0000${item.repetition}`;
    expectedPairs.add(pairKey);
    const shape = expectedShapes.get(pairKey) ?? { kind: item.kind, variants: new Set() };
    if (shape.kind !== item.kind) throw new Error('manifest contains kind drift within a pair');
    shape.variants.add(item.variant);
    expectedShapes.set(pairKey, shape);
    const expectedCase = expectedCases.get(item.caseId)
      ?? { kind: item.kind, repetitions: new Set() };
    if (expectedCase.kind !== item.kind) {
      throw new Error('manifest contains kind drift for one case');
    }
    expectedCase.repetitions.add(item.repetition);
    expectedCases.set(item.caseId, expectedCase);
  }
  if (manifest.expected.length === 0) throw new Error('manifest expected set is empty');
  const manifestModes = new Set();
  for (const shape of expectedShapes.values()) {
    const variants = [...shape.variants].sort().join(',');
    if (variants !== 'candidate' && variants !== 'baseline,candidate') {
      throw new Error('manifest expected pairs must include candidate evidence');
    }
    manifestModes.add(variants);
  }
  if (manifestModes.size !== 1) {
    throw new Error('manifest expected set must be uniformly paired or candidate-only');
  }
  const candidateOnly = manifestModes.has('candidate');
  if (candidateOnly
    && [...expectedCases.values()].some((expectedCase) => expectedCase.kind !== 'behavior')) {
    throw new Error('candidate-only manifest must contain behavior cases only');
  }
  if (manifest.runConfiguration.isolationAssurance === 'advisory' && !candidateOnly) {
    throw new Error('advisory manifest must be candidate-only');
  }

  const repetitions = Array.from({ length: manifest.runs }, (_, index) => index + 1);
  for (const expectedCase of expectedCases.values()) {
    if (!same([...expectedCase.repetitions].sort((left, right) => left - right), repetitions)) {
      throw new Error('manifest expected set is incomplete for configured runs');
    }
  }
  const orderedCases = [...expectedCases.entries()].sort(([leftId, left], [rightId, right]) =>
    Number(left.kind === 'trigger') - Number(right.kind === 'trigger')
    || compareText(leftId, rightId));
  const expectedVariants = manifestModes.has('candidate') ? ['candidate'] : VARIANTS;
  const canonicalExpectedKeys = orderedCases.flatMap(([caseId, expectedCase]) =>
    repetitions.flatMap((repetition) =>
      expectedVariants.map((variant) => expectedKey({
        kind: expectedCase.kind,
        caseId,
        variant,
        repetition,
      }))));
  if (!same(manifest.expected.map(expectedKey), canonicalExpectedKeys)) {
    throw new Error('manifest expected identities are not in canonical order');
  }

  const pairKeys = new Set();
  const orderedPairKeys = [];
  for (const pair of manifest.pairs) {
    const canonicalRoot = caseIdValid(pair?.caseId) && Number.isSafeInteger(pair?.repetition)
      ? `cases/${pair.caseId}/${pair.repetition}`
      : null;
    if (!exactKeys(pair, ['caseId', 'repetition', 'candidate', 'baseline'])
      || !caseIdValid(pair.caseId) || !Number.isSafeInteger(pair.repetition)
      || pair.repetition < 1 || pair.repetition > manifest.runs
      || pair.candidate !== `${canonicalRoot}/candidate`
      || pair.baseline !== `${canonicalRoot}/baseline`) {
      throw new Error('manifest contains an invalid workspace pair');
    }
    const key = `${pair.caseId}\u0000${pair.repetition}`;
    if (pairKeys.has(key)) throw new Error('manifest contains duplicate workspace pairs');
    pairKeys.add(key);
    orderedPairKeys.push(key);
  }
  const canonicalPairKeys = orderedCases.flatMap(([caseId]) =>
    repetitions.map((repetition) => `${caseId}\u0000${repetition}`));
  if (!same([...pairKeys].sort(), [...expectedPairs].sort())) {
    throw new Error('manifest workspace pairs do not exactly match the expected set');
  }
  if (!same(orderedPairKeys, canonicalPairKeys)) {
    throw new Error('manifest workspace pairs are not in canonical order');
  }
}

export {
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
};
