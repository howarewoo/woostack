import assert from 'node:assert/strict';
import { mkdtemp, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { validateSkillAssets } from './skill-assets.mjs';

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
