#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

REPOSITORY_ROOT=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)
SCRIPT_DIR="$REPOSITORY_ROOT/skills/woostack-eval/scripts/tests"
VALIDATOR="$REPOSITORY_ROOT/skills/woostack-eval/scripts/validate.mjs"
NODE=${NODE:-node}
# shellcheck source=../../../woostack-init/scripts/path-args.sh
. "$REPOSITORY_ROOT/skills/woostack-init/scripts/path-args.sh"
TMP_ROOT=$(mktemp -d "$REPOSITORY_ROOT/.woostack-eval-critical-corpora.XXXXXX")
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
  skills/woostack-debug
  skills/woostack-audit
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
  'skills/woostack-debug',
  'skills/woostack-audit',
  'skills/woostack-visualize',
  'skills/woostack-init',
  'skills/woostack-doctor',
  'skills/woostack-status',
];
const same = (left, right) => JSON.stringify(left) === JSON.stringify(right);
if (!same(packages, expectedPackages) || new Set(packages).size !== 16) {
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
    'canonical project admission through official Linear MCP': [
      ['build-official-mcp'],
      ['build-project-created'],
      ['build-operation-identity-preserved'],
      ['build-project-readback'],
    ],
    'complete direct issue graph and native dependencies': [
      ['build-exact-project'],
      ['build-direct-issue-graph'],
      ['build-native-dependencies'],
    ],
    'two exact content-bound approval gates': [
      ['build-project-approval'],
      ['build-plan-approval'],
      ['build-two-gates', 'build-gate-order'],
    ],
    'required provider and authority failures block safely': [
      ['build-provider-blocked'],
      ['build-provider-decisions'],
      ['build-authority-blocked'],
      ['build-authority-decisions'],
      ['build-provider-zero-dispatch', 'build-authority-zero-dispatch'],
      ['build-provider-zero-repository-mutation', 'build-authority-zero-repository-mutation'],
    ],
    'material drift invalidates the causal approval': [
      ['build-drift-results'],
      ['build-replan-invalidates-plan-approval'],
    ],
    'bounded work routes away before project creation': [
      ['build-bounded-route'],
      ['build-bounded-no-project'],
    ],
    'approved terminal context reaches overnight execution': [
      ['build-ready'],
      ['build-overnight-skill'],
      ['build-context-forwarded'],
    ],
    'no merge': [['build-never-merges']],
  },
  'woostack-plan': {
    'direct issue graph has no parent wrapper': [
      ['plan-direct-ready'],
      ['plan-two-direct-issues', 'plan-direct-issue-ids'],
      ['plan-no-parent-issue', 'plan-zero-parent-issues'],
      ['plan-native-dependency', 'plan-standalone-native-dependency'],
      ['plan-graph-readback', 'plan-standalone-graph-readback'],
    ],
    'build-delegated planning returns executor-ready candidate without provider mutation': [
      ['plan-delegated-candidate'],
      ['plan-delegated-executor-ready'],
      ['plan-delegated-no-provider-writes'],
      ['plan-delegated-synchronization-owner'],
      ['plan-delegated-hardening-owner'],
    ],
    'selected standalone persistence verifies exact project and graph': [
      ['plan-repository-verified'],
      ['plan-direct-issue-ids'],
      ['plan-zero-parent-issues'],
      ['plan-standalone-graph-readback'],
    ],
    'missing provider capability and wrong identity block mutation': [
      ['plan-mcp-blocked'],
      ['plan-mcp-decisions'],
      ['plan-identity-blocked'],
      ['plan-identity-decisions'],
      ['plan-mcp-no-issue-mutation', 'plan-identity-no-provider-mutation'],
    ],
    'unknown create and incomplete issue readback preserve stable identities': [
      ['plan-unknown-blocked'],
      ['plan-unknown-one-create'],
      ['plan-unknown-no-replacement'],
      ['plan-issue-readback-blocked'],
      ['plan-issue-readback-rejected'],
      ['plan-issue-stable-id'],
    ],
    'unsafe replans and invalid graphs fail before mutation': [
      ['plan-replan-blocked'],
      ['plan-replan-approval-invalidated'],
      ['plan-invalid-graphs-blocked'],
      ['plan-invalid-graph-reasons'],
    ],
  },
  'woostack-fix': {
    'root cause before managed issue': [['root-cause-blocker'], ['no-issue-before-root-cause']],
    'verified standalone work item without wrapper project': [
      ['verified-issue-state'],
      ['standalone-role-retained'],
      ['no-wrapper-project'],
      ['complete-readback'],
    ],
    'one approval gate and execution delegation': [
      ['exact-one-gate'],
      ['explicit-approval-read-back'],
      ['execution-is-delegated'],
    ],
    'retired authorities fail closed': [['conflict-matrix-blocked'], ['no-local-fallback'], ['no-local-fix-file']],
    'no merge': [['fix-never-merges-on-block'], ['fix-never-merges-after-approval']],
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
    'standalone and increment attribution are exact': [
      ['standalone-role'],
      ['standalone-no-project'],
      ['standalone-exact-trailer'],
      ['increment-role'],
      ['increment-project-used'],
      ['increment-exact-trailer-pair'],
    ],
    'commit submit relation and state read-backs are ordered': [
      ['standalone-operation-order'],
      ['increment-relation-verified'],
      ['partial-read-blocked'],
    ],
    'unknown outcomes resume without replay': [
      ['resume-skips-exact-mutations'],
      ['absence-permits-one-resubmit'],
      ['stale-pr-uses-committed-diff'],
    ],
    'direct branch creation is one exact native-issue action': [
      ['direct-branch-ready'],
      ['direct-branch-action'],
      ['direct-branch-name'],
      ['direct-native-identity-binding'],
      ['direct-parent-binding'],
      ['direct-worktree-binding'],
      ['direct-command-choice'],
      ['direct-command-counts'],
    ],
    'verified task contract and direct worktree state are reused without creation': [
      ['reuse-branch-ready'],
      ['reuse-branch-action'],
      ['reuse-branch-name'],
      ['reuse-native-identity-binding'],
      ['reuse-parent-binding'],
      ['reuse-worktree-binding'],
      ['reuse-command-choice'],
      ['reuse-command-counts'],
    ],
    'unsafe branch admission fails closed before every mutation': [
      ['collision-branch-blocked'],
      ['collision-branch-reason'],
      ['collision-no-branch-action'],
      ['collision-no-branch-name'],
      ['collision-no-command-choice'],
      ['collision-zero-command-counts'],
      ['collision-no-selected-bindings'],
      ['collision-no-parent-binding'],
      ['collision-no-worktree-binding'],
      ['collision-zero-forbidden-mutations'],
      ['owner-drift-branch-blocked'],
      ['owner-drift-branch-reason'],
      ['owner-drift-no-branch-action'],
      ['owner-drift-no-branch-name'],
      ['owner-drift-no-command-choice'],
      ['owner-drift-zero-command-counts'],
      ['owner-drift-no-selected-bindings'],
      ['owner-drift-no-parent-binding'],
      ['owner-drift-no-worktree-binding'],
      ['owner-drift-zero-forbidden-mutations'],
      ['worktree-drift-branch-blocked'],
      ['worktree-drift-branch-reason'],
      ['worktree-drift-no-branch-action'],
      ['worktree-drift-no-branch-name'],
      ['worktree-drift-no-command-choice'],
      ['worktree-drift-zero-command-counts'],
      ['worktree-drift-no-selected-bindings'],
      ['worktree-drift-no-parent-binding'],
      ['worktree-drift-no-worktree-binding'],
      ['worktree-drift-zero-forbidden-mutations'],
      ['preexisting-artifact-branch-blocked'],
      ['preexisting-artifact-branch-reason'],
      ['preexisting-artifact-no-branch-action'],
      ['preexisting-artifact-no-branch-name'],
      ['preexisting-artifact-no-command-choice'],
      ['preexisting-artifact-zero-command-counts'],
      ['preexisting-artifact-no-selected-bindings'],
      ['preexisting-artifact-no-parent-binding'],
      ['preexisting-artifact-no-worktree-binding'],
      ['preexisting-artifact-zero-forbidden-mutations'],
      ['title-identity-branch-blocked'],
      ['title-identity-branch-reason'],
      ['title-identity-no-branch-action'],
      ['title-identity-no-branch-name'],
      ['title-identity-no-command-choice'],
      ['title-identity-zero-command-counts'],
      ['title-identity-no-selected-bindings'],
      ['title-identity-no-parent-binding'],
      ['title-identity-no-worktree-binding'],
      ['title-identity-zero-forbidden-mutations'],
    ],
    'no merge': [['standalone-never-merges'], ['increment-never-merges']],
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
    'generic follow-up reviewers deduplicate without weakening canonical roles': [['one-focused-follow-up-reviewer'], ['stronger-reviewer-kept'], ['overlapping-reviewer-canceled'], ['one-explicit-decision-question'], ['same-evidence-assignments-rejected'], ['confidence-only-duplication-rejected'], ['cost-flag-cancels-overlap'], ['one-canonical-full-rereview-remains'], ['distinct-angle-workers-preserved'], ['adversarial-validator-pair-preserved']],
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
  'woostack-debug': {
    'root cause and regression evidence before proposal': [['valid-root-cause'], ['valid-regression-test']],
    'exact PR context with complete read-back': [['valid-project-provenance'], ['valid-issue-provenance'], ['valid-pr-source'], ['valid-readback']],
    'read-only investigation': [['valid-debug-no-writes'], ['valid-debug-source-unchanged']],
    'invalid discovery and mutation paths fail closed': [['rejected-debug-status'], ['rejected-debug-reasons'], ['rejected-debug-no-local-authority'], ['rejected-debug-no-mutation']],
  },
  'woostack-audit': {
    'standing target through synthetic all-added review': [structural('all-added-diff-created'), structural('all-added-line-present'), ['simplify-receipt-proof-recorded'], ['bugs-receipt-proof-recorded'], ['security-receipt-proof-recorded'], ['production-receipt-proof-recorded'], structural('validated-finding-recorded'), ['standing-target-unchanged']],
    'sanitized non-authoritative report with bounded remediation contract': [structural('audit-report-created'), ['report-is-explicitly-non-authoritative'], ['diagnostic-authority-recorded'], ['proposed-remediation-contract-recorded'], ['report-denies-development-authority']],
    'remediation defers Linear until fix root-cause proof': [['fix-handoff-ready'], ['linear-deferred-until-fix-proof'], ['report-remains-evidence'], ['fix-dispatched'], ['no-local-development-fallback']],
    'no remote mutation fix or merge': [['no-code-host-post'], ['no-linear-mutation-receipt'], ['no-audit-fix'], ['no-audit-merge'], ['no-linear-mutation-on-rejection'], ['no-repository-mutation-on-rejection']],
  },
  'woostack-visualize': {
    'exact managed source with complete read-back': [['valid-visualize-status'], ['valid-visualize-provenance'], ['valid-visualize-managed'], ['valid-visualize-readback']],
    'remote text encoded and output disposable': [['valid-visualize-encoding'], ['valid-visualize-disposable'], ['valid-visualize-not-authority'], ['valid-visualize-no-side-effects']],
    'invalid source paths fail closed without output': [['rejected-visualize-status'], ['rejected-visualize-reasons'], ['rejected-visualize-no-local-authority'], ['rejected-visualize-no-side-effects'], ['rejected-visualize-no-output']],
  },
  'woostack-init': {
    'automatic read-only setup failures never block local init': [
      ['missing-continues'],
      ['missing-skipped'],
      ['auth-continues'],
      ['auth-setup-blocked'],
      ['identity-continues'],
      ['identity-setup-blocked'],
      ['mapping-continues'],
      ['mapping-setup-blocked'],
      ['read-only-preserved'],
      ['read-back-preserved'],
    ],
    'successful setup preserves defaults and runs doctor after local writes': [
      ['success-linear-preserved'],
      ['success-writes-started-locally'],
      ['validation-order'],
      ['doctor-succeeded'],
    ],
    'incomplete active evidence remains preservation-only': [
      ['migration-active-status'],
      ['migration-active-classification'],
      ['migration-active-reason'],
      ['migration-active-stable-ids'],
      ['migration-active-no-deletion'],
      ['migration-active-no-mutation'],
      ['migration-active-spec-retained'],
      ['migration-active-plan-retained'],
    ],
    'eligible active creation requires authenticated approvals and complete pre-delete proof': [
      ['migration-create-status'],
      ['migration-create-approval-receipts'],
      ['migration-create-readback'],
      ['migration-create-spec-body'],
      ['migration-create-one-current-head'],
      ['migration-create-graph-complete'],
      ['migration-create-predelete-complete-set'],
      ['migration-create-predelete-git-bytes'],
      ['migration-create-deletion'],
    ],
    'historical completion requires exact merge evidence and recovery': [
      ['migration-historical-classification'],
      ['migration-historical-merge-proof'],
      ['migration-historical-all-receipts'],
      ['migration-historical-git-recovery'],
      ['migration-historical-stable-id'],
      ['migration-historical-provenance'],
      ['migration-historical-delete-after-proof'],
      ['migration-historical-remote-mutations'],
    ],
    'ambiguous classification preserves all local evidence': [
      ['migration-ambiguous-classification'],
      ['migration-ambiguous-provenance'],
      ['migration-ambiguous-no-deletions'],
      ['migration-ambiguous-no-remote-mutation'],
    ],
    'incomplete and unknown outcomes retain stable retry identity': [
      ['migration-incomplete-classification'],
      ['migration-incomplete-stable-id'],
      ['migration-incomplete-provenance'],
      ['migration-incomplete-no-deletions'],
      ['migration-incomplete-no-create-replay'],
      ['migration-unknown-classification'],
      ['migration-unknown-stable-id'],
      ['migration-unknown-retry-policy'],
      ['migration-unknown-provenance'],
      ['migration-unknown-no-deletions'],
      ['migration-unknown-no-create-replay'],
    ],
    'partial and foreign receipts fail closed without local deletion': [
      ['migration-partial-classification'],
      ['migration-partial-stable-ids'],
      ['migration-partial-provenance'],
      ['migration-partial-no-deletions'],
      ['migration-partial-no-remote-mutation'],
      ['migration-foreign-classification'],
      ['migration-foreign-stable-id'],
      ['migration-foreign-provenance'],
      ['migration-foreign-no-deletions'],
      ['migration-foreign-no-mutation'],
    ],
    'clean CRLF checkout uses filtered Git identity': [
      ['migration-crlf-comparison'],
      ['migration-crlf-raw-bytes-differ'],
      ['migration-crlf-normalized-identity'],
      ['migration-crlf-recovery-verified'],
      ['migration-crlf-no-deletion'],
    ],
    'mixed records classify and act per subset': [
      ['migration-mixed-record-classifications'],
      ['migration-mixed-active-subset'],
      ['migration-mixed-historical-subset'],
      ['migration-mixed-active-reconciled'],
      ['migration-mixed-history-linear-mutation'],
      ['migration-mixed-history-readback'],
      ['migration-mixed-deletion-mode'],
      ['migration-mixed-deletions'],
    ],
    'unsupported knowledge stores block without a disposition': [
      ['migration-unsupported-status'],
      ['migration-unsupported-reason'],
      ['migration-unsupported-paths'],
      ['migration-unsupported-deletion-not-applied'],
      ['migration-unsupported-no-deletions'],
      ['migration-unsupported-record-retained'],
      ['migration-unsupported-knowledge-retained'],
    ],
    'invalid knowledge disposition receipts block before deletion': [
      ['migration-invalid-disposition-status'],
      ['migration-invalid-disposition-reason'],
      ['migration-invalid-disposition-paths'],
      ['migration-invalid-disposition-deletion-not-applied'],
      ['migration-invalid-disposition-no-deletions'],
      ['migration-invalid-disposition-record-retained'],
      ['migration-invalid-disposition-knowledge-retained'],
      ['migration-invalid-disposition-record-recovery'],
      ['migration-invalid-disposition-knowledge-recovery'],
    ],
    'knowledge store dispositions preserve, export, or delete exact bytes': [
      ['migration-dispositions-status'],
      ['migration-dispositions-exact'],
      ['migration-dispositions-export-readback'],
      ['migration-dispositions-deletion-set'],
      ['migration-dispositions-local-deletions'],
      ['migration-dispositions-retained-hash'],
      ['migration-dispositions-export-source-hash'],
      ['migration-dispositions-export-readback-hash'],
      ['migration-dispositions-record-deleted'],
      ['migration-dispositions-knowledge-deleted'],
      ['migration-dispositions-delete-recovery'],
    ],
    'failed disposition deletion restores every source': [
      ['migration-disposition-rollback-status'],
      ['migration-disposition-rollback-reason'],
      ['migration-disposition-rollback-applied'],
      ['migration-disposition-rollback-no-deletions'],
      ['migration-disposition-rollback-legacy-hash'],
      ['migration-disposition-rollback-knowledge-hash'],
      ['migration-disposition-rollback-legacy-recovery'],
      ['migration-disposition-rollback-knowledge-recovery'],
    ],
    'late final-boundary failure preserves source': [
      ['migration-late-boundary-status'],
      ['migration-late-boundary-reason'],
      ['migration-late-deletion-not-applied'],
      ['migration-late-no-deletions'],
      ['migration-late-source-reported-retained'],
      ['migration-late-git-recovery-reported'],
      ['migration-late-source-retained'],
      ['migration-late-git-recovery'],
    ],
    'no local development record directories': [['no-local-specs'], ['no-local-plans'], ['no-local-fixes']],
    'no config clobber': [['config-before-hash'], ['config-after-hash'], ['config-preserved'], ['existing-note-preserved']],
  },
  'woostack-doctor': {
    'diagnose before explicit local repair approval': [
      ['diagnosis-completed-first'],
      ['repair-approval-pending'],
      ['doctor-config-not-repaired'],
    ],
    'remote diagnostics validate receipts without adapters': [
      ['receipt-rejected'],
      ['no-provider-invocation'],
      ['no-legacy-adapter-invocation'],
      ['remote-mutation-boundary'],
      ['live-failure-report-only'],
    ],
    'verified receipt passes read-only': [
      ['success-receipt-validated'],
      ['success-no-provider'],
      ['success-no-legacy-adapter'],
      ['success-no-remote-mutation'],
      ['success-no-repair'],
    ],
  },
  'woostack-status': {
    'one corrected current phase chain': [['phase-ready'], ['corrected-head'], ['correction-valid']],
    'feature and standalone board derive from Linear': [
      ['board-rendered'],
      ['standalone-row'],
      ['no-synthetic-project'],
      ['no-unrelated-mutation'],
    ],
    'terminal reconciliation is merge and acceptance backed': [
      ['only-app12-prior-eligible'],
      ['exact-issue-done'],
      ['second-read-accepted'],
      ['no-terminal-replay'],
      ['partial-project-not-complete'],
    ],
    'attribution mismatch blocks without fallback': [['mismatch-blocks'], ['no-write-on-mismatch'], ['no-fallback']],
    'canonical issue events dispatch strictly': [['all-canonical-kinds'], ['unsupported-kind-blocked'], ['no-generic-fallback']],
  },
};

// Each digest pins the canonical parsed corpus and the exact content of every safely resolved
// fixture. Case and assertion order remain significant, while fixture-reference order does not.
const corpusContract = (caseCount, digest) => ({ caseCount, digest });
const approvedCorpusContracts = {
  'woostack-eval': corpusContract(2, 'c7f619f14335a4f1e57978742eea6a590f055e3e364026834feeadf44f391806'),
  'woostack-build': corpusContract(7, '990901596606f1782bf76e680a4fd290a7dd8888de0f68cb34074b62ae9c2d75'),
  'woostack-plan': corpusContract(9, '9c51a5f76b8b0de3a590237621ca0c49385316c42080b6eb68f2e502869da4a6'),
  'woostack-fix': corpusContract(11, '17eb95fd57d54eb035d06bd32e0200467b34bdb53025a55be4ae13f8bca15496'),
  'woostack-execute': corpusContract(19, 'd1267048ebf05c778652723a64405bb2b5f023f1c343244dea11601d7f9935d4'),
  'woostack-execute-overnight': corpusContract(8, 'ef93b1b70e63ccef67e2f515041ace0d9652180d1303ce0b71652da6940416d6'),
  'woostack-commit': corpusContract(14, '12306fe19af4e4cf50d2cfba1ce4870c74ae54ee74d7644b05c1df2e0b0357ce'),
  'woostack-review': corpusContract(8, 'a0b1867da4944ba30d218689d8f5a68db321ac57cd864763f1dda696963006c0'),
  'woostack-sweep': corpusContract(9, 'f0a49f1ef44c9707c32b33bea645b4d3247a5128562d018491d5f0fd4399b1bc'),
  'woostack-address-comments': corpusContract(5, '63f3418aa58f54d6f1f4bef11ee283be2527b2501daf9b62d347c1cc6e1722d7'),
  'woostack-debug': corpusContract(2, '5d91d8f4c305cc987c5d8c301782601c89cbfafcad389d3ad98d8e0764843883'),
  'woostack-audit': corpusContract(2, 'c5699a63c26c01ef94d575ba1d2a6815ba68bae249db74f7f7f07eaeb7f100f4'),
  'woostack-visualize': corpusContract(2, '21d14268415178885c8df7cce00604065fc775c03f0ac6dc201d0523705655cb'),
  'woostack-init': corpusContract(24, '4070c2cd92674759c910ae37b246b99b749055e99c0b08f4f74833cf798096ed'),
  'woostack-doctor': corpusContract(3, '35017c9cc26a9ec68d10e1480b13dd4d29b1b8d793324267354a8e2751304eee'),
  'woostack-status': corpusContract(29, '1856a83e07e7174721d6e0d1433c0f68022411256c9b68ee04e99f78e6796b68'),
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

function isContained(root, candidate) {
  const relative = path.relative(root, candidate);
  return relative === '' ||
    (!relative.startsWith(`..${path.sep}`) && relative !== '..' && !path.isAbsolute(relative));
}

function normalizeFixtureReference(reference, location) {
  if (
    typeof reference !== 'string' ||
    !reference ||
    reference.includes('\\') ||
    reference.includes('\0') ||
    path.posix.isAbsolute(reference)
  ) {
    throw new Error(`${location} must be a non-empty relative POSIX fixture path`);
  }
  const segments = reference.split('/');
  if (
    segments.includes('..') ||
    segments.includes('.') ||
    segments.includes('') ||
    path.posix.normalize(reference) !== reference
  ) {
    throw new Error(`${location} must be normalized and remain inside evals/fixtures`);
  }
  return reference;
}

function requiredLstat(candidate, location) {
  try {
    return fs.lstatSync(candidate);
  } catch (error) {
    if (error?.code === 'ENOENT' || error?.code === 'ENOTDIR') {
      throw new Error(`${location} is missing`);
    }
    throw new Error(`${location} cannot be read: ${error?.code ?? 'unknown error'}`);
  }
}


function fixtureContentDigest(fixturesRoot, resolvedFixturesRoot, reference, location) {
  const candidate = path.resolve(fixturesRoot, ...reference.split('/'));
  if (!isContained(fixturesRoot, candidate)) {
    throw new Error(`${location} escapes evals/fixtures`);
  }

  let current = fixturesRoot;
  let info;
  const segments = reference.split('/');
  for (const [index, segment] of segments.entries()) {
    current = path.join(current, segment);
    info = requiredLstat(current, location);
    if (info.isSymbolicLink()) {
      throw new Error(`${location} must not resolve through a symlink`);
    }
    if (index < segments.length - 1 && !info.isDirectory()) {
      throw new Error(`${location} has a non-directory path component`);
    }
  }
  if (!info.isFile()) {
    throw new Error(`${location} must resolve to a regular file`);
  }

  const resolvedCandidate = fs.realpathSync(candidate);
  if (!isContained(resolvedFixturesRoot, resolvedCandidate)) {
    throw new Error(`${location} escapes evals/fixtures`);
  }
  const contents = fs.readFileSync(resolvedCandidate);
  if (reference.endsWith('.json')) {
    try {
      JSON.parse(contents);
    } catch (error) {
      if (!(error instanceof SyntaxError)) throw error;
    }
  }
  return crypto.createHash('sha256').update(contents).digest('hex');
}

function corpusSemanticDigest(corpus, fixturesRoot, location) {
  if (!corpus || typeof corpus !== 'object' || !Array.isArray(corpus.cases)) {
    throw new Error(`${location} must contain a cases array`);
  }

  const declaredFixtures = new Set();
  const normalizedCorpus = {
    ...corpus,
    cases: corpus.cases.map((behaviorCase, caseIndex) => {
      if (!behaviorCase || typeof behaviorCase !== 'object' || Array.isArray(behaviorCase)) {
        throw new Error(`${location} case ${caseIndex} is malformed`);
      }
      if (!Object.hasOwn(behaviorCase, 'fixtures')) return behaviorCase;
      if (!Array.isArray(behaviorCase.fixtures)) {
        throw new Error(`${location} case ${caseIndex} fixtures must be an array`);
      }

      const seen = new Set();
      const fixtures = behaviorCase.fixtures.map((reference, fixtureIndex) => {
        const fixtureLocation = `${location}/cases/${caseIndex}/fixtures/${fixtureIndex}`;
        const normalized = normalizeFixtureReference(reference, fixtureLocation);
        if (seen.has(normalized)) {
          throw new Error(`${fixtureLocation} duplicates fixture ${normalized}`);
        }
        seen.add(normalized);
        declaredFixtures.add(normalized);
        return normalized;
      }).sort();
      return { ...behaviorCase, fixtures };
    }),
  };

  let resolvedFixturesRoot;
  if (declaredFixtures.size > 0) {
    const rootInfo = requiredLstat(fixturesRoot, `${location} fixture root`);
    if (rootInfo.isSymbolicLink() || !rootInfo.isDirectory()) {
      throw new Error(`${location} fixture root must be a real directory`);
    }
    resolvedFixturesRoot = fs.realpathSync(fixturesRoot);
  }

  const fixtures = [...declaredFixtures].sort().map((reference) => ({
    path: reference,
    digest: fixtureContentDigest(
      fixturesRoot,
      resolvedFixturesRoot,
      reference,
      `${location} fixture ${reference}`,
    ),
  }));
  return semanticDigest({ corpus: normalizedCorpus, fixtures });
}

function assertCorpusContract(corpus, fixturesRoot, expectedContract, location) {
  if (!expectedContract) throw new Error(`${location} has no approved corpus contract`);
  if (corpus.cases.length !== expectedContract.caseCount) {
    throw new Error(`${location} case count changed`);
  }
  const caseIds = corpus.cases.map((behaviorCase) => behaviorCase.id);
  if (new Set(caseIds).size !== caseIds.length) {
    throw new Error(`${location} duplicates a case ID`);
  }
  for (const behaviorCase of corpus.cases) {
    const assertionIds = behaviorCase.assertions.map((assertion) => assertion.id);
    if (new Set(assertionIds).size !== assertionIds.length) {
      throw new Error(`${location} case ${behaviorCase.id} duplicates an assertion ID`);
    }
    if (new Set(behaviorCase.capabilities).size !== behaviorCase.capabilities.length) {
      throw new Error(`${location} case ${behaviorCase.id} duplicates a capability`);
    }
  }
  if (corpusSemanticDigest(corpus, fixturesRoot, location) !== expectedContract.digest) {
    throw new Error(`${location} corpus semantics or fixture content changed`);
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

const semanticProbeFixtureRoot = path.join(resultsRoot, 'semantic-probe-fixtures');
const semanticProbeFixturePath = path.join(semanticProbeFixtureRoot, 'state.json');
const semanticProbeFixtureContents = Buffer.from(
  '{"approved":true,"details":{"owner":"probe","revision":1}}\n',
  'utf8',
);
fs.mkdirSync(semanticProbeFixtureRoot, { recursive: true });
fs.writeFileSync(semanticProbeFixturePath, semanticProbeFixtureContents);
fs.writeFileSync(path.join(semanticProbeFixtureRoot, 'receipt.txt'), 'stable receipt\n');

function reverseObjectKeyOrder(value) {
  if (Array.isArray(value)) return value.map(reverseObjectKeyOrder);
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).reverse().map(([key, child]) => [key, reverseObjectKeyOrder(child)]),
    );
  }
  return value;
}

const semanticProbe = {
  schemaVersion: 1,
  skill: 'probe',
  cases: [
    {
      id: 'owner-a',
      prompt: 'Classify this bounded local receipt without any remote request or mutation.',
      fixtures: ['state.json', 'receipt.txt'],
      expected: 'The exact approved state is returned and the receipt remains unchanged.',
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
      prompt: 'Classify this second bounded receipt without contacting any remote service.',
      fixtures: [],
      expected: 'The blocked state remains explicit and no side effect is attempted.',
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
const semanticProbeContract = corpusContract(
  semanticProbe.cases.length,
  corpusSemanticDigest(semanticProbe, semanticProbeFixtureRoot, '<probe>'),
);
const mutateProbe = (operation) => {
  const probe = JSON.parse(JSON.stringify(semanticProbe));
  operation(probe);
  return () => assertCorpusContract(
    probe,
    semanticProbeFixtureRoot,
    semanticProbeContract,
    '<probe>',
  );
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
expectRejected('duplicate assertion ID within a case', mutateProbe((probe) => {
  probe.cases[0].assertions.push({ ...probe.cases[0].assertions[0] });
}));
expectRejected('duplicate case ID', mutateProbe((probe) => {
  probe.cases[1].id = 'owner-a';
}));
expectRejected('extra allowed but unneeded capability', mutateProbe((probe) => {
  probe.cases[0].capabilities.push('write-workspace');
}));
const reorderedFixtureProbe = JSON.parse(JSON.stringify(semanticProbe));
reorderedFixtureProbe.cases[0].fixtures.reverse();
assertCorpusContract(
  reorderedFixtureProbe,
  semanticProbeFixtureRoot,
  semanticProbeContract,
  '<reordered-fixture-probe>',
);
const reformattedProbe = JSON.parse(
  JSON.stringify(reverseObjectKeyOrder(semanticProbe), null, 2),
);
assertCorpusContract(
  reformattedProbe,
  semanticProbeFixtureRoot,
  semanticProbeContract,
  '<reformatted-json-probe>',
);
expectRejected('changed fixture content', () => {
  fs.writeFileSync(
    semanticProbeFixturePath,
    '{"approved":false,"details":{"owner":"probe","revision":1}}\n',
  );
  try {
    assertCorpusContract(
      semanticProbe,
      semanticProbeFixtureRoot,
      semanticProbeContract,
      '<changed-fixture-probe>',
    );
  } finally {
    fs.writeFileSync(semanticProbeFixturePath, semanticProbeFixtureContents);
  }
});
expectRejected('missing fixture reference', mutateProbe((probe) => {
  probe.cases[0].fixtures = ['missing.json'];
}));
expectRejected('traversing fixture reference', mutateProbe((probe) => {
  probe.cases[0].fixtures = ['../outside.json'];
}));
fs.mkdirSync(path.join(semanticProbeFixtureRoot, 'directory'));
expectRejected('non-file fixture reference', mutateProbe((probe) => {
  probe.cases[0].fixtures = ['directory'];
}));
expectRejected('duplicate fixture reference', mutateProbe((probe) => {
  probe.cases[0].fixtures = ['state.json', 'state.json'];
}));
expectRejected('non-string fixture reference', mutateProbe((probe) => {
  probe.cases[0].fixtures = [42];
}));
expectRejected('non-normalized fixture reference', mutateProbe((probe) => {
  probe.cases[0].fixtures = ['./state.json'];
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

  assertCorpusContract(
    corpus,
    path.join(path.dirname(corpusPath), 'fixtures'),
    approvedCorpusContracts[skill],
    packagePath,
  );
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

  const assertionsById = new Map();
  for (const behaviorCase of corpus.cases) {
    for (const assertion of behaviorCase.assertions) {
      const matches = assertionsById.get(assertion.id) ?? [];
      matches.push(assertion);
      assertionsById.set(assertion.id, matches);
    }
  }
  const contracts = requiredContractProofs[skill];
  if (!contracts) throw new Error(`missing contract map for ${skill}`);
  for (const [contract, proofGroups] of Object.entries(contracts)) {
    const contractEvidence = [];
    for (const proofGroup of proofGroups) {
      const specification = Array.isArray(proofGroup)
        ? { ids: proofGroup, critical: true }
        : proofGroup;
      const matches = specification.ids.flatMap((id) => assertionsById.get(id) ?? []);
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
  throw new Error('critical contract map must cover exactly the seventeen required packages');
}
NODE

printf 'PASS: validated critical behavior corpora for exactly 17 required packages\n'
