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
SHA_RE = re.compile(r"(?:[0-9a-f]{40}|[0-9a-f]{64})\Z")
EDGE_KINDS = ("native", "declared", "inferred")
DEFAULT_CI_REPAIR_LIMIT = 2
CI_STATES = ("unverified", "checking", "verified", "not-applicable", "blocked", "repair")
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


def landed_diff_identity(repo, revision, verification, parent=None):
    if parent is None:
        parent = verification.get("landed_parent")
        if parent is None:
            parent = git(repo, "rev-parse", revision + "^").decode().strip()
    require(SHA_RE.fullmatch(parent or "") and parent != revision
            and contains(repo, parent, revision),
            "landed-evidence-missing", "landed range must identify an ancestor of the merge")
    return "sha256:" + hashlib.sha256(git(
        repo, "diff", "--no-ext-diff", "--no-textconv", "--no-color", "--binary",
        parent, revision)).hexdigest()


def _verified_landed_prerequisite(issue_url, pr, verification, integration,
                                  repo, canonical):
    """One landed-availability rule for selected work and outside-scope prerequisites."""
    require(isinstance(pr, dict), "pr-lifecycle-missing", "current PR lifecycle evidence is missing")
    url = pr.get("pr_url", pr.get("url"))
    match = PR_RE.fullmatch(url or "")
    require(match is not None
            and "https://github.com/" + "/".join(match.groups()[:2]) == canonical
            and pr.get("repo") == pr.get("head_repo") == canonical
            and pr.get("association") == issue_url,
            "prerequisite-identity",
            "prerequisite evidence identifies another issue, repository, or invalid lifecycle")
    require(SHA_RE.fullmatch(pr.get("head_sha") or "") and text(pr.get("branch")),
            "pr-lifecycle-identity", "prerequisite head identity is incomplete")
    require(pr.get("state") == "merged"
            and pr.get("base_branch") == integration["branch"]
            and pr.get("merged_base_branch") == integration["branch"]
            and SHA_RE.fullmatch(pr.get("merge_commit_sha") or ""),
            "pr-merge-target-mismatch", "merged prerequisite is not landed in the candidate base")
    require(isinstance(verification, dict) and verification.get("complete") is True
            and verification.get("source_verified") is True
            and verification.get("checks_verified") is True
            and verification.get("reverted") is False
            and re.fullmatch(r"sha256:[0-9a-f]{64}", verification.get("diff_identity") or ""),
            "landed-evidence-missing",
            "landed prerequisite needs task-relevant source and check evidence")
    revision = pr["merge_commit_sha"]
    parent = verification.get("landed_parent")
    if parent is None:
        parent = git(repo, "rev-parse", revision + "^").decode().strip()
    landed_diff = landed_diff_identity(repo, revision, verification, parent)
    require(verification["diff_identity"] == landed_diff,
            "landed-diff-mismatch", "landed evidence does not match the current landed revision")
    require(contains(repo, revision, integration["sha"]),
            "base-satisfaction-unverified", "prerequisite is not contained in the candidate base")
    paths = changed_paths(repo, parent, revision)
    require(paths, "landed-evidence-missing", "landed prerequisite contains no change")
    require(not git(repo, "diff", "--no-ext-diff", "--name-only",
                    revision, integration["sha"], "--", *paths),
            "base-satisfaction-unverified",
            "the candidate base changes required landed content without fresh validation")
    return {"kind": "merged", "revision": revision, "branch": integration["branch"],
            "pr_url": url, "landed_diff_identity": landed_diff}


def _selected_prerequisite_facts(tasks_by_id, integration, repo, canonical):
    """Verify current selected-task availability once; uncertainty stays task-local."""
    available, errors = {}, {}
    for task_id, task in sorted(tasks_by_id.items()):
        delivery = task.get("existing_delivery")
        if delivery is None:
            continue
        try:
            require(isinstance(delivery, dict) and isinstance(delivery.get("lifecycle"), dict),
                    "pr-lifecycle-missing", "current PR lifecycle evidence is missing")
            lifecycle = delivery["lifecycle"]
            pr = copy.deepcopy(lifecycle.get("pr", lifecycle))
            require(isinstance(pr, dict), "pr-lifecycle-missing",
                    "current PR identity is missing")
            result = delivery.get("result")
            readback = result.get("readback") if isinstance(result, dict) else None
            require(isinstance(readback, dict)
                    and readback.get("association") == task["url"]
                    and readback.get("pr_url") == pr.get("pr_url", pr.get("url"))
                    and readback.get("branch") == pr.get("branch")
                    and readback.get("head_sha") == pr.get("head_sha"),
                    "wrong-association", "retained delivery does not match the selected issue and PR")
            checks = normalize_retained_result(result).get("checks") if isinstance(result, dict) else None
            review = result.get("validation")
            worker = result.get("worker")
            original_diff = readback.get("diff_identity")
            commands = checks.get("commands") if isinstance(checks, dict) else None
            smoke = checks.get("smoke") if isinstance(checks, dict) else None
            observed = {
                command["command"] for command in commands
                if isinstance(command, dict) and text(command.get("command"))
                and command.get("executed") is True and command.get("passed") is True
            } if isinstance(commands, list) else set()
            require(re.fullmatch(r"sha256:[0-9a-f]{64}", original_diff or "")
                    and isinstance(checks, dict) and checks.get("passed") is True
                    and checks.get("head_sha") == readback["head_sha"]
                    and checks.get("diff_identity") == original_diff
                    and isinstance(commands, list) and len(commands) > 0
                    and all(isinstance(command, dict) and command.get("command") in observed
                            and command.get("executed") is True and command.get("passed") is True
                            for command in commands)
                    and all(command in observed for command in task["contract"]["checks"])
                    and isinstance(smoke, dict) and text(smoke.get("description"))
                    and smoke.get("executed") is True and smoke.get("passed") is True
                    and isinstance(review, dict) and review.get("verdict") == "pass"
                    and review.get("checked_head") == readback["head_sha"]
                    and review.get("diff_identity") == original_diff
                    and review.get("contract_hash") == task["contract_hash"]
                    and isinstance(worker, dict) and text(worker.get("worker_id"))
                    and text(review.get("reviewer_id"))
                    and review["reviewer_id"] != worker["worker_id"],
                    "stale-validation", "original delivery verification is incomplete or stale")
            verification = (lifecycle.get("landed_verification")
                            or lifecycle.get("verification") or lifecycle.get("checks"))
            fact = _verified_landed_prerequisite(
                task["url"], pr, verification, integration, repo, canonical)
            fact["original"] = {
                "revision": readback.get("head_sha"), "diff_identity": readback.get("diff_identity"),
            }
            available[task_id] = fact
        except (InputError, KeyError, TypeError) as error:
            errors[task_id] = getattr(error, "code", "prerequisite-evidence-invalid")
    return available, errors


def _base_satisfied_prerequisites(task, technical, planned_parent, available):
    """Prerequisites already available in the candidate base need no worker delivery."""
    landed = set(technical[task["task_id"]])
    if planned_parent is not None:
        landed.add(planned_parent)
    return [{"task_id": task_id, "revision": available[task_id]["revision"],
             "evidence": copy.deepcopy(available[task_id])}
            for task_id in sorted(landed) if task_id in available]


def _verified_external_prerequisite(value, task, integration, repo, canonical):
    require(isinstance(value, dict) and text(value.get("provenance")),
            "landed-evidence-missing",
            "satisfied external prerequisite needs identity, revision, and provenance")
    issue_url = canonical_issue_url(value.get("issue_url"), canonical)
    revision = value.get("revision")
    require(issue_url in task["external_prerequisites"]
            and isinstance(revision, str) and SHA_RE.fullmatch(revision),
            "external-prerequisite-identity",
            "satisfied external prerequisite must match a declared external edge")
    source, evidence = value.get("source"), value.get("evidence")
    require(isinstance(source, dict) and isinstance(evidence, dict),
            "base-satisfaction-unverified",
            "satisfied external prerequisite needs source and lifecycle evidence")
    issue, pr = evidence.get("issue"), evidence.get("pr")
    require(source.get("issue_url") == issue_url and text(source.get("pr_url"))
            and isinstance(pr, dict),
            "base-satisfaction-unverified",
            "satisfied external prerequisite needs canonical issue and merge evidence")
    require(isinstance(issue, dict) and text(issue.get("url")),
            "external-prerequisite-identity", "external issue identity is missing")
    issue_identity(issue, canonical)
    require(issue.get("url") == issue_url and pr.get("url") == source.get("pr_url"),
            "external-prerequisite-identity",
            "external prerequisite evidence identifies another issue or repository")
    try:
        fact = _verified_landed_prerequisite(
            issue_url, pr, evidence.get("landed_verification"), integration, repo, canonical)
    except InputError as error:
        raise InputError({
            "prerequisite-identity": "external-prerequisite-identity",
            "pr-merge-target-mismatch": "external-prerequisite-unmerged",
            "pr-branch-missing": "external-prerequisite-unmerged",
        }.get(error.code, error.code), str(error)) from error
    require(fact["kind"] == "merged" and fact["revision"] == revision,
            "external-prerequisite-unmerged",
            "external prerequisite has no verified merge into the candidate base")
    return copy.deepcopy(value)


def _satisfied_external_prerequisites(raw, task, integration, repo, canonical):
    values = raw.get("satisfied_external_prerequisites", [])
    if not isinstance(values, list):
        return [], {issue: "landed-evidence-missing" for issue in task["external_prerequisites"]}
    require(not values or repo is not None, "git-unavailable",
            "--git-repo is required to verify external prerequisites")
    verified, errors, seen = {}, {}, set()
    for value in values:
        issue_url = value.get("issue_url") if isinstance(value, dict) else None
        if issue_url not in task["external_prerequisites"]:
            # An unassignable claim makes the dependent unsafe, not the entire scope.
            errors.update({issue: "external-prerequisite-identity"
                           for issue in task["external_prerequisites"]})
            continue
        if issue_url in seen:
            errors[issue_url] = "duplicate-external-evidence"
            verified.pop(issue_url, None)
            continue
        seen.add(issue_url)
        try:
            verified[issue_url] = _verified_external_prerequisite(
                value, task, integration, repo, canonical)
        except InputError as error:
            if error.code == "git-unavailable":
                raise
            errors[issue_url] = error.code
    return ([verified[issue] for issue in sorted(verified) if issue not in errors],
            errors)


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
    available, evidence_errors = ({}, {}) if repo is None else _selected_prerequisite_facts(
        tasks_by_id, snapshot["integration"], repo, snapshot["canonical_repo"])
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
        require(isinstance(constraints, list) and all(text(value) for value in constraints),
                "invalid-execution-layout", "execution compatibility evidence must be text")
        fallback = entry.get("fallback")
        if fallback is not None:
            require(parent is None and isinstance(fallback, dict)
                    and fallback.get("reason") == "merge-checkpoint"
                    and text(fallback.get("release_condition")),
                    "invalid-execution-fallback", "merge fallback needs one release condition")
        entry = copy.deepcopy(entry)
        entry["base_satisfied_prerequisites"] = _base_satisfied_prerequisites(
            tasks_by_id[task_id], technical, entry["execution_parent"], available)
        (entry["satisfied_external_prerequisites"],
         entry["external_evidence_errors"]) = _satisfied_external_prerequisites(
            entry, tasks_by_id[task_id], snapshot["integration"], repo, snapshot["canonical_repo"])
        tasks_by_id[task_id]["available_prerequisites"] = {
            predecessor: available[predecessor]
            for predecessor in sorted(technical[task_id]) if predecessor in available}
        tasks_by_id[task_id]["prerequisite_evidence_errors"] = {
            predecessor: evidence_errors[predecessor]
            for predecessor in sorted(technical[task_id]) if predecessor in evidence_errors}
        tasks_by_id[task_id]["own_availability"] = copy.deepcopy(available.get(task_id))
        tasks_by_id[task_id]["own_availability_error"] = copy.deepcopy(evidence_errors.get(task_id))
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
        joins = technical[task_id] - set(lineage)
        if fallback is None:
            missing = joins - base_satisfied
            require(not missing or all(predecessor in evidence_errors for predecessor in missing),
                    "missing-execution-ancestor",
                    "execution path for " + task_id + " omits " + ", ".join(sorted(missing)))
        else:
            require(joins, "invalid-execution-fallback",
                    "merge fallback requires an unsatisfied technical join")
            if not joins - base_satisfied:
                # Every technical join already landed, so the declared merge gate is released.
                entry["fallback"] = None
        task = tasks_by_id[task_id]
        task["execution_parent"] = entry["execution_parent"]
        task["execution_rationale"] = entry["rationale"]
        task["execution_constraints"] = list(entry["constraints"])
        task["execution_fallback"] = copy.deepcopy(entry.get("fallback"))
        task["execution_ancestry"] = lineage
        task["base_satisfied_prerequisites"] = [
            value["task_id"] for value in entry["base_satisfied_prerequisites"]]
        task["satisfied_external_prerequisites"] = [
            value["issue_url"] for value in entry["satisfied_external_prerequisites"]]
        task["external_evidence_errors"] = entry.pop("external_evidence_errors")
        task["effective_prerequisites"] = sorted(
            (technical[task_id] | ({entry["execution_parent"]}
                                  if entry["execution_parent"] is not None else set())) - base_satisfied)
        task["dependency_snapshot"] = {
            "prerequisites": sorted(technical[task_id]),
            "execution_parent": entry["execution_parent"],
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
        effective_edges.append({"predecessor": predecessor, "dependent": dependent,
                                "relationship": "+".join(sorted(kinds))})
    return {"revision": revision, "rationale": raw["rationale"],
            "entries": normalized_entries, "effective_edges": effective_edges,
            "execution_order": execution_order}


def execution_layout_fingerprint(layout):
    return digest(plan_identity(layout))


def plan_identity(layout):
    """Plan identity; landed, external, and merge-gate satisfaction are mutable evidence."""
    identity = copy.deepcopy(layout)
    for entry in identity["entries"]:
        # A merge fallback only holds a join that has not landed, so its necessity moves with
        # mutable satisfaction evidence instead of the declared plan.
        entry.pop("fallback", None)
        entry.pop("base_satisfied_prerequisites", None)
        entry.pop("satisfied_external_prerequisites", None)
    return identity

def _retired_execution_fingerprint(layout):
    identity = copy.deepcopy(layout)
    for entry in identity["entries"]:
        entry.pop("satisfied_external_prerequisites", None)
    return digest(identity)


def continuation_admission(admitted):
    """Accept a retained pre-cutover admission without changing its scope or receipts."""
    layout = admitted["execution_layout"]
    if admitted["execution_fingerprint"] == execution_layout_fingerprint(layout):
        return admitted
    require(admitted["execution_fingerprint"] == _retired_execution_fingerprint(layout),
            "execution-plan-drift", "retained execution identity is not verified")
    normalized = copy.deepcopy(admitted)
    relations = {}
    for task in normalized["tasks"]:
        for predecessor in task["prerequisites"]:
            relations.setdefault((predecessor, task["task_id"]), set()).add("technical")
        parent = task["execution_parent"]
        if parent is not None:
            relations.setdefault((parent, task["task_id"]), set()).add("stack")
    normalized["execution_layout"]["effective_edges"] = [
        {"predecessor": predecessor, "dependent": dependent,
         "relationship": "+".join(sorted(kinds))}
        for (predecessor, dependent), kinds in sorted(relations.items())]
    normalized["execution_fingerprint"] = execution_layout_fingerprint(normalized["execution_layout"])
    for task in normalized["tasks"]:
        task["dependency_snapshot"] = {
            key: copy.deepcopy(task["dependency_snapshot"][key])
            for key in ("prerequisites", "execution_parent", "external_prerequisites")}
    normalized["_legacy_layout"] = layout
    return normalized


def plan_entries(layout):
    return {entry["task_id"]: entry for entry in plan_identity(layout)["entries"]}


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
        require(isinstance(task_id, str) and text(task_id)
                and "\x00" not in task_id and not task_id.startswith("-"),
                "invalid-identity", "CLI-addressable stable task ID required")
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
    execution_fingerprint = execution_layout_fingerprint(execution_layout)
    host = snapshot.get("host", {})
    require(isinstance(host, dict), "no-subagent-capability", "host capability evidence missing")
    host_cap = positive(host.get("max_parallel", 1))
    if tasks:
        required_capabilities = (
            "delivery_capable", "workspace_isolation_capable",
            "result_correlation_capable", "recovery_capable",
        )
        require(all(host.get(capability) is True for capability in required_capabilities),
                "no-subagent-capability",
                "delivery, workspace isolation, result correlation, and recovery capabilities required")
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


def changed_paths(repo, ancestor, head):
    """Return complete changed paths, including both sides of renames."""
    raw = git(repo, "diff", "--name-status", "-z", "--find-renames", ancestor, head)
    fields = [item for item in raw.split(b"\0") if item]
    paths, index = [], 0
    while index < len(fields):
        status = fields[index].decode("ascii", errors="replace")
        index += 1
        if index >= len(fields):
            break
        first = os.fsdecode(fields[index])
        index += 1
        paths.append(first)
        if status[0] in "RC":
            require(index < len(fields), "git-evidence", "rename evidence is incomplete")
            paths.append(os.fsdecode(fields[index]))
            index += 1
    return sorted(set(paths))


def path_in_scope(path, scope):
    candidate = Path(path)
    allowed = Path(scope)
    return candidate == allowed or allowed in candidate.parents


def integration_advance_evidence(repo, admitted, fresh):
    """Verify that a changed integration tip is a compatible forward advance."""
    branch = admitted["integration"]["branch"]
    previous = admitted["integration"]["sha"]
    proposed = fresh["integration"]["sha"]
    require(fresh["integration"]["branch"] == branch,
            "parent-tip-drift", "integration branch identity requires reconciliation")
    current = branch_tip(repo, branch)
    require(current == proposed, "parent-tip-drift",
            "fresh integration evidence does not identify the canonical branch tip")
    if previous == proposed:
        return {"previous_sha": previous, "proposed_sha": proposed,
                "changed_paths": [], "impacted_tasks": [], "compatible": True}
    require(contains(repo, previous, proposed), "parent-tip-drift",
            "integration tip is not a fast-forward from the admitted revision")
    paths = changed_paths(repo, previous, proposed)
    impacted, uncovered = [], []
    for task in fresh["tasks"]:
        scope = task.get("contract", {}).get("scope", [])
        changed = [path for path in paths if any(path_in_scope(path, item) for item in scope)]
        if not changed:
            continue
        impacted.append(task["task_id"])
        retained = task.get("existing_delivery")
        lifecycle = retained.get("lifecycle") if isinstance(retained, dict) else None
        if lifecycle_state(lifecycle) != "merged":
            uncovered.extend(changed)
        # Merged work is checked against this exact candidate base by the task-local
        # prerequisite validator; stale or reverted evidence blocks dependents only.
    require(not uncovered, "parent-tip-drift",
            "integration advance materially changes selected task scope: "
            + ", ".join(sorted(set(uncovered))))
    return {"previous_sha": previous, "proposed_sha": proposed,
            "changed_paths": paths, "impacted_tasks": sorted(impacted),
            "compatible": True}


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
        "admission_identity": _admission_identity(admitted),
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
                "attempt_binding": None,
                "attempt_history": [],
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
def _entry_identity(entry):
    return {key: entry.get(key) for key in ("task_id", "execution_parent", "constraints")}


def _execution_identity(layout):
    return {"entries": [_entry_identity(entry) for entry in layout.get("entries", [])],
            "effective_edges": layout.get("effective_edges", []),
            "execution_order": layout.get("execution_order", [])}


def issued_attempt_binding(task, reservation, repair, retained_pr, readiness):
    return "attempt-" + hashlib.sha256(json.dumps({
        "task_id": task["task_id"], "contract_hash": task["contract_hash"],
        "reservation": reservation, "repair": bool(repair), "retained_pr": retained_pr,
        "readiness": readiness}, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def _admission_identity(admitted):
    return {
        "repository_rules": admitted["repository_rules"],
        "integration_branch": admitted["integration"]["branch"],
        "scope_identity": admitted["scope_identity"],
        "project": admitted.get("project"),
        "lifecycle": admitted.get("lifecycle"),
        "project_items": admitted.get("project_items"),
        "tasks": [{
            "task_id": task["task_id"], "url": task["url"], "id": task["id"],
            "node_id": task["node_id"], "resource": task["resource"],
            "contract_hash": task["contract_hash"], "actual_parent": task.get("actual_parent"),
            "dependency_snapshot": task["dependency_snapshot"],
        } for task in admitted["tasks"]],
    }


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
            and state.get("execution_fingerprint") == execution_layout_fingerprint(current),
            "invalid-state", "retained execution plan identity is invalid")
    if _execution_identity(current) == _execution_identity(admitted["execution_layout"]):
        if current["revision"] == admitted["execution_layout"]["revision"]:
            return None
        return {
            "from_revision": current["revision"], "from_fingerprint": state["execution_fingerprint"],
            "to_revision": admitted["execution_layout"]["revision"],
            "to_fingerprint": admitted["execution_fingerprint"], "changed_tasks": [],
        }
    require(admitted["execution_layout"]["revision"] > current["revision"],
            "execution-plan-drift", "changed execution layout requires a newer plan revision")
    current_entries = plan_entries(current)
    revised_entries = plan_entries(admitted["execution_layout"])
    changed = set()
    for task in admitted["tasks"]:
        task_id = task["task_id"]
        item = state["tasks"].get(task_id)
        require(isinstance(item, dict), "invalid-state", "retained task is missing")
        retained_parent = current_entries[task_id]["execution_parent"]
        require(item.get("execution_parent") == retained_parent
                and _known_execution_revision(state, item.get("execution_plan_revision")),
                "invalid-state", "retained task execution identity is invalid")
        if (_entry_identity(current_entries[task_id]) != _entry_identity(revised_entries[task_id])
                or _execution_ancestry(current_entries, task_id) != task["execution_ancestry"]):
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
    fingerprint_matches = state.get("fingerprint") == admitted["fingerprint"]
    require(fingerprint_matches or active_task_id is not None
            and state.get("admission_identity") == _admission_identity(admitted),
            "state-mismatch", "state belongs to another scope or execution contract")
    require(state.get("scope_identity") == admitted["scope_identity"],
            "state-mismatch", "state scope identity differs")
    legacy_layout = "execution_layout" not in state
    execution_plan_update = None
    execution_plan_error = None
    old_layout = admitted.get("_legacy_layout")
    if old_layout is not None and state.get("execution_fingerprint") == _retired_execution_fingerprint(old_layout):
        require(state.get("stop_requested") is True
                and state.get("execution_layout") == old_layout,
                "execution-plan-drift", "only the stopped retained plan may cross the cutover")
        state["execution_layout"] = copy.deepcopy(admitted["execution_layout"])
        state["execution_fingerprint"] = admitted["execution_fingerprint"]
    retained_layout = state.get("execution_layout")
    plan_matches = (isinstance(retained_layout, dict)
                    and _execution_identity(retained_layout)
                    == _execution_identity(admitted["execution_layout"]))
    plan_revision_matches = (isinstance(retained_layout, dict)
                             and retained_layout.get("revision")
                             == admitted["execution_layout"].get("revision"))
    if legacy_layout:
        state["execution_layout"] = copy.deepcopy(admitted["execution_layout"])
        state["execution_fingerprint"] = admitted["execution_fingerprint"]
    elif not plan_matches:
        if not allow_execution_plan_update:
            item = state.get("tasks", {}).get(active_task_id)
            current_entries = plan_entries(state["execution_layout"])
            prior_entries = plan_entries(admitted["execution_layout"])
            historical = (isinstance(item, dict) and active_task_id in current_entries
                          and active_task_id in prior_entries
                          and _known_execution_revision(state, item.get("execution_plan_revision"))
                          and _entry_identity(current_entries[active_task_id])
                          == _entry_identity(prior_entries[active_task_id])
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
    elif not plan_revision_matches and allow_execution_plan_update:
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
                 "evidence-pending", "satisfied", "unknown"),
                "invalid-state", "invalid task state")
        if item["status"] == "satisfied":
            require((item.get("satisfaction") or {}).get("kind") == "merged"
                    and item.get("lifecycle_error") is None,
                    "invalid-state", "satisfied prerequisite needs verified merged availability")
        elif item["status"] != "pending":
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
                snapshot = item.get("dependency_snapshot")
                expected = task["dependency_snapshot"]
                compatible = (snapshot == expected or
                              (old_layout is not None and isinstance(snapshot, dict)
                               and {key: snapshot.get(key) for key in expected} == expected))
                require(item.get("execution_parent") == task["execution_parent"]
                        and _known_execution_revision(state, item.get("execution_plan_revision"))
                        and compatible,
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
            "failure_fingerprint": None, "repair_attempts": [], "invalidates_descendants": False,
            "downstream_start": "require-ci", "downstream_policy_source": "conservative-default"}


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
            effective = set(dependencies.get("prerequisites", []))
            if dependencies.get("execution_parent") is not None:
                effective.add(dependencies["execution_parent"])
            if predecessor in effective and child_id not in affected:
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


def _ci_downstream_policy(observation):
    policy = observation.get("downstream_policy")
    if not isinstance(policy, dict) or policy.get("complete") is not True \
            or policy.get("state") not in ("require-ci", "allow-pending") \
            or not text(policy.get("source")):
        return "require-ci", "conservative-default"
    return policy["state"], policy["source"]


def _ci_applicability(observation):
    applicability = observation.get("ci_applicability")
    require(isinstance(applicability, dict) and applicability.get("complete") is True
            and applicability.get("state") in ("applicable", "pending", "not-applicable")
            and isinstance(applicability.get("expected_checks"), list)
            and isinstance(applicability.get("workflows"), list),
            "ci-applicability-incomplete", "CI applicability needs complete check/workflow context")
    expected = applicability["expected_checks"]
    require(all(isinstance(entry, dict) and text(entry.get("name")) and text(entry.get("source"))
                for entry in expected),
            "ci-applicability-incomplete", "expected check identity is incomplete")
    expected_keys = {(entry["name"], entry["source"]) for entry in expected}
    require(len(expected_keys) == len(expected),
            "ambiguous-check-identity", "expected check identities are ambiguous")
    workflows = applicability["workflows"]
    require(all(isinstance(entry, dict) and text(entry.get("name"))
                and type(entry.get("expected")) is bool and type(entry.get("applicable")) is bool
                for entry in workflows),
            "ci-applicability-incomplete", "workflow applicability evidence is malformed")
    workflow_expected = any(entry["expected"] for entry in workflows)
    require(applicability["state"] != "pending" or expected_keys or workflow_expected,
            "ci-applicability-incomplete",
            "pending applicability needs expected checks or workflows")
    return applicability["state"], expected_keys, workflows


def _classify_checks(observation, item, state):
    """Classify one complete, host-assembled observation without making network calls."""
    pr = observation.get("pr")
    require(isinstance(pr, dict), "ci-pr-incomplete", "canonical PR evidence missing")
    field_object(pr, ("url", "repo", "head_repo", "state", "branch", "head_sha",
                      "base_branch", "base_sha"), "CI PR")
    pagination = observation.get("pagination")
    require(isinstance(pagination, dict), "ci-evidence-incomplete", "CI pagination evidence missing")
    if not all(pagination.get(name) is True for name in
               ("check_runs", "commit_statuses", "required_checks")):
        raise InputError("ci-evidence-incomplete", "CI evidence did not reach terminal pagination")
    downstream_start, policy_source = _ci_downstream_policy(observation)
    applicability, expected_keys, workflows = _ci_applicability(observation)
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
    ci = item.setdefault("ci", _new_ci(item))
    ci.update(downstream_start=downstream_start, downstream_policy_source=policy_source)
    failures = []
    for record in current:
        if record["state"] not in CI_ACTIONABLE:
            continue
        reason = _check_failure_reason(record)
        if reason is not None:
            raise InputError(reason, "current failed check is not eligible for automatic repair")
        failures.append(record)
    if failures:
        fingerprint = digest(sorted(
            ({key: record.get(key) for key in
              ("name", "source", "type", "state", "category", "diagnosis")}
             for record in failures),
            key=lambda record: (record["name"], record["source"], record["type"],
                                record["state"], record["category"], record["diagnosis"]),
        ))
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
    required = observation.get("required_checks")
    required_available = isinstance(required, dict) and type(required.get("complete")) is bool \
        and isinstance(required.get("items"), list)
    require(required_available or downstream_start == "allow-pending",
            "required-check-config-incomplete", "required check configuration is incomplete")
    required_complete = required_available and required["complete"] is True
    if not required_complete and downstream_start != "allow-pending":
        raise InputError("required-check-config-inaccessible",
                         "required check configuration is inaccessible")
    required_items = required["items"] if required_complete else []
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
    missing = []
    required_nonpass = []
    for name, source in required_keys | expected_keys:
        pair = [record for kind in ("check-run", "commit-status")
                if (record := current_by_key.get((name, source, kind))) is not None]
        if not pair:
            missing.append({"name": name, "source": source})
        elif any(record["state"] in CI_PENDING for record in pair):
            continue
        elif (name, source) in required_keys \
                and any(record["state"] not in required_policy[(name, source)] for record in pair):
            required_nonpass.append({"name": name, "source": source})
    if required_nonpass:
        raise InputError("required-check-not-passing", "required check conclusions violate repository policy")
    workflow_applicable = any(entry["expected"] or entry["applicable"] for entry in workflows)
    if applicability == "not-applicable":
        require(not current and required_complete and not required_keys and not expected_keys
                and not workflow_applicable,
                "ci-applicability-unproved",
                "non-applicable CI requires complete empty discovery and workflow context")
        ci.update(state="not-applicable", reason="verified-no-applicable-ci", head_sha=pr["head_sha"],
                  target_sha=target_sha, failure_fingerprint=None,
                  next_action="no CI polling is required; keep the settled observation for resume")
        ci["links"] = links
        return ci
    if missing or not current or any(record["state"] in CI_PENDING for record in current) \
            or not required_complete:
        reason = "ci-required-policy-inaccessible" if not required_complete \
            else "ci-pending-or-missing"
        ci.update(state="checking", reason=reason, head_sha=pr["head_sha"],
                  target_sha=target_sha, failure_fingerprint=None,
                  next_action="continue observing the current revision; downstream start follows repository policy")
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
        elif item["ci"]["state"] in ("verified", "not-applicable"):
            _clear_descendant_reconciliation(admitted, state, task["task_id"])
    workspace_reopen = observation.get("workspace_reopen") if isinstance(observation, dict) else None
    if isinstance(workspace_reopen, dict):
        item.setdefault("ci", _new_ci(item))["workspace_reopen"] = copy.deepcopy(workspace_reopen)
    return item["ci"]


def cmd_observe_checks(args):
    admitted = continuation_admission(load_json(args.admitted))
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
    if ci.get("invalidates_descendants") is True or ci.get("state") in ("unverified", "repair", "blocked"):
        return True
    return ci.get("state") == "checking" and ci.get("downstream_start") != "allow-pending"


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


def review_readback(readback, head):
    """Validate complete review history, then evaluate only applicable policy evidence."""
    field_object(readback, ("head_sha", "draft", "reviews", "threads", "review_policy"), "readback")
    require(readback["head_sha"] == head, "stale-readback",
            "review history must come from a read of the current PR head")
    policy = field_object(readback["review_policy"],
                          ("complete", "required_approvals", "dismiss_stale_reviews",
                           "require_last_push_approval", "eligible_reviewers",
                           "code_owner_review_required", "code_owner_requirements"), "review policy")
    required = policy["required_approvals"]
    eligible = policy["eligible_reviewers"]
    owners = policy["code_owner_requirements"]
    last_push = policy.get("last_reviewable_push")
    require("last_reviewable_push" in policy and policy["complete"] is True
            and type(required) is int and required >= 0
            and type(policy["dismiss_stale_reviews"]) is bool
            and type(policy["require_last_push_approval"]) is bool
            and type(policy["code_owner_review_required"]) is bool
            and isinstance(eligible, list) and all(text(login) for login in eligible)
            and len({login.lower() for login in eligible}) == len(eligible)
            and isinstance(owners, list)
            and all(isinstance(group, list) and group
                    and all(text(login) for login in group) for group in owners)
            and (policy["code_owner_review_required"] or not owners)
            and (last_push is None if not policy["require_last_push_approval"] else
                 isinstance(last_push, dict) and text(last_push.get("login"))
                 and text(last_push.get("pushed_at"))),
            "review-policy-incomplete", "repository review policy read is incomplete")
    histories = {}
    for label in ("reviews", "threads"):
        value = readback[label]
        field_object(value, ("head_sha", "complete", "items"), label)
        require(value["head_sha"] == head and value["complete"] is True
                and isinstance(value["items"], list), "incomplete-pr-readback",
                label + " must be complete history bound to the observed head")
        ids = [item.get("id") for item in value["items"] if isinstance(item, dict)]
        require(len(ids) == len(value["items"])
                and all(text(item) or type(item) is int for item in ids)
                and len(set(ids)) == len(ids), "ambiguous-review-history",
                label + " must retain unique native record identities")
        histories[label] = value["items"]
    for item in histories["reviews"]:
        require(SHA_RE.fullmatch(item.get("commit_id") or "") and item.get("state") in (
            "APPROVED", "CHANGES_REQUESTED", "COMMENTED", "DISMISSED")
            and text(item.get("submitted_at"))
            and isinstance(item.get("user"), dict) and text(item["user"].get("login")),
                "incomplete-review-record", "review history must retain commit, state, author, and time")
        if item["state"] == "DISMISSED":
            dismissed_by = item.get("dismissed_by")
            require(text(item.get("dismissed_at"))
                    and isinstance(dismissed_by, dict)
                    and text(dismissed_by.get("login"))
                    and item["dismissed_at"] > item["submitted_at"],
                    "incomplete-review-record",
                    "dismissed review must identify its dismissing pusher and dismissal time")
    for item in histories["threads"]:
        require(type(item.get("is_resolved")) is bool and (text(item.get("review_id"))
                or type(item.get("review_id")) is int), "incomplete-review-thread",
                "thread history must retain review association and resolution disposition")

    latest = {}
    for review in histories["reviews"]:
        if review["state"] == "COMMENTED":
            continue
        login = review["user"]["login"]
        latest[login] = review
    review_ids = {review["id"] for review in histories["reviews"]}
    resolved_review_ids = {item["review_id"] for item in histories["threads"]
                           if item["is_resolved"]}
    dismissed_review_ids = {review["id"] for review in histories["reviews"]
                            if review["state"] == "DISMISSED"}
    for item in histories["threads"]:
        require(item["review_id"] in review_ids, "ambiguous-review-history",
                "thread identifies a review outside the complete history")
        require(item["is_resolved"] or item["review_id"] in dismissed_review_ids,
                "unresolved-review-finding", "unresolved review finding remains applicable")
    current_only = policy["dismiss_stale_reviews"] or policy["require_last_push_approval"]
    eligible_logins = {login.lower() for login in eligible}
    approvals = {
        review["user"]["login"].lower(): review for review in latest.values()
        if review["state"] == "APPROVED"
        and review["user"]["login"].lower() in eligible_logins
        and (not current_only or review["commit_id"] == head)
    }
    require(len(approvals) >= required, "review-approval-required",
            "eligible approvals do not satisfy repository policy")
    if policy["code_owner_review_required"]:
        require(all(any(login.lower() in approvals for login in group) for group in owners),
                "code-owner-approval-required", "changed paths lack required code-owner approval")
    if policy["require_last_push_approval"]:
        require(any(login != last_push["login"].lower()
                    and review["commit_id"] == head
                    and review["submitted_at"] > last_push["pushed_at"]
                    for login, review in approvals.items()),
                "last-push-approval-required", "latest reviewable push lacks another eligible approver")
    require(not any(review["state"] == "CHANGES_REQUESTED"
                    and review["id"] not in dismissed_review_ids for review in latest.values()),
            "changes-requested", "current applicable review requests changes")


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
        review_readback(pr, head)
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
            ci = item.get("ci", {})
            settled = ci.get("state") in ("verified", "not-applicable")
            permitted_pending = ci.get("state") == "checking" \
                and ci.get("downstream_start") == "allow-pending" \
                and ci.get("invalidates_descendants") is not True
            require(ci.get("head_sha") == delivery["head_sha"] and (settled or permitted_pending),
                    "pr-check-unverified",
                    "current prerequisite CI is neither settled nor explicitly permitted to remain pending")
        return {"kind": "open", "revision": delivery["head_sha"], "branch": delivery["branch"],
                "pr_url": delivery["pr_url"], "checkpoint": copy.deepcopy(delivery["checkpoint"]),
                "lifecycle": copy.deepcopy(lifecycle),
                "ci_state": item.get("ci", {}).get("state")}
    require(pr.get("association") == delivery["association"] == task["url"],
            "wrong-association", "merged prerequisite PR no longer identifies the task issue")
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
            and verification.get("reverted") is False
            and re.fullmatch(r"sha256:[0-9a-f]{64}", verification.get("diff_identity") or ""),
            "landed-evidence-missing", "landed prerequisite needs task-relevant source and check evidence")
    landed_diff = landed_diff_identity(repo, merge_sha, verification)
    require(verification["diff_identity"] == landed_diff,
            "landed-diff-mismatch", "landed evidence does not match the verified landing")
    return {"kind": "merged", "revision": merge_sha, "branch": delivery["branch"],
            "pr_url": delivery["pr_url"], "landing_branch": target, "landing_sha": target_tip,
            "original_diff_identity": delivery["validated_diff"],
            "landed_diff_identity": verification["diff_identity"],
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
    require(set(task["external_prerequisites"]).issubset(
                set(task["satisfied_external_prerequisites"])),
            "external-prerequisite", "task has unsatisfied external prerequisites")
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
    parent_checkpoint = selected[1]["checkpoint"] if selected is not None else None
    if not effective:
        planned = task["execution_parent"]
        require(planned is None or planned in task["base_satisfied_prerequisites"],
                "unapproved-parent", "root delivery must retain the admitted integration branch")
        if branch == scope["integration"]["branch"]:
            current = branch_tip(repo, branch)
            require(current is not None and (contains(repo, head, current) if retained else current == head),
                    "parent-tip-drift", "selected parent changed incompatibly")
            kind = "integration"
        else:
            # A retained stack reservation survives only while its planned parent is delivered
            # and that parent is landed in the candidate base.
            parent_delivery = (state["tasks"].get(planned) or {}).get("delivery") \
                if planned is not None else None
            landed = next((entry for entry in base_satisfied_entries(scope, task)
                           if entry["task_id"] == planned), None) if planned is not None else None
            require(retained and isinstance(parent_delivery, dict) and isinstance(landed, dict)
                    and branch == parent_delivery["branch"] and head == parent_delivery["head_sha"]
                    and contains(repo, head, landed["revision"]),
                    "unapproved-parent",
                    "retained stack parent is not a delivered, landed planned parent")
            current, kind = head, "landed-stack-parent"
            parent_checkpoint = parent_delivery["checkpoint"]
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
    proof = parent_pr_evidence(scope, branch, current, parent_checkpoint)
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
    external = next(entry for entry in scope["execution_layout"]["entries"]
                    if entry["task_id"] == task["task_id"])
    for value in external["satisfied_external_prerequisites"]:
        require(contains(repo, value["revision"], head),
                "uncontained-prerequisite",
                "selected parent does not contain external prerequisite " + value["issue_url"])
    return {"logical_prerequisites": list(task["prerequisites"]),
            "execution_prerequisites": list(effective),
            "base_satisfied_prerequisites": list(task["base_satisfied_prerequisites"]),
            "external_prerequisites": list(task["external_prerequisites"]),
            "satisfied_external_prerequisites": copy.deepcopy(
                external["satisfied_external_prerequisites"]),
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


def stack_requirement(admitted, task, readiness, state, repo):
    parent_prs = readiness["parent"]["pr_evidence"]["prs"]
    if not parent_prs:
        return None
    members = []
    for task_id in task["execution_ancestry"]:
        item = state["tasks"][task_id]
        satisfaction = prerequisite_satisfaction(
            item, task, repo, lifecycle=item.get("lifecycle"), canonical=admitted["canonical_repo"])
        if satisfaction["kind"] != "open":
            continue
        readback = satisfaction["checkpoint"]["readback"]
        members.append({key: readback[key] for key in (
            "pr_url", "branch", "head_sha", "base_branch", "draft")})
    require(members and members[-1]["pr_url"] == parent_prs[0]["pr_url"],
            "parent-pr-evidence", "open parent PR is outside the approved execution chain")
    return {"trunk": admitted["integration"]["branch"], "members": members}


def validate_stack(reservation, result, readback):
    expected = reservation.get("stack")
    if expected is None:
        require(result.get("stack") is None, "stack-readback",
                "independent delivery must not carry native stack evidence")
        return
    stack = result.get("stack")
    require(isinstance(stack, dict) and all(
        key in stack and stack[key] is not None for key in
        ("complete", "number", "trunk", "members")),
        "stack-readback", "native stack readback is missing or incomplete")
    require(stack["complete"] is True and type(stack["number"]) is int and stack["number"] > 0,
            "stack-readback", "native stack identity and pagination must be complete")
    require(stack["trunk"] == expected["trunk"] and isinstance(stack["members"], list),
            "stack-readback", "native stack trunk or membership differs from the approved chain")
    child = {key: readback[key] for key in (
        "pr_url", "branch", "head_sha", "base_branch", "draft")}
    members = [*expected["members"], child]
    require(stack["members"] == members,
            "stack-readback", "native stack membership differs from the approved chain")
    require(members[0]["base_branch"] == stack["trunk"] and all(
        member["base_branch"] == members[index - 1]["branch"]
        for index, member in enumerate(members[1:], 1)),
        "stack-readback", "native stack bases do not form the approved ordered chain")


def validate_delivery(admitted, task, reservation, result, repo, *, historical=False,
                      retained_diff=None, workspace_required=True, existing_pr=False,
                      expected_draft=None):
    require(set(task["external_prerequisites"]).issubset(
                set(task["satisfied_external_prerequisites"])),
            "external-prerequisite", "delivery has unsatisfied external prerequisites")
    external = next(entry for entry in admitted["execution_layout"]["entries"]
                    if entry["task_id"] == task["task_id"])
    for value in external["satisfied_external_prerequisites"]:
        require(contains(repo, value["revision"], reservation["parent_sha"]),
                "uncontained-prerequisite",
                "delivery parent does not contain external prerequisite " + value["issue_url"])
    require(result.get("outcome") in ("ok", "needs-repair"), "unknown-response", "worker outcome unknown")
    worker = field_object(result.get("worker"), ("worker_id", "pr_url", "branch", "workspace", "head_sha",
                          "base_branch", "commit_sha", "association"), "worker")
    readback = field_object(result.get("readback"), ("repo", "head_repo", "pr_url", "branch", "head_sha",
                            "base_branch", "commit_sha", "association", "closing_references", "open", "draft",
                            "unique", "diff_identity", "reviews", "threads"), "readback")
    require(text(worker["worker_id"]), "invalid-worker", "native host worker identity required")
    for key in ("pr_url", "branch", "head_sha", "base_branch", "commit_sha", "association"):
        require(worker[key] == readback[key], "evidence-mismatch", "worker/readback disagree on " + key)
    if reservation.get("attempt_binding") is not None:
        require(worker.get("attempt_binding") == reservation["attempt_binding"],
                "attempt-binding-mismatch", "worker result is not bound to the issued attempt")
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
    if existing_pr:
        if expected_draft is not None:
            require(type(expected_draft) is bool and readback["draft"] is expected_draft,
                    "readiness-changed", "repair must preserve the retained PR readiness")
    else:
        require(readback["draft"] is True, "draft-required", "new orchestrated delivery must be a draft")
    review_readback(readback, readback["head_sha"])
    require(readback["branch"] == reservation["branch"], "wrong-branch", "PR head is not reserved branch")
    require(readback["base_branch"] == reservation["parent_branch"], "wrong-base", "PR base is not admitted parent")
    require(readback["association"] == task["url"] and readback["closing_references"] == [task["url"]],
            "wrong-association", "exactly the task issue may be a closing reference")
    validate_stack(reservation, result, readback)
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
    commands = checks["commands"]
    require(isinstance(commands, list) and all(
        isinstance(command, dict) and text(command.get("command"))
        and type(command.get("executed")) is bool
        and type(command.get("passed")) is bool for command in commands),
        "checks-incomplete", "check outcomes must identify executed commands and results")
    require(all(command["executed"] for command in commands),
            "checks-incomplete", "every reported check must be observed")
    observed = {}
    for command in commands:
        observed.setdefault(command["command"], []).append(command)
    require(all(observed.get(required) for required in task["contract"]["checks"]),
            "checks-incomplete", "all mandatory checks must be observed")
    smoke = checks["smoke"]
    require(isinstance(smoke, dict) and text(smoke.get("description"))
            and type(smoke.get("executed")) is bool
            and type(smoke.get("passed")) is bool and smoke["executed"],
            "checks-incomplete", "smoke outcome must describe an observed scenario and result")
    outcomes_passed = all(command["passed"] for command in commands) and smoke["passed"]
    require(type(checks["passed"]) is bool and checks["passed"] == outcomes_passed
            and validation["verdict"] in ("pass", "fail"),
            "unknown-response", "verification/review outcome malformed")
    if not outcomes_passed:
        return {"status": "repair-ready", "reason": "checks-failed"}
    if result["outcome"] == "needs-repair" or validation["verdict"] == "fail":
        return {"status": "repair-ready", "reason": "validation-failed"}
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
    binding = reservation.get("attempt_binding") or issued_attempt_binding(task, reservation, repair, retained, readiness)
    specification = task["specification"]
    execution_order = {
        "plan_revision": admitted["execution_layout"]["revision"],
        "execution_parent": task["execution_parent"],
        "rationale": task["execution_rationale"],
        "constraints": copy.deepcopy(task["execution_constraints"]),
        "fallback": copy.deepcopy(task["execution_fallback"]),
        "effective_prerequisites": list(task["effective_prerequisites"]),
        "base_satisfied_prerequisites": list(task["base_satisfied_prerequisites"]),
        "satisfied_external_prerequisites": list(task["satisfied_external_prerequisites"]),
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
        "attempt_binding": binding,
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
    external = next(entry for entry in scope["execution_layout"]["entries"]
                    if entry["task_id"] == task["task_id"])
    heads.extend(value["revision"] for value in external["satisfied_external_prerequisites"])
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
        "satisfied": sorted(tid for tid, item in tasks.items() if item["status"] == "satisfied"),
        "evidence_pending": sorted(tid for tid, item in tasks.items() if item["status"] == "evidence-pending"),
        "repair_ready": sorted(tid for tid, item in tasks.items() if item["status"] == "repair-ready"),
        "pending": sorted(tid for tid, item in tasks.items() if item["status"] == "pending"),
        "checking": sorted(tid for tid, item in tasks.items()
                           if item.get("ci", {}).get("state") == "checking"),
        "verified": sorted(tid for tid, item in tasks.items()
                           if item.get("ci", {}).get("state") == "verified"),
        "not_applicable": sorted(tid for tid, item in tasks.items()
                                if item.get("ci", {}).get("state") == "not-applicable"),
        "ci_blocked": sorted(tid for tid, item in tasks.items()
                             if item.get("ci", {}).get("state") == "blocked"),
        "repair": sorted(tid for tid, item in tasks.items()
                         if item.get("ci", {}).get("state") == "repair"),
        "ci_details": {
            tid: {"state": item["ci"]["state"], "pr_url": item.get("verified_pr"),
                  "head_sha": item["ci"].get("head_sha"), "target_sha": item["ci"].get("target_sha"),
                  "reason": item["ci"].get("reason"), "next_action": item["ci"].get("next_action"),
                  "downstream_start": item["ci"].get("downstream_start"),
                  "downstream_policy_source": item["ci"].get("downstream_policy_source"),
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
    result = normalize_retained_result(retained["result"])
    proof = validate_delivery(admitted, task, retained["reservation"], result, repo,
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
                                             verify_checks=False)
    return proof, lifecycle, satisfaction

def normalize_retained_result(result):
    normalized = copy.deepcopy(result)
    checks = normalized.get("checks") if isinstance(normalized, dict) else None
    if not isinstance(checks, dict) or type(checks.get("passed")) is not bool:
        return normalized
    commands = checks.get("commands")
    if isinstance(commands, list) and all(text(command) for command in commands):
        checks["commands"] = [
            {"command": command, "executed": True, "passed": checks["passed"]}
            for command in commands
        ]
    smoke = checks.get("smoke")
    if text(smoke):
        checks["smoke"] = {
            "description": smoke, "executed": True, "passed": checks["passed"],
        }
    return normalized



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


def _external_wait(task):
    missing = sorted(set(task["external_prerequisites"]) -
                     set(task["satisfied_external_prerequisites"]))
    return {"task_id": task["task_id"], "reason": "external-prerequisite",
            "next_action": "; ".join(
                issue + ": " + task["external_evidence_errors"].get(
                    issue, "missing landed evidence") + " — refresh canonical issue, merged PR, "
                "landed verification, and candidate-base evidence"
                for issue in missing)}






def cmd_schedule(args):
    admitted = continuation_admission(load_json(args.admitted))
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
        advance = integration_advance_evidence(root, admitted, fresh)
        state.setdefault("recovery", {})["integration_advance"] = copy.deepcopy(advance)
        plan_error = state.pop("_execution_plan_error", None)
        if plan_error is not None:
            raise InputError(plan_error["code"], plan_error["message"])
        plan_update = state.pop("_execution_plan_update", None)
        if plan_update is not None:
            _apply_execution_plan_update(state, fresh, plan_update)
        if plan_identity(state["execution_layout"]) == plan_identity(fresh["execution_layout"]):
            # The plan is unchanged; refresh mutable merged and external satisfaction evidence.
            state["execution_layout"] = copy.deepcopy(fresh["execution_layout"])
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
        if not (item["status"] in ("delivered", "satisfied")
                or (item["status"] == "pending" and retained is not None)):
            continue
        if item["status"] == "satisfied":
            if task.get("own_availability") is not None:
                item["satisfaction"] = copy.deepcopy(task["own_availability"])
                continue
            item.update(status="pending", satisfaction=None, lifecycle_error=None,
                        failure_reason=None)
        if item["status"] == "pending" and task.get("own_availability") is not None:
            # A merged delivery is repository evidence; its old claim belongs to its old writer.
            item.update(status="satisfied", satisfaction=copy.deepcopy(task["own_availability"]),
                        lifecycle_error=None, failure_reason=None)
            continue
        if item["status"] == "pending":
            if (isinstance(retained, dict) and task.get("own_availability_error")
                    and lifecycle_state(retained.get("lifecycle")) == "merged"):
                reason = task["own_availability_error"]
                item["lifecycle_error"] = {
                    "reason": reason,
                    "next_action": "refresh historical PR, merge, and check evidence for this prerequisite"}
                blocked.append({"task_id": tid, "reason": reason,
                                "next_action": item["lifecycle_error"]["next_action"]})
                continue
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
        if any(issue not in task["satisfied_external_prerequisites"]
               for issue in task["external_prerequisites"]):
            if retained_reservation is not None:
                item["status"] = "repair-ready"
                item["failure_reason"] = "external-prerequisite"
            blocked.append(_external_wait(task))
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
            if item["status"] == "pending":
                # A read-only historical import never launched a writer, so uncertain evidence
                # blocks this task and its dependents without occupying capacity.
                item["lifecycle_error"] = {
                    "reason": reason,
                    "next_action": "refresh historical PR, merge, and check evidence for this prerequisite"}
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
    import_only = set()
    for tid, item in state["tasks"].items():
        retained = fresh_tasks[tid].get("existing_delivery")
        if (item["status"] == "unknown" and isinstance(retained, dict)
                and item.get("last_evidence") == retained
                and item.get("host_worker") is None and item.get("report") is None):
            try:
                if _import_only(item, fresh["recovery"], args.git_repo,
                                admitted, fresh_tasks[tid], state):
                    import_only.add(tid)
            except InputError:
                pass  # Unproved ownership or liveness keeps this slot occupied.
    occupied = [tid for tid, item in state["tasks"].items()
                if item["status"] in ("running", "unknown") and tid not in import_only]
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
        if any(issue not in task["satisfied_external_prerequisites"]
               for issue in task["external_prerequisites"]):
            blocked.append(_external_wait(task))
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
            required_stack = stack_requirement(admitted, task, readiness, state, args.git_repo)
        except InputError as error:
            blocked.append({"task_id": tid, "reason": error.code,
                            "next_action": "refresh canonical parent, PR, and Git evidence before retrying"})
            continue
        if required_stack is not None:
            reservation["stack"] = required_stack
        if item.get("ci", {}).get("state") == "repair":
            _repair_attempt(item)
        repair_evidence = copy.deepcopy(item.get("ci", {}).get("repair_context")) if repair else None
        if repair and isinstance(repair_evidence, dict) and item.get("ci", {}).get("workspace_reopen"):
            repair_evidence["workspace_reopen"] = copy.deepcopy(item["ci"]["workspace_reopen"])
        binding = issued_attempt_binding(task, reservation, repair, retained_pr, readiness)
        reservation["attempt_binding"] = binding
        item.update(status="running", reservation=reservation, attempt_binding=binding,
                    attempt_history=item.get("attempt_history", []) + [{
                        "binding": binding, "repair": repair, "retained_pr": retained_pr,
                        "worker": None,
                    }],
                    parent_decision=copy.deepcopy(decision),
                    execution_parent=task["execution_parent"],
                    execution_plan_revision=admitted["execution_layout"]["revision"],
                    dependency_snapshot=copy.deepcopy(task["dependency_snapshot"]),
                    host_worker=None,
                    first_uncertain_boundary=None,
                    last_evidence={"parent_readiness": copy.deepcopy(readiness)})
        dispatch.append({"task_id": tid, "ordinal": task["ordinal"], "child_url": task["url"],
                         "repair": repair, "retained_pr": retained_pr, **reservation,
                         "workspace_reopen": copy.deepcopy(item.get("ci", {}).get("workspace_reopen")) if repair else None,
                         "packet": packet(fresh, task, reservation, repair, retained_pr,
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
    admitted = continuation_admission(load_json(args.admitted))
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
    require(receipt.get("reservation") == item["reservation"]
            and receipt.get("attempt_binding") == item.get("attempt_binding"),
            "evidence-mismatch", "host launch readback must match the issued attempt")
    require(item.get("host_worker") in (None, worker),
            "worker-liveness", "recorded writer cannot be replaced")
    require(receipt.get("state_digest") == state["_loaded_digest"],
            "worker-liveness", "host launch readback must bind the current checkpoint")
    task = next(t for t in admitted["tasks"] if t["task_id"] == args.task)
    claim_scope(args.git_repo, admitted, state)
    claim_task(args.git_repo, admitted, task, state, item)
    item["host_worker"] = copy.deepcopy(worker)
    if item.get("attempt_history"):
        item["attempt_history"][-1]["worker"] = copy.deepcopy(worker)
    write_state(args, state)
    return {"status": "worker-recorded", "task_id": args.task}


def cmd_apply_result(args):
    admitted = continuation_admission(load_json(args.admitted))
    repository(args.git_repo, admitted["canonical_repo"])
    state = state_read(args.state, admitted, repo=args.git_repo, active_task_id=args.task)
    require(args.task in state["tasks"], "unknown-task", "task outside admitted scope")
    item = state["tasks"][args.task]
    require(item["status"] in ("running", "note-pending", "evidence-pending"),
            "not-running", "task has no active reservation or receipt retry")
    legacy_drift = _legacy_execution_drift_tasks(state)
    require(args.task not in legacy_drift, "execution-plan-drift",
            "task requires legacy execution-plan reconciliation")
    task = next(t for t in admitted["tasks"] if t["task_id"] == args.task)
    require(item.get("contract_hash") == task["contract_hash"]
            and item.get("execution_parent") == task["execution_parent"]
            and item.get("dependency_snapshot") == task["dependency_snapshot"],
            "execution-plan-drift", "worker result is for a different issued task contract or parent")

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
    if result.get("outcome") in ("ok", "needs-repair") and isinstance(worker, dict):
        issued_binding = item.get("reservation", {}).get("attempt_binding")
        required_worker_fields = {"worker_id", "pr_url", "branch", "workspace", "head_sha",
                                  "base_branch", "commit_sha", "association"}
        if issued_binding is not None and required_worker_fields <= set(worker):
            require(worker.get("attempt_binding") == issued_binding,
                    "attempt-binding-mismatch", "worker result is not bound to the issued attempt")
    task = next(t for t in admitted["tasks"] if t["task_id"] == args.task)
    claim_scope(args.git_repo, admitted, state)
    claim_task(args.git_repo, admitted, task, state, item)
    try:
        retained_pr = item.get("verified_pr")
        prior_evidence = item.get("last_evidence")
        verified_update = bool(retained_pr) and (
            isinstance(item.get("delivery"), dict)
            or isinstance(prior_evidence, dict) and isinstance(prior_evidence.get("readback"), dict))
        lifecycle_pr = (item.get("lifecycle") or {}).get("pr")
        require(not verified_update or isinstance(lifecycle_pr, dict)
                and type(lifecycle_pr.get("draft")) is bool,
                "pr-lifecycle-missing", "repair requires fresh retained PR readiness")
        proof = validate_delivery(admitted, task, item["reservation"], result, args.git_repo,
                                  existing_pr=verified_update,
                                  expected_draft=lifecycle_pr["draft"] if verified_update else None)
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
    admitted = continuation_admission(load_json(args.admitted))
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
    admitted = continuation_admission(load_json(args.admitted))
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




def _import_only(item, inventory, repo, admitted, task, state):
    """An import-only uncertainty has no bound writer; prove it stopped and unowned."""
    if item.get("host_worker") is not None or item.get("report") is not None:
        return False
    reservation = item.get("reservation")
    for rows in (inventory["sessions"], inventory["processes"]):
        require(isinstance(rows, list) and all(isinstance(row, dict) for row in rows),
                "incomplete-recovery", "host session/process inventory must be explicit lists")
        for row in rows:
            if row.get("task_id") == task["task_id"] or (reservation is not None
                                                        and row.get("reservation") == reservation):
                require(row.get("status") == "stopped", "worker-liveness",
                        "current host readback must prove the reserved writer stopped")
    if isinstance(reservation, dict) and Path(reservation["workspace"]).exists():
        workspace_identity(repo, admitted["canonical_repo"],
                           reservation["workspace"], reservation["branch"])
    key = _claim_key(admitted, task)
    path = _claims_root(repository(repo, admitted["canonical_repo"])) / (key + ".json")
    if path.is_symlink():
        raise InputError("unsafe-ownership", "orchestration claim cannot be a symlink")
    if path.exists():
        claim = load_json(path)
        require(claim.get("owner") == state["owner"]["controller_id"]
                and claim.get("canonical_repo") == admitted["canonical_repo"]
                and claim.get("scope") == admitted["scope_identity"]
                and claim.get("issue_url") == task["url"],
                "ownership-conflict", "uncertain task is owned by another controller")
    return True


def cmd_resume(args):
    admitted = continuation_admission(load_json(args.admitted))
    root = repository(args.git_repo, admitted["canonical_repo"])
    state = state_read(args.state, admitted, repo=args.git_repo)
    require(state["stop_requested"], "not-stopped", "resume requires a persisted stop request")
    claim_scope(args.git_repo, admitted, state)
    fresh = admit(load_json(args.fresh), admitted["max_parallel"], args.git_repo)
    require(fresh.get("recovery") is not None, "incomplete-recovery",
            "resume requires a complete fresh recovery inventory")
    require(fresh["fingerprint"] == admitted["fingerprint"],
            "snapshot-drift", "scope/native identity/contract changed")
    require(fresh["execution_fingerprint"] == admitted["execution_fingerprint"],
            "execution-plan-drift", "execution layout changed without a newer admitted plan")
    advance = integration_advance_evidence(root, admitted, fresh)
    state.setdefault("recovery", {})["integration_advance"] = copy.deepcopy(advance)
    inventory = recovery_inventory(fresh["recovery"])
    tasks = {task["task_id"]: task for task in fresh["tasks"]}
    released, retained = [], []
    for item in state["tasks"].values():
        if item["status"] != "unknown" and item.get("lifecycle_error") is None:
            continue
        task_id = item["task_id"]
        fact = tasks[task_id].get("own_availability")
        if fact is None or not _import_only(item, inventory, args.git_repo, admitted, tasks[task_id], state):
            retained.append(task_id)
            continue
        item.update(status="satisfied", satisfaction=copy.deepcopy(fact), lifecycle_error=None,
                    failure_reason=None, first_uncertain_boundary=None)
        released.append(task_id)
    stop_boundary = state.get("recovery", {}).get("first_uncertain_boundary")
    stop_reason = stop_boundary.get("reason") if isinstance(stop_boundary, dict) \
        and stop_boundary.get("status") == "stop-requested" else None
    state["stop_requested"] = False
    if state.get("halt_reason") == "user-stop" or (stop_reason is not None
                                                  and state.get("halt_reason") == stop_reason):
        state["halt_new_dispatch"], state["halt_reason"] = False, None
        state.setdefault("recovery", {}).pop("first_uncertain_boundary", None)
    write_state(args, state)
    return {"status": "resumed", "released": sorted(released),
            "retained_unknown": sorted(set(retained)),
            "dispatch": [], **_state_summary(state)}


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
    resume = commands.add_parser("resume")
    resume.add_argument("--admitted", required=True)
    resume.add_argument("--fresh", required=True)
    resume.add_argument("--state", required=True)
    resume.add_argument("--state-out", required=True)
    resume.add_argument("--git-repo", required=True)
    resume.set_defaults(run=cmd_resume)
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
