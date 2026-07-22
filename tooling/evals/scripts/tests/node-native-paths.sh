#!/usr/bin/env bash
set -euo pipefail

: "${WOOSTACK_NATIVE_NODE:?WOOSTACK_NATIVE_NODE must name the native Node executable}"

args=()
convert_native_path() {
  local value=$1
  if command -v cygpath >/dev/null 2>&1 \
    && [[ "$value" == /[A-Za-z]/* || "$value" == /tmp/* ]]; then
    cygpath -w -- "$value"
  else
    printf '%s\n' "$value"
  fi
}

for variable in TMPDIR RESOLVER_MARKER ${!WOOSTACK_EVAL_TEST_@}; do
  value=${!variable-}
  if [ -n "$value" ]; then
    printf -v "$variable" '%s' "$(convert_native_path "$value")"
    export "$variable"
  fi
done

for argument in "$@"; do
  argument=$(convert_native_path "$argument")
  args+=("$argument")
done

exec "$WOOSTACK_NATIVE_NODE" "${args[@]}"
