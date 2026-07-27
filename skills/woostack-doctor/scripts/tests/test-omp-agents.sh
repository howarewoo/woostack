#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/../checks/omp-agents.sh"
# shellcheck disable=SC1091
source "$HERE/../../../woostack-init/scripts/tests/assert.sh"

TMP="$(mktemp -d)"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
REPO="$TMP/repo"
LAUNCHER_DIR="$TMP/launchers"
mkdir -p "$REPO/.woostack"

run_check() {
  (cd "$REPO" && WOO_ENGINEER_LAUNCHER_DIR="$LAUNCHER_DIR" HOME="$TMP/home" bash "$CHECK" "$REPO")
}

fix_check() {
  (cd "$REPO" && WOO_ENGINEER_LAUNCHER_DIR="$LAUNCHER_DIR" HOME="$TMP/home" bash "$CHECK" --fix "$REPO")
}

mode_of() {
  python3 - "$1" <<'PY'
import os
import stat
import sys
print(f"{stat.S_IMODE(os.lstat(sys.argv[1]).st_mode):04o}")
PY
}

file_state() {
  python3 - "$1" <<'PY'
import os
import sys
value = os.stat(sys.argv[1], follow_symlinks=False)
print(f"{value.st_dev}:{value.st_ino}:{value.st_mtime_ns}:{value.st_size}")
PY
}

missing="$(run_check)"
assert_contains "$missing" $'warn\tomp-agents\tauto\t' "missing launchers produce an auto-fixable doctor finding"
assert_contains "$missing" "launch-omp" "doctor identifies the missing omp launcher"
assert_contains "$missing" "launch-hermes-review" "doctor identifies the missing Hermes reviewer launcher"

fix_check
assert_eq "$(run_check)" "" "--fix invokes the installer and clears missing findings"
assert_eq "$(mode_of "$LAUNCHER_DIR")" "0700" "doctor fix creates a private launcher directory"
assert_eq "$(mode_of "$LAUNCHER_DIR/launch-omp")" "0500" "doctor fix restores omp launcher mode 0500"
assert_eq "$(mode_of "$LAUNCHER_DIR/launch-hermes-review")" "0500" "doctor fix restores Hermes launcher mode 0500"
[ ! -e "$REPO/.omp/agents" ] && pass || fail "doctor repair never revives project .omp/agents"

chmod 755 "$LAUNCHER_DIR"
directory_drift="$(run_check)"
assert_contains "$directory_drift" "directory mode is 0755, expected 0700" "doctor detects launcher directory mode drift"
fix_check
assert_eq "$(mode_of "$LAUNCHER_DIR")" "0700" "--fix restores launcher directory mode 0700"
assert_eq "$(run_check)" "" "directory mode repair restores a clean doctor check"

before="$(file_state "$LAUNCHER_DIR/launch-omp")"
fix_check
after="$(file_state "$LAUNCHER_DIR/launch-omp")"
assert_eq "$after" "$before" "doctor repair is idempotent when launchers are reviewed and clean"

printf '%s\n' 'DOCTOR_MUST_NOT_READ_THIS_SECRET' >"$LAUNCHER_DIR/profile-secret"
chmod 600 "$LAUNCHER_DIR/profile-secret"
assert_eq "$(run_check)" "" "doctor ignores non-launcher host files instead of reading secrets"

chmod 700 "$LAUNCHER_DIR/launch-omp"
mode_drift="$(run_check)"
assert_contains "$mode_drift" "mode is 0700, expected 0500" "doctor detects launcher mode drift"
assert_not_contains "$mode_drift" "DOCTOR_MUST_NOT_READ_THIS_SECRET" "mode diagnosis never emits unrelated secret content"
fix_check
assert_eq "$(mode_of "$LAUNCHER_DIR/launch-omp")" "0500" "--fix repairs launcher mode drift"
assert_eq "$(run_check)" "" "mode repair restores a clean checksum and mode"

chmod 700 "$LAUNCHER_DIR/launch-omp"
printf '%s\n' '# drift' >>"$LAUNCHER_DIR/launch-omp"
chmod 500 "$LAUNCHER_DIR/launch-omp"
checksum_drift="$(run_check)"
assert_contains "$checksum_drift" "checksum differs" "doctor detects reviewed launcher checksum drift"
assert_not_contains "$checksum_drift" "# drift" "checksum diagnosis does not echo launcher content"
fix_check
assert_eq "$(run_check)" "" "--fix atomically reinstalls checksum-drifted launchers"

printf '%s\n' 'SYMLINK_TARGET_SECRET' >"$TMP/secret-target"
chmod 500 "$TMP/secret-target"
rm "$LAUNCHER_DIR/launch-hermes-review"
ln -s "$TMP/secret-target" "$LAUNCHER_DIR/launch-hermes-review"
symlink_drift="$(run_check)"
assert_contains "$symlink_drift" "regular no-follow file" "doctor rejects a symlink in place of a launcher"
assert_not_contains "$symlink_drift" "SYMLINK_TARGET_SECRET" "doctor never follows or emits a symlink target's content"
fix_check
[ ! -L "$LAUNCHER_DIR/launch-hermes-review" ] && pass || fail "--fix replaces a launcher symlink without following it"
assert_eq "$(cat "$TMP/secret-target")" "SYMLINK_TARGET_SECRET" "repair leaves a symlink target untouched"
assert_eq "$(run_check)" "" "symlink repair restores both reviewed launchers"
[ ! -e "$REPO/.omp/agents" ] && pass || fail "all doctor repairs remain host-only"

finish
