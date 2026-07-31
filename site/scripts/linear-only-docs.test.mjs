import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { before, test } from 'node:test';

const REPO_ROOT = path.resolve(import.meta.dirname, '..', '..');
const MCP_ENDPOINT = 'https://mcp.linear.app/mcp';
const EXACT_OMP_COMMAND = 'omp --profile <engineer> -p --cwd <repo> <prompt>';
const IMPLEMENTER_PROMPT = 'skills/woostack-execute/prompts/implementer.md';
const SUBAGENT_DRIVER = 'skills/woostack-execute/references/subagent-driver.md';
const LAUNCHER_ROOT = '${WOO_ENGINEER_LAUNCHER_ROOT:-$HOME/.local/libexec/woostack}/<ENGINEER_NAME>';
const UNIT_SCHEMA =
  '{schemaVersion:1,engineerName,repository,omp:{profile,program,environment},hermes:{profile,program,environment}}';
const SUPPORTING_CONTRACT_PATHS = [
  'skills/woostack-init/references/memory.md',
  'site/content/docs/concepts/meta.json',
  'site/content/docs/harnesses/meta.json',
];

// This is intentionally an allowlist. Generated site/content/docs/skills/* pages are derived from
// SKILL.md and must not become a second authored documentation surface.
const AUTHORED_DOC_PATHS = [
  'README.md',
  'AGENTS.md',
  'site/content/docs/index.mdx',
  'site/content/docs/getting-started.mdx',
  'site/content/docs/configuration.mdx',
  'site/content/docs/concepts.mdx',
  'site/content/docs/concepts/index.mdx',
  'site/content/docs/concepts/building-rules.mdx',
  'site/content/docs/concepts/status-tracking.mdx',
  'site/content/docs/concepts/workflows.mdx',
  'site/content/docs/concepts/worktrees.mdx',
  'site/content/docs/concepts/context-management.mdx',
  'site/content/docs/concepts/memory.mdx',
  'site/content/docs/concepts/utilities.mdx',
  'site/content/docs/concepts/engineer-agents.mdx',
  'site/content/docs/harnesses/index.mdx',
  'site/content/docs/harnesses/omp.mdx',
  'site/content/docs/harnesses/hermes.mdx',
  'skills/using-woostack/references/hosts/hermes.md',
];

const FORBIDDEN_POSITIONING = [
  {
    label: 'Markdown positioned as the default development-record store',
    pattern:
      /\b(?:local\s+)?Markdown\s*(?:\(\s*default\s*\)|(?:is|remains|stays|as)\s+(?!not\b|no longer\b)(?:the\s+)?default\b)|\bdefaults?\s+to\s+(?:local\s+)?Markdown\b/i,
  },
  {
    label: 'Linear positioned as optional or an alternative',
    pattern:
      /\bLinear\s+(?:is|remains|stays)\s+(?!not\b)(?:an?\s+)?(?:optional|alternative|opt[- ]?in)\b|(?<!not\s)\b(?:optional|alternative|opt[- ]?in)\s+Linear\b/i,
  },
  {
    label: 'the retired artifacts.specPlan selector',
    pattern: /\bartifacts\.specPlan\b/i,
  },
  {
    label: 'the retired Linear specification document',
    pattern: /\b(?:Linear\s+)?spec(?:ification)?\s+documents?\b/i,
  },
];

const HERMES_CODER_CLAIM =
  /\bHermes\s+(?:codes?|implements?|edits?|writes?|modifies?|runs\s+(?:implementation|tests?)|commits?|pushes?|opens?\s+(?:an?\s+)?implementation\s+PR)\b|\bHermes\s+(?:is|acts\s+as|serves\s+as)\s+(?:an?\s+|the\s+)?(?:coder|coding\s+(?:agent|profile|worker)|implementation\s+(?:agent|profile|worker))\b|\b(?:ask|use|dispatch)\s+Hermes\s+to\s+(?:code|implement|edit|test|commit|push)\b/i;

const NEGATION =
  /\b(?:no|not|never|neither|without|cannot|can't|does\s+not|do\s+not|must\s+not|may\s+not|non-authoritative|prohibited|forbidden|unsupported)\b/i;
const LOCAL_DEVELOPMENT_RECORD =
  /\.woostack\/(?:specs?|plans?|fix(?:es)?|overnight)\b|\blocal\s+(?:Markdown\s+)?(?:specifications?|specs?|plans?|fix(?:es)?|overnight(?:\s+(?:reports?|records?))?)\b/i;
const LOCAL_OVERNIGHT_REPORT =
  /\.woostack\/overnight(?:\/|\b)|\b(?:local\s+)?(?:morning|overnight)\s+reports?\b/i;
const LOCAL_REPORT_PRODUCTION =
  /\b(?:write|writes|writing|create|creates|creating|author|authors|authoring|save|saves|saving|store|stores|storing|persist|persists|persisting|produce|produces|producing|emit|emits|emitting|leave|leaves|leaving)\b/i;
const AUTHORITY_CLAIM =
  /\b(?:source[- ]of[- ]truth|canonical|authoritative|development[- ]record\s+authority|official\s+(?:development\s+)?record|tracks?\s+(?:feature|development|project)\s+(?:work|progress|state))\b/i;
const BACKEND_CHOICE_LANGUAGE =
  /\bartifact\s+backend\b|\bbackend\s+(?:choice|selection|selector|option|mode|configuration|mapping|contract|model)\b|\b(?:choose|select|switch|migrate)\b[^.\n]{0,80}\bbackend\b|\b(?:Markdown|Linear)\s+(?:backend|mode)\b|\b(?:two|both|either)\s+(?:artifact\s+)?(?:backends|stores|models)\b|\bMarkdown\s+(?:vs\.?|or)\s+Linear\b|\bLinear\s+(?:vs\.?|or)\s+Markdown\b/i;
const GRAPHQL_TRANSPORT = /\bGraphQL\b/i;
const TRANSPORT_CLAIM = /\b(?:adapter|client|transport|integration|API|query|mutation)\b/i;

let docs;

before(async () => {
  docs = new Map();

  for (const relativePath of [...AUTHORED_DOC_PATHS, ...SUPPORTING_CONTRACT_PATHS]) {
    try {
      docs.set(relativePath, await readFile(path.join(REPO_ROOT, relativePath), 'utf8'));
    } catch (error) {
      assert.fail(
        `${relativePath}: required authored document is missing or unreadable (${error.message})`
      );
    }
  }
});

function text(relativePath) {
  const value = docs.get(relativePath);
  assert.notEqual(value, undefined, `${relativePath}: document was not loaded by the authored-doc allowlist`);
  return value;
}

function normalize(value) {
  return value
    .replace(/\[([^\]]+)]\(([^)]+)\)/g, '$1 $2')
    .replace(/<[^>]+>/g, ' ')
    .replace(/[`*_>#|]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function excerpt(value) {
  const compact = normalize(value);
  return compact.length <= 180 ? compact : `${compact.slice(0, 177)}...`;
}

function matches(pattern, value) {
  pattern.lastIndex = 0;
  return pattern.test(value);
}

function semanticSegments(value) {
  const tableRows = value
    .split('\n')
    .filter((line) => /^\s*\|/.test(line))
    .map(normalize)
    .filter(Boolean);
  const sentences = value
    .split(/\n\s*\n+/)
    .flatMap((paragraph) => normalize(paragraph).split(/(?<=[.!?])\s+/))
    .filter(Boolean);
  return [...new Set([...tableRows, ...sentences])];
}

function semanticClauses(value) {
  return semanticSegments(value)
    .flatMap((segment) => segment.split(/\s*(?:;|,\s+(?:but|yet|however)\b)\s*/i))
    .map((clause) => clause.trim())
    .filter(Boolean);
}

function requirementsDescription(requirements) {
  return requirements.map(({ label }) => label).join(', ');
}

function assertSemanticParagraph(relativePaths, label, requirements) {
  for (const relativePath of relativePaths) {
    const paragraphs = text(relativePath).split(/\n\s*\n+/).map(normalize).filter(Boolean);
    const match = paragraphs.find((paragraph) =>
      requirements.every(({ pattern }) => matches(pattern, paragraph))
    );
    if (match) return { relativePath, match };
  }

  assert.fail(
    `${relativePaths.join(', ')}: ${label}; expected one coherent paragraph containing ${requirementsDescription(requirements)}`
  );
}

function assertNoUnnegatedClaim(relativePath, label, subject, predicate) {
  const claim = semanticClauses(text(relativePath)).find(
    (segment) =>
      matches(subject, segment) && matches(predicate, segment) && !matches(NEGATION, segment)
  );

  assert.equal(claim, undefined, `${relativePath}: ${label}; found “${excerpt(claim ?? '')}”`);
}

function assertTextInOrder(value, sourceLabel, steps) {
  const normalized = normalize(value);
  let cursor = 0;
  let previous = 'the start of the text';

  for (const { label, pattern } of steps) {
    pattern.lastIndex = 0;
    const match = pattern.exec(normalized.slice(cursor));
    assert.ok(
      match,
      `${sourceLabel}: required sequence must place “${label}” after ${previous}`
    );
    cursor += match.index + match[0].length;
    previous = `“${label}”`;
  }
}

function assertInOrder(relativePath, steps) {
  assertTextInOrder(text(relativePath), relativePath, steps);
}

function normalizedSpan(relativePath, label, startPattern, endPattern) {
  const page = normalize(text(relativePath));
  startPattern.lastIndex = 0;
  const start = startPattern.exec(page);
  assert.ok(start, `${relativePath}: missing start of ${label}`);
  const offset = start.index + start[0].length;
  endPattern.lastIndex = 0;
  const end = endPattern.exec(page.slice(offset));
  assert.ok(end, `${relativePath}: missing end of ${label}`);
  return page.slice(start.index, offset + end.index);
}

function fencedBlocks(value) {
  return [...value.matchAll(/```[^\n]*\n([\s\S]*?)```/g)].map((match) => match[1]);
}

function assertPromptClause(prompt, label, pattern) {
  assert.match(prompt, pattern, `site/content/docs/harnesses/hermes.mdx: prompt must ${label}`);
}

test('scan is limited to the authored Linear-only documentation surface', () => {
  assert.equal(new Set(AUTHORED_DOC_PATHS).size, AUTHORED_DOC_PATHS.length);
  assert.ok(
    AUTHORED_DOC_PATHS.every((relativePath) => !relativePath.startsWith('site/content/docs/skills/')),
    'generated per-skill pages must not be scanned as authored pages'
  );
  assert.ok(AUTHORED_DOC_PATHS.includes('site/content/docs/harnesses/hermes.mdx'));
  assert.ok(AUTHORED_DOC_PATHS.includes('site/content/docs/concepts/engineer-agents.mdx'));
  assert.ok(SUPPORTING_CONTRACT_PATHS.includes('skills/woostack-init/references/memory.md'));
  assert.ok(SUPPORTING_CONTRACT_PATHS.includes('site/content/docs/concepts/meta.json'));
  assert.ok(SUPPORTING_CONTRACT_PATHS.includes('site/content/docs/harnesses/meta.json'));
});

test('negative claims are scoped to their own clause', () => {
  const clauses = semanticClauses('Do not create a spec, but write a local overnight report.');
  assert.deepEqual(clauses, ['Do not create a spec', 'write a local overnight report.']);
  assert.ok(matches(NEGATION, clauses[0]));
  assert.equal(matches(NEGATION, clauses[1]), false);
  assert.ok(matches(LOCAL_OVERNIGHT_REPORT, clauses[1]));
  assert.ok(matches(LOCAL_REPORT_PRODUCTION, clauses[1]));
});

test('authored docs reject the retired dual-backend and Hermes-coder models', async (t) => {
  for (const relativePath of AUTHORED_DOC_PATHS) {
    await t.test(relativePath, () => {
      const page = text(relativePath);
      for (const { label, pattern } of FORBIDDEN_POSITIONING) {
        const match = page.match(pattern);
        assert.equal(
          match,
          null,
          `${relativePath}: remove ${label}; found “${excerpt(match?.[0] ?? '')}”`
        );
      }

      assertNoUnnegatedClaim(
        relativePath,
        'remove backend-choice positioning; Linear MCP is mandatory',
        BACKEND_CHOICE_LANGUAGE,
        /[\s\S]*/
      );
      assertNoUnnegatedClaim(
        relativePath,
        'remove Hermes implementation claims; Hermes is the decision-maker and reviewer',
        HERMES_CODER_CLAIM,
        /[\s\S]*/
      );
      assertNoUnnegatedClaim(
        relativePath,
        'local spec/plan/fix/overnight material cannot be development-record authority',
        LOCAL_DEVELOPMENT_RECORD,
        AUTHORITY_CLAIM
      );
      assertNoUnnegatedClaim(
        relativePath,
        'overnight execution renders a terminal handback and must not produce a local report',
        LOCAL_OVERNIGHT_REPORT,
        LOCAL_REPORT_PRODUCTION
      );
      assertNoUnnegatedClaim(
        relativePath,
        'remove Linear GraphQL adapter/client/transport claims; only official MCP is supported',
        GRAPHQL_TRANSPORT,
        TRANSPORT_CLAIM
      );
    });
  }
});

test('landing and setup docs position woostack for multiperson Linear project tracking', () => {
  for (const relativePath of ['README.md', 'site/content/docs/index.mdx']) {
    assertSemanticParagraph([relativePath], 'missing multiperson collaboration and project-tracking positioning', [
      {
        label: 'multiple people or engineers',
        pattern: /\bmulti[- ]?person\b|\bmultiple\s+(?:people|engineers|agents|contributors)\b|\bteam\b/i,
      },
      { label: 'collaboration', pattern: /\bcollaborat(?:e|es|ion|ive)\b/i },
      { label: 'projects', pattern: /\bprojects?\b/i },
      { label: 'tracking or coordination', pattern: /\btrack(?:s|ed|ing)?\b|\bcoordinat(?:e|es|ion)\b/i },
    ]);
  }

  for (const relativePath of [
    'site/content/docs/getting-started.mdx',
    'site/content/docs/configuration.mdx',
  ]) {
    assert.ok(
      text(relativePath).includes(MCP_ENDPOINT),
      `${relativePath}: name the mandatory official Linear MCP endpoint ${MCP_ENDPOINT}`
    );
  }

  assertSemanticParagraph(
    ['site/content/docs/getting-started.mdx', 'site/content/docs/configuration.mdx'],
    'the official Linear MCP endpoint must be mandatory, not an option',
    [
      { label: MCP_ENDPOINT, pattern: /https:\/\/mcp\.linear\.app\/mcp/i },
      { label: 'official Linear MCP', pattern: /\bofficial\b[\s\S]{0,80}\bLinear\s+MCP\b|\bLinear\s+MCP\b[\s\S]{0,80}\bofficial\b/i },
      { label: 'mandatory language', pattern: /\b(?:mandatory|required|must|only)\b/i },
    ]
  );
});

test('generic initialization requires only the current host MCP and defers the optional pair', () => {
  const initSection = normalizedSpan(
    'README.md',
    'generic initialization',
    /\b2\.\s+Initialization\b[\s\S]{0,80}\bAuthenticate\s+the\s+current\s+host\b/i,
    /\b3\.\s+Project\s+Integration\b[\s\S]{0,100}\bTo\s+ensure\s+coding\s+agents\b/i
  );
  assert.match(initSection, /\bcurrent\s+host\b[\s\S]{0,100}\bauthenticated\s+official\s+Linear\s+MCP\b/i);
  assert.match(
    initSection,
    /\bonly\s+host\s+setup\b[\s\S]{0,120}\bHermes\b[\s\S]{0,40}\bOMP\b[\s\S]{0,80}\bnot\s+prerequisites?\b/i
  );
  assertTextInOrder(text('README.md'), 'README.md', [
    { label: 'generic initialization', pattern: /\b2\.\s+Initialization\b/i },
    { label: 'repository policy', pattern: /\b4\.\s+Repository\s+Policy\b/i },
    {
      label: 'optional pair only after policy',
      pattern: /\bOnly\s+after\s+\/woostack-init\b[\s\S]{0,100}\brepository\s+policy\b[\s\S]{0,120}\boptional\b/i,
    },
  ]);
  assertSemanticParagraph(
    ['site/content/docs/getting-started.mdx'],
    'the Hermes + OMP adapter must be optional and follow generic initialization',
    [
      { label: 'generic init', pattern: /\bgeneric\b[\s\S]{0,40}\/woostack-init\b/i },
      { label: 'repository policy already established', pattern: /\bafter\b[\s\S]{0,80}\brepository\s+policy\b/i },
      { label: 'optional adapter', pattern: /\boptional\b/i },
      { label: 'not an init prerequisite', pattern: /\bnever\b[\s\S]{0,50}\bprerequisite\b/i },
    ]
  );
});

test('authored docs state the standalone and multi-issue Linear work models', () => {
  const modelPages = [
    'README.md',
    'site/content/docs/getting-started.mdx',
    'site/content/docs/concepts.mdx',
    'site/content/docs/concepts/building-rules.mdx',
    'site/content/docs/concepts/status-tracking.mdx',
    'site/content/docs/concepts/workflows.mdx',
  ];

  assertSemanticParagraph(modelPages, 'standalone work must bind exactly one Linear issue', [
    { label: 'standalone work', pattern: /\bstandalone\b/i },
    { label: 'one issue', pattern: /\b(?:one|single)\s+(?:(?:bound(?:ed)?|assigned)\s+)?(?:Linear\s+)?issue\b/i },
    { label: 'bound or assigned', pattern: /\bbound(?:ed)?\b|\bassigned\b/i },
    { label: 'Linear', pattern: /\bLinear\b/i },
  ]);

  assertSemanticParagraph(modelPages, 'multi-issue work must use one project, specification-bearing updates, and ordered increment issues', [
    { label: 'multi-issue work', pattern: /\bmulti[- ]?issue\b|\bmore\s+than\s+one\s+issue\b|\bseveral\s+issues\b/i },
    { label: 'one Linear project', pattern: /\b(?:one|single)\s+Linear\s+project\b/i },
    { label: 'specification-bearing project updates', pattern: /\bspecification[- ]bearing\s+project\s+updates\b|\bproject\s+updates\b[\s\S]{0,80}\bwritten\s+specification\b/i },
    { label: 'ordered increment issues', pattern: /\bordered\s+(?:implementation\s+|increment(?:al)?\s+)?issues?\b/i },
  ]);
});

test('issue binding preserves the approved bootstrap project-first scaffold exception', () => {
  for (const relativePath of ['README.md', 'site/content/docs/concepts.mdx']) {
    assertSemanticParagraph(
      [relativePath],
      'qualify universal issue binding with the bootstrap project-first scaffold exception',
      [
        { label: 'bootstrap', pattern: /\/woostack-bootstrap\b|\bbootstrap\b/i },
        { label: 'approved project-first scaffold', pattern: /\bapproved\b[\s\S]{0,80}\bproject-first\b[\s\S]{0,60}\bscaffold\b/i },
        { label: 'verified Linear project authority', pattern: /\bverified\s+Linear\s+project\b/i },
        { label: 'before increment issues', pattern: /\bbefore\b[\s\S]{0,80}\bincrement\s+issues\b/i },
        { label: 'later implementation issue-bound', pattern: /\b(?:every|all)\s+later\b[\s\S]{0,80}\bimplementation\b[\s\S]{0,100}\bissue[- ]bound\b|\bimplementation\b[\s\S]{0,100}\bbinds?\b[\s\S]{0,40}\bissue\b/i },
      ]
    );

    const universalClaims = text(relativePath)
      .split(/\n\s*\n+/)
      .map(normalize)
      .filter((paragraph) =>
        /\bEvery\s+(?:repository-changing|coding|implementation)\b[\s\S]{0,100}\bissue\b|\bNo\s+implementation\s+code\b[\s\S]{0,100}\bbound\s+Linear\s+issue\b/i.test(paragraph)
      );
    for (const paragraph of universalClaims) {
      assert.match(
        paragraph,
        /\bbootstrap\b[\s\S]{0,180}\b(?:exception|project-first|project-owned)\b|\b(?:exception|project-first|project-owned)\b[\s\S]{0,180}\bbootstrap\b/i,
        `${relativePath}: universal issue binding must carry the approved bootstrap scaffold exception; found “${excerpt(paragraph)}”`
      );
    }
  }
});

test('authored docs preserve the knowledge, diagnostic, code, and development-record authority boundaries', () => {
  assertSemanticParagraph(
    ['site/content/docs/concepts/memory.mdx'],
    'memory and wisdom must be reusable knowledge rather than development authority',
    [
      { label: 'memory', pattern: /\bmemory\b/i },
      { label: 'wisdom', pattern: /\bwisdom\b/i },
      { label: 'reusable knowledge', pattern: /\breusable\b[\s\S]{0,40}\b(?:knowledge|learning)\b|\b(?:knowledge|learning)\b[\s\S]{0,40}\breusable\b/i },
      { label: 'advisory or non-authoritative boundary', pattern: /\badvisory\b|\bnon-authoritative\b|\b(?:not|neither)\b[\s\S]{0,40}\bauthority\b/i },
    ]
  );

  assertSemanticParagraph(
    [
      'site/content/docs/concepts/context-management.mdx',
      'site/content/docs/concepts/memory.mdx',
      'site/content/docs/concepts/utilities.mdx',
    ],
    'local diagnostic reports must be explicitly non-authoritative evidence',
    [
      { label: 'diagnostic reports', pattern: /\bdiagnostic(?:s)?\b|\breports?\b/i },
      { label: 'non-authoritative', pattern: /\bnon-authoritative\b|\bnot\b[\s\S]{0,40}\bauthoritative\b/i },
      { label: 'evidence', pattern: /\bevidence\b/i },
    ]
  );

  assertSemanticParagraph(
    [
      'site/content/docs/concepts/context-management.mdx',
      'site/content/docs/concepts/memory.mdx',
      'site/content/docs/concepts/utilities.mdx',
      'site/content/docs/concepts/status-tracking.mdx',
    ],
    'Linear must be the only development-record authority while Git/GitHub own code and PR truth',
    [
      { label: 'Linear', pattern: /\bLinear\b/i },
      { label: 'only development-record authority', pattern: /\bonly\b[\s\S]{0,60}\bdevelopment[- ]record\b[\s\S]{0,40}\bauthority\b/i },
      { label: 'Git or GitHub', pattern: /\bGit(?:Hub)?\b/i },
      { label: 'code', pattern: /\bcode\b/i },
      { label: 'PR truth', pattern: /\b(?:PR|pull request)s?\b[\s\S]{0,50}\btruth\b|\btruth\b[\s\S]{0,50}\b(?:PR|pull request)s?\b/i },
    ]
  );
});

test('overnight guidance renders a fresh terminal handback without a local report', () => {
  assertSemanticParagraph(
    ['site/content/docs/concepts/workflows.mdx'],
    'Run overnight must persist remote evidence and render, rather than store, its handback',
    [
      { label: 'Run overnight', pattern: /\bRun overnight\b/i },
      { label: 'terminal handback', pattern: /\bterminal handback\b/i },
      { label: 'fresh Linear and GitHub reads', pattern: /\bfresh\b[\s\S]{0,40}\bLinear\b[\s\S]{0,30}\bGitHub\b[\s\S]{0,20}\breads\b/i },
      { label: 'no local morning report', pattern: /\b(?:does not|never)\b[\s\S]{0,30}\bwrite\b[\s\S]{0,30}\blocal morning report\b/i },
    ]
  );
});

test('canonical memory stays local, non-authoritative, and Linear-project-or-issue-provenanced', () => {
  const canonical = text('skills/woostack-init/references/memory.md');
  assert.match(
    canonical,
    /\bexactly\s+five\s+top-level\s+policy\s+namespaces\b[\s\S]{0,120}\blinear\b[\s\S]{0,40}\bmodels\b[\s\S]{0,40}\breview\b[\s\S]{0,40}\brespond\b[\s\S]{0,40}\bstatus\b/i
  );
  assert.doesNotMatch(canonical, /\bartifacts\.specPlan\b|\bdefaults?\s+to\s+Markdown\b|\bspec\/plan\s+backend\b/i);
  assert.match(
    canonical,
    /\bmemory\b[\s\S]{0,60}\bwisdom\b[\s\S]{0,100}\b(?:non-authoritative|neither\b[\s\S]{0,40}\bdefine)\b/i
  );
  assert.match(
    canonical,
    /\bsanitized\s+diagnostic\s+reports\b[\s\S]{0,100}\bnon-authoritative\b/i
  );
  assert.match(canonical, /linear:\/\/project\/<uuid>/i);
  assert.match(canonical, /linear:\/\/issue\/<uuid>/i);
  assert.match(canonical, /\bpr-<n>|\bpr\s+<n>/i);
  assert.match(canonical, /\baddress-comments\b/i);
  assert.doesNotMatch(canonical, /linear:\/\/document\/|\bnormalized\s+adapter\b/i);
  assert.match(
    canonical,
    /\b(?:legacy|historical)\s+Markdown\b[\s\S]{0,100}\b(?:migration|historical)\b[\s\S]{0,80}\bonly\b|\bMarkdown\b[\s\S]{0,100}\bhistorical\s+migration\s+input\s+only\b/i
  );

  const authored = text('site/content/docs/concepts/memory.mdx');
  assert.match(authored, /linear:\/\/project\/<uuid>[\s\S]{0,80}linear:\/\/issue\/<uuid>/i);
  assert.match(authored, /\bpr-<n>[\s\S]{0,60}\baddress-comments\b/i);
  assert.match(authored, /\bHistorical\s+Markdown\b[\s\S]{0,100}\bmigration\s+input\b/i);
});

test('generic engineer and Hermes pages publish the decision-maker plus isolated-coder contract', () => {
  const engineerPage = 'site/content/docs/concepts/engineer-agents.mdx';
  const hermesPage = 'site/content/docs/harnesses/hermes.mdx';

  assertSemanticParagraph([engineerPage], 'generic engineer unit must pair a decision-maker with an isolated coding profile', [
    { label: 'decision-maker', pattern: /\bdecision[- ]mak(?:er|ing)\b/i },
    { label: 'isolated', pattern: /\bisolated\b/i },
    { label: 'coding profile', pattern: /\bcod(?:er|ing)\b[\s\S]{0,40}\bprofile\b|\bprofile\b[\s\S]{0,40}\bcod(?:er|ing)\b/i },
  ]);
  assertSemanticParagraph([engineerPage], 'one engineer unit may work only one assigned issue at a time', [
    { label: 'one assigned issue', pattern: /\b(?:one|single)\s+assigned\s+(?:Linear\s+)?issue\b|\bat\s+most\s+one\s+issue\b/i },
    { label: 'at a time', pattern: /\bat\s+a\s+time\b|\bper\s+(?:run|dispatch)\b/i },
  ]);
  assert.match(
    text(engineerPage),
    /skills\/using-woostack\/references\/engineer-agents\.md/i,
    `${engineerPage}: link the canonical engineer-agent authority protocol instead of duplicating it`
  );

  assert.match(text(hermesPage), /^title:\s*Hermes\b/im, `${hermesPage}: publish the authored Hermes page`);
  assert.match(
    text('site/content/docs/harnesses/index.mdx'),
    /\/docs\/harnesses\/hermes\b/,
    'site/content/docs/harnesses/index.mdx: link the Hermes harness page'
  );
  assert.match(
    text('site/content/docs/concepts/index.mdx'),
    /\/docs\/concepts\/engineer-agents\b/,
    'site/content/docs/concepts/index.mdx: link the generic engineer-agent contract'
  );

  assertSemanticParagraph([hermesPage], 'Hermes must independently inspect and review OMP work and post its own comments or verdict', [
    { label: 'Hermes', pattern: /\bHermes\b/i },
    { label: 'independent review', pattern: /\bindependent(?:ly)?\b[\s\S]{0,80}\breviews?\b|\breviews?\b[\s\S]{0,80}\bindependent(?:ly)?\b/i },
    { label: 'diff or evidence', pattern: /\bdiff\b|\bevidence\b/i },
    { label: 'own comments or verdict', pattern: /\bown\b[\s\S]{0,60}\b(?:comments?|verdict)\b/i },
  ]);

  assertSemanticParagraph([hermesPage], 'only an explicit /woostack-review invocation may add independent reviewer delegation', [
    { label: 'explicit invocation', pattern: /\bexplicit(?:ly)?\b/i },
    { label: '/woostack-review', pattern: /\/woostack-review\b/i },
    { label: 'only or exception', pattern: /\bonly\b|\bexception\b/i },
    { label: 'independent reviewers', pattern: /\bindependent\b[\s\S]{0,40}\breviewers?\b/i },
  ]);
  assertSemanticParagraph([hermesPage], 'review delegation must leave acceptance authority with Hermes', [
    { label: 'Hermes', pattern: /\bHermes\b/i },
    { label: 'acceptance authority', pattern: /\bacceptance\b[\s\S]{0,50}\bauthority\b/i },
    { label: 'retains or remains', pattern: /\b(?:retains?|remains?|keeps?|stays?)\b/i },
  ]);
});

test('navigation registers engineer agents and Hermes', () => {
  const conceptsMeta = JSON.parse(text('site/content/docs/concepts/meta.json'));
  const harnessesMeta = JSON.parse(text('site/content/docs/harnesses/meta.json'));
  assert.ok(
    conceptsMeta.pages.includes('engineer-agents'),
    'site/content/docs/concepts/meta.json: register engineer-agents in the Core concepts sidebar'
  );
  assert.ok(
    harnessesMeta.pages.includes('hermes'),
    'site/content/docs/harnesses/meta.json: register Hermes in the Harnesses sidebar'
  );
});

test('ordered setup installs identities and launchers before issue-scoped execution and review', () => {
  const orderedPages = [
    'skills/using-woostack/references/hosts/hermes.md',
    'site/content/docs/harnesses/hermes.mdx',
    'site/content/docs/getting-started.mdx',
  ];

  for (const relativePath of orderedPages) {
    assertInOrder(relativePath, [
      { label: 'install Hermes and provision profiles', pattern: /\b1\.\s+(?:Install\s+Hermes\b|Create\s+both\s+named\s+profiles\b[\s\S]{0,180}\bInstall\s+Hermes\b)/i },
      { label: 'create the Linear identity', pattern: /\b2\.\s+(?:Create|Give)\b[\s\S]{0,80}\bLinear\s+identity\b/i },
      { label: 'configure official Linear MCP in both profiles', pattern: /\b3\.\s+(?:Connect|Configure)\s+official\s+Linear\s+MCP\b/i },
      { label: 'split repository and GitHub credentials', pattern: /\b4\.\s+(?:(?:Split|Separate)\s+repository\b|Prepare\s+distinct\s+repository\b)/i },
      { label: 'install and check reviewed launchers', pattern: /\b5\.\s+(?:Install\s+woostack\b[\s\S]{0,80}\blaunchers\b|Install\s+and\s+check\s+the\s+two\s+static\s+launchers\b)/i },
      { label: 'live profile and host preflight', pattern: /\b6\.\s+(?:(?:Discover\s+and\s+preflight|Preflight)\b[\s\S]{0,80}\b(?:capabilities|identities)\b|Only\s+after\b[\s\S]{0,100}\blive\s+identity\/capability\s+preflight\b)/i },
      { label: 'paste the decision-maker prompt', pattern: /\b7\.\s+Paste\b[\s\S]{0,60}\bdecision-maker\s+prompt\b/i },
      { label: 'assign and accept one issue', pattern: /\b8\.\s+Assign\s+and\s+accept\b[\s\S]{0,30}\bone\s+issue\b/i },
      { label: 'create and preflight the issue worktree', pattern: /\b9\.\s+Create\b[\s\S]{0,80}\bcanonical\s+issue\s+worktree\b/i },
      { label: 'implement and verify without committing', pattern: /\b(?:10|11)\.\s+Implement\s+and\s+verify\s+without\b/i },
      { label: 'review uncommitted work and authorize one commit action', pattern: /\b(?:11|12)\.\s+Review\s+uncommitted\s+work\b[\s\S]{0,80}\bone\b[\s\S]{0,30}\b(?:commit|source-control)\s+action\b/i },
      { label: 'review the submitted PR and decide', pattern: /\b(?:12|13)\.\s+Review\s+the\s+submitted\s+PR\b/i },
    ]);

    const stepOne = normalizedSpan(
      relativePath,
      'setup step 1',
      /\b1\.\s+(?:Install\s+Hermes|Create\s+both\s+named\s+profiles)\b/i,
      /\b2\.\s+(?:Create|Give)\b[\s\S]{0,80}\bLinear\s+identity\b/i
    );
    assert.match(stepOne, /\bboth\s+(?:named\s+)?profiles\b/i,
      `${relativePath}: provision/configure both pinned profiles before live use`);
    assert.match(stepOne, /\b(?:do\s+not\s+start|without\s+live\s+admission)\b/i,
      `${relativePath}: profile provisioning must not start a live profile`);

    const stepThree = normalizedSpan(
      relativePath,
      'setup step 3',
      /\b3\.\s+(?:Connect|Configure)\s+official\s+Linear\s+MCP\b/i,
      /\b4\.\s+(?:(?:Split|Separate)\s+repository\b|Prepare\s+distinct\s+repository\b)/i
    );
    assert.match(
      stepThree,
      /\b(?:do\s+not|must\s+not|without)\b[\s\S]{0,80}\bstart\b[\s\S]{0,40}\bprofiles?\b|\bprofiles?\b[\s\S]{0,80}\b(?:do\s+not|must\s+not)\s+start\b/i,
      `${relativePath}: step 3 may provision/configure profiles but must not start them`
    );
    assert.match(
      stepThree,
      /\bdefer\b[\s\S]{0,100}\b(?:identity|capability)\b[\s\S]{0,60}\bread[- ]back\b|\bread[- ]back\b[\s\S]{0,140}\bonly\s+after\b[\s\S]{0,100}\blauncher\b|\blive\b[\s\S]{0,100}\bonly\s+after\b[\s\S]{0,100}\blauncher\b/i,
      `${relativePath}: defer live identity/capability read-back until after launcher installation`
    );
    assertInOrder(relativePath, [
      { label: 'step 5 launcher installation', pattern: /\b5\.\s+(?:Install\s+woostack\b[\s\S]{0,80}\blaunchers\b|Install\s+and\s+check\s+the\s+two\s+static\s+launchers\b)/i },
      { label: 'step 6 live preflight', pattern: /\b6\.\s+(?:(?:Discover\s+and\s+preflight|Preflight)\b|Only\s+after\b[\s\S]{0,100}\blive\s+identity\/capability\s+preflight\b)/i },
      { label: 'fresh live sessions', pattern: /\bstart\s+fresh\s+sessions\b/i },
      { label: 'deferred personal OAuth login', pattern: /\b(?:perform|performing)\b[\s\S]{0,80}\binteractive\b[\s\S]{0,40}\blogins?\b/i },
      { label: 'identity and scope read-back', pattern: /\b(?:independently\s+)?read\s+back\b[\s\S]{0,160}\bactor\b[\s\S]{0,120}\bscopes?\b/i },
    ]);

    const stepSix = normalizedSpan(
      relativePath,
      'setup step 6',
      /\b6\.\s+(?:(?:Discover\s+and\s+preflight|Preflight)\b|Only\s+after\b[\s\S]{0,100}\blive\s+identity\/capability\s+preflight\b)/i,
      /\b7\.\s+Paste\b/i
    );
    const issueScopedPreflightClaims = stepSix
      .split(/(?<=[.!?])\s+/)
      .filter((sentence) =>
        /\bworktree\b/i.test(sentence) &&
        /\b(?:create|creates|resolve|resolves|preflight|preflights)\b/i.test(sentence)
      );
    assert.ok(
      issueScopedPreflightClaims.length > 0,
      `${relativePath}: step 6 must explicitly defer issue-worktree creation and preflight`
    );
    for (const claim of issueScopedPreflightClaims) {
      assert.match(
        claim,
        NEGATION,
        `${relativePath}: step 6 may preflight only facts that exist before issue allocation; found “${excerpt(claim)}”`
      );
    }
  }

  assertInOrder('site/content/docs/harnesses/omp.mdx', [
    { label: 'provision and configure without starting', pattern: /\bProvision\s+the\s+profile\s+and\s+official\s+MCP\s+without\s+starting\s+it\b/i },
    { label: 'install and preflight reviewed launchers', pattern: /\bInstall\s+and\s+preflight\s+the\s+reviewed\s+host\s+launchers\b/i },
    { label: 'fresh sessions only after launcher check', pattern: /\bOnly\s+after\s+that\s+check\s+passes,\s+start\s+fresh\b/i },
    { label: 'deferred profile login', pattern: /\bperform\s+both\b[\s\S]{0,60}\binteractive\s+OAuth\s+logins\b/i },
    { label: 'identity read-back after login', pattern: /\bIndependently\s+read\s+back\b[\s\S]{0,40}\bactor\b/i },
  ]);

  const hermesPage = 'site/content/docs/harnesses/hermes.mdx';
  assertSemanticParagraph([hermesPage], 'identity setup must distinguish autonomous app identity from human-operated personal OAuth', [
    { label: 'long-running unit', pattern: /\blong[- ]running\b|\bautonomous\b/i },
    { label: 'distinct Linear identity', pattern: /\b(?:distinct|dedicated|separate)\b[\s\S]{0,40}\b(?:Linear\s+)?(?:identity|principal|OAuth\s+app)\b/i },
    { label: 'personal OAuth', pattern: /\bpersonal\s+OAuth\b/i },
    { label: 'human-operated unit', pattern: /\bhuman[- ]operated\b|\boperated\s+by\s+(?:a\s+)?human\b/i },
  ]);
  assertSemanticParagraph([hermesPage], 'repository and Git credentials must be split by role', [
    { label: 'Hermes', pattern: /\bHermes\b/i },
    { label: 'read-only repository access', pattern: /\bread-only\b[\s\S]{0,60}\b(?:repository|source)\b|\b(?:repository|source)\b[\s\S]{0,60}\bread-only\b/i },
    { label: 'PR review and comment access', pattern: /\b(?:PR|pull request)s?\b[\s\S]{0,80}\breview\b[\s\S]{0,80}\bcomment/i },
    { label: 'OMP', pattern: /\bOMP\b/i },
    { label: 'implementation', pattern: /\bimplementation\b/i },
    { label: 'Git credentials', pattern: /\bGit\b[\s\S]{0,60}\bcredentials?\b|\bcredentials?\b[\s\S]{0,60}\bGit\b/i },
  ]);
  assertSemanticParagraph([hermesPage], 'MCP capability names must be discovered and preflighted instead of hard-coded', [
    { label: 'discover', pattern: /\bdiscover(?:ed|y)?\b|\binspect\b|\bresolve\b/i },
    { label: 'preflight', pattern: /\bpreflight(?:ed)?\b/i },
    { label: 'exact MCP capabilities', pattern: /\bexact\b[\s\S]{0,40}\bMCP\b[\s\S]{0,40}\bcapabilit(?:y|ies)\b|\bMCP\b[\s\S]{0,40}\bcapabilit(?:y|ies)\b/i },
    { label: 'no hard-coded runtime names', pattern: /\bhard[- ]?cod(?:e|ed|ing)\b[\s\S]{0,40}\b(?:names?|tools?)\b/i },
  ]);
});

test('app actors use separate profile-native bearer credentials and complete identity read-back', () => {
  const sharedBearerPages = [
    'skills/using-woostack/references/hosts/hermes.md',
    'site/content/docs/harnesses/hermes.mdx',
    'site/content/docs/getting-started.mdx',
  ];
  const allPairPages = [
    ...sharedBearerPages,
    'site/content/docs/harnesses/omp.mdx',
  ];

  for (const relativePath of sharedBearerPages) {
    const page = text(relativePath);
    assert.ok(
      page.includes('Authorization: "Bearer ${WOO_HERMES_LINEAR_APP_ACCESS_TOKEN}"'),
      `${relativePath}: configure Hermes app OAuth through an environment-backed bearer header`
    );
    assert.ok(
      page.includes('"Authorization": "Bearer ${WOO_OMP_LINEAR_APP_ACCESS_TOKEN}"'),
      `${relativePath}: configure OMP app OAuth through an environment-backed bearer header`
    );

    assertInOrder(relativePath, [
      { label: 'step 3 official-MCP setup', pattern: /\b3\.\s+(?:Connect|Configure)\s+official\s+Linear\s+MCP\b/i },
      { label: 'actor=user catalog/login path', pattern: /\bactor=user\b[\s\S]{0,80}\bonly\b|\bonly\b[\s\S]{0,80}\bactor=user\b/i },
      { label: 'actor=app bearer path', pattern: /\bactor=app\b/i },
      { label: 'Hermes profile bearer variable', pattern: /\bWOO\W+HERMES\W+LINEAR\W+APP\W+ACCESS\W+TOKEN\b/i },
      { label: 'OMP profile bearer variable', pattern: /\bWOO\W+OMP\W+LINEAR\W+APP\W+ACCESS\W+TOKEN\b/i },
      { label: 'step 4 credential split', pattern: /\b4\.\s+(?:(?:Split|Separate)\s+repository\b|Prepare\s+distinct\s+repository\b)/i },
    ]);
  }

  for (const relativePath of allPairPages) {
    const page = text(relativePath);
    assert.match(page, /\bactor=user\b[\s\S]{0,180}\b(?:catalog|login)\b|\b(?:catalog|login)\b[\s\S]{0,180}\bactor=user\b/i,
      `${relativePath}: keep Hermes catalog/login on the actor=user path`);
    assert.match(page, /\bactor=app\b/i, `${relativePath}: document the app actor`);
    assert.match(page, /\bagent\/mcp\.json\b/i, `${relativePath}: use OMP profile-local agent/mcp.json`);
    assert.match(page, /\b(?:never|not|do\s+not)\b[\s\S]{0,100}\bproject\s+`?\.omp\/mcp\.json`?/i,
      `${relativePath}: forbid project .omp/mcp.json for app credentials`);
    assert.match(page, /\b(?:separate|distinct)\b[\s\S]{0,80}\b(?:access\s+)?tokens?\b/i,
      `${relativePath}: issue a separate token to each profile`);
    assert.match(
      page,
      /\benable(?:d)?\b[\s\S]{0,60}\b(?:client\s+credentials\s+tokens?|client_credentials)\b|\b(?:client\s+credentials\s+tokens?|client_credentials)\b[\s\S]{0,60}\benable(?:d)?\b/i,
      `${relativePath}: client-credentials issuance must be enabled on the app`
    );
    assert.match(page, /\bgrant_type=client_credentials\b|\bclient_credentials\s+grant\b/i,
      `${relativePath}: issue both app access tokens through client_credentials`);
    assert.match(
      page,
      /\bidentical\b[\s\S]{0,80}\bscopes?\b|\bsame\b[\s\S]{0,80}\bscope\s+set\b/i,
      `${relativePath}: both parallel app tokens must request identical required scopes`
    );
    assert.match(page, /\bexpires?\b[\s\S]{0,40}\b30\s+days?\b|\b30-day\s+expiry\b/i,
      `${relativePath}: document the 30-day client-credentials token lifetime`);
    assert.match(page, /\bno\s+refresh\s+token\b/i,
      `${relativePath}: client-credentials access tokens have no refresh token`);
    assert.match(
      page,
      /\boperator\b[\s\S]{0,120}\bclient[_ ]secret\b[\s\S]{0,180}\b(?:never|outside)\b[\s\S]{0,80}\bprofiles?\b|\bclient[_ ]secret\b[\s\S]{0,120}\boperator\b[\s\S]{0,120}\bprofiles?\b/i,
      `${relativePath}: keep the OAuth client secret operator-only and out of both profiles`
    );
    assert.match(page, /\brotate\b[\s\S]{0,120}\b30-day\s+expiry\b|\b(?:30\s+days?|30-day)\b[\s\S]{0,160}\brotate\b/i,
      `${relativePath}: rotate both access tokens within the bounded lifetime`);
    assert.match(
      page,
      /\b(?:repeat|re-run)\b[\s\S]{0,100}\bidentity\b[\s\S]{0,60}\bcapability\s+preflight\b/i,
      `${relativePath}: every token rotation must trigger identity/capability re-preflight`
    );

    const bearerValues = [...page.matchAll(/Authorization"?\s*:\s*"Bearer\s+([^"]+)"/g)];
    assert.ok(bearerValues.length > 0, `${relativePath}: include an app bearer-header example`);
    for (const [, value] of bearerValues) {
      assert.match(
        value,
        /^\$\{[A-Z][A-Z0-9_]*\}$/,
        `${relativePath}: bearer examples must reference a secret environment variable, not contain a token`
      );
    }

    assertSemanticParagraph([relativePath], 'each live profile must read back complete Linear identity evidence', [
      { label: 'actor', pattern: /\bactor\b/i },
      { label: 'scope', pattern: /\bscopes?\b/i },
      { label: 'capabilities', pattern: /\bcapabilit(?:y|ies)\b/i },
      { label: 'workspace', pattern: /\bworkspace\b/i },
      { label: 'team', pattern: /\b(?:LINEAR_TEAM|team)\b/i },
      { label: 'native ID', pattern: /\b(?:immutable\s+)?native\b[\s\S]{0,30}\bID\b/i },
    ]);
  }
});

test('reviewed launchers are installed and checksum-verified before profile preflight', () => {
  const launcherPages = [
    'skills/using-woostack/references/hosts/hermes.md',
    'site/content/docs/harnesses/hermes.mdx',
    'site/content/docs/harnesses/omp.mdx',
    'site/content/docs/getting-started.mdx',
  ];

  for (const relativePath of launcherPages) {
    const page = text(relativePath);
    assert.match(page, /skills\/woostack-init\/scripts\/gen-omp-agents\.sh/,
      `${relativePath}: direct operators to the shipped launcher installer`);
    assert.match(page, /\bomp-agents\b[\s\S]{0,60}\brepair\b|\brepair\b[\s\S]{0,60}\bomp-agents\b/i,
      `${relativePath}: name the approved doctor repair`);
    assert.match(page, /\bchecksums?\b/i, `${relativePath}: verify reviewed launcher checksums`);
    assert.match(page, /\b(?:mode[- ]?)?0700\b/i, `${relativePath}: require the controller-owned directory mode`);
    assert.match(page, /\b(?:mode[- ]?)?0500\b/i, `${relativePath}: require reviewed launcher file modes`);
    assert.match(page, /project\s+`?\/woostack-init`?[\s\S]{0,100}\bdoes\s+(?:\*\*)?not(?:\*\*)?\s+install\b/i,
      `${relativePath}: project init must not claim to install host launchers`);
    assert.ok(page.includes(LAUNCHER_ROOT),
      `${relativePath}: use one trusted launcher directory per ENGINEER_NAME`);
    for (const launcher of ['launch-omp', 'bind-engineer-unit']) {
      assert.match(
        page,
        new RegExp(`\\b${launcher}\\b`),
        `${relativePath}: install ${launcher} in the per-engineer trusted directory`
      );
    }
    assert.match(page, /\bbind-engineer-unit\b/,
      `${relativePath}: install the static unit-authority binder`);
    assert.match(page, /\bmode[- ]?`?0400`?\b[\s\S]{0,40}\bunit-authority\.json\b|\bunit-authority\.json\b[\s\S]{0,40}\bmode[- ]?`?0400`?\b/i,
      `${relativePath}: require the adjacent read-only unit authority`);
  }

  const ompIssueFlow = normalizedSpan(
    'site/content/docs/harnesses/omp.mdx',
    'OMP accepted-issue flow',
    /\bAccept,\s+establish\s+the\s+worktree,\s+then\s+implement\b/i,
    /\bTask\s+review\s+and\s+one\s+bounded\s+commit\s+redispatch\b/i
  );
  assertTextInOrder(ompIssueFlow, 'site/content/docs/harnesses/omp.mdx: accepted-issue flow', [
    { label: 'assignmentAccepted read-back', pattern: /\breads?\s+back\b[\s\S]{0,50}\bassignmentAccepted\b/i },
    { label: 'canonical worktree resolution', pattern: /\bcreate\s+or\s+resolve\b[\s\S]{0,80}\b(?:canonical\s+issue\s+worktree|worktree\b[\s\S]{0,100}\bcanonical)\b/i },
    { label: 'mode-0600 staged unit manifest', pattern: /\bmode[- ]+0600\b[\s\S]{0,30}\bunit\.json\b/i },
    { label: 'static unit binder', pattern: /\bbind-engineer-unit\b/i },
    { label: 'mode-0400 adjacent authority', pattern: /\bmode[- ]+0400\b[\s\S]{0,30}\bunit-authority\.json\b/i },
    { label: 'implementation-only first grant', pattern: /\bfirst\s+OMP\s+grant\b[\s\S]{0,100}\bimplementation\s+and\s+verification\b/i },
  ]);
});


test('post-acceptance manifest binding locks profiles, worktree, programs, and role environments', () => {
  const authoredPairPages = [
    'site/content/docs/getting-started.mdx',
    'site/content/docs/harnesses/hermes.mdx',
    'site/content/docs/harnesses/omp.mdx',
  ];

  for (const relativePath of authoredPairPages) {
    const page = text(relativePath);
    assert.ok(page.includes(LAUNCHER_ROOT),
      `${relativePath}: bind authority beside the per-engineer trusted launchers`);
    assert.ok(page.includes(UNIT_SCHEMA),
      `${relativePath}: publish the exact staged unit.json schema`);
    assert.match(page, /\bmode[- ]?`?0600`?\b[\s\S]{0,40}\bunit\.json\b/i,
      `${relativePath}: stage unit.json with mode 0600`);
    assert.match(page, /\bbind-engineer-unit\b[\s\S]{0,100}\bstaging\s+directory\b[\s\S]{0,80}\bworking\s+directory\b/i,
      `${relativePath}: invoke the static binder with the staging directory as workdir`);
    assert.match(page, /\bmode[- ]?`?0400`?\b[\s\S]{0,40}\bunit-authority\.json\b|\bunit-authority\.json\b[\s\S]{0,40}\bmode[- ]?`?0400`?\b/i,
      `${relativePath}: atomically install adjacent mode-0400 authority`);
    assert.match(page, /\bexact\b[\s\S]{0,60}\bdistinct\b[\s\S]{0,60}\b(?:Hermes\s+and\s+OMP\s+)?profiles\b|\bprofiles\b[\s\S]{0,60}\bexact\s+and\s+distinct\b/i,
      `${relativePath}: require exact distinct Hermes and OMP profiles`);
    assert.match(page, /\bcanonical\b[\s\S]{0,50}\bworktree\b/i,
      `${relativePath}: manifest repository must be the canonical issue worktree`);
    assert.match(page, /\bpinned\s+absolute\b[\s\S]{0,60}\b(?:executables|programs|binaries)\b/i,
      `${relativePath}: execute only pinned absolute Hermes/OMP programs`);
    assert.match(page, /\bsecret-free\b[\s\S]{0,100}\brole-owned\b[\s\S]{0,100}\b(?:PATH|environment)\b/i,
      `${relativePath}: manifest stores only secret-free role-owned environment pins`);
    assert.match(page, /\blocale\b[\s\S]{0,40}\bterminal\b[\s\S]{0,60}\bSSL(?:-certificate)?\b/i,
      `${relativePath}: inherit only harmless locale, terminal, and SSL keys`);
    assert.match(page, /\bnever\s+inherits?\b[\s\S]{0,100}\bcontroller(?:'s)?\b[\s\S]{0,80}\bHOME\b[\s\S]{0,40}\bPATH\b[\s\S]{0,60}\bcredential\b/i,
      `${relativePath}: never inherit controller HOME, PATH, or credential state`);
    assert.match(page, /\b(?:reject|must\s+match)\b[\s\S]{0,100}\bprofile\b[\s\S]{0,80}\brepositor(?:y|ies)\b|\bprofile\s+or\s+repository\s+argument\b[\s\S]{0,80}\bdiffers?\b|\bprofile\b[\s\S]{0,80}\brepository\b[\s\S]{0,80}\bmust\s+match\b/i,
      `${relativePath}: launchers require exact profile and repository matches`);

    const issueFlow =
      relativePath.endsWith('/omp.mdx')
        ? normalizedSpan(
            relativePath,
            'accepted issue and bound unit',
            /\bAccept,\s+establish\s+the\s+worktree,\s+then\s+implement\b/i,
            /\bTask\s+review\s+and\s+one\s+bounded\s+commit\s+redispatch\b/i
          )
        : normalizedSpan(
            relativePath,
            'accepted issue and bound unit',
            /\b8\.\s+Assign\s+and\s+accept\b[\s\S]{0,40}\bone\s+issue\b/i,
            /\b11\.\s+Review\s+uncommitted\s+work\b/i
          );
    assertTextInOrder(issueFlow, `${relativePath}: accepted issue and bound unit`, [
      { label: 'assignmentAccepted read-back', pattern: /\bread(?:s|ing)?\s+back\b[\s\S]{0,60}\bassignmentAccepted\b|\bassignmentAccepted\b[\s\S]{0,60}\bread[- ]back\b/i },
      { label: 'canonical worktree resolution', pattern: /\bcreate\s+or\s+resolve\b[\s\S]{0,100}\b(?:canonical\s+)?(?:issue\s+)?worktree\b/i },
      { label: 'mode-0600 staged unit.json', pattern: /\bmode[- ]+0600\b[\s\S]{0,40}\bunit\.json\b/i },
      { label: 'static binder', pattern: /\bbind-engineer-unit\b/i },
      { label: 'mode-0400 installed authority', pattern: /\bmode[- ]+0400\b[\s\S]{0,40}\bunit-authority\.json\b/i },
      { label: 'implementation begins only after binding', pattern: /\b10\.\s+Implement\s+and\s+verify\b|\bfirst\s+OMP\s+grant\b/i },
    ]);
  }
});

test('the first coder dispatch uses the canonical implementer task, then a separate commit grant', () => {
  for (const relativePath of [
    'skills/using-woostack/references/hosts/hermes.md',
    'site/content/docs/getting-started.mdx',
    'site/content/docs/harnesses/hermes.mdx',
    'site/content/docs/harnesses/omp.mdx',
  ]) {
    const page = text(relativePath);
    assert.ok(page.includes(IMPLEMENTER_PROMPT),
      `${relativePath}: first dispatch must use the canonical implementer prompt`);
    assert.ok(page.includes(SUBAGENT_DRIVER),
      `${relativePath}: first dispatch must retain subagent-driver authority`);
    assert.doesNotMatch(page, /\bone\s+(?:implementation\s+)?woostack\s+command\b/i,
      `${relativePath}: do not invent a public implementation command`);
    assert.match(
      page,
      /\bbounded\b[\s\S]{0,80}\bpaired-coder\b[\s\S]{0,80}\bimplement(?:er|ation)\s+task\b/i,
      `${relativePath}: identify the bounded paired-coder implementation task`
    );
    assertInOrder(relativePath, [
      { label: 'canonical internal implementer task', pattern: /skills\/woostack-execute\/prompts\/implementer\.md/i },
      { label: 'separate bounded commit redispatch', pattern: /\bexactly\s+one\s+bounded\b[\s\S]{0,50}\/woostack-commit\b/i },
    ]);
  }
});

test('post-acceptance worktree and two-dispatch review flow remain in canonical order', () => {
  const flowPages = [
    'skills/using-woostack/references/hosts/hermes.md',
    'site/content/docs/harnesses/hermes.mdx',
    'site/content/docs/harnesses/omp.mdx',
    'site/content/docs/getting-started.mdx',
  ];

  for (const relativePath of flowPages) {
    assertInOrder(relativePath, [
      { label: 'one issue assignment boundary', pattern: /\b(?:Assign\s+and\s+accept|Accept,\s+establish)\b/i },
      { label: 'assignmentAccepted read-back', pattern: /\bread(?:s|ing)?\s+back\b[\s\S]{0,50}\bassignmentAccepted\b|\bassignmentAccepted\b[\s\S]{0,50}\bread[- ]back\b/i },
      { label: 'canonical issue-worktree creation', pattern: /\b(?:Create|create)\s+or\s+resolve\b[\s\S]{0,100}\b(?:canonical\s+)?(?:issue\s+)?worktree\b|\bCreate\s+and\s+preflight\s+the\s+canonical\s+issue\s+worktree\b/i },
      { label: 'post-worktree unit binding', pattern: /\bbind-engineer-unit\b/i },
      { label: 'implementation-only first dispatch', pattern: /\bImplement\s+and\s+verify\s+without\b|\bfirst\s+OMP\s+grant\b[\s\S]{0,120}\bpermits\s+only\s+implementation\b/i },
      { label: 'uncommitted diff handback', pattern: /\buncommitted\s+diff\b/i },
      { label: 'Hermes task specification and quality review', pattern: /\btask\b[\s\S]{0,40}\bspecification\b[\s\S]{0,40}\bquality\s+review\b/i },
      { label: 'canonical verification', pattern: /\bcanonical\s+verification\b/i },
      { label: 'precommitReview read-back', pattern: /\bprecommitReview\b/i },
      { label: 'fresh authority and Git recheck', pattern: /\bfresh(?:ly)?\b[\s\S]{0,100}\b(?:rechecks?|re-read|recheck)\b/i },
      { label: 'same OMP profile redispatch', pattern: /\bsame\b[\s\S]{0,30}\bOMP\s+profile\b/i },
      { label: 'exactly one bounded commit action', pattern: /\bexactly\s+one\s+bounded\b[\s\S]{0,40}\/woostack-commit\b/i },
      { label: 'implementationEvidence read-back', pattern: /\bimplementationEvidence\b/i },
      { label: 'native PR relation read-back', pattern: /\bnative\s+PR\s+relation\b/i },
      { label: 'initial inReview read-back', pattern: /\binReview\b/i },
      { label: 'later independent submitted-PR review', pattern: /\bindependent(?:ly)?\b[\s\S]{0,80}\b(?:read|review)\b[\s\S]{0,80}\bsubmitted\s+PR\b|\bindependent\s+submitted-PR\s+review\b|\bReview\s+the\s+submitted\s+PR\b[\s\S]{0,100}\bindependent(?:ly)?\b/i },
      { label: 'Hermes-owned PR comment or verdict', pattern: /\bpost(?:s|ed)?\b[\s\S]{0,50}\b(?:its|your)\s+own\b[\s\S]{0,60}\b(?:comments?|verdict)\b/i },
    ]);
  }
});

test('Hermes and OMP docs show the verified OMP command exactly', () => {
  for (const relativePath of [
    'site/content/docs/harnesses/hermes.mdx',
    'site/content/docs/harnesses/omp.mdx',
    'skills/using-woostack/references/hosts/hermes.md',
    'site/content/docs/getting-started.mdx',
  ]) {
    assert.ok(
      text(relativePath).includes(EXACT_OMP_COMMAND),
      `${relativePath}: include the exact verified command “${EXACT_OMP_COMMAND}”`
    );
  }
});

test('Hermes page contains the complete parameterized two-dispatch decision-maker prompt', () => {
  const hermesPage = 'site/content/docs/harnesses/hermes.mdx';
  const prompt = fencedBlocks(text(hermesPage)).find(
    (block) => /\bENGINEER_NAME\b/.test(block) && /\bdecision[- ]making\s+engineer\b/i.test(block)
  );
  assert.ok(
    prompt,
    `${hermesPage}: add one copyable fenced prompt containing ENGINEER_NAME and the decision-making engineer contract`
  );

  for (const placeholder of [
    'ENGINEER_NAME',
    'PROJECT_ID',
    'STANDALONE_DISPATCHER_ENVELOPE',
    'REPOSITORY_PATH',
    'LINEAR_TEAM',
    'OMP_PROFILE',
    'HUMAN_PRINCIPAL',
  ]) {
    assert.match(
      prompt,
      new RegExp(`\\b${placeholder}\\b`),
      `${hermesPage}: prompt is missing the ${placeholder} placeholder`
    );
  }

  assertPromptClause(prompt, 'identify Hermes as the decision-making engineer', /\bdecision[- ]making\s+engineer\b/i);
  assertPromptClause(
    prompt,
    'prohibit source edits, implementation/tests, commits, pushes, and implementation PRs',
    /\bdo\s+not\s+edit\s+source,\s+run\s+implementation\/tests,\s+commit,\s+push,\s+or\s+open\s+implementation\s+PRs\b/i
  );
  assertPromptClause(
    prompt,
    'delegate one assigned issue to the isolated OMP coding profile',
    /\bdelegate\s+repository\s+development\b[\s\S]{0,80}\bisolated\s+OMP\s+coding\s+profile\b[\s\S]{0,80}\bone\s+assigned\s+Linear\s+issue\b[\s\S]{0,30}\bat\s+a\s+time\b/i
  );

  assertTextInOrder(prompt, `${hermesPage}: decision-maker prompt`, [
    { label: 'assignmentAccepted read-back', pattern: /\bassignmentAccepted\s+receipt\b/i },
    { label: 'post-acceptance canonical worktree preflight', pattern: /\bOnly\s+after\s+that\s+read-back\b[\s\S]{0,80}\bcreate\s+or\s+resolve\b[\s\S]{0,80}\bcanonical\s+issue\s+worktree\b/i },
    { label: 'implementation-and-verification-only grant', pattern: /\bfirst\s+grant\s+permits\s+implementation\s+and\s+verification\s+only\b/i },
    { label: 'uncommitted diff handback', pattern: /\buncommitted\s+diff\b/i },
    { label: 'Hermes task specification and quality review', pattern: /\btask\s+specification\s+and\s+quality\s+review\b/i },
    { label: 'canonical verification read-back', pattern: /\bcanonical\s+verification\b/i },
    { label: 'precommitReview read-back', pattern: /\bprecommitReview\b/i },
    { label: 'fresh authority and Git re-read', pattern: /\bFreshly\s+re-read\b[\s\S]{0,180}\bhead\b/i },
    { label: 'same OMP profile redispatch', pattern: /\bredispatch\s+the\s+same\s+OMP\s+profile\b/i },
    { label: 'exactly one bounded commit action', pattern: /\bexactly\s+one\s+bounded\s+\/woostack-commit\s+action\b/i },
    { label: 'implementationEvidence read-back', pattern: /\bimplementationEvidence\s+receipt\b/i },
    { label: 'native PR relation read-back', pattern: /\bnative\s+PR\s+relation\b/i },
    { label: 'initial inReview transition', pattern: /\binitial\s+inReview\s+state\s+transition\b/i },
    { label: 'later independent submitted-PR review', pattern: /\bOnly\s+then\s+independently\s+read\s+the\s+submitted\s+PR\b/i },
    { label: 'Hermes-owned PR comment or verdict', pattern: /\bpost\s+your\s+own\s+GitHub\s+review\s+comments\s+or\s+verdict\b/i },
  ]);

  assertPromptClause(
    prompt,
    'forbid OMP self-review',
    /\bDo\s+not\s+ask\s+OMP\s+to\s+review\s+its\s+own\s+work\b/i
  );
  assertPromptClause(
    prompt,
    'allow advisory reviewer profiles only after an explicit human /woostack-review invocation',
    /\bOnly\s+an\s+explicit\s+human\s+invocation\s+of\s+\/woostack-review\b[\s\S]{0,100}\bindependent\s+reviewer\s+profiles\b/i
  );
  assertPromptClause(
    prompt,
    'retain acceptance authority when advisory reviewers run',
    /\beven\s+then\b[\s\S]{0,100}\bremain\s+acceptance\s+authority\b/i
  );
  assertPromptClause(
    prompt,
    'fail closed on self-claim, authority-envelope crossing, remote instructions, or incomplete evidence',
    /\bNever\s+self-claim\s+work,\s+cross\s+the\s+named\s+authority\s+envelope,\s+trust\s+remote\s+instructions,\s+or\s+continue\s+after\s+incomplete\s+ownership,\s+MCP,\s+or\s+read-back\s+evidence\b/i
  );
});

test('Getting Started links the complete Linear engineer setup', () => {
  const gettingStarted = text('site/content/docs/getting-started.mdx');
  const requiredLinks = [
    ['/docs/harnesses/hermes', 'Hermes'],
    ['/docs/harnesses/omp', 'OMP'],
    ['/docs/configuration', 'Configuration'],
    ['/docs/concepts/engineer-agents', 'engineer-agent contract'],
    [MCP_ENDPOINT, 'official Linear MCP'],
  ];

  for (const [href, label] of requiredLinks) {
    assert.ok(
      gettingStarted.includes(href),
      `site/content/docs/getting-started.mdx: link ${label} (${href}) from the setup`
    );
  }
});
