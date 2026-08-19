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
    (r"Owner-only local run store|canonical persistent store", "shared manifest contract"),
    (r"owner-only `0600`", "owner-only file identity"),
    (r"no-follow semantics", "no-follow file checks"),
    (r"zero provider reads or writes", "no intermediate provider cycle"),
    (r"Write `project-spec\.md` exactly once", "plain project spec write"),
    (r"Write `execution-plan\.md` exactly once", "plain execution plan write"),
    (r"stableTaskMappings", "stable canonical-reference mapping"),
    (r"canonical issue reference", "canonical issue reference"),
    (r"unknown parent state|unknown.*parent.*blocks", "unknown parent fail-closed"),
    (r"Retain `manifest\.json`, `project-spec\.md`, `execution-plan\.md`, and `\.lock`", "artifact retention"),
    (r"Planning base and Execute choice", "planning base and Execute choice"),
    (r"`Continue`.*`Revise spec/plan`.*`Stop`", "Execute base choice options"),
):
    require_shared(pattern, name)

for pattern, name in (
    (r"gate 1 displays only the", "obsolete project-pointer-only Ask"),
    (r"gate 2 displays only the", "obsolete issue-pointer-only Ask"),
    (r"Do not paste any project", "obsolete body exclusion"),
    (r"complete exact local content to be saved", "obsolete complete-inline wording"),
    (r"projectSpecApprovalRecord", "obsolete project approval record"),
    (r"executionPlanApprovalRecord", "obsolete execution plan approval record"),
    (r"canonicalProjectSpecFingerprint", "obsolete spec fingerprint"),
    (r"canonicalIncrementFingerprint", "obsolete increment fingerprint"),
    (r"providerPresentationCanonicalization", "obsolete presentation canonicalization"),
    (r"\bstream(?:ed|ing)?.*(?:full|complete).*(?:bytes|content)", "obsolete streaming in artifact"),
):
    if re.search(pattern, artifact, re.I | re.S):
        failures.append(name)


require(r"Debug.*admit writable target.*allocate or resume canonical local run.*local Ideate/Harden.*project-spec\.md.*local Plan/Harden.*execution-plan\.md.*retain run artifacts.*Stop here.*Execute.*Abandon", "canonical sequence")
require(r"Before root-cause proof, load only the routing and output rules.*woostack-debug.*references that Debug directly requires", "debug-only pre-proof loading")
require(r"Immediately after Debug returns root-cause proof and exact writable target-repository admission succeeds, load.*Linear artifact contract.*woostack-build.*woostack-ideate.*woostack-harden", "post-admission downstream loading")
if not (
    skill.index("Before root-cause proof, load only")
    < skill.index("### 1. Debug, read-only")
    < skill.index("### 1.5. Target-repository admission")
    < skill.index("Immediately after Debug returns root-cause proof")
    < skill.index("### 2. Allocate or resume canonical run")
):
    failures.append("loading boundary ordering")
if "Before acting, load and apply the shared" in skill:
    failures.append("eager pre-proof loading wording")
require(r"accepts a goal or untrusted Linear, GitHub, Sentry, or monitoring input", "untrusted input coverage")
require(r"root-cause proof.*create or update a project.*branch.*worktree.*mutate the repository", "proof write barrier")
require(r"owns one canonical local run", "one canonical local run")
require(r"name starts with `\[Fix\] `", "prefixed fix project name")
require(r"supplied.*project.*retains its existing name", "supplied project name preservation")
require(r"source issue.*never repurposed|never repurpos(?:e|ed) a supplied source\s+issue", "source issue preservation")
require(r"writes plain Markdown `project-spec\.md`", "plain project spec write")
require(r"writes plain Markdown `execution-plan\.md`", "plain execution plan write")
require(r"exact run ID.*woostack-execute --run <exact-run-id>.*Stop here.*Execute.*Abandon", "verified handoff")
require(r"shared.*repository advancement contract", "shared repository advancement authority")
require(r"Debug.*Target-repository admission.*Allocate or resume canonical run", "target-repository guard ordering")
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
    ("projectSpecApprovalRecord", "obsolete project approval record in skill"),
    ("executionPlanApprovalRecord", "obsolete plan approval record in skill"),
    ("canonicalProjectSpecFingerprint", "obsolete spec fingerprint in skill"),
):
    if obsolete.lower() in skill.lower():
        failures.append(name)

if blocked["dispatch"]["status"] != "blocked" or blocked["dispatch"]["reason"] != "root-cause-proof-required":
    failures.append("blocked fixture boundary")
if blocked["projectAdmission"]["projectCreated"] or blocked["projectAdmission"]["sourceLinkWritten"]:
    failures.append("blocked fixture project mutation")
if blocked["repository"]["mutationCount"] != 0 or blocked["debug"]["providerCallsBeforeProof"] != 0:
    failures.append("blocked fixture side effects")

ids = {case["id"] for case in evals["cases"]}
for expected in (
    "root-cause-proof-precedes-project-and-repository",
    "production-input-routes-to-fix",
    "canonical-project-preserves-source-record",
    "provider-or-readback-failure-is-nonblocking",
    "validates-fix-source-before-project-link",
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
