#!/usr/bin/env bash
# Structural contract for strict sequential direct-issue planning with Linear and Plane.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re
import sys
from pathlib import Path

plan = (Path(sys.argv[1]) / "skills/woostack-plan/SKILL.md").read_text(encoding="utf-8")
text = re.sub(r"\s+", " ", plan)
failures = []


def require(needle):
    if needle not in text:
        failures.append(f"plan: missing {needle!r}")


def forbid(pattern):
    if re.search(pattern, text, re.I):
        failures.append(f"plan: matches forbidden pattern {pattern!r}")

for needle in (
    "For standalone Linear use, `--project` is mandatory",
    "For standalone Plane use, `--project` is optional",
    "canonical `[Repo] owner/name` repository project",
    "one complete specification",
    "Never create extra container, checklist, layer, or synthetic issues",
    "stable task ID, unique positive ordinal",
    "exactly one intended PR",
    "exact scope and explicit non-goals",
    "exact files and symbols, or one bounded first discovery step",
    "ordered, concrete implementation steps",
    "observable acceptance criteria, each mapped to an implementation step",
    "focused checks and one executable smoke scenario",
    "cross-increment effects",
    "risks and active blockers",
    "explicit stop marker",
    "declared Graphite parent",
    "500 or fewer hand-written changed lines",
    "Generated files and lockfiles may exceed",
    "explicitly approved deletion-only PR",
    "strict sequential chain",
    "positive integers `1..N`",
    "ordinal k (2..N): ordinal k-1 → ordinal k",
    "exactly the matching predecessor edge",
    "Independently read every project",
    "Delegated planning performs no provider read or mutation",
    "atomically records complete candidate contracts",
    "displays every concise stable task and dependency mapping",
    "executor-ready removal-before-addition analysis",
    "safe deletion or simplification opportunities first",
    "Standalone Plan",
    "synchronization is unchanged",
    "owns no implementation, source edit, commit, branch, PR, review, merge",
    "Plane",
    "Linear",
):
    require(needle)
for pattern in (
    r"artifact-free",
    r"conversational-only",
    r"may create (?:a |an )?(?:new |implicit )?project",
    r"parallel(?:izable)? roots?",
    r"general DAG",
    r"one project, one parent plan issue",
):
    forbid(pattern)

if failures:
    print("strict sequential Plan contract violations:", file=sys.stderr)
    for failure in failures:
        print(f"  - {failure}", file=sys.stderr)
    raise SystemExit(1)

# ---------------------------------------------------------------------------
# Synthetic fixture-driven Plane Plan provider boundary tests (0 network calls)
# ---------------------------------------------------------------------------

def canonicalize_plane_url(url: str) -> str:
    url = re.sub(r"/+$", "", url)
    if re.match(r"^https?://(api|app)\.plane\.so$", url, re.I):
        return "https://api.plane.so"
    return url

class MockPlanePlanMCP:
    def __init__(self, base_url="https://api.plane.so", workspace="acme", repo="acme/widgets"):
        self.base_url = base_url
        self.workspace = workspace
        self.repo = repo
        self.projects = {
            "11111111-2222-3333-4444-555555555555": {
                "id": "11111111-2222-3333-4444-555555555555",
                "name": f"[Repo] {repo}",
                "workspace": "acme",
                "repository": f"https://github.com/{repo}",
            },
            "22222222-2222-3333-4444-555555555555": {
                "id": "22222222-2222-3333-4444-555555555555",
                "name": "Different Roadmap",
                "workspace": "acme",
                "repository": "https://github.com/acme/other-repo",
            },
        }
        self.readable_id_map = {
            "ENG-42": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
        }
        self.work_items = {}
        self.relations = []
        self.operations = []

    def resolve_project(self, project_arg):
        self.operations.append(("resolve_project", project_arg))
        # Handle URL or bare UUID
        if project_arg.startswith("http://") or project_arg.startswith("https://"):
            m = re.match(r"^(https?://[^/]+)/([^/]+)/projects/([0-9a-fA-F-]{36})$", project_arg)
            if not m:
                raise ValueError(f"malformed Plane project URL: {project_arg}")
            raw_base, workspace, proj_id = m.group(1), m.group(2), m.group(3)
            canonical_base = canonicalize_plane_url(raw_base)
            if canonical_base != self.base_url:
                raise ValueError(f"foreign host in project URL: {raw_base} != {self.base_url}")
            if workspace != self.workspace:
                raise ValueError(f"foreign workspace in project URL: {workspace} != {self.workspace}")
        elif re.match(r"^[0-9a-fA-F-]{36}$", project_arg):
            proj_id = project_arg
        else:
            raise ValueError(f"invalid project argument: {project_arg}")

        if proj_id in self.projects:
            proj = self.projects[proj_id]
            if proj.get("workspace") != self.workspace:
                raise ValueError(f"project workspace mismatch: {proj.get('workspace')} != {self.workspace}")
            return proj
        raise ValueError(f"unknown project: {project_arg}")

    def create_project(self, workspace, name, repository, external_source="woostack", external_id=None):
        self.operations.append(("create_project", workspace, name, repository, external_id))
        proj_id = f"proj-{len(self.projects) + 1}"
        proj = {
            "id": proj_id,
            "name": name,
            "workspace": workspace,
            "repository": repository,
            "external_source": external_source,
            "external_id": external_id,
        }
        self.projects[proj_id] = proj
        return proj

    def read_project(self, workspace, project_id):
        self.operations.append(("read_project", workspace, project_id))
        proj = self.projects.get(project_id)
        if not proj or proj.get("workspace") != workspace:
            return None
        return dict(proj)

    def list_projects_paginated(self, workspace, cursor=None):
        self.operations.append(("list_projects", workspace, cursor))
        items = [p for p in self.projects.values() if p.get("workspace") == workspace]
        return {"items": items, "next_cursor": None}

    def resolve_work_item_ref(self, ref):
        self.operations.append(("resolve_work_item_ref", ref))
        if ref in self.readable_id_map:
            return self.readable_id_map[ref]
        if re.match(r"^[0-9a-fA-F-]{36}$", ref):
            return ref
        raise ValueError(f"unresolved work item reference: {ref}")

    def list_work_items_paginated(self, project_id, cursor=None, simulate_incomplete=False):
        self.operations.append(("list_work_items", project_id, cursor))
        items = [wi for wi in self.work_items.values() if wi["project_id"] == project_id]
        if simulate_incomplete:
            return {"items": items[:1], "next_cursor": "cursor-unresolved"}
        return {"items": items, "next_cursor": None}

    def create_work_item(self, project_id, title, parent=None, external_id=None):
        self.operations.append(("create_work_item", project_id, title, external_id, parent))
        wi_id = f"wi-{len(self.work_items) + 1}"
        wi = {"id": wi_id, "project_id": project_id, "title": title, "parent": parent, "external_id": external_id}
        self.work_items[wi_id] = wi
        return wi

    def create_blocking_relation(self, project_id, blocker_id, blocked_id, external_id=None):
        self.operations.append(("create_blocking_relation", blocker_id, blocked_id, external_id))
        rel_id = f"rel-{len(self.relations) + 1}"
        rel = {"id": rel_id, "project_id": project_id, "blocker": blocker_id, "blocked": blocked_id, "external_id": external_id}
        self.relations.append(rel)
        return rel


def simulate_standalone_plan_plane(provider, project_arg, mcp, plan_items, simulate_incomplete_pagination=False):
    if provider == "local" or not provider:
        raise ValueError("standalone Plan requires provider linear or plane")

    # 1. Resolve exact or default repository project
    canonical_name = f"[Repo] {mcp.repo}"
    canonical_repo_url = f"https://github.com/{mcp.repo}"
    if project_arg:
        proj = mcp.resolve_project(project_arg)
        if proj.get("name") != canonical_name or proj.get("repository") != canonical_repo_url:
            raise ValueError(f"mismatched project: expected {canonical_name} ({canonical_repo_url}), got {proj.get('name')} ({proj.get('repository')})")
    else:
        # Default to canonical repository project: complete pagination to discover existing project
        proj_page = mcp.list_projects_paginated(mcp.workspace)
        matching = [
            p for p in proj_page.get("items", [])
            if p.get("name") == canonical_name and p.get("repository") == canonical_repo_url
        ]
        if len(matching) == 1:
            proj = matching[0]
        elif len(matching) > 1:
            raise ValueError(f"ambiguous matching projects found for {canonical_name}")
        else:
            # Zero canonical match first-use path: create [Repo] owner/name with preallocated identity and independent read-back
            proj_ext_id = "plan-proj-ext-1"
            created_proj = mcp.create_project(
                mcp.workspace,
                canonical_name,
                canonical_repo_url,
                external_source="woostack",
                external_id=proj_ext_id,
            )
            # Independent read_project before use
            proj = mcp.read_project(mcp.workspace, created_proj["id"])
            if not proj:
                raise RuntimeError("failed to read back created canonical repository project")
    existing_page = mcp.list_work_items_paginated(proj["id"], simulate_incomplete=simulate_incomplete_pagination)
    if existing_page.get("next_cursor") is not None:
        raise RuntimeError("incomplete pagination: terminal cursor not null")

    # 3. Create top-level specification work item with parent = None
    spec_wi = mcp.create_work_item(proj["id"], "[Plan] Feature Plan", parent=None, external_id="plan-spec-ext-1")

    # 4. Create N child work items with parent = spec_wi["id"]
    created = []
    for idx, item in enumerate(plan_items, start=1):
        ext_id = f"plan-ext-{idx}"
        wi = mcp.create_work_item(proj["id"], item["title"], parent=spec_wi["id"], external_id=ext_id)
        created.append(wi)

    # 5. Create N-1 strict sibling blocking relations: ordinal k-1 blocks ordinal k
    for k in range(len(created) - 1):
        blocker = created[k]
        blocked = created[k + 1]
        mcp.create_blocking_relation(proj["id"], blocker["id"], blocked["id"], external_id=f"rel-plan-ext-{k}")

    # 6. Read-back verification
    assert len(created) == len(plan_items)
    assert len(mcp.relations) == len(plan_items) - 1
    assert spec_wi["parent"] is None
    for wi in created:
        assert wi["parent"] == spec_wi["id"]
    for rel in mcp.relations:
        assert rel["blocker"] != rel["blocked"]

    return {"project": proj, "spec_item": spec_wi, "work_items": created, "relations": mcp.relations}


# --- Plan Test 1: Successful Standalone Plan on Plane with explicit project ---
mcp_plan = MockPlanePlanMCP(base_url="https://api.plane.so", workspace="acme")
items = [
    {"title": "Increment 1: Setup"},
    {"title": "Increment 2: Core"},
    {"title": "Increment 3: Polish"},
    {"title": "Increment 4: Verification"},
]
result = simulate_standalone_plan_plane(
    "plane",
    "https://app.plane.so/acme/projects/11111111-2222-3333-4444-555555555555",
    mcp_plan,
    items,
)
assert result["project"]["name"] == "[Repo] acme/widgets"
assert result["spec_item"]["parent"] is None
assert len(result["work_items"]) == 4
assert len(result["relations"]) == 3
for wi in result["work_items"]:
    assert wi["parent"] == result["spec_item"]["id"]
# Verify direction: item 0 blocks item 1, item 1 blocks item 2, item 2 blocks item 3
assert result["relations"][0]["blocker"] == result["work_items"][0]["id"]
assert result["relations"][0]["blocked"] == result["work_items"][1]["id"]
assert result["relations"][1]["blocker"] == result["work_items"][1]["id"]
assert result["relations"][1]["blocked"] == result["work_items"][2]["id"]
assert result["relations"][2]["blocker"] == result["work_items"][2]["id"]
assert result["relations"][2]["blocked"] == result["work_items"][3]["id"]

# --- Plan Test 1b: Successful Standalone Plan on Plane with omitted --project (defaults to canonical repo project) ---
mcp_plan_default = MockPlanePlanMCP(base_url="https://api.plane.so", workspace="acme")
result_default = simulate_standalone_plan_plane(
    "plane",
    None,
    mcp_plan_default,
    items,
)
assert result_default["project"]["name"] == "[Repo] acme/widgets"
assert result_default["spec_item"]["parent"] is None
assert len(result_default["work_items"]) == 4
assert len(result_default["relations"]) == 3
for wi in result_default["work_items"]:
    assert wi["parent"] == result_default["spec_item"]["id"]
# --- Plan Test 1c: Successful Standalone Plan on Plane with empty project set (first-use project creation) ---
mcp_plan_empty = MockPlanePlanMCP(base_url="https://api.plane.so", workspace="acme")
mcp_plan_empty.projects = {}  # Empty workspace projects
result_empty = simulate_standalone_plan_plane(
    "plane",
    None,
    mcp_plan_empty,
    items,
)
assert result_empty["project"]["name"] == "[Repo] acme/widgets"
assert result_empty["project"]["repository"] == "https://github.com/acme/widgets"
assert result_empty["project"]["external_id"] == "plan-proj-ext-1"
assert result_empty["spec_item"]["parent"] is None
assert len(result_empty["work_items"]) == 4
assert len(result_empty["relations"]) == 3
for wi in result_empty["work_items"]:
    assert wi["parent"] == result_empty["spec_item"]["id"]

# Verify create_project -> read_project ordering before any work item creation
op_types_empty = [op[0] for op in mcp_plan_empty.operations]
proj_create_idx = op_types_empty.index("create_project")
proj_read_idx = op_types_empty.index("read_project")
first_wi_create_idx = op_types_empty.index("create_work_item")
assert proj_create_idx < proj_read_idx < first_wi_create_idx, "first-use project creation must prove create_project -> read_project before work item operations"
# --- Plan Test 2: Incomplete pagination fails closed ---
try:
    simulate_standalone_plan_plane(
        "plane",
        "11111111-2222-3333-4444-555555555555",
        mcp_plan,
        items,
        simulate_incomplete_pagination=True,
    )
    raise AssertionError("expected incomplete pagination failure")
except RuntimeError as e:
    assert "incomplete pagination" in str(e)

# --- Plan Test 3: Local provider fails closed ---
try:
    simulate_standalone_plan_plane("local", "11111111-2222-3333-4444-555555555555", mcp_plan, items)
    raise AssertionError("expected local provider failure")
except ValueError as e:
    assert "requires provider linear or plane" in str(e)

# --- Plan Test 4: Readable ID resolution ---
resolved_uuid = mcp_plan.resolve_work_item_ref("ENG-42")
assert resolved_uuid == "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

# --- Plan Test 5: Foreign host in URL fails closed ---
try:
    simulate_standalone_plan_plane(
        "plane",
        "https://foreign.plane.so/acme/projects/11111111-2222-3333-4444-555555555555",
        mcp_plan,
        items,
    )
    raise AssertionError("expected foreign host failure")
except ValueError as e:
    assert "foreign host in project URL" in str(e)

# --- Plan Test 6: Foreign workspace in URL fails closed ---
try:
    simulate_standalone_plan_plane(
        "plane",
        "https://app.plane.so/foreign-workspace/projects/11111111-2222-3333-4444-555555555555",
        mcp_plan,
        items,
    )
    raise AssertionError("expected foreign workspace failure")
except ValueError as e:
    assert "foreign workspace in project URL" in str(e)

# --- Plan Test 7: Mismatched same-workspace project fails closed ---
try:
    simulate_standalone_plan_plane(
        "plane",
        "https://app.plane.so/acme/projects/22222222-2222-3333-4444-555555555555",
        mcp_plan,
        items,
    )
    raise AssertionError("expected mismatched project failure")
except ValueError as e:
    assert "mismatched project" in str(e)

print("test-provider-plan-contract: ok")
PY
