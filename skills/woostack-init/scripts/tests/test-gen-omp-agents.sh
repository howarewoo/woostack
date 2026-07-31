#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="$HERE/../gen-omp-agents.sh"
# shellcheck disable=SC1091
source "$HERE/assert.sh"

TMP="$(mktemp -d)"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
LAUNCHER_DIR="$TMP/launchers"
FAKEBIN="$TMP/bin"
PROFILE_HOME="$LAUNCHER_DIR/profiles/engineer.1"
PROFILE_XDG="$PROFILE_HOME/.config"
REVIEWER_HOME="$LAUNCHER_DIR/profiles/reviewer-1"
CALLER_HOME="$TMP/caller-home"
CALLER_XDG="$CALLER_HOME/xdg-config"
REPO_RAW="$TMP/repo"
mkdir -p \
  "$FAKEBIN" "$PROFILE_HOME/runtime" "$PROFILE_HOME/tmp" \
  "$REVIEWER_HOME/runtime" "$REVIEWER_HOME/tmp" \
  "$CALLER_XDG" "$REPO_RAW"
chmod 700 "$PROFILE_HOME" "$PROFILE_HOME/runtime" "$PROFILE_HOME/tmp"
chmod 700 "$REVIEWER_HOME" "$REVIEWER_HOME/runtime" "$REVIEWER_HOME/tmp"
git -C "$REPO_RAW" init -q
REPO="$(cd "$REPO_RAW" && pwd -P)"

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
source = f'''#!{sys.executable}
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
with open(str(base) + ".pid", "w", encoding="ascii") as handle:
    handle.write(str(os.getpid()))
raise SystemExit({status})
'''
program.write_text(source, encoding="utf-8")
program.chmod(0o700)
PY
}

stage_dispatch() {
  local directory="$1" profile="$2" repo="$3" session="${4:-}"
  mkdir -p "$directory"
  chmod 700 "$directory"
  printf '%s' "$profile" >"$directory/profile"
  printf '%s' "$repo" >"$directory/repo"
  printf '%s' "$session" >"$directory/session"
  cat >"$directory/prompt" <<'PROMPT'
-$(touch pwned-dollar)
`touch pwned-backtick`
'quoted' "double-quoted"; touch pwned-semicolon
literal second line
PROMPT
  printf '\377' >>"$directory/prompt"
  chmod 600 "$directory/profile" "$directory/repo" "$directory/prompt" "$directory/session"
}

assert_argv() {
  local capture="$1" kind="$2" profile="$3" prompt="$4" session="${5:-}"
  if python3 - "$capture.argv" "$kind" "$profile" "$REPO" "$prompt" "$session" <<'PY'
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
session = os.fsencode(sys.argv[6])
if kind == "omp":
    expected = [b"--profile", profile]
    if session:
        expected.extend([b"--resume", session])
    expected.extend([b"-p", b"--cwd", repo, b"--", prompt])
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

assert_scrubbed_environment() {
  local capture="$1" expected_home="$2"
  if python3 - "$capture.env" "$expected_home" "$REPO" <<'PY'
import os
from pathlib import Path
import sys

parts = Path(sys.argv[1]).read_bytes().split(b"\0")
environment = {}
for item in parts:
    if not item:
        continue
    key, value = item.split(b"=", 1)
    environment[key] = value
forbidden = {
    b"GH_TOKEN",
    b"GITHUB_TOKEN",
    b"LINEAR_API_KEY",
    b"LINEAR_ACCESS_TOKEN",
    b"GIT_ASKPASS",
    b"SSH_ASKPASS",
    b"SSH_AUTH_SOCK",
    b"SSH_AGENT_PID",
    b"GIT_CONFIG_COUNT",
    b"GIT_CONFIG_KEY_0",
    b"GIT_CONFIG_VALUE_0",
    b"GIT_SSH_COMMAND",
    b"GIT_CONFIG_SYSTEM",
}
leaked = sorted(forbidden.intersection(environment))
if leaked:
    raise SystemExit(f"credential environment leaked: {leaked!r}")
home = os.fsencode(sys.argv[2])
if environment.get(b"HOME") != home:
    raise SystemExit("launcher did not install the profile-owned HOME")
if environment.get(b"XDG_CONFIG_HOME") != os.path.join(home, b".config"):
    raise SystemExit("launcher did not install the profile-owned XDG_CONFIG_HOME")
if environment.get(b"GH_CONFIG_DIR") != os.path.join(home, b".config", b"gh"):
    raise SystemExit("launcher did not install the profile-owned GH_CONFIG_DIR")
if environment.get(b"GIT_CONFIG_GLOBAL") != os.path.join(home, b".gitconfig"):
    raise SystemExit("launcher did not install the profile-owned GIT_CONFIG_GLOBAL")
if environment.get(b"PWD") != os.fsencode(sys.argv[3]):
    raise SystemExit("launcher did not enter the canonical repo")
PY
  then
    pass
  else
    fail "launcher scrubs controller credentials and installs profile-owned CLI roots"
  fi
}

(cd "$REPO" && WOO_ENGINEER_LAUNCHER_DIR="$LAUNCHER_DIR" bash "$INSTALLER")
assert_eq "$(mode_of "$LAUNCHER_DIR")" "0700" "installer secures the host launcher directory"
assert_eq "$(mode_of "$LAUNCHER_DIR/launch-omp")" "0500" "omp launcher is mode 0500"
assert_eq "$(mode_of "$LAUNCHER_DIR/launch-hermes-review")" "0500" "Hermes review launcher is mode 0500"
[ ! -e "$REPO/.omp/agents" ] && pass || fail "installer never recreates project .omp/agents"

before="$(file_state "$LAUNCHER_DIR/launch-omp" "$LAUNCHER_DIR/launch-hermes-review")"
(cd "$REPO" && WOO_ENGINEER_LAUNCHER_DIR="$LAUNCHER_DIR" bash "$INSTALLER")
after="$(file_state "$LAUNCHER_DIR/launch-omp" "$LAUNCHER_DIR/launch-hermes-review")"
assert_eq "$after" "$before" "idempotent install leaves reviewed launcher files untouched"
leftovers="$(python3 - "$LAUNCHER_DIR" <<'PY'
from pathlib import Path
import sys
print("\n".join(sorted(path.name for path in Path(sys.argv[1]).glob(".*.tmp"))))
PY
)"
assert_eq "$leftovers" "" "atomic install leaves no temporary launcher files"

OMP_CAPTURE="$TMP/omp-capture"
HERMES_CAPTURE="$TMP/hermes-capture"
make_fake "$FAKEBIN/omp" "$OMP_CAPTURE" 37
make_fake "$FAKEBIN/hermes" "$HERMES_CAPTURE" 23

OMP_DISPATCH="$TMP/dispatch-omp"
stage_dispatch "$OMP_DISPATCH" "engineer.1" "$REPO" "omp-session-1"
cp "$OMP_DISPATCH/prompt" "$TMP/expected-prompt"
set +e
(
  cd "$OMP_DISPATCH"
  env \
    PATH="$FAKEBIN:$PATH" \
    HOME="$CALLER_HOME" \
    XDG_CONFIG_HOME="$CALLER_XDG" \
    GH_TOKEN=controller-gh \
    GITHUB_TOKEN=controller-github \
    LINEAR_API_KEY=controller-linear \
    LINEAR_ACCESS_TOKEN=controller-linear-access \
    GH_CONFIG_DIR=/tmp/controller-gh \
    GIT_ASKPASS=/tmp/controller-askpass \
    SSH_ASKPASS=/tmp/controller-ssh-askpass \
    SSH_AUTH_SOCK=/tmp/controller-agent \
    SSH_AGENT_PID=999 \
    GIT_CONFIG_GLOBAL=/tmp/controller-gitconfig \
    GIT_CONFIG_SYSTEM=/tmp/controller-system-gitconfig \
    GIT_CONFIG_COUNT=1 \
    GIT_CONFIG_KEY_0=credential.helper \
    GIT_CONFIG_VALUE_0=controller-helper \
    GIT_SSH_COMMAND='controller ssh command' \
    "$LAUNCHER_DIR/launch-omp"
)
omp_status=$?
set -e
assert_exit 37 "$omp_status" "omp launcher preserves the executed program exit status"
assert_argv "$OMP_CAPTURE" omp "engineer.1" "$TMP/expected-prompt" "omp-session-1"
assert_scrubbed_environment "$OMP_CAPTURE" "$PROFILE_HOME"
[ ! -e "$REPO/pwned-dollar" ] && [ ! -e "$REPO/pwned-backtick" ] && [ ! -e "$REPO/pwned-semicolon" ] \
  && [ ! -e "$OMP_DISPATCH/pwned-dollar" ] && [ ! -e "$OMP_DISPATCH/pwned-backtick" ] \
  && [ ! -e "$OMP_DISPATCH/pwned-semicolon" ] \
  && pass || fail "adversarial omp prompt bytes are never executed"

HERMES_DISPATCH="$TMP/dispatch-hermes"
stage_dispatch "$HERMES_DISPATCH" "reviewer-1" "$REPO"
[ ! -s "$HERMES_DISPATCH/session" ] && pass || fail "Hermes reviewer stages an empty session file"
assert_eq "$(mode_of "$HERMES_DISPATCH/session")" "0600" "Hermes reviewer session file is mode 0600"
set +e
(
  cd "$HERMES_DISPATCH"
  env \
    PATH="$FAKEBIN:$PATH" \
    HOME="$CALLER_HOME" \
    XDG_CONFIG_HOME="$CALLER_XDG" \
    GH_TOKEN=controller-gh \
    GITHUB_TOKEN=controller-github \
    LINEAR_API_KEY=controller-linear \
    LINEAR_ACCESS_TOKEN=controller-linear-access \
    GH_CONFIG_DIR=/tmp/controller-gh \
    GIT_ASKPASS=/tmp/controller-askpass \
    SSH_ASKPASS=/tmp/controller-ssh-askpass \
    SSH_AUTH_SOCK=/tmp/controller-agent \
    SSH_AGENT_PID=999 \
    GIT_CONFIG_GLOBAL=/tmp/controller-gitconfig \
    GIT_CONFIG_SYSTEM=/tmp/controller-system-gitconfig \
    GIT_CONFIG_COUNT=1 \
    GIT_CONFIG_KEY_0=credential.helper \
    GIT_CONFIG_VALUE_0=controller-helper \
    GIT_SSH_COMMAND='controller ssh command' \
    "$LAUNCHER_DIR/launch-hermes-review"
)
hermes_status=$?
set -e
assert_exit 23 "$hermes_status" "Hermes launcher preserves the executed program exit status"
assert_argv "$HERMES_CAPTURE" hermes "reviewer-1" "$HERMES_DISPATCH/prompt"
assert_scrubbed_environment "$HERMES_CAPTURE" "$REVIEWER_HOME"
[ ! -e "$REPO/pwned-dollar" ] && [ ! -e "$REPO/pwned-backtick" ] && [ ! -e "$REPO/pwned-semicolon" ] \
  && [ ! -e "$HERMES_DISPATCH/pwned-dollar" ] && [ ! -e "$HERMES_DISPATCH/pwned-backtick" ] \
  && [ ! -e "$HERMES_DISPATCH/pwned-semicolon" ] \
  && pass || fail "adversarial Hermes prompt bytes are never executed"

assert_rejected() {
  local directory="$1" message="$2"
  rm -f "$OMP_CAPTURE.argv" "$OMP_CAPTURE.env" "$OMP_CAPTURE.pid"
  set +e
  (cd "$directory" && env PATH="$FAKEBIN:$PATH" HOME="$PROFILE_HOME" "$LAUNCHER_DIR/launch-omp" >/dev/null 2>&1)
  local status=$?
  set -e
  assert_exit 64 "$status" "$message"
  [ ! -e "$OMP_CAPTURE.argv" ] && pass || fail "$message before executable dispatch"
}

BAD_PROFILE="$TMP/bad-profile"
stage_dispatch "$BAD_PROFILE" "bad/profile" "$REPO"
assert_rejected "$BAD_PROFILE" "invalid profile grammar is rejected"

NUL_PROMPT="$TMP/nul-prompt"
stage_dispatch "$NUL_PROMPT" "engineer-1" "$REPO"
python3 - "$NUL_PROMPT/prompt" <<'PY'
from pathlib import Path
import sys
Path(sys.argv[1]).write_bytes(b"before\0after")
PY
chmod 600 "$NUL_PROMPT/prompt"
assert_rejected "$NUL_PROMPT" "NUL prompt bytes are rejected"

REAL_PROFILE="$TMP/real-profile"
printf '%s' engineer-1 >"$REAL_PROFILE"
chmod 600 "$REAL_PROFILE"
SYMLINK_INPUT="$TMP/symlink-input"
stage_dispatch "$SYMLINK_INPUT" "engineer-1" "$REPO"
rm "$SYMLINK_INPUT/profile"
ln -s "$REAL_PROFILE" "$SYMLINK_INPUT/profile"
assert_rejected "$SYMLINK_INPUT" "symlinked staged files are rejected"

BAD_FILE_MODE="$TMP/bad-file-mode"
stage_dispatch "$BAD_FILE_MODE" "engineer-1" "$REPO"
chmod 644 "$BAD_FILE_MODE/prompt"
assert_rejected "$BAD_FILE_MODE" "staged files not mode 0600 are rejected"

BAD_DIR_MODE="$TMP/bad-dir-mode"
stage_dispatch "$BAD_DIR_MODE" "engineer-1" "$REPO"
chmod 755 "$BAD_DIR_MODE"
assert_rejected "$BAD_DIR_MODE" "dispatch directories not mode 0700 are rejected"

REPO_LINK="$TMP/repo-link"
ln -s "$REPO" "$REPO_LINK"
BAD_REPO="$TMP/bad-repo"
stage_dispatch "$BAD_REPO" "engineer-1" "$REPO_LINK"
assert_rejected "$BAD_REPO" "noncanonical symlink repo paths are rejected"

LINKED_LAUNCHER_DIR="$TMP/linked-launchers"
ln -s "$LAUNCHER_DIR" "$LINKED_LAUNCHER_DIR"
set +e
(cd "$REPO" && WOO_ENGINEER_LAUNCHER_DIR="$LINKED_LAUNCHER_DIR" bash "$INSTALLER") >/dev/null 2>&1
linked_status=$?
set -e
assert_exit 1 "$linked_status" "installer rejects a symlinked host launcher directory"
[ ! -e "$REPO/.omp/agents" ] && pass || fail "launcher rejection paths never create project agent definitions"

finish
