import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { parseFrontmatter } from '../../skills/woostack-eval/scripts/validate.mjs';
import {
  INTERNAL_ORDER,
  PUBLIC_ORDER,
  parseFrontmatter as generatorParseFrontmatter,
  stripTitleHeading,
  rewriteLinks,
  neutralizeTags,
  renderPage,
  navOrder,
} from './gen-skills.mjs';

test('generator re-exports the canonical frontmatter parser', () => {
  assert.equal(generatorParseFrontmatter, parseFrontmatter);
});

test('parseFrontmatter extracts name + description and returns the body', () => {
  const raw = '---\nname: woostack-build\ndescription: Use when building a feature.\n---\n\n# woostack-build\n\nbody';
  const { fm, body } = parseFrontmatter(raw, 'woostack-build');
  assert.equal(fm.name, 'woostack-build');
  assert.equal(fm.description, 'Use when building a feature.');
  assert.match(body, /# woostack-build/);
});

test('parseFrontmatter throws when name is missing', () => {
  assert.throws(() => parseFrontmatter('---\ndescription: x\n---\nbody', 'f'), /missing 'name'/);
});

test('parseFrontmatter strips surrounding YAML quotes (some descriptions are quoted)', () => {
  const raw = '---\nname: woostack-tdd\ndescription: "TDD home: red→green. Quoted in source."\n---\nb';
  const { fm } = parseFrontmatter(raw, 'woostack-tdd');
  assert.equal(fm.description, 'TDD home: red→green. Quoted in source.'); // no leading/trailing "
});

test('parseFrontmatter accepts safe placeholders in plain descriptions', () => {
  const raw = '---\nname: woostack-plan\ndescription: Plan the approved Linear project at <project-url>.\n---\nbody';
  const { fm } = parseFrontmatter(raw, 'woostack-plan');
  assert.equal(fm.description, 'Plan the approved Linear project at <project-url>.');
});

test('parseFrontmatter accepts quoted colon-space descriptions with safe placeholders', () => {
  const raw = '---\nname: woostack-plan\ndescription: "Plan source: use <project-url> safely."\n---\nbody';
  const { fm } = parseFrontmatter(raw, 'woostack-plan');
  assert.equal(fm.description, 'Plan source: use <project-url> safely.');
});

test('parseFrontmatter rejects colon-space in a plain description deterministically', () => {
  const raw = '---\nname: woostack-plan\ndescription: Plan source: use safely.\n---\nbody';
  assert.throws(
    () => parseFrontmatter(raw, 'woostack-plan'),
    (error) => error.code === 'frontmatter-plain-colon-space' &&
      error.message === 'woostack-plan: description contains colon-space in a plain scalar; quote the value',
  );
});

test('stripTitleHeading removes only the first exact "# <name>" H1', () => {
  const body = '\n# woostack-build\n\n## Overview\n\n# woostack-build\n';
  const out = stripTitleHeading(body, 'woostack-build');
  assert.equal((out.match(/^# woostack-build$/gm) || []).length, 1); // one removed, one stays
  assert.match(out, /## Overview/);
});

test('rewriteLinks maps skill links to routes, refs to GitHub, leaves absolute/anchors', () => {
  const r = (s) => rewriteLinks(s, 'woostack-build');
  assert.equal(r('see [plan](../woostack-plan/SKILL.md)'), 'see [plan](/docs/skills/woostack-plan)');
  assert.equal(r('[a](../woostack-plan/SKILL.md#x)'), '[a](/docs/skills/woostack-plan#x)');
  assert.equal(
    r('[wt](../woostack-init/references/worktrees.md)'),
    '[wt](https://github.com/howarewoo/woostack/blob/main/skills/woostack-init/references/worktrees.md)'
  );
  assert.equal(
    r('[self](references/linear-procedure.md)'),
    '[self](https://github.com/howarewoo/woostack/blob/main/skills/woostack-build/references/linear-procedure.md)'
  );
  assert.equal(r('[ext](https://example.com)'), '[ext](https://example.com)');
  assert.equal(r('[here](#section)'), '[here](#section)');
});

test('neutralizeTags: block tag -> Callout, prose tag escaped, code-span/fence preserved', () => {
  const block = '<HARD-GATE>\nDo not proceed.\n</HARD-GATE>';
  const out = neutralizeTags(block);
  assert.match(out, /<Callout type="warn" title="Hard gate">/);
  assert.match(out, /<\/Callout>/);
  assert.doesNotMatch(out, /<HARD-GATE>/);

  assert.match(neutralizeTags('a bare <FOO> here'), /a bare &lt;FOO&gt; here/);

  const code = 'POST `gh api repos/<repo>/pulls/<PR>/reviews` now';
  assert.equal(neutralizeTags(code), code); // uppercase tag inside inline code preserved

  const attributed = '<FOO scope="feature">**Stop.**</FOO>';
  assert.equal(
    neutralizeTags(attributed),
    '&lt;FOO scope="feature"&gt;**Stop.**&lt;/FOO&gt;'
  );

  const attributedGate = [
    '<HARD-GATE name="design-approval"></HARD-GATE>',
    '1. <HARD-GATE name="spec-approval">**Stop.**',
    'Wait for approval.</HARD-GATE>',
  ].join('\n');
  assert.equal(neutralizeTags(attributedGate), '1. **Stop.**\nWait for approval.');

  const fenced = '```\n<PR> stays\n```';
  assert.equal(neutralizeTags(fenced), fenced); // inside fence preserved

  const marker = '<!-- build-gates: design-approval | spec-approval | execution-handoff -->';
  assert.equal(neutralizeTags(marker), '');
});

test('renderPage emits title/description, source link, internal note for sub-skills', () => {
  const fm = { name: 'woostack-build', description: 'Build a feature: end to end.' };
  const page = renderPage('woostack-build', fm, '## Overview\n\nbody');
  assert.match(page, /^---\ntitle: woostack-build\n/);
  assert.match(page, /description: "Build a feature: end to end\."/); // JSON-quoted, colon-safe
  assert.match(
    page,
    /\[View source on GitHub\]\(https:\/\/github\.com\/howarewoo\/woostack\/blob\/main\/skills\/woostack-build\/SKILL\.md\)/
  );
  assert.doesNotMatch(page, /Internal sub-skill/);

  const ideate = renderPage('woostack-ideate', { name: 'woostack-ideate', description: 'x' }, 'b');
  assert.match(ideate, /Internal sub-skill/);
});

test('navOrder preserves the exact 22-public and 2-internal skill order', () => {
  const expectedPublic = [
    'using-woostack',
    'woostack-init',
    'woostack-bootstrap',
    'woostack-build',
    'woostack-fix',
    'woostack-change',
    'woostack-plan',
    'woostack-execute',
    'woostack-execute-overnight',
    'woostack-commit',
    'woostack-review',
    'woostack-address-comments',
    'woostack-status',
    'woostack-visualize',
    'woostack-debug',
    'woostack-tdd',
    'woostack-doctor',
    'woostack-sweep',
    'woostack-qa',
    'woostack-audit',
    'woostack-respond',
    'woostack-eval',
  ];
  const expectedInternal = ['woostack-harden', 'woostack-ideate'];
  const expected = [...expectedPublic, ...expectedInternal];

  assert.equal(PUBLIC_ORDER.length, 22);
  assert.deepEqual(PUBLIC_ORDER, expectedPublic);
  assert.deepEqual(INTERNAL_ORDER, expectedInternal);
  assert.equal(expected.length, 24);
  assert.equal(new Set(expected).size, 24);
  assert.deepEqual(navOrder([...expected].reverse()), expected);
});

test('concepts taxonomy keeps context economy under context management', async () => {
  const docsDir = path.join(import.meta.dirname, '..', 'content', 'docs');
  const meta = JSON.parse(await readFile(path.join(docsDir, 'concepts', 'meta.json'), 'utf8'));
  const overview = await readFile(path.join(docsDir, 'concepts', 'index.mdx'), 'utf8');

  assert.equal(meta.title, 'Core concepts');
  assert.ok(meta.pages.includes('context-management'));
  assert.match(overview, /^title:\s*Overview$/m);
  assert.doesNotMatch(overview, /ContextEconomy/);
  assert.doesNotMatch(overview, /^## Context economy$/m);
});

test('configuration docs follow the scaffold and Linear contract', async () => {
  const repoRoot = path.resolve(import.meta.dirname, '..', '..');
  const [templateRaw, configuration, auditRaw] = await Promise.all([
    readFile(path.join(repoRoot, 'skills', 'woostack-init', 'templates', 'config.json'), 'utf8'),
    readFile(path.join(repoRoot, 'site', 'content', 'docs', 'configuration.mdx'), 'utf8'),
    readFile(path.join(repoRoot, 'skills', 'woostack-audit', 'SKILL.md'), 'utf8'),
  ]);
  const template = JSON.parse(templateRaw);
  assert.deepEqual(Object.keys(template), ['models', 'review', 'respond', 'status']);
  assert.equal(template.linear, undefined);
  assert.equal(template.artifacts, undefined);

  const exampleMatch = /## A complete repository-policy example[\s\S]*?```json\n([\s\S]*?)\n```/.exec(configuration);
  assert.ok(exampleMatch, 'configuration page exposes a complete repository-policy JSON example');
  const example = JSON.parse(exampleMatch[1]);
  assert.deepEqual(
    Object.keys(example).sort(),
    ['audit', 'base_branch', 'commit', 'models', 'respond', 'review', 'review_sweep', 'status']
  );
  assert.ok(example.models);
  assert.equal(example.linear, undefined);
  assert.equal(example.artifacts, undefined);
  assert.equal(example.audit.models, undefined);

  assert.match(configuration, /ships four\s+top-level keys: `models`, `review`, `respond`, and `status`/);
  assert.match(configuration, /There are nine top-level settings:/);
  assert.doesNotMatch(configuration, /\| `artifacts` \|/);
  assert.match(configuration, /\| `linear` \|/);
  assert.match(configuration, /\| `audit` \|/);
  assert.match(configuration, /^## Linear plan configuration$/m);
  assert.match(configuration, /^## Audit engine$/m);
  assert.match(configuration, /`audit\.severity_floor`/);
  assert.match(configuration, /Root model tiers also drive \[woostack-audit\]/);
  assert.match(configuration, /automatically attempts safe read-only Linear default discovery/);
  assert.match(configuration, /Missing or incomplete Linear setup never blocks local initialization/);
  assert.match(configuration, /neither select persistence\s+nor authorize later provider access/);

  const { fm, body } = parseFrontmatter(auditRaw, 'woostack-audit');
  const renderedBody = rewriteLinks(
    neutralizeTags(stripTitleHeading(body, fm.name)),
    'woostack-audit'
  );
  const renderedAudit = renderPage('woostack-audit', fm, renderedBody);
  assert.match(renderedAudit, /shared root `models`/);
  assert.match(
    renderedAudit,
    /skills\/using-woostack\/references\/model-tiers\.md/
  );
  assert.doesNotMatch(renderedAudit, /`ignore`, `models`, `chunking/);

});
