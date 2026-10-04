import { writeFile, mkdir, rm } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { validateSkillAssets } from './skill-assets.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SKILLS_DIR = path.resolve(__dirname, '..', '..', 'skills'); // site/scripts -> repo-root skills/
const OUT_DIR = path.resolve(__dirname, '..', 'content', 'docs', 'skills');
const GH_BASE = 'https://github.com/howarewoo/woostack/blob/main';
export const PUBLIC_ORDER = [
  'using-woostack',
  'woostack-init',
  'woostack-ideate',
  'woostack-harden',
  'woostack-plan',
  'woostack-orchestrate',
  'woostack-execute',
  'woostack-simplify',
  'woostack-commit',
  'woostack-address-comments',
  'woostack-visualize',
  'woostack-design',
  'woostack-debug',
  'woostack-doctor',
  'woostack-qa',
  'woostack-reflect',
];

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

// Inline code spans are passed through untouched; `replace` only ever sees prose.
function mapOutsideCodeSpans(line, pattern, replacement) {
  return line
    .split(/(`[^`]*`)/)
    .map((segment) => (segment.startsWith('`') ? segment : segment.replace(pattern, replacement)))
    .join('');
}

export function neutralizeTags(body) {
  const out = [];
  let inFence = false;
  let attributedHardGateDepth = 0;
  for (const line of body.split('\n')) {
    if (/^\s*(```|~~~)/.test(line)) { inFence = !inFence; out.push(line); continue; }
    if (inFence) { out.push(line); continue; }
    if (/^\s*<!--.*-->\s*$/.test(line)) continue;
    let strippedHardGate = false;
    const publicLine = mapOutsideCodeSpans(
      line,
      /<HARD-GATE\s+[^<>]*>|<\/HARD-GATE>/g,
      (tag) => {
        if (tag.startsWith('</') && attributedHardGateDepth === 0) return tag;
        attributedHardGateDepth += tag.startsWith('</') ? -1 : 1;
        strippedHardGate = true;
        return '';
      }
    );
    if (strippedHardGate && publicLine.trim() === '') continue;
    const open = /^<([A-Z][A-Z-]*)>\s*$/.exec(publicLine);
    if (open) { out.push(`<Callout type="warn" title="${humanizeTag(open[1])}">`); continue; }
    if (/^<\/[A-Z][A-Z-]*>\s*$/.test(publicLine)) { out.push('</Callout>'); continue; }
    out.push(mapOutsideCodeSpans(publicLine, /<(\/?[A-Z][A-Z-]*)(\s+[^<>]*?)?>/g, '&lt;$1$2&gt;'));
  }
  return out.join('\n');
}

export function renderPage(name, fm, body) {
  const front = `---\ntitle: ${name}\ndescription: ${JSON.stringify(fm.description)}\n---\n\n`;
  const source = `[View source on GitHub](${GH_BASE}/skills/${name}/SKILL.md)\n\n`;
  return front + source + body.replace(/^\n+/, '') + '\n';
}

export function navOrder(names) {
  return [...PUBLIC_ORDER.filter((n) => names.includes(n)), ...names.filter((n) => !PUBLIC_ORDER.includes(n))];
}

async function main() {
  if (!existsSync(SKILLS_DIR)) {
    console.error(
      `gen-skills: source dir not found: ${SKILLS_DIR}\n` +
      `On Vercel, enable "Include files outside the root directory in the Build Step".`
    );
    process.exit(1);
  }
  const skills = await validateSkillAssets(SKILLS_DIR, PUBLIC_ORDER);
  await rm(OUT_DIR, { recursive: true, force: true });
  await mkdir(OUT_DIR, { recursive: true });
  for (const { name, fm, body } of skills) {
    const rendered = rewriteLinks(neutralizeTags(stripTitleHeading(body, fm.name)), name);
    await writeFile(path.join(OUT_DIR, `${name}.mdx`), renderPage(name, fm, rendered), 'utf8');
  }
  const names = skills.map(({ name }) => name);
  await writeFile(
    path.join(OUT_DIR, 'meta.json'),
    JSON.stringify({ title: 'Skills', pages: navOrder(names) }, null, 2) + '\n',
    'utf8'
  );
  console.log(`gen-skills: wrote ${names.length} pages -> ${path.relative(process.cwd(), OUT_DIR)}`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch((e) => { console.error(e.message); process.exit(1); });
}
