#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../woostack-init/scripts/tests/assert.sh"
set +e   # assert.sh enables -e; we capture doctor exit codes manually
DOC="$HERE/../doctor.sh"

empty="$(mktemp -d)"
out="$(bash "$DOC" "$empty" 2>&1)"; code=$?
assert_exit 2 "$code" "missing .woostack exits 2"
assert_contains "$out" "run woostack-init" "missing-workspace message points to init"

clean="$(mktemp -d)"; mkdir -p "$clean/.woostack/memory"
bash "$DOC" "$clean" >/dev/null 2>&1; assert_exit 0 "$?" "clean workspace exits 0"

warnws="$(mktemp -d)"; mkdir -p "$warnws/.woostack/memory"
printf -- '---\nname: n\ntype: gotcha\nscope: *\nsource: .woostack/specs/x.md\nupdated: 2099-01-01\n---\nbody [[ghost]]\n' > "$warnws/.woostack/memory/n.md"
bash "$DOC" "$warnws" >/dev/null 2>&1; assert_exit 0 "$?" "warn-only exits 0"

errws="$(mktemp -d)"; mkdir -p "$errws/.woostack/memory"
printf 'no fence\n' > "$errws/.woostack/memory/bad.md"
bash "$DOC" "$errws" >/dev/null 2>&1; assert_exit 1 "$?" "error finding exits 1"

dump="$(bash "$DOC" --check "$warnws" 2>/dev/null)"
assert_eq "$dump" "" "--check suppresses machine dump on stdout"

bash "$DOC" --check "$errws" >/dev/null 2>&1; assert_exit 1 "$?" "--check with errors still exits 1"

dump2="$(bash "$DOC" "$warnws" 2>/dev/null)"
assert_contains "$dump2" "memory-unresolved-link" "default mode dumps machine findings on stdout"

bad="$(bash "$DOC" --bogus "$warnws" 2>&1)"; bc=$?
assert_exit 2 "$bc" "unknown flag exits 2"
finish
