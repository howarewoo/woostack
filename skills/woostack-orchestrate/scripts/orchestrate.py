#!/usr/bin/env python3
"""Session-local orchestration gates; the skill supplies fresh gh/host evidence.

This is the production scheduling path. It never calls a provider or implements
source. The controller dispatches emitted packets through its native host, then
returns independent GitHub, verification, review, and progress readbacks. Git
identity, ancestry, worktree ownership, and diff hashes are checked here directly.
"""
import argparse
import copy
import hashlib
from graphlib import CycleError, TopologicalSorter
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

DEFAULT_MAX_PARALLEL = 3
ISSUE_RE = re.compile(r"https://github\.com/([\w.-]+)/([\w.-]+)/issues/([1-9][0-9]*)\Z")
PR_RE = re.compile(r"https://github\.com/([\w.-]+)/([\w.-]+)/pull/([1-9][0-9]*)\Z")
PROJECT_RE = re.compile(r"https://github\.com/(orgs|users)/([\w.-]+)/projects/([1-9][0-9]*)\Z")
REPO_RE = re.compile(r"https://github\.com/([\w.-]+)/([\w.-]+)\Z")
TASK_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*\Z")
SHA_RE = re.compile(r"(?:[0-9a-f]{40}|[0-9a-f]{64})\Z")
EDGE_KINDS = ("native", "declared", "inferred")


def canonical_issue_url(value, canonical):
    match = ISSUE_RE.fullmatch(value or "")
    repo = REPO_RE.fullmatch(canonical or "")
    require(match is not None and repo is not None
            and tuple(part.lower() for part in match.groups()[:2]) ==
            tuple(part.lower() for part in repo.groups()),
            "foreign-repository", "issue is outside the canonical repository")
    return "https://github.com/%s/%s/issues/%s" % (repo.group(1), repo.group(2), match.group(3))


def canonical_issue_selectors(values, canonical):
    if isinstance(values, str):
        values = values.split()
    require(isinstance(values, list) and bool(values), "missing-selector",
            "at least one issue selector is required")
    normalized = [canonical_issue_url(value, canonical) for value in values]
    return sorted(set(normalized))

def edge_kind(value, default=None):
    if isinstance(value, dict):
        value = value.get("kind", value.get("type", value.get("source")))
    value = value or default
    require(value in EDGE_KINDS, "invalid-edge", "edge provenance must be native, declared, or inferred")
    return value


def edge_evidence(value, default=None):
    evidence = value if value is not None else default
    require((text(evidence) or (isinstance(evidence, list) and bool(evidence))
             or (isinstance(evidence, dict) and bool(evidence))),
            "missing-edge-evidence", "dependency edge evidence is required")
    return copy.deepcopy(evidence)


class InputError(Exception):
    def __init__(self, code, message):
        super().__init__(message)
        self.code = code


def require(condition, code, message):
    if not condition:
        raise InputError(code, message)


def text(value):
    return isinstance(value, str) and bool(value.strip())


def digest(value):
    return "sha256:" + hashlib.sha256(json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=True
    ).encode()).hexdigest()


def load_json(path):
    try:
        with open(path, encoding="utf-8") as stream:
            value = json.load(stream)
        require(isinstance(value, dict), "malformed-input", "JSON must be an object")
        return value
    except (OSError, ValueError) as error:
        raise InputError("unreadable-input", str(error)) from error


def write_json(path, value):
    destination = Path(path)
    require(not destination.is_symlink(), "unsafe-state", "state cannot be a symlink")
    # A failed write must leave the previous reservations intact.
    descriptor, temporary = tempfile.mkstemp(prefix=destination.name + ".", dir=destination.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            json.dump(value, stream, indent=2, sort_keys=True)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, destination)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def positive(value):
    require(not isinstance(value, bool) and re.fullmatch(r"[1-9][0-9]*", str(value)) is not None,
            "invalid-limit", "parallel limits must be positive integers")
    return int(value)


def string_list(value, field, empty=False):
    require(isinstance(value, list) and (empty or bool(value)) and all(text(v) for v in value),
            "malformed-contract", field + " must be a string list")
    require(len(value) == len(set(value)), "duplicate-value", field + " has duplicate values")
    return value


def contract_check(contract):
    require(isinstance(contract, dict), "malformed-contract", "task contract missing")
    for key in ("goal", "smoke", "decisions", "risks"):
        require(text(contract.get(key)), "malformed-contract", "contract requires " + key)
    for key in ("scope", "acceptance", "checks", "non_goals"):
        string_list(contract.get(key), key, empty=key == "non_goals")
    for path in contract["scope"]:
        require(not Path(path).is_absolute() and ".." not in Path(path).parts,
                "malformed-contract", "allowed paths must stay inside the task worktree")


def issue_identity(item, canonical):
    require(isinstance(item, dict), "invalid-identity", "issue evidence missing")
    match = ISSUE_RE.fullmatch(item.get("url", ""))
    repo = REPO_RE.fullmatch(canonical)
    require(match is not None and repo is not None
            and tuple(part.lower() for part in match.groups()[:2]) ==
            tuple(part.lower() for part in repo.groups()),
            "foreign-repository", "issue is outside the canonical repository")
    require(type(item.get("id")) is int and item["id"] > 0 and text(item.get("node_id")),
            "invalid-identity", "native issue identities missing")
    require(item.get("resource") == "issue", "not-an-issue", "resource is not an issue")
    require(item.get("state") == "open", "issue-not-open", "issue is not open")
    require(text(item.get("title")) and text(item.get("body")),
            "malformed-contract", "complete title and body required")


def pagination(snapshot, families):
    proof = snapshot.get("pagination", {})
    require(isinstance(proof, dict) and all(proof.get(f) is True for f in families),
            "incomplete-hierarchy", "required native reads have not reached terminal pagination")


def workspace_relative(value, task):
    value = value if value is not None else ".woostack/worktrees/tasks/" + task
    require(text(value) and not Path(value).is_absolute() and ".." not in Path(value).parts,
            "invalid-workspace", "workspace must be a contained relative path")
    return value


def normalize_edge_ref(value, by_id, by_url, canonical):
    require(text(value), "missing-endpoint", "dependency edge endpoint is missing")
    if isinstance(value, str) and value in by_id:
        return value, None
    if isinstance(value, str) and ISSUE_RE.fullmatch(value):
        normalized = canonical_issue_url(value, canonical)
        if normalized in by_url:
            return by_url[normalized], None
        return None, normalized
    raise InputError("missing-endpoint", "unknown dependency endpoint " + str(value))


def edge_endpoint(raw, names):
    for name in names:
        if name in raw:
            return raw[name]
    return None


def edge_records(raw, default_dependent=None, default_kind=None, default_evidence=None):
    require(isinstance(raw, dict), "invalid-edge", "dependency edge must be an object")
    blocked = raw.get("blocked_by", raw.get("prerequisites"))
    if isinstance(blocked, list):
        dependent = edge_endpoint(raw, ("dependent", "to", "task_id", "issue_url")) or default_dependent
        require(text(dependent), "missing-endpoint", "dependency edge dependent is missing")
        result = []
        for predecessor in blocked:
            item = dict(raw)
            item.pop("blocked_by", None)
            item.pop("prerequisites", None)
            item["predecessor"] = predecessor
            item["dependent"] = dependent
            result.extend(edge_records(item, default_kind=default_kind,
                                       default_evidence=default_evidence))
        return result
    predecessor = edge_endpoint(raw, ("predecessor", "from", "blocked", "prerequisite"))
    dependent = edge_endpoint(raw, ("dependent", "to", "blocks", "task_id", "issue_url"))
    require(predecessor is not None and (dependent is not None or default_dependent is not None),
            "missing-endpoint", "dependency edge endpoints are required")
    provenance = raw.get("provenance", raw.get("kind"))
    embedded_evidence = provenance.get("evidence", provenance.get("rationale")) if isinstance(provenance, dict) else None
    return [{
        "predecessor": predecessor,
        "dependent": dependent if dependent is not None else default_dependent,
        "provenance": edge_kind(provenance, default_kind),
        "evidence": edge_evidence(raw.get("evidence", raw.get("rationale")),
                                   embedded_evidence if embedded_evidence is not None else default_evidence),
    }]


def graph_metadata(snapshot, edges):
    metadata = snapshot.get("graph", snapshot.get("graph_evidence", {}))
    require(isinstance(metadata, dict), "incomplete-graph", "graph evidence must be an object")
    coverage = metadata.get("coverage", metadata.get("status"))
    if coverage is None:
        coverage = "supplied" if edges or snapshot.get("issues") or snapshot.get("selected_issues") else "native"
    require(text(coverage), "incomplete-graph", "graph coverage evidence is required")
    require(coverage.lower() not in ("partial", "incomplete", "unknown", "missing"),
            "incomplete-graph", "graph coverage is incomplete")
    inference = metadata.get("model_inference", metadata.get("inference_status",
                                                              snapshot.get("model_inference", "not-run")))
    if isinstance(inference, dict):
        inference = inference.get("status", inference.get("state"))
    if isinstance(inference, bool):
        inference = "complete" if inference else "not-run"
    require(text(inference), "incomplete-graph", "model inference status is required")
    if any(edge["provenance"] == "inferred" for edge in edges):
        require(inference.lower() not in
                ("not-run", "unrun", "unknown", "missing", "partial", "incomplete"),
                "inference-unrun", "inferred edges require completed model evidence")
    if "complete" in metadata:
        require(metadata["complete"] is True, "incomplete-graph", "graph read is not complete")
    if "edge_count" in metadata:
        require(type(metadata["edge_count"]) is int and metadata["edge_count"] == len(edges),
                "incomplete-graph", "graph edge count does not match supplied evidence")
    return {"coverage": coverage, "model_inference": inference,
            "source": metadata.get("source", "controller-supplied"),
            "complete": metadata.get("complete", True),
            "edges": copy.deepcopy(edges)}


def check_graph(tasks, parent_url, edges=None):
    edges = edges or []
    by_id = {t["task_id"]: t for t in tasks}
    for key in ("task_id", "ordinal", "url", "id", "node_id"):
        require(len({t[key] for t in tasks}) == len(tasks), "duplicate-identity", "duplicate " + key)
    seen_edges = set()
    for edge in edges:
        predecessor, dependent = edge["predecessor"], edge["dependent"]
        if predecessor in by_id:
            require(dependent in by_id, "missing-endpoint", "unknown dependency dependent " + str(dependent))
            key = (predecessor, dependent)
            require(key not in seen_edges, "duplicate-edge", "duplicate dependency edge")
            seen_edges.add(key)
            require(predecessor != dependent, "self-dependency", "task depends on itself")
        else:
            require(ISSUE_RE.fullmatch(predecessor or "") is not None,
                    "missing-endpoint", "unknown dependency endpoint " + str(predecessor))
            require(dependent in by_id, "missing-endpoint", "unknown dependency dependent " + str(dependent))
    for task in tasks:
        require(not parent_url or (task["url"] != parent_url and parent_url not in task["external_prerequisites"]),
                "parent-as-task", "specification parent cannot be a task or dependency")
        for predecessor in task["prerequisites"]:
            require(predecessor in by_id, "missing-endpoint", "unknown prerequisite " + predecessor)
            require(predecessor != task["task_id"], "self-dependency", "task depends on itself")
    try:
        return list(TopologicalSorter({t["task_id"]: t["prerequisites"] for t in tasks}).static_order())
    except CycleError as error:
        raise InputError("cycle", "dependency graph contains a cycle") from error


def collect_edges(snapshot, tasks, mode, canonical):
    by_id = {task["task_id"]: task for task in tasks}
    by_url = {task["url"]: task["task_id"] for task in tasks}
    entries_by_id = {task["task_id"]: task for task in tasks}
    candidates = []

    def add(raw, default_dependent=None, default_kind=None, default_evidence=None):
        if isinstance(raw, str):
            raw = {"predecessor": raw, "dependent": default_dependent}
        for record in edge_records(raw, default_dependent, default_kind, default_evidence):
            candidates.append(record)

    for key in ("edges", "dependency_edges", "edge_provenance"):
        values = snapshot.get(key)
        if values is None and isinstance(snapshot.get("graph"), dict):
            values = snapshot["graph"].get(key)
        if values is not None:
            require(isinstance(values, list), "invalid-edge", key + " must be a list")
            for value in values:
                add(value, default_kind="native" if mode != "issues" else None)
    for task in tasks:
        source = task["task_id"]
        for key, kind in (("native_edges", "native"), ("native_dependencies", "native"),
                          ("native_prerequisites", "native"),
                          ("declared_edges", "declared"), ("declared_dependencies", "declared"),
                          ("declared_prerequisites", "declared"),
                          ("inferred_edges", "inferred"), ("inferred_dependencies", "inferred"),
                          ("inferred_prerequisites", "inferred")):
            values = task.get(key)
            if values is None:
                continue
            require(isinstance(values, list), "invalid-edge", key + " must be a list")
            for value in values:
                add(value, default_dependent=source, default_kind=kind,
                    default_evidence={"issue_url": task["url"], "field": key})
        prerequisites = task.get("prerequisites", [])
        require(isinstance(prerequisites, list), "malformed-contract", "prerequisites must be a string list")
        for predecessor in prerequisites:
            add({"predecessor": predecessor, "dependent": source},
                default_kind="native" if mode != "issues" else "declared",
                default_evidence={"issue_url": task["url"], "field": "prerequisites"})

    edges, seen = [], {}
    for candidate in candidates:
        predecessor, external = normalize_edge_ref(candidate["predecessor"], by_id, by_url, canonical)
        dependent, dependent_external = normalize_edge_ref(candidate["dependent"], by_id, by_url, canonical)
        require(dependent is not None and dependent_external is None,
                "missing-endpoint", "dependency edge dependent must be selected")
        endpoint = external or predecessor
        if external is None:
            require(predecessor is not None, "missing-endpoint", "dependency edge predecessor is missing")
        else:
            require(ISSUE_RE.fullmatch(external), "missing-endpoint", "external prerequisite identity is invalid")
            entries_by_id[dependent].setdefault("external_prerequisites", []).append(external)
        normalized = {"predecessor": endpoint, "dependent": dependent,
                      "provenance": candidate["provenance"],
                      "evidence": copy.deepcopy(candidate["evidence"])}
        pair = (endpoint, dependent)
        previous = seen.get(pair)
        if previous is not None:
            if previous == normalized:
                continue
            raise InputError("duplicate-edge", "conflicting dependency evidence for " + str(pair))
        seen[pair] = normalized
        edges.append(normalized)

    # A selected issue named in an external prerequisite is internal to this
    # scope, while every other canonical issue remains an explicit blocker.
    for task in tasks:
        external_values = task.get("external_prerequisites", [])
        require(isinstance(external_values, list),
                "malformed-contract", "external_prerequisites must be a string list")
        remaining = []
        for value in external_values:
            external = canonical_issue_url(value, canonical)
            if external in by_url:
                pair = (by_url[external], task["task_id"])
                if pair not in seen:
                    edge = {"predecessor": pair[0], "dependent": pair[1],
                            "provenance": "native" if mode != "issues" else "declared",
                            "evidence": {"issue_url": task["url"], "field": "external_prerequisites"}}
                    seen[pair] = edge
                    edges.append(edge)
            else:
                remaining.append(external)
        task["external_prerequisites"] = sorted(set(remaining))

    edges.sort(key=lambda edge: (edge["dependent"], edge["predecessor"], edge["provenance"],
                                 json.dumps(edge["evidence"], sort_keys=True, separators=(",", ":"))))
    for task in tasks:
        task["prerequisites"] = sorted({edge["predecessor"] for edge in edges
                                        if edge["dependent"] == task["task_id"]
                                        and edge["predecessor"] in by_id})
        task["edge_provenance"] = [copy.deepcopy(edge) for edge in edges
                                   if edge["dependent"] == task["task_id"]]
    return edges


def admit(snapshot, mode, selector, limit):
    if mode == "list":
        mode = "issues"
    canonical = snapshot.get("canonical_repo", "")
    require(REPO_RE.fullmatch(canonical) is not None, "missing-repository", "canonical repository missing")
    require(mode in ("issue", "project", "issues"), "invalid-mode", "unsupported orchestration mode")
    require(text(snapshot.get("repository_rules")), "malformed-contract", "scope requires repository_rules")
    if mode != "issues":
        require(text(snapshot.get("specification")), "malformed-contract", "scope requires specification")
    integration = snapshot.get("integration", {})
    require(isinstance(integration, dict) and text(integration.get("branch"))
            and SHA_RE.fullmatch(integration.get("sha", "")) is not None,
            "missing-integration", "admitted integration branch and commit required")
    parent_url = None
    selector_urls = None
    if mode == "issue":
        require(ISSUE_RE.fullmatch(selector) is not None, "invalid-issue-url", "exact issue URL required")
        selector = canonical_issue_url(selector, canonical)
        scope = snapshot.get("parent", {})
        issue_identity(scope, canonical)
        require(scope["url"] == selector, "invalid-parent", "selected parent differs")
        require("parent" in scope and scope["parent"] is None, "nested-parent", "top-level parent must be proved")
        pagination(snapshot, ("sub_issues", "parents", "dependencies", "contracts"))
        entries = snapshot.get("children")
        parent_url = selector
    elif mode == "project":
        require(isinstance(selector, str), "invalid-project-url", "exact Project URL required")
        match = PROJECT_RE.fullmatch(selector)
        require(match is not None, "invalid-project-url", "exact Project URL required")
        scope = snapshot.get("project", {})
        require(isinstance(scope, dict) and scope.get("url") == selector
                and type(scope.get("number")) is int and scope["number"] == int(match.group(3))
                and text(scope.get("node_id"))
                and scope.get("state") == "open", "invalid-project", "exact open Project identity required")
        owner = match.group(2)
        require(scope.get("owner") == owner and owner == REPO_RE.fullmatch(canonical).group(1)
                and scope.get("owner_type") == {"orgs": "organization", "users": "user"}[match.group(1)],
                "foreign-repository", "Project owner/repository evidence conflicts")
        lifecycle = snapshot.get("lifecycle", {})
        require(isinstance(lifecycle, dict) and all(text(lifecycle.get(k)) for k in
                ("planned", "executing", "inReview", "done", "blocked"))
                and len(set(lifecycle.values())) == 5, "missing-lifecycle", "five distinct configured statuses required")
        pagination(snapshot, ("members", "parents", "dependencies", "contracts"))
        entries = snapshot.get("members")
    else:
        selector_urls = canonical_issue_selectors(selector, canonical)
        selector = " ".join(selector_urls)
        entries = snapshot.get("selected_issues", snapshot.get("issues"))
        require(isinstance(entries, list), "incomplete-selection", "selected issue records are missing")
        pagination(snapshot, ("issues", "parents", "dependencies", "contracts"))
        graph_hint = snapshot.get("graph", snapshot.get("graph_evidence", {}))
        require(isinstance(graph_hint, dict) and
                (bool(graph_hint) or any(snapshot.get(key) is not None
                                         for key in ("edges", "dependency_edges", "edge_provenance"))),
                "incomplete-graph", "list mode requires graph evidence")
    by_url, containers = {}, []
    for entry in entries:
        issue_identity(entry, canonical)
        entry = copy.deepcopy(entry)
        entry["url"] = canonical_issue_url(entry["url"], canonical)
        issue_number = int(ISSUE_RE.fullmatch(entry["url"]).group(3))
        if entry.get("number") is not None:
            require(type(entry["number"]) is int and entry["number"] == issue_number,
                    "ambiguous-identity", "issue number conflicts with issue URL")
        entry["number"] = issue_number
        require("actual_parent" in entry, "foreign-parent", "actual parent must be independently read")
        if mode == "issue":
            require(entry["actual_parent"] == parent_url, "foreign-parent", "child belongs to another parent")
        elif mode == "project":
            require(text(entry.get("item_id")), "invalid-project-item", "native Project item identity required")
            require("declared_parent" in entry and entry["declared_parent"] == entry["actual_parent"],
                    "foreign-parent", "Project member parent evidence conflicts")
        require(entry.get("nested_children") is False or (mode == "project" and entry.get("container") is True),
                "unsupported-nested", "nested containers or unreadable child hierarchy are unsupported")
        previous = by_url.get(entry["url"])
        if previous is not None:
            immutable_previous = {k: v for k, v in previous.items() if k != "existing_delivery"}
            immutable_entry = {k: v for k, v in entry.items() if k != "existing_delivery"}
            require(immutable_previous == immutable_entry, "ambiguous-identity", "duplicate member evidence conflicts")
            if entry.get("existing_delivery") is not None:
                if previous.get("existing_delivery") is None:
                    previous["existing_delivery"] = copy.deepcopy(entry["existing_delivery"])
                else:
                    require(previous["existing_delivery"] == entry["existing_delivery"],
                            "ambiguous-identity", "duplicate delivery evidence conflicts")
            continue
        by_url[entry["url"]] = entry
        if mode == "project" and entry.get("container") is True:
            containers.append(entry["url"])
    if mode == "issues":
        require(set(by_url) == set(selector_urls), "incomplete-selection",
                "selected issue records do not exactly match the explicit list")
    tasks = []
    list_urls = sorted(by_url)
    for index, entry in enumerate(by_url.values() if mode != "issues" else
                                  [by_url[url] for url in list_urls], 1):
        if entry["url"] in containers:
            continue
        task = entry.get("task_id")
        if mode == "issues" and not task:
            task = "issue-" + ISSUE_RE.fullmatch(entry["url"]).group(3)
        require(isinstance(task, str) and TASK_RE.fullmatch(task) and ".." not in task
                and not task.endswith((".", ".lock")), "invalid-identity", "Git-safe stable task ID required")
        ordinal = entry.get("ordinal")
        if mode == "issues" and ordinal is None:
            ordinal = index
        require(type(ordinal) is int and ordinal > 0, "malformed-ordinal", "positive ordinal required")
        contract_check(entry.get("contract"))
        if mode != "issues":
            require("prerequisites" in entry and "external_prerequisites" in entry,
                    "incomplete-hierarchy", "native dependency evidence is required")
        prerequisites = entry.get("prerequisites", [])
        string_list(prerequisites, "prerequisites", empty=True)
        external = entry.get("external_prerequisites", [])
        string_list(external, "external_prerequisites", empty=True)
        require(all(ISSUE_RE.fullmatch(url) for url in external),
                "missing-endpoint", "external prerequisites need exact issue identities")
        record = copy.deepcopy(entry)
        record["task_id"] = task
        record["ordinal"] = ordinal
        record["workspace"] = workspace_relative(entry.get("workspace"), task)
        record["contract_hash"] = digest(entry["contract"])
        if mode == "issues":
            record["specification"] = entry.get("specification", entry["body"])
            require(text(record["specification"]), "malformed-contract", "selected issue specification missing")
        tasks.append(record)
    identity_entries = list(by_url.values())
    for key in (("id", "node_id", "item_id") if mode == "project" else ("id", "node_id")):
        require(len({entry[key] for entry in identity_entries}) == len(identity_entries),
                "duplicate-identity", "native membership contains conflicting " + key)
    tasks_by_id = {task["task_id"]: task for task in tasks}
    require(len(tasks_by_id) == len(tasks), "duplicate-identity", "duplicate task_id")
    edges = collect_edges(snapshot, tasks, mode, canonical)
    graph = graph_metadata(snapshot, edges) if mode == "issues" else {
        "coverage": "native", "model_inference": "not-applicable",
        "source": "native-read", "complete": True}
    task_order = check_graph(tasks, parent_url, edges)
    if mode == "issue":
        expected = snapshot.get("expected_index")
        string_list(expected, "expected_index", empty=True)
        require(set(expected) == {t["task_id"] for t in tasks}, "incomplete-index",
                "native scope and approved task index differ")
    host = snapshot.get("host", {})
    require(isinstance(host, dict), "no-subagent-capability", "host capability evidence missing")
    if tasks:
        require(host.get("delivery_capable") is True, "no-subagent-capability", "delivery-capable subagent required")
    host_cap = positive(host.get("max_parallel", 1))
    ordered_tasks = sorted(tasks, key=lambda task: task["task_id"]) if mode == "issues" else tasks
    fingerprint_tasks = sorted(tasks, key=lambda task: task["task_id"])
    immutable_tasks = [{k: v for k, v in task.items() if k != "existing_delivery"}
                       for task in fingerprint_tasks]
    binding = {"mode": mode, "selector_url": selector, "canonical_repo": canonical,
               "scope": scope if mode != "issues" else {"selector_urls": selector_urls},
               "repository_rules": snapshot["repository_rules"], "integration_branch": integration["branch"],
               "tasks": immutable_tasks, "edges": copy.deepcopy(edges),
               "edge_provenance": copy.deepcopy(edges), "graph": copy.deepcopy(graph),
               "containers": [by_url[url] for url in sorted(containers)]}
    if mode != "issues":
        binding["specification"] = snapshot["specification"]
    if mode == "project":
        binding["lifecycle"] = snapshot["lifecycle"]
    return {**binding, "status": "admitted" if tasks else "no-work", "tasks": ordered_tasks,
            "fingerprint": digest(binding), "integration": integration, "max_parallel": limit,
            "selector_urls": selector_urls, "task_order": task_order,
            "parent_prs": copy.deepcopy(snapshot.get("parent_prs", {})),
            "host_cap": host_cap, "notice": "Host runs sequential subagents (concurrency one)." if host_cap == 1 else None}


def git(repo, *args, allow_missing=False):
    try:
        result = subprocess.run(["git", "-C", str(repo), *args], capture_output=True, timeout=30)
    except (OSError, subprocess.SubprocessError) as error:
        raise InputError("git-unavailable", str(error)) from error
    if allow_missing and result.returncode:
        return None
    require(result.returncode == 0, "git-evidence", result.stderr.decode(errors="replace").strip())
    return result.stdout


def repository(repo, canonical):
    require(repo is not None, "git-unavailable", "--git-repo is required")
    remote_urls = git(repo, "remote", "-v").decode().splitlines()
    matches = []
    for line in remote_urls:
        parts = line.split()
        if len(parts) >= 2:
            url = parts[1].removesuffix(".git").rstrip("/")
            if url.startswith("git@github.com:"):
                url = "https://github.com/" + url.split(":", 1)[1]
            matches.append(url)
    require(canonical in matches, "foreign-repository", "Git remote does not match admitted repository")
    common = Path(git(repo, "rev-parse", "--path-format=absolute", "--git-common-dir").decode().strip())
    return common.parent.resolve()


def branch_tip(repo, branch):
    require(text(branch), "invalid-branch", "branch name required")
    git(repo, "check-ref-format", "--branch", branch)
    result = git(repo, "rev-parse", "--verify", "refs/heads/" + branch + "^{commit}", allow_missing=True)
    return result.decode().strip() if result else None


def contains(repo, ancestor, head):
    require(SHA_RE.fullmatch(ancestor or "") and SHA_RE.fullmatch(head or ""),
            "git-evidence", "full commit SHAs required")
    git(repo, "cat-file", "-e", ancestor + "^{commit}")
    git(repo, "cat-file", "-e", head + "^{commit}")
    try:
        result = subprocess.run(["git", "-C", str(repo), "merge-base", "--is-ancestor", ancestor, head],
                                capture_output=True, timeout=30)
    except (OSError, subprocess.SubprocessError) as error:
        raise InputError("git-unavailable", str(error)) from error
    require(result.returncode in (0, 1), "git-evidence", "ancestry check failed")
    return result.returncode == 0


def worktree_inventory(repo):
    records, item = [], {}
    for line in git(repo, "worktree", "list", "--porcelain", "-z").decode().split("\0") + [""]:
        if not line:
            if item:
                records.append(item)
                item = {}
        else:
            key, _, value = line.partition(" ")
            item[key] = value
    return records


def overlaps(left, right):
    left, right = Path(left).resolve(), Path(right).resolve()
    return left == right or left in right.parents or right in left.parents


def new_state(admitted):
    return {"fingerprint": admitted["fingerprint"], "halt_new_dispatch": False, "halt_reason": None,
            "tasks": {t["task_id"]: {"status": "pending", "reservation": None,
                                      "delivery": None, "report": None, "verified_pr": None,
                                      "parent_decision": None} for t in admitted["tasks"]}}


def state_read(path, admitted):
    state = load_json(path)
    require(state.get("fingerprint") == admitted["fingerprint"], "state-mismatch", "state belongs to another scope")
    require(isinstance(state.get("tasks"), dict) and set(state["tasks"]) == {t["task_id"] for t in admitted["tasks"]},
            "invalid-state", "state task identities differ")
    require(type(state.get("halt_new_dispatch")) is bool, "invalid-state", "halt state must be explicit")
    for item in state["tasks"].values():
        require(isinstance(item, dict) and item.get("status") in
                ("pending", "running", "delivered", "repair-ready", "unknown"), "invalid-state", "invalid task state")
        if item["status"] != "pending":
            require(isinstance(item.get("reservation"), dict), "invalid-state", "reservation missing")
            reservation = item["reservation"]
            require(all(text(reservation.get(k)) for k in ("branch", "workspace", "parent_branch", "parent_sha"))
                    and SHA_RE.fullmatch(reservation["parent_sha"])
                    and Path(reservation["workspace"]).is_absolute(),
                    "invalid-state", "reservation identity incomplete")
    return state


def halt(state, item, reason, report=None):
    if isinstance(item.get("reservation"), dict):
        item["status"] = "unknown"
    if isinstance(report, dict):
        item["report"] = report
    state["halt_new_dispatch"] = True
    state["halt_reason"] = reason
    return {"status": "halted", "reason": reason, "dispatch": []}


def field_object(value, fields, name):
    require(isinstance(value, dict), "unknown-response", name + " evidence missing")
    require(all(k in value and value[k] is not None and value[k] != "" for k in fields),
            "unknown-response", name + " evidence incomplete")
    return value


def review_readback(value, head, label):
    field_object(value, ("head_sha", "complete", "items"), label)
    require(value["head_sha"] == head and value["complete"] is True
            and isinstance(value["items"], list)
            and all(isinstance(item, dict) and item.get("id") for item in value["items"]),
            "incomplete-pr-readback", label + " must be fully paginated at the current head")
    if label == "reviews":
        require(all(item.get("commit_id") == head for item in value["items"]),
                "stale-review", "reviews must describe the current PR head")


def parent_pr_evidence(scope, branch, head, checkpoint=None):
    if checkpoint is not None:
        readback = checkpoint["readback"]
        evidence = {"repo": scope["canonical_repo"], "branch": branch, "head_sha": head,
                    "complete": True, "prs": [{**readback, "state": "open"}]}
    else:
        require(isinstance(scope["parent_prs"], dict), "parent-pr-evidence", "parent PR reads missing")
        evidence = scope["parent_prs"].get(branch)
    field_object(evidence, ("repo", "branch", "head_sha", "complete", "prs"), "parent PR discovery")
    require(evidence["repo"] == scope["canonical_repo"] and evidence["branch"] == branch
            and evidence["head_sha"] == head and evidence["complete"] is True
            and isinstance(evidence["prs"], list) and len(evidence["prs"]) <= 1,
            "parent-pr-evidence", "canonical parent PR discovery is incomplete or ambiguous")
    for pr in evidence["prs"]:
        field_object(pr, ("pr_url", "repo", "head_repo", "branch", "head_sha", "base_branch",
                          "state", "reviews", "threads"), "parent PR")
        match = PR_RE.fullmatch(pr["pr_url"])
        require(match and "https://github.com/" + "/".join(match.groups()[:2]) == scope["canonical_repo"]
                and pr["repo"] == pr["head_repo"] == scope["canonical_repo"] and pr["branch"] == branch
                and pr["head_sha"] == head and pr["state"] in ("open", "closed", "merged"),
                "parent-pr-evidence", "parent PR identity differs")
        review_readback(pr["reviews"], head, "reviews")
        review_readback(pr["threads"], head, "threads")
    return copy.deepcopy(evidence)


def parent_readiness(scope, task, state, reservation, decision, repo, retained=False):
    require(not task["external_prerequisites"], "external-prerequisite", "retained task has external blockers")
    predecessors = []
    for tid in task["prerequisites"]:
        item = state["tasks"][tid]
        require(item["status"] == "delivered" and isinstance(item.get("delivery"), dict),
                "prerequisites-unmet", "verified delivery missing for " + tid)
        predecessors.append((tid, item["delivery"]))
    branch, head = reservation["parent_branch"], reservation["parent_sha"]
    if decision is not None:
        require(isinstance(decision, dict) and decision.get("branch") == branch and decision.get("sha") == head,
                "decision-rejected", "decision cannot replace the reserved parent")
    selected = next((delivery for _, delivery in predecessors
                     if delivery["branch"] == branch and delivery["head_sha"] == head), None)
    if not predecessors:
        require(branch == scope["integration"]["branch"] and head == scope["integration"]["sha"],
                "unapproved-parent", "root delivery must retain the admitted integration parent")
        kind = "integration"
    elif selected is not None:
        kind = "predecessor"
    elif branch == scope["integration"]["branch"] and head == scope["integration"]["sha"]:
        kind = "integration"
    else:
        require(isinstance(decision, dict) and decision.get("branch") == branch and decision.get("sha") == head,
                "unapproved-parent", "retained integration choice requires its explicit approved decision")
        kind = "explicit"
    current = branch_tip(repo, branch)
    require(current is not None and (contains(repo, head, current) if retained else current == head),
            "parent-tip-drift", "selected parent changed incompatibly")
    proof = parent_pr_evidence(scope, branch, current, selected["checkpoint"] if selected is not None else None)
    records = []
    for tid, delivery in predecessors:
        require(contains(repo, delivery["head_sha"], head), "uncontained-prerequisite",
                "selected parent does not contain " + tid)
        records.append({"task_id": tid, "issue_url": delivery["association"],
                        "checkpoint": copy.deepcopy(delivery["checkpoint"]),
                        "containment": {"ancestor": delivery["head_sha"], "descendant": head, "verified": True}})
    return {"logical_prerequisites": list(task["prerequisites"]), "external_prerequisites": [],
            "prerequisites": records,
            "parent": {"branch": branch, "sha": head, "current_sha": current, "selection": kind, "pr_evidence": proof},
            "decision": copy.deepcopy(decision) if kind == "explicit" else None}


def validate_delivery(admitted, task, reservation, result, repo):
    require(result.get("outcome") in ("ok", "needs-repair"), "unknown-response", "worker outcome unknown")
    worker = field_object(result.get("worker"), ("worker_id", "pr_url", "branch", "head_sha",
                          "base_branch", "commit_sha", "association"), "worker")
    readback = field_object(result.get("readback"), ("repo", "head_repo", "pr_url", "branch", "head_sha",
                            "base_branch", "commit_sha", "association", "closing_references", "open", "draft",
                            "unique", "diff_identity", "reviews", "threads"), "readback")
    require(text(worker["worker_id"]), "invalid-worker", "native host worker identity required")
    for key in ("pr_url", "branch", "head_sha", "base_branch", "commit_sha", "association"):
        require(worker[key] == readback[key], "evidence-mismatch", "worker/readback disagree on " + key)
    require(readback["repo"] == admitted["canonical_repo"] == readback["head_repo"],
            "foreign-repo", "PR repository mismatch")
    match = PR_RE.fullmatch(readback["pr_url"])
    require(match is not None and "https://github.com/" + "/".join(match.groups()[:2]) == admitted["canonical_repo"],
            "invalid-pr", "canonical PR identity required")
    require(readback["open"] is True and readback["unique"] is True, "pr-not-unique-open", "one open PR required")
    require(readback["draft"] is True, "draft-required", "orchestrated delivery must remain a draft")
    review_readback(readback["reviews"], readback["head_sha"], "reviews")
    review_readback(readback["threads"], readback["head_sha"], "threads")
    require(readback["branch"] == reservation["branch"], "wrong-branch", "PR head is not reserved branch")
    require(readback["base_branch"] == reservation["parent_branch"], "wrong-base", "PR base is not admitted parent")
    require(readback["association"] == task["url"] and readback["closing_references"] == [task["url"]],
            "wrong-association", "exactly the task issue may be a closing reference")
    require(readback["commit_sha"] == readback["head_sha"] == branch_tip(repo, reservation["branch"]),
            "wrong-head", "commit and actual branch head must agree")
    require(contains(repo, reservation["parent_sha"], readback["head_sha"]),
            "wrong-ancestry", "admitted start is not an ancestor")
    inventory = worktree_inventory(repo)
    owned = [wt for wt in inventory if wt.get("branch") == "refs/heads/" + reservation["branch"]]
    require(len(owned) == 1 and Path(owned[0]["worktree"]).resolve() == Path(reservation["workspace"]).resolve(),
            "workspace-mismatch", "delivered branch must have exactly its reserved worktree")
    actual_diff = "sha256:" + hashlib.sha256(git(repo, "diff", "--no-ext-diff", "--no-textconv",
                                                "--no-color", "--binary",
                                                reservation["parent_sha"], readback["head_sha"])).hexdigest()
    require(readback["diff_identity"] == actual_diff, "diff-mismatch", "PR diff differs from Git evidence")
    checks = field_object(result.get("checks"), ("passed", "commands", "head_sha", "diff_identity", "smoke"), "checks")
    validation = field_object(result.get("validation"), ("verdict", "reviewer_id", "diff_identity", "contract_hash", "checked_head"), "validation")
    require(checks["head_sha"] == validation["checked_head"] == readback["head_sha"],
            "stale-validation", "verification/review head mismatch")
    require(checks["diff_identity"] == validation["diff_identity"] == actual_diff,
            "diff-mismatch", "verification/review diff mismatch")
    require(validation["contract_hash"] == task["contract_hash"], "contract-mismatch", "reviewed contract differs")
    require(text(validation["reviewer_id"]) and validation["reviewer_id"] != worker["worker_id"],
            "self-review", "validator must be independent of implementation")
    require(checks["commands"] == task["contract"]["checks"] and checks["smoke"] == task["contract"]["smoke"],
            "checks-incomplete", "all mandatory checks and smoke must be observed")
    require(type(checks["passed"]) is bool and validation["verdict"] in ("pass", "fail"),
            "unknown-response", "verification/review outcome malformed")
    if result["outcome"] == "needs-repair" or not checks["passed"] or validation["verdict"] == "fail":
        return {"status": "repair-ready", "reason": "checks-failed" if not checks["passed"] else "validation-failed"}
    note = field_object(result.get("note"), ("id", "issue_url", "pr_url", "head_sha", "contract_hash", "diff_identity"), "delivery note readback")
    require(text(note["id"]) or (type(note["id"]) is int and note["id"] > 0),
            "invalid-note", "native note identity required")
    for key, expected in (("issue_url", task["url"]), ("pr_url", readback["pr_url"]),
                          ("head_sha", readback["head_sha"]), ("contract_hash", task["contract_hash"]), ("diff_identity", actual_diff)):
        require(note[key] == expected, "note-mismatch", "delivery note differs on " + key)
    if admitted["mode"] == "project":
        progress = field_object(result.get("project_status"), ("project_url", "issue_url", "item_id", "status"), "Project status readback")
        require(progress["item_id"] == task["item_id"] and progress["project_url"] == admitted["selector_url"]
                and progress["issue_url"] == task["url"]
                and progress["status"] == admitted["lifecycle"]["inReview"],
                "project-status-mismatch", "verified Project inReview readback required")
    return {"status": "delivered", "delivery": {"pr_url": readback["pr_url"], "head_sha": readback["head_sha"],
            "branch": readback["branch"], "base_branch": readback["base_branch"], "commit_sha": readback["commit_sha"],
            "association": task["url"], "validated_diff": actual_diff, "contract_hash": task["contract_hash"],
            "checkpoint": copy.deepcopy(result)}}

def packet(admitted, task, reservation, repair, retained, readiness):
    specification = task.get("specification", admitted.get("specification"))
    require(text(specification), "malformed-contract", "worker specification context missing")
    return {"task_id": task["task_id"], "ordinal": task["ordinal"], "child_issue_url": task["url"],
            "scope_url": admitted["selector_url"],
            "parent_issue_url": admitted["selector_url"] if admitted["mode"] == "issue" else
            task.get("actual_parent"),
            "specification": specification, "repository_rules": admitted["repository_rules"],
            "bounded_input": copy.deepcopy(task["contract"]), "acceptance": task["contract"]["acceptance"],
            "parent_readiness": readiness,
            "dependency_edges": copy.deepcopy(task.get("edge_provenance", [])),
            "graph": copy.deepcopy(admitted.get("graph", {})),
            "checks": task["contract"]["checks"], "contract_hash": task["contract_hash"],
            "execute_skill": "woostack-execute", "repair": repair, "retained_pr": retained, **reservation}


def choose_parent(admitted, task, state, decisions, repo):
    if not task["prerequisites"]:
        candidates = [admitted["integration"]]
    elif task["task_id"] in decisions:
        candidates = [decisions[task["task_id"]]]
    else:
        candidates = [{"branch": state["tasks"][p]["delivery"]["branch"],
                       "sha": state["tasks"][p]["delivery"]["head_sha"]} for p in task["prerequisites"]]
        candidates.append(admitted["integration"])
    heads = [state["tasks"][p]["delivery"]["head_sha"] for p in task["prerequisites"]]
    for candidate in candidates:
        require(isinstance(candidate, dict) and text(candidate.get("branch")) and SHA_RE.fullmatch(candidate.get("sha", "")),
                "decision-rejected", "parent decision needs branch and full SHA")
        if branch_tip(repo, candidate["branch"]) != candidate["sha"]:
            continue
        if all(contains(repo, head, candidate["sha"]) for head in heads):
            return candidate
    return None
def cmd_admit(args):
    selected = [bool(args.issue), bool(args.project), bool(args.issues)]
    require(sum(selected) == 1, "conflicting-selectors" if any(selected) else "missing-selector",
            "select exactly one scope")
    if args.issues:
        return admit(load_json(args.snapshot), "issues", args.issues, positive(args.max_parallel))
    return admit(load_json(args.snapshot), "issue" if args.issue else "project",
                 args.issue or args.project, positive(args.max_parallel))




def cmd_schedule(args):
    admitted = load_json(args.admitted)
    require(admitted.get("status") in ("admitted", "no-work"), "not-admitted", "admission required")
    root = repository(args.git_repo, admitted["canonical_repo"])
    state = state_read(args.state, admitted) if args.state else new_state(admitted)
    if not args.state:
        require(not Path(args.state_out).exists(), "existing-state", "initial state already exists; resume it")
    try:
        selected = admitted.get("selector_urls") if admitted["mode"] == "issues" else admitted["selector_url"]
        fresh = admit(load_json(args.fresh), admitted["mode"], selected, admitted["max_parallel"])
        require(fresh["fingerprint"] == admitted["fingerprint"], "snapshot-drift", "scope/native identity/contract changed")
        require(fresh["integration"] == admitted["integration"], "parent-tip-drift", "integration tip requires readmission")
    except InputError as error:
        state["halt_new_dispatch"], state["halt_reason"] = True, error.code
        write_json(args.state_out, state)
        return {"status": "snapshot-drift", "reason": error.code, "dispatch": []}
    if state["halt_new_dispatch"]:
        write_json(args.state_out, state)
        return {"status": "halted", "reason": state["halt_reason"], "dispatch": []}
    decisions = {}
    if args.parent_decision:
        entries = load_json(args.parent_decision).get("decisions")
        require(isinstance(entries, list), "malformed-decision", "decisions list required")
        for decision in entries:
            require(isinstance(decision, dict) and decision.get("task_id") in state["tasks"]
                    and decision["task_id"] not in decisions, "malformed-decision", "ambiguous parent decision")
            decisions[decision["task_id"]] = decision
    # Delivery is imported/revalidated from fresh independent evidence, never a saved success flag.
    fresh_tasks = {t["task_id"]: t for t in fresh["tasks"]}
    for tid in fresh["task_order"]:
        task = fresh_tasks[tid]
        item = state["tasks"][task["task_id"]]
        retained = task.get("existing_delivery")
        if item["status"] == "delivered" or (item["status"] == "pending" and retained is not None):
            try:
                field_object(retained, ("reservation", "result"), "existing delivery")
                reservation = retained["reservation"]
                if item["reservation"] is not None:
                    require(reservation == item["reservation"], "reservation-mismatch", "retained workspace/parent changed")
                expected_workspace = (root / task["workspace"]).resolve()
                require(Path(reservation["workspace"]).resolve() == expected_workspace,
                        "reservation-mismatch", "retained workspace does not match admitted task")
                require(reservation["branch"] == "woostack/" + task["task_id"], "reservation-mismatch", "retained branch differs")
                decision = decisions.get(tid) or item.get("parent_decision")
                parent_readiness(fresh, task, state, reservation, decision, args.git_repo, retained=True)
                proof = validate_delivery(admitted, task, reservation, retained["result"], args.git_repo)
                require(proof["status"] == "delivered", "delivery-invalidated", "retained delivery no longer verified")
                require(not any(tid != task["task_id"] and other.get("verified_pr") == proof["delivery"]["pr_url"]
                                for tid, other in state["tasks"].items()),
                        "duplicate-pr", "retained deliveries claim the same PR")
                item.update(status="delivered", reservation=reservation, delivery=proof["delivery"],
                            report=retained["result"]["worker"], verified_pr=proof["delivery"]["pr_url"],
                            parent_decision=copy.deepcopy(decision))
            except (InputError, KeyError, TypeError) as error:
                reason = getattr(error, "code", "invalid-retained-delivery")
                if item["reservation"] is None and isinstance(retained, dict):
                    item["reservation"] = retained.get("reservation")
                outcome = halt(state, item, reason)
                write_json(args.state_out, state)
                return outcome
    cap = min(positive(args.cap) if args.cap is not None else admitted["max_parallel"],
              admitted["max_parallel"], fresh["host_cap"])
    running = [tid for tid, item in state["tasks"].items() if item["status"] == "running"]
    slots = max(0, cap - len(running))
    dispatch, paused, blocked, waiting = [], [], [], []
    inventory = worktree_inventory(args.git_repo)
    for task in sorted(admitted["tasks"], key=lambda t: (t["ordinal"], t["task_id"])):
        tid, item = task["task_id"], state["tasks"][task["task_id"]]
        if item["status"] not in ("pending", "repair-ready"):
            continue
        if task["external_prerequisites"]:
            blocked.append({"task_id": tid, "reason": "external-prerequisite"})
            continue
        if any(state["tasks"][p]["status"] != "delivered" for p in task["prerequisites"]):
            waiting.append({"task_id": tid, "reason": "prerequisites-unmet"})
            continue
        repair = item["status"] == "repair-ready"
        if repair:
            reservation = item["reservation"]
            require(contains(args.git_repo, reservation["parent_sha"], branch_tip(args.git_repo, reservation["branch"])),
                    "wrong-ancestry", "repair branch no longer contains admitted start")
        else:
            parent = choose_parent(admitted, task, state, decisions, args.git_repo)
            if parent is None:
                paused.append({"task_id": tid, "reason": "join-no-containing-parent",
                               "prerequisite_branches": [state["tasks"][p]["delivery"]["branch"] for p in task["prerequisites"]]})
                continue
            workspace = (root / task["workspace"]).resolve()
            require(root in workspace.parents and workspace != root / ".git" and root / ".git" not in workspace.parents,
                    "invalid-workspace", "workspace escapes repository task area")
            reservation = {"branch": "woostack/" + tid, "workspace": str(workspace),
                           "parent_branch": parent["branch"], "parent_sha": parent["sha"]}
        workspace = reservation["workspace"]
        collision = any(other != tid and other_item.get("reservation")
                        and overlaps(workspace, other_item["reservation"]["workspace"])
                        for other, other_item in state["tasks"].items())
        if not repair:
            collision = collision or Path(workspace).exists() or branch_tip(args.git_repo, reservation["branch"]) is not None
            collision = collision or any(overlaps(workspace, wt["worktree"]) and Path(wt["worktree"]).resolve() != root for wt in inventory)
        else:
            collision = collision or not any(Path(wt["worktree"]).resolve() == Path(workspace).resolve()
                and wt.get("branch") == "refs/heads/" + reservation["branch"] for wt in inventory)
        if collision:
            blocked.append({"task_id": tid, "reason": "workspace-collision"})
            continue
        if slots == 0:
            continue
        retained_pr = item.get("verified_pr")
        decision = decisions.get(tid) or item.get("parent_decision")
        readiness = parent_readiness(fresh, task, state, reservation, decision, args.git_repo, retained=repair)
        item.update(status="running", reservation=reservation, parent_decision=copy.deepcopy(decision))
        dispatch.append({"task_id": tid, "ordinal": task["ordinal"], "child_url": task["url"],
                         "repair": repair, "retained_pr": retained_pr, **reservation,
                         "packet": packet(admitted, task, reservation, repair, retained_pr, readiness)})
        running.append(tid)
        slots -= 1
    write_json(args.state_out, state)
    return {"status": "no-work" if not admitted["tasks"] else "ok", "effective_cap": cap,
            "notice": fresh["notice"], "dispatch": dispatch, "paused": paused, "blocked": blocked,
            "waiting": waiting, "running": sorted(running),
            "delivered": sorted(t for t, item in state["tasks"].items() if item["status"] == "delivered")}


def cmd_apply_result(args):
    admitted = load_json(args.admitted)
    repository(args.git_repo, admitted["canonical_repo"])
    state = state_read(args.state, admitted)
    require(args.task in state["tasks"], "unknown-task", "task outside admitted scope")
    item = state["tasks"][args.task]
    require(item["status"] == "running", "not-running", "task has no active reservation")
    task = next(t for t in admitted["tasks"] if t["task_id"] == args.task)
    result = {}
    try:
        result = load_json(args.result)
        proof = validate_delivery(admitted, task, item["reservation"], result, args.git_repo)
        pr_url = result["worker"]["pr_url"]
        require(not any(tid != args.task and other.get("verified_pr") == pr_url
                        for tid, other in state["tasks"].items()), "duplicate-pr", "another task already owns this PR")
        retained_pr = item.get("verified_pr")
        if retained_pr:
            require(retained_pr == pr_url, "pr-replaced", "repair must preserve existing PR")
        item["report"] = result["worker"]
        item["verified_pr"] = pr_url
        item["status"] = proof["status"]
        if proof["status"] == "delivered":
            item["delivery"] = proof["delivery"]
        outcome = {"task_id": args.task, **proof}
    except (InputError, KeyError, TypeError, ValueError) as error:
        outcome = halt(state, item, getattr(error, "code", "unknown-response"), result.get("worker"))
    write_json(args.state_out, state)
    return outcome


def cmd_reconcile(args):
    admitted = load_json(args.admitted)
    repository(args.git_repo, admitted["canonical_repo"])
    state = state_read(args.state, admitted)
    require(args.task in state["tasks"], "unknown-task", "task outside admitted scope")
    item = state["tasks"][args.task]
    require(item["status"] == "unknown", "not-unknown", "task has no uncertain outcome")
    evidence = load_json(args.evidence)
    reservation = item["reservation"]
    require(evidence.get("worker_stopped") is True, "worker-liveness", "old writer must be proved stopped")
    require(evidence.get("repo") == evidence.get("head_repo") == admitted["canonical_repo"],
            "foreign-repo", "canonical repository readback required")
    require(evidence.get("branch") == reservation["branch"]
            and evidence.get("base_branch") == reservation["parent_branch"]
            and evidence.get("head_sha") == branch_tip(args.git_repo, reservation["branch"])
            and evidence.get("unique") is True, "evidence-mismatch", "branch/head/base discovery conflicts")
    require(contains(args.git_repo, reservation["parent_sha"], evidence["head_sha"]),
            "wrong-ancestry", "retained branch ancestry differs")
    if evidence.get("pr_absent") is True:
        require("pr_url" in evidence and evidence["pr_url"] is None and evidence.get("open") is False,
                "evidence-mismatch", "PR absence requires an explicit null URL and closed readback")
        require(not item.get("verified_pr"), "evidence-mismatch", "verified PR cannot silently disappear")
    else:
        match = PR_RE.fullmatch(evidence.get("pr_url", ""))
        require(match and "https://github.com/" + "/".join(match.groups()[:2]) == admitted["canonical_repo"]
                and evidence.get("open") is True, "invalid-pr", "one canonical open PR required")
        require(not item.get("verified_pr") or item["verified_pr"] == evidence["pr_url"],
                "evidence-mismatch", "retained PR differs")
        item["report"] = {"pr_url": evidence["pr_url"], "head_sha": evidence["head_sha"]}
        item["verified_pr"] = evidence["pr_url"]
    item["status"] = "repair-ready"
    if not any(t["status"] == "unknown" for t in state["tasks"].values()):
        state["halt_new_dispatch"], state["halt_reason"] = False, None
    write_json(args.state_out, state)
    return {"status": "reconciled", "task_id": args.task,
            "detail": "Same task retained; full apply-result gates still required."}


def parser():
    root = argparse.ArgumentParser(description=__doc__)
    commands = root.add_subparsers(dest="command", required=True)
    admission = commands.add_parser("admit")
    admission.add_argument("--issue")
    admission.add_argument("--issues", nargs="+")
    admission.add_argument("--project")
    admission.add_argument("--snapshot", required=True)
    admission.add_argument("--max-parallel", default=str(DEFAULT_MAX_PARALLEL))
    admission.set_defaults(run=cmd_admit)
    for name, handler in (("schedule", cmd_schedule), ("apply-result", cmd_apply_result), ("reconcile", cmd_reconcile)):
        command = commands.add_parser(name)
        command.add_argument("--admitted", required=True)
        command.add_argument("--state", required=name != "schedule")
        command.add_argument("--state-out", required=True)
        command.add_argument("--git-repo", required=True)
        if name == "schedule":
            command.add_argument("--fresh", required=True)
            command.add_argument("--cap")
            command.add_argument("--parent-decision")
        else:
            command.add_argument("--task", required=True)
            command.add_argument("--result" if name == "apply-result" else "--evidence", required=True)
        command.set_defaults(run=handler)
    return root


def main():
    args = parser().parse_args()
    try:
        result = args.run(args)
        print(json.dumps({"ok": True, **result}, indent=2, sort_keys=True))
        return 0
    except (InputError, OSError, KeyError, TypeError, ValueError) as error:
        print(json.dumps({"ok": False, "error": getattr(error, "code", "malformed-input"), "message": str(error)}))
        return 1


if __name__ == "__main__":
    sys.exit(main())
