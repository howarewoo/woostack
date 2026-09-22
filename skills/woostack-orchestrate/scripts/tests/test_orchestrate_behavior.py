#!/usr/bin/env python3
"""Behavioral tests for the shipped woostack-orchestrate helper.

Every controller operation crosses the recording driver's subprocess boundary
and therefore exercises scripts/orchestrate.py, not a test scheduler.  The
fake transports only assemble paginated native reads, consume emitted Execute
packets, and provide independent Git/GitHub evidence.
"""

from __future__ import annotations

import copy
import json
import os
import shutil
import subprocess
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
        args = ["admit", "--issue", self.github.parent_url, "--snapshot", str(snapshot_path)]
        if max_parallel is not None:
            args += ["--max-parallel", max_parallel]
        code, payload = invoke_cli(*args)
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload.get("status"), "admitted", payload)
        admitted_path = self._write_json("admitted-%d.json" % len(list(self.tmp.glob("admitted-*.json"))), payload)
        return admitted_path, payload

    def _admit_project(self, snapshot: Optional[Dict[str, Any]] = None) -> Tuple[Path, Dict[str, Any]]:
        project_url = "https://github.com/orgs/acme/projects/7"
        snapshot_path = self._write_json("project-snapshot.json", snapshot or self.github.project_snapshot())
        code, payload = invoke_cli("admit", "--project", project_url, "--snapshot", str(snapshot_path))
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

    def _reservation(self, dispatch: Dict[str, Any]) -> Dict[str, Any]:
        return {
            key: dispatch[key]
            for key in ("branch", "workspace", "parent_branch", "parent_sha")
        }

    def _persist(self, task_id: str, result: Dict[str, Any], dispatch: Dict[str, Any]) -> None:
        self.github.persist_delivery(task_id, result, self._reservation(dispatch))

    def _single_task_snapshot(self, task_id: str = "task-a") -> Dict[str, Any]:
        snapshot = self.github.snapshot()
        child = next(item for item in snapshot["children"] if item["task_id"] == task_id)
        snapshot["children"] = [child]
        snapshot["expected_index"] = [task_id]
        return snapshot

    def _start_host(self, workers: int = 3) -> FakeHost:
        host = FakeHost(self.repo, self.github, max_workers=workers)
        self.hosts.append(host)
        return host

    def _seed_prior_delivery(self, task_id: str, parent_branch: str = "main", parent_sha: Optional[str] = None) -> Dict[str, Any]:
        """Create actual historical PR bytes, without declaring their current readiness."""
        parent_sha = parent_sha or self.base_sha
        task = next(child for child in self.github.children if child["task_id"] == task_id)
        worktree = self.repo / ".woostack" / "worktrees" / "tasks" / task_id
        worktree.parent.mkdir(parents=True, exist_ok=True)
        branch = "woostack/" + task_id
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
            "diff_identity": diff_identity(self.repo, parent_sha, head),
        }
        self.github.save_pr(task_id, pr)
        worker = {key: pr[key] for key in ("pr_url", "branch", "head_sha", "commit_sha", "base_branch", "association")}
        worker["worker_id"] = "prior-execute-" + task_id
        result = make_result(self.github, task_id, {"worker": worker, "parent_sha": parent_sha}, {
            "mode": "issue", "tasks": [{**task, "workspace": str(worktree.relative_to(self.repo))}],
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
        self.assertEqual(initial["status"], "ok", initial)
        self.assertEqual(
            sorted(item["task_id"] for item in initial["dispatch"]),
            ["task-a", "task-b", "task-e"],
        )
        self.assertNotIn(self.github.parent_url, [item["child_url"] for item in initial["dispatch"]])
        self.assertEqual(git(self.repo, "for-each-ref", "--format=%(refname:short)", "refs/heads"), "main")
        self.assertFalse((self.repo / ".woostack" / "worktrees" / "tasks" / "task-a").exists())

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
        self.assertEqual(c_entry["parent_branch"], "woostack/task-a")
        self.assertEqual(c_entry["parent_sha"], report_a["worker"]["head_sha"])
        self.assertEqual(c_entry["packet"]["parent_readiness"]["logical_prerequisites"], ["task-a"])
        self.assertEqual(c_entry["packet"]["parent_readiness"]["prerequisites"][0]["checkpoint"]["note"]["head_sha"],
                         report_a["worker"]["head_sha"])
        self.assertEqual(
            c_entry["packet"]["bounded_input"],
            next(item["contract"] for item in admitted["tasks"] if item["task_id"] == "task-c"),
        )
        self.assertEqual(c_entry["packet"]["child_issue_url"], self.github.children[2]["url"])
        self.assertEqual(c_entry["packet"]["scope_url"], self.github.parent_url)
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
        self.assertEqual(sorted(paused_d["prerequisite_branches"]), ["woostack/task-a", "woostack/task-b"])

        # A join branch is a user-selected parent decision.  The helper must
        # never create it automatically.
        git(self.repo, "checkout", "-q", "-b", "join-ab", self.base_sha)
        self._run(["git", "-C", str(self.repo), "merge", "--no-ff", "woostack/task-a", "-m", "join A"])
        self._run(["git", "-C", str(self.repo), "merge", "--no-ff", "woostack/task-b", "-m", "join B"])
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

    def test_admission_edges_require_native_paginated_scope(self) -> None:
        base = self.github.snapshot()
        cases = []
        wrong_parent = copy.deepcopy(base)
        wrong_parent["parent"]["url"] = self.github.canonical + "/issues/999"
        cases.append(("wrong exact parent", wrong_parent))
        missing_page = copy.deepcopy(base)
        missing_page["pagination"]["sub_issues"] = False
        cases.append(("missing terminal page", missing_page))
        foreign_parent = copy.deepcopy(base)
        foreign_parent["children"][0]["actual_parent"] = self.github.canonical + "/issues/999"
        cases.append(("child attached elsewhere", foreign_parent))
        nested = copy.deepcopy(base)
        nested["children"][0]["nested_children"] = True
        cases.append(("nested container", nested))
        missing_expected = copy.deepcopy(base)
        missing_expected["expected_index"].append("task-z")
        cases.append(("missing expected child", missing_expected))
        cycle = copy.deepcopy(base)
        cycle["children"][0]["prerequisites"] = ["task-b"]
        cycle["children"][1]["prerequisites"] = ["task-a"]
        cases.append(("dependency cycle", cycle))
        missing_endpoint = copy.deepcopy(base)
        missing_endpoint["children"][2]["prerequisites"] = ["task-z"]
        cases.append(("missing dependency endpoint", missing_endpoint))
        malformed_contract = copy.deepcopy(base)
        malformed_contract["children"][0]["contract"].pop("non_goals")
        cases.append(("malformed contract", malformed_contract))
        unavailable_host = copy.deepcopy(base)
        unavailable_host["host"]["delivery_capable"] = False
        cases.append(("host cannot deliver", unavailable_host))
        for label, snapshot in cases:
            with self.subTest(label=label):
                path = self._write_json("edge-%s.json" % label.replace(" ", "-"), snapshot)
                code, payload = invoke_cli("admit", "--issue", self.github.parent_url, "--snapshot", str(path))
                self.assertNotEqual(code, 0, payload)
                self.assertFalse(payload.get("ok", True), payload)

        empty = copy.deepcopy(base)
        empty["children"] = []
        empty["expected_index"] = []
        path = self._write_json("empty.json", empty)
        code, payload = invoke_cli("admit", "--issue", self.github.parent_url, "--snapshot", str(path))
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload.get("status"), "no-work", payload)

        text_only = copy.deepcopy(empty)
        text_only["parent"]["body"] = "- [ ] task-a\n- [ ] task-b\nParent: #100"
        path = self._write_json("text-only.json", text_only)
        code, payload = invoke_cli("admit", "--issue", self.github.parent_url, "--snapshot", str(path))
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload.get("status"), "no-work", payload)

        for args in (
            ["admit", "--snapshot", str(self._write_json("missing-selector.json", base))],
            ["admit", "--issue", self.github.parent_url, "--project", "https://github.com/orgs/acme/projects/7", "--snapshot", str(self._write_json("conflict.json", base))],
            ["admit", "--issue", self.github.parent_url, "--snapshot", str(self._write_json("zero-limit.json", base)), "--max-parallel", "0"],
            ["admit", "--issue", self.github.parent_url, "--snapshot", str(self._write_json("fraction-limit.json", base)), "--max-parallel", "1.5"],
        ):
            with self.subTest(selector_case=args):
                code, payload = invoke_cli(*args)
                self.assertNotEqual(code, 0, payload)

        project = self.github.project_snapshot()
        project["pagination"]["parents"] = False
        path = self._write_json("project-no-parents-page.json", project)
        code, payload = invoke_cli("admit", "--project", project["project"]["url"], "--snapshot", str(path))
        self.assertNotEqual(code, 0, payload)

    def test_fingerprint_binds_scope_parent_spec_rules_identity_and_workspace(self) -> None:
        snapshot = self.github.snapshot()
        admitted_path, admitted = self._admit_issue(snapshot)
        state, initial = self._schedule(admitted_path, admitted, None, snapshot, "fingerprint-base", cap="3")
        self.assertTrue(initial["dispatch"], initial)

        host_cap_only = copy.deepcopy(snapshot)
        host_cap_only["host"]["max_parallel"] = 1
        next_state, unchanged = self._schedule(
            admitted_path, admitted, state, host_cap_only, "fingerprint-host-cap"
        )
        self.assertEqual(unchanged["status"], "ok", unchanged)
        self.assertEqual(unchanged["dispatch"], [], unchanged)
        self.assertTrue(next_state.exists())

        git(self.repo, "commit", "--allow-empty", "-m", "mutable integration tip")
        mutable_tip = git(self.repo, "rev-parse", "HEAD")
        mutable_sha = copy.deepcopy(snapshot)
        mutable_sha["integration"]["sha"] = mutable_tip
        _, mutable = self._schedule(admitted_path, admitted, state, mutable_sha, "fingerprint-sha")
        self.assertEqual(mutable["status"], "snapshot-drift", mutable)
        self.assertEqual(mutable["reason"], "parent-tip-drift", mutable)
        self.assertEqual(mutable["dispatch"], [], mutable)

        drift_cases = []
        added_child = copy.deepcopy(snapshot)
        child = copy.deepcopy(added_child["children"][0])
        child.update(task_id="task-z", ordinal=6, url=self.github.canonical + "/issues/999",
                     id=999, node_id="I_new_child")
        added_child["children"].append(child)
        added_child["expected_index"].append("task-z")
        drift_cases.append(("new native child", added_child))
        changed_spec = copy.deepcopy(snapshot)
        changed_spec["specification"] += " amended"
        drift_cases.append(("parent specification", changed_spec))
        changed_rules = copy.deepcopy(snapshot)
        changed_rules["repository_rules"] += " amended"
        drift_cases.append(("repository rules", changed_rules))
        changed_parent = copy.deepcopy(snapshot)
        changed_parent["parent"]["node_id"] = "I_kwDOchanged"
        drift_cases.append(("native parent identity", changed_parent))
        changed_child = copy.deepcopy(snapshot)
        changed_child["children"][0]["node_id"] = "I_kwDOchangedchild"
        drift_cases.append(("native child identity", changed_child))
        changed_body = copy.deepcopy(snapshot)
        changed_body["children"][0]["body"] += " changed"
        drift_cases.append(("immutable child field", changed_body))
        changed_workspace = copy.deepcopy(snapshot)
        changed_workspace["children"][0]["workspace"] = "safe/alternate-task-a"
        drift_cases.append(("workspace", changed_workspace))
        for label, fresh in drift_cases:
            with self.subTest(label=label):
                _, payload = self._schedule(admitted_path, admitted, state, fresh, "drift-" + label.replace(" ", "-"))
                self.assertEqual(payload.get("status"), "snapshot-drift", payload)
                self.assertEqual(payload.get("dispatch"), [], payload)

    def test_unknown_and_malformed_results_halt_and_keep_reservations(self) -> None:
        snapshot = self._single_task_snapshot()
        admitted_path, admitted = self._admit_issue(snapshot)
        state, scheduled = self._schedule(admitted_path, admitted, None, snapshot, "unknown-initial", cap="1")
        dispatch = scheduled["dispatch"][0]
        reservation = self._reservation(dispatch)
        unknown_state, unknown_output, _ = self._apply(
            admitted_path,
            state,
            "task-a",
            {"outcome": "unknown"},
            "unknown",
        )
        self.assertIn(unknown_output.get("status"), {"unknown", "halted"}, unknown_output)
        unknown_saved = json.loads(unknown_state.read_text())
        self.assertEqual(unknown_saved["tasks"]["task-a"]["status"], "unknown")
        self.assertEqual(unknown_saved["tasks"]["task-a"]["reservation"], reservation)
        halted_state, halted = self._schedule(
            admitted_path, admitted, unknown_state, snapshot, "unknown-halted", cap="1"
        )
        self.assertEqual(halted["status"], "halted", halted)
        self.assertEqual(halted["dispatch"], [], halted)
        self.assertTrue(halted_state.exists())

        malformed_state, malformed, _ = self._apply(
            admitted_path,
            state,
            "task-a",
            {"outcome": "ok", "worker": {"worker_id": "execute-task-a"}},
            "malformed",
        )
        self.assertIn(malformed.get("status"), {"unknown", "halted"}, malformed)
        malformed_saved = json.loads(malformed_state.read_text())
        self.assertEqual(malformed_saved["tasks"]["task-a"]["status"], "unknown")
        blocked_state, blocked = self._schedule(
            admitted_path, admitted, malformed_state, snapshot, "malformed-halted", cap="1"
        )
        self.assertEqual(blocked["status"], "halted", blocked)
        self.assertEqual(blocked["dispatch"], [], blocked)
        self.assertTrue(blocked_state.exists())

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
        evidence["worker_stopped"] = True
        wrong_branch = copy.deepcopy(evidence)
        wrong_branch["branch"] = "woostack/not-task-a"
        _, wrong_output, wrong_code = self._reconcile(admitted_path, unknown_state, "task-a", wrong_branch, "reconcile-wrong")
        self.assertNotEqual(wrong_code, 0, wrong_output)
        self.assertEqual(json.loads(unknown_state.read_text())["tasks"]["task-a"]["status"], "unknown")
        missing_stop = copy.deepcopy(evidence)
        missing_stop.pop("worker_stopped")
        _, missing_output, missing_code = self._reconcile(admitted_path, unknown_state, "task-a", missing_stop, "reconcile-no-stop")
        self.assertNotEqual(missing_code, 0, missing_output)
        reconciled_state, reconciled_output, reconciled_code = self._reconcile(
            admitted_path, unknown_state, "task-a", evidence, "reconcile-good"
        )
        self.assertEqual(reconciled_code, 0, reconciled_output)
        self.assertEqual(reconciled_output.get("status"), "reconciled", reconciled_output)
        self.assertEqual(json.loads(reconciled_state.read_text())["tasks"]["task-a"]["status"], "running")

    def _reconcile(
        self, admitted_path: Path, state: Path, task_id: str, evidence: Dict[str, Any], name: str
    ) -> Tuple[Path, Dict[str, Any], int]:
        evidence_path = self._write_json(name + "-evidence.json", evidence)
        out = self.tmp / (name + "-state.json")
        args = [
            "reconcile", "--admitted", str(admitted_path), "--state", str(state), "--state-out", str(out),
            "--git-repo", str(self.repo), "--task", task_id, "--evidence", str(evidence_path),
        ]
        code, payload = invoke_cli(*args)
        return out, payload, code

    def test_reconcile_rejects_conflicting_pr_absence_and_preserves_same_pr_repair(self) -> None:
        snapshot = self._single_task_snapshot()
        admitted_path, admitted = self._admit_issue(snapshot)
        state, scheduled = self._schedule(
            admitted_path, admitted, None, snapshot, "reconcile-pr-initial", cap="1"
        )
        original = scheduled["dispatch"][0]
        host = self._start_host(workers=1)
        host.dispatch([original])
        report = host.wait_for_report("task-a")

        unknown_state, halted, _ = self._apply(
            admitted_path,
            state,
            "task-a",
            {"outcome": "unknown", "worker": report["worker"]},
            "reconcile-pr-unknown",
        )
        self.assertEqual(halted.get("status"), "halted", halted)
        unknown_saved = json.loads(unknown_state.read_text())
        self.assertEqual(unknown_saved["tasks"]["task-a"]["status"], "unknown")
        self.assertTrue(unknown_saved["halt_new_dispatch"])
        self.assertEqual(unknown_saved["halt_reason"], "unknown-response")

        evidence = self.github.readback("task-a")
        evidence["worker_stopped"] = True
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
        self.assertEqual(reconciled_saved["tasks"]["task-a"]["status"], "running")
        self.assertEqual(reconciled_saved["tasks"]["task-a"]["verified_pr"], evidence["pr_url"])
        self.assertFalse(reconciled_saved["halt_new_dispatch"])
        self.assertIsNone(reconciled_saved["halt_reason"])

        failed = make_result(self.github, "task-a", report, admitted)
        failed["checks"]["passed"] = False
        repair_ready_state, repair_ready, _ = self._apply(
            admitted_path,
            reconciled_state,
            "task-a",
            failed,
            "reconcile-pr-repair-ready",
        )
        self.assertEqual(repair_ready.get("status"), "repair-ready", repair_ready)
        repair_ready_saved = json.loads(repair_ready_state.read_text())
        self.assertEqual(repair_ready_saved["tasks"]["task-a"]["verified_pr"], evidence["pr_url"])

        resumed_state, resumed = self._schedule(
            admitted_path,
            admitted,
            repair_ready_state,
            self._single_task_snapshot(),
            "reconcile-pr-repair-resume",
            cap="1",
        )
        self.assertEqual(len(resumed["dispatch"]), 1, resumed)
        repaired_entry = resumed["dispatch"][0]
        self.assertTrue(repaired_entry["repair"], repaired_entry)
        self.assertEqual(repaired_entry["retained_pr"], evidence["pr_url"])
        host.dispatch([repaired_entry])
        repaired_report = host.wait_for_report("task-a")
        repaired_result = make_result(self.github, "task-a", repaired_report, admitted)
        _, delivered, delivered_code = self._apply(
            admitted_path,
            resumed_state,
            "task-a",
            repaired_result,
            "reconcile-pr-repaired",
        )
        self.assertEqual(delivered_code, 0, delivered)
        self.assertEqual(delivered.get("status"), "delivered", delivered)
        self.assertEqual(self.github.prs["task-a"]["pr_url"], evidence["pr_url"])

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
        unknown_state, halted, _ = self._apply(
            admitted_path,
            state,
            "task-a",
            {"outcome": "unknown", "worker": report["worker"]},
            "reconcile-no-pr-unknown",
        )
        self.assertEqual(halted.get("status"), "halted", halted)
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
            "worker_stopped": True,
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
        changed["worker"]["branch"] = "woostack/other"
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
        for label, result in zip(mismatch_cases, variants):
            with self.subTest(label=label):
                variant_state = self.tmp / ("variant-%s-state.json" % label)
                variant_state.write_text(state.read_text(), encoding="utf-8")
                state_out, payload, code = self._apply(
                    admitted_path, variant_state, "task-a", result, "variant-" + label, expect_code=None
                )
                self.assertTrue(state_out.exists(), (label, payload, code))
                saved = json.loads(state_out.read_text())
                self.assertNotEqual(saved["tasks"]["task-a"]["status"], "delivered", (label, payload))
                self.assertEqual(saved["tasks"]["task-a"]["reservation"], self._reservation(dispatch))

        failed_checks = copy.deepcopy(valid)
        failed_checks["checks"]["passed"] = False
        repaired_state, repaired, _ = self._apply(
            admitted_path, state, "task-a", failed_checks, "failed-checks"
        )
        self.assertEqual(repaired.get("status"), "repair-ready", repaired)
        repair_saved = json.loads(repaired_state.read_text())
        self.assertEqual(repair_saved["tasks"]["task-a"]["status"], "repair-ready")

        failed_validation = copy.deepcopy(valid)
        failed_validation["validation"]["verdict"] = "fail"
        validation_state, validation, _ = self._apply(
            admitted_path, state, "task-a", failed_validation, "failed-validation"
        )
        requested_repair = copy.deepcopy(valid)
        requested_repair["outcome"] = "needs-repair"
        requested_state, requested, _ = self._apply(
            admitted_path, state, "task-a", requested_repair, "requested-repair"
        )
        self.assertEqual(requested.get("status"), "repair-ready", requested)
        self.assertEqual(json.loads(requested_state.read_text())["tasks"]["task-a"]["status"], "repair-ready")
        self.assertEqual(validation.get("status"), "repair-ready", validation)
        self.assertEqual(json.loads(validation_state.read_text())["tasks"]["task-a"]["status"], "repair-ready")

    def test_alias_workspace_collision_and_same_parent_repair(self) -> None:
        worktree_root = self.repo / ".woostack" / "worktrees" / "tasks"
        worktree_root.mkdir(parents=True)
        os.symlink(".woostack/worktrees/tasks", self.repo / "alias")
        collision_snapshot = self.github.snapshot()
        collision_snapshot["children"] = collision_snapshot["children"][:2]
        collision_snapshot["children"][1]["workspace"] = "alias/task-a"
        collision_snapshot["expected_index"] = ["task-a", "task-b"]
        admitted_path, admitted = self._admit_issue(collision_snapshot)
        state, scheduled = self._schedule(admitted_path, admitted, None, collision_snapshot, "alias-collision", cap="2")
        self.assertEqual([item["task_id"] for item in scheduled["dispatch"]], ["task-a"], scheduled)
        self.assertTrue(any(item["task_id"] == "task-b" and "collision" in item["reason"] for item in scheduled["blocked"]))
        self.assertTrue(Path(scheduled["dispatch"][0]["workspace"]).is_absolute())

        repair_snapshot = self._single_task_snapshot()
        repair_admitted_path, repair_admitted = self._admit_issue(repair_snapshot)
        repair_state, repair_schedule = self._schedule(
            repair_admitted_path, repair_admitted, None, repair_snapshot, "repair-initial", cap="1"
        )
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
        for label, broken in (
            ("project-status-missing", {k: v for k, v in result.items() if k != "project_status"}),
            ("project-status-wrong", {**result, "project_status": {**result["project_status"], "status": "Todo"}}),
        ):
            with self.subTest(project_gate=label):
                variant_state = self.tmp / (label + ".state.json")
                variant_state.write_text(state.read_text(), encoding="utf-8")
                rejected_state, rejected, _ = self._apply(
                    admitted_path, variant_state, "task-a", broken, label, expect_code=None
                )
                self.assertTrue(rejected_state.exists(), rejected)
                self.assertEqual(
                    json.loads(rejected_state.read_text())["tasks"]["task-a"]["status"],
                    "unknown",
                    rejected,
                )
        delivered_state, delivered, _ = self._apply(admitted_path, state, "task-a", result, "project-delivery")
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

        mismatched_parent = self.github.project_snapshot()
        mismatched_parent["members"][1]["declared_parent"] = self.github.canonical + "/issues/999"
        path = self._write_json("project-parent-mismatch.json", mismatched_parent)
        code, payload = invoke_cli(
            "admit", "--project", mismatched_parent["project"]["url"], "--snapshot", str(path)
        )
        self.assertNotEqual(code, 0, payload)

    def test_project_item_identity_is_required_and_substituted_receipt_halts_dependents(self) -> None:
        base_project = self.github.project_snapshot()
        for label, value in (("missing", None), ("empty", "")):
            broken = copy.deepcopy(base_project)
            if label == "missing":
                broken["members"][1].pop("item_id")
            else:
                broken["members"][1]["item_id"] = value
            path = self._write_json("project-item-%s.json" % label, broken)
            code, payload = invoke_cli(
                "admit", "--project", broken["project"]["url"], "--snapshot", str(path)
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
        project_snapshot["members"].append(dependent)
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
        rejected_state, rejected, _ = self._apply(
            admitted_path,
            variant_state,
            "task-a",
            substituted,
            "project-item-substituted",
            expect_code=None,
        )
        self.assertEqual(rejected.get("status"), "halted", rejected)
        self.assertEqual(rejected.get("reason"), "project-status-mismatch", rejected)
        rejected_saved = json.loads(rejected_state.read_text())
        self.assertEqual(rejected_saved["tasks"]["task-a"]["status"], "unknown")
        self.assertEqual(rejected_saved["tasks"]["task-b"]["status"], "pending")
        self.assertTrue(rejected_saved["halt_new_dispatch"])

        _, halted = self._schedule(
            admitted_path,
            admitted,
            rejected_state,
            project_snapshot,
            "project-item-dependent-blocked",
            cap="1",
        )
        self.assertEqual(halted.get("status"), "halted", halted)
        self.assertEqual(halted.get("reason"), "project-status-mismatch", halted)
        self.assertEqual(halted.get("dispatch"), [], halted)

    def test_existing_delivery_resume_validates_same_evidence_without_duplicate(self) -> None:
        self._seed_prior_delivery("task-a")
        snapshot = self.github.snapshot()
        admitted_path, admitted = self._admit_issue(snapshot)
        state, resumed = self._schedule(admitted_path, admitted, None, snapshot, "resume-valid", cap="1")
        self.assertEqual([entry["task_id"] for entry in resumed["dispatch"]], ["task-b"], resumed)
        saved = json.loads(state.read_text())
        self.assertEqual(saved["tasks"]["task-a"]["status"], "delivered")

        stale = copy.deepcopy(snapshot)
        stale["children"][0]["existing_delivery"]["result"]["readback"]["head_sha"] = self.base_sha
        _, stale_output = self._schedule(admitted_path, admitted, None, stale, "resume-stale", cap="1")
        self.assertIn(stale_output.get("status"), {"halted", "blocked", "snapshot-drift"}, stale_output)
        self.assertEqual(stale_output.get("dispatch"), [], stale_output)


    def test_retained_dependent_cannot_skip_unfinished_prerequisite(self) -> None:
        retained = self._seed_prior_delivery("task-c")
        snapshot = self.github.snapshot()
        admitted_path, admitted = self._admit_issue(snapshot)
        state, output = self._schedule(admitted_path, admitted, None, snapshot, "retained-unready")
        self.assertEqual(output["status"], "halted")
        self.assertEqual(output["reason"], "prerequisites-unmet")
        self.assertEqual(output["dispatch"], [])
        saved = json.loads(state.read_text())
        self.assertEqual(saved["tasks"]["task-c"]["reservation"], retained["reservation"])
        self.assertNotEqual(saved["tasks"]["task-c"]["status"], "delivered")

    def test_retained_dependent_parent_must_contain_verified_prerequisite(self) -> None:
        self._seed_prior_delivery("task-a")
        self._seed_prior_delivery("task-c")
        snapshot = self.github.snapshot()
        admitted_path, admitted = self._admit_issue(snapshot)
        _, output = self._schedule(admitted_path, admitted, None, snapshot, "retained-uncontained")
        self.assertEqual(output["status"], "halted")
        self.assertEqual(output["reason"], "uncontained-prerequisite")
        self.assertEqual(output["dispatch"], [])

    def test_retained_root_cannot_replace_integration_parent(self) -> None:
        git(self.repo, "branch", "other-parent", self.base_sha)
        self._seed_prior_delivery("task-a", "other-parent")
        snapshot = self.github.snapshot()
        admitted_path, admitted = self._admit_issue(snapshot)
        _, output = self._schedule(admitted_path, admitted, None, snapshot, "retained-wrong-parent")
        self.assertEqual(output["status"], "halted")
        self.assertEqual(output["reason"], "unapproved-parent")
        self.assertEqual(output["dispatch"], [])

    def test_retained_delivery_cannot_skip_external_blocker(self) -> None:
        self._seed_prior_delivery("task-a")
        snapshot = self.github.snapshot()
        snapshot["children"][0]["external_prerequisites"] = [self.github.canonical + "/issues/999"]
        admitted_path, admitted = self._admit_issue(snapshot)
        _, output = self._schedule(admitted_path, admitted, None, snapshot, "retained-external")
        self.assertEqual(output["reason"], "external-prerequisite")
        self.assertEqual(output["dispatch"], [])

    def test_retained_dependencies_validate_topologically_not_native_order(self) -> None:
        a = self._seed_prior_delivery("task-a")
        self._seed_prior_delivery("task-c", "woostack/task-a", a["result"]["readback"]["head_sha"])
        snapshot = self.github.snapshot()
        snapshot["children"].sort(key=lambda child: child["task_id"] != "task-c")
        admitted_path, admitted = self._admit_issue(snapshot)
        state, output = self._schedule(admitted_path, admitted, None, snapshot, "retained-out-of-order", cap="1")
        self.assertEqual(output["delivered"], ["task-a", "task-c"])
        self.assertEqual([entry["task_id"] for entry in output["dispatch"]], ["task-b"])

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
