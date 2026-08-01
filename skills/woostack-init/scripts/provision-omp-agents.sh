#!/usr/bin/env bash
# provision-omp-agents.sh — install woostack's project-scoped OMP role selectors.
set -euo pipefail

exec /usr/bin/env python3 - "$@" <<'PY'
import os
import stat
import sys
import tempfile

ROLES = {
    "woostack-fast": "@smol",
    "woostack-standard": "@default",
    "woostack-deep": "@slow",
}
IGNORE_RULE = "woostack-*.md"
BODY = """You are a general-purpose woostack worker for delegated tasks.

Follow the supplied task contract, repository rules, worktree boundary, and authority constraints. Complete only the assigned work and return concise evidence.
"""


def usage():
    print("usage: provision-omp-agents.sh [--check] [repository]", file=sys.stderr)
    raise SystemExit(2)


def definition(name, role):
    return f'''---
name: {name}
description: General-purpose woostack worker using a host-owned model role
model: "{role}"
---

{BODY}'''


def fail(message):
    print(f"provision-omp-agents.sh: {message}", file=sys.stderr)
    raise SystemExit(1)


def real_directory(path, label):
    try:
        metadata = os.lstat(path)
    except OSError as error:
        fail(f"{label} is inaccessible: {error.strerror}")
    if not stat.S_ISDIR(metadata.st_mode) or os.path.realpath(path) != path:
        fail(f"{label} must be a canonical real directory")


def ensure_directory(parent, name):
    path = os.path.join(parent, name)
    try:
        metadata = os.lstat(path)
    except FileNotFoundError:
        os.mkdir(path, 0o755)
        return path
    except OSError as error:
        fail(f"{path} is inaccessible: {error.strerror}")
    if not stat.S_ISDIR(metadata.st_mode):
        fail(f"{path} must be a real directory")
    return path

def read_regular(path):
    flags = (
        os.O_RDONLY
        | getattr(os, "O_CLOEXEC", 0)
        | getattr(os, "O_NOFOLLOW", 0)
        | getattr(os, "O_NONBLOCK", 0)
    )
    descriptor = os.open(path, flags)
    try:
        if not stat.S_ISREG(os.fstat(descriptor).st_mode):
            raise OSError("not a regular file")
        chunks = []
        while True:
            chunk = os.read(descriptor, 65536)
            if not chunk:
                break
            chunks.append(chunk)
        return b"".join(chunks).decode("utf-8")
    finally:
        os.close(descriptor)


def write_atomic(path, content):
    directory = os.path.dirname(path)
    descriptor, temporary = tempfile.mkstemp(
        prefix=f".{os.path.basename(path)}.", dir=directory, text=True
    )
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="") as destination:
            destination.write(content)
            destination.flush()
            os.fsync(destination.fileno())
        os.chmod(temporary, 0o644)
        os.replace(temporary, path)
    except BaseException:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass
        raise


def ignore_rule_count(raw):
    return sum(line == IGNORE_RULE for line in raw.splitlines())


def normalized_ignore(raw):
    retained = [
        segment
        for segment in raw.splitlines(keepends=True)
        if segment.rstrip("\r\n") != IGNORE_RULE
    ]
    prefix = "".join(retained)
    if prefix and not prefix.endswith(("\n", "\r")):
        prefix += "\n"
    return f"{prefix}{IGNORE_RULE}\n"


def classify(raw, name, role):
    if raw == definition(name, role):
        return None
    if not raw.startswith("---\n") or "\n---\n" not in raw[4:]:
        return "malformed", "managed OMP agent definition has malformed frontmatter"
    header = raw[4:].split("\n---\n", 1)[0]
    fields = {}
    for line in header.splitlines():
        if ":" not in line:
            return "malformed", "managed OMP agent definition has malformed frontmatter"
        key, value = line.split(":", 1)
        fields[key.strip()] = value.strip().strip('"\'')
    if fields.get("name") != name or "model" not in fields:
        return "malformed", "managed OMP agent definition has an invalid name or model field"
    if fields["model"] != role:
        return "wrong-role", f"managed OMP agent must select the host-owned {role} role"
    return "drifted", "managed OMP agent definition differs from the shipped definition"


args = sys.argv[1:]
check = bool(args and args[0] == "--check")
if check:
    args = args[1:]
if len(args) > 1:
    usage()
root = os.path.abspath(args[0] if args else ".")
if os.path.realpath(root) != root:
    fail("repository must be a canonical path without symlink components")
real_directory(root, "repository")
agents = os.path.join(root, ".omp", "agents")

if check:
    directory_status = None
    for directory in (os.path.join(root, ".omp"), agents):
        try:
            metadata = os.lstat(directory)
        except FileNotFoundError:
            directory_status = (
                "missing",
                "project OMP agent directory or managed definition is missing",
            )
            break
        except OSError:
            directory_status = ("malformed", "project OMP agent directory is inaccessible")
            break
        if not stat.S_ISDIR(metadata.st_mode) or os.path.realpath(directory) != directory:
            directory_status = ("malformed", "project OMP agent directory is unsafe")
            break
    if directory_status:
        for name in ROLES:
            path = os.path.join(agents, f"{name}.md")
            print(f"{directory_status[0]}\t{path}\t{directory_status[1]}")
        raise SystemExit(0)
    for name, role in ROLES.items():
        path = os.path.join(agents, f"{name}.md")
        try:
            result = classify(read_regular(path), name, role)
        except FileNotFoundError:
            result = ("missing", "managed OMP agent definition is missing")
        except (OSError, UnicodeError):
            result = ("malformed", "managed OMP agent definition is unreadable or unsafe")
        if result:
            print(f"{result[0]}\t{path}\t{result[1]}")
    ignore_path = os.path.join(agents, ".gitignore")
    try:
        ignore_count = ignore_rule_count(read_regular(ignore_path))
        ignore_result = None if ignore_count == 1 else (
            "drifted",
            "project OMP agent ignore file must contain exactly one standalone woostack-*.md rule",
        )
    except FileNotFoundError:
        ignore_result = ("missing", "project OMP agent ignore file is missing")
    except (OSError, UnicodeError):
        ignore_result = ("malformed", "project OMP agent ignore file is unreadable or unsafe")
    if ignore_result:
        print(f"{ignore_result[0]}\t{ignore_path}\t{ignore_result[1]}")
    raise SystemExit(0)

omp = ensure_directory(root, ".omp")
agents = ensure_directory(omp, "agents")
ignore_path = os.path.join(agents, ".gitignore")
try:
    ignore_raw = read_regular(ignore_path)
except FileNotFoundError:
    ignore_raw = ""
except (OSError, UnicodeError) as error:
    fail(f"{ignore_path} could not be read safely: {error}")

for name, role in ROLES.items():
    path = os.path.join(agents, f"{name}.md")
    wanted = definition(name, role)
    try:
        if read_regular(path) == wanted:
            print(f"preserved\t{path}")
            continue
    except (FileNotFoundError, OSError, UnicodeError):
        pass
    write_atomic(path, wanted)
    print(f"installed\t{path}")

if ignore_rule_count(ignore_raw) == 1:
    print(f"preserved\t{ignore_path}")
else:
    write_atomic(ignore_path, normalized_ignore(ignore_raw))
    print(f"installed\t{ignore_path}")
PY
