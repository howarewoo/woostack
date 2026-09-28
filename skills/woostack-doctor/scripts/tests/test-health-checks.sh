#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../woostack-init/scripts/tests/assert.sh"
set +e
C="$HERE/../checks"

# gitignore-drift is read-only report evidence: no check-owned repair remains.
r="$(mktemp -d)"
mkdir -p "$r/.woostack"
: >"$r/.woostack/.gitignore"
out="$(bash "$C/gitignore-drift.sh" "$r")"
assert_contains "$out" "gitignore-drift" "empty .gitignore drifts"
assert_contains "$out" $'warn\tgitignore-drift\treport\t' "drift is report-only"
assert_not_contains "$out" $'auto\t' "drift never recommends a helper repair"

# A retired --fix fails, writes nothing, and is never mistaken for a target directory.
bash "$C/gitignore-drift.sh" --fix "$r" >/dev/null 2>&1
assert_exit 2 "$?" "retired --fix fails"
assert_eq "$(wc -c <"$r/.woostack/.gitignore" | tr -d ' ')" "0" "retired --fix writes nothing"
assert_eq "$(bash "$C/gitignore-drift.sh" "$r")" "$out" "retired --fix leaves the finding unchanged"
assert_eq "$(bash "$C/gitignore-drift.sh" --fix 2>/dev/null)" "" "retired --fix reads no target directory"

# A .gitignore without a final newline keeps every byte through diagnosis and a
# retired repair attempt.
rnl="$(mktemp -d)"
mkdir -p "$rnl/.woostack"
printf 'tmp/' >"$rnl/.woostack/.gitignore"
before_nl="$(cat "$rnl/.woostack/.gitignore")"
bash "$C/gitignore-drift.sh" "$rnl" >/dev/null
bash "$C/gitignore-drift.sh" --fix "$rnl" >/dev/null 2>&1
assert_eq "$(cat "$rnl/.woostack/.gitignore")" "$before_nl" "no-newline ignore bytes are preserved"
assert_eq "$(wc -c <"$rnl/.woostack/.gitignore" | tr -d ' ')" "4" "no final newline is appended"

# A symlinked ignore file is reported, not followed: the external sentinel and the
# link itself are untouched.
rl="$(mktemp -d)"
mkdir -p "$rl/.woostack" "$rl/external"
printf 'sentinel-bytes' >"$rl/external/target"
ln -s "$rl/external/target" "$rl/.woostack/.gitignore"
outl="$(bash "$C/gitignore-drift.sh" "$rl")"
assert_contains "$outl" "symlink" "symlinked ignore file reports an inspection limitation"
assert_not_contains "$outl" "missing managed line" "symlinked ignore file is not read through"
bash "$C/gitignore-drift.sh" --fix "$rl" >/dev/null 2>&1
assert_eq "$(cat "$rl/external/target")" "sentinel-bytes" "external sentinel bytes are preserved"
assert_eq "$(readlink "$rl/.woostack/.gitignore")" "$rl/external/target" "symlink is preserved"

# The containing support directory must not be followed by either direct check
# or the aggregate runner, including when its target is missing.
for kind in populated dangling; do
  boundary="$(mktemp -d)"
  if [ "$kind" = populated ]; then
    outside="$(mktemp -d)"
    printf '{"commit":{"command":"sentinel-not-executed"}}\n' >"$outside/config.json"
    printf 'external-ignore-sentinel\n' >"$outside/.gitignore"
    ln -s "$outside" "$boundary/.woostack"
  else
    ln -s "$boundary/missing" "$boundary/.woostack"
  fi
  for check in config-keys gitignore-drift; do
    finding="$(bash "$C/$check.sh" "$boundary")"
    assert_contains "$finding" $'error\t' "$kind support link is an error in direct $check"
    assert_contains "$finding" "directory must not be a symlink" "$kind direct $check reports the boundary"
    assert_not_contains "$finding" "missing managed line" "$kind direct $check does not follow the target"
  done
  report="$(bash "$HERE/../doctor.sh" "$boundary" 2>&1)"; status=$?
  assert_exit 2 "$status" "$kind support link fails aggregate Doctor"
  assert_contains "$report" "directory must not be a symlink" "$kind aggregate diagnosis reports the boundary"
  assert_not_contains "$report" "0 error(s)" "$kind aggregate diagnosis is not healthy"
  assert_eq "$(readlink "$boundary/.woostack")" "$([ "$kind" = populated ] && printf '%s' "$outside" || printf '%s' "$boundary/missing")" "$kind support link is preserved"
  if [ "$kind" = populated ]; then
    assert_eq "$(cat "$outside/config.json")" '{"commit":{"command":"sentinel-not-executed"}}' "external config remains unchanged"
    assert_eq "$(cat "$outside/.gitignore")" "external-ignore-sentinel" "external diagnostic remains unchanged"
  fi
done

# An unreadable template is an inspection failure, never a clean result.
tpl="$(mktemp -d)"
mkdir -p "$tpl/woostack-doctor/scripts/checks" "$tpl/woostack-init/templates"
cp "$C/gitignore-drift.sh" "$tpl/woostack-doctor/scripts/checks/"
assert_contains "$(bash "$tpl/woostack-doctor/scripts/checks/gitignore-drift.sh" "$r")" $'error\tgitignore-drift\treport\t' "missing template is not healthy evidence"

# A failed target read is an inspection error, not a missing managed line.
read_failure="$(mktemp -d)"
printf '#!/bin/sh\nexit 2\n' >"$read_failure/grep"
chmod +x "$read_failure/grep"
out="$(PATH="$read_failure:$PATH" bash "$C/gitignore-drift.sh" "$r")"
assert_contains "$out" $'error\tgitignore-drift\treport\t' "failed target read reports an error"
assert_not_contains "$out" "missing managed line" "failed target read does not report drift"

# config-keys delegates canonical GitHub validation to Init's resolver.
r2="$(mktemp -d)"
mkdir -p "$r2/.woostack"
printf '%s\n' '{}' >"$r2/.woostack/config.json"
assert_eq "$(bash "$C/config-keys.sh" "$r2")" "" "config without models is clean"
printf '%s\n' '{"github":{"visibility":"private"}}' >"$r2/.woostack/config.json"
assert_contains "$(bash "$C/config-keys.sh" "$r2")" "github policy permits only" "unknown canonical key is rejected by resolver"
printf '%s\n' '{"artifacts":{"provider":"plane","plane":{"workspace":"legacy"}},"models":{}}' >"$r2/.woostack/config.json"
out="$(bash "$C/config-keys.sh" "$r2")"
assert_contains "$out" "retired-provider" "legacy provider settings are report-only"
assert_not_contains "$out" $'error\t' "legacy provider settings do not block local config"

# Helper fixtures keep every exact finding contract satisfiable.
fixture_root="$(mktemp -d)"
for fixture in local-project incomplete-project legacy-project ci-project; do
  cp -R "$HERE/fixtures/$fixture" "$fixture_root/$fixture"
done
finding_codes() {
  bash "$C/config-keys.sh" "$1" | cut -f2 | paste -sd, -
}
assert_eq "$(finding_codes "$fixture_root/local-project")" "retired-status-config" "local-policy fixture emits retirement guidance"
assert_eq "$(finding_codes "$fixture_root/incomplete-project")" "" "missing historical models is not a config finding"
assert_eq "$(finding_codes "$fixture_root/legacy-project")" $'retired-provider,retained-data' "legacy fixture emits only its exact findings"
assert_eq "$(finding_codes "$fixture_root/ci-project")" "" "complete canonical policy stays free of unrelated findings"


# Retained records are report-only and byte-preserved.
r3="$(mktemp -d)"
mkdir -p "$r3/.woostack/tmp/runs/legacy" "$r3/.woostack/plans"
printf '%s\n' '{"mirror":{"provider":"linear"},"sentinel":"retain"}' >"$r3/.woostack/tmp/runs/legacy/manifest.json"
printf '%s\n' 'historical' >"$r3/.woostack/plans/old.md"
manifest_before="$(cat "$r3/.woostack/tmp/runs/legacy/manifest.json")"
out="$(bash "$C/config-keys.sh" "$r3")"
assert_contains "$out" "retained-data" "retained manifest is reported"
assert_not_contains "$out" $'error\t' "retained manifest does not block local diagnosis"
assert_eq "$(cat "$r3/.woostack/tmp/runs/legacy/manifest.json")" "$manifest_before" "retained manifest is unchanged"

# Missing config is valid local configuration; no config-policy error is emitted.
r2c="$(mktemp -d)"
mkdir -p "$r2c/.woostack"
out="$(bash "$C/config-keys.sh" "$r2c")"
assert_not_contains "$out" $'error\tconfig-policy' "missing config is not a policy error"

# Worktree cleanup is retired: a real registered worktree whose path contains spaces
# survives diagnosis unchanged, with no orphan finding or repair recommendation.
r4="$(mktemp -d)"
wt="$r4/task worktree one"
mkdir -p "$r4/repo/.woostack"
printf '%s\n' '{"models":{}}' >"$r4/repo/.woostack/config.json"
cp "$HERE/../../../woostack-init/templates/gitignore" "$r4/repo/.woostack/.gitignore"
( cd "$r4/repo" && git -c user.email=t@t -c user.name=t init -q && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init )
git -C "$r4/repo" worktree add -q "$wt" -b wt-spaced
reg_before="$(git -C "$r4/repo" worktree list --porcelain)"
out="$(bash "$HERE/../doctor.sh" "$r4/repo" 2>&1)"
assert_not_contains "$out" "worktree" "no worktree cleanup finding remains"
assert_not_contains "$out" "prune" "no worktree repair recommendation remains"
assert_eq "$(git -C "$r4/repo" worktree list --porcelain)" "$reg_before" "git registrations are preserved"
assert_eq "$([ -d "$wt" ] && echo present)" "present" "spaced worktree directory is preserved"
assert_eq "$(git -C "$wt" rev-parse --abbrev-ref HEAD)" "wt-spaced" "spaced worktree branch is preserved"

finish
