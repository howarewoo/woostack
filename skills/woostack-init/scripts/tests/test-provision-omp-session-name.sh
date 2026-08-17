#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROVISIONER="$HERE/../provision-omp-session-name.sh"
# shellcheck disable=SC1091
source "$HERE/assert.sh"

ROOT="$(mktemp -d)"
ROOT="$(cd "$ROOT" && pwd -P)"
trap 'rm -rf "$ROOT"' EXIT

file_state() {
  if [ -f "$1" ]; then stat -f "%m:%z" "$1" 2>/dev/null || stat -c "%Y:%s" "$1" 2>/dev/null; else echo "missing"; fi
}

# 1. Preservation of consumer-owned extensions, settings, and ignore rules
mkdir -p "$ROOT/.omp/extensions"
printf '%s\n' 'consumer-ext-content' >"$ROOT/.omp/extensions/custom.ts"
printf '%s\n' '{"theme": "nord", "extensions": ["./custom-ext.ts"]}' >"$ROOT/.omp/settings.json"
printf '%s' 'consumer-ignore' >"$ROOT/.omp/.gitignore"

bash "$PROVISIONER" "$ROOT" >/dev/null
assert_eq "$(cat "$ROOT/.omp/extensions/custom.ts")" "consumer-ext-content" "preserves consumer extensions"
assert_contains "$(cat "$ROOT/.omp/settings.json")" '"theme": "nord"' "preserves settings keys"
assert_contains "$(cat "$ROOT/.omp/settings.json")" '"./custom-ext.ts"' "preserves extensions entries"
assert_contains "$(cat "$ROOT/.omp/settings.json")" '".omp/extensions/woostack-session-name.ts"' "adds managed extension"
assert_contains "$(cat "$ROOT/.omp/.gitignore")" 'consumer-ignore' "preserves consumer ignore"
assert_contains "$(cat "$ROOT/.omp/.gitignore")" 'settings.json' "adds settings ignore"
assert_contains "$(cat "$ROOT/.omp/.gitignore")" 'extensions/woostack-session-name.ts' "adds extension ignore"
assert_eq "$(bash "$PROVISIONER" --check "$ROOT")" "" "clean state passes diagnosis"

# 2. Byte idempotence
before="$(file_state "$ROOT/.omp/extensions/woostack-session-name.ts"):$(file_state "$ROOT/.omp/settings.json"):$(file_state "$ROOT/.omp/.gitignore")"
bash "$PROVISIONER" "$ROOT" >/dev/null
after="$(file_state "$ROOT/.omp/extensions/woostack-session-name.ts"):$(file_state "$ROOT/.omp/settings.json"):$(file_state "$ROOT/.omp/.gitignore")"
assert_eq "$after" "$before" "provisioning is byte-idempotent"

# 3-6. Drift detection and repair
printf '%s\n' 'settings.json' >>"$ROOT/.omp/.gitignore"
assert_contains "$(bash "$PROVISIONER" --check "$ROOT")" "drifted" "reports duplicate ignore rules"
bash "$PROVISIONER" "$ROOT" >/dev/null
assert_eq "$(bash "$PROVISIONER" --check "$ROOT")" "" "repair restores clean ignore rules"

printf '%s\n' '// stale' >"$ROOT/.omp/extensions/woostack-session-name.ts"
assert_contains "$(bash "$PROVISIONER" --check "$ROOT")" "drifted" "reports drifted extension"
bash "$PROVISIONER" "$ROOT" >/dev/null
assert_eq "$(bash "$PROVISIONER" --check "$ROOT")" "" "repair restores template extension"

printf '%s\n' '{"theme": "nord"}' >"$ROOT/.omp/settings.json"
assert_contains "$(bash "$PROVISIONER" --check "$ROOT")" "drifted" "reports missing settings entry"
bash "$PROVISIONER" "$ROOT" >/dev/null
assert_contains "$(cat "$ROOT/.omp/settings.json")" '".omp/extensions/woostack-session-name.ts"' "repair adds extension entry"

printf '%s\n' '{"extensions": [".omp/extensions/woostack-session-name.ts", ".omp/extensions/woostack-session-name.ts"]}' >"$ROOT/.omp/settings.json"
assert_contains "$(bash "$PROVISIONER" --check "$ROOT")" "drifted" "reports duplicate settings extension entries"
bash "$PROVISIONER" "$ROOT" >/dev/null
assert_eq "$(bash "$PROVISIONER" --check "$ROOT")" "" "repair removes duplicate settings entries"
assert_eq "$(cat "$ROOT/.omp/settings.json")" $'{\n  "extensions": [\n    ".omp/extensions/woostack-session-name.ts"\n  ]\n}' "settings has one entry"

# 7-8. Malformed settings and git-tracked settings fail closed
printf '%s\n' '{invalid-json' >"$ROOT/.omp/settings.json"
assert_contains "$(bash "$PROVISIONER" --check "$ROOT")" "malformed" "reports malformed settings JSON"
set +e; bash "$PROVISIONER" "$ROOT" >/dev/null 2>&1; assert_exit 1 "$?" "fails closed on malformed settings JSON"; set -e

GIT_ROOT="$ROOT/git-repo"
mkdir -p "$GIT_ROOT/.omp"
(cd "$GIT_ROOT" && git init -q && git config user.name "Test" && git config user.email "t@example.com" && printf '%s\n' '{}' >.omp/settings.json && git add .omp/settings.json && git commit -q -m "track")
assert_contains "$(bash "$PROVISIONER" --check "$GIT_ROOT")" "tracked" "reports tracked settings"
set +e; bash "$PROVISIONER" "$GIT_ROOT" >/dev/null 2>&1; assert_exit 1 "$?" "fails closed on tracked settings"; set -e

# 9. Dangling and valid symlink rejection with zero writes across settings, extension, and ignore
for target in "settings.json" "extensions/woostack-session-name.ts" ".gitignore"; do
  for kind in dangling valid; do
    SYM_ROOT="$(mktemp -d)"
    SYM_ROOT="$(cd "$SYM_ROOT" && pwd -P)"
    mkdir -p "$SYM_ROOT/.omp/extensions"
    if [ "$kind" = "dangling" ]; then
      ln -s "$SYM_ROOT/nonexistent" "$SYM_ROOT/.omp/$target"
    else
      printf '%s\n' 'TARGET_CONTENT' >"$SYM_ROOT/target-payload"
      ln -s "$SYM_ROOT/target-payload" "$SYM_ROOT/.omp/$target"
    fi
    assert_contains "$(bash "$PROVISIONER" --check "$SYM_ROOT")" "malformed" "check diagnoses $kind symlink for $target as malformed"
    set +e; bash "$PROVISIONER" "$SYM_ROOT" >/dev/null 2>&1; sym_status=$?; set -e
    assert_exit 1 "$sym_status" "apply fails closed on $kind symlink for $target"
    if [ "$kind" = "valid" ]; then assert_eq "$(cat "$SYM_ROOT/target-payload")" "TARGET_CONTENT" "symlink target untouched for $target"; fi
    for other in "settings.json" "extensions/woostack-session-name.ts" ".gitignore"; do
      if [ "$other" != "$target" ]; then
        assert_eq "$([ -e "$SYM_ROOT/.omp/$other" ] || [ -L "$SYM_ROOT/.omp/$other" ] && echo y || echo n)" "n" "zero writes for $other on $kind $target collision"
      fi
    done
    rm -rf "$SYM_ROOT"
  done
done

# 10. Invocation from an unrelated working directory
UNRELATED_ROOT="$(mktemp -d)"
UNRELATED_ROOT="$(cd "$UNRELATED_ROOT" && pwd -P)"
UNRELATED_CWD="$(mktemp -d)"
(cd "$UNRELATED_CWD" && bash "$PROVISIONER" "$UNRELATED_ROOT" >/dev/null && assert_eq "$(bash "$PROVISIONER" --check "$UNRELATED_ROOT")" "" "succeeds from unrelated cwd")
rm -rf "$UNRELATED_CWD" "$UNRELATED_ROOT"

finish
