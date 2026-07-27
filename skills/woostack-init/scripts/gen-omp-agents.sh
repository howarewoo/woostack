#!/usr/bin/env bash
# gen-omp-agents.sh — install the fixed host-side engineer launchers.
#
# The historical filename is retained so existing init/doctor entry points keep one
# installation authority. It deliberately does not generate project .omp/agents.
set -euo pipefail

command -v python3 >/dev/null 2>&1 || {
  echo "gen-omp-agents.sh: python3 is required" >&2
  exit 127
}

exec python3 - "$@" <<'PY'
import hashlib
import os
import secrets
import stat
import sys

LAUNCHER_TEMPLATE = r'''#!/usr/bin/env python3
# Installed by woostack-init/scripts/gen-omp-agents.sh. Do not edit in place.
import os
import re
import stat
import sys

MODE = b"@@MODE@@"
LABEL = b"@@LABEL@@"
PROFILE_RE = re.compile(rb"[A-Za-z0-9][A-Za-z0-9._-]{0,63}")
SESSION_RE = re.compile(rb"[A-Za-z0-9][A-Za-z0-9._:-]{0,255}")
SAFE_ENV_KEYS = frozenset(
    {
        b"CLICOLOR",
        b"CLICOLOR_FORCE",
        b"COLORTERM",
        b"FORCE_COLOR",
        b"LANG",
        b"LANGUAGE",
        b"LOGNAME",
        b"NO_COLOR",
        b"PATH",
        b"SHELL",
        b"SSL_CERT_DIR",
        b"SSL_CERT_FILE",
        b"TERM",
        b"TERMINFO",
        b"TERMINFO_DIRS",
        b"TERM_PROGRAM",
        b"TERM_PROGRAM_VERSION",
        b"USER",
    }
)


def die(message, code=64):
    os.write(2, LABEL + b": " + message + b"\n")
    raise SystemExit(code)


def exact_mode(metadata):
    return stat.S_IMODE(metadata.st_mode)


def read_staged(dispatch_fd, name):
    try:
        before = os.stat(name, dir_fd=dispatch_fd, follow_symlinks=False)
    except OSError:
        die(b"required staged file is missing or inaccessible")
    if not stat.S_ISREG(before.st_mode):
        die(b"staged inputs must be regular no-follow files")
    if before.st_uid != os.geteuid():
        die(b"staged inputs must be owned by the invoking user")
    if exact_mode(before) != 0o600:
        die(b"staged inputs must have mode 0600")

    flags = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0)
    try:
        fd = os.open(name, flags, dir_fd=dispatch_fd)
    except OSError:
        die(b"required staged file is missing or inaccessible")
    try:
        after = os.fstat(fd)
        if (after.st_dev, after.st_ino) != (before.st_dev, before.st_ino):
            die(b"staged input changed while it was opened")
        if (
            not stat.S_ISREG(after.st_mode)
            or after.st_uid != os.geteuid()
            or exact_mode(after) != 0o600
        ):
            die(b"staged input ownership or mode changed while it was opened")
        chunks = []
        while True:
            chunk = os.read(fd, 1024 * 1024)
            if not chunk:
                break
            chunks.append(chunk)
    finally:
        os.close(fd)

    value = b"".join(chunks)
    if b"\0" in value:
        die(b"staged inputs may not contain NUL bytes")
    return value


def validated_dispatch():
    dispatch_path = os.getcwdb()
    if not os.path.isabs(dispatch_path) or os.path.realpath(dispatch_path) != dispatch_path:
        die(b"dispatch directory must be canonical and absolute")
    flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_CLOEXEC", 0)
    flags |= getattr(os, "O_NOFOLLOW", 0)
    try:
        dispatch_fd = os.open(b".", flags)
    except OSError:
        die(b"dispatch directory is inaccessible")
    metadata = os.fstat(dispatch_fd)
    if not stat.S_ISDIR(metadata.st_mode):
        os.close(dispatch_fd)
        die(b"dispatch path must be a directory")
    if metadata.st_uid != os.geteuid():
        os.close(dispatch_fd)
        die(b"dispatch directory must be owned by the invoking user")
    if exact_mode(metadata) != 0o700:
        os.close(dispatch_fd)
        die(b"dispatch directory must have mode 0700")
    return dispatch_fd


def validate_repo(repo):
    if not repo or not os.path.isabs(repo):
        die(b"repo must be an absolute directory")
    if os.path.normpath(repo) != repo or os.path.realpath(repo) != repo:
        die(b"repo must be a canonical no-symlink path")
    flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_CLOEXEC", 0)
    flags |= getattr(os, "O_NOFOLLOW", 0)
    try:
        repo_fd = os.open(repo, flags)
    except OSError:
        die(b"repo must be an existing canonical directory")
    if not stat.S_ISDIR(os.fstat(repo_fd).st_mode):
        os.close(repo_fd)
        die(b"repo must be an existing canonical directory")
    return repo_fd


def require_owned_directory(path, label):
    try:
        metadata = os.lstat(path)
    except OSError:
        die(label + b" is missing or inaccessible")
    if (
        not stat.S_ISDIR(metadata.st_mode)
        or metadata.st_uid != os.geteuid()
        or exact_mode(metadata) != 0o700
        or os.path.realpath(path) != path
    ):
        die(label + b" must be an owned canonical directory with mode 0700")


def profile_environment(profile):
    launcher_dir = os.path.dirname(os.path.realpath(os.fsencode(__file__)))
    profile_root = os.path.join(launcher_dir, b"profiles", profile)
    require_owned_directory(profile_root, b"profile-owned CLI root")
    runtime = os.path.join(profile_root, b"runtime")
    temporary = os.path.join(profile_root, b"tmp")
    require_owned_directory(runtime, b"profile runtime directory")
    require_owned_directory(temporary, b"profile temporary directory")
    config = os.path.join(profile_root, b".config")
    return {
        b"HOME": profile_root,
        b"XDG_CONFIG_HOME": config,
        b"XDG_CACHE_HOME": os.path.join(profile_root, b".cache"),
        b"XDG_DATA_HOME": os.path.join(profile_root, b".local", b"share"),
        b"XDG_STATE_HOME": os.path.join(profile_root, b".local", b"state"),
        b"XDG_RUNTIME_DIR": runtime,
        b"TMPDIR": temporary,
        b"TMP": temporary,
        b"TEMP": temporary,
        b"GH_CONFIG_DIR": os.path.join(config, b"gh"),
        b"GIT_CONFIG_GLOBAL": os.path.join(profile_root, b".gitconfig"),
    }


def clean_environment(repo, profile):
    source = os.environb
    clean = {
        key: value
        for key, value in source.items()
        if key in SAFE_ENV_KEYS or key.startswith(b"LC_")
    }
    clean.setdefault(b"PATH", os.fsencode(os.defpath))
    clean.update(profile_environment(profile))
    clean[b"PWD"] = repo
    return clean


def main():
    dispatch_fd = validated_dispatch()
    try:
        profile = read_staged(dispatch_fd, b"profile")
        repo = read_staged(dispatch_fd, b"repo")
        prompt = read_staged(dispatch_fd, b"prompt")
        session = read_staged(dispatch_fd, b"session")
    finally:
        os.close(dispatch_fd)

    if PROFILE_RE.fullmatch(profile) is None:
        die(b"profile must match the fixed ASCII profile grammar")
    if session and SESSION_RE.fullmatch(session) is None:
        die(b"session must be empty or match the fixed ASCII session-ID grammar")
    repo_fd = validate_repo(repo)
    try:
        os.fchdir(repo_fd)
    finally:
        os.close(repo_fd)

    environment = clean_environment(repo, profile)
    if MODE == b"omp":
        program = b"omp"
        argv = [program, b"--profile", profile]
        if session:
            argv.extend([b"--resume", session])
        argv.extend([b"-p", b"--cwd", repo, b"--", prompt])
    else:
        program = b"hermes"
        argv = [program, b"chat", b"-p", profile, b"-q", prompt]
    try:
        os.execvpe(program, argv, environment)
    except OSError:
        die(b"selected host executable could not be started", 126)


if __name__ == "__main__":
    main()
'''

LAUNCHERS = {
    "launch-omp": LAUNCHER_TEMPLATE.replace("@@MODE@@", "omp").replace(
        "@@LABEL@@", "launch-omp"
    ).encode("ascii"),
    "launch-hermes-review": LAUNCHER_TEMPLATE.replace("@@MODE@@", "hermes").replace(
        "@@LABEL@@", "launch-hermes-review"
    ).encode("ascii"),
}


def fail(message):
    print(f"gen-omp-agents.sh: {message}", file=sys.stderr)
    raise SystemExit(1)


def launcher_dir():
    configured = os.environ.get("WOO_ENGINEER_LAUNCHER_DIR")
    if configured is None:
        home = os.environ.get("HOME") or os.path.expanduser("~")
        configured = os.path.join(home, ".local", "libexec", "woostack")
    raw = os.fsencode(configured)
    if not raw or b"\0" in raw or not os.path.isabs(raw):
        fail("launcher directory must be an absolute path")
    if os.path.normpath(raw) != raw or os.path.realpath(raw) != raw:
        fail("launcher directory must be canonical and contain no symlink components")
    return raw


def open_launcher_dir(path):
    try:
        existing = os.lstat(path)
    except FileNotFoundError:
        try:
            os.makedirs(path, mode=0o700)
        except OSError:
            fail("could not create launcher directory")
        existing = os.lstat(path)
    except OSError:
        fail("launcher directory is inaccessible")

    if not stat.S_ISDIR(existing.st_mode):
        fail("launcher directory must be a real directory, not a symlink")
    if existing.st_uid != os.geteuid():
        fail("launcher directory must be owned by the invoking user")

    flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_CLOEXEC", 0)
    flags |= getattr(os, "O_NOFOLLOW", 0)
    try:
        directory_fd = os.open(path, flags)
    except OSError:
        fail("launcher directory could not be opened safely")
    metadata = os.fstat(directory_fd)
    if (
        not stat.S_ISDIR(metadata.st_mode)
        or metadata.st_uid != os.geteuid()
        or (metadata.st_dev, metadata.st_ino) != (existing.st_dev, existing.st_ino)
    ):
        os.close(directory_fd)
        fail("launcher directory changed while it was opened")
    try:
        os.fchmod(directory_fd, 0o700)
    except OSError:
        os.close(directory_fd)
        fail("could not enforce launcher directory mode 0700")
    if stat.S_IMODE(os.fstat(directory_fd).st_mode) != 0o700:
        os.close(directory_fd)
        fail("launcher directory mode is not 0700")
    return directory_fd


def existing_matches(directory_fd, name, payload):
    encoded_name = os.fsencode(name)
    try:
        before = os.stat(encoded_name, dir_fd=directory_fd, follow_symlinks=False)
    except FileNotFoundError:
        return False
    except OSError:
        return False
    if not stat.S_ISREG(before.st_mode):
        return False
    if before.st_uid != os.geteuid() or stat.S_IMODE(before.st_mode) != 0o500:
        return False
    flags = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0)
    try:
        fd = os.open(encoded_name, flags, dir_fd=directory_fd)
    except OSError:
        return False
    try:
        after = os.fstat(fd)
        if (after.st_dev, after.st_ino) != (before.st_dev, before.st_ino):
            return False
        chunks = []
        while True:
            chunk = os.read(fd, 1024 * 1024)
            if not chunk:
                break
            chunks.append(chunk)
        return b"".join(chunks) == payload
    finally:
        os.close(fd)


def atomic_install(directory_fd, name, payload):
    if existing_matches(directory_fd, name, payload):
        return
    encoded_name = os.fsencode(name)
    temporary = os.fsencode(f".{name}.{secrets.token_hex(12)}.tmp")
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_CLOEXEC", 0)
    flags |= getattr(os, "O_NOFOLLOW", 0)
    fd = -1
    try:
        fd = os.open(temporary, flags, 0o500, dir_fd=directory_fd)
        offset = 0
        while offset < len(payload):
            offset += os.write(fd, payload[offset:])
        os.fchmod(fd, 0o500)
        os.fsync(fd)
        os.close(fd)
        fd = -1
        os.replace(
            temporary,
            encoded_name,
            src_dir_fd=directory_fd,
            dst_dir_fd=directory_fd,
        )
        try:
            os.fsync(directory_fd)
        except OSError:
            pass
    except OSError:
        fail(f"could not install {name} atomically")
    finally:
        if fd >= 0:
            os.close(fd)
        try:
            os.unlink(temporary, dir_fd=directory_fd)
        except FileNotFoundError:
            pass
        except OSError:
            pass


def main():
    if sys.argv[1:] == ["--manifest"]:
        for name, payload in LAUNCHERS.items():
            print(f"{name}\t{hashlib.sha256(payload).hexdigest()}")
        return
    if sys.argv[1:]:
        fail("usage: gen-omp-agents.sh [--manifest]")

    path = launcher_dir()
    directory_fd = open_launcher_dir(path)
    try:
        for name, payload in LAUNCHERS.items():
            atomic_install(directory_fd, name, payload)
    finally:
        os.close(directory_fd)


if __name__ == "__main__":
    main()
PY
