#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../path-args.sh
. "$HERE/../path-args.sh"

fail() {
  printf 'test-path-args: %s\n' "$1" >&2
  exit 1
}

MOCK_BIN="$(mktemp -d)"
trap 'rm -rf "$MOCK_BIN"' EXIT
cat >"$MOCK_BIN/uname" <<'SH'
#!/usr/bin/env bash
printf 'MSYS_NT-10.0\n'
SH
cat >"$MOCK_BIN/cygpath" <<'SH'
#!/usr/bin/env bash
[ "$1" = "-w" ] || exit 2
printf 'C:\\converted\\%s\n' "${2#/}"
SH
cat >"$MOCK_BIN/ldd" <<'SH'
#!/usr/bin/env bash
case "$1" in
  *native.exe) printf 'KERNEL32.dll => /c/Windows/System32/KERNEL32.dll\n' ;;
  *) printf 'msys-2.0.dll => /usr/bin/msys-2.0.dll\n' ;;
esac
SH
cat >"$MOCK_BIN/native.exe" <<'SH'
#!/usr/bin/env bash
exit 0
SH
cat >"$MOCK_BIN/posix.exe" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "$MOCK_BIN/uname" "$MOCK_BIN/cygpath" "$MOCK_BIN/ldd" \
  "$MOCK_BIN/native.exe" "$MOCK_BIN/posix.exe"

PATH="$MOCK_BIN:$PATH"
INPUT='/tmp/path with spaces/config.json'
NATIVE_RESULT="$(tool_path_arg native.exe "$INPUT")"
[ "$NATIVE_RESULT" = 'C:\converted\tmp/path with spaces/config.json' ] \
  || fail "native Windows tool path was not translated with spaces preserved: $NATIVE_RESULT"
POSIX_RESULT="$(tool_path_arg posix.exe "$INPUT")"
[ "$POSIX_RESULT" = "$INPUT" ] \
  || fail "POSIX tool path changed: $POSIX_RESULT"

printf 'test-path-args: ok\n'
