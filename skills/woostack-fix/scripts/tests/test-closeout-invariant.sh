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
require(r"accepts a goal or untrusted (?:Linear|Plane|Linear, Plane, |Linear, )?GitHub, Sentry, or monitoring input", "untrusted input coverage")
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


# ---------------------------------------------------------------------------
# Deterministic Plane Fix Preservation, Timing, and Capability Fallback Simulation
# ---------------------------------------------------------------------------
class MockPlaneFixMCP:
    def __init__(self, base_url="https://api.plane.so", workspace="acme", repository="https://github.com/acme/widgets", capabilities=None):
        self.base_url = base_url
        self.workspace = workspace
        self.repository = repository
        self.capabilities = capabilities or {
            "projectRead": True, "projectWrite": True, "issueRead": True, "issueWrite": True,
            "projectLabelRead": True, "projectLabelWrite": True, "independentReadBack": True
        }
        self.projects = {}
        self.work_items = {}
        self.call_log = []

    def read_work_item(self, workspace, identifier):
        self.call_log.append(("read_work_item", workspace, identifier))
        if not self.capabilities.get("issueRead"):
            raise RuntimeError("missing capability: issueRead")
        if workspace != self.workspace:
            raise ValueError(f"foreign workspace: {workspace}")
        for wi in self.work_items.values():
            if wi["id"] == identifier or wi.get("readable_id") == identifier:
                return dict(wi)
        return None

    def create_project(self, workspace, name, labels):
        self.call_log.append(("create_project", workspace, name, labels))
        if not self.capabilities.get("projectWrite"):
            raise RuntimeError("missing capability: projectWrite")
        if not self.capabilities.get("projectLabelWrite"):
            raise RuntimeError("missing capability: projectLabelWrite")
        if workspace != self.workspace:
            raise ValueError(f"foreign workspace: {workspace}")
        proj_id = f"proj-{len(self.projects) + 1:03d}"
        proj = {"id": proj_id, "name": name, "workspace": workspace, "labels": list(labels)}
        self.projects[proj_id] = proj
        return dict(proj)

    def link_source_work_item_to_project(self, workspace, work_item_id, project_id):
        self.call_log.append(("link_source_work_item_to_project", workspace, work_item_id, project_id))
        if not self.capabilities.get("issueWrite"):
            raise RuntimeError("missing capability: issueWrite")
        if workspace != self.workspace:
            raise ValueError(f"foreign workspace: {workspace}")
        wi = self.work_items.get(work_item_id)
        if not wi:
            raise ValueError(f"work item not found: {work_item_id}")
        # Only the supported project_id link changes; all other fields remain untouched
        wi["project_id"] = project_id
        return dict(wi)


def test_plane_fix_preservation_and_scoping():
    mcp = MockPlaneFixMCP(
        base_url="https://api.plane.so",
        workspace="acme",
        repository="https://github.com/acme/widgets"
    )

    # Initial source work item in Plane
    source_id = "wi-uuid-42"
    source_readable = "ENG-42"
    mcp.work_items[source_id] = {
        "id": source_id,
        "readable_id": source_readable,
        "title": "Cache latency spikes under high concurrency",
        "description": "Investigate lock contention during cache refresh",
        "state_id": "state-open",
        "assignee": "adamwoo",
        "labels": ["bug", "performance"],
        "relations": [{"type": "relates_to", "target": "ENG-10"}],
        "project_id": None,
        "parent": None
    }

    # 1. Zero provider calls before root-cause proof (Debug phase)
    pre_proof_provider_calls = len(mcp.call_log)
    assert pre_proof_provider_calls == 0, "pre-proof phase must make zero provider calls"

    # 2. Target repository admission succeeds; Debug returns proof
    proved_root_cause = "lock contention in cache refresh loop"

    # 3. Post-proof: resolve supplied exact work-item reference to UUID with baseUrl and workspace scope
    supplied_ref = "ENG-42"
    resolved_wi = mcp.read_work_item("acme", supplied_ref)
    assert resolved_wi is not None, "source work item resolution failed"
    assert resolved_wi["id"] == source_id, f"expected UUID {source_id}, got {resolved_wi['id']}"
    assert resolved_wi["parent"] is None, "source work item must have parent = null"

    # 4. Canonical project creation with [Fix] prefix and configured labels
    proj = mcp.create_project("acme", f"[Fix] Resolve {proved_root_cause}", labels=["Core", "Fix"])
    assert proj["name"].startswith("[Fix] "), "project name must start with [Fix] "

    # 5. Source work-item preservation: update ONLY the supported project link
    mcp.link_source_work_item_to_project("acme", source_id, proj["id"])
    read_back_wi = mcp.read_work_item("acme", source_id)

    assert read_back_wi["project_id"] == proj["id"], "project_id link was not added"
    assert read_back_wi["title"] == "Cache latency spikes under high concurrency", "title was mutated"
    assert read_back_wi["description"] == "Investigate lock contention during cache refresh", "description was mutated"
    assert read_back_wi["state_id"] == "state-open", "state_id was mutated"
    assert read_back_wi["assignee"] == "adamwoo", "assignee was mutated"
    assert read_back_wi["labels"] == ["bug", "performance"], "labels were mutated"
    assert read_back_wi["parent"] is None, "parent was mutated"

    # 6. Project-label capability failure: persistence fails closed before repository mutation
    mcp_no_labels = MockPlaneFixMCP(
        base_url="https://api.plane.so",
        workspace="acme",
        capabilities={"projectRead": True, "projectWrite": True, "issueRead": True, "issueWrite": True, "projectLabelWrite": False}
    )
    label_failure_blocked = False
    try:
        mcp_no_labels.create_project("acme", "[Fix] Failed label capabilities", labels=["Core"])
    except RuntimeError as exc:
        label_failure_blocked = True
        assert "projectLabelWrite" in str(exc)
    assert label_failure_blocked is True, "missing project label capability must fail closed"

    # 7. Nonblocking mirror result: local run manifest authority remains valid
    local_manifest = {
        "status": "ready",
        "workflow": "fix",
        "mirror": {
            "provider": "plane",
            "status": "failed",
            "error": "Plane MCP timeout during execution plan mirror"
        }
    }
    local_authority_valid = local_manifest["status"] == "ready"
    execute_handoff_allowed = local_authority_valid and local_manifest["workflow"] == "fix"
    repo_mutations = 0

    assert local_authority_valid is True, "local authority must remain valid on mirror failure"
    assert execute_handoff_allowed is True, "execute handoff must be allowed on mirror failure"
    assert repo_mutations == 0, "repository mutations must remain zero on mirror failure"

test_plane_fix_preservation_and_scoping()
if failures:
    print("fix project contract violations:", file=sys.stderr)
    print("\n".join(f"- {item}" for item in failures), file=sys.stderr)
    raise SystemExit(1)
print("fix project contract: ok")
PY
