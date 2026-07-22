#!/usr/bin/env bash

node_native_path() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w -- "$1"
  else
    printf '%s\n' "$1"
  fi
}

shell_native_path() {
  if [[ "$1" =~ ^([A-Za-z]):[\\/](.*)$ ]]; then
    local drive=${BASH_REMATCH[1],,}
    local remainder=${BASH_REMATCH[2]//\\//}
    printf '/%s/%s\n' "$drive" "$remainder"
  elif command -v cygpath >/dev/null 2>&1; then
    cygpath -u -- "$1"
  else
    printf '%s\n' "$1"
  fi
}
