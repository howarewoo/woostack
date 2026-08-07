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
    (r"Approval Ask presentation", "shared Ask presentation contract"),
    (r"gate 1 displays only the .*exact canonical Linear project link", "project link-only Ask"),
    (r"gate 2 displays only the .*exact relevant direct-issue links", "issue link-only Ask"),
    (r"Do not paste any project, specification, issue, or dependency body", "body exclusion"),
    (r"canonical fingerprint.*dependency tuple.*read-back payload", "retained evidence exclusion"),
    (r"untrusted, non-authoritative pointers", "URL trust boundary"),
):
    require_shared(pattern, name)

for pattern, name in (
    (r"present the complete", "complete-body Ask directive"),
    (r"present that exact specification", "specification-body Ask directive"),
    (r"present the exact .*dependency", "dependency-body Ask directive"),
    (r"do not paste", "duplicated Ask exclusion list"),
):
    if re.search(pattern, skill, re.I | re.S):
        failures.append(name)


require(r"Debug\s*→\s*Ideate\s*→\s*Harden.*project-spec approval.*Linear.*Plan\s*→\s*Harden.*execution-plan approval.*Linear.*normal Execute", "canonical sequence")
require(r"accepts a goal or untrusted Linear, GitHub, Sentry, or monitoring input", "untrusted input coverage")
require(r"root-cause proof.*create or update a project.*branch.*worktree.*mutate the repository", "proof write barrier")
require(r"owns one canonical project", "one canonical project")
require(r"name starts with `\[Fix\] `", "prefixed fix project name")
require(r"supplied.*project.*retains its existing name", "supplied project name preservation")
require(r"source issue.*never repurposed|never repurpos(?:e|ed) a supplied source\s+issue", "source issue preservation")
require(r"multiple direct PR-linked issues", "multiple direct PR issues")
require(r"projectSpecApprovalRecord", "project approval record")
require(r"executionPlanApprovalRecord", "execution approval record")
require(r"active[- ]conversation.*explicitly approves.*Record the shared", "active conversation receipt")
require(r"independently read back both approval records", "independent approval read-back")
require(r"material project-specification change invalidates both records", "spec invalidation")
require(r"Present gate 1's exact canonical Linear project link", "fix project link-only Ask")
require(r"Present gate 2's exact relevant direct-issue links", "fix issue link-only Ask")
require(r"material direct-issue or dependency change invalidates only `executionPlanApprovalRecord`", "plan invalidation")
require(r"normal \[`woostack-execute`\]", "normal execute handoff")
require(r"before dispatch, after every worker handback, before every redispatch", "authority recheck cadence")
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
if fixture["dispatch"]["nextSkill"] != "woostack-execute":
    failures.append("normal execute dispatch")

ids = {case["id"] for case in evals["cases"]}
for expected in (
    "root-cause-proof-precedes-project-and-repository",
    "production-input-routes-to-fix",
    "canonical-project-preserves-source-record",
    "project-spec-approval-is-active-and-recorded",
    "execution-plan-approval-binds-issues-and-dependencies",
    "renders-link-only-project-spec-ask",
    "renders-link-only-execution-plan-ask",
    "material-change-invalidates-matching-receipts",
):
    if expected not in ids:
        failures.append(f"missing eval {expected}")
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
