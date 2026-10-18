#!/usr/bin/env bash
# Convert shell-native paths only at native Windows process boundaries.

_woostack_msys_or_cygwin() {
  case "${MSYSTEM:-}:$(uname -s 2>/dev/null)" in
    MINGW*:*|MSYS*:*|*:MSYS*|*:MINGW*|*:CYGWIN*) return 0 ;;
    *) return 1 ;;
  esac
}

_woostack_native_windows_tool() {
  local tool_path dependencies
  tool_path="$(type -P -- "$1" 2>/dev/null)" || return 1
  case "$tool_path" in
    *.exe|*.EXE) ;;
    *) [ -f "$tool_path.exe" ] || return 1; tool_path="$tool_path.exe" ;;
  esac
  dependencies="$(ldd "$tool_path" 2>/dev/null || true)"
  case "$dependencies" in
    *msys-2.0.dll*|*cygwin1.dll*) return 1 ;;
    *) return 0 ;;
  esac
}

# tool_path_arg <executable> <path>
# Prints a path suitable for the executable without changing the shell's path variables.
tool_path_arg() {
  local tool="$1" path="$2"
  if _woostack_msys_or_cygwin \
    && command -v cygpath >/dev/null 2>&1 \
    && _woostack_native_windows_tool "$tool"; then
    cygpath -w "$path"
  else
    printf '%s\n' "$path"
  fi
}
