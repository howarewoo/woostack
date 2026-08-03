#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/run-bounded-swarm.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/out"
printf '%s\n' bugs security types architecture docs skills > "$work/out/angles.txt"

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
  skills)
    printf '{"angle":"skills","file":"skills/example/SKILL.md","line":1,"title":"Split large skill","description":"d","fix":"f","severity":"MEDIUM","blocking":false,"fix_type":"prose","suggestion":null}\n' > "$OUTDIR/findings.skills.json"
    ;;
  *)
    printf '[]\n' > "$OUTDIR/findings.%s.json" "$WOO_REVIEW_ANGLE"
    ;;
esac
printf '{"angle":"%s","chunk":null,"runner":"test","model":"test-model","tier":"%s","ts":"t","authority":"advisory-only"}\n' \
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
assert_eq "$(jq -r '.angles_total' "$work/out/swarm-metrics.json")" "6" "metrics record angle count"
assert_eq "$(jq -r '.retry_angles | index("types") != null' "$work/out/swarm-metrics.json")" "true" "metrics record retried missing angle"
assert_eq "$(jq -r '.retry_angles | index("docs") != null' "$work/out/swarm-metrics.json")" "true" "metrics record retried non-array angle"
assert_eq "$(jq -r '.retry_angles | index("skills") == null' "$work/out/swarm-metrics.json")" "true" "single finding object normalized without retry"
assert_eq "$(jq -r '.still_invalid | index("docs") != null' "$work/out/swarm-metrics.json")" "true" "metrics record still-invalid angle"
assert_eq "$(jq -r '.degraded' "$work/out/swarm-metrics.json")" "true" "metrics record degradation"
assert_eq "$(jq -r 'type' "$work/out/findings.docs.json")" "array" "still-invalid artifact reset to array"
assert_eq "$(jq -r 'type' "$work/out/findings.skills.json")" "array" "single finding object converted to array"
assert_eq "$(jq -r 'length' "$work/out/findings.skills.json")" "1" "single finding object preserved"

for angle in bugs security types architecture docs skills; do
  assert_eq "$(cat "$work/out/state/tier.$angle")" "deep" "FORCE_TIER propagated to $angle"
done

work2="$(mktemp -d)"
mkdir -p "$work2/out"
printf '%s\n' bugs security > "$work2/out/angles.txt"
cat > "$work2/worker.sh" <<'WORKER'
#!/usr/bin/env bash
set -euo pipefail
printf '[]\n' > "$OUTDIR/findings.$WOO_REVIEW_ANGLE.json"
printf '{"angle":"%s","chunk":null,"runner":"test","model":"test-model","tier":"standard","ts":"t","authority":"advisory-only"}\n' "$WOO_REVIEW_ANGLE" > "$OUTDIR/receipt.$WOO_REVIEW_ANGLE.json"
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
printf '{"angle":"%s","chunk":"%s","runner":"test","model":"test-model","tier":"standard","ts":"t","authority":"advisory-only"}\n' "$WOO_REVIEW_ANGLE" "$WOO_REVIEW_CHUNK" > "$OUTDIR/receipt.$WOO_REVIEW_ANGLE.$WOO_REVIEW_CHUNK.json"
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

work4="$(mktemp -d)"
mkdir -p "$work4/out"
printf '%s\n' one two three four five six seven > "$work4/out/angles.txt"
cat > "$work4/worker.sh" <<'WORKER'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$OUTDIR/state"
active_file="$OUTDIR/state/active"
max_file="$OUTDIR/state/max"
lock_dir="$OUTDIR/state/lock"
while ! mkdir "$lock_dir" 2>/dev/null; do
  sleep 0.01
done
active=0
if [ -f "$active_file" ]; then
  active="$(cat "$active_file")"
fi
active=$((active + 1))
printf '%s\n' "$active" > "$active_file"
max=0
if [ -f "$max_file" ]; then
  max="$(cat "$max_file")"
fi
if [ "$active" -gt "$max" ]; then
  printf '%s\n' "$active" > "$max_file"
fi
rmdir "$lock_dir"

sleep 0.15
printf '[]\n' > "$OUTDIR/findings.$WOO_REVIEW_ANGLE.json"
printf '{"angle":"%s","chunk":null,"runner":"test","model":"test-model","tier":"standard","ts":"t","authority":"advisory-only"}\n' \
  "$WOO_REVIEW_ANGLE" > "$OUTDIR/receipt.$WOO_REVIEW_ANGLE.json"

while ! mkdir "$lock_dir" 2>/dev/null; do
  sleep 0.01
done
active="$(cat "$active_file")"
active=$((active - 1))
printf '%s\n' "$active" > "$active_file"
rmdir "$lock_dir"
WORKER
chmod +x "$work4/worker.sh"
OUTDIR="$work4/out" "$SCRIPT" -- "$work4/worker.sh"
assert_eq "$(jq -r '.mode' "$work4/out/swarm-metrics.json")" "host-managed" "default metrics record host-managed mode"
assert_eq "$(jq -r '.max_concurrency == null' "$work4/out/swarm-metrics.json")" "true" "default metrics record no concurrency cap"
rm -rf "$work4"

engineer="$work/engineer"
repo="$engineer/repo"
out="$engineer/out"
mkdir -p "$repo" "$out" "$engineer/caller-home"
git -C "$repo" init -q
git -C "$repo" config user.email test@example.com
git -C "$repo" config user.name "Receipt Test"
git -C "$repo" config commit.gpgsign false
printf 'reviewed\n' > "$repo/tracked.txt"
git -C "$repo" add tracked.txt
git -C "$repo" commit -qm initial
printf '%s\n' bugs > "$out/angles.txt"
jq -n '{
  schemaVersion: 1,
  implementingCoder: {
    profile: "omp-engineer",
    sessionId: "omp-session",
    principalId: "linear-engineer",
    credentialContextId: "omp-credential"
  },
  decisionMaker: {
    profile: "hermes-engineer",
    sessionId: "hermes-session",
    principalId: "linear-decision-maker",
    credentialContextId: "hermes-credential"
  },
  reviewers: [{
    angle: "bugs",
    chunk: null,
    reviewerProfile: "reviewer-bugs",
    reviewerSessionId: "reviewer-session-bugs",
    reviewerPrincipalId: "reviewer-principal-bugs",
    reviewerCredentialContextId: "reviewer-credential-bugs"
  }]
}' > "$out/reviewer-identities.json"
cat > "$engineer/isolated-worker.sh" <<'WORKER'
#!/usr/bin/env bash
set -euo pipefail
[ "$PWD" = "$(cd "$OUTDIR" && pwd -P)" ]
[ -z "${GH_TOKEN:-}" ]
[ -z "${GITHUB_TOKEN:-}" ]
[ -z "${SSH_AUTH_SOCK:-}" ]
[ -z "${GIT_ASKPASS:-}" ]
[ -z "${HERMES_PROFILE:-}" ]
[ "${REVIEW_PROVIDER_TOKEN:-}" = "provider-token" ]
[ -r "$WOO_REVIEW_BINDING_PATH" ]
[ ! -e "$OUTDIR/reviewer-identities.json" ]
jq -e '.angle == "bugs" and .reviewerProfile == "reviewer-bugs"' \
  "$WOO_REVIEW_BINDING_PATH" >/dev/null
jq -n --arg pwd "$PWD" --arg home "$HOME" '[{pwd:$pwd,home:$home}]' \
  > "$OUTDIR/findings.$WOO_REVIEW_ANGLE.json"
printf '{"angle":"%s","chunk":null,"runner":"test","model":"test-model","tier":"standard","ts":"t","reviewerProfile":"reviewer-bugs","reviewerSessionId":"reviewer-session-bugs","reviewerPrincipalId":"reviewer-principal-bugs","reviewerCredentialContextId":"reviewer-credential-bugs","authority":"advisory-only"}\n' \
  "$WOO_REVIEW_ANGLE" > "$OUTDIR/receipt.$WOO_REVIEW_ANGLE.json"
WORKER
chmod +x "$engineer/isolated-worker.sh"
rc=0
(
  cd "$repo"
  OUTDIR="$out" \
    WOO_REVIEW_ENGINEER_UNIT=true \
    WOO_REVIEW_PROVIDER_ENV=REVIEW_PROVIDER_TOKEN \
    REVIEW_PROVIDER_TOKEN=provider-token \
    GH_TOKEN=github-secret \
    GITHUB_TOKEN=github-actions-secret \
    SSH_AUTH_SOCK=/tmp/ssh-agent.sock \
    GIT_ASKPASS=/tmp/git-askpass \
    HERMES_PROFILE=hermes-engineer \
    HOME="$engineer/caller-home" \
    bash "$SCRIPT" -- "$engineer/isolated-worker.sh"
) >/dev/null 2>&1 || rc=$?
assert_exit 0 "$rc" "engineer swarm runs in isolated reviewer environment"
assert_contains "$(jq -r '.[0].pwd' "$out/findings.bugs.json")" \
  "woostack-review-workers." "engineer worker cwd is a private output namespace"
assert_contains "$(jq -r '.[0].home' "$out/findings.bugs.json")" \
  "woostack-review-workers." "engineer worker receives fresh private HOME"

mkdir -p "$repo/.woostack"
default_engineer_out="$(
  cd "$repo"
  env -u OUTDIR WOO_REVIEW_ENGINEER_UNIT=true \
    bash -c '. "$1"; printf "%s" "$OUTDIR"' _ "$DIR/resolve-outdir.sh"
)"
assert_contains "$default_engineer_out" "/tmp/pr-review-" \
  "engineer-unit default OUTDIR stays outside repositories with .woostack"

inside_out="$repo/.woostack/tmp/review"
mkdir -p "$inside_out"
printf '%s\n' bugs > "$inside_out/angles.txt"
cp "$out/reviewer-identities.json" "$inside_out/reviewer-identities.json"
rc=0
err="$(
  cd "$repo"
  OUTDIR="$inside_out" WOO_REVIEW_ENGINEER_UNIT=true \
    bash "$SCRIPT" -- "$engineer/isolated-worker.sh" 2>&1
)" || rc=$?
assert_exit 2 "$rc" "engineer swarm rejects an in-repository OUTDIR before dispatch"
assert_contains "$err" "OUTDIR must be outside" "OUTDIR failure names the repository boundary"
assert_eq "$([ ! -e "$inside_out/findings.bugs.json" ] && echo yes)" "yes" \
  "in-repository OUTDIR rejection occurs before worker output"
rc=0
err="$(
  OUTDIR="$out" \
    WOO_REVIEW_ENGINEER_UNIT=true \
    WOO_REVIEW_PROVIDER_ENV=GH_TOKEN \
    GH_TOKEN=github-secret \
    bash "$SCRIPT" -- "$engineer/isolated-worker.sh" 2>&1
)" || rc=$?
assert_exit 2 "$rc" "engineer provider allowlist rejects GitHub credentials"
assert_contains "$err" "provider-only variables" "provider allowlist rejection names the isolation rule"

manifest_out="$engineer/manifest-mutation-out"
mkdir -p "$manifest_out"
printf '%s\n' bugs > "$manifest_out/angles.txt"
cp "$out/reviewer-identities.json" "$manifest_out/reviewer-identities.json"
manifest_hash_before="$(git hash-object --no-filters -- "$manifest_out/reviewer-identities.json")"
cat > "$engineer/manifest-mutating-worker.sh" <<'WORKER'
#!/usr/bin/env bash
set -euo pipefail
printf '{}\n' > "$OUTDIR/reviewer-identities.json"
printf '[]\n' > "$OUTDIR/findings.$WOO_REVIEW_ANGLE.json"
printf '{"angle":"%s","chunk":null,"runner":"test","model":"test-model","tier":"standard","ts":"t","reviewerProfile":"reviewer-bugs","reviewerSessionId":"reviewer-session-bugs","reviewerPrincipalId":"reviewer-principal-bugs","reviewerCredentialContextId":"reviewer-credential-bugs","authority":"advisory-only"}\n' \
  "$WOO_REVIEW_ANGLE" > "$OUTDIR/receipt.$WOO_REVIEW_ANGLE.json"
WORKER
chmod +x "$engineer/manifest-mutating-worker.sh"
rc=0
(
  cd "$repo"
  OUTDIR="$manifest_out" \
    WOO_REVIEW_ENGINEER_UNIT=true \
    bash "$SCRIPT" -- "$engineer/manifest-mutating-worker.sh"
) >/dev/null 2>&1 || rc=$?
manifest_hash_after="$(git hash-object --no-filters -- "$manifest_out/reviewer-identities.json")"
assert_exit 0 "$rc" "worker-local manifest writes cannot alter controller state"
assert_eq "$manifest_hash_after" "$manifest_hash_before" \
  "controller identity manifest is outside every worker namespace"

mutation_out="$engineer/mutation-out"
mkdir -p "$mutation_out"
printf '%s\n' bugs > "$mutation_out/angles.txt"
cp "$out/reviewer-identities.json" "$mutation_out/reviewer-identities.json"
printf '%s\n' "$repo" > "$mutation_out/repo-path"
cat > "$engineer/mutating-worker.sh" <<'WORKER'
#!/usr/bin/env bash
set -euo pipefail
repo="$(cat "$OUTDIR/repo-path")"
printf 'mutated\n' > "$repo/tracked.txt"
printf '[]\n' > "$OUTDIR/findings.$WOO_REVIEW_ANGLE.json"
printf '{"angle":"%s","chunk":null,"runner":"test","model":"test-model","tier":"standard","ts":"t","reviewerProfile":"reviewer-bugs","reviewerSessionId":"reviewer-session-bugs","reviewerPrincipalId":"reviewer-principal-bugs","reviewerCredentialContextId":"reviewer-credential-bugs","authority":"advisory-only"}\n' \
  "$WOO_REVIEW_ANGLE" > "$OUTDIR/receipt.$WOO_REVIEW_ANGLE.json"
WORKER
chmod +x "$engineer/mutating-worker.sh"
rc=0
err="$(
  (
    cd "$repo"
    OUTDIR="$mutation_out" \
      WOO_REVIEW_ENGINEER_UNIT=true \
      bash "$SCRIPT" -- "$engineer/mutating-worker.sh"
  ) 2>&1
)" || rc=$?
assert_exit 1 "$rc" "engineer worker repository mutation hard-fails"
assert_contains "$err" "changed repository/worktree state" "mutation failure names repository fingerprint gate"

finish
