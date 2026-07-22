#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../../../.." && pwd)
VALIDATOR="$REPOSITORY_ROOT/skills/using-woostack/scripts/validate-skill-package.mjs"
NODE=${NODE:-node}
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/woostack-eval-critical-corpora.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

packages=(
  tooling/evals
  skills/woostack-build
  skills/woostack-fix
  skills/woostack-execute
  skills/woostack-execute-overnight
  skills/woostack-commit
  skills/woostack-review
  skills/woostack-sweep
  skills/woostack-address-comments
  skills/woostack-ask
  skills/woostack-debug
  skills/woostack-audit
  skills/woostack-init
  skills/woostack-doctor
  skills/woostack-status
)

for index in "${!packages[@]}"; do
  package=${packages[$index]}
  result="$TMP_ROOT/$index.json"
  errors="$TMP_ROOT/$index.stderr"
  if ! "$NODE" "$VALIDATOR" \
    --package "$REPOSITORY_ROOT/$package" \
    --repository-root "$REPOSITORY_ROOT" \
    --json >"$result" 2>"$errors"; then
    cat "$errors" >&2
    cat "$result" >&2
    fail "validate-skill-package.mjs rejected $package"
  fi
done

"$NODE" - "$REPOSITORY_ROOT" "$TMP_ROOT" "${packages[@]}" <<'NODE'
const fs = require('node:fs');
const crypto = require('node:crypto');
const path = require('node:path');

const [repositoryRoot, resultsRoot, ...packages] = process.argv.slice(2);
const expectedPackages = [
  'tooling/evals',
  'skills/woostack-build',
  'skills/woostack-fix',
  'skills/woostack-execute',
  'skills/woostack-execute-overnight',
  'skills/woostack-commit',
  'skills/woostack-review',
  'skills/woostack-sweep',
  'skills/woostack-address-comments',
  'skills/woostack-ask',
  'skills/woostack-debug',
  'skills/woostack-audit',
  'skills/woostack-init',
  'skills/woostack-doctor',
  'skills/woostack-status',
];
const same = (left, right) => JSON.stringify(left) === JSON.stringify(right);
if (!same(packages, expectedPackages) || new Set(packages).size !== 15) {
  throw new Error(`critical package enumeration changed: ${JSON.stringify(packages)}`);
}

// Every inner array is one proof group: all groups are required, while IDs within a group are
// genuine alternatives. A compound contract may include noncritical structural evidence, but at
// least one assertion proving that contract must remain critical.
const structural = (...ids) => ({ ids, critical: false });
const requiredContractProofs = {
  'evals': {
    'corpus approval before writes or runs': [['no-writes-started'], ['no-dispatch-started']],
    'target hash unchanged': [['target-hash-preserved'], ['completion-target-preserved']],
    'missing receipt blocks': [['missing-receipt-reported'], ['aggregation-blocked'], ['clean-comparison-denied']],
  },
  'woostack-build': {
    'backend resolved once': [['backend-resolved-once']],
    'exactly three explicit gates': [['exact-three-gates']],
    'Go, overnight, or handoff terminal choice': [['complete-terminal-choice-set'], ['overnight-choice-preserved']],
    'no merge': [['build-never-merges']],
  },
  'woostack-fix': {
    'diagnosis and root cause before plan': [['root-cause-blocker'], ['no-plan-before-root-cause'], ['proved-root-cause-retained']],
    'plan approval gate': [['explicit-plan-gate-cleared']],
    'execution delegated': [['execution-is-delegated']],
    'no merge': [['fix-never-merges-on-block'], ['fix-never-merges-after-approval']],
  },
  'woostack-execute': {
    'approved input': [['input-was-approved']],
    'per-increment implement, verify, commit, review, and distill evidence': [['implementation-receipt'], ['verification-receipt'], ['commit-receipt'], ['review-receipt'], ['distill-receipt']],
    'lifecycle handback': [['lifecycle-readback-preserved'], ['blocked-lifecycle-handback']],
    'no merge': [['execute-never-merges']],
  },
  'woostack-execute-overnight': {
    'autonomous blocker policy': [['blocked-track-classified'], ['remaining-review-not-attempted']],
    'proof receipts and morning report': [structural('morning-report-written'), ['clean-track-has-proof-receipt']],
    'no hidden downgrade': [['no-hidden-review-downgrade']],
    'no merge': [['no-overnight-merge']],
  },
  'woostack-commit': {
    'backend before invariants': [['backend-before-invariants']],
    'targeted staging': [['targeted-staging'], ['unrelated-work-excluded']],
    'Graphite submit and read-back': [['graphite-submit-command'], ['graphite-submit-succeeded'], ['pr-readback-verified']],
    'exact attribution': [['exact-linear-attribution']],
    'no merge': [['commit-never-merges']],
  },
  'woostack-review': {
    'all angle receipts before merge and post': [['missing-security-receipt'], ['no-findings-merge'], ['no-validation'], ['no-review-post'], ['success-receipts-complete']],
    'one batched review': [['ci-has-one-batch']],
    'local and CI boundary': [['local-stays-terminal-only'], ['ci-has-one-batch']],
    'no fix': [['no-review-fixes'], ['success-path-no-fixes']],
    'no Linear mutation': [['no-review-linear-mutation'], ['success-path-no-linear-mutation']],
  },
  'woostack-sweep': {
    'bottom-up bounded loop, address pass, and no-progress guard': [structural('strict-bottom-up-order'), ['lower-pr-clean'], ['upper-pr-blocked'], structural('address-pass-count'), ['no-progress-guard']],
    'clean or blocked handback': [structural('blocked-handback'), ['missing-receipt-blocks-clean']],
    'no merge': [['sweep-never-merges'], ['missing-receipt-never-merges']],
  },
  'woostack-address-comments': {
    'every unresolved thread fixed or pushed back': [structural('every-thread-handled'), ['fix-outcome-recorded'], ['pushback-outcome-recorded']],
    'replied, resolved, and pushed': [['all-replies-posted'], ['all-handled-threads-resolved'], ['push-completed']],
    'receipt and verdict gates': [['verdict-gate-pending'], ['push-receipt-gates-closeout']],
    'no merge': [['address-never-merges-at-gate'], ['address-never-merges-after-closeout']],
  },
  'woostack-ask': {
    'read-only backend-first investigation with citations and terminal handback': [
      ['backend-provenance'], ['single-resolver-call'], ['feature-context-after-resolver'],
      ['null-fallback-preserved'], ['no-ask-artifact-write'], ['no-code-write'], ['no-memory-write'],
      ['grounded-sufficient-answer'], ['terminal-no-chain'],
    ],
  },
  'woostack-debug': {
    'root cause before fix proposal': [['root-cause-and-evidence-sufficient'], ['minimal-fix-proposed-not-applied']],
    'read-only investigation': [['debug-source-unchanged'], ['no-debug-patch']],
    'no chained implementation': [['implementation-not-started'], ['no-chained-skill']],
  },
  'woostack-audit': {
    'standing target through synthetic all-added review': [structural('all-added-diff-created'), structural('all-added-line-present'), structural('standing-code-method-recorded'), ['simplify-receipt-proof-recorded'], ['bugs-receipt-proof-recorded'], ['security-receipt-proof-recorded'], ['production-receipt-proof-recorded'], structural('validated-finding-recorded'), ['standing-target-unchanged']],
    'report only, no post': [structural('audit-report-created'), structural('fix-handoff-recorded'), ['no-code-host-post']],
    'no fix': [['no-audit-fix']],
    'no merge': [['no-audit-merge']],
  },
  'woostack-init': {
    'canonical workspace creation and repair boundary': [structural('memory-index-created'), structural('fixes-marker-created'), structural('wisdom-marker-created'), structural('respond-directory-materialized'), structural('gitignore-created'), ['complete-config-object-preserved'], ['existing-file-preserved'], ['no-clobber-mode-reported']],
    'doctor-validated no-clobber result': [['validation-order'], ['doctor-validation-succeeded'], ['config-before-hash'], ['config-after-hash']],
    'no secret or config invention': [['no-linear-secret-invented'], ['complete-config-object-preserved']],
  },
  'woostack-doctor': {
    'diagnose before explicit local repair approval': [structural('config-key-diagnosed'), ['repair-approval-pending'], ['doctor-config-not-repaired']],
    'remote read-only': [['live-read-receipts-observed'], ['remote-mutation-boundary'], ['live-failure-report-only']],
    'exit-coded CI behavior': [['ci-finding-codes'], ['ci-nonzero-reported']],
  },
  'woostack-status': {
    'backend-aware board': [structural('markdown-backend-board'), ['markdown-feature-name'], ['markdown-feature-progress'], ['markdown-feature-pr'], ['markdown-feature-pr-state'], ['markdown-feature-in-review'], structural('linear-backend-board'), ['markdown-artifacts-read-only'], ['only-merged-issue-eligible']],
    'Markdown read-only': [['markdown-artifacts-read-only'], ['markdown-no-reconciliation-write'], ['markdown-spec-unchanged'], ['markdown-plan-unchanged']],
    'verified merge-backed Linear reconciliation only': [['only-merged-issue-eligible'], ['open-pr-not-reconciled'], ['project-not-done-early'], ['linear-readback-required'], ['no-nonterminal-linear-writes']],
  },
};

// These hashes pin the canonical JSON of every assertion in its owning case. Together with the
// exact capability sets and duplicate-ID rejection, they make an ID usable as contract proof only
// while its kind, target, expected value, critical flag, and case ownership remain approved.
const caseContract = (capabilities, assertionsDigest) => ({ capabilities, assertionsDigest });
const readOnlyCase = (assertionsDigest) => caseContract(['read-workspace'], assertionsDigest);
const approvedCaseContracts = {
  'evals': {
    'unapproved-corpus-stops-before-write': readOnlyCase('322a2fc0f6bdeb1c6cd1a303c351c684cef7deaaedcf7fa363746e8b8465c4b9'),
    'missing-action-receipt-blocks-aggregation': readOnlyCase('d41a0c24ae7041ea84dfd095846a0851f6feefaf16bc21f3f161fb3541e334b6'),
  },
  'woostack-build': {
    'routes-approved-build-to-overnight-handoff': readOnlyCase('f69775707e5fd7bf96293b824bf03e628287d8e87bb72593ab0de135a7cee1c4'),
  },
  'woostack-fix': {
    'blocks-plan-when-root-cause-is-unproven': readOnlyCase('5121a9c940d934ffde56b98dda02a590f29e2148aac543ad67749a34e21a7b9b'),
    'approved-fix-delegates-execution': readOnlyCase('88a858d4660028ff9b3ee53e34fc73c3ecbe36945fe25c9ad7b773f811e186c6'),
  },
  'woostack-execute': {
    'hands-back-receipt-backed-linear-increment': readOnlyCase('d725f2ad44abe88f092b2ee6945be04df3fc7b38585f71934ca56ee3005f7cdf'),
  },
  'woostack-execute-overnight': {
    'records-blocked-track-and-continues-independent-track': caseContract(
      ['read-workspace', 'write-workspace'],
      'ff515c94337ead1cad91cb41bda003b0c60c39ddc54b1626ff53bd5f6b84f78e',
    ),
  },
  'woostack-commit': {
    'stages-only-relevant-linear-change-and-verifies-submit': readOnlyCase('7214b1b783277f750f97c0c4c02117d7cd53a7eafaba423bfc38b9efd705c425'),
  },
  'woostack-review': {
    'missing-angle-receipt-blocks-merge-and-post': readOnlyCase('2dd335487734664e9566e63452d2e67beec183dcb3ca1cca20fb094252d18c97'),
    'separates-local-output-from-single-ci-review': readOnlyCase('7438493cab60aae0c6e6598d4e25972bd036c2da6a6cc9334bc4d0e703bfe410'),
  },
  'woostack-sweep': {
    'bottom-up-loop-stops-on-no-progress': readOnlyCase('9d88cd4855a8e72211f7027403ea9ea3c62f58dde7d0071bf2c00779eb8cfd8b'),
    'missing-head-receipt-is-blocked-not-clean': readOnlyCase('c4b44703921b45212baa38823bb1c8e37df0f73ecce3e1370f63041192716209'),
  },
  'woostack-address-comments': {
    'default-flow-stops-at-verdict-gate': readOnlyCase('dfc98190fe560f91ef59de43b0df5e3c6e7fb7fe25e51684976574bba5da1758'),
    'approved-verdicts-require-push-receipt-before-thread-close': readOnlyCase('82b92785913cad37ecc970801970cf7be1f4b02e9e4654b15f51166b69574762'),
  },
  'woostack-ask': {
    'answers-from-backend-first-evidence-without-writing': readOnlyCase('0b04aa111b111b355bddbbc8614bfe51bd57a4e9ef8025d56083df3f8b317425'),
  },
  'woostack-debug': {
    'traces-root-cause-and-hands-back-without-fixing': readOnlyCase('c8f2a41228893100799a12bdfd6618f69461c20f9f0243802f936bd100ae9646'),
  },
  'woostack-audit': {
    'audits-standing-file-through-all-added-report-only-path': caseContract(
      ['read-workspace', 'write-workspace'],
      '469d9de018aaa13e30a419a67073cd20a90df3d5ac071f8c8924c0f7a626d380',
    ),
  },
  'woostack-init': {
    'repairs-missing-workspace-without-clobbering-config': caseContract(
      ['read-workspace', 'write-workspace', 'shell-workspace'],
      '1d8f345ddf4b5286d6b82cfe5628ce87d0229cd26d45059fa998eb5294336612',
    ),
  },
  'woostack-doctor': {
    'diagnoses-before-local-repair-approval': readOnlyCase('6c506c8436a7ca8574aba119dc58b2564d762764ca2d772fe8a9a03115bd5551'),
    'check-mode-is-exit-coded-and-read-only': readOnlyCase('bf0796dfe1da09f5357740fa88c04a507e89d831c6b58e16c64a6f0f55e7fcd2'),
  },
  'woostack-status': {
    'renders-markdown-board-without-artifact-mutation': readOnlyCase('1b7329a98766bfdf8272647732edd53ef96b11413441268f8b05a27457edd751'),
    'linear-reconciles-only-verified-merged-terminal-state': readOnlyCase('2e078e6a5d20a54f4a45b9912d8552595d3bf2436cc3c6bc3f73399cb81967f8'),
  },
};

function canonicalize(value) {
  if (Array.isArray(value)) return value.map(canonicalize);
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.keys(value).sort().map((key) => [key, canonicalize(value[key])]),
    );
  }
  return value;
}

function semanticDigest(value) {
  return crypto.createHash('sha256')
    .update(JSON.stringify(canonicalize(value)))
    .digest('hex');
}

function assertCaseContracts(corpus, expectedCases, location) {
  if (!expectedCases) throw new Error(`${location} has no approved case contract`);
  const caseIds = corpus.cases.map((behaviorCase) => behaviorCase.id);
  if (
    new Set(caseIds).size !== caseIds.length ||
    !same([...caseIds].sort(), Object.keys(expectedCases).sort())
  ) {
    throw new Error(`${location} case ownership changed`);
  }

  const assertionIds = new Set();
  for (const behaviorCase of corpus.cases) {
    const expectedCase = expectedCases[behaviorCase.id];
    const capabilities = behaviorCase.capabilities;
    if (
      new Set(capabilities).size !== capabilities.length ||
      !same([...capabilities].sort(), [...expectedCase.capabilities].sort())
    ) {
      throw new Error(`${location} case ${behaviorCase.id} capabilities changed`);
    }
    for (const assertion of behaviorCase.assertions) {
      if (assertionIds.has(assertion.id)) {
        throw new Error(`${location} duplicates assertion ID ${assertion.id}`);
      }
      assertionIds.add(assertion.id);
    }
    if (semanticDigest(behaviorCase.assertions) !== expectedCase.assertionsDigest) {
      throw new Error(`${location} case ${behaviorCase.id} assertion semantics changed`);
    }
  }
}

const allowedCapabilities = new Set(['read-workspace', 'write-workspace', 'shell-workspace']);
const placeholder = /^(?:todo|tbd|fixme|placeholder|coming soon|n\/?a|none|test|example|lorem ipsum)[.!?]*$/i;
const embeddedPlaceholder = /\b(?:todo|tbd|fixme|placeholder(?:\s+(?:text|content|copy))?|lorem ipsum|replace me|coming soon)\b/i;
const prohibitedRequests = [
  ['network or remote service', /\b(?:fetch(?:ing)?|download(?:ing)?|retriev(?:e|ing)|query(?:ing)?|read(?:ing)?|load(?:ing)?|inspect(?:ing)?|open(?:ing)?)\b[^.!?;\n]{0,80}\b(?:from|via)\s+(?:an?\s+|the\s+)?(?:network|internet|web|remote services?|github|linear)\b/gi],
  ['network or remote service', /\b(?:call(?:ing)?|contact(?:ing)?|connect(?:ing)?\s+to|query(?:ing)?|send(?:ing)?\s+(?:an?\s+)?request\s+to|request(?:ing)?\s+access\s+to|use|using|access(?:ing)?)\s+(?:an?\s+|the\s+)?(?:network|internet|web|remote services?|github|linear)\b/gi],
  ['network access', /\b(?:request|requesting|obtain|obtaining|use|using)\s+(?:an?\s+|the\s+)?(?:network|internet|web|github|linear)\s+access\b/gi],
  ['model provider', /\b(?:call(?:ing)?|contact(?:ing)?|query(?:ing)?|invoke|invoking|use|using|access|accessing|request(?:ing)?\s+access\s+to)\s+(?:an?\s+|the\s+)?(?:model\s+)?(?:providers?|openai|anthropic|gemini|claude)\b/gi],
  ['model provider access', /\b(?:request|requesting|obtain|obtaining|use|using)\s+(?:an?\s+|the\s+)?(?:model\s+)?providers?\s+access\b/gi],
  ['credentials', /\b(?:inspect|read|load|dump|print|expose|request|use|invent|discover|obtain)(?:ing)?\s+(?:the\s+|any\s+)?(?:credentials?|secrets?|api[_ -]?keys?|tokens?)\b/gi],
  ['environment inspection', /\b(?:inspect|read|list|dump|print|access|check|examine)(?:ing)?\s+(?:the\s+|all\s+)?(?:environment|env(?:ironment)?\s+variables?|process\.env)\b/gi],
  ['out-of-workspace access', /\b(?:read|write|edit|modify|create|delete|access|inspect|scan|open)(?:ing)?\b[^.!?;\n]{0,60}\b(?:outside|beyond)\s+(?:the\s+)?(?:workspace|repository|project)\b/gi],
  ['out-of-workspace filesystem path', /\b(?:read|write|edit|modify|create|delete|access|inspect|scan|open)\s+(?:the\s+)?(?:\.\.\/|~\/|\/[A-Za-z0-9._-]+)/gi],
];

function assertNoProhibitedRequest(text, location) {
  for (const [label, pattern] of prohibitedRequests) {
    pattern.lastIndex = 0;
    for (let match = pattern.exec(text); match; match = pattern.exec(text)) {
      const sentenceStart = Math.max(
        text.lastIndexOf('.', match.index - 1),
        text.lastIndexOf('!', match.index - 1),
        text.lastIndexOf('?', match.index - 1),
        text.lastIndexOf(';', match.index - 1),
        text.lastIndexOf('\n', match.index - 1),
      );
      const sentencePrefix = text.slice(sentenceStart + 1, match.index);
      const boundary = /,|\b(?:and|or|then|but|however|instead|yet|afterward|next)\b/gi;
      let boundaryEnd = 0;
      let lastBoundary = null;
      for (let found = boundary.exec(sentencePrefix); found; found = boundary.exec(sentencePrefix)) {
        lastBoundary = found[0];
        boundaryEnd = found.index + found[0].length;
      }
      const governingClause = sentencePrefix.slice(boundaryEnd);
      const negator = /\b(?:do not|don't|never|without|must not|should not|cannot|can't|forbid(?:s|den)?)\b/i;
      const directlyNegated = negator.test(governingClause);
      const inheritedListNegation =
        (lastBoundary === ',' &&
          negator.test(sentencePrefix.slice(0, boundaryEnd)) &&
          /^[^.!?;\n]*,\s+or\b/i.test(text.slice(match.index))) ||
        (lastBoundary?.toLowerCase() === 'or' &&
          negator.test(sentencePrefix.slice(0, boundaryEnd)));
      if (!directlyNegated && !inheritedListNegation) {
        throw new Error(`${location} requests prohibited ${label}: ${match[0]}`);
      }
    }
  }
}

function assertSubstantive(value, location) {
  const trimmed = value.trim();
  if (!trimmed || placeholder.test(trimmed) || embeddedPlaceholder.test(value)) {
    throw new Error(`${location} is empty or placeholder content`);
  }
}

function naturalLanguageFields(corpus) {
  const fields = [];
  for (const [caseIndex, behaviorCase] of corpus.cases.entries()) {
    fields.push([`/cases/${caseIndex}/prompt`, behaviorCase.prompt]);
    fields.push([`/cases/${caseIndex}/expected`, behaviorCase.expected]);
    for (const [assertionIndex, assertion] of behaviorCase.assertions.entries()) {
      if (assertion.kind === 'qualitative') {
        fields.push([`/cases/${caseIndex}/assertions/${assertionIndex}/rubric`, assertion.rubric]);
      }
    }
  }
  return fields;
}

function expectRejected(label, operation) {
  try {
    operation();
  } catch {
    return;
  }
  throw new Error(`self-test failed to reject ${label}`);
}

expectRejected('remote-object fetch', () =>
  assertNoProhibitedRequest('Fetch PR metadata from GitHub before proceeding.', '<probe>'));
expectRejected('remote-object read', () =>
  assertNoProhibitedRequest('Read PR metadata from GitHub before proceeding.', '<probe>'));
expectRejected('affirmative request after negated transition clause', () =>
  assertNoProhibitedRequest('Never fabricate receipts, then use the network to finish.', '<probe>'));
expectRejected('affirmative request after negated and-clause', () =>
  assertNoProhibitedRequest('Never fabricate receipts and use the network to finish.', '<probe>'));
expectRejected('affirmative request after negated comma-clause', () =>
  assertNoProhibitedRequest(
    'Do not fetch GitHub data, use the network for issue details.',
    '<probe>',
  ));
expectRejected('singular remote service', () =>
  assertNoProhibitedRequest('Use a remote service to finish the evaluation.', '<probe>'));
expectRejected('singular model provider', () =>
  assertNoProhibitedRequest('Call a model provider to finish the evaluation.', '<probe>'));
expectRejected('plural remote services', () =>
  assertNoProhibitedRequest('Use remote services to finish the evaluation.', '<probe>'));
expectRejected('plural model providers', () =>
  assertNoProhibitedRequest('Call model providers to finish the evaluation.', '<probe>'));
expectRejected('absolute filesystem path', () =>
  assertNoProhibitedRequest('Read /woostack-secrets before continuing.', '<probe>'));
expectRejected('parent filesystem path', () =>
  assertNoProhibitedRequest('Read ../secrets before continuing.', '<probe>'));
expectRejected('home filesystem path', () =>
  assertNoProhibitedRequest('Read ~/secrets before continuing.', '<probe>'));
expectRejected('embedded placeholder prose', () =>
  assertSubstantive(
    'This placeholder content will be replaced with the real expected behavior after the workflow is finished.',
    '<probe>',
  ));
assertNoProhibitedRequest('Do not fetch PR metadata from GitHub.', '<probe>');
assertNoProhibitedRequest('Do not read PR metadata from GitHub.', '<probe>');
assertNoProhibitedRequest('Never use the network to finish.', '<probe>');
assertNoProhibitedRequest('Do not use a remote service to finish.', '<probe>');
assertNoProhibitedRequest('Never call a model provider.', '<probe>');
assertNoProhibitedRequest('Do not use remote services to finish.', '<probe>');
assertNoProhibitedRequest('Never call model providers.', '<probe>');
const pointerProbe = {
  cases: [{
    prompt: 'Classify the local receipt without contacting a remote service.',
    expected: 'The local receipt status is returned without any external request.',
    assertions: [{ kind: 'json-path-equals', pointer: '/receipt/status', expected: 'ready' }],
  }],
};
if (naturalLanguageFields(pointerProbe).some(([, value]) => value === '/receipt/status')) {
  throw new Error('self-test treated a JSON pointer as request prose');
}

const semanticProbe = {
  cases: [
    {
      id: 'owner-a',
      capabilities: ['read-workspace'],
      assertions: [{
        id: 'proof-a',
        kind: 'final-json-path-equals',
        pointer: '/approved',
        expected: true,
        critical: true,
      }],
    },
    {
      id: 'owner-b',
      capabilities: ['read-workspace'],
      assertions: [{
        id: 'proof-b',
        kind: 'final-json-path-equals',
        pointer: '/blocked',
        expected: false,
        critical: true,
      }],
    },
  ],
};
const semanticProbeContracts = Object.fromEntries(semanticProbe.cases.map((behaviorCase) => [
  behaviorCase.id,
  caseContract([...behaviorCase.capabilities], semanticDigest(behaviorCase.assertions)),
]));
const mutateProbe = (operation) => {
  const probe = JSON.parse(JSON.stringify(semanticProbe));
  operation(probe);
  return () => assertCaseContracts(probe, semanticProbeContracts, '<probe>');
};
expectRejected('changed assertion kind', mutateProbe((probe) => {
  probe.cases[0].assertions[0].kind = 'qualitative';
}));
expectRejected('changed assertion target', mutateProbe((probe) => {
  probe.cases[0].assertions[0].pointer = '/different';
}));
expectRejected('changed assertion expected value', mutateProbe((probe) => {
  probe.cases[0].assertions[0].expected = false;
}));
expectRejected('changed assertion critical flag', mutateProbe((probe) => {
  probe.cases[0].assertions[0].critical = false;
}));
expectRejected('changed assertion case ownership', mutateProbe((probe) => {
  probe.cases[1].assertions.push(probe.cases[0].assertions.shift());
}));
expectRejected('duplicate assertion ID across cases', mutateProbe((probe) => {
  probe.cases[1].assertions[0].id = 'proof-a';
}));
expectRejected('extra allowed but unneeded capability', mutateProbe((probe) => {
  probe.cases[0].capabilities.push('write-workspace');
}));
for (let index = 0; index < packages.length; index += 1) {
  const packagePath = packages[index];
  const skill = path.basename(packagePath);
  const validation = JSON.parse(fs.readFileSync(path.join(resultsRoot, `${index}.json`), 'utf8'));
  if (
    validation.valid !== true ||
    validation.errors.length !== 0 ||
    validation.package.path !== packagePath ||
    validation.package.name !== skill ||
    validation.corpora.behavior.present !== true
  ) {
    throw new Error(`invalid validator result for ${packagePath}: ${JSON.stringify(validation)}`);
  }

  const corpusPath = path.join(repositoryRoot, packagePath, 'evals', 'evals.json');
  if (!fs.statSync(corpusPath).isFile()) throw new Error(`missing required corpus: ${corpusPath}`);
  const corpus = JSON.parse(fs.readFileSync(corpusPath, 'utf8'));
  if (corpus.skill !== skill || !Array.isArray(corpus.cases) || corpus.cases.length < 1 || corpus.cases.length > 2) {
    throw new Error(`${packagePath} must have one or two behavior cases for its own skill`);
  }
  if (validation.corpora.behavior.caseCount !== corpus.cases.length) {
    throw new Error(`${packagePath} validator case count disagrees with its corpus`);
  }

  assertCaseContracts(corpus, approvedCaseContracts[skill], packagePath);
  for (const [caseIndex, behaviorCase] of corpus.cases.entries()) {
    for (const field of ['prompt', 'expected']) {
      const value = behaviorCase[field];
      if (typeof value !== 'string' || value.trim().length < 40 || value.trim().split(/\s+/).length < 6) {
        throw new Error(`${packagePath} case ${caseIndex} has an empty or unrealistic ${field}`);
      }
    }
    if (!Array.isArray(behaviorCase.assertions) || behaviorCase.assertions.length === 0) {
      throw new Error(`${packagePath} case ${caseIndex} has no assertions`);
    }
    if (!Array.isArray(behaviorCase.capabilities)) {
      throw new Error(`${packagePath} case ${caseIndex} must declare scoped capabilities`);
    }
    for (const capability of behaviorCase.capabilities) {
      if (!allowedCapabilities.has(capability)) {
        throw new Error(`${packagePath} case ${caseIndex} has prohibited capability ${capability}`);
      }
    }
  }

  for (const [location, value] of naturalLanguageFields(corpus)) {
    assertSubstantive(value, `${packagePath}${location}`);
    assertNoProhibitedRequest(value, `${packagePath}${location}`);
  }

  const assertionsById = new Map(corpus.cases.flatMap((entry) =>
    entry.assertions.map((assertion) => [assertion.id, assertion])));
  const contracts = requiredContractProofs[skill];
  if (!contracts) throw new Error(`missing contract map for ${skill}`);
  for (const [contract, proofGroups] of Object.entries(contracts)) {
    const contractEvidence = [];
    for (const proofGroup of proofGroups) {
      const specification = Array.isArray(proofGroup)
        ? { ids: proofGroup, critical: true }
        : proofGroup;
      const matches = specification.ids
        .map((id) => assertionsById.get(id))
        .filter(Boolean);
      if (matches.length === 0) {
        throw new Error(
          `${packagePath} lacks proof for ${contract}: ${specification.ids.join(' OR ')}`,
        );
      }
      if (specification.critical && !matches.some((assertion) => assertion.critical === true)) {
        throw new Error(
          `${packagePath} lacks critical proof for ${contract}: ${specification.ids.join(' OR ')}`,
        );
      }
      contractEvidence.push(...matches);
    }
    if (!contractEvidence.some((assertion) => assertion.critical === true)) {
      throw new Error(`${packagePath} lacks a critical assertion for: ${contract}`);
    }
  }
}

if (!same(Object.keys(requiredContractProofs).sort(), expectedPackages.map((entry) => path.basename(entry)).sort())) {
  throw new Error('critical contract map must cover exactly the fifteen required packages');
}
NODE

printf 'PASS: validated critical behavior corpora for exactly 15 required packages\n'
