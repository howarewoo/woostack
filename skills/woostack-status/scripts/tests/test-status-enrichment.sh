#!/usr/bin/env bash
# Status fixture harness: verifies Linear and Plane enrichment parity,
# two specs in one repository project, exact child attribution,
# configured instance.baseUrl/workspace validation, profile-defined owned spec identities ([Build]/[Fix]/[Plan]),
# required provider-native snake_case external_source == "woostack" and nonempty external_id (sequenceId never substitutes),
# complete terminal pagination, exact membership (projectId equality), explicit ordinals,
# exact N-1 adjacent directed chain (order-independent set comparison with duplicate/count guard),
# out-of-order relation acceptance, rejection of foreign instance/workspace,
# unrelated top-level items, missing/wrong external_source, camelCase rejection, missing/empty external_id,
# missing membership, and malformed relations with zero attribution,
# and incompatible legacy run failure without mutation.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../../.." && pwd)"

python3 - "$HERE" <<'PY'
import copy, json, sys
from pathlib import Path

fixtures_dir = Path(sys.argv[1]) / "fixtures"

repo_snapshot = json.loads((fixtures_dir / "repository-snapshot.json").read_text())
linear_fixture = json.loads((fixtures_dir / "linear-enrichment.json").read_text())
plane_fixture = json.loads((fixtures_dir / "plane-enrichment.json").read_text())
unmatched_fixture = json.loads((fixtures_dir / "unmatched-repo-enrichment.json").read_text())
multi_spec_fixture = json.loads((fixtures_dir / "plane-multi-spec-enrichment.json").read_text())
cross_parent_fixture = json.loads((fixtures_dir / "plane-cross-parent-enrichment.json").read_text())
legacy_run_fixture = json.loads((fixtures_dir / "plane-legacy-incompatible-run.json").read_text())

EXPECTED_PLANE_INSTANCE = {
    "baseUrl": "https://plane.example.com",
    "workspace": "acme"
}

def validate_plane_graph(artifact, canonical_repo, expected_instance=EXPECTED_PLANE_INSTANCE):
    """
    Validates Plane artifact hierarchy against:
    1. Configured instance.baseUrl and workspace scope.
    2. Configured project exact membership (native id and canonicalRepository).
    3. Complete terminal pagination (isComplete=True, hasMore=False, nextCursor=None).
    4. Specification items:
       - Profile-defined owned spec identities (must start with [Build] , [Fix] , or [Plan] )
       - Required provider-native snake_case external_source == "woostack" and nonempty external_id (sequenceId never substitutes)
       - parent=null, unique UUIDs, valid state, exact projectId equality.
    5. Child work items:
       - unique UUIDs, valid state, exact projectId equality, parent in spec_map,
       - required provider-native snake_case external_source == "woostack" and nonempty external_id (sequenceId never substitutes),
       - explicit 1..N ordinals.
    6. Exact N-1 adjacent directed blocking chain per parent spec:
       - Retain count and duplicate guard
       - Compare normalized edge sets order-independently
       - Rejects missing, reversed, skipped, duplicate, or cross-parent edges.
    Returns (is_valid, spec_map, work_item_map, project_name).
    """
    if not isinstance(artifact, dict) or artifact.get("provider") != "plane":
        return False, {}, {}, None

    # 1. Configured instance scope verification
    if expected_instance:
        inst = artifact.get("instance")
        if not isinstance(inst, dict):
            return False, {}, {}, None
        if inst.get("baseUrl") != expected_instance.get("baseUrl"):
            return False, {}, {}, None
        if inst.get("workspace") != expected_instance.get("workspace"):
            return False, {}, {}, None

    # 2. Configured project verification
    proj = artifact.get("project")
    if not isinstance(proj, dict):
        return False, {}, {}, None
    proj_id = proj.get("id")
    proj_name = proj.get("name")
    if not proj_id or not proj_name:
        return False, {}, {}, None
    if proj.get("canonicalRepository") != canonical_repo:
        return False, {}, {}, None

    # 3. Complete terminal pagination verification
    pagination = artifact.get("pagination")
    if not isinstance(pagination, dict):
        return False, {}, {}, None
    if pagination.get("isComplete") is not True:
        return False, {}, {}, None
    if pagination.get("hasMore") is not False:
        return False, {}, {}, None
    if pagination.get("nextCursor") is not None:
        return False, {}, {}, None

    # 4. Specification items validation
    spec_items = artifact.get("specItems")
    if spec_items is None and "specItem" in artifact:
        spec_items = [artifact["specItem"]]
    if not isinstance(spec_items, list) or len(spec_items) == 0:
        return False, {}, {}, None

    spec_map = {}
    valid_prefixes = ("[Build] ", "[Fix] ", "[Plan] ")

    for spec in spec_items:
        if not isinstance(spec, dict):
            return False, {}, {}, None
        s_id = spec.get("id")
        s_title = spec.get("title") or spec.get("name")
        if not s_id or not s_title or s_id in spec_map:
            return False, {}, {}, None  # Missing identity or duplicate

        # Accept only profile-defined owned specification identities
        if not any(s_title.startswith(pfx) for pfx in valid_prefixes):
            return False, {}, {}, None  # Unrelated top-level work item rejected

        # Required provider-native snake_case external_source == "woostack" and nonempty external_id (sequenceId never substitutes)
        if spec.get("external_source") != "woostack":
            return False, {}, {}, None
        ext_id = spec.get("external_id")
        if not ext_id or not isinstance(ext_id, str) or ext_id.strip() == "":
            return False, {}, {}, None

        # Top-level specification must have parent = null
        if spec.get("parent") is not None or spec.get("parentId") is not None:
            return False, {}, {}, None
        # Strict projectId equality: missing or mismatched projectId rejects
        if not spec.get("projectId") or spec.get("projectId") != proj_id:
            return False, {}, {}, None
        if not isinstance(spec.get("state"), dict) or not spec["state"].get("name"):
            return False, {}, {}, None
        spec_map[s_id] = spec

    # 5. Child work items validation and explicit ordinals
    work_items = artifact.get("workItems")
    if work_items is None and "workItem" in artifact:
        work_items = [artifact["workItem"]]
    if not isinstance(work_items, list) or len(work_items) == 0:
        return False, {}, {}, None

    work_item_map = {}
    spec_children = {s_id: [] for s_id in spec_map}

    for wi in work_items:
        if not isinstance(wi, dict):
            return False, {}, {}, None
        w_id = wi.get("id")
        if not w_id or w_id in work_item_map:
            return False, {}, {}, None  # Missing identity or duplicate

        # Required provider-native snake_case external_source == "woostack" and nonempty external_id (sequenceId never substitutes)
        if wi.get("external_source") != "woostack":
            return False, {}, {}, None
        ext_id = wi.get("external_id")
        if not ext_id or not isinstance(ext_id, str) or ext_id.strip() == "":
            return False, {}, {}, None

        # Strict projectId equality: missing or mismatched projectId rejects
        if not wi.get("projectId") or wi.get("projectId") != proj_id:
            return False, {}, {}, None
        if wi.get("canonicalRepository") != canonical_repo:
            return False, {}, {}, None
        parent_id = wi.get("parentId")
        if not parent_id or parent_id not in spec_map:
            return False, {}, {}, None
        if not isinstance(wi.get("state"), dict) or not wi["state"].get("name"):
            return False, {}, {}, None
        ordinal = wi.get("ordinal")
        if ordinal is None or not isinstance(ordinal, int) or ordinal < 1:
            return False, {}, {}, None  # Explicit positive integer ordinal required

        work_item_map[w_id] = wi
        spec_children[parent_id].append(wi)

    # 6. Verify consecutive 1..N ordinals and compute expected adjacent chain per parent spec
    expected_chain_by_spec = {}
    for s_id, children in spec_children.items():
        if len(children) == 0:
            return False, {}, {}, None  # Spec with zero children is invalid
        sorted_children = sorted(children, key=lambda c: c["ordinal"])
        ordinals = [c["ordinal"] for c in sorted_children]
        if ordinals != list(range(1, len(children) + 1)):
            return False, {}, {}, None  # Non-consecutive, duplicate, or gap in ordinals
        # Expected adjacent chain: c_1 -> c_2 -> ... -> c_N
        expected_chain_by_spec[s_id] = set(
            (sorted_children[i]["id"], sorted_children[i+1]["id"])
            for i in range(len(sorted_children) - 1)
        )

    # 7. Validate relations: count/duplicate guard and order-independent normalized edge set comparison
    relations = artifact.get("relations")
    if not isinstance(relations, list):
        return False, {}, {}, None

    actual_relations_by_spec = {s_id: [] for s_id in spec_map}
    seen_edges = set()

    for rel in relations:
        if not isinstance(rel, dict):
            return False, {}, {}, None
        if rel.get("relationType") != "blocks":
            return False, {}, {}, None
        src_id = rel.get("source")
        tgt_id = rel.get("target")
        if not src_id or not tgt_id or src_id not in work_item_map or tgt_id not in work_item_map:
            return False, {}, {}, None

        # Duplicate edge guard across the artifact
        edge = (src_id, tgt_id)
        if edge in seen_edges:
            return False, {}, {}, None
        seen_edges.add(edge)

        # Reject cross-parent relations: source and target must have the exact same parent specification
        src_parent = work_item_map[src_id]["parentId"]
        tgt_parent = work_item_map[tgt_id]["parentId"]
        if src_parent != tgt_parent:
            return False, {}, {}, None  # Cross-parent relation detected

        actual_relations_by_spec[src_parent].append(edge)

    # For each parent spec, verify count guard and order-independent edge set equality
    for s_id, expected_edges in expected_chain_by_spec.items():
        actual_edges_list = actual_relations_by_spec[s_id]
        if len(actual_edges_list) != len(expected_edges):
            return False, {}, {}, None  # Missing or extra relations
        if set(actual_edges_list) != expected_edges:
            return False, {}, {}, None  # Reversed, skipped, or wrong direction

    return True, spec_map, work_item_map, proj_name

def validate_github_graph(artifact, canonical_repo, expected_owner=None):
    if not isinstance(artifact, dict) or artifact.get("provider") != "github": return False, {}, {}, None
    if expected_owner and artifact.get("owner") != expected_owner: return False, {}, {}, None
    proj, pagination, issues, relations = artifact.get("project", {}), artifact.get("pagination", {}), artifact.get("issues", []), artifact.get("relations", [])
    if not proj.get("url") or proj.get("canonicalRepository") != canonical_repo: return False, {}, {}, None
    if "<!-- woostack-spec-start -->" not in proj.get("readme", "") or "<!-- woostack-spec-end -->" not in proj.get("readme", ""): return False, {}, {}, None
    if pagination.get("isComplete") is not True or pagination.get("hasMore") is not False: return False, {}, {}, None
    status_opts = artifact.get("statusOptions", {})
    if not all(k in status_opts for k in ("planned", "executing", "inReview", "done", "blocked")): return False, {}, {}, None
    issue_map = {}
    for iss in issues:
        if not isinstance(iss, dict) or not iss.get("url") or iss.get("canonicalRepository") != canonical_repo or iss.get("parent") is not None: return False, {}, {}, None
        p_item = iss.get("projectItem", {})
        if not p_item or p_item.get("projectUrl") != proj["url"]: return False, {}, {}, None
        if iss.get("ordinal") is None or not isinstance(iss.get("ordinal"), int) or iss.get("ordinal") < 1: return False, {}, {}, None
        issue_map[iss["url"]] = iss
    sorted_issues = sorted(issue_map.values(), key=lambda i: i["ordinal"])
    if not issue_map or [i["ordinal"] for i in sorted_issues] != list(range(1, len(issue_map) + 1)): return False, {}, {}, None
    expected_edges = set((sorted_issues[i]["url"], sorted_issues[i+1]["url"]) for i in range(len(sorted_issues) - 1))
    actual_edges_list = [(r.get("source"), r.get("target")) for r in relations if r.get("relationType") == "blocks"]
    if len(relations) != len(expected_edges) or len(actual_edges_list) != len(expected_edges) or set(actual_edges_list) != expected_edges: return False, {}, {}, None
    return True, {"title": proj.get("title", "Spec"), "url": proj["url"]}, issue_map, proj["url"]

def derive_status_board(repo, artifact=None, expected_instance=EXPECTED_PLANE_INSTANCE, expected_owner="howarewoo"):
    rows = []
    canonical_repo = repo["canonicalRepository"]
    for branch in repo.get("branches", []):
        pr = branch.get("pullRequest")
        if not pr:
            state = "local"
        elif pr.get("draft"):
            state = "draft"
        elif pr.get("merged"):
            state = "merged"
        elif pr.get("reviewState") == "clean" and pr.get("unresolvedThreads", 0) == 0:
            state = "review-clean"
        else:
            state = "in-review"

        row = {
            "identity": branch["name"],
            "state": state,
            "prUrl": pr.get("url") if pr else None,
            "artifact": None,
            "enrichmentOmitted": False,
        }

        if artifact:
            art_provider = artifact.get("provider")
            if art_provider == "linear":
                art_item = artifact.get("issue")
                if art_item and art_item.get("canonicalRepository") == canonical_repo and pr and art_item.get("pullRequestNumber") == pr.get("number"):
                    row["artifact"] = {
                        "provider": art_provider,
                        "identifier": art_item.get("identifier"),
                        "url": art_item.get("url"),
                        "label": art_item.get("project", {}).get("name"),
                        "nativeState": art_item.get("state", {}).get("name"),
                    }
                else:
                    row["enrichmentOmitted"] = True
            elif art_provider == "plane":
                is_valid, spec_map, work_item_map, proj_name = validate_plane_graph(artifact, canonical_repo, expected_instance)
                if not is_valid:
                    row["enrichmentOmitted"] = True
                else:
                    matches = []
                    if pr:
                        pr_num = pr.get("number")
                        for wi in work_item_map.values():
                            if wi.get("pullRequestNumber") == pr_num:
                                matches.append(wi)

                    if len(matches) == 1:
                        wi = matches[0]
                        parent_spec = spec_map[wi["parentId"]]
                        row["artifact"] = {
                            "provider": "plane",
                            "identifier": wi.get("sequenceId") or wi.get("id"),
                            "url": wi.get("url"),
                            "label": parent_spec.get("title") or parent_spec.get("name"),
                            "repoProject": proj_name,
                            "specParentId": parent_spec["id"],
                            "specState": parent_spec.get("state", {}).get("name"),
                            "nativeState": wi.get("state", {}).get("name"),
                        }
                    else:
                        row["enrichmentOmitted"] = True

            elif art_provider == "github":
                is_valid, spec_info, issue_map, proj_url = validate_github_graph(artifact, canonical_repo, expected_owner=expected_owner)
                if not is_valid:
                    row["enrichmentOmitted"] = True
                else:
                    matches = []
                    if pr:
                        pr_num = pr.get("number")
                        for iss in issue_map.values():
                            if iss.get("pullRequestNumber") == pr_num:
                                matches.append(iss)
                    if len(matches) == 1:
                        iss = matches[0]
                        row["artifact"] = {
                            "provider": "github",
                            "identifier": f"#{iss.get('number')}",
                            "url": iss.get("url"),
                            "projectUrl": proj_url,
                            "label": spec_info["title"],
                            "statusField": artifact.get("statusField", "Status"),
                            "nativeState": iss.get("projectItem", {}).get("statusOption"),
                        }
                    else:
                        row["enrichmentOmitted"] = True
        rows.append(row)
    return rows

def validate_retained_plane_run(manifest):
    # Detect incompatible legacy Plane run manifests
    if manifest.get("mirror", {}).get("provider") == "plane":
        canon = manifest.get("canonicalRepository")
        if not canon or not isinstance(canon, str) or canon.strip() == "":
            raise ValueError("incompatible legacy Plane run schema; regenerate via /woostack-build or /woostack-fix")
        mirror = manifest.get("mirror", {})
        proj = mirror.get("project", {})
        if not isinstance(proj, dict) or proj.get("name") != f"[Repo] {canon}":
            raise ValueError("incompatible legacy Plane run schema; regenerate via /woostack-build or /woostack-fix")
        status = mirror.get("status")
        if status not in ("unstarted", "synced", "failed"):
            raise ValueError("incompatible legacy Plane run schema; regenerate via /woostack-build or /woostack-fix")
        spec_item = mirror.get("specItem")
        if not isinstance(spec_item, dict) or not spec_item.get("externalId"):
            raise ValueError("incompatible legacy Plane run schema; regenerate via /woostack-build or /woostack-fix")
        if status == "synced":
            if not spec_item.get("canonicalRef") or not spec_item.get("nativeId"):
                raise ValueError("incompatible legacy Plane run schema; regenerate via /woostack-build or /woostack-fix")
    return True

# Scenario 1: Baseline repository snapshot (no artifact)
base_rows = derive_status_board(repo_snapshot, None)
assert len(base_rows) == 1, "Baseline should have exactly 1 row"
assert base_rows[0]["state"] == "review-clean", "Baseline state must be review-clean"
assert base_rows[0]["artifact"] is None, "Baseline row must have no artifact enrichment"

# Scenario 2: Linear artifact enrichment
linear_rows = derive_status_board(repo_snapshot, linear_fixture)
assert len(linear_rows) == 1, "Linear enriched board should have exactly 1 row"
assert linear_rows[0]["state"] == "review-clean", "Linear state must not override repository review-clean state"
assert linear_rows[0]["artifact"]["provider"] == "linear", "Artifact provider must be linear"
assert linear_rows[0]["artifact"]["identifier"] == "APP-42", "Artifact identifier must be APP-42"
assert linear_rows[0]["artifact"]["label"] == "[Build] Auth subsystem", "Artifact label must match"

# Scenario 3: Plane artifact enrichment (exact child increment attribution & aggregate spec lifecycle)
plane_rows = derive_status_board(repo_snapshot, plane_fixture)
assert len(plane_rows) == 1, "Plane enriched board should have exactly 1 row"
assert plane_rows[0]["state"] == "review-clean", "Plane state must not override repository review-clean state"
assert plane_rows[0]["state"] == linear_rows[0]["state"], "Linear and Plane must yield identical repository row state"
assert plane_rows[0]["artifact"]["provider"] == "plane", "Artifact provider must be plane"
assert plane_rows[0]["artifact"]["identifier"] == "ENG-42", "Artifact identifier must be ENG-42"
assert plane_rows[0]["artifact"]["label"] == "[Build] Auth subsystem", "Artifact label must be parent specification item"
assert plane_rows[0]["artifact"]["repoProject"] == "[Repo] howarewoo/woostack", "Repo project is repository association only"
assert plane_rows[0]["artifact"]["specState"] == "In Progress", "Artifact must expose parent specification aggregate state"
assert plane_rows[0]["artifact"]["nativeState"] == "In Review", "Artifact must expose child increment native state"
# Assert that project status ("Active") is never used as delivery state
assert plane_rows[0]["state"] != plane_fixture["project"]["state"]["name"]
assert "projectStatus" not in plane_rows[0]["artifact"], "Project status must not be presented as delivery state"

# Scenario 4: Two specs in one repository project
two_branch_snapshot = {
    "canonicalRepository": "howarewoo/woostack",
    "integrationBranch": "main",
    "branches": [
        {
            "name": "adamwoo/auth-subsystem",
            "headSha": "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2",
            "parent": "main",
            "worktree": None,
            "pullRequest": {
                "number": 42,
                "url": "https://github.com/howarewoo/woostack/pull/42",
                "headSha": "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2",
                "baseRef": "main",
                "draft": False,
                "reviewState": "clean",
                "unresolvedThreads": 0,
                "merged": False
            }
        },
        {
            "name": "adamwoo/payment-timeout",
            "headSha": "f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5",
            "parent": "main",
            "worktree": None,
            "pullRequest": {
                "number": 52,
                "url": "https://github.com/howarewoo/woostack/pull/52",
                "headSha": "f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5",
                "baseRef": "main",
                "draft": False,
                "reviewState": "clean",
                "unresolvedThreads": 0,
                "merged": True
            }
        }
    ]
}
multi_spec_rows = derive_status_board(two_branch_snapshot, multi_spec_fixture)
assert len(multi_spec_rows) == 2, "Multi-spec board must have 2 rows"
# Row 1 -> Auth Spec
assert multi_spec_rows[0]["identity"] == "adamwoo/auth-subsystem"
assert multi_spec_rows[0]["state"] == "review-clean"
assert multi_spec_rows[0]["artifact"]["identifier"] == "ENG-42"
assert multi_spec_rows[0]["artifact"]["label"] == "[Build] Auth subsystem"
assert multi_spec_rows[0]["artifact"]["repoProject"] == "[Repo] howarewoo/woostack"
assert multi_spec_rows[0]["artifact"]["specState"] == "In Progress"
assert multi_spec_rows[0]["artifact"]["nativeState"] == "In Review"
# Row 2 -> Payment Spec
assert multi_spec_rows[1]["identity"] == "adamwoo/payment-timeout"
assert multi_spec_rows[1]["state"] == "merged"
assert multi_spec_rows[1]["artifact"]["identifier"] == "ENG-52"
assert multi_spec_rows[1]["artifact"]["label"] == "[Fix] Payment retry timeout"
assert multi_spec_rows[1]["artifact"]["repoProject"] == "[Repo] howarewoo/woostack"
assert multi_spec_rows[1]["artifact"]["specState"] == "Done"
assert multi_spec_rows[1]["artifact"]["nativeState"] == "Done"

# Scenario 5: Valid out-of-order relation list accepted cleanly
out_of_order_fixture = copy.deepcopy(multi_spec_fixture)
c3 = {
    "id": "22222222-2222-4222-8222-222222222224",
    "projectId": "33333333-3333-4333-8333-333333333333",
    "parentId": "11111111-1111-4111-8111-111111111111",
    "external_source": "woostack",
    "external_id": "22222222-2222-4222-8222-222222222224",
    "ordinal": 3,
    "sequenceId": "ENG-44",
    "title": "Auth subsystem tokens",
    "url": "https://plane.example.com/acme/projects/33333333-3333-4333-8333-333333333333/work-items/22222222-2222-4222-8222-222222222224",
    "canonicalRepository": "howarewoo/woostack",
    "pullRequestNumber": 44,
    "pullRequestUrl": "https://github.com/howarewoo/woostack/pull/44",
    "state": {"name": "Planned"}
}
out_of_order_fixture["workItems"].append(c3)
out_of_order_fixture["relations"] = [
    {
        "source": "22222222-2222-4222-8222-222222222223",
        "target": "22222222-2222-4222-8222-222222222224",
        "relationType": "blocks"
    },
    {
        "source": "22222222-2222-4222-8222-222222222222",
        "target": "22222222-2222-4222-8222-222222222223",
        "relationType": "blocks"
    }
]
out_of_order_rows = derive_status_board(two_branch_snapshot, out_of_order_fixture)
assert out_of_order_rows[0]["artifact"] is not None, "Valid out-of-order relations must be accepted"
assert out_of_order_rows[0]["artifact"]["identifier"] == "ENG-42"
assert out_of_order_rows[0]["enrichmentOmitted"] is False

# Scenario 6: Incomplete / cross-parent graph rejection via native relations
cross_parent_rows = derive_status_board(two_branch_snapshot, cross_parent_fixture)
assert len(cross_parent_rows) == 2
# PR 42 and PR 52 must have enrichment omitted due to cross-parent invalid graph
assert cross_parent_rows[0]["artifact"] is None, "Cross-parent graph must omit enrichment"
assert cross_parent_rows[0]["enrichmentOmitted"] is True
assert cross_parent_rows[1]["artifact"] is None, "Malformed child graph must omit enrichment"
assert cross_parent_rows[1]["enrichmentOmitted"] is True
# Repository state must remain intact
assert cross_parent_rows[0]["state"] == "review-clean"
assert cross_parent_rows[1]["state"] == "merged"

# Scenario 7: Foreign instance baseUrl and workspace negatives
bad_inst_url = copy.deepcopy(multi_spec_fixture)
bad_inst_url["instance"]["baseUrl"] = "https://other-plane.example.com"
assert derive_status_board(two_branch_snapshot, bad_inst_url)[0]["artifact"] is None
assert derive_status_board(two_branch_snapshot, bad_inst_url)[0]["enrichmentOmitted"] is True

bad_inst_ws = copy.deepcopy(multi_spec_fixture)
bad_inst_ws["instance"]["workspace"] = "other-workspace"
assert derive_status_board(two_branch_snapshot, bad_inst_ws)[0]["artifact"] is None
assert derive_status_board(two_branch_snapshot, bad_inst_ws)[0]["enrichmentOmitted"] is True

# Scenario 8: Unrelated top-level specification title negative (must start with [Build] , [Fix] , or [Plan] )
bad_unrelated_spec = copy.deepcopy(multi_spec_fixture)
bad_unrelated_spec["specItems"][0]["title"] = "Random unrelated task without prefix"
assert derive_status_board(two_branch_snapshot, bad_unrelated_spec)[0]["artifact"] is None
assert derive_status_board(two_branch_snapshot, bad_unrelated_spec)[0]["enrichmentOmitted"] is True

bad_spike_spec = copy.deepcopy(multi_spec_fixture)
bad_spike_spec["specItems"][0]["title"] = "[Spike] Architecture investigation"
assert derive_status_board(two_branch_snapshot, bad_spike_spec)[0]["artifact"] is None

# Scenario 9: Required provider-native snake_case external_source == "woostack" and nonempty external_id negatives
# 9a. Spec item missing external_source
bad_spec_no_src = copy.deepcopy(multi_spec_fixture)
del bad_spec_no_src["specItems"][0]["external_source"]
assert derive_status_board(two_branch_snapshot, bad_spec_no_src)[0]["artifact"] is None
assert derive_status_board(two_branch_snapshot, bad_spec_no_src)[0]["enrichmentOmitted"] is True

# 9b. Spec item with wrong external_source (e.g. "linear")
bad_spec_wrong_src = copy.deepcopy(multi_spec_fixture)
bad_spec_wrong_src["specItems"][0]["external_source"] = "linear"
assert derive_status_board(two_branch_snapshot, bad_spec_wrong_src)[0]["artifact"] is None

# 9c. Spec item with camelCase externalSource rejected (snake_case only)
bad_spec_camel_src = copy.deepcopy(multi_spec_fixture)
del bad_spec_camel_src["specItems"][0]["external_source"]
bad_spec_camel_src["specItems"][0]["externalSource"] = "woostack"
assert derive_status_board(two_branch_snapshot, bad_spec_camel_src)[0]["artifact"] is None
assert derive_status_board(two_branch_snapshot, bad_spec_camel_src)[0]["enrichmentOmitted"] is True

# 9d. Spec item with missing external_id (even if sequenceId is present)
bad_spec_no_extid = copy.deepcopy(multi_spec_fixture)
del bad_spec_no_extid["specItems"][0]["external_id"]
assert derive_status_board(two_branch_snapshot, bad_spec_no_extid)[0]["artifact"] is None
assert derive_status_board(two_branch_snapshot, bad_spec_no_extid)[0]["enrichmentOmitted"] is True

# 9e. Spec item with empty external_id
bad_spec_empty_extid = copy.deepcopy(multi_spec_fixture)
bad_spec_empty_extid["specItems"][0]["external_id"] = ""
assert derive_status_board(two_branch_snapshot, bad_spec_empty_extid)[0]["artifact"] is None

# 9f. Spec item with camelCase externalId rejected (snake_case only)
bad_spec_camel_extid = copy.deepcopy(multi_spec_fixture)
del bad_spec_camel_extid["specItems"][0]["external_id"]
bad_spec_camel_extid["specItems"][0]["externalId"] = "11111111-1111-4111-8111-111111111111"
assert derive_status_board(two_branch_snapshot, bad_spec_camel_extid)[0]["artifact"] is None
assert derive_status_board(two_branch_snapshot, bad_spec_camel_extid)[0]["enrichmentOmitted"] is True

# 9g. Child work item missing external_source
bad_wi_no_src = copy.deepcopy(multi_spec_fixture)
del bad_wi_no_src["workItems"][0]["external_source"]
assert derive_status_board(two_branch_snapshot, bad_wi_no_src)[0]["artifact"] is None
assert derive_status_board(two_branch_snapshot, bad_wi_no_src)[0]["enrichmentOmitted"] is True

# 9h. Child work item with wrong external_source (e.g. "plane")
bad_wi_wrong_src = copy.deepcopy(multi_spec_fixture)
bad_wi_wrong_src["workItems"][0]["external_source"] = "plane"
assert derive_status_board(two_branch_snapshot, bad_wi_wrong_src)[0]["artifact"] is None

# 9i. Child work item with camelCase externalSource rejected
bad_wi_camel_src = copy.deepcopy(multi_spec_fixture)
del bad_wi_camel_src["workItems"][0]["external_source"]
bad_wi_camel_src["workItems"][0]["externalSource"] = "woostack"
assert derive_status_board(two_branch_snapshot, bad_wi_camel_src)[0]["artifact"] is None
assert derive_status_board(two_branch_snapshot, bad_wi_camel_src)[0]["enrichmentOmitted"] is True

# 9j. Child work item with missing external_id (even if sequenceId is present)
bad_wi_no_extid = copy.deepcopy(multi_spec_fixture)
del bad_wi_no_extid["workItems"][0]["external_id"]
assert derive_status_board(two_branch_snapshot, bad_wi_no_extid)[0]["artifact"] is None
assert derive_status_board(two_branch_snapshot, bad_wi_no_extid)[0]["enrichmentOmitted"] is True

# 9k. Child work item with empty external_id
bad_wi_empty_extid = copy.deepcopy(multi_spec_fixture)
bad_wi_empty_extid["workItems"][0]["external_id"] = ""
assert derive_status_board(two_branch_snapshot, bad_wi_empty_extid)[0]["artifact"] is None

# 9l. Child work item with camelCase externalId rejected
bad_wi_camel_extid = copy.deepcopy(multi_spec_fixture)
del bad_wi_camel_extid["workItems"][0]["external_id"]
bad_wi_camel_extid["workItems"][0]["externalId"] = "22222222-2222-4222-8222-222222222222"
assert derive_status_board(two_branch_snapshot, bad_wi_camel_extid)[0]["artifact"] is None
assert derive_status_board(two_branch_snapshot, bad_wi_camel_extid)[0]["enrichmentOmitted"] is True

# Scenario 10: Negative membership and missing/mismatched projectId validation
# 10a. Missing projectId on specification item
bad_spec_proj = copy.deepcopy(multi_spec_fixture)
del bad_spec_proj["specItems"][0]["projectId"]
assert derive_status_board(two_branch_snapshot, bad_spec_proj)[0]["artifact"] is None
assert derive_status_board(two_branch_snapshot, bad_spec_proj)[0]["enrichmentOmitted"] is True

# 10b. Mismatched projectId on specification item
bad_spec_proj2 = copy.deepcopy(multi_spec_fixture)
bad_spec_proj2["specItems"][0]["projectId"] = "00000000-0000-0000-0000-000000000000"
assert derive_status_board(two_branch_snapshot, bad_spec_proj2)[0]["artifact"] is None

# 10c. Missing projectId on child work item
bad_wi_proj = copy.deepcopy(multi_spec_fixture)
del bad_wi_proj["workItems"][0]["projectId"]
assert derive_status_board(two_branch_snapshot, bad_wi_proj)[0]["artifact"] is None

# 10d. Mismatched projectId on child work item
bad_wi_proj2 = copy.deepcopy(multi_spec_fixture)
bad_wi_proj2["workItems"][0]["projectId"] = "00000000-0000-0000-0000-000000000000"
assert derive_status_board(two_branch_snapshot, bad_wi_proj2)[0]["artifact"] is None

# Scenario 11: Rejection of missing, reversed, skipped, duplicate relation edges and incomplete pagination
# 11a. Missing relation edge (Spec 1 has 2 children but 0 relations)
bad_missing_edge = copy.deepcopy(multi_spec_fixture)
bad_missing_edge["relations"] = []
assert derive_status_board(two_branch_snapshot, bad_missing_edge)[0]["artifact"] is None
assert derive_status_board(two_branch_snapshot, bad_missing_edge)[0]["enrichmentOmitted"] is True

# 11b. Reversed relation edge (c_2 -> c_1)
bad_reversed_edge = copy.deepcopy(multi_spec_fixture)
bad_reversed_edge["relations"] = [
    {
        "source": "22222222-2222-4222-8222-222222222223",
        "target": "22222222-2222-4222-8222-222222222222",
        "relationType": "blocks"
    }
]
assert derive_status_board(two_branch_snapshot, bad_reversed_edge)[0]["artifact"] is None
assert derive_status_board(two_branch_snapshot, bad_reversed_edge)[0]["enrichmentOmitted"] is True

# 11c. Duplicate relation edge
bad_dup_edge = copy.deepcopy(multi_spec_fixture)
bad_dup_edge["relations"].append(bad_dup_edge["relations"][0])
assert derive_status_board(two_branch_snapshot, bad_dup_edge)[0]["artifact"] is None

# 11d. Incomplete terminal pagination (isComplete=False or nextCursor present or hasMore=True)
bad_pagination = copy.deepcopy(multi_spec_fixture)
bad_pagination["pagination"]["isComplete"] = False
assert derive_status_board(two_branch_snapshot, bad_pagination)[0]["artifact"] is None
bad_cursor = copy.deepcopy(multi_spec_fixture)
bad_cursor["pagination"]["nextCursor"] = "cursor-next-page"
assert derive_status_board(two_branch_snapshot, bad_cursor)[0]["artifact"] is None
bad_has_more = copy.deepcopy(multi_spec_fixture)
bad_has_more["pagination"]["hasMore"] = True
assert derive_status_board(two_branch_snapshot, bad_has_more)[0]["artifact"] is None

# Scenario 12: Incompatible legacy Plane run failure without mutation
manifest_before = copy.deepcopy(legacy_run_fixture)
try:
    validate_retained_plane_run(legacy_run_fixture)
    assert False, "expected ValueError on incompatible legacy Plane run"
except ValueError as exc:
    assert "incompatible legacy Plane run schema; regenerate via /woostack-build or /woostack-fix" in str(exc)
assert legacy_run_fixture == manifest_before, "Incompatible legacy run validation must perform ZERO mutation"

# Valid canonical mirror.specItem passes validation cleanly
valid_manifest = {
    "runId": "run-canonical",
    "canonicalRepository": "howarewoo/woostack",
    "mirror": {
        "provider": "plane",
        "status": "synced",
        "project": {
            "id": "33333333-3333-4333-8333-333333333333",
            "name": "[Repo] howarewoo/woostack"
        },
        "specItem": {
            "externalId": "11111111-1111-4111-8111-111111111111",
            "canonicalRef": "ENG-40",
            "nativeId": "11111111-1111-4111-8111-111111111111"
        }
    }
}
assert validate_retained_plane_run(valid_manifest) is True

# Valid unstarted null preallocation passes validation cleanly
valid_unstarted_manifest = {
    "runId": "run-unstarted",
    "canonicalRepository": "howarewoo/woostack",
    "mirror": {
        "provider": "plane",
        "status": "unstarted",
        "project": {
            "id": "33333333-3333-4333-8333-333333333333",
            "name": "[Repo] howarewoo/woostack"
        },
        "specItem": {
            "externalId": "11111111-1111-4111-8111-111111111111",
            "canonicalRef": None,
            "nativeId": None
        }
    }
}
assert validate_retained_plane_run(valid_unstarted_manifest) is True

# Valid failed status null preallocation passes validation cleanly
valid_failed_manifest = {
    "runId": "run-failed",
    "canonicalRepository": "howarewoo/woostack",
    "mirror": {
        "provider": "plane",
        "status": "failed",
        "project": {
            "id": "33333333-3333-4333-8333-333333333333",
            "name": "[Repo] howarewoo/woostack"
        },
        "specItem": {
            "externalId": "11111111-1111-4111-8111-111111111111",
            "canonicalRef": None,
            "nativeId": None
        }
    }
}
assert validate_retained_plane_run(valid_failed_manifest) is True

# Mismatched canonicalRepository negative case on manifest
bad_repo_manifest = copy.deepcopy(valid_manifest)
bad_repo_manifest["mirror"]["project"]["name"] = "[Repo] other/mismatched"
try:
    validate_retained_plane_run(bad_repo_manifest)
    assert False, "expected ValueError on mismatched project name"
except ValueError as exc:
    assert "incompatible legacy Plane run schema" in str(exc)

# Missing canonicalRepository negative case on manifest
bad_no_canon_manifest = copy.deepcopy(valid_manifest)
del bad_no_canon_manifest["canonicalRepository"]
try:
    validate_retained_plane_run(bad_no_canon_manifest)
    assert False, "expected ValueError on missing canonicalRepository"
except ValueError as exc:
    assert "incompatible legacy Plane run schema" in str(exc)

# Empty canonicalRepository negative case on manifest
bad_empty_canon_manifest = copy.deepcopy(valid_manifest)
bad_empty_canon_manifest["canonicalRepository"] = ""
try:
    validate_retained_plane_run(bad_empty_canon_manifest)
    assert False, "expected ValueError on empty canonicalRepository"
except ValueError as exc:
    assert "incompatible legacy Plane run schema" in str(exc)

# Missing mirror.status negative case on manifest
bad_no_status_manifest = copy.deepcopy(valid_manifest)
del bad_no_status_manifest["mirror"]["status"]
try:
    validate_retained_plane_run(bad_no_status_manifest)
    assert False, "expected ValueError on missing mirror.status"
except ValueError as exc:
    assert "incompatible legacy Plane run schema" in str(exc)

# Invalid mirror.status negative case on manifest
bad_invalid_status_manifest = copy.deepcopy(valid_manifest)
bad_invalid_status_manifest["mirror"]["status"] = "in_progress"
try:
    validate_retained_plane_run(bad_invalid_status_manifest)
    assert False, "expected ValueError on invalid mirror.status"
except ValueError as exc:
    assert "incompatible legacy Plane run schema" in str(exc)

# Scenario 13: Absent/unmatched repository negative case
unmatched_rows = derive_status_board(repo_snapshot, unmatched_fixture)
assert len(unmatched_rows) == 1, "Unmatched artifact must not create new rows"
assert unmatched_rows[0]["identity"] == "adamwoo/auth-subsystem", "Existing repo row remains unchanged"
assert unmatched_rows[0]["state"] == "review-clean", "Row state remains review-clean"
assert unmatched_rows[0]["artifact"] is None, "Unmatched artifact must not enrich repo row"
assert unmatched_rows[0]["enrichmentOmitted"] is True, "Enrichment omission must be recorded"

# Scenario 14: Empty repository snapshot negative case
empty_snapshot = {"canonicalRepository": "howarewoo/woostack", "branches": []}
empty_linear = derive_status_board(empty_snapshot, linear_fixture)
empty_plane = derive_status_board(empty_snapshot, plane_fixture)
assert len(empty_linear) == 0, "Artifacts cannot create board rows in empty repo (Linear)"
assert len(empty_plane) == 0, "Artifacts cannot create board rows in empty repo (Plane)"


# Scenario 15: GitHub Project enrichment parity & negative cases
gh_fixture = {"provider": "github", "owner": "howarewoo", "statusField": "Status", "statusOptions": {"planned": "o1", "executing": "o2", "inReview": "o3", "done": "o4", "blocked": "o5"}, "project": {"url": "https://github.com/orgs/howarewoo/projects/1", "title": "Spec", "canonicalRepository": "howarewoo/woostack", "readme": "<!-- woostack-spec-start -->spec<!-- woostack-spec-end -->"}, "pagination": {"isComplete": True, "hasMore": False, "nextCursor": None}, "issues": [{"url": "https://github.com/howarewoo/woostack/issues/42", "number": 42, "ordinal": 1, "parent": None, "canonicalRepository": "howarewoo/woostack", "pullRequestNumber": 42, "projectItem": {"projectUrl": "https://github.com/orgs/howarewoo/projects/1", "statusOption": "In Review"}}], "relations": []}
gh_rows = derive_status_board(repo_snapshot, gh_fixture)
assert len(gh_rows) == 1 and gh_rows[0]["artifact"]["provider"] == "github" and gh_rows[0]["artifact"]["identifier"] == "#42"
# Negative cases: owner mismatch, parented issue, non-member projectUrl, wrong dependency direction, incomplete pagination
for k, v in [("owner", "other"), ("issues", [{"url": "u", "ordinal": 1, "parent": "p", "canonicalRepository": "howarewoo/woostack"}]), ("issues", [{"url": "https://github.com/howarewoo/woostack/issues/42", "ordinal": 1, "canonicalRepository": "howarewoo/woostack", "projectItem": {"projectUrl": "other"}}]), ("relations", [{"source": "a", "target": "b", "relationType": "wrong"}]), ("pagination", {"isComplete": False})]:
    bad = copy.deepcopy(gh_fixture); bad[k] = v
    assert derive_status_board(repo_snapshot, bad)[0]["artifact"] is None and derive_status_board(repo_snapshot, bad)[0]["enrichmentOmitted"] is True
# Multi-issue out-of-order relation acceptance
multi_gh = copy.deepcopy(gh_fixture)
multi_gh["issues"] = [{"url": "u1", "ordinal": 1, "canonicalRepository": "howarewoo/woostack", "projectItem": {"projectUrl": "https://github.com/orgs/howarewoo/projects/1"}}, {"url": "u2", "ordinal": 2, "canonicalRepository": "howarewoo/woostack", "projectItem": {"projectUrl": "https://github.com/orgs/howarewoo/projects/1"}}, {"url": "u3", "ordinal": 3, "canonicalRepository": "howarewoo/woostack", "projectItem": {"projectUrl": "https://github.com/orgs/howarewoo/projects/1"}}]
multi_gh["relations"] = [{"source": "u2", "target": "u3", "relationType": "blocks"}, {"source": "u1", "target": "u2", "relationType": "blocks"}] # out of order
assert validate_github_graph(multi_gh, "howarewoo/woostack", "howarewoo")[0] is True
print("status enrichment fixture parity and negative cases: ok")
PY
