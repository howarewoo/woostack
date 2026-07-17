#!/usr/bin/env bash
set -u
root="$1/.woostack"
failed=0
for path in memory/MEMORY.md fixes/.gitkeep wisdom/.gitkeep respond/.gitkeep config.json .gitignore; do
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
