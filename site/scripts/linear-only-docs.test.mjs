import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import path from 'node:path';
import { before, test } from 'node:test';

const REPO_ROOT = path.resolve(import.meta.dirname, '..', '..');
const UNIT_SCHEMA =
  '{schemaVersion:1,engineerName,repository,omp:{profile,program,environment},hermes:{profile,program,environment}}';
const NEGATION = /\b(?:no|not|never|without|cannot|can't|does not|do not|must not|regardless)\b/i;
const HERMES_CODER_NEGATION_PREFIX =
  /\b(?:no|not|never|without|cannot|can't|does not|do not|must not)\b(?:\s+\w+){0,2}\s*$/i;
const HERMES_CODER_CLAIM =
  /\bHermes\s+(?:codes?|implements?|edits?|writes?|modifies?|runs\s+(?:implementation|tests?)|commits?|pushes?|opens?\s+(?:an?\s+)?implementation\s+PR)\b|\bHermes\s+(?:is|acts\s+as|serves\s+as)\s+(?:an?\s+|the\s+)?(?:coder|coding\s+(?:agent|profile|worker)|implementation\s+(?:agent|profile|worker))\b|\b(?:ask|use|dispatch)\s+Hermes\s+to\s+(?:code|implement|edit|test|commit|push)\b/gi;
const PATHS = [
  'README.md',
  'AGENTS.md',
  'skills/using-woostack/SKILL.md',
  'skills/using-woostack/references/hosts/hermes.md',
  'skills/woostack-init/references/artifact-backends.md',
  'skills/woostack-build/SKILL.md',
  'skills/woostack-build/references/linear-context.md',
  'skills/woostack-build/references/linear-procedure.md',
  'skills/woostack-plan/SKILL.md',
  'skills/woostack-fix/SKILL.md',
  'skills/woostack-change/SKILL.md',
  'site/content/docs/index.mdx',
  'site/content/docs/getting-started.mdx',
  'site/content/docs/configuration.mdx',
  'site/content/docs/concepts.mdx',
  'site/content/docs/concepts/building-rules.mdx',
  'site/content/docs/concepts/workflows.mdx',
  'site/content/docs/concepts/index.mdx',
  'site/content/docs/concepts/engineer-agents.mdx',
  'site/content/docs/harnesses/hermes.mdx',
  'site/content/docs/harnesses/omp.mdx',
  'skills/using-woostack/references/hosts/omp.md',
  'site/content/docs/harnesses/index.mdx',
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

function hasPositiveHermesCoderClaim(clause) {
  HERMES_CODER_CLAIM.lastIndex = 0;
  for (const match of clause.matchAll(HERMES_CODER_CLAIM)) {
    const prefix = clause.slice(0, match.index);
    const localPrefix = prefix.replace(
      /^.*(?:\b(?:and|but|while|whereas|although)\b|[;.!?])/is,
      ''
    );
    if (!HERMES_CODER_NEGATION_PREFIX.test(localPrefix)) return true;
  }
  return false;
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

function fencedBlocks(value) {
  return [...value.matchAll(/```[^\n]*\n([\s\S]*?)```/g)].map((match) => match[1]);
}

test('Linear access distinguishes the proved fix issue exception from build/plan selection', () => {
  for (const relativePath of [
    'AGENTS.md',
    'README.md',
    'skills/using-woostack/SKILL.md',
    'skills/woostack-init/references/artifact-backends.md',
    'skills/woostack-build/SKILL.md',
    'skills/woostack-plan/SKILL.md',
    'site/content/docs/getting-started.mdx',
    'site/content/docs/concepts.mdx',
    'site/content/docs/concepts/building-rules.mdx',
  ]) {
    const claim = semanticClauses(read(relativePath)).find(
      (clause) =>
        /explicit(?:ly)? (?:asks?|requests?|request).*persist|explicit persistence request/i.test(clause) &&
        /select|persist|provider|Linear|artifact mode/i.test(clause) &&
        !NEGATION.test(clause)
    );
    assert.ok(claim, `${relativePath}: build/plan explicit-selection claim missing`);
  }
  const fix = read('skills/woostack-fix/SKILL.md').replace(/\s+/g, ' ');
  assert.match(fix, /Before root-cause proof.*no provider read or write/i);
  assert.match(fix, /without `--issue`.*create exactly one native work-item issue/i);
  assert.match(fix, /no `--project` path/i);
});
test('new fix provider boundary and driver selection are explicit', () => {
  for (const relativePath of [
    'README.md',
    'site/content/docs/index.mdx',
    'skills/using-woostack/references/hosts/omp.md',
    'site/content/docs/harnesses/index.mdx',
  ]) {
    const text = read(relativePath).replace(/\s+/g, ' ');
    assert.match(text, /Linear remains optional for non-fix workflows and for fix diagnosis before root-cause proof/i,
      `${relativePath}: must qualify provider optionality`);
    assert.match(text, /proved new fix requires the configured official MCP issue path before implementation/i,
      `${relativePath}: must require official issue path after proof`);
  }
  const fix = read('skills/woostack-fix/SKILL.md').replace(/\s+/g, ' ');
  assert.match(fix, /`--inline` and `--subagent` select only the read-only debug driver and are mutually exclusive/i);
  assert.match(fix, /Use a subagent when available by default/i);
  assert.match(fix, /explicitly requested subagent is unavailable.*disclose the degradation.*run inline only when safe/i);
  assert.doesNotMatch(fix, /No driver flag uses inline read-only diagnosis/i);
  assert.doesNotMatch(fix, /blocks diagnosis when it is unavailable/i);
});
test('authored public surfaces keep optional selection boundary and narrow new-fix exception', () => {
  const surfaces = new Map([
    [
      'README.md',
      {
        selection: /Build\/standalone-plan projects require exact selection or explicit persistence/i,
        fix: /proved new fix prompt binds or creates one issue after root-cause proof/i,
      },
    ],
    [
      'site/content/docs/getting-started.mdx',
      {
        selection: /Build and plan persistence require explicit selection/i,
        fix: /proved fix prompt binds or creates one issue after proof/i,
      },
    ],
    [
      'site/content/docs/index.mdx',
      {
        selection: /caller-selected build\/standalone-plan persistence/i,
        fix: /proved new fix prompt binds or creates one compatible issue after root-cause proof/i,
      },
    ],
    [
      'site/content/docs/configuration.mdx',
      {
        selection: /exact build\/plan artifacts or explicitly requested build\/plan persistence/i,
        fix: /proved `\/woostack-fix` that creates one issue without an exact issue/i,
      },
    ],
  ]);

  for (const [relativePath, { selection, fix }] of surfaces) {
    const text = read(relativePath).replace(/\s+/g, ' ');
    assert.match(text, selection, `${relativePath}: build/plan selection boundary is missing`);
    assert.match(text, fix, `${relativePath}: proved new-fix issue exception is missing`);
    assert.doesNotMatch(
      text,
      /Linear records plans only for an exact caller-selected artifact or explicit persistence request|Without an exact artifact or explicit persistence request, commands make no Linear call/i,
      `${relativePath}: stale universal no-call claim remains`
    );
    assert.doesNotMatch(
      text,
      /(?:linear object|defaults).{0,80}(?:only after artifact selection|only after the caller supplies an exact resource)/i,
      `${relativePath}: stale default-selection-only claim remains`
    );
  }
});

test('build and standalone-plan persistence keeps one hierarchy while new fixes keep one issue', () => {
  for (const relativePath of [
    'README.md',
    'AGENTS.md',
    'skills/using-woostack/SKILL.md',
    'skills/woostack-init/references/artifact-backends.md',
    'skills/woostack-build/references/linear-procedure.md',
    'skills/woostack-plan/SKILL.md',
    'site/content/docs/getting-started.mdx',
    'site/content/docs/concepts/building-rules.mdx',
  ]) {
    const text = read(relativePath).replace(/\s+/g, ' ');
    assert.match(text, /one(?: exact Linear)? project/i, `${relativePath}: must state one project`);
    assert.match(text, /one parent plan issue/i, `${relativePath}: must state one parent plan issue`);
    assert.match(text, /one (?:native )?child issue.{0,80}(?:per|for every) increment/i,
      `${relativePath}: must state one child issue per increment`);
  }
  const fix = read('skills/woostack-fix/SKILL.md').replace(/\s+/g, ' ');
  assert.match(fix, /bind exactly one issue/i);
  assert.doesNotMatch(fix, /fix plan is persisted as one project/i);
  assert.doesNotMatch(fix, /one project.*parent plan issue.*child increment/i);
});

test('selected Linear capability is proved without reading repository credentials', () => {
  for (const relativePath of [
    'skills/woostack-init/references/artifact-backends.md',
    'skills/woostack-build/SKILL.md',
    'skills/woostack-fix/SKILL.md',
    'site/content/docs/configuration.mdx',
    'site/content/docs/getting-started.mdx',
  ]) {
    const content = read(relativePath);
    assert.match(content, /API key|OAuth credential|credentials/i,
      `${relativePath}: must identify host-owned credentials`);
    assert.match(content, /(?:never|without)\s+(?:inspect(?:ing)?|read(?:ing)?|expos(?:e|ing)|print(?:ing)?|copy(?:ing)?|place|store)|without reading the secret/i,
      `${relativePath}: must not read or expose credentials`);
  }
});

test('selected persistence fails safely and every mutation is read back', () => {
  const contract = read('skills/woostack-init/references/artifact-backends.md').replace(/\s+/g, ' ');
  assert.match(contract, /Missing required capability blocks the selected operation/i);
  assert.match(contract, /fix requires complete fix-plan content, relation, and approval-event read-back before dispatch/i);
  assert.match(contract, /perform a new independent complete read/i);

  const procedure = read('skills/woostack-build/references/linear-procedure.md').replace(/\s+/g, ' ');
  assert.match(procedure, /verify every issue, parent-child link, and dependency relation through independent complete read-back/i);
});

test('abandonment closes only project-backed workflows and preserves new fix issues', () => {
  for (const relativePath of [
    'README.md',
    'AGENTS.md',
    'skills/using-woostack/SKILL.md',
    'skills/woostack-init/references/artifact-backends.md',
    'skills/woostack-build/SKILL.md',
    'skills/woostack-build/references/linear-context.md',
    'site/content/docs/configuration.mdx',
    'site/content/docs/concepts.mdx',
    'site/content/docs/concepts/building-rules.mdx',
    'site/content/docs/concepts/workflows.mdx',
  ]) {
    const content = read(relativePath).replace(/\s+/g, ' ');
    assert.match(content, /explicit(?:ly)?(?:\s+\S+){0,3}\s+abandon/i,
      `${relativePath}: must cover explicit abandonment`);
    assert.match(content,
      /(?:abandon.{0,500}(?:(?:existing|persisted|exact|project exists|project-backed).{0,200}project.{0,250}(?:cancel|canceled|close)|project-backed.{0,250}(?:cancel|canceled|close))|(?:cancel|canceled|close).{0,250}(?:existing|persisted|exact|project-backed).{0,200}project.{0,250}abandon)/i,
      `${relativePath}: project-backed abandonment must close an existing project`);
    assert.match(content,
      /(?:abandon.{0,2000}(?:independent(?:ly)?.{0,50}read(?:-back| back)|read-back|status\/read-back|reads?.{0,60}(?:closure|transition|status).{0,30}back)|(?:independent(?:ly)?.{0,50}read(?:-back| back)|read-back|status\/read-back|reads?.{0,60}(?:closure|transition|status).{0,30}back).{0,1200}abandon)/i);
    assert.match(content,
      /(?:handoff|hand off).{0,140}(?:replan|replanning).{0,140}blocker.{0,220}(?:not abandonment|do not close|leave.{0,60}open|unchanged|do not)/i,
      `${relativePath}: non-abandonment outcomes must leave the project open`);
  }
  const fix = read('skills/woostack-fix/SKILL.md').replace(/\s+/g, ' ');
  assert.match(fix, /preserve the exact bound or created issue.{0,160}do not create or close a project for a fix/i);
  assert.match(fix, /verified abandonment note|append only.*verified.*note/i);
  assert.doesNotMatch(fix, /projectStatuses\.canceled/i);
  const contract = read('skills/woostack-init/references/artifact-backends.md').replace(/\s+/g, ' ');
  assert.match(contract, /projectStatuses\.canceled|configured canceled/i);
  assert.match(contract, /(?:do not|never)[^.]{0,160}create a project merely to cancel it/i);
  assert.match(contract, /update only that project's native status/i);
  assert.match(contract, /independently re-read the exact project/i);
  const procedure = read('skills/woostack-build/references/linear-procedure.md').replace(/\s+/g, ' ');
  assert.match(procedure, /neutral canonical artifact contract/i);
  assert.doesNotMatch(procedure, /update only that project's native status/i);
  assert.doesNotMatch(contract, /linear-procedure\.md/i);
});

test('explicit creation never fuzzy-matches an exact existing resource', () => {
  const contract = read('skills/woostack-init/references/artifact-backends.md').replace(/\s+/g, ' ');
  assert.match(contract, /exact caller-supplied resource always takes precedence over creation/i);
  assert.match(contract, /Never infer (?:an existing )?artifact from a title/i);

  const procedure = read('skills/woostack-build/references/linear-procedure.md').replace(/\s+/g, ' ');
  assert.match(procedure, /Never discover or reuse a project by title or recent activity/i);
  assert.match(procedure, /stable project mutation UUID/i);
});

test('woostack-change has no Linear command or synchronization surface', () => {
  const change = read('skills/woostack-change/SKILL.md');
  assert.match(change, /always\s+artifact-free and never reads or writes Linear/i);
  assert.doesNotMatch(change, /--issue|--project|artifact synchronization|Linear-Issue:/i);

  assertContains('skills/using-woostack/SKILL.md', /`\/woostack-change <goal>`[^\n]*artifact-free/i,
    'routing must keep change artifact-free');
  assertContains('site/content/docs/concepts/workflows.mdx', /Change[\s\S]{0,500}never reads or writes Linear/i,
    'workflow docs must keep change artifact-free');
});

test('only exact native fix approval authorizes repository work', () => {
  for (const relativePath of [
    'README.md',
    'AGENTS.md',
    'skills/woostack-build/SKILL.md',
    'site/content/docs/concepts.mdx',
  ]) {
    assertContains(relativePath, /(?:never\s+(?:grant|authorize)|do not assign permission|never\s+authorizes)/i,
      'must preserve the ordinary artifact authority boundary');
  }
  for (const relativePath of [
    'skills/using-woostack/SKILL.md',
    'skills/woostack-init/references/artifact-backends.md',
    'skills/woostack-fix/SKILL.md',
  ]) {
    assertContains(relativePath,
      /responsible[-\s]user(?:'s)?[\s\S]{0,240}(?:approvalEventRef|approval event|explicit approval comment|native approval event)/i,
      'must require the responsible user native approval event');
    assertContains(relativePath,
      /matching fix execution gate|matching fix issue revision|exact issue revision authorizes execution/i,
      'must bind approval authority to one exact fix revision');
  }
});

test('authored setup order keeps initialization, role isolation, binding, and dispatch sequenced', () => {
  assertInOrder('README.md', [
    ['initialization', /\b2\.\s+Initialization\b/i],
    ['repository policy', /\b4\.\s+Repository Policy\b/i],
    ['post-selection Linear setup', /\b5\.\s+Linear Artifact Context\b/i],
  ]);
  assertInOrder('site/content/docs/getting-started.mdx', [
    ['initialize local support', /\b2\.\s+Initialize local support\b/i],
    ['choose workflow', /\b3\.\s+Choose the workflow\b/i],
    ['automatic Linear defaults', /\b4\.\s+Automatic Linear default setup\b/i],
    ['configure engineer pair', /\b5\.\s+Optional:\s+configure a Hermes \+ OMP engineer pair\b/i],
  ]);
  assertInOrder('skills/using-woostack/references/hosts/hermes.md', [
    ['provision profiles', /\b1\.\s+provision distinct\b/i],
    ['configure selected MCP', /\b2\.\s+for caller-selected build\/standalone artifacts or a proved fix's required issue/i],
    ['split credentials', /\b3\.\s+split repository\/GitHub credentials\b/i],
    ['install launchers', /\b4\.\s+install and checksum-check\b/i],
    ['preflight fresh sessions', /\b5\.\s+start fresh sessions\b/i],
    ['bind after worktree', /\b6\.\s+only after the bounded task and canonical worktree exist\b/i],
  ]);
});

test('authored engineer pages keep one canonical bound-unit manifest and link to it', () => {
  const canonicalPath = 'skills/using-woostack/references/hosts/hermes.md';
  const owners = [];
  let occurrenceCount = 0;

  for (const relativePath of [canonicalPath, ...authoredSitePaths]) {
    const count = read(relativePath).split(UNIT_SCHEMA).length - 1;
    occurrenceCount += count;
    if (count > 0) owners.push(relativePath);
  }

  assert.equal(occurrenceCount, 1, 'installed contract and authored MDX must contain UNIT_SCHEMA once');
  assert.deepEqual(owners, [canonicalPath], 'Hermes host reference must own the only UNIT_SCHEMA');

  const canonical = read(canonicalPath);
  assert.match(canonical, /^### Bound-unit manifest and binding$/m,
    `${canonicalPath}: must own the canonical heading and generated anchor`);
  assert.match(canonical, /(?:\bunit\.json\b.{0,50}\b0600\b|\b0600\b.{0,50}\bunit\.json\b)/is,
    `${canonicalPath}: must stage unit.json with mode 0600`);
  assert.match(canonical, /\bbind-engineer-unit\b/i,
    `${canonicalPath}: must use the reviewed static binder`);
  assert.match(canonical, /(?:\bunit-authority\.json\b.{0,60}\b0400\b|\b0400\b.{0,60}\bunit-authority\.json\b)/is,
    `${canonicalPath}: must verify mode-0400 adjacent authority`);
  assertInOrder(canonicalPath, [
    ['canonical worktree', /\bcanonical\b.{0,50}\bworktree\b/is],
    ['unit manifest', /\bunit\.json\b/i],
    ['static binder', /\bbind-engineer-unit\b/i],
    ['bound authority', /\bunit-authority\.json\b/i],
    ['dispatch', /\bdispatch\b/i],
  ]);

  for (const relativePath of [
    'site/content/docs/getting-started.mdx',
    'site/content/docs/harnesses/hermes.mdx',
    'site/content/docs/harnesses/omp.mdx',
  ]) {
    assert.match(
      read(relativePath),
      /https:\/\/github\.com\/howarewoo\/woostack\/blob\/main\/skills\/using-woostack\/references\/hosts\/hermes\.md#bound-unit-manifest-and-binding/,
      `${relativePath}: must link to the installed canonical bound-unit contract`
    );
  }
});

test('authored engineer guidance preserves role isolation and forbids self-review', () => {
  for (const relativePath of [
    'site/content/docs/getting-started.mdx',
    'site/content/docs/concepts.mdx',
    'site/content/docs/concepts/engineer-agents.mdx',
    'site/content/docs/harnesses/hermes.mdx',
    'site/content/docs/harnesses/omp.mdx',
  ]) {
    const claim = semanticClauses(read(relativePath)).find(hasPositiveHermesCoderClaim);
    assert.equal(claim, undefined, `${relativePath}: Hermes must not be described as the coder`);
  }

  assert.equal(
    hasPositiveHermesCoderClaim('Hermes implements code and never merges.'),
    true,
    'an unrelated trailing negation must not mask a positive Hermes coder claim'
  );
  assert.equal(
    hasPositiveHermesCoderClaim('The workflow never merges and Hermes implements code.'),
    true,
    'an unrelated leading conjunct must not mask a positive Hermes coder claim'
  );
  assert.equal(
    hasPositiveHermesCoderClaim('Never ask Hermes to implement code.'),
    false,
    'negation scoped to the Hermes coding predicate must remain valid guidance'
  );
  assert.equal(
    hasPositiveHermesCoderClaim('Hermes does not implement code.'),
    false,
    'negation within the Hermes coding predicate must remain valid guidance'
  );

  assert.match(
    read('site/content/docs/harnesses/hermes.mdx'),
    /Do not ask OMP to review its own work/i,
    'Hermes decision-maker prompt must forbid OMP self-review'
  );
});

test('Hermes page contains the complete decision-maker handoff', () => {
  const relativePath = 'site/content/docs/harnesses/hermes.mdx';
  const prompt = fencedBlocks(read(relativePath)).find(
    (block) => /decision-making engineer/i.test(block) && /\bENGINEER_NAME\b/.test(block)
  );
  assert.ok(prompt, `${relativePath}: missing copyable decision-maker prompt`);
  for (const placeholder of [
    'ENGINEER_NAME',
    'HERMES_PROFILE',
    'OMP_PROFILE',
    'REPOSITORY_PATH',
    'TASK_CONTRACT',
  ]) {
    assert.match(prompt, new RegExp(`\\b${placeholder}\\b`), `${relativePath}: missing ${placeholder}`);
  }
  for (let step = 1; step <= 16; step += 1) {
    assert.match(prompt, new RegExp(`(?:^|\\n)${step}\\.`), `${relativePath}: missing step ${step}`);
  }
  assert.match(prompt, /implementation and verification only/i);
  assert.match(prompt, /complete uncommitted diff/i);
  assert.match(prompt, /task-specification review/i);
  assert.match(prompt, /independent quality review/i);
  assert.match(prompt, /same OMP profile for exactly one bounded \/woostack-commit action/i);
  assert.match(prompt, /Independently read the submitted PR, head, base, and complete diff/i);
  assert.match(prompt, /Post your own GitHub review comments or verdict/i);
  assert.match(prompt, /Never merge/i);
});
