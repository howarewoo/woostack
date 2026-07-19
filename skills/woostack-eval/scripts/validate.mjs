import { createHash } from 'node:crypto';
import { execFile as execFileCallback } from 'node:child_process';
import { lstat, readFile, readdir, realpath } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';

const execFile = promisify(execFileCallback);
const KEBAB_CASE = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
const CAPABILITIES = new Set(['read-workspace', 'write-workspace', 'shell-workspace']);
const CORPUS_FILES = new Map([
  ['evals.json', 'behavior'],
  ['trigger-evals.json', 'triggers'],
]);
const ASSERTION_FIELDS = new Map([
  ['path-exists', ['path']],
  ['path-absent', ['path']],
  ['file-contains', ['file', 'substring']],
  ['file-excludes', ['file', 'substring']],
  ['json-path-equals', ['file', 'pointer', 'expected']],
  ['final-contains', ['substring']],
  ['final-excludes', ['substring']],
  ['receipt-field-equals', ['pointer', 'expected']],
  ['qualitative', ['rubric']],
]);
const HTML_TAGS = new Set([
  'a', 'abbr', 'address', 'article', 'aside', 'audio', 'b', 'blockquote', 'body', 'br',
  'button', 'canvas', 'caption', 'code', 'col', 'data', 'datalist', 'dd', 'del', 'details',
  'dialog', 'div', 'dl', 'dt', 'em', 'embed', 'fieldset', 'figcaption', 'figure', 'footer',
  'form', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'head', 'header', 'hr', 'html', 'i',
  'iframe', 'img', 'input', 'ins', 'kbd', 'label', 'legend', 'li', 'link', 'main', 'map',
  'mark', 'menu', 'meta', 'meter', 'nav', 'noscript', 'object', 'ol', 'optgroup', 'option',
  'output', 'p', 'picture', 'pre', 'progress', 'q', 'rp', 'rt', 'ruby', 's', 'samp',
  'script', 'search', 'section', 'select', 'slot', 'small', 'source', 'span', 'strong',
  'style', 'sub', 'summary', 'sup', 'svg', 'table', 'tbody', 'td', 'template', 'textarea',
  'tfoot', 'th', 'thead', 'time', 'title', 'tr', 'track', 'u', 'ul', 'var', 'video', 'wbr',
  'xml',
]);
const BEHAVIOR_CASE_FIELDS = new Set([
  'id', 'prompt', 'fixtures', 'capabilities', 'expected', 'assertions',
]);
const TRIGGER_CASE_FIELDS = new Set([
  'id', 'query', 'shouldTrigger', 'expectedSkill', 'conflictsWith',
]);

class ValidationFault extends Error {
  constructor(code, field, message) {
    super(message);
    this.code = code;
    this.field = field;
  }
}

function decodeScalar(source, key, file) {
  const value = source.trim();
  if (value.startsWith('"')) {
    if (!value.endsWith('"') || value.length < 2) {
      throw new ValidationFault('frontmatter-invalid-scalar', `/${key}`, `${file}: unterminated quoted ${key}`);
    }
    try {
      return JSON.parse(value);
    } catch {
      throw new ValidationFault('frontmatter-invalid-scalar', `/${key}`, `${file}: invalid quoted ${key}`);
    }
  }
  if (value.startsWith("'")) {
    if (!value.endsWith("'") || value.length < 2) {
      throw new ValidationFault('frontmatter-invalid-scalar', `/${key}`, `${file}: unterminated quoted ${key}`);
    }
    const inner = value.slice(1, -1);
    if (inner.replace(/''/g, '').includes("'")) {
      throw new ValidationFault('frontmatter-invalid-scalar', `/${key}`, `${file}: invalid quoted ${key}`);
    }
    return inner.replace(/''/g, "'");
  }
  if (key === 'name' || key === 'description') {
    if (
      value === '' ||
      /^[\[{]|^[|>](?:[-+])?$/.test(value) ||
      /^(?:~|null|true|false|yes|no|on|off)$/i.test(value) ||
      /^[-+]?(?:(?:0|[1-9][0-9_]*|0o[0-7_]+|0x[0-9a-f_]+|0b[01_]+)|(?:(?:[0-9][0-9_]*)?\.[0-9_]+|[0-9][0-9_]*(?:\.[0-9_]*)?[eE][-+]?[0-9_]+|\.inf|\.nan))$/i.test(value)
    ) {
      throw new ValidationFault('frontmatter-non-string-scalar', `/${key}`, `${file}: ${key} must decode as a string`);
    }
  }
  // YAML treats colon followed by whitespace as a mapping token only in a plain scalar.
  if (key === 'description' && /:\s/.test(value)) {
    throw new ValidationFault(
      'frontmatter-plain-colon-space',
      '/description',
      `${file}: description contains colon-space in a plain scalar; quote the value`,
    );
  }
  return value;
}

function containsXmlMarkup(value) {
  if (/<!--[\s\S]*?-->|<![^>]*>|<\?[^>]*\?>?/.test(value)) return true;
  if (/<\/[A-Za-z][A-Za-z0-9:-]*\s*>/.test(value)) return true;
  for (const match of value.matchAll(/<([A-Za-z][A-Za-z0-9:-]*)([^>]*)>/g)) {
    const [, tag, suffix] = match;
    if (suffix.trim() || HTML_TAGS.has(tag.toLowerCase())) return true;
  }
  return false;
}

export function parseFrontmatter(raw, file = '<input>') {
  if (typeof raw !== 'string') throw new TypeError(`${file}: frontmatter source must be a string`);
  const match = /^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/.exec(raw);
  if (!match) throw new ValidationFault('frontmatter-missing', '', `${file}: missing frontmatter`);
  const fm = {};
  const seen = new Set();
  for (const line of match[1].split(/\r?\n/)) {
    if (!line.trim() || /^\s*#/.test(line) || /^\s+/.test(line)) continue;
    const field = /^([A-Za-z_][A-Za-z0-9_-]*):(?:[ \t]*(.*))$/.exec(line);
    if (!field) {
      throw new ValidationFault('frontmatter-invalid-line', '', `${file}: invalid frontmatter line`);
    }
    const [, key, source] = field;
    if (seen.has(key)) {
      throw new ValidationFault('frontmatter-duplicate-field', `/${escapePointer(key)}`, `${file}: duplicate frontmatter field ${key}`);
    }
    seen.add(key);
    fm[key] = decodeScalar(source, key, file);
  }
  if (!Object.hasOwn(fm, 'name')) {
    throw new ValidationFault('frontmatter-name-missing', '/name', `${file}: frontmatter missing 'name'`);
  }
  if (!Object.hasOwn(fm, 'description')) {
    throw new ValidationFault('frontmatter-description-missing', '/description', `${file}: frontmatter missing 'description'`);
  }
  if (typeof fm.name !== 'string') {
    throw new ValidationFault('frontmatter-name-non-scalar', '/name', `${file}: name must be a scalar string`);
  }
  if (typeof fm.description !== 'string') {
    throw new ValidationFault('frontmatter-description-non-scalar', '/description', `${file}: description must be a scalar string`);
  }
  if (containsXmlMarkup(fm.description)) {
    throw new ValidationFault(
      'frontmatter-xml-markup',
      '/description',
      `${file}: description contains XML-like markup`,
    );
  }
  return { fm, body: raw.slice(match[0].length) };
}

function escapePointer(value) {
  return String(value).replace(/~/g, '~0').replace(/\//g, '~1');
}

function pointer(...parts) {
  return parts.length ? `/${parts.map(escapePointer).join('/')}` : '';
}

function toPosix(value) {
  return value.split(path.sep).join('/');
}

function isContained(root, candidate) {
  const relative = path.relative(root, candidate);
  return relative === '' || (!relative.startsWith(`..${path.sep}`) && relative !== '..' && !path.isAbsolute(relative));
}

function normalizedRelative(root, candidate) {
  const relative = path.relative(root, candidate);
  if (!isContained(root, candidate)) return '';
  return relative ? toPosix(relative) : '.';
}

function makeError(code, field, sourcePath, message) {
  const cleanMessage = String(message)
    .replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/g, ' ')
    .trim() || 'Validation failed';
  return { code, field, path: sourcePath, message: cleanMessage };
}

function addError(errors, code, field, sourcePath, message) {
  if (!errors.some((entry) => entry.code === code && entry.field === field && entry.path === sourcePath)) {
    errors.push(makeError(code, field, sourcePath, message));
  }
}

function compareText(left, right) {
  return left < right ? -1 : left > right ? 1 : 0;
}

function sortErrors(errors) {
  errors.sort((left, right) =>
    compareText(left.path, right.path) ||
    compareText(left.field, right.field) ||
    compareText(left.code, right.code));
  return errors;
}

async function safeLstat(root, candidate) {
  if (!isContained(root, candidate)) return { kind: 'outside' };
  const relative = path.relative(root, candidate);
  let current = root;
  if (relative) {
    for (const part of relative.split(path.sep)) {
      current = path.join(current, part);
      let info;
      try {
        info = await lstat(current);
      } catch (error) {
        if (error?.code === 'ENOENT') return { kind: 'missing' };
        return { kind: 'unreadable', error };
      }
      if (info.isSymbolicLink()) return { kind: 'symlink' };
    }
  }
  try {
    const info = await lstat(candidate);
    const resolvedRoot = await realpath(root);
    const resolvedCandidate = await realpath(candidate);
    if (!isContained(resolvedRoot, resolvedCandidate)) return { kind: 'outside' };
    return { kind: info.isFile() ? 'file' : info.isDirectory() ? 'directory' : 'special', info };
  } catch (error) {
    if (error?.code === 'ENOENT') return { kind: 'missing' };
    return { kind: 'unreadable', error };
  }
}

async function baselineCollectionRoot(repositoryRoot, packageRoot, baselineSnapshot) {
  if (
    !baselineSnapshot ||
    typeof baselineSnapshot !== 'object' ||
    typeof baselineSnapshot.collectionRoot !== 'string'
  ) {
    return null;
  }
  const collectionRoot = path.resolve(baselineSnapshot.collectionRoot);
  if (
    !isContained(repositoryRoot, collectionRoot) ||
    !isContained(collectionRoot, packageRoot)
  ) {
    return null;
  }
  const state = await safeLstat(repositoryRoot, collectionRoot);
  return state.kind === 'directory' ? collectionRoot : null;
}


function isForbiddenPath(relative) {
  return relative.split('/').some((part) => part === '.git' || /^\.env/.test(part));
}

function isSecretPath(relative) {
  return relative.split('/').some((part) => {
    const normalized = part.toLowerCase().replace(/\.[^.]*$/, '');
    return /^(?:secrets?|credentials?|private-keys?|api-keys?|access-tokens?|auth-tokens?)$/.test(normalized) ||
      /(?:^|[-_.])(?:secret|credential|private[-_]?key|api[-_]?key|access[-_]?token|auth[-_]?token)(?:$|[-_.])/.test(normalized);
  });
}

function classifyFile(relative) {
  if (relative === 'SKILL.md') return 'skill';
  if (relative.startsWith('references/')) return 'reference';
  if (relative.startsWith('scripts/')) return 'script';
  if (relative.startsWith('evals/')) return 'eval';
  return 'asset';
}

function hashBuffer(buffer) {
  return `sha256:${createHash('sha256').update(buffer).digest('hex')}`;
}

function hashManifest(files) {
  const hash = createHash('sha256');
  for (const file of files) {
    const record = Buffer.from(JSON.stringify([file.path, file.type, file.bytes, file.sha256]), 'utf8');
    hash.update(String(record.length));
    hash.update(':');
    hash.update(record);
    hash.update('\n');
  }
  return `sha256:${hash.digest('hex')}`;
}

async function gitTrackedEntries(repositoryRoot, packageRoot) {
  const relativeRoot = toPosix(path.relative(repositoryRoot, packageRoot));
  const packageRelative = relativeRoot || '.';
  if (packageRelative.startsWith('../') || path.posix.isAbsolute(packageRelative)) {
    throw new Error('package must be inside the repository in tracked-only mode');
  }
  const { stdout } = await execFile(
    'git',
    ['-C', repositoryRoot, 'ls-files', '--stage', '-z', '--', packageRelative],
    { encoding: 'buffer', maxBuffer: 16 * 1024 * 1024 },
  );
  const entries = [];
  const trackedPaths = new Set();
  for (const record of stdout.toString('utf8').split('\0')) {
    if (!record) continue;
    const tab = record.indexOf('\t');
    if (tab < 0) throw new Error('Git returned an invalid tracked-file record');
    const metadata = record.slice(0, tab).split(' ');
    const repositoryPath = record.slice(tab + 1);
    if (
      metadata.length !== 3 ||
      metadata[2] !== '0' ||
      !/^[0-9a-f]{40}(?:[0-9a-f]{24})?$/.test(metadata[1]) ||
      !isContained(packageRelative, repositoryPath) ||
      trackedPaths.has(repositoryPath)
    ) {
      throw new Error('Git returned an unsafe tracked-file record');
    }
    trackedPaths.add(repositoryPath);
    const relative = path.posix.relative(packageRelative, repositoryPath);
    if (!relative || relative.startsWith('../')) continue;
    entries.push({ mode: metadata[0], relative });
  }
  entries.sort((left, right) => compareText(left.relative, right.relative));
  return entries;
}

async function untrackedEntries(packageRoot, errors) {
  const entries = [];
  async function visit(directory, prefix) {
    let children;
    try {
      children = await readdir(directory, { withFileTypes: true });
    } catch {
      addError(errors, 'package-read-error', '', prefix || '.', 'Package directory could not be read');
      return;
    }
    children.sort((left, right) => compareText(left.name, right.name));
    for (const child of children) {
      const relative = prefix ? `${prefix}/${child.name}` : child.name;
      if (isForbiddenPath(relative)) {
        addError(errors, 'package-forbidden-path', '', relative, 'Package contains a forbidden metadata or environment path');
        continue;
      }
      if (child.isSymbolicLink()) {
        addError(errors, 'package-symlink', '', relative, 'Package entries must not be symbolic links');
        continue;
      }
      if (child.isDirectory()) {
        await visit(path.join(directory, child.name), relative);
      } else if (isSecretPath(relative)) {
        addError(errors, 'package-secret-path', '', relative, 'Package contains a secret-looking path');
      } else if (child.isFile()) {
        entries.push({ mode: '100644', relative });
      } else {
        addError(errors, 'package-special-file', '', relative, 'Package entries must be regular files or directories');
      }
    }
  }
  await visit(packageRoot, '');
  return entries;
}

async function inventoryPackage(packageRoot, repositoryRoot, trackedOnly, errors) {
  let entries;
  let safe = true;
  if (trackedOnly) {
    try {
      entries = await gitTrackedEntries(repositoryRoot, packageRoot);
    } catch {
      addError(errors, 'package-git-enumeration-failed', '', '', 'Tracked package files could not be enumerated safely');
      return { files: [], safe: false, trackedPaths: new Set() };
    }
    if (!entries.some((entry) => entry.relative === 'SKILL.md')) {
      addError(errors, 'package-skill-untracked', '', 'SKILL.md', 'Owning SKILL.md is not tracked by Git');
      safe = false;
    }
  } else {
    const before = errors.length;
    entries = await untrackedEntries(packageRoot, errors);
    if (errors.length !== before) safe = false;
  }

  const files = [];
  for (const entry of entries) {
    const relative = entry.relative;
    if (isForbiddenPath(relative)) {
      addError(errors, 'package-forbidden-path', '', relative, 'Package contains a forbidden metadata or environment path');
      safe = false;
      continue;
    }
    if (isSecretPath(relative)) {
      addError(errors, 'package-secret-path', '', relative, 'Package contains a secret-looking path');
      safe = false;
      continue;
    }
    if (entry.mode === '120000') {
      addError(errors, 'package-symlink', '', relative, 'Package entries must not be symbolic links');
      safe = false;
      continue;
    }
    if (entry.mode !== '100644' && entry.mode !== '100755') {
      addError(errors, 'package-special-file', '', relative, 'Tracked package entry is not a regular file');
      safe = false;
      continue;
    }
    const absolute = path.join(packageRoot, ...relative.split('/'));
    const state = await safeLstat(packageRoot, absolute);
    if (state.kind !== 'file') {
      const code = state.kind === 'symlink' ? 'package-symlink' :
        state.kind === 'special' ? 'package-special-file' : 'package-file-unavailable';
      addError(errors, code, '', relative, 'Package file must exist as a regular non-symlink file');
      safe = false;
      continue;
    }
    try {
      const content = await readFile(absolute);
      files.push({
        path: relative,
        type: classifyFile(relative),
        bytes: content.byteLength,
        sha256: hashBuffer(content),
      });
    } catch {
      addError(errors, 'package-read-error', '', relative, 'Package file could not be read');
      safe = false;
    }
  }
  files.sort((left, right) => compareText(left.path, right.path));
  return { files, safe, trackedPaths: trackedOnly ? new Set(files.map((file) => file.path)) : null };
}

function hasOnlyFields(value, allowed, baseField, sourcePath, errors) {
  for (const key of Object.keys(value)) {
    if (!allowed.has(key)) {
      addError(errors, 'corpus-unknown-field', pointer(...baseField, key), sourcePath, `Unknown corpus field ${key}`);
    }
  }
}

function requireString(value, key, baseField, sourcePath, errors, { nonempty = true } = {}) {
  const field = pointer(...baseField, key);
  if (!Object.hasOwn(value, key) || typeof value[key] !== 'string') {
    addError(errors, 'corpus-invalid-type', field, sourcePath, `${key} must be a string`);
    return null;
  }
  if (nonempty && value[key].trim().length === 0) {
    addError(errors, 'corpus-empty-string', field, sourcePath, `${key} must be non-empty`);
    return null;
  }
  return value[key];
}

function validateIdentity(value, key, baseField, sourcePath, errors) {
  const identity = requireString(value, key, baseField, sourcePath, errors);
  if (identity !== null && !KEBAB_CASE.test(identity)) {
    addError(errors, 'corpus-invalid-id', pointer(...baseField, key), sourcePath, `${key} must be lower-case kebab-case`);
  }
  return identity;
}

function validateRelativePath(value, field, sourcePath, errors, code = 'corpus-invalid-path') {
  if (typeof value !== 'string' || !value || value.includes('\\') || path.posix.isAbsolute(value)) {
    addError(errors, code, field, sourcePath, 'Path must be a non-empty relative POSIX path');
    return false;
  }
  const segments = value.split('/');
  if (
    segments.includes('..') ||
    segments.includes('.') ||
    segments.includes('') ||
    value.includes('\0') ||
    path.posix.normalize(value) !== value
  ) {
    addError(errors, code, field, sourcePath, 'Path must be normalized and remain inside its declared root');
    return false;
  }
  return true;
}

function isJsonPointer(value) {
  return typeof value === 'string' &&
    (value === '' || (value.startsWith('/') && !/(?:^|[^~])~(?:[^01]|$)/.test(value)));
}

function validateUniqueStringArray(value, key, baseField, sourcePath, errors, validateItem) {
  const field = pointer(...baseField, key);
  if (!Array.isArray(value)) {
    addError(errors, 'corpus-invalid-type', field, sourcePath, `${key} must be an array`);
    return;
  }
  const seen = new Set();
  value.forEach((item, index) => {
    const itemField = pointer(...baseField, key, index);
    if (typeof item !== 'string') {
      addError(errors, 'corpus-invalid-type', itemField, sourcePath, `${key} entries must be strings`);
      return;
    }
    if (seen.has(item)) {
      addError(errors, 'corpus-duplicate-value', itemField, sourcePath, `${key} entries must be unique`);
    }
    seen.add(item);
    validateItem?.(item, itemField);
  });
}

async function validateFixture(fixture, corpusPath, packageRoot, trackedPaths, field, sourcePath, errors) {
  if (!validateRelativePath(fixture, field, sourcePath, errors, 'corpus-fixture-outside')) return;
  const fixtureRoot = path.join(path.dirname(corpusPath), 'fixtures');
  const candidate = path.resolve(fixtureRoot, ...fixture.split('/'));
  // Check lexical containment before any filesystem lookup, then reject symlinks in every path component.
  if (!isContained(fixtureRoot, candidate)) {
    addError(errors, 'corpus-fixture-outside', field, sourcePath, 'Fixture path escapes evals/fixtures');
    return;
  }
  const packageRelative = toPosix(path.relative(packageRoot, candidate));
  if (trackedPaths && !trackedPaths.has(packageRelative)) {
    addError(errors, 'corpus-fixture-untracked', field, sourcePath, 'Fixture must be tracked with its owning package');
    return;
  }
  const state = await safeLstat(packageRoot, candidate);
  if (state.kind === 'outside') {
    addError(errors, 'corpus-fixture-outside', field, sourcePath, 'Fixture path escapes the package');
  } else if (state.kind === 'missing') {
    addError(errors, 'corpus-fixture-missing', field, sourcePath, 'Fixture file does not exist');
  } else if (state.kind === 'symlink') {
    addError(errors, 'corpus-fixture-symlink', field, sourcePath, 'Fixture path must not resolve through a symlink');
  } else if (state.kind !== 'file') {
    addError(errors, 'corpus-fixture-special-file', field, sourcePath, 'Fixture must be a regular file');
  }
}

function validateAssertion(assertion, caseIndex, assertionIndex, sourcePath, errors) {
  const base = ['cases', caseIndex, 'assertions', assertionIndex];
  if (!assertion || typeof assertion !== 'object' || Array.isArray(assertion)) {
    addError(errors, 'corpus-invalid-type', pointer(...base), sourcePath, 'Assertion must be an object');
    return null;
  }
  const id = validateIdentity(assertion, 'id', base, sourcePath, errors);
  const kind = requireString(assertion, 'kind', base, sourcePath, errors);
  if (!ASSERTION_FIELDS.has(kind)) {
    if (kind !== null) {
      addError(errors, 'corpus-unsupported-assertion', pointer(...base, 'kind'), sourcePath, `Unsupported assertion kind ${kind}`);
    }
    return id;
  }
  const required = ASSERTION_FIELDS.get(kind);
  const allowed = new Set(['id', 'kind', 'critical', ...required]);
  hasOnlyFields(assertion, allowed, base, sourcePath, errors);
  for (const key of required) {
    if (!Object.hasOwn(assertion, key)) {
      addError(errors, 'corpus-missing-field', pointer(...base, key), sourcePath, `Assertion requires ${key}`);
    }
  }
  if (Object.hasOwn(assertion, 'critical') && typeof assertion.critical !== 'boolean') {
    addError(errors, 'corpus-invalid-critical', pointer(...base, 'critical'), sourcePath, 'critical must be boolean');
  }
  for (const key of ['path', 'file']) {
    if (required.includes(key) && Object.hasOwn(assertion, key)) {
      validateRelativePath(assertion[key], pointer(...base, key), sourcePath, errors);
    }
  }
  if (required.includes('substring') &&
      (typeof assertion.substring !== 'string' || assertion.substring.length === 0)) {
    addError(errors, 'corpus-invalid-substring', pointer(...base, 'substring'), sourcePath, 'substring must be a non-empty string');
  }
  if (required.includes('pointer') && !isJsonPointer(assertion.pointer)) {
    addError(errors, 'corpus-invalid-pointer', pointer(...base, 'pointer'), sourcePath, 'pointer must be an RFC 6901 JSON Pointer');
  }
  if (kind === 'qualitative' &&
      (typeof assertion.rubric !== 'string' || !assertion.rubric.trim() || !assertion.rubric.trim().endsWith('?'))) {
    addError(errors, 'corpus-invalid-rubric', pointer(...base, 'rubric'), sourcePath, 'rubric must be a non-empty boolean question');
  }
  return id;
}

async function validateBehaviorCase(value, index, corpusPath, packageRoot, trackedPaths, sourcePath, errors) {
  const base = ['cases', index];
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    addError(errors, 'corpus-invalid-type', pointer(...base), sourcePath, 'Behavior case must be an object');
    return null;
  }
  hasOnlyFields(value, BEHAVIOR_CASE_FIELDS, base, sourcePath, errors);
  const id = validateIdentity(value, 'id', base, sourcePath, errors);
  requireString(value, 'prompt', base, sourcePath, errors);
  requireString(value, 'expected', base, sourcePath, errors);
  if (Object.hasOwn(value, 'capabilities')) {
    validateUniqueStringArray(value.capabilities, 'capabilities', base, sourcePath, errors, (capability, field) => {
      if (!CAPABILITIES.has(capability)) {
        addError(errors, 'corpus-unsupported-capability', field, sourcePath, `Unsupported capability ${capability}`);
      }
    });
  }
  if (Object.hasOwn(value, 'fixtures')) {
    if (!Array.isArray(value.fixtures)) {
      addError(errors, 'corpus-invalid-type', pointer(...base, 'fixtures'), sourcePath, 'fixtures must be an array');
    } else {
      const seenFixtures = new Set();
      for (let fixtureIndex = 0; fixtureIndex < value.fixtures.length; fixtureIndex += 1) {
        const fixture = value.fixtures[fixtureIndex];
        const field = pointer(...base, 'fixtures', fixtureIndex);
        if (typeof fixture !== 'string') {
          addError(errors, 'corpus-invalid-type', field, sourcePath, 'Fixture paths must be strings');
          continue;
        }
        if (seenFixtures.has(fixture)) {
          addError(errors, 'corpus-duplicate-value', field, sourcePath, 'Fixture paths must be unique');
        }
        seenFixtures.add(fixture);
        await validateFixture(fixture, corpusPath, packageRoot, trackedPaths, field, sourcePath, errors);
      }
    }
  }
  if (!Array.isArray(value.assertions)) {
    addError(errors, 'corpus-invalid-type', pointer(...base, 'assertions'), sourcePath, 'assertions must be a non-empty array');
  } else if (value.assertions.length === 0) {
    addError(errors, 'corpus-empty-assertions', pointer(...base, 'assertions'), sourcePath, 'assertions must be non-empty');
  } else {
    const assertionIds = new Set();
    value.assertions.forEach((assertion, assertionIndex) => {
      const assertionId = validateAssertion(assertion, index, assertionIndex, sourcePath, errors);
      if (assertionId !== null && assertionIds.has(assertionId)) {
        addError(
          errors,
          'corpus-duplicate-assertion-id',
          pointer(...base, 'assertions', assertionIndex, 'id'),
          sourcePath,
          `Duplicate assertion id ${assertionId}`,
        );
      }
      if (assertionId !== null) assertionIds.add(assertionId);
    });
  }
  return id;
}

function validateTriggerCase(value, index, sourcePath, errors) {
  const base = ['cases', index];
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    addError(errors, 'corpus-invalid-type', pointer(...base), sourcePath, 'Trigger case must be an object');
    return null;
  }
  hasOnlyFields(value, TRIGGER_CASE_FIELDS, base, sourcePath, errors);
  const id = validateIdentity(value, 'id', base, sourcePath, errors);
  requireString(value, 'query', base, sourcePath, errors);
  if (!Object.hasOwn(value, 'shouldTrigger') || typeof value.shouldTrigger !== 'boolean') {
    addError(errors, 'corpus-invalid-type', pointer(...base, 'shouldTrigger'), sourcePath, 'shouldTrigger must be boolean');
  }
  const expectedSkill = requireString(value, 'expectedSkill', base, sourcePath, errors);
  if (expectedSkill !== null && expectedSkill !== 'none' && !KEBAB_CASE.test(expectedSkill)) {
    addError(errors, 'corpus-invalid-skill', pointer(...base, 'expectedSkill'), sourcePath, 'expectedSkill must be a canonical skill name or none');
  }
  if (Object.hasOwn(value, 'conflictsWith')) {
    validateUniqueStringArray(value.conflictsWith, 'conflictsWith', base, sourcePath, errors, (skill, field) => {
      if (!KEBAB_CASE.test(skill)) {
        addError(errors, 'corpus-invalid-skill', field, sourcePath, 'conflictsWith entries must be canonical skill names');
      }
    });
  }
  return id;
}

export async function validateCorpus(corpusPath, packageInfo) {
  const absoluteCorpus = path.resolve(corpusPath);
  const packageRoot = path.resolve(packageInfo?.root ?? packageInfo?.packageRoot ?? path.dirname(path.dirname(absoluteCorpus)));
  const packageName = packageInfo?.name ?? packageInfo?.package?.name ?? null;
  const trackedPaths = packageInfo?.trackedPaths ?? null;
  const sourcePath = normalizedRelative(packageRoot, absoluteCorpus);
  const kind = CORPUS_FILES.get(path.basename(absoluteCorpus));
  const errors = [];
  const result = { present: true, caseCount: 0, errors };
  if (!kind) {
    addError(errors, 'corpus-unknown-file', '', sourcePath, 'Corpus filename is not recognized');
    return { ...result, errors: sortErrors(errors) };
  }
  const state = await safeLstat(packageRoot, absoluteCorpus);
  if (state.kind !== 'file') {
    const code = state.kind === 'symlink' ? 'corpus-symlink' :
      state.kind === 'special' ? 'corpus-special-file' : 'corpus-file-missing';
    addError(errors, code, '', sourcePath, 'Corpus must be a regular non-symlink file');
    return { ...result, errors: sortErrors(errors) };
  }
  let data;
  try {
    data = JSON.parse(await readFile(absoluteCorpus, 'utf8'));
  } catch {
    addError(errors, 'corpus-invalid-json', '', sourcePath, 'Corpus must contain valid JSON');
    return { ...result, errors: sortErrors(errors) };
  }
  if (!data || typeof data !== 'object' || Array.isArray(data)) {
    addError(errors, 'corpus-invalid-type', '', sourcePath, 'Corpus root must be an object');
    return { ...result, errors: sortErrors(errors) };
  }
  hasOnlyFields(data, new Set(['schemaVersion', 'skill', 'cases']), [], sourcePath, errors);
  if (data.schemaVersion !== 1) {
    addError(errors, 'corpus-schema-version', '/schemaVersion', sourcePath, 'schemaVersion must equal 1');
  }
  if (typeof data.skill !== 'string') {
    addError(errors, 'corpus-invalid-type', '/skill', sourcePath, 'skill must be a string');
  } else if (data.skill !== packageName) {
    addError(errors, 'corpus-skill-mismatch', '/skill', sourcePath, 'Corpus skill must exactly match package name');
  }
  if (!Array.isArray(data.cases)) {
    addError(errors, 'corpus-invalid-type', '/cases', sourcePath, 'cases must be an array');
    return { ...result, errors: sortErrors(errors) };
  }
  result.caseCount = data.cases.length;
  const caseIds = new Set();
  for (let index = 0; index < data.cases.length; index += 1) {
    const id = kind === 'behavior'
      ? await validateBehaviorCase(data.cases[index], index, absoluteCorpus, packageRoot, trackedPaths, sourcePath, errors)
      : validateTriggerCase(data.cases[index], index, sourcePath, errors);
    if (id !== null && caseIds.has(id)) {
      addError(errors, 'corpus-duplicate-id', pointer('cases', index, 'id'), sourcePath, `Duplicate case id ${id}`);
    }
    if (id !== null) caseIds.add(id);
  }
  return { ...result, errors: sortErrors(errors) };
}

function markdownContentLines(raw) {
  const lines = [];
  let fence = null;
  for (const line of raw.split(/\r?\n/)) {
    if (fence) {
      const closing = /^ {0,3}(`{3,}|~{3,})[ \t]*$/.exec(line);
      if (
        closing &&
        closing[1][0] === fence.marker &&
        closing[1].length >= fence.length
      ) {
        fence = null;
      }
      continue;
    }
    const opening = /^ {0,3}(`{3,}|~{3,})(.*)$/.exec(line);
    if (opening && (opening[1][0] !== '`' || !opening[2].includes('`'))) {
      fence = { marker: opening[1][0], length: opening[1].length };
      continue;
    }
    lines.push(line);
  }
  return lines;
}

function markdownUnescape(value) {
  return value.replace(/\\([!\"#$%&'()*+,\-./:;<=>?@[\\\]^_`{|}~])/g, '$1');
}

function parseMarkdownBracket(line, start) {
  if (line[start] !== '[') return null;
  let depth = 1;
  let value = '';
  for (let index = start + 1; index < line.length; index += 1) {
    const character = line[index];
    if (character === '\\' && index + 1 < line.length) {
      value += character + line[index + 1];
      index += 1;
    } else if (character === '[') {
      depth += 1;
      value += character;
    } else if (character === ']') {
      depth -= 1;
      if (depth === 0) return { value, end: index + 1 };
      value += character;
    } else {
      value += character;
    }
  }
  return null;
}

function parseBareMarkdownDestination(line, start) {
  let index = start;
  while (line[index] === ' ' || line[index] === '\t') index += 1;
  if (line[index] === '<') {
    let value = '';
    for (index += 1; index < line.length; index += 1) {
      if (line[index] === '\\' && index + 1 < line.length) {
        value += line[index] + line[index + 1];
        index += 1;
      } else if (line[index] === '>') {
        return { target: markdownUnescape(value), end: index + 1 };
      } else {
        value += line[index];
      }
    }
    return null;
  }
  let depth = 0;
  let value = '';
  for (; index < line.length; index += 1) {
    const character = line[index];
    if (character === '\\' && index + 1 < line.length) {
      value += character + line[index + 1];
      index += 1;
    } else if (character === '(') {
      depth += 1;
      value += character;
    } else if (character === ')') {
      if (depth === 0) break;
      depth -= 1;
      value += character;
    } else if ((character === ' ' || character === '\t') && depth === 0) {
      break;
    } else {
      value += character;
    }
  }
  if (!value || depth !== 0) return null;
  return { target: markdownUnescape(value), end: index };
}

function parseInlineMarkdownDestination(line, start) {
  const destination = parseBareMarkdownDestination(line, start + 1);
  if (!destination) return null;
  let index = destination.end;
  const titleSeparated = line[index] === ' ' || line[index] === '\t';
  while (line[index] === ' ' || line[index] === '\t') index += 1;
  if (line[index] === ')') return { target: destination.target, end: index + 1 };
  if (!titleSeparated || !['"', "'", '('].includes(line[index])) return null;

  const opener = line[index];
  const closer = opener === '(' ? ')' : opener;
  let depth = 1;
  for (index += 1; index < line.length; index += 1) {
    if (line[index] === '\\' && index + 1 < line.length) {
      index += 1;
    } else if (opener === '(' && line[index] === opener) {
      depth += 1;
    } else if (line[index] === closer) {
      depth -= 1;
      if (depth === 0) {
        index += 1;
        break;
      }
    }
  }
  if (depth !== 0) return null;
  while (line[index] === ' ' || line[index] === '\t') index += 1;
  if (line[index] !== ')') return null;
  return { target: destination.target, end: index + 1 };
}

function normalizeReferenceLabel(value) {
  return markdownUnescape(value).trim().replace(/\s+/g, ' ').toLowerCase();
}

function stripInlineCodeSpans(line) {
  let output = '';
  for (let index = 0; index < line.length;) {
    if (line[index] === '\\' && index + 1 < line.length) {
      output += line.slice(index, index + 2);
      index += 2;
      continue;
    }
    if (line[index] !== '`') {
      output += line[index];
      index += 1;
      continue;
    }

    let runEnd = index;
    while (line[runEnd] === '`') runEnd += 1;
    const marker = line.slice(index, runEnd);
    let close = runEnd;
    while ((close = line.indexOf(marker, close)) !== -1) {
      if (line[close - 1] !== '`' && line[close + marker.length] !== '`') break;
      close += marker.length;
    }
    if (close === -1) {
      output += marker;
      index = runEnd;
      continue;
    }
    output += ' '.repeat(close + marker.length - index);
    index = close + marker.length;
  }
  return output;
}

function extractMarkdownLinks(raw) {
  const lines = markdownContentLines(raw);
  const definitions = new Map();
  const definitionLines = new Set();
  lines.forEach((line, lineIndex) => {
    const indent = /^( {0,3})/.exec(line)[1].length;
    const label = parseMarkdownBracket(line, indent);
    if (!label || line[label.end] !== ':') return;
    const destination = parseBareMarkdownDestination(line, label.end + 1);
    if (!destination) return;
    const identity = normalizeReferenceLabel(label.value);
    if (identity && !definitions.has(identity)) definitions.set(identity, destination.target);
    definitionLines.add(lineIndex);
  });

  const links = [];
  lines.forEach((rawLine, lineIndex) => {
    if (definitionLines.has(lineIndex) || /^(?: {4}|\t)/.test(rawLine)) return;
    const line = stripInlineCodeSpans(rawLine);
    for (let index = 0; index < line.length; index += 1) {
      if (line[index] === '\\') {
        index += 1;
        continue;
      }
      const bracketStart = line[index] === '!' && line[index + 1] === '[' ? index + 1 : index;
      if (line[bracketStart] !== '[') continue;
      const label = parseMarkdownBracket(line, bracketStart);
      if (!label) continue;
      if (line[label.end] === '(') {
        const destination = parseInlineMarkdownDestination(line, label.end);
        if (destination) {
          links.push(destination.target);
          index = destination.end - 1;
        }
        continue;
      }
      let identity = normalizeReferenceLabel(label.value);
      let end = label.end;
      if (line[label.end] === '[') {
        const reference = parseMarkdownBracket(line, label.end);
        if (!reference) continue;
        identity = normalizeReferenceLabel(reference.value || label.value);
        end = reference.end;
      }
      if (definitions.has(identity)) {
        links.push(definitions.get(identity));
        index = end - 1;
      }
    }
  });
  return links;
}

function localLinkTarget(target) {
  if (!target || target.startsWith('#') || target.startsWith('//')) return null;
  if (/^[A-Za-z][A-Za-z0-9+.-]*:/.test(target)) return null;
  const withoutFragment = target.replace(/[?#].*$/, '');
  if (!withoutFragment) return null;
  try {
    return decodeURIComponent(withoutFragment);
  } catch {
    return withoutFragment;
  }
}

async function validateLinks(packageRoot, repositoryRoot, files, trackedPaths, errors, baselineSnapshot) {
  const snapshotRoot = await baselineCollectionRoot(repositoryRoot, packageRoot, baselineSnapshot);
  for (const file of files) {
    if (!/\.md$/i.test(file.path)) continue;
    const absolute = path.join(packageRoot, ...file.path.split('/'));
    let raw;
    try {
      raw = await readFile(absolute, 'utf8');
    } catch {
      addError(errors, 'package-read-error', '', file.path, 'Package file could not be read');
      continue;
    }
    const links = extractMarkdownLinks(raw);
    for (let index = 0; index < links.length; index += 1) {
      const target = localLinkTarget(links[index]);
      if (target === null) continue;
      const field = pointer('links', index);
      if (target.includes('\0') || target.includes('\\')) {
        addError(errors, 'link-target-outside', field, file.path, 'Local link target is not a safe POSIX path');
        continue;
      }
      const segments = target.split('/');
      if (
        segments.includes('.') ||
        segments.includes('') ||
        path.posix.normalize(target) !== target
      ) {
        addError(errors, 'link-target-not-normalized', field, file.path, 'Local link target must use a normalized POSIX path');
        continue;
      }
      const candidate = path.resolve(path.dirname(absolute), target);
      if (!isContained(repositoryRoot, candidate)) {
        addError(errors, 'link-target-outside', field, file.path, 'Local link target escapes the allowed root');
        continue;
      }
      const state = await safeLstat(repositoryRoot, candidate);
      if (state.kind === 'missing') {
        if (
          !snapshotRoot ||
          isContained(packageRoot, candidate) ||
          !isContained(snapshotRoot, candidate)
        ) {
          addError(errors, 'link-target-missing', field, file.path, 'Local link target does not exist');
        }
      } else if (state.kind === 'symlink') {
        addError(errors, 'link-target-symlink', field, file.path, 'Local link target must not resolve through a symlink');
      } else if (state.kind !== 'file') {
        addError(errors, 'link-target-not-regular', field, file.path, 'Local link target must be a regular file');
      }
      if (
        state.kind === 'file' &&
        trackedPaths &&
        isContained(packageRoot, candidate) &&
        !trackedPaths.has(toPosix(path.relative(packageRoot, candidate)))
      ) {
        addError(errors, 'link-target-untracked', field, file.path, 'In-package link target must be tracked');
      }
    }
  }
}

async function resolvePackage(packagePath, repositoryRoot, errors) {
  const input = path.resolve(packagePath);
  if (!isContained(repositoryRoot, input)) {
    addError(errors, 'package-outside-root', '', '', 'Package path must remain inside repository root');
    return null;
  }
  const inputState = await safeLstat(repositoryRoot, input);
  if (inputState.kind === 'symlink') {
    addError(errors, 'package-symlink', '', normalizedRelative(repositoryRoot, input), 'Package path must not resolve through a symlink');
    return null;
  }
  if (inputState.kind === 'missing') {
    addError(errors, 'package-not-found', '', normalizedRelative(repositoryRoot, input), 'Package path does not exist');
    return null;
  }
  if (inputState.kind !== 'directory' && inputState.kind !== 'file') {
    addError(errors, 'package-special-file', '', normalizedRelative(repositoryRoot, input), 'Package path must be a directory or regular SKILL.md');
    return null;
  }
  let packageRoot;
  if (inputState.kind === 'file') {
    if (path.basename(input) !== 'SKILL.md') {
      addError(errors, 'package-not-skill-file', '', normalizedRelative(repositoryRoot, input), 'Package file must be named SKILL.md');
      return null;
    }
    packageRoot = path.dirname(input);
  } else {
    packageRoot = input;
  }
  const skillPath = path.join(packageRoot, 'SKILL.md');
  const skillState = await safeLstat(repositoryRoot, skillPath);
  if (skillState.kind === 'symlink') {
    addError(errors, 'package-symlink', '', normalizedRelative(packageRoot, skillPath), 'Owning SKILL.md must not be a symlink');
    return null;
  }
  if (skillState.kind === 'missing') {
    addError(errors, 'package-skill-missing', '', 'SKILL.md', 'Package must contain one owning SKILL.md');
    return null;
  }
  if (skillState.kind !== 'file') {
    addError(errors, 'package-skill-not-regular', '', 'SKILL.md', 'Owning SKILL.md must be a regular file');
    return null;
  }
  return { packageRoot, skillPath };
}

export async function validatePackage(packagePath, {
  repositoryRoot = process.cwd(),
  trackedOnly = false,
  baselineSnapshot = false,
} = {}) {
  const root = path.resolve(repositoryRoot);
  const input = path.resolve(packagePath);
  const fallbackRoot = path.basename(input) === 'SKILL.md' ? path.dirname(input) : input;
  const result = {
    schemaVersion: 1,
    valid: false,
    package: {
      name: null,
      description: null,
      path: normalizedRelative(root, fallbackRoot),
    },
    files: [],
    corpora: {
      behavior: { present: false, caseCount: 0 },
      triggers: { present: false, caseCount: 0 },
    },
    packageHash: null,
    errors: [],
  };
  const rootState = await safeLstat(root, root);
  if (rootState.kind !== 'directory') {
    addError(result.errors, 'repository-root-invalid', '', '', 'Repository root must be a readable non-symlink directory');
    result.errors = sortErrors(result.errors);
    return result;
  }
  const resolved = await resolvePackage(packagePath, root, result.errors);
  if (!resolved) {
    result.errors = sortErrors(result.errors);
    return result;
  }
  const { packageRoot, skillPath } = resolved;
  result.package.path = normalizedRelative(root, packageRoot);
  const inventory = await inventoryPackage(packageRoot, root, Boolean(trackedOnly), result.errors);
  result.files = inventory.files;
  if (inventory.safe) result.packageHash = hashManifest(result.files);

  let parsed;
  try {
    parsed = parseFrontmatter(await readFile(skillPath, 'utf8'), 'SKILL.md');
    result.package.name = parsed.fm.name;
    result.package.description = parsed.fm.description;
  } catch (error) {
    if (error instanceof ValidationFault) {
      addError(result.errors, error.code, error.field, 'SKILL.md', error.message);
    } else {
      addError(result.errors, 'frontmatter-read-error', '', 'SKILL.md', 'Owning SKILL.md could not be read');
    }
  }
  if (parsed) {
    const { name, description } = parsed.fm;
    if (!KEBAB_CASE.test(name)) {
      addError(result.errors, 'frontmatter-name-invalid', '/name', 'SKILL.md', 'name must be lower-case kebab-case');
    }
    if (name !== path.basename(packageRoot)) {
      addError(
        result.errors,
        'frontmatter-name-directory-mismatch',
        '/name',
        'SKILL.md',
        'Frontmatter name must exactly match the package directory',
      );
    }
    if (description.length === 0) {
      addError(result.errors, 'frontmatter-description-empty', '/description', 'SKILL.md', 'description must be non-empty');
    } else if ([...description].length > 1024) {
      addError(
        result.errors,
        'frontmatter-description-too-long',
        '/description',
        'SKILL.md',
        'description must not exceed 1024 characters',
      );
    }
  }

  await validateLinks(
    packageRoot,
    root,
    result.files,
    inventory.trackedPaths,
    result.errors,
    baselineSnapshot,
  );
  for (const [filename, summaryKey] of CORPUS_FILES) {
    const corpusRelative = `evals/${filename}`;
    if (inventory.trackedPaths && !inventory.trackedPaths.has(corpusRelative)) continue;
    const corpusPath = path.join(packageRoot, 'evals', filename);
    const state = await safeLstat(packageRoot, corpusPath);
    if (state.kind === 'missing') continue;
    const corpus = await validateCorpus(corpusPath, {
      root: packageRoot,
      name: result.package.name,
      trackedPaths: inventory.trackedPaths,
    });
    result.corpora[summaryKey] = { present: true, caseCount: corpus.caseCount };
    result.errors.push(...corpus.errors);
  }
  result.errors = sortErrors(result.errors);
  result.valid = result.errors.length === 0;
  return result;
}

export async function hashPackage(packagePath, { trackedOnly = false } = {}) {
  const input = path.resolve(packagePath);
  const packageRoot = path.basename(input) === 'SKILL.md' ? path.dirname(input) : input;
  let repositoryRoot = path.dirname(packageRoot);
  if (trackedOnly) {
    try {
      const { stdout } = await execFile(
        'git',
        ['-C', packageRoot, 'rev-parse', '--show-toplevel'],
        { encoding: 'utf8', maxBuffer: 1024 * 1024 },
      );
      repositoryRoot = stdout.trim();
    } catch {
      return null;
    }
  }
  const errors = [];
  const resolved = await resolvePackage(input, repositoryRoot, errors);
  if (!resolved) return null;
  const inventory = await inventoryPackage(resolved.packageRoot, repositoryRoot, Boolean(trackedOnly), errors);
  return inventory.safe && errors.length === 0 ? hashManifest(inventory.files) : null;
}

function parseArguments(argv) {
  const options = { packagePath: null, repositoryRoot: process.cwd(), trackedOnly: false, json: false };
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === '--package' || argument === '--repository-root') {
      const value = argv[index + 1];
      if (!value || value.startsWith('--')) throw new Error(`${argument} requires a value`);
      if (argument === '--package') options.packagePath = value;
      else options.repositoryRoot = value;
      index += 1;
    } else if (argument === '--tracked-only') {
      options.trackedOnly = true;
    } else if (argument === '--json') {
      options.json = true;
    } else {
      throw new Error(`Unknown argument: ${argument}`);
    }
  }
  if (!options.packagePath) throw new Error('--package is required');
  return options;
}

async function main(argv) {
  let options;
  try {
    options = parseArguments(argv);
  } catch (error) {
    process.stderr.write(`validate.mjs: ${error.message}\n`);
    process.exitCode = 2;
    return;
  }
  const result = await validatePackage(options.packagePath, options);
  process.stdout.write(`${JSON.stringify(result, null, options.json ? 0 : 2)}\n`);
  if (!result.valid) process.exitCode = 1;
}
if (process.argv[1]) {
  const self = await realpath(fileURLToPath(import.meta.url)).catch(() => path.resolve(fileURLToPath(import.meta.url)));
  const requested = await realpath(path.resolve(process.argv[1])).catch(() => path.resolve(process.argv[1]));
  if (self === requested) {
    await main(process.argv.slice(2));
  }
}

