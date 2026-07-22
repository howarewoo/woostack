import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '..', '..', '..', '..');
const read = (...parts) => readFile(path.join(root, ...parts), 'utf8');

test('maintainer evaluator is explicit, internal, and fail-closed', async () => {
  const [skill, runner, readme] = await Promise.all([
    read('tooling', 'evals', 'SKILL.md'),
    read('tooling', 'evals', 'references', 'runner.md'),
    read('tooling', 'evals', 'README.md'),
  ]);

  assert.match(skill, /^name: evals$/m);
  assert.match(skill, /^description: Maintainer-only workflow/m);
  assert.match(skill, /lives outside `skills\/`/);
  assert.match(skill, /no public command/);
  assert.doesNotMatch(skill, /\/woostack-eval/);
  assert.match(skill, /Ordinary host subagents, OMP `task` workers/);
  assert.match(skill, /Never downgrade to direct host-native dispatch, candidate-only execution, or advisory isolation/);
  assert.match(skill, /configured runner's enforced isolation/);

  assert.match(runner, /approved maintainer runner adapter/);
  assert.match(runner, /Ordinary host subagents and same-session context\s+separation do not satisfy this contract/);
  assert.match(runner, /supervisor-owned\s+evidence/);
  assert.match(runner, /refuse\s+dispatch/);
  assert.doesNotMatch(runner, /only fallback/);

  assert.match(readme, /not part of the consumer skill collection/);
  assert.match(readme, /Model-backed execution is fail-closed/);
  assert.match(readme, /issues\/560/);
});
