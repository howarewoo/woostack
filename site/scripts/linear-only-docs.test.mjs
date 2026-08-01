import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { before, test } from 'node:test';

const REPO_ROOT = path.resolve(import.meta.dirname, '..', '..');
const PATHS = [
  'README.md',
  'AGENTS.md',
  'skills/using-woostack/SKILL.md',
  'skills/woostack-init/references/artifact-backends.md',
  'skills/woostack-build/SKILL.md',
  'skills/woostack-build/references/linear-context.md',
  'skills/woostack-build/references/linear-procedure.md',
  'skills/woostack-plan/SKILL.md',
  'skills/woostack-fix/SKILL.md',
  'skills/woostack-change/SKILL.md',
  'site/content/docs/index.mdx',
  'site/content/docs/getting-started.mdx',
  'site/content/docs/configuration.mdx',
  'site/content/docs/concepts.mdx',
  'site/content/docs/concepts/building-rules.mdx',
  'site/content/docs/concepts/workflows.mdx',
];

let files;

before(async () => {
  files = new Map(
    await Promise.all(
      PATHS.map(async (relativePath) => [
        relativePath,
        await readFile(path.join(REPO_ROOT, relativePath), 'utf8'),
      ])
    )
  );
});

function read(relativePath) {
  const value = files.get(relativePath);
  assert.notEqual(value, undefined, `${relativePath}: file was not loaded`);
  return value;
}

function assertContains(relativePath, pattern, message) {
  assert.match(read(relativePath), pattern, `${relativePath}: ${message}`);
}

test('fix and build plans persist when repository Linear capability is available', () => {
  for (const relativePath of [
    'AGENTS.md',
    'skills/using-woostack/SKILL.md',
    'skills/woostack-build/SKILL.md',
    'skills/woostack-fix/SKILL.md',
    'skills/woostack-plan/SKILL.md',
    'site/content/docs/getting-started.mdx',
    'site/content/docs/concepts.mdx',
    'site/content/docs/concepts/building-rules.mdx',
    'site/content/docs/concepts/workflows.mdx',
  ]) {
    assertContains(
      relativePath,
      /Linear[\s\S]{0,300}(?:availability|available|capability)/i,
      'must describe repository-enabled Linear persistence'
    );
  }
});

test('the persisted plan uses one project, one parent plan issue, and one child per increment', () => {
  for (const relativePath of [
    'README.md',
    'AGENTS.md',
    'skills/using-woostack/SKILL.md',
    'skills/woostack-init/references/artifact-backends.md',
    'skills/woostack-build/references/linear-procedure.md',
    'skills/woostack-plan/SKILL.md',
    'site/content/docs/getting-started.mdx',
    'site/content/docs/concepts/building-rules.mdx',
  ]) {
    const text = read(relativePath).replace(/\s+/g, ' ');
    assert.match(text, /one(?: exact Linear)? project/i, `${relativePath}: must state one project`);
    assert.match(text, /one parent plan issue/i, `${relativePath}: must state one parent plan issue`);
    assert.match(text, /one (?:native )?child issue.{0,80}(?:per|for every) increment/i,
      `${relativePath}: must state one child issue per increment`);
  }
});

test('Linear availability is proved without reading repository credentials', () => {
  for (const relativePath of [
    'skills/woostack-init/references/artifact-backends.md',
    'skills/woostack-build/SKILL.md',
    'skills/woostack-fix/SKILL.md',
    'site/content/docs/configuration.mdx',
    'site/content/docs/getting-started.mdx',
  ]) {
    const content = read(relativePath);
    assert.match(content, /API key|OAuth credential|credentials/i,
      `${relativePath}: must identify host-owned credentials`);
    assert.match(content, /(?:never|without)\s+(?:inspect(?:ing)?|read(?:ing)?|expos(?:e|ing)|print(?:ing)?|copy(?:ing)?|place|store)|without reading the secret/i,
      `${relativePath}: must not read or expose credentials`);
  }
});

test('automatic persistence fails safely and every mutation is read back', () => {
  const contract = read('skills/woostack-init/references/artifact-backends.md').replace(/\s+/g, ' ');
  assert.match(contract, /preflight is unavailable or incomplete.{0,120}continue artifact-free/i);
  assert.match(contract, /Once availability is proved.{0,220}block its execution handoff on failure/i);
  assert.match(contract, /perform a new independent complete read/i);

  const procedure = read('skills/woostack-build/references/linear-procedure.md').replace(/\s+/g, ' ');
  assert.match(procedure, /verify every issue, parent-child link, and dependency relation through independent complete read-back/i);
});

test('abandonment closes an existing fix/build project without creating one', () => {
  for (const relativePath of [
    'README.md',
    'AGENTS.md',
    'skills/using-woostack/SKILL.md',
    'skills/woostack-init/references/artifact-backends.md',
    'skills/woostack-build/SKILL.md',
    'skills/woostack-build/references/linear-context.md',
    'skills/woostack-build/references/linear-procedure.md',
    'skills/woostack-fix/SKILL.md',
    'site/content/docs/configuration.mdx',
    'site/content/docs/concepts.mdx',
    'site/content/docs/concepts/building-rules.mdx',
    'site/content/docs/concepts/workflows.mdx',
  ]) {
    const content = read(relativePath).replace(/\s+/g, ' ');
    assert.match(content, /explicit(?:ly)?(?:\s+\S+){0,3}\s+abandon/i,
      `${relativePath}: must cover explicit abandonment`);
    assert.match(
      content,
      /(?:abandon.{0,500}(?:existing|persisted|exact|project exists).{0,200}project.{0,250}(?:cancel|canceled|close)|(?:cancel|canceled|close).{0,250}(?:existing|persisted|exact).{0,200}project.{0,250}abandon)/i,
      `${relativePath}: abandonment must close an existing fix/build project as canceled`
    );
    assert.match(
      content,
      /(?:abandon.{0,600}(?:independent(?:ly)?.{0,50}read(?:-back| back)|reads?.{0,60}(?:closure|transition|status).{0,30}back)|(?:independent(?:ly)?.{0,50}read(?:-back| back)|reads?.{0,60}(?:closure|transition|status).{0,30}back).{0,300}abandon)/i,
      `${relativePath}: closure must require read-back`
    );
    assert.match(
      content,
      /(?:handoff|hand off).{0,140}(?:replan|replanning).{0,140}blocker.{0,220}(?:not abandonment|do not close|leave.{0,60}open|unchanged|do not)/i,
      `${relativePath}: non-abandonment outcomes must leave the project open`
    );
  }

  const contract = read('skills/woostack-init/references/artifact-backends.md').replace(/\s+/g, ' ');
  assert.match(contract, /projectStatuses\.canceled|configured canceled/i);
  assert.match(contract, /(?:do not|never)[^.]{0,160}create a project merely to cancel it/i);

  const procedure = read('skills/woostack-build/references/linear-procedure.md').replace(/\s+/g, ' ');
  assert.match(procedure, /abandon.{0,500}independent.{0,40}read-back/i);
  assert.match(procedure, /(?:handoff|hand off).{0,100}replan.{0,100}blocker.{0,120}(?:leave|remain).{0,60}(?:open|unchanged)/i);
});

test('automatic creation never fuzzy-matches an existing project', () => {
  const contract = read('skills/woostack-init/references/artifact-backends.md').replace(/\s+/g, ' ');
  assert.match(contract, /exact caller-supplied resource takes precedence over automatic creation/i);
  assert.match(contract, /never infer an existing artifact from a title/i);

  const procedure = read('skills/woostack-build/references/linear-procedure.md').replace(/\s+/g, ' ');
  assert.match(procedure, /Never discover or reuse a project by title or recent activity/i);
  assert.match(procedure, /stable project mutation UUID/i);
});

test('woostack-change has no Linear command or synchronization surface', () => {
  const change = read('skills/woostack-change/SKILL.md');
  assert.match(change, /always\s+artifact-free and never reads or writes Linear/i);
  assert.doesNotMatch(change, /--issue|--project|artifact synchronization|Linear-Issue:/i);

  assertContains('skills/using-woostack/SKILL.md', /`\/woostack-change <goal>`[^\n]*artifact-free/i,
    'routing must keep change artifact-free');
  assertContains('site/content/docs/concepts/workflows.mdx', /Change[\s\S]{0,500}never reads or writes Linear/i,
    'workflow docs must keep change artifact-free');
});

test('Linear artifacts never authorize repository work', () => {
  for (const relativePath of [
    'README.md',
    'AGENTS.md',
    'skills/using-woostack/SKILL.md',
    'skills/woostack-init/references/artifact-backends.md',
    'skills/woostack-build/SKILL.md',
    'skills/woostack-fix/SKILL.md',
    'site/content/docs/concepts.mdx',
  ]) {
    assertContains(relativePath, /(?:never\s+(?:grant|authorize)|do not assign permission|never\s+authorizes)/i,
      'must preserve the repository authority boundary');
  }
});
