#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
EVAL_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
NODE=${NODE:-node}

"$NODE" - "$EVAL_ROOT" <<'NODE'
const fs = require('node:fs');
const path = require('node:path');
const root = process.argv[2];
const scriptsRoot = path.join(root, 'scripts');
for (const name of ['prepare.mjs', 'aggregate.mjs', 'render-report.mjs']) {
  const file = path.join(scriptsRoot, name);
  if (!fs.statSync(file).isFile()) throw new Error(`missing maintainer runtime helper: ${file}`);
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
    if (pattern.test(source)) throw new Error(`${label} is forbidden in maintainer runtime: ${file}`);
  }
}

const authority = [
  fs.readFileSync(path.join(root, 'SKILL.md'), 'utf8'),
  fs.readFileSync(path.join(root, 'references', 'runner.md'), 'utf8'),
].join('\n').replace(/\s+/g, ' ');
const requirements = [
  ['pinned scoped capabilities', /only its approved subset of `read-workspace`, `write-workspace`, and `shell-workspace`[^.]*never grant evidence-root access, network, credentials/i],
  ['same-wave pairing', /Candidate and baseline form one inseparable pair:[^.]*same wave[^.]*never split a comparative pair/i],
  ['host-owned receipts', /host supervisor.{0,600}commits output first and exactly one create-new action receipt as the final evidence action/i],
  ['blind grading', /fresh grader context with only the schema-defined payload:[^.]*opaque output bytes[^.]*anonymized output ID[^.]*frozen boolean rubric/i],
  ['source revalidation', /rehash and independently re-inventory the original source package before aggregation/i],
  ['fail-closed dispatch', /Never downgrade to direct host-native dispatch, candidate-only execution, or advisory isolation/i],
];
for (const [label, pattern] of requirements) {
  if (!pattern.test(authority)) throw new Error(`maintainer authority is missing ${label}`);
}
console.log(`PASS: scanned ${modulesUnder(scriptsRoot).length} maintainer runtime modules and enforced security authority`);
NODE
