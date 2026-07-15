#!/usr/bin/env bash
# Minimal frontmatter + date helpers for status.sh (bundled so the skill is
# self-contained). Mirrors woostack-init/scripts/lib.sh; keep formats in sync
# with ../references/conventions.md.

# field <file> <key> -> first matching frontmatter value (trimmed), empty if absent.
field() {
  sed -n '/^---$/,/^---$/p' "$1" \
    | grep -m1 "^$2:" \
    | sed "s/^$2:[[:space:]]*//; s/[[:space:]]*$//"
}

# note_body <file> -> everything after the closing frontmatter fence.
note_body() {
  awk 'done2{print} /^---$/{c++; if(c==2){done2=1}}' "$1"
}

# _woo_now -> today's ISO date (YYYY-MM-DD). Override with WOOSTACK_NOW for tests.
_woo_now() { printf '%s\n' "${WOOSTACK_NOW:-$(date +%F)}"; }

# _woo_epoch <YYYY-MM-DD> -> Unix epoch seconds at 00:00:00. GNU then BSD date.
_woo_epoch() {
  local d="$1" e
  e="$(date -d "$d 00:00:00" +%s 2>/dev/null)" \
    || e="$(date -j -f '%Y-%m-%d %H:%M:%S' "$d 00:00:00" +%s 2>/dev/null)" \
    || return 1
  printf '%s\n' "$e"
}

# Artifact adapters are shipped by woostack-init and are the only status data
# boundary. Environment overrides keep the board tests offline.
artifact_backend_init() {
  local repo_root="$1" scripts
  scripts="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../woostack-init/scripts/artifacts" && pwd)"
  WOO_BACKEND_RESOLVER="${WOOSTACK_BACKEND_RESOLVER:-$scripts/resolve-backend.sh}"
  WOO_MARKDOWN_ADAPTER="${WOOSTACK_MARKDOWN_ADAPTER:-$scripts/markdown.sh}"
  WOO_LINEAR_ADAPTER="${WOOSTACK_LINEAR_ADAPTER:-$scripts/linear.sh}"
  if [[ ! -e "$repo_root/.woostack/config.json" && -z "${WOOSTACK_BACKEND_RESOLVER:-}" ]]; then
    WOO_BACKEND_CONFIG='{"backend":"markdown","repository":null,"linear":null}'
  else
    WOO_BACKEND_CONFIG="$("$WOO_BACKEND_RESOLVER" "$repo_root")" || return 1
  fi
  WOO_ARTIFACT_BACKEND="$(jq -r '.backend' <<<"$WOO_BACKEND_CONFIG")"
  [[ "$WOO_ARTIFACT_BACKEND" == markdown || "$WOO_ARTIFACT_BACKEND" == linear ]]
}

markdown_feature_model() {
  "$WOO_MARKDOWN_ADAPTER" feature "$1"
}

linear_adapter() {
  "$WOO_LINEAR_ADAPTER" "$@"
}

# Emit every managed project UUID. feature-resolve intentionally reports
# multiple candidates as deterministic diagnostics; status turns that
# fail-closed selection surface into explicit UUID reads.
linear_project_ids() {
  local repository="$1" status_map="$2" eligible="$3" output errors code id candidates
  errors="$(mktemp)"
  if output="$(linear_adapter feature-resolve --repository "$repository" \
    --status-map "$status_map" --eligible-statuses "$eligible" 2>"$errors")"; then
    code=0
  else
    code=$?
  fi
  case "$code" in
    0)
      id="$(jq -er '.id' <<<"$output")" || {
        rm -f "$errors"
        printf 'woostack-status: Linear project discovery returned an invalid candidate\n' >&2
        return 1
      }
      [[ "$id" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$ ]] || {
        rm -f "$errors"
        printf 'woostack-status: Linear project discovery returned an invalid candidate\n' >&2
        return 1
      }
      printf '%s\n' "$id"
      ;;
    3)
      ;;
    4)
      candidates="$(sed -n 's/^candidate id=\([^ ]*\) .*/\1/p' "$errors")"
      [[ -n "$candidates" ]] || {
        rm -f "$errors"
        printf 'woostack-status: Linear project discovery returned no parseable candidates\n' >&2
        return 1
      }
      while IFS= read -r id; do
        [[ "$id" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$ ]] || {
          rm -f "$errors"
          printf 'woostack-status: Linear project discovery returned an invalid candidate\n' >&2
          return 1
        }
        printf '%s\n' "$id"
      done <<<"$candidates"
      ;;
    *)
      cat "$errors" >&2
      rm -f "$errors"
      return "$code"
      ;;
  esac
  rm -f "$errors"
}
