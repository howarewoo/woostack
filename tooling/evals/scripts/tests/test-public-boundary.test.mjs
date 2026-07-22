import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync } from 'node:fs';
import { readFile } from 'node:fs/promises';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '..', '..', '..', '..');
const read = (relative) => readFile(path.join(root, relative), 'utf8');

test('evaluation is maintainer-only and absent from the installed skill collection', async () => {
  const [agents, contributing, readme, routing, development, concepts, utilities, generator] = await Promise.all([
    read('AGENTS.md'),
    read('CONTRIBUTING.md'),
    read('README.md'),
    read('skills/using-woostack/SKILL.md'),
    read('skills/woostack-bootstrap/references/development.md'),
    read('site/content/docs/concepts/index.mdx'),
    read('site/content/docs/concepts/utilities.mdx'),
    read('site/scripts/gen-skills.mjs'),
  ]);

  assert.equal(existsSync(path.join(root, 'skills', 'woostack-eval')), false);
  assert.equal(existsSync(path.join(root, 'tooling', 'evals', 'README.md')), true);
  assert.equal(existsSync(path.join(root, 'skills', 'using-woostack', 'scripts', 'validate-skill-package.mjs')), true);

  assert.match(agents, /twenty-two public command\/adoption skills/);
  for (const content of [agents, readme, routing, development, concepts, utilities]) {
    assert.doesNotMatch(content, /woostack-eval/);
  }
  assert.doesNotMatch(generator, /['"]woostack-eval['"]/);

  assert.match(contributing, /tooling\/evals/);
  assert.match(readme, /maintainers run skill evaluations/);
});

test('host files do not assign public evaluation dispatch mechanics', async () => {
  const hosts = ['antigravity', 'claude-code', 'codex', 'cursor', 'omp', 'opencode'];
  for (const host of hosts) {
    const content = await read(`skills/using-woostack/references/hosts/${host}.md`);
    assert.doesNotMatch(content, /woostack-eval/);
  }
});
