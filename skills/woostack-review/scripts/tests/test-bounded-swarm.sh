#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/run-bounded-swarm.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/out"
printf '%s\n' bugs security types architecture docs > "$work/out/angles.txt"

cat > "$work/worker.sh" <<'WORKER'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$OUTDIR/state"
active_file="$OUTDIR/state/active"
max_file="$OUTDIR/state/max"
printf '%s\n' "${FORCE_TIER:-}" > "$OUTDIR/state/tier.$WOO_REVIEW_ANGLE"
lock_dir="$OUTDIR/state/lock"
while ! mkdir "$lock_dir" 2>/dev/null; do
  sleep 0.01
done
{
  active=0
  if [ -s "$active_file" ]; then
    active="$(cat "$active_file")"
  fi
  active=$((active + 1))
  printf '%s\n' "$active" > "$active_file"
  max=0
  if [ -s "$max_file" ]; then
    max="$(cat "$max_file")"
  fi
  if [ "$active" -gt "$max" ]; then
    printf '%s\n' "$active" > "$max_file"
  fi
  rmdir "$lock_dir"
}

sleep 0.15

case "$WOO_REVIEW_ANGLE" in
  types)
    count_file="$OUTDIR/state/types-count"
    count=0
    if [ -s "$count_file" ]; then
      count="$(cat "$count_file")"
    fi
    count=$((count + 1))
    printf '%s\n' "$count" > "$count_file"
    if [ "$count" -eq 1 ]; then
      rm -f "$OUTDIR/findings.types.json"
    else
      printf '[]\n' > "$OUTDIR/findings.types.json"
    fi
    ;;
  docs)
    printf '{"not":"array"}\n' > "$OUTDIR/findings.docs.json"
    ;;
  *)
    printf '[]\n' > "$OUTDIR/findings.%s.json" "$WOO_REVIEW_ANGLE"
    ;;
esac
printf '{"angle":"%s","chunk":null,"runner":"test","model":"test-model","tier":"%s","ts":"t"}\n' \
  "$WOO_REVIEW_ANGLE" "${FORCE_TIER:-standard}" > "$OUTDIR/receipt.$WOO_REVIEW_ANGLE.json"

while ! mkdir "$lock_dir" 2>/dev/null; do
  sleep 0.01
done
{
  active="$(cat "$active_file")"
  active=$((active - 1))
  printf '%s\n' "$active" > "$active_file"
  rmdir "$lock_dir"
}
WORKER
chmod +x "$work/worker.sh"

OUTDIR="$work/out" FORCE_TIER=deep \
  bash "$SCRIPT" --max-concurrency 2 -- "$work/worker.sh"

assert_eq "$(cat "$work/out/state/max")" "2" "max concurrency respected"
assert_eq "$(cat "$work/out/state/types-count")" "2" "missing artifact retried once after drain"
assert_eq "$(jq -r '.mode' "$work/out/swarm-metrics.json")" "bounded" "metrics mode is bounded"
assert_eq "$(jq -r '.max_concurrency' "$work/out/swarm-metrics.json")" "2" "metrics record concurrency"
assert_eq "$(jq -r '.angles_total' "$work/out/swarm-metrics.json")" "5" "metrics record angle count"
assert_eq "$(jq -r '.retry_angles | index("types") != null' "$work/out/swarm-metrics.json")" "true" "metrics record retried missing angle"
assert_eq "$(jq -r '.retry_angles | index("docs") != null' "$work/out/swarm-metrics.json")" "true" "metrics record retried non-array angle"
assert_eq "$(jq -r '.still_invalid | index("docs") != null' "$work/out/swarm-metrics.json")" "true" "metrics record still-invalid angle"
assert_eq "$(jq -r '.degraded' "$work/out/swarm-metrics.json")" "true" "metrics record degradation"
assert_eq "$(jq -r 'type' "$work/out/findings.docs.json")" "array" "still-invalid artifact reset to array"

for angle in bugs security types architecture docs; do
  assert_eq "$(cat "$work/out/state/tier.$angle")" "deep" "FORCE_TIER propagated to $angle"
done

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
OUTDIR="$work2/out" WOO_REVIEW_MAX_CONCURRENCY=1 bash "$SCRIPT" -- "$work2/worker.sh"
assert_eq "$(jq -r '.max_concurrency' "$work2/out/swarm-metrics.json")" "1" "env concurrency override used"
rm -rf "$work2"

work3="$(mktemp -d)"
mkdir -p "$work3/out"
printf '%s\n' bugs security > "$work3/out/angles.txt"
printf '%s\n' chunk-0 chunk-1 > "$work3/out/chunks.txt"
cat > "$work3/worker.sh" <<'WORKER'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$WOO_REVIEW_CHUNK" >> "$OUTDIR/chunks-seen.txt"
printf '[]\n' > "$OUTDIR/findings.$WOO_REVIEW_ANGLE.$WOO_REVIEW_CHUNK.json"
printf '{"angle":"%s","chunk":"%s","runner":"test","model":"test-model","tier":"standard","ts":"t"}\n' "$WOO_REVIEW_ANGLE" "$WOO_REVIEW_CHUNK" > "$OUTDIR/receipt.$WOO_REVIEW_ANGLE.$WOO_REVIEW_CHUNK.json"
WORKER
chmod +x "$work3/worker.sh"
OUTDIR="$work3/out" bash "$SCRIPT" --max-concurrency 3 -- "$work3/worker.sh"
assert_eq "$(jq -r '.angles_total' "$work3/out/swarm-metrics.json")" "2" "chunked metrics record angle count"
assert_eq "$(jq -r '.chunks_total' "$work3/out/swarm-metrics.json")" "2" "chunked metrics record chunk count"
assert_eq "$(jq -r '.work_items_total' "$work3/out/swarm-metrics.json")" "4" "chunked metrics record work item count"
assert_eq "$(test -f "$work3/out/findings.bugs.chunk-0.json" && echo yes || echo no)" "yes" "chunked bugs chunk-0 artifact written"
assert_eq "$(test -f "$work3/out/findings.bugs.chunk-1.json" && echo yes || echo no)" "yes" "chunked bugs chunk-1 artifact written"
assert_eq "$(test -f "$work3/out/findings.security.chunk-0.json" && echo yes || echo no)" "yes" "chunked security chunk-0 artifact written"
assert_eq "$(test -f "$work3/out/findings.security.chunk-1.json" && echo yes || echo no)" "yes" "chunked security chunk-1 artifact written"
assert_eq "$(sort -u "$work3/out/chunks-seen.txt" | paste -sd ',' -)" "chunk-0,chunk-1" "WOO_REVIEW_CHUNK propagated"
rm -rf "$work3"

finish
