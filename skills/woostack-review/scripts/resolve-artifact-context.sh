#!/usr/bin/env bash
# Resolve exactly attributed PR artifact context through the configured read backend.
# Remote PR and Linear text is normalized as data only; this helper never executes it.
set -euo pipefail
umask 077
# Capture the optional credential in a non-exported shell variable, then remove
# both public env names before spawning any parser, resolver, Markdown reader,
# jq, or utility process. Only the attributed Linear feature-read receives it.
PROVIDED_LINEAR_API_KEY="${INPUT_LINEAR_API_KEY:-${LINEAR_API_KEY:-}}"
unset INPUT_LINEAR_API_KEY LINEAR_API_KEY

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=skills/woostack-review/scripts/resolve-outdir.sh
source "$SCRIPT_DIR/resolve-outdir.sh"
mkdir -p "$OUTDIR"
chmod 700 "$OUTDIR"
CONTEXT="$OUTDIR/artifact-context.json"
rm -f "$CONTEXT"

# No PR means a local diff. Do not resolve a backend or touch any artifact reader.
if [ -z "${PR_NUMBER:-}" ]; then
  exit 0
fi

META="$OUTDIR/meta.json"
if [ ! -f "$META" ]; then
  echo "artifact context: prefetched meta.json is required in PR mode" >&2
  exit 1
fi

if [ "${WOO_REVIEW_TEST_MODE:-}" = "1" ]; then
  if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
    echo "artifact context: test mode is refused inside GitHub Actions" >&2
    exit 1
  fi
  ADAPTER_DIR="${WOO_REVIEW_ARTIFACT_ADAPTER_DIR:-$SCRIPT_DIR/../../woostack-init/scripts/artifacts}"
else
  if [ -n "${WOO_REVIEW_ARTIFACT_ADAPTER_DIR:-}" ]; then
    echo "artifact context: adapter override requires local test mode" >&2
    exit 1
  fi
  ADAPTER_DIR="$SCRIPT_DIR/../../woostack-init/scripts/artifacts"
fi
RESOLVER="$ADAPTER_DIR/resolve-backend.sh"
MARKDOWN="$ADAPTER_DIR/markdown.sh"
LINEAR="$ADAPTER_DIR/linear.sh"
PARSER="$SCRIPT_DIR/parse-artifact-trailers.py"
for required in "$RESOLVER" "$MARKDOWN" "$LINEAR" "$PARSER"; do
  [ -f "$required" ] || { echo "artifact context: required reader dependency is missing" >&2; exit 1; }
done

if [ -n "${GITHUB_WORKSPACE:-}" ]; then
  REPO_ROOT="$(cd "$GITHUB_WORKSPACE" && pwd -P)"
else
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "artifact context: repository root could not be resolved" >&2
    exit 1
  }
  REPO_ROOT="$(cd "$REPO_ROOT" && pwd -P)"
fi

# Credentials are deliberately absent while resolving non-secret backend configuration.
BACKEND_CONFIG="$(env -u LINEAR_API_KEY -u INPUT_LINEAR_API_KEY bash "$RESOLVER" "$REPO_ROOT")" || {
  echo "artifact context: backend resolution failed" >&2
  exit 1
}
BACKEND="$(jq -er '.backend | select(. == "markdown" or . == "linear")' <<<"$BACKEND_CONFIG")" || {
  echo "artifact context: backend resolver returned an invalid receipt" >&2
  exit 1
}
ATTRIBUTION="$(python3 "$PARSER" --backend "$BACKEND" --meta "$META")"
KIND="$(jq -er '.kind' <<<"$ATTRIBUTION")"
if [ "$KIND" = none ]; then
  exit 0
fi

TMP_CONTEXT="$(mktemp "$OUTDIR/.artifact-context.XXXXXX")"
cleanup() {
  rm -f "$TMP_CONTEXT"
}
trap cleanup EXIT HUP INT TERM

case "$KIND" in
  markdown-spec)
    ARTIFACT_PATH="$(jq -er '.path' <<<"$ATTRIBUTION")"
    MODEL="$(
      env -u LINEAR_API_KEY -u INPUT_LINEAR_API_KEY \
        bash "$MARKDOWN" feature "$REPO_ROOT/$ARTIFACT_PATH"
    )" || {
      echo "artifact context: Markdown feature read failed" >&2
      exit 1
    }
    jq -ce --arg path "$ARTIFACT_PATH" '
      select(
        .backend == "markdown" and
        (.feature | type) == "object" and .feature.id == $path and
        (.spec | type) == "object" and .spec.id == $path and
        (.increments | type) == "array"
      )
    ' <<<"$MODEL" >"$TMP_CONTEXT" || {
      echo "artifact context: Markdown reader returned an invalid normalized model" >&2
      exit 1
    }
    ;;

  markdown-fix)
    ARTIFACT_PATH="$(jq -er '.path' <<<"$ATTRIBUTION")"
    FIX_DIR="$REPO_ROOT/.woostack/fixes"
    FIX_PATH="$REPO_ROOT/$ARTIFACT_PATH"
    [ -d "$FIX_DIR" ] && [ ! -L "$REPO_ROOT/.woostack" ] && [ ! -L "$FIX_DIR" ] && \
      [ -f "$FIX_PATH" ] && [ ! -L "$FIX_PATH" ] || {
      echo "artifact context: attributed Markdown fix is missing or unsafe" >&2
      exit 1
    }
    [ "$(cd "$FIX_DIR" && pwd -P)/$(basename "$FIX_PATH")" = "$FIX_PATH" ] || {
      echo "artifact context: attributed Markdown fix escapes its artifact directory" >&2
      exit 1
    }
    REVISION_LINE="$(shasum -a 256 "$FIX_PATH")" || {
      echo "artifact context: Markdown fix revision could not be computed" >&2
      exit 1
    }
    REVISION="${REVISION_LINE%% *}"
    jq -cn --arg id "$ARTIFACT_PATH" --rawfile content "$FIX_PATH" --arg revision "$REVISION" '
      {
        backend: "markdown",
        feature: null,
        spec: {id: $id, url: null, content: $content, revision: $revision},
        plan: null,
        increments: []
      }
    ' >"$TMP_CONTEXT"
    ;;

  linear)
    PROJECT="$(jq -er '.project' <<<"$ATTRIBUTION")"
    ISSUE="$(jq -er '.issue' <<<"$ATTRIBUTION")"
    API_KEY="$PROVIDED_LINEAR_API_KEY"
    if [ -z "$API_KEY" ]; then
      echo "artifact context: LINEAR_API_KEY is required for an attributed Linear PR" >&2
      exit 1
    fi
    REPOSITORY="$(jq -er 'select(.backend == "linear") | .repository | strings | select(length > 0)' <<<"$BACKEND_CONFIG")" || {
      echo "artifact context: Linear repository identity is missing" >&2
      exit 1
    }
    PR_URL="$(jq -er '.url | strings | select(length > 0)' "$META")" || {
      echo "artifact context: canonical pull request URL is missing" >&2
      exit 1
    }
    STATUS_MAP="$(jq -ce '.linear.projectStatuses | objects' <<<"$BACKEND_CONFIG")" || {
      echo "artifact context: Linear project status map is missing" >&2
      exit 1
    }
    ISSUE_STATE_MAP="$(jq -ce '.linear.issueStates | objects' <<<"$BACKEND_CONFIG")" || {
      echo "artifact context: Linear issue state map is missing" >&2
      exit 1
    }
    MODEL="$(
      env -u INPUT_LINEAR_API_KEY LINEAR_API_KEY="$API_KEY" \
        bash "$LINEAR" feature-read \
          --project "$PROJECT" \
          --repository "$REPOSITORY" \
          --status-map "$STATUS_MAP" \
          --issue-state-map "$ISSUE_STATE_MAP"
    )" || {
      echo "artifact context: Linear feature read failed" >&2
      exit 1
    }
    unset API_KEY
    jq -ce --arg project "$PROJECT" --arg issue "$ISSUE" --arg pullRequest "$PR_URL" '
      select(
        .backend == "linear" and
        (.feature | type) == "object" and
        ((.feature.id | strings | ascii_downcase) == $project) and
        (.spec | type) == "object" and
        (.increments | type) == "array"
      ) |
      ([.increments[] | select((.identifier // null) == $issue)]) as $selected |
      if ($selected | length) != 1
      then error("selected issue must belong to the attributed project exactly once")
      elif (($selected[0].pullRequest // null) != $pullRequest)
      then error("selected issue must be attributed to the current pull request")
      else . + {selectedIssue: $selected[0]}
      end
    ' <<<"$MODEL" >"$TMP_CONTEXT" || {
      echo "artifact context: Linear feature and issue attribution did not match the normalized model" >&2
      exit 1
    }
    ;;

  *)
    echo "artifact context: parser returned an unsupported attribution kind" >&2
    exit 1
    ;;
esac

chmod 600 "$TMP_CONTEXT"
mv -f "$TMP_CONTEXT" "$CONTEXT"
chmod 600 "$CONTEXT"
trap - EXIT HUP INT TERM
