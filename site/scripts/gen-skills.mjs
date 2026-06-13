import { readdir, readFile, writeFile, mkdir, rm } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..', '..'); // site/scripts -> repo root
const SKILLS_DIR = path.join(REPO_ROOT, 'skills');
const OUT_DIR = path.resolve(__dirname, '..', 'content', 'docs', 'skills');
const GH_BASE = 'https://github.com/howarewoo/woostack/blob/main';
const INTERNAL = new Set(['woostack-ideate', 'woostack-harden']);

const ORDER = [
  'using-woostack', 'woostack-init', 'woostack-bootstrap', 'woostack-build', 'woostack-fix',
  'woostack-plan', 'woostack-execute', 'woostack-execute-overnight', 'woostack-commit',
  'woostack-review', 'woostack-address-comments', 'woostack-status', 'woostack-visualize',
  'woostack-debug', 'woostack-tdd', 'woostack-dream',
];

export function parseFrontmatter(raw, file = '<input>') {
  const m = /^---\n([\s\S]*?)\n---\n?/.exec(raw);
  if (!m) throw new Error(`${file}: missing frontmatter`);
  const fm = {};
  for (const line of m[1].split('\n')) {
    const mm = /^(\w+):\s*(.*)$/.exec(line);
    if (!mm) continue;
    let v = mm[2].trim();
    if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) {
      v = v.slice(1, -1).replace(/\\"/g, '"'); // some descriptions are YAML-quoted in source
    }
    fm[mm[1]] = v;
  }
  if (!fm.name) throw new Error(`${file}: frontmatter missing 'name'`);
  if (!fm.description) throw new Error(`${file}: frontmatter missing 'description'`);
  return { fm, body: raw.slice(m[0].length) };
}

export function stripTitleHeading(body, name) {
  const lines = body.split('\n');
  const idx = lines.findIndex((l) => l.trim() === `# ${name}`);
  if (idx !== -1) lines.splice(idx, 1);
  return lines.join('\n');
}

export function rewriteLinks(body, name) {
  return body.replace(/\]\(([^)]+)\)/g, (whole, target) => {
    if (/^https?:\/\//.test(target) || target.startsWith('#') || target.startsWith('mailto:')) return whole;
    const skill = /^\.\.\/([a-z0-9-]+)\/SKILL\.md(#.+)?$/.exec(target);
    if (skill) return `](/docs/skills/${skill[1]}${skill[2] || ''})`;
    const hash = (target.match(/#.*$/) || [''])[0];
    const clean = target.replace(/#.*$/, '');
    const rel = clean.replace(/^(\.\.\/)+/, ''); // strip leading ../
    const ghPath = clean.startsWith('../') ? `skills/${rel}` : `skills/${name}/${rel}`;
    return `](${GH_BASE}/${ghPath}${hash})`;
  });
}

function humanizeTag(t) {
  const s = t.replace(/-/g, ' ').toLowerCase();
  return s.charAt(0).toUpperCase() + s.slice(1);
}

function escapeBareTagsOutsideCode(line) {
  // split on inline code spans; only escape uppercase tags in the non-code segments
  return line
    .split(/(`[^`]*`)/)
    .map((seg) => (seg.startsWith('`') ? seg : seg.replace(/<(\/?[A-Z][A-Z-]*)>/g, '&lt;$1&gt;')))
    .join('');
}

export function neutralizeTags(body) {
  const out = [];
  let inFence = false;
  for (const line of body.split('\n')) {
    if (/^\s*(```|~~~)/.test(line)) { inFence = !inFence; out.push(line); continue; }
    if (inFence) { out.push(line); continue; }
    const open = /^<([A-Z][A-Z-]*)>\s*$/.exec(line);
    if (open) { out.push(`<Callout type="warn" title="${humanizeTag(open[1])}">`); continue; }
    if (/^<\/[A-Z][A-Z-]*>\s*$/.test(line)) { out.push('</Callout>'); continue; }
    out.push(escapeBareTagsOutsideCode(line));
  }
  return out.join('\n');
}

export function renderPage(name, fm, body) {
  const front = `---\ntitle: ${name}\ndescription: ${JSON.stringify(fm.description)}\n---\n\n`;
  const internal = INTERNAL.has(name)
    ? `<Callout type="info" title="Internal sub-skill">Building block of [woostack-build](/docs/skills/woostack-build); not a directly-invocable \`/woostack-*\` command.</Callout>\n\n`
    : '';
  const source = `[View source on GitHub](${GH_BASE}/skills/${name}/SKILL.md)\n\n`;
  return front + internal + source + body.replace(/^\n+/, '') + '\n';
}

export function navOrder(names) {
  return [...ORDER.filter((n) => names.includes(n)), ...names.filter((n) => !ORDER.includes(n))];
}

async function main() {
  if (!existsSync(SKILLS_DIR)) {
    console.error(
      `gen-skills: source dir not found: ${SKILLS_DIR}\n` +
      `On Vercel, enable "Include files outside the root directory in the Build Step".`
    );
    process.exit(1);
  }
  await rm(OUT_DIR, { recursive: true, force: true });
  await mkdir(OUT_DIR, { recursive: true });
  const names = (await readdir(SKILLS_DIR, { withFileTypes: true }))
    .filter((e) => e.isDirectory())
    .map((e) => e.name)
    .sort();
  const written = [];
  for (const name of names) {
    const file = path.join(SKILLS_DIR, name, 'SKILL.md');
    if (!existsSync(file)) continue;
    const raw = await readFile(file, 'utf8');
    const { fm, body } = parseFrontmatter(raw, name);
    let b = stripTitleHeading(body, fm.name);
    b = neutralizeTags(b);
    b = rewriteLinks(b, name);
    await writeFile(path.join(OUT_DIR, `${name}.mdx`), renderPage(name, fm, b), 'utf8');
    written.push(name);
  }
  await writeFile(
    path.join(OUT_DIR, 'meta.json'),
    JSON.stringify({ title: 'Skills', pages: navOrder(written) }, null, 2) + '\n',
    'utf8'
  );
  console.log(`gen-skills: wrote ${written.length} pages -> ${path.relative(process.cwd(), OUT_DIR)}`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch((e) => { console.error(e.message); process.exit(1); });
}
