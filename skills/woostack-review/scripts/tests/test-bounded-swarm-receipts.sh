#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/run-bounded-swarm.sh"

# Case A: worker writes findings but NEVER a receipt → swarm gate hard-fails.
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
mkdir -p "$work/out"
printf '%s\n' bugs security > "$work/out/angles.txt"
cat > "$work/worker.sh" <<'WORKER'
#!/usr/bin/env bash
set -euo pipefail
printf '[]\n' > "$OUTDIR/findings.$WOO_REVIEW_ANGLE.json"
# Intentionally writes NO receipt.
WORKER
chmod +x "$work/worker.sh"
rc=0
OUTDIR="$work/out" bash "$SCRIPT" --max-concurrency 2 -- "$work/worker.sh" >/dev/null 2>&1 || rc=$?
assert_exit 1 "$rc" "missing receipts → swarm exits non-zero"

# Case B: worker writes findings AND a valid receipt → swarm succeeds.
work2="$(mktemp -d)"
mkdir -p "$work2/out"
printf '%s\n' bugs security > "$work2/out/angles.txt"
cat > "$work2/worker.sh" <<'WORKER'
#!/usr/bin/env bash
set -euo pipefail
printf '[]\n' > "$OUTDIR/findings.$WOO_REVIEW_ANGLE.json"
printf '{"angle":"%s","chunk":null,"runner":"test","model":"test-model","tier":"standard","ts":"t"}\n' "$WOO_REVIEW_ANGLE" > "$OUTDIR/receipt.$WOO_REVIEW_ANGLE.json"
WORKER
chmod +x "$work2/worker.sh"
rc=0
OUTDIR="$work2/out" bash "$SCRIPT" --max-concurrency 2 -- "$work2/worker.sh" >/dev/null 2>&1 || rc=$?
assert_exit 0 "$rc" "findings + receipts → swarm exits 0"
assert_eq "$(jq -r '.executed_angles | length' "$work2/out/swarm-metrics.json")" "2" "metrics record executed angles"
rm -rf "$work2"
finish
