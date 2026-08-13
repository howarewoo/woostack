#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import json, re, sys
from pathlib import Path

root = Path(sys.argv[1])
failures = []
skill = re.sub(r"\s+", " ", (root / "skills/woostack-fix/SKILL.md").read_text())
artifact = re.sub(
    r"\s+",
    " ",
    (root / "skills/woostack-init/references/artifact-backends.md").read_text(),
)
fixture = json.loads((root / "skills/woostack-fix/evals/fixtures/approved-fix.json").read_text())
blocked = json.loads((root / "skills/woostack-fix/evals/fixtures/no-root-cause.json").read_text())
evals = json.loads((root / "skills/woostack-fix/evals/evals.json").read_text())
triggers = json.loads((root / "skills/woostack-fix/evals/trigger-evals.json").read_text())


def require(pattern, name):
    if not re.search(pattern, skill, re.I | re.S):
        failures.append(name)
def require_shared(pattern, name):
    if not re.search(pattern, artifact, re.I | re.S):
        failures.append(name)


for pattern, name in (
    (r"Run-scoped gated draft manifest", "shared manifest contract"),
    (r"owner-only.*Markdown gate files", "owner-only file identity"),
    (r"no-follow.*owner.*regular", "no-follow file checks"),
    (r"zero Linear or other provider reads and writes", "no intermediate provider cycle"),
    (r"render from the current manifest", "deterministic project and plan render"),
    (r"deterministic", "deterministic rendering"),
    (r"stream.*complete.*Markdown bytes.*full identity", "complete streamed artifact"),
    (r"same-process.*byte-complete unified diff.*old.*new.*identit", "same-process revision diff"),
    (r"body-free Ask.*Accept.*Abandon", "body-free approval Ask"),
    (r"approval.*before any draft content is saved", "approval-before-save"),
    (r"immediately re-read the exact Linear targets", "immediate pre-save drift read"),
    (r"only after that exact content read-back, record", "read-back-before-receipt"),
    (r"stable local task key to canonical issue reference", "stable canonical-reference mapping"),
    (r"canonical issue-reference/nullable-parent preflight", "shared issue-parent preflight"),
    (r"exact endpoint round trip", "exact canonical endpoint round-trip"),
    (r"unknown parent state", "unknown parent fail-closed"),
    (r"unreceipted approval is consumed and cannot be replayed", "approval replay guard"),
    (r"process restart.*complete new artifact", "process-loss complete fallback"),
    (r"unlink both gate files and the manifest", "gate-file cleanup"),
    (r"Execute-era safety reads are unchanged", "unchanged Execute checks"),
    (r"providerPresentationCanonicalization", "provider presentation canonicalization"),
    (r"Native provider bytes remain exact read-back evidence.*canonical fingerprints", "native bytes and canonical comparison"),
    (r"fresh.*body-free Ask", "presentation recovery"),
    (r"presence or absence of exactly one terminal LF", "terminal LF equivalence"),
    (r"two or more terminal LFs.*byte-sensitive", "multiple terminal LF sensitivity"),
    (r"At end of string, leave the blank suffix unchanged", "final heading EOF boundary"),
):
    require_shared(pattern, name)

for pattern, name in (
    (r"gate 1 displays only the", "obsolete project-pointer-only Ask"),
    (r"gate 2 displays only the", "obsolete issue-pointer-only Ask"),
    (r"Do not paste any project", "obsolete body exclusion"),
    (r"complete exact local content to be saved", "obsolete complete-inline wording"),
):
    if re.search(pattern, artifact, re.I | re.S):
        failures.append(name)


require(r"Debug.*gate 1 baseline.*local Ideate/Harden.*project-spec\.md.*bounded sync/read-back/receipt.*gate 2 baseline.*local Plan/Harden.*execution-plan\.md.*bounded sync/read-back/receipt.*Stop here.*Execute.*Abandon", "canonical sequence")
require(r"Before root-cause proof, load only the routing and output rules.*woostack-debug.*references that Debug directly requires", "debug-only pre-proof loading")
require(r"Immediately after Debug returns root-cause proof and exact writable target-repository admission succeeds, load.*Linear artifact contract.*woostack-build.*woostack-ideate.*woostack-harden", "post-admission downstream loading")
if not (
    skill.index("Before root-cause proof, load only")
    < skill.index("### 1. Debug, read-only")
    < skill.index("### 1.5. Target-repository admission")
    < skill.index("Immediately after Debug returns root-cause proof")
    < skill.index("### 2. Resolve the project")
):
    failures.append("loading boundary ordering")
if "Before acting, load and apply the shared" in skill:
    failures.append("eager pre-proof loading wording")
require(r"accepts a goal or untrusted Linear, GitHub, Sentry, or monitoring input", "untrusted input coverage")
require(r"root-cause proof.*create or update a project.*branch.*worktree.*mutate the repository", "proof write barrier")
require(r"owns one canonical project", "one canonical project")
require(r"name starts with `\[Fix\] `", "prefixed fix project name")
require(r"supplied.*project.*retains its existing name", "supplied project name preservation")
require(r"source issue.*never repurposed|never repurpos(?:e|ed) a supplied source\s+issue", "source issue preservation")
require(r"accepts that exact preceding identity.*projectSpecApprovalRecord", "active project approval before save/read-back/receipt")
require(r"accepts that exact preceding identity.*executionPlanApprovalRecord", "active plan approval before save/read-back/receipt")
require(r"independently read back both receipts", "independent approval read-back")
require(r"material project-specification change invalidates both records", "spec invalidation")
require(r"project-spec\.md.*complete exact.*full identity", "project streamed artifact")
require(r"execution-plan\.md.*complete ordered.*dependency tuple", "plan streamed artifact and mapping")
require(r"verified project URL or UUID.*woostack-execute.*Stop here.*Execute.*Abandon", "verified handoff")
require(r"shared repository advancement contract", "shared repository advancement authority")
require(r"Debug.*Target-repository admission.*Resolve the project", "target-repository guard ordering")
require(r"compare the proved causal target repository with the invocation repository using trusted Git/GitHub evidence", "trusted target and invocation repositories")
require(r"non-mutatingly verify that the active checkout is the exact writable owning checkout", "exact writable owning checkout")
require(r"Missing, ambiguous, foreign, read-only, unwritable, absent, or wrong checkout blocks before every provider, artifact, or repository effect", "fail-closed target boundary")
require(r"supplied `--project` or `--issue` cannot bypass", "supplied artifact non-bypass")
require(r"Preserve the matching writable path", "matching writable path preservation")
require(r"offer only `retarget-reinvoke-in-exact-writable-owning-repository` or `diagnosis-only`", "exact safe outcomes")
require(r"never clone, switch, mutate, or invent a workaround", "no target workaround")


for obsolete, name in (
    ("fixApprovalRecord", "fix-only approval record"),
    ("approve-to-execute", "issue approval wording"),
    ("one hard gate", "one-gate wording"),
    ("bind exactly one issue", "one-issue binding"),
    ("closeout", "one-issue closeout"),
):
    if obsolete.lower() in skill.lower():
        failures.append(name)

if blocked["dispatch"]["status"] != "blocked" or blocked["dispatch"]["reason"] != "root-cause-proof-required":
    failures.append("blocked fixture boundary")
if blocked["projectAdmission"]["projectCreated"] or blocked["projectAdmission"]["sourceLinkWritten"]:
    failures.append("blocked fixture project mutation")
if blocked["repository"]["mutationCount"] != 0 or blocked["debug"]["providerCallsBeforeProof"] != 0:
    failures.append("blocked fixture side effects")

if fixture["projectAdmission"]["projectId"] != "project-fix-241" or not fixture["projectAdmission"]["independentReadBack"]:
    failures.append("canonical project admission")
if fixture["projectAdmission"]["name"] != "[Fix] Prevent cache refresh stampedes":
    failures.append("fix project name prefix")
if not fixture["projectSpec"]["title"].startswith("[Fix] "):
    failures.append("fix project specification title prefix")
source = fixture["sourceIssue"]
if source["changedFields"] != ["projectLink"] or not source["unrelatedFieldsPreserved"]:
    failures.append("source issue changed beyond project link")
if len(fixture["executionPlan"]["increments"]) != 2:
    failures.append("multiple direct increments")
if {
    increment["stableTaskKey"]: increment["canonicalIssueReference"]
    for increment in fixture["executionPlan"]["increments"]
} != {"task-lock": "WOO-242", "task-stale": "WOO-243"}:
    failures.append("stable canonical-reference mappings")
if fixture["executionPlan"]["dependencies"] != [{
    "predecessorIssueReference": "WOO-242",
    "successorIssueReference": "WOO-243",
    "kind": "native-issue",
}]:
    failures.append("canonical dependency endpoints")
if fixture["approvalEvidence"]["repositoryMutationCountBeforeBothApprovals"] != 0:
    failures.append("pre-approval repository mutation")

project_record = fixture["projectSpecApprovalRecord"]
plan_record = fixture["executionPlanApprovalRecord"]
if set(project_record) != {"projectId", "canonicalProjectSpecFingerprint", "approvedBy", "approvedAt", "approvalEventRef"}:
    failures.append("project approval record shape")
if set(plan_record) != {"projectId", "canonicalProjectSpecFingerprint", "increments", "dependencies", "approvedBy", "approvedAt", "approvalEventRef"}:
    failures.append("execution approval record shape")
if not all(fixture["approvalEvidence"][key]["activeConversationApproval"] and fixture["approvalEvidence"][key]["linearReceiptReadBack"] for key in ("projectSpec", "executionPlan")):
    failures.append("approval evidence")
if fixture["dispatch"]["handoff"]["options"] != ["Stop here", "Execute", "Abandon"] or not fixture["dispatch"]["handoff"]["bodyFree"]:
    failures.append("verified body-free handoff options")
if fixture["dispatch"]["handoff"]["projectCommand"] != "/woostack-execute --project <exact Linear URL-or-UUID>":
    failures.append("project-only handoff command")
if fixture["dispatch"]["responses"]["Stop here"]["effects"] or fixture["dispatch"]["responses"]["Execute"]["dispatchCount"] != 1:
    failures.append("handoff Stop here/Execute behavior")
if fixture["dispatch"]["responses"]["Abandon"] != {"projectClosed": True, "dispatchCount": 0} or not fixture["dispatch"]["responses"]["unknownOrCustom"]["askAgain"]:
    failures.append("handoff Abandon/fail-closed behavior")

ids = {case["id"] for case in evals["cases"]}
for expected in (
    "root-cause-proof-precedes-project-and-repository",
    "production-input-routes-to-fix",
    "canonical-project-preserves-source-record",
    "project-spec-approval-is-active-and-recorded",
    "execution-plan-approval-binds-issues-and-dependencies",
    "renders-project-spec-file-ask",
    "renders-execution-plan-file-ask",
    "renders-same-process-revision-diff-with-fallbacks",
    "blocks-unreceipted-approval-replay",
    "material-change-invalidates-matching-receipts",
    "validates-fix-source-before-project-link",
    "accepts-provider-presentation-equivalence",
    "rejects-unsupported-ordered-marker-boundaries",
    "requires-fresh-ask-for-semantic-provider-change",
    "rejects-mixed-marker-transition-canonical-mismatch",
    "rejects-terminal-lf-canonical-mismatch",
):
    if expected not in ids:
        failures.append(f"missing eval {expected}")

def require_eval_fields(case_id, expected_values):
    case = next((item for item in evals["cases"] if item["id"] == case_id), None)
    if case is None:
        return
    assertions = {
        assertion.get("pointer"): assertion.get("expected")
        for assertion in case.get("assertions", [])
    }
    for pointer, expected in expected_values.items():
        if assertions.get(pointer) != expected:
            failures.append(f"{case_id} does not assert {pointer}={expected!r}")

require_eval_fields(
    "accepts-provider-presentation-equivalence",
    {
        "/approvalAskCount": 1,
        "/boundedSaveCount": 1,
        "/readBackCount": 1,
        "/receiptCount": 1,
        "/secondAskCount": 0,
    },
)
require_eval_fields(
    "requires-fresh-ask-for-semantic-provider-change",
    {
        "/results": [
            {"id": "project-description", "approvalIdentityMatch": False, "receiptCount": 0, "freshAsk": True},
            {"id": "increment-description", "approvalIdentityMatch": False, "receiptCount": 0, "freshAsk": True},
            {"id": "issue-description", "approvalIdentityMatch": False, "receiptCount": 0, "freshAsk": True},
            {"id": "rendered-gate-file", "approvalIdentityMatch": False, "receiptCount": 0, "freshAsk": True},
        ],
    },
)
require_eval_fields(
    "rejects-unsupported-ordered-marker-boundaries",
    {
        "/status": "blocked",
        "/results": [
            {"id": "two-leading-spaces", "canonicalMatch": False, "receiptCount": 0, "freshAsk": True},
            {"id": "leading-tab", "canonicalMatch": False, "receiptCount": 0, "freshAsk": True},
            {"id": "nested-container", "canonicalMatch": False, "receiptCount": 0, "freshAsk": True},
            {"id": "fenced-code", "canonicalMatch": False, "receiptCount": 0, "freshAsk": True},
            {"id": "indented-code", "canonicalMatch": False, "receiptCount": 0, "freshAsk": True},
            {"id": "missing-whitespace", "canonicalMatch": False, "receiptCount": 0, "freshAsk": True},
            {"id": "repeated-delimiter", "canonicalMatch": False, "receiptCount": 0, "freshAsk": True},
            {"id": "unicode-digits", "canonicalMatch": False, "receiptCount": 0, "freshAsk": True},
            {"id": "ten-digit-marker", "canonicalMatch": False, "receiptCount": 0, "freshAsk": True},
            {"id": "changed-number", "canonicalMatch": False, "receiptCount": 0, "freshAsk": True},
            {"id": "changed-delimiter", "canonicalMatch": False, "receiptCount": 0, "freshAsk": True},
            {"id": "changed-text", "canonicalMatch": False, "receiptCount": 0, "freshAsk": True},
            {"id": "changed-order", "canonicalMatch": False, "receiptCount": 0, "freshAsk": True},
            {"id": "blank-line-continuation", "canonicalMatch": False, "receiptCount": 0, "freshAsk": True},
        ],
    },
)
require_eval_fields(
    "rejects-mixed-marker-transition-canonical-mismatch",
    {
        "/canonicalMatch": False,
        "/receiptCount": 0,
        "/freshAsk": True,
    },
)
require_eval_fields(
    "rejects-terminal-lf-canonical-mismatch",
    {
        "/results": [
            {"id": "one-vs-two", "canonicalMatch": False, "receiptCount": 0, "freshAsk": True},
            {"id": "two-vs-three", "canonicalMatch": False, "receiptCount": 0, "freshAsk": True},
            {"id": "final-heading-two-vs-three", "canonicalMatch": False, "receiptCount": 0, "freshAsk": True},
        ],
    },
)
target_case = next((case for case in evals["cases"] if case["id"] == "target-repository-boundary-precedes-provider-admission"), None)
if target_case is None:
    failures.append("missing target repository boundary eval")
else:
    if "fixtures" in target_case:
        failures.append("target repository boundary eval must be no-fixture")
    if any(assertion.get("critical") is not True for assertion in target_case["assertions"]):
        failures.append("target repository boundary assertions must be critical")
    def require_target_assertion(pointer, expected, name):
        matches = [
            assertion for assertion in target_case["assertions"]
            if assertion.get("pointer") == pointer and assertion.get("expected") == expected
        ]
        if len(matches) != 1 or matches[0].get("critical") is not True:
            failures.append(name)
    for pointer, expected, name in (
        ("/foreignTarget/status", "blocked", "foreign target decision"),
        ("/foreignTarget/reason", "target-repository-mismatch", "foreign target reason"),
        ("/foreignTarget/safeOutcomes", ["retarget-reinvoke-in-exact-writable-owning-repository", "diagnosis-only"], "foreign target outcomes"),
        ("/foreignTarget/providerCalls", 0, "foreign target provider effects"),
        ("/foreignTarget/projectCreated", False, "foreign target project effects"),
        ("/foreignTarget/sourceLinkWritten", False, "foreign target source effects"),
        ("/foreignTarget/repositoryMutationCount", 0, "foreign target repository effects"),
        ("/foreignTarget/suppliedArtifactBypass", False, "foreign target artifact bypass"),
        ("/matchingUnwritable/status", "blocked", "unwritable target decision"),
        ("/matchingUnwritable/reason", "writable-target-checkout-required", "unwritable target reason"),
        ("/matchingUnwritable/safeOutcomes", ["retarget-reinvoke-in-exact-writable-owning-repository", "diagnosis-only"], "unwritable target outcomes"),
        ("/matchingUnwritable/providerCalls", 0, "unwritable target provider effects"),
        ("/matchingUnwritable/projectCreated", False, "unwritable target project effects"),
        ("/matchingUnwritable/sourceLinkWritten", False, "unwritable target source effects"),
        ("/matchingUnwritable/repositoryMutationCount", 0, "unwritable target repository effects"),
        ("/matchingUnwritable/suppliedArtifactBypass", False, "unwritable target artifact bypass"),
        ("/matchingWritable/status", "continue", "writable target decision"),
        ("/matchingWritable/nextPhase", "canonical-project-admission", "writable target next phase"),
        ("/matchingWritable/classificationEffects/providerCalls", 0, "writable classification provider effects"),
        ("/matchingWritable/classificationEffects/projectCreated", False, "writable classification project effects"),
        ("/matchingWritable/classificationEffects/sourceLinkWritten", False, "writable classification source effects"),
        ("/matchingWritable/classificationEffects/repositoryMutationCount", 0, "writable classification repository effects"),
    ):
        require_target_assertion(pointer, expected, name)

if not any(case["id"] == "production-monitoring-defect-routes-to-fix" for case in triggers["cases"]):
    failures.append("missing production trigger")

if failures:
    print("fix project contract violations:", file=sys.stderr)
    print("\n".join(f"- {item}" for item in failures), file=sys.stderr)
    raise SystemExit(1)
print("fix project contract: ok")
PY
