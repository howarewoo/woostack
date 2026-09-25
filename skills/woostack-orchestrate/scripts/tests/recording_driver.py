#!/usr/bin/env python3
"""Test-only fake GitHub/host transports for the shipped orchestrate CLI.

The behavioral suite imports this module for fixture assembly and for a real
ThreadPoolExecutor-backed host.  The helper remains the only scheduler: the
host consumes emitted Execute packets, uses the selected runtime workspace and
branch evidence, commits a small task file, and records a canonical fake PR.
When invoked as a script this module is a thin recording wrapper around the shipped
``scripts/orchestrate.py`` CLI.
"""

from __future__ import annotations

import copy
import hashlib
import json
import os
import secrets
import shlex
import subprocess
import sys
import threading
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Any, Dict, Iterable, Optional, Sequence, Tuple


TESTS_DIR = Path(__file__).resolve().parent
SKILL_DIR = TESTS_DIR.parent.parent
HELPER = SKILL_DIR / "scripts" / "orchestrate.py"
DRIVER = Path(__file__).resolve()


def _canonical_json(value: Any) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode("utf-8")


def contract_hash(contract: Dict[str, Any]) -> str:
    return "sha256:" + hashlib.sha256(_canonical_json(contract)).hexdigest()


def git(repo: Path, *args: str, check: bool = True) -> str:
    proc = subprocess.run(
        ["git", "-C", str(repo), *args],
        capture_output=True,
        text=True,
    )
    if check and proc.returncode:
        raise AssertionError("git failed (%s): %s" % (" ".join(args), proc.stderr.strip()))
    return proc.stdout.strip()


def diff_identity(repo: Path, parent_sha: str, head_sha: str) -> str:
    proc = subprocess.run(
        ["git", "-C", str(repo), "diff", "--no-ext-diff", "--no-textconv", "--no-color", "--binary", parent_sha, head_sha],
        capture_output=True,
    )
    if proc.returncode:
        raise AssertionError("git diff failed: %s" % proc.stderr.decode(errors="replace"))
    return "sha256:" + hashlib.sha256(proc.stdout).hexdigest()


def record(kind: str, operation: str, payload: Any) -> None:
    path = os.environ.get("WOOSTACK_ORCHESTRATE_TRANSPORT_LOG")
    if not path:
        return
    entry = {"kind": kind, "operation": operation, "payload": payload}
    with Path(path).open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(entry, sort_keys=True) + "\n")


def invoke_cli(*args: str, cwd: Optional[Path] = None) -> Tuple[int, Dict[str, Any]]:
    """Invoke the shipped helper through this recording wrapper.

    This deliberately uses a subprocess for every operation.  No scheduler is
    implemented here; the wrapper only records transport boundaries and passes
    bytes to ``orchestrate.py``.
    """

    proc = subprocess.run(
        [sys.executable, str(DRIVER), *args],
        cwd=str(cwd) if cwd else None,
        capture_output=True,
        text=True,
    )
    try:
        payload = json.loads(proc.stdout)
    except json.JSONDecodeError:
        payload = {"raw": proc.stdout, "stderr": proc.stderr}
    return proc.returncode, payload


def run_verification(workspace: Path, contract: Dict[str, Any]) -> None:
    for command in [*contract["checks"], contract["smoke"]]:
        result = subprocess.run(shlex.split(command), cwd=workspace, capture_output=True, text=True)
        record("verification", "run-command", {
            "command": command, "returncode": result.returncode,
            "stdout": result.stdout, "stderr": result.stderr,
        })
        result.check_returncode()


def make_contract(task_id: str) -> Dict[str, Any]:
    return {
        "goal": "Implement the distinct %s increment" % task_id,
        "scope": ["src/%s.txt" % task_id],
        "non_goals": ["Do not modify sibling task files"],
        "acceptance": ["The %s file contains its task marker" % task_id],
        "checks": [
            "python3 -c \"from pathlib import Path; assert '%s' in Path('src/%s.txt').read_text()\"" % (task_id, task_id),
            "git diff --check",
        ],
        "smoke": "cat src/%s.txt" % task_id,
        "decisions": "Use one small source file and one commit.",
        "risks": "None beyond the bounded file change.",
    }


def issue_record(
    parent_url: str,
    task_id: str,
    ordinal: int,
    number: int,
    prerequisites: Optional[Sequence[str]] = None,
    *,
    actual_parent: Optional[str] = None,
    workspace: Optional[str] = None,
) -> Dict[str, Any]:
    record_value: Dict[str, Any] = {
        "task_id": task_id,
        "ordinal": ordinal,
        "url": "https://github.com/acme/app/issues/%d" % number,
        "id": 10000 + number,
        "node_id": "I_kwDOtest%08d" % number,
        "state": "open",
        "resource": "issue",
        "title": "Task %s" % task_id,
        "body": "Bounded native child %s" % task_id,
        "actual_parent": actual_parent if actual_parent is not None else parent_url,
        "declared_parent": actual_parent if actual_parent is not None else parent_url,
        "nested_children": False,
        "prerequisites": list(prerequisites or []),
        "external_prerequisites": [],
        "contract": make_contract(task_id),
    }
    if workspace is not None:
        record_value["workspace"] = workspace
    return record_value


class FakeGitHub:
    """Paginated native issue/Project reads and canonical PR/note storage."""

    canonical = "https://github.com/acme/app"

    def __init__(self, repo: Path, base_sha: str, *, max_parallel: int = 3) -> None:
        self.repo = Path(repo)
        self.base_sha = base_sha
        self.max_parallel = max_parallel
        self.parent_url = self.canonical + "/issues/100"
        self.specification = "Parent P is the approved specification for A/B/C/D/E."
        self.repository_rules = "Use the repository's existing rules; keep each task bounded."
        self.integration = {"branch": "main", "sha": base_sha}
        self.parent = {
            "url": self.parent_url,
            "id": 100,
            "node_id": "I_kwDOtestparent",
            "state": "open",
            "resource": "issue",
            "parent": None,
            "title": "P specification",
            "body": self.specification,
        }
        self.children = [
            issue_record(self.parent_url, "task-a", 1, 101),
            issue_record(self.parent_url, "task-b", 2, 102),
            issue_record(self.parent_url, "task-c", 3, 103, ["task-a"]),
            issue_record(self.parent_url, "task-d", 4, 104, ["task-a"]),
            issue_record(self.parent_url, "task-e", 5, 105),
        ]
        # Runtime allocation is supplied by the host-facing snapshot, not the
        # admitted issue contract.  These paths deliberately live outside the
        # checkout and use ordinary repository branch names.
        for child in self.children:
            child["workspace"] = str(self.repo.parent / "host-worktrees" / child["task_id"])
            child["branch"] = "feature/" + child["task_id"]
        self.tracker_fixtures = self._tracker_fixtures()
        # Multiple native pages are deliberately assembled before a snapshot is
        # emitted.  These are not scheduler decisions; they model paginated gh
        # reads and leave an auditable transport log.
        self.child_pages = [self.children[:2], self.children[2:]]
        self.parent_pages = [[self.parent]]
        self.dependency_pages = [
            [{"task_id": "task-c", "blocked_by": ["task-a"]}],
            [{"task_id": "task-d", "blocked_by": ["task-a"]}],
        ]
        self.contract_pages = [self.children[:2], self.children[2:]]
        self.prs: Dict[str, Dict[str, Any]] = {}
        self.notes: Dict[str, Dict[str, Any]] = {}
        self.delivery: Dict[str, Dict[str, Any]] = {}
        self.parent_branches = {"main"}
        self.project_status_reads = []
        self.calls = []
        self._lock = threading.Lock()

    def execution_layout(
        self,
        task_ids: Sequence[str],
        parents: Dict[str, Optional[str]],
        fallbacks: Optional[Dict[str, str]] = None,
    ) -> Dict[str, Any]:
        fallbacks = fallbacks or {}
        entries = []
        for task_id in sorted(task_ids):
            parent = parents.get(task_id)
            entry = {
                "task_id": task_id,
                "execution_parent": parent,
                "rationale": (
                    "Stack after %s to keep every later prerequisite on one ancestor path." % parent
                    if parent else
                    "Start from the approved integration base."
                ),
                "constraints": ["deterministic recording-driver fixture"],
            }
            if task_id in fallbacks:
                entry["fallback"] = {
                    "reason": "merge-checkpoint",
                    "release_condition": fallbacks[task_id],
                }
            entries.append(entry)
        return {
            "revision": 1,
            "rationale": "Use one valid execution tree unless existing divergence requires a merge checkpoint.",
            "entries": entries,
        }

    def _read_pages(self, family: str, pages: Iterable[Sequence[Dict[str, Any]]]) -> list:
        values = []
        for index, page in enumerate(pages, 1):
            record("github", "read-page", {"family": family, "page": index})
            self.calls.append((family, index))
            values.extend(copy.deepcopy(list(page)))
        return values

    def parent_pr_readbacks(self) -> Dict[str, Any]:
        result = {}
        for branch in self.parent_branches:
            head = git(self.repo, "rev-parse", "refs/heads/" + branch)
            matches = [task for task, pr in self.prs.items()
                       if pr["branch"] == branch and pr["head_sha"] == head]
            result[branch] = {
                "repo": self.canonical, "branch": branch, "head_sha": head, "complete": True,
                "prs": [{**self.readback(task), "state": "open"} for task in matches],
            }
            record("github", "read-parent-prs", result[branch])
        return result

    def snapshot(self) -> Dict[str, Any]:
        """Read all fake native pages and assemble one controller snapshot."""

        parent_pages = self._read_pages("parent", self.parent_pages)
        children = self._read_pages("sub_issues", self.child_pages)
        self._read_pages("dependencies", self.dependency_pages)
        self._read_pages("contracts", self.contract_pages)
        snapshot_children = []
        for child in children:
            enriched = copy.deepcopy(child)
            delivery = self.delivery.get(enriched["task_id"])
            if delivery is not None:
                enriched["existing_delivery"] = copy.deepcopy(delivery)
            snapshot_children.append(enriched)
        parent = parent_pages[0]
        result = {
            "canonical_repo": self.canonical,
            "integration": copy.deepcopy(self.integration),
            "parent_prs": self.parent_pr_readbacks(),
            "execution_layout": self.execution_layout(
                (item["task_id"] for item in snapshot_children),
                {"task-a": None, "task-b": None, "task-c": "task-a", "task-d": "task-a", "task-e": None},
            ),
            "repository_rules": self.repository_rules,
            "specification": self.specification,
            "host": {"delivery_capable": True, "max_parallel": self.max_parallel},
            "parent": parent,
            "children": snapshot_children,
            "tasks": snapshot_children,
            "recovery": {
                "checkpoints": [],
                "processes": [],
                "sessions": [],
                "worktrees": [],
                "refs": [],
                "prs": [],
                "contracts": [],
                "dependencies": [],
            },
        }
        record("github", "assemble-issue-snapshot", {
            "pages": len(self.child_pages),
            "children": [child["task_id"] for child in snapshot_children],
        })
        return result

    def issue_list_snapshot(self, selected: Optional[Sequence[str]] = None) -> Dict[str, Any]:
        """Assemble selected issue evidence and an interpreted DAG for scheduling."""
        issues = []
        for child in self.children:
            item = copy.deepcopy(child)
            item["actual_parent"] = None
            item["declared_parent"] = None
            item["prerequisites"] = []
            item["external_prerequisites"] = []
            if item["task_id"] in self.delivery:
                item["existing_delivery"] = copy.deepcopy(self.delivery[item["task_id"]])
            issues.append(item)
        selected = list(selected or [item["url"] for item in issues])
        edges = [
            {"predecessor": "task-a", "dependent": "task-c", "provenance": "inferred",
             "evidence": {"reason": "C consumes the interface introduced by A"}},
            {"predecessor": "task-b", "dependent": "task-d", "provenance": "inferred",
             "evidence": {"reason": "D consumes the migration delivered by B"}},
            {"predecessor": "task-c", "dependent": "task-d", "provenance": "inferred",
             "evidence": {"reason": "D consumes the API delivered by C"}},
        ]
        result = {
            "canonical_repo": self.canonical,
            "integration": copy.deepcopy(self.integration),
            "parent_prs": self.parent_pr_readbacks(),
            "repository_rules": self.repository_rules,
            "host": {"delivery_capable": True, "max_parallel": self.max_parallel},
            "execution_layout": self.execution_layout(
                (item["task_id"] for item in issues),
                {"task-a": None, "task-b": None, "task-c": "task-a"},
                {"task-d": "All divergent prerequisite deliveries land in the approved base."},
            ),
            "recovery": self.snapshot()["recovery"],
            "issues": issues,
            "graph": {"edges": edges},

        }
        result["selected_issues"] = [item for item in issues if item["url"] in selected]
        selected_ids = {item["task_id"] for item in result["selected_issues"]}
        result["execution_layout"]["entries"] = [
            entry for entry in result["execution_layout"]["entries"] if entry["task_id"] in selected_ids
        ]
        result["issues"] = result["selected_issues"]
        result["tasks"] = result["issues"]
        record("github", "assemble-issue-list-snapshot", {
            "issues": selected, "edges": len(edges),
        })
        return result

    def _tracker_fixtures(self) -> Dict[str, Dict[str, Any]]:
        tracker_url = self.canonical + "/issues/15"
        contrasting_tracker_url = self.canonical + "/issues/42"
        context = issue_record(tracker_url, "context-design", 0, 2)
        context.update({
            "url": self.canonical + "/issues/2", "id": 10002,
            "node_id": "I_kwDOtestcontext2", "title": "Design context, not executable scope",
            "body": "Design decisions only.", "actual_parent": None, "declared_parent": None,
            "tracker_membership": "context",
        })
        reported_tasks = []
        for number in range(3, 10):
            task = issue_record(tracker_url, "issue-%d" % number, number - 2, number)
            task.update({
                "title": "Implementation issue #%d" % number,
                "body": "Complete issue #%d.%s" % (
                    number, " Phase #9-A records the start gate; phase #9-B records completion." if number == 9 else "",
                ),
                "prerequisites": [], "external_prerequisites": [],
                "tracker_membership": "implementation",
                "workspace": str(self.repo.parent / "tracker-worktrees" / str(number)),
                "branch": "tracker/issue-%d" % number,
            })
            task.pop("actual_parent", None)
            task.pop("declared_parent", None)
            reported_tasks.append(task)
        abcd_tasks = []
        contrasting_context = issue_record(contrasting_tracker_url, "contrasting-context", 0, 90)
        contrasting_context.update({
            "title": "Contrasting design context, not executable scope",
            "body": "Design decisions only.", "actual_parent": None, "declared_parent": None,
            "tracker_membership": "context",
        })
        for child in self.children[:4]:
            task = copy.deepcopy(child)
            task.update({
                "prerequisites": [], "external_prerequisites": [],
                "tracker_membership": "implementation",
            })
            if task["task_id"] == "task-d":
                task["body"] += " Phase delivery-b remains inside this issue."
            task.pop("actual_parent", None)
            task.pop("declared_parent", None)
            abcd_tasks.append(task)
        return {
            "reported": {
                "tracker": {
                    "url": tracker_url, "id": 10015, "node_id": "I_kwDOtesttracker15",
                    "title": "Implementation tracker", "revision": "2026-09-23T20:00:00Z",
                    "body": (
                        "Context: design #2. Baseline: PR #1. Implementation index:\n"
                        "- #3: foundation\n- #4: API\n- #5: data\n- #6: service\n"
                        "- #7: UI\n- #8: integration\n- #9: phase #9-A and phase #9-B\n"
                        "Issue #9 has phases #9-A and #9-B."
                    ),
                    "implementation_index": [task["url"] for task in reported_tasks],
                    "dependency_index": [
                        {"predecessor": "issue-3", "dependent": "issue-5"},
                        {"predecessor": "issue-4", "dependent": "issue-6"},
                        {"predecessor": "issue-5", "dependent": "issue-6"},
                        {"predecessor": "issue-6", "dependent": "issue-7"},
                        {"predecessor": "issue-7", "dependent": "issue-8"},
                        {"predecessor": "issue-8", "dependent": "issue-9"},
                    ],
                },
                "index": [context] + reported_tasks,
            },
            "abcd": {
                "tracker": {
                    "url": contrasting_tracker_url, "id": 10042, "node_id": "I_kwDOtesttracker42",
                    "title": "Contrasting implementation tracker", "revision": "2026-09-24T20:00:00Z",
                    "body": (
                        "Context: design #90. Example/baseline PR: https://github.com/acme/app/pull/91.\n"
                        "Implementation index (the repeated and reordered references are intentional):\n"
                        "- #102: API\n- #104: phase delivery-b\n- #102: API again\n"
                        "- #101: foundation\n- #104: phase delivery-b again\n- #103: data\n"
                        "Phase delivery-b belongs to #104."
                    ),
                    "implementation_index": [task["url"] for task in (abcd_tasks[1], abcd_tasks[3], abcd_tasks[0], abcd_tasks[2])],
                    "dependency_index": [
                        {"predecessor": "task-a", "dependent": "task-c"},
                        {"predecessor": "task-b", "dependent": "task-d"},
                        {"predecessor": "task-c", "dependent": "task-d"},
                    ],
                },
                "index": [contrasting_context] + abcd_tasks,
            },
        }

    def tracker_snapshot(
        self, fixture: str = "reported", *, native: bool = False,
        revision: Optional[str] = None, body_suffix: str = "",
    ) -> Dict[str, Any]:
        """Assemble a model-resolved scope from recorded tracker and issue-index reads."""
        fixture_value = self.tracker_fixtures[fixture]
        tracker = self._read_pages("tracker", [[fixture_value["tracker"]]])[0]
        tracker["body"] += body_suffix
        if revision is not None:
            tracker["revision"] = revision
        issue_index = self._read_pages("tracker_issue_index", [fixture_value["index"]])
        by_url = {item["url"]: item for item in issue_index}
        selected = [by_url[url] for url in tracker["implementation_index"]]
        if native:
            self._read_pages("tracker_native_children", [selected])
            for task in selected:
                task["actual_parent"] = tracker["url"]
        tasks = []
        for task in selected:
            item = copy.deepcopy(task)
            if item["task_id"] in self.delivery:
                item["existing_delivery"] = copy.deepcopy(self.delivery[item["task_id"]])
            tasks.append(item)
        edges = [
            {**edge, "provenance": "declared",
             "evidence": {"tracker_url": tracker["url"], "field": "dependency index"}}
            for edge in fixture_value["tracker"]["dependency_index"]
        ]
        result = {
            "canonical_repo": self.canonical,
            "integration": copy.deepcopy(self.integration),
            "parent_prs": self.parent_pr_readbacks(),
            "repository_rules": self.repository_rules,
            "host": {"delivery_capable": True, "max_parallel": self.max_parallel},
            "tasks": tasks,
            "graph": {"edges": edges},
            "execution_layout": self.execution_layout(
                (item["task_id"] for item in tasks),
                (
                    {
                        "issue-3": None, "issue-4": None, "issue-5": "issue-3",
                        "issue-6": None, "issue-7": "issue-6", "issue-8": "issue-7",
                        "issue-9": "issue-8", "task-a": None, "task-b": None,
                        "task-c": "task-a",
                    }
                ),
                (
                    {"issue-6": "Issue 6 is a real technical join; use the approved merge checkpoint."}
                    if fixture == "reported" else
                    {"task-d": "All divergent prerequisite deliveries land in the approved base."}
                    if fixture == "abcd" else {}
                ),
            ),
            "issues": tasks,
            "selected_issues": tasks,
            "scope_evidence": {
                "tracker": {key: tracker[key] for key in ("url", "id", "node_id", "title", "body", "revision")},
                "membership": {
                    "source": "native" if native else "declared",
                    "issues": sorted(item["url"] for item in tasks),
                    "evidence": {
                        "tracker_url": tracker["url"],
                        "index_read": "complete",
                        "actual_parent_read": "complete" if native else "unavailable",
                        "implementation_markers": len(tasks),
                    },
                },
            },
            "recovery": {
                "checkpoints": [], "processes": [], "sessions": [], "worktrees": [],
                "refs": [], "prs": [], "contracts": [], "dependencies": [],
            },
        }
        record("github", "assemble-tracker-snapshot", {
            "tracker_url": tracker["url"], "revision": tracker["revision"],
            "source": result["scope_evidence"]["membership"]["source"],
            "issues": result["scope_evidence"]["membership"]["issues"],
        })
        return result

    def project_snapshot(self) -> Dict[str, Any]:
        project_url = "https://github.com/orgs/acme/projects/7"
        parent = copy.deepcopy(self.parent)
        container = copy.deepcopy(parent)
        container.update({
            "container": True,
            "task_id": "spec-p",
            "ordinal": 1,
            "item_id": "PVTI_project_item_p",
            "actual_parent": None,
            "declared_parent": None,
        })
        member = copy.deepcopy(self.children[0])
        member.update({
            "ordinal": 2,
            "item_id": "PVTI_project_item_a",
            "actual_parent": self.parent_url,
            "declared_parent": self.parent_url,
        })
        result = {
            "canonical_repo": self.canonical,
            "integration": copy.deepcopy(self.integration),
            "parent_prs": self.parent_pr_readbacks(),
            "repository_rules": self.repository_rules,
            "specification": self.specification,
            "host": {"delivery_capable": True, "max_parallel": self.max_parallel},
            "execution_layout": self.execution_layout(("task-a",), {"task-a": None}),
            "project": {
                "url": project_url,
                "number": 7,
                "node_id": "PVT_kwDOtestproject",
                "owner": "acme",
                "owner_type": "organization",
                "state": "open",
            },
            "lifecycle": {
                "planned": "Planned",
                "executing": "Executing",
                "blocked": "Blocked",
                "inReview": "In Review",
                "done": "Done",
            },
            "members": [container, member],
            "tasks": [member],
            "recovery": {
                "checkpoints": [],
                "processes": [],
                "sessions": [],
                "worktrees": [],
                "refs": [],
                "prs": [],
                "contracts": [],
                "dependencies": [],
            },
        }
        if "task-a" in self.delivery:
            result["members"][1]["existing_delivery"] = copy.deepcopy(self.delivery["task-a"])
        record("github", "assemble-project-snapshot", {"project": project_url, "members": 2})
        return result

    def save_pr(self, task_id: str, pr: Dict[str, Any]) -> None:
        with self._lock:
            self.prs[task_id] = copy.deepcopy(pr)
        record("github", "create-or-update-pr", {"task_id": task_id, "pr_url": pr["pr_url"]})

    def readback(self, task_id: str) -> Dict[str, Any]:
        with self._lock:
            pr = copy.deepcopy(self.prs[task_id])
        record("github", "read-pr-and-diff", {"task_id": task_id, "pr_url": pr["pr_url"]})
        return {
            "repo": self.canonical,
            "head_repo": self.canonical,
            "pr_url": pr["pr_url"],
            "branch": pr["branch"],
            "head_sha": pr["head_sha"],
            "base_branch": pr["base_branch"],
            "commit_sha": pr["commit_sha"],
            "association": pr["association"],
            "closing_references": [pr["association"]],
            "open": bool(pr["open"]),
            "unique": bool(pr["unique"]),
            "draft": bool(pr["draft"]),
            "reviews": {"head_sha": pr["head_sha"], "complete": True, "items": self._read_pages("reviews", [[]])},
            "threads": {"head_sha": pr["head_sha"], "complete": True, "items": self._read_pages("threads", [[]])},
            "diff_identity": pr["diff_identity"],
        }

    def note(self, task_id: str, result: Dict[str, Any]) -> Dict[str, Any]:
        pr = self.prs[task_id]
        contract = next(child["contract"] for child in self.children if child["task_id"] == task_id)
        note = {
            "id": "note-%s" % task_id,
            "issue_url": next(child["url"] for child in self.children if child["task_id"] == task_id),
            "pr_url": pr["pr_url"],
            "head_sha": pr["head_sha"],
            "contract_hash": contract_hash(contract),
            "diff_identity": pr["diff_identity"],
        }
        with self._lock:
            self.notes[task_id] = copy.deepcopy(note)
        record("github", "write-child-note", note)
        with self._lock:
            note = copy.deepcopy(self.notes[task_id])
        record("github", "read-child-note", note)
        return note

    def persist_delivery(self, task_id: str, result: Dict[str, Any], reservation: Dict[str, Any]) -> None:
        """Retain fresh delivery evidence after the helper acknowledges the persisted note."""

        note = copy.deepcopy(self.notes[task_id])
        with self._lock:
            if note != result["note"]:
                raise AssertionError("delivery differs from persisted note readback")
            self.delivery[task_id] = {
                "reservation": copy.deepcopy(reservation),
                "result": copy.deepcopy(result),
                "lifecycle": {
                    "pr": {
                        "pr_url": result["readback"]["pr_url"], "repo": self.canonical,
                        "head_repo": self.canonical, "branch": result["readback"]["branch"],
                        "head_sha": result["readback"]["head_sha"],
                        "base_branch": result["readback"]["base_branch"],
                        "state": "open", "draft": result["readback"]["draft"],
                    },
                    "source": {
                        "branch": result["readback"]["branch"],
                        "head_sha": result["readback"]["head_sha"],
                        "deleted": False,
                    },
                    "checks": {
                        "complete": True,
                        "state": "verified",
                        "head_sha": result["readback"]["head_sha"],
                    },
                },
            }
        record("github", "persist-child-delivery", {"task_id": task_id, "note_id": note["id"]})

    def ci_observation(
        self,
        task_id: str,
        *,
        check_state: str = "success",
        test_merge: bool = False,
        required: bool = True,
        diagnosis: str = "Fix the bounded product failure.",
        category: str = "actionable",
        log_accessible: bool = True,
        head_sha: Optional[str] = None,
        include_status: bool = True,
    ) -> Dict[str, Any]:
        """Assemble authoritative check/status/log reads for one retained PR."""
        with self._lock:
            pr = copy.deepcopy(self.prs[task_id])
        head_sha = head_sha or pr["head_sha"]
        target_sha = ("a" * 40) if test_merge else head_sha
        records = []
        kinds = ("check-run", "commit-status") if include_status else ("check-run",)
        for kind in kinds:
            record_value = {
                "id": "%s-%s" % (kind, task_id),
                "name": "required-ci",
                "source": "ci",
                "type": kind,
                "sha": target_sha,
                "attempt": 1,
                "state": check_state,
                "url": pr["pr_url"] + "/checks/required-ci",
            }
            if check_state in ("failure", "error", "timed_out", "cancelled", "action_required"):
                record_value.update({
                    "category": category,
                    "actionable": category == "actionable",
                    "diagnosis": diagnosis if category == "actionable" else "Host classified this as non-product.",
                    "log": {
                        "accessible": log_accessible,
                        "complete": True,
                        "excerpt": diagnosis if log_accessible else "",
                    },
                })
            records.append(record_value)
        observation = {
            "pr": {
                "url": pr["pr_url"],
                "repo": self.canonical,
                "head_repo": self.canonical,
                "state": "open" if pr["open"] else "closed",
                "branch": pr["branch"],
                "head_sha": pr["head_sha"],
                "test_merge_sha": target_sha if test_merge else None,
                "base_branch": pr["base_branch"],
                "base_sha": git(self.repo, "rev-parse", "refs/heads/" + pr["base_branch"]),
            },
            "checks": self._read_pages("ci-check-runs", [[records[0]]]) + (
                self._read_pages("ci-commit-statuses", [[records[1]]]) if include_status else []
            ),
            "required_checks": {"complete": True, "items": self._read_pages("ci-required", [[{
                "name": "required-ci",
                "source": "ci",
            }]])} if required else {"complete": True, "items": []},
            "pagination": {
                "check_runs": True,
                "commit_statuses": True,
                "required_checks": True,
                "logs": True,
            },
        }
        record("github", "assemble-ci-observation", {
            "task_id": task_id,
            "pr_url": pr["pr_url"],
            "head_sha": pr["head_sha"],
            "target_sha": target_sha,
            "check_state": check_state,
        })
        return observation

    def read_project_status(self, task_id: str) -> Dict[str, Any]:
        project_url = "https://github.com/orgs/acme/projects/7"
        issue_url = next(child["url"] for child in self.children if child["task_id"] == task_id)
        value = {
            "project_url": project_url,
            "issue_url": issue_url,
            "item_id": "PVTI_project_item_a",
            "status": "In Review",
        }
        self.project_status = copy.deepcopy(value)
        record("github", "write-project-status", value)
        value = copy.deepcopy(self.project_status)
        self.project_status_reads.append(copy.deepcopy(value))
        record("github", "read-project-status", value)
        return value


def verify_execute_readiness(repo: Path, packet: Dict[str, Any], entry: Dict[str, Any]) -> None:
    readiness = packet.get("parent_readiness")
    if not isinstance(readiness, dict) or readiness.get("external_prerequisites") != []:
        raise AssertionError("Execute requires complete caller-supplied parent readiness")
    logical = readiness.get("logical_prerequisites")
    effective = readiness.get("execution_prerequisites")
    base_satisfied = readiness.get("base_satisfied_prerequisites")
    records = readiness.get("prerequisites", [])
    if not isinstance(logical, list) or not isinstance(effective, list) \
            or not isinstance(base_satisfied, list) \
            or not set(logical).issubset(set(effective) | set(base_satisfied)) \
            or set(effective) & set(base_satisfied) \
            or sorted(row["task_id"] for row in records) != sorted(effective):
        raise AssertionError("Execute prerequisite checkpoint set is incomplete")
    parent = readiness["parent"]
    if parent["branch"] != entry["parent_branch"] or parent["sha"] != entry["parent_sha"]:
        raise AssertionError("Execute parent decision differs from reservation")
    if git(repo, "rev-parse", "refs/heads/" + parent["branch"]) != parent["current_sha"]:
        raise AssertionError("Execute parent head changed")
    git(repo, "merge-base", "--is-ancestor", parent["sha"], parent["current_sha"])
    evidence = parent["pr_evidence"]
    if evidence["complete"] is not True or evidence["head_sha"] != parent["current_sha"]:
        raise AssertionError("Execute parent PR discovery is incomplete")
    layout = next(row for row in packet["execution_layout"]["entries"]
                  if row["task_id"] == entry["task_id"])
    base_entries = layout["base_satisfied_prerequisites"]
    if sorted(row["task_id"] for row in base_entries) != sorted(base_satisfied):
        raise AssertionError("Execute landed-base evidence is incomplete")
    for row in base_entries:
        git(repo, "merge-base", "--is-ancestor", row["revision"], parent["sha"])
    for row in records:
        checkpoint = row["checkpoint"]
        pr = checkpoint["readback"]
        if checkpoint["checks"]["passed"] is not True or checkpoint["validation"]["verdict"] != "pass":
            raise AssertionError("Execute prerequisite is not independently verified")
        if checkpoint["note"]["head_sha"] != pr["head_sha"] or pr["open"] is not True:
            raise AssertionError("Execute prerequisite delivery note/PR is stale")
        satisfaction = row.get("satisfaction", {})
        if satisfaction.get("kind") == "merged":
            landed = satisfaction.get("revision")
            if not landed:
                raise AssertionError("Execute prerequisite landed revision is missing")
            git(repo, "merge-base", "--is-ancestor", landed, parent["sha"])
        else:
            if git(repo, "rev-parse", "refs/heads/" + pr["branch"]) != pr["head_sha"]:
                raise AssertionError("Execute prerequisite branch changed")
            git(repo, "merge-base", "--is-ancestor", pr["head_sha"], parent["sha"])
    for pr in [*(row["checkpoint"]["readback"] for row in records), *evidence["prs"]]:
        for key in ("reviews", "threads"):
            if pr[key]["complete"] is not True or pr[key]["head_sha"] != pr["head_sha"]:
                raise AssertionError("Execute current-head reviews/threads are incomplete")


class FakeHost:
    """Real threaded host primitive consuming helper dispatch packets."""

    def __init__(self, repo: Path, github: FakeGitHub, *, max_workers: int = 3, on_launch=None) -> None:
        self.repo = Path(repo)
        self.github = github
        self.executor = ThreadPoolExecutor(max_workers=max_workers)
        self.lock = threading.Lock()
        self.git_setup_lock = threading.Lock()
        self.started: Dict[str, threading.Event] = {}
        self.completed: Dict[str, threading.Event] = {}
        self.futures = {}
        self.reports: Dict[str, Dict[str, Any]] = {}
        self.active = 0
        self.max_active = 0
        self.b_hold = threading.Event()
        self.b_started = threading.Event()
        self.b_completed = threading.Event()
        self.c_started = threading.Event()
        self.wave_barrier = None
        self.use_wave_barrier = False
        self.consumed_packets = []
        self.on_launch = on_launch
        self.host_id = secrets.token_hex(16)
        self.identities = {}
        self.reservations = {}
        self.hold_before_pr = False
        self.before_pr = threading.Event()
        self.hold_before_mutation = False
        self.before_mutation = threading.Event()
        self.mutation_hold = threading.Event()

    def dispatch(self, entries: Sequence[Dict[str, Any]]) -> None:
        if not self.futures and {entry["task_id"] for entry in entries} == {
            "task-a", "task-b", "task-e"
        }:
            self.wave_barrier = threading.Barrier(3)
            self.use_wave_barrier = True
        for entry in entries:
            task_id = entry["task_id"]
            self.started.setdefault(task_id, threading.Event())
            self.completed.setdefault(task_id, threading.Event())
            self.identities[task_id] = {
                "host_id": self.host_id, "session_id": secrets.token_hex(16),
                "worker_id": "execute-%s-%s" % (task_id, secrets.token_hex(8)),
            }
            self.reservations[task_id] = {
                key: entry[key] for key in ("branch", "workspace", "parent_branch", "parent_sha",
                                           "task_url", "scope", "contract_hash")
            }
            record("host", "dispatch-worker", {
                "task_id": task_id,
                "workspace": entry.get("workspace"),
                "branch": entry.get("branch"),
                "parent_branch": entry.get("parent_branch"),
                "packet": entry.get("packet"),
            })
            self.futures[task_id] = self.executor.submit(
                self._execute_packet, copy.deepcopy(entry), copy.deepcopy(self.identities[task_id])
            )
            if self.on_launch:
                self.on_launch(entry, self.identities[task_id])


    def recovery_inventory(self) -> Dict[str, Any]:
        inventory = self.github.snapshot()["recovery"]
        inventory["sessions"] = [
            {"task_id": task_id, "worker": copy.deepcopy(self.identities[task_id]),
             "reservation": copy.deepcopy(self.reservations[task_id]),
             "status": "stopped" if future.done() else "running"}
            for task_id, future in self.futures.items()
        ]
        record("host", "read-worker-liveness", inventory["sessions"])
        return inventory

    def stopped_receipt(self, task_id: str, state: Path, inventory: Dict[str, Any]) -> Dict[str, Any]:
        if not self.futures[task_id].done():
            raise AssertionError("live host future cannot produce a stopped receipt")
        return {
            "worker": copy.deepcopy(self.identities[task_id]),
            "state_digest": hashlib.sha256(state.read_bytes()).hexdigest(),
            "inventory_digest": contract_hash(inventory),
        }

    def _execute_packet(self, entry: Dict[str, Any], identity: Dict[str, str]) -> Dict[str, Any]:
        task_id = entry["task_id"]
        packet = entry["packet"]
        # This assertion is intentionally about the consumer boundary, not
        # helper source text: a fake worker must receive the complete Execute
        # packet before it can touch Git.
        if packet.get("task_id") != task_id or packet.get("child_issue_url") != entry["child_url"]:
            raise AssertionError("worker received an incomplete Execute packet")
        bounded = packet.get("bounded_input")
        if not isinstance(bounded, dict) or not bounded.get("goal") \
                or bounded.get("acceptance") != packet.get("acceptance") \
                or bounded.get("checks") != packet.get("checks"):
            raise AssertionError("worker did not receive the complete Execute contract")
        if packet.get("execute_skill") != "woostack-execute":
            raise AssertionError("worker did not receive the Execute handoff")
        verify_execute_readiness(self.repo, packet, entry)
        self.consumed_packets.append(task_id)
        with self.lock:
            self.active += 1
            self.max_active = max(self.max_active, self.active)
        self.started[task_id].set()
        if task_id == "task-b":
            self.b_started.set()
        if task_id == "task-c":
            self.c_started.set()

        if self.hold_before_mutation:
            self.before_mutation.set()
            self.mutation_hold.wait()

        workspace = Path(entry["workspace"])
        branch = entry["branch"]
        parent_sha = entry["parent_sha"]
        repair = bool(entry.get("repair"))
        if repair:
            if not workspace.exists():
                proof = (packet.get("repair_evidence") or {}).get("workspace_reopen")
                if not isinstance(proof, dict) or proof.get("released") is not True:
                    raise AssertionError("repair workspace reopen was not authorized by host evidence")
                workspace.parent.mkdir(parents=True, exist_ok=True)
                proc = subprocess.run(
                    ["git", "-C", str(self.repo), "worktree", "add", str(workspace), branch],
                    capture_output=True, text=True,
                )
                if proc.returncode:
                    raise AssertionError("host repair worktree creation failed: %s" % proc.stderr.strip())
            current = git(workspace, "branch", "--show-current")
            if current != branch:
                raise AssertionError("repair changed its reserved branch")
        else:
            with self.git_setup_lock:
                workspace.parent.mkdir(parents=True, exist_ok=True)
                proc = subprocess.run(
                    ["git", "-C", str(self.repo), "worktree", "add", "-b", branch, str(workspace), parent_sha],
                    capture_output=True,
                    text=True,
                )
                if proc.returncode:
                    raise AssertionError("worker worktree creation failed: %s" % proc.stderr.strip())
        if self.use_wave_barrier and task_id in {"task-a", "task-b", "task-e"}:
            self.wave_barrier.wait(timeout=30)

        task_file = workspace / "src" / (task_id + ".txt")
        task_file.parent.mkdir(parents=True, exist_ok=True)
        repair_detail = ""
        if repair:
            failures = (packet.get("repair_evidence") or {}).get("failures") or [{}]
            repair_detail = " " + str(failures[0].get("diagnosis") or "bounded repair")
        with task_file.open("w", encoding="utf-8") as handle:
            handle.write("Execute consumed packet for %s%s%s\n" % (
                task_id, " repair" if repair else "", repair_detail
            ))
        run_verification(workspace, bounded)
        git(workspace, "add", str(task_file.relative_to(workspace)))
        if git(workspace, "diff", "--cached", "--name-only"):
            git(workspace, "commit", "-m", "Implement %s%s" % (task_id, " repair" if repair else ""))
        head_sha = git(workspace, "rev-parse", "HEAD")
        base_branch = entry["parent_branch"]
        parent_sha_for_diff = entry["parent_sha"]
        pr_url = entry.get("retained_pr") or "%s/pull/%d" % (self.github.canonical, 1000 + int(entry["ordinal"]))
        child_url = entry["child_url"]
        pr = {
            "pr_url": pr_url,
            "branch": branch,
            "head_sha": head_sha,
            "commit_sha": head_sha,
            "base_branch": base_branch,
            "association": child_url,
            "open": True,
            "unique": True,
            "draft": True,
            "diff_identity": diff_identity(self.repo, parent_sha_for_diff, head_sha),
        }
        if task_id == "task-b" and self.hold_before_pr and not repair:
            self.before_pr.set()
            self.b_hold.wait()
        self.github.save_pr(task_id, pr)
        report = {
            "outcome": "ok",
            "worker": {
                **identity,
                "pr_url": pr_url,
                "branch": branch,
                "workspace": str(workspace.resolve()),
                "head_sha": head_sha,
                "base_branch": base_branch,
                "commit_sha": head_sha,
                "association": child_url,
            },
        }
        report["parent_sha"] = parent_sha
        if task_id == "task-b" and not repair:
            self.b_hold.wait(timeout=30)
        with self.lock:
            self.reports[task_id] = copy.deepcopy(report)
            self.active -= 1
        self.completed[task_id].set()
        if task_id == "task-b":
            self.b_completed.set()
        return report

    def wait_for_report(self, task_id: str, timeout: float = 30) -> Dict[str, Any]:
        future = self.futures[task_id]
        report = future.result(timeout=timeout)
        return copy.deepcopy(report)

    def release_b(self) -> None:
        self.b_hold.set()

    def shutdown(self) -> None:
        self.release_b()
        self.mutation_hold.set()
        self.executor.shutdown(wait=True)


def make_result(github: FakeGitHub, task_id: str, report: Dict[str, Any], admitted: Dict[str, Any]) -> Dict[str, Any]:
    """Assemble independent readback/check/validation evidence for apply-result."""

    record("github", "assemble-apply-evidence", {"task_id": task_id})
    readback = github.readback(task_id)
    task = next(item for item in admitted["tasks"] if item["task_id"] == task_id)
    contract = task["contract"]
    workspace = (github.repo / task["workspace"]).resolve()
    run_verification(workspace, contract)
    changed = set(git(github.repo, "diff", "--name-only", report["parent_sha"], readback["head_sha"]).splitlines())
    content = git(workspace, "show", readback["head_sha"] + ":src/" + task_id + ".txt")
    if changed != set(contract["scope"]) or task_id not in content:
        raise AssertionError("independent specification validation failed")
    record("validator", "review-submitted-diff", {
        "task_id": task_id, "head_sha": readback["head_sha"],
        "contract_hash": contract_hash(contract), "diff_identity": readback["diff_identity"],
    })
    result = {
        "outcome": "ok",
        "worker": copy.deepcopy(report["worker"]),
        "readback": readback,
        "checks": {
            "passed": True,
            "commands": list(contract["checks"]),
            "head_sha": readback["head_sha"],
            "diff_identity": readback["diff_identity"],
            "smoke": contract["smoke"],
        },
        "validation": {
            "verdict": "pass",
            "reviewer_id": "reviewer-%s" % task_id,
            "diff_identity": readback["diff_identity"],
            "contract_hash": contract_hash(contract),
            "checked_head": readback["head_sha"],
        },
        "note": github.note(task_id, result={}),
    }
    if admitted.get("project") is not None:
        # The controller writes the status and independently reads it back
        # before invoking apply-result.  The helper only gates this receipt.
        result["project_status"] = github.read_project_status(task_id)
    return result


def main(argv: Sequence[str]) -> int:
    if not argv:
        print("usage: recording_driver.py <helper args>", file=sys.stderr)
        return 2
    command = argv[0]
    if command == "admit":
        record("github", "read-snapshot", {"args": list(argv[1:])})
    elif command == "apply-result":
        record("github", "read-pr-and-diff", {"args": list(argv[1:])})
    elif command == "reconcile":
        record("github", "reconcile-pr", {"args": list(argv[1:])})
    proc = subprocess.run([sys.executable, str(HELPER), *argv], capture_output=True, text=True)
    if proc.stdout:
        try:
            parsed = json.loads(proc.stdout)
        except json.JSONDecodeError:
            parsed = {"raw": proc.stdout}
        if command == "schedule" and isinstance(parsed, dict):
            for entry in parsed.get("dispatch", []):
                record("controller", "reserve-worker", {
                    "task_id": entry.get("task_id"),
                    "workspace": entry.get("workspace"),
                    "branch": entry.get("branch"),
                    "parent_branch": entry.get("parent_branch"),
                    "packet": entry.get("packet"),
                })
        sys.stdout.write(proc.stdout)
    if proc.stderr:
        sys.stderr.write(proc.stderr)
    return proc.returncode


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
