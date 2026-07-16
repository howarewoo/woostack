import {
  chmod as chmodAsync,
  copyFile as copyFileAsync,
  lstat as lstatAsync,
  mkdir as mkdirAsync,
  mkdtemp as mkdtempAsync,
  readdir as readdirAsync,
  readFile as readFileAsync,
  realpath as realpathAsync,
  rm as rmAsync,
  writeFile as writeFileAsync,
} from 'node:fs/promises';
import { spawn, spawnSync } from 'node:child_process';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { hashPackage, parseFrontmatter, validatePackage } from './validate.mjs';

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const DEFAULT_CATALOG_ROOT = path.resolve(SCRIPT_DIR, '..', '..');
const DEFAULT_BASELINE_RESOLVER = path.resolve(
  SCRIPT_DIR,
  '..',
  '..',
  'woostack-init',
  'scripts',
  'resolve-base.sh',
);

const RUN_ID_RE = /^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/;
const SAFE_FILE_MODE = 0o700;
const MAX_CHILD_BYTES = 16 * 1024 * 1024;
const MAX_ARGUMENT_BYTES = 4096;
const MAX_CASE_ID_LENGTH = 64;
const MAX_DIAGNOSTIC_BYTES = 1000;
const MAX_CHILD_TERMINATION_MS = 2000;
const MAX_CASE_COUNT = 100;
const MAX_CASE_REPETITIONS = 500;
const MAX_PROJECTED_WORKSPACE_BYTES = 64 * 1024 * 1024;

const trackedChildren = new Set();
const tempRoots = new Set();
let allocated = null;

function emit(...parts) {
  process.stderr.write(`${parts.join(' ')}\n`);
}

function hasControlOrNul(value) {
  return /[\x00-\x1F\x7F]/.test(value);
}

function compareText(left, right) {
  return left < right ? -1 : left > right ? 1 : 0;
}

function formatRunId(timestamp = new Date(), pid = process.pid) {
  const z = (value) => String(value).padStart(2, '0');
  return `${timestamp.getUTCFullYear()}${z(timestamp.getUTCMonth() + 1)}${z(timestamp.getUTCDate())}T${z(timestamp.getUTCHours())}${z(timestamp.getUTCMinutes())}${z(timestamp.getUTCSeconds())}Z-${pid}`;
}

function validateControl(value, label) {
  if (hasControlOrNul(value)) {
    throw new Error(`invalid ${label}`);
  }
}

function validateArgumentSize(value, label) {
  if (Buffer.byteLength(value, 'utf8') > MAX_ARGUMENT_BYTES) {
    throw new Error(`${label} exceeds ${MAX_ARGUMENT_BYTES} bytes`);
  }
}

function boundedDiagnostic(error) {
  const raw = error && error.message ? error.message : String(error);
  let clean = raw.replace(/[\x00-\x1F\x7F]/g, '?');
  const bytes = Buffer.from(clean, 'utf8');
  if (bytes.byteLength <= MAX_DIAGNOSTIC_BYTES) return clean;
  clean = bytes.subarray(0, MAX_DIAGNOSTIC_BYTES - 3).toString('utf8').replace(/\uFFFD+$/g, '');
  return `${clean}...`;
}

function isSafeRelativePath(raw) {
  if (typeof raw !== 'string' || raw.length === 0) return false;
  if (raw.includes('\\')) return false;
  if (path.isAbsolute(raw)) return false;
  const parts = raw.split('/').filter(Boolean);
  if (parts.length === 0) return false;
  for (const part of parts) {
    if (part === '.' || part === '..') return false;
  }
  return !hasControlOrNul(raw);
}

function isSafeRunId(value) {
  return typeof value === 'string' && RUN_ID_RE.test(value);
}



function toCanonical(value) {
  return value.split(path.sep).join('/');
}

function parseCommandLine(argv) {
  const options = {
    target: null,
    mode: null,
    runs: null,
    baselineRef: null,
    baselinePath: null,
    catalogRoot: null,
    outRoot: null,
    runId: null,
  };
  const seen = new Set();

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    validateControl(arg, 'argument');
    validateArgumentSize(arg, 'argument');
    if (!arg.startsWith('--')) {
      throw new Error(`Unknown positional argument: ${arg}`);
    }

    const readValue = () => {
      const value = argv[index + 1];
      if (!value || value.startsWith('--')) {
        throw new Error(`${arg} requires a value`);
      }
      validateControl(value, arg);
      validateArgumentSize(value, arg);
      index += 1;
      return value;
    };

    switch (arg) {
      case '--target': {
        if (seen.has('target')) throw new Error('Repeated flag: --target');
        options.target = readValue();
        seen.add('target');
        break;
      }
      case '--mode': {
        if (seen.has('mode')) throw new Error('Repeated flag: --mode');
        const value = readValue();
        if (value !== 'behavior' && value !== 'triggers' && value !== 'all') {
          throw new Error(`Unsupported mode: ${value}`);
        }
        options.mode = value;
        seen.add('mode');
        break;
      }
      case '--runs': {
        if (seen.has('runs')) throw new Error('Repeated flag: --runs');
        const value = readValue();
        const parsed = Number(value);
        if (!Number.isInteger(parsed) || parsed < 1 || parsed > 10 || !/^[0-9]+$/.test(value)) {
          throw new Error(`Invalid runs: ${value}`);
        }
        options.runs = parsed;
        seen.add('runs');
        break;
      }
      case '--baseline-ref': {
        if (seen.has('baseline-path')) {
          throw new Error('Cannot combine --baseline-ref and --baseline-path');
        }
        if (seen.has('baseline-ref')) throw new Error('Repeated flag: --baseline-ref');
        options.baselineRef = readValue();
        seen.add('baseline-ref');
        break;
      }
      case '--baseline-path': {
        if (seen.has('baseline-ref')) {
          throw new Error('Cannot combine --baseline-ref and --baseline-path');
        }
        if (seen.has('baseline-path')) throw new Error('Repeated flag: --baseline-path');
        options.baselinePath = readValue();
        if (!path.isAbsolute(options.baselinePath)) {
          throw new Error('--baseline-path must be absolute');
        }
        seen.add('baseline-path');
        break;
      }
      case '--catalog-root': {
        if (seen.has('catalog-root')) throw new Error('Repeated flag: --catalog-root');
        options.catalogRoot = readValue();
        if (!path.isAbsolute(options.catalogRoot)) {
          throw new Error('--catalog-root must be absolute');
        }
        seen.add('catalog-root');
        break;
      }
      case '--out-root': {
        if (seen.has('out-root')) throw new Error('Repeated flag: --out-root');
        options.outRoot = readValue();
        if (!path.isAbsolute(options.outRoot)) {
          throw new Error('--out-root must be absolute');
        }
        seen.add('out-root');
        break;
      }
      case '--run-id': {
        if (seen.has('run-id')) throw new Error('Repeated flag: --run-id');
        options.runId = readValue();
        if (!isSafeRunId(options.runId)) {
          throw new Error(`Invalid run-id: ${options.runId}`);
        }
        seen.add('run-id');
        break;
      }
      default:
        throw new Error(`Unknown argument: ${arg}`);
    }
  }

  if (!options.target || !options.mode || options.runs === null) {
    throw new Error('Missing required flags: --target, --mode, --runs');
  }
  if (options.baselinePath && !path.isAbsolute(options.baselinePath)) {
    throw new Error('--baseline-path must be absolute');
  }
  if (options.runId && !isSafeRunId(options.runId)) {
    throw new Error(`Invalid run-id: ${options.runId}`);
  }

  return options;
}

function parseGitSha(value) {
  const normalized = String(value || '').trim().toLowerCase();
  if (!/^[0-9a-f]{40}$/.test(normalized)) return null;
  return normalized;
}

function isBlobMode(mode) {
  return mode === '100644' || mode === '100755';
}

function terminateChild(child) {
  if (process.platform === 'win32' && child.pid) {
    try {
      spawnSync('taskkill', ['/PID', String(child.pid), '/T', '/F'], {
        stdio: 'ignore',
        timeout: MAX_CHILD_TERMINATION_MS,
        windowsHide: true,
      });
    } catch {
      // Fall back to the direct child when taskkill is unavailable.
    }
  }
  if (process.platform !== 'win32' && child.pid) {
    try {
      process.kill(-child.pid, 'SIGKILL');
      return;
    } catch {
      // Fall back to the direct child when its process group is already gone.
    }
  }
  try {
    child.kill('SIGKILL');
  } catch {
    // The child may already have exited.
  }
}

async function runCommand(command, args, {
  cwd = process.cwd(),
  env = process.env,
  timeoutMs = 10000,
  allowCodes = [0],
  encoding = 'utf8',
} = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd,
      env,
      detached: process.platform !== 'win32',
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    trackedChildren.add(child);
    const stdoutChunks = [];
    const stderrChunks = [];
    let stdoutBytes = 0;
    let stderrBytes = 0;
    let settled = false;
    let terminationError = null;
    let terminationTimer = null;

    const finish = (action, value) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      clearTimeout(terminationTimer);
      trackedChildren.delete(child);
      action(value);
    };
    const timeoutError = () => {
      const error = new Error(`command timeout: ${command} ${args.join(' ')}`);
      error.code = 'ETIMEDOUT';
      return error;
    };
    const terminateWithDeadline = (error) => {
      if (terminationError) return;
      terminationError = error;
      terminateChild(child);
      terminationTimer = setTimeout(() => finish(reject, error), MAX_CHILD_TERMINATION_MS);
    };

    const timer = setTimeout(() => {
      terminateWithDeadline(timeoutError());
    }, timeoutMs);

    const pushChunk = (chunk, kind) => {
      if (!chunk?.length || settled) return;
      const nextSize = (kind === 'stdout' ? stdoutBytes : stderrBytes) + chunk.length;
      if (nextSize > MAX_CHILD_BYTES) {
        terminateWithDeadline(new Error(`command output exceeded limit: ${command} ${args.join(' ')}`));
        return;
      }
      if (kind === 'stdout') {
        stdoutBytes = nextSize;
        stdoutChunks.push(chunk);
      } else {
        stderrBytes = nextSize;
        stderrChunks.push(chunk);
      }
    };

    child.stdout?.on('data', (chunk) => pushChunk(chunk, 'stdout'));
    child.stderr?.on('data', (chunk) => pushChunk(chunk, 'stderr'));

    child.once('error', (error) => finish(reject, error));

    child.once('close', (code, signal) => {
      if (settled) return;
      const stdout = encoding === 'buffer'
        ? Buffer.concat(stdoutChunks)
        : Buffer.concat(stdoutChunks).toString(encoding);
      const stderr = encoding === 'buffer'
        ? Buffer.concat(stderrChunks)
        : Buffer.concat(stderrChunks).toString(encoding);

      if (terminationError) {
        finish(reject, terminationError);
        return;
      }

      if (!allowCodes.includes(code)) {
        const failed = new Error(`command failed (${code ?? signal ?? 'signal'}) : ${command} ${args.join(' ')}`);
        failed.code = code;
        failed.stderr = String(stderr);
        failed.stdout = String(stdout);
        finish(reject, failed);
        return;
      }

      finish(resolve, { code, stdout, stderr });
    });
  });
}

function gitEnvironment(env = {}) {
  return {
    ...process.env,
    ...env,
    GIT_CONFIG_COUNT: '1',
    GIT_CONFIG_KEY_0: 'core.fsmonitor',
    GIT_CONFIG_VALUE_0: 'false',
  };
}

async function runGit(cwd, args, opts = {}) {
  return runCommand('git', ['-c', 'core.fsmonitor=false', ...args], {
    cwd,
    ...opts,
    env: gitEnvironment(opts.env),
    allowCodes: opts.allowCodes ?? [0],
  });
}
async function readIndexTree(gitRoot) {
  let failure;
  for (let attempt = 0; attempt < 10; attempt += 1) {
    try {
      return String((await runGit(gitRoot, ['write-tree'])).stdout).trim();
    } catch (error) {
      failure = error;
      await new Promise((resolve) => setTimeout(resolve, (attempt + 1) * 10));
    }
  }
  throw failure;
}

async function snapshotSource(packageRoot, gitRoot) {
  const packageHash = await hashPackage(packageRoot, { trackedOnly: false });
  if (!packageHash) throw new Error('could not snapshot target package');
  if (!gitRoot) return { packageHash, git: null };
  const head = String((await runGit(gitRoot, ['rev-parse', 'HEAD'])).stdout).trim();
  const indexTree = await readIndexTree(gitRoot);
  const porcelain = (await runGit(
    gitRoot,
    ['status', '--porcelain=v1', '-z', '--untracked-files=all'],
    { encoding: 'buffer' },
  )).stdout;
  return { packageHash, git: { head, indexTree, porcelain } };
}

async function assertSourceUnchanged(before, packageRoot, gitRoot) {
  const after = await snapshotSource(packageRoot, gitRoot);
  const sameGit = before.git === null
    ? after.git === null
    : after.git !== null
      && before.git.head === after.git.head
      && before.git.indexTree === after.git.indexTree
      && before.git.porcelain.equals(after.git.porcelain);
  if (before.packageHash !== after.packageHash || !sameGit) {
    throw new Error('source target changed during preparation');
  }
}


async function resolveGitRoot(startPath) {
  const result = await runGit(startPath, ['rev-parse', '--show-toplevel'], { allowCodes: [0, 128] });
  if (result.code === 0) {
    const root = String(result.stdout || '').trim();
    if (!root) throw new Error('Git returned an empty repository root');
    return path.resolve(root);
  }
  if (!/not a git repository/i.test(String(result.stderr || ''))) {
    throw new Error('Git repository resolution failed');
  }

  for (let current = path.resolve(startPath); ; current = path.dirname(current)) {
    try {
      await lstatAsync(path.join(current, '.git'));
      throw new Error('Git metadata is present but invalid or unreadable');
    } catch (error) {
      if (error?.code !== 'ENOENT') throw error;
    }
    const parent = path.dirname(current);
    if (parent === current) return null;
  }
}

async function runResolver(gitRoot) {
  const info = await lstatAsync(DEFAULT_BASELINE_RESOLVER);
  if (!info.isFile() || info.isSymbolicLink()) {
    throw new Error('canonical resolver missing');
  }
  const result = await runCommand('bash', [DEFAULT_BASELINE_RESOLVER], {
    cwd: gitRoot,
    timeoutMs: 15000,
    env: gitEnvironment(),
    allowCodes: [0],
  });
  const branch = String(result.stdout || '').trim().split('\n')[0];
  if (!branch) {
    throw new Error('canonical resolver returned no branch');
  }
  return branch;
}

function safePackageRelative(gitRoot, packageRoot) {
  const relative = path.relative(gitRoot, packageRoot);
  if (!relative || relative === '.' || relative.startsWith('..') || path.isAbsolute(relative)) {
    return null;
  }
  return toCanonical(relative);
}

function parseValidation(value, label) {
  if (!value || !value.valid) {
    const first = Array.isArray(value?.errors) && value.errors.length > 0
      ? `${value.errors[0].code} ${value.errors[0].message}`
      : 'invalid package';
    throw new Error(`${label} validation failed: ${first}`);
  }
}

async function validateTargetPackage(input, defaultRoot) {
  const result = await validatePackage(input, { repositoryRoot: defaultRoot, trackedOnly: false });
  parseValidation(result, 'target');

  const packageRoot = await realpathAsync(path.resolve(defaultRoot, result.package.path));
  const hash = await hashPackage(input, { trackedOnly: false });
  if (!hash) {
    throw new Error('could not hash target package');
  }

  const name = result.package?.name;
  const description = result.package?.description;
  if (!name || !description) {
    throw new Error('target package lacks name or description');
  }

  return {
    root: packageRoot,
    name,
    description,
    hash,
    validation: result,
  };
}

async function loadCasesFromCorpus(corpusPath, mode) {
  let raw;
  try {
    raw = await readFileAsync(corpusPath, 'utf8');
  } catch (error) {
    if (error?.code === 'ENOENT') return [];
    throw error;
  }

  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return [];
  }

  const entries = Array.isArray(parsed?.cases) ? parsed.cases : [];
  if (mode === 'behavior') {
    return entries
      .map((entry) => {
        const id = typeof entry?.id === 'string' ? entry.id : '';
        const fixtureEntries = [];
        const fixtures = Array.isArray(entry?.fixtures) ? entry.fixtures : [];
        for (const fixture of fixtures) {
          if (typeof fixture !== 'string' || !isSafeRelativePath(fixture)) {
            continue;
          }
          if (!fixtureEntries.includes(fixture)) {
            fixtureEntries.push(fixture);
          }
        }
        return { id, kind: 'behavior', fixtures: fixtureEntries, definition: entry };
      })
      .filter((item) => item.id)
      .sort((left, right) => compareText(left.id, right.id));
  }

  return entries
    .map((entry) => ({
      id: typeof entry?.id === 'string' ? entry.id : '',
      kind: 'trigger',
      definition: entry,
    }))
    .filter((item) => item.id)
    .sort((left, right) => compareText(left.id, right.id));
}

async function loadPublicSkillNames(catalogRoot) {
  const authorityRoot = path.join(catalogRoot, 'using-woostack');
  const validation = await validatePackage(authorityRoot, {
    repositoryRoot: catalogRoot,
    trackedOnly: false,
  });
  parseValidation(validation, 'public command authority');

  const content = await readFileAsync(path.join(authorityRoot, 'SKILL.md'), 'utf8');
  const names = new Set(['using-woostack']);
  let inRouting = false;
  let routeCount = 0;
  for (const line of content.split(/\r?\n/)) {
    if (line === '## Command Routing') {
      inRouting = true;
      continue;
    }
    if (inRouting && line.startsWith('## ')) break;
    if (!inRouting) continue;
    const route = line.match(/^\|.*\|\s*`([a-z0-9]+(?:-[a-z0-9]+)*)`\s*\|\s*$/);
    if (!route) continue;
    names.add(route[1]);
    routeCount += 1;
  }
  if (routeCount === 0) {
    throw new Error('public command authority has no routing entries');
  }
  return names;
}

async function loadCatalogSkills(catalogRoot, publicSkillNames) {
  const root = path.resolve(catalogRoot);
  const rootStat = await lstatAsync(root);
  if (!rootStat.isDirectory() || rootStat.isSymbolicLink()) {
    throw new Error('--catalog-root must be a directory');
  }
  const skills = [];
  for (const publicName of [...publicSkillNames].sort(compareText)) {
    const packageRoot = path.join(root, publicName);
    let packageState;
    try {
      packageState = await lstatAsync(packageRoot);
    } catch (error) {
      if (error?.code === 'ENOENT') throw new Error(`catalog entry missing: ${publicName}`);
      throw error;
    }
    if (packageState.isSymbolicLink() || !packageState.isDirectory()) {
      throw new Error(`invalid catalog entry: ${publicName}`);
    }
    const skillPath = path.join(packageRoot, 'SKILL.md');
    let skillState;
    try {
      skillState = await lstatAsync(skillPath);
    } catch (error) {
      if (error?.code === 'ENOENT') throw new Error(`catalog entry lacks SKILL.md: ${publicName}`);
      throw error;
    }
    if (skillState.isSymbolicLink() || !skillState.isFile()) {
      throw new Error(`invalid catalog skill file: ${skillPath}`);
    }
    const content = await readFileAsync(skillPath, 'utf8');
    const parsed = parseFrontmatter(content, path.join(publicName, 'SKILL.md'));
    const name = parsed.fm.name;
    const description = parsed.fm.description;
    if (name !== publicName || !description) {
      throw new Error(`invalid catalog skill identity: ${publicName}`);
    }
    skills.push({ name, description });
  }
  return skills;
}

function catalogForTarget(baseSkills, includeTarget, targetName, targetDescription) {
  const byName = new Map();
  for (const skill of baseSkills) {
    byName.set(skill.name, { name: skill.name, description: skill.description });
  }
  byName.delete(targetName);
  if (includeTarget) {
    byName.set(targetName, { name: targetName, description: targetDescription });
  }
  return {
    schemaVersion: 1,
    skills: [...byName.values()].sort((left, right) => compareText(left.name, right.name)),
  };
}

async function materializeGitPackage(gitRoot, commit, packageRelative) {
  const ls = await runGit(gitRoot, ['ls-tree', '-r', '-z', commit, '--', packageRelative], {
    allowCodes: [0],
    encoding: 'utf8',
    timeoutMs: 20000,
  });
  const raw = String(ls.stdout || '');
  const records = raw.split('\0').filter(Boolean);
  if (records.length === 0) {
    return {
      present: false,
      tempRoot: null,
      packageRoot: null,
    };
  }

  const tempRoot = await mkdtempAsync(path.join(os.tmpdir(), 'woostack-eval-baseline-'));
  tempRoots.add(tempRoot);
  const packageRoot = path.join(tempRoot, path.posix.basename(packageRelative));
  await mkdirAsync(packageRoot, { mode: SAFE_FILE_MODE, recursive: true });

  for (const rawEntry of records) {
    const split = rawEntry.indexOf('\t');
    if (split < 0) throw new Error('invalid git ls-tree output');
    const meta = rawEntry.slice(0, split);
    const filePath = rawEntry.slice(split + 1);
    const parts = meta.split(' ');
    if (parts.length !== 3) throw new Error('invalid git ls-tree metadata');
    const [mode, kind] = parts;
    if (kind !== 'blob' || !isBlobMode(mode)) {
      throw new Error(`invalid git blob mode for ${filePath}`);
    }
    if (!isSafeRelativePath(filePath) && filePath !== packageRelative) {
      throw new Error(`invalid git path in tree: ${filePath}`);
    }
    if (!toCanonical(filePath).startsWith(`${toCanonical(packageRelative)}/`)) {
      throw new Error(`tree path outside package: ${filePath}`);
    }
    const relative = toCanonical(filePath).slice(packageRelative.length + 1);
    if (!isSafeRelativePath(relative)) throw new Error(`invalid relative blob path: ${relative}`);
    const { stdout } = await runGit(gitRoot, ['show', `${commit}:${filePath}`], {
      allowCodes: [0],
      encoding: 'buffer',
      timeoutMs: 20000,
    });
    const destination = path.join(packageRoot, relative);
    await mkdirAsync(path.dirname(destination), { mode: SAFE_FILE_MODE, recursive: true });
    await writeFileAsync(destination, stdout);
    await chmodAsync(destination, mode === '100755' ? 0o755 : 0o644);
  }

  return {
    present: true,
    tempRoot,
    packageRoot,
  };
}

async function copyDirectory(source, destination, prefix = '', { includeFixtures = false } = {}) {
  const sourceState = await lstatAsync(source);
  if (!sourceState.isDirectory() || sourceState.isSymbolicLink()) {
    throw new Error(`invalid source directory: ${source}`);
  }

  await mkdirAsync(destination, { mode: SAFE_FILE_MODE, recursive: true });
  const children = await readdirAsync(source, { withFileTypes: true });
  const sorted = children.sort((left, right) => compareText(left.name, right.name));
  for (const child of sorted) {
    if (!isSafeRelativePath(child.name)) throw new Error(`unsafe path: ${child.name}`);
    const relative = prefix ? `${prefix}/${child.name}` : child.name;
    if (
      (!includeFixtures && relative === 'evals/fixtures')
      || relative === '.woostack/tmp/skill-evals'
      || relative.startsWith('.woostack/tmp/skill-evals/')
    ) {
      continue;
    }
    const from = path.join(source, child.name);
    const to = path.join(destination, child.name);
    const state = await lstatAsync(from);
    if (state.isSymbolicLink()) {
      throw new Error(`symlink not allowed: ${from}`);
    }
    if (state.isDirectory()) {
      await copyDirectory(from, to, relative, { includeFixtures });
      continue;
    }
    if (!state.isFile()) {
      throw new Error(`special file not allowed: ${from}`);
    }
    await mkdirAsync(path.dirname(to), { mode: SAFE_FILE_MODE, recursive: true });
    await copyFileAsync(from, to);
  }
}

async function copyFixture(sourcePackage, relativeFixture, destinationFixtures) {
  if (!isSafeRelativePath(relativeFixture)) {
    throw new Error(`invalid fixture path: ${relativeFixture}`);
  }
  const source = path.join(sourcePackage, 'evals', 'fixtures', relativeFixture);
  const state = await lstatAsync(source);
  if (state.isSymbolicLink()) {
    throw new Error(`fixture symlink: ${relativeFixture}`);
  }
  if (!state.isFile()) {
    throw new Error(`fixture is not a file: ${relativeFixture}`);
  }
  const destination = path.join(destinationFixtures, relativeFixture);
  await mkdirAsync(path.dirname(destination), { mode: SAFE_FILE_MODE, recursive: true });
  await copyFileAsync(source, destination);
}

function buildSelection(mode, behaviorCases, triggerCases, runs) {
  const selected = [];
  const selectedIds = new Set();
  const kinds = [];
  if (mode === 'behavior' || mode === 'all') kinds.push('behavior');
  if (mode === 'triggers' || mode === 'all') kinds.push('trigger');

  for (const kind of kinds) {
    const cases = kind === 'behavior' ? behaviorCases : triggerCases;
    for (const item of cases) {
      if (item.id.length > MAX_CASE_ID_LENGTH) {
        throw new Error(`case id exceeds ${MAX_CASE_ID_LENGTH} characters: ${item.id}`);
      }
      if (selectedIds.has(item.id)) {
        throw new Error(`duplicate selected case id across corpora: ${item.id}`);
      }
      selectedIds.add(item.id);
      if (selectedIds.size > MAX_CASE_COUNT) {
        throw new Error(`selected case count exceeds ${MAX_CASE_COUNT}`);
      }
      if (selected.length + runs > MAX_CASE_REPETITIONS) {
        throw new Error(`selected case repetitions exceed ${MAX_CASE_REPETITIONS}`);
      }
      for (let repetition = 1; repetition <= runs; repetition += 1) {
        selected.push({
          caseId: item.id,
          kind,
          repetition,
          fixtures: item.kind === 'behavior' ? item.fixtures : [],
          definition: item.definition,
        });
      }
    }
  }
  return selected;
}
function sumPackageBytes(files, includeFixtures) {
  let total = 0n;
  for (const file of files) {
    if (!includeFixtures && file.path.startsWith('evals/fixtures/')) continue;
    total += BigInt(file.bytes);
  }
  return total;
}

function assertWorkspaceBudget(selected, target, baseline, catalogSkills) {
  const candidatePackageBytes = sumPackageBytes(target.validation.files, false);
  const baselinePackageBytes = sumPackageBytes(baseline.files, false);
  const fixtureBytes = new Map(
    target.validation.files
      .filter((file) => file.path.startsWith('evals/fixtures/'))
      .map((file) => [file.path.slice('evals/fixtures/'.length), BigInt(file.bytes)]),
  );
  const candidateCatalogBytes = BigInt(Buffer.byteLength(`${JSON.stringify(catalogForTarget(
    catalogSkills,
    true,
    target.name,
    target.description,
  ))}\n`));
  const baselineCatalogBytes = BigInt(Buffer.byteLength(`${JSON.stringify(catalogForTarget(
    catalogSkills,
    baseline.packageRoot !== null,
    baseline.packageRoot !== null ? baseline.name : target.name,
    baseline.packageRoot !== null ? baseline.description : target.description,
  ))}\n`));
  const frozenDefinitions = new Set();
  let projectedBytes = 0n;

  for (const item of selected) {
    projectedBytes += candidatePackageBytes + baselinePackageBytes;
    if (item.kind === 'behavior') {
      for (const fixture of item.fixtures) {
        const bytes = fixtureBytes.get(fixture);
        if (bytes === undefined) throw new Error(`fixture missing from package inventory: ${fixture}`);
        projectedBytes += bytes * 2n;
      }
    } else {
      projectedBytes += candidateCatalogBytes + baselineCatalogBytes;
    }
    const definitionName = `${item.kind}.${item.caseId}`;
    if (!frozenDefinitions.has(definitionName)) {
      frozenDefinitions.add(definitionName);
      projectedBytes += BigInt(Buffer.byteLength(`${JSON.stringify(item.definition)}\n`));
    }
  }

  if (projectedBytes > BigInt(MAX_PROJECTED_WORKSPACE_BYTES)) {
    throw new Error(
      `projected workspace exceeds ${MAX_PROJECTED_WORKSPACE_BYTES} bytes: ${projectedBytes}`,
    );
  }
}



function makeManifest({
  runId,
  targetName,
  mode,
  runs,
  baseline,
  originalPackageHash,
  packageHashes,
  gradingPlan,
  expected,
  pairs,
}) {
  return {
    schemaVersion: 1,
    runId,
    targetSkill: targetName,
    mode,
    runs,
    baseline,
    runConfiguration: {
      host: null,
      runner: null,
      model: null,
      sessionIdentity: null,
      tier: null,
      effort: null,
    },
    originalPackageHash,
    packageHashes,
    gradingPlan,
    expected,
    pairs,
  };
}

async function assertCleanDirectory(candidate, label) {
  if (!path.isAbsolute(candidate)) {
    throw new Error(`${label} must be absolute`);
  }

  const normalized = path.resolve(candidate);
  const stat = await lstatAsync(normalized);
  if (stat.isSymbolicLink()) {
    throw new Error(`${label} must not be a symlink`);
  }
  if (!stat.isDirectory()) {
    throw new Error(`${label} must be a directory`);
  }

  return candidate;
}
async function canonicalizePotentialPath(candidate) {
  try {
    return await realpathAsync(candidate);
  } catch (error) {
    if (error?.code !== 'ENOENT') throw error;
    const parent = path.dirname(candidate);
    if (parent === candidate) throw error;
    return path.join(await canonicalizePotentialPath(parent), path.basename(candidate));
  }
}

function isContained(root, candidate) {
  const relative = path.relative(root, candidate);
  return relative === '' || (!relative.startsWith(`..${path.sep}`) && relative !== '..' && !path.isAbsolute(relative));
}

async function assertOutsideSourceRoots(candidate, roots, label) {
  const canonical = await canonicalizePotentialPath(path.resolve(candidate));
  for (const root of roots.filter(Boolean)) {
    if (isContained(root, canonical)) {
      throw new Error(`${label} must not be inside a source package`);
    }
  }
  return canonical;
}

async function prepareOutputRoot(candidate, disallowedRoots) {
  const normalized = path.resolve(candidate);
  try {
    const state = await lstatAsync(normalized);
    if (state.isSymbolicLink()) throw new Error('output root must not be a symlink');
    if (!state.isDirectory()) throw new Error('output root must be a directory');
  } catch (error) {
    if (error?.code !== 'ENOENT') throw error;
  }
  const canonical = await canonicalizePotentialPath(normalized);
  for (const root of disallowedRoots.filter(Boolean)) {
    if (isContained(root, canonical)) {
      throw new Error('output root must not be inside a source package');
    }
  }
  await mkdirAsync(canonical, { mode: SAFE_FILE_MODE, recursive: true });
  return canonical;
}



function chooseOutRoot(options, gitRoot) {
  const fallback = path.isAbsolute(process.env.TMPDIR || '/tmp')
    ? (process.env.TMPDIR || '/tmp')
    : path.resolve(process.env.TMPDIR);
  if (options.outRoot) {
    return options.outRoot;
  }

  if (!gitRoot) {
    emit(`fallback output root: ${fallback}`);
    return fallback;
  }

  return runGit(gitRoot, ['check-ignore', '-q', '--', '.woostack/tmp/skill-evals/'], { allowCodes: [0, 1] })
    .then((result) => {
      if (result.code === 0) {
        return path.join(gitRoot, '.woostack', 'tmp', 'skill-evals');
      }
      emit(`fallback output root: ${fallback}`);
      return fallback;
    })
    .catch(() => {
      emit(`fallback output root: ${fallback}`);
      return fallback;
    });
}

async function allocateRunRoot(outRoot, requestedRunId) {
  const reserve = async (runId) => {
    const finalPath = path.join(outRoot, runId);
    let created = false;
    try {
      await mkdirAsync(finalPath, { mode: SAFE_FILE_MODE });
      created = true;
      await chmodAsync(finalPath, SAFE_FILE_MODE);
      const identity = await lstatAsync(finalPath);
      return {
        runId,
        finalPath,
        rootPath: finalPath,
        identity: { dev: identity.dev, ino: identity.ino },
      };
    } catch (error) {
      if (error?.code === 'EEXIST') return null;
      if (created) {
        try {
          await rmAsync(finalPath, { recursive: true, force: true });
        } catch (cleanupError) {
          throw new AggregateError(
            [error, cleanupError],
            'run-root reservation failed and rollback cleanup failed',
          );
        }
      }
      throw error;
    }
  };

  if (requestedRunId) {
    if (!isSafeRunId(requestedRunId)) throw new Error(`invalid run-id: ${requestedRunId}`);
    const allocation = await reserve(requestedRunId);
    if (!allocation) {
      throw new Error(`run id already exists: ${requestedRunId}`);
    }
    return allocation;
  }

  while (true) {
    const allocation = await reserve(formatRunId());
    if (allocation) return allocation;
  }
}

function scheduleExitCleanup() {
  let stopping = false;
  const stop = (signal, code) => {
    if (stopping) return;
    stopping = true;
    void (async () => {
      let diagnostic = `received ${signal}; cleanup complete`;
      try {
        await killTrackedChildren();
        await cleanupRun();
      } catch (error) {
        diagnostic = `received ${signal}; cleanup failed: ${boundedDiagnostic(error)}`;
      } finally {
        emit('prepare.mjs:', boundedDiagnostic(diagnostic));
        process.exit(code);
      }
    })();
  };
  process.once('SIGINT', () => stop('SIGINT', 130));
  process.once('SIGTERM', () => stop('SIGTERM', 143));
}

async function killTrackedChildren() {
  const children = [...trackedChildren];
  for (const child of children) terminateChild(child);
  await Promise.all(children.map((child) => new Promise((resolve) => {
    if (!trackedChildren.has(child)) {
      resolve();
      return;
    }
    let waitTimer;
    const finish = () => {
      clearTimeout(waitTimer);
      child.off('close', finish);
      trackedChildren.delete(child);
      resolve();
    };
    child.once('close', finish);
    waitTimer = setTimeout(finish, MAX_CHILD_TERMINATION_MS);
  })));
}

async function cleanupTemporaryRoots(failures) {
  for (const root of [...tempRoots]) {
    try {
      await rmAsync(root, { recursive: true, force: true });
      tempRoots.delete(root);
    } catch (error) {
      if (error?.code === 'ENOENT') {
        tempRoots.delete(root);
      } else {
        failures.push(error);
      }
    }
  }
}

function throwCleanupFailures(failures) {
  if (failures.length === 0) return;
  throw new Error(
    `cleanup failed (${failures.length}): ${boundedDiagnostic(failures[0])}`,
    { cause: new AggregateError(failures, 'evaluator cleanup failures') },
  );
}

async function cleanupTemporarySnapshots() {
  const failures = [];
  await cleanupTemporaryRoots(failures);
  throwCleanupFailures(failures);
}

async function cleanupRun() {
  const failures = [];
  if (allocated) {
    try {
      const state = await lstatAsync(allocated.rootPath);
      if (state.dev === allocated.identity.dev && state.ino === allocated.identity.ino) {
        await rmAsync(allocated.rootPath, { recursive: true, force: true });
      }
      allocated = null;
    } catch (error) {
      if (error?.code === 'ENOENT') {
        allocated = null;
      } else {
        failures.push(error);
      }
    }
  }
  await cleanupTemporaryRoots(failures);
  throwCleanupFailures(failures);
}

async function chooseBaseline(info, options) {
  const gitRoot = info.gitRoot;
  if (options.baselineRef) {
    if (!gitRoot) {
      throw new Error('explicit baseline-ref requires target under git');
    }
    const resolved = parseGitSha((await runGit(gitRoot, ['rev-parse', `${options.baselineRef}^{commit}`]).then((value) => value.stdout)));
    if (!resolved) {
      throw new Error(`invalid baseline ref: ${options.baselineRef}`);
    }
    const packageRelative = safePackageRelative(gitRoot, info.packageRoot);
    if (!packageRelative) {
      throw new Error('candidate package is outside git root');
    }
    const materialized = await materializeGitPackage(gitRoot, resolved, packageRelative);
    if (!materialized.present) {
      throw new Error('explicit baseline ref does not point to a package');
    }
    const validation = await validatePackage(materialized.packageRoot, {
      repositoryRoot: materialized.tempRoot,
      trackedOnly: false,
    });
    parseValidation(validation, 'baseline');
    return {
      identity: { kind: 'git-ref', identity: resolved },
      packageRoot: materialized.packageRoot,
      name: validation.package.name,
      description: validation.package.description,
      files: validation.files,
    };
  }

  if (options.baselinePath) {
    const baselineInput = path.resolve(options.baselinePath);
    const baselineState = await lstatAsync(baselineInput);
    if (baselineState.isSymbolicLink() || !baselineState.isDirectory()) {
      throw new Error('--baseline-path must name a non-symlink skill directory');
    }
    const candidate = await validateTargetPackage(baselineInput, baselineInput);
    if (candidate.name !== info.targetName) {
      throw new Error('--baseline-path must identify the same skill as --target');
    }

    const tempRoot = await mkdtempAsync(path.join(os.tmpdir(), 'woostack-eval-path-baseline-'));
    tempRoots.add(tempRoot);
    await chmodAsync(tempRoot, SAFE_FILE_MODE);
    const snapshotRoot = path.join(tempRoot, 'package');
    await copyDirectory(candidate.root, snapshotRoot, '', { includeFixtures: true });
    const snapshotHash = await hashPackage(snapshotRoot, { trackedOnly: false });
    if (snapshotHash !== candidate.hash) {
      throw new Error('explicit baseline changed while creating its private snapshot');
    }
    return {
      identity: { kind: 'path', identity: candidate.hash },
      packageRoot: snapshotRoot,
      sourceRoot: candidate.root,
      sourceHash: candidate.hash,
      name: candidate.name,
      description: candidate.description,
      files: candidate.validation.files,
    };
  }

  if (!gitRoot) {
    return {
      identity: { kind: 'none', identity: `non-git:${info.targetHash}:absent` },
      packageRoot: null,
      name: null,
      description: null,
      files: [],
    };
  }

  const baseBranch = await runResolver(gitRoot);
  const mergeBase = parseGitSha(await runGit(gitRoot, ['merge-base', 'HEAD', baseBranch]).then((value) => value.stdout));
  if (!mergeBase) {
    throw new Error('could not compute merge-base baseline');
  }
  const packageRelative = safePackageRelative(gitRoot, info.packageRoot);
  if (!packageRelative) {
    throw new Error('candidate package is outside resolved Git root');
  }
  const materialized = await materializeGitPackage(gitRoot, mergeBase, packageRelative);
  if (!materialized.present) {
    return {
      identity: { kind: 'none', identity: `${mergeBase}:absent` },
      packageRoot: null,
      name: null,
      description: null,
      files: [],
    };
  }
  const validation = await validatePackage(materialized.packageRoot, {
    repositoryRoot: materialized.tempRoot,
    trackedOnly: false,
  });
  if (!validation.valid) {
    throw new Error('merge-base baseline materialization is invalid');
  }
  return {
    identity: { kind: 'git-ref', identity: mergeBase },
    packageRoot: materialized.packageRoot,
    name: validation.package.name,
    description: validation.package.description,
    files: validation.files,
  };
}

async function synchronizeBaselineSnapshot() {
  const readyPath = process.env.WOOSTACK_EVAL_TEST_BASELINE_SNAPSHOT_READY || '';
  const releasePath = process.env.WOOSTACK_EVAL_TEST_BASELINE_SNAPSHOT_RELEASE || '';
  if (!readyPath && !releasePath) return;
  if (process.env.WOOSTACK_EVAL_TEST_MODE !== '1') {
    throw new Error('baseline snapshot synchronization requires WOOSTACK_EVAL_TEST_MODE=1');
  }
  if (!readyPath || !releasePath) {
    throw new Error('baseline snapshot synchronization paths must be provided together');
  }
  for (const [value, label] of [
    [readyPath, 'WOOSTACK_EVAL_TEST_BASELINE_SNAPSHOT_READY'],
    [releasePath, 'WOOSTACK_EVAL_TEST_BASELINE_SNAPSHOT_RELEASE'],
  ]) {
    validateControl(value, label);
    validateArgumentSize(value, label);
    if (!path.isAbsolute(value)) throw new Error(`${label} must be absolute`);
  }
  await writeFileAsync(readyPath, 'ready\n', 'utf8');
  const release = await readFileAsync(releasePath, 'utf8');
  if (release !== 'release\n') {
    throw new Error('invalid baseline snapshot synchronization release');
  }
}

async function prepare(argv) {

  const options = parseCommandLine(argv);
  const configuredTmp = process.env.TMPDIR || '/tmp';
  validateControl(configuredTmp, 'TMPDIR');
  validateArgumentSize(configuredTmp, 'TMPDIR');

  const candidateInput = path.resolve(options.target);
  const candidateBoundary = path.basename(candidateInput) === 'SKILL.md'
    ? path.dirname(candidateInput)
    : candidateInput;
  const target = await validateTargetPackage(candidateInput, candidateBoundary);
  const targetPackageRoot = target.root;
  const candidateCatalogCases = await loadCasesFromCorpus(path.join(targetPackageRoot, 'evals', 'evals.json'), 'behavior');
  const candidateTriggerCases = await loadCasesFromCorpus(path.join(targetPackageRoot, 'evals', 'trigger-evals.json'), 'trigger');
  const selected = buildSelection(options.mode, candidateCatalogCases, candidateTriggerCases, options.runs);
  if (selected.length === 0) {
    throw new Error(`no ${options.mode} evaluation cases selected`);
  }

  const catalogRoot = path.resolve(options.catalogRoot || DEFAULT_CATALOG_ROOT);
  const safeCatalogRoot = await assertCleanDirectory(catalogRoot, '--catalog-root');
  const publicSkillNames = await loadPublicSkillNames(safeCatalogRoot);
  const catalogSkills = await loadCatalogSkills(safeCatalogRoot, publicSkillNames);

  const gitRoot = await resolveGitRoot(targetPackageRoot);
  const sourceSnapshot = await snapshotSource(targetPackageRoot, gitRoot);
  if (sourceSnapshot.packageHash !== target.hash) {
    throw new Error('source target changed during validation');
  }

  const explicitBaselineRoot = options.baselinePath
    ? await canonicalizePotentialPath(path.resolve(options.baselinePath))
    : null;
  await assertOutsideSourceRoots(configuredTmp, [targetPackageRoot, explicitBaselineRoot], 'TMPDIR');

  const baseline = await chooseBaseline({
    gitRoot,
    packageRoot: targetPackageRoot,
    targetName: target.name,
    targetHash: target.hash,
  }, options);
  assertWorkspaceBudget(selected, target, baseline, catalogSkills);

  await synchronizeBaselineSnapshot();
  const outputRoot = await chooseOutRoot(options, gitRoot);
  const resolvedOutRoot = await prepareOutputRoot(outputRoot, [
    targetPackageRoot,
    baseline.sourceRoot,
  ]);

  const allocation = await allocateRunRoot(resolvedOutRoot, options.runId || null);
  allocated = allocation;

  try {
    await mkdirAsync(path.join(allocation.rootPath, 'cases'), { mode: SAFE_FILE_MODE, recursive: true });
    const definitionsRoot = path.join(allocation.rootPath, 'definitions');
    await mkdirAsync(definitionsRoot, { mode: SAFE_FILE_MODE });
    const frozenDefinitions = new Set();
    for (const item of selected) {
      const definitionName = `${item.kind}.${item.caseId}.json`;
      if (frozenDefinitions.has(definitionName)) continue;
      frozenDefinitions.add(definitionName);
      await writeFileAsync(
        path.join(definitionsRoot, definitionName),
        `${JSON.stringify(item.definition)}\n`,
        { encoding: 'utf8', flag: 'wx', mode: 0o600 },
      );
    }
    const expected = [];
    const pairs = [];
    const gradingPlan = selected.flatMap((item) =>
      (item.definition.assertions ?? [])
        .filter((assertion) => assertion.kind === 'qualitative')
        .map((assertion) => ({
          caseId: item.caseId,
          repetition: item.repetition,
          assertionId: assertion.id,
          graderId: null,
        }))).sort((left, right) =>
      compareText(left.caseId, right.caseId)
      || left.repetition - right.repetition
      || compareText(left.assertionId, right.assertionId));
    const packageHashes = { candidate: null, baseline: null };

    for (const item of selected) {
      const caseDir = path.join(allocation.rootPath, 'cases', item.caseId, String(item.repetition));
      const candidateVariant = path.join(caseDir, 'candidate');
      const baselineVariant = path.join(caseDir, 'baseline');
      await mkdirAsync(candidateVariant, { mode: SAFE_FILE_MODE, recursive: true });
      await mkdirAsync(baselineVariant, { mode: SAFE_FILE_MODE, recursive: true });
      await copyDirectory(targetPackageRoot, path.join(candidateVariant, 'package'));

      if (baseline.packageRoot) {
        await copyDirectory(baseline.packageRoot, path.join(baselineVariant, 'package'));
      }
      for (const [variant, packageRoot] of [
        ['candidate', path.join(candidateVariant, 'package')],
        ['baseline', baseline.packageRoot ? path.join(baselineVariant, 'package') : null],
      ]) {
        if (!packageRoot) continue;
        const copiedHash = await hashPackage(packageRoot, { trackedOnly: false });
        if (!copiedHash) throw new Error(`failed to hash copied ${variant} package`);
        if (packageHashes[variant] === null) {
          packageHashes[variant] = copiedHash;
        } else if (packageHashes[variant] !== copiedHash) {
          throw new Error(`copied ${variant} packages do not share one frozen hash`);
        }
      }

      if (item.kind === 'behavior') {
        await mkdirAsync(path.join(candidateVariant, 'fixtures'), { mode: SAFE_FILE_MODE });
        await mkdirAsync(path.join(baselineVariant, 'fixtures'), { mode: SAFE_FILE_MODE });
        for (const fixture of item.fixtures) {
          await copyFixture(targetPackageRoot, fixture, path.join(candidateVariant, 'fixtures'));
          if (baseline.packageRoot || baseline.identity.kind === 'none') {
            await copyFixture(targetPackageRoot, fixture, path.join(baselineVariant, 'fixtures'));
          }
        }
      }

      if (item.kind === 'trigger') {
        const candidateCatalog = catalogForTarget(
          catalogSkills,
          true,
          target.name,
          target.description,
        );
        const baselineCatalog = catalogForTarget(
          catalogSkills,
          baseline.packageRoot !== null,
          baseline.packageRoot !== null ? baseline.name : target.name,
          baseline.packageRoot !== null ? baseline.description : target.description,
        );
        await writeFileAsync(path.join(candidateVariant, 'catalog.json'), `${JSON.stringify(candidateCatalog)}\n`, 'utf8');
        await writeFileAsync(path.join(baselineVariant, 'catalog.json'), `${JSON.stringify(baselineCatalog)}\n`, 'utf8');
      }

      expected.push(
        {
          caseId: item.caseId,
          variant: 'candidate',
          repetition: item.repetition,
          kind: item.kind,
        },
        {
          caseId: item.caseId,
          variant: 'baseline',
          repetition: item.repetition,
          kind: item.kind,
        },
      );
      pairs.push({
        caseId: item.caseId,
        repetition: item.repetition,
        candidate: toCanonical(path.join('cases', item.caseId, String(item.repetition), 'candidate')),
        baseline: toCanonical(path.join('cases', item.caseId, String(item.repetition), 'baseline')),
      });
    }


    const manifest = makeManifest({
      runId: allocation.runId,
      targetName: target.name,
      mode: options.mode,
      runs: options.runs,
      baseline: baseline.identity.kind === 'path'
        ? { kind: 'path', identity: packageHashes.baseline }
        : baseline.identity,
      originalPackageHash: target.hash,
      packageHashes,
      gradingPlan,
      expected,
      pairs,
    });

    await mkdirAsync(path.join(allocation.rootPath, 'evidence'), {
      recursive: true,
      mode: SAFE_FILE_MODE,
    });
    await assertSourceUnchanged(sourceSnapshot, targetPackageRoot, gitRoot);
    if (baseline.sourceRoot) {
      const currentBaselineHash = await hashPackage(baseline.sourceRoot, { trackedOnly: false });
      if (currentBaselineHash !== baseline.sourceHash) {
        throw new Error('baseline source changed during preparation');
      }
    }

    await writeFileAsync(
      path.join(allocation.rootPath, 'manifest.json'),
      `${JSON.stringify(manifest)}\n`,
      { encoding: 'utf8', flag: 'wx' },
    );
    await cleanupTemporarySnapshots();
    allocated = null;
    process.stdout.write(`${allocation.finalPath}\n`);
  } finally {
    await cleanupRun();
  }
}

async function main(argv) {
  scheduleExitCleanup();
  try {
    await prepare(argv);
  } finally {
    await killTrackedChildren();
    await cleanupRun();
  }
}

function withRealpath(value) {
  return realpathAsync(value).then(
    (resolved) => resolved,
    () => value,
  );
}

if (process.argv[1]) {
  const caller = await withRealpath(path.resolve(process.argv[1]));
  if ((await withRealpath(fileURLToPath(import.meta.url))) === caller) {
    main(process.argv.slice(2)).catch((error) => {
      emit('prepare.mjs:', boundedDiagnostic(error));
      process.exitCode = 1;
    });
  }
}
