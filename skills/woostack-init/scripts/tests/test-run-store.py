#!/usr/bin/env python3
"""Reader regression coverage for run-store.py; only disposable local Git repositories."""

import argparse
import copy
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
RETIRED = (["init"], ["update", "--expected-revision", "1"], ["write-spec"], ["write-plan"])


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
        self.manifest = {
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
        self.spec = b"# Specification\n\nVerified caf\xc3\xa9 requirement.\n"
        self.plan = b"# Plan\n\nOne sequential increment.\n"

    def seed(self, manifest=None, spec=None, plan=None):
        """Write one pre-existing legacy record the reader can admit; no retired writer is used."""
        self.run_dir.mkdir(parents=True, mode=0o700, exist_ok=True)
        for directory in (self.root / ".woostack", self.root / ".woostack/tmp",
                          self.root / ".woostack/tmp/runs", self.run_dir):
            directory.chmod(0o700)
        for name, data in ((".lock", b""), ("manifest.json", manifest),
                           ("project-spec.md", spec), ("execution-plan.md", plan)):
            if data is None:
                continue
            path = self.run_dir / name
            path.write_bytes(data if isinstance(data, bytes) else json.dumps(data).encode())
            path.chmod(0o600)

    def record(self):
        self.seed(self.manifest, self.spec, self.plan)

    def command(self, *args, root=None, run_id=None):
        return [sys.executable, str(HELPER), "--repo", str(root or self.root),
                "--run", run_id or self.run_id, *args]

    def cli(self, *args, success=True, **kwargs):
        result = subprocess.run(self.command(*args, **kwargs), input=b"", capture_output=True, timeout=15)
        if success:
            self.assertEqual(result.returncode, 0, result.stderr.decode())
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout.decode())
        return result.stdout

    def state(self):
        """Retained bytes, mode, and owner per entry; access timestamps are not an immutability oracle."""
        return {path.name: (path.read_bytes(), stat.S_IMODE(path.stat().st_mode), path.stat().st_uid)
                for path in self.run_dir.iterdir()}

    def test_valid_reads_return_the_exact_retained_bytes(self):
        manifest_bytes = json.dumps(self.manifest, indent=2, ensure_ascii=False).encode() + b"\n"
        self.seed(manifest_bytes, self.spec, self.plan)
        before = self.state()
        self.assertEqual(self.cli("read"), manifest_bytes)
        self.assertEqual(self.cli("read", "--artifact", "manifest"), manifest_bytes)
        self.assertEqual(self.cli("read", "--artifact", "spec"), self.spec)
        self.assertEqual(self.cli("read", "--artifact", "plan"), self.plan)
        self.assertEqual(self.state(), before)
        self.assertEqual(stat.S_IMODE(self.run_dir.stat().st_mode), 0o700)

    def test_retired_commands_reject_without_creating_or_changing_files(self):
        self.record()
        before = self.state()
        for arguments in RETIRED:
            with self.subTest(command=" ".join(arguments)):
                result = subprocess.run(self.command(*arguments), input=b'{"manifestVersion": 1}',
                                        capture_output=True, timeout=15)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, b"")
        self.assertEqual(self.state(), before)
        absent = "absent-run"
        for arguments in RETIRED:
            with self.subTest(absent=" ".join(arguments)):
                self.cli(*arguments, run_id=absent, success=False)
        self.assertFalse((self.root / ".woostack/tmp/runs" / absent).exists())

    def test_missing_run_lock_manifest_and_artifact_reject_without_creation(self):
        self.cli("read", success=False)
        self.assertFalse((self.root / ".woostack").exists())
        self.seed()
        (self.run_dir / ".lock").unlink()
        self.cli("read", success=False)
        self.assertEqual(sorted(path.name for path in self.run_dir.iterdir()), [])
        self.seed(None, self.spec)
        before = self.state()
        self.cli("read", success=False)
        self.assertEqual(self.state(), before)
        (self.run_dir / ".lock").unlink()
        self.cli("read", success=False)
        self.assertEqual(sorted(path.name for path in self.run_dir.iterdir()), ["project-spec.md"])
        (self.run_dir / "project-spec.md").unlink()
        self.seed(self.manifest)
        self.assertEqual(json.loads(self.cli("read")), self.manifest)
        self.cli("read", "--artifact", "spec", success=False)
        self.cli("read", "--artifact", "plan", success=False)

    def test_malformed_and_wrong_identity_manifests_reject_without_changes(self):
        cases = {
            "not an object": b"[]",
            "unsupported version": dict(self.manifest, manifestVersion=2),
            "foreign run": dict(self.manifest, runId="other-run"),
            "foreign repository": dict(self.manifest, repoRoot="/somewhere/else"),
            "negative revision": dict(self.manifest, manifestRevision=-1),
            "boolean revision": dict(self.manifest, manifestRevision=True),
            "duplicate key": b'{"manifestVersion":1,"runId":"run-regression","runId":"other-run"}',
            "non-JSON constant": b'{"manifestVersion":NaN}',
            "truncated": b"{\"manifestVersion\": 1,",
        }
        for name, manifest in cases.items():
            with self.subTest(case=name):
                self.seed(manifest, self.spec)
                before = self.state()
                self.cli("read", success=False)
                self.assertEqual(self.state(), before)

    def test_unsafe_run_ids_and_symlinked_repository_reject_without_creation(self):
        self.record()
        before = self.state()
        for run_id in ("../escape", "nested/run", ".", "..", "/absolute", ".hidden"):
            with self.subTest(run_id=run_id):
                self.cli("read", run_id=run_id, success=False)
        alias = self.root.parent / "alias"
        alias.symlink_to(self.root, target_is_directory=True)
        self.cli("read", root=alias, success=False)
        nested = self.root / "nested"
        nested.mkdir()
        self.cli("read", root=nested, success=False)
        self.assertEqual(self.state(), before)

    def test_symlinked_ancestors_reject_without_touching_retained_data(self):
        self.record()
        before = self.state()
        for relative in (".woostack", ".woostack/tmp", ".woostack/tmp/runs",
                         f".woostack/tmp/runs/{self.run_id}"):
            with self.subTest(path=relative):
                original = self.root / relative
                retained = original.with_name(original.name + "-retained")
                original.rename(retained)
                original.symlink_to(retained, target_is_directory=True)
                try:
                    self.cli("read", success=False)
                finally:
                    original.unlink()
                    retained.rename(original)
                self.assertEqual(self.state(), before)

    def test_symlinked_and_hardlinked_entries_reject_without_touching_retained_data(self):
        self.record()
        before = self.state()
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
                        self.assertEqual(retained.read_bytes(), before[name][0])
                    finally:
                        original.unlink()
                        retained.rename(original)
                    self.assertEqual(self.state(), before)

    def test_unsafe_modes_reject_instead_of_being_repaired(self):
        self.record()
        before = self.state()
        for path in [self.run_dir, *self.run_dir.iterdir(), self.root / ".woostack/tmp"]:
            original_mode = stat.S_IMODE(path.stat().st_mode)
            bad_mode = 0o777 if path.is_dir() else 0o644
            with self.subTest(path=path):
                path.chmod(bad_mode)
                try:
                    self.cli("read", success=False)
                    self.assertEqual(stat.S_IMODE(path.stat().st_mode), bad_mode)
                finally:
                    path.chmod(original_mode)
                self.assertEqual(self.state(), before)

    def test_nonregular_and_unexpected_entries_reject_without_cleanup(self):
        self.record()
        before = self.state()
        interrupted = self.run_dir / ".tmp-interrupted"
        interrupted.write_bytes(b"retained interrupted write")
        interrupted.chmod(0o600)
        self.cli("read", success=False)
        self.assertEqual(interrupted.read_bytes(), b"retained interrupted write")
        interrupted.unlink()
        self.assertEqual(self.state(), before)
        (self.run_dir / "project-spec.md").unlink()
        fifo = self.run_dir / "project-spec.md"
        os.mkfifo(fifo, 0o600)
        self.assertEqual(self.cli("read", success=False), b"")
        self.assertTrue(stat.S_ISFIFO(fifo.stat().st_mode))
        fifo.unlink()
        self.seed(None, self.spec)
        self.assertEqual(self.state(), before)
        self.assertEqual(self.cli("read", "--artifact", "spec"), self.spec)

    def test_ignore_and_tracked_store_boundaries_reject(self):
        self.record()
        (self.root / ".gitignore").unlink()
        self.cli("read", success=False)
        (self.root / ".gitignore").write_text(".woostack/tmp/\n", encoding="utf-8")
        subprocess.run(["git", "-C", str(self.root), "add", "-f", ".gitignore",
                        f".woostack/tmp/runs/{self.run_id}/manifest.json"], check=True)
        self.cli("read", success=False)

    def test_file_replaced_while_being_read_is_rejected(self):
        self.record()
        before = self.state()
        target = self.run_dir / "execution-plan.md"
        target_inode = target.stat().st_ino
        real_fstat = os.fstat
        inspected = []

        def replace_after_first_stat(fd):
            info = real_fstat(fd)
            if info.st_ino == target_inode and stat.S_ISREG(info.st_mode):
                inspected.append(info)
                if len(inspected) == 2:
                    with open(target, "r+b") as stream:
                        stream.write(b"# Replaced mid-read\n")
                        stream.truncate()
                    info = real_fstat(fd)
            return info

        args = argparse.Namespace(repo=str(self.root), run=self.run_id, command="read", artifact="plan")
        with patch.object(store.os, "fstat", side_effect=replace_after_first_stat):
            with self.assertRaises(store.StoreError):
                store.run(args)
        self.assertEqual(len(inspected), 2)
        self.assertEqual(target.read_bytes(), b"# Replaced mid-read\n")
        with open(target, "wb") as stream:
            stream.write(before["execution-plan.md"][0])
        target.chmod(0o600)
        self.assertEqual(self.state(), before)
        self.assertEqual(self.cli("read", "--artifact", "plan"), self.plan)

    def test_uninterpreted_workflow_fields_survive_a_read(self):
        existing = copy.deepcopy(self.manifest)
        existing["draft"]["verifiedDecisions"] = {"interface": {"nullable": True}}
        existing["taskGraph"] = {"task-one": {"ordinal": 1, "dependencies": []}}
        self.seed(existing, self.spec, self.plan)
        self.assertEqual(json.loads(self.cli("read")), existing)
        self.assertEqual(self.cli("read", "--artifact", "spec"), self.spec)


if __name__ == "__main__":
    unittest.main()
