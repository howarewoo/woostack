#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../woostack-init/scripts/tests/assert.sh"
CHK="$HERE/../checks/omp-agents.sh"
GEN="$HERE/../../../woostack-init/scripts/gen-omp-agents.sh"
set +e                                    # assert.sh enables errexit; keep the suite running to the finish tally
tmpdirs=(); trap 'rm -rf "${tmpdirs[@]}"' EXIT   # track + clean every sandbox on exit (incl. early abort)

# no .omp/ -> silent, exit 0 (not an omp workspace)
r="$(mktemp -d)"; tmpdirs+=("$r"); mkdir -p "$r/.woostack"; printf '{}' > "$r/.woostack/config.json"
out="$(bash "$CHK" "$r")"; rc=$?
assert_exit 0 "$rc" "no .omp: exit 0"
assert_eq "$out" "" "no .omp: silent"

# .omp/ present, defs missing -> warn
r="$(mktemp -d)"; tmpdirs+=("$r"); mkdir -p "$r/.woostack" "$r/.omp/agents"
printf '{ "models": { "fast": "p/q" } }' > "$r/.woostack/config.json"
out="$(bash "$CHK" "$r")"
assert_contains "$out" "omp-agents-missing" "missing def -> warn"

# --fix -> regenerates, then diagnose is silent
bash "$CHK" --fix "$r" >/dev/null 2>&1
out="$(bash "$CHK" "$r")"
assert_eq "$out" "" "after --fix: no drift"

# drift (hand-edit a def) -> warn
echo "tampered" >> "$r/.omp/agents/woostack-fast.md"
out="$(bash "$CHK" "$r")"
assert_contains "$out" "omp-agents-drift" "tampered def -> drift warn"

finish
