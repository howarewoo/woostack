#!/usr/bin/env bash
# omp-agents.sh — verify the optional fixed host engineer launchers.
# The historical check name is retained; project .omp/agents are never generated.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="$HERE/../../../woostack-init/scripts/gen-omp-agents.sh"
emit() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"; }

if [ "${1:-}" = "--fix" ]; then
  shift
  [ "$#" -le 1 ] || {
    echo "omp-agents.sh: usage: omp-agents.sh [--fix [workspace]]" >&2
    exit 2
  }
  exec bash "$INSTALLER"
fi

[ "$#" -le 1 ] || {
  echo "omp-agents.sh: usage: omp-agents.sh [workspace]" >&2
  exit 2
}

if ! command -v python3 >/dev/null 2>&1; then
  emit warn omp-agents auto "${WOO_ENGINEER_LAUNCHER_DIR:-${HOME:-}/.local/libexec/woostack}" \
    "python3 is required to verify the reviewed engineer launchers"
  exit 0
fi

manifest="$(mktemp)" || exit 1
trap 'rm -f "$manifest"' EXIT
if ! bash "$INSTALLER" --manifest >"$manifest"; then
  emit warn omp-agents auto "$INSTALLER" \
    "the reviewed launcher manifest could not be computed"
  exit 0
fi

python3 - "$manifest" <<'PY'
import hashlib
import os
import stat
import sys

configured = os.environ.get("WOO_ENGINEER_LAUNCHER_DIR")
if configured is None:
    home = os.environ.get("HOME") or os.path.expanduser("~")
    configured = os.path.join(home, ".local", "libexec", "woostack")
launcher_dir = os.fsencode(configured)
manifest_path = sys.argv[1]


def emit(path, message):
    rendered = os.fsdecode(path).replace("\t", "?").replace("\n", "?")
    print(f"warn\tomp-agents\tauto\t{rendered}\t{message}")


if (
    not launcher_dir
    or b"\0" in launcher_dir
    or not os.path.isabs(launcher_dir)
    or os.path.normpath(launcher_dir) != launcher_dir
    or os.path.realpath(launcher_dir) != launcher_dir
):
    emit(launcher_dir, "reviewed launcher directory must be a canonical absolute path; --fix uses the same requirement")
    raise SystemExit(0)

try:
    with open(manifest_path, "r", encoding="ascii") as handle:
        expected = [line.rstrip("\n").split("\t", 1) for line in handle]
except (OSError, UnicodeError, ValueError):
    emit(os.fsencode(manifest_path), "the reviewed launcher manifest is unreadable")
    raise SystemExit(0)

try:
    directory_before = os.lstat(launcher_dir)
except FileNotFoundError:
    emit(launcher_dir, "reviewed launcher directory is missing; --fix reinstalls it")
    for name, _ in expected:
        emit(
            os.path.join(launcher_dir, os.fsencode(name)),
            "reviewed launcher is missing; --fix reinstalls it",
        )
    raise SystemExit(0)
except OSError:
    emit(launcher_dir, "reviewed launcher directory is inaccessible; --fix reinstalls it")
    raise SystemExit(0)

if not stat.S_ISDIR(directory_before.st_mode):
    emit(
        launcher_dir,
        "reviewed launcher directory must be a real no-follow directory; --fix reinstalls it",
    )
    raise SystemExit(0)
directory_mode = stat.S_IMODE(directory_before.st_mode)
if directory_mode != 0o700:
    emit(
        launcher_dir,
        f"reviewed launcher directory mode is {directory_mode:04o}, expected 0700; --fix reinstalls it",
    )

directory_flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0)
directory_flags |= getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0)
try:
    directory_fd = os.open(launcher_dir, directory_flags)
except OSError:
    emit(launcher_dir, "reviewed launcher directory could not be opened safely; --fix reinstalls it")
    raise SystemExit(0)
directory_after = os.fstat(directory_fd)
if (directory_after.st_dev, directory_after.st_ino) != (
    directory_before.st_dev,
    directory_before.st_ino,
):
    os.close(directory_fd)
    emit(launcher_dir, "reviewed launcher directory changed while it was checked; --fix reinstalls it")
    raise SystemExit(0)

try:
    for name, wanted_hash in expected:
        encoded_name = os.fsencode(name)
        path = os.path.join(launcher_dir, encoded_name)
        try:
            before = os.stat(encoded_name, dir_fd=directory_fd, follow_symlinks=False)
        except FileNotFoundError:
            emit(path, "reviewed launcher is missing; --fix reinstalls it")
            continue
        except OSError:
            emit(path, "reviewed launcher is inaccessible; --fix reinstalls it")
            continue

        if not stat.S_ISREG(before.st_mode):
            emit(path, "reviewed launcher must be a regular no-follow file; --fix reinstalls it")
            continue

        actual_mode = stat.S_IMODE(before.st_mode)
        if actual_mode != 0o500:
            emit(
                path,
                f"reviewed launcher mode is {actual_mode:04o}, expected 0500; --fix reinstalls it",
            )

        flags = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0)
        try:
            fd = os.open(encoded_name, flags, dir_fd=directory_fd)
        except OSError:
            emit(path, "reviewed launcher could not be opened without following links; --fix reinstalls it")
            continue
        digest = hashlib.sha256()
        safe = True
        try:
            after = os.fstat(fd)
            if (after.st_dev, after.st_ino) != (before.st_dev, before.st_ino):
                safe = False
            else:
                while True:
                    chunk = os.read(fd, 1024 * 1024)
                    if not chunk:
                        break
                    digest.update(chunk)
        finally:
            os.close(fd)
        if not safe:
            emit(path, "reviewed launcher changed while it was checked; --fix reinstalls it")
        elif digest.hexdigest() != wanted_hash:
            emit(path, "reviewed launcher checksum differs from the installed source; --fix reinstalls it")
finally:
    os.close(directory_fd)
PY
