#!/usr/bin/env python3
"""Session-local orchestration gates; the skill supplies fresh gh/host evidence.

This is the production scheduling path. It never calls GitHub or implements source.
The controller dispatches emitted packets through its native host, then returns independent GitHub,
verification, review, and progress readbacks. Git identity, ancestry, worktree ownership, and diff
hashes are checked here directly.
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
DEFAULT_CI_REPAIR_LIMIT = 2
CI_STATES = ("unverified", "checking", "verified", "blocked", "repair")
CI_PENDING = ("queued", "waiting", "requested", "pending", "in_progress", "running")
CI_SUCCESS = ("success", "neutral", "skipped")
CI_ACTIONABLE = ("failure", "error", "timed_out", "cancelled", "startup_failure")
CI_NONPASS = ("action_required", "stale", "unknown")


def canonical_issue_url(value, canonical):
    match = ISSUE_RE.fullmatch(value or "")
    repo = REPO_RE.fullmatch(canonical or "")
    require(match is not None and repo is not None
            and tuple(part.lower() for part in match.groups()[:2]) ==
            tuple(part.lower() for part in repo.groups()),
            "foreign-repository", "issue is outside the canonical repository")
    return "https://github.com/%s/%s/issues/%s" % (repo.group(1), repo.group(2), match.group(3))



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

    def existing_claim():
        if path.is_symlink():
            raise InputError("unsafe-ownership", "orchestration claim cannot be a symlink")
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

    if path.exists():
        return existing_claim()

    descriptor, temporary = tempfile.mkstemp(prefix=path.name + ".", dir=claims)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(_json_bytes(record))
            stream.flush()
            os.fsync(stream.fileno())
        try:
            os.link(temporary, path, follow_symlinks=False)
        except FileExistsError:
            return existing_claim()
        _fsync_parent(path)
        return record
    except OSError as error:
        raise InputError("ownership-write", str(error)) from error
    finally:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass



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


def contract_check(contract):
    """Check the model-resolved worker brief, not the source issue's layout."""
    require(isinstance(contract, dict), "incomplete-task", "resolved task brief missing")
    require(text(contract.get("goal")) and text(contract.get("smoke")),
            "incomplete-task", "task needs an understood goal and real smoke scenario")
    for key in ("scope", "acceptance", "checks"):
        values = contract.get(key)
        require(isinstance(values, list) and bool(values) and all(text(v) for v in values),
                "incomplete-task", "resolved task needs " + key)
    for path in contract["scope"]:
        require(not Path(path).is_absolute() and ".." not in Path(path).parts,
                "invalid-scope", "allowed paths must stay inside the task worktree")


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
    require(item.get("state") in ("open", "closed"), "issue-not-open", "issue is not open or closed")
    require(isinstance(item.get("title"), str) and isinstance(item.get("body"), str),
            "invalid-identity", "issue title and body must be completely read")


def nonempty_scope_evidence(value):
    return text(value) if isinstance(value, str) else isinstance(value, (list, dict)) and bool(value)


def normalize_scope_evidence(value, tasks, canonical):
    if value is None:
        return None
    require(isinstance(value, dict), "invalid-scope-evidence", "scope evidence must be an object")
    tracker = value.get("tracker")
    require(isinstance(tracker, dict), "invalid-scope-evidence", "selected tracker evidence missing")
    url = canonical_issue_url(tracker.get("url", ""), canonical)
    require(type(tracker.get("id")) is int and tracker["id"] > 0 and text(tracker.get("node_id"))
            and text(tracker.get("title")) and isinstance(tracker.get("body"), str)
            and text(tracker.get("revision")),
            "invalid-scope-evidence", "selected tracker identity, content, and revision are incomplete")
    membership = value.get("membership")
    require(isinstance(membership, dict) and membership.get("source") in ("native", "declared")
            and isinstance(membership.get("issues"), list)
            and nonempty_scope_evidence(membership.get("evidence")),
            "invalid-scope-evidence", "tracker membership source, issues, or evidence is incomplete")
    require(all(text(issue) for issue in membership["issues"]),
            "invalid-scope-evidence", "tracker membership contains an invalid issue URL")
    issues = [canonical_issue_url(issue, canonical) for issue in membership["issues"]]
    require(len(issues) == len(set(issues)),
            "ambiguous-scope", "tracker membership must be a unique issue set")
    task_urls = {task["url"] for task in tasks}
    normalized_issues = sorted(issues)
    require(set(issues) == task_urls, "scope-membership-mismatch",
            "tracker membership must exactly match executable tasks")
    require(url not in task_urls, "invalid-scope-evidence", "tracker cannot also be an executable task")
    if membership["source"] == "native":
        require(all(text(task.get("actual_parent"))
                    and canonical_issue_url(task["actual_parent"], canonical) == url
                    for task in tasks),
                "native-membership-unverified", "native membership requires tracker parentage for every task")
    return {
        "tracker": {"url": url, **{key: tracker[key] for key in ("id", "node_id", "title", "body", "revision")}},
        "membership": {
            "source": membership["source"], "issues": normalized_issues,
            "evidence": copy.deepcopy(membership["evidence"]),
        },
    }


def tracker_scope_context(tracker):
    """Normalize tracker prose and unordered annotated issue rows."""
    references = set()
    link_pattern = re.compile(
        r"https://github\.com/([\w.-]+)/([\w.-]+)/(issues|pull)/([1-9][0-9]*)"
    )
    relative_pattern = re.compile(r"#([1-9][0-9]*)")
    row_pattern = re.compile(r"^\s*(?:[-*+]|\d+[.)])\s+")

    def normalize_line(line):
        line_references = []

        def canonical_link(match):
            owner, repo, kind, number = match.groups()
            reference = kind + ":" + owner.lower() + "/" + repo.lower() + ":" + number
            references.add(reference)
            line_references.append(reference)
            return " " + reference + " "

        def relative_link(match):
            owner, repo = ISSUE_RE.fullmatch(tracker["url"]).groups()[:2]
            reference = "issues:" + owner.lower() + "/" + repo.lower() + ":" + match.group(1)
            references.add(reference)
            line_references.append(reference)
            return " " + reference + " "

        line = link_pattern.sub(canonical_link, line)
        line = relative_pattern.sub(relative_link, line)
        line = re.sub(r"\s*,\s*", ",", " ".join(line.split()))
        return tuple(sorted(line_references)), line

    normalized_lines = []
    pending_rows = []

    def flush_rows():
        normalized_lines.extend(line for _, line in sorted(pending_rows))
        pending_rows.clear()

    for raw_line in tracker["body"].splitlines() or [tracker["body"]]:
        line_references, line = normalize_line(raw_line)
        if row_pattern.match(raw_line) and line_references:
            pending_rows.append((line_references, line))
        else:
            flush_rows()
            normalized_lines.append(line)
    flush_rows()
    return {
        "url": tracker["url"], "id": tracker["id"], "node_id": tracker["node_id"],
        "title": " ".join(tracker["title"].split()),
        "body": " ".join(normalized_lines), "references": sorted(references),
    }


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


def graph_metadata(edges):
    return {"edges": copy.deepcopy(edges)}


def check_graph(tasks, edges=None):
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
        for predecessor in task["prerequisites"]:
            require(predecessor in by_id, "missing-endpoint", "unknown prerequisite " + predecessor)
            require(predecessor != task["task_id"], "self-dependency", "task depends on itself")
    try:
        return list(TopologicalSorter({t["task_id"]: t["prerequisites"] for t in tasks}).static_order())
    except CycleError as error:
        raise InputError("cycle", "dependency cycle: " + " -> ".join(error.args[1])) from error


def collect_edges(snapshot, tasks, canonical):
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
                add(value)
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
        for predecessor in task.get("prerequisites", []):
            add({"predecessor": predecessor, "dependent": source},
                default_kind="declared",
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
                            "provenance": "declared",
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


def _base_satisfied_prerequisites(raw, task, tasks_by_id, technical, integration, repo):
    values = raw.get("base_satisfied_prerequisites", [])
    require(isinstance(values, list),
            "invalid-execution-layout", "base-satisfied prerequisites must be a list")
    require(not values or repo is not None, "git-unavailable",
            "--git-repo is required to verify base-satisfied prerequisites")
    result, seen = [], set()
    for value in values:
        require(isinstance(value, dict) and text(value.get("task_id"))
                and SHA_RE.fullmatch(value.get("revision") or "")
                and nonempty_scope_evidence(value.get("evidence")),
                "invalid-execution-layout",
                "base-satisfied prerequisite needs task identity, revision, and evidence")
        task_id = value["task_id"]
        require(task_id in technical[task["task_id"]], "invalid-execution-layout",
                "base-satisfied prerequisite must be a technical prerequisite")
        require(task_id not in seen, "duplicate-execution-task",
                "base-satisfied prerequisite is repeated")
        seen.add(task_id)
        delivery = tasks_by_id[task_id].get("existing_delivery")
        require(isinstance(delivery, dict), "base-satisfaction-unverified",
                "base-satisfied prerequisite needs retained delivery evidence")
        lifecycle = delivery.get("lifecycle")
        require(isinstance(lifecycle, dict), "base-satisfaction-unverified",
                "base-satisfied prerequisite needs current lifecycle evidence")
        pr = lifecycle.get("pr", lifecycle)
        landed_revision = (pr.get("merge_commit_sha") if isinstance(pr, dict) else None) \
            or lifecycle.get("landed_revision")
        landing_target = (pr.get("merged_base_branch") if isinstance(pr, dict) else None) \
            or lifecycle.get("landing_target")
        verification = lifecycle.get("landed_verification") or lifecycle.get("verification")
        require(isinstance(pr, dict) and pr.get("state") == "merged"
                and landing_target == integration["branch"]
                and SHA_RE.fullmatch(landed_revision or "")
                and value["revision"] == landed_revision
                and isinstance(verification, dict)
                and verification.get("complete") is True
                and verification.get("source_verified") is True
                and verification.get("checks_verified") is True
                and verification.get("reverted") is not True,
                "base-satisfaction-unverified",
                "base-satisfied prerequisite is not verified in the admitted integration base")
        require(contains(repo, landed_revision, integration["sha"]),
                "base-satisfaction-unverified",
                "landed prerequisite is not contained in the admitted integration revision")
        result.append(copy.deepcopy(value))
    return sorted(result, key=lambda value: value["task_id"])


def collect_execution_layout(snapshot, tasks, repo):
    """Validate the model-selected task tree without changing technical edges."""
    raw = snapshot.get("execution_layout")
    require(isinstance(raw, dict), "missing-execution-layout", "execution layout missing")
    revision = raw.get("revision")
    require(type(revision) is int and revision > 0 and text(raw.get("rationale"))
            and isinstance(raw.get("entries"), list),
            "invalid-execution-layout", "execution layout revision, rationale, and entries required")
    task_ids = {task["task_id"] for task in tasks}
    tasks_by_id = {task["task_id"]: task for task in tasks}
    by_id = {}
    technical = {task_id: set(tasks_by_id[task_id]["prerequisites"]) for task_id in sorted(task_ids)}
    for entry in raw["entries"]:
        require(isinstance(entry, dict) and text(entry.get("task_id")),
                "invalid-execution-layout", "execution entry identity required")
        task_id = entry["task_id"]
        require(task_id in task_ids, "foreign-execution-task", "execution entry selects an unselected task")
        require(task_id not in by_id, "duplicate-execution-task", "duplicate execution task")
        require("execution_parent" in entry and text(entry.get("rationale")),
                "invalid-execution-layout", "execution parent and rationale required")
        parent = entry["execution_parent"]
        if parent is not None:
            require(parent in task_ids, "foreign-execution-parent", "execution parent is not selected")
            require(parent != task_id, "self-execution-parent", "task cannot stack on itself")
        constraints = entry.get("constraints")
        require(isinstance(constraints, list) and constraints and all(text(value) for value in constraints),
                "invalid-execution-layout", "execution compatibility evidence required")
        fallback = entry.get("fallback")
        if fallback is not None:
            require(parent is None and isinstance(fallback, dict)
                    and fallback.get("reason") == "merge-checkpoint"
                    and text(fallback.get("release_condition")),
                    "invalid-execution-fallback", "merge fallback needs one release condition")
        entry = copy.deepcopy(entry)
        entry["base_satisfied_prerequisites"] = _base_satisfied_prerequisites(
            entry, tasks_by_id[task_id], tasks_by_id, technical, snapshot["integration"], repo)
        by_id[task_id] = entry
    require(set(by_id) == task_ids, "missing-execution-task", "execution layout must select every task once")

    combined = {task_id: set(parents) for task_id, parents in technical.items()}
    for task_id, entry in by_id.items():
        if entry["execution_parent"] is not None:
            combined[task_id].add(entry["execution_parent"])
    combined = {task_id: tuple(sorted(parents)) for task_id, parents in sorted(combined.items())}
    try:
        execution_order = list(TopologicalSorter(combined).static_order())
    except CycleError as error:
        raise InputError("execution-cycle", "execution order cycle: " + " -> ".join(error.args[1])) from error

    normalized_entries = []
    for task_id in sorted(task_ids):
        entry = copy.deepcopy(by_id[task_id])
        lineage, parent = [], entry["execution_parent"]
        while parent is not None:
            lineage.append(parent)
            parent = by_id[parent]["execution_parent"]
        lineage.reverse()
        fallback = entry.get("fallback")
        base_satisfied = {value["task_id"] for value in entry["base_satisfied_prerequisites"]}
        if fallback is None:
            missing = technical[task_id] - set(lineage) - base_satisfied
            require(not missing, "missing-execution-ancestor",
                    "execution path for " + task_id + " omits " + ", ".join(sorted(missing)))
        else:
            require(technical[task_id] - base_satisfied, "invalid-execution-fallback",
                    "merge fallback requires an unsatisfied technical join")
        task = tasks_by_id[task_id]
        task["execution_parent"] = entry["execution_parent"]
        task["execution_rationale"] = entry["rationale"]
        task["execution_constraints"] = list(entry["constraints"])
        task["execution_fallback"] = copy.deepcopy(entry.get("fallback"))
        task["execution_ancestry"] = lineage
        task["base_satisfied_prerequisites"] = [
            value["task_id"] for value in entry["base_satisfied_prerequisites"]]
        task["effective_prerequisites"] = sorted(
            (technical[task_id] | ({entry["execution_parent"]}
                                  if entry["execution_parent"] is not None else set())) - base_satisfied)
        task["dependency_snapshot"] = {
            "prerequisites": sorted(technical[task_id]),
            "effective_prerequisites": list(task["effective_prerequisites"]),
            "execution_parent": entry["execution_parent"],
            "base_satisfied_prerequisites": list(task["base_satisfied_prerequisites"]),
            "external_prerequisites": list(task["external_prerequisites"]),
        }
        normalized_entries.append(entry)

    effective_edges = []
    relationships = {}
    for task_id, parents in technical.items():
        for predecessor in parents:
            relationships.setdefault((predecessor, task_id), set()).add("technical")
    for entry in normalized_entries:
        if entry["execution_parent"] is not None:
            relationships.setdefault((entry["execution_parent"], entry["task_id"]), set()).add("stack")
    for (predecessor, dependent), kinds in sorted(relationships.items()):
        if predecessor not in tasks_by_id[dependent]["effective_prerequisites"]:
            continue
        effective_edges.append({"predecessor": predecessor, "dependent": dependent,
                                "relationship": "+".join(sorted(kinds))})
    return {"revision": revision, "rationale": raw["rationale"],
            "entries": normalized_entries, "effective_edges": effective_edges,
            "execution_order": execution_order}


def admit(snapshot, limit, repo=None):
    canonical = snapshot.get("canonical_repo", "")
    require(REPO_RE.fullmatch(canonical) is not None, "missing-repository", "canonical repository missing")
    require(text(snapshot.get("repository_rules")), "incomplete-task", "repository rules must be read")
    integration = snapshot.get("integration", {})
    require(isinstance(integration, dict) and text(integration.get("branch"))
            and SHA_RE.fullmatch(integration.get("sha", "")) is not None,
            "missing-integration", "admitted integration branch and commit required")
    if repo is not None:
        repository(repo, canonical)
    entries = snapshot.get("tasks")
    require(isinstance(entries, list), "incomplete-selection", "resolved executable tasks are missing")
    by_url = {}
    for entry in entries:
        issue_identity(entry, canonical)
        record = copy.deepcopy(entry)
        record["url"] = canonical_issue_url(entry["url"], canonical)
        issue_number = int(ISSUE_RE.fullmatch(record["url"]).group(3))
        if record.get("number") is not None:
            require(type(record["number"]) is int and record["number"] == issue_number,
                    "ambiguous-identity", "issue number conflicts with issue URL")
        record["number"] = issue_number
        if record.get("actual_parent") is not None:
            record["actual_parent"] = canonical_issue_url(record["actual_parent"], canonical)
        if record["url"] in by_url:
            require(record == by_url[record["url"]], "ambiguous-identity", "duplicate issue evidence conflicts")
            continue
        by_url[record["url"]] = record
    tasks = []
    project = snapshot.get("project")
    if project is not None:
        match = PROJECT_RE.fullmatch(project.get("url", "")) if isinstance(project, dict) else None
        require(match is not None and text(project.get("node_id"))
                and project.get("state") == "open"
                and project.get("owner") == match.group(2)
                and match.group(2) == REPO_RE.fullmatch(canonical).group(1)
                and project.get("owner_type") == {"orgs": "organization", "users": "user"}[match.group(1)]
                and project.get("number") == int(match.group(3)),
                "invalid-project", "selected Project identity conflicts")
        lifecycle = snapshot.get("lifecycle")
        require(isinstance(lifecycle, dict) and text(lifecycle.get("inReview")),
                "missing-lifecycle", "selected Project inReview option missing")
    else:
        lifecycle = None
    for index, url in enumerate(sorted(by_url), 1):
        entry = by_url[url]
        task_id = entry.get("task_id") or "issue-" + str(entry["number"])
        require(isinstance(task_id, str) and TASK_RE.fullmatch(task_id) and ".." not in task_id
                and not task_id.endswith((".", ".lock")), "invalid-identity", "Git-safe stable task ID required")
        if project is not None:
            require(text(entry.get("item_id")), "invalid-project-item", "selected Project item ID missing")
        contract = entry.get("contract")
        contract_check(contract)
        record = copy.deepcopy(entry)
        record["task_id"] = task_id
        record["ordinal"] = index
        record["contract_hash"] = digest(contract)
        record["contract_revision"] = record["contract_hash"]
        record["specification"] = entry.get("specification") or entry["body"]
        tasks.append(record)
    for key in (("id", "node_id", "item_id") if project is not None else ("id", "node_id")):
        require(len({entry[key] for entry in tasks}) == len(tasks), "duplicate-identity", "issue identity conflicts")
    require(len({task["task_id"] for task in tasks}) == len(tasks), "duplicate-identity", "duplicate task ID")
    scope_evidence = normalize_scope_evidence(snapshot.get("scope_evidence"), tasks, canonical)
    if scope_evidence is not None:
        tracker = scope_evidence["tracker"]
        require(tracker["id"] not in {task["id"] for task in tasks}
                and tracker["node_id"] not in {task["node_id"] for task in tasks},
                "ambiguous-identity", "tracker and executable issue identities conflict")
    for task in tasks:
        if task.get("actual_parent") is not None:
            task["actual_parent"] = canonical_issue_url(task["actual_parent"], canonical)
    edges = collect_edges(snapshot, tasks, canonical)
    task_order = check_graph(tasks, edges)
    execution_layout = collect_execution_layout(snapshot, tasks, repo)
    execution_fingerprint = digest(execution_layout)
    host = snapshot.get("host", {})
    require(isinstance(host, dict), "no-subagent-capability", "host capability evidence missing")
    host_cap = positive(host.get("max_parallel", 1))
    if tasks:
        require(host.get("delivery_capable") is True, "no-subagent-capability", "delivery-capable subagent required")
    scope_identity = {"canonical_repo": canonical, "issues": sorted(by_url)}
    immutable_tasks = [{
        "task_id": task["task_id"], "url": task["url"], "id": task["id"],
        "node_id": task["node_id"], "resource": task["resource"],
        "title": task["title"], "body": task["body"], "contract": task["contract"],
        "specification": task["specification"],
        "actual_parent": (None if scope_evidence is not None
                          and task.get("actual_parent") == scope_evidence["tracker"]["url"]
                          else task.get("actual_parent")),
        "edge_provenance": copy.deepcopy(task["edge_provenance"]),
    } for task in tasks]
    binding = {
        "canonical_repo": canonical, "scope_identity": scope_identity,
        "repository_rules": snapshot["repository_rules"], "integration_branch": integration["branch"],
        "tasks": immutable_tasks,
        "dependencies": sorted((edge["predecessor"], edge["dependent"]) for edge in edges),
        "scope_evidence": (None if scope_evidence is None else {
            "tracker_context": tracker_scope_context(scope_evidence["tracker"]),
            "membership_issues": scope_evidence["membership"]["issues"],
        }),
    }
    if project is not None:
        binding["project"] = project
        binding["lifecycle"] = lifecycle
        binding["project_items"] = {task["url"]: task["item_id"] for task in tasks}
    recovery = recovery_inventory(snapshot.get("recovery"))
    return {**binding, "status": "admitted" if tasks else "no-work", "tasks": tasks,
            "fingerprint": digest(binding), "integration": integration, "max_parallel": limit,
            "task_order": task_order, "graph": graph_metadata(edges),
            "execution_layout": execution_layout, "execution_fingerprint": execution_fingerprint,
            "edge_provenance": edges, "parent_prs": copy.deepcopy(snapshot.get("parent_prs", {})),
            "host_cap": host_cap, "recovery": recovery,
            "scope_evidence": scope_evidence,
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
        "execution_layout": copy.deepcopy(admitted["execution_layout"]),
        "execution_fingerprint": admitted["execution_fingerprint"],
        "scope_evidence": copy.deepcopy(admitted.get("scope_evidence")),
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
                "task_id": t["task_id"],
                "status": "pending",
                "reservation": None,
                "claim": None,
                "delivery": None,
                "lifecycle": None,
                "lifecycle_error": None,
                "report": None,
                "verified_pr": None,
                "parent_decision": None,
                "contract_hash": t["contract_hash"],
                "contract_revision": t.get("contract_revision", t["contract_hash"]),
                "execution_parent": t["execution_parent"],
                "execution_plan_revision": admitted["execution_layout"]["revision"],
                "dependency_snapshot": copy.deepcopy(t["dependency_snapshot"]),
                "source": None,
                "diff_identity": None,
                "checks": None,
                "validation": None,
                "pr": None,
                "first_uncertain_boundary": None,
                "ci": _new_ci(),
                "last_evidence": None,
            } for t in admitted["tasks"]
        },
    }

def _execution_ancestry(entries, task_id):
    lineage, parent = [], entries[task_id]["execution_parent"]
    while parent is not None:
        lineage.append(parent)
        parent = entries[parent]["execution_parent"]
    return list(reversed(lineage))


def _genuinely_unstarted(item, task):
    untouched = (
        "reservation", "claim", "host_worker", "delivery", "verified_pr", "lifecycle",
        "satisfaction", "report", "source", "diff_identity", "checks", "validation", "pr",
        "parent_decision", "first_uncertain_boundary", "last_evidence", "failure_reason",
    )
    return (item.get("status") == "pending" and task.get("existing_delivery") is None
            and all(item.get(key) is None for key in untouched)
            and item.get("ci") == _new_ci(item))

def _legacy_execution_drift_tasks(state):
    recovery = state.get("recovery")
    require(isinstance(recovery, dict), "invalid-state", "recovery state is invalid")
    task_ids = recovery.get("legacy_execution_plan_drift", [])
    require(isinstance(task_ids, list) and all(text(task_id) for task_id in task_ids),
            "invalid-state", "legacy execution-plan drift state is invalid")
    return task_ids



def _known_execution_revision(state, revision):
    return type(revision) is int and (
        revision == state["execution_layout"]["revision"]
        or any(entry.get("from_revision") == revision
               for entry in state.get("execution_plan_history", [])))


def _execution_plan_update(state, admitted, repo):
    current = state["execution_layout"]
    require(type(current.get("revision")) is int and current["revision"] > 0
            and state.get("execution_fingerprint") == digest(current),
            "invalid-state", "retained execution plan identity is invalid")
    if state["execution_fingerprint"] == admitted["execution_fingerprint"]:
        return None
    require(admitted["execution_layout"]["revision"] > current["revision"],
            "execution-plan-drift", "changed execution layout requires a newer plan revision")
    current_entries = {entry["task_id"]: entry for entry in current["entries"]}
    revised_entries = {entry["task_id"]: entry for entry in admitted["execution_layout"]["entries"]}
    changed = set()
    for task in admitted["tasks"]:
        task_id = task["task_id"]
        item = state["tasks"].get(task_id)
        require(isinstance(item, dict), "invalid-state", "retained task is missing")
        retained_parent = current_entries[task_id]["execution_parent"]
        retained_effective = set((item.get("dependency_snapshot") or {}).get(
            "effective_prerequisites", []))
        require(item.get("execution_parent") == retained_parent
                and _known_execution_revision(state, item.get("execution_plan_revision")),
                "invalid-state", "retained task execution identity is invalid")
        if (current_entries[task_id] != revised_entries[task_id]
                or _execution_ancestry(current_entries, task_id) != task["execution_ancestry"]
                or retained_effective != set(task["effective_prerequisites"])):
            changed.add(task_id)
    legacy_drift = set(_legacy_execution_drift_tasks(state))
    for task_id in sorted(changed - legacy_drift):
        require(_genuinely_unstarted(state["tasks"][task_id],
                                     next(task for task in admitted["tasks"]
                                          if task["task_id"] == task_id)),
                "execution-plan-drift", "changed execution plan affects started or reserved work")
    for task_id in sorted(legacy_drift):
        require(task_id in revised_entries, "invalid-state", "legacy drift task is outside the selected scope")
        task = next(task for task in admitted["tasks"] if task["task_id"] == task_id)
        require(repo is not None and legacy_execution_reservation_compatible(
                    repo, state, admitted, task, state["tasks"][task_id].get("reservation")),
                "execution-plan-drift", "legacy task parent is incompatible with the revised plan")
    return {
        "from_revision": current["revision"],
        "from_fingerprint": state["execution_fingerprint"],
        "to_revision": admitted["execution_layout"]["revision"],
        "to_fingerprint": admitted["execution_fingerprint"],
        "changed_tasks": sorted(changed),
    }


def _apply_execution_plan_update(state, admitted, update):
    state["execution_layout"] = copy.deepcopy(admitted["execution_layout"])
    state["execution_fingerprint"] = admitted["execution_fingerprint"]
    for task in admitted["tasks"]:
        item = state["tasks"][task["task_id"]]
        if task["task_id"] in update["changed_tasks"] or _genuinely_unstarted(item, task):
            item.update(
                execution_parent=task["execution_parent"],
                execution_plan_revision=admitted["execution_layout"]["revision"],
                dependency_snapshot=copy.deepcopy(task["dependency_snapshot"]),
            )
    state["recovery"].pop("legacy_execution_plan_drift", None)
    state.setdefault("execution_plan_history", []).append(copy.deepcopy(update))




def state_read(path, admitted, *, allow_execution_plan_update=False, repo=None, active_task_id=None):
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
    legacy_layout = "execution_layout" not in state
    execution_plan_update = None
    execution_plan_error = None
    plan_matches = (state.get("execution_layout") == admitted["execution_layout"]
                    and state.get("execution_fingerprint") == admitted["execution_fingerprint"])
    if legacy_layout:
        state["execution_layout"] = copy.deepcopy(admitted["execution_layout"])
        state["execution_fingerprint"] = admitted["execution_fingerprint"]
    elif not plan_matches:
        if not allow_execution_plan_update:
            item = state.get("tasks", {}).get(active_task_id)
            current_entries = {entry["task_id"]: entry for entry in state["execution_layout"]["entries"]}
            prior_entries = {entry["task_id"]: entry for entry in admitted["execution_layout"]["entries"]}
            historical = (isinstance(item, dict) and active_task_id in current_entries
                          and active_task_id in prior_entries
                          and item.get("execution_plan_revision") == admitted["execution_layout"]["revision"]
                          and any(entry.get("from_fingerprint") == admitted["execution_fingerprint"]
                                  for entry in state.get("execution_plan_history", []))
                          and current_entries[active_task_id] == prior_entries[active_task_id]
                          and _execution_ancestry(current_entries, active_task_id)
                          == _execution_ancestry(prior_entries, active_task_id))
            require(historical, "execution-plan-drift", "controller execution plan changed")
        else:
            try:
                execution_plan_update = _execution_plan_update(state, admitted, repo)
            except InputError as error:
                execution_plan_error = {"code": error.code, "message": str(error)}
            if execution_plan_update is not None:
                state["_execution_plan_update"] = execution_plan_update
            if execution_plan_error is not None:
                state["_execution_plan_error"] = execution_plan_error
    owner = state.get("owner")
    require(isinstance(owner, dict) and text(owner.get("controller_id")),
            "ownership-missing", "controller ownership identity missing")
    require(isinstance(state.get("tasks"), dict)
            and set(state["tasks"]) == {t["task_id"] for t in admitted["tasks"]},
            "invalid-state", "state task identities differ")
    require("scope_evidence" in state
            and (state["scope_evidence"] is None) == (admitted.get("scope_evidence") is None),
            "invalid-state", "scope provenance is missing")
    _legacy_execution_drift_tasks(state)
    admitted_tasks = {task["task_id"]: task for task in admitted["tasks"]}
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
        task = admitted_tasks[item["task_id"]]
        if legacy_layout:
            retained_start = item["status"] != "pending" or not _genuinely_unstarted(item, task)
            require(not retained_start or legacy_execution_reservation_compatible(
                        repo, state, admitted, task, item.get("reservation")),
                    "execution-plan-drift",
                    "legacy task parent is incompatible with the candidate execution layout")
            item["execution_parent"] = task["execution_parent"]
            item["execution_plan_revision"] = admitted["execution_layout"]["revision"]
            item["dependency_snapshot"] = copy.deepcopy(task["dependency_snapshot"])
        elif execution_plan_update is None and execution_plan_error is None:
            if plan_matches or item["task_id"] == active_task_id:
                require(item.get("execution_parent") == task["execution_parent"]
                        and _known_execution_revision(state, item.get("execution_plan_revision"))
                        and item.get("dependency_snapshot") == task["dependency_snapshot"],
                        "invalid-state", "task execution plan identity changed")
        for key in ("lifecycle", "lifecycle_error", "satisfaction", "failure_reason"):
            if key not in item:
                item[key] = None
        ci = item.setdefault("ci", _new_ci(item))
        require(isinstance(ci, dict) and ci.get("state") in CI_STATES
                and isinstance(ci.get("repair_attempts"), list),
                "invalid-state", "CI transition state is invalid")
        require(all(isinstance(attempt, dict)
                    and text(attempt.get("head_sha")) and SHA_RE.fullmatch(attempt["head_sha"])
                    and text(attempt.get("target_sha")) and SHA_RE.fullmatch(attempt["target_sha"])
                    and text(attempt.get("failure_fingerprint"))
                    for attempt in ci["repair_attempts"]),
                "invalid-state", "CI repair attempt identities are malformed")
        if ci.get("state") != "unverified":
            require(item.get("reservation") is not None, "invalid-state",
                    "observed CI state requires a task reservation")
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


def _new_ci(item=None, state="unverified", reason=None):
    head = None
    if isinstance(item, dict):
        head = ((item.get("delivery") or {}).get("head_sha")
                or (item.get("source") or {}).get("head_sha"))
    return {"state": state, "reason": reason, "head_sha": head, "target_sha": None,
            "failure_fingerprint": None, "repair_attempts": [], "invalidates_descendants": False}


def _ci_blocked(item, reason, next_action):
    ci = item.setdefault("ci", _new_ci(item))
    ci.update(state="blocked", reason=reason, next_action=next_action)
    ci.pop("links", None)
    return ci


def _invalidate_descendants(admitted, state, task_id, reason):
    parent = state["tasks"][task_id]
    parent.setdefault("ci", _new_ci(parent))["invalidates_descendants"] = True
    tasks = {task["task_id"]: task for task in admitted["tasks"]}
    affected, frontier = set(), [task_id]
    while frontier:
        predecessor = frontier.pop()
        for child_id, child in state["tasks"].items():
            dependencies = child.get("dependency_snapshot", {})
            if predecessor in dependencies.get(
                    "effective_prerequisites", dependencies.get("prerequisites", [])) \
                    and child_id not in affected:
                affected.add(child_id)
                frontier.append(child_id)
    for child_id in affected:
        child = state["tasks"][child_id]
        if child["status"] != "pending":
            child.setdefault("ci", _new_ci(child))["reconcile_required"] = {
                "parent_task_id": task_id, "reason": reason,
                "parent_head_sha": parent.get("delivery", {}).get("head_sha"),
            }


def _clear_descendant_reconciliation(admitted, state, task_id):
    for task in admitted["tasks"]:
        item = state["tasks"][task["task_id"]]
        ci = item.get("ci")
        if not isinstance(ci, dict) or not isinstance(ci.get("reconcile_required"), dict):
            continue
        if (item["status"] == "pending"
                and ci["reconcile_required"].get("parent_task_id") == task_id):
            ci.pop("reconcile_required")
    parent_ci = state["tasks"][task_id].setdefault("ci", _new_ci())
    parent_ci["invalidates_descendants"] = False
    parent_ci.pop("reconcile_required", None)


def _latest_checks(records, target_sha):
    latest = {}
    for record in records:
        if record["sha"] != target_sha:
            continue
        key = (record["name"], record["source"], record["type"])
        previous = latest.get(key)
        if previous is None or record["attempt"] > previous["attempt"]:
            latest[key] = record
        elif record["attempt"] == previous["attempt"] and record != previous:
            raise InputError("ambiguous-check-attempt",
                             "same-name/source/type records conflict at one attempt")
    return list(latest.values())


def _check_failure_reason(record):
    if record["category"] in ("infrastructure", "approval", "unrelated"):
        return "ci-" + record["category"] + "-blocker"
    if record["category"] != "actionable" or record.get("actionable") is not True:
        return "ci-failure-unactionable"
    log = record.get("log")
    if not isinstance(log, dict) or log.get("accessible") is not True \
            or log.get("complete") is not True or not text(log.get("excerpt")):
        return "ci-log-inaccessible"
    if not text(record.get("diagnosis")):
        return "ci-diagnosis-incomplete"
    return None


def _classify_checks(observation, item, state):
    """Classify one complete, host-assembled observation without making network calls."""
    pr = observation.get("pr")
    require(isinstance(pr, dict), "ci-pr-incomplete", "canonical PR evidence missing")
    field_object(pr, ("url", "repo", "head_repo", "state", "branch", "head_sha",
                      "base_branch", "base_sha"), "CI PR")
    pagination = observation.get("pagination")
    require(isinstance(pagination, dict), "ci-evidence-incomplete", "CI pagination evidence missing")
    if not all(pagination.get(name) is True for name in
               ("check_runs", "commit_statuses", "required_checks", "logs")):
        raise InputError("ci-evidence-incomplete", "CI evidence did not reach terminal pagination")
    required = observation.get("required_checks")
    require(isinstance(required, dict) and type(required.get("complete")) is bool
            and isinstance(required.get("items"), list), "required-check-config-incomplete",
            "required check configuration is incomplete")
    if required["complete"] is not True:
        raise InputError("required-check-config-inaccessible", "required check configuration is inaccessible")
    required_items = required["items"]
    require(all(isinstance(entry, dict) and text(entry.get("name")) and text(entry.get("source"))
                for entry in required_items), "required-check-config-incomplete",
            "required check identity is incomplete")
    required_keys = {(entry["name"], entry["source"]) for entry in required_items}
    require(len(required_keys) == len(required_items), "ambiguous-check-identity",
            "required check configuration contains duplicate identities")
    required_policy = {}
    for entry in required_items:
        allowed = entry.get("accepted_conclusions", list(CI_SUCCESS))
        require(isinstance(allowed, list) and "success" in allowed
                and all(value in CI_SUCCESS for value in allowed),
                "required-check-config-incomplete", "required check conclusions need verified policy")
        required_policy[(entry["name"], entry["source"])] = set(allowed)
    records = observation.get("checks")
    require(isinstance(records, list), "ci-evidence-incomplete", "complete check/status records required")
    normalized = []
    states = set(CI_PENDING + CI_SUCCESS + CI_ACTIONABLE + CI_NONPASS)
    for raw in records:
        require(isinstance(raw, dict), "ci-evidence-incomplete", "check/status record malformed")
        field_object(raw, ("id", "name", "source", "type", "sha", "attempt", "state", "url"),
                     "check/status")
        require(raw["type"] in ("check-run", "commit-status") and raw["state"] in states
                and SHA_RE.fullmatch(raw["sha"])
                and type(raw["attempt"]) is int and raw["attempt"] > 0,
                "ci-evidence-incomplete", "check/status identity or outcome malformed")
        record = copy.deepcopy(raw)
        if record["state"] in CI_ACTIONABLE:
            require(text(record.get("category")) and type(record.get("actionable")) is bool,
                    "ci-classification-incomplete", "failed check needs an explicit classification")
        normalized.append(record)
    test_merge = pr.get("test_merge_sha")
    require("test_merge_sha" in pr and (test_merge is None or SHA_RE.fullmatch(test_merge)),
            "ci-target-incomplete", "test-merge target must be a full SHA or null")
    target_sha = pr["head_sha"]
    if test_merge and any(record["sha"] == test_merge for record in normalized):
        target_sha = test_merge
    current = _latest_checks(normalized, target_sha)
    current_by_key = {(record["name"], record["source"], record["type"]): record
                      for record in current}
    links = [{"name": record["name"], "source": record["source"],
              "type": record["type"], "state": record["state"], "url": record["url"],
              "log_url": (record["log"].get("url") if isinstance(record.get("log"), dict)
                          else None)} for record in current]
    missing = []
    required_nonpass = []
    for name, source in required_keys:
        pair = [record for kind in ("check-run", "commit-status")
                if (record := current_by_key.get((name, source, kind))) is not None]
        if not pair:
            missing.append({"name": name, "source": source})
        elif any(record["state"] in CI_PENDING for record in pair):
            continue
        elif any(record["state"] in CI_ACTIONABLE for record in pair):
            continue
        elif any(record["state"] not in required_policy[(name, source)] for record in pair):
            required_nonpass.append({"name": name, "source": source})
    failures = []
    for record in current:
        if record["state"] not in CI_ACTIONABLE:
            continue
        reason = _check_failure_reason(record)
        if reason is not None:
            raise InputError(reason, "current failed check is not eligible for automatic repair")
        failures.append(record)
    if required_nonpass:
        raise InputError("required-check-not-passing", "required check conclusions violate repository policy")
    if failures:
        fingerprint = digest(sorted(
            ({key: record.get(key) for key in
              ("name", "source", "type", "state", "category", "diagnosis")}
             for record in failures),
            key=lambda record: (record["name"], record["source"], record["type"],
                                record["state"], record["category"], record["diagnosis"]),
        ))
        ci = item.setdefault("ci", _new_ci(item))
        if any(attempt.get("failure_fingerprint") == fingerprint
               for attempt in ci.get("repair_attempts", [])):
            raise InputError("repeated-identical-failure",
                             "the same diagnosed failure already received a bounded repair")
        if len(ci.get("repair_attempts", [])) >= DEFAULT_CI_REPAIR_LIMIT:
            raise InputError("repair-retry-exhausted", "finite CI repair retry policy is exhausted")
        ci.update(state="repair", reason="ci-failure", head_sha=pr["head_sha"],
                  target_sha=target_sha, failure_fingerprint=fingerprint,
                  next_action="dispatch one bounded Execute repair for the retained PR")
        ci["links"] = links
        ci["repair_context"] = {
            "kind": "remote-ci", "pr_url": pr["url"], "branch": pr["branch"],
            "head_sha": pr["head_sha"], "target_sha": target_sha,
            "base_branch": pr["base_branch"], "base_sha": pr["base_sha"],
            "objective": "Make the smallest evidence-backed in-scope correction and update the retained PR.",
            "failures": copy.deepcopy(failures),
        }
        return ci
    if missing or not current or any(record["state"] in CI_PENDING for record in current):
        ci = item.setdefault("ci", _new_ci(item))
        ci.update(state="checking", reason="ci-pending-or-missing", head_sha=pr["head_sha"],
                  target_sha=target_sha, failure_fingerprint=None,
                  next_action="observe the current revision again without dispatching a repair")
        ci["links"] = links
        return ci
    if item["status"] != "delivered" or not isinstance(item.get("delivery"), dict):
        _ci_blocked(item, "delivery-validation-incomplete",
                    "complete delivery evidence before accepting remote CI success")
        return item["ci"]
    if item["delivery"]["head_sha"] != pr["head_sha"] \
            or item["delivery"].get("base_branch") != pr["base_branch"]:
        _ci_blocked(item, "delivery-revision-mismatch",
                    "independently revalidate delivery at the observed PR revision")
        return item["ci"]
    ci = item.setdefault("ci", _new_ci(item))
    ci.update(state="verified", reason="current-required-checks-passed", head_sha=pr["head_sha"],
              target_sha=target_sha, failure_fingerprint=None,
              next_action="continue observing while the active Orchestrate run remains open")
    ci["links"] = links
    return ci



def _observed_ci(admitted, state, item, observation, repo=None):
    task = next(task for task in admitted["tasks"] if task["task_id"] ==
                next(tid for tid, value in state["tasks"].items() if value is item))
    try:
        pr = observation.get("pr") if isinstance(observation, dict) else None
        require(isinstance(pr, dict), "ci-pr-incomplete", "canonical PR evidence missing")
        match = PR_RE.fullmatch(pr.get("url") or "")
        require(match and "https://github.com/" + "/".join(match.groups()[:2]) == admitted["canonical_repo"]
                and SHA_RE.fullmatch(pr.get("head_sha") or "") is not None
                and SHA_RE.fullmatch(pr.get("base_sha") or "") is not None,
                "ci-pr-identity-mismatch", "observation does not identify the retained canonical PR revision")
        require(pr.get("url") == item.get("verified_pr")
                and pr.get("repo") == pr.get("head_repo") == admitted["canonical_repo"]
                and pr.get("state") in ("open", "closed", "merged"),
                "ci-pr-identity-mismatch", "observation does not identify the retained canonical PR")
        require(item.get("delivery") and item.get("reservation"),
                "ci-delivery-unavailable", "independently verified delivery is required before monitoring")
        delivery, reservation = item["delivery"], item["reservation"]
        require(pr.get("branch") == delivery["branch"] == reservation["branch"]
                and pr.get("base_branch") == delivery["base_branch"] == reservation["parent_branch"],
                "external-head-change", "PR branch/base must match the independently verified delivery")
        if pr.get("head_sha") != delivery["head_sha"]:
            if (repo is not None and branch_tip(repo, delivery["branch"]) == delivery["head_sha"]
                    and any(attempt.get("head_sha") == pr["head_sha"]
                            for attempt in item.get("ci", {}).get("repair_attempts", []))):
                return item.setdefault("ci", _new_ci(item))
            raise InputError("external-head-change", "PR head changed outside the verified delivery")
        if repo is not None:
            require(branch_tip(repo, delivery["branch"]) == pr["head_sha"]
                    and branch_tip(repo, delivery["base_branch"]) == pr["base_sha"],
                    "ci-pr-revision-stale", "PR head/base no longer match current local branch tips")
        if pr["state"] != "open":
            raise InputError("pr-not-open", "closed or merged PRs are never reopened or modified automatically")
        if item.get("ci", {}).get("reconcile_required"):
            _ci_blocked(item, "parent-revision-changed",
                        "reconcile this descendant against the advanced parent in its own exclusive task")
            return item["ci"]
        _classify_checks(observation, item, state)
    except (InputError, KeyError, TypeError, ValueError) as error:
        reason = _safe_reason(error, "ci-evidence-incomplete")
        if reason in ("external-head-change", "ci-pr-revision-stale", "delivery-revision-mismatch"):
            next_action = "reconcile current PR/branch/base ownership before any repair"
        elif reason == "pr-not-open":
            next_action = "verify closed/merged PR state; do not reopen automatically"
        else:
            next_action = "refresh authoritative PR/check/status/log evidence before any repair"
        _ci_blocked(item, reason, next_action)
        if (reason in ("required-check-not-passing", "external-head-change", "pr-not-open",
                       "delivery-revision-mismatch") or reason.startswith("ci-")):
            _invalidate_descendants(admitted, state, task["task_id"], reason)
    else:
        if item["ci"]["state"] in ("repair", "blocked"):
            _invalidate_descendants(admitted, state, task["task_id"], item["ci"]["reason"])
        elif item["ci"]["state"] == "verified":
            _clear_descendant_reconciliation(admitted, state, task["task_id"])
    workspace_reopen = observation.get("workspace_reopen") if isinstance(observation, dict) else None
    if isinstance(workspace_reopen, dict):
        item.setdefault("ci", _new_ci(item))["workspace_reopen"] = copy.deepcopy(workspace_reopen)
    return item["ci"]


def cmd_observe_checks(args):
    admitted = load_json(args.admitted)
    repository(args.git_repo, admitted["canonical_repo"])
    state = state_read(args.state, admitted, repo=args.git_repo, active_task_id=args.task)
    require(args.task in state["tasks"], "unknown-task", "task outside admitted scope")
    item = state["tasks"][args.task]
    require(item["status"] == "delivered" and isinstance(item.get("delivery"), dict),
            "not-delivered", "monitoring requires independently verified delivery")
    task = next(task for task in admitted["tasks"] if task["task_id"] == args.task)
    claim_scope(args.git_repo, admitted, state)
    claim_task(args.git_repo, admitted, task, state, item)
    observation = load_json(args.observation)
    _observed_ci(admitted, state, item, observation, args.git_repo)
    write_state(args, state)
    ci = item["ci"]
    return {"status": "ci-observed", "task_id": args.task, "ci_state": ci["state"],
            "reason": ci.get("reason"), "next_action": ci.get("next_action"),
            "repair_context": copy.deepcopy(ci.get("repair_context")) if ci["state"] == "repair" else None,
            **_state_summary(state, blocked=[{"task_id": args.task, "reason": ci.get("reason"),
                                               "next_action": ci.get("next_action")}]
                             if ci["state"] == "blocked" else [])}


def _repair_attempt(item):
    ci = item.get("ci", {})
    if ci.get("state") != "repair":
        return
    attempts = ci.setdefault("repair_attempts", [])
    attempts.append({"head_sha": ci["head_sha"], "target_sha": ci.get("target_sha"),
                     "failure_fingerprint": ci.get("failure_fingerprint")})



def _reopen_repair_workspace(repo, admitted, state, item):
    reservation = item["reservation"]
    workspace = Path(reservation["workspace"])
    if workspace.exists():
        identity = workspace_identity(repo, admitted["canonical_repo"], workspace, reservation["branch"])
        require(not git(workspace, "status", "--porcelain=v2", "--untracked-files=all").decode(),
                "workspace-dirty", "repair requires the retained worktree to be clean")
        return identity
    ci = item.get("ci", {})
    proof = ci.get("workspace_reopen")
    release = proof.get("release") if isinstance(proof, dict) and isinstance(proof.get("release"), dict) else proof
    task_id = item.get("task_id") or next((tid for tid, value in state["tasks"].items() if value is item), None)
    claim = item.get("claim") or {}
    require(isinstance(proof, dict) and proof.get("released") is True
            and proof.get("path") == str(workspace)
            and proof.get("branch") == reservation["branch"]
            and proof.get("base_branch") == item.get("delivery", {}).get("base_branch")
            and proof.get("head_sha") == item.get("delivery", {}).get("head_sha"),
            "workspace-release-unverified", "released repair worktree needs revision-bound release proof")
    require(isinstance(release, dict) and release.get("complete") is True
            and release.get("task_id") == task_id
            and release.get("path") == str(workspace)
            and release.get("branch") == reservation["branch"]
            and release.get("head_sha") == item.get("delivery", {}).get("head_sha")
            and release.get("pr_url") == item.get("verified_pr")
            and release.get("writer_status") == "stopped"
            and release.get("claim_owner") == claim.get("owner"),
            "workspace-release-unverified", "host evidence does not prove writer release and task ownership")
    require(branch_tip(repo, reservation["branch"]) == proof["head_sha"]
            and contains(repo, reservation["parent_sha"], proof["head_sha"]),
            "branch-revision-drift", "released branch no longer matches the diagnosed PR revision")
    inventory = worktree_inventory(repo)
    require(not any(Path(entry["worktree"]).resolve() == workspace.resolve()
                    or entry.get("branch") == "refs/heads/" + reservation["branch"]
                    for entry in inventory),
            "workspace-release-unverified", "released worktree is still registered or its branch is checked out")
    return {"workspace": str(workspace), "branch": reservation["branch"],
            "head_sha": proof["head_sha"]}


def _ci_dependency_blocked(item):
    if item.get("lifecycle_error"):
        return True
    if item.get("satisfaction", {}).get("kind") == "merged":
        return False
    ci = item.get("ci", {})
    return ci.get("state") in ("unverified", "checking", "repair", "blocked") or ci.get("invalidates_descendants") is True


def _reset_ci_after_delivery(admitted, state, item, head_sha):
    previous = item.get("ci", {}) if isinstance(item.get("ci"), dict) else {}
    reconcile = copy.deepcopy(previous.get("reconcile_required"))
    attempts = copy.deepcopy(previous.get("repair_attempts", []))
    item["ci"] = _new_ci(item, "checking", "awaiting-current-remote-ci")
    item["ci"]["head_sha"] = head_sha
    item["ci"]["repair_attempts"] = attempts
    if reconcile is not None:
        item["ci"]["reconcile_required"] = reconcile
        _ci_blocked(item, "parent-revision-changed",
                    "reconcile this descendant against the advanced parent in its own exclusive task")
        _invalidate_descendants(admitted, state,
                                next(tid for tid, value in state["tasks"].items() if value is item),
                                "parent-revision-changed")


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


def initial_lifecycle(result):
    readback = result["readback"]
    return {
        "pr": {
            "pr_url": readback["pr_url"], "repo": readback["repo"],
            "head_repo": readback["head_repo"], "branch": readback["branch"],
            "head_sha": readback["head_sha"], "base_branch": readback["base_branch"],
            "state": "open", "draft": readback["draft"],
        },
        "source": {"branch": readback["branch"], "head_sha": readback["head_sha"], "deleted": False},
        "checks": None,
    }


def lifecycle_state(lifecycle):
    if not isinstance(lifecycle, dict):
        return None
    pr = lifecycle.get("pr", lifecycle)
    return pr.get("state") if isinstance(pr, dict) else None


def prerequisite_satisfaction(item, task, repo, lifecycle=None, canonical=None, *, verify_checks=True):
    delivery = item.get("delivery")
    require(isinstance(delivery, dict), "prerequisites-unmet", "verified delivery missing for " + task["task_id"])
    require(isinstance(lifecycle, dict) and lifecycle,
            "pr-lifecycle-missing", "current PR lifecycle evidence is missing")
    pr = lifecycle.get("pr", lifecycle)
    require(isinstance(pr, dict), "pr-lifecycle-missing", "current PR lifecycle evidence is missing")
    url = pr.get("pr_url", pr.get("url"))
    require(url == delivery["pr_url"] and (canonical is None or
            (pr.get("repo") == canonical and pr.get("head_repo") == canonical)),
            "pr-lifecycle-identity", "current PR lifecycle identifies another delivery")
    require(pr.get("branch") == delivery["branch"] and text(pr.get("head_sha"))
            and SHA_RE.fullmatch(pr["head_sha"]), "pr-lifecycle-identity", "current PR head identity is incomplete")
    require(pr.get("state") in ("open", "closed", "merged"),
            "pr-lifecycle-state", "current PR lifecycle state is invalid")
    if pr["state"] == "closed":
        raise InputError("pr-closed-unmerged", "prerequisite PR closed without a verified merge")
    if pr["state"] == "open":
        require(pr["head_sha"] == delivery["head_sha"], "pr-lifecycle-head",
                "open prerequisite PR no longer describes the verified delivery")
        require(pr.get("base_branch") == delivery["base_branch"], "pr-lifecycle-base",
                "open prerequisite PR no longer targets the verified delivery base")
        source = lifecycle.get("source")
        require(isinstance(source, dict) and source.get("branch") == delivery["branch"]
                and source.get("head_sha") == delivery["head_sha"] and source.get("deleted") is False,
                "pr-source-mismatch", "open prerequisite source evidence does not match the verified delivery")
        require(branch_tip(repo, delivery["branch"]) == delivery["head_sha"],
                "pr-branch-missing", "open prerequisite source branch is missing or changed")
        if verify_checks:
            checks = lifecycle.get("checks")
            if checks is None:
                raise InputError("pr-check-evidence-missing",
                                 "current prerequisite check evidence is missing")
            require(isinstance(checks, dict) and checks.get("complete") is True
                    and checks.get("state") in ("success", "verified")
                    and checks.get("head_sha") == delivery["head_sha"],
                    "pr-check-unverified", "current prerequisite checks are not successful")
        return {"kind": "open", "revision": delivery["head_sha"], "branch": delivery["branch"],
                "pr_url": delivery["pr_url"], "checkpoint": copy.deepcopy(delivery["checkpoint"]),
                "lifecycle": copy.deepcopy(lifecycle)}
    require(pr.get("base_branch") == delivery["base_branch"], "pr-lifecycle-base",
            "merged prerequisite PR no longer identifies the verified delivery base")
    merge_sha = pr.get("merge_commit_sha") or lifecycle.get("landed_revision")
    target = pr.get("merged_base_branch") or lifecycle.get("landing_target")
    require(SHA_RE.fullmatch(merge_sha or "") and text(target),
            "pr-merge-evidence-incomplete", "merged PR lacks landed revision and target evidence")
    target_tip = branch_tip(repo, target)
    require(target_tip is not None and contains(repo, merge_sha, target_tip),
            "pr-merge-target-mismatch", "merged prerequisite is not contained in its stated landing target")
    verification = lifecycle.get("landed_verification") or lifecycle.get("verification")
    require(isinstance(verification, dict) and verification.get("complete") is True
            and verification.get("source_verified") is True
            and verification.get("checks_verified") is True
            and verification.get("reverted") is not True
            and text(verification.get("diff_identity")),
            "landed-evidence-missing", "landed prerequisite needs task-relevant source and check evidence")
    landed_parent = git(repo, "rev-parse", merge_sha + "^").decode().strip()
    candidate_parents = [landed_parent]
    declared_parent = verification.get("landed_parent")
    if declared_parent is not None:
        require(SHA_RE.fullmatch(declared_parent),
                "landed-evidence-missing", "landed parent evidence is not a commit")
        candidate_parents.append(declared_parent)
    reservation_parent = (item.get("reservation") or {}).get("parent_sha")
    if SHA_RE.fullmatch(reservation_parent or ""):
        candidate_parents.append(reservation_parent)
    actual_diffs = {
        "sha256:" + hashlib.sha256(git(
            repo, "diff", "--no-ext-diff", "--no-textconv", "--no-color", "--binary",
            parent, merge_sha)).hexdigest()
        for parent in dict.fromkeys(candidate_parents)
    }
    require(verification["diff_identity"] in actual_diffs
            and verification["diff_identity"] == delivery["validated_diff"],
            "landed-diff-mismatch", "landed evidence does not match the verified task diff")
    source = lifecycle.get("source")
    require(isinstance(source, dict) and source.get("branch") == delivery["branch"],
            "pr-source-mismatch", "merged prerequisite source evidence identifies another branch")
    if source.get("deleted") is not True:
        require(source.get("head_sha") == pr["head_sha"]
                and branch_tip(repo, delivery["branch"]) == source["head_sha"],
                "pr-source-mismatch", "merged prerequisite source evidence does not match the current PR")
    return {"kind": "merged", "revision": merge_sha, "branch": delivery["branch"],
            "pr_url": delivery["pr_url"], "landing_branch": target, "landing_sha": target_tip,
            "checkpoint": copy.deepcopy(delivery["checkpoint"]), "lifecycle": copy.deepcopy(lifecycle)}
def legacy_execution_reservation_compatible(repo, state, admitted, task, reservation):
    if not isinstance(reservation, dict) or repo is None:
        return False
    planned_parent = task["execution_parent"]
    expected_branches = {admitted["integration"]["branch"]} if planned_parent is None else set()
    planned_item = state["tasks"].get(planned_parent, {})
    planned_delivery = planned_item.get("delivery") or {}
    planned_branch = planned_delivery.get("branch")
    if text(planned_branch):
        expected_branches.add(planned_branch)
    planned_lifecycle = planned_item.get("lifecycle") or {}
    planned_pr = planned_lifecycle.get("pr", planned_lifecycle) \
        if isinstance(planned_lifecycle, dict) else {}
    if isinstance(planned_pr, dict) and planned_pr.get("state") == "merged" \
            and (planned_pr.get("merged_base_branch")
                 or planned_lifecycle.get("landing_target")) == admitted["integration"]["branch"]:
        expected_branches.add(admitted["integration"]["branch"])
    return (reservation["parent_branch"] in expected_branches
            and legacy_execution_parent_compatible(repo, state, admitted, task, reservation))


def legacy_execution_parent_compatible(repo, state, admitted, task, reservation):
    admitted_tasks = {item["task_id"]: item for item in admitted["tasks"]}
    current = task
    first = True
    seen = set()
    while isinstance(current, dict) and current["task_id"] not in seen:
        seen.add(current["task_id"])
        base_satisfied = set(current.get("base_satisfied_prerequisites", []))
        execution_parent = current.get("execution_parent")
        for predecessor_id in current.get("effective_prerequisites", []):
            if predecessor_id in base_satisfied:
                continue
            item = state["tasks"].get(predecessor_id)
            predecessor = admitted_tasks.get(predecessor_id)
            if not isinstance(item, dict) or not isinstance(predecessor, dict):
                return False
            try:
                satisfaction = prerequisite_satisfaction(
                    item, predecessor, repo, lifecycle=item.get("lifecycle"),
                    canonical=admitted["canonical_repo"], verify_checks=False)
            except InputError:
                return False
            if not contains(repo, satisfaction["revision"], reservation["parent_sha"]):
                return False
            if first and predecessor_id == execution_parent:
                expected_branch = (satisfaction["branch"] if satisfaction["kind"] == "open"
                                   else admitted["integration"]["branch"])
                if reservation["parent_branch"] != expected_branch:
                    return False
        for predecessor_id in sorted(base_satisfied):
            predecessor = admitted_tasks.get(predecessor_id)
            delivery = predecessor.get("existing_delivery") if isinstance(predecessor, dict) else None
            lifecycle = delivery.get("lifecycle") if isinstance(delivery, dict) else None
            pr = lifecycle.get("pr", lifecycle) if isinstance(lifecycle, dict) else None
            revision = ((pr.get("merge_commit_sha") if isinstance(pr, dict) else None)
                        or (lifecycle.get("landed_revision") if isinstance(lifecycle, dict) else None))
            if not SHA_RE.fullmatch(revision or "") or not contains(
                    repo, revision, reservation["parent_sha"]):
                return False
        if first and execution_parent in base_satisfied:
            if reservation["parent_branch"] != admitted["integration"]["branch"]:
                return False
        first = False
        current = admitted_tasks.get(execution_parent)
    return True




def base_satisfied_entries(scope, task):
    return next(entry["base_satisfied_prerequisites"] for entry in scope["execution_layout"]["entries"]
                if entry["task_id"] == task["task_id"])


def parent_readiness(scope, task, state, reservation, decision, repo, retained=False):
    require(not task["external_prerequisites"], "external-prerequisite", "retained task has external blockers")
    technical = set(task["prerequisites"])
    effective = task["effective_prerequisites"]
    predecessors = []
    satisfactions = {}
    for tid in effective:
        item = state["tasks"][tid]
        satisfaction = prerequisite_satisfaction(
            item, task, repo, lifecycle=item.get("lifecycle"), canonical=scope["canonical_repo"])
        predecessors.append((tid, item["delivery"], satisfaction))
        satisfactions[tid] = satisfaction
    branch, head = reservation["parent_branch"], reservation["parent_sha"]
    if decision is not None:
        require(isinstance(decision, dict) and decision.get("branch") == branch and decision.get("sha") == head,
                "decision-rejected", "decision cannot replace the reserved parent")
    selected = next((entry for entry in predecessors
                     if (entry[2]["kind"] == "open" or retained)
                     and entry[1]["branch"] == branch and entry[1]["head_sha"] == head), None)
    if not effective:
        require((task["execution_parent"] is None
                 or task["execution_parent"] in task["base_satisfied_prerequisites"])
                and branch == scope["integration"]["branch"],
                "unapproved-parent", "root delivery must retain the admitted integration branch")
        current = branch_tip(repo, branch)
        require(current is not None and (contains(repo, head, current) if retained else current == head),
                "parent-tip-drift", "selected parent changed incompatibly")
        kind = "integration"
    elif selected is not None:
        if task["execution_parent"] is None:
            require(task["execution_fallback"] is not None, "unapproved-parent",
                    "a dependent task needs a selected execution parent or merge fallback")
            kind = "fallback-parent"
        else:
            require(task["execution_parent"] == selected[0], "unapproved-parent",
                    "reserved parent differs from the execution plan")
            kind = "technical-parent" if selected[0] in technical else "stack-parent"
        current = branch_tip(repo, branch) or (head if retained else None)
        require(current == head or (retained and contains(repo, head, current)),
                "parent-tip-drift", "selected parent changed incompatibly")
    elif branch == scope["integration"]["branch"] and head == scope["integration"]["sha"]:
        planned = task["execution_parent"]
        require(planned is None or planned in task["base_satisfied_prerequisites"]
                or satisfactions[planned]["kind"] == "merged",
                "unapproved-parent", "integration cannot replace an open execution parent")
        current = branch_tip(repo, branch)
        require(current == head, "parent-tip-drift", "selected parent changed incompatibly")
        kind = "landed-stack-parent" if planned is not None else "integration"
    else:
        require(task["execution_parent"] is None and isinstance(decision, dict)
                and decision.get("branch") == branch and decision.get("sha") == head,
                "unapproved-parent", "retained integration choice requires its explicit approved decision")
        current = branch_tip(repo, branch) or (head if retained else None)
        require(current is not None and contains(repo, head, current),
                "parent-tip-drift", "selected parent changed incompatibly")
        kind = "explicit"
    proof = parent_pr_evidence(scope, branch, current,
                               selected[1]["checkpoint"] if selected is not None else None)
    records = []
    for tid, delivery, satisfaction in predecessors:
        revision = delivery["head_sha"] if retained and selected is not None and selected[0] == tid \
            else satisfaction["revision"]
        require(contains(repo, revision, head), "uncontained-prerequisite",
                "selected parent does not contain " + tid)
        records.append({"task_id": tid, "issue_url": delivery["association"],
                        "relationship": "technical+stack" if tid in technical
                        and tid == task["execution_parent"] else "technical" if tid in technical else "stack",
                        "checkpoint": copy.deepcopy(delivery["checkpoint"]),
                        "satisfaction": copy.deepcopy(satisfaction),
                        "containment": {"ancestor": revision, "descendant": head,
                                        "verified": True}})
    for entry in base_satisfied_entries(scope, task):
        require(contains(repo, entry["revision"], head), "uncontained-prerequisite",
                "selected parent does not contain base-satisfied prerequisite " + entry["task_id"])
    return {"logical_prerequisites": list(task["prerequisites"]),
            "execution_prerequisites": list(effective),
            "base_satisfied_prerequisites": list(task["base_satisfied_prerequisites"]),
            "external_prerequisites": [],
            "execution_parent": task["execution_parent"],
            "execution_ancestry": list(task["execution_ancestry"]),
            "execution_rationale": task["execution_rationale"],
            "execution_constraints": copy.deepcopy(task["execution_constraints"]),
            "execution_fallback": copy.deepcopy(task["execution_fallback"]),
            "prerequisites": records,
            "parent": {"branch": branch, "sha": head, "current_sha": current, "selection": kind,
                       "pr_evidence": proof},
            "decision": copy.deepcopy(decision) if kind == "explicit" else None}


def delivery_head_diff(repo, reservation, head_sha):
    """Validate original delivery when its commit is locally available."""
    if git(repo, "cat-file", "-e", head_sha + "^{commit}", allow_missing=True) is None:
        return None
    if contains(repo, reservation["parent_sha"], head_sha):
        return "sha256:" + hashlib.sha256(git(
            repo, "diff", "--no-ext-diff", "--no-textconv", "--no-color", "--binary",
            reservation["parent_sha"], head_sha)).hexdigest()
    return None


def validate_delivery(admitted, task, reservation, result, repo, *, historical=False,
                      retained_diff=None, workspace_required=True, existing_pr=False):
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
    require(type(readback["draft"]) is bool, "invalid-pr-readback", "PR draft readback must be boolean")
    if not existing_pr:
        require(readback["draft"] is True, "draft-required", "new orchestrated delivery must be a draft")
    review_readback(readback["reviews"], readback["head_sha"], "reviews")
    review_readback(readback["threads"], readback["head_sha"], "threads")
    require(readback["branch"] == reservation["branch"], "wrong-branch", "PR head is not reserved branch")
    require(readback["base_branch"] == reservation["parent_branch"], "wrong-base", "PR base is not admitted parent")
    require(readback["association"] == task["url"] and readback["closing_references"] == [task["url"]],
            "wrong-association", "exactly the task issue may be a closing reference")
    if historical:
        head_present = git(repo, "cat-file", "-e", readback["head_sha"] + "^{commit}", allow_missing=True) is not None
        if not head_present:
            require(isinstance(retained_diff, str)
                    and re.fullmatch(r"sha256:[0-9a-f]{64}", retained_diff),
                    "historical-delivery-missing", "retained validated diff is required when the source head is unavailable")
            actual_diff = retained_diff
        else:
            actual_diff = delivery_head_diff(repo, reservation, readback["head_sha"])
            require(actual_diff is not None, "wrong-ancestry",
                    "historical source head is not descended from the admitted start")
    else:
        evidence_repo = repo
        if workspace_required:
            identity = workspace_identity(repo, admitted["canonical_repo"],
                                         reservation["workspace"], reservation["branch"])
            evidence_repo = reservation["workspace"]
            actual_head = identity["head_sha"]
        else:
            require(branch_tip(repo, reservation["branch"]) == readback["head_sha"],
                    "delivery-revision-mismatch", "repair source branch no longer matches the retained delivery")
            actual_head = readback["head_sha"]
        require(readback["commit_sha"] == readback["head_sha"] == actual_head,
                "wrong-head", "commit and actual source head must agree")
        actual_diff = delivery_head_diff(evidence_repo, reservation, readback["head_sha"])
        require(actual_diff is not None, "wrong-ancestry", "admitted start is not an ancestor")
    checks = field_object(result.get("checks"), ("passed", "commands", "head_sha", "diff_identity", "smoke"), "checks")
    validation = field_object(result.get("validation"), ("verdict", "reviewer_id", "diff_identity", "contract_hash", "checked_head"), "validation")
    require(checks["head_sha"] == validation["checked_head"] == readback["head_sha"],
            "stale-validation", "verification/review head mismatch")
    require(readback["diff_identity"] == actual_diff,
            "diff-mismatch", "worker readback does not describe the actual workspace diff")
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
    if admitted.get("project") is not None:
        if result.get("project_status") is None:
            return {"status": "note-pending", "reason": "project-status-readback", "delivery": delivery}
        progress = field_object(result.get("project_status"),
                                ("project_url", "issue_url", "item_id", "status"),
                                "Project status readback")
        require(progress["item_id"] == task["item_id"] and progress["project_url"] == admitted["project"]["url"]
                and progress["issue_url"] == task["url"]
                and progress["status"] == admitted["lifecycle"]["inReview"],
                "project-status-mismatch", "verified Project inReview readback required")
    return {"status": "delivered", "delivery": delivery}

def packet(admitted, task, reservation, repair, retained, readiness, scope_evidence=None, repair_context=None):
    specification = task["specification"]
    execution_order = {
        "plan_revision": admitted["execution_layout"]["revision"],
        "execution_parent": task["execution_parent"],
        "rationale": task["execution_rationale"],
        "constraints": copy.deepcopy(task["execution_constraints"]),
        "fallback": copy.deepcopy(task["execution_fallback"]),
        "effective_prerequisites": list(task["effective_prerequisites"]),
        "base_satisfied_prerequisites": list(task["base_satisfied_prerequisites"]),
        "ancestry": list(task["execution_ancestry"]),
    }
    result = {
        "task_id": task["task_id"], "ordinal": task["ordinal"], "child_issue_url": task["url"],
        "scope_url": task["url"], "specification": specification,
        "repository_rules": admitted["repository_rules"],
        "bounded_input": copy.deepcopy(task["contract"]), "acceptance": task["contract"]["acceptance"],
        "parent_readiness": readiness,
        "dependency_edges": copy.deepcopy(task.get("edge_provenance", [])),
        "graph": copy.deepcopy(admitted["graph"]),
        "execution_layout": copy.deepcopy(admitted["execution_layout"]),
        "execution_order": execution_order,
        "checks": task["contract"]["checks"], "contract_hash": task["contract_hash"],
        "scope_evidence": copy.deepcopy(scope_evidence),
        "repair_evidence": copy.deepcopy(repair_context),
        "execute_skill": "woostack-execute", "repair": repair, "retained_pr": retained,
        **reservation,
    }
    if "actual_parent" in task:
        result["parent_issue_url"] = task["actual_parent"]
        if scope_evidence is not None:
            result["parent_issue_read"] = "complete"
    evidence = ((scope_evidence or {}).get("membership") or {}).get("evidence")
    if "actual_parent" not in task and isinstance(evidence, dict) and "actual_parent_read" in evidence:
        result["parent_issue_read"] = evidence["actual_parent_read"]
    return result


def choose_parent(scope, task, state, decisions, repo):
    effective = task["effective_prerequisites"]
    satisfactions = {
        tid: prerequisite_satisfaction(
            state["tasks"][tid], task, repo, lifecycle=state["tasks"][tid].get("lifecycle"),
            canonical=scope["canonical_repo"])
        for tid in effective
    }
    planned = task["execution_parent"]
    if not effective:
        candidates = [scope["integration"]]
    elif planned is not None and planned not in task["base_satisfied_prerequisites"]:
        planned_satisfaction = satisfactions[planned]
        candidates = [{"branch": planned_satisfaction["branch"], "sha": planned_satisfaction["revision"]}] \
            if planned_satisfaction["kind"] == "open" else [scope["integration"]] \
            if planned_satisfaction["kind"] == "merged" else []
    else:
        candidates = [scope["integration"]]
        if task["task_id"] in decisions:
            candidates.append(decisions[task["task_id"]])
        candidates.extend({"branch": satisfaction["branch"], "sha": satisfaction["revision"]}
                          for satisfaction in satisfactions.values() if satisfaction["kind"] == "open")
    heads = [satisfaction["revision"] for satisfaction in satisfactions.values()]
    heads.extend(entry["revision"] for entry in base_satisfied_entries(scope, task))
    seen = set()
    for candidate in candidates:
        require(isinstance(candidate, dict) and text(candidate.get("branch"))
                and SHA_RE.fullmatch(candidate.get("sha") or ""),
                "decision-rejected", "parent decision needs branch and full SHA")
        key = (candidate["branch"], candidate["sha"])
        if key in seen:
            continue
        seen.add(key)
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
        "checking": sorted(tid for tid, item in tasks.items()
                           if item.get("ci", {}).get("state") == "checking"),
        "verified": sorted(tid for tid, item in tasks.items()
                           if item.get("ci", {}).get("state") == "verified"),
        "ci_blocked": sorted(tid for tid, item in tasks.items()
                             if item.get("ci", {}).get("state") == "blocked"),
        "repair": sorted(tid for tid, item in tasks.items()
                         if item.get("ci", {}).get("state") == "repair"),
        "ci_details": {
            tid: {"state": item["ci"]["state"], "pr_url": item.get("verified_pr"),
                  "head_sha": item["ci"].get("head_sha"), "target_sha": item["ci"].get("target_sha"),
                  "reason": item["ci"].get("reason"), "next_action": item["ci"].get("next_action"),
                  "links": copy.deepcopy(item["ci"].get("links", []))}
            for tid, item in sorted(tasks.items()) if item.get("ci", {}).get("state") != "unverified"
        },
        "reconciliation_required": sorted(tid for tid, item in tasks.items()
                                          if item.get("ci", {}).get("reconcile_required")),
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
        item.setdefault("lifecycle", initial_lifecycle(result))
    if isinstance(result.get("checks"), dict):
        item["checks"] = copy.deepcopy(result["checks"])
    if isinstance(result.get("validation"), dict):
        item["validation"] = copy.deepcopy(result["validation"])

def reconcile_delivery(admitted, task, item, retained, repo, *, repairing=False, workspace_required=True):
    explicit_lifecycle = retained.get("lifecycle")
    require(isinstance(explicit_lifecycle, dict) and explicit_lifecycle,
            "pr-lifecycle-missing", "fresh canonical PR lifecycle evidence is required")
    lifecycle = explicit_lifecycle
    if repairing:
        require(lifecycle_state(lifecycle) == "open", "pr-not-open",
                "CI repair requires a current open PR lifecycle")
    historical = lifecycle_state(lifecycle) == "merged"
    prior_delivery = item.get("delivery")
    prior_diff = prior_delivery.get("validated_diff") if isinstance(prior_delivery, dict) else None
    proof = validate_delivery(admitted, task, retained["reservation"], retained["result"], repo,
                              historical=historical, retained_diff=prior_diff,
                              workspace_required=workspace_required, existing_pr=True)
    delivery = proof.get("delivery")
    if delivery is None:
        return proof, lifecycle, None
    probe = copy.copy(item)
    probe["delivery"] = delivery
    probe["lifecycle"] = lifecycle
    satisfaction = prerequisite_satisfaction(probe, task, repo, lifecycle=lifecycle,
                                             canonical=admitted["canonical_repo"],
                                             verify_checks=not repairing)
    if lifecycle_state(lifecycle) == "open" and not repairing:
        checks = lifecycle.get("checks")
        if isinstance(checks, dict) and checks.get("complete") is True \
                and checks.get("state") in ("success", "verified") \
                and checks.get("head_sha") == delivery["head_sha"]:
            item["ci"] = copy.deepcopy(item.get("ci", _new_ci(item)))
            item["ci"].update(state="verified", head_sha=delivery["head_sha"],
                              target_sha=delivery["head_sha"], reason=None, next_action=None)
    return proof, lifecycle, satisfaction


def _safe_reason(error, default="blocked"):
    return getattr(error, "code", default)


def _dependency_wait_reason(task, state):
    statuses = {task_id: state["tasks"][task_id]["status"] for task_id in task["effective_prerequisites"]}
    if any(status == "unknown" for status in statuses.values()):
        return "prerequisite-unknown"
    if any(statuses[task_id] != "delivered"
           for task_id in set(task["prerequisites"]) & statuses.keys()):
        return "prerequisites-unmet"
    return "execution-parent-unmet"




def cmd_schedule(args):
    admitted = load_json(args.admitted)
    require(admitted.get("status") in ("admitted", "no-work"), "not-admitted", "admission required")
    root = repository(args.git_repo, admitted["canonical_repo"])
    state = (state_read(args.state, admitted, allow_execution_plan_update=True, repo=args.git_repo)
             if args.state else new_state(admitted))
    if not args.state:
        require(not Path(args.state_out).exists(), "existing-state", "initial state already exists; resume it")
        # Publish the owner-bearing initial state before acquiring the claim: the
        # claim's random owner is only recoverable from durable state, so a claim
        # must never exist at a point where an interruption would lose its owner.
        write_state(args, state)
        state["_loaded_digest"] = hashlib.sha256(_json_bytes(state)).hexdigest()
        args.state = args.state_out
    claim_scope(args.git_repo, admitted, state)
    try:
        fresh = admit(load_json(args.fresh), admitted["max_parallel"], args.git_repo)
        require(fresh.get("recovery") is not None, "incomplete-recovery",
                "schedule requires a complete fresh recovery inventory")
        require(fresh["fingerprint"] == admitted["fingerprint"],
                "snapshot-drift", "scope/native identity/contract changed")
        require(fresh["execution_fingerprint"] == admitted["execution_fingerprint"],
                "execution-plan-drift", "execution layout changed without a newer admitted plan")
        require(fresh["integration"]["branch"] == admitted["integration"]["branch"],
                "parent-tip-drift", "integration branch identity requires readmission")
        if fresh["integration"]["sha"] != admitted["integration"]["sha"]:
            landed = False
            for task in fresh["tasks"]:
                retained = task.get("existing_delivery")
                lifecycle = retained.get("lifecycle") if isinstance(retained, dict) else None
                pr = lifecycle.get("pr", lifecycle) if isinstance(lifecycle, dict) else None
                if not isinstance(pr, dict) or pr.get("state") != "merged":
                    continue
                merge_sha = pr.get("merge_commit_sha") or lifecycle.get("landed_revision")
                target = pr.get("merged_base_branch") or lifecycle.get("landing_target")
                if (target == fresh["integration"]["branch"]
                        and SHA_RE.fullmatch(merge_sha or "")
                        and contains(root, merge_sha, fresh["integration"]["sha"])):
                    landed = True
                    break
            require(landed, "parent-tip-drift",
                    "integration tip changed without a verified delivered merge")
        plan_error = state.pop("_execution_plan_error", None)
        if plan_error is not None:
            raise InputError(plan_error["code"], plan_error["message"])
        plan_update = state.pop("_execution_plan_update", None)
        if plan_update is not None:
            _apply_execution_plan_update(state, fresh, plan_update)
    except InputError as error:
        state.pop("_execution_plan_update", None)
        state.pop("_execution_plan_error", None)
        state["halt_new_dispatch"], state["halt_reason"] = True, error.code
        state.setdefault("recovery", {})["first_uncertain_boundary"] = {
            "reason": error.code, "status": "snapshot-drift",
        }
        write_state(args, state)
        return {"status": "snapshot-drift", "reason": error.code, "dispatch": [],
                "execution_layout": copy.deepcopy(state["execution_layout"]),
                **_state_summary(state)}
    state.setdefault("recovery", {})["last_snapshot"] = {
        "fingerprint": fresh["fingerprint"],
        "scope_identity": copy.deepcopy(fresh["scope_identity"]),
        "scope_evidence": copy.deepcopy(fresh.get("scope_evidence")),
        "execution_layout": copy.deepcopy(fresh["execution_layout"]),
        "execution_fingerprint": fresh["execution_fingerprint"],
        "membership": [
            {"url": task["url"], "id": task["id"], "node_id": task["node_id"],
             **({"actual_parent": task["actual_parent"]} if "actual_parent" in task else {}),
             "item_id": task.get("item_id")}
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
    state["scope_evidence"] = copy.deepcopy(fresh.get("scope_evidence"))
    if state.get("stop_requested"):
        state["halt_new_dispatch"], state["halt_reason"] = True, "user-stop"
        write_state(args, state)
        return {"status": "stopped", "reason": "user-stop", "dispatch": [],
                "execution_layout": copy.deepcopy(state["execution_layout"]),
                **_state_summary(state)}
    if state["halt_new_dispatch"]:
        legacy_drift = _legacy_execution_drift_tasks(state)
        if state.get("halt_reason") in {
                "snapshot-drift", "execution-plan-drift", "parent-tip-drift",
                "incomplete-recovery", "incomplete-selection", "incomplete-task",
                "missing-repository", "missing-integration", "missing-execution-layout",
                "invalid-identity",
        } and not legacy_drift:
            state["halt_new_dispatch"], state["halt_reason"] = False, None
            state.setdefault("recovery", {}).pop("first_uncertain_boundary", None)
        else:
            write_state(args, state)
            return {"status": "halted", "reason": state["halt_reason"], "dispatch": [],
                    "execution_layout": copy.deepcopy(state["execution_layout"]),
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
        if any(state["tasks"][p]["status"] != "delivered" for p in task["effective_prerequisites"]):
            if retained_reservation is not None:
                item["status"] = "repair-ready"
                item["failure_reason"] = "prerequisites-unmet"
            waiting.append({"task_id": tid, "reason": _dependency_wait_reason(task, state)})
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
            repairing = item.get("ci", {}).get("state") == "repair"
            workspace_required = not (repairing and not Path(reservation["workspace"]).exists())
            proof, lifecycle, satisfaction = reconcile_delivery(
                admitted, task, item, retained, args.git_repo,
                repairing=repairing, workspace_required=workspace_required)
            claim_task(args.git_repo, admitted, task, state, item)
            decision = decisions.get(tid) or item.get("parent_decision")
            parent_readiness(fresh, task, state, reservation, decision, args.git_repo, retained=True)
            require(proof["status"] in ("delivered", "note-pending"),
                    "delivery-invalidated", "retained delivery no longer verified")
            require(not any(tid != task["task_id"] and other.get("verified_pr") == proof["delivery"]["pr_url"]
                            for tid, other in state["tasks"].items()),
                    "duplicate-pr", "retained deliveries claim the same PR")
            prior_head = (item.get("delivery") or {}).get("head_sha")
            prior_revision = (item.get("satisfaction") or {}).get("revision")
            _remember_result(item, retained["result"])
            item.update(status=proof["status"], reservation=reservation,
                        delivery=proof["delivery"], verified_pr=proof["delivery"]["pr_url"],
                        lifecycle=copy.deepcopy(lifecycle), satisfaction=copy.deepcopy(satisfaction),
                        lifecycle_error=None, parent_decision=copy.deepcopy(decision))
            if proof["status"] == "delivered" and prior_head != proof["delivery"]["head_sha"]:
                _invalidate_descendants(admitted, state, tid, "parent-revision-changed")
            if proof["status"] == "delivered" and prior_revision and \
                    prior_revision != (satisfaction or {}).get("revision"):
                _invalidate_descendants(admitted, state, tid, "parent-revision-changed")
            if proof["status"] == "delivered" and item.get("ci", {}).get("state") == "unverified":
                _reset_ci_after_delivery(admitted, state, item, proof["delivery"]["head_sha"])
        except (InputError, KeyError, TypeError) as error:
            reason = _safe_reason(error, "invalid-retained-delivery")
            if reason == "ownership-conflict":
                blocked.append({"task_id": tid, "reason": reason,
                                "next_action": "reconcile the other controller's canonical task claim"})
                continue
            if item["status"] == "delivered":
                item["lifecycle_error"] = {"reason": reason,
                                           "next_action": "refresh canonical PR, merge-target, source, and check evidence"}
                blocked.append({"task_id": tid, "reason": reason,
                                "next_action": item["lifecycle_error"]["next_action"]})
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
    for task in sorted(fresh_tasks.values(), key=lambda t: (t["ordinal"], t["task_id"])):
        tid, item = task["task_id"], state["tasks"][task["task_id"]]
        if tid in ownership_unverified:
            continue
        if task["state"] == "closed" and item["status"] == "pending":
            blocked.append({"task_id": tid, "reason": "issue-closed",
                            "next_action": "prove a verified delivery before resuming a closed issue"})
            continue
        if item["status"] == "running":
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
        if item.get("ci", {}).get("state") == "blocked" \
                and item["status"] not in ("running", "unknown"):
            blocked.append({"task_id": tid, "reason": item["ci"].get("reason", "ci-blocked"),
                            "next_action": item["ci"].get("next_action")})
            continue
        if item.get("lifecycle_error"):
            continue
        ci_repair = item.get("ci", {}).get("state") == "repair"
        if item["status"] not in ("pending", "repair-ready") and not ci_repair:
            continue
        if item.get("ci", {}).get("reconcile_required"):
            blocked.append({"task_id": tid, "reason": "parent-revision-changed",
                            "next_action": "reconcile in an exclusive descendant task; do not mutate its checkout"})
            continue
        if task["external_prerequisites"]:
            blocked.append({"task_id": tid, "reason": "external-prerequisite"})
            continue
        lifecycle_failures = []
        for predecessor in task["effective_prerequisites"]:
            if state["tasks"][predecessor]["status"] != "delivered":
                continue
            predecessor_item = state["tasks"][predecessor]
            if predecessor_item.get("lifecycle_error"):
                lifecycle_failures.append((predecessor, predecessor_item["lifecycle_error"]["reason"]))
                continue
            try:
                prerequisite_satisfaction(predecessor_item, task, args.git_repo,
                                         lifecycle=predecessor_item.get("lifecycle"),
                                         canonical=admitted["canonical_repo"])
            except InputError as error:
                lifecycle_failures.append((predecessor, getattr(error, "code", "pr-lifecycle-invalid")))
        if lifecycle_failures:
            waiting.append({"task_id": tid, "reason": "prerequisite-lifecycle-unresolved",
                            "prerequisites": [{"task_id": p, "reason": r} for p, r in lifecycle_failures]})
            continue
        predecessor_states = [state["tasks"][p]["status"] for p in task["effective_prerequisites"]]
        if any(status != "delivered" for status in predecessor_states):
            waiting.append({"task_id": tid, "reason": _dependency_wait_reason(task, state)})
            continue
        if any(_ci_dependency_blocked(state["tasks"][p]) for p in task["effective_prerequisites"]):
            waiting.append({"task_id": tid, "reason": "prerequisite-ci-unverified"})
            continue
        repair = item["status"] == "repair-ready" or ci_repair
        reservation = copy.deepcopy(item.get("reservation"))
        if repair:
            try:
                require(isinstance(reservation, dict), "workspace-conflict", "repair has no retained reservation")
                identity = _reopen_repair_workspace(args.git_repo, admitted, state, item)
                require(contains(args.git_repo, reservation["parent_sha"], identity["head_sha"]),
                        "wrong-ancestry", "repair workspace no longer contains admitted start")
            except InputError as error:
                blocked.append({"task_id": tid, "reason": getattr(error, "code", "workspace-conflict")})
                continue
        else:
            try:
                parent = choose_parent(fresh, task, state, decisions, args.git_repo)
            except InputError as error:
                blocked.append({"task_id": tid, "reason": error.code,
                                "next_action": "refresh canonical PR and Git evidence before retrying"})
                continue
            if parent is None:
                if task["execution_fallback"] is None:
                    blocked.append({
                        "task_id": tid,
                        "reason": "parent-unavailable",
                        "next_action": "select a verified containing parent or record an approved merge-checkpoint fallback",
                    })
                    continue
                merge_prerequisites = []
                for predecessor in task["effective_prerequisites"]:
                    predecessor_item = state["tasks"][predecessor]
                    lifecycle = predecessor_item.get("lifecycle")
                    require(isinstance(lifecycle, dict) and lifecycle,
                            "pr-lifecycle-missing", "current PR lifecycle evidence is missing")
                    current_pr = lifecycle.get("pr", lifecycle)
                    merge_prerequisites.append({
                        "task_id": predecessor,
                        "pr_url": predecessor_item["verified_pr"],
                        "state": current_pr.get("state"),
                        "branch": current_pr.get("branch"),
                        "head_sha": current_pr.get("head_sha"),
                    })
                waiting.append({
                    "task_id": tid,
                    "reason": "waiting-for-merge",
                    "prerequisites": merge_prerequisites,
                    "merge_prerequisites": copy.deepcopy(merge_prerequisites),
                    "execution_parent": task["execution_parent"],
                    "execution_fallback": copy.deepcopy(task["execution_fallback"]),
                    "integration_branch": fresh["integration"]["branch"],
                    "release_condition": task["execution_fallback"]["release_condition"],
                })
                continue
            try:
                allocation = runtime_allocation(fresh, tid, root)
            except InputError as error:
                blocked.append({"task_id": tid, "reason": getattr(error, "code", "workspace-unassigned")})
                continue
            reservation = {"branch": allocation["branch"], "workspace": allocation["workspace"],
                           "parent_branch": parent["branch"], "parent_sha": parent["sha"],
                           "task_url": task["url"], "scope": copy.deepcopy(admitted["scope_identity"]),
                           "contract_hash": task["contract_hash"]}
        if any(other != tid and other_item.get("reservation")
               and overlaps(reservation["workspace"], other_item["reservation"]["workspace"])
               for other, other_item in state["tasks"].items()):
            blocked.append({"task_id": tid, "reason": "workspace-alias-collision"})
            continue
        try:
            collision = allocation_collision(args.git_repo, admitted["canonical_repo"], reservation,
                                             inventory, state, tid) if not repair else None
        except InputError as error:
            blocked.append({"task_id": tid, "reason": getattr(error, "code", "workspace-conflict")})
            continue
        if collision:
            blocked.append({"task_id": tid, "reason": collision})
            continue
        existing_checkout = (Path(reservation["workspace"]).exists()
                             and git(reservation["workspace"], "rev-parse", "--show-toplevel",
                                     allow_missing=True) is not None)
        if not repair and existing_checkout:
            try:
                current = workspace_identity(args.git_repo, admitted["canonical_repo"],
                                             reservation["workspace"], reservation["branch"])
                require(contains(reservation["workspace"], reservation["parent_sha"], current["head_sha"]),
                        "wrong-ancestry", "existing task workspace does not contain selected parent")
                fresh_workspace_state(reservation["workspace"], reservation["parent_sha"], current["head_sha"])
            except InputError as error:
                blocked.append({"task_id": tid, "reason": getattr(error, "code", "workspace-conflict")})
                continue
        if slots == 0:
            continue
        try:
            claim_task(args.git_repo, admitted, task, state, item)
        except InputError as error:
            blocked.append({"task_id": tid, "reason": error.code,
                            "next_action": "reconcile the other controller's canonical task claim"})
            continue
        retained_pr = item.get("verified_pr")
        decision = decisions.get(tid) or item.get("parent_decision")
        try:
            readiness = parent_readiness(fresh, task, state, reservation, decision, args.git_repo, retained=repair)
        except InputError as error:
            blocked.append({"task_id": tid, "reason": error.code,
                            "next_action": "refresh canonical parent, PR, and Git evidence before retrying"})
            continue
        if item.get("ci", {}).get("state") == "repair":
            _repair_attempt(item)
        repair_evidence = copy.deepcopy(item.get("ci", {}).get("repair_context")) if repair else None
        if repair and isinstance(repair_evidence, dict) and item.get("ci", {}).get("workspace_reopen"):
            repair_evidence["workspace_reopen"] = copy.deepcopy(item["ci"]["workspace_reopen"])
        item.update(status="running", reservation=reservation, parent_decision=copy.deepcopy(decision),
                    execution_parent=task["execution_parent"],
                    execution_plan_revision=admitted["execution_layout"]["revision"],
                    dependency_snapshot=copy.deepcopy(task["dependency_snapshot"]),
                    host_worker=None,
                    first_uncertain_boundary=None,
                    last_evidence={"parent_readiness": copy.deepcopy(readiness)})
        dispatch.append({"task_id": tid, "ordinal": task["ordinal"], "child_url": task["url"],
                         "repair": repair, "retained_pr": retained_pr, **reservation,
                         "workspace_reopen": copy.deepcopy(item.get("ci", {}).get("workspace_reopen")) if repair else None,
                         "packet": packet(admitted, task, reservation, repair, retained_pr,
                                          readiness, fresh.get("scope_evidence"), repair_evidence)})
        occupied.append(tid)
        slots -= 1
    write_state(args, state)
    return {"status": "no-work" if not admitted["tasks"] else "ok", "effective_cap": cap,
            "execution_layout": copy.deepcopy(state["execution_layout"]),
            "notice": fresh["notice"], "dispatch": dispatch, **_state_summary(
                state, blocked=blocked, waiting=waiting, paused=paused,
                unknown_details=unknown)}


def cmd_record_worker(args):
    admitted = load_json(args.admitted)
    repository(args.git_repo, admitted["canonical_repo"])
    state = state_read(args.state, admitted, repo=args.git_repo, active_task_id=args.task)
    require(args.task in state["tasks"], "unknown-task", "task outside admitted scope")
    item = state["tasks"][args.task]
    require(item["status"] in ("running", "unknown"), "not-running", "worker needs an active reservation")
    receipt = load_json(args.evidence)
    worker = receipt.get("worker")
    require(isinstance(worker, dict)
            and set(worker) == {"host_id", "session_id", "worker_id"}
            and all(text(value) for value in worker.values()),
            "worker-liveness", "native host/session/worker identity required")
    require(receipt.get("reservation") == item["reservation"],
            "evidence-mismatch", "host launch readback must match the reservation")
    require(item.get("host_worker") in (None, worker),
            "worker-liveness", "recorded writer cannot be replaced")
    require(receipt.get("state_digest") == state["_loaded_digest"],
            "worker-liveness", "host launch readback must bind the current checkpoint")
    task = next(t for t in admitted["tasks"] if t["task_id"] == args.task)
    claim_scope(args.git_repo, admitted, state)
    claim_task(args.git_repo, admitted, task, state, item)
    item["host_worker"] = copy.deepcopy(worker)
    write_state(args, state)
    return {"status": "worker-recorded", "task_id": args.task}


def cmd_apply_result(args):
    admitted = load_json(args.admitted)
    repository(args.git_repo, admitted["canonical_repo"])
    state = state_read(args.state, admitted, repo=args.git_repo, active_task_id=args.task)
    require(args.task in state["tasks"], "unknown-task", "task outside admitted scope")
    item = state["tasks"][args.task]
    require(item["status"] in ("running", "note-pending", "evidence-pending"),
            "not-running", "task has no active reservation or receipt retry")
    legacy_drift = _legacy_execution_drift_tasks(state)
    require(item["execution_plan_revision"] == admitted["execution_layout"]["revision"],
            "execution-plan-drift", "worker result must use its dispatched execution plan")
    require(args.task not in legacy_drift, "execution-plan-drift",
            "task requires legacy execution-plan reconciliation")

    try:
        result = load_json(args.result)
    except InputError as error:
        raise InputError("worker-identity", "parseable completion envelope with native worker identity required") from error
    worker = result.get("worker")
    host_worker = item.get("host_worker")
    identity_fields = ("host_id", "session_id", "worker_id")
    require(isinstance(host_worker, dict) and isinstance(worker, dict)
            and all(text(host_worker.get(key)) for key in identity_fields)
            and host_worker == {key: worker.get(key) for key in identity_fields},
            "worker-identity", "completion must match the recorded native host/session/worker identity")
    task = next(t for t in admitted["tasks"] if t["task_id"] == args.task)
    claim_scope(args.git_repo, admitted, state)
    claim_task(args.git_repo, admitted, task, state, item)
    try:
        retained_pr = item.get("verified_pr")
        prior_evidence = item.get("last_evidence")
        verified_update = bool(retained_pr) and (
            isinstance(item.get("delivery"), dict)
            or isinstance(prior_evidence, dict) and isinstance(prior_evidence.get("readback"), dict))
        proof = validate_delivery(admitted, task, item["reservation"], result, args.git_repo,
                                  existing_pr=verified_update)
        pr_url = result["worker"]["pr_url"]
        require(not any(tid != args.task and other.get("verified_pr") == pr_url
                        for tid, other in state["tasks"].items()),
                "duplicate-pr", "another task already owns this PR")
        if retained_pr:
            require(retained_pr == pr_url, "pr-replaced", "repair must preserve existing PR")
        prior_head = (item.get("delivery") or {}).get("head_sha")
        _remember_result(item, result)
        item["lifecycle"] = initial_lifecycle(result)
        item["verified_pr"] = pr_url
        item["status"] = proof["status"]
        item["failure_reason"] = proof.get("reason") if proof["status"] == "note-pending" else None
        if proof["status"] in ("delivered", "note-pending"):
            item["delivery"] = proof["delivery"]
        if proof["status"] == "delivered":
            item["satisfaction"] = {
                "kind": "open", "revision": proof["delivery"]["head_sha"],
                "branch": proof["delivery"]["branch"], "pr_url": proof["delivery"]["pr_url"],
                "checkpoint": copy.deepcopy(proof["delivery"]["checkpoint"]),
                "lifecycle": copy.deepcopy(item["lifecycle"]),
            }
            item["first_uncertain_boundary"] = None
            _reset_ci_after_delivery(admitted, state, item, proof["delivery"]["head_sha"])
            if prior_head and prior_head != proof["delivery"]["head_sha"]:
                _invalidate_descendants(admitted, state, args.task, "parent-revision-changed")
        outcome = {"task_id": args.task, **proof}
    except (InputError, KeyError, TypeError, ValueError) as error:
        outcome = halt(state, item, getattr(error, "code", "unknown-response"),
                       result.get("worker") if isinstance(result, dict) else None)
        write_state(args, state)
        return outcome

    write_state(args, state)
    return outcome
def cmd_reconcile(args):
    admitted = load_json(args.admitted)
    repository(args.git_repo, admitted["canonical_repo"])
    state = state_read(args.state, admitted, repo=args.git_repo, active_task_id=args.task)
    require(args.task in state["tasks"], "unknown-task", "task outside admitted scope")
    item = state["tasks"][args.task]
    descendant_reconcile = isinstance(item.get("ci"), dict) \
        and isinstance(item["ci"].get("reconcile_required"), dict)
    require(item["status"] == "unknown"
            or (descendant_reconcile and item["status"] in
                ("running", "delivered", "evidence-pending", "repair-ready")),
            "not-unknown", "task has no uncertain outcome or active descendant reconciliation")
    task = next(t for t in admitted["tasks"] if t["task_id"] == args.task)
    claim_scope(args.git_repo, admitted, state)
    claim_task(args.git_repo, admitted, task, state, item)
    evidence = load_json(args.evidence)
    reservation = item["reservation"]
    stopped = evidence.get("worker_stop")
    worker = item.get("host_worker")
    require(isinstance(worker, dict) and isinstance(stopped, dict),
            "worker-liveness", "recorded host writer and bound stop readback required")
    inventory = recovery_inventory(load_json(args.inventory))
    require(stopped.get("worker") == worker
            and stopped.get("state_digest") == state["_loaded_digest"]
            and stopped.get("inventory_digest") == digest(inventory),
            "worker-liveness", "stop readback must bind the current writer, checkpoint and inventory")
    sessions = inventory["sessions"]
    require(isinstance(sessions, list) and all(isinstance(row, dict) for row in sessions),
            "worker-liveness", "host session inventory must be an explicit list")
    matching = [row for row in sessions if row.get("worker") == worker
                or row.get("task_id") == args.task
                or row.get("reservation") == reservation]
    require(len(matching) == 1 and matching[0] == {
        "worker": worker, "task_id": args.task, "reservation": reservation, "status": "stopped",
    }, "worker-liveness", "current host readback must prove the reserved writer stopped")
    processes = inventory["processes"]
    require(isinstance(processes, list) and all(isinstance(row, dict) for row in processes)
            and all(row.get("status") == "stopped" for row in processes
                    if row.get("worker") == worker or row.get("task_id") == args.task
                    or row.get("reservation") == reservation),
            "worker-liveness", "reserved writer processes must also be stopped")
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
    state.setdefault("recovery", {})["last_inventory"] = inventory
    if state.get("halt_reason") in (None, "unknown-response"):
        state["halt_new_dispatch"], state["halt_reason"] = False, None
    write_state(args, state)
    return {"status": "reconciled", "task_id": args.task,
            "detail": "Same task retained; full apply-result gates still required.",
            **_state_summary(state)}
def cmd_stop(args):
    admitted = load_json(args.admitted)
    repository(args.git_repo, admitted["canonical_repo"])
    state = state_read(args.state, admitted, repo=args.git_repo)
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
    return admit(load_json(args.snapshot), positive(args.max_parallel), args.git_repo)


def parser():
    root = argparse.ArgumentParser(description=__doc__)
    commands = root.add_subparsers(dest="command", required=True)
    admission = commands.add_parser("admit")
    admission.add_argument("--snapshot", required=True)
    admission.add_argument("--max-parallel", default=str(DEFAULT_MAX_PARALLEL))
    admission.add_argument("--git-repo")
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
    record_worker = commands.add_parser("record-worker")
    record_worker.add_argument("--admitted", required=True)
    record_worker.add_argument("--state", required=True)
    record_worker.add_argument("--state-out", required=True)
    record_worker.add_argument("--git-repo", required=True)
    record_worker.add_argument("--task", required=True)
    record_worker.add_argument("--evidence", required=True)
    record_worker.set_defaults(run=cmd_record_worker)
    reconcile = commands.add_parser("reconcile")
    reconcile.add_argument("--admitted", required=True)
    reconcile.add_argument("--state", required=True)
    reconcile.add_argument("--state-out", required=True)
    reconcile.add_argument("--git-repo", required=True)
    reconcile.add_argument("--task", required=True)
    reconcile.add_argument("--evidence", required=True)
    reconcile.add_argument("--inventory", required=True)
    reconcile.set_defaults(run=cmd_reconcile)
    observe = commands.add_parser("observe-checks")
    observe.add_argument("--admitted", required=True)
    observe.add_argument("--state", required=True)
    observe.add_argument("--state-out", required=True)
    observe.add_argument("--git-repo", required=True)
    observe.add_argument("--task", required=True)
    observe.add_argument("--observation", required=True)
    observe.set_defaults(run=cmd_observe_checks)
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
