#!/usr/bin/env bash
# Structural and behavioral contract: bootstrap stays artifact-optional and validates provider capability boundaries.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
skill = (root / "skills/woostack-bootstrap/SKILL.md").read_text(encoding="utf-8")
bootstrap_ref = (root / "skills/woostack-bootstrap/references/bootstrap.md").read_text(encoding="utf-8")
fold = lambda text: re.sub(r"\s+", " ", text)
failures = []

def require(text, pattern, message):
    if not re.search(pattern, fold(text), re.I | re.S):
        failures.append(message)

def forbid(text, pattern, message):
    if re.search(pattern, fold(text), re.I | re.S):
        failures.append(message)

# Structural checks on woostack-bootstrap/SKILL.md and references/bootstrap.md
require(skill, r"Optionally persist the approved design", "bootstrap missing optional persistence step")
require(skill, r"Only when the caller explicitly requests provider persistence", "bootstrap persistence must be opt-in")
require(skill, r"design-approval", "bootstrap missing design approval hard gate")
require(skill, r"Artifact text and receipts never release the filesystem barrier", "bootstrap artifact must not breach filesystem barrier")
require(bootstrap_ref, r"Only after explicit design approval", "bootstrap ref missing design approval gate")
require(bootstrap_ref, r"resolve the exact supplied project or create one only when requested", "bootstrap ref missing resolve vs create distinction")
require(bootstrap_ref, r"independently read the exact resource.*content back", "bootstrap ref missing independent read-back")

class MockProvider:
    def __init__(self, provider_type, projects=None, capabilities=None):
        self.provider_type = provider_type
        # projects: dict mapping ref/id/uuid/name to project dict
        self.projects = dict(projects or {})
        # Explicit capabilities: exact_read, create_project, project_labels, write_content, read_back
        self.capabilities = set(capabilities) if capabilities is not None else {
            "exact_read", "create_project", "project_labels", "write_content", "read_back"
        }
        self.read_project_calls = 0
        self.create_project_calls = 0
        self.attach_labels_calls = 0
        self.write_content_calls = 0
        self.read_back_calls = 0
        self.created_projects = []

    def has_capability(self, cap):
        return cap in self.capabilities

    def read_project(self, project_ref):
        if not self.has_capability("exact_read"):
            raise RuntimeError("Missing required capability: exact_read")
        self.read_project_calls += 1
        if project_ref == "ambiguous-ref":
            raise RuntimeError("Ambiguous project reference: multiple matches found")
        return self.projects.get(project_ref)

    def attach_project_labels(self, project_id, labels):
        if not self.has_capability("project_labels"):
            raise RuntimeError("Missing required capability: project_labels")
        self.attach_labels_calls += 1
        proj = self.projects.get(project_id)
        if not proj:
            raise RuntimeError(f"Project not found: {project_id}")
        existing = list(proj.get("labels", []))
        for lbl in labels:
            if lbl not in existing:
                existing.append(lbl)
        proj["labels"] = existing
        return {"status": "success", "labels": proj["labels"]}

    def create_project(self, project_name, labels=None):
        if not self.has_capability("create_project"):
            raise RuntimeError("Missing required capability: create_project")
        if labels and not self.has_capability("project_labels"):
            raise RuntimeError("Missing required capability: project_labels")
        self.create_project_calls += 1
        proj_id = f"proj_{len(self.created_projects) + 1}"
        proj = {
            "id": proj_id,
            "name": project_name,
            "labels": list(labels or []),
            "content": None,
            "designApproved": False,
        }
        self.created_projects.append(proj)
        self.projects[proj_id] = proj
        self.projects[project_name] = proj
        return proj

    def append_design_content(self, project_id, content):
        if not self.has_capability("write_content"):
            raise RuntimeError("Missing required capability: write_content")
        self.write_content_calls += 1
        proj = self.projects.get(project_id)
        if not proj:
            raise RuntimeError(f"Project not found: {project_id}")
        proj["content"] = content
        proj["designApproved"] = True
        return {"status": "success", "project_id": project_id}

    def read_back_project(self, project_id):
        if not self.has_capability("read_back"):
            raise RuntimeError("Missing required capability: read_back")
        self.read_back_calls += 1
        proj = self.projects.get(project_id)
        if not proj:
            raise RuntimeError(f"Project not found on read-back: {project_id}")
        return {
            "id": proj["id"],
            "name": proj["name"],
            "labels": list(proj.get("labels", [])),
            "content": proj.get("content"),
            "designApproved": proj.get("designApproved", False),
        }

def simulate_bootstrap_persistence(
    config,
    design_approved,
    collision_admitted=True,
    explicit_persist=False,
    provider_mock=None,
    supplied_project=None,
    create_requested=False,
    project_name="Widget App",
    design_content="Approved design for Widget App",
):
    if not design_approved:
        return {"status": "blocked", "error": "design approval required before provider persistence"}
    if not collision_admitted:
        return {"status": "blocked", "error": "target collision admission required before provider persistence"}
    provider = config.get("artifacts", {}).get("provider", "local")

    if not explicit_persist or provider == "local":
        return {"status": "skipped", "provider_sync": "none", "project": None}

    if not provider_mock:
        return {"status": "failed", "error": "provider persistence requested but no provider mock available"}

    if provider != provider_mock.provider_type:
        return {"status": "failed", "error": f"provider mismatch: config specifies '{provider}' but mock is '{provider_mock.provider_type}'"}

    project = None
    configured_labels = []
    if provider == "plane":
        configured_labels = config.get("artifacts", {}).get("plane", {}).get("projectLabels", [])
        if not configured_labels:
            return {"status": "failed", "error": "artifacts.plane.projectLabels required as non-empty array"}
    elif provider == "linear":
        configured_labels = config.get("artifacts", {}).get("linear", {}).get("projectLabels", [])

    if supplied_project:
        try:
            project = provider_mock.read_project(supplied_project)
            if not project:
                return {"status": "failed", "provider_sync": "failed", "sync_error": f"supplied project '{supplied_project}' not found"}
        except Exception as e:
            return {"status": "failed", "provider_sync": "failed", "sync_error": str(e)}

        if configured_labels:
            if not provider_mock.has_capability("project_labels"):
                return {"status": "failed", "provider_sync": "failed", "sync_error": "Missing required capability: project_labels"}
            existing_labels = list(project.get("labels", []))
            missing_labels = [lbl for lbl in configured_labels if lbl not in existing_labels]
            if missing_labels:
                try:
                    provider_mock.attach_project_labels(project["id"], missing_labels)
                except Exception as e:
                    return {"status": "failed", "provider_sync": "failed", "sync_error": str(e)}
    elif create_requested:
        try:
            project = provider_mock.create_project(project_name, labels=configured_labels)
        except Exception as e:
            return {"status": "failed", "provider_sync": "failed", "sync_error": str(e)}
    else:
        return {"status": "failed", "error": "neither supplied project nor explicit create requested"}

    try:
        provider_mock.append_design_content(project["id"], design_content)
    except Exception as e:
        return {"status": "failed", "provider_sync": "failed", "sync_error": str(e)}

    try:
        read_back = provider_mock.read_back_project(project["id"])
        if configured_labels:
            read_back_labels = read_back.get("labels", [])
            for req_lbl in configured_labels:
                if req_lbl not in read_back_labels:
                    return {"status": "failed", "provider_sync": "failed", "sync_error": f"configured label '{req_lbl}' missing from read-back project labels"}
        return {"status": "success", "provider_sync": "success", "project": read_back}
    except Exception as e:
        return {"status": "failed", "provider_sync": "failed", "sync_error": str(e)}

# Bootstrap Test 1: Local artifact-free bootstrap
b_res1 = simulate_bootstrap_persistence({"artifacts": {"provider": "local"}}, design_approved=True, explicit_persist=False)
if b_res1["status"] != "skipped" or b_res1["provider_sync"] != "none":
    failures.append("Bootstrap Test 1 failed: Local bootstrap must skip provider calls")

# Bootstrap Test 2: Exact existing Linear project resolution without creation
b_lin_existing = MockProvider("linear", projects={"lin_p1": {"id": "lin_p1", "name": "Core App", "labels": ["web"]}})
b_res2 = simulate_bootstrap_persistence({"artifacts": {"provider": "linear"}}, design_approved=True, explicit_persist=True, provider_mock=b_lin_existing, supplied_project="lin_p1")
if (
    b_res2["status"] != "success"
    or b_res2["provider_sync"] != "success"
    or b_lin_existing.create_project_calls != 0
    or b_lin_existing.read_project_calls != 1
    or b_lin_existing.attach_labels_calls != 0
    or b_lin_existing.write_content_calls != 1
    or b_lin_existing.read_back_calls != 1
    or b_res2["project"]["id"] != "lin_p1"
    or not b_res2["project"]["designApproved"]
):
    failures.append("Bootstrap Test 2 failed: Exact existing Linear project must resolve without creation and read back approved design")

# Bootstrap Test 3: Exact existing Plane project resolution (matching-label case)
b_plane_existing = MockProvider("plane", projects={"plane_p2": {"id": "plane_p2", "name": "API Service", "labels": ["backend"]}})
b_res3 = simulate_bootstrap_persistence({"artifacts": {"provider": "plane", "plane": {"projectLabels": ["backend"]}}}, design_approved=True, explicit_persist=True, provider_mock=b_plane_existing, supplied_project="plane_p2")
if (
    b_res3["status"] != "success"
    or b_res3["provider_sync"] != "success"
    or b_plane_existing.create_project_calls != 0
    or b_plane_existing.read_project_calls != 1
    or b_plane_existing.attach_labels_calls != 0
    or b_plane_existing.write_content_calls != 1
    or b_plane_existing.read_back_calls != 1
    or b_res3["project"]["id"] != "plane_p2"
    or b_res3["project"]["labels"] != ["backend"]
    or not b_res3["project"]["designApproved"]
):
    failures.append("Bootstrap Test 3 failed: Exact existing Plane project with matching labels must resolve without creation or extra attach calls")

# Bootstrap Test 3b: Exact existing Plane project resolution (missing-label case: attaches only missing labels)
b_plane_miss = MockProvider("plane", projects={"plane_miss": {"id": "plane_miss", "name": "Worker Service", "labels": ["backend"]}})
b_res3b = simulate_bootstrap_persistence({"artifacts": {"provider": "plane", "plane": {"projectLabels": ["backend", "core"]}}}, design_approved=True, explicit_persist=True, provider_mock=b_plane_miss, supplied_project="plane_miss")
if (
    b_res3b["status"] != "success"
    or b_res3b["provider_sync"] != "success"
    or b_plane_miss.create_project_calls != 0
    or b_plane_miss.read_project_calls != 1
    or b_plane_miss.attach_labels_calls != 1
    or b_plane_miss.write_content_calls != 1
    or b_plane_miss.read_back_calls != 1
    or b_res3b["project"]["id"] != "plane_miss"
    or b_res3b["project"]["labels"] != ["backend", "core"]
    or not b_res3b["project"]["designApproved"]
):
    failures.append("Bootstrap Test 3b failed: Exact existing Plane project must attach only missing labels and read back full union")

# Bootstrap Test 3c: Exact existing Plane project resolution (unrelated-label preservation case)
b_plane_unrelated = MockProvider("plane", projects={"plane_unrel": {"id": "plane_unrel", "name": "Custom Service", "labels": ["custom-infra", "billing", "backend"]}})
b_res3c = simulate_bootstrap_persistence({"artifacts": {"provider": "plane", "plane": {"projectLabels": ["backend", "core"]}}}, design_approved=True, explicit_persist=True, provider_mock=b_plane_unrelated, supplied_project="plane_unrel")
if (
    b_res3c["status"] != "success"
    or b_res3c["provider_sync"] != "success"
    or b_plane_unrelated.create_project_calls != 0
    or b_plane_unrelated.read_project_calls != 1
    or b_plane_unrelated.attach_labels_calls != 1
    or b_plane_unrelated.write_content_calls != 1
    or b_plane_unrelated.read_back_calls != 1
    or b_res3c["project"]["id"] != "plane_unrel"
    or b_res3c["project"]["labels"] != ["custom-infra", "billing", "backend", "core"]
    or not b_res3c["project"]["designApproved"]
):
    failures.append("Bootstrap Test 3c failed: Exact existing Plane project must preserve all unrelated existing labels")

# Bootstrap Test 3d: Exact existing Plane project resolution (missing project_labels capability fails cleanly)
b_plane_nocap = MockProvider("plane", projects={"plane_nocap": {"id": "plane_nocap", "name": "No Cap Service", "labels": ["backend"]}}, capabilities={"exact_read", "create_project", "write_content", "read_back"})
b_res3d = simulate_bootstrap_persistence({"artifacts": {"provider": "plane", "plane": {"projectLabels": ["backend", "core"]}}}, design_approved=True, explicit_persist=True, provider_mock=b_plane_nocap, supplied_project="plane_nocap")
if (
    b_res3d["status"] != "failed"
    or b_res3d["provider_sync"] != "failed"
    or b_plane_nocap.create_project_calls != 0
    or b_plane_nocap.read_project_calls != 1
    or b_plane_nocap.attach_labels_calls != 0
    or b_plane_nocap.write_content_calls != 0
    or b_plane_nocap.read_back_calls != 0
    or "project_labels" not in b_res3d["sync_error"]
):
    failures.append("Bootstrap Test 3d failed: Existing Plane project with missing project_labels capability must fail cleanly without write/attach calls")

# Bootstrap Test 4: Explicit new-project creation after design approval (Plane with labels)
b_plane_create = MockProvider("plane")
b_res4 = simulate_bootstrap_persistence({"artifacts": {"provider": "plane", "plane": {"projectLabels": ["core"]}}}, design_approved=True, explicit_persist=True, provider_mock=b_plane_create, create_requested=True, project_name="Widget App")
if (
    b_res4["status"] != "success"
    or b_res4["provider_sync"] != "success"
    or b_plane_create.create_project_calls != 1
    or b_plane_create.read_project_calls != 0
    or b_plane_create.write_content_calls != 1
    or b_plane_create.read_back_calls != 1
    or b_res4["project"]["name"] != "Widget App"
    or b_res4["project"]["labels"] != ["core"]
    or not b_res4["project"]["designApproved"]
):
    failures.append("Bootstrap Test 4 failed: Explicit Plane project creation must create, append, and read back")

# Bootstrap Test 5: Explicit new-project creation with Linear
b_linear_create = MockProvider("linear")
b_res5 = simulate_bootstrap_persistence({"artifacts": {"provider": "linear", "linear": {"projectLabels": ["frontend"]}}}, design_approved=True, explicit_persist=True, provider_mock=b_linear_create, create_requested=True, project_name="Linear App")
if (
    b_res5["status"] != "success"
    or b_res5["provider_sync"] != "success"
    or b_linear_create.create_project_calls != 1
    or b_linear_create.write_content_calls != 1
    or b_linear_create.read_back_calls != 1
    or b_res5["project"]["name"] != "Linear App"
    or not b_res5["project"]["designApproved"]
):
    failures.append("Bootstrap Test 5 failed: Explicit Linear project creation must create, append, and read back")
# Bootstrap Test 5b: Exact existing GitHub project resolution without creation
gh_p1_proj = {"id": "gh_p1", "name": "GitHub App", "labels": []}
b_gh_existing = MockProvider("github", projects={"https://github.com/orgs/acme/projects/1": gh_p1_proj, "gh_p1": gh_p1_proj})
b_res5b = simulate_bootstrap_persistence({"artifacts": {"provider": "github", "github": {"owner": "acme"}}}, design_approved=True, explicit_persist=True, provider_mock=b_gh_existing, supplied_project="https://github.com/orgs/acme/projects/1")
if (
    b_res5b["status"] != "success"
    or b_res5b["provider_sync"] != "success"
    or b_gh_existing.create_project_calls != 0
    or b_gh_existing.read_project_calls != 1
    or b_gh_existing.write_content_calls != 1
    or b_gh_existing.read_back_calls != 1
    or b_res5b["project"]["id"] != "gh_p1"
    or not b_res5b["project"]["designApproved"]
):
    failures.append("Bootstrap Test 5b failed: Exact existing GitHub project must resolve without creation and read back approved design")

# Bootstrap Test 5c: Explicit new-project creation with GitHub
b_gh_create = MockProvider("github")
b_res5c = simulate_bootstrap_persistence({"artifacts": {"provider": "github", "github": {"owner": "acme"}}}, design_approved=True, explicit_persist=True, provider_mock=b_gh_create, create_requested=True, project_name="GitHub App")
if (
    b_res5c["status"] != "success"
    or b_res5c["provider_sync"] != "success"
    or b_gh_create.create_project_calls != 1
    or b_gh_create.write_content_calls != 1
    or b_gh_create.read_back_calls != 1
    or b_res5c["project"]["name"] != "GitHub App"
    or not b_res5c["project"]["designApproved"]
):
    failures.append("Bootstrap Test 5c failed: Explicit GitHub project creation must create, append, and read back")

# Bootstrap Test 6: Ambiguous / duplicate project selection fails closed without creation
b_ambig_mock = MockProvider("linear")
b_res6 = simulate_bootstrap_persistence({"artifacts": {"provider": "linear"}}, design_approved=True, explicit_persist=True, provider_mock=b_ambig_mock, supplied_project="ambiguous-ref")
if (
    b_res6["status"] != "failed"
    or b_res6["provider_sync"] != "failed"
    or b_ambig_mock.create_project_calls != 0
    or "Ambiguous" not in b_res6["sync_error"]
):
    failures.append("Bootstrap Test 6 failed: Ambiguous project reference must fail closed with zero project creation")

# Bootstrap Test 7: Absent / unknown supplied project fails closed without creation
b_absent_mock = MockProvider("linear")
b_res7 = simulate_bootstrap_persistence({"artifacts": {"provider": "linear"}}, design_approved=True, explicit_persist=True, provider_mock=b_absent_mock, supplied_project="nonexistent-proj")
if (
    b_res7["status"] != "failed"
    or b_res7["provider_sync"] != "failed"
    or b_absent_mock.create_project_calls != 0
    or "not found" not in b_res7["sync_error"]
):
    failures.append("Bootstrap Test 7 failed: Absent supplied project must fail closed with zero project creation")

# Bootstrap Test 8: Missing exact_read capability on supplied project fails closed
b_no_read_mock = MockProvider("linear", projects={"lin_p1": {"id": "lin_p1"}}, capabilities={"create_project", "project_labels", "write_content", "read_back"})
b_res8 = simulate_bootstrap_persistence({"artifacts": {"provider": "linear"}}, design_approved=True, explicit_persist=True, provider_mock=b_no_read_mock, supplied_project="lin_p1")
if (
    b_res8["status"] != "failed"
    or b_res8["provider_sync"] != "failed"
    or b_no_read_mock.create_project_calls != 0
    or "exact_read" not in b_res8["sync_error"]
):
    failures.append("Bootstrap Test 8 failed: Missing exact_read capability must fail closed without project creation")

# Bootstrap Test 9: Missing create_project capability on explicit create fails closed
b_no_create_mock = MockProvider("plane", capabilities={"exact_read", "project_labels", "write_content", "read_back"})
b_res9 = simulate_bootstrap_persistence({"artifacts": {"provider": "plane", "plane": {"projectLabels": ["core"]}}}, design_approved=True, explicit_persist=True, provider_mock=b_no_create_mock, create_requested=True)
if (
    b_res9["status"] != "failed"
    or b_res9["provider_sync"] != "failed"
    or "create_project" not in b_res9["sync_error"]
):
    failures.append("Bootstrap Test 9 failed: Missing create_project capability must fail sync cleanly")

# Bootstrap Test 10: Missing project_labels capability on Plane create fails closed
b_no_labels_mock = MockProvider("plane", capabilities={"exact_read", "create_project", "write_content", "read_back"})
b_res10 = simulate_bootstrap_persistence({"artifacts": {"provider": "plane", "plane": {"projectLabels": ["core"]}}}, design_approved=True, explicit_persist=True, provider_mock=b_no_labels_mock, create_requested=True)
if (
    b_res10["status"] != "failed"
    or b_res10["provider_sync"] != "failed"
    or "project_labels" not in b_res10["sync_error"]
):
    failures.append("Bootstrap Test 10 failed: Missing project_labels capability must fail sync cleanly")

# Bootstrap Test 11: Missing write_content capability fails sync cleanly
b_no_write_mock = MockProvider("plane", capabilities={"exact_read", "create_project", "project_labels", "read_back"})
b_res11 = simulate_bootstrap_persistence({"artifacts": {"provider": "plane", "plane": {"projectLabels": ["core"]}}}, design_approved=True, explicit_persist=True, provider_mock=b_no_write_mock, create_requested=True)
if (
    b_res11["status"] != "failed"
    or b_res11["provider_sync"] != "failed"
    or b_no_write_mock.create_project_calls != 1
    or b_no_write_mock.write_content_calls != 0
    or b_no_write_mock.read_back_calls != 0
    or "write_content" not in b_res11["sync_error"]
):
    failures.append("Bootstrap Test 11 failed: Missing write_content capability must fail sync cleanly")

# Bootstrap Test 12: Missing read_back capability fails sync cleanly
b_no_readback_mock = MockProvider("plane", capabilities={"exact_read", "create_project", "project_labels", "write_content"})
b_res12 = simulate_bootstrap_persistence({"artifacts": {"provider": "plane", "plane": {"projectLabels": ["core"]}}}, design_approved=True, explicit_persist=True, provider_mock=b_no_readback_mock, create_requested=True)
if (
    b_res12["status"] != "failed"
    or b_res12["provider_sync"] != "failed"
    or b_no_readback_mock.create_project_calls != 1
    or b_no_readback_mock.write_content_calls != 1
    or b_no_readback_mock.read_back_calls != 0
    or "read_back" not in b_res12["sync_error"]
):
    failures.append("Bootstrap Test 12 failed: Missing read_back capability must fail sync cleanly")

# Bootstrap Test 13: Wrong provider bootstrap (Linear config with Plane mock)
b_res13 = simulate_bootstrap_persistence({"artifacts": {"provider": "linear"}}, design_approved=True, explicit_persist=True, provider_mock=b_plane_create, create_requested=True)
if b_res13["status"] != "failed" or "provider mismatch" not in b_res13["error"]:
    failures.append("Bootstrap Test 13 failed: Wrong provider must fail closed")

# Bootstrap Test 13b: Wrong provider bootstrap (GitHub config with Linear mock)
b_res13b = simulate_bootstrap_persistence({"artifacts": {"provider": "github", "github": {"owner": "acme"}}}, design_approved=True, explicit_persist=True, provider_mock=b_linear_create, create_requested=True)
if b_res13b["status"] != "failed" or "provider mismatch" not in b_res13b["error"]:
    failures.append("Bootstrap Test 13b failed: Wrong provider for GitHub must fail closed")

# Bootstrap Test 14: Unapproved design blocks before any provider calls
b_unapproved_mock = MockProvider("plane")
b_res14 = simulate_bootstrap_persistence({"artifacts": {"provider": "plane", "plane": {"projectLabels": ["core"]}}}, design_approved=False, collision_admitted=True, explicit_persist=True, provider_mock=b_unapproved_mock, create_requested=True)
if (
    b_res14["status"] != "blocked"
    or "design approval required" not in b_res14["error"]
    or b_unapproved_mock.read_project_calls != 0
    or b_unapproved_mock.create_project_calls != 0
    or b_unapproved_mock.write_content_calls != 0
    or b_unapproved_mock.read_back_calls != 0
):
    failures.append("Bootstrap Test 14 failed: Unapproved design must block before any provider calls")

# Bootstrap Test 14b: Unadmitted collision blocks before any GitHub calls
b_unadmitted_gh_mock = MockProvider("github")
b_res14b = simulate_bootstrap_persistence({"artifacts": {"provider": "github", "github": {"owner": "acme"}}}, design_approved=True, collision_admitted=False, explicit_persist=True, provider_mock=b_unadmitted_gh_mock, create_requested=True)
if (
    b_res14b["status"] != "blocked"
    or "target collision admission required" not in b_res14b["error"]
    or b_unadmitted_gh_mock.read_project_calls != 0
    or b_unadmitted_gh_mock.create_project_calls != 0
    or b_unadmitted_gh_mock.write_content_calls != 0
    or b_unadmitted_gh_mock.read_back_calls != 0
):
    failures.append("Bootstrap Test 14b failed: Unadmitted collision must block before any GitHub provider calls")

if failures:
    print("artifact-optional bootstrap contract violations:", file=sys.stderr)
    for failure in failures:
        print(f"- {failure}", file=sys.stderr)
    raise SystemExit(1)
print("artifact-optional bootstrap contract: ok")
PY
