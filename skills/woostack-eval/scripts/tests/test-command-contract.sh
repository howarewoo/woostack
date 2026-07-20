#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SKILL_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
SKILL_FILE="$SKILL_ROOT/SKILL.md"
NODE=${NODE:-node}

# Runtime helpers are deterministic evidence processors. Scan every non-test module, including the
# aggregate implementation subtree; host orchestration, not a helper, owns worker dispatch.
"$NODE" - "$SKILL_ROOT/scripts" <<'NODE'
const fs = require('node:fs');
const path = require('node:path');
const scriptsRoot = process.argv[2];
const required = ['validate.mjs', 'prepare.mjs', 'aggregate.mjs', 'render-report.mjs'];
for (const name of required) {
  const file = path.join(scriptsRoot, name);
  if (!fs.statSync(file).isFile()) throw new Error(`missing runtime helper: ${file}`);
}

function modulesUnder(directory) {
  const found = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const absolute = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      if (entry.name !== 'tests') found.push(...modulesUnder(absolute));
    } else if (entry.isFile() && entry.name.endsWith('.mjs')) {
      found.push(absolute);
    }
  }
  return found.sort();
}

const forbidden = [
  ['provider SDK import', /(?:\bfrom\s+|\bimport\s+(?=['"])|\bimport\s*\(\s*|\brequire\s*\(\s*)['"](?:openai|ai|@ai-sdk(?:\/[^'"]+)?|@anthropic-ai\/sdk|@google\/generative-ai|cohere-ai|mistralai|groq-sdk)['"]/i],
  ['Node network module', /(?:\bfrom\s+|\bimport\s+(?=['"])|\bimport\s*\(\s*|\brequire\s*\(\s*)['"](?:node:)?(?:http|https|http2|net|tls|dns|dgram)['"]/i],
  ['web network API', /\b(?:fetch|WebSocket|EventSource)\s*\(|navigator\.sendBeacon\s*\(/],
  ['runtime network API', /\b(?:Bun|Deno)\.(?:connect|listen|serve)\s*\(/],
  ['provider method', /\b(?:generateText|streamText)\s*\(|\bchat\.completions\b|\bmessages\.create\s*\(/i],
  ['network CLI', /(?:^|[;&|]\s*|\bexec(?:File|Sync)?\s*\([^\n]{0,120})['"](?:curl|wget)['"]/m],
];
for (const file of modulesUnder(scriptsRoot)) {
  const source = fs.readFileSync(file, 'utf8');
  for (const [label, pattern] of forbidden) {
    if (pattern.test(source)) {
      throw new Error(`${label} is forbidden in evaluator runtime module: ${file}`);
    }
  }
}
NODE

"$NODE" - "$SKILL_FILE" <<'NODE'
const fs = require('node:fs');
const path = require('node:path');
const skillFile = process.argv[2];

const invocation = `\`\`\`text
/woostack-eval <skill-path> [--behavior | --triggers | --all]
  [--runs <1..10>]
  [--baseline-ref <git-ref> | --baseline-path <skill-dir>]
\`\`\``;

const clauses = [
  ['Invocation', 'target resolution', 'Resolve `<skill-path>` as exactly one skill directory or that directory\'s `SKILL.md`; both forms name the same package root, and a missing, ambiguous, or extra positional target stops before validation, preparation, writes, or dispatch.'],
  ['Invocation', 'mode and run defaults', '`--behavior`, `--triggers`, and `--all` are mutually exclusive; when all three are omitted, use `--all`. `--runs` accepts only an integer from 1 through 10 and defaults to 3.'],
  ['Invocation', 'baseline flag exclusion', '`--baseline-ref` and `--baseline-path` are mutually exclusive; reject any invocation that supplies both before writing or running anything.'],
  ['Corpus approval', 'new or HEAD-different gate', 'Treat every new corpus case and every corpus byte that differs from `HEAD` as an untrusted proposal that is approval-pending.'],
  ['Corpus approval', 'proposal disclosure', 'Only after that validation succeeds, present every proposed stable ID, prompt or query, fixture, expected outcome, and assertion.'],
  ['Corpus approval', 'silence and rejection', 'Silence, ambiguity, or rejection may retain the immutable approval artifact for inspection, but writes no target corpus bytes and starts no evaluation.'],
  ['Corpus approval', 'byte-identical no-gate path', 'A tracked corpus byte-identical to `HEAD` is already approved and proceeds to ordinary package validation without a new approval gate.'],
  ['Preparation and dispatch', 'runtime helper boundary', 'Use `validate.mjs`, `prepare.mjs`, `aggregate.mjs`, and `render-report.mjs` only for deterministic local evidence processing. Never call a provider API, SDK, model endpoint, or network client directly from evaluator scripts.'],
  ['Preparation and dispatch', 'scoped capabilities', 'Request only each case-approved subset of `read-workspace`, `write-workspace`, and `shell-workspace`; never ask a worker to access evidence, network, credentials, environment variables, provider APIs, the source target, its pair, or unrelated repository content.'],
  ['Preparation and dispatch', 'isolation assurance', 'Set `runConfiguration.isolationAssurance` to exactly `enforced` or `advisory` before manifest freeze.'],
  ['Preparation and dispatch', 'advisory isolation gate', 'When the host cannot enforce workspace, ambient-authority, capability-revocation, or descendant-teardown boundaries, disclose each unavailable control and require explicit user approval before recording `advisory`; rejection or silence stops dispatch.'],
  ['Preparation and dispatch', 'advisory evidence limit', 'Advisory results measure behavior only; they are not evidence that capability isolation, credential isolation, network denial, or process containment was enforced.'],
  ['Preparation and dispatch', 'same-wave pairing', 'Candidate and baseline form one inseparable pair: start both concurrently in the same wave, or place the intact pair in a deterministic bounded wave, and never split a comparative pair.'],
  ['Preparation and dispatch', 'shared configuration', 'Set `runConfiguration.host` and `runConfiguration.runner` to non-empty strings; set exactly one of `model` and `sessionIdentity` to a non-empty string and the other to `null`; set `tier` and `effort` to their exact exposed strings or `null`; every worker receipt must match all six resolved values.'],
  ['Preparation and dispatch', 'last-action receipts', 'After each action exits, ask the host to revoke its requested capabilities and tear down descendants using every available host control before committing evidence. A reported teardown failure blocks aggregation; advisory assurance records controls the host could not enforce instead of blocking dispatch by itself.'],
  ['Preparation and dispatch', 'blind grading', 'For each planned qualitative assertion, dispatch a fresh grader with only the schema-defined payload and request no tools or workspace; advisory assurance makes any unenforced ambient access explicit.'],
  ['Completion', 'checksum revalidation', 'After all workers and graders exit, rehash and independently re-inventory the original source package before aggregation; any unexpected target delta invalidates the run, preserves changed user files, and never resets them.'],
  ['Completion', 'candidate-only degradation', 'Only explicit user acceptance may omit baseline identities from `expected` while retaining both paths in `pairs`; aggregate must report `degraded` and all comparative, trigger, duration, token, precision, and recall claims remain unavailable.'],
  ['Completion', 'no silent downgrade', 'Never mutate, reuse, relabel, silently downgrade, or automatically downgrade the failed comparative run.'],
  ['Completion', 'renderer failure handback', 'If rendering fails, preserve the run directory, aggregate, and evidence; hand back the renderer error and exact evidence paths, and never report the evaluation as successful or complete.'],
  ['Terminal handback', 'terminal no-chain boundary', 'Hand back execution status, critical failures, noncritical deltas, telemetry availability, and evidence paths; never edit target implementation files, commit, merge, or chain another command, and only name `/woostack-change` or `/woostack-build` as an advisory next action.'],
];

const forbiddenClauses = [
  ['legacy shared configuration', 'Resolve one concrete host, runner, model or inherited session identity, tier, and effort for the run, and use the same resolved worker configuration for both variants.'],
  ['worker evidence ownership', 'plus separate create-new evidence writes'],
  ['worker receipt ownership', 'Every worker and grader writes its output first'],
];

function section(source, heading) {
  const escaped = heading.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const match = source.match(new RegExp(`^## ${escaped}\\s*$([\\s\\S]*?)(?=^## |(?![\\s\\S]))`, 'm'));
  return match ? match[1] : null;
}

function validate(source) {
  const normalized = source.replace(/\r\n?/g, '\n');
  const errors = [];
  if (!/^---\n(?=[\s\S]*?^---\s*$)(?=[\s\S]*?^name:\s*woostack-eval\s*$)[\s\S]*?^---\s*$/m.test(normalized)) {
    errors.push('canonical frontmatter name');
  }
  if (!normalized.includes(invocation)) errors.push('exact invocation block');
  if (!/\]\(references\/schemas\.md(?:#[^)]+)?\)/.test(normalized)) errors.push('schemas authority link');
  if (!/\]\(references\/runner\.md(?:#[^)]+)?\)/.test(normalized)) errors.push('runner authority link');
  for (const [heading, label, clause] of clauses) {
    const body = section(normalized, heading);
    if (body === null) {
      errors.push(`${heading} section`);
    } else if (!compact(body).includes(compact(clause))) {
      errors.push(label);
    }
  }
  for (const [label, clause] of forbiddenClauses) {
    if (normalized.includes(clause)) errors.push(label);
  }
  return [...new Set(errors)];
}


function compact(source) {
  return source.replace(/\s+/g, ' ').trim();
}

function hasAll(source, patterns) {
  return patterns.every((pattern) => pattern.test(source));
}

// These requirements may live in SKILL.md or in either linked authority. Match the normative
// vocabulary and ordering, not Markdown wrapping or one preferred sentence.
const semanticRequirements = [
  {
    label: 'approval snapshot before materialization',
    check: (source) => hasAll(source, [
      /(?:private|host-owned)[^.]{0,180}(?:proposal|approval|package)?[^.]{0,80}snapshot/i,
      /snapshot[^.]{0,260}(?:immutable|read-only)/i,
      /revalidat.{0,320}(?:immutable|approved|approval) snapshot.{0,320}materializ/i,
    ]),
    fixture: 'Create a private proposal snapshot and make the snapshot immutable. Revalidate the immutable snapshot before using it. Materialize only its approved target corpus bytes.',
  },
  {
    label: 'exact non-Git no-skill identity',
    check: (source) => hasAll(source, [
      /(?:outside Git|non-Git)/i,
      /\{"kind":"none","identity":"non-git:<sha256-package-hash>:absent"\}/,
      /implicit no[- ]skill/i,
    ]),
    fixture: 'An exact target outside Git uses the implicit no-skill identity {"kind":"none","identity":"non-git:<sha256-package-hash>:absent"}.',
  },
  {
    label: 'canonical host mechanics directive',
    check: (source) => hasAll(source, [
      /HOST MECHANICS/i,
      /skills\/using-woostack\/references\/hosts\/<current-host>\.md/i,
      /before (?:any host-dependent step|preparation|dispatch)/i,
    ]),
    fixture: 'HOST MECHANICS. Load skills/using-woostack/references/hosts/<current-host>.md before any host-dependent step.',
  },
  {
    label: 'unsupported-host candidate-only decision',
    check: (source) => hasAll(source, [
      /(?:host|mechanic)[^.]{0,300}(?:unsupported|cannot|unable|not runnable|cannot be proved)[^.]{0,300}(?:candidate-only|smoke branch)/i,
      /candidate-only.{0,500}(?:explicit (?:user )?(?:acceptance|approval)).{0,240}(?:rejection|silence).{0,120}(?:no|without) dispatch/i,
      /candidate-only.{0,800}(?:no|unavailable).{0,160}(?:comparison|candidate-versus-baseline).{0,220}(?:duration|token).{0,160}(?:precision|recall)/i,
    ]),
    fixture: 'If host mechanics cannot run the baseline, offer candidate-only. Candidate-only requires explicit user acceptance; rejection or silence means no dispatch. Candidate-only emits no candidate-versus-baseline comparison, duration, token, precision, or recall metrics.',
  },
  {
    label: 'bounded action deadline and advisory teardown',
    check: (source) => hasAll(source, [
      /(?:finite positive|positive finite|positive (?:per-)?action) deadline/i,
      /before (?:manifest freeze|dispatch)/i,
      /whole[- ]descendant[^.]{0,240}(?:graceful|terminate).{0,180}(?:force|kill)/i,
      /(?:request|ask)[^.]{0,100}(?:revoke|revocation)[^.]{0,100}capabilit/i,
      /reported teardown failure[^.]{0,120}block/i,
      /advisory[^.]{0,180}(?:unavailable|could not enforce|cannot enforce)/i,
    ]),
    fixture: 'Assign a finite positive deadline before manifest freeze. Request revocation of capabilities and whole-descendant graceful termination, then force-kill. A reported teardown failure blocks; advisory assurance records controls the host could not enforce.',
  },
  {
    label: 'payload-only advisory grader',
    check: (source) => hasAll(source, [
      /grader[^.]{0,260}(?:payload only|payload-only|only (?:the )?(?:schema-defined |opaque )?(?:output|payload))/i,
      /grader.{0,520}request[^.]{0,160}no tools?[^.]{0,160}workspace/i,
      /grader.{0,520}capabilities[^.]{0,100}\[\][^.]{0,180}(?:granted|requested)/i,
      /advisory[^.]{0,180}(?:ambient|unenforced)/i,
    ]),
    fixture: 'The grader receives only the schema-defined payload and requests no tools or workspace. Its capabilities [] records granted scope under enforced assurance or requested scope under advisory assurance, which exposes any unenforced ambient access.',
  },
];

function validateSemantics(source) {
  const normalized = compact(source);
  return semanticRequirements
    .filter(({ check }) => !check(normalized))
    .map(({ label }) => label);
}

for (const requirement of semanticRequirements) {
  if (!requirement.check(compact(requirement.fixture))) {
    throw new Error(`malformed positive semantic fixture: ${requirement.label}`);
  }
  if (!validateSemantics(
    semanticRequirements
      .filter((candidate) => candidate !== requirement)
      .map(({ fixture }) => fixture)
      .join('\n'),
  ).includes(requirement.label)) {
    throw new Error(`missing semantic contract escaped: ${requirement.label}`);
  }
}
function positiveFixture() {
  const grouped = new Map();
  for (const [heading, , clause] of clauses) {
    if (!grouped.has(heading)) grouped.set(heading, []);
    grouped.get(heading).push(clause);
  }
  let fixture = `---\nname: woostack-eval\ndescription: Contract fixture.\n---\n# Evaluator\n\n[Schema authority](references/schemas.md) and [runner authority](references/runner.md).\n\n## Invocation\n\n${invocation}\n\n`;
  fixture += `${grouped.get('Invocation').join('\n\n')}\n\n`;
  for (const heading of ['Corpus approval', 'Preparation and dispatch', 'Completion', 'Terminal handback']) {
    fixture += `## ${heading}\n\n${grouped.get(heading).join('\n\n')}\n\n`;
  }
  return fixture;
}

// Prove the harness accepts the complete contract, rejects every normative contradiction, keeps
// clauses scoped to their owning section, and requires the invocation's final bracket and fence.
const positive = positiveFixture();
const positiveErrors = validate(positive);
if (positiveErrors.length) throw new Error(`malformed positive contract fixture: ${positiveErrors.join(', ')}`);
for (const [, label, clause] of clauses) {
  const contradicted = positive.replace(clause, `CONTRADICTION: ${label} is optional.`);
  const errors = validate(contradicted);
  if (!errors.includes(label)) throw new Error(`contradictory fixture escaped contract: ${label}`);
}
for (const [label, clause] of forbiddenClauses) {
  const contradicted = positive.replace('## Preparation and dispatch', `## Preparation and dispatch\n\n${clause}`);
  if (!validate(contradicted).includes(label)) {
    throw new Error(`legacy contract fixture escaped: ${label}`);
  }
}
const movedClause = clauses.find(([, label]) => label === 'runtime helper boundary');
const moved = positive.replace(movedClause[2], '').replace(
  '## Terminal handback',
  `## Terminal handback\n\n${movedClause[2]}`,
);
if (!validate(moved).includes('runtime helper boundary')) {
  throw new Error('section-scoping fixture escaped the contract');
}
if (!validate(positive.replace('  [--baseline-ref <git-ref> | --baseline-path <skill-dir>]\n```', '  [--baseline-ref <git-ref> | --baseline-path <skill-dir>\n```')).includes('exact invocation block')) {
  throw new Error('unterminated invocation fixture escaped the contract');
}

if (!fs.existsSync(skillFile)) {
  console.error('FAIL: RED: skills/woostack-eval/SKILL.md is missing; the public command workflow is not implemented');
  process.exit(1);
}
const skillSource = fs.readFileSync(skillFile, 'utf8');
const errors = validate(skillSource);
const skillRoot = path.dirname(skillFile);
const authorityFiles = [
  path.join(skillRoot, 'references', 'runner.md'),
  path.join(skillRoot, 'references', 'schemas.md'),
];
for (const authorityFile of authorityFiles) {
  if (!fs.existsSync(authorityFile)) {
    errors.push(`linked authority missing: ${path.relative(skillRoot, authorityFile)}`);
  }
}
if (errors.length === 0) {
  const authoritySource = authorityFiles.map((file) => fs.readFileSync(file, 'utf8')).join('\n');
  errors.push(...validateSemantics(`${skillSource}\n${authoritySource}`));
}
if (errors.length) {
  console.error(`FAIL: RED: skills/woostack-eval command sources lack required workflow clauses: ${[...new Set(errors)].join(', ')}`);
  process.exit(1);
}
console.log('PASS: woostack-eval command contract');
NODE
