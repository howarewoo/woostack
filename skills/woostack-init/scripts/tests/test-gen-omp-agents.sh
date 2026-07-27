#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="$HERE/../gen-omp-agents.sh"
# shellcheck disable=SC1091
source "$HERE/assert.sh"

TMP="$(mktemp -d)"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
ENGINEER_NAME="engineer.1"
HERMES_PROFILE="hermes-review.1"
LAUNCHER_ROOT="$TMP/launcher-root"
LAUNCHER_DIR="$LAUNCHER_ROOT/$ENGINEER_NAME"
OMP_BIN_DIR="$TMP/omp-bin"
HERMES_BIN_DIR="$TMP/hermes-bin"
CONTROLLER_BIN="$TMP/controller-bin"
OMP_HOME="$TMP/omp-home"
HERMES_HOME="$TMP/hermes-home"
OMP_XDG="$OMP_HOME/xdg-config"
HERMES_XDG="$HERMES_HOME/xdg-config"
OMP_GH="$OMP_HOME/gh"
HERMES_GH="$HERMES_HOME/gh"
OMP_GIT_CONFIG="$OMP_HOME/gitconfig"
HERMES_GIT_CONFIG="$HERMES_HOME/gitconfig"
REPO_RAW="$TMP/accepted-worktree"
OTHER_REPO="$TMP/other-worktree"
mkdir -p \
  "$OMP_BIN_DIR" "$HERMES_BIN_DIR" "$CONTROLLER_BIN" \
  "$OMP_XDG" "$HERMES_XDG" "$OMP_GH" "$HERMES_GH" \
  "$REPO_RAW" "$OTHER_REPO"
chmod 777 "$CONTROLLER_BIN"
printf '%s\n' '[user]' >"$OMP_GIT_CONFIG"
printf '%s\n' '[user]' >"$HERMES_GIT_CONFIG"
chmod 600 "$OMP_GIT_CONFIG" "$HERMES_GIT_CONFIG"
REPO="$(cd "$REPO_RAW" && pwd -P)"
OTHER_REPO="$(cd "$OTHER_REPO" && pwd -P)"

mode_of() {
  python3 - "$1" <<'PY'
import os
import stat
import sys
print(f"{stat.S_IMODE(os.lstat(sys.argv[1]).st_mode):04o}")
PY
}

file_state() {
  python3 - "$@" <<'PY'
import os
import sys
for path in sys.argv[1:]:
    value = os.stat(path, follow_symlinks=False)
    print(f"{value.st_dev}:{value.st_ino}:{value.st_mtime_ns}:{value.st_size}")
PY
}

make_fake() {
  python3 - "$1" "$2" "$3" <<'PY'
import os
from pathlib import Path
import sys

program = Path(sys.argv[1])
capture = sys.argv[2]
status = int(sys.argv[3])
source = f'''#!{os.path.realpath(sys.executable)}
import os
from pathlib import Path
import sys
base = Path({capture!r})
with open(str(base) + ".argv", "wb") as handle:
    for value in sys.argv[1:]:
        handle.write(os.fsencode(value) + b"\\0")
with open(str(base) + ".env", "wb") as handle:
    for key, value in sorted(os.environb.items()):
        handle.write(key + b"=" + value + b"\\0")
raise SystemExit({status})
'''
program.write_text(source, encoding="utf-8")
program.chmod(0o700)
PY
}

OMP_CAPTURE="$TMP/omp-capture"
HERMES_CAPTURE="$TMP/hermes-capture"
CONTROLLER_CAPTURE="$TMP/controller-capture"
make_fake "$OMP_BIN_DIR/omp" "$OMP_CAPTURE" 37
make_fake "$HERMES_BIN_DIR/hermes" "$HERMES_CAPTURE" 23
make_fake "$CONTROLLER_BIN/omp" "$CONTROLLER_CAPTURE" 91
make_fake "$CONTROLLER_BIN/hermes" "$CONTROLLER_CAPTURE" 92

write_valid_unit() {
  local destination="$1"
  python3 - \
    "$destination" "$ENGINEER_NAME" "$HERMES_PROFILE" "$REPO" \
    "$OMP_BIN_DIR/omp" "$HERMES_BIN_DIR/hermes" \
    "$OMP_HOME" "$HERMES_HOME" "$OMP_XDG" "$HERMES_XDG" \
    "$OMP_BIN_DIR" "$HERMES_BIN_DIR" "$OMP_GH" "$HERMES_GH" \
    "$OMP_GIT_CONFIG" "$HERMES_GIT_CONFIG" <<'PY'
import json
from pathlib import Path
import sys

(
    destination,
    engineer,
    hermes_profile,
    repository,
    omp_program,
    hermes_program,
    omp_home,
    hermes_home,
    omp_xdg,
    hermes_xdg,
    omp_path,
    hermes_path,
    omp_gh,
    hermes_gh,
    omp_git,
    hermes_git,
) = sys.argv[1:]
value = {
    "schemaVersion": 1,
    "engineerName": engineer,
    "repository": repository,
    "omp": {
        "profile": engineer,
        "program": omp_program,
        "environment": {
            "HOME": omp_home,
            "PATH": omp_path,
            "LANG": "C",
            "OMP_HOME": omp_home,
            "OMP_CONFIG_HOME": omp_xdg,
            "XDG_CONFIG_HOME": omp_xdg,
            "GH_CONFIG_DIR": omp_gh,
            "GIT_CONFIG_GLOBAL": omp_git,
        },
    },
    "hermes": {
        "profile": hermes_profile,
        "program": hermes_program,
        "environment": {
            "HOME": hermes_home,
            "PATH": hermes_path,
            "LANG": "C",
            "HERMES_HOME": hermes_home,
            "HERMES_CONFIG_HOME": hermes_xdg,
            "XDG_CONFIG_HOME": hermes_xdg,
            "GH_CONFIG_DIR": hermes_gh,
            "GIT_CONFIG_GLOBAL": hermes_git,
        },
    },
}
Path(destination).write_text(json.dumps(value), encoding="utf-8")
PY
}

stage_dispatch() {
  local directory="$1" profile="$2" repo="$3"
  mkdir -p "$directory"
  chmod 700 "$directory"
  printf '%s' "$profile" >"$directory/profile"
  printf '%s' "$repo" >"$directory/repo"
  cat >"$directory/prompt" <<'PROMPT'
-$(touch pwned-dollar)
`touch pwned-backtick`
'quoted' "double-quoted"; touch pwned-semicolon
literal second line
PROMPT
  printf '\377' >>"$directory/prompt"
  chmod 600 "$directory/profile" "$directory/repo" "$directory/prompt"
}

bind_valid_unit() {
  local directory="$1"
  mkdir -p "$directory"
  chmod 700 "$directory"
  write_valid_unit "$directory/unit.json"
  chmod 600 "$directory/unit.json"
  (cd "$directory" && "$LAUNCHER_DIR/bind-engineer-unit")
}

launch_with_hostile_controller() {
  local launcher="$1" directory="$2"
  (
    cd "$directory"
    /usr/bin/env -i \
      PATH="$CONTROLLER_BIN" \
      HOME="$TMP/controller-home" \
      HERMES_HOME="$TMP/controller-hermes" \
      HERMES_CONFIG_HOME="$TMP/controller-hermes-config" \
      OMP_HOME="$TMP/controller-omp" \
      OMP_CONFIG_HOME="$TMP/controller-omp-config" \
      XDG_CACHE_HOME="$TMP/controller-xdg-cache" \
      XDG_CONFIG_HOME="$TMP/controller-xdg-config" \
      XDG_DATA_HOME="$TMP/controller-xdg-data" \
      XDG_STATE_HOME="$TMP/controller-xdg-state" \
      GH_TOKEN=controller-gh \
      GITHUB_TOKEN=controller-github \
      LINEAR_API_KEY=controller-linear \
      LINEAR_ACCESS_TOKEN=controller-linear-access \
      LINEAR_OAUTH_TOKEN=controller-linear-oauth \
      WOO_HERMES_LINEAR_APP_ACCESS_TOKEN=controller-hermes-linear \
      WOO_OMP_LINEAR_APP_ACCESS_TOKEN=controller-omp-linear \
      GH_CONFIG_DIR="$TMP/controller-gh" \
      GIT_ASKPASS="$TMP/controller-askpass" \
      SSH_ASKPASS="$TMP/controller-ssh-askpass" \
      SSH_AUTH_SOCK="$TMP/controller-agent" \
      SSH_AGENT_PID=999 \
      GIT_CONFIG_GLOBAL="$TMP/controller-gitconfig" \
      GIT_CONFIG_SYSTEM="$TMP/controller-system-gitconfig" \
      GIT_CONFIG_COUNT=1 \
      GIT_CONFIG_KEY_0=credential.helper \
      GIT_CONFIG_VALUE_0=controller-helper \
      GIT_SSH_COMMAND='controller ssh command' \
      TERM=controller-term \
      "$launcher"
  )
}

assert_argv() {
  local capture="$1" kind="$2" profile="$3" prompt="$4"
  if python3 - "$capture.argv" "$kind" "$profile" "$REPO" "$prompt" <<'PY'
import os
from pathlib import Path
import sys

raw = Path(sys.argv[1]).read_bytes()
parts = raw.split(b"\0")
if not parts or parts[-1] != b"":
    raise SystemExit("capture is not NUL-delimited")
actual = parts[:-1]
kind = sys.argv[2]
profile = os.fsencode(sys.argv[3])
repo = os.fsencode(sys.argv[4])
prompt = Path(sys.argv[5]).read_bytes()
if kind == "omp":
    expected = [b"--profile", profile, b"-p", b"--cwd", repo, b"--", prompt]
else:
    expected = [b"chat", b"-p", profile, b"-q", prompt]
if actual != expected:
    raise SystemExit(f"argv differs: {actual!r} != {expected!r}")
PY
  then
    pass
  else
    fail "$kind launcher preserves exact argv and prompt bytes"
  fi
}

assert_bound_environment() {
  local capture="$1" role="$2"
  if python3 - \
    "$capture.env" "$role" "$REPO" \
    "$OMP_HOME" "$HERMES_HOME" "$OMP_XDG" "$HERMES_XDG" \
    "$OMP_BIN_DIR" "$HERMES_BIN_DIR" <<'PY'
import os
from pathlib import Path
import sys

raw, role, repo, omp_home, hermes_home, omp_xdg, hermes_xdg, omp_path, hermes_path = sys.argv[1:]
items = Path(raw).read_bytes().split(b"\0")
environment = {}
for item in items:
    if not item:
        continue
    key, value = item.split(b"=", 1)
    environment[key] = value
forbidden = {
    b"GH_TOKEN",
    b"GITHUB_TOKEN",
    b"LINEAR_API_KEY",
    b"LINEAR_ACCESS_TOKEN",
    b"LINEAR_OAUTH_TOKEN",
    b"WOO_HERMES_LINEAR_APP_ACCESS_TOKEN",
    b"WOO_OMP_LINEAR_APP_ACCESS_TOKEN",
    b"GIT_ASKPASS",
    b"SSH_ASKPASS",
    b"SSH_AGENT_PID",
    b"GIT_CONFIG_COUNT",
    b"GIT_CONFIG_KEY_0",
    b"GIT_CONFIG_VALUE_0",
    b"GIT_SSH_COMMAND",
}
leaked = sorted(forbidden.intersection(environment))
if leaked:
    raise SystemExit(f"controller credential environment leaked: {leaked!r}")
unpinned_controller_roots = {
    b"XDG_CACHE_HOME",
    b"XDG_DATA_HOME",
    b"XDG_STATE_HOME",
}
leaked_roots = sorted(unpinned_controller_roots.intersection(environment))
if leaked_roots:
    raise SystemExit(f"unpinned controller XDG roots leaked: {leaked_roots!r}")
if environment.get(b"PWD") != os.fsencode(repo):
    raise SystemExit("launcher did not enter the bound repository")
if environment.get(b"LANG") != b"C":
    raise SystemExit("manifest LANG pin was not authoritative")
if environment.get(b"TERM") != b"controller-term":
    raise SystemExit("harmless terminal metadata was not inherited")
if role == "omp":
    expected = (omp_home, omp_xdg, omp_path)
    actual = (
        os.fsdecode(environment.get(b"HOME", b"")),
        os.fsdecode(environment.get(b"XDG_CONFIG_HOME", b"")),
        os.fsdecode(environment.get(b"PATH", b"")),
    )
    if b"HERMES_HOME" in environment or b"HERMES_CONFIG_HOME" in environment:
        raise SystemExit("Hermes environment crossed into omp")
else:
    expected = (hermes_home, hermes_xdg, hermes_path)
    actual = (
        os.fsdecode(environment.get(b"HOME", b"")),
        os.fsdecode(environment.get(b"XDG_CONFIG_HOME", b"")),
        os.fsdecode(environment.get(b"PATH", b"")),
    )
    if (
        b"OMP_HOME" in environment
        or b"OMP_CONFIG_HOME" in environment
        or b"SSH_AUTH_SOCK" in environment
    ):
        raise SystemExit("omp or controller SSH environment crossed into Hermes")
if actual != expected:
    raise SystemExit(f"role-owned environment pins differ: {actual!r} != {expected!r}")
PY
  then
    pass
  else
    fail "$role launcher uses only bound role environment plus harmless inherited metadata"
  fi
}

ENGINEER_NAME="$ENGINEER_NAME" WOO_ENGINEER_LAUNCHER_ROOT="$LAUNCHER_ROOT" bash "$INSTALLER"
assert_eq "$(mode_of "$LAUNCHER_ROOT")" "0700" "installer secures the shared launcher root"
assert_eq "$(mode_of "$LAUNCHER_DIR")" "0700" "installer creates one private per-engineer launcher directory"
for launcher in launch-omp bind-engineer-unit; do
  assert_eq "$(mode_of "$LAUNCHER_DIR/$launcher")" "0500" "$launcher is mode 0500"
done
printf '%s\n' 'retired launcher' >"$LAUNCHER_DIR/launch-hermes-review"
chmod 500 "$LAUNCHER_DIR/launch-hermes-review"
ENGINEER_NAME="$ENGINEER_NAME" WOO_ENGINEER_LAUNCHER_ROOT="$LAUNCHER_ROOT" bash "$INSTALLER"
[ ! -e "$LAUNCHER_DIR/launch-hermes-review" ] \
  && pass || fail "installer removes the retired decision-maker review launcher"

IFS= read -r pinned_interpreter_line <"$LAUNCHER_DIR/launch-omp"
PINNED_INTERPRETER="${pinned_interpreter_line#\#!}"
[ "$PINNED_INTERPRETER" != "$pinned_interpreter_line" ] && [ -x "$PINNED_INTERPRETER" ] \
  && pass || fail "installed launchers pin one absolute executable Python interpreter"
if [ -x /usr/bin/python3 ]; then
  SYSTEM_RESOLVED_INTERPRETER="$(/usr/bin/python3 - <<'PY'
import os
import sys
print(os.path.realpath(sys.executable))
PY
)"
  assert_eq "$PINNED_INTERPRETER" "$SYSTEM_RESOLVED_INTERPRETER" \
    "the trusted system shim resolves to and embeds its actual canonical interpreter"
  if [ "$SYSTEM_RESOLVED_INTERPRETER" != /usr/bin/python3 ]; then
    set +e
    WOO_ENGINEER_PYTHON=/usr/bin/python3 \
      ENGINEER_NAME="engineer.explicit-shim" \
      WOO_ENGINEER_LAUNCHER_ROOT="$LAUNCHER_ROOT" \
      /bin/bash "$INSTALLER" >/dev/null 2>&1
    explicit_shim_status=$?
    set -e
    assert_exit 1 "$explicit_shim_status" \
      "the system-shim exception never weakens exact equality for an explicit interpreter pin"
  fi
fi

PINNED_ENGINEER="engineer.pinned"
WOO_ENGINEER_PYTHON="$PINNED_INTERPRETER" \
  ENGINEER_NAME="$PINNED_ENGINEER" \
  WOO_ENGINEER_LAUNCHER_ROOT="$LAUNCHER_ROOT" \
  /bin/bash "$INSTALLER"
assert_eq "$(mode_of "$LAUNCHER_ROOT/$PINNED_ENGINEER/launch-omp")" "0500" \
  "an explicitly pinned safe interpreter installs reviewed launchers"

UNSAFE_INTERPRETER="$TMP/unsafe-python"
UNSAFE_INTERPRETER_MARKER="$TMP/unsafe-python-ran"
cat >"$UNSAFE_INTERPRETER" <<EOF
#!/bin/sh
echo invoked >"$UNSAFE_INTERPRETER_MARKER"
exec "$PINNED_INTERPRETER" "\$@"
EOF
chmod 777 "$UNSAFE_INTERPRETER"
set +e
WOO_ENGINEER_PYTHON="$UNSAFE_INTERPRETER" \
  ENGINEER_NAME="engineer.unsafe-python" \
  WOO_ENGINEER_LAUNCHER_ROOT="$LAUNCHER_ROOT" \
  /bin/bash "$INSTALLER" >/dev/null 2>&1
unsafe_interpreter_status=$?
set -e
assert_exit 1 "$unsafe_interpreter_status" \
  "a caller-selected interpreter that does not resolve to the trusted executable is rejected"
if [ -x /usr/bin/python3 ]; then
  [ ! -e "$UNSAFE_INTERPRETER_MARKER" ] \
    && pass || fail "the safe bootstrap rejects an unsafe interpreter before executing it"
fi

if [ -x /usr/bin/python3 ]; then
  POISON_PYTHON_DIR="$TMP/poison-python"
  POISON_PYTHON_MARKER="$TMP/poison-python-ran"
  mkdir -p "$POISON_PYTHON_DIR"
  cat >"$POISON_PYTHON_DIR/python3" <<EOF
#!/bin/sh
echo invoked >"$POISON_PYTHON_MARKER"
exit 99
EOF
  chmod 700 "$POISON_PYTHON_DIR/python3"
  FALLBACK_ENGINEER="engineer.system-python"
  PATH="$POISON_PYTHON_DIR" \
    ENGINEER_NAME="$FALLBACK_ENGINEER" \
    WOO_ENGINEER_LAUNCHER_ROOT="$LAUNCHER_ROOT" \
    /bin/bash "$INSTALLER"
  [ ! -e "$POISON_PYTHON_MARKER" ] && pass || fail "controller PATH cannot select the installer interpreter"
  assert_eq "$(mode_of "$LAUNCHER_ROOT/$FALLBACK_ENGINEER/launch-omp")" "0500" \
    "the installer prefers the verified system interpreter when controller PATH is unsafe"
else
  pass
fi
[ ! -e "$REPO/.omp/agents" ] && pass || fail "installer never recreates project .omp/agents"

before="$(file_state "$LAUNCHER_DIR/launch-omp" "$LAUNCHER_DIR/bind-engineer-unit")"
ENGINEER_NAME="$ENGINEER_NAME" WOO_ENGINEER_LAUNCHER_ROOT="$LAUNCHER_ROOT" bash "$INSTALLER"
after="$(file_state "$LAUNCHER_DIR/launch-omp" "$LAUNCHER_DIR/bind-engineer-unit")"
assert_eq "$after" "$before" "idempotent install leaves all reviewed static launchers untouched"
leftovers="$(python3 - "$LAUNCHER_DIR" <<'PY'
from pathlib import Path
import sys
print("\n".join(sorted(path.name for path in Path(sys.argv[1]).glob(".*.tmp"))))
PY
)"
assert_eq "$leftovers" "" "atomic install leaves no temporary launcher files"

UNBOUND_DISPATCH="$TMP/unbound-dispatch"
stage_dispatch "$UNBOUND_DISPATCH" "$ENGINEER_NAME" "$REPO"
set +e
launch_with_hostile_controller "$LAUNCHER_DIR/launch-omp" "$UNBOUND_DISPATCH" >/dev/null 2>&1
unbound_status=$?
set -e
assert_exit 64 "$unbound_status" "launch is rejected until the trusted controller binds unit authority"
[ ! -e "$OMP_CAPTURE.argv" ] && pass || fail "unbound launch never reaches a controller or pinned executable"

BIND_DIR="$TMP/bind-valid"
bind_valid_unit "$BIND_DIR"
assert_eq "$(mode_of "$LAUNCHER_DIR/unit-authority.json")" "0400" "binder atomically installs adjacent read-only unit authority"
bound_static_before="$(file_state "$LAUNCHER_DIR/launch-omp" "$LAUNCHER_DIR/bind-engineer-unit")"
bound_authority_before="$(file_state "$LAUNCHER_DIR/unit-authority.json")"
ENGINEER_NAME="$ENGINEER_NAME" WOO_ENGINEER_LAUNCHER_ROOT="$LAUNCHER_ROOT" bash "$INSTALLER"
bound_static_after="$(file_state "$LAUNCHER_DIR/launch-omp" "$LAUNCHER_DIR/bind-engineer-unit")"
bound_authority_after="$(file_state "$LAUNCHER_DIR/unit-authority.json")"
assert_eq "$bound_static_after" "$bound_static_before" "idempotent static reinstall leaves reviewed launchers untouched after binding"
assert_eq "$bound_authority_after" "$bound_authority_before" "static reinstall never rewrites or removes bound unit authority"

SECOND_ENGINEER="engineer.2"
SECOND_LAUNCHER_DIR="$LAUNCHER_ROOT/$SECOND_ENGINEER"
ENGINEER_NAME="$SECOND_ENGINEER" WOO_ENGINEER_LAUNCHER_ROOT="$LAUNCHER_ROOT" bash "$INSTALLER"
assert_eq "$(mode_of "$SECOND_LAUNCHER_DIR")" "0700" "each active engineer receives a distinct private launcher directory"
for launcher in launch-omp bind-engineer-unit; do
  assert_eq "$(mode_of "$SECOND_LAUNCHER_DIR/$launcher")" "0500" "second unit receives reviewed static $launcher"
done
[ ! -e "$SECOND_LAUNCHER_DIR/unit-authority.json" ] \
  && pass || fail "installing a second unit never copies the first unit authority"
assert_eq "$(file_state "$LAUNCHER_DIR/unit-authority.json")" "$bound_authority_before" \
  "installing another engineer never changes the first unit authority"

OMP_DISPATCH="$TMP/dispatch-omp"
stage_dispatch "$OMP_DISPATCH" "$ENGINEER_NAME" "$REPO"
cp "$OMP_DISPATCH/prompt" "$TMP/expected-prompt"
set +e
launch_with_hostile_controller "$LAUNCHER_DIR/launch-omp" "$OMP_DISPATCH"
omp_status=$?
set -e
assert_exit 37 "$omp_status" "omp launcher preserves the pinned executable exit status"
assert_argv "$OMP_CAPTURE" omp "$ENGINEER_NAME" "$TMP/expected-prompt"
assert_bound_environment "$OMP_CAPTURE" omp
[ ! -e "$CONTROLLER_CAPTURE.argv" ] && pass || fail "controller PATH cannot substitute the pinned omp executable"
[ ! -e "$REPO/pwned-dollar" ] && [ ! -e "$REPO/pwned-backtick" ] && [ ! -e "$REPO/pwned-semicolon" ] \
  && [ ! -e "$OMP_DISPATCH/pwned-dollar" ] && [ ! -e "$OMP_DISPATCH/pwned-backtick" ] \
  && [ ! -e "$OMP_DISPATCH/pwned-semicolon" ] \
  && pass || fail "adversarial omp prompt bytes are never executed"



assert_omp_rejected() {
  local directory="$1" message="$2"
  rm -f "$OMP_CAPTURE.argv" "$OMP_CAPTURE.env" "$CONTROLLER_CAPTURE.argv" "$CONTROLLER_CAPTURE.env"
  set +e
  launch_with_hostile_controller "$LAUNCHER_DIR/launch-omp" "$directory" >/dev/null 2>&1
  local status=$?
  set -e
  assert_exit 64 "$status" "$message"
  [ ! -e "$OMP_CAPTURE.argv" ] && [ ! -e "$CONTROLLER_CAPTURE.argv" ] \
    && pass || fail "$message before executable dispatch"
}

BAD_PROFILE="$TMP/bad-profile"
stage_dispatch "$BAD_PROFILE" "other-engineer" "$REPO"
assert_omp_rejected "$BAD_PROFILE" "a staged profile that differs from bound omp.profile is rejected"

BAD_REPO="$TMP/bad-repo"
stage_dispatch "$BAD_REPO" "$ENGINEER_NAME" "$OTHER_REPO"
assert_omp_rejected "$BAD_REPO" "a canonical repo that differs from the bound accepted worktree is rejected"

NUL_PROMPT="$TMP/nul-prompt"
stage_dispatch "$NUL_PROMPT" "$ENGINEER_NAME" "$REPO"
python3 - "$NUL_PROMPT/prompt" <<'PY'
from pathlib import Path
import sys
Path(sys.argv[1]).write_bytes(b"before\0after")
PY
chmod 600 "$NUL_PROMPT/prompt"
assert_omp_rejected "$NUL_PROMPT" "NUL prompt bytes are rejected"

REAL_PROFILE="$TMP/real-profile"
printf '%s' "$ENGINEER_NAME" >"$REAL_PROFILE"
chmod 600 "$REAL_PROFILE"
SYMLINK_INPUT="$TMP/symlink-input"
stage_dispatch "$SYMLINK_INPUT" "$ENGINEER_NAME" "$REPO"
rm "$SYMLINK_INPUT/profile"
ln -s "$REAL_PROFILE" "$SYMLINK_INPUT/profile"
assert_omp_rejected "$SYMLINK_INPUT" "symlinked staged files are rejected"

BAD_FILE_MODE="$TMP/bad-file-mode"
stage_dispatch "$BAD_FILE_MODE" "$ENGINEER_NAME" "$REPO"
chmod 644 "$BAD_FILE_MODE/prompt"
assert_omp_rejected "$BAD_FILE_MODE" "staged files not mode 0600 are rejected"

BAD_DIR_MODE="$TMP/bad-dir-mode"
stage_dispatch "$BAD_DIR_MODE" "$ENGINEER_NAME" "$REPO"
chmod 755 "$BAD_DIR_MODE"
assert_omp_rejected "$BAD_DIR_MODE" "dispatch directories not mode 0700 are rejected"

assert_bind_rejected() {
  local directory="$1" message="$2"
  local before_authority after_authority
  before_authority="$(file_state "$LAUNCHER_DIR/unit-authority.json")"
  set +e
  (cd "$directory" && "$LAUNCHER_DIR/bind-engineer-unit" >/dev/null 2>&1)
  local status=$?
  set -e
  assert_exit 64 "$status" "$message"
  after_authority="$(file_state "$LAUNCHER_DIR/unit-authority.json")"
  assert_eq "$after_authority" "$before_authority" "$message without replacing valid authority"
}

BAD_MANIFEST_MODE="$TMP/bind-bad-mode"
mkdir -p "$BAD_MANIFEST_MODE"
chmod 700 "$BAD_MANIFEST_MODE"
write_valid_unit "$BAD_MANIFEST_MODE/unit.json"
chmod 644 "$BAD_MANIFEST_MODE/unit.json"
assert_bind_rejected "$BAD_MANIFEST_MODE" "unit.json must have mode 0600"

MISSING_MANIFEST="$TMP/bind-missing"
mkdir -p "$MISSING_MANIFEST"
chmod 700 "$MISSING_MANIFEST"
assert_bind_rejected "$MISSING_MANIFEST" "missing unit.json is rejected"

SYMLINK_MANIFEST="$TMP/bind-symlink"
mkdir -p "$SYMLINK_MANIFEST"
chmod 700 "$SYMLINK_MANIFEST"
ln -s "$BIND_DIR/unit.json" "$SYMLINK_MANIFEST/unit.json"
assert_bind_rejected "$SYMLINK_MANIFEST" "symlinked unit.json is rejected"

MALFORMED_MANIFEST="$TMP/bind-malformed"
mkdir -p "$MALFORMED_MANIFEST"
chmod 700 "$MALFORMED_MANIFEST"
printf '%s' '{"schemaVersion":1' >"$MALFORMED_MANIFEST/unit.json"
chmod 600 "$MALFORMED_MANIFEST/unit.json"
assert_bind_rejected "$MALFORMED_MANIFEST" "malformed unit authority JSON is rejected"

make_changed_manifest() {
  local directory="$1" mutation="$2"
  mkdir -p "$directory"
  chmod 700 "$directory"
  write_valid_unit "$directory/unit.json"
  python3 - "$directory/unit.json" "$mutation" "$OTHER_REPO" "$TMP" <<'PY'
import json
from pathlib import Path
import sys

path = Path(sys.argv[1])
mutation = sys.argv[2]
value = json.loads(path.read_text(encoding="utf-8"))
if mutation == "same-profile":
    value["hermes"]["profile"] = value["omp"]["profile"]
elif mutation == "shared-home":
    value["hermes"]["environment"]["HOME"] = value["omp"]["environment"]["HOME"]
elif mutation == "wrong-engineer":
    value["engineerName"] = "other-engineer"
elif mutation == "wrong-repository":
    value["repository"] = sys.argv[3]
elif mutation == "relative-program":
    value["omp"]["program"] = "omp"
elif mutation == "writable-program":
    unsafe_program = Path(sys.argv[4]) / "writable-omp"
    unsafe_program.write_bytes(Path(value["omp"]["program"]).read_bytes())
    unsafe_program.chmod(0o722)
    value["omp"]["program"] = str(unsafe_program)
elif mutation == "unsafe-path":
    unsafe = Path(sys.argv[4]) / "unsafe-path"
    unsafe.mkdir(exist_ok=True)
    unsafe.chmod(0o777)
    value["omp"]["environment"]["PATH"] = str(unsafe)
elif mutation == "secret":
    value["omp"]["environment"]["GH_TOKEN"] = "secret-value"
elif mutation == "arbitrary-env":
    value["hermes"]["environment"]["PYTHONPATH"] = str(Path(sys.argv[4]))
else:
    raise SystemExit(f"unknown mutation {mutation}")
path.write_text(json.dumps(value), encoding="utf-8")
PY
  chmod 600 "$directory/unit.json"
}

for case in same-profile shared-home wrong-engineer relative-program writable-program unsafe-path secret arbitrary-env; do
  directory="$TMP/bind-$case"
  make_changed_manifest "$directory" "$case"
  assert_bind_rejected "$directory" "$case unit authority is rejected"
done

SYMLINK_PROGRAM_DIR="$TMP/bind-symlink-program"
mkdir -p "$SYMLINK_PROGRAM_DIR"
chmod 700 "$SYMLINK_PROGRAM_DIR"
write_valid_unit "$SYMLINK_PROGRAM_DIR/unit.json"
ln -s "$OMP_BIN_DIR/omp" "$TMP/omp-link"
python3 - "$SYMLINK_PROGRAM_DIR/unit.json" "$TMP/omp-link" <<'PY'
import json
from pathlib import Path
import sys
path = Path(sys.argv[1])
value = json.loads(path.read_text(encoding="utf-8"))
value["omp"]["program"] = sys.argv[2]
path.write_text(json.dumps(value), encoding="utf-8")
PY
chmod 600 "$SYMLINK_PROGRAM_DIR/unit.json"
assert_bind_rejected "$SYMLINK_PROGRAM_DIR" "symlinked pinned programs are rejected"

AUTHORITY_BACKUP="$TMP/unit-authority.backup"
cp "$LAUNCHER_DIR/unit-authority.json" "$AUTHORITY_BACKUP"
chmod 400 "$AUTHORITY_BACKUP"

restore_authority() {
  rm -f "$LAUNCHER_DIR/unit-authority.json"
  cp "$AUTHORITY_BACKUP" "$LAUNCHER_DIR/unit-authority.json"
  chmod 400 "$LAUNCHER_DIR/unit-authority.json"
}

chmod 600 "$LAUNCHER_DIR/unit-authority.json"
AUTHORITY_MODE_DISPATCH="$TMP/authority-mode-dispatch"
stage_dispatch "$AUTHORITY_MODE_DISPATCH" "$ENGINEER_NAME" "$REPO"
assert_omp_rejected "$AUTHORITY_MODE_DISPATCH" "unit authority with the wrong mode is rejected"
restore_authority

chmod 600 "$LAUNCHER_DIR/unit-authority.json"
printf '%s' '{"schemaVersion":1' >"$LAUNCHER_DIR/unit-authority.json"
chmod 400 "$LAUNCHER_DIR/unit-authority.json"
MALFORMED_AUTHORITY_DISPATCH="$TMP/malformed-authority-dispatch"
stage_dispatch "$MALFORMED_AUTHORITY_DISPATCH" "$ENGINEER_NAME" "$REPO"
assert_omp_rejected "$MALFORMED_AUTHORITY_DISPATCH" "malformed installed authority is rejected"
restore_authority

python3 - "$LAUNCHER_DIR/unit-authority.json" <<'PY'
import json
from pathlib import Path
import sys
path = Path(sys.argv[1])
value = json.loads(path.read_text(encoding="utf-8"))
value["hermes"]["environment"]["LINEAR_ACCESS_TOKEN"] = "must-not-load"
path.chmod(0o600)
path.write_text(
    json.dumps(value, ensure_ascii=True, sort_keys=True, separators=(",", ":")) + "\n",
    encoding="ascii",
)
path.chmod(0o400)
PY
SECRET_AUTHORITY_DISPATCH="$TMP/secret-authority-dispatch"
stage_dispatch "$SECRET_AUTHORITY_DISPATCH" "$ENGINEER_NAME" "$REPO"
assert_omp_rejected "$SECRET_AUTHORITY_DISPATCH" "secret-bearing installed authority is rejected"
restore_authority

rm "$LAUNCHER_DIR/unit-authority.json"
ln -s "$AUTHORITY_BACKUP" "$LAUNCHER_DIR/unit-authority.json"
SYMLINK_AUTHORITY_DISPATCH="$TMP/symlink-authority-dispatch"
stage_dispatch "$SYMLINK_AUTHORITY_DISPATCH" "$ENGINEER_NAME" "$REPO"
assert_omp_rejected "$SYMLINK_AUTHORITY_DISPATCH" "symlinked installed authority is rejected"
restore_authority

LINKED_ROOT="$TMP/linked-launcher-root"
ln -s "$LAUNCHER_ROOT" "$LINKED_ROOT"
set +e
ENGINEER_NAME="$ENGINEER_NAME" WOO_ENGINEER_LAUNCHER_ROOT="$LINKED_ROOT" bash "$INSTALLER" >/dev/null 2>&1
linked_status=$?
set -e
assert_exit 1 "$linked_status" "installer rejects a symlinked shared launcher root"

set +e
ENGINEER_NAME='bad/name' WOO_ENGINEER_LAUNCHER_ROOT="$LAUNCHER_ROOT" bash "$INSTALLER" >/dev/null 2>&1
bad_engineer_status=$?
set -e
assert_exit 1 "$bad_engineer_status" "installer rejects an unsafe or ambiguous engineer identity"
[ ! -e "$REPO/.omp/agents" ] && pass || fail "launcher rejection paths never create project agent definitions"

finish
