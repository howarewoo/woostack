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
ENGINEER_NAME="engineer.1"
LAUNCHER_ROOT="$TMP/launcher-root"
LAUNCHER_DIR="$LAUNCHER_ROOT/$ENGINEER_NAME"
mkdir -p "$REPO/.woostack"

run_check() {
  (
    cd "$REPO"
    ENGINEER_NAME="$ENGINEER_NAME" \
      WOO_ENGINEER_LAUNCHER_ROOT="$LAUNCHER_ROOT" \
      HOME="$TMP/controller-home" \
      bash "$CHECK" "$REPO"
  )
}

fix_check() {
  (
    cd "$REPO"
    ENGINEER_NAME="$ENGINEER_NAME" \
      WOO_ENGINEER_LAUNCHER_ROOT="$LAUNCHER_ROOT" \
      HOME="$TMP/controller-home" \
      bash "$CHECK" --fix "$REPO"
  )
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
assert_contains "$missing" $'warn\tomp-agent\tauto\t' "missing project OMP agents produce auto-fixable doctor findings"
for tier in fast standard deep; do
  assert_contains "$missing" "woostack-$tier.md" "doctor identifies missing $tier role definition"
done
assert_contains "$missing" $'warn\tomp-agents\tauto\t' "missing per-engineer launchers produce an auto-fixable doctor finding"
for launcher in launch-omp bind-engineer-unit; do
  assert_contains "$missing" "$launcher" "doctor identifies missing $launcher"
done

fix_check
assert_eq "$(run_check)" "" "--fix invokes the installer and clears missing findings"
assert_eq "$(mode_of "$LAUNCHER_ROOT")" "0700" "doctor fix creates a private shared launcher root"
assert_eq "$(mode_of "$LAUNCHER_DIR")" "0700" "doctor fix creates a private per-engineer directory"
for launcher in launch-omp bind-engineer-unit; do
  assert_eq "$(mode_of "$LAUNCHER_DIR/$launcher")" "0500" "doctor fix restores $launcher mode 0500"
done
for tier in fast standard deep; do
  [ -f "$REPO/.omp/agents/woostack-$tier.md" ] \
    && pass || fail "doctor repair creates the managed $tier role definition"
done
printf '%s\n' 'consumer-owned' >"$REPO/.omp/agents/custom.md"
printf '%s\n' '---' 'name: woostack-standard' 'model: "@smol"' '---' >"$REPO/.omp/agents/woostack-standard.md"
role_drift="$(run_check)"
assert_contains "$role_drift" $'warn\tomp-agent\tauto\t' "doctor reports a wrong-role managed definition"
assert_contains "$role_drift" "wrong-role:" "doctor distinguishes wrong-role drift"
fix_check
assert_contains "$(cat "$REPO/.omp/agents/woostack-standard.md")" 'model: "@default"' \
  "doctor restores the standard host role"
assert_eq "$(cat "$REPO/.omp/agents/custom.md")" "consumer-owned" \
  "doctor repair preserves unrelated project agents"
printf '%s\n' '# stale body' >>"$REPO/.omp/agents/woostack-fast.md"
definition_drift="$(run_check)"
assert_contains "$definition_drift" "drifted:" "doctor reports stale managed definition content"
fix_check
assert_eq "$(run_check)" "" "doctor repair clears managed definition drift"
printf '%s\n' 'consumer-ignore' 'woostack-*.md' 'woostack-*.md' >"$REPO/.omp/agents/.gitignore"
ignore_drift="$(run_check)"
assert_contains "$ignore_drift" ".omp/agents/.gitignore" \
  "doctor reports duplicate generated-agent ignore coverage"
fix_check
assert_eq "$(cat "$REPO/.omp/agents/.gitignore")" $'consumer-ignore\nwoostack-*.md' \
  "doctor repair preserves consumer ignore lines and one managed rule"
printf '%s\n' 'retired launcher' >"$LAUNCHER_DIR/launch-hermes-review"
chmod 500 "$LAUNCHER_DIR/launch-hermes-review"
retired_launcher="$(run_check)"
assert_contains "$retired_launcher" "retired reviewer launcher is present; --fix removes it" \
  "doctor reports the retired decision-maker review launcher"
fix_check
[ ! -e "$LAUNCHER_DIR/launch-hermes-review" ] \
  && pass || fail "doctor repair removes the retired decision-maker review launcher"

chmod 755 "$LAUNCHER_ROOT"
root_drift="$(run_check)"
assert_contains "$root_drift" "launcher root mode is 0755, expected 0700" "doctor detects shared launcher root mode drift"
fix_check
assert_eq "$(mode_of "$LAUNCHER_ROOT")" "0700" "--fix restores launcher root mode 0700"

chmod 755 "$LAUNCHER_DIR"
directory_drift="$(run_check)"
assert_contains "$directory_drift" "per-engineer launcher directory mode is 0755, expected 0700" "doctor detects unit directory mode drift"
fix_check
assert_eq "$(mode_of "$LAUNCHER_DIR")" "0700" "--fix restores per-engineer directory mode 0700"
assert_eq "$(run_check)" "" "directory mode repair restores a clean doctor check"

before="$(file_state "$LAUNCHER_DIR/launch-omp")"
fix_check
after="$(file_state "$LAUNCHER_DIR/launch-omp")"
assert_eq "$after" "$before" "doctor repair is idempotent when static launchers are reviewed and clean"

printf '%s\n' 'DOCTOR_MUST_NOT_READ_THIS_SECRET' >"$LAUNCHER_DIR/profile-secret"
chmod 600 "$LAUNCHER_DIR/profile-secret"
assert_eq "$(run_check)" "" "doctor ignores unrelated host files instead of reading secrets"

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
rm "$LAUNCHER_DIR/bind-engineer-unit"
ln -s "$TMP/secret-target" "$LAUNCHER_DIR/bind-engineer-unit"
symlink_drift="$(run_check)"
assert_contains "$symlink_drift" "regular no-follow file" "doctor rejects a symlink in place of a launcher"
assert_not_contains "$symlink_drift" "SYMLINK_TARGET_SECRET" "doctor never follows or emits a symlink target's content"
fix_check
[ ! -L "$LAUNCHER_DIR/bind-engineer-unit" ] && pass || fail "--fix replaces a launcher symlink without following it"
assert_eq "$(cat "$TMP/secret-target")" "SYMLINK_TARGET_SECRET" "repair leaves a symlink target untouched"
assert_eq "$(run_check)" "" "symlink repair restores all reviewed launchers"

printf '%s\n' '{"schemaVersion":1}' >"$LAUNCHER_DIR/unit-authority.json"
chmod 600 "$LAUNCHER_DIR/unit-authority.json"
authority_mode="$(run_check)"
assert_contains "$authority_mode" "bound unit authority mode is 0600, expected 0400" "doctor rejects writable bound authority"
assert_contains "$authority_mode" $'warn\tomp-agents\treport\t' \
  "bound authority drift is report-only because static repair preserves the binding"
assert_not_contains "$authority_mode" $'warn\tomp-agents\tauto\t' \
  "bound authority drift is never advertised as auto-fixable"
chmod 400 "$LAUNCHER_DIR/unit-authority.json"
assert_eq "$(run_check)" "" "doctor accepts the authority file's canonical owner and mode without reading its contents"

rm "$LAUNCHER_DIR/unit-authority.json"
ln -s "$TMP/secret-target" "$LAUNCHER_DIR/unit-authority.json"
authority_link="$(run_check)"
assert_contains "$authority_link" "bound unit authority must be a regular no-follow file" "doctor rejects a symlinked authority file"
assert_not_contains "$authority_link" "SYMLINK_TARGET_SECRET" "doctor never reads a symlinked authority target"
rm "$LAUNCHER_DIR/unit-authority.json"

set +e
missing_name="$(cd "$REPO" && WOO_ENGINEER_LAUNCHER_ROOT="$LAUNCHER_ROOT" bash "$CHECK" "$REPO")"
missing_name_status=$?
set -e
assert_exit 0 "$missing_name_status" "optional doctor check reports rather than crashes without a selected engineer"
assert_contains "$missing_name" "ENGINEER_NAME must identify" "doctor refuses to guess a per-engineer directory"
assert_eq "$(run_check | grep -c $'warn\tomp-agent' || true)" "0" \
  "agent diagnosis remains clean without a selected engineer"

finish
