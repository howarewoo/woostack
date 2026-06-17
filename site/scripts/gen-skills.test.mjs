import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import {
  parseFrontmatter,
  stripTitleHeading,
  rewriteLinks,
  neutralizeTags,
  renderPage,
  navOrder,
} from './gen-skills.mjs';

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
    r('[self](references/plan-template.md)'),
    '[self](https://github.com/howarewoo/woostack/blob/main/skills/woostack-build/references/plan-template.md)'
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

  const fenced = '```\n<PR> stays\n```';
  assert.equal(neutralizeTags(fenced), fenced); // inside fence preserved
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

test('navOrder puts public commands first, internal sub-skills last', () => {
  const names = ['woostack-harden', 'woostack-build', 'woostack-ideate', 'using-woostack'];
  const order = navOrder(names);
  assert.deepEqual(order, ['using-woostack', 'woostack-build', 'woostack-harden', 'woostack-ideate']);
  assert.ok(order.indexOf('woostack-build') < order.indexOf('woostack-ideate'));
  assert.ok(order.indexOf('woostack-build') < order.indexOf('woostack-harden'));
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
