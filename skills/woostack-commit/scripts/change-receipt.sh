#!/usr/bin/env bash
set -euo pipefail

base_ref="${1:?usage: change-receipt.sh <base-ref>}"
root="$(git rev-parse --show-toplevel)"
cd "$root"

branch="$(git branch --show-current)"
[ -n "$branch" ] || { printf 'change-receipt: detached HEAD\n' >&2; exit 1; }
base_commit="$(git rev-parse --verify "${base_ref}^{commit}")"
head_commit="$(git rev-parse --verify 'HEAD^{commit}')"

hash_diff() {
  git hash-object --stdin
}

base_to_head="$(git diff --binary --no-ext-diff "$base_commit"...HEAD | hash_diff)"
staged="$(git diff --binary --no-ext-diff --cached | hash_diff)"
unstaged="$(git diff --binary --no-ext-diff | hash_diff)"

untracked="$({
  while IFS= read -r -d '' path; do
    path_base64="$(printf '%s' "$path" | base64 | tr -d '\n')"
    object="$(git hash-object --no-filters -- "$path")"
    printf '%s\t%s\n' "$path_base64" "$object"
  done < <(LC_ALL=C git ls-files --others --exclude-standard -z)
} | jq -Rn '[inputs | split("\t") | {pathBase64: .[0], object: .[1]}]')"

jq -cn \
  --arg branch "$branch" \
  --arg baseRef "$base_ref" \
  --arg baseCommit "$base_commit" \
  --arg headCommit "$head_commit" \
  --arg baseToHead "$base_to_head" \
  --arg staged "$staged" \
  --arg unstaged "$unstaged" \
  --argjson untracked "$untracked" \
  '{branch: $branch, baseRef: $baseRef, baseCommit: $baseCommit, headCommit: $headCommit, baseToHead: $baseToHead, staged: $staged, unstaged: $unstaged, untracked: $untracked}'
