#!/usr/bin/env bash
# Self-contained (no external assert harness): verifies compose-wisdom.sh cats
# all wisdom bodies wholesale and is a no-op when the store is absent/empty.
set -uo pipefail
SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/compose-wisdom.sh"
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok - $1"; else echo "FAIL - $1 (got '$2', want '$3')"; fail=1; fi; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Case 1: absent store → empty output, exit 0.
out="$(bash "$SCRIPT" "$tmp" 2>/dev/null)"; rc=$?
check "absent store is empty" "$out" ""
check "absent store exits 0" "$rc" "0"

# Case 2: two wisdom files → both bodies present, with SOURCE headers.
mkdir -p "$tmp/.woostack/wisdom"
printf -- '---\nname: a\ntype: wisdom\n---\nAlpha finding.\n' > "$tmp/.woostack/wisdom/a.md"
printf -- '---\nname: b\ntype: wisdom\n---\nBeta finding.\n'  > "$tmp/.woostack/wisdom/b.md"
out="$(bash "$SCRIPT" "$tmp")"
case "$out" in *"Alpha finding."*) echo "ok - emits a.md body";; *) echo "FAIL - missing a.md body"; fail=1;; esac
case "$out" in *"Beta finding."*)  echo "ok - emits b.md body";; *) echo "FAIL - missing b.md body"; fail=1;; esac
case "$out" in *"SOURCE: a.md"*)   echo "ok - labels source a.md";; *) echo "FAIL - missing SOURCE a.md"; fail=1;; esac

# Case 3: empty store dir (only .gitkeep) → empty output.
rm -f "$tmp/.woostack/wisdom/"*.md; : > "$tmp/.woostack/wisdom/.gitkeep"
out="$(bash "$SCRIPT" "$tmp" 2>/dev/null)"; rc=$?
check "empty store (.gitkeep only) is empty" "$out" ""
check "empty store (.gitkeep only) exits 0" "$rc" "0"

[ "$fail" = 0 ] && echo "PASS" || { echo "FAILED"; exit 1; }
