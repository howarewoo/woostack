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
  skills/woostack-bootstrap
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
  'skills/woostack-bootstrap',
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
    'canonical project admission through official MCP': [
      ['build-official-mcp'],
      ['build-project-created'],
      ['build-operation-identity-preserved'],
      ['build-project-readback'],
    ],
    'nonblocking provider mirror failure preserves local authority': [
      ['build-local-ready'],
      ['build-mirror-failed'],
      ['build-local-authority-preserved'],
      ['build-handoff-preserved'],
      ['build-provider-zero-repository-mutation'],
    ],
    'noncanonical authority inputs block safely': [
      ['build-authority-blocked'],
      ['build-authority-decisions'],
      ['build-authority-provider-artifacts-non-authorizing'],
      ['build-authority-retained-local-artifacts-required'],
      ['build-authority-no-native-linear-approval-reason'],
      ['build-authority-zero-provider-mutation'],
      ['build-authority-zero-dispatch'],
      ['build-authority-zero-repository-mutation'],
    ],
    'local run artifacts are retained upon completion': [
      ['retention-ready'],
      ['retention-verified'],
      ['retention-next-skill'],
      ['retention-execute-allowed'],
    ],
    'canonical issue reference validation precedes graph writes': [
      ['build-read-shapes-blocked'],
      ['build-read-shapes-two-creates'],
      ['build-read-shapes-one-membership-mutation'],
      ['build-read-shapes-one-relation-mutation'],
      ['build-read-shapes-four-provider-mutations'],
      ['build-read-shapes-zero-repository-mutation'],
    ],
    'verified build routes to user handoff': [
      ['handoff-options'],
      ['handoff-command'],
      ['handoff-details-complete'],
      ['execute-dispatched-once'],
      ['abandon-retains-artifacts-without-dispatch'],
    ],
    'no merge': [['never-merges']],
  },
  'woostack-plan': {
    'Linear exact project receives a strict direct-issue chain': [
      ['plan-existing-project-required'],
      ['plan-project-reused'],
      ['plan-two-direct-issues'],
      ['plan-no-parent-issue'],
      ['plan-contiguous-ordinals'],
      ['plan-strict-dependency'],
      ['plan-readback'],
    ],
    'Plane provider and exact project repository identity are required': [
      ['plan-plane-provider'],
      ['plan-plane-base-url'],
      ['plan-plane-workspace'],
      ['plan-plane-project-id'],
      ['plan-plane-repository'],
    ],
    'Plane native and readable work-item IDs are both required': [
      ['plan-plane-native-ids'],
      ['plan-plane-readable-work-item-ids'],
    ],
    'Plane project memberships are required': [
      ['plan-plane-project-memberships'],
    ],
    'Plane native-to-external mapping and external source are required': [
      ['plan-plane-native-external-mapping'],
      ['plan-plane-external-source'],
    ],
    'Plane read-back is required': [
      ['plan-plane-readback'],
    ],
    'Plane terminal zero-match discovery is required': [
      ['plan-plane-zero-match-discovery'],
    ],
    'Plane exact five provider writes are required': [
      ['plan-plane-provider-write-count'],
    ],
    'Plane operation scope is required on provider operations': [
      ['plan-plane-operation-base-url'],
      ['plan-plane-operation-workspace'],
      ['plan-plane-operation-project-id'],
    ],
    'Plane relation endpoints are required': [
      ['plan-plane-relation-endpoints'],
      ['plan-plane-native-relation-id'],
    ],
    'direct specification requires an existing exact project': [
      ['plan-exact-project-blocked'],
      ['plan-no-provider-mutation'],
    ],
    'invalid issue contracts fail before mutation': [
      ['plan-invalid-contracts-blocked'],
      ['plan-invalid-no-provider-mutation'],
    ],
    'standalone graph preflight validates canonical provider shapes': [
      ['plan-linear-shape-status'],
      ['plan-linear-shape-decisions'],
      ['plan-linear-shape-zero-provider-mutation'],
      ['plan-linear-shape-zero-repository-mutation'],
    ],
    'build delegation returns a provider-free candidate': [
      ['plan-delegated-candidate'],
      ['plan-delegated-tasks'],
      ['plan-delegated-dependency'],
      ['plan-delegated-no-provider-writes'],
      ['plan-delegated-sync-owner'],
    ],
    'plan never approves executes or mutates the repository': [
      ['plan-no-approval'],
      ['plan-no-execution'],
      structural('plan-no-repository-mutation'),
    ],
  },
  'woostack-fix': {
    'target repository boundary precedes provider admission': [
      ['foreign-target-blocked'],
      ['unwritable-target-blocked'],
      ['writable-target-continues'],
    ],
    'debug defers untrusted source identity': [
      ['no-provider-call'],
      ['source-is-untrusted'],
    ],
    'root cause proof precedes project and repository mutation': [
      ['blocked'],
      ['no-project'],
      ['no-repository-mutation'],
    ],
    'production inputs route through debug': [['fix-route'], ['debug-required']],
    'one canonical project preserves the source record': [
      ['one-project'],
      ['project-readback'],
      ['source-only-link'],
      ['source-preserved'],
    ],
    'provider mirror failure is nonblocking for local authority': [
      ['local-ready'],
      ['mirror-failed'],
      ['local-authority-valid'],
      ['handoff-allowed'],
      ['no-repository-mutation'],
    ],
    'source validation precedes project link': [
      ['fix-source-preflight-overall-blocked'],
      ['fix-source-two-link-writes'],
      ['fix-source-two-provider-mutations'],
      ['fix-source-zero-repository-mutation'],
    ],
  },
  'woostack-execute': {
    'project mode selects the lowest unfinished issue': [
      ['project-selected'],
      ['project-ordinal'],
      ['project-no-sibling'],
    ],
    'stop markers pause before the next issue': [['stop-paused'], ['stop-no-next'], ['stop-cleanup']],
    'issue mode never advances siblings': [['issue-selected'], ['issue-no-siblings'], ['issue-stops']],
    'local run admission requires exact valid manifest': [
      ['local-run-proceed'],
      ['fuzzy-run-status'],
      ['unsafe-perm-status'],
      ['legacy-schema-status'],
      ['abandoned-run-status'],
    ],
    'resume reuses existing delivery state': [['resume-pr'], ['resume-no-duplicate'], ['resume-retained']],
    'failure retains the worktree': [['failure-retained'], ['failure-boundary'], ['failure-next']],
    'verified delivery stops at open PR without merge': [
      ['open-pr-no-merge'],
      ['explicit-merge-no-authority'],
    ],
  },
  'woostack-commit': {
    'supplied issue receives exact closing reference on PR body': [
      ['standalone-commit-provider'],
      ['standalone-commit-closing-ref'],
      ['increment-commit-provider'],
      ['increment-commit-closing-ref'],
    ],
    'delivery note synchronization avoids role relation and state mutations': [
      ['standalone-commit-readback'],
      ['standalone-commit-zero-relation-mutations'],
      ['standalone-commit-zero-state-mutations'],
      ['increment-commit-readback'],
      ['increment-commit-zero-relation-mutations'],
      ['increment-commit-zero-state-mutations'],
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
      ['direct-identity-binding'],
      ['direct-parent-binding'],
      ['direct-worktree-binding'],
      ['direct-command-choice'],
      ['direct-command-counts'],
    ],
    'verified task contract and direct worktree state are reused without creation': [
      ['reuse-branch-ready'],
      ['reuse-branch-action'],
      ['reuse-branch-name'],
      ['reuse-identity-binding'],
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
      ['run-drift-branch-blocked'],
      ['run-drift-branch-reason'],
      ['run-drift-no-branch-action'],
      ['run-drift-no-branch-name'],
      ['run-drift-no-command-choice'],
      ['run-drift-zero-command-counts'],
      ['run-drift-no-selected-bindings'],
      ['run-drift-no-parent-binding'],
      ['run-drift-no-worktree-binding'],
      ['run-drift-zero-forbidden-mutations'],
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
    'no merge': [['standalone-commit-no-merge'], ['increment-commit-no-merge']],
  },
  'woostack-review': {
    'one exact PR is the only public mode': [['accepts-exact-pr'], ['rejects-other-modes'], ['review-read-only']],
    'one multi-angle swarm has one evidence adjudicator': [
      ['all-angles'],
      ['one-swarm'],
      ['one-adjudicator'],
      ['finalization-after-adjudication'],
      ['no-early-merge'],
    ],
    'accepted findings produce one native PR event': [
      ['blocker-event'],
      ['nit-event'],
      ['all-findings-posted'],
    ],
    'no edit or merge': [['no-code-edits'], ['no-merge-or-edit']],
  },
  'woostack-sweep': {
    'preexisting comments are addressed before one review': [
      ['order'],
      ['old-thread-before-review'],
      ['review-once-each'],
    ],
    'nit-only rounds advance without rereview': [
      ['nit-resolved'],
      ['address-without-rereview'],
      ['correction-only-proof'],
      ['focused-verification'],
      ['descendant-restack'],
      ['complete-evidence'],
      ['clean'],
    ],
    'blocking rounds restack descendants and review again': [
      ['review-count'],
      ['restack-descendants'],
      ['heads-current'],
    ],
    'unchanged blockers halt with an exact resume boundary': [
      ['blocked'],
      ['no-extra-review'],
      ['exact-blocker'],
      ['resume'],
    ],
    'stale-parent mergeability matrix and direct Review independence': [
      ['mergeable-review-once'],
      ['mergeable-no-restack'],
      ['mergeable-clean-eligible'],
      ['stale-sync-informational'],
      ['stale-sync-does-not-invalidate'],
      ['conflicting-no-review'],
      ['conflicting-no-address'],
      ['conflicting-not-clean-eligible'],
      ['conflicting-guarded-restack'],
      ['unknown-no-review'],
      ['unknown-no-address'],
      ['unknown-not-clean-eligible'],
      ['unknown-no-restack'],
      ['unknown-blocked'],
      ['direct-review-independent'],
      ['direct-review-no-conflict-authority'],
    ],
  },
  'woostack-address-comments': {
    'one exact PR is required': [['blocked'], ['exact-pr-reason'], ['no-mutation']],
    'every thread receives a deterministic disposition': [
      ['valid-fixed'],
      ['obsolete-pushed-back'],
      ['unsafe-blocked'],
      ['only-valid-edit'],
    ],
    'handled threads are replied to and resolved': [
      ['replies-for-handled'],
      ['resolutions-for-handled'],
    ],
    'head drift restarts discovery without stale effects': [
      ['blocked-stale'],
      ['one-restart'],
      ['no-stale-reply'],
      ['no-stale-resolution'],
      ['resume-boundary'],
    ],
    'no merge': [['never-merges']],
  },
  'woostack-debug': {
    'root cause and regression evidence before proposal': [['valid-root-cause'], ['valid-regression-test']],
    'exact PR context with complete read-back': [['valid-project-provenance'], ['valid-issue-provenance'], ['valid-pr-source'], ['valid-readback']],
    'read-only investigation': [['valid-debug-no-writes'], ['valid-debug-source-unchanged']],
    'invalid discovery and mutation paths fail closed': [['rejected-debug-status'], ['rejected-debug-reasons'], ['rejected-debug-no-local-authority'], ['rejected-debug-no-mutation']],
  },
  'woostack-audit': {
    'standing target through synthetic all-added review': [
      structural('all-added-diff-created'),
      structural('all-added-line-present'),
      ['simplify-receipt-proof-recorded'],
      ['bugs-receipt-proof-recorded'],
      ['security-receipt-proof-recorded'],
      ['production-receipt-proof-recorded'],
      structural('validated-finding-recorded'),
      ['standing-target-unchanged'],
    ],
    'sanitized non-authoritative report with bounded remediation contract': [
      structural('audit-report-created'),
      ['report-is-explicitly-non-authoritative'],
      ['diagnostic-authority-recorded'],
      ['proposed-remediation-contract-recorded'],
      ['report-denies-development-authority'],
    ],
    'remediation defers provider until fix root-cause proof': [
      ['fix-handoff-ready'],
      ['provider-deferred-until-fix-proof'],
      ['report-remains-evidence'],
      ['fix-dispatched'],
      ['no-local-development-fallback'],
    ],
    'no remote mutation fix or merge': [
      ['no-code-host-post'],
      ['no-provider-mutation-receipt'],
      ['no-audit-fix'],
      ['no-audit-merge'],
      ['no-provider-mutation-on-rejection'],
      ['no-repository-mutation-on-rejection'],
    ],
    'optional provider context resolves exact scoped provenance': [
      ['audit-plane-context-resolved'],
      ['audit-plane-provenance'],
      ['audit-plane-foreign-omitted'],
      ['audit-plane-zero-mutation'],
    ],
  },
  'woostack-visualize': {
    'exact managed source with complete read-back': [['valid-visualize-status'], ['valid-visualize-provenance'], ['valid-visualize-source-accepted'], ['valid-visualize-readback']],
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
    'selected Linear receipt rejection is required': [
      ['receipt-rejected'],
    ],
    'selected Plane receipt rejection is required': [
      ['plane-receipt-rejected'],
    ],
    'selected Linear capability boundary is required': [
      ['no-provider-invocation'],
      ['no-legacy-adapter-invocation'],
      ['remote-mutation-boundary'],
      ['live-failure-report-only'],
    ],
    'selected Plane capability boundary is required': [
      ['plane-no-provider-invocation'],
      ['plane-no-legacy-adapter-invocation'],
      ['plane-remote-mutation-boundary'],
      ['plane-live-failure-report-only'],
    ],
    'selected Linear success is required': [
      ['success-receipt-validated'],
      ['success-no-provider'],
      ['success-no-legacy-adapter'],
      ['success-no-remote-mutation'],
      ['success-no-repair'],
    ],
    'selected Plane success is required': [
      ['plane-success-receipt-validated'],
      ['plane-success-no-provider'],
      ['plane-success-no-legacy-adapter'],
      ['plane-success-no-remote-mutation'],
      ['plane-success-no-repair'],
    ],
    'selected provider branching ignores the unselected provider': [
      ['local-live-skip-skipped'],
      ['local-live-skip-no-repair'],
      ['plane-check-live-mode-reported'],
      ['plane-unselected-ignored'],
      ['plane-success-unselected-ignored'],
    ],
  },
  'woostack-status': {
    'repository evidence defines row state read-only': [
      ['board-rendered'],
      ['repo-row-states-derived'],
      ['checks-observable-only'],
      ['status-zero-provider-mutation'],
      ['status-zero-repository-mutation'],
    ],
    'checks are observable and independent of review state': [
      ['clean-state-failed-checks'],
      ['clean-state-pending-checks'],
      ['blocked-state-review-failure'],
    ],
    'worktree collision and head drift fail closed': [
      ['collision-blocked'],
      ['collision-reason'],
      ['drifted-blocked'],
      ['drifted-reason'],
      ['collision-drift-no-writes'],
    ],
    'provider enrichment parity preserves repository row state': [
      ['parity-baseline-row-state'],
      ['parity-linear-row-state'],
      ['parity-plane-row-state'],
      ['parity-row-state-identical'],
      ['parity-linear-enrichment-payload'],
      ['parity-linear-provenance'],
      ['parity-plane-enrichment-payload'],
      ['parity-plane-provenance'],
      ['parity-absent-repo-no-row'],
      ['parity-absent-repo-empty-rows'],
      ['parity-no-provider-mutation'],
    ],
  },
  'woostack-bootstrap': {
    'explicit design approval precedes target directory writes': [
      ['approved-flow-complete'],
      ['plane-approved-flow-complete'],
      ['local-approved-flow-complete'],
      ['project-first-order'],
      ['plane-provider-selected'],
      ['local-provider-selected'],
      ['design-artifact-free-before-approval'],
      ['local-zero-provider-discovery'],
      ['zero-target-writes-before-authority'],
      ['local-collision-check-is-first'],
      ['target-creation-authorized-after-receipts'],
      ['plane-target-creation-authorized'],
      ['local-target-creation-authorized'],
    ],
    'selected provider mode operates strictly within its boundary': [
      ['local-zero-mcp-preflights'],
      ['local-zero-projects-created'],
      ['local-scaffold-project-identity-null'],
      ['exactly-one-project-created'],
    ],
    'plane provider derives external identities and verifies exact read-back': [
      ['plane-external-source-bound'],
      ['plane-external-id-bound'],
      ['plane-project-uuid-verified'],
      ['plane-project-url-verified'],
      ['plane-project-discovery-complete'],
      ['plane-zero-matches-before-create'],
      ['plane-one-project-created'],
      ['plane-readback-verified'],
      ['plane-design-approved-verified', 'plane-exact-design-approved-verified'],
      ['plane-scaffold-receives-exact-project', 'plane-exact-scaffold-project-identity'],
      ['plane-build-handoff-receives-exact-project', 'plane-exact-build-project-identity'],
    ],
    'plane configured labels compute union and preserve existing labels': [
      ['plane-labels-attached'],
      ['plane-exact-labels-unioned'],
      ['plane-label-readback-verified'],
      ['plane-exact-readback-verified'],
    ],
    'plane provider mirror failure is nonblocking for approved scaffold': [
      ['plane-label-cap-status'],
      ['plane-label-cap-mirror-status'],
      ['plane-label-cap-missing-reason'],
      ['plane-label-cap-no-project-created'],
      ['plane-label-cap-collision-check'],
      ['plane-label-cap-target-authorized'],
      ['plane-label-cap-scaffold-null'],
    ],
    'linear provider mirror failure is nonblocking for approved scaffold': [
      ['linear-missing-mcp-status'],
      ['linear-missing-mcp-mirror-status'],
      ['linear-missing-mcp-reason'],
      ['linear-missing-mcp-no-project-created'],
      ['linear-missing-mcp-collision-check'],
      ['linear-missing-mcp-target-authorized'],
      ['linear-missing-mcp-scaffold-null'],
    ],
    'explicit required persistence fails closed on missing provider': [
      ['missing-mcp-blocks'],
      ['missing-mcp-reason'],
      ['missing-mcp-order'],
      ['no-target-access'],
      ['no-fallback-authority'],
    ],
    'linear provider discovery proves absence before exactly one create': [
      ['project-discovery-complete'],
      ['event-absence-proven-before-append'],
      ['exactly-one-project-created'],
    ],
    'plane provider discovery proves absence before exactly one create': [
      ['plane-project-discovery-complete'],
      ['plane-zero-matches-before-create'],
      ['plane-one-project-created'],
    ],
    'exact supplied project reuses native identity without implicit creation': [
      ['plane-exact-project-reused'],
      ['plane-exact-project-id'],
      ['plane-exact-no-create'],
      ['plane-exact-no-replacement'],
    ],
    'read-only collision check is first target action': [
      ['first-target-action-is-collision-check'],
      ['plane-target-collision-check'],
      ['local-collision-check-is-first'],
      ['absent-target-passes-collision-check'],
      ['target-collision-blocks'],
      ['collision-reports-client-project'],
    ],
    'bounded brownfield requests route to change': [
      ['routes-to-change'],
      ['bounded-brownfield-reason'],
      ['bootstrap-never-starts'],
      ['design-never-starts'],
    ],
    'fresh restart rediscovers exact Linear project and record identities': [
      ['restart-ready'],
      ['restart-linear-provider'],
      ['restart-identity-source'],
      ['restart-approved-design-key'],
      ['restart-client-project-id'],
      ['restart-native-project-id'],
      ['restart-operation-id'],
      ['restart-project-discovery-complete'],
      ['restart-one-project'],
      ['restart-project-read-back'],
      ['restart-no-project-create'],
      ['restart-design-discovery-complete'],
      ['restart-one-design-record'],
      ['restart-design-read-back'],
      ['restart-base-intent'],
      ['restart-reused-project-id'],
      ['restart-reused-operation-id'],
      ['restart-no-update-append'],
      ['restart-zero-target-access'],
      ['restart-collision-check'],
      ['restart-target-absent'],
      ['restart-target-authorized'],
    ],
    'partial duplicate and unknown Linear identities fail closed': [
      ['partial-duplicate-linear-blocks'],
      ['partial-duplicate-linear-reason'],
      ['partial-duplicate-linear-provider'],
      ['partial-duplicate-linear-discovery-complete'],
      ['partial-duplicate-linear-count'],
      ['partial-duplicate-linear-unknown-count'],
      ['partial-duplicate-linear-no-create'],
      ['partial-duplicate-linear-no-update'],
      ['partial-duplicate-linear-no-target'],
      ['partial-duplicate-linear-no-replacement'],
      ['partial-duplicate-linear-no-fallback'],
      ['partial-duplicate-linear-preserve-id'],
    ],
    'conflicting Linear project updates fail closed': [
      ['conflicting-linear-block'],
      ['conflicting-linear-reason'],
      ['conflicting-linear-provider'],
      ['conflicting-linear-client-id'],
      ['conflicting-linear-project-id'],
      ['conflicting-linear-discovery-complete'],
      ['conflicting-linear-one-match'],
      ['conflicting-linear-two-records'],
      ['conflicting-linear-read-attempted'],
      ['conflicting-linear-not-reused'],
      ['conflicting-linear-no-append'],
      ['conflicting-linear-no-target'],
      ['conflicting-linear-preserve-operation'],
    ],
    'Linear design-approved base mismatch fails closed': [
      ['base-mismatch-blocks'],
      ['base-mismatch-reason'],
      ['base-mismatch-linear-provider'],
      ['base-mismatch-discovery-complete'],
      ['base-mismatch-one-record'],
      ['base-mismatch-client-id'],
      ['base-mismatch-expected-base'],
      ['base-mismatch-record-base'],
      ['base-mismatch-read-back'],
      ['base-mismatch-not-reused'],
      ['base-mismatch-no-append'],
      ['base-mismatch-no-target'],
      ['base-mismatch-preserve-operation'],
    ],
  },
};

// Each digest pins the canonical parsed corpus and the exact content of every safely resolved
// fixture. Case and assertion order remain significant, while fixture-reference order does not.
const corpusContract = (caseCount, digest) => ({ caseCount, digest });
const approvedCorpusContracts = {
  'woostack-eval': corpusContract(2, 'c7f619f14335a4f1e57978742eea6a590f055e3e364026834feeadf44f391806'),
  'woostack-build': corpusContract(6, '6e80c13770ab7eeaf4cb39c82d56c3672d8e543b20374796a63279464ae0ecd7'),
  'woostack-plan': corpusContract(7, '7ec236b731dfa39cece196ae1d62169512ff3dd7b1c0cfb5219581ea8a101694'),
  'woostack-fix': corpusContract(7, '3eab5562704e48562a13e92620c8a4f7b1f27b5acdfb1c9b30f371d9edde36ef'),
  'woostack-execute': corpusContract(37, 'a138230444aa5098c160c3764ea89d2e19ab0cb2b49539bde258e918201f8ede'),
  'woostack-commit': corpusContract(17, '5831bc06ad35d0b5261cc3c6969d3cc09a87d32f094e244b9fed7184674568a5'),
  'woostack-review': corpusContract(4, '72dddc1a586ca2c1fddb1d017b02d18cf95fd4b311384f5816eaea22a9300a93'),
  'woostack-sweep': corpusContract(13, '1d109f7e085d3c409d2963180863351234b75f82d967c789387d9874ae1c4282'),
  'woostack-address-comments': corpusContract(3, '6a5d04522d1f10af74ee69300a49f2fe23aa7e3357b8cb6223399e8511d6c0a5'),
  'woostack-debug': corpusContract(4, 'ab54ed28d0ac1dd043104fcecdae38ea22a21471baa1356cabf7f1d061121014'),
  'woostack-audit': corpusContract(3, '94462137c1dfc06c853bbca7143a169ed57c2b1b6988d8c5595e89d324157b87'),
  'woostack-visualize': corpusContract(3, 'e986a8099ca7aa788ed424f5753956dbf479a6b124f4719f6af6c053203bd7e5'),
  'woostack-init': corpusContract(24, '59e6caef4aae98972b65721ff28a28115c0019e4f8c75f1b282586bec8a9b7d5'),
  'woostack-doctor': corpusContract(6, 'c452e457bae579b3bf76c37069653bc855843024820723ec4861ee618a743ea3'),
  'woostack-status': corpusContract(8, '58fcfbd6428547d559ce92c891f7a0c768f6a1c7c92f859fa19c30412f023ca2'),
  'woostack-bootstrap': corpusContract(13, '03a3e5b8a99dc0e6e458486ff6f59c61332427dda0d6c26658a78e2a2e1977b6'),
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
      throw new Error(`${location} contains invalid JSON: ${error.message}`);
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
  ['network or remote service', /\b(?:fetch(?:ing)?|download(?:ing)?|retriev(?:e|ing)|query(?:ing)?|read(?:ing)?|load(?:ing)?|inspect(?:ing)?|open(?:ing)?)\b[^.!?;\n]{0,80}\b(?:from|via)\s+(?:an?\s+|the\s+)?(?:network|internet|web|remote services?|github|linear|plane)\b/gi],
  ['network or remote service', /\b(?:call(?:ing)?|contact(?:ing)?|connect(?:ing)?\s+to|query(?:ing)?|send(?:ing)?\s+(?:an?\s+)?request\s+to|request(?:ing)?\s+access\s+to|use|using|access(?:ing)?)\s+(?:an?\s+|the\s+)?(?:network|internet|web|remote services?|github|linear|plane)\b/gi],
  ['network access', /\b(?:request|requesting|obtain|obtaining|use|using)\s+(?:an?\s+|the\s+)?(?:network|internet|web|github|linear|plane)\s+access\b/gi],
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
expectRejected('affirmative Plane request', () =>
  assertNoProhibitedRequest('Call Plane before proceeding.', '<probe>'));
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
expectRejected('malformed referenced JSON fixture', () => {
  fs.writeFileSync(semanticProbeFixturePath, '{"approved":true,\n');
  try {
    assertCorpusContract(
      semanticProbe,
      semanticProbeFixtureRoot,
      semanticProbeContract,
      '<malformed-fixture-probe>',
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
  throw new Error('critical contract map must cover exactly the sixteen required packages');
}
NODE

printf 'PASS: validated critical behavior corpora for exactly 16 required packages\n'
