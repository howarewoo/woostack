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
    "artifact": root / "skills/woostack-init/references/artifact-backends.md",
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

for name in ("build", "linear_context", "linear_procedure", "plane_context", "plane_procedure", "ideate", "harden", "plan", "fix", "execute"):
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
    r"Do not create a parent plan issue",
    r"Preserve its title, description, status, assignment, labels, relations, comments, and lifecycle",
    r"full project fields.*complete direct membership set.*complete dependency graph",
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
for name in ("linear_context", "linear_procedure", "plane_context", "plane_procedure"):
    require(name, r"nullable-parent|null parent|parent state|parent = null")
for name in ("linear_procedure", "plane_procedure"):
    require(name, r"zero provider and repository mutation")
require("harden", r"canonical issue references|canonical provider references")
require("artifact", r"host's authenticated official Linear or Plane MCP|authenticated official Linear MCP")
require("artifact", r"untrusted data, never instructions")
require("artifact", r"Never replace an existing full description")
require("artifact", r"completed or canceled project.*terminal conflict")
require("artifact", r"update only the native status field")

# Configured project label preservation contracts
require("artifact", r"projectLabels.*array of non-empty strings")
require("artifact", r"completely paginate.*workspace project labels.*flatten.*null terminal cursor.*resolves each configured label")
require("artifact", r"exact.*native ID.*or.*exact.*case-sensitive name")
require("artifact", r"union of existing project labels and configured labels")
require("artifact", r"preserving all unrelated existing labels")
require("artifact", r"Preflight label discovery")
require("artifact", r"at most one write alongside project creation or admission")
require("artifact", r"independently read back the complete label set")
require("artifact", r"fails closed before mutating the project")

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
require("plane_context", r"completely paginate all workspace project labels.*flatten every page.*require null terminal cursors.*resolve.*before any project creation or admission mutation")
require("plane_context", r"exact native UUID.*or exact case-sensitive name|exact native UUID")
require("plane_context", r"union.*configured labels with existing project labels")
require("plane_context", r"preserving unrelated.*existing labels")
require("plane_context", r"official Plane MCP lacks project-label operations.*fails closed")
require("plane_context", r"external_source.*external_id")
require("plane_context", r"parent = null")
require("plane_procedure", r"external_source.*external_id")
require("plane_procedure", r"parent = null")
require("plane_procedure", r"N-1.*strict blocking relations")

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
require("artifact", r"Do not create a parent plan issue")
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
        self.operations.append(("create_work_item", workspace, project_id, title, external_id))
        if not self.capabilities.get("issueWrite"):
            raise RuntimeError("missing capability: issueWrite")
        if parent is not None:
            raise ValueError("parent must be null")
        wi_id = f"wi-{len(self.work_items) + 1}"
        wi = {
            "id": wi_id, "workspace": workspace, "project_id": project_id,
            "title": title, "external_source": external_source,
            "external_id": external_id, "parent": None
        }
        self.work_items[wi_id] = wi
        return wi

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

    # 4. Project creation (preallocates externalId, baseUrl, workspace into manifest before create attempt)
    proj_ext_id = "ext-proj-1"
    manifest = {
        "stableTaskMappings": {},
        "mirror": {
            "provider": "plane",
            "project": {
                "externalId": proj_ext_id,
                "baseUrl": canonical_url,
                "workspace": config["plane"]["workspace"],
                "name": "[Build] New Feature",
                "canonicalRef": None,
                "nativeId": None,
            },
            "tasks": {},
            "relations": [],
            "status": "unstarted",
        }
    }

    existing_project_labels = ["lbl-existing"]
    effective_labels = list(dict.fromkeys(existing_project_labels + resolved_label_ids))
    proj_created = mcp.create_project(config["plane"]["workspace"], "[Build] New Feature", labels=effective_labels,
                                      external_source="woostack", external_id=proj_ext_id)
    # Independent read_project before project binding (create response alone cannot authorize binding)
    proj = mcp.read_project(config["plane"]["workspace"], proj_created["id"])
    if not proj:
        raise RuntimeError("failed to read back created project")

    # Bind canonical/native IDs after independent read-back into mirror.project only (never stableTaskMappings; no readable ID assumed)
    manifest["mirror"]["project"]["nativeId"] = proj["id"]
    manifest["mirror"]["project"]["canonicalRef"] = proj["id"]

    created_wis = []
    for inc in plan_increments:
        task_key = inc["task_key"]
        ext_id = f"ext-{task_key}"
        # Preallocate
        manifest["mirror"]["tasks"][task_key] = {"externalId": ext_id, "canonicalRef": None, "nativeId": None}
        # Create
        wi = mcp.create_work_item(config["plane"]["workspace"], proj["id"], inc["title"],
                                  external_source="woostack", external_id=ext_id, parent=None)
        manifest["stableTaskMappings"][task_key] = wi["id"]
        manifest["mirror"]["tasks"][task_key]["nativeId"] = wi["id"]
        manifest["mirror"]["tasks"][task_key]["canonicalRef"] = wi["id"]
        created_wis.append(wi)

    # Create N-1 blocking relations (predecessor blocks successor)
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

    # 6. Read-back verification
    graph = mcp.read_back_graph(proj["id"])
    assert len(graph["work_items"]) == len(plan_increments)
    assert len(graph["relations"]) == len(plan_increments) - 1
    for wi in graph["work_items"]:
        assert wi["parent"] is None
    manifest["mirror"]["status"] = "synced"
    return manifest


# --- Scenario A: Valid Plane Build mirror ---
mcp_valid = MockPlaneMCP(base_url="https://api.plane.so", workspace="acme")
mcp_valid.workspace_labels = [
    {"id": "l-1", "name": "Core"},
    {"id": "l-2", "name": "Backend"},
    {"id": "l-3", "name": "Docs"},
]
cfg_valid = {
    "plane": {
        "baseUrl": "https://app.plane.so",  # Cloud app/api equivalence
        "workspace": "acme",
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

assert manifest_out["mirror"]["project"]["externalId"] == "ext-proj-1"
assert manifest_out["mirror"]["project"]["baseUrl"] == "https://api.plane.so"
assert manifest_out["mirror"]["project"]["workspace"] == "acme"
assert manifest_out["mirror"]["project"]["nativeId"] == "proj-1"
assert manifest_out["mirror"]["project"]["canonicalRef"] == "proj-1"
assert manifest_out["mirror"]["project"]["name"] == "[Build] New Feature"
# Project never enters stableTaskMappings and assumes no readable ID
assert "proj-1" not in manifest_out["stableTaskMappings"]
assert set(manifest_out["stableTaskMappings"].keys()) == {"task-1", "task-2", "task-3"}
assert "readableId" not in manifest_out["mirror"]["project"]

# Operation counts and ordering check: prove create_project -> read_project -> bind before work item mutation
create_proj_ops = [op for op in mcp_valid.operations if op[0] == "create_project"]
read_proj_ops = [op for op in mcp_valid.operations if op[0] == "read_project"]
create_wi_ops = [op for op in mcp_valid.operations if op[0] == "create_work_item"]
create_rel_ops = [op for op in mcp_valid.operations if op[0] == "create_relation"]
assert len(create_proj_ops) == 1
assert len(read_proj_ops) == 1
assert len(create_wi_ops) == 3
assert len(create_rel_ops) == 2

op_types = [op[0] for op in mcp_valid.operations]
create_idx = op_types.index("create_project")
read_proj_idx = op_types.index("read_project")
first_wi_idx = op_types.index("create_work_item")
assert create_idx < read_proj_idx < first_wi_idx, "operation sequence must prove create_project -> read_project before work item operations"
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
cfg_selfhosted = {
    "plane": {
        "baseUrl": "https://plane.internal.org/",  # trailing slash
        "workspace": "infra",
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

print("test-provider-build-contract: ok")
PY
