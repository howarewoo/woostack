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
    'official Linear MCP feature authority': [
      ['official-linear-mcp-only'],
      ['official-linear-mcp-endpoint'],
      ['complete-official-mcp-preflight'],
      ['exact-feature-project-retained'],
      ['exact-feature-project-native-id'],
      ['feature-project-read-back'],
      ['specification-project-update'],
      ['all-managed-readbacks-complete'],
    ],
    'native phase and complete issue graph gate overnight dispatch': [
      ['exact-native-phase-chain'],
      ['complete-increment-issue-graph'],
      ['overnight-dispatch-preconditions-verified'],
    ],
    'local and document inputs never become development authority': [
      ['build-input-blocked-without-canonical-project'],
      ['build-input-canonical-project-unresolved'],
      ['build-input-local-spec-rejected'],
      ['build-input-local-plan-rejected'],
      ['build-input-linear-document-rejected'],
      ['build-input-no-authority-fallback'],
      ['build-input-no-managed-mutation'],
      ['build-input-no-git-mutation'],
      ['build-input-requires-canonical-project-identity'],
    ],
    'raw capability and authentication failures override preflightComplete': [
      ['build-snapshot-01-blocked'],
      ['build-snapshot-01-reason'],
      ['build-snapshot-01-zero-dispatch'],
      ['build-snapshot-01-zero-managed-mutation'],
      ['build-snapshot-01-zero-repository-mutation'],
      ['build-snapshot-02-blocked'],
      ['build-snapshot-02-reason'],
      ['build-snapshot-02-zero-dispatch'],
      ['build-snapshot-02-zero-managed-mutation'],
      ['build-snapshot-02-zero-repository-mutation'],
    ],
    'incomplete pagination and read-back override preflightComplete': [
      ['build-snapshot-03-blocked'],
      ['build-snapshot-03-reason'],
      ['build-snapshot-03-zero-dispatch'],
      ['build-snapshot-03-zero-managed-mutation'],
      ['build-snapshot-03-zero-repository-mutation'],
      ['build-snapshot-04-blocked'],
      ['build-snapshot-04-reason'],
      ['build-snapshot-04-zero-dispatch'],
      ['build-snapshot-04-zero-managed-mutation'],
      ['build-snapshot-04-zero-repository-mutation'],
    ],
    'mutation and independent receipt mismatch blocks': [
      ['build-snapshot-05-blocked'],
      ['build-snapshot-05-reason'],
      ['build-snapshot-05-zero-dispatch'],
      ['build-snapshot-05-zero-managed-mutation'],
      ['build-snapshot-05-zero-repository-mutation'],
    ],
    'duplicate and multiple lifecycle heads block': [
      ['build-snapshot-06-blocked'],
      ['build-snapshot-06-reason'],
      ['build-snapshot-06-zero-dispatch'],
      ['build-snapshot-06-zero-managed-mutation'],
      ['build-snapshot-06-zero-repository-mutation'],
      ['build-snapshot-07-blocked'],
      ['build-snapshot-07-reason'],
      ['build-snapshot-07-zero-dispatch'],
      ['build-snapshot-07-zero-managed-mutation'],
      ['build-snapshot-07-zero-repository-mutation'],
    ],
    'wrong predecessor and native category block': [
      ['build-snapshot-08-blocked'],
      ['build-snapshot-08-reason'],
      ['build-snapshot-08-zero-dispatch'],
      ['build-snapshot-08-zero-managed-mutation'],
      ['build-snapshot-08-zero-repository-mutation'],
      ['build-snapshot-09-blocked'],
      ['build-snapshot-09-reason'],
      ['build-snapshot-09-zero-dispatch'],
      ['build-snapshot-09-zero-managed-mutation'],
      ['build-snapshot-09-zero-repository-mutation'],
    ],
    'missing foreign and cyclic increment dependency relations block': [
      ['build-snapshot-10-blocked'],
      ['build-snapshot-10-reason'],
      ['build-snapshot-10-zero-dispatch'],
      ['build-snapshot-10-zero-managed-mutation'],
      ['build-snapshot-10-zero-repository-mutation'],
      ['build-snapshot-11-blocked'],
      ['build-snapshot-11-reason'],
      ['build-snapshot-11-zero-dispatch'],
      ['build-snapshot-11-zero-managed-mutation'],
      ['build-snapshot-11-zero-repository-mutation'],
      ['build-snapshot-12-blocked'],
      ['build-snapshot-12-reason'],
      ['build-snapshot-12-zero-dispatch'],
      ['build-snapshot-12-zero-managed-mutation'],
      ['build-snapshot-12-zero-repository-mutation'],
    ],
    'exactly three explicit gates': [['exact-three-gates']],
    'Go, overnight, or handoff terminal choice': [
      ['complete-terminal-choice-set'],
      ['overnight-choice-preserved'],
      ['overnight-driver-selected'],
    ],
    'no merge': [['build-never-merges']],
  },
  'woostack-plan': {
    'official MCP and exact feature project authorize planning': [
      ['plan-official-linear-mcp'],
      ['plan-official-mcp-endpoint'],
      ['plan-complete-mcp-preflight'],
      ['plan-exact-feature-project'],
      ['plan-current-approved-head'],
    ],
    'verified planning event precedes every issue mutation': [
      ['plan-exact-planning-readback'],
      ['plan-phase-before-issue-mutations'],
      ['plan-final-phase'],
      ['plan-backlog-category'],
    ],
    'complete stable issue graph and native relations are read back': [
      ['plan-complete-increment-graph'],
      ['plan-all-readbacks-complete'],
    ],
    'missing or partial official MCP blocks all mutation': [
      ['plan-missing-partial-mcp-decisions'],
      ['plan-mcp-blocks-project-update'],
      ['plan-mcp-blocks-issues'],
      ['plan-mcp-blocks-repository'],
    ],
    'wrong role or repository blocks before phase consumption': [
      ['plan-wrong-role-repository-decisions'],
      ['plan-identity-blocks-phase-read'],
      ['plan-identity-blocks-planning-mutation'],
      ['plan-identity-blocks-issue-mutation'],
    ],
    'duplicate revisions and multiple current heads fail closed': [
      ['plan-duplicate-head-decisions'],
      ['plan-conflict-selects-no-head'],
      ['plan-conflict-no-planning-mutation'],
      ['plan-conflict-no-issue-mutation'],
    ],
    'unknown planning mutation preserves identity without retry': [
      ['plan-unknown-mutation-reason'],
      ['plan-unknown-preserves-event-id'],
      ['plan-unknown-single-append'],
      ['plan-unknown-zero-rediscovery'],
      ['plan-unknown-no-replacement-event'],
      ['plan-unknown-no-same-phase-retry'],
      ['plan-unknown-no-issue-mutation'],
    ],
    'incomplete event or issue read-back stops at its mutation boundary': [
      ['plan-incomplete-event-readback-reason'],
      ['plan-incomplete-event-not-accepted'],
      ['plan-incomplete-event-no-issues'],
      ['plan-incomplete-issue-readback-reason'],
      ['plan-incomplete-issue-not-accepted'],
      ['plan-incomplete-issue-no-relations'],
      ['plan-incomplete-issue-stable-id'],
    ],
    'planning never appends ready or mutates the repository': [
      ['plan-does-not-append-ready'],
      ['plan-no-repository-mutation'],
    ],
  },
  'woostack-fix': {
    'root cause before managed issue': [['root-cause-blocker'], ['no-issue-before-root-cause']],
    'verified standalone work item without wrapper project': [
      ['verified-issue-state'],
      ['standalone-role-retained'],
      ['no-wrapper-project'],
      ['complete-create-readback'],
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
    'caller-created branch claim and worktree are reused without creation': [
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
    'official MCP preflight blocks before project access': [
      ['missing-mcp-blocks'],
      ['auth-blocks'],
      ['identity-blocks'],
      ['mapping-blocks'],
      ['read-only-blocks'],
      ['read-back-blocks'],
    ],
    'successful preflight precedes workspace writes': [
      ['success-zero-project-access-before-preflight'],
      ['success-writes-started-after-preflight'],
      ['validation-order'],
      ['doctor-validation-succeeded'],
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
      ['migration-historical-no-remote-mutation'],
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
      ['migration-mixed-history-no-linear'],
      ['migration-mixed-deletion-mode'],
      ['migration-mixed-deletions'],
    ],
    'late final-boundary failure preserves source and knowledge': [
      ['migration-late-boundary-status'],
      ['migration-late-boundary-reason'],
      ['migration-late-rewrite-not-applied'],
      ['migration-late-original-provenance'],
      ['migration-late-no-deletions'],
      ['migration-late-source-retained'],
      ['migration-late-knowledge-retained'],
    ],
    'no local development record directories': [['no-local-specs'], ['no-local-plans'], ['no-local-fixes']],
    'no config clobber': [['config-before-hash'], ['config-after-hash'], ['config-preserved-on-disk'], ['existing-file-preserved-on-disk']],
  },
  'woostack-doctor': {
    'diagnose before explicit local repair approval': [
      ['diagnosis-completed-first'],
      ['repair-approval-pending'],
      ['doctor-config-not-repaired'],
    ],
    'remote diagnostics consume receipts without adapters': [
      ['one-receipt-provenance-observed'],
      ['no-provider-invocation'],
      ['no-legacy-adapter-invocation'],
      ['remote-mutation-boundary'],
      ['live-failure-report-only'],
    ],
    'verified receipt passes read-only': [
      ['success-one-provenance'],
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
  'woostack-build': corpusContract(17, '8a9bb51d77f6e5be37578b9dcfe3dba7a0f02cafaeaaab8b7118858a801a4a4f'),
  'woostack-plan': corpusContract(9, '580bded363cfbfa30fc06a3207bfd132182798742f6347e69eb7b1c4713b8224'),
  'woostack-fix': corpusContract(5, 'cde7dea1b27e6035a5b30950f65c0bf86fbf50eb85297d55fb5026852aace487'),
  'woostack-execute': corpusContract(19, '95a0553fce8370202296b17828bbc9f7d4ce6aef747de72f7015164bcee0bf88'),
  'woostack-execute-overnight': corpusContract(8, '15902f239a11d81e2b1667d249cc25cee5f62ead215b8afa79be16f9fa20136a'),
  'woostack-commit': corpusContract(14, 'b929bdcc7b1f83cd860116e1419d84b559d491ec26f33a990b8b9eddce644205'),
  'woostack-review': corpusContract(8, 'a0b1867da4944ba30d218689d8f5a68db321ac57cd864763f1dda696963006c0'),
  'woostack-sweep': corpusContract(8, '098852d02511483fc7b9fa207c2f179f86eedf9ae518e6f13802f782e4cf7344'),
  'woostack-address-comments': corpusContract(5, '094be219ed4a95a6117c6ed0609a50c81b31dbc75ca8eaa905cd94dd1a648234'),
  'woostack-ask': corpusContract(2, '8c57c5e2cc5caf6c1c477b11249c94595b82e3195ad7193a80e8a44b025999b3'),
  'woostack-debug': corpusContract(2, '5d91d8f4c305cc987c5d8c301782601c89cbfafcad389d3ad98d8e0764843883'),
  'woostack-audit': corpusContract(2, 'c1c6ffac6012703cf566d9e9e394bcf887723a5e2293b95214863c206ab114a5'),
  'woostack-respond': corpusContract(4, 'cb5f36c58a34253ca21a3c8932c879bea9b4a5336090c5438ef5155b08daa6b1'),
  'woostack-visualize': corpusContract(2, '21d14268415178885c8df7cce00604065fc775c03f0ac6dc201d0523705655cb'),
  'woostack-init': corpusContract(18, 'fcd632f0862c9a32e1a513a74abbbb1fd9a8e6d7b73c799033031c82bef1e09a'),
  'woostack-doctor': corpusContract(3, '531453d08cf16439d5a9f36d68c6502e028c4056699ed01e9300e07ff2b07c80'),
  'woostack-status': corpusContract(29, 'fbc77312e479cc5d2cdc865660178610b5ed1f984c5bb528e4ba84d4b85ad0a2'),
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
  throw new Error('critical contract map must cover exactly the eighteen required packages');
}
NODE

printf 'PASS: validated critical behavior corpora for exactly 18 required packages\n'
