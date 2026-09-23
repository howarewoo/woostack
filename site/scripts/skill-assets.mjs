import { lstat, readFile, readdir } from 'node:fs/promises';
import path from 'node:path';

const KEBAB_CASE = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
const HTML_TAGS = new Set([
  'a', 'abbr', 'address', 'article', 'aside', 'audio', 'b', 'blockquote', 'body', 'br',
  'button', 'canvas', 'caption', 'code', 'col', 'data', 'datalist', 'dd', 'del',
  'details', 'dialog', 'div', 'dl', 'dt', 'em', 'embed', 'fieldset', 'figcaption', 'figure',
  'footer', 'form', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'head', 'header', 'hr', 'html', 'i',
  'iframe', 'img', 'input', 'ins', 'kbd', 'label', 'legend', 'li', 'link', 'main', 'map',
  'mark', 'menu', 'meta', 'meter', 'nav', 'noscript', 'object', 'ol', 'optgroup', 'option',
  'output', 'p', 'picture', 'pre', 'progress', 'q', 'rp', 'rt', 'ruby', 's', 'samp', 'script',
  'search', 'section', 'select', 'slot', 'small', 'source', 'span', 'strong', 'style',
  'sub', 'summary', 'sup', 'svg', 'table', 'tbody', 'td', 'template', 'textarea', 'tfoot', 'th',
  'thead', 'time', 'title', 'tr', 'track', 'u', 'ul', 'var', 'video', 'wbr', 'xml',
]);

class FrontmatterFault extends Error {
  constructor(code, field, message) {
    super(message);
    this.code = code;
    this.field = field;
  }
}

function escapePointer(value) {
  return String(value).replace(/~/g, '~0').replace(/\//g, '~1');
}

function decodeScalar(source, key, file) {
  const value = source.trim();
  if (value.startsWith('"')) {
    if (!value.endsWith('"') || value.length < 2) {
      throw new FrontmatterFault('frontmatter-invalid-scalar', `/${key}`, `${file}: unterminated quoted ${key}`);
    }
    try {
      return JSON.parse(value);
    } catch {
      throw new FrontmatterFault('frontmatter-invalid-scalar', `/${key}`, `${file}: invalid quoted ${key}`);
    }
  }
  if (value.startsWith("'")) {
    if (!value.endsWith("'") || value.length < 2) {
      throw new FrontmatterFault('frontmatter-invalid-scalar', `/${key}`, `${file}: unterminated quoted ${key}`);
    }
    const inner = value.slice(1, -1);
    if (inner.replace(/''/g, '').includes("'")) {
      throw new FrontmatterFault('frontmatter-invalid-scalar', `/${key}`, `${file}: invalid quoted ${key}`);
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
      throw new FrontmatterFault('frontmatter-non-string-scalar', `/${key}`, `${file}: ${key} must decode as a string`);
    }
  }
  if (key === 'description' && /:\s/.test(value)) {
    throw new FrontmatterFault(
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
  if (!match) throw new FrontmatterFault('frontmatter-missing', '', `${file}: missing frontmatter`);
  const fm = {};
  const seen = new Set();
  for (const line of match[1].split(/\r?\n/)) {
    if (!line.trim() || /^\s*#/.test(line) || /^\s+/.test(line)) continue;
    const field = /^([A-Za-z_][A-Za-z0-9_-]*):(?:[ \t]*(.*))$/.exec(line);
    if (!field) {
      throw new FrontmatterFault('frontmatter-invalid-line', '', `${file}: invalid frontmatter line`);
    }
    const [, key, source] = field;
    if (seen.has(key)) {
      throw new FrontmatterFault(
        'frontmatter-duplicate-field',
        `/${escapePointer(key)}`,
        `${file}: duplicate frontmatter field ${key}`,
      );
    }
    seen.add(key);
    fm[key] = decodeScalar(source, key, file);
  }
  if (!Object.hasOwn(fm, 'name')) {
    throw new FrontmatterFault('frontmatter-name-missing', '/name', `${file}: frontmatter missing 'name'`);
  }
  if (!Object.hasOwn(fm, 'description')) {
    throw new FrontmatterFault(
      'frontmatter-description-missing',
      '/description',
      `${file}: frontmatter missing 'description'`,
    );
  }
  if (typeof fm.name !== 'string') {
    throw new FrontmatterFault('frontmatter-name-non-scalar', '/name', `${file}: name must be a scalar string`);
  }
  if (typeof fm.description !== 'string') {
    throw new FrontmatterFault(
      'frontmatter-description-non-scalar',
      '/description',
      `${file}: description must be a scalar string`,
    );
  }
  if (containsXmlMarkup(fm.description)) {
    throw new FrontmatterFault(
      'frontmatter-xml-markup',
      '/description',
      `${file}: description contains XML-like markup`,
    );
  }
  return { fm, body: raw.slice(match[0].length) };
}

function markdownContentLines(raw) {
  const lines = [];
  let fence = null;
  for (const line of raw.split(/\r?\n/)) {
    if (fence) {
      const closing = /^ {0,3}(`{3,}|~{3,})[ \t]*$/.exec(line);
      if (closing && closing[1][0] === fence.marker && closing[1].length >= fence.length) {
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
  return value.replace(/\\([!"#$%&'()*+,\-./:;<=>?@[\\\]^_`{|}~])/g, '$1');
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

function isContained(root, candidate) {
  const relative = path.relative(root, candidate);
  return relative === '' || (!relative.startsWith(`..${path.sep}`) && relative !== '..' && !path.isAbsolute(relative));
}

async function validateLocalLinks(collectionRoot, sourcePath, raw) {
  for (const link of extractMarkdownLinks(raw)) {
    const target = localLinkTarget(link);
    if (target === null) continue;
    if (target.includes('\0') || target.includes('\\')) {
      throw new Error(`${sourcePath}: local link target is not a safe POSIX path: ${link}`);
    }
    const segments = target.split('/');
    if (segments.includes('.') || segments.includes('') || path.posix.normalize(target) !== target) {
      throw new Error(`${sourcePath}: local link target must use a normalized POSIX path: ${link}`);
    }
    const candidate = path.resolve(path.dirname(path.join(collectionRoot, sourcePath)), target);
    if (!isContained(collectionRoot, candidate)) {
      throw new Error(`${sourcePath}: local link target escapes the skill collection: ${link}`);
    }
    let state;
    try {
      state = await lstat(candidate);
    } catch (error) {
      if (error?.code === 'ENOENT') {
        throw new Error(`${sourcePath}: local link target does not exist: ${link}`);
      }
      throw error;
    }
    if (state.isSymbolicLink()) {
      throw new Error(`${sourcePath}: local link target must not be a symlink: ${link}`);
    }
    if (!state.isFile()) {
      throw new Error(`${sourcePath}: local link target must be a regular file: ${link}`);
    }
  }
}

async function collectFiles(root) {
  const files = [];
  async function visit(directory) {
    const entries = (await readdir(directory, { withFileTypes: true })).sort((a, b) => a.name.localeCompare(b.name));
    for (const entry of entries) {
      const absolute = path.join(directory, entry.name);
      if (entry.isDirectory()) await visit(absolute);
      else if (entry.isFile()) files.push(path.relative(root, absolute));
      else throw new Error(`${path.relative(root, absolute)}: skill assets must be regular files or directories`);
    }
  }
  await visit(root);
  return files;
}

export async function validateSkillAssets(skillsDir, publicOrder) {
  const root = path.resolve(skillsDir);
  const names = (await readdir(root, { withFileTypes: true }))
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort();
  const expected = [...publicOrder].sort();
  if (JSON.stringify(names) !== JSON.stringify(expected)) {
    throw new Error(`skill catalog mismatch: discovered ${names.join(', ')}; expected ${expected.join(', ')}`);
  }

  const skills = [];
  for (const name of names) {
    const packageRoot = path.join(root, name);
    const parsed = parseFrontmatter(await readFile(path.join(packageRoot, 'SKILL.md'), 'utf8'), `${name}/SKILL.md`);
    if (!KEBAB_CASE.test(parsed.fm.name)) {
      throw new Error(`${name}/SKILL.md: name must be lower-case kebab-case`);
    }
    if (parsed.fm.name !== name) {
      throw new Error(`${name}/SKILL.md: frontmatter name must exactly match the package directory`);
    }
    if (parsed.fm.description.length === 0) {
      throw new Error(`${name}/SKILL.md: description must be non-empty`);
    }
    if ([...parsed.fm.description].length > 1024) {
      throw new Error(`${name}/SKILL.md: description must not exceed 1024 characters`);
    }

    for (const file of await collectFiles(packageRoot)) {
      const sourcePath = path.posix.join(name, ...file.split(path.sep));
      const absolute = path.join(packageRoot, file);
      if (file.endsWith('.json')) {
        try {
          JSON.parse(await readFile(absolute, 'utf8'));
        } catch (error) {
          throw new Error(`${sourcePath}: invalid JSON: ${error.message}`);
        }
      } else if (/\.md$/i.test(file)) {
        await validateLocalLinks(root, sourcePath, await readFile(absolute, 'utf8'));
      }
    }
    skills.push({ name, ...parsed });
  }
  return skills;
}
