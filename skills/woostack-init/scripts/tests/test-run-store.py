#!/usr/bin/env python3
"""Behavioral regression coverage for run-store.py; only disposable local Git repositories."""

import argparse
import copy
import errno
from concurrent.futures import ThreadPoolExecutor
import importlib.util
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


HELPER = Path(__file__).resolve().parents[1] / "run-store.py"
spec = importlib.util.spec_from_file_location("run_store", HELPER)
store = importlib.util.module_from_spec(spec)
spec.loader.exec_module(store)


class RunStoreTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="woostack-run-store-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve() / "repo"
        self.root.mkdir()
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        (self.root / ".gitignore").write_text(".woostack/tmp/\n", encoding="utf-8")
        self.run_id = "run-regression"
        self.run_dir = self.root / ".woostack/tmp/runs" / self.run_id
        self.initial = {
            "manifestVersion": 1,
            "manifestRevision": 1,
            "runId": self.run_id,
            "repoRoot": str(self.root),
            "canonicalRepository": "https://github.com/example/product",
            "workflow": "build",
            "status": "drafting",
            "planningParentBranch": "refs/heads/main",
            "planningParentTip": "observed-parent-tip",
            "draft": {"specification": "User-verified content", "unresolvedQuestions": ["Open decision"]},
            "stableTaskMappings": {},
            "taskExecutions": {},
        }

    def command(self, *args, root=None, run_id=None):
        return [sys.executable, str(HELPER), "--repo", str(root or self.root),
                "--run", run_id or self.run_id, *args]

    def cli(self, *args, data=b"", success=True, **kwargs):
        if isinstance(data, dict):
            data = json.dumps(data).encode()
        result = subprocess.run(self.command(*args, **kwargs), input=data, capture_output=True, timeout=15)
        if success:
            self.assertEqual(result.returncode, 0, result.stderr.decode())
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout.decode())
        return result.stdout

    def initialize(self):
        self.assertEqual(json.loads(self.cli("init", data=self.initial)), self.initial)

    def next_manifest(self):
        result = copy.deepcopy(self.initial)
        result["manifestRevision"] += 1
        result["draft"]["unresolvedQuestions"] = []
        return result

    def persisted(self):
        return {path.name: path.read_bytes() for path in self.run_dir.iterdir() if path.is_file()}

    def test_real_round_trip_and_retained_final_artifacts(self):
        previous_umask = os.umask(0o777)
        try:
            self.initialize()
        finally:
            os.umask(previous_umask)
        self.assertEqual(json.loads(self.cli("read")), self.initial)
        replacement = self.next_manifest()
        self.assertEqual(json.loads(self.cli("update", "--expected-revision", "1", data=replacement)), replacement)
        artifacts = {"spec": "# Specification\n\nVerified café requirement.\n".encode(),
                     "plan": b"# Plan\n\nOne sequential increment.\n"}
        for kind, content in artifacts.items():
            self.assertEqual(self.cli(f"write-{kind}", data=content), content)
            self.assertEqual(self.cli("read", "--artifact", kind), content)
        replacement["manifestRevision"] = 3
        replacement["status"] = "abandoned"
        self.cli("update", "--expected-revision", "2", data=replacement)
        self.assertEqual(json.loads(self.cli("read")), replacement)
        for kind, content in artifacts.items():
            self.assertEqual(self.cli("read", "--artifact", kind), content)
        self.assertEqual(stat.S_IMODE(self.run_dir.stat().st_mode), 0o700)
        self.assertEqual(set(self.persisted()), {"manifest.json", ".lock", "project-spec.md", "execution-plan.md"})
        for entry in self.run_dir.iterdir():
            self.assertEqual(stat.S_IMODE(entry.stat().st_mode), 0o600)
            self.assertEqual(entry.stat().st_uid, os.geteuid())

    def test_existing_manifest_and_uninterpreted_workflow_fields_survive(self):
        self.run_dir.mkdir(parents=True, mode=0o700)
        existing = copy.deepcopy(self.initial)
        existing["draft"]["verifiedDecisions"] = {"interface": {"nullable": True}}
        existing["taskGraph"] = {"task-one": {"ordinal": 1, "dependencies": []}}
        for name, data in ((".lock", b""), ("manifest.json", json.dumps(existing).encode())):
            path = self.run_dir / name
            path.write_bytes(data)
            path.chmod(0o600)
        self.assertEqual(json.loads(self.cli("read")), existing)
        existing["manifestRevision"] = 2
        self.cli("update", "--expected-revision", "1", data=existing)
        self.assertEqual(json.loads(self.cli("read")), existing)

    def test_stale_revision_and_nonmonotonic_replacements_preserve_bytes(self):
        self.initialize()
        before = self.persisted()
        for expected, revision in ((0, 1), (2, 3), (1, 1), (1, 3), (1, True)):
            with self.subTest(expected=expected, revision=revision):
                replacement = self.next_manifest()
                replacement["manifestRevision"] = revision
                self.cli("update", "--expected-revision", str(expected), data=replacement, success=False)
                self.assertEqual(self.persisted(), before)

    def test_immutable_identity_and_unsupported_schema_preserve_bytes(self):
        self.initialize()
        before = self.persisted()
        for key, value in (("runId", "other-run"), ("repoRoot", str(self.root.parent)),
                           ("canonicalRepository", "https://github.com/foreign/repo"),
                           ("workflow", "fix"), ("manifestVersion", 2)):
            with self.subTest(key=key):
                replacement = self.next_manifest()
                replacement[key] = value
                self.cli("update", "--expected-revision", "1", data=replacement, success=False)
                self.assertEqual(self.persisted(), before)
        replacement = self.next_manifest()
        del replacement["canonicalRepository"]
        self.cli("update", "--expected-revision", "1", data=replacement, success=False)
        self.assertEqual(self.persisted(), before)

    def test_final_files_and_initial_manifest_are_write_once(self):
        self.initialize()
        for kind in ("spec", "plan"):
            content = f"# Final {kind}\n".encode()
            self.cli(f"write-{kind}", data=content)
            before = self.persisted()
            self.cli(f"write-{kind}", data=b"# Different content\n", success=False)
            self.cli(f"write-{kind}", data=content, success=False)
            self.assertEqual(self.persisted(), before)
        before = self.persisted()
        self.cli("init", data=self.initial, success=False)
        self.assertEqual(self.persisted(), before)
        (self.run_dir / ".lock").unlink()
        del before[".lock"]
        self.cli("init", data=self.initial, success=False)
        self.assertEqual(self.persisted(), before)

    def test_concurrent_checkpoint_writers_have_one_winner(self):
        self.initialize()
        writers = []
        for index in range(8):
            replacement = self.next_manifest()
            replacement["draft"]["specification"] = f"Writer {index} " + "x" * 65536
            process = subprocess.Popen(self.command("update", "--expected-revision", "1"),
                                       stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            writers.append((process, replacement))
        # Each process receives the same expected revision, regardless of scheduling.
        with ThreadPoolExecutor(max_workers=len(writers)) as pool:
            results = list(pool.map(lambda pair: pair[0].communicate(json.dumps(pair[1]).encode(), timeout=15), writers))
        winners = [(replacement, result) for (process, replacement), result in zip(writers, results)
                   if process.returncode == 0]
        self.assertEqual(len(winners), 1, results)
        self.assertEqual(json.loads(self.cli("read")), winners[0][0])
        self.assertEqual(json.loads(winners[0][1][0]), winners[0][0])
        self.assertEqual(set(self.persisted()), {"manifest.json", ".lock"})

    def test_concurrent_final_writes_never_replace_the_winner(self):
        self.initialize()
        writers = [(subprocess.Popen(self.command("write-spec"), stdin=subprocess.PIPE,
                                     stdout=subprocess.PIPE, stderr=subprocess.PIPE), data)
                   for data in (b"# First\n" * 8192, b"# Second\n" * 8192)]
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(lambda pair: pair[0].communicate(pair[1], timeout=15), writers))
        winners = [(data, result) for (process, data), result in zip(writers, results) if process.returncode == 0]
        self.assertEqual(len(winners), 1, results)
        self.assertEqual(self.cli("read", "--artifact", "spec"), winners[0][0])
        self.assertEqual(winners[0][1][0], winners[0][0])

    def test_run_traversal_and_symlinked_repository_fail_without_creation(self):
        for run_id in ("../escape", "nested/run", ".", "..", "/absolute"):
            with self.subTest(run_id=run_id):
                invalid = dict(self.initial, runId=run_id)
                self.cli("init", run_id=run_id, data=invalid, success=False)
        alias = self.root.parent / "alias"
        alias.symlink_to(self.root, target_is_directory=True)
        invalid = dict(self.initial, repoRoot=str(alias))
        self.cli("init", root=alias, data=invalid, success=False)
        self.assertFalse((self.root / ".woostack").exists())

    def test_symlinked_ancestors_fail_without_touching_retained_data(self):
        self.initialize()
        before = self.persisted()
        for relative in (".woostack", ".woostack/tmp", ".woostack/tmp/runs", f".woostack/tmp/runs/{self.run_id}"):
            with self.subTest(path=relative):
                original = self.root / relative
                retained = original.with_name(original.name + "-retained")
                original.rename(retained)
                original.symlink_to(retained, target_is_directory=True)
                try:
                    self.cli("read", success=False)
                    self.cli("update", "--expected-revision", "1", data=self.next_manifest(), success=False)
                finally:
                    original.unlink()
                    retained.rename(original)
                self.assertEqual(self.persisted(), before)

    def test_symlinked_and_hardlinked_files_are_not_admitted(self):
        self.initialize()
        self.cli("write-spec", data=b"# Specification\n")
        self.cli("write-plan", data=b"# Plan\n")
        before = self.persisted()
        for name in before:
            for hardlink in (False, True):
                with self.subTest(name=name, hardlink=hardlink):
                    original = self.run_dir / name
                    retained = self.root.parent / "retained-file"
                    original.rename(retained)
                    if hardlink:
                        os.link(retained, original)
                    else:
                        original.symlink_to(retained)
                    try:
                        self.cli("read", success=False)
                        self.cli("update", "--expected-revision", "1", data=self.next_manifest(), success=False)
                        self.assertEqual(retained.read_bytes(), before[name])
                    finally:
                        original.unlink()
                        retained.rename(original)
                    self.assertEqual(self.persisted(), before)

    def test_permissions_are_rejected_not_silently_repaired(self):
        self.initialize()
        self.cli("write-spec", data=b"# Specification\n")
        self.cli("write-plan", data=b"# Plan\n")
        before = self.persisted()
        for path in [self.run_dir, *self.run_dir.iterdir(), self.root / ".woostack/tmp"]:
            original_mode = stat.S_IMODE(path.stat().st_mode)
            bad_mode = 0o777 if path.is_dir() else 0o644
            with self.subTest(path=path):
                path.chmod(bad_mode)
                try:
                    self.cli("read", success=False)
                    self.cli("update", "--expected-revision", "1", data=self.next_manifest(), success=False)
                    self.assertEqual(stat.S_IMODE(path.stat().st_mode), bad_mode)
                finally:
                    path.chmod(original_mode)
                self.assertEqual(self.persisted(), before)

    def test_nonregular_files_and_unknown_entries_block_without_cleanup(self):
        self.initialize()
        original = (self.run_dir / "manifest.json").read_bytes()
        extra = self.run_dir / ".tmp-interrupted"
        extra.write_bytes(b"retained interrupted write")
        extra.chmod(0o600)
        self.cli("read", success=False)
        self.assertEqual(extra.read_bytes(), b"retained interrupted write")
        extra.unlink()
        fifo = self.run_dir / "project-spec.md"
        os.mkfifo(fifo, 0o600)
        self.cli("read", success=False)
        self.assertTrue(stat.S_ISFIFO(fifo.stat().st_mode))
        self.assertEqual((self.run_dir / "manifest.json").read_bytes(), original)

    def test_ignore_and_tracked_run_boundaries(self):
        (self.root / ".gitignore").unlink()
        self.cli("init", data=self.initial, success=False)
        self.assertFalse((self.root / ".woostack").exists())
        (self.root / ".gitignore").write_text(".woostack/tmp/\n", encoding="utf-8")
        self.initialize()
        before = self.persisted()
        subprocess.run(["git", "-C", str(self.root), "add", "-f", ".woostack/tmp/runs/run-regression/manifest.json"], check=True)
        self.cli("update", "--expected-revision", "1", data=self.next_manifest(), success=False)
        self.assertEqual(self.persisted(), before)

    def test_write_failure_keeps_old_bytes_and_removes_only_own_temporary(self):
        self.initialize()
        before = self.persisted()
        args = argparse.Namespace(repo=str(self.root), run=self.run_id, command="update", expected_revision=1)
        real_fsync = os.fsync

        def fail_file_flush(fd):
            if stat.S_ISREG(os.fstat(fd).st_mode):
                raise OSError(errno.EIO, "injected file flush failure")
            return real_fsync(fd)

        with patch.object(store.os, "fsync", side_effect=fail_file_flush):
            with self.assertRaises(OSError):
                store.run(args, json.dumps(self.next_manifest()).encode())
        self.assertEqual(self.persisted(), before)
        self.assertEqual(json.loads(self.cli("read")), self.initial)

    def test_unknown_post_rename_failure_is_recovered_by_read_not_replay(self):
        self.initialize()
        self.cli("write-plan", data=b"# Retained plan\n")
        args = argparse.Namespace(repo=str(self.root), run=self.run_id, command="write-spec")
        real_fsync = os.fsync
        content = b"# Final specification\n"

        def fail_committed_directory_flush(fd):
            if stat.S_ISDIR(os.fstat(fd).st_mode) and (self.run_dir / "project-spec.md").exists():
                raise OSError(errno.EIO, "injected post-rename directory flush failure")
            return real_fsync(fd)

        with patch.object(store.os, "fsync", side_effect=fail_committed_directory_flush):
            with self.assertRaises(OSError):
                store.run(args, content)
        self.assertEqual(self.cli("read", "--artifact", "spec"), content)
        self.assertEqual(self.cli("read", "--artifact", "plan"), b"# Retained plan\n")
        self.cli("write-spec", data=b"# Blind replay\n", success=False)
        self.assertEqual(self.cli("read", "--artifact", "spec"), content)
        self.assertEqual(json.loads(self.cli("read")), self.initial)


if __name__ == "__main__":
    unittest.main()
