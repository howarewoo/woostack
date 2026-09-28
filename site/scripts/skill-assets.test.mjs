import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { chmod, copyFile, lstat, mkdir, mkdtemp, readFile, readdir, readlink, realpath, rename, rm, stat, symlink, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { parseFrontmatter, validateSkillAssets } from './skill-assets.mjs';
import { PUBLIC_ORDER } from './gen-skills.mjs';

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

async function findBrokenSkillLinks(skillsDir, collectionRoot) {
  const collection = await realpath(collectionRoot);
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
        continue;
      }
    } catch (error) {
      if (error?.code !== 'ENOENT') throw error;
      broken.push(`${entry.name} -> ${target}: has no SKILL.md`);
      continue;
    }
    const expected = path.join(collection, entry.name);
    if (resolved !== expected) {
      broken.push(`${entry.name} -> ${target}: resolves to ${resolved} instead of ${expected}`);
    }
  }
  return broken.sort();
}

const CANDIDATE_PATHS = ['skills', '.claude/skills'];

// What this checkout offers to install: tracked paths, including staged additions and deletions,
// plus untracked files that no ignore rule excludes.
function candidatePaths(checkout, ...modes) {
  return execFileSync('git', ['ls-files', ...modes, '-z', '--', ...CANDIDATE_PATHS], {
    cwd: checkout, encoding: 'utf8', maxBuffer: 32 * 1024 * 1024,
  }).split('\0').filter(Boolean);
}

// The candidate's discoverable skill packages, by the production entry-point rule: a top-level
// directory whose SKILL.md exists, whether or not the catalog or Git knows it.
async function candidateSkillPackages(checkout) {
  const skills = path.join(checkout, 'skills');
  const packages = new Set();
  for (const entry of await readdir(skills, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue;
    try {
      await lstat(path.join(skills, entry.name, 'SKILL.md'));
    } catch (error) {
      if (error?.code !== 'ENOENT') throw error;
      continue;
    }
    packages.add(entry.name);
  }
  return packages;
}

// Copy the candidate into a disposable install: tracked shipped files, every candidate skill
// package, and the discovery links. Untracked non-skill debris, ignored caches, and personal
// files are not installable content, and links stay links instead of being dereferenced.
async function installCandidate(checkout, destination) {
  const tracked = new Set(candidatePaths(checkout, '--cached'));
  const packages = await candidateSkillPackages(checkout);
  const checkedDirectories = new Set();
  for (const relative of candidatePaths(checkout, '--cached', '--others', '--exclude-standard')) {
    const [area, name] = relative.split('/');
    if (!tracked.has(relative) && !(area === 'skills' && packages.has(name))
      && !(area === '.claude' && name === 'skills' && relative.split('/').length === 3)) continue;
    let parent = checkout;
    for (const part of relative.split('/').slice(0, -1)) {
      parent = path.join(parent, part);
      if (checkedDirectories.has(parent)) continue;
      let directory;
      try {
        directory = await lstat(parent);
      } catch (error) {
        if (error?.code !== 'ENOENT') throw error;
        break;
      }
      if (directory.isSymbolicLink()) throw new Error(`symlinked candidate directory: ${parent}`);
      checkedDirectories.add(parent);
    }
    const source = path.join(checkout, relative);
    const target = path.join(destination, relative);
    let info;
    try {
      info = await lstat(source);
    } catch (error) {
      if (error?.code !== 'ENOENT') throw error;
      continue; // removed from the worktree, so absent from this candidate
    }
    if (info.isDirectory()) {
      await mkdir(target, { recursive: true });
      continue;
    }
    await mkdir(path.dirname(target), { recursive: true });
    if (info.isSymbolicLink()) {
      await symlink(await readlink(source), target);
      continue;
    }
    await copyFile(source, target);
    await chmod(target, info.mode & 0o777);
  }
}

function git(checkout, ...args) {
  return execFileSync('git', args, { cwd: checkout, encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 });
}

async function exists(target) {
  try {
    await lstat(target);
    return true;
  } catch (error) {
    if (error?.code !== 'ENOENT') throw error;
    return false;
  }
}

// A disposable checkout whose committed candidate is already coherent, so any later uncommitted
// or staged edit is the only difference an installed-candidate check can report.
async function makeCandidateCheckout(root, names) {
  const checkout = path.join(root, 'candidate-source');
  await mkdir(checkout, { recursive: true });
  git(checkout, 'init', '-q');
  git(checkout, 'config', 'user.name', 'Skill Assets');
  git(checkout, 'config', 'user.email', 'skill-assets@example.invalid');
  await writeFile(path.join(checkout, '.gitignore'),
    'skills/ignored-cache/\nskills/*/node_modules/\n*.log\n');
  await mkdir(path.join(checkout, '.claude', 'skills'), { recursive: true });
  for (const name of names) {
    await writeSkill(path.join(checkout, 'skills'), name);
    await symlink(`../../skills/${name}`, path.join(checkout, '.claude', 'skills', name));
  }
  // A tracked file outside any skill package is still shipped content.
  await writeFile(path.join(checkout, 'skills', 'INDEX.md'), '# Tracked candidate index\n');
  git(checkout, 'add', '-A');
  git(checkout, '-c', 'commit.gpgsign=false', 'commit', '-qm', 'Seed candidate');
  return checkout;
}

// The immutable committed release, which the separate documented smoke still exercises.
async function exportCommittedRelease(checkout, destination) {
  await mkdir(destination, { recursive: true });
  execFileSync('tar', ['-xf', '-', '-C', destination], {
    input: execFileSync('git', ['archive', 'HEAD', 'skills'], { cwd: checkout, maxBuffer: 32 * 1024 * 1024 }),
  });
  return path.join(destination, 'skills');
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

test('every checkout-local skill link resolves to its skill in this collection', async () => {
  assert.deepEqual(await findBrokenSkillLinks(path.join(REPO_ROOT, '.claude', 'skills'),
    path.join(REPO_ROOT, 'skills')), []);
});

test('catalog ignores non-skill debris but requires expected skills and rejects extra skills', async (t) => {
  const root = await makeRoot(t);
  await writeSkill(root, 'sample-skill');
  await mkdir(path.join(root, 'cache-only', 'scripts'), { recursive: true });
  await writeFile(path.join(root, 'cache-only', 'scripts', 'retained.bin'), 'user bytes');
  assert.deepEqual((await validateSkillAssets(root, ['sample-skill'])).map(({ name }) => name),
    ['sample-skill']);
  await assert.rejects(validateSkillAssets(root, ['sample-skill', 'cache-only']),
    /skill catalog mismatch/);
  await writeSkill(root, 'unknown-skill');
  await assert.rejects(validateSkillAssets(root, ['sample-skill']), /skill catalog mismatch/);
  assert.equal(await readFile(path.join(root, 'cache-only', 'scripts', 'retained.bin'), 'utf8'),
    'user bytes');
});

test('catalog discovery does not admit a symlinked skill entry point', async (t) => {
  const root = await makeRoot(t);
  const skill = await writeSkill(root, 'sample-skill');
  await writeFile(path.join(skill, 'entry.md'), await readFile(path.join(skill, 'SKILL.md')));
  await rm(path.join(skill, 'SKILL.md'));
  await symlink('entry.md', path.join(skill, 'SKILL.md'));
  await assert.rejects(validateSkillAssets(root, ['sample-skill']),
    /skill assets must be regular files or directories/);
});

test('installed candidate collection resolves without a checkout or docs application', async (t) => {
  const root = await makeRoot(t);
  await installCandidate(REPO_ROOT, root);
  const installed = path.join(root, 'skills');
  assert.deepEqual(
    (await validateSkillAssets(installed, PUBLIC_ORDER)).map(({ name }) => name),
    [...PUBLIC_ORDER].sort(),
  );

  // Links stay links, and they resolve against the copied collection.
  const links = path.join(root, '.claude', 'skills');
  assert.deepEqual((await readdir(links, { withFileTypes: true })).map((entry) => entry.isSymbolicLink()),
    [true, true, true]);
  assert.deepEqual(await findBrokenSkillLinks(links, installed), []);
  assert.deepEqual((await readdir(links)).sort(),
    ['woostack-address-comments', 'woostack-bootstrap', 'woostack-commit']);

  // A checkout-only target must fail even when a neighboring docs tree exists.
  const entry = path.join(installed, 'using-woostack', 'SKILL.md');
  await mkdir(path.join(root, 'site'), { recursive: true });
  await writeFile(path.join(root, 'site', 'guide.md'), '# Checkout-only guide\n');
  await writeFile(entry, `${await readFile(entry, 'utf8')}\n[Guide](../../site/guide.md)\n`);
  await assert.rejects(validateSkillAssets(installed, PUBLIC_ORDER),
    /local link target escapes the skill collection/);
});

test('an uncommitted candidate error is not hidden by the committed release bytes', async (t) => {
  const root = await makeRoot(t);
  const checkout = await makeCandidateCheckout(root, ['sample-skill']);
  const entry = path.join(checkout, 'skills', 'sample-skill', 'SKILL.md');
  const broken = `${await readFile(entry, 'utf8')}\n[Missing](references/missing.md)\n`;
  await writeFile(entry, broken);

  // HEAD still validates, which is exactly why committed bytes cannot stand in for the candidate.
  const release = await exportCommittedRelease(checkout, path.join(root, 'committed-release'));
  assert.deepEqual((await validateSkillAssets(release, ['sample-skill'])).map(({ name }) => name),
    ['sample-skill']);

  const before = git(checkout, 'status', '--porcelain');
  const install = path.join(root, 'candidate-install');
  await installCandidate(checkout, install);
  await assert.rejects(validateSkillAssets(path.join(install, 'skills'), ['sample-skill']),
    /sample-skill\/SKILL\.md: local link target does not exist/);
  assert.equal(git(checkout, 'status', '--porcelain'), before);
  assert.equal(await readFile(entry, 'utf8'), broken);

  // Cleanup removes the disposable copy and nothing else.
  await rm(install, { recursive: true, force: true });
  assert.equal(await readFile(entry, 'utf8'), broken);
  assert.equal(await exists(path.join(root, 'committed-release', 'skills')), true);
});

test('unstaged discovery links are included and dangling links remain detectable', async (t) => {
  const root = await makeRoot(t);
  const checkout = await makeCandidateCheckout(root, ['sample-skill']);
  await writeSkill(path.join(checkout, 'skills'), 'new-skill');
  const link = path.join(checkout, '.claude', 'skills', 'new-skill');
  await symlink('../../skills/new-skill', link);

  const install = path.join(root, 'candidate-install');
  await installCandidate(checkout, install);
  assert.deepEqual((await validateSkillAssets(path.join(install, 'skills'), ['sample-skill', 'new-skill']))
    .map(({ name }) => name), ['new-skill', 'sample-skill']);
  assert.equal((await lstat(path.join(install, '.claude', 'skills', 'new-skill'))).isSymbolicLink(), true);
  assert.deepEqual(await findBrokenSkillLinks(path.join(install, '.claude', 'skills'),
    path.join(install, 'skills')), []);

  await rm(link);
  await symlink('../../skills/missing-skill', link);
  const broken = path.join(root, 'broken-install');
  await installCandidate(checkout, broken);
  assert.deepEqual(await findBrokenSkillLinks(path.join(broken, '.claude', 'skills'),
    path.join(broken, 'skills')), ['new-skill -> ../../skills/missing-skill: is a dangling link']);
});

test('copied relative discovery link survives removal of its source checkout', async (t) => {
  const root = await makeRoot(t);
  const checkout = await makeCandidateCheckout(root, ['sample-skill']);
  const install = path.join(root, 'candidate-install');
  await installCandidate(checkout, install);
  await rename(checkout, path.join(root, 'retired-source'));

  const link = path.join(install, '.claude', 'skills', 'sample-skill');
  assert.equal(await readlink(link), '../../skills/sample-skill');
  assert.deepEqual(await findBrokenSkillLinks(path.dirname(link), path.join(install, 'skills')), []);
  assert.equal(await readFile(path.join(link, 'SKILL.md'), 'utf8'),
    await readFile(path.join(install, 'skills', 'sample-skill', 'SKILL.md'), 'utf8'));
});

test('copied discovery links reject available external skills', async (t) => {
  const root = await makeRoot(t);
  const checkout = await makeCandidateCheckout(root, ['sample-skill']);
  const sourceLink = path.join(checkout, '.claude', 'skills', 'sample-skill');
  const external = await writeSkill(root, 'external-skill');
  const targets = [path.join(checkout, 'skills', 'sample-skill'),
    path.relative(path.dirname(sourceLink), external)];

  for (const [index, target] of targets.entries()) {
    await rm(sourceLink);
    await symlink(target, sourceLink);
    const install = path.join(root, `candidate-install-${index}`);
    await installCandidate(checkout, install);
    const links = path.join(install, '.claude', 'skills');
    assert.equal(await readlink(path.join(links, 'sample-skill')), target);
    const actual = await realpath(path.join(links, 'sample-skill'));
    assert.equal(actual, await realpath(index === 0
      ? path.join(checkout, 'skills', 'sample-skill') : external));
    assert.equal((await stat(path.join(actual, 'SKILL.md'))).isFile(), true);
    const broken = await findBrokenSkillLinks(links, path.join(install, 'skills'));
    assert.equal(broken.length, 1);
    assert.ok(broken[0].includes(`sample-skill -> ${target}:`));
    assert.ok(broken[0].includes(actual));
  }
});

test('copied discovery link rejects another skill in its own collection', async (t) => {
  const root = await makeRoot(t);
  const checkout = await makeCandidateCheckout(root, ['sample-skill', 'other-skill']);
  const link = path.join(checkout, '.claude', 'skills', 'sample-skill');
  const valid = path.join(root, 'valid-install');
  await installCandidate(checkout, valid);
  assert.deepEqual(await findBrokenSkillLinks(path.join(valid, '.claude', 'skills'),
    path.join(valid, 'skills')), []);

  await rm(link);
  await symlink('../../skills/other-skill', link);
  const invalid = path.join(root, 'invalid-install');
  await installCandidate(checkout, invalid);
  const broken = await findBrokenSkillLinks(path.join(invalid, '.claude', 'skills'),
    path.join(invalid, 'skills'));
  assert.equal(broken.length, 1);
  assert.ok(broken[0].includes('sample-skill -> ../../skills/other-skill:'));
  assert.ok(broken[0].includes(await realpath(path.join(invalid, 'skills', 'other-skill'))));
});

test('a substituted skill directory cannot be flattened into the candidate', async (t) => {
  const root = await makeRoot(t);
  const checkout = await makeCandidateCheckout(root, ['sample-skill']);
  const replacement = await writeSkill(root, 'sample-skill');
  const skill = path.join(checkout, 'skills', 'sample-skill');
  await rm(skill, { recursive: true });
  await symlink(replacement, skill);

  await assert.rejects(installCandidate(checkout, path.join(root, 'candidate-install')),
    /symlinked candidate directory/);
});

test('staged additions and retirements install as one candidate, and unknown skills stay visible', async (t) => {
  const root = await makeRoot(t);
  const checkout = await makeCandidateCheckout(root, ['sample-skill', 'retired-skill']);
  const skills = path.join(checkout, 'skills');
  const order = ['sample-skill', 'staged-skill'];

  // A staged addition and a not-yet-staged retirement are one candidate, never HEAD mixed with
  // a new catalog.
  await writeSkill(skills, 'staged-skill');
  await symlink('../../skills/staged-skill', path.join(checkout, '.claude', 'skills', 'staged-skill'));
  git(checkout, 'add', '-A');
  await rm(path.join(skills, 'retired-skill'), { recursive: true, force: true });
  await rm(path.join(checkout, '.claude', 'skills', 'retired-skill'), { force: true });

  // Untracked content inside a candidate package ships; ignored runtime data, personal files, and
  // untracked non-skill debris do not.
  await mkdir(path.join(skills, 'ignored-cache'), { recursive: true });
  await writeFile(path.join(skills, 'ignored-cache', 'session.json'), '{"token":"user"}\n');
  await mkdir(path.join(skills, 'staged-skill', 'node_modules', 'dep'), { recursive: true });
  await writeFile(path.join(skills, 'staged-skill', 'node_modules', 'dep', 'index.js'), 'module.exports = 1;\n');
  await writeFile(path.join(skills, 'staged-skill', 'debug.log'), 'local noise\n');
  await writeFile(path.join(skills, 'staged-skill', 'references', 'notes.md'), '# Untracked notes\n');
  await mkdir(path.join(skills, 'cache-only', 'scripts'), { recursive: true });
  await writeFile(path.join(skills, 'cache-only', 'scripts', 'retained.bin'), 'user bytes\n');

  const release = await exportCommittedRelease(checkout, path.join(root, 'committed-release'));
  await assert.rejects(validateSkillAssets(release, order), /skill catalog mismatch/);

  const install = path.join(root, 'candidate-install');
  await installCandidate(checkout, install);
  assert.deepEqual(
    (await validateSkillAssets(path.join(install, 'skills'), order)).map(({ name }) => name),
    order,
  );
  assert.deepEqual(await findBrokenSkillLinks(path.join(install, '.claude', 'skills'),
    path.join(install, 'skills')), []);
  assert.deepEqual((await readdir(path.join(install, '.claude', 'skills'))).sort(),
    ['sample-skill', 'staged-skill']);
  assert.equal(await readFile(path.join(install, 'skills', 'INDEX.md'), 'utf8'), '# Tracked candidate index\n');
  assert.equal(await readFile(path.join(install, 'skills', 'staged-skill', 'references', 'notes.md'), 'utf8'),
    '# Untracked notes\n');
  for (const excluded of ['cache-only/scripts/retained.bin', 'ignored-cache/session.json',
    'staged-skill/node_modules/dep/index.js', 'staged-skill/debug.log']) {
    assert.equal(await exists(path.join(install, 'skills', excluded)), false, `${excluded} is not installable`);
  }

  // A discoverable skill missing from the catalog is not filtered away.
  await writeSkill(skills, 'unknown-skill');
  const discovered = path.join(root, 'discovered-install');
  await installCandidate(checkout, discovered);
  await assert.rejects(validateSkillAssets(path.join(discovered, 'skills'), order),
    /skill catalog mismatch: discovered sample-skill, staged-skill, unknown-skill/);
  await rm(path.join(skills, 'unknown-skill'), { recursive: true, force: true });

  // Link identity survives the copy, so a symlinked entry point is still rejected.
  const stagedEntry = path.join(skills, 'staged-skill', 'SKILL.md');
  await writeFile(path.join(skills, 'staged-skill', 'entry.md'), await readFile(stagedEntry, 'utf8'));
  await rm(stagedEntry, { force: true });
  await symlink('entry.md', stagedEntry);
  const linked = path.join(root, 'linked-install');
  await installCandidate(checkout, linked);
  await assert.rejects(validateSkillAssets(path.join(linked, 'skills'), order),
    /skill assets must be regular files or directories/);
});

test('broken skill links are reported for the intended reason', async (t) => {
  const root = await makeRoot(t);
  const skills = path.join(root, 'skills');
  const links = path.join(root, '.claude', 'skills');
  await mkdir(path.join(skills, 'live-skill'), { recursive: true });
  await writeFile(path.join(skills, 'live-skill', 'SKILL.md'), '# live-skill\n');
  await mkdir(path.join(skills, 'not-a-skill'));
  await writeFile(path.join(skills, 'not-a-directory'), '# not a skill directory\n');
  await mkdir(links, { recursive: true });
  await symlink('../../skills/live-skill', path.join(links, 'live-skill'));
  await symlink('../../skills/retired-skill', path.join(links, 'retired-skill'));
  await symlink('../../skills/not-a-skill', path.join(links, 'not-a-skill'));
  await symlink('../../skills/not-a-directory', path.join(links, 'not-a-directory'));

  assert.deepEqual(await findBrokenSkillLinks(links, skills), [
    'not-a-directory -> ../../skills/not-a-directory: is not a skill directory',
    'not-a-skill -> ../../skills/not-a-skill: has no SKILL.md',
    'retired-skill -> ../../skills/retired-skill: is a dangling link',
  ]);
});
