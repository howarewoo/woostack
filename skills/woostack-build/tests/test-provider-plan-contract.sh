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
    "`--project` is mandatory",
    "exact existing Linear or Plane project",
    "never creates or selects an implicit project",
    "one complete specification",
    "Never create a parent, container, checklist, layer, or plan issue",
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
    "Independently read every project, issue",
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
    def __init__(self, base_url="https://api.plane.so", workspace="acme"):
        self.base_url = base_url
        self.workspace = workspace
        self.projects = {
            "11111111-2222-3333-4444-555555555555": {
                "id": "11111111-2222-3333-4444-555555555555",
                "name": "Platform Core",
                "workspace": "acme",
                "repository": "https://github.com/acme/widgets",
            }
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
        self.operations.append(("create_work_item", project_id, title, external_id))
        if parent is not None:
            raise ValueError("parent must be null")
        wi_id = f"wi-{len(self.work_items) + 1}"
        wi = {"id": wi_id, "project_id": project_id, "title": title, "parent": None, "external_id": external_id}
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
    if not project_arg:
        raise ValueError("--project is mandatory for standalone Plan")

    # 1. Resolve exact project
    proj = mcp.resolve_project(project_arg)

    # 2. Check complete pagination on existing items
    existing_page = mcp.list_work_items_paginated(proj["id"], simulate_incomplete=simulate_incomplete_pagination)
    if existing_page.get("next_cursor") is not None:
        raise RuntimeError("incomplete pagination: terminal cursor not null")

    # 3. Create N parentless work items
    created = []
    for idx, item in enumerate(plan_items, start=1):
        ext_id = f"plan-ext-{idx}"
        wi = mcp.create_work_item(proj["id"], item["title"], parent=None, external_id=ext_id)
        created.append(wi)

    # 4. Create N-1 strict blocking relations: ordinal k-1 blocks ordinal k
    for k in range(len(created) - 1):
        blocker = created[k]
        blocked = created[k + 1]
        mcp.create_blocking_relation(proj["id"], blocker["id"], blocked["id"], external_id=f"rel-plan-ext-{k}")

    # 5. Read-back verification
    assert len(created) == len(plan_items)
    assert len(mcp.relations) == len(plan_items) - 1
    for wi in created:
        assert wi["parent"] is None
    for rel in mcp.relations:
        assert rel["blocker"] != rel["blocked"]

    return {"project": proj, "work_items": created, "relations": mcp.relations}


# --- Plan Test 1: Successful Standalone Plan on Plane ---
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
assert len(result["work_items"]) == 4
assert len(result["relations"]) == 3
# Verify direction: item 0 blocks item 1, item 1 blocks item 2, item 2 blocks item 3
assert result["relations"][0]["blocker"] == result["work_items"][0]["id"]
assert result["relations"][0]["blocked"] == result["work_items"][1]["id"]
assert result["relations"][1]["blocker"] == result["work_items"][1]["id"]
assert result["relations"][1]["blocked"] == result["work_items"][2]["id"]
assert result["relations"][2]["blocker"] == result["work_items"][2]["id"]
assert result["relations"][2]["blocked"] == result["work_items"][3]["id"]

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

print("test-provider-plan-contract: ok")
PY
