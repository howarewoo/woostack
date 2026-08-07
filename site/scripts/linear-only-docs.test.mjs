import assert from 'node:assert/strict';
import { lstat, readFile, readdir } from 'node:fs/promises';
import path from 'node:path';
import { before, test } from 'node:test';

const REPO_ROOT = path.resolve(import.meta.dirname, '..', '..');
const NEGATION = /\b(?:no|not|never|without|cannot|can't|does not|do not|must not|regardless)\b/i;
const WOO_167_RETIRED_FILES = Object.freeze([
  'skills/using-woostack/references/engineer-agents.md',
  'skills/using-woostack/references/hosts/hermes.md',
  'skills/woostack-init/scripts/gen-omp-agents.sh',
  'skills/woostack-init/scripts/tests/test-gen-omp-agents.sh',
  'site/content/docs/concepts/engineer-agents.mdx',
  'site/content/docs/harnesses/hermes.mdx',
]);
const WOO_166_REVIEW_PATHS = Object.freeze([
  'skills/woostack-review/prompts/_orchestrator-header.md',
  'skills/woostack-review/prompts/_worker-header.md',
  'skills/woostack-review/prompts/validator-prosecutor.md',
  'skills/woostack-review/prompts/validator.md',
  'skills/woostack-review/references/ci.md',
  'skills/woostack-review/scripts/resolve-outdir.sh',
  'skills/woostack-review/scripts/run-bounded-swarm.sh',
  'skills/woostack-review/scripts/verify-receipts.sh',
  'skills/woostack-review/scripts/tests/test-bounded-swarm.sh',
  'skills/woostack-review/scripts/tests/test-verify-receipts-identity.sh',
  'skills/woostack-review/scripts/tests/test-review-payload-ranges.sh',
  'skills/woostack-review/evals/evals.json',
]);
const REVIEW_MODE_MARKERS = Object.freeze([
  'WOO_REVIEW_ENGINEER_UNIT',
  'WOO_REVIEW_IDENTITY_MANIFEST',
  'reviewer-identities.json',
  'implementingCoder',
  'decisionMaker',
]);

const PATHS = [
  'README.md',
  'AGENTS.md',
  'skills/using-woostack/SKILL.md',
  'skills/using-woostack/references/hosts/README.md',
  'skills/using-woostack/references/model-tiers.md',
  'skills/woostack-review/SKILL.md',
  'skills/woostack-review/prompts/_orchestrator-header.md',
  'skills/woostack-doctor/scripts/checks/omp-agents.sh',
  'site/lib/source.ts',
  'skills/woostack-init/references/artifact-backends.md',
  'skills/woostack-build/SKILL.md',
  'skills/woostack-build/references/linear-context.md',
  'skills/woostack-build/references/linear-procedure.md',
  'skills/woostack-plan/SKILL.md',
  'skills/woostack-fix/SKILL.md',
  'skills/woostack-change/SKILL.md',
  'site/content/docs/index.mdx',
  'site/content/docs/meta.json',
  'site/content/docs/concepts/meta.json',
  'site/content/docs/harnesses/meta.json',
  'site/content/docs/getting-started.mdx',
  'site/content/docs/hermes.mdx',
  'site/content/docs/configuration.mdx',
  'site/content/docs/concepts.mdx',
  'site/content/docs/concepts/building-rules.mdx',
  'site/content/docs/concepts/workflows.mdx',
  'site/content/docs/concepts/index.mdx',
  'site/content/docs/harnesses/omp.mdx',
  'skills/using-woostack/references/hosts/omp.md',
  'site/content/docs/harnesses/index.mdx',
  ...WOO_166_REVIEW_PATHS,
];

let files;
let authoredSitePaths;

async function collectAuthoredSitePaths(relativeDir = 'site/content/docs') {
  const entries = await readdir(path.join(REPO_ROOT, relativeDir), { withFileTypes: true });
  const paths = [];

  for (const entry of entries) {
    const relativePath = path.join(relativeDir, entry.name);
    if (entry.isDirectory()) {
      if (relativePath !== 'site/content/docs/skills') {
        paths.push(...await collectAuthoredSitePaths(relativePath));
      }
    } else if (entry.isFile() && entry.name.endsWith('.mdx')) {
      paths.push(relativePath);
    }
  }

  return paths.sort();
}

before(async () => {
  authoredSitePaths = await collectAuthoredSitePaths();
  const loadedPaths = [...new Set([...PATHS, ...authoredSitePaths])];
  files = new Map(
    await Promise.all(
      loadedPaths.map(async (relativePath) => [
        relativePath,
        await readFile(path.join(REPO_ROOT, relativePath), 'utf8'),
      ])
    )
  );
});

function read(relativePath) {
  const value = files.get(relativePath);
  assert.notEqual(value, undefined, `${relativePath}: file was not loaded`);
  return value;
}

function assertContains(relativePath, pattern, message) {
  assert.match(read(relativePath), pattern, `${relativePath}: ${message}`);
}

function normalize(value) {
  return value
    .replace(/\[([^\]]+)]\(([^)]+)\)/g, '$1 $2')
    .replace(/<[^>]+>/g, ' ')
    .replace(/[`*_>#|]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function semanticClauses(value) {
  return value
    .split(/\n\s*\n+/)
    .flatMap((paragraph) => normalize(paragraph).split(/(?<=[.!?])\s+/))
    .flatMap((segment) => segment.split(/\s*(?:;|,\s+(?:but|yet|however)\b)\s*/i))
    .map((clause) => clause.trim())
    .filter(Boolean);
}


function assertInOrder(relativePath, steps) {
  const content = normalize(read(relativePath));
  let cursor = 0;
  for (const [label, pattern] of steps) {
    pattern.lastIndex = 0;
    const match = pattern.exec(content.slice(cursor));
    assert.ok(match, `${relativePath}: missing ordered step ${label}`);
    cursor += match.index + match[0].length;
  }
}


test('Linear access follows the canonical project and direct-issue contract', () => {
  for (const relativePath of [
    'README.md',
    'skills/woostack-init/references/artifact-backends.md',
    'skills/woostack-build/SKILL.md',
    'skills/woostack-fix/SKILL.md',
    'site/content/docs/getting-started.mdx',
  ]) {
    const text = read(relativePath).replace(/\s+/g, ' ');
    assert.match(text, /one (?:exact )?(?:canonical )?project/i,
      `${relativePath}: canonical project claim missing`);
    assert.match(text, /one direct (?:project )?issue per|one direct issue in that project|project issue per increment|increment is one direct issue|direct-issue (?:set|chain)|direct issues/i,
      `${relativePath}: direct issue per increment claim missing`);
  }
  const fix = read('skills/woostack-fix/SKILL.md').replace(/\s+/g, ' ');
  assert.match(fix, /Before root-cause proof, Fix makes no provider (?:call|read or write)/i);
  assert.match(fix, /After Debug returns root-cause proof.*resolve the exact supplied project or create exactly one canonical project/i);
  assert.match(fix, /`--issue` is optional source context, not the fix contract/i);
});

test('new fix provider boundary and driver selection are explicit', () => {
  const contract = read('skills/woostack-init/references/artifact-backends.md').replace(/\s+/g, ' ');
  assert.match(contract, /Build project resolution\/creation happens before ideation.*build has no artifact-free fallback/i);
  assert.match(contract, /Before root-cause proof, a fix makes no provider read or write/i);
  assert.match(contract, /Without exact selection or explicit persistence, standalone planning and all other artifact-optional commands make no provider call/i);

  const fix = read('skills/woostack-fix/SKILL.md').replace(/\s+/g, ' ');
  assert.match(fix, /`--inline` and `--subagent` select only the read-only Debug driver and are mutually exclusive/i);
  assert.match(fix, /Use a subagent when available by default/i);
  assert.match(fix, /explicitly requested subagent is unavailable.*disclose the degradation.*run inline only when safe/i);
});

test('authored public surfaces keep the canonical project and direct-issue boundary', () => {
  const surfaces = new Map([
    ['README.md', [
      /Build resolves one exact project/i,
      /new Fix uses one project plus a strict direct-issue chain/i,
    ]],
    ['site/content/docs/getting-started.mdx', [
      /Build uses one project for the high-level specification/i,
      /Fix uses one project for the complete specification/i,
    ]],
    ['site/content/docs/index.mdx', [
      /every build uses one project .* plus one direct issue per independently shippable increment/i,
      /every Fix uses one project .* strict direct-issue chain/i,
    ]],
  ]);

  for (const [relativePath, patterns] of surfaces) {
    const text = read(relativePath).replace(/\s+/g, ' ');
    for (const pattern of patterns) {
      assert.match(text, pattern, `${relativePath}: canonical project/direct-issue claim is missing`);
    }
  }
});

test('build and standalone-plan persistence keeps direct issues without a parent plan', () => {
  const surfaces = new Map([
    ['skills/woostack-init/references/artifact-backends.md', [
      /independently shippable increment.*one direct issue/i,
      /Do not create a parent plan issue/i,
    ]],
    ['skills/woostack-build/references/linear-procedure.md', [
      /one direct project issue per current increment/i,
      /no parent\/container relation/i,
    ]],
    ['skills/woostack-plan/SKILL.md', [
      /one direct project issue for each execution increment/i,
      /Never create a parent, container, checklist, layer, or plan issue/i,
    ]],
    ['site/content/docs/getting-started.mdx', [
      /Build uses one project for the high-level specification, one direct issue per increment/i,
    ]],
  ]);
  for (const [relativePath, patterns] of surfaces) {
    const text = read(relativePath).replace(/\s+/g, ' ');
    for (const pattern of patterns) {
      assert.match(text, pattern, `${relativePath}: direct issue hierarchy claim is missing`);
    }
  }
  const fix = read('skills/woostack-fix/SKILL.md').replace(/\s+/g, ' ');
  assert.match(fix, /one canonical project/i);
  assert.doesNotMatch(fix, /fix plan is persisted as one project/i);
  assert.doesNotMatch(fix, /one project.*parent plan issue.*child increment/i);
});

test('selected Linear capability is proved without reading repository credentials', () => {
  const contract = read('skills/woostack-init/references/artifact-backends.md');
  assert.match(contract, /Authentication remains in the host's secret store/i,
    'contract must identify host-owned credentials');
  assert.match(contract, /Init discovery may validate only non-secret repository\/workspace\/team\/native-name defaults/i,
    'init discovery must stay non-secret');
  for (const relativePath of [
    'skills/woostack-build/SKILL.md',
    'skills/woostack-fix/SKILL.md',
  ]) {
    assert.match(read(relativePath), /shared[\s\S]{0,80}Linear artifact contract/i,
      `${relativePath}: must load the shared artifact contract`);
  }
});

test('selected persistence fails safely and every mutation is read back', () => {
  const contract = read('skills/woostack-init/references/artifact-backends.md').replace(/\s+/g, ' ');
  assert.match(contract, /Missing required capability blocks the selected or required operation/i);
  assert.match(contract, /Fix requires complete fix-plan, relation, and approval-event read-back before dispatch/i);
  assert.match(contract, /After every mutation, perform a new independent complete read/i);

  const procedure = read('skills/woostack-build/references/linear-procedure.md').replace(/\s+/g, ' ');
  assert.match(procedure, /one direct project issue per current increment/i);
  assert.match(procedure, /independently read native identity, content, project membership, parent absence/i);
  assert.match(procedure, /independently read the complete relation set back/i);
});

test('abandonment closes only project-backed workflows and preserves source issues', () => {
  const contract = read('skills/woostack-init/references/artifact-backends.md').replace(/\s+/g, ' ');
  assert.match(contract, /Explicit abandonment is a terminal workflow action/i);
  assert.match(contract, /one exact persisted project/i);
  assert.match(contract, /existing project moves to the configured canceled status/i);
  assert.match(contract, /verify the canonical repository association and resolved workspace\/team/i);
  assert.match(contract, /update only that project's native status to the resolved canceled status/i);
  assert.match(contract, /independently re-read the exact project and verify its identity, canceled status/i);
  assert.match(contract, /never resumes repository work/i);
  assert.match(contract, /Handoff, replan, and blocker handling leave project status unchanged/i);
  assert.match(contract, /Never create a project merely to cancel it/i);

  const procedure = read('skills/woostack-build/references/linear-procedure.md');
  assert.match(procedure, /Explicit abandonment follows the shared[\s\S]{0,100}project-backed workflow closure/i);
  assert.match(procedure, /Handoff, replan, pauses, and blockers leave project status unchanged/i);

  const fix = read('skills/woostack-fix/SKILL.md').replace(/\s+/g, ' ');
  assert.match(fix, /If an exact source issue was supplied.*preserve its title, description, status, assignment, labels, relations, comments, and lifecycle/i);
  assert.doesNotMatch(fix, /projectStatuses\.canceled/i);
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



test('only exact native fix approval authorizes repository work', () => {
  for (const relativePath of ['README.md', 'AGENTS.md']) {
    assertContains(relativePath,
      /Linear never\s+supplies source-control or delivery truth|artifacts?[\s\S]{0,80}never (?:grant|authorize)|do not assign permission/i,
      'must preserve the ordinary artifact authority boundary');
  }
  assertContains('skills/woostack-build/SKILL.md',
    /(?:artifacts?|records?)[\s\S]{0,120}(?:never|do not)[\s\S]{0,80}(?:grant|authorize|assign)[\s\S]{0,40}(?:permission|authority)/i,
    'Build must preserve the artifact permission boundary');
  assertContains('site/content/docs/concepts.mdx',
    /Linear is required[\s\S]{0,100}but never\s+replaces direct repository delivery evidence/i,
    'concepts must preserve repository delivery authority');
  assertContains('skills/using-woostack/SKILL.md',
    /responsible user[\s\S]{0,300}approval\s+events/i,
    'using-woostack must require responsible-user approval events');
  assertContains('skills/using-woostack/SKILL.md',
    /(?:matching workflow gate|exact (?:content|project|issue) (?:revision|record)|project-spec(?:ification)? revision|execution-plan revision)/i,
    'using-woostack must bind approval authority to one exact content revision');

  assertContains('skills/woostack-init/references/artifact-backends.md',
    /responsible[-\s]user(?:'s)?[\s\S]{0,800}(?:approvalEventRef|approval\s+event|explicit approval comment|native approval\s+event)/i,
    'artifact contract must require the responsible user native approval event');
  assertContains('skills/woostack-init/references/artifact-backends.md',
    /(?:matching workflow gate|exact (?:content|project|issue) (?:revision|record)|project-spec(?:ification)? revision|execution-plan revision)/i,
    'artifact contract must bind approval authority to one exact content revision');

  assertContains('skills/woostack-fix/SKILL.md',
    /responsible user explicitly approves that Ask[\s\S]{0,180}projectSpecApprovalRecord/i,
    'Fix must bind project-spec approval to the responsible user');
  assertContains('skills/woostack-fix/SKILL.md',
    /responsible user explicitly approves that Ask[\s\S]{0,180}executionPlanApprovalRecord/i,
    'Fix must bind execution-plan approval to the responsible user');
  assertContains('skills/woostack-fix/SKILL.md',
    /exact canonical Linear project link[\s\S]{0,220}exact fingerprint/i,
    'Fix must bind project approval to the exact canonical project fingerprint');
  assertContains('skills/woostack-fix/SKILL.md',
    /exact relevant direct-issue links[\s\S]{0,220}complete independently read issue and dependency sets/i,
    'Fix must bind execution approval to the exact independently read plan set');
});

test('authored setup order keeps initialization and the external-engineer guide sequenced', () => {
  assertInOrder('README.md', [
    ['initialization', /\b2\.\s+Initialization\b/i],
    ['repository policy', /\b4\.\s+Repository Policy\b/i],
    ['external engineer context', /\b5\.\s+Linear Product Context and External Engineers\b/i],
  ]);
  const sectionFiveTocLine = read('README.md')
    .split('\n')
    .find((line) => line.includes('](#5-linear-product-context-and-external-engineers)'));
  assert.match(sectionFiveTocLine ?? '', /^ {2}- /,
    'README.md: section 5 must remain nested under Getting Started');
  assertInOrder('site/content/docs/getting-started.mdx', [
    ['initialize local support', /\b2\.\s+Initialize local support\b/i],
    ['choose workflow', /\b3\.\s+Choose the workflow\b/i],
    ['automatic Linear defaults', /\b4\.\s+Automatic Linear default setup\b/i],
    ['external engineer', /5\. Use an external engineer \(optional\)/i],
  ]);
});

test('Hermes is one external engineer over one persistent OMP process', () => {
  const guide = read('site/content/docs/hermes.mdx').replace(/\s+/g, ' ');
  for (const pattern of [
    /external engineer/i,
    /not a supported woostack host or installed woostack runtime/i,
    /(?:install woostack only|woostack is installed only) in OMP or another supported coding harness/i,
    /one persistent OMP process/i,
    /process.*PTY|PTY.*process/i,
    /arguments? (?:are|as) values, not shell source/i,
    /in-contract decisions?/i,
    /responsible user/i,
    /escalat/i,
    /verbatim and unmodified/i,
    /same persistent OMP process/i,
    /matching Linear receipt/i,
    /evidence/i,
    /redispatch/i,
    /restarted or different OMP process/i,
    /copied response.*summarized response.*replayed transcript/i,
    /legacy.*launch-omp|launch-omp.*legacy/i,
    /bind-engineer-unit/i,
    /omp --profile <profile> --cwd <worktree> <prompt>/i,
    /(?:-p|--print).*non-interactive mode.*exit after one response/i,
    /retain the interactive process handle/i,
  ]) {
    assert.match(guide, pattern, `Hermes guide missing ${pattern}`);
  }
  assert.doesNotMatch(guide, /Hermes (?:codes?|implements?|edits?|commits?|pushes?)/i);
  assert.doesNotMatch(guide, /omp --profile <profile>\s+-p\b/i);
});

test('canonical host routing excludes retired Hermes and includes OMP', () => {
  const links = [...read('skills/using-woostack/references/hosts/README.md')
    .matchAll(/^- \[`([^`]+)`\]\(([^/)]+)\.md\)$/gm)]
    .filter(([, slug, target]) => slug === target)
    .map(([, slug]) => slug)
    .sort();
  assert.deepEqual(links, ['antigravity', 'claude-code', 'codex', 'cursor', 'omp', 'opencode']);
  assert.ok(links.includes('omp'), 'OMP must remain dispatchable');
  assert.ok(!links.includes('hermes'), 'retired Hermes adapter must not be dispatchable');
  assert.match(read('skills/using-woostack/references/model-tiers.md'),
    /supported coding-host allowlist.*hosts\/README\.md/is,
    'model-tier routing must obey the canonical host gate');
});

test('supported navigation keeps Hermes out of coding harnesses', () => {
  assert.match(read('site/content/docs/meta.json'), /"hermes"/i);
  assert.doesNotMatch(read('site/content/docs/harnesses/meta.json'), /"hermes"/i);
  assert.doesNotMatch(read('site/content/docs/concepts/meta.json'), /"engineer-agents"/i);
  for (const relativePath of authoredSitePaths) {
    const content = read(relativePath);
    assert.doesNotMatch(content,
      /\/docs\/harnesses\/hermes|\/docs\/concepts\/engineer-agents|references\/hosts\/hermes\.md|references\/engineer-agents\.md/i,
      `${relativePath}: supported authored page reaches a retired path or route`);
  }
  const sourceRegistry = read('site/lib/source.ts');
  assert.doesNotMatch(sourceRegistry,
    /retiredPagePaths|concepts\/engineer-agents\.mdx|harnesses\/hermes\.mdx|files\.filter\(/,
    'docs source must not retain the retired-page registry, paths, or filter');
  assert.match(sourceRegistry, /source:\s*docs\.toFumadocsSource\(\)/,
    'docs loader must consume the generated docs source directly');
  assert.match(read('site/content/docs/harnesses/omp.mdx'), /three neutral project workers/i);
  assert.match(read('skills/using-woostack/references/hosts/omp.md'), /agent:\s+woostack-fast/i);
  assert.match(read('skills/woostack-review/SKILL.md'), /fresh read-only profiles\/sessions/i);
  assert.match(read('skills/woostack-review/prompts/_orchestrator-header.md'),
    /fresh read-only reviewer session/i);
});

test('approval relay remains responsible-user and receipt bound', () => {
  const contract = read('skills/woostack-init/references/artifact-backends.md').replace(/\s+/g, ' ');
  assert.match(contract, /responsible user's response must travel verbatim, without summarization/i);
  assert.match(contract, /same persistent OMP process/i);
  assert.match(contract, /Hermes may transmit.*may not author or transform/i);
  assert.match(contract, /restarted or different process.*fails closed/i);
  assert.match(contract, /fresh Ask and active-conversation approval/i);
  assert.match(contract, /matching active-conversation approval/i);
  assert.match(contract, /Linear receipt\/event/i);
});

test('retired WOO-167 assets are absent and the WOO-166 Review mode is absent', async () => {
  assert.equal(WOO_167_RETIRED_FILES.length, 6, 'WOO-167 whole-file inventory must stay exact');
  for (const relativePath of WOO_167_RETIRED_FILES) {
    await assert.rejects(
      lstat(path.join(REPO_ROOT, relativePath)),
      (error) => error?.code === 'ENOENT',
      `${relativePath}: retired WOO-167 asset still exists`
    );
  }

  assert.equal(WOO_166_REVIEW_PATHS.length, 12, 'WOO-166 focused path inventory must stay exact');
  for (const relativePath of WOO_166_REVIEW_PATHS) {
    const content = read(relativePath);
    for (const marker of REVIEW_MODE_MARKERS) {
      assert.ok(!content.includes(marker), `${relativePath}: removed Review marker remains: ${marker}`);
    }
    assert.doesNotMatch(content, /engineer-unit|local\/Hermes|Hermes-direct|\bHermes\b/i,
      `${relativePath}: removed Hermes-direct Review wording remains`);
  }

  const supportedPaths = [...new Set([...PATHS, ...authoredSitePaths])];
  const retiredReference =
    /engineer-agents\.md|hosts\/hermes\.md|(?:test-)?gen-omp-agents\.sh|(?:concepts\/engineer-agents|harnesses\/hermes)\.mdx|\/docs\/(?:concepts\/engineer-agents|harnesses\/hermes)/i;
  for (const relativePath of supportedPaths) {
    const content = read(relativePath);
    assert.doesNotMatch(content, retiredReference,
      `${relativePath}: supported surface reaches a WOO-167 file or old route`);
    for (const marker of REVIEW_MODE_MARKERS) {
      assert.ok(!content.includes(marker),
        `${relativePath}: supported surface activates removed Review marker ${marker}`);
    }
    if (relativePath !== 'site/content/docs/hermes.mdx') {
      assert.doesNotMatch(content, /\b(?:launch-omp|bind-engineer-unit)\b/,
        `${relativePath}: supported surface reaches a reserved launcher`);
    }
  }
});
