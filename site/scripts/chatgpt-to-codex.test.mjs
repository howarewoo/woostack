import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';

// This inspects authored mock receipts. It does not run a planner, model, HTTP client, or CLI.
const fixture = JSON.parse(readFileSync(new URL('./fixtures/chatgpt-to-codex.json', import.meta.url), 'utf8'));
const guide = readFileSync(new URL(fixture.prompt.path, import.meta.url), 'utf8');
const prompt = guide.split(`${fixture.prompt.fence}\n`)[1]?.split('\n```')[0];
const api = '/repos/woostack-fixture/catalog/issues';
const keys = ['P', 'A', 'B', 'C', 'D'];
const number = (key) => 101 + keys.indexOf(key);
const id = (key) => 9101 + keys.indexOf(key);
const url = (key) => `${fixture.repository.url}/issues/${number(key)}`;

function expand(value) {
  if (Array.isArray(value)) return value.map(expand);
  if (!value || typeof value !== 'object') return value;
  if ('$body' in value) {
    assert.ok(Object.hasOwn(fixture.bodyPool, value.$body), `Missing body ${value.$body}`);
    return fixture.bodyPool[value.$body];
  }
  return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, expand(item)]));
}

function operations(scenario) {
  if (scenario === fixture) return expand(fixture.operations);
  return expand([
    ...(scenario.useSuccess ? fixture.operations : fixture.operations.slice(0, scenario.prefixThrough ?? 0)),
    ...scenario.operations,
    ...(scenario.resumeFrom === undefined ? [] : fixture.operations.slice(scenario.resumeFrom)),
  ]);
}

// Only the recorded anonymous, parameterized query form is admitted as a GraphQL read.
const isWrite = ({ request }) => request.method !== 'GET' && !(
  request.path === '/graphql' && /^\s*query\s*\(/.test(request.json?.query ?? '') &&
  request.json.operationName == null
);
const writes = (ops) => ops.filter(isWrite);
const variant = (name) => {
  const found = fixture.variants.find((item) => item.name === name);
  assert.ok(found, `Missing fixture scenario ${name}`);
  return found;
};

function readPages(ops, start) {
  assert.ok(start >= 0, 'Missing discovery or collection');
  const items = [];
  let index = start;
  while (true) {
    const event = ops[index];
    assert.equal(event.response.status, 200);
    items.push(...event.response.json);
    if (event.response.next === null) break;
    assert.equal(typeof event.response.next, 'string', 'Terminal pagination evidence is required');
    index = ops.findIndex((e, n) => n > index && e.request.method === 'GET' && e.request.path === event.response.next);
    assert.ok(index >= 0, `Unfetched page ${event.response.next}`);
  }
  return { items, lastIndex: index };
}

function assertNativeParent(ops, key, restIssue) {
  const parent = ops.filter((e) => e.request.path === '/graphql' && e.request.json.variables.number === number(key)).at(-1);
  assert.equal(parent?.response.status, 200);
  const scope = parent.request.json.variables;
  assert.equal(`https://github.com/${scope.owner}/${scope.repo}`, fixture.repository.url, 'Foreign parent-query scope');
  assert.deepEqual(parent.response.json.errors ?? [], [], 'GraphQL parent read failed');
  assert.equal(typeof restIssue.node_id, 'string', 'Missing independent REST node identity');
  assert.ok(restIssue.node_id);
  const subject = parent.response.json.data?.repository?.issue;
  assert.equal(subject?.id, restIssue.node_id, 'Native parent read targets another issue');
  assert.deepEqual(subject.parent, key === 'P' ? null : { id: 'I_fixture_P', number: 101, url: url('P') });
}

function inspectParentRecovery(ops) {
  const failed = ops.findIndex((e) => e.creationKey === fixture.markers.P);
  assert.ok(failed >= 0);
  assert.equal(ops[failed].response.status, null);
  const nextWrite = ops.findIndex((e, index) => index > failed && isWrite(e));
  const window = ops.slice(failed + 1, nextWrite < 0 ? undefined : nextWrite);
  const start = window.findIndex((e) => e.request.method === 'GET' && e.request.path.startsWith(`${api}?state=all&`) && e.request.path.endsWith('page=1'));
  const discovery = readPages(window, start);
  const marker = `<!-- woostack-issue-mutation:${fixture.markers.P} -->`;
  const matches = discovery.items.filter((item) => typeof item.body === 'string' && item.body.includes(marker));
  if (nextWrite >= 0) {
    assert.equal(matches.length, 1, 'Resumed writes require unique complete discovery');
    const found = matches[0];
    assert.equal(found.html_url, url('P'));
    assert.equal(found.id, id('P'));
    assert.equal(found.number, number('P'));
    assert.equal(found.state, 'open');
    assert.equal(found.pull_request, undefined);
    assert.equal(found.title, ops[failed].request.json.title);
    assert.equal(found.body, ops[failed].request.json.body);
    const readIndex = window.findIndex((e, index) => index > discovery.lastIndex && e.request.method === 'GET' && e.request.path === `${api}/${number('P')}`);
    assert.ok(readIndex >= 0, 'Missing independent recovered-identity read-back');
    const readback = window[readIndex];
    assert.equal(readback.response.status, 200);
    for (const field of ['id', 'node_id', 'number', 'html_url', 'state', 'title', 'body']) {
      assert.deepEqual(readback.response.json[field], found[field], `Recovered ${field} differs`);
    }
    assertNativeParent(window.slice(readIndex + 1), 'P', readback.response.json);
  }
  return matches;
}

function assertReadyReadBack(ops, result) {
  assert.equal(result.status, 'ready');
  // Only inspect the last complete read-back, not a second workflow state machine.
  const lastBody = (key) => ops.filter((e) => e.request.method === 'GET' && e.request.path === `${api}/${number(key)}`).at(-1);
  for (const key of keys) {
    const receipt = lastBody(key);
    assert.equal(receipt?.response.status, 200);
    assert.equal(receipt.response.json.id, id(key));
    assert.equal(receipt.response.json.html_url, url(key));
    assert.equal(receipt.response.json.body, fixture.bodyPool[key]);
    assertNativeParent(ops, key, receipt.response.json);
  }

  function collection(path) {
    const start = ops.findLastIndex((e) => e.request.method === 'GET' && e.request.path.startsWith(path) && e.request.path.endsWith('page=1'));
    return readPages(ops, start).items.map((item) => item.id).sort((a, b) => a - b);
  }

  assert.deepEqual(collection(`${api}/101/sub_issues?`), ['A', 'B', 'C', 'D'].map(id));
  for (const key of keys.slice(1)) {
    const expectedBefore = fixture.final.edges.filter(([, after]) => after === key).map(([before]) => id(before)).sort((a, b) => a - b);
    const expectedAfter = fixture.final.edges.filter(([before]) => before === key).map(([, after]) => id(after)).sort((a, b) => a - b);
    assert.deepEqual(collection(`${api}/${number(key)}/dependencies/blocked_by?`), expectedBefore);
    assert.deepEqual(collection(`${api}/${number(key)}/dependencies/blocking?`), expectedAfter);
  }
  assert.equal(result.command, `/woostack-orchestrate --issue ${url('P')}`);
  assert.equal(result.invoked, false);
  assert.equal(result.terminal, 'STOP');
}

test('recorded input is the exact canonical published prompt, not a second prompt', () => {
  assert.equal(fixture.kind, 'authored-recorded-mock');
  assert.equal(typeof prompt, 'string');
  assert.equal(createHash('sha256').update(prompt).digest('hex'), fixture.prompt.sha256,
    'Prompt changed: review the recorded mock cases against it before updating their receipt');
  assert.equal(guide.split(fixture.prompt.fence).length, 2);
  assert.deepEqual(fixture.repository.executedChecks, []);
});

test('vague feature and repository conflict retain an explicit user choice before publication', () => {
  const turns = fixture.conversation;
  const conflict = turns.findIndex((turn) => turn.role === 'evidence');
  assert.equal(turns[conflict + 1].role, 'planner');
  assert.equal(turns[conflict + 2].role, 'user');
  assert.deepEqual(turns.at(-2).attachments, keys.map((key) => `approvalDrafts.${key}`));
  assert.equal(turns.at(-1).role, 'user');
  for (const key of keys) {
    assert.ok(fixture.approvalDrafts[key]);
    assert.doesNotMatch(fixture.approvalDrafts[key], /\/issues\/10[1-5]/, 'Draft approval cannot predict issue numbers');
  }
  assert.equal(fixture.capacity.complete, true);
  assert.ok(fixture.capacity.existing.length + fixture.capacity.additional.length <= fixture.capacity.limit);
});

test('standalone contracts bind the canonical parent and evidence to the declared graph', () => {
  const contracts = expand(fixture.contracts);
  for (const key of keys.slice(1)) {
    const body = contracts[key].body;
    assert.ok(body.includes(url('P')));
    assert.ok(body.includes(fixture.repository.sha));
  }
  assert.deepEqual(fixture.final.edges, [['A', 'C'], ['B', 'D'], ['C', 'D']]);
  assert.deepEqual(fixture.final.independent, ['A', 'B']);
});

test('one publisher records real-ID native containment and exactly the approved edges before STOP', () => {
  const ops = operations(fixture);
  assert.deepEqual([...new Set(writes(ops).map((e) => e.publisher))], ['chat-planner']);
  const creates = writes(ops).filter((e) => e.request.path === api);
  assert.equal(creates.length, 5);
  assert.equal(new Set(creates.map((e) => e.creationKey)).size, 5);
  assert.ok(creates.every((e) => e.request.json.body.includes(`woostack-issue-mutation:${e.creationKey}`)));
  const links = writes(ops).filter((e) => e.request.path === `${api}/101/sub_issues`);
  assert.deepEqual(links.map((e) => e.request.json), keys.slice(1).map((key) => ({ sub_issue_id: id(key), replace_parent: false })));
  const edges = writes(ops).filter((e) => e.request.path.endsWith('/dependencies/blocked_by'));
  assert.deepEqual(edges.map((e) => [e.request.json.issue_id, e.request.path]), [
    [id('A'), `${api}/104/dependencies/blocked_by`],
    [id('B'), `${api}/105/dependencies/blocked_by`],
    [id('C'), `${api}/105/dependencies/blocked_by`],
  ]);
  const indexUpdate = ops.findIndex((e) => e.request.method === 'PATCH');
  assert.ok(indexUpdate > ops.indexOf(links.at(-1)));
  assert.ok(indexUpdate < ops.indexOf(edges[0]));
  for (const event of writes(ops)) {
    assert.ok(event.request.path === api || event.request.path === `${api}/101` || event.request.path === `${api}/101/sub_issues` || /\/issues\/10[45]\/dependencies\/blocked_by$/.test(event.request.path));
  }
  assertReadyReadBack(ops, fixture.final);
});

test('required evidence gaps record no publication and no ready handoff', () => {
  for (const name of ['defect-without-runtime-proof', 'native-capabilities-missing', 'missing-test-command', 'conflicting-parent', 'incomplete-pagination', 'untrusted-issue-text', 'direct-child-capacity']) {
    const scenario = variant(name);
    assert.deepEqual(writes(operations(scenario)), [], name);
    assert.equal(scenario.final.status, 'blocked', name);
    assert.equal(scenario.final.command, null, name);
    assert.equal(scenario.final.invoked, false, name);
  }
  assert.equal(variant('defect-without-runtime-proof').evidence.provedCause, null);
  const cap = variant('direct-child-capacity').capacity;
  assert.ok(cap.existingCount + cap.additional.length > cap.limit);
  assert.equal(variant('incomplete-pagination').capacity.complete, false);
  assert.deepEqual(variant('missing-test-command').provenance, { exists: false, createdByTask: null, createdByPrerequisite: null });
});

test('partial writes retain confirmed identities and do not hide missing native links', () => {
  const scenario = variant('partial-publication-permission-loss');
  const ops = operations(scenario);
  assert.equal(ops.at(-1).response.status, 403);
  assert.deepEqual(writes(ops).filter((e) => e.request.path === api).map((e) => e.creationKey), ['P', 'A', 'B'].map((key) => fixture.markers[key]));
  assert.deepEqual(scenario.final.confirmed, ['P', 'A', 'B'].map(url));
  assert.equal(scenario.final.command, null);
  assert.ok(scenario.final.missing.includes('P contains B'));
});

test('optional Project failure does not invalidate verified parent mode', () => {
  const scenario = variant('optional-project-unavailable');
  assert.equal(scenario.capabilities.projectWrite, false);
  assertReadyReadBack(operations(scenario), scenario.final);
  assert.ok(operations(scenario).every((e) => !e.request.path.includes('/projects')));
});

test('unknown creation recovers by complete same-marker discovery, never a duplicate create', () => {
  for (const name of ['unknown-parent-creation', 'unknown-parent-zero-matches', 'unknown-parent-ambiguous']) {
    const scenario = variant(name);
    const ops = operations(scenario);
    const parentCreates = writes(ops).filter((e) => e.creationKey === fixture.markers.P);
    assert.equal(parentCreates.length, 1, name);
    assert.equal(parentCreates[0].response.status, null);
    const matches = inspectParentRecovery(ops);
    assert.deepEqual(matches.map((item) => item.html_url), scenario.recovery.matches);
    if (name === 'unknown-parent-creation') assertReadyReadBack(ops, scenario.final);
    else {
      assert.equal(scenario.final.command, null);
      assert.equal(writes(ops).length, 1, 'Uncertain identity stops every later mutation');
    }
  }
});

test('errored native-parent receipts cannot certify an otherwise complete graph', () => {
  const ops = operations(fixture);
  const parent = ops.findLast((e) => e.request.path === '/graphql' && e.request.json.variables.number === number('P'));
  parent.response.json.errors = [{ message: 'Parent read denied', path: ['repository', 'issue', 'parent'] }];
  assert.throws(() => assertReadyReadBack(ops, fixture.final), /GraphQL parent read failed/);
});

test('resumed writes cannot substitute a final graph for unknown-create discovery', () => {
  const scenario = structuredClone(variant('unknown-parent-creation'));
  scenario.operations = scenario.operations.filter((e) => !e.request.path.startsWith(`${api}?state=all&`));
  assert.throws(() => inspectParentRecovery(operations(scenario)), /Missing independent recovered-identity read-back/);
});

test('unknown links are discovered in both directions without reparenting or replay', () => {
  const scenario = variant('unknown-link-existing');
  const ops = operations(scenario);
  const attempts = writes(ops).filter((e) => e.request.path === `${api}/101/sub_issues` && e.request.json.sub_issue_id === id('A'));
  assert.equal(attempts.length, 1);
  assert.equal(attempts[0].response.status, null);
  assert.equal(scenario.recovery.replayedLink, false);
  assertReadyReadBack(ops, scenario.final);
});

test('a missing final dependency page cannot masquerade as a ready graph', () => {
  const scenario = variant('incomplete-final-dependency-page');
  const ops = operations(scenario);
  assert.ok(ops.at(-1).response.next);
  assert.equal(scenario.final.command, null);
  assert.equal(scenario.final.status, 'blocked');
  assert.throws(() => assertReadyReadBack(ops, { ...fixture.final }), /Missing|Unfetched|Expected/);
});
