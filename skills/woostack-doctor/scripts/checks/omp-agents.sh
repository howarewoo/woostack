#!/usr/bin/env bash
# omp-agents.sh — verify one optional trusted per-engineer launcher directory.
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
  exec /bin/bash "$INSTALLER"
fi

[ "$#" -le 1 ] || {
  echo "omp-agents.sh: usage: omp-agents.sh [workspace]" >&2
  exit 2
}

launcher_root="${WOO_ENGINEER_LAUNCHER_ROOT:-${HOME:-}/.local/libexec/woostack}"
engineer_name="${ENGINEER_NAME:-}"
launcher_dir="$launcher_root/$engineer_name"

if [ -x /usr/bin/python3 ]; then
  python_bin=/usr/bin/python3
else
  python_bin="${WOO_ENGINEER_PYTHON:-}"
fi
case "$python_bin" in
  /*) ;;
  *)
    emit warn omp-agents auto "$launcher_dir" \
      "an absolute trusted Python interpreter is required to verify the reviewed launchers"
    exit 0
    ;;
esac

manifest="$(mktemp)" || exit 1
trap 'rm -f "$manifest"' EXIT
if ! /bin/bash "$INSTALLER" --manifest >"$manifest"; then
  emit warn omp-agents auto "$INSTALLER" \
    "the reviewed launcher manifest could not be computed"
  exit 0
fi

"$python_bin" - "$launcher_root" "$engineer_name" "$manifest" <<'PY'
import hashlib
import os
import re
import stat
import sys

launcher_root = os.fsencode(sys.argv[1])
engineer_name_text = sys.argv[2]
manifest_path = sys.argv[3]
profile_re = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]{0,63}")


def render(path):
    return os.fsdecode(path).replace("\t", "?").replace("\n", "?")


def emit(path, message, fixable="auto"):
    print(f"warn\tomp-agents\t{fixable}\t{render(path)}\t{message}")


def signature(metadata):
    return (
        metadata.st_dev,
        metadata.st_ino,
        metadata.st_mode,
        metadata.st_uid,
        metadata.st_gid,
        metadata.st_size,
        getattr(metadata, "st_mtime_ns", int(metadata.st_mtime * 1_000_000_000)),
        getattr(metadata, "st_ctime_ns", int(metadata.st_ctime * 1_000_000_000)),
    )



try:
    with open(manifest_path, "r", encoding="ascii") as handle:
        expected = [line.rstrip("\n").split("\t", 1) for line in handle]
    if (
        not expected
        or any(len(row) != 2 for row in expected)
        or {row[0] for row in expected}
        != {"launch-omp", "bind-engineer-unit"}
        or any(re.fullmatch(r"[0-9a-f]{64}", row[1]) is None for row in expected)
    ):
        raise ValueError("invalid reviewed manifest")
except (OSError, UnicodeError, ValueError):
    emit(os.fsencode(manifest_path), "the reviewed launcher manifest is unreadable")
    raise SystemExit(0)

if profile_re.fullmatch(engineer_name_text) is None:
    emit(launcher_root, "ENGINEER_NAME must identify the per-engineer launcher directory before check or repair")
    raise SystemExit(0)
engineer_name = os.fsencode(engineer_name_text)
launcher_dir = os.path.join(launcher_root, engineer_name)


def canonical(path):
    return (
        bool(path)
        and os.path.isabs(path)
        and os.path.normpath(path) == path
        and os.path.realpath(path) == path
    )


def open_checked_directory(path, description):
    if not canonical(path):
        emit(path, f"{description} must be canonical, absolute, and contain no symlink components")
        return None
    try:
        before = os.lstat(path)
    except FileNotFoundError:
        emit(path, f"{description} is missing; --fix reinstalls it")
        return None
    except OSError:
        emit(path, f"{description} is inaccessible; --fix reinstalls it")
        return None
    if not stat.S_ISDIR(before.st_mode):
        emit(path, f"{description} must be a real no-follow directory; --fix reinstalls it")
        return None
    if before.st_uid != os.geteuid():
        emit(path, f"{description} owner differs from the invoking user; repair ownership before use")
    directory_mode = stat.S_IMODE(before.st_mode)
    if directory_mode != 0o700:
        emit(path, f"{description} mode is {directory_mode:04o}, expected 0700; --fix reinstalls it")
    flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0)
    flags |= getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0)
    try:
        directory_fd = os.open(path, flags)
    except OSError:
        emit(path, f"{description} could not be opened safely; --fix reinstalls it")
        return None
    after = os.fstat(directory_fd)
    if signature(after) != signature(before):
        os.close(directory_fd)
        emit(path, f"{description} changed while it was checked; --fix reinstalls it")
        return None
    return directory_fd


root_fd = open_checked_directory(launcher_root, "reviewed launcher root")
if root_fd is None:
    for name, _ in expected:
        emit(
            os.path.join(launcher_dir, os.fsencode(name)),
            "reviewed launcher is missing; --fix reinstalls it",
        )
    raise SystemExit(0)

try:
    try:
        unit_before = os.stat(engineer_name, dir_fd=root_fd, follow_symlinks=False)
    except FileNotFoundError:
        emit(launcher_dir, "reviewed per-engineer launcher directory is missing; --fix reinstalls it")
        for name, _ in expected:
            emit(
                os.path.join(launcher_dir, os.fsencode(name)),
                "reviewed launcher is missing; --fix reinstalls it",
            )
        raise SystemExit(0)
    except OSError:
        emit(launcher_dir, "reviewed per-engineer launcher directory is inaccessible; --fix reinstalls it")
        raise SystemExit(0)
    if not stat.S_ISDIR(unit_before.st_mode):
        emit(launcher_dir, "reviewed per-engineer launcher directory must be real and no-follow; --fix reinstalls it")
        raise SystemExit(0)
    if unit_before.st_uid != os.geteuid():
        emit(launcher_dir, "reviewed per-engineer launcher directory owner differs from the invoking user")
    unit_mode = stat.S_IMODE(unit_before.st_mode)
    if unit_mode != 0o700:
        emit(
            launcher_dir,
            f"reviewed per-engineer launcher directory mode is {unit_mode:04o}, expected 0700; --fix reinstalls it",
        )
    flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0)
    flags |= getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0)
    try:
        unit_fd = os.open(engineer_name, flags, dir_fd=root_fd)
    except OSError:
        emit(launcher_dir, "reviewed per-engineer launcher directory could not be opened safely")
        raise SystemExit(0)
    if signature(os.fstat(unit_fd)) != signature(unit_before):
        os.close(unit_fd)
        emit(launcher_dir, "reviewed per-engineer launcher directory changed while it was checked")
        raise SystemExit(0)
finally:
    os.close(root_fd)

try:
    for name, wanted_hash in expected:
        encoded_name = os.fsencode(name)
        path = os.path.join(launcher_dir, encoded_name)
        try:
            before = os.stat(encoded_name, dir_fd=unit_fd, follow_symlinks=False)
        except FileNotFoundError:
            emit(path, "reviewed launcher is missing; --fix reinstalls it")
            continue
        except OSError:
            emit(path, "reviewed launcher is inaccessible; --fix reinstalls it")
            continue
        if not stat.S_ISREG(before.st_mode):
            emit(path, "reviewed launcher must be a regular no-follow file; --fix reinstalls it")
            continue
        if before.st_uid != os.geteuid():
            emit(path, "reviewed launcher owner differs from the invoking user; repair ownership before use")
        actual_mode = stat.S_IMODE(before.st_mode)
        if actual_mode != 0o500:
            emit(path, f"reviewed launcher mode is {actual_mode:04o}, expected 0500; --fix reinstalls it")
        flags = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0)
        try:
            fd = os.open(encoded_name, flags, dir_fd=unit_fd)
        except OSError:
            emit(path, "reviewed launcher could not be opened without following links; --fix reinstalls it")
            continue
        digest = hashlib.sha256()
        safe = True
        wanted_signature = signature(before)
        try:
            if signature(os.fstat(fd)) != wanted_signature:
                safe = False
            else:
                while True:
                    chunk = os.read(fd, 1024 * 1024)
                    if not chunk:
                        break
                    digest.update(chunk)
                if signature(os.fstat(fd)) != wanted_signature:
                    safe = False
        finally:
            os.close(fd)
        try:
            entry_after = os.stat(encoded_name, dir_fd=unit_fd, follow_symlinks=False)
        except OSError:
            safe = False
        else:
            if signature(entry_after) != wanted_signature:
                safe = False
        if not safe:
            emit(path, "reviewed launcher changed while it was checked; --fix reinstalls it")
        elif digest.hexdigest() != wanted_hash:
            emit(path, "reviewed launcher checksum differs from the installed source; --fix reinstalls it")

    retired_name = b"launch-hermes-review"
    retired_path = os.path.join(launcher_dir, retired_name)
    try:
        os.stat(retired_name, dir_fd=unit_fd, follow_symlinks=False)
    except FileNotFoundError:
        pass
    except OSError:
        emit(retired_path, "retired reviewer launcher is inaccessible; --fix removes it")
    else:
        emit(retired_path, "retired reviewer launcher is present; --fix removes it")

    authority_name = b"unit-authority.json"
    authority_path = os.path.join(launcher_dir, authority_name)
    try:
        authority = os.stat(authority_name, dir_fd=unit_fd, follow_symlinks=False)
    except FileNotFoundError:
        pass
    except OSError:
        emit(authority_path, "bound unit authority is inaccessible and must not be used", "report")
    else:
        if not stat.S_ISREG(authority.st_mode):
            emit(authority_path, "bound unit authority must be a regular no-follow file", "report")
        else:
            if authority.st_uid != os.geteuid():
                emit(authority_path, "bound unit authority owner differs from the invoking user", "report")
            authority_mode = stat.S_IMODE(authority.st_mode)
            if authority_mode != 0o400:
                emit(authority_path, f"bound unit authority mode is {authority_mode:04o}, expected 0400", "report")
finally:
    os.close(unit_fd)
PY
