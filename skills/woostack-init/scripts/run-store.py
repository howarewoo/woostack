#!/usr/bin/env python3
"""Owner-only reader for retained local run records. Workflow admission is the caller's job."""

import argparse
from contextlib import ExitStack
try:
    import fcntl
except ModuleNotFoundError as error:
    if error.name != "fcntl":
        raise
    fcntl = None
import json
import os
from pathlib import PurePath
import re
import stat
import subprocess
import sys


FILES = {"manifest": "manifest.json", "spec": "project-spec.md", "plan": "execution-plan.md"}


class StoreError(Exception):
    pass


def require(condition, message):
    if not condition:
        raise StoreError(message)


def require_environment():
    """Reject unsupported readers before opening even the repository directory."""
    for module, names in (
        (fcntl, ("flock", "LOCK_EX")),
        (os, ("O_RDONLY", "O_DIRECTORY", "O_NOFOLLOW", "O_NONBLOCK",
              "open", "close", "fstat", "fdopen", "geteuid", "listdir")),
    ):
        for name in names:
            if module is None or not hasattr(module, name):
                capability = "fcntl" if module is None else f"{module.__name__}.{name}"
                raise StoreError(f"missing {capability}; run in an environment with the required "
                                 "Unix locking, ownership, and no-follow filesystem primitives")
    if os.open not in getattr(os, "supports_dir_fd", ()):
        raise StoreError("missing os.open(dir_fd=...); run in an environment with the required "
                         "Unix locking, ownership, and no-follow filesystem primitives")
    if os.listdir not in getattr(os, "supports_fd", ()):
        raise StoreError("missing os.listdir(fd); run in an environment with the required "
                         "Unix locking, ownership, and no-follow filesystem primitives")



def inode(info):
    return info.st_dev, info.st_ino


def directory(stack, path, parent=None):
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=parent)
    stack.callback(os.close, fd)
    return fd


def repository(stack, root):
    fd = directory(stack, "/")
    for part in PurePath(root).parts[1:]:
        fd = directory(stack, part, fd)
    return fd


def private(info, mode, device, name):
    kind = stat.S_ISDIR if mode == 0o700 else stat.S_ISREG
    require(kind(info.st_mode) and info.st_uid == os.geteuid()
            and stat.S_IMODE(info.st_mode) == mode and info.st_dev == device,
            f"unsafe owner, mode, type, or filesystem: {name}")
    if mode == 0o600:
        require(info.st_nlink == 1, f"hard-linked file: {name}")


def file_bytes(run_fd, name):
    fd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=run_fd)
    with os.fdopen(fd, "rb") as stream:
        before = os.fstat(stream.fileno())
        private(before, 0o600, os.fstat(run_fd).st_dev, name)
        data = stream.read()
        after = os.fstat(stream.fileno())
        private(after, 0o600, os.fstat(run_fd).st_dev, name)
        require((before.st_size, before.st_mtime_ns, before.st_ctime_ns)
                == (after.st_size, after.st_mtime_ns, after.st_ctime_ns),
                f"file changed while reading: {name}")
        return data


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, f"duplicate JSON key: {key}")
        result[key] = value
    return result


def invalid_constant(value):
    raise StoreError(f"non-JSON constant: {value}")


def manifest(data, root, run_id):
    value = json.loads(data.decode("utf-8"), object_pairs_hook=unique_object,
                       parse_constant=invalid_constant)
    require(isinstance(value, dict), "manifest must be a JSON object")
    require(type(value.get("manifestVersion")) is int and value["manifestVersion"] == 1,
            "unsupported manifestVersion; retain the run unchanged")
    require(value.get("runId") == run_id and value.get("repoRoot") == root,
            "manifest runId/repoRoot does not match the exact run/repository")
    revision = value.get("manifestRevision")
    require(type(revision) is int and revision >= 0, "manifestRevision must be a nonnegative integer")
    return value


class RunStore:
    def __init__(self, stack, root, run_id):
        self.root, self.run_id = root, run_id
        self.root_fd = repository(stack, root)
        git_env = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}

        def git(*args):
            result = subprocess.run(["git", "-C", root, *args], env=git_env,
                                    capture_output=True, check=False)
            require(result.returncode == 0, f"Git admission failed: {' '.join(args)}")
            return result.stdout

        require(os.fsdecode(git("rev-parse", "--show-toplevel")).rstrip("\n") == root,
                "--repo must be the canonical Git worktree root")
        git("check-ignore", "--quiet", "--", ".woostack/tmp/")
        require(not git("ls-files", "-z", "--", ".woostack/tmp/"),
                ".woostack/tmp/ contains tracked files")
        self.run_fd = self.open_run(stack)
        self.lock_fd = os.open(".lock", os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK,
                               dir_fd=self.run_fd)
        stack.callback(os.close, self.lock_fd)
        private(os.fstat(self.lock_fd), 0o600, os.fstat(self.run_fd).st_dev, ".lock")
        fcntl.flock(self.lock_fd, fcntl.LOCK_EX)
        self.reopen()

    def open_run(self, stack):
        parent = repository(stack, self.root)
        require(inode(os.fstat(parent)) == inode(os.fstat(self.root_fd)), "repository path changed")
        for part in (".woostack", "tmp", "runs", self.run_id):
            parent = directory(stack, part, parent)
            info = os.fstat(parent)
            require(info.st_uid == os.geteuid() and not (stat.S_IMODE(info.st_mode) & 0o022),
                    f"foreign-owned or group/world-writable directory: {part}")
        private(info, 0o700, os.fstat(self.root_fd).st_dev, self.run_id)
        return parent

    def reopen(self):
        with ExitStack() as stack:
            fd = self.open_run(stack)
            require(inode(os.fstat(fd)) == inode(os.fstat(self.run_fd)), "run directory changed")
            lock = os.open(".lock", os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=fd)
            stack.callback(os.close, lock)
            private(os.fstat(lock), 0o600, os.fstat(fd).st_dev, ".lock")
            require(inode(os.fstat(lock)) == inode(os.fstat(self.lock_fd)), "run lock changed")

    def snapshot(self):
        self.reopen()
        entries = set(os.listdir(self.run_fd))
        unexpected = entries - set(FILES.values()) - {".lock"}
        require(not unexpected, f"unexpected entries; retain for explicit recovery: {sorted(unexpected)}")
        return {name: file_bytes(self.run_fd, name) for name in FILES.values() if name in entries}


def run(args):
    require(".." not in PurePath(args.repo).parts, "repository path traversal is forbidden")
    root = os.path.abspath(args.repo)
    require(re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*", args.run) is not None,
            "run ID must be one exact safe path component")
    with ExitStack() as stack:
        store = RunStore(stack, root, args.run)
        before = store.snapshot()
        require(FILES["manifest"] in before, "manifest missing; retain the run for explicit recovery")
        manifest(before[FILES["manifest"]], root, args.run)
        name = FILES[args.artifact]
        require(name in before, f"artifact not written: {name}")
        return before[name]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", required=True)
    parser.add_argument("--run", required=True)
    reader = parser.add_subparsers(dest="command", required=True).add_parser(
        "read", help="read the exact retained bytes of one admitted artifact")
    reader.add_argument("--artifact", choices=FILES, default="manifest")
    args = parser.parse_args()
    try:
        require_environment()
        sys.stdout.buffer.write(run(args))
        sys.stdout.buffer.flush()
    except (StoreError, OSError, ValueError) as error:
        print(f"run-store: {error}. This reader never creates, changes, or deletes retained data; "
              "resolve the reported condition explicitly instead of replaying an operation.",
              file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
