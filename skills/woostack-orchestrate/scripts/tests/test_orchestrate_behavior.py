#!/usr/bin/env python3
"""Behavioral tests for the shipped woostack-orchestrate helper.

Every controller operation crosses the recording driver's subprocess boundary
and therefore exercises scripts/orchestrate.py, not a test scheduler.  The
fake transports only assemble paginated native reads, consume emitted Execute
packets, and provide independent Git/GitHub evidence.
"""

from __future__ import annotations

import copy
import hashlib
import json
import importlib.util
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Any, Dict, Optional, Sequence, Tuple

from recording_driver import (
    FakeGitHub,
    FakeHost,
    contract_hash,
    diff_identity,
    git,
    invoke_cli,
    make_result,
)

FAULT_RUNNER = '''"""Run the shipped helper with one deterministic interruption installed.

The behavioral suite crosses a real subprocess boundary for every controller
operation; this wrapper keeps that property while killing the helper process at
an exact durability point instead of a timing-dependent one.
"""
import importlib.util
import os
import sys

spec = importlib.util.spec_from_file_location("orchestrate_fault", sys.argv[1])
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)
fault, helper_args = sys.argv[2], sys.argv[3:]


def die(*args, **kwargs):
    raise SystemExit(97)


if fault == "die-before-state-publication":
    helper.write_state = die
elif fault == "die-before-claim":
    helper.claim_scope = die
elif fault == "die-before-claim-publication":
    original_link = os.link

    def die_before_link(source, target, **kwargs):
        if str(target).endswith(".json"):
            die()
        return original_link(source, target, **kwargs)

    helper.os.link = die_before_link
elif fault == "die-after-claim-publication":
    original_fsync_parent = helper._fsync_parent

    def die_after_fsync(path):
        original_fsync_parent(path)
        if path.parent.name == "orchestrate-claims" and path.name.endswith(".json"):
            die()

    helper._fsync_parent = die_after_fsync
else:
    raise SystemExit("unknown fault: " + fault)
sys.argv = ["orchestrate.py", *helper_args]
raise SystemExit(helper.main())
'''


class OrchestrateBehavior(unittest.TestCase):
    maxDiff = None

    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp(prefix="woostack-orchestrate-behavior-"))
        self.repo = self.tmp / "repo"
        self.repo.mkdir()
        self._run(["git", "init", "-q", "-b", "main", str(self.repo)])
        git(self.repo, "config", "user.email", "orchestrate-tests@example.invalid")
        git(self.repo, "config", "user.name", "Orchestrate behavioral tests")
        (self.repo / "README").write_text("base\n", encoding="utf-8")
        git(self.repo, "add", "README")
        git(self.repo, "commit", "-m", "base")
        git(self.repo, "remote", "add", "origin", "https://github.com/acme/app.git")
        self.base_sha = git(self.repo, "rev-parse", "HEAD")
        self.github = FakeGitHub(self.repo, self.base_sha)
        self.transport_log = self.tmp / "transport.jsonl"
        self.old_transport_log = os.environ.get("WOOSTACK_ORCHESTRATE_TRANSPORT_LOG")
        os.environ["WOOSTACK_ORCHESTRATE_TRANSPORT_LOG"] = str(self.transport_log)
        self.hosts = []
        self.launch_context = {}

    def tearDown(self) -> None:
        for host in self.hosts:
            host.shutdown()
        if self.old_transport_log is None:
            os.environ.pop("WOOSTACK_ORCHESTRATE_TRANSPORT_LOG", None)
        else:
            os.environ["WOOSTACK_ORCHESTRATE_TRANSPORT_LOG"] = self.old_transport_log
        shutil.rmtree(self.tmp, ignore_errors=True)

    @staticmethod
    def _run(command: Sequence[str], *, cwd: Optional[Path] = None) -> str:
        proc = subprocess.run(command, cwd=str(cwd) if cwd else None, capture_output=True, text=True)
        if proc.returncode:
            raise AssertionError("command failed: %s\n%s" % (" ".join(command), proc.stderr))
        return proc.stdout.strip()

    def _write_json(self, name: str, payload: Dict[str, Any]) -> Path:
        path = self.tmp / name
        path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        return path

    def _admit_issue(self, snapshot: Optional[Dict[str, Any]] = None, *, max_parallel: Optional[str] = None) -> Tuple[Path, Dict[str, Any]]:
        snapshot_path = self._write_json("snapshot-%d.json" % len(list(self.tmp.glob("snapshot-*.json"))), snapshot or self.github.snapshot())
        args = ["admit", "--snapshot", str(snapshot_path)]
        if max_parallel is not None:
            args += ["--max-parallel", max_parallel]
        code, payload = invoke_cli(*args)
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload.get("status"), "admitted", payload)
        admitted_path = self._write_json("admitted-%d.json" % len(list(self.tmp.glob("admitted-*.json"))), payload)
        return admitted_path, payload

    def _admit_issues(
        self,
        snapshot: Optional[Dict[str, Any]] = None,
        *,
        selectors: Optional[Sequence[str]] = None,
        max_parallel: Optional[str] = None,
    ) -> Tuple[Path, Dict[str, Any]]:
        snapshot = snapshot or self.github.issue_list_snapshot()
        selected = list(selectors or [item["url"] for item in snapshot["issues"]])
        snapshot_path = self._write_json(
            "issue-list-snapshot-%d.json" % len(list(self.tmp.glob("issue-list-snapshot-*.json"))),
            snapshot,
        )
        args = ["admit", "--snapshot", str(snapshot_path)]
        if max_parallel is not None:
            args += ["--max-parallel", max_parallel]
        code, payload = invoke_cli(*args)
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload.get("status"), "admitted", payload)
        admitted_path = self._write_json(
            "issue-list-admitted-%d.json" % len(list(self.tmp.glob("issue-list-admitted-*.json"))),
            payload,
        )
        return admitted_path, payload

    def _admit_project(self, snapshot: Optional[Dict[str, Any]] = None) -> Tuple[Path, Dict[str, Any]]:
        project_url = "https://github.com/orgs/acme/projects/7"
        snapshot_path = self._write_json("project-snapshot.json", snapshot or self.github.project_snapshot())
        code, payload = invoke_cli("admit", "--snapshot", str(snapshot_path))
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload.get("status"), "admitted", payload)
        admitted_path = self._write_json("project-admitted.json", payload)
        return admitted_path, payload

    def _schedule(
        self,
        admitted_path: Path,
        admitted: Dict[str, Any],
        state: Optional[Path],
        snapshot: Dict[str, Any],
        name: str,
        *,
        cap: Optional[str] = None,
        decision: Optional[Path] = None,
    ) -> Tuple[Path, Dict[str, Any]]:
        fresh_path = self._write_json(name + "-fresh.json", snapshot)
        state_out = self.tmp / (name + "-state.json")
        args = [
            "schedule",
            "--admitted",
            str(admitted_path),
            "--state-out",
            str(state_out),
            "--git-repo",
            str(self.repo),
            "--fresh",
            str(fresh_path),
        ]
        if state is not None:
            args += ["--state", str(state)]
        if cap is not None:
            args += ["--cap", cap]
        if decision is not None:
            args += ["--parent-decision", str(decision)]
        code, payload = invoke_cli(*args)
        self.assertEqual(code, 0, payload)
        for entry in payload.get("dispatch", []):
            self.launch_context[entry["branch"]] = (admitted_path, state_out)
        return state_out, payload

    def _apply(
        self,
        admitted_path: Path,
        state: Path,
        task_id: str,
        result: Dict[str, Any],
        name: str,
        *,
        expect_code: Optional[int] = 0,
    ) -> Tuple[Path, Dict[str, Any], int]:
        result_path = self._write_json(name + "-result.json", result)
        state_out = self.tmp / (name + "-state.json")
        code, payload = invoke_cli(
            "apply-result",
            "--admitted",
            str(admitted_path),
            "--state",
            str(state),
            "--state-out",
            str(state_out),
            "--git-repo",
            str(self.repo),
            "--task",
            task_id,
            "--result",
            str(result_path),
        )
        if expect_code is not None:
            self.assertEqual(code, expect_code, payload)
        return state_out, payload, code
    def _stop(
        self,
        admitted_path: Path,
        state: Path,
        name: str,
        *,
        reason: str = "operator-stop",
    ) -> Tuple[Path, Dict[str, Any]]:
        state_out = self.tmp / (name + "-state.json")
        code, payload = invoke_cli(
            "stop",
            "--admitted",
            str(admitted_path),
            "--state",
            str(state),
            "--state-out",
            str(state_out),
            "--git-repo",
            str(self.repo),
            "--reason",
            reason,
        )
        self.assertEqual(code, 0, payload)
        return state_out, payload



    def _reservation(self, dispatch: Dict[str, Any]) -> Dict[str, Any]:
        return {
            key: dispatch[key]
            for key in ("branch", "workspace", "parent_branch", "parent_sha",
                        "task_url", "scope", "contract_hash")
        }

    def _persist(self, task_id: str, result: Dict[str, Any], dispatch: Dict[str, Any]) -> None:
        self.github.persist_delivery(task_id, result, self._reservation(dispatch))

    def _single_task_snapshot(self, task_id: str = "task-a") -> Dict[str, Any]:
        snapshot = self.github.snapshot()
        child = next(item for item in snapshot["children"] if item["task_id"] == task_id)
        snapshot["tasks"] = snapshot["children"] = [child]
        return snapshot

    def _two_task_snapshot(self) -> Dict[str, Any]:
        snapshot = self.github.snapshot()
        snapshot["tasks"] = snapshot["children"] = [
            item for item in snapshot["children"] if item["task_id"] in {"task-a", "task-b"}
        ]
        return snapshot



    def _start_host(self, workers: int = 3) -> FakeHost:
        host = FakeHost(self.repo, self.github, max_workers=workers, on_launch=self._record_launch)
        self.hosts.append(host)
        return host

    def _record_launch(self, entry, worker) -> None:
        admitted_path, state = self.launch_context[entry["branch"]]
        receipt = self._write_json("launch-" + worker["worker_id"] + ".json", {
            "worker": worker, "reservation": self._reservation(entry),
            "state_digest": hashlib.sha256(state.read_bytes()).hexdigest(),
        })
        code, payload = invoke_cli(
            "record-worker", "--admitted", str(admitted_path), "--state", str(state),
            "--state-out", str(state), "--git-repo", str(self.repo),
            "--task", entry["task_id"], "--evidence", str(receipt),
        )
        self.assertEqual(code, 0, payload)

    def _stop_receipt(self, host, task_id, state):
        return host.stopped_receipt(task_id, state, host.recovery_inventory())

    def _seed_prior_delivery(self, task_id: str, parent_branch: str = "main", parent_sha: Optional[str] = None) -> Dict[str, Any]:
        """Create actual historical PR bytes, without declaring their current readiness."""
        parent_sha = parent_sha or self.base_sha
        task = next(child for child in self.github.children if child["task_id"] == task_id)
        worktree = Path(task["workspace"])
        worktree.parent.mkdir(parents=True, exist_ok=True)
        branch = task["branch"]
        git(self.repo, "worktree", "add", "-b", branch, str(worktree), parent_sha)
        (worktree / "src").mkdir(exist_ok=True)
        (worktree / "src" / (task_id + ".txt")).write_text("Historical delivery for " + task_id + "\n")
        git(worktree, "add", "src/" + task_id + ".txt")
        git(worktree, "commit", "-m", "Prior " + task_id)
        head = git(worktree, "rev-parse", "HEAD")
        pr = {
            "pr_url": self.github.canonical + "/pull/" + str(1000 + task["ordinal"]),
            "branch": branch, "head_sha": head, "commit_sha": head, "base_branch": parent_branch,
            "association": task["url"], "open": True, "unique": True, "draft": True,
            "diff_identity": diff_identity(worktree, parent_sha, head),
        }
        self.github.save_pr(task_id, pr)
        worker = {key: pr[key] for key in ("pr_url", "branch", "head_sha", "commit_sha", "base_branch", "association")}
        worker["worker_id"] = "prior-execute-" + task_id
        worker["workspace"] = str(worktree.resolve())
        result = make_result(self.github, task_id, {"worker": worker, "parent_sha": parent_sha}, {
            "tasks": [{**task, "workspace": str(worktree.resolve()), "branch": branch}],
        })
        retained = {"reservation": {"branch": branch, "workspace": str(worktree.resolve()),
                                   "parent_branch": parent_branch, "parent_sha": parent_sha},
                    "result": result}
        self.github.delivery[task_id] = copy.deepcopy(retained)
        return retained

    def test_full_issue_smoke_uses_real_git_and_concurrent_execute_packets(self) -> None:
        """A/B/E are concurrent; C stacks on A; D pauses then uses explicit join."""

        admitted_path, admitted = self._admit_issue()
        initial_state, initial = self._schedule(
            admitted_path, admitted, None, self.github.snapshot(), "initial", cap="3"
        )
        self.assertEqual(
            sorted(item["task_id"] for item in initial["dispatch"]),
            ["task-a", "task-b", "task-e"],
        )
        self.assertNotIn(self.github.parent_url, [item["child_url"] for item in initial["dispatch"]])
        first_entry = next(item for item in initial["dispatch"] if item["task_id"] == "task-a")
        self.assertEqual(first_entry["branch"], "feature/task-a")
        self.assertTrue(Path(first_entry["workspace"]).is_absolute())
        self.assertNotIn(".woostack", Path(first_entry["workspace"]).parts)
        self.assertFalse(Path(first_entry["workspace"]).exists())

        host = self._start_host()
        host.dispatch(initial["dispatch"])
        for task_id in ("task-a", "task-b", "task-e"):
            self.assertTrue(host.started[task_id].wait(30), task_id)
        self.assertTrue(host.b_started.is_set())
        self.assertEqual(host.max_active, 3)

        report_a = host.wait_for_report("task-a")
        result_a = make_result(self.github, "task-a", report_a, admitted)
        state_a, applied_a, _ = self._apply(admitted_path, initial_state, "task-a", result_a, "a")
        self.assertEqual(applied_a.get("status"), "delivered", applied_a)
        self._persist("task-a", result_a, initial["dispatch"][0])

        report_e = host.wait_for_report("task-e")
        e_entry = next(item for item in initial["dispatch"] if item["task_id"] == "task-e")
        result_e = make_result(self.github, "task-e", report_e, admitted)
        state_e, applied_e, _ = self._apply(admitted_path, state_a, "task-e", result_e, "e")
        self.assertEqual(applied_e.get("status"), "delivered", applied_e)
        self._persist("task-e", result_e, e_entry)

        refill_c_state, refill_c = self._schedule(
            admitted_path, admitted, state_e, self.github.snapshot(), "after-a-e"
        )
        c_entries = [item for item in refill_c["dispatch"] if item["task_id"] == "task-c"]
        self.assertEqual(len(c_entries), 1, refill_c)
        c_entry = c_entries[0]
        self.assertEqual(c_entry["parent_branch"], self.github.children[0]["branch"])
        self.assertEqual(c_entry["parent_sha"], report_a["worker"]["head_sha"])
        self.assertEqual(c_entry["packet"]["parent_readiness"]["logical_prerequisites"], ["task-a"])
        self.assertEqual(c_entry["packet"]["parent_readiness"]["prerequisites"][0]["checkpoint"]["note"]["head_sha"],
                         report_a["worker"]["head_sha"])
        self.assertEqual(
            c_entry["packet"]["bounded_input"],
            next(item["contract"] for item in admitted["tasks"] if item["task_id"] == "task-c"),
        )
        self.assertEqual(c_entry["packet"]["child_issue_url"], self.github.children[2]["url"])
        self.assertEqual(c_entry["packet"]["scope_url"], self.github.children[2]["url"])
        self.assertEqual(c_entry["packet"]["execute_skill"], "woostack-execute")
        self.assertNotEqual(c_entry["packet"]["child_issue_url"], self.github.parent_url)
        self.assertTrue(c_entry["packet"]["acceptance"])
        self.assertTrue(c_entry["packet"]["checks"])
        self.assertTrue(any(item["task_id"] == "task-d" for item in refill_c["waiting"]))

        host.dispatch([c_entry])
        self.assertTrue(host.c_started.wait(30))
        self.assertFalse(host.b_completed.is_set(), "C must start while B remains held")
        report_c = host.wait_for_report("task-c")
        result_c = make_result(self.github, "task-c", report_c, admitted)
        state_c, applied_c, _ = self._apply(admitted_path, refill_c_state, "task-c", result_c, "c")
        self.assertEqual(applied_c.get("status"), "delivered", applied_c)
        self._persist("task-c", result_c, c_entry)

        host.release_b()
        report_b = host.wait_for_report("task-b")
        b_entry = next(item for item in initial["dispatch"] if item["task_id"] == "task-b")
        result_b = make_result(self.github, "task-b", report_b, admitted)
        state_b, applied_b, _ = self._apply(admitted_path, state_c, "task-b", result_b, "b")
        self.assertEqual(applied_b.get("status"), "delivered", applied_b)
        self._persist("task-b", result_b, b_entry)
        self.assertTrue(host.b_completed.is_set())

        paused_state, paused = self._schedule(
            admitted_path, admitted, state_b, self.github.snapshot(), "before-join"
        )
        self.assertEqual(paused["dispatch"], [], paused)
        paused_d = next(item for item in paused["paused"] if item["task_id"] == "task-d")
        self.assertEqual(paused_d["reason"], "join-no-containing-parent")
        self.assertEqual(sorted(paused_d["prerequisite_branches"]),
                         [self.github.children[0]["branch"], self.github.children[1]["branch"]])

        # A join branch is a user-selected parent decision.  The helper must
        # never create it automatically.
        git(self.repo, "checkout", "-q", "-b", "join-ab", self.base_sha)
        self._run(["git", "-C", str(self.repo), "merge", "--no-ff",
                   self.github.children[0]["branch"], "-m", "join A"])
        self._run(["git", "-C", str(self.repo), "merge", "--no-ff",
                   self.github.children[1]["branch"], "-m", "join B"])
        join_sha = git(self.repo, "rev-parse", "HEAD")
        git(self.repo, "checkout", "-q", "main")
        self.github.parent_branches.add("join-ab")
        decision = self._write_json("join-decision.json", {
            "decisions": [{"task_id": "task-d", "branch": "join-ab", "sha": join_sha}]
        })
        state_d, resumed = self._schedule(
            admitted_path,
            admitted,
            paused_state,
            self.github.snapshot(),
            "after-join",
            decision=decision,
        )
        d_entries = [item for item in resumed["dispatch"] if item["task_id"] == "task-d"]
        self.assertEqual(len(d_entries), 1, resumed)
        self.assertEqual(d_entries[0]["parent_branch"], "join-ab")
        self.assertEqual(d_entries[0]["parent_sha"], join_sha)
        self.assertEqual(d_entries[0]["packet"]["parent_readiness"]["logical_prerequisites"], ["task-a", "task-b"])

        host.dispatch(d_entries)
        report_d = host.wait_for_report("task-d")
        result_d = make_result(self.github, "task-d", report_d, admitted)
        state_final, applied_d, _ = self._apply(admitted_path, state_d, "task-d", result_d, "d")
        self.assertEqual(applied_d.get("status"), "delivered", applied_d)
        self._persist("task-d", result_d, d_entries[0])
        self.assertNotIn("spec-p", host.consumed_packets)
        self.assertNotIn(self.github.parent_url, [pr["association"] for pr in self.github.prs.values()])
        self.assertEqual(sorted(json.loads(state_final.read_text())["tasks"].keys()), [
            "task-a", "task-b", "task-c", "task-d", "task-e"
        ])
        self.assertEqual(host.max_active, 3)
        log = [json.loads(line) for line in self.transport_log.read_text().splitlines()]
        review_a = next(i for i, item in enumerate(log) if item["operation"] == "review-submitted-diff" and item["payload"]["task_id"] == "task-a")
        write_a = next(i for i, item in enumerate(log) if item["operation"] == "write-child-note" and item["payload"]["issue_url"].endswith("/101"))
        read_a = next(i for i, item in enumerate(log) if item["operation"] == "read-child-note" and item["payload"]["issue_url"].endswith("/101"))
        dispatch_c = next(i for i, item in enumerate(log) if item["operation"] == "dispatch-worker" and item["payload"]["task_id"] == "task-c")
        self.assertLess(review_a, write_a)
        self.assertLess(write_a, read_a)
        self.assertLess(read_a, dispatch_c)
        self.assertFalse(self.github.project_status_reads)
        self.assertIn(("sub_issues", 1), self.github.calls)
        self.assertIn(("sub_issues", 2), self.github.calls)
        self.assertIn(("dependencies", 2), self.github.calls)

    def test_issue_list_reuses_resolved_task_identity_and_graph(self) -> None:
        snapshot = self.github.issue_list_snapshot()
        admitted_path, admitted = self._admit_issues(snapshot)
        self.assertEqual(admitted["scope_identity"]["issues"],
                         sorted(item["url"] for item in snapshot["tasks"]))
        self.assertEqual(
            [(edge["predecessor"], edge["dependent"], edge["provenance"])
             for edge in admitted["edge_provenance"]],
            [("task-a", "task-c", "inferred"), ("task-b", "task-d", "inferred"),
             ("task-c", "task-d", "inferred")],
        )

        missing_template_fields = copy.deepcopy(snapshot)
        brief = missing_template_fields["tasks"][0]["contract"]
        for field in ("non_goals", "decisions", "risks"):
            brief.pop(field)
        _, resolved = self._admit_issues(missing_template_fields)
        self.assertEqual(resolved["tasks"][0]["contract"], brief)

        contradictory = copy.deepcopy(snapshot)
        contradictory["graph"]["edges"].append({
            "predecessor": "task-a", "dependent": "task-c",
            "provenance": "declared", "evidence": {"reason": "contradictory duplicate"},
        })
        code, payload = invoke_cli("admit", "--snapshot",
                                   str(self._write_json("contradictory.json", contradictory)))
        self.assertNotEqual(code, 0, payload)
        self.assertEqual(payload["error"], "duplicate-edge")

    def test_declared_tracker_fixture_dispatches_exact_reported_issue_set(self) -> None:
        snapshot = self.github.tracker_snapshot("reported")
        admitted_path, admitted = self._admit_issues(snapshot)
        self.assertEqual([task["url"] for task in admitted["tasks"]],
                         [self.github.canonical + "/issues/" + str(number) for number in range(3, 10)])
        self.assertEqual([task["task_id"] for task in admitted["tasks"]],
                         ["issue-%d" % number for number in range(3, 10)])
        self.assertTrue(all("actual_parent" not in task for task in admitted["tasks"]))
        self.assertEqual(admitted["scope_evidence"]["membership"]["source"], "declared")
        self.assertEqual(admitted["scope_evidence"]["membership"]["evidence"]["actual_parent_read"], "unavailable")
        self.assertIn("Phase #9-A", admitted["tasks"][-1]["body"])
        self.assertIn(("tracker", 1), self.github.calls)
        self.assertIn(("tracker_issue_index", 1), self.github.calls)
        self.assertNotIn(("tracker_native_children", 1), self.github.calls)

        state, scheduled = self._schedule(admitted_path, admitted, None, snapshot, "tracker-root", cap="2")
        self.assertEqual([entry["task_id"] for entry in scheduled["dispatch"]], ["issue-3", "issue-4"])
        packet = scheduled["dispatch"][0]["packet"]
        self.assertEqual(packet["scope_evidence"], admitted["scope_evidence"])
        self.assertNotIn("parent_issue_url", packet)
        self.assertEqual(packet["parent_issue_read"], "unavailable")
        saved = json.loads(state.read_text())
        self.assertEqual(saved["scope_evidence"], admitted["scope_evidence"])
        self.assertNotIn("actual_parent", saved["recovery"]["last_snapshot"]["membership"][0])
        self.assertEqual(saved["recovery"]["last_snapshot"]["scope_evidence"], admitted["scope_evidence"])
        writes = [json.loads(line) for line in self.transport_log.read_text().splitlines()
                  if json.loads(line)["operation"].startswith("write-")]
        self.assertFalse(writes, writes)

    def test_partial_native_parent_read_preserves_per_task_packet_evidence(self) -> None:
        snapshot = self.github.tracker_snapshot("reported")
        tracker_url = snapshot["scope_evidence"]["tracker"]["url"]
        snapshot["tasks"][0]["actual_parent"] = tracker_url
        admitted_path, admitted = self._admit_issues(snapshot)
        _, scheduled = self._schedule(admitted_path, admitted, None, snapshot, "tracker-partial", cap="2")
        packets = {entry["task_id"]: entry["packet"] for entry in scheduled["dispatch"]}
        self.assertEqual(packets["issue-3"]["parent_issue_url"], tracker_url)
        self.assertEqual(packets["issue-3"]["parent_issue_read"], "complete")
        self.assertNotIn("parent_issue_url", packets["issue-4"])
        self.assertEqual(packets["issue-4"]["parent_issue_read"], "unavailable")

    def test_tracker_identity_allows_metadata_transition_but_rejects_scope_drift(self) -> None:
        snapshot = self.github.tracker_snapshot("reported")
        admitted_path, admitted = self._admit_issues(snapshot)
        _, native = self._admit_issues(self.github.tracker_snapshot("reported", native=True))
        self.assertEqual(admitted["fingerprint"], native["fingerprint"])
        self.assertEqual(native["scope_evidence"]["membership"]["source"], "native")
        self.assertTrue(all(task["actual_parent"] == self.github.canonical + "/issues/15"
                            for task in native["tasks"]))

        reordered = self.github.tracker_snapshot("reported", native=True, revision="2026-09-23T21:00:00Z")
        reordered["scope_evidence"]["membership"]["issues"].reverse()
        reordered["scope_evidence"]["tracker"]["body"] = (
            "Context: design #2. Baseline: PR #1. Implementation index:\n"
            "- #9: phase #9-A and phase #9-B\n- #8: integration\n- #7: UI\n"
            "- #6: service\n- #5: data\n- #4: API\n- #3: foundation\n"
            "Issue #9 has phases #9-A and #9-B."
        )
        _, equivalent = self._admit_issues(reordered)
        self.assertEqual(admitted["fingerprint"], equivalent["fingerprint"])
        state, resumed = self._schedule(
            admitted_path, admitted, None, reordered, "tracker-native-resume", cap="1",
        )
        self.assertEqual(resumed["status"], "ok", resumed)
        saved = json.loads(state.read_text())
        self.assertEqual(saved["scope_evidence"]["membership"]["source"], "native")
        self.assertEqual(saved["scope_evidence"]["tracker"]["revision"], "2026-09-23T21:00:00Z")

        drift = self.github.tracker_snapshot("reported", body_suffix=" The acceptance policy changed.")
        _, changed = self._schedule(admitted_path, admitted, state, drift, "tracker-semantic-drift")
        self.assertEqual(changed["status"], "snapshot-drift", changed)
        redirected = self.github.tracker_snapshot("reported")
        redirected["scope_evidence"]["tracker"]["body"] = redirected["scope_evidence"]["tracker"]["body"].replace(
            "Context: design #2", "Context: design #3"
        )
        _, changed_context = self._admit_issues(redirected)
        self.assertNotEqual(admitted["fingerprint"], changed_context["fingerprint"])

    def test_tracker_receipt_rejects_membership_ambiguity_foreign_and_fabrication(self) -> None:
        snapshot = self.github.tracker_snapshot("reported")
        cases = []
        mismatch = copy.deepcopy(snapshot)
        mismatch["scope_evidence"]["membership"]["issues"].append(self.github.canonical + "/issues/2")
        cases.append(("membership", mismatch, "scope-membership-mismatch"))
        ambiguous = copy.deepcopy(snapshot)
        ambiguous["scope_evidence"]["membership"]["issues"].append(snapshot["tasks"][0]["url"])
        cases.append(("ambiguous", ambiguous, "ambiguous-scope"))
        foreign = copy.deepcopy(snapshot)
        foreign["scope_evidence"]["tracker"]["url"] = "https://github.com/other/app/issues/15"
        cases.append(("foreign", foreign, "foreign-repository"))
        unverified_native = copy.deepcopy(snapshot)
        unverified_native["scope_evidence"]["membership"]["source"] = "native"
        cases.append(("fabricated native", unverified_native, "native-membership-unverified"))
        fabricated = copy.deepcopy(snapshot)
        fabricated["scope_evidence"]["membership"]["evidence"] = {}
        cases.append(("fabricated evidence", fabricated, "invalid-scope-evidence"))
        asserted = copy.deepcopy(snapshot)
        asserted["scope_evidence"]["membership"]["evidence"] = True
        cases.append(("asserted evidence", asserted, "invalid-scope-evidence"))
        blank = copy.deepcopy(snapshot)
        blank["scope_evidence"]["membership"]["evidence"] = "  "
        cases.append(("blank evidence", blank, "invalid-scope-evidence"))
        for label, invalid, expected in cases:
            with self.subTest(label=label):
                code, payload = invoke_cli(
                    "admit", "--snapshot",
                    str(self._write_json("invalid-scope-" + label.replace(" ", "-") + ".json", invalid)),
                )
                self.assertNotEqual(code, 0, payload)
                self.assertEqual(payload["error"], expected, payload)

    def test_declared_tracker_partial_join_uses_same_scheduler(self) -> None:
        snapshot = self.github.tracker_snapshot("abcd")
        admitted_path, admitted = self._admit_issues(snapshot)
        state, initial = self._schedule(admitted_path, admitted, None, snapshot, "tracker-abcd", cap="2")
        self.assertEqual([entry["task_id"] for entry in initial["dispatch"]], ["task-a", "task-b"])
        host = self._start_host(workers=2)
        host.dispatch(initial["dispatch"])
        self.assertTrue(host.b_started.wait(30))
        report_a = host.wait_for_report("task-a")
        result_a = make_result(self.github, "task-a", report_a, admitted)
        state, applied_a, _ = self._apply(admitted_path, state, "task-a", result_a, "tracker-abcd-a")
        self.assertEqual(applied_a["status"], "delivered")
        self._persist("task-a", result_a, initial["dispatch"][0])
        state, after_a = self._schedule(
            admitted_path, admitted, state, self.github.tracker_snapshot("abcd"), "tracker-abcd-c", cap="2",
        )
        self.assertEqual([entry["task_id"] for entry in after_a["dispatch"]], ["task-c"])
        c_entry = after_a["dispatch"][0]
        host.dispatch([c_entry])
        self.assertTrue(host.c_started.wait(30))
        report_c = host.wait_for_report("task-c")
        result_c = make_result(self.github, "task-c", report_c, admitted)
        state, applied_c, _ = self._apply(admitted_path, state, "task-c", result_c, "tracker-abcd-c-result")
        self.assertEqual(applied_c["status"], "delivered")
        self._persist("task-c", result_c, c_entry)
        self.assertFalse(host.b_completed.is_set())
        host.release_b()
        report_b = host.wait_for_report("task-b")
        result_b = make_result(self.github, "task-b", report_b, admitted)
        state, applied_b, _ = self._apply(admitted_path, state, "task-b", result_b, "tracker-abcd-b")
        self.assertEqual(applied_b["status"], "delivered")
        self._persist("task-b", result_b, initial["dispatch"][1])
        _, paused = self._schedule(
            admitted_path, admitted, state, self.github.tracker_snapshot("abcd"), "tracker-abcd-d",
        )
        self.assertEqual([item for item in paused["paused"] if item["task_id"] == "task-d"], [{
            "task_id": "task-d", "reason": "join-no-containing-parent",
            "prerequisite_branches": ["feature/task-b", "feature/task-c"],
        }])

    def test_declared_tracker_recovery_preserves_scope_provenance(self) -> None:
        snapshot = self.github.tracker_snapshot("reported")
        admitted_path, admitted = self._admit_issues(snapshot)
        fresh_path = self._write_json("tracker-recovery-fresh.json", snapshot)
        state_out = self.tmp / "tracker-recovery-state.json"
        args = self._first_schedule_args(admitted_path, fresh_path, state_out, self.repo) + ["--cap", "1"]
        self._interrupted_schedule("die-before-state-publication", args)
        code, resumed = invoke_cli(*args)
        self.assertEqual(code, 0, resumed)
        state = json.loads(state_out.read_text())
        self.assertEqual(state["scope_evidence"], admitted["scope_evidence"])
        self.assertEqual(state["recovery"]["last_snapshot"]["scope_evidence"], admitted["scope_evidence"])
        self.assertEqual([entry["task_id"] for entry in resumed["dispatch"]], ["issue-3"])

        native_path, native = self._admit_issues(self.github.tracker_snapshot("reported", native=True))
        self.assertEqual(native["fingerprint"], admitted["fingerprint"])
        native_state, unchanged = self._schedule(
            native_path, native, state_out, self.github.tracker_snapshot("reported", native=True),
            "tracker-recovery-native", cap="1",
        )
        self.assertEqual(unchanged["dispatch"], [])
        saved = json.loads(native_state.read_text())
        self.assertEqual(saved["scope_evidence"]["membership"]["source"], "native")
        self.assertEqual(saved["tasks"]["issue-3"]["status"], "running")

        semantic = self.github.tracker_snapshot("reported", native=True, body_suffix=" Changed policy.")
        _, drift = self._schedule(native_path, native, native_state, semantic, "tracker-recovery-drift")
        self.assertEqual(drift["status"], "snapshot-drift", drift)
        self.assertEqual(drift["dispatch"], [], drift)

    def test_issue_list_external_blocker_stays_outside_scope(self) -> None:
        snapshot = self.github.issue_list_snapshot()
        issue = next(item for item in snapshot["issues"] if item["task_id"] == "task-a")
        issue["external_prerequisites"] = [self.github.canonical + "/issues/999"]
        issue["prerequisites"] = []
        admitted_path, admitted = self._admit_issues(snapshot)
        state, scheduled = self._schedule(admitted_path, admitted, None, snapshot, "issue-list-external")
        self.assertNotIn("task-a", [entry["task_id"] for entry in scheduled["dispatch"]])
        self.assertIn({"task_id": "task-a", "reason": "external-prerequisite"}, scheduled["blocked"])
        self.assertNotIn("issue-999", [task["task_id"] for task in admitted["tasks"]])
        self.assertTrue(state.exists())

    def test_serial_host_blocks_external_prerequisites_without_expanding_scope(self) -> None:
        snapshot = self.github.snapshot()
        snapshot["host"]["max_parallel"] = 1
        snapshot["children"][0]["external_prerequisites"] = [self.github.canonical + "/issues/999"]
        admitted_path, admitted = self._admit_issue(snapshot)
        state, scheduled = self._schedule(admitted_path, admitted, None, snapshot, "serial-external")
        self.assertEqual([entry["task_id"] for entry in scheduled["dispatch"]], ["task-b"])
        self.assertIn({"task_id": "task-a", "reason": "external-prerequisite"}, scheduled["blocked"])
        self.assertEqual(scheduled["effective_cap"], 1)
        self.assertTrue(scheduled["notice"])
        _, still_running = self._schedule(admitted_path, admitted, state, snapshot, "serial-held")
        self.assertEqual(still_running["dispatch"], [])
        self.assertEqual(still_running["running"], ["task-b"])

    def test_resolved_graph_rejects_cycles_foreign_identity_and_unsafe_recovery(self) -> None:
        base = self.github.snapshot()
        cases = []
        foreign = copy.deepcopy(base)
        foreign["tasks"][0]["url"] = "https://github.com/elsewhere/app/issues/101"
        cases.append(("foreign repository", foreign, "foreign-repository"))
        cycle = copy.deepcopy(base)
        cycle["tasks"][0]["prerequisites"] = ["task-b"]
        cycle["tasks"][1]["prerequisites"] = ["task-a"]
        cases.append(("dependency cycle", cycle, "cycle"))
        unknown = copy.deepcopy(base)
        unknown["tasks"][2]["prerequisites"] = ["task-z"]
        cases.append(("unknown dependency", unknown, "missing-endpoint"))
        incomplete = copy.deepcopy(base)
        incomplete["tasks"][0]["contract"].pop("acceptance")
        cases.append(("unresolved acceptance", incomplete, "incomplete-task"))
        unavailable = copy.deepcopy(base)
        unavailable["host"]["delivery_capable"] = False
        cases.append(("no worker", unavailable, "no-subagent-capability"))
        recovery = copy.deepcopy(base)
        recovery["recovery"] = {"worktrees": []}
        cases.append(("unsafe recovery", recovery, "incomplete-recovery"))
        for label, snapshot, expected in cases:
            with self.subTest(label=label):
                code, payload = invoke_cli(
                    "admit", "--snapshot",
                    str(self._write_json("invalid-%s.json" % label.replace(" ", "-"), snapshot)),
                )
                self.assertNotEqual(code, 0, payload)
                self.assertEqual(payload["error"], expected, payload)
                if expected == "cycle":
                    self.assertIn("task-a", payload["message"])
                    self.assertIn("task-b", payload["message"])

        empty = copy.deepcopy(base)
        empty["tasks"] = []
        code, payload = invoke_cli("admit", "--snapshot",
                                   str(self._write_json("resolved-empty.json", empty)))
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload["status"], "no-work")

        for limit in ("0", "1.5"):
            code, payload = invoke_cli("admit", "--snapshot",
                                       str(self._write_json("bad-limit-%s.json" % limit, base)),
                                       "--max-parallel", limit)
            self.assertNotEqual(code, 0, payload)

    def test_reordered_tasks_and_missing_native_dependency_metadata_remain_admissible(self) -> None:
        base = self.github.snapshot()
        _, admitted = self._admit_issue(base)
        reordered = copy.deepcopy(base)
        reordered["tasks"].reverse()
        _, reordered_admitted = self._admit_issue(reordered)
        self.assertEqual(admitted["fingerprint"], reordered_admitted["fingerprint"])

        project = self.github.project_snapshot()
        project["tasks"][0].pop("external_prerequisites")
        project["tasks"][0].pop("prerequisites")
        _, from_project = self._admit_project(project)
        self.assertEqual(from_project["tasks"][0]["prerequisites"], [])

    def test_fingerprint_binds_resolved_scope_graph_and_contract_not_runtime_allocation(self) -> None:
        snapshot = self.github.snapshot()
        admitted_path, admitted = self._admit_issue(snapshot)
        state, initial = self._schedule(admitted_path, admitted, None, snapshot, "fingerprint-base", cap="3")
        self.assertTrue(initial["dispatch"], initial)

        host_cap_only = copy.deepcopy(snapshot)
        host_cap_only["host"]["max_parallel"] = 1
        state, unchanged = self._schedule(
            admitted_path, admitted, state, host_cap_only, "fingerprint-host-cap"
        )
        self.assertEqual(unchanged["status"], "ok", unchanged)
        self.assertEqual(unchanged["dispatch"], [], unchanged)
        self.assertTrue(state.exists())

        # Runtime allocation is not fingerprint-bound: workspace/branch changes
        # must schedule cleanly while immutable scope facts drift below. This
        # has to run before the drift cases, which deliberately halt the state.
        changed_workspace = copy.deepcopy(snapshot)
        changed_workspace["children"][0]["workspace"] = str(self.repo.parent / "agent-selected" / "task-a")
        changed_workspace["children"][0]["branch"] = "agent/task-a"
        state, allocation_changed = self._schedule(
            admitted_path, admitted, state, changed_workspace, "runtime-allocation-change"
        )
        self.assertEqual(allocation_changed.get("status"), "ok", allocation_changed)

        git(self.repo, "commit", "--allow-empty", "-m", "mutable integration tip")
        mutable_tip = git(self.repo, "rev-parse", "HEAD")
        mutable_sha = copy.deepcopy(snapshot)
        mutable_sha["integration"]["sha"] = mutable_tip
        state, mutable = self._schedule(admitted_path, admitted, state, mutable_sha, "fingerprint-sha")
        self.assertEqual(mutable["status"], "snapshot-drift", mutable)
        self.assertEqual(mutable["reason"], "parent-tip-drift", mutable)
        self.assertEqual(mutable["dispatch"], [], mutable)

        drift_cases = []
        added_child = copy.deepcopy(snapshot)
        child = copy.deepcopy(added_child["children"][0])
        child.update(task_id="task-z", ordinal=6, url=self.github.canonical + "/issues/999",
                     id=999, node_id="I_new_child")
        added_child["tasks"].append(child)
        drift_cases.append(("new executable task", added_child))
        changed_scope = copy.deepcopy(snapshot)
        changed_scope["tasks"][0]["contract"]["acceptance"].append("New observable requirement")
        drift_cases.append(("task acceptance", changed_scope))
        changed_rules = copy.deepcopy(snapshot)
        changed_rules["repository_rules"] += " amended"
        drift_cases.append(("repository rules", changed_rules))
        changed_child = copy.deepcopy(snapshot)
        changed_child["children"][0]["node_id"] = "I_kwDOchangedchild"
        drift_cases.append(("native child identity", changed_child))
        changed_graph = copy.deepcopy(snapshot)
        changed_graph["tasks"][1]["prerequisites"] = ["task-a"]
        drift_cases.append(("resolved graph", changed_graph))
        for label, fresh in drift_cases:
            with self.subTest(label=label):
                state, payload = self._schedule(admitted_path, admitted, state, fresh, "drift-" + label.replace(" ", "-"))
                self.assertEqual(payload.get("status"), "snapshot-drift", payload)
                self.assertEqual(payload.get("dispatch"), [], payload)

    def test_refill_rejects_changed_dispatch_context_before_dispatch(self) -> None:
        snapshot = self.github.snapshot()
        admitted_path, admitted = self._admit_issue(snapshot)
        state = None

        changed_specification = copy.deepcopy(snapshot)
        changed_specification["tasks"][0]["specification"] = "Updated task specification"
        changed_parent = copy.deepcopy(snapshot)
        changed_parent["tasks"][0]["actual_parent"] = self.github.canonical + "/issues/200"
        changed_evidence = copy.deepcopy(snapshot)
        changed_evidence["tasks"][2]["declared_edges"] = [{
            "predecessor": "task-a", "dependent": "task-c", "provenance": "declared",
            "evidence": {"review": "updated"},
        }]

        for label, fresh in (
            ("specification", changed_specification),
            ("actual parent", changed_parent),
            ("edge evidence", changed_evidence),
        ):
            with self.subTest(label=label):
                state, payload = self._schedule(
                    admitted_path, admitted, state, fresh, "dispatch-context-" + label.replace(" ", "-"),
                )
                self.assertEqual("snapshot-drift", payload.get("status"), payload)
                self.assertEqual("snapshot-drift", payload.get("reason"), payload)
                self.assertEqual([], payload.get("dispatch"), payload)

    def test_runtime_branch_collision_blocks_duplicate_reservations(self) -> None:
        snapshot = self.github.snapshot()
        snapshot["tasks"] = snapshot["children"] = snapshot["children"][:2]
        shared_branch = "review/custom-shared"
        for child in snapshot["children"]:
            child["branch"] = shared_branch
        admitted_path, admitted = self._admit_issue(snapshot)
        _, output = self._schedule(admitted_path, admitted, None, snapshot, "branch-reservation", cap="2")
        self.assertEqual([entry["task_id"] for entry in output["dispatch"]], ["task-a"], output)
        self.assertEqual(
            [{"task_id": "task-b", "reason": "branch-reservation-collision"}],
            [item for item in output["blocked"] if item["task_id"] == "task-b"],
        )

    def test_fresh_reuse_blocks_unowned_dirty_existing_worktree(self) -> None:
        snapshot = self._single_task_snapshot()
        task = snapshot["children"][0]
        workspace = self.tmp / "existing-dirty"
        branch = "host/reused-dirty"
        git(self.repo, "worktree", "add", "-q", "-b", branch, str(workspace), self.base_sha)
        task["workspace"] = str(workspace)
        task["branch"] = branch
        (workspace / "staged.txt").write_text("staged user state\n", encoding="utf-8")
        git(workspace, "add", "staged.txt")
        (workspace / "dirty.txt").write_text("uncommitted user state\n", encoding="utf-8")
        staged_bytes = (workspace / "staged.txt").read_bytes()
        dirty_bytes = (workspace / "dirty.txt").read_bytes()

        admitted_path, admitted = self._admit_issue(snapshot)
        _, output = self._schedule(admitted_path, admitted, None, snapshot, "fresh-dirty", cap="1")

        self.assertEqual(output["dispatch"], [], output)
        self.assertEqual(
            [{"task_id": "task-a", "reason": "workspace-unclaimed"}],
            [item for item in output["blocked"] if item["task_id"] == "task-a"],
        )
        self.assertEqual((workspace / "staged.txt").read_bytes(), staged_bytes)
        self.assertEqual((workspace / "dirty.txt").read_bytes(), dirty_bytes)

    def test_fresh_reuse_blocks_unowned_committed_existing_branch(self) -> None:
        snapshot = self._single_task_snapshot()
        task = snapshot["children"][0]
        workspace = self.tmp / "existing-committed"
        branch = "host/reused-committed"
        git(self.repo, "worktree", "add", "-q", "-b", branch, str(workspace), self.base_sha)
        task["workspace"] = str(workspace)
        task["branch"] = branch
        (workspace / "unrelated.txt").write_text("unrelated user commit\n", encoding="utf-8")
        git(workspace, "add", "unrelated.txt")
        git(workspace, "commit", "-m", "Unrelated retained work")
        retained_head = git(workspace, "rev-parse", "HEAD")
        retained_bytes = (workspace / "unrelated.txt").read_bytes()

        admitted_path, admitted = self._admit_issue(snapshot)
        _, output = self._schedule(admitted_path, admitted, None, snapshot, "fresh-committed", cap="1")

        self.assertEqual(output["dispatch"], [], output)
        self.assertEqual(
            [{"task_id": "task-a", "reason": "workspace-unclaimed"}],
            [item for item in output["blocked"] if item["task_id"] == "task-a"],
        )
        self.assertEqual(git(workspace, "rev-parse", "HEAD"), retained_head)
        self.assertEqual((workspace / "unrelated.txt").read_bytes(), retained_bytes)


    def test_runtime_rejects_unlinked_clone_even_with_matching_remote_and_branch(self) -> None:
        clone = self.tmp / "external-clone"
        self._run(["git", "clone", "-q", str(self.repo), str(clone)])
        git(clone, "remote", "set-url", "origin", self.github.canonical + ".git")
        git(clone, "switch", "-q", "-c", "external/task-a")
        snapshot = self._single_task_snapshot()
        snapshot["children"][0]["workspace"] = str(clone)
        snapshot["children"][0]["branch"] = "external/task-a"
        admitted_path, admitted = self._admit_issue(snapshot)
        _, output = self._schedule(admitted_path, admitted, None, snapshot, "unlinked-clone", cap="1")
        self.assertEqual(output["dispatch"], [], output)
        self.assertEqual(
            [{"task_id": "task-a", "reason": "workspace-not-linked"}],
            [item for item in output["blocked"] if item["task_id"] == "task-a"],
        )

    def test_checkpoint_cas_rejects_stale_writer_without_overwriting_evidence(self) -> None:
        snapshot = self._single_task_snapshot()
        admitted_path, admitted = self._admit_issue(snapshot)
        state, scheduled = self._schedule(
            admitted_path, admitted, None, snapshot, "cas-initial", cap="1"
        )
        self.assertTrue(scheduled["dispatch"], scheduled)

        helper_path = Path(__file__).resolve().parents[1] / "orchestrate.py"
        spec = importlib.util.spec_from_file_location("orchestrate_cas", helper_path)
        self.assertIsNotNone(spec)
        self.assertIsNotNone(spec.loader)
        helper = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(helper)
        loaded = helper.state_read(str(state), admitted)
        stale = helper.state_read(str(state), admitted)
        loaded["stop_requested"] = True
        loaded["halt_new_dispatch"] = True
        args = type("StateArgs", (), {
            "state": str(state),
            "state_out": str(self.tmp / "cas-first-state.json"),
            "git_repo": str(self.repo),
        })()
        helper.write_state(args, loaded)
        stale_args = type("StateArgs", (), {
            "state": str(state),
            "state_out": str(self.tmp / "cas-stale-state.json"),
            "git_repo": str(self.repo),
        })()
        with self.assertRaises(helper.InputError) as raised:
            helper.write_state(stale_args, stale)
        self.assertEqual(raised.exception.code, "stale-state")
        self.assertTrue(Path(args.state_out).exists())
        self.assertFalse(Path(stale_args.state_out).exists())

    def test_same_path_checkpoint_recovery_preserves_generation_and_cas(self) -> None:
        snapshot = self._single_task_snapshot()
        admitted_path, admitted = self._admit_issue(snapshot)
        state, scheduled = self._schedule(
            admitted_path, admitted, None, snapshot, "same-path-initial", cap="1"
        )
        self.assertTrue(scheduled["dispatch"], scheduled)

        helper_path = Path(__file__).resolve().parents[1] / "orchestrate.py"
        spec = importlib.util.spec_from_file_location("orchestrate_same_path", helper_path)
        self.assertIsNotNone(spec)
        self.assertIsNotNone(spec.loader)
        helper = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(helper)
        args = type("StateArgs", (), {
            "state": str(state),
            "state_out": str(state),
            "git_repo": str(self.repo),
        })()
        loaded = helper.state_read(str(state), admitted)
        stale = helper.state_read(str(state), admitted)
        _, head_path = helper._checkpoint_paths(args, loaded)
        pending_path = helper._checkpoint_pending_path(head_path)
        old_head = helper._checkpoint_head(head_path)
        original_write_json = helper.write_json

        def fail_after_state(path, value):
            original_write_json(path, value)
            if Path(path).resolve() == state.resolve():
                raise RuntimeError("fault after same-path state publication")

        helper.write_json = fail_after_state
        loaded["stop_requested"] = True
        with self.assertRaises(RuntimeError):
            helper.write_state(args, loaded)
        self.assertTrue(pending_path.exists())
        self.assertEqual(helper._checkpoint_head(head_path), old_head)
        current = helper.state_read(str(state), admitted)
        self.assertTrue(current["stop_requested"])

        with self.assertRaises(helper.InputError) as raised:
            helper.write_state(args, stale)
        self.assertEqual(raised.exception.code, "stale-state")
        self.assertTrue(pending_path.exists())
        helper.write_json = original_write_json
        helper.write_state(args, current)
        self.assertFalse(pending_path.exists())
        self.assertEqual(
            helper._checkpoint_head(head_path)["digest"],
            helper._state_digest(state),
        )

        def fail_after_head(path, value):
            original_write_json(path, value)
            if Path(path).resolve() == head_path.resolve():
                raise RuntimeError("fault after same-path head publication")

        helper.write_json = fail_after_head
        next_state = helper.state_read(str(state), admitted)
        next_state["halt_new_dispatch"] = True
        with self.assertRaises(RuntimeError):
            helper.write_state(args, next_state)
        self.assertTrue(pending_path.exists())
        helper.write_json = original_write_json
        helper.write_state(args, helper.state_read(str(state), admitted))
        self.assertFalse(pending_path.exists())
        self.assertTrue(helper.state_read(str(state), admitted)["halt_new_dispatch"])

    def _interrupted_schedule(self, fault: str, schedule_args: Sequence[str]) -> None:
        """Run one real first-schedule attempt that dies at an exact durability point."""
        runner = self.tmp / "fault-runner.py"
        runner.write_text(FAULT_RUNNER, encoding="utf-8")
        helper_path = Path(__file__).resolve().parents[1] / "orchestrate.py"
        proc = subprocess.run(
            [sys.executable, str(runner), str(helper_path), fault, *schedule_args],
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(proc.returncode, 0, proc)
        self.assertEqual(proc.stdout, "", "interruption must precede any command result")

    def _scope_claims(self) -> list:
        root = self.repo / ".woostack" / "tmp" / "orchestrate-claims"
        if not root.exists():
            return []
        records = [
            json.loads(path.read_text(encoding="utf-8"))
            for path in sorted(root.glob("*.json"))
        ]
        return [record for record in records if record["kind"] == "scope"]

    @staticmethod
    def _first_schedule_args(
        admitted_path: Path, fresh_path: Path, state_out: Path, git_repo: Path
    ) -> list:
        return [
            "schedule",
            "--admitted", str(admitted_path),
            "--state-out", str(state_out),
            "--git-repo", str(git_repo),
            "--fresh", str(fresh_path),
        ]

    def test_interruption_before_durable_state_leaves_a_retry_that_recovers(self) -> None:
        """A kill before state publication may never strand an unrecoverable scope claim."""
        snapshot = self._single_task_snapshot()
        admitted_path, _ = self._admit_issue(snapshot)
        fresh_path = self._write_json("interrupt-before-state-fresh.json", snapshot)
        state_out = self.tmp / "interrupt-before-state.json"
        args = self._first_schedule_args(admitted_path, fresh_path, state_out, self.repo)
        self._interrupted_schedule("die-before-state-publication", args)

        code, payload = invoke_cli(*args)
        self.assertEqual(code, 0, payload)
        self.assertTrue(payload.get("dispatch"), payload)
        state = json.loads(state_out.read_text(encoding="utf-8"))
        claims = self._scope_claims()
        self.assertEqual(len(claims), 1, claims)
        self.assertEqual(claims[0]["owner"], state["owner"]["controller_id"])

    def test_initial_state_precedes_the_claim_and_a_claim_gap_resumes_with_state(self) -> None:
        """The owner-bearing state is durable before the claim, so a --state resume reclaims it."""
        snapshot = self._single_task_snapshot()
        admitted_path, _ = self._admit_issue(snapshot)
        fresh_path = self._write_json("interrupt-before-claim-fresh.json", snapshot)
        state_out = self.tmp / "interrupt-before-claim.json"
        args = self._first_schedule_args(admitted_path, fresh_path, state_out, self.repo)
        self._interrupted_schedule("die-before-claim", args)

        self.assertTrue(
            state_out.exists(),
            "owner-bearing initial state must be durable before the claim is attempted",
        )
        state = json.loads(state_out.read_text(encoding="utf-8"))
        self.assertEqual(self._scope_claims(), [], "claim must never precede state publication")

        blocked_code, blocked = invoke_cli(*args)
        self.assertNotEqual(blocked_code, 0, blocked)
        self.assertEqual(blocked.get("error"), "existing-state", blocked)

        code, payload = invoke_cli(*args, "--state", str(state_out))
        self.assertEqual(code, 0, payload)
        self.assertTrue(payload.get("dispatch"), payload)
        claims = self._scope_claims()
        self.assertEqual(len(claims), 1, claims)
        self.assertEqual(claims[0]["owner"], state["owner"]["controller_id"])

    def test_claim_publication_failure_leaves_no_final_claim_and_resumes(self) -> None:
        """Failure before final-path publication leaves only resumable owner state."""
        snapshot = self._single_task_snapshot()
        admitted_path, _ = self._admit_issue(snapshot)
        fresh_path = self._write_json("interrupt-before-claim-publication-fresh.json", snapshot)
        state_out = self.tmp / "interrupt-before-claim-publication.json"
        args = self._first_schedule_args(admitted_path, fresh_path, state_out, self.repo)
        self._interrupted_schedule("die-before-claim-publication", args)

        state = json.loads(state_out.read_text(encoding="utf-8"))
        self.assertEqual(self._scope_claims(), [])
        code, payload = invoke_cli(*args, "--state", str(state_out))
        self.assertEqual(code, 0, payload)
        self.assertTrue(payload.get("dispatch"), payload)
        claims = self._scope_claims()
        self.assertEqual(len(claims), 1, claims)
        self.assertEqual(claims[0]["owner"], state["owner"]["controller_id"])

    def test_claim_publication_failure_leaves_complete_owner_claim_and_resumes(self) -> None:
        """Failure after final-path publication leaves a complete same-owner claim."""
        snapshot = self._single_task_snapshot()
        admitted_path, _ = self._admit_issue(snapshot)
        fresh_path = self._write_json("interrupt-after-claim-publication-fresh.json", snapshot)
        state_out = self.tmp / "interrupt-after-claim-publication.json"
        args = self._first_schedule_args(admitted_path, fresh_path, state_out, self.repo)
        self._interrupted_schedule("die-after-claim-publication", args)

        state = json.loads(state_out.read_text(encoding="utf-8"))
        claims = self._scope_claims()
        self.assertEqual(len(claims), 1, claims)
        self.assertEqual(claims[0]["owner"], state["owner"]["controller_id"])
        code, payload = invoke_cli(*args, "--state", str(state_out))
        self.assertEqual(code, 0, payload)
        self.assertTrue(payload.get("dispatch"), payload)
    def test_state_symlink_is_rejected_before_read_or_write(self) -> None:
        snapshot = self._single_task_snapshot()
        admitted_path, admitted = self._admit_issue(snapshot)
        state, scheduled = self._schedule(
            admitted_path, admitted, None, snapshot, "symlink-initial", cap="1"
        )
        self.assertTrue(scheduled["dispatch"], scheduled)
        symlink = self.tmp / "state-link.json"
        symlink.symlink_to(state)
        result_path = self._write_json("symlink-result.json", {})
        code, payload = invoke_cli(
            "apply-result",
            "--admitted",
            str(admitted_path),
            "--state",
            str(symlink),
            "--state-out",
            str(self.tmp / "symlink-state.json"),
            "--git-repo",
            str(self.repo),
            "--task",
            "task-a",
            "--result",
            str(result_path),
        )
        self.assertNotEqual(code, 0, payload)
        self.assertEqual(payload.get("error"), "unsafe-state", payload)
        self.assertFalse((self.tmp / "symlink-state.json").exists())

    def test_unknown_and_malformed_results_isolate_tasks_and_keep_reservations(self) -> None:
        snapshot = self._two_task_snapshot()
        admitted_path, admitted = self._admit_issue(snapshot)
        state, scheduled = self._schedule(admitted_path, admitted, None, snapshot, "unknown-initial", cap="1")
        dispatch = scheduled["dispatch"][0]
        self.assertEqual(dispatch["task_id"], "task-a")
        reservation = self._reservation(dispatch)
        host = self._start_host()
        host.dispatch([dispatch])
        report = host.wait_for_report("task-a")
        unknown_state, unknown_output, _ = self._apply(
            admitted_path,
            state,
            "task-a",
            {"outcome": "unknown", "worker": report["worker"]},
            "unknown",
        )
        self.assertEqual(unknown_output.get("status"), "unknown", unknown_output)
        unknown_saved = json.loads(unknown_state.read_text())
        self.assertEqual(unknown_saved["tasks"]["task-a"]["status"], "unknown")
        self.assertEqual(unknown_saved["tasks"]["task-a"]["reservation"], reservation)
        resumed_state, resumed = self._schedule(
            admitted_path, admitted, unknown_state, snapshot, "unknown-isolated", cap="1"
        )
        self.assertEqual(resumed["status"], "ok", resumed)
        self.assertEqual(resumed["dispatch"], [], resumed)
        self.assertEqual(resumed["unknown"], ["task-a"], resumed)
        spare_state, spare = self._schedule(
            admitted_path, admitted, resumed_state, snapshot, "unknown-spare-capacity", cap="2"
        )
        self.assertEqual([item["task_id"] for item in spare["dispatch"]], ["task-b"], spare)
        self.assertTrue(spare_state.exists())
        host.dispatch(spare["dispatch"])
        self.assertTrue(host.b_started.wait(30))
        observed_worker = copy.deepcopy(host.identities["task-b"])

        malformed_state, malformed, _ = self._apply(
            admitted_path,
            spare_state,
            "task-b",
            {"outcome": "ok", "worker": observed_worker},
            "malformed",
        )
        self.assertEqual(malformed.get("status"), "unknown", malformed)
        malformed_saved = json.loads(malformed_state.read_text())
        self.assertEqual(malformed_saved["tasks"]["task-b"]["status"], "unknown")
        blocked_state, blocked = self._schedule(
            admitted_path, admitted, malformed_state, snapshot, "malformed-isolated", cap="1"
        )
        self.assertEqual(blocked["status"], "ok", blocked)
        self.assertEqual(blocked["dispatch"], [], blocked)
        self.assertEqual(blocked["unknown"], ["task-a", "task-b"], blocked)
        self.assertTrue(blocked_state.exists())

    def test_live_worker_cannot_be_taken_over_after_timeout(self) -> None:
        snapshot = self._single_task_snapshot("task-b")
        admitted_path, admitted = self._admit_issue(snapshot)
        state, scheduled = self._schedule(
            admitted_path, admitted, None, snapshot, "live-initial", cap="1"
        )
        host = self._start_host(workers=1)
        host.dispatch(scheduled["dispatch"])
        self.assertTrue(host.b_started.wait(30))
        self.assertFalse(host.futures["task-b"].done())
        observed_worker = copy.deepcopy(host.identities["task-b"])
        unknown_state, unknown, _ = self._apply(
            admitted_path, state, "task-b",
            {"outcome": "unknown", "worker": observed_worker}, "live-timeout"
        )
        self.assertEqual(unknown["status"], "unknown", unknown)
        _, rejected, code = self._reconcile(
            admitted_path, unknown_state, "task-b", {"worker_stopped": False}, "live-reconcile"
        )
        self.assertNotEqual(code, 0, rejected)
        self.assertEqual(rejected["error"], "worker-liveness", rejected)
        _, resumed = self._schedule(
            admitted_path, admitted, unknown_state, snapshot, "live-resume", cap="1"
        )
        self.assertEqual(resumed["dispatch"], [], resumed)
        self.assertEqual(resumed["unknown"], ["task-b"], resumed)
        self.assertFalse(host.futures["task-b"].done())

    def test_live_no_pr_writer_rejects_unbound_stale_foreign_and_contradictory_stop(self) -> None:
        snapshot = self._single_task_snapshot("task-b")
        admitted_path, admitted = self._admit_issue(snapshot)
        state, scheduled = self._schedule(
            admitted_path, admitted, None, snapshot, "positive-live-initial", cap="1"
        )
        entry = scheduled["dispatch"][0]
        host = self._start_host(workers=1)
        host.hold_before_pr = True
        host.dispatch([entry])
        self.assertTrue(host.before_pr.wait(30))
        self.assertNotIn("task-b", self.github.prs)
        self.assertFalse(host.futures["task-b"].done())
        observed_worker = copy.deepcopy(host.identities["task-b"])
        state, unknown, _ = self._apply(
            admitted_path, state, "task-b",
            {"outcome": "unknown", "worker": observed_worker}, "positive-live-timeout"
        )
        self.assertEqual(unknown["status"], "unknown")
        original = state.read_bytes()
        inventory = host.recovery_inventory()
        stop = {
            "worker": copy.deepcopy(host.identities["task-b"]),
            "state_digest": hashlib.sha256(original).hexdigest(),
            "inventory_digest": contract_hash(inventory),
        }
        canonical = {
            "repo": self.github.canonical, "head_repo": self.github.canonical,
            "branch": entry["branch"], "base_branch": entry["parent_branch"],
            "head_sha": git(Path(entry["workspace"]), "rev-parse", "HEAD"),
            "workspace": entry["workspace"], "unique": True,
            "pr_absent": True, "pr_url": None, "open": False,
        }
        variants = {
            "bare-positive": {"worker_stopped": True},
            "stale-checkpoint": {"worker_stop": {**stop, "state_digest": "0" * 64}},
            "stale-inventory": {"worker_stop": {**stop, "inventory_digest": "sha256:" + "0" * 64}},
            "foreign-worker": {"worker_stop": {**stop, "worker": {**stop["worker"], "worker_id": "other"}}},
            "foreign-session": {"worker_stop": {**stop, "worker": {**stop["worker"], "session_id": "other"}}},
            "foreign-host": {"worker_stop": {**stop, "worker": {**stop["worker"], "host_id": "other"}}},
            "current-but-live": {"worker_stop": stop},
        }
        for label, positive in variants.items():
            with self.subTest(receipt=label):
                out, rejected, code = self._reconcile(
                    admitted_path, state, "task-b", {**canonical, **positive}, label, inventory=inventory,
                )
                self.assertNotEqual(code, 0, rejected)
                self.assertEqual(rejected["error"], "worker-liveness", rejected)
                self.assertFalse(out.exists())
                self.assertEqual(state.read_bytes(), original)
                self.assertFalse(host.futures["task-b"].done())
        _, resumed = self._schedule(
            admitted_path, admitted, state, snapshot, "positive-live-resume", cap="1"
        )
        self.assertEqual(resumed["dispatch"], [])
        self.assertEqual(resumed["unknown"], ["task-b"])
        self.assertEqual(host.consumed_packets, ["task-b"])
        self.assertFalse(host.futures["task-b"].done())

    def test_replayed_needs_repair_cannot_release_live_repair_worker(self) -> None:
        snapshot = self._single_task_snapshot()
        admitted_path, admitted = self._admit_issue(snapshot)
        state, scheduled = self._schedule(
            admitted_path, admitted, None, snapshot, "replay-initial", cap="1"
        )
        entry_a = scheduled["dispatch"][0]
        host = self._start_host(workers=2)
        host.dispatch([entry_a])
        report_a = host.wait_for_report("task-a")
        cached_a = make_result(self.github, "task-a", report_a, admitted)
        cached_a["outcome"] = "needs-repair"
        state, repair_ready, _ = self._apply(
            admitted_path, state, "task-a", cached_a, "replay-first-completion"
        )
        self.assertEqual(repair_ready["status"], "repair-ready", repair_ready)

        state, repair = self._schedule(
            admitted_path, admitted, state, snapshot, "replay-repair", cap="1"
        )
        self.assertEqual([entry["task_id"] for entry in repair["dispatch"]], ["task-a"])
        entry_b = repair["dispatch"][0]
        self.assertTrue(entry_b["repair"])
        self.assertEqual(self._reservation(entry_b), self._reservation(entry_a))
        host.hold_before_mutation = True
        host.dispatch([entry_b])
        self.assertTrue(host.before_mutation.wait(30))
        future_b = host.futures["task-a"]
        self.assertTrue(future_b.running())
        identity_b = copy.deepcopy(host.identities["task-a"])
        self.assertNotEqual(identity_b["worker_id"], report_a["worker"]["worker_id"])
        self.assertEqual(
            {key: cached_a["worker"][key] for key in identity_b},
            {key: report_a["worker"][key] for key in identity_b},
        )
        before = state.read_bytes()
        current = json.loads(before)["tasks"]["task-a"]
        self.assertEqual(current["status"], "running")
        self.assertEqual(current["host_worker"], identity_b)
        self.assertEqual(current["reservation"], self._reservation(entry_b))
        # B has started but cannot alter A's valid Git/PR evidence until released.
        self.assertEqual(git(Path(entry_b["workspace"]), "rev-parse", "HEAD"), report_a["worker"]["head_sha"])
        self.assertEqual(self.github.readback("task-a"), cached_a["readback"])
        self.assertEqual(make_result(self.github, "task-a", report_a, admitted)["checks"], cached_a["checks"])

        out, rejected, code = self._apply(
            admitted_path, state, "task-a", cached_a, "replay-stale-completion", expect_code=None
        )
        self.assertNotEqual(code, 0, rejected)
        self.assertEqual(rejected["error"], "worker-identity", rejected)
        self.assertFalse(out.exists())
        self.assertEqual(state.read_bytes(), before)
        self.assertTrue(future_b.running())
        state, no_third_worker = self._schedule(
            admitted_path, admitted, state, snapshot, "replay-no-third-worker", cap="2"
        )
        self.assertEqual(no_third_worker["dispatch"], [], no_third_worker)
        retained = json.loads(state.read_text())["tasks"]["task-a"]
        self.assertEqual(retained["status"], "running")
        self.assertEqual(retained["host_worker"], identity_b)
        self.assertEqual(retained["reservation"], self._reservation(entry_b))
        self.assertEqual(host.consumed_packets, ["task-a", "task-a"])
        self.assertTrue(future_b.running())

        host.mutation_hold.set()
        report_b = host.wait_for_report("task-a")
        self.assertEqual({key: report_b["worker"][key] for key in identity_b}, identity_b)
        self.assertNotEqual(report_b["worker"]["head_sha"], report_a["worker"]["head_sha"])
        result_b = make_result(self.github, "task-a", report_b, admitted)
        delivered_state, delivered, _ = self._apply(
            admitted_path, state, "task-a", result_b, "replay-current-completion"
        )
        self.assertEqual(delivered["status"], "delivered", delivered)
        self.assertEqual(json.loads(delivered_state.read_text())["tasks"]["task-a"]["status"], "delivered")

    def test_unbound_and_foreign_unknown_envelopes_leave_live_launch_untouched(self) -> None:
        snapshot = self._single_task_snapshot()
        admitted_path, admitted = self._admit_issue(snapshot)
        state, scheduled = self._schedule(
            admitted_path, admitted, None, snapshot, "binding-initial", cap="1"
        )
        host = self._start_host(workers=1)
        host.hold_before_mutation = True
        host.dispatch(scheduled["dispatch"])
        self.assertTrue(host.before_mutation.wait(30))
        identity = copy.deepcopy(host.identities["task-a"])
        before = state.read_bytes()
        variants = {
            "missing-worker": {"outcome": "unknown"},
            "malformed-worker": {"outcome": "unknown", "worker": []},
            "incomplete-identity": {
                "outcome": "unknown", "worker": {"worker_id": identity["worker_id"]},
            },
        }
        for field in ("host_id", "session_id", "worker_id"):
            variants["foreign-" + field] = {
                "outcome": "unknown", "worker": {**identity, field: "another-native-launch"},
            }
        for label, envelope in variants.items():
            with self.subTest(envelope=label):
                out, rejected, code = self._apply(
                    admitted_path, state, "task-a", envelope, "binding-" + label, expect_code=None
                )
                self.assertNotEqual(code, 0, rejected)
                self.assertEqual(rejected["error"], "worker-identity", rejected)
                self.assertFalse(out.exists())
                self.assertEqual(state.read_bytes(), before)
                self.assertTrue(host.futures["task-a"].running())

        # Unparseable transport bytes cannot enter the bound malformed-report transition.
        result_path = self.tmp / "binding-unparseable.json"
        result_path.write_text("{", encoding="utf-8")
        out = self.tmp / "binding-unparseable-state.json"
        code, rejected = invoke_cli(
            "apply-result", "--admitted", str(admitted_path), "--state", str(state),
            "--state-out", str(out), "--git-repo", str(self.repo),
            "--task", "task-a", "--result", str(result_path),
        )
        self.assertNotEqual(code, 0, rejected)
        self.assertEqual(rejected["error"], "worker-identity", rejected)
        self.assertFalse(out.exists())
        self.assertEqual(state.read_bytes(), before)
        self.assertTrue(host.futures["task-a"].running())
        _, resumed = self._schedule(
            admitted_path, admitted, state, snapshot, "binding-no-takeover", cap="2"
        )
        self.assertEqual(resumed["dispatch"], [], resumed)
        self.assertEqual(host.consumed_packets, ["task-a"])

    def test_unrecorded_completion_is_rejected_until_native_discovery_and_current_stop(self) -> None:
        snapshot = self._single_task_snapshot()
        admitted_path, admitted = self._admit_issue(snapshot)
        state, scheduled = self._schedule(admitted_path, admitted, None, snapshot, "unrecorded")
        host = self._start_host(workers=1)
        host.on_launch = None  # Lost host launch receipt, not a worker completion report.
        host.dispatch(scheduled["dispatch"])
        report = host.wait_for_report("task-a")
        observation = {"outcome": "unknown", "worker": report["worker"]}
        original = state.read_bytes()
        out, rejected, code = self._apply(
            admitted_path, state, "task-a", observation, "unrecorded-unknown", expect_code=None
        )
        self.assertNotEqual(code, 0, rejected)
        self.assertEqual(rejected["error"], "worker-identity", rejected)
        self.assertFalse(out.exists())
        self.assertEqual(state.read_bytes(), original)
        evidence = self.github.readback("task-a")
        evidence["worker_stop"] = self._stop_receipt(host, "task-a", state)
        # Actual host discovery can bind the missing launch, but cannot reuse the old receipt.
        self.launch_context[scheduled["dispatch"][0]["branch"]] = (admitted_path, state)
        self._record_launch(scheduled["dispatch"][0], host.identities["task-a"])
        state, unknown, _ = self._apply(
            admitted_path, state, "task-a", observation, "discovered-unknown"
        )
        self.assertEqual(unknown["status"], "unknown", unknown)
        _, rejected, code = self._reconcile(admitted_path, state, "task-a", evidence, "unrecorded-stale")
        self.assertNotEqual(code, 0, rejected)
        self.assertEqual(rejected["error"], "worker-liveness")
        evidence["worker_stop"] = self._stop_receipt(host, "task-a", state)
        _, reconciled, code = self._reconcile(admitted_path, state, "task-a", evidence, "discovered-stop")
        self.assertEqual(code, 0, reconciled)
        self.assertEqual(reconciled["evidence_pending"], ["task-a"])

    def test_cross_selector_claim_prevents_second_physical_worker_and_keeps_owned_recovery(self) -> None:
        snapshot = self._single_task_snapshot()
        admitted_path, admitted = self._admit_issue(snapshot)
        state, scheduled = self._schedule(admitted_path, admitted, None, snapshot, "claim-parent")
        original = scheduled["dispatch"][0]
        host = self._start_host(workers=1)
        host.dispatch([original])
        report = host.wait_for_report("task-a")
        state, outcome, _ = self._apply(
            admitted_path, state, "task-a",
            {"outcome": "unknown", "worker": report["worker"]}, "claim-lost-response"
        )
        self.assertEqual(outcome["status"], "unknown", outcome)

        listed = self.github.issue_list_snapshot(selected=[original["child_url"]])
        listed["graph"]["edges"] = []
        project = self.github.project_snapshot()
        for mode, fresh, admit_scope in (
            ("list", listed, self._admit_issues),
            ("project", project, self._admit_project),
        ):
            # Alternate wording or a Project view resolves the same issue identity.
            task = fresh["tasks"][0]
            task["workspace"] = str(self.tmp / ("second-" + mode))
            task["branch"] = "host/second-" + mode
            other_path, other = admit_scope(fresh)
            path = self._write_json("claim-%s-fresh.json" % mode, fresh)
            code, blocked = invoke_cli(
                "schedule", "--admitted", str(other_path),
                "--state-out", str(self.tmp / ("claim-" + mode + "-state.json")),
                "--git-repo", str(self.repo), "--fresh", str(path),
            )
            self.assertNotEqual(code, 0, blocked)
            self.assertIn(blocked["error"], ("existing-state", "ownership-conflict"))
            self.assertFalse(Path(task["workspace"]).exists())
            self.assertEqual(git(self.repo, "branch", "--list", task["branch"]), "")

        evidence = self.github.readback("task-a")
        evidence["worker_stop"] = self._stop_receipt(host, "task-a", state)
        state, reconciled, code = self._reconcile(
            admitted_path, state, "task-a", evidence, "claim-owned-recovery"
        )
        self.assertEqual(code, 0, reconciled)
        result = make_result(self.github, "task-a", report, admitted)
        state, delivered, _ = self._apply(admitted_path, state, "task-a", result, "claim-delivered")
        self.assertEqual(delivered["status"], "delivered", delivered)
        self._persist("task-a", result, original)
        _, resumed = self._schedule(
            admitted_path, admitted, state, self._single_task_snapshot(), "claim-resumed"
        )
        self.assertEqual(resumed["dispatch"], [], resumed)
        self.assertEqual(resumed["delivered"], ["task-a"])
        self.assertEqual(self.github.prs["task-a"]["pr_url"], evidence["pr_url"])
        workers = [json.loads(line) for line in self.transport_log.read_text().splitlines()
                   if json.loads(line).get("operation") == "dispatch-worker"]
        self.assertEqual(len(workers), 1)

    def test_stop_preserves_running_reservation_and_blocks_new_dispatch(self) -> None:
        snapshot = self._two_task_snapshot()
        admitted_path, admitted = self._admit_issue(snapshot)
        state, scheduled = self._schedule(admitted_path, admitted, None, snapshot, "stop-initial", cap="1")
        self.assertEqual([item["task_id"] for item in scheduled["dispatch"]], ["task-a"], scheduled)
        stopped_state, stopped = self._stop(admitted_path, state, "stop-request")
        self.assertEqual(stopped["status"], "stop-requested", stopped)
        saved = json.loads(stopped_state.read_text())
        self.assertTrue(saved["stop_requested"])
        self.assertEqual(saved["tasks"]["task-a"]["status"], "running")
        resumed_state, resumed = self._schedule(
            admitted_path, admitted, stopped_state, snapshot, "stop-resume", cap="1"
        )
        self.assertEqual(resumed["status"], "stopped", resumed)
        self.assertEqual(resumed["dispatch"], [], resumed)
        self.assertEqual(resumed["active"], ["task-a"], resumed)
        self.assertTrue(resumed_state.exists())

    def test_missing_delivery_note_retries_receipt_without_replaying_repository_work(self) -> None:
        snapshot = self._single_task_snapshot()
        admitted_path, admitted = self._admit_issue(snapshot)
        state, scheduled = self._schedule(admitted_path, admitted, None, snapshot, "receipt-initial")
        dispatch = scheduled["dispatch"][0]
        host = self._start_host(workers=1)
        host.dispatch([dispatch])
        report = host.wait_for_report("task-a")
        result = make_result(self.github, "task-a", report, admitted)
        missing_note = copy.deepcopy(result)
        missing_note.pop("note")
        pending_state, pending, _ = self._apply(
            admitted_path, state, "task-a", missing_note, "receipt-pending"
        )
        self.assertEqual(pending.get("status"), "note-pending", pending)
        complete_state, complete, _ = self._apply(
            admitted_path, pending_state, "task-a", result, "receipt-retry"
        )
        self.assertEqual(complete.get("status"), "delivered", complete)
        self.assertEqual(json.loads(complete_state.read_text())["tasks"]["task-a"]["status"], "delivered")
        self.assertEqual(
            sum(1 for line in self.transport_log.read_text().splitlines()
                if json.loads(line).get("kind") == "host"
                and json.loads(line).get("operation") == "dispatch-worker"),
            1,
        )


    def test_missing_state_never_reinitializes_and_reconcile_requires_direct_evidence(self) -> None:
        snapshot = self._single_task_snapshot()
        admitted_path, admitted = self._admit_issue(snapshot)
        state, scheduled = self._schedule(admitted_path, admitted, None, snapshot, "missing-state-initial", cap="1")
        dispatch = scheduled["dispatch"][0]
        missing = self.tmp / "does-not-exist-state.json"
        fresh_path = self._write_json("missing-state-fresh.json", snapshot)
        state_out = self.tmp / "missing-state-out.json"
        code, payload = invoke_cli(
            "schedule", "--admitted", str(admitted_path), "--state", str(missing), "--state-out", str(state_out),
            "--git-repo", str(self.repo), "--fresh", str(fresh_path), "--cap", "1",
        )
        self.assertNotEqual(code, 0, payload)
        self.assertFalse(missing.exists())
        self.assertFalse(state_out.exists())

        host = self._start_host(workers=1)
        host.dispatch([dispatch])
        report = host.wait_for_report("task-a")
        unknown = {"outcome": "unknown", "worker": report["worker"]}
        unknown_state, _, _ = self._apply(admitted_path, state, "task-a", unknown, "reconcile-unknown")
        saved = json.loads(unknown_state.read_text())
        self.assertEqual(saved["tasks"]["task-a"]["status"], "unknown")
        evidence = self.github.readback("task-a")
        evidence["worker_stop"] = self._stop_receipt(host, "task-a", unknown_state)
        wrong_branch = copy.deepcopy(evidence)
        wrong_branch["branch"] = "other/branch"
        _, wrong_output, wrong_code = self._reconcile(admitted_path, unknown_state, "task-a", wrong_branch, "reconcile-wrong")
        self.assertNotEqual(wrong_code, 0, wrong_output)
        self.assertEqual(json.loads(unknown_state.read_text())["tasks"]["task-a"]["status"], "unknown")
        missing_stop = copy.deepcopy(evidence)
        missing_stop.pop("worker_stop")
        _, missing_output, missing_code = self._reconcile(admitted_path, unknown_state, "task-a", missing_stop, "reconcile-no-stop")
        self.assertNotEqual(missing_code, 0, missing_output)
        reconciled_state, reconciled_output, reconciled_code = self._reconcile(
            admitted_path, unknown_state, "task-a", evidence, "reconcile-good"
        )
        self.assertEqual(reconciled_code, 0, reconciled_output)
        self.assertEqual(reconciled_output.get("status"), "reconciled", reconciled_output)
        self.assertEqual(json.loads(reconciled_state.read_text())["tasks"]["task-a"]["status"], "evidence-pending")

    def _reconcile(
        self, admitted_path: Path, state: Path, task_id: str, evidence: Dict[str, Any], name: str,
        *, inventory=None,
    ) -> Tuple[Path, Dict[str, Any], int]:
        evidence_path = self._write_json(name + "-evidence.json", evidence)
        if inventory is None:
            host = next(host for host in reversed(self.hosts) if task_id in host.futures)
            inventory = host.recovery_inventory()
        inventory_path = self._write_json(name + "-inventory.json", inventory)
        out = self.tmp / (name + "-state.json")
        args = [
            "reconcile", "--admitted", str(admitted_path), "--state", str(state), "--state-out", str(out),
            "--git-repo", str(self.repo), "--task", task_id, "--evidence", str(evidence_path),
            "--inventory", str(inventory_path),
        ]
        code, payload = invoke_cli(*args)
        return out, payload, code

    def test_reconcile_existing_pr_verifies_without_second_worker(self) -> None:
        snapshot = self._single_task_snapshot()
        admitted_path, admitted = self._admit_issue(snapshot)
        state, scheduled = self._schedule(
            admitted_path, admitted, None, snapshot, "reconcile-pr-initial", cap="1"
        )
        original = scheduled["dispatch"][0]
        host = self._start_host(workers=1)
        host.dispatch([original])
        report = host.wait_for_report("task-a")

        unknown_state, unknown_output, _ = self._apply(
            admitted_path,
            state,
            "task-a",
            {"outcome": "unknown", "worker": report["worker"]},
            "reconcile-pr-unknown",
        )
        self.assertEqual(unknown_output.get("status"), "unknown", unknown_output)
        unknown_saved = json.loads(unknown_state.read_text())
        self.assertEqual(unknown_saved["tasks"]["task-a"]["status"], "unknown")
        self.assertFalse(unknown_saved["halt_new_dispatch"])
        self.assertIsNone(unknown_saved["halt_reason"])

        evidence = self.github.readback("task-a")
        evidence["worker_stop"] = self._stop_receipt(host, "task-a", unknown_state)
        conflicting_absence = copy.deepcopy(evidence)
        conflicting_absence["pr_absent"] = True
        _, conflict_output, conflict_code = self._reconcile(
            admitted_path,
            unknown_state,
            "task-a",
            conflicting_absence,
            "reconcile-pr-conflicting-absence",
        )
        self.assertNotEqual(conflict_code, 0, conflict_output)
        self.assertEqual(conflict_output.get("error"), "evidence-mismatch", conflict_output)
        self.assertEqual(json.loads(unknown_state.read_text()), unknown_saved)

        for missing in ("pr_url", "open"):
            incomplete_absence = copy.deepcopy(evidence)
            incomplete_absence["pr_absent"] = True
            incomplete_absence.update(pr_url=None, open=False)
            incomplete_absence.pop(missing)
            _, missing_output, missing_code = self._reconcile(
                admitted_path,
                unknown_state,
                "task-a",
                incomplete_absence,
                "reconcile-pr-missing-" + missing,
            )
            self.assertNotEqual(missing_code, 0, missing_output)
            self.assertEqual(missing_output.get("error"), "evidence-mismatch", missing_output)
            self.assertEqual(json.loads(unknown_state.read_text()), unknown_saved)

        reconciled_state, reconciled, reconciled_code = self._reconcile(
            admitted_path, unknown_state, "task-a", evidence, "reconcile-pr-present"
        )
        self.assertEqual(reconciled_code, 0, reconciled)
        self.assertEqual(reconciled.get("status"), "reconciled", reconciled)
        reconciled_saved = json.loads(reconciled_state.read_text())
        self.assertEqual(reconciled_saved["tasks"]["task-a"]["status"], "evidence-pending")
        self.assertEqual(reconciled_saved["tasks"]["task-a"]["verified_pr"], evidence["pr_url"])
        self.assertFalse(reconciled_saved["halt_new_dispatch"])
        self.assertIsNone(reconciled_saved["halt_reason"])

        resumed_state, resumed = self._schedule(
            admitted_path,
            admitted,
            reconciled_state,
            self._single_task_snapshot(),
            "reconcile-pr-evidence-resume",
            cap="1",
        )
        self.assertEqual(resumed["dispatch"], [], resumed)
        self.assertIn(
            {"task_id": "task-a", "reason": "delivery-evidence-pending",
             "next_action": "assemble and apply independent full delivery evidence; do not dispatch another worker"},
            resumed["blocked"],
        )
        complete_result = make_result(self.github, "task-a", report, admitted)
        _, delivered, delivered_code = self._apply(
            admitted_path,
            resumed_state,
            "task-a",
            complete_result,
            "reconcile-pr-delivered",
        )
        self.assertEqual(delivered_code, 0, delivered)
        self.assertEqual(delivered.get("status"), "delivered", delivered)
        self.assertEqual(self.github.prs["task-a"]["pr_url"], evidence["pr_url"])
        self.assertEqual(
            sum(1 for line in self.transport_log.read_text().splitlines()
                if json.loads(line).get("kind") == "host"
                and json.loads(line).get("operation") == "dispatch-worker"),
            1,
        )

    def test_reconcile_explicit_pr_absence_recovers_to_repair_ready(self) -> None:
        snapshot = self._single_task_snapshot()
        admitted_path, admitted = self._admit_issue(snapshot)
        state, scheduled = self._schedule(
            admitted_path, admitted, None, snapshot, "reconcile-no-pr-initial", cap="1"
        )
        host = self._start_host(workers=1)
        entry = scheduled["dispatch"][0]
        host.dispatch([entry])
        report = host.wait_for_report("task-a")
        unknown_state, unknown_output, _ = self._apply(
            admitted_path,
            state,
            "task-a",
            {"outcome": "unknown", "worker": report["worker"]},
            "reconcile-no-pr-unknown",
        )
        self.assertEqual(unknown_output.get("status"), "unknown", unknown_output)
        self.github.prs.pop("task-a")
        worker = report["worker"]
        evidence = {
            "repo": self.github.canonical,
            "head_repo": self.github.canonical,
            "branch": worker["branch"],
            "base_branch": worker["base_branch"],
            "head_sha": worker["head_sha"],
            "unique": True,
            "pr_absent": True,
            "pr_url": None,
            "open": False,
            "worker_stop": self._stop_receipt(host, "task-a", unknown_state),
        }
        reconciled_state, reconciled, reconciled_code = self._reconcile(
            admitted_path, unknown_state, "task-a", evidence, "reconcile-no-pr-valid"
        )
        self.assertEqual(reconciled_code, 0, reconciled)
        self.assertEqual(reconciled.get("status"), "reconciled", reconciled)
        saved = json.loads(reconciled_state.read_text())
        self.assertEqual(saved["tasks"]["task-a"]["status"], "repair-ready")
        self.assertIsNone(saved["tasks"]["task-a"]["verified_pr"])
        self.assertFalse(saved["halt_new_dispatch"])
        self.assertIsNone(saved["halt_reason"])
        repair_state, repair = self._schedule(
            admitted_path, admitted, reconciled_state, snapshot, "reconcile-no-pr-repair", cap="1"
        )
        self.assertEqual([item["task_id"] for item in repair["dispatch"]], ["task-a"])
        self.assertEqual(self._reservation(repair["dispatch"][0]), self._reservation(entry))
        prior_worker = copy.deepcopy(host.identities["task-a"])
        host.dispatch(repair["dispatch"])
        repair_report = host.wait_for_report("task-a")
        self.assertNotEqual(host.identities["task-a"], prior_worker)
        result = make_result(self.github, "task-a", repair_report, admitted)
        _, delivered, _ = self._apply(admitted_path, repair_state, "task-a", result, "no-pr-repaired")
        self.assertEqual(delivered["status"], "delivered", delivered)

    def test_evidence_identity_diff_contract_reviewer_and_validation_gates(self) -> None:
        snapshot = self._single_task_snapshot()
        admitted_path, admitted = self._admit_issue(snapshot)
        state, scheduled = self._schedule(admitted_path, admitted, None, snapshot, "evidence-initial", cap="1")
        dispatch = scheduled["dispatch"][0]
        host = self._start_host(workers=1)
        host.dispatch([dispatch])
        report = host.wait_for_report("task-a")
        valid = make_result(self.github, "task-a", report, admitted)

        mismatch_cases = []
        changed = copy.deepcopy(valid)
        changed["worker"]["branch"] = "other/branch"
        mismatch_cases.append("worker-branch")
        changed2 = copy.deepcopy(valid)
        changed2["worker"]["head_sha"] = self.base_sha
        mismatch_cases.append("worker-head")
        changed3 = copy.deepcopy(valid)
        changed3["readback"]["diff_identity"] = "sha256:" + "0" * 64
        mismatch_cases.append("readback-diff")
        changed4 = copy.deepcopy(valid)
        changed4["validation"]["contract_hash"] = "sha256:" + "1" * 64
        mismatch_cases.append("contract-hash")
        changed5 = copy.deepcopy(valid)
        changed5["validation"]["reviewer_id"] = changed5["worker"]["worker_id"]
        mismatch_cases.append("reviewer-identity")
        changed6 = copy.deepcopy(valid)
        changed6["worker"]["base_branch"] = "other-parent"
        changed6["readback"]["base_branch"] = "other-parent"
        mismatch_cases.append("wrong-base")
        changed7 = copy.deepcopy(valid)
        changed7["readback"]["repo"] = "https://github.com/other/repo"
        mismatch_cases.append("wrong-repository")
        changed8 = copy.deepcopy(valid)
        changed8["readback"]["open"] = False
        mismatch_cases.append("closed-pr")
        changed9 = copy.deepcopy(valid)
        changed9["readback"]["unique"] = False
        mismatch_cases.append("duplicate-pr")
        changed10 = copy.deepcopy(valid)
        changed10["readback"]["draft"] = False
        mismatch_cases.append("ready-pr")
        variants = [changed, changed2, changed3, changed4, changed5, changed6, changed7, changed8, changed9, changed10]
        incomplete_reviews = copy.deepcopy(valid)
        incomplete_reviews["readback"]["reviews"]["complete"] = False
        stale_reviews = copy.deepcopy(valid)
        stale_reviews["readback"]["reviews"]["items"] = [{"id": 17, "commit_id": self.base_sha}]
        mismatch_cases.extend(["incomplete-review-pages", "stale-current-head-review"])
        variants.extend([incomplete_reviews, stale_reviews])
        current_state = state
        for label, result in zip(mismatch_cases, variants):
            with self.subTest(label=label):
                state_out, payload, code = self._apply(
                    admitted_path, current_state, "task-a", result, "variant-" + label, expect_code=None
                )
                self.assertTrue(state_out.exists(), (label, payload, code))
                saved = json.loads(state_out.read_text())
                self.assertNotEqual(saved["tasks"]["task-a"]["status"], "delivered", (label, payload))
                self.assertEqual(saved["tasks"]["task-a"]["reservation"], self._reservation(dispatch))
                evidence = {
                    "repo": self.github.canonical,
                    "head_repo": self.github.canonical,
                    "branch": report["worker"]["branch"],
                    "base_branch": report["worker"]["base_branch"],
                    "head_sha": report["worker"]["head_sha"],
                    "unique": True,
                    "pr_url": report["worker"]["pr_url"],
                    "open": True,
                    "worker_stop": self._stop_receipt(host, "task-a", state_out),
                }
                current_state, reconciled, reconcile_code = self._reconcile(
                    admitted_path, state_out, "task-a", evidence, "variant-" + label + "-reconcile"
                )
                self.assertEqual(reconcile_code, 0, reconciled)
                self.assertEqual(reconciled.get("status"), "reconciled", reconciled)

        failed_checks = copy.deepcopy(valid)
        failed_checks["checks"]["passed"] = False
        repaired_state, repaired, _ = self._apply(
            admitted_path, current_state, "task-a", failed_checks, "failed-checks"
        )
        self.assertEqual(repaired.get("status"), "repair-ready", repaired)
        repair_saved = json.loads(repaired_state.read_text())
        self.assertEqual(repair_saved["tasks"]["task-a"]["status"], "repair-ready")

        repair_input, repair_schedule = self._schedule(
            admitted_path, admitted, repaired_state, snapshot, "failed-validation-refill", cap="1"
        )
        self.assertEqual([entry["task_id"] for entry in repair_schedule["dispatch"]], ["task-a"])
        host.dispatch(repair_schedule["dispatch"])
        repair_report = host.wait_for_report("task-a")
        failed_validation = make_result(self.github, "task-a", repair_report, admitted)
        failed_validation["validation"]["verdict"] = "fail"
        validation_state, validation, _ = self._apply(
            admitted_path, repair_input, "task-a", failed_validation, "failed-validation"
        )
        self.assertEqual(validation.get("status"), "repair-ready", validation)
        self.assertEqual(json.loads(validation_state.read_text())["tasks"]["task-a"]["status"], "repair-ready")

        requested_input, requested_schedule = self._schedule(
            admitted_path, admitted, validation_state, snapshot, "requested-repair-refill", cap="1"
        )
        self.assertEqual([entry["task_id"] for entry in requested_schedule["dispatch"]], ["task-a"])
        host.dispatch(requested_schedule["dispatch"])
        requested_report = host.wait_for_report("task-a")
        requested_repair = make_result(self.github, "task-a", requested_report, admitted)
        requested_repair["outcome"] = "needs-repair"
        requested_state, requested, _ = self._apply(
            admitted_path, requested_input, "task-a", requested_repair, "requested-repair"
        )
        self.assertEqual(requested.get("status"), "repair-ready", requested)
        self.assertEqual(json.loads(requested_state.read_text())["tasks"]["task-a"]["status"], "repair-ready")

    def test_alias_workspace_collision_and_same_parent_repair(self) -> None:
        worktree_root = Path(self.github.children[0]["workspace"]).parent
        worktree_root.mkdir(parents=True, exist_ok=True)
        os.symlink(worktree_root, self.repo / "alias")
        collision_snapshot = self.github.snapshot()
        collision_snapshot["tasks"] = collision_snapshot["children"] = collision_snapshot["children"][:2]
        collision_snapshot["children"][1]["workspace"] = "alias/task-a"
        admitted_path, admitted = self._admit_issue(collision_snapshot)
        state, scheduled = self._schedule(admitted_path, admitted, None, collision_snapshot, "alias-collision", cap="2")
        self.assertEqual([item["task_id"] for item in scheduled["dispatch"]], ["task-a"], scheduled)
        self.assertTrue(any(item["task_id"] == "task-b" and "collision" in item["reason"] for item in scheduled["blocked"]))
        self.assertTrue(Path(scheduled["dispatch"][0]["workspace"]).is_absolute())

        repair_snapshot = collision_snapshot
        repair_admitted_path, repair_admitted = admitted_path, admitted
        repair_state, repair_schedule = state, scheduled
        original = repair_schedule["dispatch"][0]
        host = self._start_host(workers=1)
        host.dispatch([original])
        report = host.wait_for_report("task-a")
        valid = make_result(self.github, "task-a", report, repair_admitted)
        failed = copy.deepcopy(valid)
        failed["checks"]["passed"] = False
        repair_ready_state, repair_ready, _ = self._apply(
            repair_admitted_path, repair_state, "task-a", failed, "repair-ready"
        )
        self.assertEqual(repair_ready.get("status"), "repair-ready", repair_ready)
        resumed_state, resumed = self._schedule(
            repair_admitted_path, repair_admitted, repair_ready_state, repair_snapshot, "repair-resume", cap="1"
        )
        self.assertEqual(len(resumed["dispatch"]), 1, resumed)
        repaired_entry = resumed["dispatch"][0]
        self.assertTrue(repaired_entry["repair"], repaired_entry)
        self.assertEqual(repaired_entry["branch"], original["branch"])
        self.assertEqual(repaired_entry["workspace"], original["workspace"])
        self.assertEqual(repaired_entry["parent_branch"], original["parent_branch"])
        self.assertEqual(repaired_entry["parent_sha"], original["parent_sha"])
        self.assertEqual(repaired_entry["retained_pr"], valid["worker"]["pr_url"])
        host.dispatch([repaired_entry])
        repaired_report = host.wait_for_report("task-a")
        repaired_result = make_result(self.github, "task-a", repaired_report, repair_admitted)
        _, delivered, _ = self._apply(
            repair_admitted_path, resumed_state, "task-a", repaired_result, "repair-delivered"
        )
        self.assertEqual(delivered.get("status"), "delivered", delivered)

    def test_project_dedup_parented_members_and_status_readback(self) -> None:
        project_snapshot = self.github.project_snapshot()
        project_snapshot["members"].append(copy.deepcopy(project_snapshot["members"][1]))
        admitted_path, admitted = self._admit_project(project_snapshot)
        self.assertEqual([item["task_id"] for item in admitted["tasks"]], ["task-a"])
        state, scheduled = self._schedule(
            admitted_path, admitted, None, project_snapshot, "project-initial", cap="1"
        )
        self.assertEqual([item["task_id"] for item in scheduled["dispatch"]], ["task-a"])
        host = self._start_host(workers=1)
        entry = scheduled["dispatch"][0]
        host.dispatch([entry])
        report = host.wait_for_report("task-a")
        result = make_result(self.github, "task-a", report, admitted)
        current_state = state
        for label, broken in (
            ("project-status-missing", {k: v for k, v in result.items() if k != "project_status"}),
            ("project-status-wrong", {**result, "project_status": {**result["project_status"], "status": "Todo"}}),
        ):
            with self.subTest(project_gate=label):
                rejected_state, rejected, _ = self._apply(
                    admitted_path, current_state, "task-a", broken, label, expect_code=None
                )
                self.assertTrue(rejected_state.exists(), rejected)
                self.assertEqual(
                    json.loads(rejected_state.read_text())["tasks"]["task-a"]["status"],
                    "note-pending" if label == "project-status-missing" else "unknown",
                    rejected,
                )
                if label == "project-status-missing":
                    rejected_state, pending = self._schedule(
                        admitted_path, admitted, rejected_state, project_snapshot,
                        "project-status-pending",
                    )
                    self.assertEqual(pending["dispatch"], [], pending)
                current_state = rejected_state
        evidence = {
            "repo": self.github.canonical,
            "head_repo": self.github.canonical,
            "branch": report["worker"]["branch"],
            "base_branch": report["worker"]["base_branch"],
            "head_sha": report["worker"]["head_sha"],
            "unique": True,
            "pr_url": report["worker"]["pr_url"],
            "open": True,
            "worker_stop": self._stop_receipt(host, "task-a", current_state),
        }
        current_state, reconciled, reconcile_code = self._reconcile(
            admitted_path, current_state, "task-a", evidence, "project-status-reconcile"
        )
        self.assertEqual(reconcile_code, 0, reconciled)
        result["project_status"] = self.github.read_project_status("task-a")
        delivered_state, delivered, _ = self._apply(
            admitted_path, current_state, "task-a", result, "project-delivery"
        )
        self.assertEqual(delivered["status"], "delivered", delivered)
        self.assertEqual(
            sum(json.loads(line).get("operation") == "dispatch-worker"
                for line in self.transport_log.read_text().splitlines()),
            1,
        )
        self._persist("task-a", result, entry)
        receipt = result["project_status"]
        self.assertEqual(
            {"project_url", "issue_url", "item_id", "status"},
            set(receipt),
        )
        self.assertEqual(receipt["project_url"], project_snapshot["project"]["url"])
        self.assertEqual(receipt["issue_url"], project_snapshot["members"][1]["url"])
        self.assertEqual(receipt["status"], project_snapshot["lifecycle"]["inReview"])
        self.assertEqual(self.github.read_project_status("task-a"), receipt)
        _, after = self._schedule(
            admitted_path, admitted, delivered_state, self.github.project_snapshot(), "project-status"
        )
        self.assertEqual(after["dispatch"], [], after)
        self.assertNotIn("project_sync", after)
        self.assertNotIn("project_status", after)


    def test_project_item_identity_is_required_and_substituted_receipt_isolated(self) -> None:
        base_project = self.github.project_snapshot()
        for label, value in (("missing", None), ("empty", "")):
            broken = copy.deepcopy(base_project)
            if label == "missing":
                broken["members"][1].pop("item_id")
            else:
                broken["members"][1]["item_id"] = value
            path = self._write_json("project-item-%s.json" % label, broken)
            code, payload = invoke_cli(
                "admit", "--snapshot", str(path)
            )
            self.assertNotEqual(code, 0, payload)
            self.assertEqual(payload.get("error"), "invalid-project-item", payload)

        project_snapshot = copy.deepcopy(base_project)
        dependent = copy.deepcopy(self.github.children[1])
        dependent.update(
            ordinal=3,
            item_id="PVTI_project_item_b",
            actual_parent=self.github.parent_url,
            declared_parent=self.github.parent_url,
            prerequisites=["task-a"],
        )
        project_snapshot["tasks"].append(dependent)
        conflicting = copy.deepcopy(project_snapshot)
        conflicting["tasks"][1]["item_id"] = conflicting["tasks"][0]["item_id"]
        path = self._write_json("project-duplicate-item.json", conflicting)
        code, payload = invoke_cli("admit", "--snapshot", str(path))
        self.assertNotEqual(code, 0, payload)
        self.assertEqual(payload.get("error"), "duplicate-identity", payload)
        admitted_path, admitted = self._admit_project(project_snapshot)
        state, scheduled = self._schedule(
            admitted_path, admitted, None, project_snapshot, "project-item-initial", cap="1"
        )
        self.assertEqual([entry["task_id"] for entry in scheduled["dispatch"]], ["task-a"])
        host = self._start_host(workers=1)
        entry = scheduled["dispatch"][0]
        host.dispatch([entry])
        report = host.wait_for_report("task-a")
        result = make_result(self.github, "task-a", report, admitted)
        substituted = copy.deepcopy(result)
        substituted["project_status"]["item_id"] = "PVTI_project_item_substituted"
        variant_state = self.tmp / "project-item-substituted-input.state.json"
        variant_state.write_text(state.read_text(), encoding="utf-8")
        variant_state.chmod(0o600)
        rejected_state, rejected, _ = self._apply(
            admitted_path,
            variant_state,
            "task-a",
            substituted,
            "project-item-substituted",
            expect_code=None,
        )
        self.assertEqual(rejected.get("status"), "unknown", rejected)
        self.assertEqual(rejected.get("reason"), "project-status-mismatch", rejected)
        rejected_saved = json.loads(rejected_state.read_text())
        self.assertEqual(rejected_saved["tasks"]["task-a"]["status"], "unknown")
        self.assertFalse(rejected_saved["halt_new_dispatch"])

        _, resumed = self._schedule(
            admitted_path,
            admitted,
            rejected_state,
            project_snapshot,
            "project-item-dependent-blocked",
            cap="1",
        )
        self.assertEqual(resumed.get("status"), "ok", resumed)
        self.assertEqual(resumed.get("unknown"), ["task-a"], resumed)
        self.assertEqual(resumed.get("dispatch"), [], resumed)

    def test_existing_delivery_without_owner_claim_cannot_be_adopted(self) -> None:
        retained = self._seed_prior_delivery("task-a")
        retained_workspace = Path(retained["reservation"]["workspace"])
        self.assertTrue(retained_workspace.is_absolute())
        self.assertNotIn(".woostack", retained_workspace.parts)
        self.assertEqual(retained["reservation"]["branch"], "feature/task-a")
        self.assertEqual(git(retained_workspace, "status", "--porcelain"), "")
        self.assertNotEqual(git(retained_workspace, "rev-parse", "HEAD"), self.base_sha)
        snapshot = self.github.snapshot()
        admitted_path, admitted = self._admit_issue(snapshot)
        state, resumed = self._schedule(admitted_path, admitted, None, snapshot, "resume-valid", cap="1")
        self.assertEqual([entry["task_id"] for entry in resumed["dispatch"]], ["task-b"], resumed)
        self.assertIn({"task_id": "task-a", "reason": "ownership-unverified",
                       "next_action": "prove prior claim or perform explicit verified ownership transfer"},
                      resumed["blocked"])
        saved = json.loads(state.read_text())
        self.assertEqual(saved["tasks"]["task-a"]["status"], "pending")

        stale = copy.deepcopy(snapshot)
        stale["children"][0]["existing_delivery"]["result"]["readback"]["head_sha"] = self.base_sha
        stale_state, stale_output = self._schedule(admitted_path, admitted, state, stale, "resume-stale", cap="1")
        self.assertEqual(stale_output["dispatch"], [], stale_output)
        self.assertIn({"task_id": "task-a", "reason": "ownership-unverified",
                       "next_action": "prove prior claim or perform explicit verified ownership transfer"},
                      stale_output["blocked"])
        self.assertTrue(stale_state.exists())


    def test_retained_delivery_without_owner_claim_stays_blocked(self) -> None:
        retained = self._seed_prior_delivery("task-c")
        snapshot = self.github.snapshot()
        admitted_path, admitted = self._admit_issue(snapshot)
        state, output = self._schedule(admitted_path, admitted, None, snapshot, "retained-unready")
        self.assertEqual(output["status"], "ok")
        self.assertIn({"task_id": "task-c", "reason": "ownership-unverified",
                       "next_action": "prove prior claim or perform explicit verified ownership transfer"},
                      output["blocked"])
        saved = json.loads(state.read_text())
        self.assertIsNone(saved["tasks"]["task-c"]["reservation"])
        self.assertEqual(saved["tasks"]["task-c"]["status"], "pending")

    def test_retained_delivery_cannot_be_adopted_even_with_conflicting_parent(self) -> None:
        self._seed_prior_delivery("task-a")
        self._seed_prior_delivery("task-c")
        snapshot = self.github.snapshot()
        admitted_path, admitted = self._admit_issue(snapshot)
        _, output = self._schedule(admitted_path, admitted, None, snapshot, "retained-uncontained")
        self.assertEqual(output["status"], "ok")
        self.assertIn("task-a", [entry["task_id"] for entry in output["blocked"]])
        self.assertIn("task-c", [entry["task_id"] for entry in output["blocked"]])

    def test_retained_root_without_owner_claim_cannot_replace_integration_parent(self) -> None:
        git(self.repo, "branch", "other-parent", self.base_sha)
        self._seed_prior_delivery("task-a", "other-parent")
        snapshot = self.github.snapshot()
        admitted_path, admitted = self._admit_issue(snapshot)
        _, output = self._schedule(admitted_path, admitted, None, snapshot, "retained-wrong-parent")
        self.assertEqual(output["status"], "ok")
        self.assertIn({"task_id": "task-a", "reason": "ownership-unverified",
                       "next_action": "prove prior claim or perform explicit verified ownership transfer"},
                      output["blocked"])

    def test_retained_delivery_without_owner_claim_cannot_skip_external_blocker(self) -> None:
        self._seed_prior_delivery("task-a")
        snapshot = self.github.snapshot()
        snapshot["children"][0]["external_prerequisites"] = [self.github.canonical + "/issues/999"]
        admitted_path, admitted = self._admit_issue(snapshot)
        state, output = self._schedule(admitted_path, admitted, None, snapshot, "retained-external")
        self.assertEqual(output["status"], "ok")
        self.assertIn({"task_id": "task-a", "reason": "ownership-unverified",
                       "next_action": "prove prior claim or perform explicit verified ownership transfer"},
                      output["blocked"])
        self.assertIsNone(json.loads(state.read_text())["tasks"]["task-a"]["reservation"])

    def test_execute_consumer_blocks_missing_readiness_before_git_mutation(self) -> None:
        snapshot = self._single_task_snapshot()
        admitted_path, admitted = self._admit_issue(snapshot)
        _, output = self._schedule(admitted_path, admitted, None, snapshot, "consumer-readiness")
        entry = copy.deepcopy(output["dispatch"][0])
        entry["packet"].pop("parent_readiness")
        host = self._start_host(workers=1)
        host.dispatch([entry])
        with self.assertRaises(AssertionError):
            host.wait_for_report("task-a")
        self.assertFalse(Path(entry["workspace"]).exists())
        self.assertEqual(self.github.prs, {})


if __name__ == "__main__":
    unittest.main()
