import assert from 'node:assert/strict';
import { mkdtemp, mkdir, readFile, readdir, readlink, realpath, rm, stat, symlink, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { parseFrontmatter, validateSkillAssets } from './skill-assets.mjs';

async function makeRoot(t) {
  const root = await mkdtemp(path.join(os.tmpdir(), 'woostack-skill-assets-'));
  t.after(() => rm(root, { recursive: true, force: true }));
  return root;
}

async function writeSkill(root, name, body = '') {
  const skillRoot = path.join(root, name);
  await mkdir(path.join(skillRoot, 'references'), { recursive: true });
  await writeFile(
    path.join(skillRoot, 'SKILL.md'),
    `---\nname: ${name}\ndescription: Validate a corpus-free skill.\n---\n# ${name}\n${body}\n`,
  );
  return skillRoot;
}

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');

async function findBrokenSkillLinks(skillsDir) {
  const broken = [];
  for (const entry of await readdir(skillsDir, { withFileTypes: true })) {
    if (!entry.isSymbolicLink()) continue;
    const link = path.join(skillsDir, entry.name);
    const target = await readlink(link);
    let resolved;
    try {
      resolved = await realpath(link);
    } catch (error) {
      if (error?.code !== 'ENOENT') throw error;
      broken.push(`${entry.name} -> ${target}: is a dangling link`);
      continue;
    }
    if (!(await stat(resolved)).isDirectory()) {
      broken.push(`${entry.name} -> ${target}: is not a skill directory`);
      continue;
    }
    try {
      if (!(await stat(path.join(resolved, 'SKILL.md'))).isFile()) {
        broken.push(`${entry.name} -> ${target}: has no SKILL.md`);
      }
    } catch (error) {
      if (error?.code !== 'ENOENT') throw error;
      broken.push(`${entry.name} -> ${target}: has no SKILL.md`);
    }
  }
  return broken.sort();
}

test('structural validation accepts corpus-free skills, local references, JSON, and catalog order', async (t) => {
  const root = await makeRoot(t);
  const skillRoot = await writeSkill(root, 'sample-skill', '[Guide](references/guide.md)');
  await writeFile(path.join(skillRoot, 'references', 'guide.md'), '# Guide\n');
  await writeFile(path.join(skillRoot, 'references', 'config.json'), '{"enabled":true}\n');

  const skills = await validateSkillAssets(root, ['sample-skill']);
  assert.equal(skills.length, 1);
  assert.equal(skills[0].name, 'sample-skill');
  assert.match(skills[0].body, /\[Guide\]\(references\/guide\.md\)/);
});

test('frontmatter validation rejects decimal scalars and SVG markup', () => {
  const cases = [
    ['0.5', 'frontmatter-non-string-scalar'],
    ['-0.5', 'frontmatter-non-string-scalar'],
    ['<svg>', 'frontmatter-xml-markup'],
  ];
  for (const [description, code] of cases) {
    assert.throws(
      () => parseFrontmatter(`---\nname: sample-skill\ndescription: ${description}\n---\n`, 'sample-skill'),
      (error) => error.code === code,
    );
  }
});

test('structural validation rejects invalid JSON and missing local references', async (t) => {
  const root = await makeRoot(t);
  const skillRoot = await writeSkill(root, 'sample-skill');
  const jsonPath = path.join(skillRoot, 'references', 'config.json');
  await writeFile(jsonPath, '{ invalid\n');
  await assert.rejects(validateSkillAssets(root, ['sample-skill']), /config\.json: invalid JSON/);

  await writeFile(jsonPath, '{}\n');
  await writeFile(path.join(skillRoot, 'SKILL.md'), `${await readFile(path.join(skillRoot, 'SKILL.md'), 'utf8')}\n[Missing](references/missing.md)\n`);
  await assert.rejects(validateSkillAssets(root, ['sample-skill']), /local link target does not exist/);
});

test('local reference validation preserves escaped backticks and uppercase Markdown files', async (t) => {
  const root = await makeRoot(t);
  const skillRoot = await writeSkill(root, 'sample-skill', 'Literal \\` [Missing](references/missing.md) \\` text');
  await assert.rejects(validateSkillAssets(root, ['sample-skill']), /local link target does not exist/);

  await writeFile(path.join(skillRoot, 'references', 'guide.MD'), '[Missing](references/missing.md)\n');
  await assert.rejects(validateSkillAssets(root, ['sample-skill']), /guide\.MD: local link target does not exist/);
});

test('structural validation rejects mismatched metadata and catalog discovery', async (t) => {
  const root = await makeRoot(t);
  await mkdir(path.join(root, 'sample-skill'));
  await writeFile(
    path.join(root, 'sample-skill', 'SKILL.md'),
    '---\nname: other-skill\ndescription: Valid metadata.\n---\n',
  );
  await assert.rejects(validateSkillAssets(root, ['sample-skill']), /name must exactly match/);
  await assert.rejects(validateSkillAssets(root, []), /skill catalog mismatch/);
});

test('every checkout-local skill link resolves to a skill directory', async () => {
  assert.deepEqual(await findBrokenSkillLinks(path.join(REPO_ROOT, '.claude', 'skills')), []);
});

test('broken skill links are reported for the intended reason', async (t) => {
  const root = await makeRoot(t);
  const skills = path.join(root, 'skills');
  const links = path.join(root, '.claude', 'skills');
  await mkdir(path.join(skills, 'live-skill'), { recursive: true });
  await writeFile(path.join(skills, 'live-skill', 'SKILL.md'), '# live-skill\n');
  await mkdir(path.join(skills, 'not-a-skill'));
  await mkdir(links, { recursive: true });
  await symlink('../../skills/live-skill', path.join(links, 'live-skill'));
  await symlink('../../skills/retired-skill', path.join(links, 'retired-skill'));
  await symlink('../../skills/not-a-skill', path.join(links, 'not-a-skill'));

  assert.deepEqual(await findBrokenSkillLinks(links), [
    'not-a-skill -> ../../skills/not-a-skill: has no SKILL.md',
    'retired-skill -> ../../skills/retired-skill: is a dangling link',
  ]);
});
