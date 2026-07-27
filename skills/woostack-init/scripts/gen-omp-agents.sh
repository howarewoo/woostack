#!/usr/bin/env bash
# gen-omp-agents.sh — install the fixed host-side engineer launchers.
#
# The historical filename is retained so existing init/doctor entry points keep one
# installation authority. It deliberately does not generate project .omp/agents.
set -euo pipefail

if [ -x /usr/bin/python3 ]; then
  bootstrap_python=/usr/bin/python3
  if [ -n "${WOO_ENGINEER_PYTHON:-}" ]; then
    selected_python="$WOO_ENGINEER_PYTHON"
    selection_mode=explicit
  else
    selected_python=/usr/bin/python3
    selection_mode=system-shim
  fi
else
  bootstrap_python="${WOO_ENGINEER_PYTHON:-}"
  selected_python="$bootstrap_python"
  selection_mode=explicit
fi

for python_bin in "$bootstrap_python" "$selected_python"; do
  case "$python_bin" in
    /*) ;;
    *)
      echo "gen-omp-agents.sh: /usr/bin/python3 or WOO_ENGINEER_PYTHON set to an absolute interpreter is required" >&2
      exit 127
      ;;
  esac
done

exec "$bootstrap_python" - "$selected_python" "$selection_mode" "$@" <<'PY'
import hashlib
import os
import re
import secrets
import stat
import sys

PROFILE_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]{0,63}")


def fail(message):
    print(f"gen-omp-agents.sh: {message}", file=sys.stderr)
    raise SystemExit(1)


if len(sys.argv) < 3:
    fail("the selected Python interpreter and selection mode were not provided")
selected_interpreter = sys.argv.pop(1)
selection_mode = sys.argv.pop(1)
if selection_mode not in {"explicit", "system-shim"}:
    fail("the Python interpreter selection mode is invalid")


def validate_interpreter_path(path, label):
    if (
        not os.path.isabs(path)
        or os.path.normpath(path) != path
        or os.path.realpath(path) != path
        or any(character.isspace() for character in path)
    ):
        fail(f"{label} must be a canonical absolute path without whitespace")
    try:
        metadata = os.lstat(path)
    except OSError:
        fail(f"{label} could not be pinned")
    if (
        not stat.S_ISREG(metadata.st_mode)
        or metadata.st_uid not in (0, os.geteuid())
        or stat.S_IMODE(metadata.st_mode) & 0o6022
        or not os.access(path, os.X_OK)
    ):
        fail(f"{label} must be a canonical trusted non-setid executable")
    return path


def validate_system_shim(path):
    try:
        metadata = os.lstat(path)
    except OSError:
        fail("the system Python shim could not be pinned")
    if (
        path != "/usr/bin/python3"
        or not (stat.S_ISREG(metadata.st_mode) or stat.S_ISLNK(metadata.st_mode))
        or metadata.st_uid != 0
        or (stat.S_ISREG(metadata.st_mode) and stat.S_IMODE(metadata.st_mode) & 0o6022)
        or not os.access(path, os.X_OK)
    ):
        fail("the system Python shim must be the trusted /usr/bin/python3 path")


running_interpreter = os.path.realpath(sys.executable)
if selection_mode == "system-shim":
    if selected_interpreter != "/usr/bin/python3":
        fail("the default Python interpreter must be the trusted system shim")
    validate_system_shim(selected_interpreter)
    interpreter = validate_interpreter_path(
        running_interpreter, "the resolved system Python interpreter"
    )
else:
    interpreter = validate_interpreter_path(
        selected_interpreter, "WOO_ENGINEER_PYTHON"
    )
    if running_interpreter != interpreter:
        fail("WOO_ENGINEER_PYTHON must exactly equal the running canonical interpreter")

LAUNCHER_TEMPLATE = r'''#!@@PYTHON@@
# Installed by woostack-init/scripts/gen-omp-agents.sh. Do not edit in place.
import json
import os
import re
import secrets
import stat
import sys

MODE = "@@MODE@@"
LABEL = b"@@LABEL@@"
PROFILE_RE = re.compile(rb"[A-Za-z0-9][A-Za-z0-9._-]{0,63}")
LC_RE = re.compile(r"LC_[A-Z0-9_]+")
LC_BYTES_RE = re.compile(rb"LC_[A-Z0-9_]+")
SENSITIVE_KEY_RE = re.compile(r"TOKEN|SECRET|PASSWORD", re.IGNORECASE)
SENSITIVE_VALUE_RE = re.compile(
    r"(?:\bBearer\s+|-----BEGIN [A-Z ]*PRIVATE KEY-----|\b(?:gh[pousr]|github_pat|lin_api|sk)-?[A-Za-z0-9_]{8,})",
    re.IGNORECASE,
)
UNIT_KEYS = frozenset({"schemaVersion", "engineerName", "repository", "omp", "hermes"})
ROLE_KEYS = frozenset({"profile", "program", "environment"})
COMMON_SCALAR_ENV = frozenset(
    {
        "CLICOLOR",
        "CLICOLOR_FORCE",
        "COLORTERM",
        "FORCE_COLOR",
        "LANG",
        "LANGUAGE",
        "NO_COLOR",
        "TERM",
        "TERM_PROGRAM",
        "TERM_PROGRAM_VERSION",
    }
)
INHERITED_ENV = frozenset(os.fsencode(key) for key in COMMON_SCALAR_ENV | {"SSL_CERT_DIR", "SSL_CERT_FILE"})
XDG_DIR_ENV = frozenset(
    {
        "XDG_CACHE_HOME",
        "XDG_CONFIG_HOME",
        "XDG_DATA_HOME",
        "XDG_RUNTIME_DIR",
        "XDG_STATE_HOME",
    }
)
COMMON_DIR_ENV = frozenset({"HOME", "SSL_CERT_DIR"}) | XDG_DIR_ENV
COMMON_FILE_ENV = frozenset({"SSL_CERT_FILE"})
ROLE_DIR_ENV = {
    "omp": frozenset({"OMP_HOME", "OMP_CONFIG_HOME", "GH_CONFIG_DIR"}),
    "hermes": frozenset({"HERMES_HOME", "HERMES_CONFIG_HOME", "GH_CONFIG_DIR"}),
}
ROLE_FILE_ENV = {
    "omp": frozenset({"GIT_CONFIG_GLOBAL", "GIT_CONFIG_SYSTEM"}),
    "hermes": frozenset({"GIT_CONFIG_GLOBAL", "GIT_CONFIG_SYSTEM"}),
}
ROLE_SOCKET_ENV = {"omp": frozenset({"SSH_AUTH_SOCK"}), "hermes": frozenset()}


def die(message, code=64):
    os.write(2, LABEL + b": " + message + b"\n")
    raise SystemExit(code)


def exact_mode(metadata):
    return stat.S_IMODE(metadata.st_mode)


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


def canonical_bytes(value, label):
    if not value or b"\0" in value or b"\n" in value or b"\r" in value:
        die(label + b" must be a non-empty path without control bytes")
    if not os.path.isabs(value) or os.path.normpath(value) != value or os.path.realpath(value) != value:
        die(label + b" must be canonical, absolute, and contain no symlink components")
    return value


def path_is_within(path, parent):
    try:
        return os.path.commonpath((path, parent)) == parent
    except ValueError:
        return False


def open_directory(path, label, expected_mode=None, owner_required=True, writable_safe=False):
    canonical_bytes(path, label)
    try:
        before = os.lstat(path)
    except OSError:
        die(label + b" is missing or inaccessible")
    if not stat.S_ISDIR(before.st_mode):
        die(label + b" must be a real no-follow directory")
    if owner_required and before.st_uid != os.geteuid():
        die(label + b" must be owned by the invoking user")
    if before.st_uid not in (0, os.geteuid()):
        die(label + b" has an untrusted owner")
    if expected_mode is not None and exact_mode(before) != expected_mode:
        die(label + f" must have mode {expected_mode:04o}".encode("ascii"))
    if writable_safe and exact_mode(before) & 0o022:
        die(label + b" must not be group- or other-writable")
    flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_CLOEXEC", 0)
    flags |= getattr(os, "O_NOFOLLOW", 0)
    try:
        fd = os.open(path, flags)
    except OSError:
        die(label + b" could not be opened safely")
    after = os.fstat(fd)
    if signature(after) != signature(before):
        os.close(fd)
        die(label + b" changed while it was opened")
    return fd, signature(before)


def read_owned_at(directory_fd, name, wanted_mode, label):
    try:
        before = os.stat(name, dir_fd=directory_fd, follow_symlinks=False)
    except OSError:
        die(label + b" is missing or inaccessible")
    if not stat.S_ISREG(before.st_mode):
        die(label + b" must be a regular no-follow file")
    if before.st_uid != os.geteuid():
        die(label + b" must be owned by the invoking user")
    if exact_mode(before) != wanted_mode:
        die(label + f" must have mode {wanted_mode:04o}".encode("ascii"))
    before_signature = signature(before)
    flags = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0)
    try:
        fd = os.open(name, flags, dir_fd=directory_fd)
    except OSError:
        die(label + b" could not be opened safely")
    try:
        opened = os.fstat(fd)
        if signature(opened) != before_signature:
            die(label + b" changed while it was opened")
        chunks = []
        while True:
            chunk = os.read(fd, 1024 * 1024)
            if not chunk:
                break
            chunks.append(chunk)
        after_read = os.fstat(fd)
        if signature(after_read) != before_signature:
            die(label + b" changed while it was read")
    finally:
        os.close(fd)
    try:
        after_entry = os.stat(name, dir_fd=directory_fd, follow_symlinks=False)
    except OSError:
        die(label + b" changed while it was read")
    if signature(after_entry) != before_signature:
        die(label + b" changed while it was read")
    return b"".join(chunks), before_signature


def verify_owned_at(directory_fd, name, wanted_signature, label):
    try:
        current = os.stat(name, dir_fd=directory_fd, follow_symlinks=False)
    except OSError:
        die(label + b" changed after it was read")
    if signature(current) != wanted_signature:
        die(label + b" changed after it was read")


def parse_json(raw, label):
    if b"\0" in raw:
        die(label + b" may not contain NUL bytes")

    def unique_object(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError("duplicate object key")
            result[key] = value
        return result

    try:
        value = json.loads(raw.decode("utf-8"), object_pairs_hook=unique_object)
    except (UnicodeError, ValueError, TypeError):
        die(label + b" must be valid duplicate-free UTF-8 JSON")
    return value


def reject_secrets(value):
    if isinstance(value, dict):
        for key, child in value.items():
            if not isinstance(key, str):
                die(b"unit manifest object keys must be strings")
            if SENSITIVE_KEY_RE.search(key):
                die(b"unit manifest may not contain token, secret, or password fields")
            reject_secrets(child)
    elif isinstance(value, list):
        for child in value:
            reject_secrets(child)
    elif isinstance(value, str) and SENSITIVE_VALUE_RE.search(value):
        die(b"unit manifest may not contain credential material")


def text_bytes(value, label):
    if not isinstance(value, str):
        die(label + b" must be a string")
    try:
        encoded = os.fsencode(value)
    except (UnicodeError, TypeError):
        die(label + b" cannot be represented as an OS argument")
    if b"\0" in encoded or b"\n" in encoded or b"\r" in encoded:
        die(label + b" contains forbidden control bytes")
    return encoded


def validate_profile(value, label):
    encoded = text_bytes(value, label)
    if PROFILE_RE.fullmatch(encoded) is None:
        die(label + b" must match the fixed ASCII profile grammar")
    return encoded


def validate_path_metadata(path, label, kind, owner_policy, repository):
    canonical_bytes(path, label)
    if path_is_within(path, repository):
        die(label + b" must remain outside the accepted issue worktree")
    try:
        metadata = os.lstat(path)
    except OSError:
        die(label + b" is missing or inaccessible")
    if kind == "directory" and not stat.S_ISDIR(metadata.st_mode):
        die(label + b" must be a real no-follow directory")
    if kind == "file" and not stat.S_ISREG(metadata.st_mode):
        die(label + b" must be a regular no-follow file")
    if kind == "socket" and not stat.S_ISSOCK(metadata.st_mode):
        die(label + b" must be a real no-follow socket")
    if owner_policy == "role" and metadata.st_uid != os.geteuid():
        die(label + b" must be owned by the invoking user")
    if owner_policy == "trusted" and metadata.st_uid not in (0, os.geteuid()):
        die(label + b" has an untrusted owner")
    if exact_mode(metadata) & 0o022:
        die(label + b" must not be group- or other-writable")
    return metadata


def validate_program(value, label, repository):
    path = text_bytes(value, label)
    metadata = validate_path_metadata(path, label, "file", "trusted", repository)
    if exact_mode(metadata) & 0o6000 or exact_mode(metadata) & 0o111 == 0 or not os.access(path, os.X_OK):
        die(label + b" must be a non-setid executable")
    flags = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0)
    try:
        fd = os.open(path, flags)
    except OSError:
        die(label + b" could not be opened safely")
    try:
        opened = os.fstat(fd)
        if signature(opened) != signature(metadata):
            die(label + b" changed while it was opened")
    finally:
        os.close(fd)
    try:
        after = os.lstat(path)
    except OSError:
        die(label + b" changed while it was checked")
    if signature(after) != signature(metadata):
        die(label + b" changed while it was checked")
    return path


def validate_scalar(value, label):
    encoded = text_bytes(value, label)
    if not encoded or any(byte < 0x20 or byte == 0x7F for byte in encoded):
        die(label + b" must be a non-empty single-line scalar")


def validate_path_list(value, label, repository):
    encoded = text_bytes(value, label)
    components = encoded.split(os.fsencode(os.pathsep))
    if not components or any(not component for component in components):
        die(label + b" may not contain empty PATH components")
    if len(set(components)) != len(components):
        die(label + b" may not contain duplicate PATH components")
    for component in components:
        validate_path_metadata(component, label + b" component", "directory", "trusted", repository)


def allowed_environment_key(role, key):
    return (
        key == "PATH"
        or key in COMMON_SCALAR_ENV
        or LC_RE.fullmatch(key) is not None
        or key in COMMON_DIR_ENV
        or key in COMMON_FILE_ENV
        or key in ROLE_DIR_ENV[role]
        or key in ROLE_FILE_ENV[role]
        or key in ROLE_SOCKET_ENV[role]
    )


def validate_environment(role, value, repository):
    if not isinstance(value, dict):
        die(os.fsencode(role) + b" environment must be an object")
    if "HOME" not in value or "PATH" not in value:
        die(os.fsencode(role) + b" environment must pin HOME and PATH")
    for key, item in value.items():
        if not isinstance(key, str) or not allowed_environment_key(role, key):
            die(os.fsencode(role) + b" environment contains an unsupported key")
        if SENSITIVE_KEY_RE.search(key):
            die(b"unit manifest may not contain token, secret, or password fields")
        label = os.fsencode(role + ".environment." + key)
        if key == "PATH":
            validate_path_list(item, label, repository)
        elif key in COMMON_DIR_ENV or key in ROLE_DIR_ENV[role]:
            owner_policy = "trusted" if key == "SSL_CERT_DIR" else "role"
            validate_path_metadata(text_bytes(item, label), label, "directory", owner_policy, repository)
        elif key in COMMON_FILE_ENV or key in ROLE_FILE_ENV[role]:
            owner_policy = "trusted" if key in {"SSL_CERT_FILE", "GIT_CONFIG_SYSTEM"} else "role"
            validate_path_metadata(text_bytes(item, label), label, "file", owner_policy, repository)
        elif key in ROLE_SOCKET_ENV[role]:
            validate_path_metadata(text_bytes(item, label), label, "socket", "role", repository)
        else:
            validate_scalar(item, label)


def validate_unit(value, unit_path):
    reject_secrets(value)
    if not isinstance(value, dict) or set(value) != UNIT_KEYS:
        die(b"unit manifest has an unsupported top-level schema")
    if type(value.get("schemaVersion")) is not int or value["schemaVersion"] != 1:
        die(b"unit manifest schemaVersion must equal 1")
    engineer = validate_profile(value.get("engineerName"), b"engineerName")
    if os.path.basename(unit_path) != engineer:
        die(b"engineerName must exactly match the trusted per-unit launcher directory")
    roles = {}
    for role in ("omp", "hermes"):
        role_value = value.get(role)
        if not isinstance(role_value, dict) or set(role_value) != ROLE_KEYS:
            die(os.fsencode(role) + b" manifest entry has an unsupported schema")
        roles[role] = role_value
    omp_profile = validate_profile(roles["omp"].get("profile"), b"omp.profile")
    hermes_profile = validate_profile(roles["hermes"].get("profile"), b"hermes.profile")
    if omp_profile != engineer:
        die(b"omp.profile must exactly match engineerName")
    if hermes_profile == omp_profile:
        die(b"Hermes and omp profiles must be distinct")
    repository = text_bytes(value.get("repository"), b"repository")
    repository_fd, _ = open_directory(
        repository,
        b"repository",
        owner_required=True,
        writable_safe=True,
    )
    os.close(repository_fd)
    programs = {}
    environments = {}
    for role in ("omp", "hermes"):
        role_label = os.fsencode(role)
        programs[role] = validate_program(roles[role].get("program"), role_label + b".program", repository)
        validate_environment(role, roles[role].get("environment"), repository)
        environments[role] = roles[role]["environment"]
    if programs["omp"] == programs["hermes"]:
        die(b"Hermes and omp programs must be distinct")
    if environments["omp"]["HOME"] == environments["hermes"]["HOME"]:
        die(b"Hermes and omp HOME pins must be distinct")
    isolated_common = frozenset({"HOME", "GH_CONFIG_DIR", "GIT_CONFIG_GLOBAL"}) | XDG_DIR_ENV
    isolated_paths = {}
    for role in ("omp", "hermes"):
        isolated_keys = isolated_common | ROLE_DIR_ENV[role] | ROLE_SOCKET_ENV[role]
        isolated_paths[role] = [
            os.fsencode(environments[role][key])
            for key in isolated_keys
            if key in environments[role]
        ]
    for omp_path in isolated_paths["omp"]:
        for hermes_path in isolated_paths["hermes"]:
            if (
                omp_path == hermes_path
                or path_is_within(omp_path, hermes_path)
                or path_is_within(hermes_path, omp_path)
            ):
                die(b"Hermes and omp role-owned environment paths must not overlap")
    return {
        "engineer": engineer,
        "repository": repository,
        "profiles": {"omp": omp_profile, "hermes": hermes_profile},
        "programs": programs,
        "environments": environments,
    }


def open_static_unit():
    try:
        script_path = os.fsencode(os.path.abspath(__file__))
    except (UnicodeError, TypeError):
        die(b"launcher path cannot be represented safely")
    canonical_bytes(script_path, b"launcher path")
    if os.path.basename(script_path) != LABEL:
        die(b"launcher filename does not match its installed role")
    unit_path = os.path.dirname(script_path)
    root_path = os.path.dirname(unit_path)
    root_fd, _ = open_directory(root_path, b"launcher root", expected_mode=0o700)
    os.close(root_fd)
    unit_fd, _ = open_directory(unit_path, b"per-unit launcher directory", expected_mode=0o700)
    read_owned_at(unit_fd, LABEL, 0o500, b"installed launcher")
    return unit_path, unit_fd


def open_dispatch():
    dispatch_path = os.getcwdb()
    dispatch_fd, dispatch_signature = open_directory(
        dispatch_path,
        b"dispatch directory",
        expected_mode=0o700,
    )
    return dispatch_path, dispatch_fd, dispatch_signature


def verify_directory(fd, wanted_signature, label):
    if signature(os.fstat(fd)) != wanted_signature:
        die(label + b" changed while it was used")


def atomic_authority_install(unit_fd, payload):
    temporary = os.fsencode(f".unit-authority.{secrets.token_hex(12)}.tmp")
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_CLOEXEC", 0)
    flags |= getattr(os, "O_NOFOLLOW", 0)
    fd = -1
    try:
        fd = os.open(temporary, flags, 0o400, dir_fd=unit_fd)
        offset = 0
        while offset < len(payload):
            offset += os.write(fd, payload[offset:])
        os.fchmod(fd, 0o400)
        os.fsync(fd)
        os.close(fd)
        fd = -1
        os.replace(
            temporary,
            b"unit-authority.json",
            src_dir_fd=unit_fd,
            dst_dir_fd=unit_fd,
        )
        try:
            os.fsync(unit_fd)
        except OSError:
            pass
    except OSError:
        die(b"unit authority could not be installed atomically")
    finally:
        if fd >= 0:
            os.close(fd)
        try:
            os.unlink(temporary, dir_fd=unit_fd)
        except FileNotFoundError:
            pass
        except OSError:
            pass


def bind_unit(unit_path, unit_fd):
    dispatch_path, dispatch_fd, dispatch_signature = open_dispatch()
    if path_is_within(dispatch_path, unit_path):
        os.close(dispatch_fd)
        die(b"unit manifest staging must remain outside the trusted launcher directory")
    try:
        raw, unit_signature = read_owned_at(
            dispatch_fd,
            b"unit.json",
            0o600,
            b"staged unit.json",
        )
        value = parse_json(raw, b"staged unit.json")
        validate_unit(value, unit_path)
        verify_owned_at(dispatch_fd, b"unit.json", unit_signature, b"staged unit.json")
        verify_directory(dispatch_fd, dispatch_signature, b"dispatch directory")
    finally:
        os.close(dispatch_fd)
    payload = (json.dumps(value, ensure_ascii=True, sort_keys=True, separators=(",", ":")) + "\n").encode("ascii")
    atomic_authority_install(unit_fd, payload)


def build_environment(role_environment, repository):
    environment = {
        os.fsencode(key): os.fsencode(value)
        for key, value in role_environment.items()
    }
    for key, value in os.environb.items():
        if key in INHERITED_ENV or LC_BYTES_RE.fullmatch(key) is not None:
            environment.setdefault(key, value)
    environment[b"PWD"] = repository
    return environment


def launch(unit_path, unit_fd):
    raw_authority, authority_signature = read_owned_at(
        unit_fd,
        b"unit-authority.json",
        0o400,
        b"unit authority",
    )
    authority = parse_json(raw_authority, b"unit authority")
    canonical_authority = (
        json.dumps(authority, ensure_ascii=True, sort_keys=True, separators=(",", ":")) + "\n"
    ).encode("ascii")
    if raw_authority != canonical_authority:
        die(b"unit authority must retain the binder's canonical byte representation")
    pins = validate_unit(authority, unit_path)
    verify_owned_at(unit_fd, b"unit-authority.json", authority_signature, b"unit authority")

    dispatch_path, dispatch_fd, dispatch_signature = open_dispatch()
    if path_is_within(dispatch_path, unit_path) or path_is_within(dispatch_path, pins["repository"]):
        os.close(dispatch_fd)
        die(b"launch staging must remain outside the launcher and repository directories")
    staged = {}
    staged_signatures = {}
    try:
        for name in (b"profile", b"repo", b"prompt"):
            staged[name], staged_signatures[name] = read_owned_at(
                dispatch_fd,
                name,
                0o600,
                b"staged " + name,
            )
        for name in (b"profile", b"repo", b"prompt"):
            verify_owned_at(dispatch_fd, name, staged_signatures[name], b"staged " + name)
        verify_directory(dispatch_fd, dispatch_signature, b"dispatch directory")
    finally:
        os.close(dispatch_fd)
    if any(b"\0" in staged[name] for name in (b"profile", b"repo", b"prompt")):
        die(b"staged launch inputs may not contain NUL bytes")
    role = MODE
    if staged[b"profile"] != pins["profiles"][role]:
        die(b"staged profile does not match the bound unit authority")
    if staged[b"repo"] != pins["repository"]:
        die(b"staged repo does not match the bound accepted issue worktree")

    repository_fd, _ = open_directory(
        pins["repository"],
        b"repository",
        owner_required=True,
        writable_safe=True,
    )
    try:
        os.fchdir(repository_fd)
    finally:
        os.close(repository_fd)
    environment = build_environment(pins["environments"][role], pins["repository"])
    program = pins["programs"][role]
    argv = [b"omp", b"--profile", staged[b"profile"], b"-p", b"--cwd", staged[b"repo"], b"--", staged[b"prompt"]]
    try:
        os.execve(program, argv, environment)
    except OSError:
        die(b"pinned host executable could not be started", 126)


def main():
    if sys.argv[1:]:
        die(b"installed launcher accepts no arguments")
    unit_path, unit_fd = open_static_unit()
    try:
        if MODE == "bind":
            bind_unit(unit_path, unit_fd)
        else:
            launch(unit_path, unit_fd)
    finally:
        os.close(unit_fd)


if __name__ == "__main__":
    main()
'''


def launcher_payload(mode, label):
    return (
        LAUNCHER_TEMPLATE.replace("@@PYTHON@@", interpreter)
        .replace("@@MODE@@", mode)
        .replace("@@LABEL@@", label)
        .encode("utf-8")
    )


LAUNCHERS = {
    "launch-omp": launcher_payload("omp", "launch-omp"),
    "bind-engineer-unit": launcher_payload("bind", "bind-engineer-unit"),
}
RETIRED_LAUNCHERS = ("launch-hermes-review",)


def validate_engineer_name():
    value = os.environ.get("ENGINEER_NAME")
    if value is None or PROFILE_RE.fullmatch(value) is None:
        fail("ENGINEER_NAME must match [A-Za-z0-9][A-Za-z0-9._-]{0,63}")
    return value


def launcher_root():
    configured = os.environ.get("WOO_ENGINEER_LAUNCHER_ROOT")
    if configured is None:
        home = os.environ.get("HOME")
        if not home:
            fail("HOME or WOO_ENGINEER_LAUNCHER_ROOT is required")
        configured = os.path.join(home, ".local", "libexec", "woostack")
    raw = os.fsencode(configured)
    if (
        not raw
        or any(character in raw for character in (b"\0", b"\n", b"\r"))
        or not os.path.isabs(raw)
        or os.path.normpath(raw) != raw
    ):
        fail("launcher root must be a normalized absolute path without control bytes")
    parent = os.path.dirname(raw)
    if os.path.realpath(parent) != parent:
        fail("launcher root parent must contain no symlink components")
    return raw


def open_root(path):
    try:
        os.makedirs(path, mode=0o700, exist_ok=True)
    except OSError:
        fail("could not create launcher root")
    if os.path.realpath(path) != path:
        fail("launcher root must be canonical and contain no symlink components")
    try:
        existing = os.lstat(path)
    except OSError:
        fail("launcher root is inaccessible")
    if not stat.S_ISDIR(existing.st_mode):
        fail("launcher root must be a real directory, not a symlink")
    if existing.st_uid != os.geteuid():
        fail("launcher root must be owned by the invoking user")
    flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_CLOEXEC", 0)
    flags |= getattr(os, "O_NOFOLLOW", 0)
    try:
        root_fd = os.open(path, flags)
    except OSError:
        fail("launcher root could not be opened safely")
    opened = os.fstat(root_fd)
    if (opened.st_dev, opened.st_ino) != (existing.st_dev, existing.st_ino):
        os.close(root_fd)
        fail("launcher root changed while it was opened")
    try:
        os.fchmod(root_fd, 0o700)
    except OSError:
        os.close(root_fd)
        fail("could not enforce launcher root mode 0700")
    if stat.S_IMODE(os.fstat(root_fd).st_mode) != 0o700:
        os.close(root_fd)
        fail("launcher root mode is not 0700")
    return root_fd


def open_unit(root_fd, engineer_name):
    encoded_name = os.fsencode(engineer_name)
    try:
        os.mkdir(encoded_name, 0o700, dir_fd=root_fd)
    except FileExistsError:
        pass
    except OSError:
        fail("could not create per-unit launcher directory")
    try:
        existing = os.stat(encoded_name, dir_fd=root_fd, follow_symlinks=False)
    except OSError:
        fail("per-unit launcher directory is inaccessible")
    if not stat.S_ISDIR(existing.st_mode):
        fail("per-unit launcher directory must be a real directory, not a symlink")
    if existing.st_uid != os.geteuid():
        fail("per-unit launcher directory must be owned by the invoking user")
    flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_CLOEXEC", 0)
    flags |= getattr(os, "O_NOFOLLOW", 0)
    try:
        unit_fd = os.open(encoded_name, flags, dir_fd=root_fd)
    except OSError:
        fail("per-unit launcher directory could not be opened safely")
    opened = os.fstat(unit_fd)
    if (opened.st_dev, opened.st_ino) != (existing.st_dev, existing.st_ino):
        os.close(unit_fd)
        fail("per-unit launcher directory changed while it was opened")
    try:
        os.fchmod(unit_fd, 0o700)
    except OSError:
        os.close(unit_fd)
        fail("could not enforce per-unit launcher directory mode 0700")
    if stat.S_IMODE(os.fstat(unit_fd).st_mode) != 0o700:
        os.close(unit_fd)
        fail("per-unit launcher directory mode is not 0700")
    return unit_fd


def existing_matches(directory_fd, name, payload):
    encoded_name = os.fsencode(name)
    try:
        before = os.stat(encoded_name, dir_fd=directory_fd, follow_symlinks=False)
    except OSError:
        return False
    if (
        not stat.S_ISREG(before.st_mode)
        or before.st_uid != os.geteuid()
        or stat.S_IMODE(before.st_mode) != 0o500
    ):
        return False
    flags = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0)
    try:
        fd = os.open(encoded_name, flags, dir_fd=directory_fd)
    except OSError:
        return False
    try:
        opened = os.fstat(fd)
        if (opened.st_dev, opened.st_ino, opened.st_size, opened.st_mtime_ns) != (
            before.st_dev,
            before.st_ino,
            before.st_size,
            before.st_mtime_ns,
        ):
            return False
        chunks = []
        while True:
            chunk = os.read(fd, 1024 * 1024)
            if not chunk:
                break
            chunks.append(chunk)
        after = os.fstat(fd)
        return (
            after.st_dev,
            after.st_ino,
            after.st_size,
            after.st_mtime_ns,
        ) == (
            before.st_dev,
            before.st_ino,
            before.st_size,
            before.st_mtime_ns,
        ) and b"".join(chunks) == payload
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


def remove_retired_launcher(directory_fd, name):
    encoded_name = os.fsencode(name)
    try:
        metadata = os.stat(encoded_name, dir_fd=directory_fd, follow_symlinks=False)
    except FileNotFoundError:
        return
    except OSError:
        fail(f"could not inspect retired {name}")
    if metadata.st_uid != os.geteuid():
        fail(f"retired {name} must be owned by the invoking user before removal")
    try:
        os.unlink(encoded_name, dir_fd=directory_fd)
        os.fsync(directory_fd)
    except OSError:
        fail(f"could not remove retired {name}")


def main():
    if sys.argv[1:] == ["--manifest"]:
        for name, payload in LAUNCHERS.items():
            print(f"{name}\t{hashlib.sha256(payload).hexdigest()}")
        return
    if sys.argv[1:]:
        fail("usage: gen-omp-agents.sh [--manifest]")
    engineer_name = validate_engineer_name()
    root_path = launcher_root()
    root_fd = open_root(root_path)
    try:
        unit_fd = open_unit(root_fd, engineer_name)
        try:
            for name in RETIRED_LAUNCHERS:
                remove_retired_launcher(unit_fd, name)
            for name, payload in LAUNCHERS.items():
                atomic_install(unit_fd, name, payload)
        finally:
            os.close(unit_fd)
    finally:
        os.close(root_fd)


if __name__ == "__main__":
    main()
PY
