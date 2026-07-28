#!/usr/bin/env bash
# Prefetches PR diff, metadata, exact Linear trailer candidates, and review rules.
# Inputs (env): GH_TOKEN, GITHUB_REPOSITORY, INPUT_SKIP_LABELS, INPUT_INCREMENTAL,
#               INPUT_FORCE_TIER, PR_NUMBER, EVENT_NAME, EVENT_ACTION, COMMENT_BODY.
# Outputs: skip=true|false and outdir=<path> to $GITHUB_OUTPUT (outdir also to stdout).
# Side effects: writes /tmp/pr-review/{diff.txt,meta.json,attribution.md,last_sha.txt,
#               prior-findings.json}, plus rules.md when project-rule files are
#               discovered. It never reads authoritative Linear issue context.
#
# Incremental mode (INPUT_INCREMENTAL=auto, default): if a prior woostack-review marker
# `<!-- woostack-review:sha=<oid> -->` is found in any prior review body, diff
# <last_sha>...HEAD via the GitHub compare API instead of the full PR diff. A
# `--full` substring in COMMENT_BODY (issue_comment trigger) overrides to off.
# Test hooks (env, only active when WOO_REVIEW_TEST_MODE=1):
#   WOO_REVIEW_FAKE_PR_REVIEWS_JSON, WOO_REVIEW_FAKE_META_JSON,
#   WOO_REVIEW_FAKE_FULL_DIFF, WOO_REVIEW_FAKE_INCREMENTAL_DIFF,
#   WOO_REVIEW_FAKE_PRIOR_THREADS_JSON, WOO_REVIEW_FAKE_BOT_COMMENTS,
#   WOO_REVIEW_TEST_SNAPSHOT_MAX_FILES, WOO_REVIEW_TEST_SNAPSHOT_MAX_FILE_BYTES,
#   WOO_REVIEW_TEST_SNAPSHOT_MAX_BYTES, WOO_REVIEW_TEST_SNAPSHOT_VALIDATOR.
#   The mode flag is intentionally not
#   exposed in action.yml — a calling workflow cannot opt itself into the
#   fake-data hooks without first setting an undocumented env var.
# WOO_REVIEW_FRESH=1 forces the OUTDIR wipe even when in-flight findings.* are
# present (issue #48 guard). Unset/0 = guard active (skip wipe if findings.* exist).

set -euo pipefail
umask 077

# Atomic state. Prior runs may have left stale findings.<angle>.json,
# raw_findings.json, validator-metrics.json, etc. in $OUTDIR. Without a wipe,
# stale files (e.g. from an earlier meta-review of the skill itself) silently
# re-enter the merge step. Wipe first, recreate empty.
#
# GUARD (issue #48): refuse to wipe an $OUTDIR that already holds in-flight
# findings.* — a stray mid-run re-run (e.g. a sub-agent over-stepping its scope)
# would otherwise destroy meta.json / prior-findings.json and break the posting
# stage. prefetch is a Stage-1-only operation; set WOO_REVIEW_FRESH=1 to force a
# wipe (the only legitimate caller is a genuinely fresh run).
#
# The refusal is context-split (issue #321):
#   - Local (GITHUB_ACTIONS != true): with per-run OUTDIRs a fresh review never
#     lands on a dir that already holds findings.*, so their presence means a
#     contaminated/active tree. HARD-STOP — do not proceed to merge/validation/
#     posting with stale artifacts.
#   - CI (GITHUB_ACTIONS = true): the validate / validate-prosecutor job
#     legitimately downloads findings.<angle>.json / receipt.<angle>.json into
#     $OUTDIR BEFORE re-invoking the action (reusable-review.yml), so prefetch
#     must PRESERVE them and continue — wiping or aborting would destroy the
#     matrix output the validator must read.
# shellcheck source=skills/woostack-review/scripts/resolve-outdir.sh
source "$(dirname "${BASH_SOURCE[0]:-$0}")/resolve-outdir.sh"
# shellcheck source=skills/woostack-review/scripts/resolve-root.sh
source "$(dirname "${BASH_SOURCE[0]:-$0}")/resolve-root.sh"
has_complete_skill_packages() {
  [ -f "$OUTDIR/skill-packages.json" ] || return 1
  [ -d "$OUTDIR/skill-packages" ] ||
    jq -e '.schemaVersion == 1 and (.packages | type == "array" and length == 0)' \
      "$OUTDIR/skill-packages.json" >/dev/null 2>&1
}
if [ "${WOO_REVIEW_FRESH:-}" != "1" ] &&
  [ "${GITHUB_ACTIONS:-}" = "true" ] &&
  [ "${WOO_REVIEW_MODE:-}" = "review" ] &&
  has_complete_skill_packages; then
  echo "::warning::prefetch: preserving detection artifacts for CI review worker" >&2
elif [ "${WOO_REVIEW_FRESH:-}" != "1" ] && compgen -G "$OUTDIR/findings.*" >/dev/null 2>&1; then
  if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
    echo "::warning::prefetch: $OUTDIR holds in-flight findings.* — preserving (CI validate path); not wiping (set WOO_REVIEW_FRESH=1 to force a fresh wipe)" >&2
  else
    echo "::error::prefetch: $OUTDIR already holds in-flight findings.* — refusing to reuse a contaminated review directory; aborting instead of proceeding with stale artifacts. Re-run with a clean per-run OUTDIR, or set WOO_REVIEW_FRESH=1 to force a fresh wipe." >&2
    exit 1
  fi
else
  rm -rf "$OUTDIR"
fi
mkdir -p "$OUTDIR"
chmod 700 "$OUTDIR"

# Announce the resolved OUTDIR so a chat-host orchestrator can capture it and
# export OUTDIR verbatim to every sub-agent (no recompute drift). Emitted before
# any early skip-exit below so the value is always available. stdout always;
# GITHUB_OUTPUT additionally in CI.
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "outdir=$OUTDIR" >> "$GITHUB_OUTPUT"
fi
echo "outdir=$OUTDIR"

PR_NUMBER="${PR_NUMBER:-}"
EVENT_NAME="${EVENT_NAME:-}"
EVENT_ACTION="${EVENT_ACTION:-}"
# GITHUB_REPOSITORY is set by CI but unset on local hosts. Resolve it once here
# (via gh) so the later bare ${GITHUB_REPOSITORY} uses don't trip `set -u` and
# abort a local /woostack-review run with "GITHUB_REPOSITORY: unbound variable".
GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo)}"
export GITHUB_REPOSITORY
# Hardcoded — not exposed as a knob. Fed into a jq test() regex below; allowing
# external override would let a misconfigured caller inject arbitrary regex.
BOT_NAME_PATTERN="claude|openai|gemini|opencode"
SKIP_LABELS="${INPUT_SKIP_LABELS:-}"
INCREMENTAL="${INPUT_INCREMENTAL:-auto}"
# Test-mode gate: WOO_REVIEW_FAKE_* hooks only honored when this flag is set.
# Refused in any GitHub Actions context — a caller workflow could otherwise
# inject env vars via job/step `env:` blocks (those bypass action.yml inputs)
# and feed fabricated review/diff data into the production code path.
TEST_MODE="${WOO_REVIEW_TEST_MODE:-}"
if [ "$TEST_MODE" = "1" ] && [ "${GITHUB_ACTIONS:-}" = "true" ]; then
  echo "::error::WOO_REVIEW_TEST_MODE is refused inside GitHub Actions. Test hooks are local-only." >&2
  exit 1
fi
# Trigger-comment parsing (issue #19 + existing --full override).
normalize_token() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]-/'
}

parse_review_comment() {
  local body token next
  local -a words
  local i j
  local cmd_found=0
  local force_tier_explicit=""

  body="$1"

  HAS_FORCE=0
  HAS_RECHECK=0

  read -r -a words <<<"$(printf '%s' "$body" | tr '\n' ' ')"
  for ((i = 0; i < ${#words[@]}; i++)); do
    token=$(normalize_token "${words[i]}")
    if [ "$token" != "/woostack-review" ]; then
      continue
    fi
    cmd_found=1

    for ((j = i + 1; j < ${#words[@]}; j++)); do
      next=$(normalize_token "${words[j]}")
      case "$next" in
        --full)
          INCREMENTAL="off"
          ;;
        force)
          HAS_FORCE=1
          ;;
        recheck)
          HAS_RECHECK=1
          ;;
        --fast|fast)
          force_tier_explicit="fast"
          ;;
        --deep|deep)
          force_tier_explicit="deep"
          ;;
      esac
    done
  done

  if [ "$cmd_found" = "1" ]; then
    FORCE_TIER_EXPLICIT="$force_tier_explicit"
  fi
}

FORCE_BYPASS=""
INPUT_FORCE_TIER="${INPUT_FORCE_TIER:-}"
FORCE_TIER="$(printf '%s' "$INPUT_FORCE_TIER" | tr '[:upper:]' '[:lower:]')"
FORCE_TIER_EXPLICIT=""

if [ -n "$FORCE_TIER" ] && [ "$FORCE_TIER" != "fast" ] && [ "$FORCE_TIER" != "deep" ]; then
  echo "::error::INPUT_FORCE_TIER must be 'fast' or 'deep' if set (got '$FORCE_TIER')"
  exit 1
fi

if [ "$EVENT_NAME" = "issue_comment" ]; then
  parse_review_comment "${COMMENT_BODY:-}"
  if [ -n "$FORCE_TIER_EXPLICIT" ]; then
    FORCE_TIER="$FORCE_TIER_EXPLICIT"
  fi

  if printf '%s' "${COMMENT_BODY:-}" | grep -qF -- '--full'; then
    INCREMENTAL="off"
    echo "Incremental: forced to 'off' by --full in trigger comment"
  fi
  if printf '%s' "${COMMENT_BODY:-}" | grep -qE '(^|[[:space:]])/woostack-review([[:space:]]|$)'; then
    if [ "$HAS_FORCE" = "1" ]; then
      FORCE_BYPASS=1
      echo "Auto-skip bypass: '/woostack-review force' detected in trigger comment"
    fi
    if [ "$HAS_RECHECK" = "1" ]; then
      INCREMENTAL="auto"
      echo "Incremental: forced to 'auto' by '/woostack-review recheck'"
    elif [ "$HAS_FORCE" = "0" ]; then
      # Bare `/woostack-review` → full review.
      INCREMENTAL="off"
      echo "Incremental: forced to 'off' by bare '/woostack-review' trigger"
    fi
  fi
fi

emit_skip() {
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "force_tier=${FORCE_TIER:-}" >> "$GITHUB_OUTPUT"
  fi
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "skip=true" >> "$GITHUB_OUTPUT"
  fi
  echo "skip=true"
  echo "Skipping: $1"
  exit 0
}

# Auto-skip (issue #19): emit a single explanatory comment then exit. Idempotent
# via the `<!-- woostack-review:skipped -->` marker — repeat triggers (synchronize on
# a dependabot PR, etc.) re-skip silently. Marker scan also picks up prior skip
# comments authored by the action across re-runs, so the comment is posted at
# most once per PR until a human types `/woostack-review force`.
emit_skip_with_comment() {
  local reason="$1"
  local body="woostack-review skipped: ${reason}

<!-- woostack-review:skipped -->"
  local existing
  # Read side accepts the legacy `woo-stack-review:skipped` marker too (woo-?stack),
  # so PRs skipped before the woostack rename aren't double-commented. Writes use the new brand.
  existing=$(gh pr view "$PR_NUMBER" --json comments \
    --jq '[.comments[]? | select((.body // "") | test("<!-- woo-?stack-review:skipped -->"))] | length' \
    2>/dev/null || echo 0)
  if [ "${existing:-0}" = "0" ]; then
    if gh pr comment "$PR_NUMBER" --body "$body" >/dev/null 2>&1; then
      echo "Posted skip comment: ${reason}"
    else
      echo "::warning::failed to post skip comment (gh pr comment exit nonzero); continuing to skip"
    fi
  else
    echo "Skip comment marker already present; not reposting"
  fi
  emit_skip "$reason"
}

# Host-portability: when invoked outside GitHub Actions and no PR number was
# supplied, try to derive one from the current branch. Subshell is internal to
# this script (script-local subshells are not blocked by host sandboxes the way
# caller-side `PR_NUMBER="$(gh pr view ...)"` is — that pattern is what forced
# manual PR# resolution under a sandboxed host's tool gating).
if [ -z "$PR_NUMBER" ] && [ "${GITHUB_ACTIONS:-}" != "true" ]; then
  PR_NUMBER=$(gh pr view --json number --jq .number 2>/dev/null || true)
  if [ -n "$PR_NUMBER" ]; then
    echo "Resolved PR_NUMBER=$PR_NUMBER from current branch"
  fi
fi

if [ -z "$PR_NUMBER" ]; then
  emit_skip "no PR number resolvable from event"
fi

# Skip if any user-configured skip label is present.
if [ -n "$SKIP_LABELS" ]; then
  CURRENT_LABELS=$(gh pr view "$PR_NUMBER" --json labels --jq '.labels[].name' || true)
  IFS=',' read -ra LBL_ARRAY <<< "$SKIP_LABELS"
  for lbl in "${LBL_ARRAY[@]}"; do
    lbl_trim=$(echo "$lbl" | xargs)
    if echo "$CURRENT_LABELS" | grep -qxF "$lbl_trim"; then
      emit_skip "skip label '$lbl_trim' is present"
    fi
  done
fi

# Marker lookup: pull the latest woostack-review SHA watermark from prior review bodies.
# Empty result means no prior marker → full diff path (first run, or marker absent).
# Hand-edited / malformed markers also yield empty → silent fallback to full diff.
LAST_SHA=""
if [ "$TEST_MODE" = "1" ] && [ -n "${WOO_REVIEW_FAKE_PR_REVIEWS_JSON:-}" ]; then
  REVIEWS_JSON="$WOO_REVIEW_FAKE_PR_REVIEWS_JSON"
else
  REVIEWS_JSON=$(gh pr view "$PR_NUMBER" --json reviews 2>/dev/null || echo '{"reviews":[]}')
fi
# Marker trust: honor a marker authored by a woostack-review bot, OR — on a local
# (not-in-CI) run only — one authored by the gh user running this review. Without
# the bot gate any PR collaborator could submit a fake review with a forged marker
# pointing past their own malicious commits, narrowing the next incremental window
# to exclude them. The bot login pattern is anchored to the start of the string so
# logins like `myclaudebot` are rejected; a residual risk remains for logins that
# START with a bot prefix (e.g. `claude-evil`), which would require an attacker to
# register such a login AND obtain PR-collaborator access — defense-in-depth, not a
# hard guarantee. The local self-trust clause is gated on NOT running in CI so the
# same forge threat does not apply: locally the user reviews as themselves with
# their own token (a local re-review can then trust the marker it wrote last run);
# a different local reviewer or any CI third-party still falls back to a full pass.
# resolve-marker.sh owns the trust filter (single authority) and the legacy
# `woo-stack-review:sha=` read alias (woo-?stack), so a PR last reviewed before the
# woostack rename still resolves incrementally. Writes use the new brand.
LOCAL_RUN=0
AUTH_LOGIN=""
if [ "${GITHUB_ACTIONS:-}" != "true" ]; then
  LOCAL_RUN=1
  # Authenticated gh login of whoever is running this local review (lowercased);
  # empty on auth failure → self-trust disabled → safe fall back to full diff.
  AUTH_LOGIN=$(gh api user --jq '.login' 2>/dev/null | tr '[:upper:]' '[:lower:]' || true)
fi
LAST_SHA=$(printf '%s' "$REVIEWS_JSON" \
  | bash "$(dirname "${BASH_SOURCE[0]:-$0}")/resolve-marker.sh" "$BOT_NAME_PATTERN" "$AUTH_LOGIN" "$LOCAL_RUN")

# Re-run guard: if a prior AI bot has already commented and the current trigger is
# not an explicit user request, skip. Skipped when a marker is present — the marker
# means we've reviewed this PR before, so any new trigger (including synchronize)
# is the intended re-run signal for incremental mode. Pattern is anchored to
# match the marker filter — keeps "bot" classification consistent across both
# trust gates.
if [ "$TEST_MODE" = "1" ] && [ -n "${WOO_REVIEW_FAKE_BOT_COMMENTS:-}" ]; then
  ISSUE_COMMENTS="$WOO_REVIEW_FAKE_BOT_COMMENTS"
  REVIEW_COMMENTS=0
else
  ISSUE_COMMENTS=$(gh pr view "$PR_NUMBER" --json comments \
    --jq "[.comments[] | select(.author.login | test(\"^($BOT_NAME_PATTERN)\"; \"i\"))] | length")
  REVIEW_COMMENTS=$(gh api "repos/${GITHUB_REPOSITORY}/pulls/$PR_NUMBER/comments" \
    --jq "[.[] | select(.user.login | test(\"^($BOT_NAME_PATTERN)\"; \"i\"))] | length")
fi
TOTAL_BOT_COMMENTS=$((ISSUE_COMMENTS + REVIEW_COMMENTS))

echo "Event: $EVENT_NAME, Action: $EVENT_ACTION, Prior bot comments: $TOTAL_BOT_COMMENTS, Marker: ${LAST_SHA:-none}, Incremental: $INCREMENTAL"

# Re-run guard scope: this check only applies inside GitHub Actions, where the
# review is auto-triggered by GitHub events and "explicit" is a meaningful
# concept. When invoked from a local host (Claude Code, Antigravity CLI, opencode
# /woostack-review skill), the user typed the command — by definition explicit —
# so EVENT_NAME is empty and the gate would otherwise misclassify the run as
# implicit and skip it whenever any prior bot comment exists on the PR.
if [ "${GITHUB_ACTIONS:-}" = "true" ] && \
   [ "$TOTAL_BOT_COMMENTS" -gt 0 ] && [ -z "$LAST_SHA" ] && \
   [ "$EVENT_NAME" != "issue_comment" ] && \
   [ "$EVENT_NAME" != "pull_request_target" ] && \
   [ "$EVENT_NAME" != "workflow_dispatch" ] && \
   [ "$EVENT_ACTION" != "ready_for_review" ] && \
   [ "$EVENT_ACTION" != "opened" ] && \
   [ "$EVENT_ACTION" != "reopened" ]; then
  emit_skip "bot already commented and trigger is not explicit"
fi

# Fetch metadata first — HEAD_SHA is needed for the compare-API incremental path.
if [ "$TEST_MODE" = "1" ] && [ -n "${WOO_REVIEW_FAKE_META_JSON:-}" ]; then
  printf '%s' "$WOO_REVIEW_FAKE_META_JSON" > "$OUTDIR/meta.json"
else
  gh pr view "$PR_NUMBER" --json headRefOid,headRefName,baseRefName,title,body,files,author > "$OUTDIR/meta.json"
fi
HEAD_SHA=$(jq -r '.headRefOid' "$OUTDIR/meta.json")

# Load per-repo config early (issue #19) so the bot-author / release-rollup
# skip checks can read user overrides BEFORE we pay for the diff fetch.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# Prefetch never reads local specs/plans/fixes or Linear. It records only an exact,
# untrusted trailer candidate so a local host can verify it through official MCP.
# GitHub Actions keeps this explicitly diff-only and advisory; no intent.md means
# detect-angles.sh cannot run the contract-aware acceptance angle in CI.
rm -f "$OUTDIR/intent.md"
ATTRIBUTION_DELIVERY="local-mcp-verification-required"
if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
  ATTRIBUTION_DELIVERY="ci-diff-only-advisory"
fi
python3 - "$OUTDIR/meta.json" "$OUTDIR/attribution.md" "$ATTRIBUTION_DELIVERY" <<'PY'
import json
import re
import sys

meta_path, output_path, delivery = sys.argv[1:]
try:
    with open(meta_path, encoding="utf-8") as source:
        meta = json.load(source)
except (OSError, ValueError):
    meta = {}

body = meta.get("body") if isinstance(meta, dict) else ""
if not isinstance(body, str):
    body = ""
lines = body.split("\n")
lines = [line[:-1] if line.endswith("\r") else line for line in lines]
while lines and not lines[-1].strip():
    lines.pop()

uuid = r"[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}"
issue = r"[A-Z][A-Z0-9]*-[1-9][0-9]*"
project_pattern = re.compile(rf"Linear-Project: ({uuid})")
issue_pattern = re.compile(rf"Linear-Issue: ({issue})")
candidate_pattern = re.compile(
    r"(?<![A-Za-z0-9_])(?i:Linear-Project|Linear-Issue|Spec)[ \t]*:"
)
candidates = [line for line in lines if candidate_pattern.search(line)]

syntax = "absent"
trailers = []
if (
    len(candidates) == 2
    and candidates == lines[-2:]
    and project_pattern.fullmatch(candidates[0])
    and issue_pattern.fullmatch(candidates[1])
):
    syntax = "exact-project-issue"
    trailers = candidates
elif (
    len(candidates) == 1
    and candidates == lines[-1:]
    and issue_pattern.fullmatch(candidates[0])
):
    syntax = "exact-issue"
    trailers = candidates
elif candidates:
    syntax = "invalid"

with open(output_path, "w", encoding="utf-8") as output:
    output.write("# PR Linear attribution candidate\n\n")
    output.write("authoritative-issue-context: absent\n")
    output.write(f"delivery-boundary: {delivery}\n")
    output.write(f"trailer-syntax: {syntax}\n")
    if trailers:
        output.write("\nexact-trailers:\n")
        for trailer in trailers:
            output.write(f"{trailer}\n")

print(f"Prefetch attribution: {syntax}; authoritative issue context absent")
PY
bash "$SCRIPT_DIR/load-config.sh"

# Force-tier precedence:
# 1) explicit command/runner override
# 2) workflow input (`inputs.force_tier` via INPUT_FORCE_TIER)
# 3) review.force_tier in .woostack/config.json
# 4) unset/blank => standard-tier fallback (resolved later by load-prompt)
if [ -z "$FORCE_TIER" ] && [ -f "$OUTDIR/config.json" ]; then
  CONFIG_TIER="$(jq -r '.force_tier // empty' "$OUTDIR/config.json" 2>/dev/null || true)"
  if [ "$CONFIG_TIER" = "fast" ] || [ "$CONFIG_TIER" = "deep" ]; then
    FORCE_TIER="$CONFIG_TIER"
  fi
fi
if [ -n "$FORCE_TIER" ]; then
  echo "Resolved force_tier=$FORCE_TIER"
else
  echo "Resolved force_tier=unset (default standard run)"
fi

# Issue #19: auto-skip mechanical bot PRs (renovate / dependabot / etc.) and
# release-rollup PRs. Effective lists fall back to defaults when the user did
# not supply them. An explicit empty list (`authors_skip: []`) opts out.
# `/woostack-review force` in a trigger comment bypasses both checks.
if [ "${FORCE_BYPASS:-}" != "1" ]; then
  AUTHOR_LOGIN=$(jq -r '.author.login // empty' "$OUTDIR/meta.json")
  PR_TITLE=$(jq -r '.title // ""' "$OUTDIR/meta.json")

  # authors_skip — config wins; defaults apply when key absent (`// null`
  # distinguishes "absent" from "explicit []").
  SKIP_MATCH=$(jq -r --arg login "$AUTHOR_LOGIN" '
    (if has("authors_skip") then .authors_skip
     else ["dependabot[bot]","renovate[bot]","github-actions[bot]"] end)
    | if index($login) then "yes" else "no" end
  ' "$OUTDIR/config.json" 2>/dev/null || echo "no")
  if [ -n "$AUTHOR_LOGIN" ] && [ "$SKIP_MATCH" = "yes" ]; then
    emit_skip_with_comment "author '$AUTHOR_LOGIN' matches authors_skip (override with \`/woostack-review force\`)"
  fi

  # release_rollup_pattern — same precedence. Empty string opts out.
  ROLLUP_PATTERN=$(jq -r '
    if has("release_rollup_pattern") then .release_rollup_pattern
    else "^(staging|release|chore\\(release\\))" end
  ' "$OUTDIR/config.json" 2>/dev/null || echo '^(staging|release|chore\(release\))')
  if [ -n "$ROLLUP_PATTERN" ] && [ -n "$PR_TITLE" ]; then
    # Python regex (matches the engine used to validate the pattern in
    # load-config.sh, so a pattern that validated will execute identically).
    if python3 -c '
import re, sys
pattern, title = sys.argv[1], sys.argv[2]
sys.exit(0 if re.search(pattern, title) else 1)
' "$ROLLUP_PATTERN" "$PR_TITLE" 2>/dev/null; then
      emit_skip_with_comment "PR title matches release_rollup_pattern (override with \`/woostack-review force\`)"
    fi
  fi
fi

# No-new-commits short-circuit: marker present and HEAD already matches it
# (e.g. user re-triggered without pushing). SKILL.md documents this skip.
if [ "$INCREMENTAL" = "auto" ] && [ -n "$LAST_SHA" ] && [ "$LAST_SHA" = "$HEAD_SHA" ]; then
  emit_skip "no new commits since last review ($LAST_SHA)"
fi

# Fetch diff. Three paths:
#   1. INCREMENTAL=auto + valid LAST_SHA + LAST_SHA != HEAD_SHA → compare API.
#   2. Compare-API 404 (force-push dropped LAST_SHA) → warn + full diff fallback.
#   3. Otherwise → full PR diff (today's behaviour).
INCREMENTAL_USED=""
if [ "$INCREMENTAL" = "auto" ] && [ -n "$LAST_SHA" ] && [ "$LAST_SHA" != "$HEAD_SHA" ]; then
  if [ "$TEST_MODE" = "1" ] && [ -n "${WOO_REVIEW_FAKE_INCREMENTAL_DIFF:-}" ]; then
    printf '%s' "$WOO_REVIEW_FAKE_INCREMENTAL_DIFF" > "$OUTDIR/diff.txt"
    INCREMENTAL_USED="$LAST_SHA"
    echo "Incremental diff: $LAST_SHA...$HEAD_SHA (test hook)"
  elif COMPARE_JSON=$(gh api "repos/${GITHUB_REPOSITORY}/compare/${LAST_SHA}...${HEAD_SHA}" 2>/dev/null); then
    # NOTE: cannot pipe $COMPARE_JSON to `python3 -` — `python3 -` reads its
    # script from stdin via the heredoc, so a pipe + heredoc would contend
    # for fd 0 (heredoc wins, JSON is lost). Stage JSON in a workflow-scoped
    # scratch file under $OUTDIR (not mktemp) so a Python crash under
    # `set -e` cannot leak a tempfile — $OUTDIR is already the run's
    # scratch directory.
    COMPARE_TMP="$OUTDIR/.compare.json"
    printf '%s' "$COMPARE_JSON" > "$COMPARE_TMP"
    python3 - "$OUTDIR/diff.txt" "$COMPARE_TMP" <<'PY'
import json, sys
out_path, in_path = sys.argv[1], sys.argv[2]
with open(in_path) as fh:
    data = json.load(fh)
with open(out_path, "w") as fh:
    for f in data.get("files", []):
        path = f.get("filename", "")
        if not path:
            continue
        fh.write(f"diff --git a/{path} b/{path}\n")
        patch = f.get("patch")
        if patch:
            fh.write(patch)
            if not patch.endswith("\n"):
                fh.write("\n")
PY
    rm -f "$COMPARE_TMP"
    INCREMENTAL_USED="$LAST_SHA"
    echo "Incremental diff: $LAST_SHA...$HEAD_SHA via compare API"
  else
    echo "::warning::last review SHA $LAST_SHA unreachable (force-push?); falling back to full diff"
  fi
fi

if [ -z "$INCREMENTAL_USED" ]; then
  if [ "$TEST_MODE" = "1" ] && [ -n "${WOO_REVIEW_FAKE_FULL_DIFF:-}" ]; then
    printf '%s' "$WOO_REVIEW_FAKE_FULL_DIFF" > "$OUTDIR/diff.txt"
  else
    gh pr diff "$PR_NUMBER" > "$OUTDIR/diff.txt"
  fi
fi
printf '%s' "$INCREMENTAL_USED" > "$OUTDIR/last_sha.txt"

# PR-scope intersection (issue #374): a rebased branch makes the incremental
# marker a non-ancestor of HEAD, so the three-dot compare returns HTTP 200 with
# the commits the branch was rebased OVER — files that are not in this PR. The
# 404-only fallback above never catches that (reachable != ancestor). Restrict the
# incremental diff to the authoritative PR file set (meta.json .files[].path) so
# off-PR sections never reach the angle workers or the posting stage, which 422s
# on paths outside the PR diff. Runs before the byte/cap/ignore stages so they all
# see PR-scoped input. The full-diff path is already PR-scoped (gh pr diff), so
# this is gated on an incremental diff actually being used. Missing/unparseable
# meta, or a meta with no file list, is a no-op (never narrower than today).
if [ -n "$INCREMENTAL_USED" ] && [ -f "$OUTDIR/meta.json" ]; then
  python3 - "$OUTDIR/diff.txt" "$OUTDIR/meta.json" <<'PY'
import json, re, sys

diff_path, meta_path = sys.argv[1], sys.argv[2]
try:
    meta = json.load(open(meta_path, encoding="utf-8"))
    pr_paths = {f.get("path", "") for f in meta.get("files", []) if f.get("path")}
except (OSError, ValueError):
    pr_paths = set()
# Empty/absent PR file set -> cannot determine scope -> keep everything (safe
# degradation; never drop the whole diff on a meta we could not read).
if not pr_paths:
    sys.exit(0)

lines = open(diff_path, encoding="utf-8", errors="replace").read().splitlines(keepends=True)
# Same section split as the diff-cap ranker: one block per `diff --git` header,
# keyed on the b/ (new) path so renames intersect on their PR-reported name.
HEADER = re.compile(r'^diff --git a/(.+?) b/(.+?)\s*$')
preamble, sections, cur = [], [], None
for ln in lines:
    m = HEADER.match(ln)
    if m:
        if cur is not None:
            sections.append(cur)
        cur = {"path": m.group(2), "lines": [ln]}
    elif cur is None:
        preamble.append(ln)
    else:
        cur["lines"].append(ln)
if cur is not None:
    sections.append(cur)

dropped = [s["path"] for s in sections if s["path"] not in pr_paths]
if not dropped:
    sys.exit(0)

out = list(preamble)
for sec in sections:
    if sec["path"] in pr_paths:
        out.extend(sec["lines"])
open(diff_path, "w", encoding="utf-8").write("".join(out))
print("prefetch: dropped %d off-PR diff section(s) not in PR file set (rebased marker?): %s"
      % (len(dropped), ", ".join(sorted(dropped)[:15]) + (" ..." if len(dropped) > 15 else "")))
PY
fi

# A skills review needs the touched skill's whole tracked package, but workers
# must not read the host checkout: downstream CI review/validate jobs may not
# even have the same tree. Detection/local prefetch therefore validates and
# snapshots each owning package before any size/angle skip decisions. A CI stage
# that downloaded detection artifacts preserves them instead of regenerating
# them: review mode carries the validated package snapshot, while validate modes
# also carry in-flight findings.*.
if [ "${GITHUB_ACTIONS:-}" = "true" ] &&
  has_complete_skill_packages &&
  { [ "${WOO_REVIEW_MODE:-}" = "review" ] ||
    compgen -G "$OUTDIR/findings.*" >/dev/null 2>&1; }; then
  echo "::warning::prefetch: preserving detection skill package artifacts for downstream CI worker" >&2
else
  SNAPSHOT_REPOSITORY="$(git -C "${GITHUB_WORKSPACE:-.}" rev-parse --show-toplevel 2>/dev/null || true)"
  SNAPSHOT_VALIDATOR="$SCRIPT_DIR/../../woostack-eval/scripts/validate.mjs"
  if [ "${WOO_REVIEW_TEST_MODE:-}" = "1" ] &&
    [ -n "${WOO_REVIEW_TEST_SNAPSHOT_VALIDATOR:-}" ]; then
    SNAPSHOT_VALIDATOR="$WOO_REVIEW_TEST_SNAPSHOT_VALIDATOR"
  fi
  if ! node - "$OUTDIR" "$SNAPSHOT_REPOSITORY" "$SNAPSHOT_VALIDATOR" <<'NODE'
const crypto = require('node:crypto');
const childProcess = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const [outdir, repositoryArgument, validator] = process.argv.slice(2);
const manifestPath = path.join(outdir, 'skill-packages.json');
const snapshotsPath = path.join(outdir, 'skill-packages');
const compare = (left, right) => left < right ? -1 : left > right ? 1 : 0;
const digest = (bytes) =>
  `sha256:${crypto.createHash('sha256').update(bytes).digest('hex')}`;
const safePath = (value) =>
  typeof value === 'string' &&
  value.length > 0 &&
  !path.posix.isAbsolute(value) &&
  !value.includes('\\') &&
  !/[\0-\x1f\x7f]/.test(value) &&
  value.split('/').every((part) => part && part !== '.' && part !== '..');

function testLimit(name, fallback) {
  if (process.env.WOO_REVIEW_TEST_MODE !== '1' || !process.env[name]) return fallback;
  const value = Number(process.env[name]);
  if (!Number.isSafeInteger(value) || value < 1) fail(`invalid ${name} test limit`);
  return value;
}

const MAX_SNAPSHOT_FILES =
  testLimit('WOO_REVIEW_TEST_SNAPSHOT_MAX_FILES', 2000);
const MAX_SNAPSHOT_FILE_BYTES =
  testLimit('WOO_REVIEW_TEST_SNAPSHOT_MAX_FILE_BYTES', 5 * 1024 * 1024);
const MAX_SNAPSHOT_BYTES =
  testLimit('WOO_REVIEW_TEST_SNAPSHOT_MAX_BYTES', 50 * 1024 * 1024);

let stagingPath;
let manifestTemporary;
let publishedSnapshots = false;
let publishedManifest = false;

function fail(message) {
  throw new Error(message);
}

function validationErrorDiagnostic(error) {
  if (!error || typeof error !== 'object') return 'code=unknown';
  return ['code', 'path', 'field', 'message']
    .filter((key) => error[key] !== undefined && error[key] !== '')
    .map((key) => {
      const value = String(error[key]).replace(/[\0-\x1f\x7f]/g, ' ').slice(0, 256);
      return `${key}=${value}`;
    })
    .join(' ');
}
function processDiagnostic(result) {
  const clean = (value, fallback) => {
    const text = value === undefined || value === null || value === ''
      ? fallback
      : String(value);
    return text.replace(/[\0-\x1f\x7f]/g, ' ').slice(0, 512);
  };
  return [
    `status=${clean(result && result.status, 'null')}`,
    `signal=${clean(result && result.signal, 'none')}`,
    `error=${clean(result && result.error && result.error.message, 'none')}`,
    `stderr=${clean(result && result.stderr, 'empty')}`,
  ].join(' ');
}

function requireImmutablePackage(repository, packagePath) {
  const pathspec = packagePath === '.' ? '.' : `:(literal)${packagePath}`;
  const result = childProcess.spawnSync(
    'git',
    ['-C', repository, 'diff', '--quiet', 'HEAD', '--', pathspec],
    { encoding: 'utf8', maxBuffer: 1024 * 1024 },
  );
  if (result.status === 1 && !result.signal && !result.error) {
    fail(`tracked package differs from the immutable PR head: ${packagePath}`);
  }
  if (result.status !== 0 || result.signal || result.error) {
    fail(`could not verify immutable package bytes for ${packagePath}: ${processDiagnostic(result)}`);
  }
}

function trackedFiles(repository, packagePath) {
  const output = childProcess.execFileSync(
    'git',
    ['-C', repository, 'ls-tree', '-r', '-l', '-z', '--full-tree', 'HEAD', '--', packagePath],
    { encoding: 'buffer', maxBuffer: 16 * 1024 * 1024 },
  );
  const files = [];
  const seen = new Set();
  for (const record of output.toString('utf8').split('\0')) {
    if (!record) continue;
    const match = /^([0-9]{6}) (blob|commit) ([0-9a-f]{40}(?:[0-9a-f]{24})?) +(-|[0-9]+)\t([\s\S]+)$/.exec(record);
    if (!match) fail('Git returned an unsafe tracked package record');
    const [, mode, type, oid, size, repositoryPath] = match;
    const relative = packagePath === '.'
      ? repositoryPath
      : repositoryPath.startsWith(`${packagePath}/`)
        ? repositoryPath.slice(packagePath.length + 1)
        : '';
    if (!safePath(repositoryPath) || !safePath(relative) || seen.has(relative)) {
      fail('Git returned an out-of-package or duplicate tracked path');
    }
    if (
      type !== 'blob' ||
      (mode !== '100644' && mode !== '100755') ||
      !/^[0-9]+$/.test(size)
    ) {
      fail(`tracked package entry is not a regular file: ${relative}`);
    }
    const bytes = Number(size);
    if (!Number.isSafeInteger(bytes)) fail(`tracked package file has an invalid size: ${relative}`);
    seen.add(relative);
    files.push({ mode, path: relative, oid, bytes });
  }
  files.sort((left, right) => compare(left.path, right.path));
  if (!seen.has('SKILL.md')) fail('owning SKILL.md is not Git-visible');
  return files;
}

function immutableBlobs(repository, tracked) {
  if (tracked.length === 0) return [];
  const output = childProcess.execFileSync(
    'git',
    ['-C', repository, 'cat-file', '--batch'],
    {
      input: `${tracked.map((file) => file.oid).join('\n')}\n`,
      encoding: null,
      maxBuffer: tracked.reduce((total, file) => total + file.bytes + 256, 1),
    },
  );
  let offset = 0;
  const blobs = tracked.map((file) => {
    const headerEnd = output.indexOf(0x0a, offset);
    if (headerEnd < 0) fail(`Git returned a truncated blob header: ${file.path}`);
    const [oid, type, size] = output.subarray(offset, headerEnd).toString('utf8').split(' ');
    const bodyStart = headerEnd + 1;
    const bodyEnd = bodyStart + file.bytes;
    if (
      oid !== file.oid ||
      type !== 'blob' ||
      Number(size) !== file.bytes ||
      bodyEnd >= output.length ||
      output[bodyEnd] !== 0x0a
    ) {
      fail(`Git returned invalid immutable blob bytes: ${file.path}`);
    }
    offset = bodyEnd + 1;
    return output.subarray(bodyStart, bodyEnd);
  });
  if (offset !== output.length) fail('Git returned trailing immutable blob data');
  return blobs;
}


function hasRightSideSkill(repository, skillPath) {
  const result = childProcess.spawnSync(
    'git',
    ['-C', repository, 'cat-file', '-e', `HEAD:${skillPath}`],
    { encoding: 'utf8', maxBuffer: 1024 * 1024 },
  );
  if (result.status === 0 && !result.signal && !result.error) return true;
  if (result.status === 128 && !result.signal && !result.error) return false;
  fail(`could not resolve right-side SKILL.md: ${processDiagnostic(result)}`);
}

try {
  if (!repositoryArgument) fail('repository root is unavailable');
  if (!fs.existsSync(validator)) fail('shared skill package validator is unavailable');
  if (fs.existsSync(manifestPath) || fs.existsSync(snapshotsPath)) {
    fail('skill package artifact destination already exists');
  }

  const repository = fs.realpathSync(repositoryArgument);
  const metadata = JSON.parse(fs.readFileSync(path.join(outdir, 'meta.json'), 'utf8'));
  const checkoutHead = childProcess.execFileSync(
    'git',
    ['-C', repository, 'rev-parse', 'HEAD'],
    { encoding: 'utf8', maxBuffer: 1024 },
  ).trim();
  if (
    typeof metadata.headRefOid !== 'string' ||
    !/^[0-9a-f]{40}(?:[0-9a-f]{24})?$/.test(metadata.headRefOid) ||
    checkoutHead !== metadata.headRefOid
  ) {
    fail('repository checkout does not match the immutable PR head');
  }
  const touchedSkillPaths = [...new Set(
    (Array.isArray(metadata.files) ? metadata.files : [])
      .map((file) => file && file.path)
      .filter((file) => file === 'SKILL.md' ||
        (typeof file === 'string' && file.endsWith('/SKILL.md'))),
  )].sort(compare);
  for (const skillPath of touchedSkillPaths) {
    if (skillPath !== 'SKILL.md' && !safePath(skillPath)) {
      fail('metadata contains an unsafe SKILL.md path');
    }
  }
  const skillPaths = touchedSkillPaths.filter((skillPath) =>
    hasRightSideSkill(repository, skillPath));

  let snapshotFileCount = 0;
  let snapshotBytes = 0;
  const packages = skillPaths.map((skillPath) => {
    const packagePath = path.posix.dirname(skillPath);
    const packageRoot = packagePath === '.'
      ? repository
      : path.join(repository, ...packagePath.split('/'));
    const packageState = fs.lstatSync(packageRoot);
    if (packageState.isSymbolicLink() || !packageState.isDirectory()) {
      fail(`owning skill package is not a regular directory: ${packagePath}`);
    }
    requireImmutablePackage(repository, packagePath);
    const tracked = trackedFiles(repository, packagePath);
    snapshotFileCount += tracked.length;
    if (snapshotFileCount > MAX_SNAPSHOT_FILES) {
      fail(`skill package snapshot exceeds ${MAX_SNAPSHOT_FILES} tracked files`);
    }
    for (const file of tracked) {
      if (file.bytes > MAX_SNAPSHOT_FILE_BYTES) {
        fail(`tracked package file exceeds ${MAX_SNAPSHOT_FILE_BYTES} bytes: ${file.path}`);
      }
      snapshotBytes += file.bytes;
      if (snapshotBytes > MAX_SNAPSHOT_BYTES) {
        fail(`skill package snapshot exceeds ${MAX_SNAPSHOT_BYTES} bytes`);
      }
    }
    const immutable = immutableBlobs(repository, tracked);

    const validation = childProcess.spawnSync(
      process.execPath,
      [
        validator,
        '--package', packageRoot,
        '--repository-root', repository,
        '--tracked-only',
        '--json',
      ],
      { encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 },
    );
    let result;
    try {
      result = JSON.parse(validation.stdout || '');
    } catch {
      fail(`shared validator returned unreadable output for ${packagePath}: ${processDiagnostic(validation)}`);
    }
    if (validation.status !== 0 || !result.valid) {
      const errors = Array.isArray(result.errors)
        ? result.errors.slice(0, 10).map(validationErrorDiagnostic)
        : [];
      const omitted = Array.isArray(result.errors) && result.errors.length > errors.length
        ? `; ${result.errors.length - errors.length} more error(s)`
        : '';
      fail(`shared validator rejected ${packagePath}${errors.length ? `: ${errors.join('; ')}${omitted}` : ''}`);
    }
    const validated = Array.isArray(result.files) ? result.files : [];
    if (
      validated.length !== tracked.length ||
      validated.some((file, index) => file.path !== tracked[index].path)
    ) {
      fail(`shared validator inventory differs from Git for ${packagePath}`);
    }
    return { skillPath, packagePath, tracked, validated, immutable };
  });

  stagingPath = fs.mkdtempSync(path.join(outdir, '.skill-packages.tmp-'));
  fs.chmodSync(stagingPath, 0o700);
  const entries = [];
  for (const skillPackage of packages) {
    const encoded = skillPackage.packagePath === '.'
      ? '%2E'
      : skillPackage.packagePath.split('/').map(encodeURIComponent).join('%2F');
    const destinationRoot = path.join(stagingPath, encoded);
    fs.mkdirSync(destinationRoot, { recursive: true, mode: 0o700 });
    const files = [];
    for (let index = 0; index < skillPackage.tracked.length; index += 1) {
      const tracked = skillPackage.tracked[index];
      const validated = skillPackage.validated[index];
      const bytes = skillPackage.immutable[index];
      const sha256 = digest(bytes);
      if (
        validated.bytes !== bytes.length ||
        validated.sha256 !== sha256 ||
        typeof validated.type !== 'string'
      ) {
        fail(`tracked package changed after validation: ${skillPackage.packagePath}/${tracked.path}`);
      }
      const destination = path.join(destinationRoot, ...tracked.path.split('/'));
      fs.mkdirSync(path.dirname(destination), { recursive: true, mode: 0o700 });
      const descriptor = fs.openSync(destination, 'wx', tracked.mode === '100755' ? 0o755 : 0o644);
      try {
        fs.writeFileSync(descriptor, bytes);
      } finally {
        fs.closeSync(descriptor);
      }
      files.push({
        path: tracked.path,
        type: validated.type,
        bytes: bytes.length,
        sha256,
      });
    }
    const packageHash = digest(Buffer.from(
      files.map((file) => `${file.path}\0${file.sha256}\n`).join(''),
      'utf8',
    ));
    entries.push({
      skillPath: skillPackage.skillPath,
      packagePath: skillPackage.packagePath,
      snapshotPath: `skill-packages/${encoded}`,
      packageHash,
      files,
    });
  }

  const manifest = `${JSON.stringify({ schemaVersion: 1, packages: entries }, null, 2)}\n`;
  manifestTemporary = path.join(
    outdir,
    `.skill-packages.json.tmp-${process.pid}-${crypto.randomBytes(8).toString('hex')}`,
  );
  fs.writeFileSync(manifestTemporary, manifest, { flag: 'wx', mode: 0o600 });
  fs.renameSync(stagingPath, snapshotsPath);
  stagingPath = undefined;
  publishedSnapshots = true;
  fs.linkSync(manifestTemporary, manifestPath);
  publishedManifest = true;
  fs.unlinkSync(manifestTemporary);
  manifestTemporary = undefined;
} catch (error) {
  if (manifestTemporary) fs.rmSync(manifestTemporary, { force: true });
  if (stagingPath) fs.rmSync(stagingPath, { recursive: true, force: true });
  if (publishedManifest) fs.rmSync(manifestPath, { force: true });
  if (publishedSnapshots) fs.rmSync(snapshotsPath, { recursive: true, force: true });
  console.error(`prefetch: ${error instanceof Error ? error.message : 'skill package snapshot failed'}`);
  process.exitCode = 1;
}
NODE
  then
    echo "::error::prefetch: skill package validation or snapshot failed; review blocked" >&2
    exit 1
  fi
fi

# The package manifest is the validated current/right-side view of touched
# SKILL.md paths. A deletion produces no package entry and gets no exemption.
HAS_TOUCHED_SKILL=$(jq -r 'if (.packages | length) > 0 then 1 else 0 end' \
  "$OUTDIR/skill-packages.json")

DIFF_BYTES=$(wc -c < "$OUTDIR/diff.txt")
if [ -n "$INCREMENTAL_USED" ]; then
  # Derive CODE_FILES / LOC_CHANGED from the incremental diff itself (meta.json
  # reflects full PR scope, not the new commits).
  CODE_FILES=$(grep -E '^diff --git ' "$OUTDIR/diff.txt" \
    | sed -E 's|.* b/||' \
    | grep -vE '\.(md|tsv|json|lock|yaml|yml)$|^docs/|^specs/|database\.types\.ts$' \
    | wc -l || true)
  LOC_CHANGED=$(grep -cE '^[+-][^+-]' "$OUTDIR/diff.txt" || true)
else
  CODE_FILES=$(jq -r '.files[].path' "$OUTDIR/meta.json" \
    | grep -vE '\.(md|tsv|json|lock|yaml|yml)$|^docs/|^specs/|database\.types\.ts$' \
    | wc -l || true)
  LOC_CHANGED=$(jq -r '[.files[] | .additions + .deletions] | add // 0' "$OUTDIR/meta.json")
fi

echo "Diff bytes: $DIFF_BYTES, Code files: $CODE_FILES, LOC: $LOC_CHANGED"

if [ -n "$INCREMENTAL_USED" ] && [ "$DIFF_BYTES" -lt 50 ]; then
  emit_skip "no new commits since last review ($INCREMENTAL_USED)"
fi

HAS_SKILL_OR_DOC=$(jq -r '.files[].path' "$OUTDIR/meta.json" 2>/dev/null | grep -E '\.md$' | wc -l || echo 0)
if [ "$CODE_FILES" -eq 0 ] && [ "$HAS_SKILL_OR_DOC" -eq 0 ]; then
  emit_skip "no code files changed"
fi

# LOC floor: only enforced on full-diff runs without a present touched skill.
# Incremental runs may legitimately review a tiny fixup; the validator dedupe
# handles noise. Skill package validation/snapshotting above must succeed before
# a small present SKILL.md can bypass this gate.
if [ -z "$INCREMENTAL_USED" ] && [ "$HAS_TOUCHED_SKILL" -eq 0 ] && [ "$LOC_CHANGED" -lt 10 ]; then
  emit_skip "<10 LOC changed"
fi

# Cap the diff at DIFF_CAP_BYTES (default 300KB; override via WOO_REVIEW_DIFF_CAP_BYTES).
#
# The cap is section-aware, NOT a raw byte cut. A naive `head -c` is order-blind:
# when a large low-value prefix (mass file deletions, lockfiles, generated trees)
# sorts ahead of the substantive changes, the byte cut drops the real review
# surface and the swarm reviews nothing while reporting clean (issue #150).
#
# Instead we split the diff into whole `diff --git` file sections, rank them by
# review value, then greedily keep whole sections (never splitting one) until the
# budget is hit. Lowest-value sections are dropped first:
#   tier 0 — sections that add lines (real RIGHT-side content to anchor comments on)
#   tier 1 — modified, no additions (renames, mode changes, context-only)
#   tier 2 — pure file deletions + lockfiles/generated (deletions have no RIGHT
#            side, so resolve-diff-line.sh returns null for them anyway)
# Dropped paths are recorded to $OUTDIR/diff-dropped.txt and surfaced as a loud
# ::warning:: so an under-review is never silent. Under the threshold the diff is
# left byte-for-byte untouched.
DIFF_CAP_BYTES="${WOO_REVIEW_DIFF_CAP_BYTES:-300000}"
if [ "$DIFF_BYTES" -gt "$DIFF_CAP_BYTES" ]; then
  python3 - "$OUTDIR/diff.txt" "$OUTDIR/diff.txt.capped" "$OUTDIR/diff-dropped.txt" "$DIFF_CAP_BYTES" <<'PY'
import re, sys

src, dst, dropped_path, cap = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
lines = open(src, encoding="utf-8", errors="replace").read().splitlines(keepends=True)

# Split into a leading preamble (rare) + one block per `diff --git` header.
HEADER = re.compile(r'^diff --git a/(.+?) b/(.+?)\s*$')
LOWVALUE = re.compile(
    r'(^|/)(package-lock\.json|pnpm-lock\.yaml|yarn\.lock|.+\.lock)$'
    r'|\.(min\.(js|css)|map)$'
    r'|(^|/)(dist|build|vendor|node_modules)/'
    r'|\.generated\.'
)

preamble, sections = [], []
cur = None
for ln in lines:
    m = HEADER.match(ln)
    if m:
        if cur is not None:
            sections.append(cur)
        cur = {"path": m.group(2), "lines": [ln]}
    elif cur is None:
        preamble.append(ln)
    else:
        cur["lines"].append(ln)
if cur is not None:
    sections.append(cur)

def tier(sec):
    body = sec["lines"]
    has_add = any(l.startswith('+') and not l.startswith('+++') for l in body)
    is_delete_file = any(l.startswith('deleted file mode') for l in body)
    low = is_delete_file or bool(LOWVALUE.search(sec["path"]))
    if has_add and not low:
        return 0
    if low or is_delete_file:
        return 2
    return 1

for i, sec in enumerate(sections):
    sec["tier"] = tier(sec)
    sec["orig"] = i
    sec["bytes"] = len("".join(sec["lines"]).encode("utf-8"))

# Stable sort by tier, preserving original order within a tier.
ranked = sorted(sections, key=lambda s: (s["tier"], s["orig"]))

budget = cap - len("".join(preamble).encode("utf-8"))
kept_idx, dropped = set(), []
used = 0
for sec in ranked:
    # Always keep the single highest-value section even if it alone exceeds the
    # budget — one oversized section beats reviewing nothing. Never split it.
    forced = not kept_idx
    if forced or used + sec["bytes"] <= budget:
        kept_idx.add(sec["orig"])
        # An oversized forced keep is an allowed one-time overflow: it must NOT
        # consume the budget meant for the remaining sections, or every later
        # section fails the `used + bytes <= budget` check and is dropped even
        # when it would trivially fit (issue #150 follow-up). Only count bytes
        # that actually fit the budget; the forced overflow is free.
        if not forced or sec["bytes"] <= budget:
            used += sec["bytes"]
    else:
        dropped.append(sec)

# Re-emit kept sections in their ORIGINAL diff order (anchoring is per-file, but
# original order keeps the diff readable and stable).
out = list(preamble)
for sec in sections:
    if sec["orig"] in kept_idx:
        out.extend(sec["lines"])

if dropped:
    drop_paths = sorted({s["path"] for s in dropped})
    out.append(
        "\n[DIFF TRUNCATED: %d of %d file section(s) dropped to fit the %d-byte "
        "cap; lowest review-value first. Dropped paths in diff-dropped.txt.]\n"
        % (len(dropped), len(sections), cap)
    )
    with open(dropped_path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(drop_paths) + "\n")
    sys.stderr.write(
        "::warning::woostack-review: diff exceeded %d bytes; dropped %d lower-value "
        "file section(s) from review: %s%s\n"
        % (
            cap,
            len(dropped),
            ", ".join(drop_paths[:15]),
            " ..." if len(drop_paths) > 15 else "",
        )
    )

open(dst, "w", encoding="utf-8").write("".join(out))
print("diff-cap: kept %d/%d section(s), dropped %d, ~%d bytes (cap %d)"
      % (len(kept_idx), len(sections), len(dropped), used, cap))
PY
  # Atomic replace so a crash mid-write cannot corrupt the original.
  mv "$OUTDIR/diff.txt.capped" "$OUTDIR/diff.txt"
  DIFF_BYTES=$(wc -c < "$OUTDIR/diff.txt")
fi

# Discover project-rule files.
# Root scan: AGENTS.md / CLAUDE.md / .cursorrules / .windsurfrules / GEMINI.md.
# Per-changed-file walk: collect AGENTS.md / CLAUDE.md from every parent dir
# between the changed file and repo root. Config-listed project_rules are appended
# to the same candidate stream. Each unique document is emitted once: first by
# resolved real path (symlinks / alternate spellings), then by content hash (hard
# links or copied aliases), then by relative path as a fallback.
ROOT="$(git -C "${GITHUB_WORKSPACE:-.}" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$ROOT" ]; then
  RULES_LIST="$(mktemp)"
  RULES_BUF="$(mktemp)"
  RULES_INCLUDED="$(mktemp)"
  RULES_SEEN_REL="$(mktemp)"
  RULES_SEEN_REAL="$(mktemp)"
  RULES_SEEN_HASH="$(mktemp)"

  # One python3 spawn per candidate: prints the resolved real path on line 1
  # and the sha256 content digest on line 2.
  rule_identity() {
    python3 - "$ROOT/$1" <<'PY'
import hashlib
import os
import sys

path = sys.argv[1]
print(os.path.realpath(path))
h = hashlib.sha256()
with open(path, "rb") as fh:
    for chunk in iter(lambda: fh.read(1024 * 1024), b""):
        h.update(chunk)
print(h.hexdigest())
PY
  }

  include_rule_once() {
    local rel="$1"
    local identity real hash

    [ -n "$rel" ] || return 0
    [ -f "$ROOT/$rel" ] || return 0

    identity="$(rule_identity "$rel")"
    real="$(printf '%s\n' "$identity" | sed -n '1p')"
    hash="$(printf '%s\n' "$identity" | sed -n '2p')"

    if grep -qxF "$rel" "$RULES_SEEN_REL"; then
      return 0
    fi
    if [ -n "$real" ] && grep -qxF "$real" "$RULES_SEEN_REAL"; then
      return 0
    fi
    if [ -n "$hash" ] && grep -qxF "$hash" "$RULES_SEEN_HASH"; then
      return 0
    fi

    printf '%s\n' "$rel" >> "$RULES_SEEN_REL"
    [ -n "$real" ] && printf '%s\n' "$real" >> "$RULES_SEEN_REAL"
    [ -n "$hash" ] && printf '%s\n' "$hash" >> "$RULES_SEEN_HASH"

    printf '%s\n' "$rel" >> "$RULES_INCLUDED"
    printf '## SOURCE: %s\n' "$rel" >> "$RULES_BUF"
    cat "$ROOT/$rel" >> "$RULES_BUF"
    printf '\n\n' >> "$RULES_BUF"
  }

  for f in AGENTS.md CLAUDE.md .cursorrules .windsurfrules GEMINI.md; do
    [ -f "$ROOT/$f" ] && printf '%s\n' "$f" >> "$RULES_LIST"
  done

  while IFS= read -r changed; do
    [ -n "$changed" ] || continue
    dir="$(dirname "$changed")"
    while [ "$dir" != "." ] && [ "$dir" != "/" ]; do
      for f in AGENTS.md CLAUDE.md; do
        [ -f "$ROOT/$dir/$f" ] && printf '%s\n' "$dir/$f" >> "$RULES_LIST"
      done
      dir="$(dirname "$dir")"
    done
  done < <(jq -r '.files[].path' "$OUTDIR/meta.json")

  # `load-config.sh` already ran near the top (issue #19 auto-skip needs it).
  # Append config-listed project_rules to the same dedupe pass as auto-discovery.
  if [ -s "$OUTDIR/config.json" ] && jq -e '.project_rules // empty' "$OUTDIR/config.json" >/dev/null 2>&1; then
    while IFS= read -r pat; do
      [ -n "$pat" ] || continue
      while IFS= read -r match; do
        [ -n "$match" ] && [ -f "$ROOT/$match" ] && printf '%s\n' "$match" >> "$RULES_LIST"
      done < <(cd "$ROOT" && compgen -G "$pat" 2>/dev/null || true)
    done < <(jq -r '.project_rules[]?' "$OUTDIR/config.json")
  fi

  # include_rule_once dedupes by rel path / real path / content hash and skips
  # blank lines itself, so the candidate list feeds it directly.
  if [ -s "$RULES_LIST" ]; then
    while IFS= read -r rel; do
      include_rule_once "$rel"
    done < "$RULES_LIST"
  fi

  if [ -s "$RULES_INCLUDED" ]; then
    RULES_BYTES=$(wc -c < "$RULES_BUF")
    if [ "$RULES_BYTES" -gt 100000 ]; then
      {
        head -c 100000 "$RULES_BUF"
        printf '\n[RULES TRUNCATED AT 100KB]\n'
      } > "$OUTDIR/rules.md"
    else
      mv "$RULES_BUF" "$OUTDIR/rules.md"
    fi

    RULES_COUNT=$(wc -l < "$RULES_INCLUDED" | xargs)
    FINAL_BYTES=$(wc -c < "$OUTDIR/rules.md")
    echo "Discovered $RULES_COUNT unique rule document(s), $FINAL_BYTES bytes:"
    sed 's/^/  /' "$RULES_INCLUDED"
  fi

  rm -f "$RULES_LIST" "$RULES_BUF" "$RULES_INCLUDED" "$RULES_SEEN_REL" "$RULES_SEEN_REAL" "$RULES_SEEN_HASH"
fi

# `authors_skip` + `release_rollup_pattern` already enforced above (issue #19),
# pre-diff-fetch so a skipped PR never pays for the diff download.

# ignore[] — pre-filter changed paths and diff body for downstream angle gates.
# fnmatch semantics; '**' matches any depth via Python's fnmatch.
if [ -s "$OUTDIR/config.json" ] && jq -e '.ignore // empty' "$OUTDIR/config.json" >/dev/null 2>&1; then
  python3 - "$OUTDIR/meta.json" "$OUTDIR/diff.txt" "$OUTDIR/config.json" "$OUTDIR/changed-paths.filtered.txt" "$OUTDIR/diff.filtered.txt" <<'PY'
import json
import os
import re
import sys
from fnmatch import fnmatch

meta_path, diff_path, cfg_path, paths_out, diff_out = sys.argv[1:6]

cfg = json.load(open(cfg_path))
patterns = cfg.get("ignore") or []

def globmatch(path, pattern):
    # Support '**' (any depth) on top of plain fnmatch.
    if "**" in pattern:
        regex = re.escape(pattern).replace(r"\*\*", ".*").replace(r"\*", "[^/]*").replace(r"\?", ".")
        return re.fullmatch(regex, path) is not None
    return fnmatch(path, pattern)

def ignored(path):
    return any(globmatch(path, p) for p in patterns)

meta = json.load(open(meta_path))
kept_paths = [f["path"] for f in meta.get("files", []) if not ignored(f["path"])]
with open(paths_out, "w") as fh:
    for p in kept_paths:
        fh.write(p + "\n")

# Strip per-file diff sections whose header path is ignored.
with open(diff_path, "r", errors="replace") as fh:
    diff = fh.read()
out = []
keep = True
for line in diff.splitlines(keepends=True):
    if line.startswith("diff --git "):
        m = re.match(r"diff --git a/(\S+) b/(\S+)", line)
        path = (m.group(2) if m else "")
        keep = not ignored(path)
    if keep:
        out.append(line)
with open(diff_out, "w") as fh:
    fh.writelines(out)

stripped = len(meta.get("files", [])) - len(kept_paths)
print("load-config: ignore[] stripped {} path(s); filtered artifacts written".format(stripped))
PY
fi

# Prior unresolved review threads — feed the posting stage's event-floor + dedupe
# logic. REST does not expose isResolved; GraphQL reviewThreads does. Counts ANY
# unresolved thread (human + bot) — a conservative gate that keeps a PR in
# REQUEST_CHANGES while any reviewer still has an open thread. First page only
# (100 threads); pagination is a follow-up.
if [ "$TEST_MODE" = "1" ] && [ -n "${WOO_REVIEW_FAKE_PRIOR_THREADS_JSON:-}" ]; then
  THREADS_JSON="$WOO_REVIEW_FAKE_PRIOR_THREADS_JSON"
else
  OWNER_NAME="${GITHUB_REPOSITORY%/*}"
  REPO_NAME="${GITHUB_REPOSITORY#*/}"
  THREADS_JSON=$(gh api graphql -F owner="$OWNER_NAME" -F repo="$REPO_NAME" -F pr="$PR_NUMBER" -f query='
    query($owner: String!, $repo: String!, $pr: Int!) {
      repository(owner: $owner, name: $repo) {
        pullRequest(number: $pr) {
          reviewThreads(first: 100) {
            nodes {
              isResolved
              path
              line
              comments(first: 1) {
                nodes { body author { login } }
              }
            }
          }
        }
      }
    }' 2>/dev/null || echo '{}')
fi
# Each entry is informational only — used by the dedup + posting stage.
# Includes resolved threads (status: "resolved") so dedup can suppress
# re-raising them. Posting event-floor counts ONLY open threads.
printf '%s' "$THREADS_JSON" | jq '
  [ .data.repository.pullRequest.reviewThreads.nodes[]?
    | select(.path != null)
    | { file: .path,
        line: (.line // 1),
        title: (((.comments.nodes[0].body // "") | split("\n")[0] | gsub("^\\*\\*|\\*\\*$"; ""))[0:60]),
        author: (.comments.nodes[0].author.login // ""),
        status: (if .isResolved then "resolved" else "open" end)
      }
  ]' > "$OUTDIR/prior-findings.json" 2>/dev/null || echo '[]' > "$OUTDIR/prior-findings.json"

PRIOR_COUNT=$(jq 'length' "$OUTDIR/prior-findings.json" 2>/dev/null || echo 0)
echo "Prior review threads (open + resolved): $PRIOR_COUNT"

# Cross-PR memory — composed per-PR via recall.sh when a scope-routed store
# (.woostack/memory/) exists: scope-matched notes, one-hop links, and
# global-scoped notes. Missing store or recall.sh => no memory context
# (normal for fresh repos or individual manual installs).
WOOSTACK_DIR="$WOOSTACK_COMMON_ROOT/.woostack"
MEMORY_OUT="$OUTDIR/memory.md"
RECALL="$SCRIPT_DIR/../../woostack-init/scripts/recall.sh"
# Working-set paths: prefer the ignore-filtered list, else derive from meta.json.
PATHS_FILE="$OUTDIR/changed-paths.filtered.txt"
if [ ! -f "$PATHS_FILE" ]; then
  jq -r '.files[].path' "$OUTDIR/meta.json" 2>/dev/null > "$OUTDIR/changed-paths.txt" || true
  PATHS_FILE="$OUTDIR/changed-paths.txt"
fi

if [ -d "$WOOSTACK_DIR/memory" ]; then
  if [ -f "$RECALL" ]; then
    if bash "$RECALL" "$WOOSTACK_DIR" "$PATHS_FILE" > "$MEMORY_OUT" 2> "$OUTDIR/recall.log"; then
      [ -s "$MEMORY_OUT" ] || rm -f "$MEMORY_OUT"
      echo "Composed cross-PR memory via recall.sh ($(wc -c < "$MEMORY_OUT" 2>/dev/null || echo 0)B; see recall.log)"
    else
      echo "::warning::recall.sh failed; omitting cross-PR memory"
      rm -f "$MEMORY_OUT"
    fi
  else
    echo "::warning::recall.sh not found at $RECALL; omitting cross-PR memory"
    rm -f "$MEMORY_OUT"
  fi
else
  rm -f "$MEMORY_OUT"
fi

# Wholesale wisdom guidance — every .woostack/wisdom/*.md body (generalized,
# cross-cutting house-rules), composed via compose-wisdom.sh (the wisdom analogue
# of recall.sh/memory.md). Always-load, no scope routing. No-op when the store is
# absent/empty, so $OUTDIR/wisdom.md is present only when there is wisdom to read.
WISDOM_OUT="$OUTDIR/wisdom.md"
COMPOSE_WISDOM="$SCRIPT_DIR/compose-wisdom.sh"
if [ -f "$COMPOSE_WISDOM" ]; then
  if bash "$COMPOSE_WISDOM" "$WOOSTACK_COMMON_ROOT" > "$WISDOM_OUT" 2>"$OUTDIR/compose-wisdom.log"; then
    [ -s "$WISDOM_OUT" ] || rm -f "$WISDOM_OUT"
    [ -f "$WISDOM_OUT" ] && echo "Composed wisdom guidance ($(wc -c < "$WISDOM_OUT")B)"
  else
    echo "::warning::compose-wisdom.sh failed; omitting wisdom guidance (see compose-wisdom.log)" >&2
    rm -f "$WISDOM_OUT"
  fi
fi

# Issue #14: split oversized diffs into chunks. Runs LAST so it sees the final
# post-ignore diff (diff.filtered.txt when present). Under the threshold this
# is a no-op (no chunks.txt produced, downstream behaves exactly as before).
bash "$SCRIPT_DIR/chunk-diff.sh"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "force_tier=${FORCE_TIER:-}" >> "$GITHUB_OUTPUT"
  echo "skip=false" >> "$GITHUB_OUTPUT"
fi
echo "skip=false"
echo "Prefetch complete: $OUTDIR/"
