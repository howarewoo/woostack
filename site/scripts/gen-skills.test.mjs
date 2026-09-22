import { test } from 'node:test';
import assert from 'node:assert/strict';
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
  const raw = '---\nname: woostack-execute\ndescription: "Execute task: red→green. Quoted in source."\n---\nb';
  const { fm } = parseFrontmatter(raw, 'woostack-execute');
  assert.equal(fm.description, 'Execute task: red→green. Quoted in source.'); // no leading/trailing "
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

test('navOrder places orchestration between planning and bounded execution', () => {
  const expectedPublic = [
    'using-woostack',
    'woostack-init',
    'woostack-bootstrap',
    'woostack-build',
    'woostack-fix',
    'woostack-change',
    'woostack-plan',
    'woostack-orchestrate',
    'woostack-execute',
    'woostack-commit',
    'woostack-address-comments',
    'woostack-status',
    'woostack-visualize',
    'woostack-design',
    'woostack-debug',
    'woostack-doctor',
    'woostack-qa',
    'woostack-eval',
    'woostack-reflect',
  ];
  const expectedInternal = ['woostack-harden', 'woostack-ideate'];
  const expected = [...expectedPublic, ...expectedInternal];

  assert.deepEqual(navOrder([...expected].reverse()), expected);
});

