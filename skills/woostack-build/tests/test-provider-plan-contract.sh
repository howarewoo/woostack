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
    "For standalone Linear or GitHub use, `--project` is mandatory",
    "For standalone Plane use, `--project` is optional",
    "exact `artifacts.plane.project`",
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
    "GitHub",
    "parentless repository issue",
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
        self.configured_project = "11111111-2222-3333-4444-555555555555"
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

    # 1. Resolve the exact configured project; an explicit --project must match it.
    canonical_repo_url = f"https://github.com/{mcp.repo}"
    configured = mcp.resolve_project(mcp.configured_project)
    if configured.get("repository") != canonical_repo_url:
        raise ValueError("configured project repository does not match policy")
    if project_arg:
        supplied = mcp.resolve_project(project_arg)
        if supplied["id"] != configured["id"]:
            raise ValueError(f"mismatched project: configured {configured['id']}, got {supplied['id']}")
    proj = mcp.read_project(mcp.workspace, configured["id"])
    if not proj:
        raise RuntimeError("failed to read back configured project")
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

# --- Plan Test 1b: Omitted --project uses artifacts.plane.project ---
mcp_plan_default = MockPlanePlanMCP(base_url="https://api.plane.so", workspace="acme")
result_default = simulate_standalone_plan_plane(
    "plane",
    None,
    mcp_plan_default,
    items,
)
assert result_default["project"]["id"] == mcp_plan_default.configured_project
assert result_default["spec_item"]["parent"] is None
assert len(result_default["work_items"]) == 4
assert len(result_default["relations"]) == 3
for wi in result_default["work_items"]:
    assert wi["parent"] == result_default["spec_item"]["id"]
# --- Plan Test 1c: Missing configured project fails closed without creation ---
mcp_plan_empty = MockPlanePlanMCP(base_url="https://api.plane.so", workspace="acme")
mcp_plan_empty.projects = {}
try:
    simulate_standalone_plan_plane("plane", None, mcp_plan_empty, items)
    raise AssertionError("expected configured project resolution failure")
except ValueError as e:
    assert "unknown project" in str(e)
assert not any(op[0] == "create_project" for op in mcp_plan_empty.operations)
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


# ---------------------------------------------------------------------------
# Synthetic fixture-driven GitHub Plan provider boundary tests (0 network calls)
# ---------------------------------------------------------------------------

class MockGitHubPlanCLI:
    def __init__(self, owner="acme", repo="acme/widgets"):
        self.owner, self.repo = owner, repo
        self.projects = {1: {"id": "PVT_0001", "number": 1, "owner": "acme", "title": "Roadmap", "readme": "", "shortDescription": "", "repository": f"https://github.com/{repo}"}, 2: {"id": "PVT_0002", "number": 2, "owner": "acme", "title": "Foreign", "readme": "", "shortDescription": "", "repository": "https://github.com/foreign/repo"}}
        self.issues, self.items, self.dependencies = {}, {}, []

    def resolve_project_url(self, url):
        m = re.match(r"^https://github\.com/(orgs|users)/([^/]+)/projects/(\d+)$", url)
        if not m: raise ValueError(f"malformed canonical GitHub Project URL: {url}")
        if m.group(2) != self.owner: raise ValueError(f"owner mismatch: {m.group(2)} != {self.owner}")
        num = int(m.group(3))
        if num not in self.projects: raise ValueError(f"unknown Project number: {num}")
        p = self.projects[num]
        if p.get("repository") != f"https://github.com/{self.repo}": raise ValueError("repository mismatch")
        return dict(p)

    def update_project_readme(self, pid, readme, short_description=""):
        self.projects[1]["readme"] = readme; self.projects[1]["shortDescription"] = short_description

    def create_issue(self, repo, title, body):
        n = len(self.issues) + 1; iid = f"I_{n:04d}"
        iss = {"id": iid, "number": n, "repo": repo, "title": title, "body": body, "url": f"https://github.com/{repo}/issues/{n}", "parent": None}
        self.issues[iid] = iss; return dict(iss)

    def add_project_item(self, pid, cid):
        item = {"id": f"PVTI_{len(self.items)+1:04d}", "content_id": cid}
        self.items.setdefault(pid, []).append(item); return dict(item)

    def add_issue_dependency(self, blocker_id, blocked_id):
        dep = {"id": f"DEP_{len(self.dependencies)+1:04d}", "blocker_id": blocker_id, "blocked_id": blocked_id}
        self.dependencies.append(dep); return dict(dep)


def simulate_standalone_plan_github(provider, project_arg, cli, plan_items):
    if provider != "github": raise ValueError("provider must be github")
    if not project_arg: raise ValueError("requires mandatory --project")
    proj = cli.resolve_project_url(project_arg)
    cli.update_project_readme(proj["id"], "<!-- woostack-spec-start -->\n# Spec\n<!-- woostack-spec-end -->", short_description="Plan summary")
    created = []
    for idx, item in enumerate(plan_items):
        contract = f"## {item['title']}\nOutcome: {item['title']}\nScope: lib.ts\n<!-- woostack-issue-mutation:plan-{idx}-uuid -->\nStop marker: complete"
        iss = cli.create_issue(cli.repo, item["title"], contract)
        if iss["parent"] is not None or "<!-- woostack-issue-mutation:" not in iss["body"] or "Stop marker: complete" not in iss["body"]:
            raise RuntimeError("invalid issue contract")
        cli.add_project_item(proj["id"], iss["id"])
        created.append(iss)
    for k in range(len(created) - 1):
        cli.add_issue_dependency(created[k]["id"], created[k+1]["id"])
    assert len(created) == len(plan_items) and len(cli.dependencies) == len(plan_items) - 1
    return {"project": proj, "issues": created, "dependencies": cli.dependencies}


# --- GitHub Plan Tests ---
cli_plan = MockGitHubPlanCLI(owner="acme", repo="acme/widgets")
gh_items = [{"title": "Increment 1: Setup"}, {"title": "Increment 2: Core"}, {"title": "Increment 3: Polish"}]
gh_plan_res = simulate_standalone_plan_github("github", "https://github.com/orgs/acme/projects/1", cli_plan, gh_items)
assert gh_plan_res["project"]["number"] == 1 and len(gh_plan_res["issues"]) == 3 and len(gh_plan_res["dependencies"]) == 2
assert gh_plan_res["dependencies"][0]["blocker_id"] == "I_0001" and gh_plan_res["dependencies"][0]["blocked_id"] == "I_0002"
assert cli_plan.projects[1]["shortDescription"] == "Plan summary"

for bad_url, err in [(None, "requires mandatory --project"), ("https://github.com/not-a-project", "malformed canonical GitHub Project URL"), ("https://github.com/orgs/foreign/projects/1", "owner mismatch"), ("https://github.com/orgs/acme/projects/2", "repository mismatch")]:
    try:
        simulate_standalone_plan_github("github", bad_url, cli_plan, gh_items)
        raise AssertionError(f"expected failure for {bad_url}")
    except ValueError as e: assert err in str(e)
print("test-provider-plan-contract: ok")
PY
