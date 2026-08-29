#!/usr/bin/env bash
# Structural and behavioral contract: commit stays artifact-optional and attributes configured providers (Linear, Plane) only after merge.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
skill = (root / "skills/woostack-commit/SKILL.md").read_text(encoding="utf-8")
artifact = (root / "skills/woostack-commit/references/provider-attribution.md").read_text(encoding="utf-8")
pr_body = (root / "skills/woostack-commit/references/pr-body.md").read_text(encoding="utf-8")
graphite = (root / "skills/woostack-commit/references/graphite.md").read_text(encoding="utf-8")
fold = lambda text: re.sub(r"\s+", " ", text)
failures = []

def require(text, pattern, message):
    if not re.search(pattern, fold(text), re.I | re.S):
        failures.append(message)

def forbid(text, pattern, message):
    if re.search(pattern, fold(text), re.I | re.S):
        failures.append(message)

# Structural checks on woostack-commit/SKILL.md
for pattern, message in (
    (r"Artifact providers \((?:Linear or Plane|Linear, Plane, or GitHub)\) are optional: no issue, work item, project, assignment", "commit does not declare provider-optional operation"),
    (r"`--issue` associates the verified Linear issue, Plane work item, or GitHub issue", "--issue does not require merge-closing association"),
    (r"never creates one implicitly", "commit can create an artifact implicitly"),
    (r"Do not add a provider reference in artifact-free mode", "artifact-free PR body is not protected"),
    (r"append one verified `Resolves <issue identifier>` line", "supplied issue lacks closing reference"),
    (r"moves the issue or work item to its configured merged state only after the PR merges", "closing reference claims an early lifecycle transition"),
    (r"Artifact failure does not invalidate the verified commit or PR", "artifact failure can invalidate repository delivery"),
    (r"Graphite for history mutation", "Graphite mutation boundary missing"),
    (r"independently read the canonical GitHub PR", "PR read-back missing"),
):
    require(skill, pattern, message)

# Structural checks on references/provider-attribution.md
for pattern, message in (
    (r"normal commit/PR path is artifact-free", "optional association reference lacks artifact-free default"),
    (r"Never infer an issue or work item", "optional artifact identity can be inferred"),
    (r"`Resolves <issue identifier>` line", "optional association lacks closing reference"),
    (r"Do not add a project reference", "project could be incorrectly closed by an issue PR"),
    (r"only after the PR merges", "association claims issue closure before merge"),
    (r"Never change scope, assignment, delegate, owner, status, acceptance", "artifact mutation is too broad"),
    (r"external_source.*external_id|stable operation identity", "Plane external identity or stable mutation missing"),
):
    require(artifact, pattern, message)

require(pr_body, r"exactly one matching `Resolves <issue identifier>` line when an issue was supplied", "PR body closing-reference cardinality missing")
require(pr_body, r"merged PR resolves its issue or work item, not the containing project", "PR body may resolve a containing project")
require(graphite, r"provider-attribution\.md", "Graphite reference does not link provider-attribution.md")

for text, label in ((skill, "skill"), (artifact, "artifact"), (pr_body, "pr-body"), (graphite, "graphite")):
    forbid(text, r"`--issue` is always required|must identify exactly one.*issue to commit", f"{label}: mandatory issue prerequisite returned")
    forbid(text, r"linear-attribution\.md", f"{label}: obsolete linear-attribution.md reference remains")

# Behavioral contract simulation cases (deterministic local, Linear, Plane, missing-capability)
class MockProvider:
    def __init__(self, provider_type, issues=None, projects=None, capabilities=None):
        self.provider_type = provider_type
        self.issues = issues or {}
        self.projects = projects or {}
        # Explicit capabilities: exact_read, write_note, read_back, create_project, project_labels
        self.capabilities = set(capabilities) if capabilities is not None else {
            "exact_read", "write_note", "read_back", "create_project", "project_labels"
        }
        self.notes = []
        self.created_projects = []

    def has_capability(self, cap):
        return cap in self.capabilities

    def read_issue(self, ref):
        if not self.has_capability("exact_read"):
            raise RuntimeError("Missing required capability: exact_read")
        return self.issues.get(ref)

    def append_delivery_note(self, ref, note):
        if not self.has_capability("write_note"):
            raise RuntimeError("Missing required capability: write_note")
        if not self.has_capability("read_back"):
            raise RuntimeError("Missing required capability: read_back")
        self.notes.append((ref, note))
        return {"status": "success", "note": note}

    def create_or_resolve_project(self, project_name, labels=None):
        if not self.has_capability("create_project"):
            raise RuntimeError("Missing required capability: create_project")
        if labels and not self.has_capability("project_labels"):
            raise RuntimeError("Missing required capability: project_labels")
        if not self.has_capability("read_back"):
            raise RuntimeError("Missing required capability: read_back")
        proj = {"name": project_name, "labels": labels or [], "designApproved": True}
        self.created_projects.append(proj)
        return {"status": "success", "project": proj}

def simulate_commit_pr_update(config, explicit_issue, provider_mock=None, pr_repo="acme/repo"):
    provider = config.get("artifacts", {}).get("provider", "local")
    pr_body_lines = [
        "## Goal",
        "Implement requested feature.",
        "",
        "## Summary",
        "- Added new module.",
        "",
        "## Test plan",
        "### Automated",
        "- `npm test` — passed",
    ]
    delivery_outcome = {"pr_updated": False, "closing_ref": None, "artifact_sync": "none", "error": None}

    if explicit_issue:
        if not provider_mock or provider == "local":
            delivery_outcome["error"] = "explicit issue supplied but no active provider configured"
            return delivery_outcome

        # Enforce config provider == mock provider type
        if provider != provider_mock.provider_type:
            delivery_outcome["error"] = f"provider mismatch: config specifies '{provider}' but mock is '{provider_mock.provider_type}'"
            return delivery_outcome

        try:
            issue_data = provider_mock.read_issue(explicit_issue)
        except Exception as e:
            delivery_outcome["error"] = f"failed to read issue due to missing capability: {e}"
            return delivery_outcome

        if not issue_data:
            delivery_outcome["error"] = f"unresolvable issue/work-item reference {explicit_issue}"
            return delivery_outcome

        # Verify repository boundary
        if issue_data.get("repository") and issue_data["repository"] != pr_repo:
            delivery_outcome["error"] = f"issue repository mismatch: {issue_data['repository']} != {pr_repo}"
            return delivery_outcome

        canonical_id = issue_data["identifier"]
        closing_line = f"Resolves {canonical_id}"
        pr_body_lines.append("")
        pr_body_lines.append(closing_line)
        delivery_outcome["closing_ref"] = closing_line

    delivery_outcome["pr_updated"] = True
    delivery_outcome["pr_body"] = "\n".join(pr_body_lines)

    if explicit_issue and provider_mock:
        try:
            note_content = f"Delivered in PR https://github.com/{pr_repo}/pull/42 on branch feat-x"
            provider_mock.append_delivery_note(explicit_issue, note_content)
            delivery_outcome["artifact_sync"] = "success"
        except Exception as e:
            # Sync failure is non-blocking for repository delivery
            delivery_outcome["artifact_sync"] = "failed"
            delivery_outcome["sync_error"] = str(e)

    return delivery_outcome

def simulate_bootstrap_persistence(config, design_approved, explicit_persist=False, provider_mock=None, project_name="Widget App"):
    # Hard gate: explicit design approval required before provider persistence
    if not design_approved:
        return {"status": "blocked", "error": "design approval required before provider persistence"}

    provider = config.get("artifacts", {}).get("provider", "local")

    # Local mode or no explicit persistence requested -> zero provider calls
    if not explicit_persist or provider == "local":
        return {"status": "skipped", "provider_sync": "none", "project": None}

    if not provider_mock:
        return {"status": "failed", "error": "provider persistence requested but no provider mock available"}

    if provider != provider_mock.provider_type:
        return {"status": "failed", "error": f"provider mismatch: config specifies '{provider}' but mock is '{provider_mock.provider_type}'"}

    labels = []
    if provider == "plane":
        labels = config.get("artifacts", {}).get("plane", {}).get("projectLabels", [])
        if not labels:
            return {"status": "failed", "error": "artifacts.plane.projectLabels required as non-empty array"}
    elif provider == "linear":
        labels = config.get("artifacts", {}).get("linear", {}).get("projectLabels", [])

    try:
        res = provider_mock.create_or_resolve_project(project_name, labels=labels)
        return {"status": "success", "provider_sync": "success", "project": res["project"]}
    except Exception as e:
        # Capability failure blocks requested sync but is nonblocking for filesystem/repo authority
        return {"status": "failed", "provider_sync": "failed", "sync_error": str(e)}

# Commit Test Cases
# Test case 1: Local artifact-free commit
res1 = simulate_commit_pr_update({"artifacts": {"provider": "local"}}, explicit_issue=None)
if not res1["pr_updated"] or res1["closing_ref"] is not None or res1["artifact_sync"] != "none":
    failures.append("Commit Test 1 failed: local artifact-free commit did not succeed cleanly")

# Test case 2: Linear issue attribution
linear_mock = MockProvider("linear", issues={"WOO-101": {"identifier": "WOO-101", "repository": "acme/repo"}})
res2 = simulate_commit_pr_update({"artifacts": {"provider": "linear"}}, explicit_issue="WOO-101", provider_mock=linear_mock)
if not res2["pr_updated"] or res2["closing_ref"] != "Resolves WOO-101" or res2["artifact_sync"] != "success":
    failures.append("Commit Test 2 failed: Linear attribution did not associate correctly")

# Test case 3: Plane work-item attribution
plane_mock = MockProvider("plane", issues={"PROJ-42": {"identifier": "PROJ-42", "repository": "acme/repo"}})
res3 = simulate_commit_pr_update({"artifacts": {"provider": "plane"}}, explicit_issue="PROJ-42", provider_mock=plane_mock)
if not res3["pr_updated"] or res3["closing_ref"] != "Resolves PROJ-42" or res3["artifact_sync"] != "success":
    failures.append("Commit Test 3 failed: Plane attribution did not associate correctly")


# Test case 3b: GitHub issue attribution
github_mock = MockProvider("github", issues={"https://github.com/acme/repo/issues/42": {"identifier": "https://github.com/acme/repo/issues/42", "repository": "acme/repo"}})
res3b = simulate_commit_pr_update({"artifacts": {"provider": "github"}}, explicit_issue="https://github.com/acme/repo/issues/42", provider_mock=github_mock)
if not res3b["pr_updated"] or res3b["closing_ref"] != "Resolves https://github.com/acme/repo/issues/42" or res3b["artifact_sync"] != "success":
    failures.append("Commit Test 3b failed: GitHub attribution did not associate correctly")
# Test case 4: Absent exact-read capability on provider
no_read_linear = MockProvider("linear", issues={"WOO-101": {"identifier": "WOO-101", "repository": "acme/repo"}}, capabilities={"write_note", "read_back"})
res4a = simulate_commit_pr_update({"artifacts": {"provider": "linear"}}, explicit_issue="WOO-101", provider_mock=no_read_linear)
if res4a["pr_updated"] or res4a["error"] is None or "exact_read" not in res4a["error"]:
    failures.append("Commit Test 4 failed: Absent exact-read capability must fail closed before PR update")

# Test case 5: Absent note write / read-back capability during optional note sync
no_note_linear = MockProvider("linear", issues={"WOO-101": {"identifier": "WOO-101", "repository": "acme/repo"}}, capabilities={"exact_read"})
res4b = simulate_commit_pr_update({"artifacts": {"provider": "linear"}}, explicit_issue="WOO-101", provider_mock=no_note_linear)
if not res4b["pr_updated"] or res4b["closing_ref"] != "Resolves WOO-101" or res4b["artifact_sync"] != "failed":
    failures.append("Commit Test 5 failed: Missing note write/read-back capability must not invalidate PR delivery")

# Test case 6: Issue repository mismatch (wrong repo)
mismatch_plane = MockProvider("plane", issues={"PROJ-42": {"identifier": "PROJ-42", "repository": "other/repo"}})
res5 = simulate_commit_pr_update({"artifacts": {"provider": "plane"}}, explicit_issue="PROJ-42", provider_mock=mismatch_plane)
if res5["pr_updated"] or res5["error"] is None:
    failures.append("Commit Test 6 failed: Foreign repository issue must fail closed before PR update")

# Test case 7: Provider mismatch (Linear config with Plane mock)
res6 = simulate_commit_pr_update({"artifacts": {"provider": "linear"}}, explicit_issue="WOO-101", provider_mock=plane_mock)
if res6["pr_updated"] or res6["error"] is None or "provider mismatch" not in res6["error"]:
    failures.append("Commit Test 7 failed: Provider mismatch must fail closed before PR update")

# Bootstrap Test Cases
# Bootstrap Test 1: Local artifact-free bootstrap
b_res1 = simulate_bootstrap_persistence({"artifacts": {"provider": "local"}}, design_approved=True, explicit_persist=False)
if b_res1["status"] != "skipped" or b_res1["provider_sync"] != "none":
    failures.append("Bootstrap Test 1 failed: Local bootstrap must skip provider calls")

# Bootstrap Test 2: Linear bootstrap with explicit persistence
b_linear_mock = MockProvider("linear")
b_res2 = simulate_bootstrap_persistence({"artifacts": {"provider": "linear", "linear": {"projectLabels": ["frontend"]}}}, design_approved=True, explicit_persist=True, provider_mock=b_linear_mock)
if b_res2["status"] != "success" or b_res2["provider_sync"] != "success" or not b_res2["project"]["designApproved"]:
    failures.append("Bootstrap Test 2 failed: Linear persistence must create project after design approval")

# Bootstrap Test 3: Plane bootstrap with explicit persistence
b_plane_mock = MockProvider("plane")
b_res3 = simulate_bootstrap_persistence({"artifacts": {"provider": "plane", "plane": {"projectLabels": ["core"]}}}, design_approved=True, explicit_persist=True, provider_mock=b_plane_mock)
if b_res3["status"] != "success" or b_res3["provider_sync"] != "success" or not b_res3["project"]["designApproved"]:
    failures.append("Bootstrap Test 3 failed: Plane persistence must create project after design approval")

# Bootstrap Test 4: Missing capability bootstrap (missing project_labels)
b_no_label_mock = MockProvider("plane", capabilities={"create_project", "read_back"})
b_res4 = simulate_bootstrap_persistence({"artifacts": {"provider": "plane", "plane": {"projectLabels": ["core"]}}}, design_approved=True, explicit_persist=True, provider_mock=b_no_label_mock)
if b_res4["status"] != "failed" or b_res4["provider_sync"] != "failed" or "project_labels" not in b_res4["sync_error"]:
    failures.append("Bootstrap Test 4 failed: Missing label capability must fail sync without throwing uncaught error")

# Bootstrap Test 5: Wrong provider bootstrap (Linear config with Plane mock)
b_res5 = simulate_bootstrap_persistence({"artifacts": {"provider": "linear"}}, design_approved=True, explicit_persist=True, provider_mock=b_plane_mock)
if b_res5["status"] != "failed" or "provider mismatch" not in b_res5["error"]:
    failures.append("Bootstrap Test 5 failed: Wrong provider must fail closed")

# Bootstrap Test 6: Unapproved design
b_res6 = simulate_bootstrap_persistence({"artifacts": {"provider": "plane", "plane": {"projectLabels": ["core"]}}}, design_approved=False, explicit_persist=True, provider_mock=b_plane_mock)
if b_res6["status"] != "blocked" or "design approval required" not in b_res6["error"]:
    failures.append("Bootstrap Test 6 failed: Unapproved design must block before provider call")
if failures:
    print("artifact-optional commit contract violations:", file=sys.stderr)
    for failure in failures:
        print(f"- {failure}", file=sys.stderr)
    raise SystemExit(1)
print("artifact-optional commit contract: ok")
PY
