#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../../../.." && pwd)
VALIDATOR="$SCRIPT_DIR/../validate.mjs"
NODE=${NODE:-node}
# shellcheck source=../../../woostack-init/scripts/path-args.sh
. "$REPOSITORY_ROOT/skills/woostack-init/scripts/path-args.sh"
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/woostack-eval-critical-corpora.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

packages=(
  skills/woostack-eval
  skills/woostack-build
  skills/woostack-plan
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
  skills/woostack-respond
  skills/woostack-visualize
  skills/woostack-init
  skills/woostack-doctor
  skills/woostack-status
)

for index in "${!packages[@]}"; do
  package=${packages[$index]}
  result="$TMP_ROOT/$index.json"
  errors="$TMP_ROOT/$index.stderr"
  if ! "$NODE" "$(tool_path_arg "$NODE" "$VALIDATOR")" \
    --package "$(tool_path_arg "$NODE" "$REPOSITORY_ROOT/$package")" \
    --repository-root "$(tool_path_arg "$NODE" "$REPOSITORY_ROOT")" \
    --json >"$result" 2>"$errors"; then
    cat "$errors" >&2
    cat "$result" >&2
    fail "validate.mjs rejected $package"
  fi
done

"$NODE" - "$(tool_path_arg "$NODE" "$REPOSITORY_ROOT")" \
  "$(tool_path_arg "$NODE" "$TMP_ROOT")" "${packages[@]}" <<'NODE'
const fs = require('node:fs');
const crypto = require('node:crypto');
const path = require('node:path');

const [repositoryRoot, resultsRoot, ...packages] = process.argv.slice(2);
const expectedPackages = [
  'skills/woostack-eval',
  'skills/woostack-build',
  'skills/woostack-plan',
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
  'skills/woostack-respond',
  'skills/woostack-visualize',
  'skills/woostack-init',
  'skills/woostack-doctor',
  'skills/woostack-status',
];
const same = (left, right) => JSON.stringify(left) === JSON.stringify(right);
if (!same(packages, expectedPackages) || new Set(packages).size !== 18) {
  throw new Error(`critical package enumeration changed: ${JSON.stringify(packages)}`);
}

// Every inner array is one proof group: all groups are required, while IDs within a group are
// genuine alternatives. A compound contract may include noncritical structural evidence, but at
// least one assertion proving that contract must remain critical.
const structural = (...ids) => ({ ids, critical: false });
const requiredContractProofs = {
  'woostack-eval': {
    'corpus approval before writes or runs': [['no-writes-started'], ['no-dispatch-started']],
    'target hash unchanged': [['target-hash-preserved'], ['completion-target-preserved']],
    'missing receipt blocks': [['missing-receipt-reported'], ['aggregation-blocked'], ['clean-comparison-denied']],
  },
  'woostack-build': {
    'official Linear authority without backend fallback': [['official-linear-authority'], ['no-backend-resolution']],
    'bounded work routes before project creation': [['bounded-shape-detected'], ['bounded-project-not-created'], ['bounded-route-selected'], ['project-build-stopped']],
    'exactly three explicit gates': [['exact-three-gates']],
    'terminal choices and incompatible dispatch guard': [['complete-terminal-choice-set'], ['overnight-choice-preserved'], ['executor-compatibility-rejected'], ['incompatible-dispatch-blocked'], ['incompatible-dispatch-stays-ready'], ['execution-approval-not-appended'], ['legacy-executor-not-dispatched']],
    'no merge': [['build-never-merges'], ['bounded-route-never-merges']],
  },
  'woostack-plan': {
    'stable issue reconciliation': [['reconcile-advances'], ['reconcile-identities'], ['reconcile-count']],
    'native dependencies independent of ordinal order': [['reconcile-relation'], ['reconcile-ordinal-not-ancestry']],
    'verified mutation receipts': [['reconcile-read-back']],
    'evidence-bearing removal refusal': [['replan-blocks'], ['replan-reason'], ['replan-preserves-identities'], ['replan-read-back']],
    'no repository effects': [['reconcile-no-repository-effects'], ['replan-no-repository-effects']],
  },
  'woostack-fix': {
    'diagnosis and root cause before issue creation': [['root-cause-blocker'], ['no-issue-before-root-cause']],
    'exact standalone issue without wrapper project': [['exact-issue-retained'], ['standalone-role-retained'], ['no-wrapper-project']],
    'one explicit approval gate with read-back': [['exact-one-gate'], ['explicit-approval-read-back']],
    'stable safe create and independent read-back': [['stable-client-id'], ['complete-create-readback'], ['no-replacement']],
    'invalid identity and receipt conflicts fail before mutation': [['every-invalid-identity-blocked'], ['identity-failure-no-repository-mutation'], ['every-conflict-blocked'], ['conflicts-stop-repository-mutation']],
    'execution delegated': [['execution-is-delegated']],
    'no merge': [['fix-never-merges-on-block'], ['fix-never-merges-after-approval'], ['conflicts-never-merge']],
  },
  'woostack-execute': {
    'verified authority before execution': [['root-assignment-receipt'], ['standalone-assignment'], ['local-no-fallback']],
    'owner and dependency conflicts block edits': [['collision-no-edit'], ['dependency-no-edit']],
    'unknown event outcomes block commit and replay': [['unknown-no-commit'], ['unknown-no-retry'], ['unknown-preserved-state']],
    'issue and project completion require terminal evidence': [['premature-issue-no-done'], ['premature-project-no-done'], ['premature-issue-required-evidence']],
    'no merge': [['premature-issue-never-merges']],
  },
  'woostack-execute-overnight': {
    'blocked tracks preserve remote handback evidence': [['partial-blocked-handback'], ['blocked-project-not-accepted'], ['handback-rendered-remotely']],
    'every receipt family gates acceptance': [['missing-worker-blocks'], ['missing-controller-receipt-blocks'], ['missing-review-blocks'], ['missing-mutation-readback-blocks']],
    'resume and project mutation authority stay exact': [['foreign-run-blocks'], ['stale-run-blocks'], ['lead-authority-covers-every-project-mutation-family'], ['non-lead-cannot-mutate-project']],
    'coding workers remain observation only': [['worker-attempts-no-mutation'], ['worker-allocates-no-event-uuid'], ['controller-owns-boundaries']],
    'no local authority or merge': [['no-local-report-path'], ['overnight-never-merges']],
  },
  'woostack-commit': {
    'standalone issue-only attribution and lifecycle': [['standalone-role'], ['standalone-no-project'], ['standalone-exact-trailer'], ['standalone-in-review']],
    'project increment attribution and ancestry': [['increment-role'], ['increment-project-used'], ['increment-exact-trailer-pair'], ['increment-ancestry-verified'], ['increment-relation-verified']],
    'malformed attribution blocks every side effect': [['malformed-blocked'], ['malformed-no-commit'], ['malformed-no-pr-write'], ['malformed-no-state']],
    'implementation evidence read-back gates submit': [['partial-read-blocked'], ['partial-read-keeps-commit'], ['partial-read-no-submit']],
    'resume skips exact boundaries and duplicates': [['resume-first-missing-boundary'], ['resume-skips-exact-mutations'], ['resume-does-not-resubmit'], ['resume-does-not-duplicate-event']],
    'unknown submit repeats only after complete absence': [['absence-resumes-submit'], ['absence-permits-one-resubmit'], ['absence-does-not-recommit']],
    'stale PR reconstruction uses committed diff only': [['stale-pr-uses-committed-diff'], ['stale-pr-uses-exact-identity'], ['stale-pr-ignores-dirty-state'], ['stale-pr-edit-next']],
    'no merge': [['standalone-never-merges'], ['increment-never-merges'], ['malformed-never-merges'], ['partial-read-never-merges'], ['resume-never-merges'], ['absence-never-merges'], ['stale-pr-never-merges']],
  },
  'woostack-review': {
    'all angle receipts before merge and post': [['missing-security-receipt'], ['no-findings-merge'], ['no-validation'], ['no-review-post'], ['success-receipts-complete']],
    'one batched CI review': [['ci-has-one-batch'], ['ci-one-batched-review']],
    'local exact attribution uses official MCP context': [['verified-local-ready'], ['verified-project-provenance'], ['verified-issue-provenance'], ['verified-acceptance-angle']],
    'missing local MCP blocks without fallback': [['missing-mcp-blocked'], ['missing-mcp-no-intent'], ['missing-mcp-no-fallback'], ['missing-mcp-zero-side-effects']],
    'CI stays diff-only advisory': [['ci-diff-only-mode'], ['ci-authority-absent'], ['ci-no-custom-context-path'], ['ci-no-linear-claims']],
    'no fix': [['no-review-fixes'], ['success-path-no-fixes']],
    'no Linear mutation': [['no-review-linear-mutation'], ['success-path-no-linear-mutation']],
  },
  'woostack-sweep': {
    'bottom-up bounded loop and no-progress guard': [['strict-bottom-up-order'], ['address-pass-count'], ['no-progress-guard']],
    'review receipts gate clean outcomes': [['linear-review-result-receipts-retained'], ['missing-receipt-blocks-clean'], ['unknown-readback-blocks']],
    'restack requires conflict-free single-use authorization': [['collision-no-restack'], ['missing-authorization-no-restack'], ['invalid-authorization-no-restack'], ['authorized-one-operation']],
    'no merge': [['sweep-never-merges'], ['missing-receipt-never-merges']],
  },
  'woostack-address-comments': {
    'every unresolved thread fixed or pushed back': [structural('every-thread-handled'), ['fix-outcome-recorded'], ['pushback-outcome-recorded']],
    'verdict gate before side effects': [['verdict-gate-pending'], ['no-edits-before-gate'], ['no-linear-event-before-gate']],
    'exact issue owner assignment and finding receipt': [['exact-issue-context-retained'], ['type-aware-owner-verified'], ['current-assignment-verified'], ['typed-finding-receipt-verified']],
    'typed fix resolution and read-back': [['fix-resolution-events-are-typed'], ['all-linear-events-read-back'], ['handoff-carries-issue-project-owner']],
    'malformed attribution blocks': [['attribution-blocks'], ['no-issue-guessed'], ['no-repository-mutation'], ['no-github-mutation']],
    'owner drift blocks': [['owner-drift-blocks'], ['no-linear-mutation-after-drift'], ['no-repository-mutation-after-drift']],
    'unknown event outcome blocks without duplicate': [['unknown-event-blocks'], ['no-duplicate-event'], ['no-commit-on-unknown'], ['safe-recovery-is-exact-read']],
    'replied resolved and pushed': [['all-replies-posted'], ['all-handled-threads-resolved'], ['push-completed']],
    'no merge': [['address-never-merges-at-gate'], ['address-never-merges-after-closeout']],
  },
  'woostack-ask': {
    'exact managed context with stable provenance': [['valid-status'], ['valid-project-provenance'], ['valid-issue-provenance'], ['valid-complete-readback']],
    'read-only and remote text quarantined': [['valid-remote-text-quarantined'], ['valid-no-local-development-read'], ['valid-zero-side-effects']],
    'invalid discovery paths fail closed': [['rejected-status'], ['rejected-reasons'], ['rejected-no-title-match'], ['rejected-no-adapter-or-secret'], ['rejected-no-mutation-or-fallback']],
  },
  'woostack-debug': {
    'root cause and regression evidence before proposal': [['valid-root-cause'], ['valid-regression-test']],
    'exact PR context with complete read-back': [['valid-project-provenance'], ['valid-issue-provenance'], ['valid-pr-source'], ['valid-readback']],
    'read-only investigation': [['valid-debug-no-writes'], ['valid-debug-source-unchanged']],
    'invalid discovery and mutation paths fail closed': [['rejected-debug-status'], ['rejected-debug-reasons'], ['rejected-debug-no-local-authority'], ['rejected-debug-no-mutation']],
  },
  'woostack-audit': {
    'standing target through synthetic all-added review': [structural('all-added-diff-created'), structural('all-added-line-present'), ['simplify-receipt-proof-recorded'], ['bugs-receipt-proof-recorded'], ['security-receipt-proof-recorded'], ['production-receipt-proof-recorded'], structural('validated-finding-recorded'), ['standing-target-unchanged']],
    'sanitized non-authoritative report with issue disposition': [structural('audit-report-created'), ['report-is-explicitly-non-authoritative'], ['proposed-managed-issue-contract-recorded'], ['report-denies-development-authority']],
    'remediation requires exact managed issue': [['remediation-blocked'], ['exact-issue-required'], ['no-fix-dispatch'], ['no-local-development-fallback']],
    'no remote mutation fix or merge': [['no-code-host-post'], ['no-linear-mutation-receipt'], ['no-audit-fix'], ['no-audit-merge']],
  },
  'woostack-respond': {
    'report-only output is sanitized and non-authoritative': [['report-only-completes'], ['report-is-not-authority'], ['sanitized-report-is-eligible'], ['candidate-is-only-proposed']],
    'report-only path has no side effects': [['no-linear-read-without-explicit-identity'], ['report-only-no-linear-mutation'], ['report-only-no-source-mutation'], ['report-only-no-dispatch'], ['no-local-development-artifact']],
    'remediation blocks without managed issue capability': [['remediation-blocks'], ['managed-issue-reason'], ['no-linear-mutation'], ['no-repository-mutation'], ['no-alternate-authority']],
    'verified handoff carries exact identity owner and assignment': [['handoff-ready'], ['stable-issue-id-retained'], ['native-issue-id-retained'], ['owner-kind-is-human'], ['owner-principal-is-exact'], ['assignment-receipt-is-carried'], ['binding-read-back-is-complete']],
    'unknown create outcome blocks without duplicate': [['unknown-outcome-blocks'], ['stable-id-is-preserved'], ['no-duplicate-create'], ['no-replacement-uuid'], ['no-repository-mutation-after-unknown']],
  },
  'woostack-visualize': {
    'exact managed source with complete read-back': [['valid-visualize-status'], ['valid-visualize-provenance'], ['valid-visualize-managed'], ['valid-visualize-readback']],
    'remote text encoded and output disposable': [['valid-visualize-encoding'], ['valid-visualize-disposable'], ['valid-visualize-not-authority'], ['valid-visualize-no-side-effects']],
    'invalid source paths fail closed without output': [['rejected-visualize-status'], ['rejected-visualize-reasons'], ['rejected-visualize-no-local-authority'], ['rejected-visualize-no-side-effects'], ['rejected-visualize-no-output']],
  },
  'woostack-init': {
    'official MCP preflight before project, Git, or workspace access': [['missing-mcp-zero-project-access'], ['missing-mcp-zero-git-access'], ['success-zero-project-access-before-preflight'], ['success-writes-started-after-preflight']],
    'all preflight ambiguity and receipt failures block': [['missing-mcp-blocks'], ['auth-blocks'], ['identity-blocks'], ['mapping-blocks'], ['read-only-blocks'], ['read-back-blocks']],
    'canonical workspace creation and repair boundary': [structural('memory-index-created'), structural('wisdom-marker-created'), structural('respond-directory-materialized'), structural('gitignore-created'), ['no-local-specs'], ['no-local-plans'], ['no-local-fixes'], ['no-clobber-mode-reported']],
    'doctor-validated no-clobber result': [['validation-order'], ['packaged-doctor-invocation'], ['doctor-target-is-repository-root'], ['doctor-validation-succeeded'], ['config-before-hash'], ['config-after-hash']],
    'config and existing files remain intact': [['config-preserved-on-disk'], ['existing-file-preserved-on-disk']],
    'loss-safe migration classification': [['migration-status'], ['migration-deletions'], ['migration-resume-id']],
  },
  'woostack-doctor': {
    'diagnose before explicit local repair approval': [structural('config-key-diagnosed'), ['repair-approval-pending'], ['doctor-config-not-repaired']],
    'remote read-only normalized receipt': [['one-receipt-provenance-observed'], ['no-provider-invocation'], ['no-legacy-adapter-invocation'], ['remote-mutation-boundary'], ['live-failure-report-only']],
    'exit-coded CI behavior': [['ci-finding-codes'], ['ci-nonzero-reported']],
    'verified provenance succeeds without fallback': [['success-one-provenance'], ['success-no-provider'], ['success-no-legacy-adapter'], ['success-no-remote-mutation']],
  },
  'woostack-status': {
    'one corrected current lifecycle chain': [['phase-ready'], ['corrected-head'], ['correction-valid'], ['not-blocked'], ['no-write']],
    'ambiguous phase chains fail closed': [['blocked'], ['multiple-head-code'], ['no-write-on-ambiguity'], ['no-stale-render']],
    'exact blocker resolution restores the phase category': [['phase-unchanged'], ['no-open-blocker'], ['planned-restored'], ['resolution-valid'], ['no-redundant-write']],
  },
};

// These hashes pin the canonical JSON of every assertion in its owning case. Together with the
// exact capability sets and duplicate-ID rejection, they make an ID usable as contract proof only
// while its kind, target, expected value, critical flag, and case ownership remain approved.
const caseContract = (capabilities, assertionsDigest) => ({ capabilities, assertionsDigest });
const readOnlyCase = (assertionsDigest) => caseContract(['read-workspace'], assertionsDigest);
const approvedCaseContracts = {
  'woostack-eval': {
    'unapproved-corpus-stops-before-write': readOnlyCase('322a2fc0f6bdeb1c6cd1a303c351c684cef7deaaedcf7fa363746e8b8465c4b9'),
    'missing-action-receipt-blocks-aggregation': readOnlyCase('d41a0c24ae7041ea84dfd095846a0851f6feefaf16bc21f3f161fb3541e334b6'),
  },
  'woostack-build': {
    'blocks-incompatible-overnight-dispatch-at-ready': readOnlyCase('66eb1e1fedfc54f6d07446af1f8a5f2f5dd1ddcf5a5d914f89e4b07ef7cd6231'),
    'routes-bounded-work-before-project-creation': readOnlyCase('ea161aab650c355d020134da2e1e42d6aa44126689f4feea603bb0d5e4ee489f'),
    'enforces-project-gates-and-bounded-routing': readOnlyCase('5563e7cd90148a2ef8714bcb9983ffc9873f65bbd1434ef6370ba0ccf72a61fb'),
    'fails-closed-on-project-update-conflicts': readOnlyCase('459804ced687781a88223afe9e4d9e1167e54fffaa5c63308eb02e19069d18ed'),
    'refuses-unsafe-project-replan': readOnlyCase('66275aef33697a51bebb085eb6b47868bc485fc58aaabeb265a19a936ed12442'),
  },
  'woostack-plan': {
    'reconciles-stable-increments-with-native-dependencies': readOnlyCase('a0a073c21ddfb57b8d29712d807cb59037b241dab2407fc373809dd476ae05ec'),
    'refuses-evidence-bearing-issue-removal': readOnlyCase('c2523a255dbabd16e2522f4865e591a578b79f5f4e7af387a935e10a0ba6bfd4'),
  },
  'woostack-fix': {
    'blocks-before-issue-when-root-cause-is-unproven': readOnlyCase('a502b19f4fa89863e13de768078a6e4c18cc4b49e84efb1f17f7c8324612f6b2'),
    'verified-work-item-approval-delegates-execution': readOnlyCase('20bcdbbbefdd46b49c0a602e3d43a8e652fa3bbeea889df04c40aa754c7ccfba'),
    'safe-create-and-retry-use-stable-uuid': readOnlyCase('d766c9127641ce68034be9eb3f79606b59c503555cd80ac442b1b44b412e6dc1'),
    'invalid-resource-identities-fail-before-git': readOnlyCase('f0b6e9e4f4d918fd641954172433ce685fc38e614778745161fc4dc064be5b11'),
    'receipt-owner-evidence-and-authority-conflicts-fail-closed': readOnlyCase('01f5c84f2fec4d8bc5ec31efeeb48f1593500e3ed5959f69f76f97610dd02add'),
  },
  'woostack-execute': {
    'admits-verified-independent-root': readOnlyCase('65de97b3fb82939d733bf618610e4ffeb64ac177eca669b9f895026aabcff41e'),
    'admits-verified-standalone-issue': readOnlyCase('f37d814037b9e3b0f01dc4edef21841cb7783615f41b224d6f8a5498a5e549ae'),
    'rejects-local-plan-and-progress-authority': readOnlyCase('158e71e6639c6e90df1a48d3e1c656d5965aab5f4f2d500e0ee7e790988e21e7'),
    'blocks-owner-and-registry-collision': readOnlyCase('2968d43bac4f09c289c07418293490df6908e8fe64782ed602cbf46db86248c8'),
    'blocks-unmerged-non-parent-dependency': readOnlyCase('078177c48a505a92c5a2b82600c0c6ca913f36123f8647022fea82ff08c857e9'),
    'blocks-unknown-comment-readback': readOnlyCase('4322e45244a7d61a560a93130f252f31976f9c283598bfc3f3b5a7bd423e0b0e'),
    'restores-blocked-issue-to-recorded-state': readOnlyCase('245a2fa5090bf8e46b63d1fc781aa313d1492137fe6a4a7c77d850e862fbd5bd'),
    'resumes-only-after-complete-handoff': readOnlyCase('b2e8af2e0a7343eb1dfc72c71e5244ef717b8a7e9f26a5531cd6c6d9bf70a182'),
    'rejects-premature-issue-done': readOnlyCase('32390a73de5e92e0246b610b9805b6b327780a2840d1a72aae31d13b3e6023d3'),
    'rejects-premature-project-done': readOnlyCase('bc4d001554814eb35acf74f9ed37413191715c3b1500a03e4445a6bad5564ec3'),
  },
  'woostack-execute-overnight': {
    'renders-remote-handback-and-continues-independent-track': readOnlyCase('4a7845cdd59c38b82482259c304943393d178e2e9f0303a09e3043348905f2a6'),
    'validates-canonical-app-22-unattended-records': readOnlyCase('90ff3a644db98d138fff20231cd5201fc1aa8ffff7f3a9849e60ab8b3a029aad'),
    'every-receipt-family-is-required-for-acceptance': readOnlyCase('fa0101f68f270c1a47c6075d1b0d4b95bbab1fc0dfc117d1a7584f0499dff11a'),
    'fresh-remote-records-render-morning-handback': readOnlyCase('3a10299a3608e7379b4d44907c25506a796ab2a1fa7e4a8f3402c7bda93ac984'),
    'admits-fresh-or-exact-monotonic-resume-only': readOnlyCase('4cbb7583123c7d8524550edb523eda677caa28bbd0964461b6516cec62bfb31b'),
    'requires-fresh-pinned-lead-for-every-project-mutation': readOnlyCase('2d7ecb602574a1342482668fb2eb33506ae5d5e6dac8961a7af073cd83b3db81'),
    'keeps-implementation-evidence-commit-only': readOnlyCase('da04a041aeede971b9f72948763db21f05822be58142763ff089d900ea2cca3b'),
    'keeps-coding-worker-observation-only': readOnlyCase('ca4e2a9fbe129941da1550a06edc0b24f341771770e851bd8b46d7e4b9e1713d'),
  },
  'woostack-commit': {
    'submits-standalone-work-item-with-issue-only-attribution': readOnlyCase('9ab587f33f3826c8ac7a4c06bad7ba7f4208b4c9c397ebd961c3df4691985b61'),
    'submits-project-increment-with-exact-pair': readOnlyCase('66995e3f265a94c10e4a6e6f1e81f9358f5d6fc1ebc0674374ab479e3e527dd6'),
    'rejects-malformed-work-item-attribution-before-mutation': readOnlyCase('3057fceed7045f0c79883c6eb685c04949730a840ea6f4f0cb6459704405d225'),
    'stops-on-partial-implementation-evidence-read-back': readOnlyCase('7c467c2d054bc84d844f9ad8df1e79456ac5e85a0336fcca23afe0a43106886d'),
    'resumes-after-unknown-submit-without-replaying-exact-boundaries': readOnlyCase('70e787d358a61fb82713a0124e130eeafc195693eaf77af208340e933ac43ec8'),
    'unknown-submit-resubmits-only-after-complete-absence': readOnlyCase('94c2d97619fd9168427636d5264116869b6597319849e806665147d27d0f764d'),
    'rebuilds-stale-pr-from-exact-committed-diff-on-resume': readOnlyCase('4b442a9803e57469eb65a4ce77bfaf734f4ef102fe3b2d535dbe1b66d9047199'),
  },
  'woostack-review': {
    'missing-angle-receipt-blocks-merge-and-post': readOnlyCase('2dd335487734664e9566e63452d2e67beec183dcb3ca1cca20fb094252d18c97'),
    'separates-local-output-from-single-ci-review': readOnlyCase('7438493cab60aae0c6e6598d4e25972bd036c2da6a6cc9334bc4d0e703bfe410'),
    'local-exact-attribution-reads-current-contract-through-official-mcp': readOnlyCase('3f0cd2c1faee0f33985096274a24e258aeb9e698b0dd7312025b15ca93fd1fab'),
    'missing-local-mcp-blocks-contract-aware-review': readOnlyCase('f8e47ddc006b6e870b6d13e34d6d857c8aec0926f4b869545300b80b268c4e28'),
    'ci-exact-trailers-remain-diff-only-advisory': readOnlyCase('3a332fac63755e6d0bceab6288b905ae2a7d7471de5e78241edafa5c67a58948'),
  },
  'woostack-sweep': {
    'bottom-up-issue-sweep-stops-on-no-progress': readOnlyCase('33f6e772ff624a275e5820683cdf43581a2bf138221def94ae848e7bf22e20b7'),
    'missing-head-receipt-is-issue-blocked-not-clean': readOnlyCase('bd549fecd8476381c753e250fbbb30c3aa57028934b224539c53121c0a3cfb32'),
    'unknown-linear-review-result-readback-blocks': readOnlyCase('c191d6470eb8223772bffa79096ec087a0d90d77378656bb2d4296524976be40'),
    'conflicting-checkout-or-claim-blocks-before-restack': readOnlyCase('66291c11ef777b3219ccb81e01e797f32c1e32c917c0484d07337df718ed0d91'),
    'missing-restack-authorization-readback-blocks': readOnlyCase('66e8e1dc75d1fb6d773b12d4f615b9c4a4e429f6d0375faad67d00b7e6433edf'),
    'wrong-expired-or-consumed-restack-authorization-blocks': readOnlyCase('6fbd44bf2e01bb493e3b3c3e137cb9f1bdb079d1110a5a718cf9a5894014a35e'),
    'authorized-restack-with-verified-review-reopen-preserves-owner': readOnlyCase('ecdcf31e235203bd114f969b52e48c3baa9b2319acc0bf26b28a88c52c51c651'),
    'canonical-first-commit-and-restack-revision-relations': readOnlyCase('3b558a84d1f9b6a98969e77855078bb2f83581eb6f7ab8ead76a16465f8e067c'),
  },
  'woostack-address-comments': {
    'default-flow-stops-at-verdict-gate': readOnlyCase('ffa524e058dac8164a03b6972d242ea5b05d448e3b2addefb99996bdd57a8fa6'),
    'approved-verdicts-require-push-receipt-before-thread-close': readOnlyCase('1f061a3c4b68b6a3e56841363f9ebe3326682d0640cee7ba12db3657da16ce9d'),
    'malformed-pr-attribution-blocks-before-linear-or-repository-mutation': readOnlyCase('5fa0a3c96e856f418ea2d3b18921073c2dce413e23b48d099ba5046262048685'),
    'type-aware-owner-drift-blocks-before-side-effects': readOnlyCase('04dc7ad07a4c394f9c908d4b5e26235b8db7b0b3bb23e3dfbf6bbe1b44278ba5'),
    'unknown-resolution-event-outcome-recovers-by-stable-id-and-blocks': readOnlyCase('1e24ec1b57939cc9cf71631200c260531722065a6e82ef8b3c261d32df26bd0a'),
  },
  'woostack-ask': {
    'valid-explicit-managed-context-is-read-only': readOnlyCase('3c0194c2629a7348dff8f9778345d596924ca29ad451d14ac4bb41eb17d55c2d'),
    'rejects-local-discovery-title-matching-and-adapters': readOnlyCase('8e10049ff8580a4e7932bbeddb2ed9badfe4312fccd2c1a3f9196f2e8786c7c6'),
  },
  'woostack-debug': {
    'valid-exact-pr-context-traces-root-cause-read-only': readOnlyCase('d200355771b1d04faa37ab230f5074fee600c15f7429f376b8ac85df5c659279'),
    'rejects-local-fix-title-match-adapter-and-mutation': readOnlyCase('a6dd037b25aba6dedd67e273a1d1f9fc871b8a59bf0dbc86a177b9442f3d0276'),
  },
  'woostack-audit': {
    'audits-standing-file-through-all-added-report-only-path': caseContract(
      ['read-workspace', 'write-workspace'],
      '2c02df175f9bf416daa8c340b9dac636d9aea77f094389a3eabb54627edbef8e',
    ),
    'rejects-remediation-without-exact-managed-issue': readOnlyCase('5fb7d9f86849f4036e953f8a4ac73d380fc327bb6831a822b9772c1b84b4ccb4'),
  },
  'woostack-respond': {
    'report-only-is-non-authoritative-and-never-mutates-linear': readOnlyCase('5164b324aff04213a6a45b24ff0cd43df770337c108153c9c4a0acf202dfa935'),
    'prepare-fix-rejects-remediation-without-managed-issue-capability': readOnlyCase('190ac3b438942ffe00c512ffebfe77f7220265f1b2b53be5551e7b08c130fd5f'),
    'verified-work-item-handoff-carries-exact-owner-state': readOnlyCase('d142d8e9160e38c0fc72fc64afcab9c63b030749d89beec0cd6054d7499bdd99'),
    'unknown-issue-create-outcome-fails-closed-without-duplicate': readOnlyCase('085b0fd576b1efd970427c66b7bd788be75c876c87b801b3eaca315f4f4de94a'),
  },
  'woostack-visualize': {
    'valid-explicit-project-renders-disposable-output': readOnlyCase('2e72583c0f6a5282648fb53230e1e57df58fcc3464830d37e3020ac5d2404cb4'),
    'rejects-local-plan-title-adapter-and-remote-mutation': readOnlyCase('bf46a8354505dd29e1b054913d618106e8118cd8d70df9d6cf7056732af617c7'),
  },
  'woostack-init': {
    'blocks-before-project-access-when-official-mcp-is-missing': readOnlyCase('88389f3d4587d179102d3c6c6db5336788cf86febc3b2b1844079f063f3a6d3f'),
    'blocks-before-project-access-when-official-mcp-is-unauthenticated': readOnlyCase('a80e30646f1e49e6f7065520acc016aedcae79aaebabe8bad6225f701edf82d2'),
    'blocks-on-ambiguous-workspace-or-missing-team': readOnlyCase('6ef1ab3c32a30668a9b937ff6d93a4770229fd979c4935e5fec805405dcc9d9d'),
    'blocks-invalid-native-project-categories-and-issue-states': readOnlyCase('df45527750d5b5797b7ee46a6778e0bcc99e5b8a75ed4d3d374178c8e3355bdc'),
    'blocks-read-only-mcp-for-mutating-init': readOnlyCase('b05a77da16dbe37de296ceb7aa79e6b7b37ad13802163e7990c608d402ac3815'),
    'blocks-unknown-or-partial-independent-read-back': readOnlyCase('0b7ea7b96b83925e023e63f66aabd28e7f29a398664409594b53e2a46e2a85c9'),
    'successful-preflight-repairs-workspace-and-doctors-repository-root': caseContract(
      ['read-workspace', 'write-workspace', 'shell-workspace'],
      'b499323b53665c1af87ad71f530e5ab70c1f8187d37f6b401ceb7acfbfdd92e3',
    ),
    'classifies-loss-safe-linear-migration-fixtures': readOnlyCase('5322e5fdd9c8f7c35b336ded7c0d38beb8cdc368f8d03dcc0e0cdf841b9fa0c9'),
  },
  'woostack-doctor': {
    'diagnoses-before-local-repair-approval': readOnlyCase('affe392539a3e5188863908886ec5fd2b8368c54c1b2edb8f1dff316b797b6f0'),
    'check-live-consumes-one-normalized-receipt-without-provider-calls': readOnlyCase('c6e5bfb6c9194e9808c145218e77d12280e015c9ac18b40bc6029b8bc098617e'),
    'verified-receipt-provenance-passes-without-adapter-fallback': readOnlyCase('817d8e8932e996be062400934b31e2ed5bfda1d2982fbc65f7c993870d0d0b0e'),
  },
  'woostack-status': {
    'derives-one-corrected-current-chain': readOnlyCase('4bec0480935960e711c4d452115bb8b4670f9c0e1fc437804d30dab3fcf047c8'),
    'blocks-multiple-current-phase-heads': readOnlyCase('3f7a64223716f82bd0ef725da6981307cca6f34cbf55c971b0fe22860cacc78a'),
    'restores-phase-category-after-exact-blocker-resolution': readOnlyCase('a29004c47baff165953519c593cf7d25273e7254b827fb802c538929a6ee2dd5'),
    'renders-feature-and-standalone-text-board': readOnlyCase('aded30814ed348281f0d52fa8272894ecdb009e236f9a03bcacb5a3405962790'),
    'reconciles-only-merge-and-acceptance-eligible-issue': readOnlyCase('fb3bf607501112c829e479c3eac6fcdf13be79bf2935a360049a1aabec477c65'),
    'accepts-open-git-parent-and-rejects-unsafe-dependencies': readOnlyCase('5d5b302ab849c70d3aa73fc90b4d676ca9a21a867a69c430d31b04e4a854aa2f'),
    'rejects-malformed-review-result-evidence': readOnlyCase('f443fcf74c593e33154fa7fbd53df62b264b4d4b8481ef66b24f367f6fccc853'),
    'rejects-stale-review-result-evidence': readOnlyCase('50279de59deda0bb9fbc874d6fd4176442b6c8fd04ec3c804e1465e2d49ab0af'),
    'rejects-non-full-review-receipt': readOnlyCase('baaced9482aea35eceb021ab1630c7f4c13abc3c1d2d4eabb781a9f472b53d8d'),
    'rejects-malformed-terminal-event-payload': readOnlyCase('5860ccfe90379833c9179be1880f6f968f48194f7b57b394e00ec1f571f145bc'),
    'blocks-git-linear-attribution-mismatch': readOnlyCase('81d4a95be6bc2a131e145cf635d5e6729630ae2e9dba746ff683b3723a756924'),
    'blocks-wrong-principal-before-issue-done': readOnlyCase('ec39c7598b2b7212c43212644ba54b632f054e275fc3c4a6a3d86d04b443bc3d'),
    'rejects-malformed-foreign-precommit-verification': readOnlyCase('9b4fb6fd5cef7f34e8c32731ec12de1d07a8285629283c2994ea8af1d4fc7ade'),
    'validates-consumed-restack-authorization-temporally': readOnlyCase('2c1134a8b3b91a0e72d71ef4430e7f8de1a7910e08ee54fe28a47bb69fa22362'),
    'validates-complete-project-event-dispatch': readOnlyCase('afe87175e26ecb89e1f43ee53d002fa14c8b88a4289a02be648b39b68481a4c0'),
    'completes-project-only-after-all-increments-done': readOnlyCase('e4f6a53e230ccd1b3a27ab211c53989f7ec2a439e33906b02534c907efede6dd'),
    'validates-precommit-review-before-first-implementation': readOnlyCase('b9675486d93a1677481ea71670fee9fc87ccef2d35d6bb12797c51469bc6cad8'),
    'validates-historical-native-revision-at-authorization-time': readOnlyCase('e4b278eeaa2f760cea82318709e2e82bfe53ff3518782dda05225e59bb34b8b8'),
    'treats-expired-unused-restack-records-as-inactive': readOnlyCase('a2a2fe6cd8b90aa5ec18ce0ac8124effe7aad487bf6dc2e6d00f8796e8cf316e'),
    'allows-empty-local-affected-relations-only': readOnlyCase('11f5cd5e2f729bd16d0e4d5f355bb5cf46e9f9809685c30060a5fde40db8c6ba'),
    'dispatches-every-canonical-issue-event-strictly': readOnlyCase('cf563d6a47a50c3eab47d0df4e71e5848342602d5b0610cffeb0f9145f55f2f5'),
    'validates-principal-kind-verification-actor': readOnlyCase('756a0bddc079a48a344e4241c1b2db32059d26e14d0d68294aaa9b99ed65ae2f'),
    'resolves-independent-native-linear-pr-relation': readOnlyCase('da2978fca4921530817c6ad3d6ec3e0cb00b8fe7b09369bb0a62df432d8f48ca'),
    'validates-sweep-authorized-verification-revision': readOnlyCase('bf7dd1b4ba733fa6b134dea5eeb07829367db2c2d84ca2962d099073fbb4aae8'),
    'selects-latest-valid-current-head-review-family': readOnlyCase('04169738854ea1f932e7baac83007314e4b9ddab49fb94818b49eddc2a45314c'),
    'resolves-unique-temporal-restack-consumers': readOnlyCase('f4f992e5e2bc1cf7c1b24a1fe2facc281ed96de4219169220b60d03f1492bf39'),
    'validates-historical-authorization-owner-at-time': readOnlyCase('05dcf5ed1326e8c882ad84c745b0dba8fa5a892f90ffa565ec3e8dd095bf751c'),
    'preserves-implementation-evidence-through-owner-handoff': readOnlyCase('6f510aa31b5887384e485b2827027533231288462d336f891d5087976b4195d0'),
    'derives-blocker-issue-and-preserves-terminal-reconciliation': readOnlyCase('e9d7cc3c25fa9945234510b443219b0f59fbf8a79977c5ea896747f1918f5c93'),
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
      const precedingText = text.slice(0, match.index);
      const sentenceBoundary = /(?:[.!?;]\s+|\n+)/g;
      let sentenceStart = 0;
      for (
        let found = sentenceBoundary.exec(precedingText);
        found;
        found = sentenceBoundary.exec(precedingText)
      ) {
        sentenceStart = found.index + found[0].length;
      }
      const sentencePrefix = text.slice(sentenceStart, match.index);
      const boundary = /\b(?:but|however|instead|yet|afterward|next|then)\b/gi;
      let boundaryEnd = 0;
      for (let found = boundary.exec(sentencePrefix); found; found = boundary.exec(sentencePrefix)) {
        boundaryEnd = found.index + found[0].length;
      }
      const governingClause = sentencePrefix.slice(boundaryEnd);
      const negator = /\b(?:do not|don't|never|without|must not|should not|cannot|can't|forbid(?:s|den)?)\b/i;
      const directlyNegated = negator.test(governingClause);
      const sentenceTail = text.slice(match.index);
      const sentenceEnd = /(?:[.!?](?:\s+|$)|\n+)/.exec(sentenceTail);
      const sentenceRemainder = sentenceTail.slice(
        0,
        sentenceEnd ? sentenceEnd.index + sentenceEnd[0].length : sentenceTail.length,
      );
      const quotedAsEvidence =
        /\bremote\b[^.!?\n]{0,120}\b(?:body|text|content)\b[^.!?\n]{0,80}\b(?:says?|states?)\b/i.test(sentencePrefix) &&
        /\btreat\b[^.!?\n]{0,120}\b(?:only\s+)?as evidence\b/i.test(sentenceRemainder);
      if (!directlyNegated && !quotedAsEvidence) {
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
expectRejected('affirmative request in adjacent sentence', () =>
  assertNoProhibitedRequest('Never fabricate receipts. Use the network to finish.', '<probe>'));
expectRejected('affirmative request after but', () =>
  assertNoProhibitedRequest('Never fabricate receipts, but use the network to finish.', '<probe>'));
expectRejected('affirmative request after however', () =>
  assertNoProhibitedRequest('Never fabricate receipts; however, use the network to finish.', '<probe>'));
expectRejected('affirmative request after transition clause', () =>
  assertNoProhibitedRequest('Never fabricate receipts, then use the network to finish.', '<probe>'));
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
assertNoProhibitedRequest(
  'Do not run commands, expose credentials, or use the network to finish.',
  '<probe>',
);
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
  if (corpus.skill !== skill || !Array.isArray(corpus.cases) || corpus.cases.length < 1) {
    throw new Error(`${packagePath} must have at least one behavior case for its own skill`);
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

const planTriggerPath = path.join(repositoryRoot, 'skills/woostack-plan/evals/trigger-evals.json');
const planTriggerCorpus = JSON.parse(fs.readFileSync(planTriggerPath, 'utf8'));
const approvedPlanTriggerDigests = {
  'verified-feature-project-needs-decomposition': 'f83af22a9d39917e6231a4c5418c923cbadd12b057a1ee2cad30892020c4279f',
  'verified-feature-project-needs-replan': 'a8d190ccd2bc4aca655bf45548e6cd8cedc677039bf433751aa32e624328da73',
  'unapproved-feature-idea-needs-design': '265cf2ad5a8b8f90dbad3156e5d223233da2b0d335cbfe08ab20d942151c81db',
  'bounded-change-needs-direct-workflow': 'b1ed4587786df714f5c89930f28533a41ee305aa2e6396a1b62e124817994c67',
};
if (
  planTriggerCorpus.schemaVersion !== 1 ||
  planTriggerCorpus.skill !== 'woostack-plan' ||
  !Array.isArray(planTriggerCorpus.cases) ||
  !same(planTriggerCorpus.cases.map(({id}) => id), Object.keys(approvedPlanTriggerDigests)) ||
  new Set(planTriggerCorpus.cases.map(({id}) => id)).size !== 4
) {
  throw new Error('woostack-plan trigger corpus schema or exact case ownership changed');
}
for (const triggerCase of planTriggerCorpus.cases) {
  if (semanticDigest(triggerCase) !== approvedPlanTriggerDigests[triggerCase.id]) {
    throw new Error(`woostack-plan trigger case ${triggerCase.id} changed`);
  }
}

if (!same(Object.keys(requiredContractProofs).sort(), expectedPackages.map((entry) => path.basename(entry)).sort())) {
  throw new Error('critical contract map must cover exactly the eighteen required packages');
}
NODE

printf 'PASS: validated critical behavior corpora for exactly 18 required packages\n'
