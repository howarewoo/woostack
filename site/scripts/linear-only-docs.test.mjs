import assert from 'node:assert/strict';
import { readdir, readFile } from 'node:fs/promises';
import path from 'node:path';
import { before, test } from 'node:test';

const REPO_ROOT = path.resolve(import.meta.dirname, '..', '..');
const NEGATION = /\b(?:no|not|never|without|cannot|can't|does not|do not|must not|regardless)\b/i;
const WOO_167_RETIRED_FILES = Object.freeze([
  'skills/woostack-review/references/linear-review.md',
  'skills/woostack-review/evals/fixtures/linear-review-contract.json',
  'skills/woostack-build/references/linear-review.md',
  'skills/woostack-build/evals/fixtures/linear-review-contract.json',
  'skills/woostack-execute/references/linear-review.md',
  'skills/woostack-execute/evals/fixtures/linear-review-contract.json',
]);
const WOO_166_REVIEW_PATHS = Object.freeze([
  'skills/woostack-review/SKILL.md',
  'skills/woostack-review/references/context.md',
  'skills/woostack-review/references/procedure.md',
  'skills/woostack-review/references/linear-context.md',
  'skills/woostack-review/references/linear-procedure.md',
  'skills/woostack-address-comments/SKILL.md',
  'skills/woostack-address-comments/references/linear-context.md',
  'skills/woostack-address-comments/references/linear-procedure.md',
  'skills/woostack-sweep/SKILL.md',
  'skills/woostack-sweep/references/linear-context.md',
  'skills/woostack-sweep/references/linear-procedure.md',
]);
const REVIEW_MODE_MARKERS = Object.freeze([
  /\blinear\.reviewMode\b/i,
  /\breviewMode\b/i,
  /\bReview mode\b/i,
  /\b`reviewMode`\b/i,
  /\b`linear\.reviewMode`\b/i,
  /\bWOO-166\b/i,
]);

const PATHS = [
  'skills/using-woostack/SKILL.md',
  'skills/woostack-init/SKILL.md',
  'skills/woostack-init/references/artifact-backends.md',
  'skills/woostack-init/references/worktrees.md',
  'skills/woostack-bootstrap/SKILL.md',
  'skills/woostack-build/SKILL.md',
  'skills/woostack-build/references/linear-context.md',
  'skills/woostack-build/references/linear-procedure.md',
  'skills/woostack-fix/SKILL.md',
  'skills/woostack-change/SKILL.md',
  'skills/woostack-plan/SKILL.md',
  'skills/woostack-execute/SKILL.md',
  'skills/woostack-execute/references/controller.md',
  'skills/woostack-execute/references/subagent-driver.md',
  'skills/woostack-commit/SKILL.md',
  'skills/woostack-review/SKILL.md',
  'skills/woostack-address-comments/SKILL.md',
  'skills/woostack-status/SKILL.md',
  'skills/woostack-visualize/SKILL.md',
  'skills/woostack-debug/SKILL.md',
  'skills/woostack-tdd/SKILL.md',
  'skills/woostack-doctor/SKILL.md',
  'skills/woostack-sweep/SKILL.md',
  'skills/woostack-qa/SKILL.md',
  'skills/woostack-audit/SKILL.md',
  'skills/woostack-eval/SKILL.md',
  'skills/woostack-reflect/SKILL.md',
  'skills/woostack-ideate/SKILL.md',
  'skills/woostack-harden/SKILL.md',
  'site/content/docs/concepts.mdx',
  'site/content/docs/configuration.mdx',
  'site/content/docs/getting-started.mdx',
  'site/content/docs/hermes.mdx',
  'site/content/docs/index.mdx',
  'site/content/docs/concepts/building-rules.mdx',
  'site/content/docs/concepts/workflows.mdx',
  'site/content/docs/harnesses/omp.mdx',
  'README.md',
  'AGENTS.md',
];

let files;
let authoredSitePaths;

async function collectAuthoredSitePaths(relativeDir = 'site/content/docs') {
  const absoluteDir = path.join(REPO_ROOT, relativeDir);
  const entries = await readdir(absoluteDir, { withFileTypes: true });
  const collected = [];

  for (const entry of entries) {
    const entryRelative = path.join(relativeDir, entry.name);
    if (entry.isDirectory()) {
      if (entryRelative === 'site/content/docs/skills') {
        continue;
      }
      collected.push(...await collectAuthoredSitePaths(entryRelative));
      continue;
    }
    if (entry.isFile() && entry.name.endsWith('.mdx')) {
      collected.push(entryRelative);
    }
  }

  return collected.sort();
}

before(async () => {
  authoredSitePaths = await collectAuthoredSitePaths();
  const allPaths = Array.from(new Set([...PATHS, ...authoredSitePaths]));
  const loaded = await Promise.all(
    allPaths.map(async (relativePath) => {
      const content = await readFile(path.join(REPO_ROOT, relativePath), 'utf8');
      return [relativePath, content];
    }),
  );
  files = new Map(loaded);
});

function read(relativePath) {
  const content = files.get(relativePath);
  assert.ok(content, `File not loaded: ${relativePath}`);
  return content;
}

function assertContains(relativePath, pattern, message) {
  assert.match(read(relativePath), pattern, `${relativePath}: ${message}`);
}

function normalize(value) {
  return value
    .toLowerCase()
    .replace(/[`*_#[\]()]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function semanticClauses(value) {
  return value
    .split(/(?:\r?\n)+|[.;:]\s+/)
    .map(normalize)
    .filter(Boolean);
}


function assertInOrder(relativePath, steps) {
  const content = read(relativePath);
  let lastIndex = -1;
  for (const [name, pattern] of steps) {
    const match = pattern.exec(content.slice(lastIndex + 1));
    assert.ok(match, `${relativePath}: missing step "${name}" in expected order`);
    lastIndex = lastIndex + 1 + match.index;
  }
}


test('Linear access follows the canonical project and direct-issue contract', () => {
  for (const relativePath of [
    'skills/woostack-build/SKILL.md',
    'skills/woostack-fix/SKILL.md',
    'skills/woostack-plan/SKILL.md',
    'skills/woostack-execute/SKILL.md',
  ]) {
    const content = read(relativePath);
    assert.doesNotMatch(content, /`--parent`|--parent-issue/i,
      `${relativePath}: must not mention a retired parent flag`);
    assert.match(content, /`--project`/i,
      `${relativePath}: must reference the canonical --project flag`);
  }

  for (const relativePath of [
    'skills/woostack-build/SKILL.md',
    'skills/woostack-plan/SKILL.md',
    'skills/woostack-init/references/artifact-backends.md',
  ]) {
    assert.match(read(relativePath), /Each independently shippable increment is one direct issue in that project/i,
      `${relativePath}: must enforce direct project issues`);
  }
});

test('new fix provider boundary and driver selection are explicit', () => {
  const fix = read('skills/woostack-fix/SKILL.md');
  assert.match(fix, /Before root-cause proof, Fix makes no provider call/i,
    'skills/woostack-fix/SKILL.md: must enforce zero provider calls before proof');
  assert.match(fix, /If `--project` is omitted, Fix creates exactly one project after root-cause proof/i,
    'skills/woostack-fix/SKILL.md: must create exactly one canonical project after proof');
  assert.match(fix, /\[Fast-model subagent driver\]\(references\/subagent-driver\.md\)/i,
    'skills/woostack-execute/SKILL.md: must link to the fast-model driver');
});

test('authored public surfaces keep the canonical project and direct-issue boundary', () => {
  for (const relativePath of [
    'site/content/docs/concepts.mdx',
    'site/content/docs/getting-started.mdx',
    'site/content/docs/concepts/workflows.mdx',
    'README.md',
    'AGENTS.md',
  ]) {
    const content = read(relativePath);
    assert.doesNotMatch(content, /one project, one parent plan issue/i,
      `${relativePath}: must not use the retired wrapper model`);
    assert.doesNotMatch(content, /\bparent plan issue\b/i,
      `${relativePath}: must not refer to a parent plan issue`);
  }

  assertContains('site/content/docs/concepts.mdx',
    /Every build or project-backed fix manages one high-level specification plus direct increment contracts/i,
    'concepts must describe direct increment contracts');
  assertContains('site/content/docs/concepts/workflows.mdx',
    /direct-issue plan/i,
    'workflow docs must describe direct-issue planning');
});

test('build and standalone-plan persistence keeps direct issues without a parent plan', () => {
  const build = read('skills/woostack-build/SKILL.md');
  assert.match(build, /Each independently shippable increment is one direct issue in that project/i,
    'skills/woostack-build/SKILL.md: must enforce direct project issues');
  assert.match(build, /Do not create a parent plan issue/i,
    'skills/woostack-build/SKILL.md: must forbid parent plan creation');

  const plan = read('skills/woostack-plan/SKILL.md');
  assert.match(plan, /`--project` is mandatory/i,
    'skills/woostack-plan/SKILL.md: must require --project');
  assert.match(plan, /never creates or selects an implicit project/i,
    'skills/woostack-plan/SKILL.md: must not create an implicit project');
  assert.match(plan, /one complete approved specification/i,
    'skills/woostack-plan/SKILL.md: must require one approved specification');
  assert.match(plan, /exactly one direct project issue for each execution increment/i,
    'skills/woostack-plan/SKILL.md: must persist direct issues');
  assert.match(plan, /Never create a parent, container, checklist, layer, or wrapper issue/i,
    'skills/woostack-plan/SKILL.md: must forbid wrapper issues');

  const procedure = read('skills/woostack-build/references/linear-procedure.md');
  assert.match(procedure, /one direct project issue per current increment/i,
    'procedure: must persist direct issues');
  assert.match(procedure, /Do not create a parent plan issue/i,
    'procedure: must forbid parent plan creation');

  const context = read('skills/woostack-build/references/linear-context.md');
  assert.match(context, /direct-issue/i,
    'context: must describe direct issues');
});

test('selected Linear capability is proved without reading repository credentials', () => {
  for (const relativePath of [
    'skills/woostack-build/SKILL.md',
    'skills/woostack-fix/SKILL.md',
  ]) {
    assert.match(read(relativePath), /(?:shared[\s\S]{0,80})?Linear artifact contract/i,
      `${relativePath}: must load the Linear artifact contract`);
  }
});

test('local drafts defer provider synchronization until plain artifacts are written', () => {
  const contract = read('skills/woostack-init/references/artifact-backends.md').replace(/\s+/g, ' ');
  assert.match(contract, /0700.*0600/i);
  assert.match(contract, /zero Linear or other provider reads and writes|zero provider reads and writes/i);
  assert.match(contract, /writes plain Markdown `project-spec\.md`|Write `project-spec\.md` exactly once/i);
  assert.match(contract, /writes plain Markdown `execution-plan\.md`|Write `execution-plan\.md` exactly once/i);
  assert.match(contract, /Execute-era safety reads are unchanged|Execute safety reads/i);

  const procedure = read('skills/woostack-build/references/linear-procedure.md').replace(/\s+/g, ' ');
  assert.match(procedure, /one direct project issue per current increment/i);
  assert.match(procedure, /independently read every issue's canonical issue reference/i);
  assert.match(procedure, /independently read the complete relation set/i);
});

test('abandonment retains local run artifacts and leaves mirrored projects unchanged', () => {
  const contract = read('skills/woostack-init/references/artifact-backends.md').replace(/\s+/g, ' ');
  assert.match(contract, /Retain `manifest\.json`, `project-spec\.md`, `execution-plan\.md`, and `\.lock`/i);
  assert.match(contract, /status: "abandoned"/i);
  assert.match(contract, /without mutating a mirrored Linear project|does not mutate a mirrored Linear project/i);
  assert.match(contract, /Handoff, replanning?, and blockers leave project status unchanged/i);

  const procedure = read('skills/woostack-build/references/linear-procedure.md');
  assert.match(procedure, /recording `status: "abandoned"` and retaining all run artifacts without closing a mirrored Linear project/i);
  assert.match(procedure, /Handoff, replan, pauses, and blockers leave project status unchanged/i);

  const fix = read('skills/woostack-fix/SKILL.md').replace(/\s+/g, ' ');
  assert.match(fix, /If an exact canonical issue reference was supplied.*preserve its title, description, status, assignment, labels, relations, comments, and lifecycle/i);
  assert.match(fix, /Abandon.*records `status: "abandoned"` in the manifest, retains run artifacts, does not close or mutate a mirrored Linear project/i);
});

test('explicit creation never fuzzy-matches an exact existing resource', () => {
  const contract = read('skills/woostack-init/references/artifact-backends.md').replace(/\s+/g, ' ');
  assert.match(contract, /exact caller-supplied resource always takes precedence over creation/i);
  assert.match(contract, /Never infer an artifact from\s+a title/i);

  const procedure = read('skills/woostack-build/references/linear-procedure.md').replace(/\s+/g, ' ');
  assert.match(procedure, /stable client-generated (?:issue and relation )?mutation UUID/i);
});


test('woostack-change has no Linear command or synchronization surface', () => {
  const change = read('skills/woostack-change/SKILL.md');
  assert.match(change, /makes no Linear call and invokes no other woostack workflow/i);
  assert.doesNotMatch(change, /--issue|--project|artifact synchronization|Linear-Issue:/i);

  assertContains('skills/using-woostack/SKILL.md', /`\/woostack-change <goal>`[^\n]*one isolated worktree/i,
    'routing must keep Change repository-local');
  assertContains('site/content/docs/concepts/workflows.mdx', /Change[\s\S]{0,500}never reads or writes Linear/i,
    'workflow docs must keep Change artifact-free');
});



test('local run manifests and git evidence own delivery truth', () => {
  for (const relativePath of ['README.md', 'AGENTS.md']) {
    assertContains(relativePath,
      /Linear never\s+supplies source-control or delivery truth|artifacts?[\s\S]{0,80}never (?:grant|authorize)|do not assign permission|Git and GitHub own/i,
      'must preserve the ordinary artifact authority boundary');
  }
  assertContains('skills/woostack-build/SKILL.md',
    /(?:artifacts?|records?)[\s\S]{0,120}(?:never|do not)[\s\S]{0,80}(?:grant|authorize|assign)[\s\S]{0,40}(?:permission|authority)/i,
    'Build must preserve the artifact permission boundary');
  assertContains('site/content/docs/concepts.mdx',
    /Linear mirroring|artifacts\.provider|Git and GitHub own source/i,
    'concepts must preserve repository delivery authority');
});

test('authored setup order keeps initialization and the external-engineer guide sequenced', () => {
  assertInOrder('README.md', [
    ['initialization', /\b2\.\s+Initialization\b/i],
    ['repository policy', /\b4\.\s+Repository Policy\b/i],
    ['external engineer context', /\b5\.\s+Artifact Context, Provider Mirroring, and External Engineers\b/i],
  ]);
  const sectionFiveTocLine = read('README.md')
    .split('\n')
    .find((line) => line.includes('](#5-artifact-context-provider-mirroring-and-external-engineers)'));
  assert.match(sectionFiveTocLine ?? '', /^ {2}- /,
    'README.md: section 5 must remain nested under Getting Started');
  assertInOrder('site/content/docs/getting-started.mdx', [
    ['initialize local support', /\b2\.\s+Initialize local support\b/i],
    ['choose workflow', /\b3\.\s+Choose the workflow\b/i],
    ['automatic Linear defaults', /\b4\.\s+(?:Automatic\s+Linear\s+default\s+setup|Optional\s+Linear\s+mirror\s+setup)\b/i],
    ['external engineer', /5\. Use an external engineer \(optional\)/i],
  ]);
});

test('Hermes is one external engineer over one persistent OMP process', () => {
  assertContains('site/content/docs/hermes.mdx',
    /Hermes is an \*\*external engineer\*\*, not a supported woostack host or installed woostack runtime/i,
    'Hermes docs must define Hermes as an external engineer');
  assertContains('site/content/docs/hermes.mdx',
    /Drive one persistent OMP session per live interaction/i,
    'Hermes docs must prescribe driving persistent OMP sessions');
  assertContains('site/content/docs/hermes.mdx',
    /Keep one OMP process identity for each active bounded interaction/i,
    'Hermes docs must preserve OMP process identity');
  assertContains('site/content/docs/hermes.mdx',
    /Do not switch processes during a live interaction/i,
    'Hermes docs must forbid process switching during live interactions');
  assertContains('site/content/docs/hermes.mdx',
    /Clean up is optional and manual/i,
    'Hermes docs must treat process cleanup as manual');
});

test('canonical host routing excludes retired Hermes and includes OMP', () => {
  for (const relativePath of [
    'skills/using-woostack/SKILL.md',
    'skills/woostack-doctor/SKILL.md',
  ]) {
    assertContains(relativePath,
      /`omp` \(Oh My Pi\)/i,
      `${relativePath}: must include OMP in the canonical host list`);
    assert.doesNotMatch(read(relativePath), /`hermes`/i,
      `${relativePath}: must not include Hermes as a supported host`);
  }
});

test('supported navigation keeps Hermes out of coding harnesses', () => {
  const hermes = read('site/content/docs/hermes.mdx');
  assert.match(hermes, /sidebar:\s*\{\s*order:\s*4\s*\}/i,
    'hermes.mdx: must place Hermes in root sidebar order 4');
  assert.doesNotMatch(hermes, /sidebar:\s*\{\s*hidden:\s*true\s*\}/i,
    'hermes.mdx: must not hide Hermes from navigation');
});

test('approval relay remains responsible-user and receipt bound', () => {
  assertContains('site/content/docs/hermes.mdx',
    /relay that response \*\*verbatim and unmodified\*\*|responsible-user's live response must be relayed verbatim|relay the responsible user's verbatim approval/i,
    'Hermes docs must require verbatim responsible-user approval relay');
});

test('provider-neutral configuration and project label preservation contracts are documented', () => {
  const contract = read('skills/woostack-init/references/artifact-backends.md').replace(/\s+/g, ' ');
  assert.match(contract, /artifacts\.provider/i);
  assert.match(contract, /artifacts\.linear\.projectLabels/i);
  assert.match(contract, /exact native ID.*or.*exact case-sensitive name/i);
  assert.match(contract, /union of existing project labels and configured labels/i);
  assert.match(contract, /preserving all unrelated existing labels/i);
  assert.match(contract, /at most one write alongside project creation or admission/i);
  assert.match(contract, /independently read back the complete label set/i);

  const configDoc = read('site/content/docs/configuration.mdx').replace(/\s+/g, ' ');
  assert.match(configDoc, /artifacts\.provider/i);
  assert.match(configDoc, /artifacts\.linear\.projectLabels/i);
});

test('retired WOO-167 assets are absent and the WOO-166 Review mode is absent', async () => {
  for (const relativePath of WOO_167_RETIRED_FILES) {
    assert.strictEqual(
      files.has(relativePath),
      false,
      `Retired WOO-167 asset must not exist: ${relativePath}`,
    );
  }

  for (const relativePath of WOO_166_REVIEW_PATHS) {
    const content = read(relativePath);
    for (const marker of REVIEW_MODE_MARKERS) {
      assert.doesNotMatch(
        content,
        marker,
        `${relativePath}: must not contain retired WOO-166 review mode marker ${marker}`,
      );
    }
  }
});
