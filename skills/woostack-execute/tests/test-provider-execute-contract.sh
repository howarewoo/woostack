#!/usr/bin/env bash
# Structural and fixture-driven contract for provider-neutral execution (Linear, Plane, local run).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
paths = {
    "skill": root / "skills/woostack-execute/SKILL.md",
    "controller": root / "skills/woostack-execute/references/controller.md",
    "driver": root / "skills/woostack-execute/references/subagent-driver.md",
    "fix": root / "skills/woostack-fix/SKILL.md",
    "artifact": root / "skills/woostack-init/references/artifact-backends.md",
    "linear_profile": root / "skills/woostack-init/references/artifact-providers/linear.md",
    "plane_profile": root / "skills/woostack-init/references/artifact-providers/plane.md",
    "plane_procedure": root / "skills/woostack-build/references/plane-procedure.md",
    "repo_rules": root / "AGENTS.md",
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


# 1. Structural assertions on Execute, Controller, Driver, and Shared Artifacts
require("skill", r"`--project`, `--issue`, and `--run` are mutually exclusive; exactly one is required")
require("skill", r"lowest-ordinal unfinished (?:task or issue|issue or work item|task|entry)")
require("skill", r"stop marker")
require("skill", r"issue mode.*never advances siblings")
require("skill", r"configured fast-model subagent")
require("skill", r"one focused verification.*one small bounded spec-compliance validator")
require("skill", r"branch, commit, PR URL/head/base.*verification")
require("skill", r"clean exact worktree")
require("skill", r"never create a duplicate")
require("skill", r"stop at that verified open-PR boundary.*No user wording overrides")

require("controller", r"Execute accepts exactly one of `--project`, `--issue`, or `--run`")
require("controller", r"select lowest unfinished ordinal")
require("controller", r"immediate predecessor's complete delivery checkpoint")
require("controller", r"one worktree")
require("controller", r"fast-model subagent")
require("controller", r"bounded spec-compliance validator")
require("controller", r"Successful submission requires branch, commit, PR")
require("controller", r"fresh independent evidence")
require("controller", r"terminal repository mutation is Graphite PR submission or update.*never marks a PR ready.*auto-merge.*merge queue.*merges")

require("driver", r"configured fast-model subagent")
require("driver", r"prohibitions on changing scope, dependencies, records, provider state, source-control")

# Linear-specific and Plane-specific state mappings
require("linear_profile", r"artifacts\.linear.*issueStates.*executing.*inReview")
require("linear_profile", r"projectStatuses\.started")
require("controller", r"artifacts\.linear\.issueStates\.executing.*artifacts\.linear\.issueStates\.inReview")
require("controller", r"artifacts\.plane\.issueStates")
require("controller", r"artifacts\.linear\.projectStatuses\.started")

# Plane-specific state resolution: exact UUID or case-sensitive name, scoping, rejection, read-back, group semantics
require("plane_profile", r"issueStates\.executing.*inReview.*done.*blocked.*by exact native UUID or exact case-sensitive name")
require("plane_profile", r"canonical baseUrl/workspace/project scope")
require("plane_profile", r"Reject missing, ambiguous, duplicate, foreign-scope, or group-mismatched states")
require("plane_profile", r"Read back native ID, name, and group")
require("plane_profile", r"Allowable groups are")

require("controller", r"resolve.*configured `artifacts\.plane\.issueStates`.*executing, inReview, done, blocked.*by exact UUID or case-sensitive name in exact scope, validate allowable group semantics")
require("controller", r"canonical `baseUrl`, `workspace`, and `project` scope")
require("controller", r"reject missing, ambiguous, duplicate, foreign-scope, or group-mismatched states")
require("controller", r"independently read back native ID, name, and group")
require("controller", r"validate allowable group semantics")

require("plane_profile", r"issueStates\.executing.*inReview.*done.*blocked.*by exact native UUID or exact case-sensitive name")
require("plane_profile", r"reject missing, ambiguous, duplicate, foreign-scope, or group-mismatched states")
require("plane_profile", r"Read back native ID, name, and group")
require("plane_profile", r"Allowable groups are")

# Plane procedure reflects Execute support while delivery notes/comments/Commit writer remain deferred
require("plane_procedure", r"Plane delivery notes, comments, and Commit writer are unsupported in this increment")
require("plane_procedure", r"Execute supports work-item state transitions and delivery checkpoints")

# Plane project status immutability: never synthesize or mutate project status for Plane
require("skill", r"Unsupported project lifecycle is a required no-op")
require("controller", r"For Plane, project status is never mutated, synthesized, or gated; Execute mutates and reads back only configured work-item states")
require("plane_profile", r"Never mutate, synthesize, archive, or gate on Plane project status")

# Delivery checkpoints and mirror failure nonblocking separation
require("skill", r"persisted checkpoint.*teardown.*resume.*sibling")
require("controller", r"full delivery checkpoint.*teardown.*resume.*sibling")
require("skill", r"mirror writes are configured in local run mode, they are best effort only.*never invalidates, blocks, or overwrites")
require("controller", r"mirror writes are configured in local run mode, mirror writes are best effort only.*never invalidates, blocks, or overwrites")
require("artifact", r"Report repository delivery and mirror synchronization separately")

# Base change choices
require("artifact", r"If the current tip equals the planning tip, continue without a question")
require("artifact", r"If the same branch has a different tip, make zero mutations")
require("artifact", r"`Continue`.*`Revise spec/plan`.*`Stop`")
require("repo_rules", r"Merge authority is human-only.*never mark a PR ready.*auto-merge.*enqueue.*merge")

# Forbid obsolete constructs
source_names = tuple(paths)
for obsolete in (
    r"canonicalProjectSpecFingerprint",
    r"canonicalIncrementFingerprint",
    r"projectSpecApprovalRecord",
    r"executionPlanApprovalRecord",
    r"fingerprintVersion",
    r"providerPresentationCanonicalization",
    r"compatible[- ]advancement|compatible parent advancement",
    r"reaccept|re-accept",
):
    forbid(source_names, obsolete)

if failures:
    print("structural execute contract violations:", file=sys.stderr)
    print("\n".join(f"- {item}" for item in failures), file=sys.stderr)
    sys.exit(1)

print("execute structural contract: ok")

# ---------------------------------------------------------------------------
# Fixture-driven synthetic execution simulations (0 network calls)
# ---------------------------------------------------------------------------

class MockPlaneMCP:
    def __init__(self, base_url="https://api.plane.so", workspace="acme", capabilities=None):
        self.base_url = base_url
        self.workspace = workspace
        self.capabilities = capabilities or {
            "projectRead": True, "issueRead": True, "issueWrite": True,
            "relationRead": True, "stateRead": True, "independentReadBack": True
        }
        self.projects = {}
        self.work_items = {}
        self.states = {}  # key: (workspace, project_id, state_id) -> state dict
        self.relations = []
        self.state_mutations = []
        self.project_status_mutations = []
        self.checkpoint_writes = []

    def add_state(self, workspace, project_id, state_id, name, group):
        self.states[(workspace, project_id, state_id)] = {
            "id": state_id,
            "name": name,
            "group": group,
            "project_id": project_id,
            "workspace": workspace,
        }

    def resolve_state(self, workspace, project_id, state_id_or_name):
        if not self.capabilities.get("stateRead", True):
            raise RuntimeError("missing capability: stateRead")
        if workspace != self.workspace:
            raise ValueError(f"foreign workspace: {workspace} != {self.workspace}")
        
        matches = []
        for (ws, pid, sid), state in self.states.items():
            if ws == workspace and pid == project_id:
                # Match by exact UUID or exact case-sensitive name
                if state["id"] == state_id_or_name or state["name"] == state_id_or_name:
                    matches.append(state)
        
        if len(matches) == 0:
            raise ValueError(f"state not found in scope: {state_id_or_name}")
        if len(matches) > 1:
            raise ValueError(f"ambiguous state match: {state_id_or_name} matched {len(matches)} states")
        return dict(matches[0])

    def read_state(self, workspace, project_id, state_id):
        if not self.capabilities.get("independentReadBack", True):
            raise RuntimeError("missing capability: independentReadBack")
        if workspace != self.workspace:
            raise ValueError(f"foreign workspace: {workspace} != {self.workspace}")
        state = self.states.get((workspace, project_id, state_id))
        if not state:
            raise ValueError(f"state not found: {state_id}")
        return dict(state)

    def read_project(self, workspace, project_id):
        if not self.capabilities.get("projectRead"):
            raise RuntimeError("missing capability: projectRead")
        if workspace != self.workspace:
            raise ValueError(f"foreign workspace: {workspace}")
        return self.projects.get(project_id)

    def list_work_items(self, workspace, project_id):
        if not self.capabilities.get("issueRead"):
            raise RuntimeError("missing capability: issueRead")
        if workspace != self.workspace:
            raise ValueError(f"foreign workspace: {workspace}")
        return [dict(wi) for wi in self.work_items.values() if wi.get("project_id") == project_id]

    def list_relations(self, workspace, project_id):
        if not self.capabilities.get("relationRead"):
            raise RuntimeError("missing capability: relationRead")
        if workspace != self.workspace:
            raise ValueError(f"foreign workspace: {workspace}")
        project_item_ids = {wi["id"] for wi in self.work_items.values() if wi.get("project_id") == project_id}
        return [
            dict(r) for r in self.relations
            if r.get("source") in project_item_ids and r.get("target") in project_item_ids
        ]

    def read_work_item(self, workspace, work_item_id_or_readable):
        if not self.capabilities.get("issueRead"):
            raise RuntimeError("missing capability: issueRead")
        if workspace != self.workspace:
            raise ValueError(f"foreign workspace: {workspace}")
        # Support resolution by readable ID or UUID
        for wi in self.work_items.values():
            if wi["id"] == work_item_id_or_readable or wi.get("readable_id") == work_item_id_or_readable:
                return dict(wi)
        return None

    def update_work_item_state(self, workspace, work_item_id, state_id):
        if not self.capabilities.get("issueWrite"):
            raise RuntimeError("missing capability: issueWrite")
        if workspace != self.workspace:
            raise ValueError(f"foreign workspace: {workspace}")
        wi = self.work_items.get(work_item_id)
        if not wi:
            raise ValueError(f"work item not found: {work_item_id}")
        wi["state_id"] = state_id
        self.state_mutations.append((work_item_id, state_id))
        return dict(wi)

    def update_project_status(self, workspace, project_id, status):
        # Plane does not support project status mutation in woostack
        self.project_status_mutations.append((project_id, status))
        raise RuntimeError("Plane project status mutation is forbidden in woostack")

    def write_delivery_checkpoint(self, workspace, work_item_id, checkpoint_data):
        if not self.capabilities.get("issueWrite"):
            raise RuntimeError("missing capability: issueWrite")
        if workspace != self.workspace:
            raise ValueError(f"foreign workspace: {workspace}")
        wi = self.work_items.get(work_item_id)
        if not wi:
            raise ValueError(f"work item not found: {work_item_id}")
        wi["delivery_checkpoint"] = dict(checkpoint_data)
        self.checkpoint_writes.append((work_item_id, checkpoint_data))
        return {"status": "checkpoint-recorded", "work_item_id": work_item_id}

class MockRepository:
    def __init__(self, parent_tip="commit-base-000"):
        self.parent_tip = parent_tip
        self.branches = {}
        self.commits = []
        self.prs = []
        self.mutation_count = 0

    def create_branch(self, branch_name, start_point):
        self.branches[branch_name] = start_point
        self.mutation_count += 1

    def commit(self, branch_name, message, files):
        sha = f"sha-{len(self.commits) + 1:03d}"
        commit_record = {"sha": sha, "branch": branch_name, "message": message, "files": files}
        self.commits.append(commit_record)
        self.branches[branch_name] = sha
        self.mutation_count += 1
        return sha

    def submit_pr(self, branch_name, base_branch, title, body, graphite_parent):
        pr_number = len(self.prs) + 1
        pr_url = f"https://github.com/acme/widgets/pull/{pr_number}"
        pr_record = {
            "number": pr_number,
            "url": pr_url,
            "head": branch_name,
            "base": base_branch,
            "title": title,
            "body": body,
            "graphite_parent": graphite_parent,
        }
        self.prs.append(pr_record)
        self.mutation_count += 1
        return pr_record


def resolve_and_validate_plane_states(config, mcp, project_id):
    plane_cfg = config["artifacts"]["plane"]
    base_url = plane_cfg["baseUrl"]
    workspace = plane_cfg["workspace"]

    if base_url != mcp.base_url:
        raise ValueError(f"foreign baseUrl: {base_url} != {mcp.base_url}")
    if workspace != mcp.workspace:
        raise ValueError(f"foreign workspace: {workspace} != {mcp.workspace}")

    required_groups = {
        "executing": "started",
        "inReview": "started",
        "done": "completed",
        "blocked": "started",
    }

    resolved_states = {}
    for role, expected_group in required_groups.items():
        state_id_or_name = plane_cfg["issueStates"].get(role)
        if not state_id_or_name:
            raise ValueError(f"missing configured issueStates.{role}")
        
        # Resolve state by exact UUID or case-sensitive name in exact scope
        state = mcp.resolve_state(workspace, project_id, state_id_or_name)
        
        # Independently read back native ID, name, and group
        read_back = mcp.read_state(workspace, project_id, state["id"])
        assert read_back["id"] == state["id"]
        assert read_back["name"] == state["name"]
        assert read_back["group"] == state["group"]

        # Validate allowable group semantics
        if read_back["group"] != expected_group:
            raise ValueError(
                f"group mismatch for issueStates.{role}: expected group '{expected_group}', got '{read_back['group']}'"
            )

        resolved_states[role] = read_back

    return resolved_states


# ---------------------------------------------------------------------------
# Test Case 1: Exact Three-Item Plane Chain Smoke Test
# ---------------------------------------------------------------------------
def test_three_item_plane_chain_smoke():
    config = {
        "artifacts": {
            "provider": "plane",
            "plane": {
                "baseUrl": "https://api.plane.so",
                "workspace": "acme",
                "repository": "https://github.com/acme/widgets",
                "projectLabels": ["woostack", "repo:widgets"],
                "projectStatuses": {
                    "backlog": "Backlog", "planned": "Planned", "started": "In Progress",
                    "completed": "Completed", "canceled": "Canceled"
                },
                "issueStates": {
                    "planned": "state-planned",
                    "executing": "state-in-progress",
                    "inReview": "state-in-review",
                    "done": "state-done",
                    "blocked": "state-blocked"
                }
            }
        }
    }

    mcp = MockPlaneMCP(base_url="https://api.plane.so", workspace="acme")
    proj_id = "proj-plane-001"
    mcp.projects[proj_id] = {
        "id": proj_id,
        "name": "[Build] Widget Catalog",
        "workspace": "acme",
        "status": "Planned",
    }

    # Add native states to MCP with exact groups
    mcp.add_state("acme", proj_id, "state-planned", "Planned", "unstarted")
    mcp.add_state("acme", proj_id, "state-in-progress", "In Progress", "started")
    mcp.add_state("acme", proj_id, "state-in-review", "In Review", "started")
    mcp.add_state("acme", proj_id, "state-done", "Done", "completed")
    mcp.add_state("acme", proj_id, "state-blocked", "Blocked", "started")

    # Resolve and validate all 4 lifecycle states before any transition
    resolved_states = resolve_and_validate_plane_states(config, mcp, proj_id)
    assert resolved_states["executing"]["id"] == "state-in-progress"
    assert resolved_states["executing"]["group"] == "started"
    assert resolved_states["inReview"]["id"] == "state-in-review"
    assert resolved_states["inReview"]["group"] == "started"
    assert resolved_states["done"]["id"] == "state-done"
    assert resolved_states["done"]["group"] == "completed"
    assert resolved_states["blocked"]["id"] == "state-blocked"
    assert resolved_states["blocked"]["group"] == "started"

    # Three work items:
    # 1: Delivered (has complete delivery checkpoint)
    # 2: Eligible (lowest unfinished ordinal, predecessor delivered)
    # 3: Pending (waiting for 2)
    mcp.work_items["wi-001"] = {
        "id": "wi-001", "readable_id": "WID-1", "project_id": proj_id,
        "title": "Increment 1: Core Schema", "state_id": "state-in-review",
        "parent": None, "ordinal": 1,
        "delivery_checkpoint": {
            "ordinal": 1, "branch": "adamwoo/core-schema", "commitSha": "sha-001",
            "prUrl": "https://github.com/acme/widgets/pull/1", "prHead": "adamwoo/core-schema",
            "prBase": "main", "graphiteParent": "main", "verificationReceipt": "verified",
            "deliveredAt": "2026-08-25T12:00:00Z"
        }
    }
    mcp.work_items["wi-002"] = {
        "id": "wi-002", "readable_id": "WID-2", "project_id": proj_id,
        "title": "Increment 2: API Handler", "state_id": "state-planned",
        "parent": None, "ordinal": 2,
        "delivery_checkpoint": None
    }
    mcp.work_items["wi-003"] = {
        "id": "wi-003", "readable_id": "WID-3", "project_id": proj_id,
        "title": "Increment 3: UI Component", "state_id": "state-planned",
        "parent": None, "ordinal": 3,
        "delivery_checkpoint": None
    }
    mcp.relations = [
        {"id": "rel-1", "source": "wi-001", "target": "wi-002", "type": "blocks"},
        {"id": "rel-2", "source": "wi-002", "target": "wi-003", "type": "blocks"},
    ]

    repo = MockRepository(parent_tip="sha-001")

    # Controller execution simulation:
    # 1. Validate baseUrl, workspace scope, and read project
    assert config["artifacts"]["plane"]["baseUrl"] == mcp.base_url, "baseUrl mismatch"
    assert config["artifacts"]["plane"]["workspace"] == mcp.workspace, "workspace mismatch"
    project = mcp.read_project("acme", proj_id)
    assert project is not None, "project read failed"
    assert project["workspace"] == "acme", "project workspace mismatch"

    # 2. Enumerate and scope all direct work items and native relations
    items = mcp.list_work_items("acme", proj_id)
    assert len(items) == 3, f"expected 3 scoped items, got {len(items)}"
    for item in items:
        assert item["project_id"] == proj_id, f"item {item['id']} has foreign project scope"
        assert item["parent"] is None, f"item {item['id']} has non-null parent"
        assert item["ordinal"] in (1, 2, 3), f"invalid ordinal {item['ordinal']}"

    relations = mcp.list_relations("acme", proj_id)
    assert len(relations) == 2, f"expected 2 blocking relations, got {len(relations)}"
    predecessors = {}
    for rel in relations:
        assert rel["type"] == "blocks", f"unexpected relation type {rel['type']}"
        predecessors[rel["target"]] = rel["source"]

    # Verify strict predecessor chain: wi-001 -> wi-002 -> wi-003
    assert predecessors.get("wi-002") == "wi-001", "predecessor of wi-002 must be wi-001"
    assert predecessors.get("wi-003") == "wi-002", "predecessor of wi-003 must be wi-002"

    # 3. Finished predicate: state is inReview or done, and full delivery checkpoint is present
    in_review_state = resolved_states["inReview"]["id"]
    done_state = resolved_states["done"]["id"]

    def is_finished(wi):
        return (
            wi.get("state_id") in (in_review_state, done_state)
            and wi.get("delivery_checkpoint") is not None
            and wi["delivery_checkpoint"].get("commitSha") is not None
            and wi["delivery_checkpoint"].get("prUrl") is not None
        )

    # 4. Derive lowest eligible unfinished item dynamically
    unfinished = [wi for wi in sorted(items, key=lambda x: x["ordinal"]) if not is_finished(wi)]
    assert len(unfinished) == 2, f"expected 2 unfinished items, got {len(unfinished)}"

    eligible = []
    for wi in unfinished:
        pred_id = predecessors.get(wi["id"])
        if pred_id is None:
            eligible.append(wi)
        else:
            pred_item = next((x for x in items if x["id"] == pred_id), None)
            if pred_item and is_finished(pred_item):
                eligible.append(wi)

    assert len(eligible) > 0, "no eligible unfinished items found"
    selected_wi = eligible[0]
    assert selected_wi["id"] == "wi-002", f"expected wi-002 selected, got {selected_wi['id']}"
    assert selected_wi["ordinal"] == 2

    # 5. Read predecessor delivery checkpoint from provider
    pred_item = mcp.read_work_item("acme", predecessors[selected_wi["id"]])
    assert pred_item is not None
    assert pred_item["delivery_checkpoint"] is not None
    assert pred_item["delivery_checkpoint"]["commitSha"] == "sha-001"
    assert pred_item["delivery_checkpoint"]["branch"] == "adamwoo/core-schema"

    # 6. Transition selected work item to executing state and read back
    executing_state = resolved_states["executing"]["id"]
    mcp.update_work_item_state("acme", selected_wi["id"], executing_state)
    read_back_exec = mcp.read_work_item("acme", selected_wi["id"])
    assert read_back_exec["state_id"] == "state-in-progress"
    read_back_state = mcp.read_state("acme", proj_id, read_back_exec["state_id"])
    assert read_back_state["group"] == "started"
    assert len(mcp.project_status_mutations) == 0, "Plane project status must never be mutated"

    # 7. Worker dispatch, implementation, commit without --issue (no Resolves line for Plane)
    branch_name = "adamwoo/api-handler"
    repo.create_branch(branch_name, pred_item["delivery_checkpoint"]["commitSha"])
    commit_sha = repo.commit(branch_name, "feat: implement API handler", ["src/api.ts"])
    pr = repo.submit_pr(
        branch_name=branch_name,
        base_branch=pred_item["delivery_checkpoint"]["branch"],
        title="feat: implement API handler",
        body="Implement API handler",
        graphite_parent=pred_item["delivery_checkpoint"]["branch"]
    )

    # 8. Delivery checkpoint persistence to provider
    checkpoint_data = {
        "stableTaskKey": "task-api-handler",
        "ordinal": 2,
        "branch": branch_name,
        "commitSha": commit_sha,
        "prUrl": pr["url"],
        "prHead": pr["head"],
        "prBase": pr["base"],
        "graphiteParent": pr["graphite_parent"],
        "verificationReceipt": "verified: unit + integration tests pass",
        "deliveredAt": "2026-08-25T13:00:00Z"
    }
    mcp.write_delivery_checkpoint("acme", selected_wi["id"], checkpoint_data)

    # 9. Independently read back delivery checkpoint from provider
    read_back_wi = mcp.read_work_item("acme", selected_wi["id"])
    assert read_back_wi["delivery_checkpoint"] == checkpoint_data, "checkpoint read-back mismatch"

    # 10. Transition to inReview state only after full checkpoint readback
    mcp.update_work_item_state("acme", selected_wi["id"], in_review_state)
    read_back_final = mcp.read_work_item("acme", selected_wi["id"])
    assert read_back_final["state_id"] == "state-in-review"
    read_back_final_state = mcp.read_state("acme", proj_id, read_back_final["state_id"])
    assert read_back_final_state["group"] == "started"
    assert is_finished(read_back_final) is True

    # 11. Sibling item 3 must NOT be advanced in this cycle
    item_3 = mcp.read_work_item("acme", "WID-3")
    assert item_3["state_id"] == "state-planned"
    assert item_3["delivery_checkpoint"] is None
    assert is_finished(item_3) is False

    # 12. Verify done state semantics (done + checkpoint counts as finished)
    done_item = {
        "id": "wi-done", "state_id": "state-done",
        "delivery_checkpoint": checkpoint_data
    }
    assert is_finished(done_item) is True

    # 13. Verify blocked transition and read-back for failure recovery
    blocked_state = resolved_states["blocked"]["id"]
    mcp.update_work_item_state("acme", "wi-003", blocked_state)
    read_back_blocked = mcp.read_work_item("acme", "wi-003")
    assert read_back_blocked["state_id"] == "state-blocked"
    read_back_blocked_state = mcp.read_state("acme", proj_id, read_back_blocked["state_id"])
    assert read_back_blocked_state["group"] == "started"

    # Overall outcomes
    assert len(mcp.project_status_mutations) == 0, "project status must not be mutated"
    assert repo.mutation_count == 3, f"expected 3 repo mutations (branch, commit, pr), got {repo.mutation_count}"
    assert len(repo.prs) == 1, "exactly one PR submitted"

    print("smoke: three-item Plane chain: ok")

test_three_item_plane_chain_smoke()


# ---------------------------------------------------------------------------
# Test Case 2: Plane State Resolution Acceptance (UUID vs Name vs Same-State)
# ---------------------------------------------------------------------------
def test_plane_state_resolution_acceptance():
    mcp = MockPlaneMCP(base_url="https://api.plane.so", workspace="acme")
    proj_id = "proj-plane-002"
    mcp.projects[proj_id] = {"id": proj_id, "name": "Catalog", "workspace": "acme"}

    # Scenario A: Exact UUID resolution
    mcp.add_state("acme", proj_id, "uuid-exec-01", "In Progress", "started")
    mcp.add_state("acme", proj_id, "uuid-rev-02", "In Review", "started")
    mcp.add_state("acme", proj_id, "uuid-done-03", "Done", "completed")
    mcp.add_state("acme", proj_id, "uuid-block-04", "Blocked", "started")

    config_uuid = {
        "artifacts": {
            "provider": "plane",
            "plane": {
                "baseUrl": "https://api.plane.so",
                "workspace": "acme",
                "issueStates": {
                    "planned": "Planned",
                    "executing": "uuid-exec-01",
                    "inReview": "uuid-rev-02",
                    "done": "uuid-done-03",
                    "blocked": "uuid-block-04"
                }
            }
        }
    }
    resolved_uuid = resolve_and_validate_plane_states(config_uuid, mcp, proj_id)
    assert resolved_uuid["executing"]["id"] == "uuid-exec-01"
    assert resolved_uuid["executing"]["group"] == "started"
    assert resolved_uuid["inReview"]["id"] == "uuid-rev-02"
    assert resolved_uuid["inReview"]["group"] == "started"
    assert resolved_uuid["done"]["id"] == "uuid-done-03"
    assert resolved_uuid["done"]["group"] == "completed"
    assert resolved_uuid["blocked"]["id"] == "uuid-block-04"
    assert resolved_uuid["blocked"]["group"] == "started"

    # Scenario B: Exact case-sensitive name resolution
    config_name = {
        "artifacts": {
            "provider": "plane",
            "plane": {
                "baseUrl": "https://api.plane.so",
                "workspace": "acme",
                "issueStates": {
                    "planned": "Planned",
                    "executing": "In Progress",
                    "inReview": "In Review",
                    "done": "Done",
                    "blocked": "Blocked"
                }
            }
        }
    }
    resolved_name = resolve_and_validate_plane_states(config_name, mcp, proj_id)
    assert resolved_name["executing"]["id"] == "uuid-exec-01"
    assert resolved_name["executing"]["name"] == "In Progress"
    assert resolved_name["inReview"]["id"] == "uuid-rev-02"
    assert resolved_name["inReview"]["name"] == "In Review"
    assert resolved_name["done"]["id"] == "uuid-done-03"
    assert resolved_name["done"]["name"] == "Done"
    assert resolved_name["blocked"]["id"] == "uuid-block-04"
    assert resolved_name["blocked"]["name"] == "Blocked"

    # Scenario C: Same executing and inReview state (idempotent delivery transition)
    config_same = {
        "artifacts": {
            "provider": "plane",
            "plane": {
                "baseUrl": "https://api.plane.so",
                "workspace": "acme",
                "issueStates": {
                    "planned": "Planned",
                    "executing": "In Progress",
                    "inReview": "In Progress",
                    "done": "Done",
                    "blocked": "Blocked"
                }
            }
        }
    }
    resolved_same = resolve_and_validate_plane_states(config_same, mcp, proj_id)
    assert resolved_same["executing"]["id"] == resolved_same["inReview"]["id"]
    assert resolved_same["executing"]["group"] == "started"

    print("smoke: Plane state resolution acceptance: ok")

test_plane_state_resolution_acceptance()


# ---------------------------------------------------------------------------
# Test Case 3: Plane State Resolution Rejection (Missing, Ambiguous, Foreign, Group Mismatch)
# ---------------------------------------------------------------------------
def test_plane_state_resolution_rejection():
    mcp = MockPlaneMCP(base_url="https://api.plane.so", workspace="acme")
    proj_id = "proj-plane-003"
    mcp.projects[proj_id] = {"id": proj_id, "name": "Catalog", "workspace": "acme"}

    # Base valid states
    mcp.add_state("acme", proj_id, "s-exec", "In Progress", "started")
    mcp.add_state("acme", proj_id, "s-rev", "In Review", "started")
    mcp.add_state("acme", proj_id, "s-done", "Done", "completed")
    mcp.add_state("acme", proj_id, "s-block", "Blocked", "started")

    def make_config(exec_val="s-exec", rev_val="s-rev", done_val="s-done", block_val="s-block", base="https://api.plane.so", ws="acme"):
        return {
            "artifacts": {
                "provider": "plane",
                "plane": {
                    "baseUrl": base,
                    "workspace": ws,
                    "issueStates": {
                        "planned": "Planned",
                        "executing": exec_val,
                        "inReview": rev_val,
                        "done": done_val,
                        "blocked": block_val,
                    }
                }
            }
        }

    # 1. Missing state
    try:
        resolve_and_validate_plane_states(make_config(exec_val="NonExistentState"), mcp, proj_id)
        assert False, "expected failure on missing state"
    except ValueError as exc:
        assert "state not found in scope" in str(exc)

    # 2. Ambiguous state (two states with same name in project)
    mcp.add_state("acme", proj_id, "s-exec-dup", "In Progress", "started")
    try:
        resolve_and_validate_plane_states(make_config(exec_val="In Progress"), mcp, proj_id)
        assert False, "expected failure on ambiguous state name"
    except ValueError as exc:
        assert "ambiguous state match" in str(exc)
    del mcp.states[("acme", proj_id, "s-exec-dup")]

    # 3. Foreign project scope (state belongs to another project)
    mcp.add_state("acme", "proj-other", "s-other-proj", "Other Proj State", "started")
    try:
        resolve_and_validate_plane_states(make_config(exec_val="s-other-proj"), mcp, proj_id)
        assert False, "expected failure on state from foreign project"
    except ValueError as exc:
        assert "state not found in scope" in str(exc)

    # 4. Foreign workspace scope
    try:
        resolve_and_validate_plane_states(make_config(ws="foreign-ws"), mcp, proj_id)
        assert False, "expected failure on foreign workspace"
    except ValueError as exc:
        assert "foreign workspace" in str(exc)

    # 5. Foreign baseUrl scope
    try:
        resolve_and_validate_plane_states(make_config(base="https://foreign.plane.so"), mcp, proj_id)
        assert False, "expected failure on foreign baseUrl"
    except ValueError as exc:
        assert "foreign baseUrl" in str(exc)

    # 6. Group mismatch: executing has group "backlog" instead of "started"
    mcp.add_state("acme", proj_id, "s-exec-backlog", "Backlog Exec", "backlog")
    try:
        resolve_and_validate_plane_states(make_config(exec_val="s-exec-backlog"), mcp, proj_id)
        assert False, "expected failure on executing group mismatch"
    except ValueError as exc:
        assert "group mismatch for issueStates.executing" in str(exc)

    # 7. Group mismatch: inReview has group "completed" instead of "started"
    mcp.add_state("acme", proj_id, "s-rev-completed", "Completed Review", "completed")
    try:
        resolve_and_validate_plane_states(make_config(rev_val="s-rev-completed"), mcp, proj_id)
        assert False, "expected failure on inReview group mismatch"
    except ValueError as exc:
        assert "group mismatch for issueStates.inReview" in str(exc)

    # 8. Group mismatch: done has group "started" instead of "completed"
    mcp.add_state("acme", proj_id, "s-done-started", "Done But Started", "started")
    try:
        resolve_and_validate_plane_states(make_config(done_val="s-done-started"), mcp, proj_id)
        assert False, "expected failure on done group mismatch"
    except ValueError as exc:
        assert "group mismatch for issueStates.done" in str(exc)

    # 9. Group mismatch: blocked has group "unstarted" instead of "started"
    mcp.add_state("acme", proj_id, "s-block-unstarted", "Blocked Unstarted", "unstarted")
    try:
        resolve_and_validate_plane_states(make_config(block_val="s-block-unstarted"), mcp, proj_id)
        assert False, "expected failure on blocked group mismatch"
    except ValueError as exc:
        assert "group mismatch for issueStates.blocked" in str(exc)

    print("smoke: Plane state resolution rejection: ok")

test_plane_state_resolution_rejection()


# ---------------------------------------------------------------------------
# Test Case 4: Injected Mirror Failure with Zero Repository-Mutation Change
# ---------------------------------------------------------------------------
def test_injected_mirror_failure_zero_repo_change():
    repo = MockRepository(parent_tip="sha-000")
    branch_name = "adamwoo/fix-cache"
    repo.create_branch(branch_name, "sha-000")
    commit_sha = repo.commit(branch_name, "fix: prevent cache refresh stampedes", ["src/cache.ts"])
    pr = repo.submit_pr(
        branch_name=branch_name,
        base_branch="main",
        title="fix: prevent cache refresh stampedes",
        body="Fix cache stampede issue",
        graphite_parent="main"
    )
    repo_mutations_before_mirror = repo.mutation_count
    assert repo_mutations_before_mirror == 3

    # Local manifest checkpoint write succeeds (CAS update)
    local_manifest = {
        "manifestRevision": 2,
        "taskExecutions": {
            "task-cache-fix": {
                "status": "delivered",
                "checkpoint": {
                    "stableTaskKey": "task-cache-fix",
                    "ordinal": 1,
                    "branch": branch_name,
                    "commitSha": commit_sha,
                    "prUrl": pr["url"],
                    "prHead": pr["head"],
                    "prBase": pr["base"],
                    "graphiteParent": pr["graphite_parent"],
                    "verificationReceipt": "verified",
                    "deliveredAt": "2026-08-25T14:00:00Z"
                }
            }
        },
        "mirror": {
            "provider": "plane",
            "status": "unstarted",
            "error": None
        }
    }

    # Inject mirror failure (e.g. MCP timeout / network error)
    mirror_failed = False
    try:
        raise RuntimeError("Plane MCP request timeout during mirror checkpoint write")
    except Exception as exc:
        mirror_failed = True
        local_manifest["mirror"]["status"] = "failed"
        local_manifest["mirror"]["error"] = str(exc)

    assert mirror_failed is True
    assert local_manifest["taskExecutions"]["task-cache-fix"]["status"] == "delivered"
    assert local_manifest["mirror"]["status"] == "failed"

    # Repository mutations must remain EXACTLY unchanged
    assert repo.mutation_count == repo_mutations_before_mirror, (
        f"repository mutation count changed on mirror failure: {repo.mutation_count} vs {repo_mutations_before_mirror}"
    )

    print("smoke: injected mirror failure with zero repo change: ok")

test_injected_mirror_failure_zero_repo_change()


# ---------------------------------------------------------------------------
# Test Case 5: Local Run Mode Base-Change User Choice
# ---------------------------------------------------------------------------
def test_local_run_base_change_choice():
    manifest = {
        "planningParentBranch": "refs/heads/main",
        "planningParentTip": "sha-planning-100"
    }

    # Scenario A: Unchanged tip -> proceeds directly
    observed_tip_same = "sha-planning-100"
    decision_same = "proceed" if observed_tip_same == manifest["planningParentTip"] else "ask"
    assert decision_same == "proceed"

    # Scenario B: Changed tip -> zero mutations, asks Continue / Revise spec/plan / Stop
    observed_tip_diff = "sha-integration-200"
    decision_diff = "proceed" if observed_tip_diff == manifest["planningParentTip"] else "ask"
    assert decision_diff == "ask"
    options = ["Continue", "Revise spec/plan", "Stop"]
    assert len(options) == 3

    print("smoke: local run base-change choice: ok")

test_local_run_base_change_choice()

print("all provider execute contract tests: ok")
PY
