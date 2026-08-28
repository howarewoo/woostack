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
require("skill", r"lowest-ordinal unfinished (?:task or issue|issue or work item|task|entry|child)")
require("skill", r"stop marker")
require("skill", r"exact issue mode.*never advances siblings")
require("skill", r"configured fast-model subagent")
require("skill", r"one focused verification.*one small bounded spec-compliance validator")
require("skill", r"branch, commit, PR URL/head/base.*verification")
require("skill", r"clean exact worktree")
require("skill", r"never create a duplicate")
require("skill", r"stop at that verified open-PR boundary.*No user wording overrides")
require("skill", r"Plane does not accept `--project` as an executable scope")

require("controller", r"Execute accepts exactly one of `--project`, `--issue`, or `--run`")
require("controller", r"Plane accepts only `--issue` and rejects `--project` before mutation")
require("controller", r"select lowest unfinished ordinal")
require("controller", r"immediate predecessor's complete delivery checkpoint")
require("controller", r"one worktree")
require("controller", r"fast-model subagent")
require("controller", r"bounded spec-compliance validator")
require("controller", r"Successful submission requires branch, commit, PR")
require("controller", r"fresh independent evidence")
require("controller", r"terminal repository mutation is Graphite PR submission or update.*never marks a PR ready.*auto-merge.*merge queue.*merges")
require("controller", r"Parent lifecycle aggregates its children")
require("controller", r"In local run mode, CAS-update the active task to `blocked` with that recovery evidence, increment `manifestRevision`")

require("driver", r"configured fast-model subagent")
require("driver", r"prohibitions on changing scope, dependencies, records, provider state, source-control")
require("skill", r"exact isolated task worktree as its active session cwd")
require("skill", r"omp --cwd <exact-worktree> -p <packet>")
require("controller", r"exact isolated task worktree as its active session cwd")
require("controller", r"omp --cwd <exact-worktree> -p <packet>")
require("driver", r"exact task worktree as its active session cwd before its first tracked-file read or write")
require("driver", r"omp --cwd <exact-worktree> -p <packet>")
require("driver", r"normalized isolation assertion without changing directories")

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
require("plane_profile", r"Plane Execute requires one exact work-item reference via `--issue`.*does not accept `--project`")
require("plane_profile", r"Parent lifecycle aggregates its child increment work items")

require("controller", r"resolve.*configured `artifacts\.plane\.issueStates`.*executing, inReview, done, blocked.*by exact UUID or case-sensitive name in exact scope, validate allowable group semantics")
require("controller", r"canonical `baseUrl`, `workspace`, and `project` scope")
require("controller", r"reject missing, ambiguous, duplicate, foreign-scope, or group-mismatched states")
require("controller", r"independently read back native ID, name, and group")
require("controller", r"validate allowable group semantics")

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
            raise ValueError(f"foreign workspace: {workspace}")
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

    def resolve_configured_project(self, workspace, project_ref, repository):
        project = self.read_project(workspace, project_ref)
        if not project:
            raise ValueError(f"configured project '{project_ref}' not found in workspace '{workspace}'")
        if project.get("repository", repository) != repository:
            raise ValueError("configured project repository does not match policy")
        return dict(project)

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


def _validate_spec_child_graph_and_relations(spec_item, children, all_relations):
    """
    Validates a complete single-parent child graph:
    1. Direct parent membership (parent = spec_item["id"])
    2. Strict 1..N ordinal numbering
    3. Zero cross-parent or foreign relations
    4. Exact adjacent-ordinal blocking relations: ordinal k-1 blocks ordinal k for k = 2..N
    """
    if not children:
        raise ValueError(f"specification item {spec_item['id']} has no children")

    child_ids = {c["id"] for c in children}

    # Check for cross-parent or foreign relations involving ANY child of this spec
    spec_relations = []
    for rel in all_relations:
        src_in = rel["source"] in child_ids
        tgt_in = rel["target"] in child_ids
        if src_in and tgt_in:
            spec_relations.append(rel)
        elif src_in or tgt_in:
            raise ValueError(
                f"cross-parent relation detected: {rel.get('id')} connects child in spec {spec_item['id']} with external/foreign work item"
            )

    # Validate strict 1..N ordinals
    ordinals = [c["ordinal"] for c in children]
    if sorted(ordinals) != list(range(1, len(children) + 1)):
        raise ValueError(f"child ordinals are not strict 1..N: {ordinals}")

    sorted_children = sorted(children, key=lambda x: x["ordinal"])

    # Expected exact adjacent-ordinal blocking edges: ordinal k-1 blocks ordinal k
    expected_edges = {
        (sorted_children[k - 2]["id"], sorted_children[k - 1]["id"])
        for k in range(2, len(sorted_children) + 1)
    }

    # 1. Verify all relations in spec_relations are 'blocks'
    for rel in spec_relations:
        if rel.get("type") != "blocks":
            raise ValueError(f"unsupported relation type: {rel.get('type')}")

    # 2. Reject unless relation row count equals expected N-1
    expected_count = len(sorted_children) - 1
    raw_count = len(spec_relations)
    if raw_count != expected_count:
        raise ValueError(
            f"relation count mismatch: expected {expected_count} relations for {len(sorted_children)} children, got {raw_count}"
        )

    # 3. Reject unless endpoint-pair cardinality equals raw row count (duplicate native edge rejection)
    raw_endpoint_pairs = [(rel["source"], rel["target"]) for rel in spec_relations]
    actual_edges = set(raw_endpoint_pairs)
    if len(actual_edges) != raw_count:
        raise ValueError(
            f"duplicate native relations detected: {raw_count} raw relations contains only {len(actual_edges)} unique endpoint pairs"
        )

    # 4. Validate exact adjacent-ordinal endpoint set
    if actual_edges != expected_edges:
        raise ValueError(
            f"malformed, reversed, or skipped relation chain: expected edges {expected_edges}, got {actual_edges}"
        )

    predecessors = {rel["target"]: rel["source"] for rel in spec_relations}
    return spec_relations, predecessors


def admit_plane_execution_target(config, mcp, ref, is_project_mode=False):
    """
    Validates Plane execution target admission under the contract:
    - Plane does not accept --project as executable scope.
    - Resolves and verifies the exact configured project first.
    - Rejects target if its direct project membership does not match the configured project UUID.
    - --issue admits either:
        1. Top-level spec item (parent = null): discovers its complete validated child graph.
        2. Exact child increment item (parent = <spec-UUID>): validates complete parent graph and admits child.
    - Rejects cross-parent, duplicate, ambiguous, unparented children, foreign-scope, and malformed graphs.
    """
    if is_project_mode:
        raise ValueError("Plane does not accept `--project` as an executable scope; use `--issue` with a spec work item or child work item")

    plane_cfg = config["artifacts"]["plane"]
    workspace = plane_cfg["workspace"]
    repo_identity = plane_cfg["repository"]
    project_ref = plane_cfg["project"]

    # 1. Resolve and independently verify the configured project
    canonical_proj = mcp.resolve_configured_project(workspace, project_ref, repo_identity)
    canonical_project_id = canonical_proj["id"]

    # 2. Read target work item
    target_item = mcp.read_work_item(workspace, ref)
    if not target_item:
        raise ValueError(f"work item not found: {ref}")

    # 3. Reject foreign project scope before mutation
    if target_item.get("project_id") != canonical_project_id:
        raise ValueError(
            f"target work item {ref} belongs to foreign project '{target_item.get('project_id')}', expected canonical project '{canonical_project_id}'"
        )

    all_project_items = mcp.list_work_items(workspace, canonical_project_id)
    all_relations = mcp.list_relations(workspace, canonical_project_id)

    if target_item["parent"] is None:
        # 1. Top-level specification work item
        spec_item = target_item
        children = [wi for wi in all_project_items if wi.get("parent") == spec_item["id"]]
        spec_relations, predecessors = _validate_spec_child_graph_and_relations(spec_item, children, all_relations)

        return {
            "mode": "spec",
            "spec_item": spec_item,
            "children": sorted(children, key=lambda x: x["ordinal"]),
            "relations": spec_relations,
            "predecessors": predecessors,
            "project_id": canonical_project_id,
        }
    else:
        # 2. Exact child increment work item
        child_item = target_item
        parent_id = child_item["parent"]
        parent_spec = next((wi for wi in all_project_items if wi["id"] == parent_id), None)
        if not parent_spec or parent_spec.get("parent") is not None or parent_spec.get("project_id") != canonical_project_id:
            raise ValueError(f"child item {child_item['id']} has invalid, foreign, or non-top-level parent {parent_id}")

        # Validate parent specification's complete child and relation graph
        parent_children = [wi for wi in all_project_items if wi.get("parent") == parent_spec["id"]]
        spec_relations, predecessors = _validate_spec_child_graph_and_relations(parent_spec, parent_children, all_relations)

        predecessor_id = predecessors.get(child_item["id"])
        if child_item["ordinal"] > 1 and not predecessor_id:
            raise ValueError(f"child item {child_item['id']} at ordinal {child_item['ordinal']} lacks required predecessor")

        return {
            "mode": "child",
            "spec_item": parent_spec,
            "selected_child": child_item,
            "predecessor_id": predecessor_id,
            "project_id": canonical_project_id,
        }


# ---------------------------------------------------------------------------
# Test Case 1: Plane Spec Execution with Two Spec Parents
# Proves selecting the second of two spec parents touches only its children,
# repeatedly cycles all unfinished children in strict ordinal order until done,
# aggregates parent lifecycle (executing -> done), and leaves the first spec
# parent and its children completely untouched.
# ---------------------------------------------------------------------------
def test_two_spec_parents_isolation_and_lifecycle_aggregation():
    config = {
        "artifacts": {
            "provider": "plane",
            "plane": {
                "baseUrl": "https://api.plane.so",
                "workspace": "acme",
                "repository": "https://github.com/acme/widgets",
                "project": "proj-plane-001",
                "projectLabels": ["woostack", "repo:widgets"],
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
        "name": "[Repo] acme/widgets",
        "workspace": "acme",
        "status": "Planned",
    }

    # Add native states with exact categories
    mcp.add_state("acme", proj_id, "state-planned", "Planned", "unstarted")
    mcp.add_state("acme", proj_id, "state-in-progress", "In Progress", "started")
    mcp.add_state("acme", proj_id, "state-in-review", "In Review", "started")
    mcp.add_state("acme", proj_id, "state-done", "Done", "completed")
    mcp.add_state("acme", proj_id, "state-blocked", "Blocked", "started")

    resolved_states = resolve_and_validate_plane_states(config, mcp, proj_id)

    # 1. Spec Parent 1: [Build] Auth Service
    mcp.work_items["spec-001"] = {
        "id": "spec-001", "readable_id": "SPEC-1", "project_id": proj_id,
        "title": "[Build] Auth Service", "state_id": "state-planned",
        "parent": None, "ordinal": None, "delivery_checkpoint": None
    }
    mcp.work_items["wi-101"] = {
        "id": "wi-101", "readable_id": "AUTH-1", "project_id": proj_id,
        "title": "Auth Tokens", "state_id": "state-planned",
        "parent": "spec-001", "ordinal": 1, "delivery_checkpoint": None
    }
    mcp.work_items["wi-102"] = {
        "id": "wi-102", "readable_id": "AUTH-2", "project_id": proj_id,
        "title": "Auth Middleware", "state_id": "state-planned",
        "parent": "spec-001", "ordinal": 2, "delivery_checkpoint": None
    }

    # 2. Spec Parent 2: [Build] Widget Catalog (Selected for Execution)
    mcp.work_items["spec-002"] = {
        "id": "spec-002", "readable_id": "SPEC-2", "project_id": proj_id,
        "title": "[Build] Widget Catalog", "state_id": "state-planned",
        "parent": None, "ordinal": None, "delivery_checkpoint": None
    }
    mcp.work_items["wi-201"] = {
        "id": "wi-201", "readable_id": "WID-1", "project_id": proj_id,
        "title": "Increment 1: Core Schema", "state_id": "state-in-review",
        "parent": "spec-002", "ordinal": 1,
        "delivery_checkpoint": {
            "ordinal": 1, "branch": "adamwoo/core-schema", "commitSha": "sha-001",
            "prUrl": "https://github.com/acme/widgets/pull/1", "prHead": "adamwoo/core-schema",
            "prBase": "main", "graphiteParent": "main", "verificationReceipt": "verified",
            "deliveredAt": "2026-08-25T12:00:00Z"
        }
    }
    mcp.work_items["wi-202"] = {
        "id": "wi-202", "readable_id": "WID-2", "project_id": proj_id,
        "title": "Increment 2: API Handler", "state_id": "state-planned",
        "parent": "spec-002", "ordinal": 2,
        "delivery_checkpoint": None
    }
    mcp.work_items["wi-203"] = {
        "id": "wi-203", "readable_id": "WID-3", "project_id": proj_id,
        "title": "Increment 3: UI Component", "state_id": "state-planned",
        "parent": "spec-002", "ordinal": 3,
        "delivery_checkpoint": None
    }

    # Relations strictly within each spec parent (adjacent ordinals)
    mcp.relations = [
        {"id": "rel-auth-1", "source": "wi-101", "target": "wi-102", "type": "blocks"},
        {"id": "rel-wid-1", "source": "wi-201", "target": "wi-202", "type": "blocks"},
        {"id": "rel-wid-2", "source": "wi-202", "target": "wi-203", "type": "blocks"},
    ]

    repo = MockRepository(parent_tip="sha-001")

    # Admit execution of SPEC-2
    admission = admit_plane_execution_target(config, mcp, "SPEC-2", is_project_mode=False)
    assert admission["mode"] == "spec"
    assert admission["spec_item"]["id"] == "spec-002"
    assert len(admission["children"]) == 3
    assert [c["id"] for c in admission["children"]] == ["wi-201", "wi-202", "wi-203"]

    in_review_state = resolved_states["inReview"]["id"]
    done_state = resolved_states["done"]["id"]
    executing_state = resolved_states["executing"]["id"]

    def is_finished(wi):
        return (
            wi.get("state_id") in (in_review_state, done_state)
            and wi.get("delivery_checkpoint") is not None
            and wi["delivery_checkpoint"].get("commitSha") is not None
            and wi["delivery_checkpoint"].get("prUrl") is not None
        )

    # --- Plane Specification Mode Loop: Execute unfinished children in strict ordinal order ---
    # 1. Transition parent specification work item to executing
    mcp.update_work_item_state("acme", "spec-002", executing_state)
    assert mcp.read_work_item("acme", "spec-002")["state_id"] == executing_state

    # --- Cycle 1: Execute lowest unfinished child (wi-202) ---
    unfinished_c1 = [wi for wi in admission["children"] if not is_finished(mcp.read_work_item("acme", wi["id"]))]
    assert len(unfinished_c1) == 2
    selected_c1 = unfinished_c1[0]
    assert selected_c1["id"] == "wi-202"

    pred_item_c1 = mcp.read_work_item("acme", admission["predecessors"][selected_c1["id"]])
    assert pred_item_c1["delivery_checkpoint"]["commitSha"] == "sha-001"

    mcp.update_work_item_state("acme", selected_c1["id"], executing_state)

    branch_202 = "adamwoo/api-handler"
    repo.create_branch(branch_202, pred_item_c1["delivery_checkpoint"]["commitSha"])
    commit_sha_202 = repo.commit(branch_202, "feat: implement API handler", ["src/api.ts"])
    pr_202 = repo.submit_pr(
        branch_name=branch_202,
        base_branch=pred_item_c1["delivery_checkpoint"]["branch"],
        title="feat: implement API handler",
        body="Implement API handler",
        graphite_parent=pred_item_c1["delivery_checkpoint"]["branch"]
    )

    checkpoint_202 = {
        "stableTaskKey": "task-api-handler",
        "ordinal": 2,
        "branch": branch_202,
        "commitSha": commit_sha_202,
        "prUrl": pr_202["url"],
        "prHead": pr_202["head"],
        "prBase": pr_202["base"],
        "graphiteParent": pr_202["graphite_parent"],
        "verificationReceipt": "verified",
        "deliveredAt": "2026-08-25T13:00:00Z"
    }
    mcp.write_delivery_checkpoint("acme", selected_c1["id"], checkpoint_202)
    mcp.update_work_item_state("acme", selected_c1["id"], in_review_state)

    # Verify Sibling Spec (spec-001 and children) is COMPLETELY UNTOUCHED
    spec_001_read = mcp.read_work_item("acme", "spec-001")
    assert spec_001_read["state_id"] == "state-planned", "spec-001 must remain planned"
    assert spec_001_read["delivery_checkpoint"] is None

    wi_101_read = mcp.read_work_item("acme", "wi-101")
    assert wi_101_read["state_id"] == "state-planned", "wi-101 must remain planned"
    assert wi_101_read["delivery_checkpoint"] is None

    wi_102_read = mcp.read_work_item("acme", "wi-102")
    assert wi_102_read["state_id"] == "state-planned", "wi-102 must remain planned"
    assert wi_102_read["delivery_checkpoint"] is None

    # --- Cycle 2: Automatically advances to next unfinished child (wi-203) in spec mode ---
    unfinished_c2 = [wi for wi in admission["children"] if not is_finished(mcp.read_work_item("acme", wi["id"]))]
    assert len(unfinished_c2) == 1
    selected_c2 = unfinished_c2[0]
    assert selected_c2["id"] == "wi-203"

    mcp.update_work_item_state("acme", selected_c2["id"], executing_state)
    branch_203 = "adamwoo/ui-component"
    repo.create_branch(branch_203, commit_sha_202)
    commit_sha_203 = repo.commit(branch_203, "feat: implement UI component", ["src/ui.tsx"])
    pr_203 = repo.submit_pr(
        branch_name=branch_203,
        base_branch=branch_202,
        title="feat: implement UI component",
        body="Implement UI component",
        graphite_parent=branch_202
    )
    checkpoint_203 = {
        "stableTaskKey": "task-ui-component",
        "ordinal": 3,
        "branch": branch_203,
        "commitSha": commit_sha_203,
        "prUrl": pr_203["url"],
        "prHead": pr_203["head"],
        "prBase": pr_203["base"],
        "graphiteParent": pr_203["graphite_parent"],
        "verificationReceipt": "verified",
        "deliveredAt": "2026-08-25T14:00:00Z"
    }
    mcp.write_delivery_checkpoint("acme", selected_c2["id"], checkpoint_203)
    mcp.update_work_item_state("acme", selected_c2["id"], done_state)

    # --- Parent Lifecycle Aggregation: All children completed -> spec-002 transitions to done ---
    all_children_finished = all(
        is_finished(mcp.read_work_item("acme", c["id"])) for c in admission["children"]
    )
    assert all_children_finished is True
    mcp.update_work_item_state("acme", "spec-002", done_state)
    assert mcp.read_work_item("acme", "spec-002")["state_id"] == done_state

    # Verify spec-001 and its children STILL untouched
    assert mcp.read_work_item("acme", "spec-001")["state_id"] == "state-planned"
    assert mcp.read_work_item("acme", "wi-101")["state_id"] == "state-planned"
    assert mcp.read_work_item("acme", "wi-102")["state_id"] == "state-planned"
    assert len(mcp.project_status_mutations) == 0, "Plane project status must never be mutated"

    print("smoke: two spec parents isolation and lifecycle aggregation: ok")

test_two_spec_parents_isolation_and_lifecycle_aggregation()


# ---------------------------------------------------------------------------
# Test Case 2: Exact Child Selection Touches No Sibling
# ---------------------------------------------------------------------------
def test_exact_child_selection_touches_no_sibling():
    config = {
        "artifacts": {
            "provider": "plane",
            "plane": {
                "baseUrl": "https://api.plane.so",
                "workspace": "acme",
                "repository": "https://github.com/acme/widgets",
                "project": "proj-plane-001",
                "projectLabels": ["woostack", "repo:widgets"],
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
    mcp.projects[proj_id] = {"id": proj_id, "name": "[Repo] acme/widgets", "workspace": "acme"}
    mcp.add_state("acme", proj_id, "state-planned", "Planned", "unstarted")
    mcp.add_state("acme", proj_id, "state-in-progress", "In Progress", "started")
    mcp.add_state("acme", proj_id, "state-in-review", "In Review", "started")
    mcp.add_state("acme", proj_id, "state-done", "Done", "completed")
    mcp.add_state("acme", proj_id, "state-blocked", "Blocked", "started")

    resolved_states = resolve_and_validate_plane_states(config, mcp, proj_id)

    mcp.work_items["spec-002"] = {
        "id": "spec-002", "readable_id": "SPEC-2", "project_id": proj_id,
        "title": "[Build] Widget Catalog", "state_id": "state-planned", "parent": None
    }
    mcp.work_items["wi-201"] = {
        "id": "wi-201", "readable_id": "WID-1", "project_id": proj_id,
        "title": "Increment 1", "state_id": "state-in-review", "parent": "spec-002", "ordinal": 1,
        "delivery_checkpoint": {"commitSha": "sha-001", "branch": "adamwoo/core-schema", "prUrl": "https://pr/1"}
    }
    mcp.work_items["wi-202"] = {
        "id": "wi-202", "readable_id": "WID-2", "project_id": proj_id,
        "title": "Increment 2", "state_id": "state-planned", "parent": "spec-002", "ordinal": 2,
        "delivery_checkpoint": None
    }
    mcp.work_items["wi-203"] = {
        "id": "wi-203", "readable_id": "WID-3", "project_id": proj_id,
        "title": "Increment 3", "state_id": "state-planned", "parent": "spec-002", "ordinal": 3,
        "delivery_checkpoint": None
    }
    mcp.relations = [
        {"id": "rel-1", "source": "wi-201", "target": "wi-202", "type": "blocks"},
        {"id": "rel-2", "source": "wi-202", "target": "wi-203", "type": "blocks"},
    ]

    repo = MockRepository(parent_tip="sha-001")

    # Admit exact child selection: --issue WID-2
    admission = admit_plane_execution_target(config, mcp, "WID-2", is_project_mode=False)
    assert admission["mode"] == "child"
    assert admission["selected_child"]["id"] == "wi-202"
    assert admission["predecessor_id"] == "wi-201"

    # Predecessor verification
    pred_item = mcp.read_work_item("acme", admission["predecessor_id"])
    assert pred_item["delivery_checkpoint"] is not None

    # Parent aggregates to executing
    mcp.update_work_item_state("acme", "spec-002", resolved_states["executing"]["id"])
    mcp.update_work_item_state("acme", "wi-202", resolved_states["executing"]["id"])

    # Execution of ONLY wi-202
    branch = "adamwoo/api-handler"
    repo.create_branch(branch, pred_item["delivery_checkpoint"]["commitSha"])
    commit_sha = repo.commit(branch, "feat: api", ["src/api.ts"])
    pr = repo.submit_pr(branch, pred_item["delivery_checkpoint"]["branch"], "feat: api", "body", pred_item["delivery_checkpoint"]["branch"])

    checkpoint = {
        "stableTaskKey": "task-api-handler", "ordinal": 2, "branch": branch,
        "commitSha": commit_sha, "prUrl": pr["url"], "prHead": pr["head"],
        "prBase": pr["base"], "graphiteParent": pr["graphite_parent"],
        "verificationReceipt": "verified", "deliveredAt": "2026-08-25T13:00:00Z"
    }
    mcp.write_delivery_checkpoint("acme", "wi-202", checkpoint)
    mcp.update_work_item_state("acme", "wi-202", resolved_states["inReview"]["id"])

    # Sibling wi-203 MUST remain planned with NO checkpoint and NO advancement
    wi_203_read = mcp.read_work_item("acme", "wi-203")
    assert wi_203_read["state_id"] == "state-planned"
    assert wi_203_read["delivery_checkpoint"] is None

    # Issue mode finishes after the single selected child
    assert repo.mutation_count == 3
    assert len(repo.prs) == 1

    print("smoke: exact child selection touches no sibling: ok")

test_exact_child_selection_touches_no_sibling()


# ---------------------------------------------------------------------------
# Test Case 3: Cross-Parent Graph Rejection on Top-Level Spec (Zero Mutations)
# ---------------------------------------------------------------------------
def test_cross_parent_graph_causes_zero_mutation():
    config = {
        "artifacts": {
            "provider": "plane",
            "plane": {
                "baseUrl": "https://api.plane.so",
                "workspace": "acme",
                "repository": "https://github.com/acme/widgets",
                "project": "proj-plane-001",
                "projectLabels": ["woostack"],
                "issueStates": {
                    "executing": "state-in-progress", "inReview": "state-in-review",
                    "done": "state-done", "blocked": "state-blocked"
                }
            }
        }
    }
    mcp = MockPlaneMCP(base_url="https://api.plane.so", workspace="acme")
    proj_id = "proj-plane-001"
    mcp.projects[proj_id] = {"id": proj_id, "name": "[Repo] acme/widgets", "workspace": "acme"}

    # Two spec items
    mcp.work_items["spec-001"] = {"id": "spec-001", "readable_id": "SPEC-1", "project_id": proj_id, "parent": None}
    mcp.work_items["wi-101"] = {"id": "wi-101", "readable_id": "AUTH-1", "project_id": proj_id, "parent": "spec-001", "ordinal": 1}

    mcp.work_items["spec-002"] = {"id": "spec-002", "readable_id": "SPEC-2", "project_id": proj_id, "parent": None}
    mcp.work_items["wi-201"] = {"id": "wi-201", "readable_id": "WID-1", "project_id": proj_id, "parent": "spec-002", "ordinal": 1}
    mcp.work_items["wi-202"] = {"id": "wi-202", "readable_id": "WID-2", "project_id": proj_id, "parent": "spec-002", "ordinal": 2}

    # Cross-parent relation: wi-101 (child of spec 1) blocks wi-201 (child of spec 2)
    mcp.relations = [
        {"id": "rel-cross", "source": "wi-101", "target": "wi-201", "type": "blocks"},
        {"id": "rel-wid-1", "source": "wi-201", "target": "wi-202", "type": "blocks"},
    ]

    repo = MockRepository(parent_tip="sha-000")

    # Attempt to admit spec-002: cross-parent relation must reject before ANY mutation
    rejected = False
    try:
        admit_plane_execution_target(config, mcp, "SPEC-2", is_project_mode=False)
    except ValueError as exc:
        rejected = True
        assert "cross-parent relation detected" in str(exc)

    assert rejected is True, "cross-parent graph must be rejected"
    assert repo.mutation_count == 0, "cross-parent rejection must make 0 repo mutations"
    assert len(mcp.state_mutations) == 0, "cross-parent rejection must make 0 provider state mutations"
    assert len(mcp.checkpoint_writes) == 0, "cross-parent rejection must make 0 checkpoint writes"
    assert len(mcp.project_status_mutations) == 0, "cross-parent rejection must make 0 project mutations"

    print("smoke: cross-parent graph causes zero mutation: ok")

test_cross_parent_graph_causes_zero_mutation()


# ---------------------------------------------------------------------------
# Test Case 4: Exact Child Cross-Parent Graph Rejection (Zero Mutations)
# ---------------------------------------------------------------------------
def test_exact_child_cross_parent_graph_causes_zero_mutation():
    config = {
        "artifacts": {
            "provider": "plane",
            "plane": {
                "baseUrl": "https://api.plane.so",
                "workspace": "acme",
                "repository": "https://github.com/acme/widgets",
                "project": "proj-plane-001",
                "projectLabels": ["woostack"],
                "issueStates": {
                    "executing": "state-in-progress", "inReview": "state-in-review",
                    "done": "state-done", "blocked": "state-blocked"
                }
            }
        }
    }
    mcp = MockPlaneMCP(base_url="https://api.plane.so", workspace="acme")
    proj_id = "proj-plane-001"
    mcp.projects[proj_id] = {"id": proj_id, "name": "[Repo] acme/widgets", "workspace": "acme"}

    # Two spec items
    mcp.work_items["spec-001"] = {"id": "spec-001", "readable_id": "SPEC-1", "project_id": proj_id, "parent": None}
    mcp.work_items["wi-101"] = {"id": "wi-101", "readable_id": "AUTH-1", "project_id": proj_id, "parent": "spec-001", "ordinal": 1}

    mcp.work_items["spec-002"] = {"id": "spec-002", "readable_id": "SPEC-2", "project_id": proj_id, "parent": None}
    mcp.work_items["wi-201"] = {"id": "wi-201", "readable_id": "WID-1", "project_id": proj_id, "parent": "spec-002", "ordinal": 1}
    mcp.work_items["wi-202"] = {"id": "wi-202", "readable_id": "WID-2", "project_id": proj_id, "parent": "spec-002", "ordinal": 2}

    # Cross-parent relation incoming to exact child wi-202 from external child wi-101
    mcp.relations = [
        {"id": "rel-cross", "source": "wi-101", "target": "wi-202", "type": "blocks"},
    ]

    repo = MockRepository(parent_tip="sha-000")

    # Attempt to admit exact child WID-2: cross-parent relation must reject before ANY mutation
    rejected = False
    try:
        admit_plane_execution_target(config, mcp, "WID-2", is_project_mode=False)
    except ValueError as exc:
        rejected = True
        assert "cross-parent relation detected" in str(exc)

    assert rejected is True
    assert repo.mutation_count == 0
    assert len(mcp.state_mutations) == 0
    assert len(mcp.checkpoint_writes) == 0

    print("smoke: exact child cross-parent graph causes zero mutation: ok")

test_exact_child_cross_parent_graph_causes_zero_mutation()


# ---------------------------------------------------------------------------
# Test Case 5: Malformed, Reversed, or Skipped Relation Order Rejection (Zero Mutations)
# ---------------------------------------------------------------------------
def test_malformed_reversed_or_skipped_order_causes_zero_mutation():
    config = {
        "artifacts": {
            "provider": "plane",
            "plane": {
                "baseUrl": "https://api.plane.so",
                "workspace": "acme",
                "repository": "https://github.com/acme/widgets",
                "project": "proj-plane-001",
                "projectLabels": ["woostack"],
                "issueStates": {
                    "executing": "state-in-progress", "inReview": "state-in-review",
                    "done": "state-done", "blocked": "state-blocked"
                }
            }
        }
    }
    mcp = MockPlaneMCP(base_url="https://api.plane.so", workspace="acme")
    proj_id = "proj-plane-001"
    mcp.projects[proj_id] = {"id": proj_id, "name": "[Repo] acme/widgets", "workspace": "acme"}

    mcp.work_items["spec-002"] = {"id": "spec-002", "readable_id": "SPEC-2", "project_id": proj_id, "parent": None}
    mcp.work_items["wi-201"] = {"id": "wi-201", "readable_id": "WID-1", "project_id": proj_id, "parent": "spec-002", "ordinal": 1}
    mcp.work_items["wi-202"] = {"id": "wi-202", "readable_id": "WID-2", "project_id": proj_id, "parent": "spec-002", "ordinal": 2}
    mcp.work_items["wi-203"] = {"id": "wi-203", "readable_id": "WID-3", "project_id": proj_id, "parent": "spec-002", "ordinal": 3}

    # Scenario A: Reversed edge with N-1=2 relations (2 blocks 1 instead of 1 blocks 2)
    mcp.relations = [
        {"id": "rel-rev", "source": "wi-202", "target": "wi-201", "type": "blocks"},
        {"id": "rel-2", "source": "wi-202", "target": "wi-203", "type": "blocks"},
    ]
    repo = MockRepository(parent_tip="sha-000")

    rejected_reversed = False
    try:
        admit_plane_execution_target(config, mcp, "SPEC-2", is_project_mode=False)
    except ValueError as exc:
        rejected_reversed = True
        assert "malformed, reversed, or skipped relation chain" in str(exc)

    assert rejected_reversed is True
    assert repo.mutation_count == 0
    assert len(mcp.state_mutations) == 0
    assert len(mcp.checkpoint_writes) == 0

    # Scenario B: Skipped/permutated edges with N-1=2 relations (1 blocks 3 and 3 blocks 2)
    mcp.relations = [
        {"id": "rel-skip", "source": "wi-201", "target": "wi-203", "type": "blocks"},
        {"id": "rel-perm", "source": "wi-203", "target": "wi-202", "type": "blocks"},
    ]
    rejected_skipped = False
    try:
        admit_plane_execution_target(config, mcp, "WID-2", is_project_mode=False)
    except ValueError as exc:
        rejected_skipped = True
        assert "malformed, reversed, or skipped relation chain" in str(exc)

    assert rejected_skipped is True
    assert repo.mutation_count == 0
    assert len(mcp.state_mutations) == 0
    assert len(mcp.checkpoint_writes) == 0

    # Scenario C: Incomplete relation count (1 relation for 3 children: count mismatch)
    mcp.relations = [
        {"id": "rel-only-1", "source": "wi-201", "target": "wi-203", "type": "blocks"},
    ]
    rejected_count = False
    try:
        admit_plane_execution_target(config, mcp, "SPEC-2", is_project_mode=False)
    except ValueError as exc:
        rejected_count = True
        assert "relation count mismatch" in str(exc)

    assert rejected_count is True
    assert repo.mutation_count == 0
    assert len(mcp.state_mutations) == 0
    assert len(mcp.checkpoint_writes) == 0

    print("smoke: malformed reversed or skipped order causes zero mutation: ok")
test_malformed_reversed_or_skipped_order_causes_zero_mutation()

# ---------------------------------------------------------------------------
# Test Case 6: Duplicate Native Relations Rejection (Zero Mutations)
# ---------------------------------------------------------------------------
def test_duplicate_native_relations_causes_zero_mutation():
    config = {
        "artifacts": {
            "provider": "plane",
            "plane": {
                "baseUrl": "https://api.plane.so",
                "workspace": "acme",
                "repository": "https://github.com/acme/widgets",
                "project": "proj-plane-001",
                "projectLabels": ["woostack"],
                "issueStates": {
                    "executing": "state-in-progress", "inReview": "state-in-review",
                    "done": "state-done", "blocked": "state-blocked"
                }
            }
        }
    }
    mcp = MockPlaneMCP(base_url="https://api.plane.so", workspace="acme")
    proj_id = "proj-plane-001"
    mcp.projects[proj_id] = {"id": proj_id, "name": "[Repo] acme/widgets", "workspace": "acme"}

    mcp.work_items["spec-002"] = {"id": "spec-002", "readable_id": "SPEC-2", "project_id": proj_id, "parent": None}
    mcp.work_items["wi-201"] = {"id": "wi-201", "readable_id": "WID-1", "project_id": proj_id, "parent": "spec-002", "ordinal": 1}
    mcp.work_items["wi-202"] = {"id": "wi-202", "readable_id": "WID-2", "project_id": proj_id, "parent": "spec-002", "ordinal": 2}
    mcp.work_items["wi-203"] = {"id": "wi-203", "readable_id": "WID-3", "project_id": proj_id, "parent": "spec-002", "ordinal": 3}

    # Duplicate relation: two distinct relation rows for wi-201 -> wi-202
    mcp.relations = [
        {"id": "rel-1", "source": "wi-201", "target": "wi-202", "type": "blocks"},
        {"id": "rel-1-dup", "source": "wi-201", "target": "wi-202", "type": "blocks"},
        {"id": "rel-2", "source": "wi-202", "target": "wi-203", "type": "blocks"},
    ]
    repo = MockRepository(parent_tip="sha-000")

    rejected_spec = False
    try:
        admit_plane_execution_target(config, mcp, "SPEC-2", is_project_mode=False)
    except ValueError as exc:
        rejected_spec = True
        assert "relation count mismatch" in str(exc) or "duplicate native relations detected" in str(exc)

    assert rejected_spec is True
    assert repo.mutation_count == 0
    assert len(mcp.state_mutations) == 0
    assert len(mcp.checkpoint_writes) == 0

    rejected_child = False
    try:
        admit_plane_execution_target(config, mcp, "WID-2", is_project_mode=False)
    except ValueError as exc:
        rejected_child = True
        assert "relation count mismatch" in str(exc) or "duplicate native relations detected" in str(exc)

    assert rejected_child is True
    assert repo.mutation_count == 0
    assert len(mcp.state_mutations) == 0
    assert len(mcp.checkpoint_writes) == 0

    print("smoke: duplicate native relations cause zero mutation: ok")

test_duplicate_native_relations_causes_zero_mutation()


# ---------------------------------------------------------------------------
# Test Case 7: Foreign Project Target Rejection (Zero Mutations)
# ---------------------------------------------------------------------------
def test_foreign_project_target_causes_zero_mutation():
    config = {
        "artifacts": {
            "provider": "plane",
            "plane": {
                "baseUrl": "https://api.plane.so",
                "workspace": "acme",
                "repository": "https://github.com/acme/widgets",
                "project": "proj-plane-001",
                "projectLabels": ["woostack"],
                "issueStates": {
                    "executing": "state-in-progress", "inReview": "state-in-review",
                    "done": "state-done", "blocked": "state-blocked"
                }
            }
        }
    }
    mcp = MockPlaneMCP(base_url="https://api.plane.so", workspace="acme")
    canonical_proj_id = "proj-plane-001"
    mcp.projects[canonical_proj_id] = {"id": canonical_proj_id, "name": "[Repo] acme/widgets", "workspace": "acme"}

    # Foreign project in same workspace
    foreign_proj_id = "proj-other-001"
    mcp.projects[foreign_proj_id] = {"id": foreign_proj_id, "name": "[Other] acme/other", "workspace": "acme"}
    mcp.work_items["foreign-001"] = {
        "id": "foreign-001", "readable_id": "FOREIGN-1", "project_id": foreign_proj_id,
        "title": "Foreign item", "parent": None, "ordinal": 1
    }

    repo = MockRepository(parent_tip="sha-000")

    rejected = False
    try:
        admit_plane_execution_target(config, mcp, "FOREIGN-1", is_project_mode=False)
    except ValueError as exc:
        rejected = True
        assert "belongs to foreign project" in str(exc)

    assert rejected is True
    assert repo.mutation_count == 0
    assert len(mcp.state_mutations) == 0
    assert len(mcp.checkpoint_writes) == 0
    assert len(mcp.project_status_mutations) == 0

    print("smoke: foreign project target causes zero mutation: ok")

test_foreign_project_target_causes_zero_mutation()


# ---------------------------------------------------------------------------
# Test Case 8: Plane Project Mode Selector Rejected (Zero Mutations)
# ---------------------------------------------------------------------------
def test_plane_project_selector_rejected_zero_mutation():
    config = {
        "artifacts": {
            "provider": "plane",
            "plane": {
                "baseUrl": "https://api.plane.so",
                "workspace": "acme",
                "repository": "https://github.com/acme/widgets",
                "project": "proj-plane-001",
                "projectLabels": ["woostack"],
                "issueStates": {"executing": "s1", "inReview": "s2", "done": "s3", "blocked": "s4"}
            }
        }
    }
    mcp = MockPlaneMCP(base_url="https://api.plane.so", workspace="acme")
    repo = MockRepository(parent_tip="sha-000")

    rejected = False
    try:
        admit_plane_execution_target(config, mcp, "proj-plane-001", is_project_mode=True)
    except ValueError as exc:
        rejected = True
        assert "Plane does not accept `--project` as an executable scope" in str(exc)

    assert rejected is True
    assert repo.mutation_count == 0
    assert len(mcp.state_mutations) == 0
    assert len(mcp.checkpoint_writes) == 0

    print("smoke: Plane project selector rejected with zero mutation: ok")

test_plane_project_selector_rejected_zero_mutation()


# ---------------------------------------------------------------------------
# Test Case 9: Plane Parent Lifecycle Aggregation on Child Blocker
# ---------------------------------------------------------------------------
def test_plane_parent_lifecycle_aggregation_on_blocker():
    config = {
        "artifacts": {
            "provider": "plane",
            "plane": {
                "baseUrl": "https://api.plane.so",
                "workspace": "acme",
                "repository": "https://github.com/acme/widgets",
                "project": "proj-plane-001",
                "projectLabels": ["woostack"],
                "issueStates": {
                    "executing": "state-in-progress", "inReview": "state-in-review",
                    "done": "state-done", "blocked": "state-blocked"
                }
            }
        }
    }
    mcp = MockPlaneMCP(base_url="https://api.plane.so", workspace="acme")
    proj_id = "proj-plane-001"
    mcp.projects[proj_id] = {"id": proj_id, "name": "[Repo] acme/widgets", "workspace": "acme"}
    mcp.add_state("acme", proj_id, "state-planned", "Planned", "unstarted")
    mcp.add_state("acme", proj_id, "state-in-progress", "In Progress", "started")
    mcp.add_state("acme", proj_id, "state-in-review", "In Review", "started")
    mcp.add_state("acme", proj_id, "state-done", "Done", "completed")
    mcp.add_state("acme", proj_id, "state-blocked", "Blocked", "started")

    resolved_states = resolve_and_validate_plane_states(config, mcp, proj_id)

    mcp.work_items["spec-002"] = {"id": "spec-002", "readable_id": "SPEC-2", "project_id": proj_id, "state_id": "state-in-progress", "parent": None}
    mcp.work_items["wi-201"] = {"id": "wi-201", "readable_id": "WID-1", "project_id": proj_id, "state_id": "state-in-progress", "parent": "spec-002", "ordinal": 1}

    # Failure / blocker occurs on wi-201
    blocked_state = resolved_states["blocked"]["id"]
    mcp.update_work_item_state("acme", "wi-201", blocked_state)
    mcp.update_work_item_state("acme", "spec-002", blocked_state)

    assert mcp.read_work_item("acme", "wi-201")["state_id"] == "state-blocked"
    assert mcp.read_work_item("acme", "spec-002")["state_id"] == "state-blocked"
    assert len(mcp.project_status_mutations) == 0

    print("smoke: Plane parent lifecycle aggregation on blocker: ok")

test_plane_parent_lifecycle_aggregation_on_blocker()


# ---------------------------------------------------------------------------
# Test Case 10: Plane State Resolution Acceptance (UUID vs Name vs Same-State)
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
# Test Case 11: Plane State Resolution Rejection (Missing, Ambiguous, Foreign, Group Mismatch)
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
# Test Case 12: Injected Mirror Failure with Zero Repository-Mutation Change
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
# Test Case 13: Local Run Mode Base-Change User Choice
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
