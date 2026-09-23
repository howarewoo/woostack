#!/usr/bin/env python3
"""Session-local orchestration gates; the skill supplies fresh gh/host evidence.

This is the production scheduling path. It never calls a provider or implements
source. The controller dispatches emitted packets through its native host, then
returns independent GitHub, verification, review, and progress readbacks. Git
identity, ancestry, worktree ownership, and diff hashes are checked here directly.
"""
import argparse
import copy
from graphlib import CycleError, TopologicalSorter
import hashlib
import json
import os
import fcntl
from pathlib import Path
import re
import secrets
import subprocess
import sys
import tempfile

DEFAULT_MAX_PARALLEL = 3
STATE_VERSION = 2
CLAIM_DIRECTORY = (".woostack", "tmp", "orchestrate-claims")

ISSUE_RE = re.compile(r"https://github\.com/([\w.-]+)/([\w.-]+)/issues/([1-9][0-9]*)\Z")
PR_RE = re.compile(r"https://github\.com/([\w.-]+)/([\w.-]+)/pull/([1-9][0-9]*)\Z")
PROJECT_RE = re.compile(r"https://github\.com/(orgs|users)/([\w.-]+)/projects/([1-9][0-9]*)\Z")
REPO_RE = re.compile(r"https://github\.com/([\w.-]+)/([\w.-]+)\Z")
TASK_RE = re.compile(r"[^\x00-\x1f\x7f]+")
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


def _json_bytes(value):
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode()


def _fsync_parent(path):
    try:
        descriptor = os.open(Path(path).parent, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    except OSError as error:
        raise InputError("state-directory", str(error)) from error
    try:
        info = os.fstat(descriptor)
        require((info.st_mode & 0o170000) == 0o40000,
                "unsafe-state", "state parent must be a directory")
        os.fsync(descriptor)
    except OSError as error:
        raise InputError("state-directory", str(error)) from error
    finally:
        os.close(descriptor)


def write_json(path, value):
    destination = Path(path)
    require(not destination.is_symlink(), "unsafe-state", "state cannot be a symlink")
    if destination.exists():
        info = destination.lstat()
        require(info.st_uid == os.getuid() and info.st_nlink == 1
                and destination.is_file() and (info.st_mode & 0o777) == 0o600,
                "unsafe-state", "state destination must be owner-only regular file")
    # A failed write must leave the previous reservations intact.
    descriptor, temporary = tempfile.mkstemp(prefix=destination.name + ".", dir=destination.parent)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(_json_bytes(value))
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, destination)
        _fsync_parent(destination)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def _state_bytes(path):
    require(not Path(path).is_symlink(), "unsafe-state", "state cannot be a symlink")
    try:
        descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    except OSError as error:
        raise InputError("unreadable-state", str(error)) from error
    try:
        info = os.fstat(descriptor)
        require(info.st_uid == os.getuid() and info.st_nlink == 1
                and (info.st_mode & 0o170000) == 0o100000
                and (info.st_mode & 0o777) == 0o600,
                "unsafe-state", "state must be an owner-only regular file")
        with os.fdopen(descriptor, "rb") as stream:
            descriptor = None
            return stream.read()
    finally:
        if descriptor is not None:
            os.close(descriptor)


def _state_digest(path):
    return hashlib.sha256(_state_bytes(path)).hexdigest()


def _checkpoint_pending_path(head_path):
    return head_path.with_name(head_path.name + ".pending.json")


def _optional_state_digest(path):
    destination = Path(path)
    require(not destination.is_symlink(), "unsafe-state", "state cannot be a symlink")
    if not destination.exists():
        return None
    return _state_digest(destination)


def _remove_checkpoint_pending(path):
    if path.is_symlink():
        raise InputError("unsafe-state", "checkpoint recovery record cannot be a symlink")
    if path.exists():
        path.unlink()
        _fsync_parent(path)


def _validated_checkpoint_head(value, label):
    require(isinstance(value, dict)
            and value.get("version") == 1
            and text(value.get("fingerprint"))
            and text(value.get("digest"))
            and SHA_RE.fullmatch(value["digest"])
            and text(value.get("state_path")),
            "invalid-state", label + " is incomplete")
    return value


def _checkpoint_pending(path):
    if path.is_symlink():
        raise InputError("unsafe-state", "checkpoint recovery record cannot be a symlink")
    if not path.exists():
        return None
    try:
        value = json.loads(_state_bytes(path))
    except ValueError as error:
        raise InputError("invalid-state", "checkpoint recovery record is malformed") from error
    require(isinstance(value, dict) and value.get("version") == 1
            and text(value.get("fingerprint"))
            and re.fullmatch(r"sha256:[0-9a-f]{64}", value["fingerprint"])
            and isinstance(value.get("scope_identity"), dict)
            and "prior_head" in value and "next_head" in value and "destination" in value,
            "invalid-state", "checkpoint recovery record is incomplete")
    prior = value["prior_head"]
    if prior is not None:
        _validated_checkpoint_head(prior, "prior checkpoint head")
        require(prior["fingerprint"] == value["fingerprint"]
                and prior.get("scope_identity") == value["scope_identity"],
                "invalid-state", "prior checkpoint head does not match recovery record")
    next_head = _validated_checkpoint_head(value["next_head"], "next checkpoint head")
    require(next_head["fingerprint"] == value["fingerprint"]
            and next_head.get("scope_identity") == value["scope_identity"],
            "invalid-state", "next checkpoint head does not match recovery record")
    destination = value["destination"]
    prior_digest = destination.get("prior_digest") if isinstance(destination, dict) else None
    next_digest = destination.get("next_digest") if isinstance(destination, dict) else None
    require(isinstance(destination, dict) and text(destination.get("path"))
            and destination["path"] == next_head["state_path"]
            and (prior_digest is None or (text(prior_digest) and SHA_RE.fullmatch(prior_digest)))
            and text(next_digest) and SHA_RE.fullmatch(next_digest)
            and next_digest == next_head["digest"],
            "invalid-state", "checkpoint recovery destination is incomplete")
    return value


def _recover_checkpoint(head_path, pending_path, head, expected):
    pending = _checkpoint_pending(pending_path)
    if pending is None:
        return head
    destination = pending["destination"]
    current_digest = _optional_state_digest(destination["path"])
    prior_head = pending["prior_head"]
    next_head = pending["next_head"]
    if head == next_head:
        require(current_digest == destination["next_digest"],
                "checkpoint-recovery", "committed checkpoint bytes are missing")
        _remove_checkpoint_pending(pending_path)
        return head
    if head == prior_head:
        if current_digest == destination["prior_digest"]:
            _remove_checkpoint_pending(pending_path)
            return head
        if current_digest == destination["next_digest"]:
            require(text(expected) and expected == destination["next_digest"],
                    "stale-state", "checkpoint publication is ahead of loaded state")
            write_json(head_path, next_head)
            require(_optional_state_digest(destination["path"]) == destination["next_digest"],
                    "checkpoint-recovery", "checkpoint bytes changed during recovery")
            _remove_checkpoint_pending(pending_path)
            return next_head
    raise InputError("checkpoint-recovery",
                     "checkpoint head and state bytes do not form a committed generation")


def write_state(args, state):
    expected = state.pop("_loaded_digest", None)
    lock_path, head_path = _checkpoint_paths(args, state)
    pending_path = _checkpoint_pending_path(head_path)
    require(not lock_path.is_symlink(), "unsafe-state", "checkpoint lock cannot be a symlink")
    try:
        descriptor = os.open(lock_path, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    except OSError as error:
        raise InputError("state-lock", str(error)) from error
    try:
        info = os.fstat(descriptor)
        require(info.st_uid == os.getuid() and info.st_nlink == 1
                and (info.st_mode & 0o777) == 0o600,
                "unsafe-state", "checkpoint lock must be owner-only")
        fcntl.flock(descriptor, fcntl.LOCK_EX)
        head = _checkpoint_head(head_path)
        head = _recover_checkpoint(head_path, pending_path, head, expected)
        if args.state:
            require(head is not None, "missing-checkpoint",
                    "durable checkpoint head is missing; reconcile before mutation")
            require(text(expected), "stale-state", "loaded controller state digest is missing")
            require(head["fingerprint"] == state["fingerprint"]
                    and head.get("scope_identity") == state["scope_identity"]
                    and head["digest"] == expected,
                    "stale-state", "controller checkpoint changed; reread and reconcile before mutation")
        else:
            require(head is None, "existing-state", "checkpoint already exists; resume it")
        destination = Path(args.state_out).resolve()
        prior_digest = _optional_state_digest(destination)
        next_digest = hashlib.sha256(_json_bytes(state)).hexdigest()
        next_head = {
            "version": 1,
            "fingerprint": state["fingerprint"],
            "scope_identity": copy.deepcopy(state["scope_identity"]),
            "digest": next_digest,
            "state_path": str(destination),
        }
        write_json(pending_path, {
            "version": 1,
            "fingerprint": state["fingerprint"],
            "scope_identity": copy.deepcopy(state["scope_identity"]),
            "prior_head": copy.deepcopy(head),
            "destination": {
                "path": str(destination),
                "prior_digest": prior_digest,
                "next_digest": next_digest,
            },
            "next_head": next_head,
        })
        write_json(args.state_out, state)
        require(_state_digest(args.state_out) == next_digest,
                "checkpoint-recovery", "state bytes changed during publication")
        write_json(head_path, next_head)
        _remove_checkpoint_pending(pending_path)
    finally:
        fcntl.flock(descriptor, fcntl.LOCK_UN)
        os.close(descriptor)


def _claims_root(repo):
    root = Path(repo).resolve()
    current = root
    for component in CLAIM_DIRECTORY:
        current = current / component
        if current.exists():
            require(not current.is_symlink() and current.is_dir(), "unsafe-ownership",
                    "orchestration ownership path must be a directory")
            continue
        try:
            current.mkdir(mode=0o700)
        except FileExistsError:
            require(not current.is_symlink() and current.is_dir(), "unsafe-ownership",
                    "orchestration ownership path must be a directory")
    require(current.stat().st_uid == os.getuid() and current.stat().st_mode & 0o077 == 0,
            "unsafe-ownership", "orchestration ownership directory must be owner-only")
    return current


def _checkpoint_root(repo):
    root = _claims_root(repo).parent / "orchestrate-checkpoints"
    if root.exists():
        require(not root.is_symlink() and root.is_dir(), "unsafe-state",
                "checkpoint path must be a directory")
    else:
        try:
            root.mkdir(mode=0o700)
        except FileExistsError:
            require(not root.is_symlink() and root.is_dir(), "unsafe-state",
                    "checkpoint path must be a directory")
    info = root.stat()
    require(info.st_uid == os.getuid() and info.st_mode & 0o077 == 0,
            "unsafe-state", "checkpoint directory must be owner-only")
    return root


def _checkpoint_paths(args, state):
    root = _checkpoint_root(repository(args.git_repo, state["scope_identity"]["canonical_repo"]))
    fingerprint = state.get("fingerprint", "")
    require(text(fingerprint) and re.fullmatch(r"sha256:[0-9a-f]{64}", fingerprint),
            "invalid-state", "checkpoint fingerprint missing")
    key = fingerprint.split(":", 1)[1]
    return root / (key + ".lock"), root / (key + ".head.json")


def _checkpoint_head(path):
    if not path.exists():
        require(not path.is_symlink(), "unsafe-state", "checkpoint head cannot be a symlink")
        return None
    try:
        value = json.loads(_state_bytes(path))
    except ValueError as error:
        raise InputError("invalid-state", "checkpoint head is malformed") from error
    return _validated_checkpoint_head(value, "checkpoint head")


def _claim_key(admitted, task=None):
    value = {
        "canonical_repo": admitted["canonical_repo"],
        "kind": "task" if task is not None else "scope",
    }
    if task is not None:
        value["issue"] = {"url": task["url"]}
    else:
        value["scope"] = admitted["scope_identity"]
    return digest(value).split(":", 1)[1]


def _claim(repo, admitted, owner, task=None):
    require(text(owner), "ownership-missing", "controller ownership identity required")
    claims = _claims_root(repository(repo, admitted["canonical_repo"]))
    key = _claim_key(admitted, task)
    path = claims / (key + ".json")
    record = {
        "claim_key": key,
        "kind": "task" if task is not None else "scope",
        "canonical_repo": admitted["canonical_repo"],
        "scope": copy.deepcopy(admitted["scope_identity"]),
        "issue_url": task["url"] if task is not None else None,
        "issue_id": task["id"] if task is not None else None,
        "issue_node_id": task["node_id"] if task is not None else None,
        "owner": owner,
    }
    if path.is_symlink():
        raise InputError("unsafe-ownership", "orchestration claim cannot be a symlink")
    try:
        descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    except FileExistsError:
        try:
            existing = load_json(path)
        except InputError as error:
            raise InputError("ownership-conflict", "existing ownership claim is unreadable") from error
        require(existing == record or (
            existing.get("claim_key") == key
            and existing.get("owner") == owner
            and existing.get("canonical_repo") == record["canonical_repo"]
            and existing.get("scope") == record["scope"]
            and existing.get("issue_url") == record["issue_url"]
        ), "ownership-conflict", "task or scope is owned by another controller")
        return existing
    except OSError as error:
        raise InputError("ownership-unavailable", str(error)) from error
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            json.dump(record, stream, indent=2, sort_keys=True)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
    except OSError as error:
        try:
            path.unlink()
        except OSError:
            pass
        raise InputError("ownership-write", str(error)) from error
    return record


def claim_scope(repo, admitted, state):
    record = _claim(repo, admitted, state["owner"]["controller_id"])
    state["scope_claim"] = record
    return record


def claim_task(repo, admitted, task, state, item):
    record = _claim(repo, admitted, state["owner"]["controller_id"], task)
    item["claim"] = record
    return record


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

def recovery_inventory(value):
    require(value is not None, "incomplete-recovery",
            "complete recovery inventory is required")
    require(isinstance(value, dict), "malformed-recovery", "recovery inventory must be an object")
    for key in ("checkpoints", "processes", "sessions", "worktrees", "refs",
                "prs", "contracts", "dependencies"):
        require(key in value and isinstance(value[key], (list, dict)),
                "incomplete-recovery", "recovery inventory is missing " + key)
    return copy.deepcopy(value)



def runtime_workspace(value, root):
    """Resolve a caller/host-selected workspace without prescribing its layout."""
    require(text(value), "invalid-workspace", "runtime workspace is required")
    path = Path(value).expanduser()
    if not path.is_absolute():
        path = Path(root) / path
    path = path.resolve()
    require(path != Path(root).resolve(), "shared-workspace", "primary checkout is not an isolated task workspace")
    return str(path)


def runtime_allocation(snapshot, task_id, root):
    """Return runtime workspace and branch evidence on the selected task."""
    task = next((item for item in snapshot.get("tasks", []) if item.get("task_id") == task_id), None)
    require(isinstance(task, dict), "workspace-unassigned", "runtime task evidence is missing")
    require(text(task.get("branch")), "invalid-branch", "runtime task branch is required")
    workspace = runtime_workspace(task.get("workspace"), root)
    return {"workspace": workspace, "branch": task["branch"]}


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
    coverage = metadata.get("coverage")
    require(text(coverage) and coverage.strip().lower() == "complete",
            "incomplete-graph", "graph coverage must have an explicit complete receipt")
    inference = metadata.get("model_inference")
    require(text(inference) and inference.strip().lower() == "complete",
            "inference-unrun", "model inference must have an explicit complete receipt")
    require(metadata.get("complete") is True,
            "incomplete-graph", "graph read must have an explicit complete receipt")
    if "edge_count" in metadata:
        require(type(metadata["edge_count"]) is int and metadata["edge_count"] == len(edges),
                "incomplete-graph", "graph edge count does not match supplied evidence")
    return {"coverage": coverage.strip().lower(), "model_inference": inference.strip().lower(),
            "source": metadata.get("source", "controller-supplied"),
            "complete": True, "edges": copy.deepcopy(edges)}


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

    def add(raw, default_dependent=None, default_kind=None, default_evidence=None,
            authoritative=True):
        if isinstance(raw, str):
            raw = {"predecessor": raw, "dependent": default_dependent}
        for record in edge_records(raw, default_dependent, default_kind, default_evidence):
            record["_authoritative"] = authoritative
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
                default_evidence={"issue_url": task["url"], "field": "prerequisites"},
                authoritative=False)

    edges, seen, edge_indexes, seen_authoritative = [], {}, {}, {}
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
        authoritative = candidate["_authoritative"]
        previous = seen.get(pair)
        if previous is not None:
            if previous == normalized:
                continue
            if authoritative and not seen_authoritative[pair]:
                edges[edge_indexes[pair]] = normalized
                seen[pair] = normalized
                seen_authoritative[pair] = True
                continue
            if not authoritative and seen_authoritative[pair]:
                continue
            raise InputError("duplicate-edge", "conflicting dependency evidence for " + str(pair))
        seen[pair] = normalized
        edge_indexes[pair] = len(edges)
        seen_authoritative[pair] = authoritative
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
                    edge_indexes[pair] = len(edges)
                    seen_authoritative[pair] = False
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
        scope = {"selector_urls": selector_urls}
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
        require(text(task) and TASK_RE.fullmatch(task), "invalid-identity", "non-empty stable task ID required")
        ordinal = entry.get("ordinal")
        if mode == "issues" and ordinal is None:
            ordinal = index
        require(type(ordinal) is int and ordinal > 0, "malformed-ordinal", "positive ordinal required")
        contract_check(entry.get("contract"))
        if mode == "issues":
            require("prerequisites" in entry and "external_prerequisites" in entry,
                    "incomplete-graph", "selected issue dependency evidence is required")
        elif mode != "issues":
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
        # Workspace and branch are runtime allocation evidence.  They may be
        # supplied by a repository, host, or agent on a fresh refill, but must
        # never become issue/publication identity or snapshot drift.
        record["contract_hash"] = digest(entry["contract"])
        if mode == "issues":
            record["specification"] = entry.get("specification", entry["body"])
            require(text(record["specification"]), "malformed-contract", "selected issue specification missing")
        record["contract_revision"] = record["contract_hash"]
        record["dependency_snapshot"] = {
            "prerequisites": list(record["prerequisites"]),
            "external_prerequisites": list(record["external_prerequisites"]),
        }
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
    host_cap = positive(host.get("max_parallel", 1))
    if tasks:
        require(host.get("delivery_capable") is True, "no-subagent-capability", "delivery-capable subagent required")
    ordered_tasks = sorted(tasks, key=lambda task: task["task_id"]) if mode == "issues" else tasks
    immutable_tasks = []
    for task in sorted(tasks, key=lambda t: t["task_id"]):
        immutable_tasks.append({k: v for k, v in task.items()
                                if k not in ("existing_delivery", "workspace", "branch")})
    scope_identity = {
        "mode": mode,
        "selector_url": selector,
        "canonical_repo": canonical,
        "native_id": scope.get("id") if mode == "issue" else scope.get("node_id"),
        "native_node_id": scope.get("node_id"),
        "number": scope.get("number") if mode == "project" else None,
    }
    binding = {"mode": mode, "selector_url": selector, "canonical_repo": canonical,
               "scope": scope, "scope_identity": scope_identity,
               "repository_rules": snapshot["repository_rules"], "integration_branch": integration["branch"],
               "tasks": immutable_tasks, "edges": copy.deepcopy(edges),
               "edge_provenance": copy.deepcopy(edges), "graph": copy.deepcopy(graph),
               "containers": [by_url[url] for url in sorted(containers)]}
    if mode != "issues":
        binding["specification"] = snapshot["specification"]
    if mode == "project":
        binding["lifecycle"] = snapshot["lifecycle"]
    recovery = recovery_inventory(snapshot.get("recovery", snapshot.get("inventory")))
    return {**binding, "status": "admitted" if tasks else "no-work", "tasks": ordered_tasks,
            "fingerprint": digest(binding), "integration": integration, "max_parallel": limit,
            "selector_urls": selector_urls, "task_order": task_order,
            "parent_prs": copy.deepcopy(snapshot.get("parent_prs", {})),
            "host_cap": host_cap, "recovery": recovery,
            "notice": "Host runs sequential subagents (concurrency one)." if host_cap == 1 else None}


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



def remote_matches(path, canonical):
    output = git(path, "remote", "-v", allow_missing=True)
    if output is None:
        return False
    matches = []
    for line in output.decode().splitlines():
        parts = line.split()
        if len(parts) >= 2:
            url = parts[1].removesuffix(".git").rstrip("/")
            if url.startswith("git@github.com:"):
                url = "https://github.com/" + url.split(":", 1)[1]
            matches.append(url)
    return canonical in matches


def workspace_identity(repo, canonical, workspace, branch):
    """Read the selected linked checkout's repository, branch, and HEAD."""
    path = Path(workspace).resolve()
    common_dir = Path(git(repo, "rev-parse", "--path-format=absolute", "--git-common-dir")
                      .decode().strip()).resolve()
    require(path.exists() and path.is_dir(), "workspace-missing",
            "selected task workspace does not exist")
    top = git(path, "rev-parse", "--show-toplevel", allow_missing=True)
    require(top is not None, "workspace-repository", "selected workspace is not a Git checkout")
    top_path = Path(top.decode().strip()).resolve()
    require(top_path == path, "workspace-mismatch", "selected path is not the checkout root")
    selected_common = Path(git(path, "rev-parse", "--path-format=absolute", "--git-common-dir")
                           .decode().strip()).resolve()
    selected_git_dir = Path(git(path, "rev-parse", "--path-format=absolute", "--git-dir")
                            .decode().strip()).resolve()
    require(selected_common == common_dir and selected_git_dir != selected_common,
            "workspace-not-linked", "selected workspace is not a linked checkout of the canonical repository")
    require(any(Path(item["worktree"]).resolve() == path for item in worktree_inventory(repo)),
            "workspace-not-linked", "selected workspace is absent from canonical worktree inventory")
    require(remote_matches(path, canonical), "foreign-repository",
            "selected workspace remote does not match the admitted repository")
    actual_branch = git(path, "branch", "--show-current").decode().strip()
    require(actual_branch == branch, "wrong-branch",
            "selected workspace is not checked out on the selected task branch")
    head = git(path, "rev-parse", "HEAD").decode().strip()
    require(SHA_RE.fullmatch(head) is not None, "git-evidence",
            "selected workspace HEAD is not a full commit SHA")
    return {"workspace": str(path), "branch": actual_branch, "head_sha": head}


def fresh_workspace_state(workspace, parent_sha, head_sha):
    """Allow fresh dispatch only for an untouched checkout at its selected parent."""
    require(head_sha == parent_sha, "workspace-unclaimed",
            "existing task workspace contains commits without task ownership evidence")
    status = git(workspace, "status", "--porcelain=v2", "--untracked-files=all").decode()
    require(not status, "workspace-unclaimed",
            "existing task workspace contains uncommitted or conflicted changes without task ownership evidence")


def allocation_collision(repo, canonical, allocation, inventory, state, task_id):
    workspace = Path(allocation["workspace"]).resolve()
    branch = allocation["branch"]
    git(repo, "check-ref-format", "--branch", branch)
    primary = Path(git(repo, "rev-parse", "--path-format=absolute", "--git-common-dir")
                   .decode().strip()).resolve().parent
    for other, item in state["tasks"].items():
        if other != task_id and item.get("reservation"):
            reservation = item["reservation"]
            if reservation.get("branch") == branch:
                return "branch-reservation-collision"
            if overlaps(workspace, reservation["workspace"]):
                return "workspace-alias-collision"
    matching_paths = [Path(wt["worktree"]).resolve() for wt in inventory]
    for wt in inventory:
        wt_path = Path(wt["worktree"]).resolve()
        if wt_path != primary and overlaps(workspace, wt_path) and wt_path != workspace:
            return "workspace-alias-collision"
        if wt.get("branch") == "refs/heads/" + branch and wt_path != workspace:
            return "branch-checkout-collision"
    known_branch = branch_tip(repo, branch)
    if known_branch is not None and workspace not in matching_paths:
        return "branch-already-exists"
    if workspace.exists():
        if workspace.is_file():
            return "workspace-collision"
        top = git(workspace, "rev-parse", "--show-toplevel", allow_missing=True)
        if top is None:
            try:
                if any(workspace.iterdir()):
                    return "workspace-collision"
            except OSError:
                return "workspace-collision"
        else:
            try:
                workspace_identity(repo, canonical, workspace, branch)
            except InputError as error:
                return error.code
    return None

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
    return {
        "version": STATE_VERSION,
        "fingerprint": admitted["fingerprint"],
        "scope_identity": copy.deepcopy(admitted["scope_identity"]),
        "owner": {"controller_id": secrets.token_hex(16)},
        "scope_claim": None,
        "halt_new_dispatch": False,
        "halt_reason": None,
        "stop_requested": False,
        "recovery": {
            "last_snapshot": None,
            "last_inventory": copy.deepcopy(admitted.get("recovery")),
            "first_uncertain_boundary": None,
        },
        "tasks": {
            t["task_id"]: {
                "status": "pending",
                "reservation": None,
                "claim": None,
                "delivery": None,
                "report": None,
                "verified_pr": None,
                "parent_decision": None,
                "contract_hash": t["contract_hash"],
                "contract_revision": t.get("contract_revision", t["contract_hash"]),
                "dependency_snapshot": copy.deepcopy(t.get("dependency_snapshot", {
                    "prerequisites": t["prerequisites"],
                    "external_prerequisites": t["external_prerequisites"],
                })),
                "source": None,
                "diff_identity": None,
                "checks": None,
                "validation": None,
                "pr": None,
                "first_uncertain_boundary": None,
                "last_evidence": None,
            } for t in admitted["tasks"]
        },
    }


def state_read(path, admitted):
    try:
        raw = _state_bytes(path)
        state = json.loads(raw)
    except ValueError as error:
        raise InputError("unreadable-state", str(error)) from error
    require(isinstance(state, dict), "malformed-input", "JSON must be an object")
    state["_loaded_digest"] = hashlib.sha256(raw).hexdigest()
    require(state.get("version") == STATE_VERSION, "invalid-state", "unsupported controller state version")
    require(state.get("fingerprint") == admitted["fingerprint"],
            "state-mismatch", "state belongs to another scope")
    require(state.get("scope_identity") == admitted["scope_identity"],
            "state-mismatch", "state scope identity differs")
    owner = state.get("owner")
    require(isinstance(owner, dict) and text(owner.get("controller_id")),
            "ownership-missing", "controller ownership identity missing")
    require(isinstance(state.get("tasks"), dict)
            and set(state["tasks"]) == {t["task_id"] for t in admitted["tasks"]},
            "invalid-state", "state task identities differ")
    require(type(state.get("halt_new_dispatch")) is bool
            and type(state.get("stop_requested", False)) is bool,
            "invalid-state", "halt/stop state must be explicit")
    for item in state["tasks"].values():
        require(isinstance(item, dict) and item.get("status") in
                ("pending", "running", "delivered", "repair-ready", "note-pending",
                 "evidence-pending", "unknown"),
                "invalid-state", "invalid task state")
        if item["status"] != "pending":
            require(isinstance(item.get("reservation"), dict), "invalid-state", "reservation missing")
            reservation = item["reservation"]
            require(all(text(reservation.get(k)) for k in ("branch", "workspace", "parent_branch", "parent_sha"))
                    and SHA_RE.fullmatch(reservation["parent_sha"])
                    and Path(reservation["workspace"]).is_absolute(),
                    "invalid-state", "reservation identity incomplete")
        if item.get("first_uncertain_boundary") is not None:
            require(isinstance(item["first_uncertain_boundary"], dict),
                    "invalid-state", "uncertain boundary must be an object")
    return state


def halt(state, item, reason, report=None, global_halt=False):
    if isinstance(item.get("reservation"), dict):
        item["status"] = "unknown"
    if isinstance(report, dict):
        item["report"] = copy.deepcopy(report)
        item["last_evidence"] = copy.deepcopy(report)
    boundary = {
        "reason": reason,
        "status": "unknown",
        "reservation": copy.deepcopy(item.get("reservation")),
        "report": copy.deepcopy(report) if isinstance(report, dict) else None,
    }
    item["failure_reason"] = reason
    item["first_uncertain_boundary"] = item.get("first_uncertain_boundary") or boundary
    if global_halt:
        state["halt_new_dispatch"] = True
        state["halt_reason"] = reason
        state.setdefault("recovery", {})["first_uncertain_boundary"] = copy.deepcopy(boundary)
    return {
        "status": "halted" if global_halt else "unknown",
        "task_id": next((tid for tid, value in state["tasks"].items() if value is item), None),
        "reason": reason,
        "dispatch": [],
    }


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
    worker = field_object(result.get("worker"), ("worker_id", "pr_url", "branch", "workspace", "head_sha",
                          "base_branch", "commit_sha", "association"), "worker")
    readback = field_object(result.get("readback"), ("repo", "head_repo", "pr_url", "branch", "head_sha",
                            "base_branch", "commit_sha", "association", "closing_references", "open", "draft",
                            "unique", "diff_identity", "reviews", "threads"), "readback")
    require(text(worker["worker_id"]), "invalid-worker", "native host worker identity required")
    for key in ("pr_url", "branch", "head_sha", "base_branch", "commit_sha", "association"):
        require(worker[key] == readback[key], "evidence-mismatch", "worker/readback disagree on " + key)
    require(Path(worker["workspace"]).is_absolute()
            and Path(worker["workspace"]).resolve() == Path(reservation["workspace"]).resolve(),
            "workspace-mismatch", "worker used a different selected workspace")
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
    identity = workspace_identity(repo, admitted["canonical_repo"], reservation["workspace"], reservation["branch"])
    require(readback["commit_sha"] == readback["head_sha"] == identity["head_sha"],
            "wrong-head", "commit and actual workspace head must agree")
    require(contains(reservation["workspace"], reservation["parent_sha"], readback["head_sha"]),
            "wrong-ancestry", "admitted start is not an ancestor")
    actual_diff = "sha256:" + hashlib.sha256(git(reservation["workspace"], "diff", "--no-ext-diff", "--no-textconv",
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
    delivery = {"pr_url": readback["pr_url"], "head_sha": readback["head_sha"],
                "branch": readback["branch"], "workspace": reservation["workspace"],
                "base_branch": readback["base_branch"],
                "commit_sha": readback["commit_sha"], "association": task["url"],
                "validated_diff": actual_diff, "contract_hash": task["contract_hash"],
                "checkpoint": copy.deepcopy(result)}
    if result.get("note") is None:
        return {"status": "note-pending", "reason": "delivery-note-readback", "delivery": delivery}
    note = field_object(result.get("note"), ("id", "issue_url", "pr_url", "head_sha",
                                             "contract_hash", "diff_identity"),
                        "delivery note readback")
    require(text(note["id"]) or (type(note["id"]) is int and note["id"] > 0),
            "invalid-note", "native note identity required")
    for key, expected in (("issue_url", task["url"]), ("pr_url", readback["pr_url"]),
                          ("head_sha", readback["head_sha"]), ("contract_hash", task["contract_hash"]),
                          ("diff_identity", actual_diff)):
        require(note[key] == expected, "note-mismatch", "delivery note differs on " + key)
    if admitted["mode"] == "project":
        if result.get("project_status") is None:
            return {"status": "note-pending", "reason": "project-status-readback", "delivery": delivery}
        progress = field_object(result.get("project_status"),
                                ("project_url", "issue_url", "item_id", "status"),
                                "Project status readback")
        require(progress["item_id"] == task["item_id"] and progress["project_url"] == admitted["selector_url"]
                and progress["issue_url"] == task["url"]
                and progress["status"] == admitted["lifecycle"]["inReview"],
                "project-status-mismatch", "verified Project inReview readback required")
    return {"status": "delivered", "delivery": delivery}

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
        require(isinstance(candidate, dict) and text(candidate.get("branch"))
                and SHA_RE.fullmatch(candidate.get("sha", "")),
                "decision-rejected", "parent decision needs branch and full SHA")
        if branch_tip(repo, candidate["branch"]) != candidate["sha"]:
            continue
        if all(contains(repo, head, candidate["sha"]) for head in heads):
            return candidate
    return None

def _state_summary(state, blocked=None, waiting=None, paused=None, unknown_details=None):
    blocked = list(blocked or [])
    waiting = list(waiting or [])
    paused = list(paused or [])
    unknown_details = list(unknown_details or [])
    tasks = state["tasks"]
    return {
        "delivered": sorted(tid for tid, item in tasks.items() if item["status"] == "delivered"),
        "running": sorted(tid for tid, item in tasks.items() if item["status"] == "running"),
        "active": sorted(tid for tid, item in tasks.items() if item["status"] in ("running", "note-pending")),
        "unknown": sorted(tid for tid, item in tasks.items() if item["status"] == "unknown"),
        "unknown_details": unknown_details,
        "evidence_pending": sorted(tid for tid, item in tasks.items() if item["status"] == "evidence-pending"),
        "repair_ready": sorted(tid for tid, item in tasks.items() if item["status"] == "repair-ready"),
        "pending": sorted(tid for tid, item in tasks.items() if item["status"] == "pending"),
        "blocked": blocked,
        "waiting": waiting,
        "paused": paused,
    }


def _remember_result(item, result):
    item["last_evidence"] = copy.deepcopy(result)
    worker = result.get("worker") if isinstance(result, dict) else None
    readback = result.get("readback") if isinstance(result, dict) else None
    if isinstance(worker, dict):
        item["report"] = copy.deepcopy(worker)
        item["worker"] = copy.deepcopy(worker)
    if isinstance(readback, dict):
        item["source"] = {
            "branch": readback.get("branch"),
            "head_sha": readback.get("head_sha"),
            "base_branch": readback.get("base_branch"),
            "commit_sha": readback.get("commit_sha"),
            "diff_identity": readback.get("diff_identity"),
        }
        item["pr"] = {
            "pr_url": readback.get("pr_url"),
            "head_sha": readback.get("head_sha"),
            "base_branch": readback.get("base_branch"),
            "open": readback.get("open"),
            "draft": readback.get("draft"),
            "unique": readback.get("unique"),
        }
    if isinstance(result.get("checks"), dict):
        item["checks"] = copy.deepcopy(result["checks"])
    if isinstance(result.get("validation"), dict):
        item["validation"] = copy.deepcopy(result["validation"])


def _safe_reason(error, default="blocked"):
    return getattr(error, "code", default)




def cmd_schedule(args):
    admitted = load_json(args.admitted)
    require(admitted.get("status") in ("admitted", "no-work"), "not-admitted", "admission required")
    root = repository(args.git_repo, admitted["canonical_repo"])
    state = state_read(args.state, admitted) if args.state else new_state(admitted)
    if not args.state:
        require(not Path(args.state_out).exists(), "existing-state", "initial state already exists; resume it")
    claim_scope(args.git_repo, admitted, state)
    try:
        selected = admitted.get("selector_urls") if admitted["mode"] == "issues" else admitted["selector_url"]
        fresh = admit(load_json(args.fresh), admitted["mode"], selected, admitted["max_parallel"])
        require(fresh.get("recovery") is not None, "incomplete-recovery",
                "schedule requires a complete fresh recovery inventory")
        require(fresh["fingerprint"] == admitted["fingerprint"],
                "snapshot-drift", "scope/native identity/contract changed")
        require(fresh["integration"] == admitted["integration"],
                "parent-tip-drift", "integration tip requires readmission")
    except InputError as error:
        state["halt_new_dispatch"], state["halt_reason"] = True, error.code
        state.setdefault("recovery", {})["first_uncertain_boundary"] = {
            "reason": error.code, "status": "snapshot-drift",
        }
        write_state(args, state)
        return {"status": "snapshot-drift", "reason": error.code, "dispatch": [],
                **_state_summary(state)}
    state.setdefault("recovery", {})["last_snapshot"] = {
        "fingerprint": fresh["fingerprint"],
        "scope_identity": copy.deepcopy(fresh["scope_identity"]),
        "membership": [
            {"url": task["url"], "id": task["id"], "node_id": task["node_id"],
             "actual_parent": task.get("actual_parent"), "item_id": task.get("item_id")}
            for task in fresh["tasks"]
        ],
        "dependencies": {
            task["task_id"]: copy.deepcopy(task.get("dependency_snapshot", {
                "prerequisites": task["prerequisites"],
                "external_prerequisites": task["external_prerequisites"],
            })) for task in fresh["tasks"]
        },
        "contract_revisions": {
            task["task_id"]: task.get("contract_revision", task["contract_hash"])
            for task in fresh["tasks"]
        },
    }
    state.setdefault("recovery", {})["last_inventory"] = copy.deepcopy(fresh.get("recovery"))
    if state.get("stop_requested"):
        state["halt_new_dispatch"], state["halt_reason"] = True, "user-stop"
        write_state(args, state)
        return {"status": "stopped", "reason": "user-stop", "dispatch": [],
                **_state_summary(state)}
    if state["halt_new_dispatch"]:
        write_state(args, state)
        return {"status": "halted", "reason": state["halt_reason"], "dispatch": [],
                **_state_summary(state)}
    decisions = {}
    if args.parent_decision:
        entries = load_json(args.parent_decision).get("decisions")
        require(isinstance(entries, list), "malformed-decision", "decisions list required")
        for decision in entries:
            require(isinstance(decision, dict) and decision.get("task_id") in state["tasks"]
                    and decision["task_id"] not in decisions,
                    "malformed-decision", "ambiguous parent decision")
            decisions[decision["task_id"]] = decision
    blocked, paused, waiting, unknown = [], [], [], []
    ownership_unverified = set()
    fresh_tasks = {t["task_id"]: t for t in fresh["tasks"]}
    # Delivery is imported/revalidated from fresh independent evidence, never a saved success flag.
    for tid in fresh["task_order"]:
        task = fresh_tasks[tid]
        item = state["tasks"][tid]
        retained = task.get("existing_delivery")
        if not (item["status"] == "delivered" or (item["status"] == "pending" and retained is not None)):
            continue
        if item["status"] == "pending":
            prior_claim = retained.get("claim") if isinstance(retained, dict) else None
            if not (isinstance(prior_claim, dict)
                    and prior_claim.get("owner") == state["owner"]["controller_id"]
                    and prior_claim.get("canonical_repo") == admitted["canonical_repo"]
                    and prior_claim.get("scope") == admitted["scope_identity"]
                    and prior_claim.get("issue_url") == task["url"]):
                ownership_unverified.add(tid)
                blocked.append({"task_id": tid, "reason": "ownership-unverified",
                                "next_action": "prove prior claim or perform explicit verified ownership transfer"})
                continue
        retained_reservation = retained.get("reservation") if isinstance(retained, dict) else None
        if item["reservation"] is None and isinstance(retained_reservation, dict):
            item["reservation"] = copy.deepcopy(retained_reservation)
        if task["external_prerequisites"]:
            if retained_reservation is not None:
                item["status"] = "repair-ready"
                item["failure_reason"] = "external-prerequisite"
            blocked.append({"task_id": tid, "reason": "external-prerequisite"})
            continue
        if any(state["tasks"][p]["status"] != "delivered" for p in task["prerequisites"]):
            if retained_reservation is not None:
                item["status"] = "repair-ready"
                item["failure_reason"] = "prerequisites-unmet"
            waiting.append({"task_id": tid, "reason": "prerequisites-unmet"})
            continue
        try:
            require(isinstance(retained, dict), "invalid-retained-delivery",
                    "delivered task requires fresh delivery evidence")
            field_object(retained, ("reservation", "result"), "existing delivery")
            reservation = retained["reservation"]
            if item["reservation"] is not None:
                require(reservation == item["reservation"], "reservation-mismatch",
                        "retained workspace/parent changed")
            require(Path(reservation["workspace"]).is_absolute(),
                    "reservation-mismatch", "retained workspace must be absolute")
            require(text(reservation.get("branch")), "reservation-mismatch",
                    "retained branch is missing")
            claim_task(args.git_repo, admitted, task, state, item)
            decision = decisions.get(tid) or item.get("parent_decision")
            parent_readiness(fresh, task, state, reservation, decision, args.git_repo, retained=True)
            proof = validate_delivery(admitted, task, reservation, retained["result"], args.git_repo)
            require(proof["status"] in ("delivered", "note-pending"),
                    "delivery-invalidated", "retained delivery no longer verified")
            require(not any(tid != task["task_id"] and other.get("verified_pr") == proof["delivery"]["pr_url"]
                            for tid, other in state["tasks"].items()),
                    "duplicate-pr", "retained deliveries claim the same PR")
            _remember_result(item, retained["result"])
            item.update(status=proof["status"], reservation=reservation,
                        delivery=proof["delivery"], verified_pr=proof["delivery"]["pr_url"],
                        parent_decision=copy.deepcopy(decision))
        except (InputError, KeyError, TypeError) as error:
            reason = _safe_reason(error, "invalid-retained-delivery")
            if reason == "ownership-conflict":
                blocked.append({"task_id": tid, "reason": reason,
                                 "next_action": "reconcile the other controller's canonical task claim"})
                continue
            if item["reservation"] is None and isinstance(retained, dict):
                item["reservation"] = retained.get("reservation")
            halt(state, item, reason)
            unknown.append({"task_id": tid, "reason": reason,
                            "next_action": "prove worker stopped and reconcile direct Git/PR evidence"})
            item["last_evidence"] = copy.deepcopy(retained)
            continue
    cap = min(positive(args.cap) if args.cap is not None else admitted["max_parallel"],
              admitted["max_parallel"], fresh["host_cap"])
    occupied = [tid for tid, item in state["tasks"].items()
                if item["status"] in ("running", "unknown")]
    slots = max(0, cap - len(occupied))
    inventory = worktree_inventory(args.git_repo)
    dispatch = []
    for task in sorted(admitted["tasks"], key=lambda t: (t["ordinal"], t["task_id"])):
        tid, item = task["task_id"], state["tasks"][task["task_id"]]
        if tid in ownership_unverified:
            continue
        if item["status"] == "unknown":
            unknown.append({"task_id": tid, "reason": item.get("failure_reason", "unknown"),
                            "next_action": "prove worker stopped and reconcile before repair"})
            continue
        if item["status"] == "note-pending":
            blocked.append({"task_id": tid, "reason": item.get("failure_reason", "delivery-receipt-pending"),
                             "next_action": "retry note/Project read-back; do not replay repository delivery"})
            continue
        if item["status"] == "evidence-pending":
            blocked.append({"task_id": tid, "reason": item.get("failure_reason", "delivery-evidence-pending"),
                            "next_action": "assemble and apply independent full delivery evidence; do not dispatch another worker"})
            continue
        if item["status"] not in ("pending", "repair-ready"):
            continue
        if task["external_prerequisites"]:
            blocked.append({"task_id": tid, "reason": "external-prerequisite"})
            continue
        predecessor_states = [state["tasks"][p]["status"] for p in task["prerequisites"]]
        if any(status != "delivered" for status in predecessor_states):
            waiting.append({
                "task_id": tid,
                "reason": "prerequisite-unknown" if any(status == "unknown" for status in predecessor_states)
                else "prerequisites-unmet",
            })
            continue
        repair = item["status"] == "repair-ready"
        try:
            if repair:
                reservation = item["reservation"]
                try:
                    identity = workspace_identity(args.git_repo, admitted["canonical_repo"],
                                                  reservation["workspace"], reservation["branch"])
                    require(contains(reservation["workspace"], reservation["parent_sha"],
                                     identity["head_sha"]),
                            "wrong-ancestry", "repair workspace no longer contains admitted start")
                except InputError as error:
                    blocked.append({"task_id": tid,
                                    "reason": getattr(error, "code", "workspace-conflict")})
                    continue
            else:
                parent = choose_parent(admitted, task, state, decisions, args.git_repo)
                if parent is None:
                    paused.append({"task_id": tid, "reason": "join-no-containing-parent",
                                   "prerequisite_branches": [
                                       state["tasks"][p]["delivery"]["branch"]
                                       for p in task["prerequisites"]]})
                    continue
                try:
                    allocation = runtime_allocation(fresh, tid, root)
                except InputError as error:
                    blocked.append({"task_id": tid,
                                    "reason": getattr(error, "code", "workspace-unassigned")})
                    continue
                reservation = {"branch": allocation["branch"],
                               "workspace": allocation["workspace"],
                               "parent_branch": parent["branch"], "parent_sha": parent["sha"],
                               "task_url": task["url"],
                               "scope": copy.deepcopy(admitted["scope_identity"]),
                               "contract_hash": task["contract_hash"]}
            workspace = reservation["workspace"]
            if any(other != tid and other_item.get("reservation")
                   and overlaps(workspace, other_item["reservation"]["workspace"])
                   for other, other_item in state["tasks"].items()):
                blocked.append({"task_id": tid, "reason": "workspace-alias-collision"})
                continue
            try:
                collision = (allocation_collision(args.git_repo, admitted["canonical_repo"],
                                                  reservation, inventory, state, tid)
                             if not repair else None)
            except InputError as error:
                blocked.append({"task_id": tid,
                                "reason": getattr(error, "code", "workspace-conflict")})
                continue
            if collision:
                blocked.append({"task_id": tid, "reason": collision})
                continue
            existing_checkout = (Path(workspace).exists()
                                 and git(workspace, "rev-parse", "--show-toplevel",
                                         allow_missing=True) is not None)
            if not repair and existing_checkout:
                try:
                    current = workspace_identity(args.git_repo, admitted["canonical_repo"],
                                                 reservation["workspace"], reservation["branch"])
                    require(contains(reservation["workspace"], reservation["parent_sha"],
                                     current["head_sha"]),
                            "wrong-ancestry",
                            "existing task workspace does not contain selected parent")
                    fresh_workspace_state(reservation["workspace"], reservation["parent_sha"],
                                           current["head_sha"])
                except InputError as error:
                    blocked.append({"task_id": tid,
                                    "reason": getattr(error, "code", "workspace-conflict")})
                    continue
            if slots == 0:
                continue
            claim_task(args.git_repo, admitted, task, state, item)
            retained_pr = item.get("verified_pr")
            decision = decisions.get(tid) or item.get("parent_decision")
            readiness = parent_readiness(fresh, task, state, reservation, decision,
                                         args.git_repo, retained=repair)
            item.update(status="running", reservation=reservation,
                        parent_decision=copy.deepcopy(decision),
                        first_uncertain_boundary=None,
                        last_evidence={"parent_readiness": copy.deepcopy(readiness)})
            dispatch.append({"task_id": tid, "ordinal": task["ordinal"], "child_url": task["url"],
                             "repair": repair, "retained_pr": retained_pr, **reservation,
                             "packet": packet(admitted, task, reservation, repair, retained_pr,
                                              readiness)})
            occupied.append(tid)
            slots -= 1
        except (InputError, KeyError, TypeError) as error:
            reason = _safe_reason(error)
            if reason == "ownership-conflict":
                blocked.append({"task_id": tid, "reason": reason,
                                "next_action": "reconcile the other controller's canonical task claim"})
            elif reason in ("parent-tip-drift", "wrong-ancestry", "decision-rejected",
                            "unapproved-parent", "uncontained-prerequisite"):
                paused.append({"task_id": tid, "reason": reason,
                               "next_action": "make an explicit parent/base decision and re-read Git ancestry"})
            else:
                blocked.append({"task_id": tid, "reason": reason})
    write_state(args, state)
    return {"status": "no-work" if not admitted["tasks"] else "ok", "effective_cap": cap,
            "notice": fresh["notice"], "dispatch": dispatch, **_state_summary(
                state, blocked=blocked, waiting=waiting, paused=paused,
                unknown_details=unknown)}


def cmd_apply_result(args):
    admitted = load_json(args.admitted)
    repository(args.git_repo, admitted["canonical_repo"])
    state = state_read(args.state, admitted)
    require(args.task in state["tasks"], "unknown-task", "task outside admitted scope")
    item = state["tasks"][args.task]
    require(item["status"] in ("running", "note-pending", "evidence-pending"),
            "not-running", "task has no active reservation or receipt retry")
    task = next(t for t in admitted["tasks"] if t["task_id"] == args.task)
    claim_scope(args.git_repo, admitted, state)
    claim_task(args.git_repo, admitted, task, state, item)
    result = {}
    try:
        result = load_json(args.result)
        proof = validate_delivery(admitted, task, item["reservation"], result, args.git_repo)
        pr_url = result["worker"]["pr_url"]
        require(not any(tid != args.task and other.get("verified_pr") == pr_url
                        for tid, other in state["tasks"].items()),
                "duplicate-pr", "another task already owns this PR")
        retained_pr = item.get("verified_pr")
        if retained_pr:
            require(retained_pr == pr_url, "pr-replaced", "repair must preserve existing PR")
        _remember_result(item, result)
        item["verified_pr"] = pr_url
        item["status"] = proof["status"]
        item["failure_reason"] = proof.get("reason") if proof["status"] == "note-pending" else None
        if proof["status"] in ("delivered", "note-pending"):
            item["delivery"] = proof["delivery"]
        if proof["status"] == "delivered":
            item["first_uncertain_boundary"] = None
        outcome = {"task_id": args.task, **proof}
    except (InputError, KeyError, TypeError, ValueError) as error:
        outcome = halt(state, item, getattr(error, "code", "unknown-response"),
                       result.get("worker") if isinstance(result, dict) else None)
    write_state(args, state)
    return outcome

def cmd_reconcile(args):
    admitted = load_json(args.admitted)
    repository(args.git_repo, admitted["canonical_repo"])
    state = state_read(args.state, admitted)
    require(args.task in state["tasks"], "unknown-task", "task outside admitted scope")
    item = state["tasks"][args.task]
    require(item["status"] == "unknown", "not-unknown", "task has no uncertain outcome")
    task = next(t for t in admitted["tasks"] if t["task_id"] == args.task)
    claim_scope(args.git_repo, admitted, state)
    claim_task(args.git_repo, admitted, task, state, item)
    evidence = load_json(args.evidence)
    reservation = item["reservation"]
    require(evidence.get("worker_stopped") is True,
            "worker-liveness", "old writer must be proved stopped")
    require(evidence.get("repo") == evidence.get("head_repo") == admitted["canonical_repo"],
            "foreign-repo", "canonical repository readback required")
    observed_workspace = evidence.get("workspace")
    if observed_workspace is not None:
        require(Path(observed_workspace).resolve() == Path(reservation["workspace"]).resolve(),
                "evidence-mismatch", "workspace discovery conflicts with reservation")
    if Path(reservation["workspace"]).exists():
        identity = workspace_identity(args.git_repo, admitted["canonical_repo"],
                                      reservation["workspace"], reservation["branch"])
        actual_head = identity["head_sha"]
        ancestry_repo = reservation["workspace"]
    else:
        actual_head = branch_tip(args.git_repo, reservation["branch"])
        ancestry_repo = args.git_repo
    require(evidence.get("branch") == reservation["branch"]
            and evidence.get("base_branch") == reservation["parent_branch"]
            and evidence.get("head_sha") == actual_head
            and evidence.get("unique") is True, "evidence-mismatch", "branch/head/base discovery conflicts")
    require(contains(ancestry_repo, reservation["parent_sha"], evidence["head_sha"]),
            "wrong-ancestry", "retained branch ancestry differs")
    item["last_evidence"] = copy.deepcopy(evidence)
    item["source"] = {
        "branch": evidence["branch"],
        "head_sha": evidence["head_sha"],
        "base_branch": evidence["base_branch"],
        "commit_sha": evidence["head_sha"],
        "diff_identity": evidence.get("diff_identity"),
    }
    if evidence.get("pr_absent") is True:
        require("pr_url" in evidence and evidence["pr_url"] is None and evidence.get("open") is False,
                "evidence-mismatch", "PR absence requires an explicit null URL and closed readback")
        require(not item.get("verified_pr"), "evidence-mismatch", "verified PR cannot silently disappear")
        item["pr"] = {
            "pr_url": None, "head_sha": evidence["head_sha"],
            "base_branch": evidence["base_branch"], "open": False, "unique": True,
        }
    else:
        match = PR_RE.fullmatch(evidence.get("pr_url", ""))
        require(match and "https://github.com/" + "/".join(match.groups()[:2]) == admitted["canonical_repo"]
                and evidence.get("open") is True,
                "invalid-pr", "one canonical open PR required")
        require(not item.get("verified_pr") or item["verified_pr"] == evidence["pr_url"],
                "evidence-mismatch", "retained PR differs")
        item["report"] = {"pr_url": evidence["pr_url"], "head_sha": evidence["head_sha"]}
        item["worker"] = copy.deepcopy(item["report"])
        item["verified_pr"] = evidence["pr_url"]
        item["pr"] = {
            "pr_url": evidence["pr_url"], "head_sha": evidence["head_sha"],
            "base_branch": evidence["base_branch"], "open": True, "unique": True,
        }
    item["status"] = "repair-ready" if evidence.get("pr_absent") is True else "evidence-pending"
    item["failure_reason"] = None if evidence.get("pr_absent") is True else "delivery-evidence-pending"
    if state.get("halt_reason") in (None, "unknown-response"):
        state["halt_new_dispatch"], state["halt_reason"] = False, None
    write_state(args, state)
    return {"status": "reconciled", "task_id": args.task,
            "detail": "Same task retained; full apply-result gates still required.",
            **_state_summary(state)}
def cmd_stop(args):
    admitted = load_json(args.admitted)
    repository(args.git_repo, admitted["canonical_repo"])
    state = state_read(args.state, admitted)
    claim_scope(args.git_repo, admitted, state)
    require(text(args.reason), "invalid-stop", "stop reason required")
    state["stop_requested"] = True
    state["halt_new_dispatch"] = True
    state["halt_reason"] = args.reason
    state.setdefault("recovery", {})["first_uncertain_boundary"] = {
        "reason": args.reason,
        "status": "stop-requested",
        "running": sorted(tid for tid, item in state["tasks"].items()
                          if item["status"] == "running"),
    }
    write_state(args, state)
    return {"status": "stop-requested", "reason": args.reason, "dispatch": [],
            **_state_summary(state)}




def cmd_admit(args):
    selected = [bool(args.issue), bool(args.project), bool(args.issues)]
    require(sum(selected) == 1, "conflicting-selectors" if any(selected) else "missing-selector",
            "select exactly one scope")
    if args.issues:
        return admit(load_json(args.snapshot), "issues", args.issues, positive(args.max_parallel))
    return admit(load_json(args.snapshot), "issue" if args.issue else "project",
                 args.issue or args.project, positive(args.max_parallel))


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
    schedule = commands.add_parser("schedule")
    schedule.add_argument("--admitted", required=True)
    schedule.add_argument("--state")
    schedule.add_argument("--state-out", required=True)
    schedule.add_argument("--git-repo", required=True)
    schedule.add_argument("--fresh", required=True)
    schedule.add_argument("--cap")
    schedule.add_argument("--parent-decision")
    schedule.set_defaults(run=cmd_schedule)
    apply = commands.add_parser("apply-result")
    apply.add_argument("--admitted", required=True)
    apply.add_argument("--state", required=True)
    apply.add_argument("--state-out", required=True)
    apply.add_argument("--git-repo", required=True)
    apply.add_argument("--task", required=True)
    apply.add_argument("--result", required=True)
    apply.set_defaults(run=cmd_apply_result)
    reconcile = commands.add_parser("reconcile")
    reconcile.add_argument("--admitted", required=True)
    reconcile.add_argument("--state", required=True)
    reconcile.add_argument("--state-out", required=True)
    reconcile.add_argument("--git-repo", required=True)
    reconcile.add_argument("--task", required=True)
    reconcile.add_argument("--evidence", required=True)
    reconcile.set_defaults(run=cmd_reconcile)
    stop = commands.add_parser("stop")
    stop.add_argument("--admitted", required=True)
    stop.add_argument("--state", required=True)
    stop.add_argument("--state-out", required=True)
    stop.add_argument("--git-repo", required=True)
    stop.add_argument("--reason", default="user-stop")
    stop.set_defaults(run=cmd_stop)
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
