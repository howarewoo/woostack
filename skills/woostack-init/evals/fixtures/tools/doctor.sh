#!/usr/bin/env bash
set -u

if [ "$#" -ne 3 ] || [ "$1" != "--live-receipt" ]; then
  printf 'error\tinvocation-shape\texpected --live-receipt <receipt> <repository-root>\n'
  exit 2
fi

receipt="$2"
project_root="$3"
if [ ! -r "$receipt" ] ||
  ! grep -q '"provider"[[:space:]]*:[[:space:]]*"official-linear-mcp"' "$receipt" ||
  ! grep -q '"ready"[[:space:]]*:[[:space:]]*true' "$receipt"; then
  printf 'error\tlive-receipt\tmissing or unsuccessful official host-MCP receipt\n'
  exit 1
fi

root="$project_root/.woostack"
failed=0
for path in config.json .gitignore; do
  if [ ! -f "$root/$path" ]; then
    printf "error\tmissing-canonical-path\t%s\n" "$path"
    failed=1
  fi
done
if grep -q "LINEAR_API_KEY" "$root/config.json"; then
  printf "error\tcredential-in-config\tconfig.json\n"
  failed=1
fi
exit "$failed"
