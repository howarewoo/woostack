#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../woostack-init/scripts/tests/assert.sh"
set +e
C="$HERE/../checks"

# gitignore-drift
r="$(mktemp -d)"
mkdir -p "$r/.woostack"
: >"$r/.woostack/.gitignore"
assert_contains "$(bash "$C/gitignore-drift.sh" "$r")" "gitignore-drift" "empty .gitignore drifts"
bash "$C/gitignore-drift.sh" --fix "$r"
assert_eq "$(bash "$C/gitignore-drift.sh" "$r")" "" "after fix there is no gitignore drift"
before="$(wc -l <"$r/.woostack/.gitignore")"
bash "$C/gitignore-drift.sh" --fix "$r"
assert_eq "$(wc -l <"$r/.woostack/.gitignore")" "$before" "gitignore repair is idempotent"

# config-keys delegates canonical GitHub validation to Init's resolver.
r2="$(mktemp -d)"
mkdir -p "$r2/.woostack"
printf '%s\n' '{"models":{}}' >"$r2/.woostack/config.json"
assert_eq "$(bash "$C/config-keys.sh" "$r2")" "" "minimal config is clean"
printf '%s\n' '{"github":{"visibility":"private"}}' >"$r2/.woostack/config.json"
assert_contains "$(bash "$C/config-keys.sh" "$r2")" "github policy permits only" "unknown canonical key is rejected by resolver"
printf '%s\n' '{"artifacts":{"provider":"plane","plane":{"workspace":"legacy"}},"models":{}}' >"$r2/.woostack/config.json"
out="$(bash "$C/config-keys.sh" "$r2")"
assert_contains "$out" "retired-provider" "legacy provider settings are report-only"
assert_not_contains "$out" $'error\t' "legacy provider settings do not block local config"

# Eval fixtures keep every exact finding contract satisfiable.
eval_root="$(mktemp -d)"
for fixture in local-project incomplete-project legacy-project ci-project; do
  cp -R "$HERE/../../evals/fixtures/$fixture" "$eval_root/$fixture"
done
finding_codes() {
  bash "$C/config-keys.sh" "$1" | cut -f2 | paste -sd, -
}
assert_eq "$(finding_codes "$eval_root/local-project")" "retired-status-config" "local-policy fixture emits retirement guidance"
assert_eq "$(finding_codes "$eval_root/incomplete-project")" "config-key" "incomplete fixture emits its required config finding"
assert_eq "$(finding_codes "$eval_root/legacy-project")" $'retired-provider,retained-data' "legacy fixture emits only its exact findings"
assert_eq "$(finding_codes "$eval_root/ci-project")" "" "receipt fixture stays free of unrelated findings"
git -C "$eval_root/ci-project" init -q
git -C "$eval_root/ci-project" remote add origin https://github.com/acme/widgets.git
assert_eq "$(WOOSTACK_DOCTOR_LIVE=1 WOOSTACK_DOCTOR_LIVE_CONTEXT="$HERE/../../evals/fixtures/receipts/github-success.json" finding_codes "$eval_root/ci-project")" "" "successful receipt fixture remains clean"
assert_eq "$(WOOSTACK_DOCTOR_LIVE=1 WOOSTACK_DOCTOR_LIVE_CONTEXT="$HERE/../../evals/fixtures/receipts/github-missing-read.json" finding_codes "$eval_root/ci-project")" "github-live" "rejected receipt emits only the live finding"

# --fix only adds a template key and is idempotent.
r2b="$(mktemp -d)"
mkdir -p "$r2b/.woostack"
printf '%s\n' '{}' >"$r2b/.woostack/config.json"
assert_contains "$(bash "$C/config-keys.sh" "$r2b")" "missing required config key" "missing template key is reported"
bash "$C/config-keys.sh" --fix "$r2b" models
assert_eq "$(jq -c '.models' "$r2b/.woostack/config.json")" '{}' "config repair adds template value"
assert_eq "$(bash "$C/config-keys.sh" "$r2b" | grep -c 'missing required config key: models')" "0" "config repair removes the selected finding"

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
# Repairs reject arbitrary keys and never create a symlink target.
set +e
bash "$C/config-keys.sh" --fix "$r2c" provider >/dev/null 2>&1
fix_rc=$?
set -e
assert_eq "$fix_rc" "2" "repair rejects unsupported config keys"
if [ -e "$r2c/.woostack/config.json" ]; then
  fix_created=yes
else
  fix_created=no
fi
assert_eq "$fix_created" "no" "rejected repair creates no config"

# A registered-prefix collision must not hide an unregistered directory.
r4prefix="$(cd "$(mktemp -d)" && pwd -P)"
( cd "$r4prefix" && git -c user.email=t@t -c user.name=t init -q && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init )
mkdir -p "$r4prefix/.woostack/worktrees/app"
( cd "$r4prefix" && git worktree add -q "$r4prefix/.woostack/worktrees/app2" -b wt-app2 )
assert_contains "$(bash "$C/orphan-worktree.sh" "$r4prefix")" $'worktrees/app\t' "prefix collision is reported"
git -C "$r4prefix" worktree add -q "$r4prefix/.woostack/worktrees/stale" -b wt-stale
rm -rf "$r4prefix/.woostack/worktrees/stale"
assert_contains "$(cd "$r4prefix" && bash "$C/orphan-worktree.sh" .)" "stale worktree registration" "stale registration is reported"
# orphan-worktree
r4="$(cd "$(mktemp -d)" && pwd -P)"
( cd "$r4" && git -c user.email=t@t -c user.name=t init -q && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init )
mkdir -p "$r4/.woostack/worktrees/ghost"
assert_contains "$(bash "$C/orphan-worktree.sh" "$r4")" "orphan-worktree" "unregistered worktree is reported"
assert_contains "$(bash "$C/orphan-worktree.sh" "$r4")" "report" "present unregistered worktree is never auto-pruned"

finish
