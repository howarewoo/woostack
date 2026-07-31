#!/usr/bin/env bash
set -euo pipefail

ROOT=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)
VALIDATOR="$ROOT/skills/woostack-eval/scripts/validate.mjs"
NODE=${NODE:-node}
TMP_ROOT=$(mktemp -d "$ROOT/.woostack-oracle-isolation.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM

"$NODE" - "$TMP_ROOT" "$VALIDATOR" <<'NODE'
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const [root, validator] = process.argv.slice(2);
const values = ['secret', false, 7, null, [1, null], { decision: 'deny' }];
const kinds = ['final-json-path-equals', 'json-path-equals', 'receipt-field-equals'];

function writePackage(name, cases, fixtures) {
  const packageRoot = path.join(root, name);
  fs.mkdirSync(path.join(packageRoot, 'evals', 'fixtures'), { recursive: true });
  fs.mkdirSync(path.join(packageRoot, 'references'), { recursive: true });
  fs.writeFileSync(path.join(packageRoot, 'SKILL.md'), `---\nname: ${name}\ndescription: Oracle isolation contract.\n---\n# ${name}\n\n[Guide](references/guide.md)\n`);
  fs.writeFileSync(path.join(packageRoot, 'references', 'guide.md'), '# Guide\n');
  fs.writeFileSync(path.join(packageRoot, 'evals', 'evals.json'), `${JSON.stringify({ schemaVersion: 1, skill: name, cases })}\n`);
  for (const [fixture, value] of Object.entries(fixtures)) {
    fs.writeFileSync(path.join(packageRoot, 'evals', 'fixtures', fixture), `${JSON.stringify(value)}\n`);
  }
  return packageRoot;
}

function validate(packageRoot) {
  const result = spawnSync(process.execPath, [validator, '--package', packageRoot, '--repository-root', root, '--json'], { encoding: 'utf8' });
  if (!result.stdout) throw new Error(result.stderr || `validator produced no JSON for ${packageRoot}`);
  return JSON.parse(result.stdout);
}

function assertion(kind, id, pointer, expected) {
  const value = { id, kind, pointer, expected };
  if (kind === 'json-path-equals') value.file = 'result.json';
  return value;
}

const scopedCases = [];
const scopedFixtures = {};
for (const [kindIndex, kind] of kinds.entries()) {
  for (const [valueIndex, expected] of values.entries()) {
    const id = `scoped-${kindIndex}-${valueIndex}`;
    const fixture = `${id}.json`;
    scopedFixtures[fixture] = { raw: { verdict: expected }, leaked: { verdict: expected } };
    scopedCases.push({
      id,
      prompt: 'Derive the verdict',
      fixtures: [fixture],
      fixturePassthroughAssertions: [{ assertionId: id, fixture, pointer: '/raw/verdict' }],
      expected: 'Keep only the declared raw location public',
      assertions: [assertion(kind, id, '/verdict', expected)],
    });
  }
}
const scoped = validate(writePackage('scoped-declaration-matrix', scopedCases, scopedFixtures));
for (let index = 0; index < scopedCases.length; index += 1) {
  if (!scoped.errors.some((error) =>
    error.code === 'corpus-fixture-output-oracle'
    && error.field === `/cases/${index}/fixtures/0`)) {
    throw new Error(`scoped declaration bypass accepted for ${scopedCases[index].id}`);
  }
}

const semanticAliases = ['classification', 'label', 'outcome', 'scenario'];
const aliasCases = [];
const aliasFixtures = {};
const legitimateAliasCases = [];
const legitimateAliasFixtures = {};
for (const [kindIndex, kind] of kinds.entries()) {
  for (const [valueIndex, expected] of values.entries()) {
    for (const assertionAlias of semanticAliases) {
      for (const fixtureAlias of semanticAliases) {
        if (fixtureAlias === assertionAlias) continue;
        const id = `alias-${kindIndex}-${valueIndex}-${assertionAlias}-${fixtureAlias}`;
        const fixture = `${id}.json`;
        aliasFixtures[fixture] = {
          raw: { [fixtureAlias]: expected },
          leaked: { [fixtureAlias]: expected },
        };
        aliasCases.push({
          id,
          prompt: `Derive the ${assertionAlias}`,
          fixtures: [fixture],
          fixturePassthroughAssertions: [{
            assertionId: id,
            fixture,
            pointer: `/raw/${fixtureAlias}`,
          }],
          expected: 'Keep aliases private outside the exact declared raw location',
          assertions: [assertion(kind, id, `/${assertionAlias}`, expected)],
        });

        const legitimateId = `legitimate-${id}`;
        const legitimateFixture = `${legitimateId}.json`;
        legitimateAliasFixtures[legitimateFixture] = { raw: { [fixtureAlias]: expected } };
        legitimateAliasCases.push({
          id: legitimateId,
          prompt: 'Return exact raw alias evidence',
          fixtures: [legitimateFixture],
          fixturePassthroughAssertions: [{
            assertionId: legitimateId,
            fixture: legitimateFixture,
            pointer: `/raw/${fixtureAlias}`,
          }],
          expected: 'Echo only the exact declared raw alias location',
          assertions: [assertion(kind, legitimateId, `/${assertionAlias}`, expected)],
        });
      }
    }
  }
}
const aliases = validate(writePackage('alias-declaration-matrix', aliasCases, aliasFixtures));
for (let index = 0; index < aliasCases.length; index += 1) {
  if (!aliases.errors.some((error) =>
    error.code === 'corpus-fixture-output-oracle'
    && error.field === `/cases/${index}/fixtures/0`)) {
    throw new Error(`alias declaration bypass accepted for ${aliasCases[index].id}`);
  }
}
const legitimateAliases = validate(writePackage(
  'legitimate-alias-declaration-matrix',
  legitimateAliasCases,
  legitimateAliasFixtures,
));
if (!legitimateAliases.valid) {
  throw new Error(`legitimate alias declaration matrix rejected: ${JSON.stringify(legitimateAliases.errors)}`);
}

const legitimateCases = [];
const legitimateFixtures = {};
for (const [kindIndex, kind] of kinds.entries()) {
  for (const [valueIndex, expected] of values.entries()) {
    const id = `legitimate-${kindIndex}-${valueIndex}`;
    const fixture = `${id}.json`;
    legitimateFixtures[fixture] = { raw: { verdict: expected } };
    legitimateCases.push({
      id,
      prompt: 'Return raw evidence',
      fixtures: [fixture],
      fixturePassthroughAssertions: [{ assertionId: id, fixture, pointer: '/raw/verdict' }],
      expected: 'Echo the declared raw location',
      assertions: [assertion(kind, id, '/verdict', expected)],
    });
  }
}
const legitimate = validate(writePackage('legitimate-declaration-matrix', legitimateCases, legitimateFixtures));
if (!legitimate.valid) throw new Error(`legitimate declaration matrix rejected: ${JSON.stringify(legitimate.errors)}`);

const wholeLegitimateCases = [];
const wholeLegitimateFixtures = {};
for (const [kindIndex, kind] of kinds.entries()) {
  for (const [valueIndex, expected] of values.entries()) {
    const id = `whole-legitimate-${kindIndex}-${valueIndex}`;
    const fixture = `${id}.json`;
    wholeLegitimateFixtures[fixture] = expected;
    wholeLegitimateCases.push({
      id,
      prompt: 'Return complete raw evidence',
      fixtures: [fixture],
      fixturePassthroughAssertions: [{ assertionId: id, fixture, pointer: '' }],
      expected: 'Echo the exact root evidence',
      assertions: [assertion(kind, id, '', expected)],
    });
  }
}
const wholeLegitimate = validate(writePackage(
  'whole-legitimate-declaration-matrix',
  wholeLegitimateCases,
  wholeLegitimateFixtures,
));
if (!wholeLegitimate.valid) {
  throw new Error(`whole legitimate declaration matrix rejected: ${JSON.stringify(wholeLegitimate.errors)}`);
}

const wholeCases = [];
const wholeFixtures = {};
for (const [kindIndex, kind] of kinds.entries()) {
  for (const [valueIndex, expected] of values.entries()) {
    const id = `whole-${kindIndex}-${valueIndex}`;
    const fixture = `${id}.json`;
    wholeFixtures[fixture] = { arbitrary: { nested: expected } };
    wholeCases.push({
      id,
      prompt: 'Derive the whole document',
      fixtures: [fixture],
      expected: 'Keep the complete output private',
      assertions: [assertion(kind, id, '', expected)],
    });
  }
}
const whole = validate(writePackage('whole-document-matrix', wholeCases, wholeFixtures));
for (let index = 0; index < wholeCases.length; index += 1) {
  if (!whole.errors.some((error) => error.code === 'corpus-fixture-output-oracle' && error.field === `/cases/${index}/fixtures/0`)) {
    throw new Error(`whole-document oracle accepted for ${wholeCases[index].id}`);
  }
}

const assertionTransferCases = [];
const assertionTransferFixtures = {};
const assertionTransferValidCases = [];
for (const [kindIndex, kind] of kinds.entries()) {
  for (const [valueIndex, expected] of values.entries()) {
    const caseId = `assertion-transfer-${kindIndex}-${valueIndex}`;
    const fixture = `${caseId}.json`;
    const firstId = `${caseId}-first`;
    const secondId = `${caseId}-second`;
    assertionTransferFixtures[fixture] = { raw: { verdict: expected } };
    const common = {
      id: caseId,
      prompt: 'Return raw evidence',
      fixtures: [fixture],
      expected: 'Require each matching assertion boundary to be declared',
      assertions: [
        assertion(kind, firstId, '/verdict', expected),
        assertion(kind, secondId, '/verdict', expected),
      ],
    };
    assertionTransferCases.push({
      ...common,
      fixturePassthroughAssertions: [
        { assertionId: firstId, fixture, pointer: '/raw/verdict' },
      ],
    });
    assertionTransferValidCases.push({
      ...common,
      fixturePassthroughAssertions: [
        { assertionId: firstId, fixture, pointer: '/raw/verdict' },
        { assertionId: secondId, fixture, pointer: '/raw/verdict' },
      ],
    });
  }
}
const assertionTransfer = validate(writePackage(
  'assertion-id-transfer-matrix',
  assertionTransferCases,
  assertionTransferFixtures,
));
for (let index = 0; index < assertionTransferCases.length; index += 1) {
  if (!assertionTransfer.errors.some((error) =>
    error.code === 'corpus-fixture-output-oracle'
    && error.field === `/cases/${index}/fixtures/0`)) {
    throw new Error(`first assertion declaration authorized second for ${assertionTransferCases[index].id}`);
  }
}
const assertionTransferValid = validate(writePackage(
  'assertion-id-exact-matrix',
  assertionTransferValidCases,
  assertionTransferFixtures,
));
if (!assertionTransferValid.valid) {
  throw new Error(`exact assertion declarations rejected: ${JSON.stringify(assertionTransferValid.errors)}`);
}

const wholeAssertionTransferCases = [];
const wholeAssertionTransferFixtures = {};
const wholeAssertionTransferValidCases = [];
for (const [kindIndex, kind] of kinds.entries()) {
  for (const [valueIndex, expected] of values.entries()) {
    const caseId = `whole-assertion-transfer-${kindIndex}-${valueIndex}`;
    const fixture = `${caseId}.json`;
    const firstId = `${caseId}-first`;
    const secondId = `${caseId}-second`;
    wholeAssertionTransferFixtures[fixture] = expected;
    const common = {
      id: caseId,
      prompt: 'Return complete raw evidence',
      fixtures: [fixture],
      expected: 'Require each matching whole-document assertion boundary to be declared',
      assertions: [
        assertion(kind, firstId, '', expected),
        assertion(kind, secondId, '', expected),
      ],
    };
    wholeAssertionTransferCases.push({
      ...common,
      fixturePassthroughAssertions: [{ assertionId: firstId, fixture, pointer: '' }],
    });
    wholeAssertionTransferValidCases.push({
      ...common,
      fixturePassthroughAssertions: [
        { assertionId: firstId, fixture, pointer: '' },
        { assertionId: secondId, fixture, pointer: '' },
      ],
    });
  }
}
const wholeAssertionTransfer = validate(writePackage(
  'whole-assertion-id-transfer-matrix',
  wholeAssertionTransferCases,
  wholeAssertionTransferFixtures,
));
for (let index = 0; index < wholeAssertionTransferCases.length; index += 1) {
  if (!wholeAssertionTransfer.errors.some((error) =>
    error.code === 'corpus-fixture-output-oracle'
    && error.field === `/cases/${index}/fixtures/0`)) {
    throw new Error(`whole-document declaration authorized second assertion for ${wholeAssertionTransferCases[index].id}`);
  }
}
const wholeAssertionTransferValid = validate(writePackage(
  'whole-assertion-id-exact-matrix',
  wholeAssertionTransferValidCases,
  wholeAssertionTransferFixtures,
));
if (!wholeAssertionTransferValid.valid) {
  throw new Error(`exact whole-document declarations rejected: ${JSON.stringify(wholeAssertionTransferValid.errors)}`);
}

const fixtureScoped = validate(writePackage('fixture-scoped-declaration', [{
  id: 'fixture-scoped', prompt: 'Derive', fixtures: ['a.json', 'b.json'],
  fixturePassthroughAssertions: [
    { assertionId: 'verdict', fixture: 'a.json', pointer: '/raw/verdict' },
  ], expected: 'Only a.json is raw evidence',
  assertions: [assertion('final-json-path-equals', 'verdict', '/verdict', 'secret')],
}], {
  'a.json': { raw: { verdict: 'secret' } },
  'b.json': { raw: { verdict: 'secret' } },
}));
if (fixtureScoped.valid || !fixtureScoped.errors.some((error) =>
  error.code === 'corpus-fixture-output-oracle' && error.field === '/cases/0/fixtures/1')) {
  throw new Error('declaration for one fixture authorized the same pointer in another fixture');
}

const pointerScoped = validate(writePackage('pointer-scoped-declaration', [{
  id: 'pointer-scoped', prompt: 'Derive', fixtures: ['a.json'],
  fixturePassthroughAssertions: [
    { assertionId: 'first', fixture: 'a.json', pointer: '/raw/first' },
  ], expected: 'Only the first exact tuple is raw evidence',
  assertions: [
    assertion('final-json-path-equals', 'first', '/first', 'secret'),
    assertion('final-json-path-equals', 'second', '/second', 'secret'),
  ],
}], { 'a.json': { raw: { first: 'secret', second: 'secret' } } }));
if (pointerScoped.valid || !pointerScoped.errors.some((error) =>
  error.code === 'corpus-fixture-output-oracle' && error.field === '/cases/0/fixtures/0')) {
  throw new Error('declaration for the first pointer authorized the second assertion pointer');
}

const controls = [
  ['mismatch', { assertionId: 'verdict', fixture: 'a.json', pointer: '/raw/verdict' }, { raw: { verdict: 'other' } }, ['a.json']],
  ['unused', { assertionId: 'verdict', fixture: 'a.json', pointer: '/raw/other' }, { raw: { verdict: 'secret', other: 'secret' } }, ['a.json']],
  ['wrong-fixture', { assertionId: 'verdict', fixture: 'b.json', pointer: '/raw/verdict' }, { raw: { verdict: 'secret' } }, ['a.json']],
];
for (const [name, declaration, fixtureValue, fixtures] of controls) {
  const result = validate(writePackage(`declaration-${name}`, [{
    id: name, prompt: 'Derive', fixtures, fixturePassthroughAssertions: [declaration], expected: 'Derive',
    assertions: [assertion('final-json-path-equals', 'verdict', '/verdict', 'secret')],
  }], { 'a.json': fixtureValue, 'b.json': fixtureValue }));
  if (result.valid || !result.errors.some((error) => error.code === 'corpus-invalid-fixture-passthrough')) {
    throw new Error(`${name} declaration control accepted`);
  }
}
const duplicate = validate(writePackage('declaration-duplicate', [{
  id: 'duplicate', prompt: 'Derive', fixtures: ['a.json'],
  fixturePassthroughAssertions: [
    { assertionId: 'verdict', fixture: 'a.json', pointer: '/raw/verdict' },
    { assertionId: 'verdict', fixture: 'a.json', pointer: '/raw/verdict' },
  ], expected: 'Derive', assertions: [assertion('final-json-path-equals', 'verdict', '/verdict', 'secret')],
}], { 'a.json': { raw: { verdict: 'secret' } } }));
if (duplicate.valid || !duplicate.errors.some((error) => error.code === 'corpus-duplicate-value')) {
  throw new Error('duplicate declaration accepted');
}
console.log('test-oracle-isolation: ok');
NODE
