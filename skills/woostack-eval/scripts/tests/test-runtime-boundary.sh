#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SKILL_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
NODE=${NODE:-node}
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/woostack-eval-runtime-boundary.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM

# Runtime helpers are deterministic evidence processors. Scan every non-test module, including the
# aggregate implementation subtree; host orchestration, not a helper, owns worker dispatch.
"$NODE" - "$SKILL_ROOT/scripts" "$TMP_ROOT" <<'NODE'
const fs = require('node:fs');
const path = require('node:path');

const [scriptsRoot, fixtureRoot] = process.argv.slice(2);

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
  ['network CLI', /(?:^|[;&|]\s*|\b(?:exec(?:File)?(?:Sync)?|spawn(?:Sync)?)\s*\([^\n]{0,120})['"](?:curl|wget)['"]/m],
];

function violationsInFile(file) {
  const source = fs.readFileSync(file, 'utf8');
  return forbidden
    .filter(([, pattern]) => pattern.test(source))
    .map(([label]) => ({ file, label }));
}

function violations(directory) {
  return modulesUnder(directory).flatMap((file) => violationsInFile(file));
}

const runtimeModules = modulesUnder(scriptsRoot);
if (runtimeModules.length === 0) throw new Error(`no runtime modules found under ${scriptsRoot}`);
const runtimeFailures = violations(scriptsRoot);
if (runtimeFailures.length) {
  throw new Error(`forbidden evaluator runtime entry point: ${JSON.stringify(runtimeFailures)}`);
}

const acceptedRoot = path.join(fixtureRoot, 'accepted', 'nested');
const rejectedRoot = path.join(fixtureRoot, 'rejected', 'dormant');
fs.mkdirSync(acceptedRoot, { recursive: true });
fs.mkdirSync(rejectedRoot, { recursive: true });
fs.writeFileSync(
  path.join(acceptedRoot, 'filesystem.mjs'),
  "import fs from 'node:fs';\nimport path from 'node:path';\nexport const runtimeReady = Boolean(fs && path);\n",
);
if (violations(path.join(fixtureRoot, 'accepted')).length) {
  throw new Error('safe local filesystem imports were rejected');
}

const rejected = [
  ['provider-sdk-import', "import provider from 'openai';\nexport default provider;\n", 'provider SDK import'],
  ['node-network-import', "import net from 'node:net';\nexport default net;\n", 'Node network module'],
  ['web-network-api', "export async function probe(url) { return fetch(url); }\n", 'web network API'],
  ['runtime-network-api', "export function probe() { return Bun.connect({ hostname: 'example.invalid' }); }\n", 'runtime network API'],
  ['provider-method', "export async function probe() { return generateText({ prompt: 'probe' }); }\n", 'provider method'],
  ['network-cli', "import { execFile } from 'node:child_process';\nexport function probe() { return execFile('curl', ['https://example.invalid']); }\n", 'network CLI'],
];
for (const [name, source, label] of rejected) {
  const file = path.join(rejectedRoot, `${name}.mjs`);
  fs.writeFileSync(file, source);
  const failures = violationsInFile(file);
  if (!failures.some((failure) => failure.label === label)) {
    throw new Error(`forbidden ${label} fixture was accepted: ${file}`);
  }
}
NODE

printf 'PASS: Eval runtime modules remain network-free\n'
