#!/usr/bin/env bash
# Builds an all-added synthetic diff for an explicit standing-code target so review's
# diff-anchored swarm audits code at rest. AUDIT_TARGET is required (no default). Skips binary,
# gitignored, lockfile, and generated files. Warns when the synthetic diff exceeds the cap
# (WOO_REVIEW_DIFF_CAP_BYTES) and delegates size handling to chunk-diff.sh chunking — it does not
# truncate. bash-3.2 safe (guards empty arrays).
set -euo pipefail
RVW="$(dirname "${BASH_SOURCE[0]:-$0}")/../../woostack-review/scripts"
source "$RVW/resolve-outdir.sh"
TARGET="${AUDIT_TARGET:?AUDIT_TARGET (an explicit path) is required — woostack-audit <target>}"
if [ ! -e "$TARGET" ]; then
  echo "::error::audit target not found: $TARGET" >&2
  exit 1
fi
: > "$OUTDIR/diff.txt"

# Enumerate candidate files: honor .gitignore when the target lives inside a repo, else find.
# Run git in the *target's* repo (via -C "$repo_root"), not the script's CWD, so a cross-repo
# audit still honors the target's .gitignore instead of silently falling back to `find` (which
# does not). --full-name yields repo-root-relative paths; sed re-absolutizes them for the loop.
target_dir="$TARGET"; [ -d "$target_dir" ] || target_dir="$(dirname "$TARGET")"
repo_root="$(git -C "$target_dir" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$repo_root" ]; then
  enum() {
    git -C "$repo_root" ls-files --cached --others --exclude-standard --full-name -- "$TARGET" 2>/dev/null \
      | sed "s|^|$repo_root/|" \
      || find "$TARGET" -type f
  }
else
  enum() { find "$TARGET" -type f; }
fi

files=()
while IFS= read -r f; do
  [ -f "$f" ] || continue
  case "$f" in *.lock|*-lock.json|*.min.js|*.map) continue;; esac
  grep -Iq . "$f" 2>/dev/null || continue   # -I skips binary; empty files have no content to audit
  files+=("$f")
done < <(enum)

# Append one all-added new-file section per file. `git diff --no-index /dev/null <f>` exits 1
# ("differs", always true vs /dev/null) — expected, never a failure.
for f in ${files[@]+"${files[@]}"}; do
  git diff --no-index -- /dev/null "$f" >> "$OUTDIR/diff.txt" 2>/dev/null || true
done

# Synthesize meta.json (synthetic head = current HEAD when in a repo, else "audit").
head_oid="$(git rev-parse HEAD 2>/dev/null || echo audit)"
printf '%s\n' ${files[@]+"${files[@]}"} | jq -R 'select(length>0)' | jq -s \
  --arg oid "$head_oid" --arg t "$TARGET" \
  '{headRefOid:$oid, baseRefName:"audit", title:("(audit: "+$t+")"), body:"", files:[.[]|{path:.}]}' \
  > "$OUTDIR/meta.json"

# Section-aware cap + chunking, reusing review's machinery on the synthetic diff.
cap="${WOO_REVIEW_DIFF_CAP_BYTES:-300000}"
if [ "$(wc -c < "$OUTDIR/diff.txt")" -gt "$cap" ]; then
  echo "::warning::audit diff exceeds ${cap}B; chunking" >&2
fi
bash "$RVW/chunk-diff.sh" >/dev/null 2>&1 || true
