#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd)
PREFETCH="$SCRIPT_DIR/prefetch.sh"
ANCHOR_RESOLVER="$SCRIPT_DIR/resolve-diff-line.sh"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/woostack-review-skill-package-ci.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM
REPO="$TMP_ROOT/repo"
BIN="$TMP_ROOT/bin"
mkdir -p "$REPO/skills/ci-skill/references" "$REPO/skills/ci-skill/scripts" \
  "$REPO/skills/ci-skill/assets" "$REPO/skills/ci-skill/evals" "$BIN"

git -C "$REPO" init -q
git -C "$REPO" config user.email test@example.com
git -C "$REPO" config user.name "Test User"
cat >"$REPO/skills/ci-skill/SKILL.md" <<'EOF'
---
name: ci-skill
description: Review CI package artifacts safely.
---
# ci-skill

[Guide](references/guide.md)

Stable body one.
Stable body two.
EOF
printf '# Guide\n' >"$REPO/skills/ci-skill/references/guide.md"
printf '#!/usr/bin/env bash\nprintf "checked\\n"\n' >"$REPO/skills/ci-skill/scripts/check.sh"
chmod +x "$REPO/skills/ci-skill/scripts/check.sh"
printf 'CI asset\n' >"$REPO/skills/ci-skill/assets/logo.txt"
printf '# Evaluation notes\n' >"$REPO/skills/ci-skill/evals/notes.md"
printf 'tracked hidden context\n' >"$REPO/skills/ci-skill/references/.review-context"
git -C "$REPO" add .
git -C "$REPO" commit -q -m base
i=1
while [ "$i" -le 12 ]; do
  printf 'Changed CI package contract line %02d.\n' "$i" >>"$REPO/skills/ci-skill/SKILL.md"
  i=$((i + 1))
done

DIFF_FIXTURE="$TMP_ROOT/authoritative.diff"
META_FIXTURE="$TMP_ROOT/meta.json"
git -C "$REPO" diff --no-ext-diff --binary -- skills/ci-skill/SKILL.md >"$DIFF_FIXTURE"
jq -cn --arg head "$(git -C "$REPO" rev-parse HEAD)" \
  '{headRefOid:$head,headRefName:"feature/package-context",baseRefName:"main",title:"skill package",body:"",author:{login:"human"},files:[{path:"skills/ci-skill/SKILL.md",additions:12,deletions:0}]}' \
  >"$META_FIXTURE"

# CI uses the production gh branch, not WOO_REVIEW_TEST_MODE. This stub exposes
# only the deterministic GitHub responses prefetch needs and records every call;
# no provider, network, or model boundary is reachable.
cat >"$BIN/gh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$GH_CALL_LOG"
if [ "${1:-}" = pr ] && [ "${2:-}" = view ]; then
  case " $* " in
    *" --json reviews "*) printf '%s\n' '{"reviews":[]}' ;;
    *" --json comments "*) printf '%s\n' 0 ;;
    *" --json headRefOid,headRefName,baseRefName,title,body,files,author "*) cat "$FAKE_META_FILE" ;;
    *) printf 'unsupported gh pr view: %s\n' "$*" >&2; exit 97 ;;
  esac
elif [ "${1:-}" = pr ] && [ "${2:-}" = diff ]; then
  cat "$FAKE_DIFF_FILE"
elif [ "${1:-}" = api ] && [ "${2:-}" = graphql ]; then
  printf '%s\n' '{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[]}}}}}'
elif [ "${1:-}" = api ]; then
  printf '%s\n' 0
else
  printf 'unsupported gh invocation: %s\n' "$*" >&2
  exit 97
fi
SH
chmod +x "$BIN/gh"
GH_CALL_LOG="$TMP_ROOT/gh-calls.log"
: >"$GH_CALL_LOG"

run_ci_prefetch() {
  out=$1
  mode=$2
  stdout_file="$TMP_ROOT/ci.$mode.$$.out"
  stderr_file="$TMP_ROOT/ci.$mode.$$.err"
  set +e
  (
    cd "$REPO"
    PATH="$BIN:$PATH" \
    GH_CALL_LOG="$GH_CALL_LOG" \
    FAKE_META_FILE="$META_FIXTURE" \
    FAKE_DIFF_FILE="$DIFF_FIXTURE" \
    OUTDIR="$out" \
    PR_NUMBER=1 \
    GITHUB_ACTIONS=true \
    GITHUB_REPOSITORY=owner/repo \
    GITHUB_WORKSPACE="$REPO" \
    EVENT_NAME=pull_request \
    EVENT_ACTION=opened \
    WOO_REVIEW_MODE="$mode" \
    INPUT_INCREMENTAL=off \
      bash "$PREFETCH"
  ) >"$stdout_file" 2>"$stderr_file"
  RUN_RC=$?
  set -e
  RUN_STDOUT=$(cat "$stdout_file")
  RUN_STDERR=$(cat "$stderr_file")
  rm -f "$stdout_file" "$stderr_file"
}

check_ci_manifest() {
  out=$1
  source_repo=$2
  node - "$out" "$source_repo" <<'NODE'
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const [out, repo] = process.argv.slice(2);
const manifest = JSON.parse(fs.readFileSync(path.join(out, 'skill-packages.json'), 'utf8'));
const fail = (message) => { throw new Error(message); };
const digest = (bytes) => `sha256:${crypto.createHash('sha256').update(bytes).digest('hex')}`;
if (manifest.schemaVersion !== 1 || !Array.isArray(manifest.packages) || manifest.packages.length !== 1) {
  fail('expected one schemaVersion 1 package');
}
const entry = manifest.packages[0];
if (entry.skillPath !== 'skills/ci-skill/SKILL.md' || entry.packagePath !== 'skills/ci-skill') {
  fail('manifest does not identify the owning package');
}
if (entry.snapshotPath !== 'skill-packages/skills%2Fci-skill') {
  fail('nested package path must encode `/` as `%2F`: skills/ci-skill -> skill-packages/skills%2Fci-skill');
}
const expected = [
  ['SKILL.md', 'skill'],
  ['assets/logo.txt', 'asset'],
  ['evals/notes.md', 'eval'],
  ['references/.review-context', 'reference'],
  ['references/guide.md', 'reference'],
  ['scripts/check.sh', 'script'],
];
const inventory = entry.files.map((file) => [file.path, file.type]);
if (JSON.stringify(inventory) !== JSON.stringify(expected)) {
  fail('manifest file order/classification is incomplete or non-deterministic');
}
const packageHash = digest(Buffer.from(
  entry.files.map((file) => `${file.path}\0${file.sha256}\n`).join(''),
  'utf8',
));
if (entry.packageHash !== packageHash) fail('packageHash does not match the ordered path/hash records');
const snapshotRoot = path.join(out, entry.snapshotPath);
const compareCodePoints = (a, b) => a < b ? -1 : a > b ? 1 : 0;
const seen = [];
const walk = (directory, prefix = '') => {
  for (const dirent of fs.readdirSync(directory, { withFileTypes: true })) {
    const rel = prefix ? `${prefix}/${dirent.name}` : dirent.name;
    const absolute = path.join(directory, dirent.name);
    if (dirent.isDirectory()) walk(absolute, rel);
    else if (dirent.isFile()) seen.push(rel);
    else fail(`unsafe snapshot entry: ${rel}`);
  }
};
walk(snapshotRoot);
seen.sort(compareCodePoints);
if (JSON.stringify(seen) !== JSON.stringify(expected.map(([rel]) => rel))) {
  fail(`snapshot file set differs: ${seen}`);
}
for (const [rel] of expected) {
  const file = entry.files.find((candidate) => candidate.path === rel);
  const source = fs.readFileSync(path.join(repo, entry.packagePath, rel));
  const copied = fs.readFileSync(path.join(snapshotRoot, rel));
  if (!source.equals(copied) || file.bytes !== source.length || file.sha256 !== digest(source)) {
    fail(`snapshot/hash mismatch for ${rel}`);
  }
}
NODE
}

assert_ci_manifest() {
  out=$1
  label=$2
  source_repo=$3
  error_file="$TMP_ROOT/ci-manifest.$$.err"
  if [ -f "$out/skill-packages.json" ] && check_ci_manifest "$out" "$source_repo" 2>"$error_file"; then
    pass
  else
    fail "package snapshot CI: $label"
  fi
  rm -f "$error_file"
}

# Detection is the artifact-producing CI entrypoint.
DETECT_OUT="$TMP_ROOT/detect-out"
run_ci_prefetch "$DETECT_OUT" detect
assert_exit 0 "$RUN_RC" "CI detect fixture reaches the production prefetch path"
if cmp -s "$DIFF_FIXTURE" "$DETECT_OUT/diff.txt"; then pass; else fail "package snapshot CI: detect must preserve authoritative diff bytes"; fi
assert_ci_manifest "$DETECT_OUT" "detect mode materializes the same classified, hashed package contract as local mode" "$REPO"
[ -f "$DETECT_OUT/skill-packages/skills%2Fci-skill/references/.review-context" ] &&
  pass || fail "CI detect snapshot includes tracked dotfiles"


ARTIFACT="$TMP_ROOT/uploaded-review-artifacts"
REVIEW_OUT="$TMP_ROOT/review-out"
mkdir -p "$ARTIFACT" "$REVIEW_OUT"
cp -R "$DETECT_OUT/." "$ARTIFACT/"
cp -R "$ARTIFACT/." "$REVIEW_OUT/"
cp "$ARTIFACT/skill-packages.json" "$TMP_ROOT/expected-manifest.json"
cp -R "$ARTIFACT/skill-packages" "$TMP_ROOT/expected-snapshots"

# Freeze the reviewed source independently, then remove the checked-out package.
# A review worker can now succeed only by reading the downloaded package artifact;
# regeneration from its workspace would fail or produce different bytes.
EXPECTED_REPO="$TMP_ROOT/immutable-expected-repository"
mkdir -p "$EXPECTED_REPO/skills"
cp -R "$REPO/skills/ci-skill" "$EXPECTED_REPO/skills/"
rm -rf "$REPO/skills/ci-skill"

run_ci_prefetch "$REVIEW_OUT" review
assert_exit 0 "$RUN_RC" "CI review fixture reads the preserved prefetch artifact tree"
if cmp -s "$TMP_ROOT/expected-manifest.json" "$REVIEW_OUT/skill-packages.json" && \
  diff -qr "$TMP_ROOT/expected-snapshots" "$REVIEW_OUT/skill-packages" >/dev/null; then
  pass
else
  fail "package snapshot CI: review mode must preserve the detection manifest and snapshots byte-for-byte"
fi
assert_ci_manifest "$REVIEW_OUT" "downloaded review artifact remains readable after the workspace package disappears" "$EXPECTED_REPO"
[ -f "$REVIEW_OUT/skill-packages/skills%2Fci-skill/references/.review-context" ] &&
  pass || fail "CI artifact handoff preserves tracked dotfiles"
if cmp -s "$DIFF_FIXTURE" "$REVIEW_OUT/diff.txt"; then pass; else fail "package snapshot CI: review handoff must leave diff.txt authoritative"; fi
assert_eq "$(OUTDIR="$REVIEW_OUT" bash "$ANCHOR_RESOLVER" --file skills/ci-skill/SKILL.md --line 11 --no-cache)" 11 \
  "CI package context keeps changed right-side finding anchors"
assert_eq "$(OUTDIR="$REVIEW_OUT" bash "$ANCHOR_RESOLVER" --file skills/ci-skill/SKILL.md --line 1 --no-cache)" null \
  "CI package context cannot manufacture a finding anchor"

# Validate jobs download the same detection tree plus their in-flight findings.
# Both validator modes must preserve package artifacts rather than regenerate
# them from a checkout that may no longer contain the reviewed package.
for validate_mode in validate validate-prosecutor; do
  validate_out="$TMP_ROOT/$validate_mode-out"
  mkdir -p "$validate_out"
  cp -R "$ARTIFACT/." "$validate_out/"
  printf '[]\n' >"$validate_out/findings.bugs.json"
  run_ci_prefetch "$validate_out" "$validate_mode"
  assert_exit 0 "$RUN_RC" "CI $validate_mode fixture reads preserved package artifacts"
  if cmp -s "$TMP_ROOT/expected-manifest.json" "$validate_out/skill-packages.json" &&
    diff -qr "$TMP_ROOT/expected-snapshots" "$validate_out/skill-packages" >/dev/null; then
    pass
  else
    fail "package snapshot CI: $validate_mode must preserve manifest and snapshots byte-for-byte"
  fi
  assert_ci_manifest "$validate_out" "$validate_mode artifact remains readable without workspace package" "$EXPECTED_REPO"
  if cmp -s "$DIFF_FIXTURE" "$validate_out/diff.txt"; then
    pass
  else
    fail "package snapshot CI: $validate_mode must leave diff.txt authoritative"
  fi
done
if [ "$(grep -c '^pr diff ' "$GH_CALL_LOG")" -eq 4 ]; then
  pass
else
  fail "package snapshot CI: fixture must execute exactly four actual prefetch diff fetches"
fi

finish
