#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../../../.." && pwd)
VALIDATOR="$REPO_ROOT/skills/using-woostack/scripts/validate-skill-package.mjs"
GENERATOR="$REPO_ROOT/site/scripts/gen-skills.mjs"
NODE=${NODE:-node}

"$NODE" --input-type=module - "$VALIDATOR" "$GENERATOR" <<'NODE'
import assert from 'node:assert/strict';
import { pathToFileURL } from 'node:url';

const [validatorPath, generatorPath] = process.argv.slice(2);
const { parseFrontmatter } = await import(pathToFileURL(validatorPath).href);
const { parseFrontmatter: siteParseFrontmatter } = await import(pathToFileURL(generatorPath).href);

assert.equal(typeof parseFrontmatter, 'function', 'validator exports parseFrontmatter(raw, file)');

const quoted = `---
name: parser-contract
description: "Use when the source contains status: approved."
plugin: preserved-for-the-site
---
# Parser contract

Body remains byte-for-byte compatible.
`;
const placeholder = `---
name: parser-contract
description: Execute the approved plan at <plan-path>.
---
Body with no title.
`;

for (const [label, raw] of [['quoted colon-space', quoted], ['plain placeholder', placeholder]]) {
  const canonical = parseFrontmatter(raw, `${label}.md`);
  const site = siteParseFrontmatter(raw, `${label}.md`);
  assert.deepEqual(
    canonical,
    site,
    `${label}: canonical parser returns the site-compatible {fm, body} shape`,
  );
  assert.deepEqual(Object.keys(canonical).sort(), ['body', 'fm']);
  assert.equal(typeof canonical.fm, 'object');
  assert.equal(typeof canonical.body, 'string');
}

const plainColonHazard = `---
name: parser-contract
description: Use when status: approved is present.
---
Body.
`;
assert.throws(
  () => parseFrontmatter(plainColonHazard, 'plain-colon.md'),
  /description|colon|plain scalar/i,
  'canonical parser rejects colon-space in an unquoted description',
);

const fenced = `\`\`\`yaml
---
name: parser-contract
description: This is fenced, not frontmatter.
---
\`\`\`
`;
assert.throws(
  () => parseFrontmatter(fenced, 'fenced.md'),
  /missing frontmatter/i,
  'canonical parser accepts only an opening unfenced frontmatter block',
);

console.log('PASS: shared frontmatter parser contract');
NODE
