#!/usr/bin/env bash
# retained-plane-runs.sh — validate retained Plane run manifests under
# .woostack/tmp/runs/*/manifest.json and .woostack/runs/*/manifest.json:
# Plane runs require a nonempty top-level canonicalRepository,
# canonical [Repo] <canonicalRepository> project association,
# mirror.status exactly one of unstarted|synced|failed,
# and valid mirror.specItem schema (externalId, canonicalRef, nativeId keys with nonempty externalId).
# When mirror.status is "synced", bound native refs are required;
# null preallocation with mirror.status "unstarted" or "failed" remains valid.
# Incompatible legacy Plane runs produce a report-only finding with regeneration guidance.
# Diagnose-only; no --fix.
set -uo pipefail

emit() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"; }
command -v jq >/dev/null 2>&1 || exit 0
WOO_ROOT="${1:-.}"

[ -d "$WOO_ROOT/.woostack" ] || exit 0

shopt -s nullglob
manifests=("$WOO_ROOT/.woostack/tmp/runs/"*/manifest.json "$WOO_ROOT/.woostack/runs/"*/manifest.json)
shopt -u nullglob

for m in "${manifests[@]}"; do
  [ -f "$m" ] || continue
  rel_path="${m#"$WOO_ROOT/"}"

  if ! jq -e 'type == "object"' "$m" >/dev/null 2>&1; then
    continue
  fi

  provider="$(jq -r '.mirror.provider // empty' "$m" 2>/dev/null)"
  [ "$provider" = "plane" ] || continue

  is_incompatible="$(jq -r '
    def is_valid_canon:
      .canonicalRepository != null and (.canonicalRepository | type == "string") and (.canonicalRepository != "");

    def is_valid_project(canon):
      has("project") and (.project | type == "object")
      and (.project.name == ("[Repo] " + canon));

    def is_valid_status:
      has("status") and (.status == "unstarted" or .status == "synced" or .status == "failed");

    def is_valid_spec:
      has("specItem") and (.specItem | type == "object")
      and (.specItem | has("externalId"))
      and (.specItem | has("canonicalRef"))
      and (.specItem | has("nativeId"))
      and (.specItem.externalId != null and .specItem.externalId != "")
      and (
        if (.status == "synced")
        then (
          .specItem.nativeId != null and .specItem.nativeId != "" and
          .specItem.canonicalRef != null and .specItem.canonicalRef != ""
        )
        elif (.status == "unstarted" or .status == "failed")
        then true
        else false
        end
      );

    if (is_valid_canon | not) then "true"
    else
      .canonicalRepository as $canon
      | .mirror as $m
      | if ($m == null) then "true"
        elif ($m | is_valid_status | not) then "true"
        elif ($m | is_valid_project($canon) | not) then "true"
        elif ($m | is_valid_spec | not) then "true"
        else "false"
        end
    end
  ' "$m" 2>/dev/null || echo "false")"

  if [ "$is_incompatible" = "true" ]; then
    emit error retained-plane-runs report "$rel_path" \
      "incompatible retained Plane run: missing or invalid mirror.specItem; regenerate via /woostack-build <goal> or /woostack-fix <prompt>"
  fi
done
