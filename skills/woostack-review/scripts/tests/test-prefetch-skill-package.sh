#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd)
PREFETCH="$SCRIPT_DIR/prefetch.sh"
ANCHOR_RESOLVER="$SCRIPT_DIR/resolve-diff-line.sh"
SKILLS_PROMPT="$ROOT/skills/woostack-review/prompts/angles/skills.md"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/woostack-review-skill-package.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM
mkdir -p "$TMP_ROOT/bin"
cat >"$TMP_ROOT/bin/gh" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = api ] && [ "${2:-}" = user ]; then
  printf '%s\n' tester
  exit 0
fi
printf 'unexpected gh invocation: %s\n' "$*" >&2
exit 97
SH
chmod +x "$TMP_ROOT/bin/gh"
TEST_PATH="$TMP_ROOT/bin:$PATH"

init_repo() {
  REPO="$TMP_ROOT/$1"
  mkdir -p "$REPO"
  git -C "$REPO" init -q
  git -C "$REPO" config user.email test@example.com
  git -C "$REPO" config user.name "Test User"
}

create_skill() {
  package_path=$1
  skill_name=$2
  mkdir -p "$REPO/$package_path/references" "$REPO/$package_path/scripts" \
    "$REPO/$package_path/assets" "$REPO/$package_path/evals"
  cat >"$REPO/$package_path/SKILL.md" <<EOF
---
name: $skill_name
description: Review $skill_name packages safely.
---
# $skill_name

[Guide](references/guide.md)

Stable body one.
Stable body two.
EOF
  printf '# Guide\n' >"$REPO/$package_path/references/guide.md"
  printf '#!/usr/bin/env bash\nprintf "checked\\n"\n' >"$REPO/$package_path/scripts/check.sh"
  chmod +x "$REPO/$package_path/scripts/check.sh"
  printf 'asset for %s\n' "$skill_name" >"$REPO/$package_path/assets/logo.txt"
  printf '# Evaluation notes\n' >"$REPO/$package_path/evals/notes.md"
}

append_reviewable_change() {
  skill_file=$1
  i=1
  while [ "$i" -le 12 ]; do
    printf 'Changed package contract line %02d.\n' "$i" >>"$REPO/$skill_file"
    i=$((i + 1))
  done
}

normalize_diff_fixture() {
  diff_file=$1
  diff_body=$(cat "$diff_file")
  printf '%s' "$diff_body" >"$diff_file"
}

added_right_lines_for_file() {
  diff_file=$1
  skill_file=$2
  awk -v target="+++ b/$skill_file" '
    $0 == target { in_file = 1; next }
    in_file && /^diff --git / { exit }
    in_file && /^@@ / {
      header = $0
      sub(/^@@ -[^ ]+ \+/, "", header)
      sub(/ .*/, "", header)
      sub(/,.*/, "", header)
      right = header - 1
      in_hunk = 1
      next
    }
    in_file && in_hunk && /^\+/ { right++; print right; next }
    in_file && in_hunk && /^-/ { next }
    in_file && in_hunk && /^ / { right++ }
  ' "$diff_file"
}

meta_for_paths() {
  files='[]'
  for path in "$@"; do
    files=$(jq -cn --argjson files "$files" --arg path "$path" \
      '$files + [{path:$path,additions:12,deletions:0}]')
  done
  jq -cn --arg head "$(git -C "$REPO" rev-parse HEAD)" --argjson files "$files" \
    '{headRefOid:$head,headRefName:"feature/package-context",baseRefName:"main",title:"skill package",body:"",author:{login:"human"},files:$files}'
}

run_local_prefetch() {
  out=$1
  meta=$2
  diff_file=$3
  stdout_file="$TMP_ROOT/prefetch.$$.out"
  stderr_file="$TMP_ROOT/prefetch.$$.err"
  set +e
  (
    cd "$REPO"
    PATH="$TEST_PATH" \
    OUTDIR="$out" \
    PR_NUMBER=1 \
    GITHUB_REPOSITORY=owner/repo \
    GITHUB_WORKSPACE="$REPO" \
    WOO_REVIEW_TEST_MODE=1 \
    WOO_REVIEW_FAKE_PR_REVIEWS_JSON='{"reviews":[]}' \
    WOO_REVIEW_FAKE_BOT_COMMENTS=0 \
    WOO_REVIEW_FAKE_META_JSON="$meta" \
    WOO_REVIEW_FAKE_FULL_DIFF="$(cat "$diff_file")" \
    WOO_REVIEW_FAKE_PRIOR_THREADS_JSON='{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[]}}}}}' \
    WOO_REVIEW_TEST_SNAPSHOT_MAX_FILES="${WOO_REVIEW_TEST_SNAPSHOT_MAX_FILES:-}" \
    WOO_REVIEW_TEST_SNAPSHOT_MAX_FILE_BYTES="${WOO_REVIEW_TEST_SNAPSHOT_MAX_FILE_BYTES:-}" \
    WOO_REVIEW_TEST_SNAPSHOT_MAX_BYTES="${WOO_REVIEW_TEST_SNAPSHOT_MAX_BYTES:-}" \
    WOO_REVIEW_TEST_SNAPSHOT_VALIDATOR="${WOO_REVIEW_TEST_SNAPSHOT_VALIDATOR:-}" \
    WOO_REVIEW_TEST_REAL_VALIDATOR="${WOO_REVIEW_TEST_REAL_VALIDATOR:-}" \
    WOO_REVIEW_TEST_RACE_FILE="${WOO_REVIEW_TEST_RACE_FILE:-}" \
      bash "$PREFETCH"
  ) >"$stdout_file" 2>"$stderr_file"
  RUN_RC=$?
  set -e
  RUN_STDOUT=$(cat "$stdout_file")
  RUN_STDERR=$(cat "$stderr_file")
  rm -f "$stdout_file" "$stderr_file"
}

check_manifest_contract() {
  out=$1
  shift
  node - "$out" "$REPO" "$@" <<'NODE'
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const [out, repo, ...expectedSkills] = process.argv.slice(2);
const manifestPath = path.join(out, 'skill-packages.json');
const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
const fail = (message) => { throw new Error(message); };
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
const compareCodePoints = (a, b) => a < b ? -1 : a > b ? 1 : 0;
const digest = (data) => `sha256:${crypto.createHash('sha256').update(data).digest('hex')}`;

if (manifest.schemaVersion !== 1 || !Array.isArray(manifest.packages)) {
  fail('manifest must be schemaVersion 1 with a packages array');
}
const expectedSorted = [...expectedSkills].sort(compareCodePoints);
const actualSkills = manifest.packages.map((entry) => entry.skillPath);
if (!same(actualSkills, expectedSorted)) fail(`packages are not deterministically sorted: ${actualSkills}`);

if (manifest.packages.length > 1) {
  const hashes = manifest.packages.map((entry) => entry.packageHash);
  if (new Set(hashes).size !== hashes.length) fail('distinct fixture packages must have distinct package hashes');
}

for (const skillPath of expectedSorted) {
  const entry = manifest.packages.find((candidate) => candidate.skillPath === skillPath);
  const packagePath = path.posix.dirname(skillPath);
  if (!entry || entry.packagePath !== packagePath) fail(`missing owning package for ${skillPath}`);
  const encodedPackagePath = packagePath === '.'
    ? '%2E'
    : packagePath.split('/').map((segment) => encodeURIComponent(segment)).join('%2F');
  const expectedSnapshotPath = `skill-packages/${encodedPackagePath}`;
  if (entry.snapshotPath !== expectedSnapshotPath) {
    fail(`snapshot path must encode the package path (${packagePath} -> ${expectedSnapshotPath}), got ${entry.snapshotPath}`);
  }
  if (!Array.isArray(entry.files)) fail('missing package file inventory');

  const expectedFiles = [
    ['SKILL.md', 'skill'],
    ['assets/logo.txt', 'asset'],
    ['evals/notes.md', 'eval'],
    ['references/guide.md', 'reference'],
    ['scripts/check.sh', 'script'],
  ];
  const actualInventory = entry.files.map((file) => [file.path, file.type]);
  if (!same(actualInventory, expectedFiles)) {
    fail(`manifest file order/classification is wrong for ${skillPath}: ${JSON.stringify(actualInventory)}`);
  }
  const packageHash = digest(Buffer.from(
    entry.files.map((file) => `${file.path}\0${file.sha256}\n`).join(''),
    'utf8',
  ));
  if (entry.packageHash !== packageHash) fail(`wrong package hash for ${skillPath}`);

  const snapshotRoot = path.join(out, entry.snapshotPath);
  const seen = [];
  const walk = (dir, prefix = '') => {
    for (const dirent of fs.readdirSync(dir, { withFileTypes: true })) {
      const rel = prefix ? `${prefix}/${dirent.name}` : dirent.name;
      const absolute = path.join(dir, dirent.name);
      const stat = fs.lstatSync(absolute);
      if (stat.isSymbolicLink() || (!stat.isDirectory() && !stat.isFile())) fail(`unsafe snapshot entry: ${rel}`);
      if (stat.isDirectory()) walk(absolute, rel); else seen.push(rel);
    }
  };
  walk(snapshotRoot);
  seen.sort(compareCodePoints);
  if (!same(seen, expectedFiles.map(([file]) => file))) fail(`snapshot leaked or omitted files: ${seen}`);

  for (const expected of expectedFiles) {
    const rel = expected[0];
    const file = entry.files.find((candidate) => candidate.path === rel);
    const sourceBytes = fs.readFileSync(path.join(repo, packagePath, rel));
    const snapshotBytes = fs.readFileSync(path.join(snapshotRoot, rel));
    if (!sourceBytes.equals(snapshotBytes)) fail(`snapshot differs from Git-visible source: ${rel}`);
    if (file.bytes !== sourceBytes.length || file.sha256 !== digest(sourceBytes)) {
      fail(`wrong bytes/hash for ${rel}`);
    }
  }
}
NODE
}

assert_manifest() {
  out=$1
  label=$2
  shift 2
  error_file="$TMP_ROOT/manifest-check.$$.err"
  if [ -f "$out/skill-packages.json" ] && check_manifest_contract "$out" "$@" 2>"$error_file"; then
    pass
  else
    fail "package snapshot: $label"
  fi
  rm -f "$error_file"
}

assert_blocked() {
  out=$1
  label=$2
  diff_file=$3
  if [ "$RUN_RC" -ne 0 ] && \
    printf '%s\n%s' "$RUN_STDOUT" "$RUN_STDERR" | grep -qF -- '::error::' && \
    [ ! -e "$out/skill-packages.json" ] && \
    [ ! -e "$out/skill-packages" ]; then
    pass
  else
    fail "package snapshot: $label must hard-fail prefetch without publishing a manifest"
  fi
  if [ -f "$out/diff.txt" ] && cmp -s "$diff_file" "$out/diff.txt"; then
    pass
  else
    fail "package snapshot: $label must not rewrite the authoritative diff"
  fi
}

# Existing package: tracked owning-package inventory only, hashes, deterministic
# destination, byte-for-byte authoritative diff, and diff-only finding anchors.
init_repo existing
create_skill skills/alpha alpha
create_skill skills/unrelated unrelated
printf 'skills/alpha/assets/ignored.txt\n' >"$REPO/.gitignore"
git -C "$REPO" add .
git -C "$REPO" commit -q -m base
printf 'ignored\n' >"$REPO/skills/alpha/assets/ignored.txt"
printf 'untracked\n' >"$REPO/skills/alpha/assets/untracked.txt"
append_reviewable_change skills/alpha/SKILL.md
git -C "$REPO" add skills/alpha/SKILL.md
git -C "$REPO" commit -q -m reviewable-change
existing_diff="$TMP_ROOT/existing.diff"
git -C "$REPO" show --format= --no-ext-diff --binary HEAD -- skills/alpha/SKILL.md >"$existing_diff"
normalize_diff_fixture "$existing_diff"
existing_meta=$(meta_for_paths skills/alpha/SKILL.md)
existing_out="$TMP_ROOT/existing-out"
run_local_prefetch "$existing_out" "$existing_meta" "$existing_diff"
assert_exit 0 "$RUN_RC" "existing skill fixture reaches prefetch completion"
assert_manifest "$existing_out" "existing touched skill exposes only tracked owning-package files with classifications and hashes" skills/alpha/SKILL.md
if cmp -s "$existing_diff" "$existing_out/diff.txt"; then pass; else fail "package snapshot: materialization must leave diff.txt byte-for-byte authoritative"; fi
assert_eq "$(OUTDIR="$existing_out" bash "$ANCHOR_RESOLVER" --file skills/alpha/SKILL.md --line 11 --no-cache)" 11 \
  "changed right-side SKILL line remains anchorable"
assert_eq "$(OUTDIR="$existing_out" bash "$ANCHOR_RESOLVER" --file skills/alpha/SKILL.md --line 1 --no-cache)" null \
  "resolver blocks the unchanged SKILL line outside diff.txt"
skills_prompt=$(cat "$SKILLS_PROMPT")
assert_contains "$skills_prompt" '`diff.txt` is the sole finding-anchor' \
  "skills worker keeps diff.txt as the sole finding-anchor"
assert_contains "$skills_prompt" '`resolve-diff-line.sh` authority' \
  "skills worker keeps resolve-diff-line.sh as finding-anchor authority"
assert_contains "$skills_prompt" 'attaching a sibling-file concern to an unrelated changed line' \
  "skills worker forbids borrowing an unrelated changed line for an unchanged sibling concern"
assert_contains "$skills_prompt" 'DROP any finding that resolves to `null`' \
  "skills worker drops findings without a resolver-approved anchor"
assert_not_contains "$skills_prompt" \
  "may attach an unchanged sibling-file concern to an unrelated changed line" \
  "skills worker does not explicitly permit borrowing an unrelated changed line"
assert_not_contains "$skills_prompt" \
  "may anchor an unchanged package concern to any changed line" \
  "skills worker does not explicitly permit anchoring an unchanged concern"
existing_out_again="$TMP_ROOT/existing-out-again"
run_local_prefetch "$existing_out_again" "$existing_meta" "$existing_diff"
if [ -f "$existing_out/skill-packages.json" ] && [ -f "$existing_out_again/skill-packages.json" ] && \
  cmp -s "$existing_out/skill-packages.json" "$existing_out_again/skill-packages.json"; then
  pass
else
  fail "package snapshot: repeated fresh local prefetch uses the same deterministic package manifest"
fi

# Every tracked package byte must still match the immutable reviewed HEAD.
printf 'dirty sibling bytes\n' >>"$REPO/skills/alpha/references/guide.md"
run_local_prefetch "$TMP_ROOT/dirty-sibling-out" "$existing_meta" "$existing_diff"
assert_blocked "$TMP_ROOT/dirty-sibling-out" "dirty tracked package sibling" "$existing_diff"
assert_contains "$RUN_STDERR" \
  'tracked package differs from the immutable PR head: skills/alpha' \
  "dirty tracked sibling identifies the package that violated the immutable source boundary"
git -C "$REPO" checkout -- skills/alpha/references/guide.md

# Validator process failures retain bounded process diagnostics instead of
# collapsing every failure into an unreadable-output message.
fake_validator="$TMP_ROOT/failing-validator.mjs"
cat >"$fake_validator" <<'NODE'
process.stderr.write('simulated validator\u0001crash\n');
process.stdout.write('{');
process.exit(7);
NODE
WOO_REVIEW_TEST_SNAPSHOT_VALIDATOR="$fake_validator" \
  run_local_prefetch "$TMP_ROOT/validator-process-out" "$existing_meta" "$existing_diff"
assert_blocked "$TMP_ROOT/validator-process-out" "validator process failure" "$existing_diff"
assert_contains "$RUN_STDERR" \
  'status=7 signal=none error=none stderr=simulated validator crash' \
  "validator failure reports sanitized status, signal, error, and stderr context"

# A tracked file that changes after validation cannot race into the published
# snapshot: publication uses the immutable HEAD blobs captured before validation.
race_validator="$TMP_ROOT/race-validator.mjs"
cat >"$race_validator" <<'NODE'
import fs from 'node:fs';
import { spawnSync } from 'node:child_process';

const validation = spawnSync(
  process.execPath,
  [process.env.WOO_REVIEW_TEST_REAL_VALIDATOR, ...process.argv.slice(2)],
  { encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 },
);
if (validation.error) throw validation.error;
fs.appendFileSync(process.env.WOO_REVIEW_TEST_RACE_FILE, 'raced bytes\n');
process.stdout.write(validation.stdout || '');
process.stderr.write(validation.stderr || '');
process.exit(validation.status ?? 1);
NODE
race_out="$TMP_ROOT/race-out"
WOO_REVIEW_TEST_SNAPSHOT_VALIDATOR="$race_validator" \
WOO_REVIEW_TEST_REAL_VALIDATOR="$ROOT/skills/woostack-eval/scripts/validate.mjs" \
WOO_REVIEW_TEST_RACE_FILE="$REPO/skills/alpha/references/guide.md" \
  run_local_prefetch "$race_out" "$existing_meta" "$existing_diff"
assert_exit 0 "$RUN_RC" "concurrent post-validation package change cannot alter the snapshot"
git -C "$REPO" show HEAD:skills/alpha/references/guide.md >"$TMP_ROOT/head-guide.md"
if cmp -s "$TMP_ROOT/head-guide.md" \
  "$race_out/skill-packages/skills%2Falpha/references/guide.md" &&
  ! cmp -s "$REPO/skills/alpha/references/guide.md" \
  "$race_out/skill-packages/skills%2Falpha/references/guide.md"; then
  pass
else
  fail "package snapshot: publication must use immutable HEAD bytes after a concurrent mutation"
fi
git -C "$REPO" checkout -- skills/alpha/references/guide.md

# A repository-root SKILL.md uses package path `.`. The collision-safe encoding
# formula is path-segment URI encoding with `/` encoded as `%2F`, and the root
# sentinel encoded explicitly as `%2E`.
init_repo root-skill
create_skill . root-skill
git -C "$REPO" add .
git -C "$REPO" commit -q -m base
append_reviewable_change SKILL.md
git -C "$REPO" add SKILL.md
git -C "$REPO" commit -q -m reviewable-change
root_diff="$TMP_ROOT/root.diff"
git -C "$REPO" show --format= --no-ext-diff --binary HEAD -- SKILL.md >"$root_diff"
normalize_diff_fixture "$root_diff"
root_out="$TMP_ROOT/root-out"
run_local_prefetch "$root_out" "$(meta_for_paths SKILL.md)" "$root_diff"
assert_exit 0 "$RUN_RC" "repository-root skill fixture reaches prefetch completion"
assert_manifest "$root_out" "repository-root SKILL.md uses skill-packages/%2E" SKILL.md
if cmp -s "$root_diff" "$root_out/diff.txt"; then pass; else fail "package snapshot: root package materialization must leave diff.txt authoritative"; fi

# A committed deleted SKILL.md has no stage-0 index record, RIGHT-side package,
# or anchor. Prefetch succeeds, publishes an empty package manifest, preserves
# the deletion diff, and leaves the skills angle disabled.
init_repo deleted-skill
create_skill skills/deleted deleted
git -C "$REPO" add .
git -C "$REPO" commit -q -m base
git -C "$REPO" rm -q skills/deleted/SKILL.md
git -C "$REPO" commit -q -m delete-skill
deleted_diff="$TMP_ROOT/deleted.diff"
git -C "$REPO" show --format= --no-ext-diff --binary HEAD -- skills/deleted/SKILL.md >"$deleted_diff"
normalize_diff_fixture "$deleted_diff"
deleted_out="$TMP_ROOT/deleted-out"
run_local_prefetch "$deleted_out" "$(meta_for_paths skills/deleted/SKILL.md)" "$deleted_diff"
assert_exit 0 "$RUN_RC" "deleted skill fixture reaches prefetch completion"
if [ "$(jq -r '.schemaVersion' "$deleted_out/skill-packages.json")" = "1" ] &&
  [ "$(jq -r '.packages | length' "$deleted_out/skill-packages.json")" = "0" ]; then
  pass
else
  fail "package snapshot: deleted SKILL.md must produce an empty package manifest"
fi
if cmp -s "$deleted_diff" "$deleted_out/diff.txt"; then
  pass
else
  fail "package snapshot: deleted SKILL.md must leave diff.txt byte-for-byte authoritative"
fi
OUTDIR="$deleted_out" bash "$SCRIPT_DIR/detect-angles.sh" >/dev/null
if [ "$(grep -cx 'skills' "$deleted_out/angles.txt" || true)" -eq 0 ]; then
  pass
else
  fail "package snapshot: deleted SKILL.md must not enable the skills angle"
fi

# A PR-touched SKILL.md that still has a stage-0 index record but is missing
# only from the worktree is not an authoritative deletion. Fail closed rather
# than silently omitting its package and later treating it as a LOC-floor skip.
init_repo unstaged-deletion
create_skill skills/unstaged unstaged
git -C "$REPO" add .
git -C "$REPO" commit -q -m base
rm "$REPO/skills/unstaged/SKILL.md"
unstaged_diff="$TMP_ROOT/unstaged-deletion.diff"
git -C "$REPO" diff --no-ext-diff --binary -- skills/unstaged/SKILL.md >"$unstaged_diff"
normalize_diff_fixture "$unstaged_diff"
run_local_prefetch "$TMP_ROOT/unstaged-deletion-out" \
  "$(meta_for_paths skills/unstaged/SKILL.md)" "$unstaged_diff"
assert_blocked "$TMP_ROOT/unstaged-deletion-out" "unstaged SKILL.md deletion" "$unstaged_diff"

# Tracked symlinks are unsafe even when their target remains inside the package.
init_repo symlink
create_skill skills/alpha alpha
ln -s ../SKILL.md "$REPO/skills/alpha/assets/linked-skill"
git -C "$REPO" add .
git -C "$REPO" commit -q -m base
append_reviewable_change skills/alpha/SKILL.md
git -C "$REPO" add skills/alpha/SKILL.md
git -C "$REPO" commit -q -m reviewable-change
symlink_diff="$TMP_ROOT/symlink.diff"
git -C "$REPO" show --format= --no-ext-diff --binary HEAD -- skills/alpha/SKILL.md >"$symlink_diff"
normalize_diff_fixture "$symlink_diff"
run_local_prefetch "$TMP_ROOT/symlink-out" "$(meta_for_paths skills/alpha/SKILL.md)" "$symlink_diff"
assert_blocked "$TMP_ROOT/symlink-out" "tracked symlink" "$symlink_diff"

# A gitlink (mode 160000) is the tracked special-file case Git can represent.
init_repo special
create_skill skills/alpha alpha
git -C "$REPO" add .
git -C "$REPO" commit -q -m base
special_oid=$(git -C "$REPO" rev-parse HEAD)
git -C "$REPO" update-index --add --cacheinfo "160000,$special_oid,skills/alpha/assets/vendor"
git -C "$REPO" commit -q -m gitlink
append_reviewable_change skills/alpha/SKILL.md
git -C "$REPO" add skills/alpha/SKILL.md
git -C "$REPO" commit -q -m reviewable-change
special_diff="$TMP_ROOT/special.diff"
git -C "$REPO" show --format= --no-ext-diff --binary HEAD -- skills/alpha/SKILL.md >"$special_diff"
normalize_diff_fixture "$special_diff"
run_local_prefetch "$TMP_ROOT/special-out" "$(meta_for_paths skills/alpha/SKILL.md)" "$special_diff"
assert_blocked "$TMP_ROOT/special-out" "tracked special file" "$special_diff"

# Tracked secret/unsafe paths fail closed rather than being silently copied.
init_repo unsafe
create_skill skills/alpha alpha
printf 'not-a-real-secret\n' >"$REPO/skills/alpha/.env.secret"
git -C "$REPO" add -f .
git -C "$REPO" commit -q -m base
append_reviewable_change skills/alpha/SKILL.md
git -C "$REPO" add skills/alpha/SKILL.md
git -C "$REPO" commit -q -m reviewable-change
unsafe_diff="$TMP_ROOT/unsafe.diff"
git -C "$REPO" show --format= --no-ext-diff --binary HEAD -- skills/alpha/SKILL.md >"$unsafe_diff"
normalize_diff_fixture "$unsafe_diff"
run_local_prefetch "$TMP_ROOT/unsafe-out" "$(meta_for_paths skills/alpha/SKILL.md)" "$unsafe_diff"
assert_blocked "$TMP_ROOT/unsafe-out" "tracked unsafe path" "$unsafe_diff"

# A deterministic validator error (missing direct resource) also blocks prefetch.
init_repo invalid
create_skill skills/alpha alpha
git -C "$REPO" add .
git -C "$REPO" commit -q -m base
printf '\n[Missing](references/missing.md)\n' >>"$REPO/skills/alpha/SKILL.md"
i=1; while [ "$i" -le 10 ]; do printf 'Invalid fixture filler %02d.\n' "$i" >>"$REPO/skills/alpha/SKILL.md"; i=$((i + 1)); done
git -C "$REPO" add skills/alpha/SKILL.md
git -C "$REPO" commit -q -m reviewable-change
invalid_diff="$TMP_ROOT/invalid.diff"
git -C "$REPO" show --format= --no-ext-diff --binary HEAD -- skills/alpha/SKILL.md >"$invalid_diff"
normalize_diff_fixture "$invalid_diff"
run_local_prefetch "$TMP_ROOT/invalid-out" "$(meta_for_paths skills/alpha/SKILL.md)" "$invalid_diff"
assert_blocked "$TMP_ROOT/invalid-out" "shared validator failure" "$invalid_diff"
assert_contains "$RUN_STDERR" \
  'code=link-target-missing path=SKILL.md field=/links/1 message=Local link target does not exist' \
  "shared validator failure identifies the offending code, path, field, and message"

# Snapshot resource ceilings fail before validation or publication. Test-only
# lower limits exercise each production boundary without creating huge files.
init_repo bounded
create_skill skills/alpha alpha
git -C "$REPO" add .
git -C "$REPO" commit -q -m base
append_reviewable_change skills/alpha/SKILL.md
git -C "$REPO" add skills/alpha/SKILL.md
git -C "$REPO" commit -q -m reviewable-change
bounded_diff="$TMP_ROOT/bounded.diff"
git -C "$REPO" show --format= --no-ext-diff --binary HEAD -- skills/alpha/SKILL.md >"$bounded_diff"
normalize_diff_fixture "$bounded_diff"
WOO_REVIEW_TEST_SNAPSHOT_MAX_FILES=4 \
  run_local_prefetch "$TMP_ROOT/bounded-files-out" \
  "$(meta_for_paths skills/alpha/SKILL.md)" "$bounded_diff"
assert_blocked "$TMP_ROOT/bounded-files-out" "tracked file-count ceiling" "$bounded_diff"
assert_contains "$RUN_STDERR" 'snapshot exceeds 4 tracked files' \
  "tracked file-count ceiling reports its bound"
WOO_REVIEW_TEST_SNAPSHOT_MAX_FILE_BYTES=16 \
  run_local_prefetch "$TMP_ROOT/bounded-file-bytes-out" \
  "$(meta_for_paths skills/alpha/SKILL.md)" "$bounded_diff"
assert_blocked "$TMP_ROOT/bounded-file-bytes-out" "per-file byte ceiling" "$bounded_diff"
assert_contains "$RUN_STDERR" 'file exceeds 16 bytes' \
  "per-file byte ceiling reports its bound"
WOO_REVIEW_TEST_SNAPSHOT_MAX_BYTES=32 \
  run_local_prefetch "$TMP_ROOT/bounded-total-bytes-out" \
  "$(meta_for_paths skills/alpha/SKILL.md)" "$bounded_diff"
assert_blocked "$TMP_ROOT/bounded-total-bytes-out" "aggregate byte ceiling" "$bounded_diff"
assert_contains "$RUN_STDERR" 'snapshot exceeds 32 bytes' \
  "aggregate byte ceiling reports its bound"

# A newly added, staged skill package is Git-visible and snapshots successfully.
init_repo new-package
printf '# fixture\n' >"$REPO/README.md"
printf 'skills/new-skill/assets/ignored.txt\n' >"$REPO/.gitignore"
git -C "$REPO" add .
git -C "$REPO" commit -q -m base
create_skill skills/new-skill new-skill
printf 'ignored\n' >"$REPO/skills/new-skill/assets/ignored.txt"
git -C "$REPO" add skills/new-skill
git -C "$REPO" commit -q -m add-skill
printf 'untracked\n' >"$REPO/skills/new-skill/assets/untracked.txt"
new_diff="$TMP_ROOT/new.diff"
git -C "$REPO" show --format= --no-ext-diff --binary HEAD -- skills/new-skill >"$new_diff"
normalize_diff_fixture "$new_diff"
run_local_prefetch "$TMP_ROOT/new-out" "$(meta_for_paths skills/new-skill/SKILL.md)" "$new_diff"
assert_exit 0 "$RUN_RC" "new skill fixture reaches prefetch completion"
assert_manifest "$TMP_ROOT/new-out" "new Git-visible skill package is materialized" skills/new-skill/SKILL.md
new_skill_added_lines=$(added_right_lines_for_file "$new_diff" skills/new-skill/SKILL.md)
if [ -n "$new_skill_added_lines" ]; then
  pass
else
  fail "new skill fixture exposes added right-side SKILL.md lines"
fi
for new_skill_line in $new_skill_added_lines; do
  assert_eq "$(OUTDIR="$TMP_ROOT/new-out" bash "$ANCHOR_RESOLVER" \
    --file skills/new-skill/SKILL.md --line "$new_skill_line" --no-cache)" "$new_skill_line" \
    "new skill added line $new_skill_line is anchorable"
done

# Multiple touched skills have sorted manifest entries and distinct deterministic
# package directories; reversing metadata order cannot change the manifest.
init_repo multiple
create_skill skills/alpha alpha
create_skill skills/beta beta
git -C "$REPO" add .
git -C "$REPO" commit -q -m base
append_reviewable_change skills/alpha/SKILL.md
append_reviewable_change skills/beta/SKILL.md
git -C "$REPO" add skills/alpha/SKILL.md skills/beta/SKILL.md
git -C "$REPO" commit -q -m reviewable-changes
multiple_diff="$TMP_ROOT/multiple.diff"
git -C "$REPO" show --format= --no-ext-diff --binary HEAD -- \
  skills/alpha/SKILL.md skills/beta/SKILL.md >"$multiple_diff"
normalize_diff_fixture "$multiple_diff"
run_local_prefetch "$TMP_ROOT/multiple-out" \
  "$(meta_for_paths skills/beta/SKILL.md skills/alpha/SKILL.md)" "$multiple_diff"
assert_exit 0 "$RUN_RC" "multiple skill fixture reaches prefetch completion"
assert_manifest "$TMP_ROOT/multiple-out" "multiple touched skills use distinct sorted package directories" \
  skills/alpha/SKILL.md skills/beta/SKILL.md
run_local_prefetch "$TMP_ROOT/multiple-out-again" \
  "$(meta_for_paths skills/alpha/SKILL.md skills/beta/SKILL.md)" "$multiple_diff"
if [ -f "$TMP_ROOT/multiple-out/skill-packages.json" ] && \
  [ -f "$TMP_ROOT/multiple-out-again/skill-packages.json" ] && \
  cmp -s "$TMP_ROOT/multiple-out/skill-packages.json" "$TMP_ROOT/multiple-out-again/skill-packages.json"; then
  pass
else
  fail "package snapshot: metadata order cannot change deterministic package directories or manifest"
fi

finish
