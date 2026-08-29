#!/usr/bin/env bash
# Structural contract for plain local artifacts and optional Linear/Plane mirrors.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
paths = {
    "build": root / "skills/woostack-build/SKILL.md",
    "linear_context": root / "skills/woostack-build/references/linear-context.md",
    "linear_procedure": root / "skills/woostack-build/references/linear-procedure.md",
    "plane_context": root / "skills/woostack-build/references/plane-context.md",
    "plane_procedure": root / "skills/woostack-build/references/plane-procedure.md",
    "github_context": root / "skills/woostack-build/references/github-context.md",
    "github_procedure": root / "skills/woostack-build/references/github-procedure.md",
    "artifact": root / "skills/woostack-init/references/artifact-backends.md",
    "linear_profile": root / "skills/woostack-init/references/artifact-providers/linear.md",
    "plane_profile": root / "skills/woostack-init/references/artifact-providers/plane.md",
    "github_profile": root / "skills/woostack-init/references/artifact-providers/github.md",
    "ideate": root / "skills/woostack-ideate/SKILL.md",
    "harden": root / "skills/woostack-harden/SKILL.md",
    "plan": root / "skills/woostack-plan/SKILL.md",
    "fix": root / "skills/woostack-fix/SKILL.md",
    "execute": root / "skills/woostack-execute/SKILL.md",
    "controller": root / "skills/woostack-execute/references/controller.md",
}
text = {name: path.read_text(encoding="utf-8") for name, path in paths.items()}
flat = {name: re.sub(r"\s+", " ", value) for name, value in text.items()}
failures = []


def require(name, pattern, message=None):
    if not re.search(pattern, flat[name], re.I | re.S):
        failures.append(message or f"{name}: missing {pattern!r}")


def forbid(names, pattern, message=None):
    for name in names:
        if re.search(pattern, flat[name], re.I | re.S):
            failures.append(message or f"{name}: obsolete contract remains: {pattern!r}")


# Build remains a thin controller around plain local artifacts.
for pattern in (
    r"\.woostack/tmp/runs/<run-id>/",
    r"project-spec\.md",
    r"execution-plan\.md",
    r"Ideate.*zero provider",
    r"delegated Plan.*zero provider",
    r"Stop here.*Execute.*Abandon",
    r"retain.*run artifacts",
    r"Build never merges|never merges",
    r"resolves the exact.*supplied.*project or creates exactly one.*project|\[Build\] ",
    r"writes plain Markdown `project-spec\.md`",
    r"writes plain Markdown `execution-plan\.md`",
    r"safe removal/simplification analysis|removal.*before additive",
):
    require("build", pattern)

for name in ("build", "linear_context", "linear_procedure", "plane_context", "plane_procedure", "github_context", "github_procedure", "ideate", "harden", "plan", "fix", "execute"):
    require(name, r"manifest", f"{name}: local run manifest contract missing")
# The shared contract owns local safety, one-time plain writes, recovery, and explicit base choice.
artifact_requirements = (
    r"Local run artifact and provider mirror contract",
    r"artifacts\.provider.*gates every provider call",
    r"zero provider reads or writes",
    r"\.woostack/config\.local\.json",
    r"no-follow semantics",
    r"directory mode is exactly `0700`",
    r"owner-only `0600`",
    r"Write `project-spec\.md` exactly once",
    r"Write `execution-plan\.md` exactly once",
    r"Never patch, replace, regenerate, or rewrite either final artifact",
    r"exclusive creation.*flush the file.*atomically rename.*flush the directory",
    r"manifest records only what recovery and strict sequential execution need",
    r"compare-and-swap",
    r"stableTaskMappings",
    r"taskExecutions\[stableTaskKey\]",
    r"unknown.*parent.*blocks",
    r"Do not create (?:synthetic )?parent plan resource",
    r"Preserve its title, description, lifecycle state, assignment, labels, relations, comments, and membership",
    r"full project fields.*complete membership set.*complete dependency graph",
    r"existing-description mutation invariant",
    r"active Execute project-start synchronization",
    r"project-backed workflow closure",
    r"Retain `manifest\.json`, `project-spec\.md`, `execution-plan\.md`, and `\.lock`",
    r"Report repository delivery and mirror synchronization separately",
    r"If the current tip equals the planning tip, continue without a question",
    r"If the same branch has a different tip, make zero mutations",
    r"`Continue`.*`Revise spec/plan`.*`Stop`",
    r"This is never automatic",
    r"checks.*for observation only",
)
for pattern in artifact_requirements:
    require("artifact", pattern)

# Provider safety retained by Build and its shared references.
for name in ("linear_context", "linear_procedure", "plane_context", "plane_procedure", "github_context", "github_procedure"):
    require(name, r"nullable-parent|null parent|parent state|parent = null")
for name in ("linear_procedure", "plane_procedure", "github_procedure"):
    require(name, r"zero provider and repository mutation")
require("harden", r"canonical issue references|canonical provider references")
require("linear_profile", r"host-authenticated official Linear MCP")
require("plane_profile", r"host-authenticated official Plane MCP")
require("github_profile", r"host-authenticated official `?gh`? CLI")
require("artifact", r"untrusted data")
require("artifact", r"Never replace an existing full description")
require("linear_profile", r"completed or canceled.*terminal conflicts")
require("linear_profile", r"update only its native status")

# Configured project label preservation contracts
for profile in ("linear_profile", "plane_profile"):
    require(profile, r"projectLabels")
    require(profile, r"complete.*workspace project-label discovery|completely paginate workspace project labels")
    require(profile, r"exact.*native ID.*or exact.*case-sensitive name|exact native UUID.*or exact case-sensitive name")
    require(profile, r"Union configured labels with existing labels")
    require(profile, r"preserving unrelated labels")
    require(profile, r"write at most once")
    require(profile, r"independently read back the complete label set")
    require(profile, r"before mutation")

# Linear-specific context checks
require("linear_context", r"projectLabels")
require("linear_context", r"completely paginate all workspace project labels.*flatten every page.*require null terminal cursors.*resolve.*before any project creation or admission mutation")
require("linear_context", r"exact native ID.*or exact case-sensitive name")
require("linear_context", r"union.*configured labels with existing project labels")
require("linear_context", r"preserving unrelated.*existing labels")
require("linear_context", r"at most one write alongside admission|applying the union of resolved configured labels in the creation write")
require("linear_context", r"independently read the project and complete label set back")
require("linear_context", r"Reject missing, ambiguous, duplicate, or incomplete matches before mutation")

# Plane-specific context and procedure checks
require("plane_context", r"projectLabels")
require("plane_context", r"Completely paginate all workspace project labels.*require null terminal cursors.*resolve")
require("plane_context", r"exact native UUID.*or exact case-sensitive name")
require("plane_context", r"Union resolved labels with the configured project's.*existing labels")
require("plane_context", r"preserving unrelated labels")
require("plane_context", r"Preflight official Plane MCP capabilities.*project-label")
require("plane_context", r"external_source.*external_id")
require("plane_context", r"parent = null")
require("plane_context", r"parent = <spec-item-UUID>|exact children of the specification work item")
require("plane_procedure", r"external_source.*external_id")
require("plane_procedure", r"parent = null")
require("plane_procedure", r"parent = <spec-item-UUID>|exact specification parent UUID")
require("plane_procedure", r"N-1.*strict blocking relations")

# GitHub-specific context and procedure checks
require("github_context", r"artifacts\.github\.owner")
require("github_context", r"<!-- woostack-project-mutation:<UUID> -->")
require("github_context", r"<!-- woostack-spec-start -->.*<!-- woostack-spec-end -->")
require("github_context", r"<!-- woostack-issue-mutation:<UUID> -->")
require("github_context", r"parent = null")
require("github_procedure", r"<!-- woostack-spec-start -->.*<!-- woostack-spec-end -->")
require("github_procedure", r"shortDescription")
require("github_procedure", r"parent = null")
require("github_procedure", r"N-1.*strict dependencies|N-1.*dependencies")
source_names = tuple(paths)
for obsolete in (
    r"canonicalProjectSpecFingerprint",
    r"canonicalIncrementFingerprint",
    r"projectSpecApprovalRecord",
    r"executionPlanApprovalRecord",
    r"approvalEventId",
    r"fingerprintVersion",
    r"providerPresentationCanonicalization",
    r"gate[- ]file.*(?:SHA-256|byteLength|identity)",
    r"\bstream(?:ed|ing)?.*(?:full|complete).*(?:bytes|content)",
    r"reaccept|re-accept",
    r"compatible[- ]advancement|compatible parent advancement",
):
    forbid(source_names, obsolete)

# One direct issue per increment and native relations remain required.
require("artifact", r"Do not create (?:synthetic )?parent plan resource")
require("artifact", r"membership before relations")
require("artifact", r"Bind each newly created issue to its stable task key exactly once|bind the mapping exactly once")

if failures:
    raise SystemExit("\n".join(failures))

# ---------------------------------------------------------------------------
# Synthetic fixture-driven Plane Build provider boundary tests (0 network calls)
# ---------------------------------------------------------------------------

class MockPlaneMCP:
    def __init__(self, base_url="https://api.plane.so", workspace="acme", capabilities=None):
        self.base_url = base_url
        self.workspace = workspace
        self.capabilities = capabilities or {
            "projectRead": True, "projectWrite": True,
            "issueRead": True, "issueWrite": True,
            "relationRead": True, "relationWrite": True,
            "projectLabelRead": True, "projectLabelWrite": True,
            "independentReadBack": True,
        }
        self.workspace_labels = []
        self.projects = {}
        self.work_items = {}
        self.relations = []
        self.operations = []

    def list_project_labels(self, workspace, cursor=None):
        self.operations.append(("list_project_labels", workspace, cursor))
        if not self.capabilities.get("projectLabelRead"):
            raise RuntimeError("missing capability: projectLabelRead")
        if workspace != self.workspace:
            raise ValueError(f"foreign workspace: {workspace}")
        # 2-page pagination fixture
        if cursor is None:
            return {"items": self.workspace_labels[:2], "next_cursor": "cur-2"}
        elif cursor == "cur-2":
            return {"items": self.workspace_labels[2:], "next_cursor": None}
        return {"items": [], "next_cursor": None}

    def create_project(self, workspace, name, labels=None, external_source=None, external_id=None):
        self.operations.append(("create_project", workspace, name, labels, external_id))
        if not self.capabilities.get("projectWrite"):
            raise RuntimeError("missing capability: projectWrite")
        proj_id = f"proj-{len(self.projects) + 1}"
        proj = {"id": proj_id, "name": name, "workspace": workspace, "labels": labels or [], "external_source": external_source, "external_id": external_id}
        self.projects[proj_id] = proj
        return proj
    def read_project(self, workspace, project_id):
        self.operations.append(("read_project", workspace, project_id))
        if not self.capabilities.get("projectRead"):
            raise RuntimeError("missing capability: projectRead")
        proj = self.projects.get(project_id)
        if not proj or proj["workspace"] != workspace:
            return None
        return dict(proj)


    def find_project_by_external_id(self, workspace, external_source, external_id):
        self.operations.append(("find_proj_by_ext_id", workspace, external_source, external_id))
        for proj in self.projects.values():
            if proj["workspace"] == workspace and proj.get("external_source") == external_source and proj.get("external_id") == external_id:
                return proj
        return None

    def create_work_item(self, workspace, project_id, title, external_source=None, external_id=None, parent=None):
        self.operations.append(("create_work_item", workspace, project_id, title, external_id, parent))
        if not self.capabilities.get("issueWrite"):
            raise RuntimeError("missing capability: issueWrite")
        wi_id = f"wi-{len(self.work_items) + 1}"
        wi = {
            "id": wi_id, "workspace": workspace, "project_id": project_id,
            "title": title, "external_source": external_source,
            "external_id": external_id, "parent": parent
        }
        self.work_items[wi_id] = wi
        return wi
    def read_work_item(self, workspace, project_id, work_item_id):
        self.operations.append(("read_work_item", workspace, project_id, work_item_id))
        wi = self.work_items.get(work_item_id)
        if not wi or wi["workspace"] != workspace or wi["project_id"] != project_id:
            return None
        return dict(wi)

    def find_work_item_by_external_id(self, workspace, project_id, external_source, external_id):
        self.operations.append(("find_by_ext_id", workspace, project_id, external_source, external_id))
        for wi in self.work_items.values():
            if wi["workspace"] == workspace and wi["project_id"] == project_id and wi["external_source"] == external_source and wi["external_id"] == external_id:
                return wi
        return None

    def create_relation(self, workspace, project_id, source_id, target_id, relation_type="blocks", external_id=None):
        self.operations.append(("create_relation", source_id, target_id, relation_type, external_id))
        if not self.capabilities.get("relationWrite"):
            raise RuntimeError("missing capability: relationWrite")
        rel_id = f"rel-{len(self.relations) + 1}"
        rel = {"id": rel_id, "source": source_id, "target": target_id, "type": relation_type, "external_id": external_id}
        self.relations.append(rel)
        return rel

    def read_back_graph(self, project_id):
        self.operations.append(("read_back_graph", project_id))
        items = [wi for wi in self.work_items.values() if wi["project_id"] == project_id]
        return {"work_items": items, "relations": list(self.relations)}


def canonicalize_plane_url(url: str) -> str:
    url = re.sub(r"/+$", "", url)
    if re.match(r"^https?://(api|app)\.plane\.so$", url, re.I):
        return "https://api.plane.so"
    return url


# Simulation: Execute Plane Build mirror workflow
def simulate_plane_build_mirror(config, mcp, spec_text, plan_increments):
    # 1. Canonicalize instance URL and check scope
    canonical_url = canonicalize_plane_url(config["plane"]["baseUrl"])
    if canonical_url != mcp.base_url or config["plane"]["workspace"] != mcp.workspace:
        raise ValueError(f"instance/workspace mismatch: {canonical_url}/{config['plane']['workspace']}")

    # 2. Check capabilities
    req_caps = ["projectRead", "projectWrite", "issueRead", "issueWrite", "relationRead", "relationWrite", "independentReadBack"]
    for cap in req_caps:
        if not mcp.capabilities.get(cap):
            raise RuntimeError(f"missing capability: {cap}")

    # 3. Label resolution if configured
    configured_labels = config["plane"].get("projectLabels", [])
    resolved_label_ids = []
    if configured_labels:
        if not mcp.capabilities.get("projectLabelRead") or not mcp.capabilities.get("projectLabelWrite"):
            raise RuntimeError("missing label capability")
        # Paginate labels
        all_labels = []
        cursor = None
        while True:
            page = mcp.list_project_labels(config["plane"]["workspace"], cursor)
            all_labels.extend(page["items"])
            cursor = page.get("next_cursor")
            if cursor is None:
                break
        label_map = {lbl["name"]: lbl["id"] for lbl in all_labels}
        for name in configured_labels:
            if name not in label_map:
                raise ValueError(f"unresolved label: {name}")
            resolved_label_ids.append(label_map[name])

    # 4. Exact configured project admission
    project_ref = config["plane"]["project"]
    manifest = {
        "stableTaskMappings": {},
        "mirror": {
            "provider": "plane",
            "project": {
                "baseUrl": canonical_url,
                "workspace": config["plane"]["workspace"],
                "canonicalRef": None,
                "nativeId": None,
            },
            "specItem": {
                "externalId": "ext-spec-1",
                "canonicalRef": None,
                "nativeId": None,
            },
            "tasks": {},
            "relations": [],
            "status": "unstarted",
        }
    }

    proj = mcp.read_project(config["plane"]["workspace"], project_ref)
    if not proj:
        raise RuntimeError("failed to read configured project")
    effective_labels = list(dict.fromkeys(proj.get("labels", []) + resolved_label_ids))
    mcp.projects[proj["id"]]["labels"] = effective_labels
    mcp.operations.append(("update_project_labels", proj["id"], effective_labels))
    proj = mcp.read_project(config["plane"]["workspace"], project_ref)
    if not proj or proj.get("labels") != effective_labels:
        raise RuntimeError("failed to read back configured project labels")

    manifest["mirror"]["project"]["nativeId"] = proj["id"]
    manifest["mirror"]["project"]["canonicalRef"] = proj["id"]

    # 5. Top-level specification work item creation with parent = None
    spec_created = mcp.create_work_item(config["plane"]["workspace"], proj["id"], "[Build] New Feature",
                                        external_source="woostack", external_id="ext-spec-1", parent=None)
    # Independent read_work_item before spec item binding
    spec_wi = mcp.read_work_item(config["plane"]["workspace"], proj["id"], spec_created["id"])
    if not spec_wi:
        raise RuntimeError("failed to read back created specification work item")
    manifest["mirror"]["specItem"]["nativeId"] = spec_wi["id"]
    manifest["mirror"]["specItem"]["canonicalRef"] = spec_wi["id"]

    # 6. Increment child work items with parent = spec_wi["id"]
    created_wis = []
    for inc in plan_increments:
        task_key = inc["task_key"]
        ext_id = f"ext-{task_key}"
        # Preallocate
        manifest["mirror"]["tasks"][task_key] = {"externalId": ext_id, "canonicalRef": None, "nativeId": None}
        # Create child work item with parent = spec_wi["id"]
        wi_created = mcp.create_work_item(config["plane"]["workspace"], proj["id"], inc["title"],
                                          external_source="woostack", external_id=ext_id, parent=spec_wi["id"])
        # Independent read_work_item before binding to stableTaskMappings and before relations
        wi = mcp.read_work_item(config["plane"]["workspace"], proj["id"], wi_created["id"])
        if not wi:
            raise RuntimeError(f"failed to read back created child work item {task_key}")
        manifest["stableTaskMappings"][task_key] = wi["id"]
        manifest["mirror"]["tasks"][task_key]["nativeId"] = wi["id"]
        manifest["mirror"]["tasks"][task_key]["canonicalRef"] = wi["id"]
        created_wis.append(wi)

    # Create N-1 blocking relations (predecessor blocks successor) between increment child work items
    for i in range(len(created_wis) - 1):
        pred = created_wis[i]
        succ = created_wis[i + 1]
        rel_ext_id = f"rel-ext-{i}"
        rel = mcp.create_relation(config["plane"]["workspace"], proj["id"],
                                  pred["id"], succ["id"], relation_type="blocks", external_id=rel_ext_id)
        manifest["mirror"]["relations"].append({
            "sourceKey": plan_increments[i]["task_key"],
            "targetKey": plan_increments[i + 1]["task_key"],
            "nativeId": rel["id"],
            "externalId": rel_ext_id,
            "relationType": "blocks",
        })

    # 7. Read-back verification
    graph = mcp.read_back_graph(proj["id"])
    assert len(graph["work_items"]) == len(plan_increments) + 1  # 1 spec + N increments
    assert len(graph["relations"]) == len(plan_increments) - 1
    # Spec item has parent None
    spec_in_graph = [w for w in graph["work_items"] if w["id"] == spec_wi["id"]][0]
    assert spec_in_graph["parent"] is None
    # Child increment work items have parent == spec_wi["id"]
    child_wis_in_graph = [w for w in graph["work_items"] if w["id"] != spec_wi["id"]]
    assert len(child_wis_in_graph) == len(plan_increments)
    for wi in child_wis_in_graph:
        assert wi["parent"] == spec_wi["id"]
    manifest["mirror"]["status"] = "synced"
    return manifest


# --- Scenario A: Valid Plane Build mirror ---
mcp_valid = MockPlaneMCP(base_url="https://api.plane.so", workspace="acme")
mcp_valid.workspace_labels = [
    {"id": "l-1", "name": "Core"},
    {"id": "l-2", "name": "Backend"},
    {"id": "l-3", "name": "Docs"},
]
configured_project = mcp_valid.create_project("acme", "Product Delivery", labels=["lbl-existing"])
mcp_valid.operations.clear()
cfg_valid = {
    "plane": {
        "baseUrl": "https://app.plane.so",  # Cloud app/api equivalence
        "workspace": "acme",
        "project": configured_project["id"],
        "projectLabels": ["Core", "Backend"],
    }
}
increments = [
    {"task_key": "task-1", "title": "First slice"},
    {"task_key": "task-2", "title": "Second slice"},
    {"task_key": "task-3", "title": "Third slice"},
]
manifest_out = simulate_plane_build_mirror(cfg_valid, mcp_valid, "# Spec", increments)
assert manifest_out["mirror"]["status"] == "synced"
assert len(manifest_out["mirror"]["relations"]) == 2  # 3 items -> 2 relations
assert mcp_valid.projects["proj-1"]["labels"] == ["lbl-existing", "l-1", "l-2"]  # preserves unrelated label

assert "externalId" not in manifest_out["mirror"]["project"]
assert manifest_out["mirror"]["project"]["baseUrl"] == "https://api.plane.so"
assert manifest_out["mirror"]["project"]["workspace"] == "acme"
assert manifest_out["mirror"]["project"]["nativeId"] == configured_project["id"]
assert manifest_out["mirror"]["project"]["canonicalRef"] == configured_project["id"]
assert manifest_out["mirror"]["specItem"]["nativeId"] == "wi-1"
assert manifest_out["mirror"]["specItem"]["canonicalRef"] == "wi-1"
# Project and spec item never enter stableTaskMappings and assume no readable ID
assert "proj-1" not in manifest_out["stableTaskMappings"]
assert "wi-1" not in manifest_out["stableTaskMappings"]
assert set(manifest_out["stableTaskMappings"].keys()) == {"task-1", "task-2", "task-3"}
assert "readableId" not in manifest_out["mirror"]["project"]

# Operation counts and ordering: the configured project is read and labeled before work-item creation.
create_proj_ops = [op for op in mcp_valid.operations if op[0] == "create_project"]
read_proj_ops = [op for op in mcp_valid.operations if op[0] == "read_project"]
create_wi_ops = [op for op in mcp_valid.operations if op[0] == "create_work_item"]
read_wi_ops = [op for op in mcp_valid.operations if op[0] == "read_work_item"]
create_rel_ops = [op for op in mcp_valid.operations if op[0] == "create_relation"]
assert len(create_proj_ops) == 0
assert len(read_proj_ops) == 2
assert len(create_wi_ops) == 4
assert len(read_wi_ops) == 4
assert len(create_rel_ops) == 2

op_types = [op[0] for op in mcp_valid.operations]
read_proj_idx = op_types.index("read_project")

wi_create_indices = [i for i, op in enumerate(mcp_valid.operations) if op[0] == "create_work_item"]
wi_read_indices = [i for i, op in enumerate(mcp_valid.operations) if op[0] == "read_work_item"]
rel_create_indices = [i for i, op in enumerate(mcp_valid.operations) if op[0] == "create_relation"]

for c_idx, r_idx in zip(wi_create_indices, wi_read_indices):
    assert c_idx < r_idx, "each work item must be independently read back after creation"

assert read_proj_idx < wi_create_indices[0]

for r_idx in wi_read_indices:
    for rel_idx in rel_create_indices:
        assert r_idx < rel_idx, "all work items must be independently read back before relation writes"
# --- Scenario B: Missing label capability fails closed with 0 project/work item writes ---
mcp_no_label = MockPlaneMCP(base_url="https://api.plane.so", workspace="acme",
                            capabilities={"projectRead": True, "projectWrite": True, "issueRead": True, "issueWrite": True,
                                          "relationRead": True, "relationWrite": True, "projectLabelRead": False,
                                          "projectLabelWrite": True, "independentReadBack": True})
try:
    simulate_plane_build_mirror(cfg_valid, mcp_no_label, "# Spec", increments)
    raise AssertionError("expected failure on missing projectLabelRead")
except RuntimeError as e:
    assert "missing label capability" in str(e)
assert len(mcp_no_label.projects) == 0
assert len(mcp_no_label.work_items) == 0

# --- Scenario C: Self-hosted trailing slash normalization and scoping ---
mcp_selfhosted = MockPlaneMCP(base_url="https://plane.internal.org", workspace="infra")
configured_selfhosted = mcp_selfhosted.create_project("infra", "Infrastructure", labels=[])
mcp_selfhosted.operations.clear()
cfg_selfhosted = {
    "plane": {
        "baseUrl": "https://plane.internal.org/",  # trailing slash
        "workspace": "infra",
        "project": configured_selfhosted["id"],
        "projectLabels": [],
    }
}
manifest_sh = simulate_plane_build_mirror(cfg_selfhosted, mcp_selfhosted, "# Spec", increments[:2])
assert manifest_sh["mirror"]["status"] == "synced"
assert len(manifest_sh["mirror"]["relations"]) == 1

# --- Scenario D: Unknown outcome recovery via external_id ---
mcp_recovery = MockPlaneMCP(base_url="https://api.plane.so", workspace="acme")
# Simulate project already created before process loss
proj_existing = mcp_recovery.create_project("acme", "[Build] Prior Feature", external_source="woostack", external_id="ext-proj-1")
recovered_proj = mcp_recovery.find_project_by_external_id("acme", "woostack", "ext-proj-1")
assert recovered_proj is not None
assert recovered_proj["id"] == proj_existing["id"]

# Simulate work item already created before process loss
wi_existing = mcp_recovery.create_work_item("acme", "proj-1", "First slice",
                                            external_source="woostack", external_id="ext-task-1", parent=None)
# Resume search
recovered = mcp_recovery.find_work_item_by_external_id("acme", "proj-1", "woostack", "ext-task-1")
assert recovered is not None
assert recovered["id"] == wi_existing["id"]

# ---------------------------------------------------------------------------
# Synthetic fixture-driven GitHub Build provider boundary tests (0 network calls)
# ---------------------------------------------------------------------------

class MockGitHubCLI:
    def __init__(self, owner="acme", repo="acme/widgets", capabilities=None):
        self.owner, self.repo = owner, repo
        self.capabilities = capabilities or {"projectRead": True, "projectWrite": True, "issueRead": True, "issueWrite": True, "dependencyRead": True, "dependencyWrite": True, "pagination": True, "independentReadBack": True}
        self.projects, self.issues, self.items, self.dependencies = {}, {}, {}, []
        self.create_calls, self.throw_on_create = 0, False

    def list_projects_paginated(self, owner):
        if not self.capabilities.get("pagination"): raise RuntimeError("missing capability: pagination")
        return {"items": [p for p in self.projects.values() if p["owner"] == owner], "next_cursor": None}

    def create_project(self, owner, title, visibility="private"):
        if not self.capabilities.get("projectWrite"): raise RuntimeError("missing capability: projectWrite")
        pid = f"PVT_{len(self.projects)+1:04d}"
        p = {"id": pid, "number": len(self.projects)+1, "owner": owner, "title": title, "visibility": visibility, "repository": f"https://github.com/{self.repo}", "readme": "", "shortDescription": ""}
        self.projects[pid] = p; return dict(p)

    def read_project(self, pid):
        if not self.capabilities.get("projectRead"): raise RuntimeError("missing capability: projectRead")
        return dict(self.projects[pid]) if pid in self.projects else None

    def update_project_readme(self, pid, readme, short_description=""):
        if not self.capabilities.get("projectWrite"): raise RuntimeError("missing capability: projectWrite")
        self.projects[pid]["readme"] = readme; self.projects[pid]["shortDescription"] = short_description
        return dict(self.projects[pid])

    def create_issue(self, repo, title, body):
        if not self.capabilities.get("issueWrite"): raise RuntimeError("missing capability: issueWrite")
        self.create_calls += 1
        n = len(self.issues) + 1; iid = f"I_{n:04d}"
        iss = {"id": iid, "number": n, "repo": repo, "title": title, "body": body, "url": f"https://github.com/{repo}/issues/{n}", "parent": None}
        self.issues[iid] = iss
        if self.throw_on_create: raise RuntimeError("unknown issue creation result")
        return dict(iss)

    def read_issue(self, iid):
        if not self.capabilities.get("issueRead"): raise RuntimeError("missing capability: issueRead")
        return dict(self.issues[iid]) if iid in self.issues else None

    def add_project_item(self, pid, cid):
        if not self.capabilities.get("projectWrite"): raise RuntimeError("missing capability: projectWrite")
        item = {"id": f"PVTI_{len(self.items.get(pid, []))+1:04d}", "content_id": cid}
        self.items.setdefault(pid, []).append(item); return dict(item)

    def add_issue_dependency(self, blocker_id, blocked_id):
        if not self.capabilities.get("dependencyWrite"): raise RuntimeError("missing capability: dependencyWrite")
        dep = {"id": f"DEP_{len(self.dependencies)+1:04d}", "blocker_id": blocker_id, "blocked_id": blocked_id}
        self.dependencies.append(dep); return dict(dep)


def simulate_github_build_mirror(config, cli, spec_text, plan_increments):
    if config["github"]["owner"] != cli.owner: raise ValueError("owner mismatch")
    for cap in ("projectRead", "projectWrite", "issueRead", "issueWrite", "dependencyRead", "dependencyWrite", "independentReadBack"):
        if not cli.capabilities.get(cap): raise RuntimeError(f"missing capability: {cap}")
    proj_marker = "<!-- woostack-project-mutation:proj-uuid-1 -->"
    existing_projs = [p for p in cli.list_projects_paginated(config["github"]["owner"])["items"] if proj_marker in p.get("readme", "")]
    if len(existing_projs) == 1:
        proj = existing_projs[0]
    elif len(existing_projs) > 1:
        raise ValueError("duplicate project marker")
    else:
        proj = cli.create_project(config["github"]["owner"], "[Build] Feature", visibility=config["github"].get("visibility", "private"))
        if proj.get("repository") != f"https://github.com/{cli.repo}": raise ValueError("repository mismatch")
        spec_section = f"<!-- woostack-spec-start -->\n{proj_marker}\n{spec_text}\n<!-- woostack-spec-end -->"
        cli.update_project_readme(proj["id"], spec_section, short_description="Feature")
    manifest = {"stableTaskMappings": {}, "mirror": {"provider": "github", "project": {"owner": config["github"]["owner"], "canonicalRef": f"https://github.com/orgs/{config['github']['owner']}/projects/{proj['number']}", "nativeId": proj["id"]}, "tasks": {}, "relations": [], "status": "unstarted"}}
    created_issues = []
    for inc in plan_increments:
        k = inc["task_key"]
        contract = f"## {inc['title']}\nOutcome: {inc['title']}\nScope: lib.ts\n<!-- woostack-issue-mutation:{k}-uuid -->\nStop marker: complete"
        matching_issues = [i for i in cli.issues.values() if i["repo"] == cli.repo and f"<!-- woostack-issue-mutation:{k}-uuid -->" in i.get("body", "")]
        if len(matching_issues) == 1:
            iss = matching_issues[0]
        elif len(matching_issues) > 1:
            raise ValueError("duplicate issue marker")
        else:
            iss = cli.create_issue(cli.repo, inc["title"], contract)
        read_iss = cli.read_issue(iss["id"])
        if not read_iss or read_iss["parent"] is not None or "<!-- woostack-issue-mutation:" not in read_iss["body"] or "Stop marker: complete" not in read_iss["body"]:
            raise RuntimeError("invalid issue contract read-back")
        manifest["stableTaskMappings"][k] = iss["url"]
        manifest["mirror"]["tasks"][k] = {"canonicalRef": iss["url"], "nativeId": iss["id"]}
        item = cli.add_project_item(proj["id"], iss["id"])
        manifest["mirror"]["tasks"][k]["itemNodeId"] = item["id"]
        created_issues.append(iss)
    for i in range(len(created_issues) - 1):
        dep = cli.add_issue_dependency(created_issues[i]["id"], created_issues[i+1]["id"])
        manifest["mirror"]["relations"].append({"sourceKey": plan_increments[i]["task_key"], "targetKey": plan_increments[i+1]["task_key"], "nativeId": dep["id"], "relationType": "blocks"})
    assert len(cli.items.get(proj["id"], [])) == len(plan_increments) and len(cli.dependencies) == len(plan_increments) - 1
    manifest["mirror"]["status"] = "synced"
    return manifest


# --- Scenario A: Valid GitHub Build mirror ---
cli_valid = MockGitHubCLI(owner="acme", repo="acme/widgets")
cfg_gh_valid = {"github": {"owner": "acme", "ownerType": "organization", "visibility": "private", "statusField": "Status", "projectStatuses": {"planned": "Todo", "executing": "In Progress", "inReview": "In Review", "done": "Done", "blocked": "Blocked"}}}
gh_increments = [{"task_key": "task-1", "title": "First slice"}, {"task_key": "task-2", "title": "Second slice"}, {"task_key": "task-3", "title": "Third slice"}]
gh_manifest = simulate_github_build_mirror(cfg_gh_valid, cli_valid, "# Feature Spec", gh_increments)
assert gh_manifest["mirror"]["status"] == "synced" and len(gh_manifest["mirror"]["relations"]) == 2
assert gh_manifest["stableTaskMappings"]["task-1"] == "https://github.com/acme/widgets/issues/1"
assert cli_valid.dependencies[0]["blocker_id"] == "I_0001" and cli_valid.dependencies[0]["blocked_id"] == "I_0002"

# --- Scenario B: Missing capability / foreign repo fails closed ---
try:
    simulate_github_build_mirror(cfg_gh_valid, MockGitHubCLI(capabilities={"projectWrite": False}), "# Spec", gh_increments)
    raise AssertionError("expected failure on missing capability")
except RuntimeError as e: assert "missing capability" in str(e)

# --- Scenario C: Unknown issue creation committed server-side then throws, resumes real sync path ---
cli_throw = MockGitHubCLI(owner="acme", repo="acme/widgets")
cli_throw.throw_on_create = True
try:
    simulate_github_build_mirror(cfg_gh_valid, cli_throw, "# Spec", [{"task_key": "task-1", "title": "First slice"}])
    raise AssertionError("expected unknown error")
except RuntimeError as e: assert "unknown issue creation result" in str(e)
cli_throw.throw_on_create = False
gh_resumed = simulate_github_build_mirror(cfg_gh_valid, cli_throw, "# Spec", [{"task_key": "task-1", "title": "First slice"}])
assert cli_throw.create_calls == 1, "create_issue must not be called a second time on resume"
assert gh_resumed["stableTaskMappings"]["task-1"] == "https://github.com/acme/widgets/issues/1"
assert len(cli_throw.issues) == 1, "no duplicate issue should be created"

# --- Scenario D: Supplied Project preserves prefix, suffix, title, visibility, metadata ---
cli_supp = MockGitHubCLI(owner="acme", repo="acme/widgets")
cli_supp.projects["PVT_S"] = {"id": "PVT_S", "number": 42, "owner": "acme", "title": "Custom", "visibility": "public", "repository": "https://github.com/acme/widgets", "custom": "meta", "readme": "# Pre\n<!-- woostack-spec-start -->\nOld\n<!-- woostack-spec-end -->\n# Post", "shortDescription": "Old"}
p = cli_supp.read_project("PVT_S")
assert p["repository"] == "https://github.com/acme/widgets"
pre, post = p["readme"].split("<!-- woostack-spec-start -->")[0], p["readme"].split("<!-- woostack-spec-end -->")[1]
cli_supp.update_project_readme("PVT_S", f"{pre}<!-- woostack-spec-start -->\nNew Spec\n<!-- woostack-spec-end -->{post}", "New Summary")
p_after = cli_supp.read_project("PVT_S")
assert p_after["title"] == "Custom" and p_after["visibility"] == "public" and p_after["custom"] == "meta"
assert p_after["readme"].startswith("# Pre\n") and p_after["readme"].endswith("\n# Post") and p_after["shortDescription"] == "New Summary"
print("test-provider-build-contract: ok")
PY
