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
  const raw = '---\nname: woostack-prepare\ndescription: Prepare a feature.\n---\n\n# woostack-prepare\n\nbody';
  const { fm, body } = parseFrontmatter(raw, 'woostack-prepare');
  assert.equal(fm.name, 'woostack-prepare');
  assert.equal(fm.description, 'Prepare a feature.');
  assert.match(body, /# woostack-prepare/);
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
  const body = '\n# woostack-prepare\n\n## Overview\n\n# woostack-prepare\n';
  const out = stripTitleHeading(body, 'woostack-prepare');
  assert.equal((out.match(/^# woostack-prepare$/gm) || []).length, 1); // one removed, one stays
  assert.match(out, /## Overview/);
});

test('rewriteLinks maps skill links to routes, refs to GitHub, leaves absolute/anchors', () => {
  const r = (s) => rewriteLinks(s, 'woostack-plan');
  assert.equal(r('see [plan](../woostack-plan/SKILL.md)'), 'see [plan](/docs/skills/woostack-plan)');
  assert.equal(r('[a](../woostack-plan/SKILL.md#x)'), '[a](/docs/skills/woostack-plan#x)');
  assert.equal(
    r('[wt](../woostack-init/references/worktrees.md)'),
    '[wt](https://github.com/howarewoo/woostack/blob/main/skills/woostack-init/references/worktrees.md)'
  );
  assert.equal(
    r('[self](references/github-procedure.md)'),
    '[self](https://github.com/howarewoo/woostack/blob/main/skills/woostack-plan/references/github-procedure.md)'
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

test('renderPage emits title/description and source links for public phases', () => {
  const fm = { name: 'woostack-prepare', description: 'Prepare a feature: end to end.' };
  const page = renderPage('woostack-prepare', fm, '## Overview\n\nbody');
  assert.match(page, /^---\ntitle: woostack-prepare\n/);
  assert.match(page, /description: "Prepare a feature: end to end\."/); // JSON-quoted, colon-safe
  assert.match(
    page,
    /\[View source on GitHub\]\(https:\/\/github\.com\/howarewoo\/woostack\/blob\/main\/skills\/woostack-prepare\/SKILL\.md\)/
  );
  assert.doesNotMatch(page, /Internal sub-skill/);

  const ideate = renderPage('woostack-ideate', { name: 'woostack-ideate', description: 'x' }, 'b');
  const harden = renderPage('woostack-harden', { name: 'woostack-harden', description: 'x' }, 'b');
  assert.doesNotMatch(ideate, /Internal sub-skill/);
  assert.doesNotMatch(harden, /Internal sub-skill/);
});

test('navOrder places public planning phases before orchestration', () => {
  const expectedPublic = [
    'using-woostack',
    'woostack-init',
    'woostack-bootstrap',
    'woostack-ideate',
    'woostack-harden',
    'woostack-prepare',
    'woostack-plan',
    'woostack-orchestrate',
    'woostack-execute',
    'woostack-commit',
    'woostack-address-comments',
    'woostack-visualize',
    'woostack-design',
    'woostack-debug',
    'woostack-doctor',
    'woostack-qa',
    'woostack-eval',
    'woostack-reflect',
  ];

  assert.deepEqual(navOrder([...expectedPublic].reverse()), expectedPublic);
});

